# Display width, and laying text out by it.

test_that("CJK characters are two columns and ASCII is one", {
  expect_equal(cjk_width(ZH), 4L)
  expect_equal(cjk_width("ab"), 2L)
  expect_equal(cjk_width(ZH_SENTENCE), 12L)
  expect_equal(cjk_width(JA_KANA), 10L)
  expect_equal(cjk_width(KO), 10L)
})

test_that("width and nchar() disagree exactly where they should", {
  # the misalignment this package exists to fix: same nchar, different width
  expect_equal(nchar(ZH), nchar("ab"))
  expect_false(cjk_width(ZH) == cjk_width("ab"))
})

test_that("width is an integer vector and is vectorised", {
  w <- cjk_width(c(ZH, "ab", ""))
  expect_type(w, "integer")
  expect_equal(w, c(4L, 2L, 0L))
})

test_that("combining marks and zero-width characters take no columns", {
  # "e" + COMBINING ACUTE ACCENT is two code points, one column
  expect_equal(nchar(COMBINING), 2L)
  expect_equal(cjk_width(COMBINING), 1L)
  # ZERO WIDTH SPACE between two letters
  expect_equal(nchar(ZWSP), 3L)
  expect_equal(cjk_width(ZWSP), 2L)
})

test_that("supplementary-plane ideographs are two columns", {
  expect_equal(cjk_width(EXT_B), 2L)
})

test_that("fullwidth forms are two columns and halfwidth katakana is one", {
  expect_equal(cjk_width(FW_DIGITS), 6L)
  expect_equal(cjk_width(IDEOGRAPHIC_SPACE), 2L)
  expect_equal(cjk_width(HW_KA), 1L)
})

test_that("width is stable for the characters Annex #11 pins down", {
  # Only the classes Annex #11 actually fixes: Wide, Fullwidth and Halfwidth.
  # Deliberately NOT asserted: the degree sign, the box-drawing characters and
  # friends. ICU 60 called them one column and ICU 74 calls them two, so any
  # literal width for them is a claim about the checking machine's stringi
  # build rather than about this package -- see ?cjk_width.
  expect_equal(cjk_width("\u4e2d"), 2L)        # ideograph, EastAsianWidth=W
  expect_equal(cjk_width("\U00020000"), 2L)    # Extension B ideograph, =W
  expect_equal(cjk_width("\u3000"), 2L)        # ideographic space, =F
  expect_equal(cjk_width("\uff11"), 2L)        # fullwidth digit one, =F
  expect_equal(cjk_width("\uff76"), 1L)        # halfwidth katakana, =H
})

test_that("zero width comes from the general category, not from Annex #11", {
  # These four are asserted literally for a reason that has nothing to do with
  # East Asian Width, which is why they are safe where the ambiguous letters
  # below are not: U+0301 and U+200B are zero because their general categories
  # are Mn and Cf, and the two jamo are zero because they compose onto a
  # preceding syllable. U+0301 is in fact East Asian Ambiguous -- asserting it
  # in the block above implied a stability guarantee that class does not give.
  expect_equal(cjk_width("\u0301"), 0L)        # combining acute, Mn
  expect_equal(cjk_width("\u200b"), 0L)        # ZERO WIDTH SPACE, Cf
  expect_equal(cjk_width("\u1160"), 0L)        # jamo medial vowel
  expect_equal(cjk_width("\u11a8"), 0L)        # jamo final consonant
  # the categories those claims rest on, pinned so the reasoning cannot rot
  expect_true(stringi::stri_detect_charclass("\u0301", "\\p{Mn}"))
  expect_true(stringi::stri_detect_charclass("\u200b", "\\p{Cf}"))
})

