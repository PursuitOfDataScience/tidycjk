# The tidy layer: verbs taking (data, column) and returning a tibble.

test_that("cjk_summary() counts documents and averages ratios", {
  df <- data.frame(text = c(ZH, paste0("mixed ", ZH, " text"), "plain", NA))
  out <- cjk_summary(df, text)

  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
  expect_named(out, c("n_docs", "n_with_cjk", "prop_with_cjk", "mean_ratio"))
  expect_equal(out$n_docs, 4L)
  expect_equal(out$n_with_cjk, 2L)
  expect_equal(out$prop_with_cjk, 0.5)
  # NA rows are excluded from the mean, so it is over the three real strings
  expect_equal(out$mean_ratio, mean(cjk_ratio(c(ZH, paste0("mixed ", ZH,
                                                           " text"), "plain"))))
})

test_that("cjk_summary() distinguishes 'how many' from 'how much'", {
  # every row has CJK, but almost none of the text is CJK
  sparse <- data.frame(
    text = rep(paste0("a long English sentence with ", ZH, " in it"), 5)
  )
  out <- cjk_summary(sparse, text)
  expect_equal(out$prop_with_cjk, 1)
  expect_lt(out$mean_ratio, 0.1)
})

test_that("cjk_summary() has the documented column types", {
  out <- cjk_summary(data.frame(text = ZH), text)
  expect_type(out$n_docs, "integer")
  expect_type(out$n_with_cjk, "integer")
  expect_type(out$prop_with_cjk, "double")
  expect_type(out$mean_ratio, "double")
})

test_that("cjk_summary() handles an empty column", {
  out <- cjk_summary(data.frame(text = character(0)), text)
  expect_equal(nrow(out), 1L)
  expect_equal(out$n_docs, 0L)
  expect_equal(out$n_with_cjk, 0L)
  expect_true(is.na(out$prop_with_cjk))
  expect_true(is.na(out$mean_ratio))
})

test_that("the undefined figures are NA, not NaN", {
  # Both guards exist to turn an undefined division into NA: without them
  # prop_with_cjk is 0/0 and mean_ratio is mean(numeric(0)), and both are NaN.
  # is.na(NaN) is TRUE, so the assertions above pass either way -- the point of
  # the guards is invisible to them. The help page says NA, and NaN prints as
  # NaN in a tibble and survives a round trip through a file as NaN, so the
  # difference is one a caller sees.
  empty <- cjk_summary(data.frame(text = character(0)), text)
  expect_identical(empty$prop_with_cjk, NA_real_)
  expect_false(is.nan(empty$prop_with_cjk))
  expect_identical(empty$mean_ratio, NA_real_)
  expect_false(is.nan(empty$mean_ratio))
  # mean_ratio is also undefined when every row is NA or empty
  for (txt in list(c(NA_character_, NA_character_), c("", ""))) {
    out <- cjk_summary(data.frame(text = txt), text)
    expect_identical(out$mean_ratio, NA_real_)
    expect_false(is.nan(out$mean_ratio))
  }
})

test_that("cjk_summary() handles all-NA and all-empty columns", {
  all_na <- cjk_summary(data.frame(text = c(NA_character_, NA)), text)
  expect_equal(all_na$n_docs, 2L)
  expect_equal(all_na$n_with_cjk, 0L)
  expect_equal(all_na$prop_with_cjk, 0)
  expect_true(is.na(all_na$mean_ratio))

  all_empty <- cjk_summary(data.frame(text = c("", "")), text)
  expect_equal(all_empty$n_with_cjk, 0L)
  expect_true(is.na(all_empty$mean_ratio))
})

test_that("cjk_summary() keeps NA rows in the prop_with_cjk denominator", {
  # the help page used to say NA entries were "excluded from every other
  # figure", which is true of mean_ratio and false of prop_with_cjk
  out <- cjk_summary(data.frame(text = c(ZH, NA)), text)
  expect_equal(out$n_docs, 2L)
  expect_equal(out$n_with_cjk, 1L)
  expect_equal(out$prop_with_cjk, 0.5)
  expect_equal(out$mean_ratio, 1)
})

test_that("cjk_char_counts() returns one row per distinct character", {
  df <- data.frame(text = c(paste0(ZH, ZH), JA_MIXED, "ascii only"))
  out <- cjk_char_counts(df, text)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("char", "codepoint", "script", "block", "n"))
  # 2 distinct han from ZH, plus 2 kanji and 4 kana from JA_MIXED
  expect_equal(nrow(out), 8L)
  expect_equal(sum(out$n), 4L + 6L)
  expect_false(any(duplicated(out$char)))
})

test_that("cjk_char_counts() sorts by count, then by first appearance", {
  df <- data.frame(text = paste0(ZH, ZH))
  out <- cjk_char_counts(df, text)
  expect_equal(out$n, c(2L, 2L))
  # tied at 2, so the character that appeared first comes first
  expect_equal(out$char, c("\u4e2d", "\u6587"))
  expect_equal(out$codepoint, c(0x4E2DL, 0x6587L))
})

