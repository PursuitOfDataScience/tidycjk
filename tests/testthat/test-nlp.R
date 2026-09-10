# cjk_sentences() and cjk_ngrams(): the two preprocessing steps that generic
# tooling gets wrong on CJK. Strings are written as \u escapes, as everywhere
# else under tests/, so the file stays ASCII and cannot become mojibake when
# read under a non-UTF-8 locale.

ZH  <- "\u6211\u4eca\u5929\u5f88\u958b\u5fc3\u3002\u4f60\u5462\uff1f"  # two sentences
NG  <- "\u4e2d\u6587\u5f88\u597d"                                       # 4 chars

test_that("cjk_sentences splits on the CJK terminators", {
  out <- cjk_sentences(ZH)[[1]]
  expect_length(out, 2L)
  expect_true(endsWith(out[[1]], "\u3002"))
  expect_true(endsWith(out[[2]], "\uff1f"))
})

test_that("cjk_sentences handles ASCII terminators and mixed text", {
  expect_length(cjk_sentences("One. Two. Three.")[[1]], 3L)
  expect_length(cjk_sentences(paste0("First. ", ZH))[[1]], 3L)
})

test_that("cjk_sentences keeps the NA / empty distinction", {
  out <- cjk_sentences(c(ZH, NA, ""))
  expect_length(out, 3L)
  expect_identical(out[[2]], NA_character_)
  expect_identical(out[[3]], character(0))
  expect_identical(cjk_sentences(character(0)), list())
})

test_that("cjk_sentences is lossless -- the pieces rebuild the input", {
  # It divides text rather than editing it, so this must hold exactly.
  for (s in c(ZH, "One. Two.", "no terminator")) {
    expect_equal(paste(cjk_sentences(s)[[1]], collapse = ""), s)
  }
})

test_that("cjk_ngrams returns every window, in order, with repeats", {
  expect_equal(cjk_ngrams(NG)[[1]],
               c("\u4e2d\u6587", "\u6587\u5f88", "\u5f88\u597d"))
  expect_equal(cjk_ngrams(NG, n = 3)[[1]],
               c("\u4e2d\u6587\u5f88", "\u6587\u5f88\u597d"))
  expect_equal(cjk_ngrams(NG, n = 4)[[1]], NG)
  # repeats are kept, not deduplicated
  expect_length(cjk_ngrams("\u4e2d\u4e2d\u4e2d")[[1]], 2L)
})

test_that("cjk_ngrams forms no window across whitespace", {
  # "<zh><zh> <zh><zh>": 4 non-space chars, but only 2 bigrams, not 3
  out <- cjk_ngrams("\u4e2d\u6587 \u4f60\u597d")[[1]]
  expect_equal(out, c("\u4e2d\u6587", "\u4f60\u597d"))
  # the ideographic space counts as whitespace here too
  expect_equal(cjk_ngrams("\u4e2d\u3000\u6587")[[1]], character(0))
})

test_that("cjk_ngrams returns character(0) for strings shorter than n", {
  expect_identical(cjk_ngrams("\u4e2d")[[1]], character(0))
  expect_identical(cjk_ngrams("", n = 2)[[1]], character(0))
  expect_identical(cjk_ngrams("\u4e2d\u6587", n = 5)[[1]], character(0))
})

test_that("cjk_ngrams keeps the NA / empty distinction and validates n", {
  out <- cjk_ngrams(c(NG, NA, ""))
  expect_identical(out[[2]], NA_character_)
  expect_identical(out[[3]], character(0))
  expect_identical(cjk_ngrams(character(0)), list())
  for (bad in list(0, -1, 2.5, NA, Inf, "2", c(2, 3))) {
    expect_error(cjk_ngrams(NG, n = bad), "`n`")
  }
})

test_that("cjk_ngrams counts code points, so a supplementary char is one", {
  # U+20000 is one character and must not be split into surrogates
  out <- cjk_ngrams(paste0("\U00020000", "\u4e2d"))[[1]]
  expect_length(out, 1L)
  expect_equal(nchar(out), 2L)
})

test_that("cjk_ngrams rejects an n past the integer range", {
  # Otherwise as.integer() gives NA and a bare coercion warning, and the
  # comparison against it fails with a missing-value error further down.
  expect_error(cjk_ngrams("abc", n = 1e10), "integer range")
  expect_error(cjk_ngrams("abc", n = 2^31), "integer range")
})

test_that("cjk_sentences rejects a locale ICU has no break data for", {
  # stringi only warns and silently falls back to the root locale.
  expect_error(cjk_sentences("a. b.", locale = "not-a-locale"), "break data")
  expect_error(cjk_sentences("a. b.", locale = "qqq"), "break data")
  # a known language is fine, and so is NULL
  expect_silent(cjk_sentences("a. b.", locale = "ja"))
  expect_silent(cjk_sentences("a. b."))
})

test_that("locale does not change CJK sentence boundaries", {
  # ?cjk_sentences says so, so it is pinned: if a future ICU tailors these
  # per locale, the documentation is wrong and this should fail.
  s <- "\u6211\u4eca\u5929\u5f88\u958b\u5fc3\u3002\u4f60\u5462\uff1f\u5929\u6c23\u5f88\u597d\uff01"
  base <- cjk_sentences(s)[[1]]
  for (l in c("zh", "ja", "ko", "en")) {
    expect_equal(cjk_sentences(s, locale = l)[[1]], base)
  }
})

test_that("cjk_sentences keeps a leading byte-order mark", {
  # stri_split_boundaries() drops it; the help page promises the pieces
  # concatenate back to the input exactly, so it has to be restored.
  y <- "\ufeff\u4e2d\u6587\u3002"
  expect_equal(paste(cjk_sentences(y)[[1]], collapse = ""), y)
})
