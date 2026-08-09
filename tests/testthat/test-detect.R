# Detection, script classification, language inference and ratio.

test_that("has_cjk() detects CJK and ignores everything else", {
  expect_true(has_cjk(ZH))
  expect_true(has_cjk(JA_KANA))
  expect_true(has_cjk(KO))
  expect_true(has_cjk(EXT_B))
  expect_false(has_cjk("plain ASCII"))
  expect_false(has_cjk("caf\u00e9 na\u00efve"))
})

test_that("has_cjk() finds CJK embedded in Latin text", {
  expect_true(has_cjk(paste0("hello ", ZH, " world")))
  expect_equal(
    has_cjk(c(ZH, "nope", KO)),
    c(TRUE, FALSE, TRUE)
  )
})

test_that("has_cjk() counts punctuation and fullwidth forms, as documented", {
  expect_true(has_cjk(IDEOGRAPHIC_STOP))
  expect_true(has_cjk(IDEOGRAPHIC_SPACE))
  expect_true(has_cjk(FW_DIGITS))
})

test_that("ideographs from the newer extensions count as CJK", {
  # regression: the block table stopped at Extension F, so an ideograph from
  # Extension G, H or I -- or from the compatibility supplement -- came back as
  # not CJK at all, silently, in every verb in the package
  modern <- c(EXT_I, EXT_G, EXT_H, COMPAT_SUP)
  expect_equal(has_cjk(modern), rep(TRUE, 4L))
  expect_equal(cjk_script(modern), rep("han", 4L))
  expect_equal(cjk_ratio(modern), rep(1, 4L))
  expect_equal(cjk_ratio(paste0("a", modern)), rep(0.5, 4L))
  # ...and they still do not settle the language, being Han
  expect_true(all(is.na(cjk_detect_language(modern))))
  expect_equal(
    cjk_char_counts(data.frame(text = modern), text)$block,
    c("CJK Unified Ideographs Extension I",
      "CJK Unified Ideographs Extension G",
      "CJK Unified Ideographs Extension H",
      "CJK Compatibility Ideographs Supplement")
  )
})

test_that("has_cjk() handles NA, empty strings and zero-length input", {
  expect_true(is.na(has_cjk(NA_character_)))
  expect_equal(has_cjk(c(ZH, NA, "x")), c(TRUE, NA, FALSE))
  expect_false(has_cjk(""))
  expect_equal(has_cjk(character(0)), logical(0))
  expect_type(has_cjk(character(0)), "logical")
})

test_that("cjk_script() names the dominant script", {
  expect_equal(cjk_script(ZH), "han")
  expect_equal(cjk_script(ZH_SENTENCE), "han")
  expect_equal(cjk_script(JA_KANA), "hiragana")
  expect_equal(cjk_script(JA_KATAKANA), "katakana")
  expect_equal(cjk_script(KO), "hangul")
  expect_equal(cjk_script(KO_JAMO), "hangul")
  expect_equal(cjk_script(BOPOMOFO), "bopomofo")
  expect_equal(cjk_script(KANBUN), "kanbun")
})

test_that("cjk_script() counts only CJK characters, not the Latin around them", {
  # two ideographs beat nothing; the English is not a script and does not vote
  expect_equal(cjk_script(paste0("a very long English sentence ", ZH)), "han")
})

test_that("cjk_script() picks the majority in a mixed-script string", {
  # JA_MIXED is 2 kanji + 4 kana, so kana wins
  expect_equal(cjk_script(JA_MIXED), "hiragana")
  # ...and adding enough kanji flips it
  expect_equal(cjk_script(paste0(JA_MIXED, ZH_SENTENCE)), "han")
})

test_that("cjk_script() breaks ties by first appearance, not by locale", {
  # one ideograph and one hiragana: whichever came first wins
  han_first <- paste0("\u4e2d", "\u3042")
  kana_first <- paste0("\u3042", "\u4e2d")
  expect_equal(cjk_script(han_first), "han")
  expect_equal(cjk_script(kana_first), "hiragana")
})