test_that("ambiguous-width characters are reported consistently, whatever ICU says", {
  # The value is ICU's to choose; what must hold on every build is that it is
  # a sane column count and that a homogeneous block is not split down the
  # middle, which would make a table ragged in a way no caller could predict.
  box <- stringi::stri_enc_fromutf32(as.list(0x2500:0x257F))
  w <- cjk_width(box)
  expect_true(all(w %in% c(1L, 2L)))
  expect_length(unique(w), 1L)
  amb <- cjk_width(c("\u00b0", "\u00ae", "\u2122", "\u00a9", "\u2714"))
  expect_true(all(amb %in% c(1L, 2L)))
  # Greek, Cyrillic, the section sign and plus-minus live here too, not in the
  # stable block. All four are East Asian Ambiguous, the same class as the
  # degree sign, which ICU 60 called one column and ICU 74 calls two. Asserting
  # a literal 1 for them was a claim about this machine's ICU that a newer one
  # on a CRAN check farm could falsify.
  letters_amb <- cjk_width(c("\u03b1", "\u0430", "\u00a7", "\u00b1"))
  expect_true(all(letters_amb %in% c(1L, 2L)))
  # what does hold everywhere: an ambiguous character is never wider than an
  # ideograph, so a layout budgeted for CJK always has room for it
  expect_true(all(letters_amb <= cjk_width("\u4e2d")))
  # and whatever the per-character answer is, the total is additive
  expect_equal(cjk_width(paste0(box, collapse = "")), as.integer(sum(w)))
})

test_that("a character vector measures the same whatever the print options", {
  # The invariant users can rely on: text is text. as.character() coercion of a
  # *numeric* vector is R's formatting and moves with options(scipen) and
  # options(OutDec) -- documented on ?has_cjk -- so this pins the half that must
  # not move, and shows by contrast that the other half genuinely does.
  old <- options(scipen = 0, OutDec = ".")
  on.exit(options(old), add = TRUE)
  txt <- c(ZH, "abcd", FW_DIGITS, "")
  base_w <- cjk_width(txt); base_r <- cjk_ratio(txt); base_s <- cjk_script(txt)
  for (o in list(list(scipen = 100), list(scipen = -9), list(OutDec = ","),
                 list(scipen = 100, OutDec = ","))) {
    do.call(options, o)
    expect_equal(cjk_width(txt), base_w, info = paste(names(o), collapse = "+"))
    expect_equal(cjk_ratio(txt), base_r, info = paste(names(o), collapse = "+"))
    expect_equal(cjk_script(txt), base_s, info = paste(names(o), collapse = "+"))
    expect_equal(to_halfwidth(FW_DIGITS), "123")
  }
  options(old)
  # and the contrast: a numeric vector is not stable, which is the reason the
  # help page tells you to convert deliberately
  options(scipen = 0)
  narrow <- cjk_width(100000)
  options(scipen = 100)
  expect_false(identical(cjk_width(100000), narrow))
})

test_that("cjk_width() handles NA, empty strings and zero-length input", {
  expect_true(is.na(cjk_width(NA_character_)))
  expect_equal(cjk_width(""), 0L)
  expect_equal(cjk_width(character(0)), integer(0))
  expect_type(cjk_width(character(0)), "integer")
  expect_equal(cjk_width(c(ZH, NA, "")), c(4L, NA, 0L))
})

test_that("cjk_pad() pads to a display width, not a character count", {
  padded <- cjk_pad(c(ZH, "abcd"), 6)
  expect_equal(cjk_width(padded), c(6L, 6L))
  # the CJK string needed two spaces, the ASCII one needed two as well, but
  # they started from different character counts
  expect_equal(nchar(padded), c(4L, 6L))
})

test_that("cjk_pad() honours the side argument", {
  expect_equal(cjk_pad("ab", 6, side = "right"), "ab    ")
  expect_equal(cjk_pad("ab", 6, side = "left"), "    ab")
  expect_equal(cjk_width(cjk_pad(ZH, 8, side = "both")), 8L)
})

