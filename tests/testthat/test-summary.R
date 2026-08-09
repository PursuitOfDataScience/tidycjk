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
})
