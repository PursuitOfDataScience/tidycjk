# Transliteration: romanisation, Han script conversion, kana and jamo.
#
# All of this is ICU, reached through stringi, which is already an Import. No
# new dependency is taken on and no table is bundled: the mappings are the
# ones ICU ships, which is the same source the rest of the package leans on
# for width and script.
#
# The honest boundary is that ICU's transforms are *character*-level. They map
# code points, not phrases, and for several of these tasks the phrase is what
# decides the right answer. Each function below says where that bites, because
# a transliteration that is quietly wrong is worse than one that refuses.

# One place to reach ICU, so an unknown transliterator id is our error rather
# than a U_INVALID_ID from four frames down, and so the UTF-8 relabelling in
# .cjk_stri() applies here too.
.cjk_trans <- function(x, id) {
  .cjk_stri(tryCatch(
    stringi::stri_trans_general(x, id),
    error = function(e) {
      if (grepl("U_INVALID_ID", conditionMessage(e), fixed = TRUE)) {
        stop("ICU does not provide the transliterator \"", id, "\". The ICU ",
             "build behind stringi decides which are available; ",
             "stringi::stri_trans_list() shows them.", call. = FALSE)
      }
      # Not reachable from any input we can construct -- unlike
      # stri_width(), stri_trans_general() substitutes replacement
      # characters for invalid UTF-8 rather than erroring. Kept so that a
      # future stringi that does raise here is not silently relabelled.
      stop(e)
    }
  ))
}

# Every verb here is a plain vectorised map: NA in, NA out; zero length in,
# zero length out. Sharing the shell keeps that promise identical across them.
.cjk_trans_verb <- function(x, id) {
  x <- as.character(x)
  # stri_trans_general() already returns character(0) for zero-length input,
  # so this exit changes nothing on the current stringi. Kept for the reason
  # the NULL-to-NA restoration in .cjk_rewidth() is kept -- the stringi
  # version is unpinned and the contract is ours -- and the assumption is
  # pinned by a test, so a change there surfaces as a failure rather than as
  # a verb quietly returning the wrong shape.
  if (length(x) == 0L) {
    return(character(0))
  }
  .cjk_trans(x, id)
}


#' Romanise CJK text
#'
#' Transliterates Han, kana and Hangul into the Latin alphabet: pinyin for
#' Chinese, romaji for Japanese kana, Revised-Romanisation-style output for
#' Korean.
#'
#' @details
#' The mapping is ICU's `Any-Latin`, which handles all three scripts in one
#' pass, so mixed text does not need splitting first. Text that is already
#' Latin is left alone.
#'
#' # What this is not
#'
#' Romanisation is not a function of the code point alone, and ICU treats it
#' as though it were. Three consequences worth knowing before you trust the
#' output:
#'
#' * **Han is always read as Chinese.** ICU routes every Han character
#'   through pinyin, whatever language surrounds it, so Japanese kanji come
#'   back with Chinese readings: U+65E5 U+672C U+8A9E ("Japanese language")
#'   romanises to `ri ben yu`, not `nihongo`. This is not a near miss to be
#'   cleaned up afterwards -- it is the wrong language. Do not use
#'   `cjk_romanize()` on Japanese kanji.
#' * **No word spacing.** ICU inserts a space between Han syllables but not
#'   between scripts, so Han followed immediately by kana romanises to a run
#'   with no boundary where the script changes. Segment first with
#'   [cjk_segment()] if you need words.
#' * **Kana particles are spelled, not pronounced.** The Japanese topic
#'   particle U+306F romanises to `ha`, which is how it is written and not
#'   how it is said.
#'
#' # It is slow, by a wide margin
#'
#' The figures below were measured on one machine and will move with the
#' CPU, the load and the ICU build; the ratios are the durable part. Nothing
#' in the test suite asserts them, deliberately, because a timing assertion
#' on a CRAN build machine fails for reasons that have nothing to do with
#' this package.
#'
#' ICU's transliterator is the most expensive thing this package calls.
#' Measured here, romanising a column of short documents runs at roughly
#' sixty thousand characters a second, and it degrades on a single very long
#' string: the same volume in one string runs at nearer forty thousand,
#' 200,000 characters take about five seconds, and a million takes over two
#' minutes. For scale, `cjk_segment(engine = "icu")` gets through that same
#' million in under half a second, so romanisation can be a few hundred
#' times the cost of everything around it -- measured at about 320 times on
#' the million.
#'
#' None of that is this package's doing -- a bare
#' `stringi::stri_trans_general(x, "Any-Latin")` takes the same time -- and
#' there is no faster route to the same answer. Two things help. Keep a
#' corpus as one row per document rather than pasting it into one string,
#' which is worth about a factor of two. And romanise once into a column you
#' keep, rather than inside a loop.
#'
#' For Japanese specifically, a morphological analyser that knows the reading
#' -- [gibasa](https://CRAN.R-project.org/package=gibasa), which binds MeCab
#' -- is the right tool. This function is for Chinese, for kana, and for
#' getting a sortable ASCII key out of a CJK column.
#'
#' @param x A character vector.
#' @param ascii If `TRUE`, strip diacritics so the result is plain ASCII:
#'   pinyin tone marks are removed, so that `wo` with a caron becomes plain
#'   `wo`. Defaults to `FALSE`,
#'   which keeps them.
#'
#' @return A character vector the same length as `x`. `NA` gives `NA`.
#' @seealso [cjk_simplify()] for Han script conversion, [cjk_segment()] for
#'   word boundaries.
#' @examples
#' # U+4E2D U+6587, "Chinese writing"
#' cjk_romanize("\u4e2d\u6587")            # pinyin, with tone marks
#' cjk_romanize("\u4e2d\u6587", ascii = TRUE)
#'
#' # Han is read as Chinese even in Japanese text -- see Details
#' cjk_romanize("\u65e5\u672c\u8a9e")
#'
#' # kana and Hangul go through the same call
#' cjk_romanize(c("\u3053\u3093\u306b\u3061\u306f", "\uc548\ub155"))
#' @export
cjk_romanize <- function(x, ascii = FALSE) {
  if (!is.logical(ascii) || length(ascii) != 1L || is.na(ascii)) {
    stop("`ascii` must be TRUE or FALSE.", call. = FALSE)
  }
  .cjk_trans_verb(x, if (ascii) "Any-Latin; Latin-ASCII" else "Any-Latin")
}


