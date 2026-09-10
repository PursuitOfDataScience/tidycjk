# cjk_sort() / cjk_order(): ICU collation, plus the two guards that make them
# safer than calling stringi directly.

ZH <- c("\u5f35", "\u738b", "\u674e")   # Zhang, Wang, Li

test_that("cjk_sort orders Han by pronunciation, not by code point", {
  # pinyin: li, wang, zhang
  expect_equal(cjk_sort(ZH, locale = "zh"),
               c("\u674e", "\u738b", "\u5f35"))
  # ... and that differs from code point order. Compared against an
  # explicit code point sort rather than against sort(), whose result
  # follows LC_COLLATE: under ko_KR.euckr sort() happens to agree with
  # pinyin for these three, so asserting "differs from sort()" was a claim
  # about the session's collation rather than about this package.
  by_codepoint <- ZH[order(vapply(ZH, utf8ToInt, integer(1)))]
  expect_false(identical(cjk_sort(ZH, locale = "zh"), by_codepoint))
})

test_that("a collation variant changes the order", {
  # Stroke order is CLDR data rather than a Unicode invariant, so the exact
  # sequence is not asserted -- see the reasoning in test-width.R. What must
  # hold is that asking for a different collation gives a different order,
  # and still a permutation of the input.
  strokes <- cjk_sort(ZH, locale = "zh-u-co-stroke")
  expect_setequal(strokes, ZH)
  expect_false(identical(strokes, cjk_sort(ZH, locale = "zh")))
})

test_that("cjk_order returns a permutation that reproduces cjk_sort", {
  o <- cjk_order(ZH, locale = "zh")
  expect_type(o, "integer")
  expect_setequal(o, seq_along(ZH))
  expect_equal(ZH[o], cjk_sort(ZH, locale = "zh"))
})

test_that("decreasing reverses, and is validated", {
  expect_equal(cjk_sort(ZH, locale = "zh", decreasing = TRUE),
               rev(cjk_sort(ZH, locale = "zh")))
  expect_error(cjk_sort(ZH, decreasing = NA), "`decreasing`")
  expect_error(cjk_order(ZH, decreasing = 1), "`decreasing`")
})

test_that("NA is kept and sorts last, so length is preserved", {
  # stri_sort() drops NA by default, which would silently shorten a column.
  x <- c("\u5f35", NA, "\u674e")
  out <- cjk_sort(x, locale = "zh")
  expect_length(out, 3L)
  expect_true(is.na(out[[3]]))
  expect_length(cjk_order(x, locale = "zh"), 3L)
})

test_that("zero length in, zero length out", {
  expect_identical(cjk_sort(character(0)), character(0))
  expect_identical(cjk_order(character(0)), integer(0))
})

test_that("an unknown language is an error, not a silent root-collation sort", {
  # stringi only warns and falls back, which produces a plausible wrong order.
  expect_error(cjk_sort(ZH, locale = "xx"), "no collation data")
  expect_error(cjk_order(ZH, locale = "not-a-locale"), "no collation data")
})

test_that("an unknown region falls back to the language, which is correct", {
  # "zh-CH" is a typo for "zh-CN", but ICU resolves the language and sorts by
  # pinyin regardless -- a right answer, so the guard must NOT fire here.
  expect_equal(cjk_sort(ZH, locale = "zh-CH"), cjk_sort(ZH, locale = "zh"))
})

test_that("locale = NULL is allowed and does not trigger the guard", {
  expect_length(cjk_sort(ZH), 3L)
  expect_length(cjk_order(ZH), 3L)
})

test_that("a malformed locale is rejected by every verb that takes one", {
  # The guard validates the argument's shape before its content, so a
  # non-string cannot reach ICU and come back as a silent root-locale
  # fallback. All four locale-taking verbs share the one guard.
  for (bad in list(1, TRUE, NA, NA_character_, c("zh", "ja"), character(0))) {
    expect_error(cjk_sort("a", locale = bad), "`locale`")
    expect_error(cjk_order("a", locale = bad), "`locale`")
    expect_error(cjk_sentences("a", locale = bad), "`locale`")
    expect_error(cjk_wrap("a", 5, locale = bad), "`locale`")
    expect_error(cjk_segment("a", engine = "icu", locale = bad), "`locale`")
  }
})

test_that("sorting reorders the input and never rewrites it", {
  # stri_sort() round-trips its values and drops a leading U+FEFF, so a
  # sorted vector used to come back holding different strings from the one
  # that went in -- and x[cjk_order(x)] disagreed with cjk_sort(x).
  x <- c("\ufeff\u5f35", "\u738b", "\u674e")
  expect_setequal(cjk_sort(x, locale = "zh"), x)
  expect_equal(x[cjk_order(x, locale = "zh")], cjk_sort(x, locale = "zh"))
  expect_true(any(startsWith(cjk_sort(x, locale = "zh"), "\ufeff")))
})
