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
})

test_that("cjk_pad() refuses a width it cannot recycle", {
  # stringi recycles a ragged pair with a warning and hands back a partial
  # result; for a layout function that is worse than refusing, and it left
  # cjk_pad() and cjk_truncate() disagreeing about the same mistake
  expect_error(cjk_pad(c("a", "b"), c(3, 4, 5)), "recyclable")
  expect_error(cjk_pad(c("a", "b", "c"), c(3, 4)), "recyclable")
  expect_error(cjk_pad("a", integer(0)), "at least one element")
  # ...and a clean recycle still works, in both directions
  expect_equal(cjk_width(cjk_pad(c("a", "b"), 4)), c(4L, 4L))
  expect_equal(cjk_width(cjk_pad("a", c(3, 5))), c(3L, 5L))
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
    for (e in c("...", "…", "")) {
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

test_that("cjk_truncate() validates its arguments", {
  expect_error(cjk_truncate("abc", 5, ellipsis = NA_character_), "single")
  expect_error(cjk_truncate("abc", 5, ellipsis = c("a", "b")), "single")
  expect_error(cjk_truncate(c("a", "b", "c"), c(1, 2)), "recyclable")
})
