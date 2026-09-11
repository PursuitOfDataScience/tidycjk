# Locale-aware ordering.
#
# R's sort() reads LC_COLLATE, so what it does to Han depends on the session:
# code point order under C and en_US.UTF-8, pinyin under zh_CN.utf8, a third
# order again under ja_JP.utf8. Every one of those is a defensible answer and
# none of them is reproducible, which is the problem -- the same script sorts
# a name column differently on two machines with no warning. ICU has real CJK
# collations and stringi exposes them, so this is a thin wrapper -- with two
# guards, because the underlying functions fail quietly in ways the rest of
# this package does not.

#' Sort CJK text by pronunciation or stroke
#'
#' `cjk_sort()` returns `x` ordered by an ICU collation; `cjk_order()` returns
#' the permutation that would do it, for reordering a data frame.
#'
#' @details
#' `sort()` reads `LC_COLLATE`, so the order it gives Han text is a property
#' of the session rather than of the data. Under `C` or `en_US.UTF-8` it
#' falls back to code point order; under `zh_CN.utf8` glibc supplies a pinyin
#' collation and the answer changes; under `ja_JP.utf8` it changes again.
#' None of those is wrong in itself, and that is the difficulty: the same
#' script sorts a name column differently on two machines and says nothing.
#'
#' The fallback order is worth knowing, because it is not arbitrary. The
#' unified ideographs are laid out in KangXi radical-stroke order, so within
#' the base block sorting by code point sorts by radical. What it is not is
#' phonetic, which is what someone sorting names is after. It also stops
#' being radical order across blocks: every Extension A character
#' (U+3400-U+4DBF) sorts ahead of every base-block one, so a rare character
#' lands nowhere near the common characters sharing its radical.
#'
#' ICU carries real collations. With `locale = "zh"` Han sorts by pinyin, so a
#' column of Chinese surnames comes out in the order a Chinese reader expects.
#'
#' # Choosing the order
#'
#' The collation is selected by the locale string, including the BCP 47
#' variants:
#'
#' * `"zh"` -- Mandarin pinyin.
#' * `"zh-u-co-stroke"` -- stroke count, the convention in many indexes.
#' * `"zh-u-co-zhuyin"` -- bopomofo order.
#' * `"ja"` and `"ko"` -- Japanese and Korean.
#'
#' A locale whose *language* ICU has no collation for is an error here rather
#' than the silent fallback to root collation stringi would otherwise give
#' you, because that fallback produces a plausible-looking wrong order. An
#' unrecognised *region* is not an error: `"zh-CH"`, a typo for `"zh-CN"`,
#' resolves to `"zh"` and still sorts by pinyin, which is the right answer.
#'
#' # Missing values
#'
#' `NA` sorts last and is kept, so the result is always the same length as
#' `x`. `stringi::stri_sort()` drops missing values by default, which would
#' silently shorten a column.
#'
#' @param x A character vector.
#' @param locale ICU locale naming the collation, e.g. `"zh"`. `NULL`, the
#'   default, uses the session default -- which is unlikely to order Han
#'   usefully, so name one.
#' @param decreasing Reverse the order.
#'
#' @return `cjk_sort()` a character vector the same length as `x`;
#'   `cjk_order()` an integer vector of indices.
#' @seealso [cjk_romanize()], whose `ascii = TRUE` output gives a sort key you
#'   can use where no ICU locale is available.
#' @examples
#' # Chinese surnames: Zhang, Wang, Li
#' x <- c("\u5f35", "\u738b", "\u674e")
#'
#' sort(x)                        # depends on LC_COLLATE
#' cjk_sort(x, locale = "zh")     # pinyin: Li, Wang, Zhang -- on any machine
#'
#' # stroke order instead
#' cjk_sort(x, locale = "zh-u-co-stroke")
#'
#' # reorder a data frame
#' df <- data.frame(name = x)
#' df[cjk_order(x, locale = "zh"), , drop = FALSE]
#' @export
cjk_sort <- function(x, locale = NULL, decreasing = FALSE) {
  x <- as.character(x)
  if (!is.logical(decreasing) || length(decreasing) != 1L ||
      is.na(decreasing)) {
    stop("`decreasing` must be TRUE or FALSE.", call. = FALSE)
  }
  if (length(x) == 0L) {
    return(character(0))
  }
  # Subset by the permutation rather than calling stri_sort(). stri_sort()
  # returns *values* that stringi has round-tripped, and that round trip
  # drops a leading U+FEFF -- so a sorted vector came back holding different
  # strings from the one that went in, and x[cjk_order(x)] disagreed with
  # cjk_sort(x). Indexing the original can only reorder it. It is the same
  # byte-order-mark trap .cjk_codepoints() documents, reached through a
  # different stringi entry point.
  x[cjk_order(x, locale = locale, decreasing = decreasing)]
}

#' @rdname cjk_sort
#' @export
cjk_order <- function(x, locale = NULL, decreasing = FALSE) {
  x <- as.character(x)
  if (!is.logical(decreasing) || length(decreasing) != 1L ||
      is.na(decreasing)) {
    stop("`decreasing` must be TRUE or FALSE.", call. = FALSE)
  }
  if (length(x) == 0L) {
    return(integer(0))
  }
  .cjk_locale_guard(
    .cjk_stri(stringi::stri_order(x, decreasing = decreasing, na_last = TRUE,
                                  locale = locale)),
    locale, "collation data",
    "Use \"zh\", \"ja\", \"ko\", or a variant such as \"zh-u-co-stroke\"."
  )
}
