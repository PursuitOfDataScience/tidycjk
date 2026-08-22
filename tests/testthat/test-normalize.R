# Fullwidth and halfwidth normalisation, and voiced-mark composition.

test_that("fullwidth ASCII narrows to ASCII", {
  expect_equal(to_halfwidth(FW_DIGITS), "123")
  expect_equal(to_halfwidth("\uff21\uff22\uff23"), "ABC")
  expect_equal(to_halfwidth("\uff01\uff1f\uff20"), "!?@")
  # the point of narrowing: the result parses as a number
  expect_equal(as.numeric(to_halfwidth(FW_DIGITS)), 123)
})

test_that("ASCII widens to fullwidth", {
  expect_equal(to_fullwidth("123"), FW_DIGITS)
  expect_equal(to_fullwidth("ABC"), "\uff21\uff22\uff23")
})

test_that("the ideographic space maps to and from the ASCII space", {
  expect_equal(to_halfwidth(IDEOGRAPHIC_SPACE), " ")
  expect_equal(to_fullwidth(" "), IDEOGRAPHIC_SPACE)
})

test_that("ASCII round-trips exactly, in both directions", {
  x <- "abc XYZ 123 !?@ ~"
  expect_equal(to_halfwidth(to_fullwidth(x)), x)
  wide <- to_fullwidth(x)
  expect_equal(to_fullwidth(to_halfwidth(wide)), wide)
  # every printable ASCII character survives the trip
  ascii <- paste0(intToUtf8(0x20:0x7E, multiple = TRUE), collapse = "")
  expect_equal(to_halfwidth(to_fullwidth(ascii)), ascii)
})

test_that("halfwidth katakana is widened, and composed by default", {
  # U+FF76 U+FF9E -- two code points -- becomes U+30AC, one
  expect_equal(to_halfwidth(HW_KA_VOICED), FW_GA)
  expect_equal(nchar(to_halfwidth(HW_KA_VOICED)), 1L)
  expect_equal(utf8ToInt(to_halfwidth(HW_KA_VOICED)), 0x30ACL)
  # the input really was two code points, so this is composition, not a no-op
  expect_equal(nchar(HW_KA_VOICED), 2L)
})

test_that("compose = FALSE leaves the pair as two code points", {
  out <- to_halfwidth(HW_KA_VOICED, compose = FALSE)
  expect_equal(nchar(out), 2L)
  expect_equal(utf8ToInt(out), c(0x30ABL, 0x309BL))
  # ...and it is the spacing mark U+309B, not the combining mark U+3099
  expect_equal(substr(out, 2, 2), VOICED_MARK)
})

test_that("to_fullwidth() widens and composes halfwidth katakana too", {
  expect_equal(to_fullwidth(HW_KA_VOICED), FW_GA)
  expect_equal(to_fullwidth(HW_KA), FW_KA)
})

test_that("bare halfwidth katakana widens without composing anything", {
  expect_equal(to_halfwidth(HW_KA), FW_KA)
  expect_equal(to_halfwidth("\uff71\uff72\uff73"), "\u30a2\u30a4\u30a6")
  expect_equal(to_halfwidth("\uff76\uff80\uff76\uff85"), JA_KATAKANA)
})

test_that("every row of the voicing table composes correctly", {
  # ka sa ta ha rows: base + 1
  expect_equal(to_halfwidth("\uff76\uff9e\uff77\uff9e\uff78\uff9e\uff79\uff9e\uff7a\uff9e"), "\u30ac\u30ae\u30b0\u30b2\u30b4")
  expect_equal(to_halfwidth("\uff7b\uff9e\uff7c\uff9e\uff7d\uff9e\uff7e\uff9e\uff7f\uff9e"), "\u30b6\u30b8\u30ba\u30bc\u30be")
  expect_equal(to_halfwidth("\uff80\uff9e\uff81\uff9e\uff82\uff9e\uff83\uff9e\uff84\uff9e"), "\u30c0\u30c2\u30c5\u30c7\u30c9")
  expect_equal(to_halfwidth("\uff8a\uff9e\uff8b\uff9e\uff8c\uff9e\uff8d\uff9e\uff8e\uff9e"), "\u30d0\u30d3\u30d6\u30d9\u30dc")
  # semi-voiced: ha row only, base + 2
  expect_equal(to_halfwidth("\uff8a\uff9f\uff8b\uff9f\uff8c\uff9f\uff8d\uff9f\uff8e\uff9f"), "\u30d1\u30d4\u30d7\u30da\u30dd")
  # the documented exception: U+30A6 voices to U+30F4, not U+30A7
  expect_equal(to_halfwidth("\uff73\uff9e"), "\u30f4")
  expect_equal(utf8ToInt(to_halfwidth("\uff73\uff9e")), 0x30F4L)
  # the wa row voices into U+30F7..U+30FA
  expect_equal(to_halfwidth("\uff9c\uff9e"), "\u30f7")
  expect_equal(utf8ToInt(to_halfwidth("\uff9c\uff9e")), 0x30F7L)
  expect_equal(utf8ToInt(to_halfwidth("\uff66\uff9e")), 0x30FAL)
})

