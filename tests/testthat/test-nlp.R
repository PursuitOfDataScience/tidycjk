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

test_that("a string of nothing but byte-order marks comes back unchanged", {
  # The split has nothing to return once the marks are stripped, so the
  # restored marks are the whole result. Without this the branch that
  # handles it is never executed.
  expect_equal(cjk_sentences("\ufeff")[[1]], "\ufeff")
  expect_equal(cjk_sentences("\ufeff\ufeff")[[1]], "\ufeff\ufeff")
  expect_equal(cjk_sentences("\ufeff\ufeff\ufeff")[[1]], "\ufeff\ufeff\ufeff")
  # and a mark followed by content still leads the first sentence
  expect_equal(cjk_sentences("\ufeff ")[[1]], "\ufeff ")
  expect_length(cjk_sentences(c("\ufeff", "\u4e2d\u6587\u3002")), 2L)
})


# --------------------------------------------------------------------------
# cjk_strip_punct()

test_that("cjk_strip_punct removes CJK punctuation", {
  # the ideographic full stop and comma, the fullwidth brackets, the
  # fullwidth exclamation and question marks, the corner brackets
  expect_equal(cjk_strip_punct("\u4e2d\u3002\u6587", ""), "\u4e2d\u6587")
  expect_equal(cjk_strip_punct("\u4e2d\u3001\u6587", ""), "\u4e2d\u6587")
  expect_equal(cjk_strip_punct("\uff08\u4e2d\uff09", ""), "\u4e2d")
  expect_equal(cjk_strip_punct("\u300c\u4e2d\u300d", ""), "\u4e2d")
  expect_equal(cjk_strip_punct("\u4e2d\uff01\uff1f", ""), "\u4e2d")
  expect_equal(cjk_strip_punct("\u30a2\u30fb\u30a4", ""), "\u30a2\u30a4")
  # ASCII punctuation too, so mixed text needs one pass
  expect_equal(cjk_strip_punct("a.b,c!\u4e2d\u3002", ""), "abc\u4e2d")
})

test_that("cjk_strip_punct keeps the prolonged sound mark", {
  # U+30FC is Lm, a modifier letter, not punctuation. Removing it would
  # gut every Japanese loanword, which is why this tests a category and
  # not a list of dash-like characters.
  expect_equal(cjk_strip_punct("\u30b3\u30fc\u30d2\u30fc", ""),
               "\u30b3\u30fc\u30d2\u30fc")
  expect_equal(cjk_strip_punct("\u30e9\u30fc\u30e1\u30f3\u3001", ""),
               "\u30e9\u30fc\u30e1\u30f3")
  expect_false(stringi::stri_detect_charclass("\u30fc", "\\p{P}"))
})

test_that("cjk_strip_punct leaves whitespace and letters alone", {
  # U+3000 is Zs, not P -- and the verbs downstream ignore whitespace
  expect_equal(cjk_strip_punct("\u4e2d\u3000\u6587", ""), "\u4e2d\u3000\u6587")
  expect_equal(cjk_strip_punct("\u4e2d \u6587", ""), "\u4e2d \u6587")
  expect_equal(cjk_strip_punct("\u4e2d\u6587", ""), "\u4e2d\u6587")
  expect_equal(cjk_strip_punct("abc123", ""), "abc123")
})

test_that("symbols = TRUE adds General_Category S and FALSE does not", {
  for (s in c("\uff5e", "\uffe5", "\u00a5", "\uff0b")) {
    expect_equal(cjk_strip_punct(s, ""), s)          # kept by default
    expect_equal(cjk_strip_punct(s, "", symbols = TRUE), "")
  }
  # and punctuation still goes in both modes
  expect_equal(cjk_strip_punct("\u4e2d\u3002", "", symbols = TRUE), "\u4e2d")
})

test_that("the default replacement is a space, and it matters", {
  expect_equal(cjk_strip_punct("\u597d\u3002\u5929"), "\u597d \u5929")
  # the reason for the default: a deletion invents a bigram spanning the
  # sentence boundary, a space does not
  expect_equal(cjk_ngrams(cjk_strip_punct("\u597d\u3002\u5929"))[[1]],
               character(0))
  expect_equal(cjk_ngrams(cjk_strip_punct("\u597d\u3002\u5929", ""))[[1]],
               "\u597d\u5929")
  # an arbitrary replacement is allowed
  expect_equal(cjk_strip_punct("\u4e2d\u3002", "_"), "\u4e2d_")
})

test_that("cjk_strip_punct is the same in every locale", {
  # This is the whole point: gsub("[[:punct:]]", ...) is resolved by the C
  # library and answers differently under LC_ALL=C, and perl = TRUE removes
  # nothing from CJK in any locale. ICU's category is fixed.
  x <- "\u4ed6\u8aaa\uff08\u4eca\u5929\uff09\u3002"
  want <- "\u4ed6\u8aaa\u4eca\u5929"
  old <- Sys.getlocale("LC_CTYPE")
  on.exit(suppressWarnings(Sys.setlocale("LC_CTYPE", old)), add = TRUE)
  seen <- character(0)
  for (loc in c("C", "en_US.UTF-8", "zh_CN.utf8")) {
    if (!nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", loc)))) next
    seen <- c(seen, loc)
    expect_equal(cjk_strip_punct(x, ""), want, info = loc)
  }
  suppressWarnings(Sys.setlocale("LC_CTYPE", old))
  expect_true("C" %in% seen)
})

test_that("cjk_strip_punct keeps a leading byte-order mark", {
  # stri_replace_all_charclass() drops one, as several other stringi entry
  # points do; the verb counts it off and puts it back.
  expect_equal(cjk_strip_punct("\ufeff\u4e2d\u3002", ""), "\ufeff\u4e2d")
  expect_equal(cjk_strip_punct("\ufeff\ufeff\u4e2d\u3002", ""),
               "\ufeff\ufeff\u4e2d")
  expect_equal(cjk_strip_punct("\ufeff"), "\ufeff")
  # an interior one is not punctuation and is untouched
  expect_equal(cjk_strip_punct("\u4e2d\ufeff\u6587", ""), "\u4e2d\ufeff\u6587")
})

test_that("cjk_strip_punct keeps the vector contract", {
  expect_equal(cjk_strip_punct(character(0)), character(0))
  expect_equal(cjk_strip_punct(NA_character_), NA_character_)
  expect_equal(cjk_strip_punct(c("\u4e2d\u3002", NA, "")),
               c("\u4e2d ", NA, ""))
  expect_length(cjk_strip_punct(c("a.", NA, "b,")), 3L)
  expect_equal(cjk_strip_punct(factor("\u4e2d\u3002"), ""), "\u4e2d")
  expect_equal(cjk_strip_punct(1.5, ""), "15")
})

test_that("cjk_strip_punct rejects a bad replacement or flag", {
  expect_error(cjk_strip_punct("a", NA_character_), "single string")
  expect_error(cjk_strip_punct("a", c(" ", "")), "single string")
  expect_error(cjk_strip_punct("a", 1), "single string")
  expect_error(cjk_strip_punct("a", symbols = NA), "TRUE or FALSE")
  expect_error(cjk_strip_punct("a", symbols = 1), "TRUE or FALSE")
})