test_that("cjk_pad() never truncates", {
  expect_equal(cjk_pad(ZH_SENTENCE, 2), ZH_SENTENCE)
  expect_equal(cjk_pad("abcdef", 3), "abcdef")
})

test_that("cjk_pad() validates the pad character", {
  expect_error(cjk_pad("a", 5, pad = "ab"), "single")
  expect_error(cjk_pad("a", 5, pad = ""), "single")
  # a fullwidth pad would make the arithmetic wrong, so it is rejected
  expect_error(cjk_pad("a", 5, pad = "\u3000"), "one column")
  expect_error(cjk_pad("a", 5, side = "middle"))
})

test_that("cjk_pad() handles NA and zero-length input", {
  expect_true(is.na(cjk_pad(NA_character_, 5)))
  expect_true(is.na(cjk_pad("ab", NA)))
  expect_equal(cjk_pad(character(0), 5), character(0))
  # `width` is checked before the zero-length exit, so a bad one is an error
  # whatever the length of `x` -- as `pad` already was
  expect_error(cjk_pad(character(0), Inf), "finite")
  expect_error(cjk_pad(character(0), "5"), "numeric")
  expect_error(cjk_pad(character(0), numeric(0)), "at least one element")
  expect_error(cjk_truncate(character(0), Inf), "finite")
  expect_error(cjk_truncate(character(0), "5"), "numeric")
})

test_that("cjk_pad() does not eat a leading byte-order mark", {
  # stri_pad() strips one leading U+FEFF, reading it as a byte-order mark, and
  # does so unconditionally -- including when the string is already wide enough
  # and no padding is added, which made a documented no-op return an edited
  # string. U+FEFF is zero width, so none of this changes a column count.
  bom <- "\uFEFF"
  zh <- "\u4e2d"
  expect_equal(utf8ToInt(cjk_pad(paste0(bom, zh), 6))[1], 0xFEFFL)
  expect_equal(utf8ToInt(cjk_pad(paste0(bom, zh), 6, side = "left"))[1],
               0xFEFFL)
  expect_equal(utf8ToInt(cjk_pad(paste0(bom, zh), 6, side = "both"))[1],
               0xFEFFL)
  # already wide enough: must come back byte-for-byte unchanged
  wide <- paste0(bom, zh, zh, zh)
  expect_equal(cjk_pad(wide, 2), wide)
  expect_equal(cjk_pad(paste0(bom, zh), 2), paste0(bom, zh))
  # a lone mark is not destroyed, even with nothing to pad to
  expect_equal(cjk_pad(bom, 0), bom)
  expect_equal(utf8ToInt(cjk_pad(bom, 3)), c(0xFEFFL, 0x20L, 0x20L, 0x20L))
  # only the one stringi removes is restored, so a doubled mark stays doubled
  expect_equal(utf8ToInt(cjk_pad(paste0(bom, bom, zh), 4))[1:2],
               c(0xFEFFL, 0xFEFFL))
  # the width contract still holds exactly
  for (w in 2:9) {
    expect_equal(cjk_width(cjk_pad(paste0(bom, zh), w)), as.integer(w))
  }
  # and an NA width must not become the string "NA" with a mark glued on
  expect_true(is.na(cjk_pad(paste0(bom, zh), NA)))
  # text with no mark is untouched by any of this
  expect_equal(cjk_pad(zh, 6), paste0(zh, "    "))
})

test_that("cjk_pad() refuses a width it cannot recycle", {
  # stringi recycles a ragged pair with a warning and hands back a partial
  # result; for a layout function that is worse than refusing, and it left
  # cjk_pad() and cjk_truncate() disagreeing about the same mistake
  expect_error(cjk_pad(c("a", "b"), c(3, 4, 5)), "recyclable")
  expect_error(cjk_pad(c("a", "b", "c"), c(3, 4)), "recyclable")
  # the lengths are named, because they come from data rather than from
  # something the caller just typed and can see
  expect_error(cjk_pad(c("a", "b", "c"), c(3, 4)),
               "`x` \\(3\\) and `width` \\(2\\)")
  expect_error(cjk_truncate(c("a", "b"), c(3, 4, 5)),
               "`x` \\(2\\) and `width` \\(3\\)")
  expect_error(cjk_pad("a", integer(0)), "at least one element")
  # ...and a clean recycle still works, in both directions
  expect_equal(cjk_width(cjk_pad(c("a", "b"), 4)), c(4L, 4L))
  expect_equal(cjk_width(cjk_pad("a", c(3, 5))), c(3L, 5L))
})