#' Convert between simplified and traditional Han
#'
#' `cjk_simplify()` maps traditional Han characters to simplified;
#' `cjk_traditionalize()` maps the other way. Characters outside Han, and
#' characters with no counterpart, are left alone.
#'
#' @details
#' This is ICU's `Simplified-Traditional` pair, and it is context-aware
#' rather than a per-character table. Simplified to traditional is genuinely
#' one-to-many -- U+53D1 is U+767C ("to send") or U+9AEE ("hair") depending
#' on the word, and U+5E72 is U+4E7E, U+5E79 or U+5E72 -- and ICU picks
#' correctly from the surrounding characters. Fourteen such pairs were
#' checked, including the ones where the same character splits both ways
#' ("after" against "empress", "inside" against "kilometre"), and every one
#' came out right.
#'
#' What it does not do is substitute regional vocabulary. The two standards
#' differ in the words they use as well as in glyph shape, and that is
#' lexical rather than orthographic. The simplified word for "software",
#' U+8F6F U+4EF6, converts to U+8EDF U+4EF6 -- the correct characters, and
#' the wrong word in Taiwan, where the term is U+8EDF U+9AD4. "Mouse" becomes
#' U+9F20 U+6A19 rather than U+6ED1 U+9F20.
#'
#' So use these for script conversion, which is what they are good at, and
#' reach for [OpenCC](https://github.com/BYVoid/OpenCC) when you need
#' Taiwanese or Hong Kong idiom -- its regional configurations are what carry
#' that.
#'
#' @param x A character vector.
#'
#' @return A character vector the same length as `x`. `NA` gives `NA`.
#' @seealso [cjk_romanize()], [to_halfwidth()] for the width axis.
#' @examples
#' # U+6F22 U+5B57 / U+6C49 U+5B57, "Han characters"
#' cjk_simplify("\u6f22\u5b57")        # traditional -> simplified
#' cjk_traditionalize("\u6c49\u5b57")  # and back
#'
#' # context decides a one-to-many character: "hair" vs "to send"
#' cjk_traditionalize(c("\u5934\u53d1", "\u53d1\u9001"))
#'
#' # but regional vocabulary is not substituted: the Taiwanese word differs
#' cjk_traditionalize("\u8f6f\u4ef6")  # -> U+8EDF U+4EF6, not U+8EDF U+9AD4
#' @export
cjk_simplify <- function(x) {
  .cjk_trans_verb(x, "Traditional-Simplified")
}

#' @rdname cjk_simplify
#' @export
cjk_traditionalize <- function(x) {
  .cjk_trans_verb(x, "Simplified-Traditional")
}


#' Convert between hiragana and katakana
#'
#' `to_hiragana()` maps katakana to hiragana and `to_katakana()` maps the
#' other way. Kanji, Latin text and punctuation are untouched.
#'
#' @details
#' The two kana syllabaries encode the same sounds, so this conversion is
#' unambiguous -- unlike [cjk_romanize()] or [cjk_simplify()], there is no
#' context that could change the answer. It is the normalisation you want
#' before comparing or grouping Japanese text, where the same word may be
#' written either way for emphasis.
#'
#' It is a normalisation, not a reversible mapping. Applied to text holding
#' both syllabaries it erases the distinction between them, and that
#' distinction means something: katakana marks loanwords, onomatopoeia and
#' emphasis. `to_katakana(to_hiragana(x))` returns `x` only when `x` was
#' already all katakana. Run it one way, and keep the original if you need
#' to go back.
#'
#' Halfwidth katakana is handled too, and composed while it is: the halfwidth
#' voiced KA is two code points, U+FF76 and U+FF9E, and `to_katakana()`
#' returns the single character U+30AC. So no width conversion is needed
#' first, though
#' [to_halfwidth()] and [to_fullwidth()] remain the way to move along the
#' width axis without touching the syllabary.
#'
#' @param x A character vector.
#'
#' @return A character vector the same length as `x`. `NA` gives `NA`.
#' @seealso [to_halfwidth()] for the width axis, [cjk_script()] to see which
#'   kana a string is in.
#' @examples
#' to_hiragana("\u30ab\u30bf\u30ab\u30ca")   # katakana -> hiragana
#' to_katakana("\u3072\u3089\u304c\u306a")   # and back
#'
#' # kanji is left alone
#' to_katakana("\u65e5\u672c\u8a9e\u3067\u3059")
#' @export
to_hiragana <- function(x) {
  .cjk_trans_verb(x, "Katakana-Hiragana")
}

