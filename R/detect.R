# Detection and classification: is this CJK, which script is it, which
# language is it, and how much of it is CJK.
#
# Every source file in this package is pure ASCII. CJK text is written with
# \u escapes and referred to in prose by code point, so that no checking host
# has to agree with us about the file encoding. The romanised meaning is given
# in a comment wherever the escape is not self-evident.

#' Does the text contain CJK characters?
#'
#' `has_cjk()` reports, for each element, whether the string contains at least
#' one character from a CJK Unicode block.
#'
#' @details
#' "CJK" here means any block listed by [cjk_blocks()], which includes CJK
#' punctuation and the halfwidth and fullwidth forms as well as the ideographs
#' and the phonetic scripts. That is deliberate -- a column typed with a CJK
#' input method carries the punctuation too -- but it does mean that a string
#' of nothing but ideographic full stops (U+3002) is `TRUE`. Use [cjk_script()]
#' when you need to know *which* kind of CJK you have.
#'
#' @param x A character vector. Anything else is coerced with [as.character()].
#'
#' @return A logical vector the same length as `x`. `NA` input gives `NA`; the
#'   empty string gives `FALSE`.
#' @seealso [cjk_ratio()] for how much of the text is CJK, [cjk_script()] for
#'   which script it is.
#' @examples
#' # U+4E2D U+6587, "Chinese writing"
#' has_cjk(c("\u4e2d\u6587", "plain ASCII", NA))
#'
#' # the ideographic full stop U+3002 counts, by design
#' has_cjk("\u3002")
#' @export
has_cjk <- function(x) {
  cps <- .cjk_codepoints(x)
  vapply(cps, function(cp) {
    if (is.null(cp)) {
      return(NA)
    }
    if (length(cp) == 0L) {
      return(FALSE)
    }
    any(!is.na(.cjk_block_index(cp)))
  }, logical(1))
}


#' Which CJK script dominates the text?
#'
#' `cjk_script()` returns the script that accounts for the most CJK characters
#' in each string: one of `"han"`, `"hiragana"`, `"katakana"`, `"hangul"`,
#' `"bopomofo"`, `"kanbun"`, `"punctuation"` or `"fullwidth"`.
#'
#' @details
#' Only CJK characters vote. Latin letters, digits and whitespace are ignored
#' entirely, so a string of English with two ideographs in it is `"han"` rather
#' than something averaged over the whole string.
#'
#' Ties are broken by first appearance in the string -- not alphabetically and
#' not by the session's collation -- so the result never depends on the locale.
#'
#' @inheritParams has_cjk
#'
#' @return A character vector the same length as `x`. Strings with no CJK
#'   characters -- and `NA` strings, and `""` -- give `NA`.
#' @seealso [cjk_blocks()] for the script labels, [cjk_char_counts()] for the
#'   full per-character breakdown rather than just the winner.
#' @examples
#' # Chinese, Japanese, Korean, then a string with no CJK at all
#' cjk_script(c("\u4e2d\u6587", "\u3053\u3093\u306b\u3061\u306f",
#'              "\uc548\ub155", "ascii"))
#'
#' # mixed Han and kana: four kana outvote two ideographs
#' cjk_script("\u65e5\u672c\u306e\u3053\u3068\u3070")
#' @export
cjk_script <- function(x) {
  cps <- .cjk_codepoints(x)
  vapply(cps, function(cp) {
    if (is.null(cp) || length(cp) == 0L) {
      return(NA_character_)
    }
    s <- .cjk_scripts_of(cp)
    s <- s[!is.na(s)]
    if (length(s) == 0L) {
      return(NA_character_)
    }
    # unique() keeps first-appearance order and which.max() takes the first
    # maximum, so ties resolve to whichever script appeared first.
    lv <- unique(s)
    lv[[which.max(tabulate(match(s, lv), nbins = length(lv)))]]
  }, character(1))
}