test_that("both layout verbs reject a width that cannot be an integer", {
  # Inf and anything past the integer range are numeric, so they clear the
  # is.numeric() check and then coerce to NA -- which is the silent
  # missing-output failure that check exists to prevent, plus a base R warning
  # that names no argument. cjk_pad(x, Inf) is a plausible way to write "do not
  # truncate" and it used to hand back a vector of NA.
  expect_error(cjk_pad("a", Inf), "finite")
  expect_error(cjk_pad("a", -Inf), "finite")
  expect_error(cjk_truncate("abcdef", Inf), "finite")
  expect_error(cjk_pad("a", 3e9), "integer range")
  expect_error(cjk_truncate("abcdef", -3e9), "integer range")
  # one bad element in an otherwise fine vector is still an error
  expect_error(cjk_pad(c("a", "b"), c(2, Inf)), "finite")
  # ...and no warning leaks out of the rejection
  expect_silent(try(cjk_pad("a", Inf), silent = TRUE))
})

test_that("a missing width is still missing output, not an error", {
  # NA is how every other function in the package reports missing input, and
  # NaN is a kind of NA in R, so neither is caught by the check above
  expect_true(is.na(cjk_pad("a", NA_real_)))
  expect_true(is.na(cjk_pad("a", NaN)))
  expect_true(is.na(cjk_truncate("abcdef", NaN)))
  expect_equal(cjk_pad(c("a", "b"), c(4, NA)), c("a   ", NA))
})

test_that("both layout verbs reject a width that is not a number", {
  # as.integer("abc") is a warning and an NA, so a typo used to come back as
  # missing output rather than as an error
  expect_error(cjk_pad("abc", "5"), "numeric")
  expect_error(cjk_truncate("abcdef", "abc"), "numeric")
  expect_error(cjk_truncate("abcdef", list(3)), "numeric")
  expect_error(cjk_truncate("abcdef", TRUE), "numeric")
})

test_that("cjk_truncate() fits the result inside the budget", {
  # 6 ideographs is 12 columns; 6 columns leaves room for one plus "..."
  out <- cjk_truncate("\u4e2d\u6587\u4e2d\u6587\u4e2d\u6587", 6)
  expect_true(cjk_width(out) <= 6L)
  expect_equal(out, "\u4e2d...")
  expect_equal(cjk_width(out), 5L)
})

test_that("cjk_truncate() uses the full budget on ASCII", {
  expect_equal(cjk_truncate("abcdefghij", 6), "abc...")
  expect_equal(cjk_width(cjk_truncate("abcdefghij", 6)), 6L)
})

test_that("cjk_truncate() leaves text that already fits alone", {
  expect_equal(cjk_truncate(ZH, 10), ZH)
  expect_equal(cjk_truncate("abc", 3), "abc")
  # exactly at the limit is still a fit
  expect_equal(cjk_truncate(ZH, 4), ZH)
})

test_that("cjk_truncate() respects a custom ellipsis", {
  # the single-character ellipsis is one column, so more text survives
  out <- cjk_truncate("\u4e2d\u6587\u4e2d\u6587\u4e2d\u6587", 6, ellipsis = "\u2026")
  expect_true(cjk_width(out) <= 6L)
  expect_equal(out, "\u4e2d\u6587\u2026")
})

