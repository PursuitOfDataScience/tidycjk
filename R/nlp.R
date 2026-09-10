# Sentence boundaries and character n-grams.
#
# Two preprocessing steps that CJK text needs and generic tooling gets wrong.
# Sentence splitting because the terminators are U+3002, U+FF01 and U+FF1F
# rather than ".!?"; n-grams because character n-grams are the standard
# baseline for Chinese retrieval and classification, and often competitive
# with word segmentation without needing a dictionary at all.

#' Split text into sentences
#'
#' Splits each string into sentences using ICU's sentence break iterator,
#' which knows the CJK terminators -- the ideographic full stop U+3002, the
#' fullwidth exclamation mark U+FF01 and the fullwidth question mark U+FF1F --
#' as well as the ASCII ones.
#'
#' @details
#' A regular expression on `[.!?]` finds no boundary at all in Chinese or
#' Japanese text, because neither uses those characters to end a sentence.
#' This is the reason the function exists: it is the sentence-level
#' counterpart of [cjk_segment()], and the usual first step before
#' sentence-level classification, translation or embedding.
#'
#' Boundaries follow Unicode Annex #29. `locale` is accepted and forwarded,
#' but do not expect it to change where CJK sentences break: across Chinese,
#' Japanese, Korean and mixed text it gave identical output under `"zh"`,
#' `"ja"`, `"ko"`, `"en"` and the session default. ICU can tailor break rules
#' per locale in principle, and a locale it has no break data for is an error
#' here rather than a silent fallback, which is why the argument is worth
#' having at all.
#'
#' # What comes back
#'
#' The spans are ICU's, returned unmodified, which has one visible
#' consequence: whitespace that sits between two sentences stays attached to
#' the end of the first. Nothing is trimmed, because trimming would make this
#' verb edit text rather than divide it. Call `trimws()` on the result if you
#' want it gone.
#'
#' # A limitation worth knowing
#'
#' Abbreviations are a hard case in Latin text and ICU's default rules do not
#' carry an abbreviation list, so `"Dr. Smith went home."` splits after
#' `"Dr. "`. CJK text does not have the problem, because the terminator is
#' unambiguous. If your corpus is mixed and abbreviation-heavy, check the
#' result before trusting it.
#'
#' @param x A character vector.
#' @param locale ICU locale for the break iterator, e.g. `"ja"`. `NULL`, the
#'   default, uses the session default. See Details -- it does not change
#'   where CJK sentences break.
#'
#' @return A list the same length as `x`, each element a character vector of
#'   sentences. `NA` gives `NA_character_`; the empty string gives
#'   `character(0)`.
#' @seealso [cjk_segment()] for words, [cjk_ngrams()] for character n-grams.
#' @examples
#' # "I am happy today. And you?"
#' cjk_sentences("\u6211\u4eca\u5929\u5f88\u958b\u5fc3\u3002\u4f60\u5462\uff1f")
#'
#' # ASCII terminators work too, and mixed text is fine
#' cjk_sentences("First one. \u4e2d\u6587\u4e5f\u53ef\u4ee5\u3002")
#' @export
cjk_sentences <- function(x, locale = NULL) {
  x <- as.character(x)
  if (length(x) == 0L) {
    return(list())
  }
  # Hidden from stringi for the same reason as in cjk_wrap(): a leading
  # byte-order mark would be dropped, and this verb promises the pieces
  # concatenate back to the input exactly.
  bom <- .cjk_leading_bom(x)
  x <- .cjk_strip_bom(x, bom)
  out <- .cjk_locale_guard(
    .cjk_stri(stringi::stri_split_boundaries(
      x, type = "sentence", locale = locale
    )),
    locale, "break data", "Use a language such as \"zh\", \"ja\" or \"ko\"."
  )
  # As in the icu engine: stringi already returns NA for NA and character(0)
  # for "", and the coercion only fixes the type of an NA element.
  out <- lapply(out, function(s) {
    if (length(s) == 1L && is.na(s)) NA_character_ else as.character(s)
  })
  hit <- which(bom > 0L)
  for (i in hit) {
    mark <- strrep("\uFEFF", bom[[i]])
    s_i <- out[[i]]
    out[[i]] <- if (length(s_i) == 0L) mark
                else if (is.na(s_i[[1]])) s_i
                else c(paste0(mark, s_i[[1]]), s_i[-1L])
  }
  out
}


