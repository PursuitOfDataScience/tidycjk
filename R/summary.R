# The tidy layer: two verbs that take (data, column) and return a tibble.
#
# This is the part of the package that does not exist anywhere else. The
# Unicode primitives are available -- stringi has had them for years -- but
# answering "how much of this column is CJK, and which characters are in it"
# still means writing the same twenty lines of sapply() every time. These are
# those twenty lines, named.

# Pull the text column, translating the one error a wrong `data` produces.
#
# dplyr reports a `data` it cannot pull from as "no applicable method for
# 'pull' applied to an object of class matrix" -- naming a function the caller
# never called, in a package they may not know they are using. That is the
# same complaint .cjk_stri() answers for stringi, and the same standard ought
# to apply here.
#
# The decision is made on the object, never on the message. R translates its
# "no applicable method" text, and the translations share no phrase with the
# English: German has "nicht anwendbare Methode", French "pas de methode ...
# applicable", and Italian reorders the placeholders entirely. Matching the
# English wording therefore relabelled nothing outside an English session,
# silently, which is the failure this handler exists to prevent.
#
# Asking whether pull() has a method for this class is the same question in
# every locale, and it keeps the promise the message match was chosen for:
# dplyr ships only pull.data.frame, but other packages register their own, so
# anything that can be pulled from -- a data frame, a tibble, a grouped_df, a
# database-backed tbl -- has its own error re-thrown untouched. Shared with
# cjk_tokens() in segment.R, the third verb of the same layer.
.cjk_pull <- function(expr, data) {
  tryCatch(expr, error = function(e) {
    if (.cjk_has_pull_method(data)) {
      stop(e)
    }
    stop("`data` must be a data frame or tibble.", call. = FALSE)
  })
}

.cjk_has_pull_method <- function(data) {
  # The documented contract, and the case that must never be misreported: a
  # missing column in a data frame has to keep its own error. Answered first
  # and without a lookup, so no subtlety below can take it away.
  if (is.data.frame(data)) {
    return(TRUE)
  }
  # Anything else that can be pulled from. A package registering a pull method
  # -- dbplyr for a database-backed tbl, say -- lands it in dplyr's S3 table,
  # so one lookup finds them all. It has to name that namespace: inside this
  # handler dplyr is loaded but not attached, and a plain getS3method() cannot
  # see the generic and answers FALSE for every class, which relabelled a
  # missing-column error as a wrong-type one.
  for (cl in class(data)) {
    if (!is.null(utils::getS3method("pull", cl, optional = TRUE,
                                    envir = asNamespace("dplyr")))) {
      return(TRUE)
    }
  }
  FALSE
}


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
#' `NA` entries never count as containing CJK, and they do count towards
#' `n_docs` -- so they are in the denominator of `prop_with_cjk` and dilute it:
#' a column that is half missing cannot score above 0.5. `mean_ratio` is the
#' one figure they are dropped from, along with empty strings, because neither
#' has a ratio to contribute.
#'
#' Grouping is ignored: the result is always one row for the whole column. Use
#' [dplyr::group_modify()] if you need it per group.
#'
#' @param data A data frame or tibble containing a text column.
#' @param col The text column to scan, supplied unquoted. A non-character
#'   column is coerced with [as.character()]; see [has_cjk()] for why
#'   that makes a numeric column a poor thing to measure.
#'
#' @return A one-row tibble with columns `n_docs` (all entries), `n_with_cjk`
#'   (entries holding at least one CJK character), `prop_with_cjk` and
#'   `mean_ratio`. `prop_with_cjk` is `NA` for a zero-row column, and
#'   `mean_ratio` is `NA` when no entry has a ratio to contribute.
#' @seealso [cjk_char_counts()] for the per-character breakdown, [cjk_ratio()]
#'   for the per-row measure this averages.
#' @examples
#' df <- data.frame(
#'   text = c("\u4e2d\u6587", "mixed \u4e2d\u6587 text", "plain ASCII", NA)
#' )
#' cjk_summary(df, text)
#' @export
cjk_summary <- function(data, col) {
  v <- as.character(.cjk_pull(dplyr::pull(data, {{ col }}), data))
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
#'   text = c("\u4e2d\u6587\u4e2d\u6587",
#'            "\u65e5\u672c\u306e\u3053\u3068\u3070",
#'            "ascii only")
#' )
#' cjk_char_counts(df, text)
#' @export
cjk_char_counts <- function(data, col) {
  v <- as.character(.cjk_pull(dplyr::pull(data, {{ col }}), data))
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
