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
  x <- .cjk_as_text(x)
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
#' as though it were. Four consequences worth knowing before you trust the
#' output:
#'
#' * **Han is always read as Chinese.** ICU routes every Han character
#'   through pinyin, whatever language surrounds it, so Japanese kanji come
#'   back with Chinese readings: U+65E5 U+672C U+8A9E ("Japanese language")
#'   romanises to `ri ben yu`, not `nihongo`. This is not a near miss to be
#'   cleaned up afterwards -- it is the wrong language. Do not use
#'   `cjk_romanize()` on Japanese kanji.
#' * **A character with two readings gets one.** ICU reads each Han
#'   character on its own, so a polyphonic character gets its most common
#'   reading whatever word it is in: U+94F6 U+884C ("bank") romanises to
#'   `yin xing` rather than `yin hang`, and U+97F3 U+4E50 ("music") to
#'   `yin le` rather than `yin yue` (tone marks omitted here). Treat the
#'   output as a sort or search key, not as pinyin to show a reader.
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
#' ICU's transliterator is the most expensive thing this package calls. On a
#' column of 5,000 twenty-character Chinese documents, romanising ran at a
#' median of about 45,000 characters a second (95% CI 43,500 to 45,600) and
#' took about 27 times as long as `cjk_segment(engine = "icu")` on the same
#' column (95% CI 24 to 29; the closest of the pairs was 17 times). The cost
#' is ICU's: a bare `stringi::stri_trans_general(x, "Any-Latin")` takes the
#' same time (ratio 1.01, 95% CI 0.99 to 1.02), and there is no faster route
#' to the same answer.
#'
#' It also gets slower per character as one string gets longer, so the same
#' 100,000 characters took 1.4 times as long pasted into a single string as
#' kept as a column (95% CI 1.35 to 1.43). Keep a corpus as one row per
#' document, and romanise once into a column you keep rather than inside a
#' loop.
#'
#' Those figures are medians of 30 paired, interleaved runs on one machine
#' (an AMD EPYC 7702, ICU 74.1) and will move with the CPU, the load and the
#' ICU build; the ratios are the durable part. Nothing in the test suite
#' asserts them, because a timing assertion on a CRAN build machine fails
#' for reasons that have nothing to do with this package.
#'
#' For Japanese specifically, a morphological analyser that knows the
#' reading is the right tool: [gibasa](https://CRAN.R-project.org/package=gibasa),
#' which binds MeCab. This function is for Chinese, for kana, and for getting
#' a sortable ASCII key out of a CJK column.
#'
#' @inheritParams has_cjk
#' @param ascii If `TRUE`, strip diacritics so the result is plain ASCII:
#'   pinyin tone marks are removed, so that `wo` with a caron becomes plain
#'   `wo`. Defaults to `FALSE`, which keeps them.
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
#' correctly from the surrounding characters. Twenty such words were
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
#' @inheritParams has_cjk
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
#' emphasis. `to_katakana(to_hiragana(x))` turns any hiragana in `x` into
#' katakana, and it is not exact even on text that was all katakana, because
#' ICU's mapping makes a few choices of its own: the small katakana U+30F5 and
#' U+30F6 become the full-size hiragana U+304B and U+3051, and the digraphs
#' U+30FF (*koto*) and U+309F (*yori*) are spelled out as two kana each. Run
#' it one way, and keep the original if you need to go back.
#'
#' Halfwidth katakana is handled too, and composed while it is: the halfwidth
#' voiced KA is two code points, U+FF76 and U+FF9E, and `to_katakana()`
#' returns the single character U+30AC. So no width conversion is needed
#' first, though [to_halfwidth()] and [to_fullwidth()] remain the way to move
#' along the width axis without touching the syllabary.
#'
#' @inheritParams has_cjk
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
#' `SIndex = (LIndex * 21 + VIndex) * 28 + TIndex`. Both verbs apply that
#' arithmetic directly, so the decomposition is exact: no table can be out of
#' date and no syllable is missed.
#'
#' # Only Hangul is touched
#'
#' A character that is not a Hangul syllable passes through `cjk_jamo()` as
#' itself, and `cjk_compose_jamo()` joins conjoining jamo into syllables and
#' changes nothing else, so both are safe to run over a mixed column. That is
#' deliberately narrower than Unicode normalisation. NFD would also split an
#' accented Latin letter, and NFD and NFC alike replace a CJK compatibility
#' ideograph with its unified form, which in a Korean column means silently
#' rewriting Hanja: the compatibility ideographs exist so that the Korean
#' legacy encodings round-trip. Use [cjk_normalize()] when normalisation is
#' what you want.
#'
#' # The round trip
#'
#' `cjk_jamo()` returns a **list**, one character vector of jamo per element
#' of `x`, and `cjk_compose_jamo()` takes a character vector, so the two do
#' not compose directly: join each element first, as the `rt()` helper in the
#' examples does. Writing `cjk_compose_jamo(cjk_jamo(x))` is an error rather
#' than a silent wrong answer, because `as.character()` would deparse the list
#' and hand back the literal string `c("\u1112", "\u1161", "\u11ab")`.
#'
#' Joined and composed, the jamo give back `x` exactly, with one exception
#' that is the point of `cjk_compose_jamo()`: conjoining jamo that `x`
#' already held as separate code points come back composed into their
#' syllable.
#'
#' That makes jamo the right unit for questions the syllable hides: which
#' initial consonants a corpus favours, whether two spellings differ only in
#' a final consonant, or how to sort by consonant. U+D55C counts three ways,
#' each right for a different question: one character to `nchar()`, two
#' terminal columns to [cjk_width()] (a Hangul syllable is East Asian Wide),
#' and three jamo here.
#'
#' @inheritParams has_cjk
#'
#' @return `cjk_jamo()` returns a list the same length as `x`, each element a
#'   character vector of jamo and of the other characters, one per code
#'   point; `NA` gives `NA_character_` and the empty string gives
#'   `character(0)`. `cjk_compose_jamo()` takes a character vector and
#'   returns one.
#' @seealso [cjk_script()] to detect Hangul, [cjk_blocks()] for the blocks
#'   involved, [cjk_normalize()] for the Unicode normalisation forms.
#' @examples
#' # U+D55C U+AE00, "Hangul"
#' cjk_jamo("\ud55c\uae00")
#'
#' # join each element and compose it: the round trip is exact
#' rt <- function(x) {
#'   cjk_compose_jamo(vapply(cjk_jamo(x), paste, character(1), collapse = ""))
#' }
#' rt("\ud55c\uae00")
#'
#' # text that is not Hangul is left alone: the accent stays where it was,
#' # and the compatibility ideograph U+F900 is not swapped for U+8C48
#' cjk_jamo("e\u0301")
#' rt("\uf900") == "\uf900"
#' @export
cjk_jamo <- function(x) {
  x <- .cjk_as_text(x)
  if (length(x) == 0L) {
    return(list())
  }
  # Code points rather than a stringi split, so a leading byte-order mark
  # survives the same way it does in every verb built on .cjk_codepoints().
  lapply(.cjk_codepoints(x), function(cp) {
    if (is.null(cp)) {
      return(NA_character_)
    }
    if (length(cp) == 0L) {
      return(character(0))
    }
    stringi::stri_enc_fromutf32(as.list(.cjk_decompose_hangul(cp)))
  })
}

