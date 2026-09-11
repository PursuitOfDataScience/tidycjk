# Differential and property tests for the verbs added in 0.2.0.
#
# The package already holds cjk_truncate() and the character engine to this
# standard -- checked against a brute-force reference over random strings
# rather than over hand-picked examples. These are the same for the new
# verbs. The corpus deliberately mixes scripts with the things that have
# broken this package before: the ideographic space U+3000, embedded
# newlines, and supplementary-plane ideographs.
#
# N is kept modest so the suite stays quick; the same harness was run over
# 4,000 strings during development with no mismatches.

make_corpus <- function(n, seed = 20260909) {
  set.seed(seed)
  pool <- c(
    intToUtf8(sample(0x4E00:0x9FA0, 40), multiple = TRUE),
    intToUtf8(sample(0x3041:0x3096, 15), multiple = TRUE),
    intToUtf8(sample(0x30A1:0x30F6, 15), multiple = TRUE),
    intToUtf8(sample(0xAC00:0xD7A3, 15), multiple = TRUE),
    letters[1:8], as.character(0:9),
    " ", " ", "\u3000", "\n", "\u3002", "\uff01", ".", ",", "(", ")",
    "\uFEFF",                       # byte-order mark: stringi drops a leading
                                    # one, which broke losslessness once
    intToUtf8(sample(0x20000:0x2A6D0, 4), multiple = TRUE)
  )
  vapply(seq_len(n), function(i)
    paste(sample(pool, sample(0:20, 1), replace = TRUE), collapse = ""),
    character(1))
}

X <- make_corpus(300)

test_that("the corpus actually exercises what the properties below assume", {
  # Every test in this file asserts a property over X. Each of them would
  # pass on a corpus of empty strings, so the corpus itself has to be
  # checked -- otherwise a change to the pool, or a generator that quietly
  # stopped working, would leave the whole file green and testing nothing.
  # Lower bounds rather than exact counts, so tuning the pool does not
  # break this spuriously while degeneracy still would.
  expect_length(X, 300L)
  expect_gt(sum(nzchar(X)), 250L)              # not mostly empty
  expect_gt(sum(nchar(X) >= 2L), 200L)         # long enough for bigrams
  expect_gt(sum(has_cjk(X), na.rm = TRUE), 200L)
  expect_gt(sum(lengths(cjk_ngrams(X)) > 0L), 200L)
  expect_gt(sum(lengths(cjk_sentences(X)) > 1L), 20L)   # some split
  # the byte-order mark is in the pool deliberately: adding it is what
  # exposed four verbs silently deleting one
  expect_gt(sum(grepl("\uFEFF", X, fixed = TRUE)), 5L)
  # and supplementary-plane ideographs, which are two code units apiece
  expect_true(any(vapply(X, function(s) {
    nzchar(s) && any(utf8ToInt(s) > 0xFFFF)
  }, logical(1))))
})

test_that("cjk_ngrams agrees with a brute-force reference", {
  ref <- function(s, n) {
    # utf8ToInt(), not stri_sub(): stringi's own substring drops a leading
    # U+FEFF, so a reference built on it disagreed with the package for the
    # wrong reason -- the reference was wrong, not cjk_ngrams().
    ch <- if (nchar(s)) intToUtf8(utf8ToInt(s), multiple = TRUE) else character(0)
    if (length(ch) < n) return(character(0))
    out <- character(0)
    for (i in seq_len(length(ch) - n + 1L)) {
      w <- ch[i:(i + n - 1L)]
      if (!any(stringi::stri_detect_charclass(w, "\\p{WHITE_SPACE}"))) {
        out <- c(out, paste(w, collapse = ""))
      }
    }
    out
  }
  for (n in 1:3) {
    got <- cjk_ngrams(X, n = n)
    expect_equal(got, lapply(X, ref, n = n))
  }
})

test_that("cjk_wrap preserves content, ignoring whitespace", {
  # U+FEFF is excluded alongside whitespace, and ?cjk_wrap says why: a
  # re-flow can leave one at the start of a segment, where stringi reads it
  # as a byte-order mark and drops it. A *leading* one is preserved, and
  # test-wrap.R pins that separately.
  #
  # The removal is base gsub(), not stri_replace_all_fixed(): stringi strips
  # a leading byte-order mark from the *pattern* as well, so a pattern of
  # U+FEFF alone arrives empty, warns, and returns NA for every element --
  # which made both sides of this comparison NA and the assertion vacuous.
  # R/ranges.R says the same about the production path. base gsub() does no
  # such stripping.
  strip <- function(z) {
    stringi::stri_replace_all_charclass(
      gsub("\uFEFF", "", z, fixed = TRUE),
      "\\p{WHITE_SPACE}", "")
  }
  # strip() is the whole assertion here, so it gets the same degeneracy
  # check the corpus gets above: a helper that returns NA, or the input
  # untouched, would make the comparison below pass without testing
  # anything. That is not hypothetical -- it is what this test did.
  expect_false(any(is.na(strip(X))))
  expect_gt(sum(nzchar(strip(X))), 250L)
  expect_equal(strip("\uFEFF\u4e2d \u3000\uFEFF\u6587"), "\u4e2d\u6587")
  expect_lt(sum(nchar(strip(X))), sum(nchar(X)))

  for (w in c(4, 9, 20)) {
    got <- cjk_wrap(X, w)
    expect_equal(strip(gsub("\n", "", got, fixed = TRUE)), strip(X))
  }
})

test_that("cjk_sentences divides text without editing it", {
  # The pieces must concatenate back to the input exactly -- this is what
  # justifies not trimming the whitespace between sentences.
  got <- cjk_sentences(X)
  expect_equal(vapply(got, paste, character(1), collapse = ""), X)
})

test_that("cjk_jamo round-trips through cjk_compose_jamo for any input", {
  # cjk_compose_jamo() is NFC, so it composes everything composable and not
  # only the jamo -- "e" plus a combining acute comes back as U+00E9. The
  # guarantee is therefore NFC(x), which is x whenever x was already NFC.
  j <- cjk_jamo(X)
  back <- vapply(j, paste, character(1), collapse = "")
  expect_equal(cjk_compose_jamo(back), stringi::stri_trans_nfc(X))
})

test_that("cjk_order reproduces cjk_sort and preserves length", {
  o <- cjk_order(X, locale = "zh")
  expect_equal(X[o], cjk_sort(X, locale = "zh"))
  expect_length(cjk_sort(X, locale = "zh"), length(X))
  # a sort may reorder its input and may not rewrite it
  expect_setequal(cjk_sort(X, locale = "zh"), X)
})