#' @rdname to_hiragana
#' @export
to_katakana <- function(x) {
  .cjk_trans_verb(x, "Hiragana-Katakana")
}


#' Decompose and recompose Hangul syllables
#'
#' `cjk_jamo()` splits each Hangul syllable into the jamo it is built from;
#' `cjk_compose_jamo()` puts them back together.
#'
#' @details
#' A modern Hangul syllable is a composite. Unicode encodes 11,172 of them
#' precomposed in the Hangul Syllables block, each one algorithmically derived
#' from a leading consonant, a vowel and an optional trailing consonant:
#' `SIndex = (LIndex * 21 + VIndex) * 28 + TIndex`. Because the relationship
#' is arithmetic rather than tabulated, the decomposition is exact for
#' Hangul: no table can be out of date and no syllable is missed.
#'
#' # The round trip returns NFC, which is not always the input
#'
#' `cjk_compose_jamo()` is normalisation form C, so it composes everything
#' composable and not only the jamo it was handed. If `x` was already in
#' NFC -- which text from almost any source is -- the round trip returns it
#' unchanged. If it was not, the result is `x` normalised: an `e` followed by
#' a combining acute comes back as the single character `U+00E9`, because
#' that is what NFC is for.
#'
#' So the guarantee is `cjk_compose_jamo(cjk_jamo(x))` equals
#' `stringi::stri_trans_nfc(x)`, which equals `x` exactly when `x` is already
#' NFC. Normalise first if you need to be certain.
#'
#' That makes jamo the right unit for questions the syllable hides: which
#' initial consonants a corpus favours, whether two spellings differ only in
#' a final consonant, or how to sort by consonant. U+D55C counts three ways,
#' each right for a different question: one character to `nchar()`, two
#' terminal columns to [cjk_width()] -- a Hangul syllable is East Asian
#' Wide -- and three jamo here.
#'
#' Text that is not Hangul passes through unchanged, so it is safe to run over
#' a mixed column.
#'
#' @param x A character vector.
#'
#' @return `cjk_jamo()` returns a list the same length as `x`, each element a
#'   character vector of jamo; `NA` gives `NA_character_` and the empty string
#'   gives `character(0)`. `cjk_compose_jamo()` takes a character vector and
#'   returns one.
#' @seealso [cjk_script()] to detect Hangul, [cjk_blocks()] for the blocks
#'   involved.
#' @examples
#' # U+D55C U+AE00, "Hangul"
#' cjk_jamo("\ud55c\uae00")
#'
#' # the round trip returns NFC, so already-NFC input comes back unchanged
#' rt <- function(x) {
#'   cjk_compose_jamo(vapply(cjk_jamo(x), paste, character(1), collapse = ""))
#' }
#' rt("\ud55c\uae00")
#'
#' # input that was not NFC comes back normalised: "e" plus a combining
#' # acute becomes the single character U+00E9
#' rt("e\u0301")
#' @export
cjk_jamo <- function(x) {
  x <- as.character(x)
  if (length(x) == 0L) {
    return(list())
  }
  # A leading byte-order mark is hidden from stringi first: stri_sub() below
  # drops one, which cost cjk_compose_jamo(cjk_jamo(x)) the exactness its
  # help page promises.
  bom <- .cjk_leading_bom(x)
  x <- .cjk_strip_bom(x, bom)
  # NFD is the decomposition -- the mapping is defined arithmetically in the
  # standard, so this is exact rather than a lookup that could be incomplete.
  d <- .cjk_stri(stringi::stri_trans_nfd(x))
  lapply(seq_along(d), function(i) {
    if (is.na(d[[i]])) {
      return(NA_character_)
    }
    if (!nzchar(d[[i]])) {
      return(if (bom[[i]] > 0L) rep("\uFEFF", bom[[i]]) else character(0))
    }
    ch <- .cjk_stri(stringi::stri_sub(d[[i]], seq_len(nchar(d[[i]])),
                                      length = 1L))
    if (bom[[i]] > 0L) c(rep("\uFEFF", bom[[i]]), ch) else ch
  })
}

#' @rdname cjk_jamo
#' @export
cjk_compose_jamo <- function(x) {
  x <- as.character(x)
  if (length(x) == 0L) {
    return(character(0))
  }
  .cjk_stri(stringi::stri_trans_nfc(x))
}
