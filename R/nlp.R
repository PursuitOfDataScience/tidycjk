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
#'
#' # One row per sentence, the way cjk_tokens() gives one row per token.
#' # There is no tidy verb for this because the list is already the hard
#' # part; rep() over lengths() is the whole of the rest.
#' docs <- data.frame(
#'   id = 1:2,
#'   text = c("\u6211\u5f88\u958b\u5fc3\u3002\u4f60\u5462\uff1f", "One. Two.")
#' )
#' sents <- cjk_sentences(docs$text)
#' data.frame(
#'   id = rep(docs$id, lengths(sents)),
#'   sentence = unlist(sents, use.names = FALSE)
#' )
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
  # for "". On the current stringi that NA is already NA_character_, so the
  # coercion below changes nothing; it is kept because the type is part of
  # this verb's contract and stringi's version is unpinned, and the
  # assumption is pinned by a test.
  out <- lapply(out, function(s) {
    if (length(s) == 1L && is.na(s)) NA_character_ else as.character(s)
  })
  hit <- which(bom > 0L)
  for (i in hit) {
    mark <- strrep("\uFEFF", bom[[i]])
    s_i <- out[[i]]
    out[[i]] <- if (length(s_i) == 0L) {
      # A string that was nothing but marks: the split returns nothing, so
      # the marks are the whole result.
      mark
    } else if (is.na(s_i[[1]])) {
      # Not reachable: .cjk_leading_bom() counts 0 for NA, so this loop
      # never visits an NA element. Kept because the NA branch above and
      # this one are the same contract, and a future change to either
      # counting or splitting should not have to rediscover it.
      s_i
    } else {
      c(paste0(mark, s_i[[1]]), s_i[-1L])
    }
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
#' so a supplementary-plane ideograph counts once. A combining mark or a
#' variation selector is a code point too, and therefore its own position in
#' the window: a base character followed by a selector contributes two grams
#' rather than one. That is consistent with the rest of the package, and it
#' is worth knowing if your corpus carries ideographic variation sequences.
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
    # n vectorised paste0() calls rather than one closure call per gram.
    # The k-th gram is chars[i] ... chars[i + n - 1], so pasting n shifted
    # slices column-wise builds every gram at once; measured about five
    # times faster than the per-window vapply() on a corpus of short
    # documents, with byte-identical output.
    hit <- starts[keep]
    do.call(paste0, lapply(seq_len(n) - 1L, function(k) chars[hit + k]))
  })
}


# Punctuation removal.
#
# The obvious spelling of this is gsub("[[:punct:]]", "", x), and it is
# wrong twice over. TRE resolves [:punct:] through the C library, so under
# LC_ALL=C it matches no CJK punctuation at all and under a UTF-8 locale it
# matches all of it -- the same script, two answers, no warning. perl = TRUE
# is worse rather than better: PCRE's POSIX classes are ASCII-only unless
# (*UCP) is set, so it silently removes nothing from Chinese or Japanese in
# any locale. ICU's \p{P} is the same set on every machine, which is the
# property the rest of this package holds to.
#
# What is removed is a Unicode General_Category, not a list of characters,
# and that matters most for what it leaves alone: U+30FC, the prolonged
# sound mark in every Japanese loanword, is a modifier letter rather than
# punctuation, so a category test keeps it where any rule about dashes
# would have eaten the middle of every long vowel.