#' Character n-grams
#'
#' Returns every run of `n` consecutive characters in each string. Character
#' n-grams are the standard dictionary-free baseline for Chinese information
#' retrieval and text classification, and for many tasks they are competitive
#' with word segmentation while needing no model at all.
#'
#' @details
#' For a language that writes word boundaries, n-grams are a crude feature.
#' For Chinese they are not: most words are one or two characters, so
#' character bigrams capture the majority of them without a dictionary, and
#' they degrade gracefully on the out-of-vocabulary terms -- names, slang,
#' new coinages -- where a segmenter is least reliable. Compare against
#' `cjk_segment(engine = "icu")` on your own corpus rather than assuming
#' either wins.
#'
#' Characters are counted as code points, the same unit [cjk_ratio()] uses,
#' so a supplementary-plane ideograph counts once.
#'
#' # Whitespace ends a window
#'
#' An n-gram is never formed across a space, so no gram spans two words of a
#' Latin run or two sides of an ideographic space U+3000. Punctuation is kept,
#' because in CJK it is often informative and it is cheap to filter
#' afterwards; whitespace is not, because a gram containing one is an artefact
#' of layout.
#'
#' A string shorter than `n` characters yields `character(0)` rather than a
#' padded gram.
#'
#' @param x A character vector.
#' @param n Size of each gram, a single positive whole number. Defaults to
#'   `2`, the usual choice for Chinese.
#'
#' @return A list the same length as `x`, each element a character vector of
#'   n-grams in order of occurrence, with repeats kept. `NA` gives
#'   `NA_character_`; the empty string gives `character(0)`.
#' @seealso [cjk_segment()] for word tokens, [cjk_sentences()] for sentences.
#' @examples
#' # U+4E2D U+6587 U+5F88 U+597D, "Chinese is good"
#' cjk_ngrams("\u4e2d\u6587\u5f88\u597d")
#'
#' # trigrams, and the short-string case
#' cjk_ngrams("\u4e2d\u6587\u5f88\u597d", n = 3)
#' cjk_ngrams("\u4e2d")
#'
#' # no gram is formed across the space
#' cjk_ngrams("\u4e2d\u6587 \u4f60\u597d")
#' @export
cjk_ngrams <- function(x, n = 2L) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || !is.finite(n) ||
      n < 1 || n != trunc(n)) {
    stop("`n` must be a single positive whole number.", call. = FALSE)
  }
  # Past the integer range, as.integer() gives NA and a bare "NAs introduced
  # by coercion" warning naming no argument -- then `length(cp) < NA` fails
  # with a missing-value error four frames down. .cjk_as_width() rejects the
  # same case for `width`; this is the same guard for `n`.
  if (n > .Machine$integer.max) {
    stop("`n` must be within integer range.", call. = FALSE)
  }
  n <- as.integer(n)
  x <- as.character(x)
  if (length(x) == 0L) {
    return(list())
  }
  lapply(.cjk_codepoints(x), function(cp) {
    if (is.null(cp)) {
      return(NA_character_)
    }
    if (length(cp) < n) {
      return(character(0))
    }
    chars <- stringi::stri_enc_fromutf32(as.list(cp))
    # ICU's WHITE_SPACE rather than [[:space:]], for the same reason the
    # character engine uses it: the POSIX class goes through the C library
    # and disagrees with itself about U+3000 across locales.
    ws <- stringi::stri_detect_charclass(chars, "\\p{WHITE_SPACE}")
    starts <- seq_len(length(chars) - n + 1L)
    # A window is usable when it contains no whitespace. The cumulative count
    # gives that in one pass rather than re-scanning each window.
    cw <- c(0L, cumsum(ws))
    keep <- (cw[starts + n] - cw[starts]) == 0L
    if (!any(keep)) {
      return(character(0))
    }
    vapply(starts[keep],
           function(i) paste(chars[i:(i + n - 1L)], collapse = ""),
           character(1))
  })
}