test_that("cjk_char_counts() sorts by DESCENDING count", {
  # Every count above is tied, so ascending and descending order agree and the
  # test could not tell them apart. Unequal counts are what pin the direction
  # the help page promises.
  df <- data.frame(text = "\u6587\u4e2d\u4e2d\u4e2d\u65e5\u65e5")
  out <- cjk_char_counts(df, text)
  expect_equal(out$n, c(3L, 2L, 1L))
  expect_equal(out$char, c("\u4e2d", "\u65e5", "\u6587"))
  # the rarest character appeared first in the text, so this is the direction
  # of the sort and not an accident of input order
  expect_equal(out$char[[1]], "\u4e2d")
  expect_true(!is.unsorted(rev(out$n)))
})

test_that("cjk_char_counts() labels a character that first appeared late", {
  # The block and script come from idx[match(lv, cp)] -- the block of each
  # character's FIRST occurrence. Replacing that with idx[seq_along(lv)] broke
  # no test, because every fixture either had no repeats before a new character
  # or drew every character from one block. It takes a repeat followed by a
  # character from a different block to tell the two apart.
  out <- cjk_char_counts(data.frame(text = "\u4e2d\u4e2d\u3042"), text)
  expect_equal(out$char, c("\u4e2d", "\u3042"))
  expect_equal(out$n, c(2L, 1L))
  expect_equal(out$script, c("han", "hiragana"))
  expect_equal(out$block, c("CJK Unified Ideographs", "Hiragana"))
  # a longer run of repeats before two more blocks, to be sure it is general
  out2 <- cjk_char_counts(
    data.frame(text = "\u4e2d\u4e2d\u4e2d\u3042\uc548\uff11"), text)
  expect_equal(out2$script, c("han", "hiragana", "hangul", "fullwidth"))
})

test_that("cjk_char_counts() labels the script and block", {
  out <- cjk_char_counts(data.frame(text = JA_MIXED), text)
  expect_equal(
    out$script[out$char == "\u65e5"], "han"
  )
  expect_equal(
    out$script[out$char == "\u306e"], "hiragana"
  )
  expect_equal(
    out$block[out$char == "\u65e5"], "CJK Unified Ideographs"
  )
  expect_equal(
    out$block[out$char == "\u306e"], "Hiragana"
  )
})

test_that("cjk_char_counts() drops non-CJK characters", {
  out <- cjk_char_counts(data.frame(text = paste0("abc 123 ", ZH)), text)
  expect_equal(nrow(out), 2L)
  expect_setequal(out$char, c("\u4e2d", "\u6587"))
})

test_that("cjk_char_counts() surfaces fullwidth contamination", {
  # the practical use: a column that looks clean but is full of fullwidth forms
  out <- cjk_char_counts(data.frame(text = FW_DIGITS), text)
  expect_equal(nrow(out), 3L)
  expect_true(all(out$script == "fullwidth"))
})

test_that("cjk_char_counts() handles supplementary-plane characters", {
  out <- cjk_char_counts(data.frame(text = EXT_B), text)
  expect_equal(nrow(out), 1L)
  expect_equal(out$codepoint, 0x20000L)
  expect_equal(out$block, "CJK Unified Ideographs Extension B")
  expect_equal(nchar(out$char), 1L)
})

test_that("cjk_char_counts() gives a typed zero-row tibble when there is no CJK", {
  for (txt in list("ascii only", character(0), NA_character_, "")) {
    out <- cjk_char_counts(data.frame(text = txt), text)
    expect_equal(nrow(out), 0L)
    expect_named(out, c("char", "codepoint", "script", "block", "n"))
    expect_type(out$char, "character")
    expect_type(out$codepoint, "integer")
    expect_type(out$n, "integer")
  }
})

test_that("NA rows do not break either verb", {
  df <- data.frame(text = c(NA_character_, ZH, NA))
  expect_equal(cjk_summary(df, text)$n_with_cjk, 1L)
  expect_equal(nrow(cjk_char_counts(df, text)), 2L)
})

test_that("both verbs take tibbles and unquoted column names", {
  tb <- tibble::tibble(body = c(ZH, "plain"))
  expect_equal(cjk_summary(tb, body)$n_with_cjk, 1L)
  expect_equal(nrow(cjk_char_counts(tb, body)), 2L)
})

test_that("both verbs accept a column selected by string or by position", {
  df <- data.frame(text = c(ZH, "plain"))
  expect_equal(cjk_summary(df, "text")$n_with_cjk, 1L)
  expect_equal(cjk_summary(df, 1)$n_with_cjk, 1L)
  # "both verbs" has to mean both: cjk_char_counts() takes the column the same
  # way, and cjk_tokens() is the third caller of the same dplyr::pull()
  expect_equal(nrow(cjk_char_counts(df, "text")), 2L)
  expect_equal(nrow(cjk_char_counts(df, 1)), 2L)
  expect_equal(nrow(cjk_tokens(df, "text", engine = "character")), 3L)
  expect_equal(nrow(cjk_tokens(df, 1, engine = "character")), 3L)
})

