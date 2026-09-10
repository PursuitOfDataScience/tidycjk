# Transliteration: romanisation, Han conversion, kana, jamo.
#
# These wrap ICU, so the tests pin the contract this package promises -- NA
# in/NA out, zero length, non-target scripts untouched -- rather than
# re-testing ICU's tables, which would just restate whatever ICU version is
# installed. The one exception is the round trips, which are exact by
# construction and so are safe to assert on.

test_that("cjk_romanize romanises the three scripts", {
  # The readings are ICU's tables, not the Unicode standard, so a different
  # ICU on a check farm may spell them differently -- the same reasoning that
  # keeps ambiguous widths out of test-width.R. Assert that each script is
  # romanised at all: Latin out, none of the original script left.
  for (s in c("\u4e2d\u6587", "\u3053\u3093\u306b\u3061\u306f", "\uc548\ub155")) {
    out <- cjk_romanize(s)
    expect_true(nzchar(out))
    expect_false(identical(out, s))
    expect_false(stringi::stri_detect_charclass(out, "\\p{Han}"))
    expect_false(stringi::stri_detect_charclass(out, "\\p{Hiragana}"))
    expect_false(stringi::stri_detect_charclass(out, "\\p{Hangul}"))
  }
  # pinyin keeps its tone marks by default, so Chinese is not plain ASCII
  expect_true(stringi::stri_detect_charclass(cjk_romanize("\u4e2d\u6587"),
                                             "[^\\p{ASCII}]"))
})

test_that("cjk_romanize(ascii =) strips tone marks", {
  # The property rather than the syllables: ascii = TRUE is pure ASCII, and
  # differs from the default, which keeps the diacritics.
  out <- cjk_romanize("\u4e2d\u6587", ascii = TRUE)
  expect_false(stringi::stri_detect_charclass(out, "[^\\p{ASCII}]"))
  expect_false(identical(cjk_romanize("\u4e2d\u6587"), out))
})

test_that("cjk_romanize leaves Latin alone and propagates NA", {
  expect_equal(cjk_romanize("plain ascii"), "plain ascii")
  expect_equal(cjk_romanize(NA), NA_character_)
  expect_equal(cjk_romanize(c("\u4e2d", NA)), c(cjk_romanize("\u4e2d"), NA))
  expect_equal(cjk_romanize(character(0)), character(0))
})

test_that("cjk_romanize validates ascii", {
  expect_error(cjk_romanize("\u4e2d", ascii = NA), "`ascii`")
  expect_error(cjk_romanize("\u4e2d", ascii = 1), "`ascii`")
  expect_error(cjk_romanize("\u4e2d", ascii = c(TRUE, TRUE)), "`ascii`")
})

test_that("Han conversion round-trips on characters with one mapping", {
  expect_equal(cjk_simplify("\u6f22\u5b57"), "\u6c49\u5b57")
  expect_equal(cjk_traditionalize("\u6c49\u5b57"), "\u6f22\u5b57")
  expect_equal(cjk_simplify(cjk_traditionalize("\u6c49\u5b57")), "\u6c49\u5b57")
})

test_that("Han conversion leaves non-Han alone and propagates NA", {
  expect_equal(cjk_simplify("abc \u3042 \uc548"), "abc \u3042 \uc548")
  expect_equal(cjk_simplify(NA), NA_character_)
  expect_equal(cjk_traditionalize(NA), NA_character_)
  expect_equal(cjk_simplify(character(0)), character(0))
  expect_equal(cjk_traditionalize(character(0)), character(0))
})

test_that("Han conversion resolves one-to-many characters from context", {
  # ?cjk_simplify claims context-sensitivity. What holds on any ICU table is
  # that the *same* simplified character converts differently in two
  # different words -- which a per-character mapping cannot do. Which
  # traditional forms it picks is ICU's choice and is not asserted.
  hs <- cjk_traditionalize(c("\u5934\u53d1", "\u53d1\u9001"))   # hair, send
  expect_false(identical(substr(hs[1], 2L, 2L), substr(hs[2], 1L, 1L)))
  ct <- cjk_traditionalize(c("\u5e72\u51c0", "\u6811\u5e72"))   # clean, trunk
  expect_false(identical(substr(ct[1], 1L, 1L), substr(ct[2], 2L, 2L)))
})

test_that("Han conversion does not substitute regional vocabulary", {
  # The documented limitation: it converts characters and does not reach the
  # Taiwanese *word*. Asserted as "converted, but not the Taiwanese term",
  # which holds whatever ICU's table says.
  sw <- cjk_traditionalize("\u8f6f\u4ef6")
  expect_false(identical(sw, "\u8edf\u9ad4"))   # not the Taiwan term
  expect_false(identical(sw, "\u8f6f\u4ef6"))   # but it did convert
  ms <- cjk_traditionalize("\u9f20\u6807")
  expect_false(identical(ms, "\u6ed1\u9f20"))
})