test_that("composition matches Unicode NFC", {
  voiced <- c("\uff76\uff9e", "\uff77\uff9e", "\uff7b\uff9e", "\uff80\uff9e", "\uff8a\uff9e", "\uff73\uff9e", "\uff9c\uff9e", "\uff8a\uff9f")
  composed <- to_halfwidth(voiced)
  expect_equal(composed, stringi::stri_trans_nfc(composed))
  expect_equal(nchar(composed), rep(1L, length(voiced)))
})

test_that("already-decomposed katakana is composed too", {
  # base + COMBINING voiced mark (U+3099), as NFD leaves it
  decomposed <- paste0(FW_KA, "\u3099")
  expect_equal(nchar(decomposed), 2L)
  expect_equal(to_halfwidth(decomposed), FW_GA)
  # ...and the spacing mark U+309B is handled the same way
  expect_equal(to_halfwidth(paste0(FW_KA, VOICED_MARK)), FW_GA)
})

test_that("the bare voiced marks map to the spacing forms, not the combining ones", {
  # The documented, deliberate divergence from both NFKC and ICU: their
  # halfwidth-to-fullwidth mapping for U+FF9E and U+FF9F is the *combining*
  # mark (U+3099, U+309A), which attaches itself to whatever precedes it.
  # These map to the *spacing* marks instead. Pin all three, so the help page's
  # claim about what the other two do cannot quietly go stale.
  expect_equal(utf8ToInt(to_halfwidth("\uff9e", compose = FALSE)), 0x309BL)
  expect_equal(utf8ToInt(to_halfwidth("\uff9f", compose = FALSE)), 0x309CL)
  expect_equal(utf8ToInt(stringi::stri_trans_nfkc("\uff9e")), 0x3099L)
  expect_equal(
    utf8ToInt(stringi::stri_trans_general("\uff9e", "Halfwidth-Fullwidth")),
    0x3099L
  )
  # the hazard itself: ICU hangs the loose mark on the preceding letter
  expect_equal(
    utf8ToInt(stringi::stri_trans_general("a\uff9e", "Halfwidth-Fullwidth")),
    c(0xFF41L, 0x3099L)
  )
  expect_equal(utf8ToInt(to_halfwidth("a\uff9e", compose = FALSE)),
               c(0x61L, 0x309BL))
})

test_that("a voiced mark after something that cannot take one is left alone", {
  # "a" does not voice; the mark must survive rather than be swallowed
  out <- to_halfwidth(paste0("\uff71", "\uff9e"))
  expect_equal(nchar(out), 2L)
  expect_equal(utf8ToInt(out), c(0x30A2L, 0x309BL))
})

test_that("a trailing voiced mark with no base is left alone", {
  expect_equal(utf8ToInt(to_halfwidth("\uff9e")), 0x309BL)
})

test_that("normalisation is surgical where NFKC is not", {
  # NFKC rewrites all of these; tidycjk must not touch any of them
  untouched <- c(
    "\u00bd",      # VULGAR FRACTION ONE HALF
    "\u2460",      # CIRCLED DIGIT ONE
    "\u2168",      # ROMAN NUMERAL NINE
    "\ufb01",      # LATIN SMALL LIGATURE FI
    "\u00a0",      # NO-BREAK SPACE
    "\ufa10",      # a CJK compatibility ideograph
    "\u33a1"       # SQUARE M SQUARED
  )
  expect_equal(to_halfwidth(untouched), untouched)
  # ...and NFKC really would have changed every one of them
  expect_true(all(stringi::stri_trans_nfkc(untouched) != untouched))
})