test_that("cjk_truncate() copes with a budget smaller than the ellipsis", {
  expect_equal(cjk_truncate("abcdef", 2), "..")
  expect_equal(cjk_truncate("abcdef", 0), "")
  expect_true(cjk_width(cjk_truncate("abcdef", 1)) <= 1L)
})

test_that("cjk_truncate() never orphans a combining mark", {
  # "e" + acute, then more text; a cut at one column must keep the mark
  x <- paste0(COMBINING, "xxxx")
  out <- cjk_truncate(x, 4, ellipsis = "")
  expect_equal(out, paste0(COMBINING, "xxx"))
  expect_equal(cjk_width(out), 4L)
})

test_that("the truncated result never exceeds the budget", {
  # a width-aware truncate that can overshoot is no better than substr()
  pool <- c(ZH, "ab", EXT_B, COMBINING, ZWSP, IDEOGRAPHIC_SPACE, FW_DIGITS,
            JA_KANA, HW_KA, " ")
  set.seed(20240609)
  for (i in seq_len(200)) {
    s <- paste0(sample(pool, sample(1:5, 1), replace = TRUE), collapse = "")
    w <- sample(0:14, 1)
    # a literal U+2026 here would be mojibake in a non-UTF-8 locale, and the
    # assertion would silently stop testing a one-column ellipsis
    for (e in c("...", "\u2026", "")) {
      expect_lte(cjk_width(cjk_truncate(s, w, ellipsis = e)), w)
    }
  }
})

test_that("cjk_truncate() is vectorised over x and width", {
  expect_equal(
    cjk_truncate(c("abcdefghij", "abc"), 6),
    c("abc...", "abc")
  )
  expect_equal(
    cjk_truncate("abcdefghij", c(6, 20)),
    c("abc...", "abcdefghij")
  )
})

test_that("cjk_truncate() handles NA, empty strings and zero-length input", {
  expect_true(is.na(cjk_truncate(NA_character_, 5)))
  expect_equal(cjk_truncate("", 5), "")
  expect_equal(cjk_truncate(character(0), 5), character(0))
  expect_type(cjk_truncate(character(0), 5), "character")
  expect_equal(cjk_truncate(c("abcdefghij", NA), 6), c("abc...", NA))
})

test_that("a string of zero-width characters fits in nought columns", {
  # "strings that already fit are returned unchanged" has to hold at width 0
  # too: a lone byte-order mark, a format character and a combining mark all
  # occupy no columns, so nought of them is enough. Testing width 0 before the
  # fit made cjk_truncate() answer "" for all three, deleting a character while
  # promising not to -- the same silent edit cjk_pad() was fixed for.
  zero_width <- c("\uFEFF", "\u200b", "\u0301", "\u200b\uFEFF", "")
  for (s in zero_width) {
    expect_equal(cjk_width(s), 0L, info = sprintf("U+%04X", utf8ToInt(s)[1]))
    expect_equal(cjk_truncate(s, 0), s, info = sprintf("U+%04X",
                                                       utf8ToInt(s)[1]))
    expect_equal(cjk_truncate(s, 5), s, info = sprintf("U+%04X",
                                                       utf8ToInt(s)[1]))
  }
  # a negative budget still accommodates nothing at all
  expect_equal(cjk_truncate("\uFEFF", -1), "")
  # and a string with any real width is still emptied at 0
  expect_equal(cjk_truncate("abc", 0), "")
  expect_equal(cjk_truncate(ZH, 0), "")
  # the mark is kept where it belongs, not moved
  expect_equal(cjk_truncate("\uFEFFabcdef", 4), "\uFEFFa...")
})

test_that("cjk_truncate() validates its arguments", {
  expect_error(cjk_truncate("abc", 5, ellipsis = NA_character_), "single")
  expect_error(cjk_truncate("abc", 5, ellipsis = c("a", "b")), "single")
  expect_error(cjk_truncate(c("a", "b", "c"), c(1, 2)), "recyclable")
})