test_that("kana conversion round-trips and leaves kanji alone", {
  expect_equal(to_hiragana("\u30ab\u30bf\u30ab\u30ca"), "\u304b\u305f\u304b\u306a")
  expect_equal(to_katakana("\u3072\u3089\u304c\u306a"), "\u30d2\u30e9\u30ac\u30ca")
  expect_equal(to_hiragana(to_katakana("\u3072\u3089\u304c\u306a")),
               "\u3072\u3089\u304c\u306a")
  # kanji is not kana and must survive untouched
  expect_equal(to_katakana("\u65e5\u672c\u8a9e"), "\u65e5\u672c\u8a9e")
})

test_that("kana conversion propagates NA and zero length", {
  expect_equal(to_hiragana(NA), NA_character_)
  expect_equal(to_katakana(NA), NA_character_)
  expect_equal(to_hiragana(character(0)), character(0))
  expect_equal(to_katakana(character(0)), character(0))
})

test_that("cjk_jamo decomposes a syllable into its jamo", {
  # U+D55C HANGUL SYLLABLE HAN -> U+1112 U+1161 U+11AB
  expect_equal(cjk_jamo("\ud55c")[[1]],
               c("\u1112", "\u1161", "\u11ab"))
  expect_length(cjk_jamo("\ud55c\uae00")[[1]], 6L)
})

test_that("cjk_jamo round-trips through cjk_compose_jamo", {
  x <- c("\ud55c\uae00", "\uc548\ub155\ud558\uc138\uc694")
  back <- vapply(cjk_jamo(x), paste, character(1), collapse = "")
  expect_equal(cjk_compose_jamo(back), x)
})

test_that("cjk_jamo keeps the NA / empty distinction", {
  out <- cjk_jamo(c("\ud55c", NA, ""))
  expect_equal(out[[1]], c("\u1112", "\u1161", "\u11ab"))
  expect_identical(out[[2]], NA_character_)
  expect_identical(out[[3]], character(0))
  expect_identical(cjk_jamo(character(0)), list())
  expect_equal(cjk_compose_jamo(character(0)), character(0))
})

test_that("cjk_jamo passes non-Hangul through", {
  expect_equal(cjk_jamo("ab")[[1]], c("a", "b"))
  # Han has no canonical decomposition, so it stays one element
  expect_equal(cjk_jamo("\u4e2d")[[1]], "\u4e2d")
})

test_that("kana conversion handles halfwidth, composing voiced marks", {
  # Documented in ?to_hiragana, so pinned here: halfwidth input needs no
  # width conversion first, and the two-code-point voiced form composes.
  expect_equal(to_hiragana("\uff76\uff80\uff76\uff85"), "\u304b\u305f\u304b\u306a")
  expect_equal(to_katakana("\uff76\uff9e"), "\u30ac")
  expect_equal(nchar(to_katakana("\uff76\uff9e")), 1L)
})

test_that("cjk_romanize reads Han as Chinese even in Japanese text", {
  # The documented failure mode: the Japanese reading of U+65E5 U+672C U+8A9E
  # is "nihongo". Whatever pinyin ICU produces, it must not be that; if it
  # ever is, ?cjk_romanize and the vignette are wrong.
  got <- gsub("[^a-z]", "", cjk_romanize("\u65e5\u672c\u8a9e", ascii = TRUE))
  expect_false(identical(got, "nihongo"))
  expect_true(nzchar(got))
})

test_that(".cjk_trans reports a transliterator ICU does not provide", {
  # Unreachable through the exported verbs, whose ids are all literals, but
  # not dead: stringi built against a system ICU with reduced data can be
  # missing one. Tested directly so the message is known to work.
  expect_error(.cjk_trans("x", "No-Such-Transliterator"),
               "does not provide the transliterator")
  # The re-raise branch beside it is not reachable from any input:
  # stri_trans_general() substitutes replacement characters for invalid
  # UTF-8 rather than erroring, unlike stri_width(). It stays as a guard.
})

test_that("kana conversion round-trips only within one syllabary", {
  # Documented in ?to_hiragana: it is a normalisation, not a reversible map.
  expect_equal(to_katakana(to_hiragana("\u30ab\u30bf\u30ab\u30ca")), "\u30ab\u30bf\u30ab\u30ca")
  expect_equal(to_hiragana(to_katakana("\u3072\u3089\u304c\u306a")), "\u3072\u3089\u304c\u306a")
  # mixed input cannot survive the trip, because the distinction is erased
  mixed <- "\u30a2\u304b"
  expect_equal(to_hiragana(mixed), "\u3042\u304b")
  expect_false(identical(to_katakana(to_hiragana(mixed)), mixed))
})

test_that("the jamo round trip returns NFC, not necessarily the input", {
  # Documented in ?cjk_jamo. Already-NFC input is returned unchanged...
  for (s in c("\ud55c\uae00", "\u4e2d\u6587", "abc")) {
    expect_equal(cjk_compose_jamo(paste(cjk_jamo(s)[[1]], collapse = "")), s)
  }
  # ... and input that is not gets normalised, which is what NFC is for
  decomposed <- "e\u0301"
  expect_false(identical(stringi::stri_trans_nfc(decomposed), decomposed))
  expect_equal(
    cjk_compose_jamo(paste(cjk_jamo(decomposed)[[1]], collapse = "")),
    stringi::stri_trans_nfc(decomposed)
  )
})