#' Which language is the text written in?
#'
#' `cjk_detect_language()` infers the language of each string from the scripts
#' it contains, and returns `NA` when the scripts do not settle the question.
#'
#' @details
#' The rules are applied in order:
#'
#' 1. Hiragana or katakana present: `"japanese"`. Only Japanese uses kana.
#' 2. Kanbun annotation marks present: `"japanese"`. They exist to make
#'    Classical Chinese readable as Japanese.
#' 3. Hangul present: `"korean"`.
#' 4. Bopomofo present: `"chinese"`. Bopomofo annotates Mandarin.
#' 5. Han characters and nothing else from the list above: **`NA`** by default.
#' 6. No CJK writing system at all: `NA`.
#'
#' Rule 5 is the point of the function. Japanese written without kana -- a
#' headline, a shop sign, a personal name, a compound such as U+6771 U+4EAC
#' U+90FD (Tokyo Metropolis) -- is not distinguishable from Chinese by script
#' alone, because both are writing the same Han characters. Any package that
#' answers `"chinese"` there is guessing, and it will be wrong on Japanese
#' input in a way the caller cannot detect. `tidycjk` returns `NA` instead.
#'
#' If your corpus is known to be Chinese and you want the guess anyway, ask for
#' it explicitly with `han_only = "chinese"`. Making it an argument keeps the
#' assumption in the script, where a reader of the analysis can see it.
#'
#' CJK punctuation and fullwidth forms are ignored here, even though
#' [has_cjk()] counts them, because all three languages share them.
#'
#' @inheritParams has_cjk
#' @param han_only What to return for a string written in Han characters only.
#'   Defaults to `NA_character_`, meaning "undecidable". Set it to `"chinese"`
#'   to opt into the guess.
#'
#' @return A character vector the same length as `x`, holding `"japanese"`,
#'   `"korean"`, `"chinese"`, the value of `han_only`, or `NA`.
#' @seealso [cjk_script()], which reports what is actually there rather than
#'   inferring from it.
#' @examples
#' # kana settles it; hangul settles it
#' cjk_detect_language(c("\u3053\u3093\u306b\u3061\u306f", "\uc548\ub155"))
#'
#' # U+6771 U+4EAC U+90FD is Tokyo Metropolis: Japanese, written without kana,
#' # and therefore indistinguishable from Chinese. The honest answer is NA.
#' cjk_detect_language("\u6771\u4eac\u90fd")
#'
#' # opt in to the guess when you know the corpus is Chinese
#' cjk_detect_language("\u6771\u4eac\u90fd", han_only = "chinese")
#' @export
cjk_detect_language <- function(x, han_only = NA_character_) {
  if (length(han_only) != 1L) {
    stop("`han_only` must be a single string or NA.", call. = FALSE)
  }
  han_only <- as.character(han_only)

  cps <- .cjk_codepoints(x)
  vapply(cps, function(cp) {
    if (is.null(cp) || length(cp) == 0L) {
      return(NA_character_)
    }
    s <- .cjk_scripts_of(cp)
    s <- s[!is.na(s)]
    if (any(s %in% c("hiragana", "katakana", "kanbun"))) {
      return("japanese")
    }
    if (any(s == "hangul")) {
      return("korean")
    }
    if (any(s == "bopomofo")) {
      return("chinese")
    }
    if (any(s == "han")) {
      return(han_only)
    }
    NA_character_
  }, character(1))
}


#' What share of the text is CJK?
#'
#' `cjk_ratio()` reports the proportion of each string's characters that fall
#' in a CJK Unicode block, from 0 to 1. It is the natural way to find the rows
#' of a mixed corpus that are actually CJK, as opposed to the ones carrying a
#' single stray ideograph.
#'
#' @details
#' Characters are counted as Unicode code points, so an ideograph from a
#' supplementary plane counts once, not twice. The denominator is every
#' character in the string, including spaces and Latin punctuation.
#'
#' @inheritParams has_cjk
#'
#' @return A numeric vector the same length as `x`, between 0 and 1. `NA` input
#'   gives `NA`. The empty string gives `NA` rather than 0, because the ratio is
#'   0/0 and undefined.
#' @seealso [has_cjk()] for the yes/no version, [cjk_summary()] for the
#'   column-level summary.
#' @examples
#' cjk_ratio(c("\u4e2d\u6587", "half \u4e2d\u6587", "none", "", NA))
#' @export
cjk_ratio <- function(x) {
  cps <- .cjk_codepoints(x)
  vapply(cps, function(cp) {
    if (is.null(cp)) {
      return(NA_real_)
    }
    n <- length(cp)
    if (n == 0L) {
      return(NA_real_)
    }
    sum(!is.na(.cjk_block_index(cp))) / n
  }, numeric(1))
}