test_that("cjk_script() returns NA when there is no CJK", {
  expect_true(is.na(cjk_script("ascii only")))
  expect_true(is.na(cjk_script("")))
  expect_true(is.na(cjk_script(NA_character_)))
  expect_equal(cjk_script(character(0)), character(0))
  expect_type(cjk_script(character(0)), "character")
})

test_that("cjk_detect_language() resolves what the scripts settle", {
  expect_equal(cjk_detect_language(JA_KANA), "japanese")
  expect_equal(cjk_detect_language(JA_KATAKANA), "japanese")
  expect_equal(cjk_detect_language(JA_MIXED), "japanese")
  expect_equal(cjk_detect_language(KO), "korean")
  expect_equal(cjk_detect_language(KO_JAMO), "korean")
  expect_equal(cjk_detect_language(BOPOMOFO), "chinese")
  expect_equal(cjk_detect_language(KANBUN), "japanese")
})

test_that("cjk_detect_language() returns NA for kana-free Japanese", {
  # This is the whole point: JA_KANJI_ONLY is Japanese, ZH is Chinese, and
  # nothing in the script tells them apart. Guessing would be wrong half the
  # time and the caller could not tell.
  expect_true(is.na(cjk_detect_language(JA_KANJI_ONLY)))
  expect_true(is.na(cjk_detect_language(ZH)))
  expect_true(is.na(cjk_detect_language(ZH_SENTENCE)))
})

test_that("the Han-only guess is available but has to be asked for", {
  expect_equal(cjk_detect_language(ZH, han_only = "chinese"), "chinese")
  expect_equal(
    cjk_detect_language(JA_KANJI_ONLY, han_only = "chinese"),
    "chinese"
  )
  # kana still wins over the opt-in default
  expect_equal(cjk_detect_language(JA_KANA, han_only = "chinese"), "japanese")
  expect_error(cjk_detect_language(ZH, han_only = c("a", "b")), "single string")
})

test_that("kana beats Han when both are present", {
  expect_equal(cjk_detect_language(paste0(ZH_SENTENCE, JA_KANA)), "japanese")
})

test_that("hangul beats Han when both are present", {
  # Korean written with hanja: the hangul settles it
  expect_equal(cjk_detect_language(paste0(ZH, KO)), "korean")
})

test_that("cjk_detect_language() returns NA when there is no CJK at all", {
  expect_true(is.na(cjk_detect_language("ascii")))
  expect_true(is.na(cjk_detect_language("")))
  expect_true(is.na(cjk_detect_language(NA_character_)))
  expect_equal(cjk_detect_language(character(0)), character(0))
})

test_that("punctuation and fullwidth forms do not decide a language", {
  expect_true(is.na(cjk_detect_language(IDEOGRAPHIC_STOP)))
  expect_true(is.na(cjk_detect_language(FW_DIGITS)))
})

test_that("cjk_ratio() measures the CJK share of the characters", {
  expect_equal(cjk_ratio(ZH), 1)
  expect_equal(cjk_ratio("ascii"), 0)
  # 2 CJK characters out of 7 ("half " is 5)
  expect_equal(cjk_ratio(paste0("half ", ZH)), 2 / 7)
})

test_that("cjk_ratio() counts supplementary characters once", {
  expect_equal(cjk_ratio(EXT_B), 1)
  expect_equal(cjk_ratio(paste0("a", EXT_B)), 0.5)
})

test_that("cjk_ratio() handles NA, empty strings and zero-length input", {
  expect_true(is.na(cjk_ratio(NA_character_)))
  expect_true(is.na(cjk_ratio("")))
  expect_equal(cjk_ratio(character(0)), numeric(0))
  expect_type(cjk_ratio(character(0)), "double")
  expect_equal(cjk_ratio(c(ZH, "", NA, "no")), c(1, NA, NA, 0))
})

test_that("every ratio is a proportion", {
  x <- c(ZH, ZH_SENTENCE, JA_MIXED, KO, "ascii", paste0("mix ", ZH))
  r <- cjk_ratio(x)
  expect_true(all(r >= 0 & r <= 1))
})
