# The tidy layer: two verbs that take (data, column) and return a tibble.
#
# This is the part of the package that does not exist anywhere else. The
# Unicode primitives are available -- stringi has had them for years -- but
# answering "how much of this column is CJK, and which characters are in it"
# still means writing the same twenty lines of sapply() every time. These are
# those twenty lines, named.

#' Summarise CJK content in a text column
#'
#' `cjk_summary()` reports how much of a text column is CJK: how many entries
#' contain any CJK at all, what share of entries that is, and the mean share of
#' each entry's characters that are CJK.
#'
#' @details
#' `prop_with_cjk` counts an entry once however much CJK it holds, so it
#' answers "how many of these documents are CJK at all". `mean_ratio` averages
#' [cjk_ratio()] over the entries that have one, so it answers "how CJK are
#' they". A corpus of English with one ideograph per row scores high on the
#' first and near zero on the second.
#'
#' `NA` entries count towards `n_docs` but are excluded from every other
#' figure. Empty strings likewise have no ratio to contribute.
#'
#' Grouping is ignored: the result is always one row for the whole column. Use
#' [dplyr::group_modify()] if you need it per group.
#'
#' @param data A data frame or tibble containing a text column.
#' @param col The text column to scan, supplied unquoted.
#'
#' @return A one-row tibble with columns `n_docs` (all entries), `n_with_cjk`
#'   (entries holding at least one CJK character), `prop_with_cjk` and
#'   `mean_ratio`. The two proportions are `NA` when there is nothing to
#'   average.
#' @seealso [cjk_char_counts()] for the per-character breakdown, [cjk_ratio()]
#'   for the per-row measure this averages.
#' @examples
#' df <- data.frame(
#'   text = c("\u4e2d\u6587", "mixed \u4e2d\u6587 text", "plain ASCII", NA)
#' )
#' cjk_summary(df, text)
#' @export
cjk_summary <- function(data, col) {
  v <- as.character(dplyr::pull(data, {{ col }}))
  has <- has_cjk(v)
  ratio <- cjk_ratio(v)

  n_docs <- length(v)
  n_with <- sum(has, na.rm = TRUE)
  tibble::tibble(
    n_docs = as.integer(n_docs),
    n_with_cjk = as.integer(n_with),
    prop_with_cjk = if (n_docs == 0L) NA_real_ else n_with / n_docs,
    mean_ratio = if (all(is.na(ratio))) NA_real_ else mean(ratio, na.rm = TRUE)
  )
}


#' Count the CJK characters in a text column
#'
#' `cjk_char_counts()` returns one row per distinct CJK character in a text
#' column, with the script and Unicode block it belongs to and how often it
#' occurred. It is the frequency table you would otherwise write by hand before
#' every CJK analysis.
#'
#' @details
#' Only CJK characters appear; Latin letters, digits and whitespace are
#' dropped. "CJK" means any block listed by [cjk_blocks()], so ideographic
#' punctuation and fullwidth forms are included and are labelled as such in
#' `script` -- which makes this the quickest way to find out that a column you
#' thought was clean is full of fullwidth spaces.
#'
#' Rows are ordered by descending count, and ties are broken by first
#' appearance in the column rather than by the session's collation, so the
#' output does not change with the locale.
#'
#' @inheritParams cjk_summary
#'
#' @return A tibble with one row per distinct character and columns `char`,
#'   `codepoint` (integer), `script`, `block` and `n`. A column with no CJK in
#'   it gives a zero-row tibble with those columns.
#' @seealso [cjk_summary()] for the column-level figures, [cjk_blocks()] for
#'   the block table these labels come from.
#' @examples
#' df <- data.frame(
#'   text = c("\u4e2d\u6587\u4e2d\u6587", "\u65e5\u672c\u306e\u3053\u3068\u3070", "ascii only")
#' )
#' cjk_char_counts(df, text)
#' @export
cjk_char_counts <- function(data, col) {
  v <- as.character(dplyr::pull(data, {{ col }}))
  cps <- .cjk_codepoints(v)
  all_cp <- unlist(cps, use.names = FALSE)
  if (is.null(all_cp)) {
    all_cp <- integer(0)
  }

  idx <- .cjk_block_index(all_cp)
  keep <- !is.na(idx)
  cp <- all_cp[keep]
  idx <- idx[keep]

  if (length(cp) == 0L) {
    return(tibble::tibble(
      char = character(0),
      codepoint = integer(0),
      script = character(0),
      block = character(0),
      n = integer(0)
    ))
  }

  # unique() preserves first appearance, which is what the tie-break uses.
  lv <- unique(cp)
  counts <- tabulate(match(cp, lv), nbins = length(lv))
  lv_idx <- idx[match(lv, cp)]
  tab <- .cjk_ranges()

  ord <- order(-counts, seq_along(lv))
  tibble::tibble(
    char = stringi::stri_enc_fromutf32(as.list(lv[ord])),
    codepoint = as.integer(lv[ord]),
    script = tab$script[lv_idx[ord]],
    block = tab$block[lv_idx[ord]],
    n = as.integer(counts[ord])
  )
}