test_that("the rest of the Halfwidth and Fullwidth Forms block is left alone", {
  # The mapped ranges are FF01-FF5E and FF61-FF9F, and ?to_halfwidth names what
  # sits either side of them so that nobody reads "narrows fullwidth forms" as
  # covering the whole block. None of these is ASCII on either side, which is
  # the reason they are out; NFKC maps every one of them, so the difference is
  # a choice and needs pinning rather than assuming.
  block <- c(
    "\uffe0", "\uffe1", "\uffe2",           # fullwidth cent, pound, not
    "\uffe3", "\uffe4", "\uffe5", "\uffe6", # macron, broken bar, yen, won
    "\uffa0", "\uffa1", "\uffdc",           # halfwidth Hangul jamo
    "\uffe8", "\uffee",                     # halfwidth symbol forms
    "\uff5f", "\uff60"                      # fullwidth white parentheses
  )
  expect_equal(to_halfwidth(block), block)
  expect_equal(to_fullwidth(block), block)
  expect_true(all(stringi::stri_trans_nfkc(block) != block))
  # the practical consequence the help page states: the digits of a price
  # narrow and the currency sign does not
  expect_equal(to_halfwidth(paste0("\uffe5", FW_DIGITS)), "\uffe5123")
  # and the two mapped ranges really do stop where the table says, so these are
  # the neighbours of a boundary rather than an arbitrary sample
  expect_equal(to_halfwidth("\uff5e"), "~")        # last of FF01-FF5E
  expect_equal(to_halfwidth("\uff61"), "\u3002")   # first of FF61-FF9F
  expect_equal(to_halfwidth("\uff9f"), "\u309c")   # last of FF61-FF9F
})

test_that("CJK ideographs and hangul are never rewritten", {
  expect_equal(to_halfwidth(ZH_SENTENCE), ZH_SENTENCE)
  expect_equal(to_fullwidth(ZH_SENTENCE), ZH_SENTENCE)
  expect_equal(to_halfwidth(KO), KO)
})

test_that("mixed text has only its width-variant characters changed", {
  expect_equal(
    to_halfwidth(paste0(ZH, FW_DIGITS, "abc")),
    paste0(ZH, "123abc")
  )
})

test_that("normalisation handles NA, empty strings and zero-length input", {
  expect_true(is.na(to_halfwidth(NA_character_)))
  expect_true(is.na(to_fullwidth(NA_character_)))
  expect_equal(to_halfwidth(""), "")
  expect_equal(to_fullwidth(""), "")
  expect_equal(to_halfwidth(character(0)), character(0))
  expect_equal(to_fullwidth(character(0)), character(0))
  expect_type(to_halfwidth(character(0)), "character")
  expect_equal(to_halfwidth(c(FW_DIGITS, NA, "")), c("123", NA, ""))
})

test_that("normalisation is vectorised", {
  expect_equal(
    to_halfwidth(c(FW_DIGITS, HW_KA_VOICED, "plain")),
    c("123", FW_GA, "plain")
  )
})

test_that("the composition fast path changes nothing it skips", {
  # The composition scan is a per-character R loop, so it is skipped outright
  # when the string holds no voiced or semi-voiced mark. That guard must be
  # invisible: a string with no mark in it has to come back exactly as the
  # loop would have left it, and one with a mark still has to compose wherever
  # the mark sits.
  no_marks <- c("abc XYZ 123", FW_DIGITS, ZH_SENTENCE, JA_KATAKANA, KO, "",
                "\uff71\uff72\uff73", EXT_B)
  expect_equal(to_halfwidth(no_marks, compose = FALSE),
               to_halfwidth(no_marks, compose = TRUE))
  # to_fullwidth() has no compose argument -- it always composes -- so the
  # guard is pinned against a literal instead: width changed, nothing else
  expect_equal(
    to_fullwidth("abc XYZ 123"),
    "\uff41\uff42\uff43\u3000\uff38\uff39\uff3a\u3000\uff11\uff12\uff13"
  )
  expect_equal(to_halfwidth(to_fullwidth(no_marks)), to_halfwidth(no_marks))
  # a mark at the start, in the middle and at the end all still compose
  expect_equal(to_halfwidth(paste0("a", HW_KA_VOICED)), paste0("a", FW_GA))
  expect_equal(to_halfwidth(paste0(HW_KA_VOICED, "a")), paste0(FW_GA, "a"))
  expect_equal(to_halfwidth(paste0("a", HW_KA_VOICED, "b")),
               paste0("a", FW_GA, "b"))
  # a two-code-point string that is only marks is still left alone
  expect_equal(utf8ToInt(to_halfwidth("\uff9e\uff9f")), c(0x309BL, 0x309CL))
})

test_that("compose is validated", {
  expect_error(to_halfwidth("a", compose = NA), "TRUE or FALSE")
  expect_error(to_halfwidth("a", compose = "yes"), "TRUE or FALSE")
})