#' @rdname cjk_jamo
#' @export
cjk_compose_jamo <- function(x) {
  x <- .cjk_as_text(x)
  if (length(x) == 0L) {
    return(character(0))
  }
  cps <- .cjk_codepoints(x)
  out <- stringi::stri_enc_fromutf32(lapply(cps, function(cp) {
    if (is.null(cp)) NULL else .cjk_compose_hangul(cp)
  }))
  out[vapply(cps, is.null, logical(1))] <- NA_character_
  out
}


# Hangul syllable arithmetic, from section 3.12 of the Unicode standard.
#
# A syllable S is SBase + (L * VCount + V) * TCount + T, with the leading
# consonant L, vowel V and optional trailing consonant T counted from their
# own bases; T = 0 means there is none. That is the whole of the mapping,
# which is why both directions are computed here rather than borrowed from
# NFD and NFC: those forms decompose and compose everything else as well, and
# a verb named for jamo had no business rewriting an accented letter or a
# compatibility ideograph on the way past.
.CJK_HANGUL <- list(s_base = 0xAC00L, s_last = 0xD7A3L, l_base = 0x1100L,
                    v_base = 0x1161L, t_base = 0x11A7L, v_count = 21L,
                    t_count = 28L, l_count = 19L)

.cjk_decompose_hangul <- function(cp) {
  h <- .CJK_HANGUL
  syl <- cp >= h$s_base & cp <= h$s_last
  if (!any(syl)) {
    return(cp)
  }
  s <- cp[syl] - h$s_base
  t <- s %% h$t_count
  # every syllable becomes two jamo, or three when it has a final consonant;
  # everything else stays one code point
  width <- rep(1L, length(cp))
  width[syl] <- 2L + (t > 0L)
  out <- rep(cp, width)
  first <- (cumsum(width) - width + 1L)[syl]
  n_vt <- h$v_count * h$t_count
  out[first] <- h$l_base + s %/% n_vt
  out[first + 1L] <- h$v_base + (s %% n_vt) %/% h$t_count
  out[first[t > 0L] + 2L] <- h$t_base + t[t > 0L]
  out
}

.cjk_compose_hangul <- function(cp) {
  h <- .CJK_HANGUL
  n <- length(cp)
  if (n < 2L) {
    return(cp)
  }
  is_l <- function(v) v >= h$l_base & v < h$l_base + h$l_count
  is_v <- function(v) v >= h$v_base & v < h$v_base + h$v_count
  is_t <- function(v) v > h$t_base & v < h$t_base + h$t_count
  # Leading consonant + vowel first. The two sets are disjoint, so the pairs
  # cannot overlap and one vectorised pass finds them all.
  lv <- which(is_l(cp[-n]) & is_v(cp[-1L]))
  if (length(lv)) {
    cp[lv] <- h$s_base +
      ((cp[lv] - h$l_base) * h$v_count + (cp[lv + 1L] - h$v_base)) *
      h$t_count
    cp <- cp[-(lv + 1L)]
    n <- length(cp)
  }
  if (n < 2L) {
    return(cp)
  }
  # Then an LV syllable + trailing consonant, which covers both an L V T run
  # composed above and an LV syllable that arrived precomposed: NFC composes
  # both, and composing one but not the other would be a half-normalisation.
  lvt <- which(cp[-n] >= h$s_base & cp[-n] <= h$s_last &
                 (cp[-n] - h$s_base) %% h$t_count == 0L & is_t(cp[-1L]))
  if (length(lvt)) {
    cp[lvt] <- cp[lvt] + (cp[lvt + 1L] - h$t_base)
    cp <- cp[-(lvt + 1L)]
  }
  cp
}