#' Remove punctuation from CJK text
#'
#' `cjk_strip_punct()` removes punctuation using Unicode's own category
#' rather than a POSIX class, so the same call removes the same characters
#' on every machine. It is the step before [cjk_ngrams()] or
#' [cjk_segment()] that stops punctuation becoming part of a token.
#'
#' @details
#' The usual spelling, `gsub("[[:punct:]]", "", x)`, is unreliable on CJK in
#' two separate ways. R's default engine resolves `[:punct:]` through the C
#' library, so under `LC_ALL=C` it removes no CJK punctuation and under a
#' UTF-8 locale it removes all of it -- the same script gives two answers on
#' two machines. Passing `perl = TRUE` does not fix it but hides it: PCRE's
#' POSIX classes are ASCII-only unless `(*UCP)` is set, so that spelling
#' silently removes nothing from Chinese or Japanese in any locale at all.
#'
#' This removes Unicode General_Category `P`, which is the ideographic full
#' stop U+3002, the ideographic comma U+3001, the fullwidth comma, question
#' mark and exclamation mark, the corner and fullwidth brackets, and the
#' katakana middle dot U+30FB that separates the parts of a transliterated
#' name -- along with ASCII punctuation, so mixed text needs only one pass.
#'
#' # What it deliberately keeps
#'
#' U+30FC, the katakana-hiragana prolonged sound mark, is a *modifier
#' letter* and not punctuation. It looks like a dash and is not one: it
#' carries the long vowel in most Japanese loanwords, so removing it turns
#' the words for coffee and ramen into something else. Testing the category
#' keeps it; any rule phrased about dashes does not.
#'
#' The ideographic space U+3000 is whitespace rather than punctuation and is
#' left alone too. [cjk_segment()] and [cjk_ngrams()] already ignore
#' whitespace, so there is nothing to do about it here.
#'
#' # Why the default replaces rather than deletes
#'
#' `replacement` defaults to a space, not `""`. Deleting a full stop closes
#' the gap it left, and the two characters that were on either side of it
#' become adjacent: `cjk_ngrams()` then reports a bigram spanning a sentence
#' boundary, a "word" that was never written. A space keeps the boundary,
#' and every verb here that walks a string already declines to cross
#' whitespace. Pass `replacement = ""` when you want the characters closed
#' up -- for a display string rather than for tokenising.
#'
#' @inheritParams has_cjk
#' @param replacement A single string to put in place of each removed
#'   character. Defaults to `" "`; see above for why it is not `""`.
#' @param symbols Also remove General_Category `S`: the fullwidth tilde
#'   U+FF5E, currency signs including U+FFE5, and mathematical operators.
#'   Defaults to `FALSE`, because a currency sign is often content.
#'
#' @return A character vector the same length as `x`. `NA` gives `NA`, and a
#'   leading byte-order mark is preserved.
#' @seealso [cjk_ngrams()] and [cjk_segment()], the verbs this feeds;
#'   [cjk_normalize()] for folding width and compatibility variants.
#' @examples
#' x <- "\u4ed6\u8aaa\uff08\u4eca\u5929\uff09\u3002\u771f\u597d"
#' cjk_strip_punct(x)
#' cjk_strip_punct(x, replacement = "")
#'
#' # the prolonged sound mark is a letter, not a dash, and survives
#' cjk_strip_punct("\u30b3\u30fc\u30d2\u30fc\u3001\u30e9\u30fc\u30e1\u30f3")
#'
#' # a space keeps n-grams from spanning the full stop
#' cjk_ngrams(cjk_strip_punct("\u597d\u3002\u5929"))
#' cjk_ngrams(cjk_strip_punct("\u597d\u3002\u5929", replacement = ""))
#' @export
cjk_strip_punct <- function(x, replacement = " ", symbols = FALSE) {
  if (!is.character(replacement) || length(replacement) != 1L ||
        is.na(replacement)) {
    stop("`replacement` must be a single string.", call. = FALSE)
  }
  if (!is.logical(symbols) || length(symbols) != 1L || is.na(symbols)) {
    stop("`symbols` must be TRUE or FALSE.", call. = FALSE)
  }
  x <- as.character(x)
  # Restores nothing on the current stringi, which already answers
  # character(0) here; kept for the reason the identical exits in
  # .cjk_trans_verb() and cjk_normalize() are kept, and pinned by the same
  # test, so a change in stringi surfaces as a failure rather than as a
  # verb quietly returning the wrong shape.
  if (length(x) == 0L) {
    return(character(0))
  }
  # stri_replace_all_charclass() reads a leading U+FEFF as a byte-order mark
  # and drops it, so it is counted off and put back -- the same guard the
  # other verbs here take, and the reason ?cjk_strip_punct promises the mark
  # survives. An interior one is not touched by either stringi or the class.
  bom <- .cjk_leading_bom(x)
  x <- .cjk_strip_bom(x, bom)
  cls <- if (symbols) "[\\p{P}\\p{S}]" else "\\p{P}"
  out <- .cjk_stri(stringi::stri_replace_all_charclass(x, cls, replacement))
  .cjk_restore_bom(out, bom)
}