test_that("a `data` that is not a data frame is reported in tidycjk's terms", {
  # dplyr reports it as "no applicable method for 'pull' applied to an object
  # of class matrix" -- naming a function the caller never called, in a package
  # they may not know they are using. That is the complaint .cjk_stri() exists
  # to answer for stringi, so the same standard applies to the tidy layer.
  for (bad in list(matrix(c("a", "b"), 2), list(text = "a"), 1:3, "abc",
                   NULL, factor("a"))) {
    expect_error(cjk_summary(bad, 1), "must be a data frame or tibble")
    expect_error(cjk_char_counts(bad, 1), "must be a data frame or tibble")
    expect_error(cjk_tokens(bad, 1, engine = "character"),
                 "must be a data frame or tibble")
  }
  # the message must not name pull(), which is the whole point
  msg <- tryCatch(cjk_summary(1:3, 1), error = function(e) conditionMessage(e))
  expect_false(grepl("pull", msg, fixed = TRUE))
})

test_that("the pull handler decides on the object, not on the message", {
  # R translates its "no applicable method" text and the translations share no
  # phrase with the English -- German "nicht anwendbare Methode", French "pas
  # de methode ... applicable", Italian reorders the placeholders. Matching the
  # English wording relabelled nothing outside an English session, silently.
  # Testing the mechanism rather than a locale is not a stylistic choice: it is
  # the only thing that can work here. testthat sets LANGUAGE=C inside a test
  # block, the same way it sets LC_COLLATE=C, so R's messages are English no
  # matter what locale the suite is run in. A test that drove cjk_summary() and
  # looked at the resulting text would therefore pass under every locale even
  # with the English-only matcher restored -- which is exactly how that bug
  # survived. Do not "improve" this into a locale-based test; it would prove
  # nothing. Pass an arbitrary message and assert the decision instead.
  expect_true(.cjk_has_pull_method(data.frame(a = 1)))
  expect_true(.cjk_has_pull_method(tibble::tibble(a = 1)))
  expect_true(.cjk_has_pull_method(dplyr::group_by(data.frame(a = 1, b = 2), a)))
  for (bad in list(matrix(1:4, 2), list(a = 1), 1:3, "abc", NULL, factor("a"))) {
    expect_false(.cjk_has_pull_method(bad))
  }
  # so an error is relabelled for an unpullable `data` whatever it says...
  expect_error(.cjk_pull(stop("nicht anwendbare Methode"), matrix(1:4, 2)),
               "must be a data frame or tibble")
  expect_error(.cjk_pull(stop("any wording at all"), 1:3),
               "must be a data frame or tibble")
  # ...and passed through untouched for a `data` that can be pulled from
  expect_error(.cjk_pull(stop("object 'nope' not found"), data.frame(a = 1)),
               "object 'nope' not found")
})

test_that("the pull handler relabels only the missing-method error", {
  # Narrow, like .cjk_stri(): anything else dplyr raises has to come through
  # untouched, or a real mistake gets reported as the wrong mistake.
  df <- data.frame(text = ZH, stringsAsFactors = FALSE)
  expect_error(cjk_summary(df, nope), "nope")
  expect_error(cjk_char_counts(df, nope), "nope")
  expect_error(.cjk_pull(stop("something else entirely"), data.frame(a = 1)),
               "something else")
  # and a working pull is left alone -- data frames, tibbles and grouped_dfs
  expect_equal(cjk_summary(df, text)$n_docs, 1L)
  expect_equal(cjk_summary(tibble::tibble(text = ZH), text)$n_docs, 1L)
  expect_equal(
    cjk_summary(dplyr::group_by(data.frame(g = 1, text = ZH), g), text)$n_docs,
    1L
  )
})

test_that("a misspelled column is an error, not a silent empty result", {
  df <- data.frame(text = ZH)
  expect_error(cjk_summary(df, txet))
  expect_error(cjk_char_counts(df, txet))
})

test_that("the verbs compose in a dplyr pipeline", {
  df <- data.frame(
    id = 1:3,
    text = c(ZH, JA_MIXED, "plain")
  )
  out <- dplyr::filter(dplyr::mutate(df, cjk = has_cjk(text)), cjk)
  expect_equal(nrow(out), 2L)
  expect_equal(cjk_summary(out, text)$prop_with_cjk, 1)
})

test_that("grouped input is accepted and summarised globally", {
  df <- dplyr::group_by(
    data.frame(g = c("a", "a", "b"), text = c(ZH, "plain", ZH)),
    g
  )
  out <- cjk_summary(df, text)
  expect_equal(nrow(out), 1L)
  expect_equal(out$n_docs, 3L)
  # the help page promises a plain tibble, as cjk_tokens() does
  expect_false(inherits(out, "grouped_df"))
  expect_false(inherits(cjk_char_counts(df, text), "grouped_df"))
})
