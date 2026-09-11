# Fullwidth and halfwidth normalisation.
#
# The usual advice is "just run NFKC". NFKC does fix width, but it is a blunt
# instrument: it also rewrites ligatures, superscripts, Roman numerals, circled
# numbers and the no-break space. Someone who wants their fullwidth digits
# narrowed rarely wants any of that. These two functions touch width and
# nothing else. cjk_normalize(), below, is the blunt instrument for when it is
# the right one -- and the place the compatibility ideographs are answered,
# because those are folded by every form including NFC, not by NFKC alone.
#
# The direction convention is the ordinary Japanese one: alphanumerics
# halfwidth, katakana fullwidth. So to_halfwidth() narrows fullwidth ASCII
# *and* widens halfwidth katakana -- halfwidth katakana is a legacy encoding
# artefact with no canonical narrow form for the voiced syllables, so
# "normalise the width of this text" always means widening it.

# Halfwidth forms U+FF61-U+FF9F, in code point order, mapped to their
# fullwidth equivalents. Contiguous, so it indexes directly.
.cjk_halfwidth_katakana <- function() {
  c(
    0x3002, 0x300C, 0x300D, 0x3001, 0x30FB, 0x30F2, # FF61-FF66
    0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9,         # FF67-FF6B
    0x30E3, 0x30E5, 0x30E7, 0x30C3,                 # FF6C-FF6F
    0x30FC, 0x30A2, 0x30A4, 0x30A6, 0x30A8, 0x30AA, # FF70-FF75
    0x30AB, 0x30AD, 0x30AF, 0x30B1, 0x30B3,         # FF76-FF7A  ka row
    0x30B5, 0x30B7, 0x30B9, 0x30BB, 0x30BD,         # FF7B-FF7F  sa row
    0x30BF, 0x30C1, 0x30C4, 0x30C6, 0x30C8,         # FF80-FF84  ta row
    0x30CA, 0x30CB, 0x30CC, 0x30CD, 0x30CE,         # FF85-FF89  na row
    0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB,         # FF8A-FF8E  ha row
    0x30DE, 0x30DF, 0x30E0, 0x30E1, 0x30E2,         # FF8F-FF93  ma row
    0x30E4, 0x30E6, 0x30E8,                         # FF94-FF96  ya row
    0x30E9, 0x30EA, 0x30EB, 0x30EC, 0x30ED,         # FF97-FF9B  ra row
    0x30EF, 0x30F3,                                 # FF9C-FF9D
    0x309B, 0x309C                                  # FF9E-FF9F  voiced marks
  )
}

# Katakana that take a voiced mark (dakuten), and what they become. Across the
# ka, sa, ta and ha rows the voiced syllable is simply the base plus one, but
# five characters break that rule and are listed out: U+30A6 voices to U+30F4,
# and the wa-row four voice into the U+30F7-U+30FA block. Every pair here
# agrees with Unicode NFC composition.
.cjk_voiced_map <- function() {
  rows <- c(
    0x30AB, 0x30AD, 0x30AF, 0x30B1, 0x30B3, # ka ki ku ke ko
    0x30B5, 0x30B7, 0x30B9, 0x30BB, 0x30BD, # sa shi su se so
    0x30BF, 0x30C1, 0x30C4, 0x30C6, 0x30C8, # ta chi tsu te to
    0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB  # ha hi fu he ho
  )
  list(
    from = c(rows, 0x30FD, 0x30A6, 0x30EF, 0x30F0, 0x30F1, 0x30F2),
    to   = c(rows + 1, 0x30FE, 0x30F4, 0x30F7, 0x30F8, 0x30F9, 0x30FA)
  )
}

# The semi-voiced mark (handakuten) applies to the ha row only, adding two.
.cjk_semivoiced_map <- function() {
  rows <- c(0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB)
  list(from = rows, to = rows + 2)
}

# Both the spacing marks that halfwidth katakana maps to and the combining
# marks that the same syllables carry in decomposed text.
.CJK_VOICED_MARKS <- c(0x309B, 0x3099)
.CJK_SEMIVOICED_MARKS <- c(0x309C, 0x309A)

# Fold [base][voiced mark] pairs into the single precomposed code point.
.cjk_compose_voiced <- function(cp) {
  n <- length(cp)
  if (n < 2L) {
    return(cp)
  }
  # The scan below walks the string one code point at a time in R, and
  # to_fullwidth() always composes, so without this guard a column of plain
  # ASCII pays that cost on every character it holds -- measurably, about ten
  # times the rest of the width mapping put together. Nothing can compose
  # unless a mark is actually present, and testing for one is a single
  # vectorised pass.
  if (!any(cp %in% c(.CJK_VOICED_MARKS, .CJK_SEMIVOICED_MARKS))) {
    return(cp)
  }
  voiced <- .cjk_voiced_map()
  semi <- .cjk_semivoiced_map()
  out <- integer(n)
  k <- 0L
  i <- 1L
  while (i <= n) {
    this <- cp[[i]]
    nxt <- if (i < n) cp[[i + 1L]] else NA_integer_
    composed <- NA_integer_
    if (!is.na(nxt)) {
      if (nxt %in% .CJK_VOICED_MARKS) {
        composed <- voiced$to[match(this, voiced$from)]
      } else if (nxt %in% .CJK_SEMIVOICED_MARKS) {
        composed <- semi$to[match(this, semi$from)]
      }
    }
    k <- k + 1L
    if (is.na(composed)) {
      out[[k]] <- this
      i <- i + 1L
    } else {
      out[[k]] <- composed
      i <- i + 2L
    }
  }
  out[seq_len(k)]
}

# The single code point mapper both exported functions run through.
.cjk_rewidth <- function(x, to, compose) {
  cps <- .cjk_codepoints(x)
  kata <- .cjk_halfwidth_katakana()
  mapped <- lapply(cps, function(cp) {
    if (is.null(cp)) {
      return(NULL)
    }
    if (length(cp) == 0L) {
      return(integer(0))
    }
    # Halfwidth katakana always widens, in both directions: there is no
    # halfwidth form of a voiced syllable, so the fullwidth one is the only
    # form that round-trips.
    hw <- cp >= 0xFF61 & cp <= 0xFF9F
    if (any(hw)) {
      cp[hw] <- kata[cp[hw] - 0xFF61 + 1L]
    }
    if (identical(to, "halfwidth")) {
      ascii <- cp >= 0xFF01 & cp <= 0xFF5E
      cp[ascii] <- cp[ascii] - 0xFEE0
      cp[cp == 0x3000] <- 0x0020
    } else {
      ascii <- cp >= 0x0021 & cp <= 0x007E
      cp[ascii] <- cp[ascii] + 0xFEE0
      cp[cp == 0x0020] <- 0x3000
    }
    if (compose) as.integer(.cjk_compose_voiced(cp)) else as.integer(cp)
  })
  out <- stringi::stri_enc_fromutf32(mapped)
  # As in cjk_width(): stri_enc_fromutf32() already maps a NULL element to NA,
  # so this restores nothing on the current stringi. Kept for the same reason
  # -- the version is unpinned and the NA contract is ours -- and pinned by a
  # test so a change in stringi surfaces as a failure.
  out[vapply(mapped, is.null, logical(1))] <- NA_character_
  out
}


#' Normalise fullwidth and halfwidth forms
#'
#' `to_halfwidth()` narrows fullwidth ASCII to ASCII, and `to_fullwidth()`
#' widens ASCII to fullwidth. Both widen halfwidth katakana to its fullwidth
#' form. Nothing else in the string is touched.
#'
#' @details
#' # Why not NFKC
#'
#' `NFKC` normalisation does fix character width, and it is what most advice
#' recommends. It also rewrites ligatures, superscripts and subscripts, Roman
#' numerals, circled and parenthesised numbers, the no-break space, and the CJK
#' compatibility ideographs. A user who wants fullwidth digits narrowed before
#' parsing them as numbers almost never wants the rest of that, and the damage
#' is silent. These functions change width and nothing else.
#'
#' # What is mapped
#'
#' * Fullwidth ASCII U+FF01-U+FF5E and ASCII U+0021-U+007E, which differ by a
#'   constant offset of `0xFEE0`.
#' * The ideographic space U+3000 and the ASCII space U+0020.
#' * Halfwidth katakana U+FF61-U+FF9F, which always maps *to* the fullwidth
#'   form -- in both directions. This is the ordinary Japanese convention
#'   (alphanumerics halfwidth, katakana fullwidth), and it is forced: the
#'   voiced syllables have no halfwidth form of their own, so fullwidth is the
#'   only representation that survives a round trip.
#'
#' That is the whole of it, and the rest of the Halfwidth and Fullwidth Forms
#' block is left alone -- which is worth naming, because those code points sit
#' immediately beside the ones above. The fullwidth currency and sign forms
#' U+FFE0-U+FFE6 (cent, pound, not, macron, broken bar, yen, won) keep their
#' width, so `to_halfwidth()` narrows the digits of a price and leaves the
#' currency symbol fullwidth. So do the halfwidth Hangul jamo U+FFA0-U+FFDC,
#' the halfwidth symbol forms U+FFE8-U+FFEE, and the fullwidth white
#' parentheses U+FF5F and U+FF60. None of them is ASCII on either side, and
#' fullwidth ASCII is what these functions promise; `NFKC` maps all of them,
#' along with everything else named under "Why not NFKC" above.
#'
#' # Voiced marks
#'
#' Halfwidth katakana writes a voiced syllable as two code points, a bare
#' syllable followed by a voiced sound mark. Mapping those to fullwidth
#' one-for-one leaves the pair intact, so the text still has two code points
#' where a reader sees one character, and it will not match a literal written
#' the normal way.
#'
#' With `compose = TRUE`, the default, the pair is folded into the single
#' precomposed code point: U+FF76 U+FF9E becomes U+30AC, one character, rather
#' than U+30AB followed by U+309B. Voicing adds one to the base throughout the
#' ka, sa, ta and ha rows, and to the katakana iteration mark U+30FD; the
#' semi-voiced mark adds two and applies to the ha row only. Five characters
#' break the arithmetic and are mapped explicitly:
#' U+30A6 voices to U+30F4, and the wa-row characters U+30EF, U+30F0, U+30F1
#' and U+30F2 voice into U+30F7 to U+30FA. Every pair agrees with Unicode NFC
#' composition.
#'
#' Composition applies to katakana, which is what the width mapping produces.
#' Both the spacing marks (U+309B, U+309C) and the combining marks (U+3099,
#' U+309A) are recognised, so katakana that arrived already decomposed is
#' composed too.
#'
#' `to_fullwidth()` always composes, because a fullwidth string carrying an
#' uncomposed voiced mark is not a form anyone wants.
#'
#' # One deliberate difference from NFKC and from ICU
#'
#' The Unicode compatibility decomposition of U+FF9E is the *combining* mark
#' U+3099, so `NFKC` maps the halfwidth voiced mark onto a combining
#' character, and so does [ICU](https://icu.unicode.org)'s
#' `Halfwidth-Fullwidth` transform. These functions map it to the *spacing*
#' mark U+309B instead, and U+FF9F to U+309C.
#'
#' The difference is only visible with `compose = FALSE`, and the spacing mark
#' is the safer of the two there: a combining mark left loose attaches itself
#' to whatever character happens to precede it. ICU shows the hazard on its own
#' transform -- `"a"` followed by U+FF9E comes back as U+FF41 U+3099, a
#' fullwidth `a` wearing a voiced sound mark. With `compose = TRUE`, the
#' default, the question does not arise: the mark is folded into the syllable
#' and no bare mark survives either way.
#'
#' @inheritParams has_cjk
#' @param compose Fold a syllable and a following voiced mark into the single
#'   precomposed code point. Defaults to `TRUE`. `FALSE` leaves the pair as
#'   two code points, which is occasionally what you want if you are counting
#'   marks rather than characters.
#'
#' @return A character vector the same length as `x`. `NA` input gives `NA`;
#'   the empty string gives the empty string.
#' @seealso [cjk_normalize()] for the Unicode normalisation forms, which
#'   fold width along with much else, [cjk_width()] for measuring the
#'   result.
#' @examples
#' # fullwidth digits will not parse as numbers until they are narrowed
#' to_halfwidth("\uff11\uff12\uff13")
#' as.numeric(to_halfwidth("\uff11\uff12\uff13"))
#'
#' # halfwidth katakana is widened, and the voiced mark is composed:
#' # U+FF76 U+FF9E (two code points) becomes U+30AC (one)
#' to_halfwidth("\uff76\uff9e")
#' nchar(to_halfwidth("\uff76\uff9e"))
#' nchar(to_halfwidth("\uff76\uff9e", compose = FALSE))
#'
#' # ASCII round-trips exactly, in both directions
#' to_halfwidth(to_fullwidth("abc 123"))
#' to_fullwidth("abc")
#' @export
to_halfwidth <- function(x, compose = TRUE) {
  if (!is.logical(compose) || length(compose) != 1L || is.na(compose)) {
    stop("`compose` must be TRUE or FALSE.", call. = FALSE)
  }
  x <- as.character(x)
  if (length(x) == 0L) {
    return(character(0))
  }
  .cjk_rewidth(x, to = "halfwidth", compose = compose)
}

#' @rdname to_halfwidth
#' @export
to_fullwidth <- function(x) {
  x <- as.character(x)
  if (length(x) == 0L) {
    return(character(0))
  }
  .cjk_rewidth(x, to = "fullwidth", compose = TRUE)
}


# Unicode normalisation.
#
# Everything above rewrites width. This rewrites the code points themselves,
# which is a different axis and the one that decides whether two strings that
# look identical compare equal.
#
# The forms are stringi's, and a bare wrapper over them would not be worth an
# export. What is worth one is the ordering: variation selectors have to come
# out *before* the form is applied, never after. A selector has combining
# class zero, so it blocks canonical composition across itself -- U+0041
# U+FE00 U+0300 stays three code points under NFC. Strip the selector
# afterwards and the result is A followed by a bare combining grave: not NFC,
# although it was just normalised. Strip first and NFC composes it to U+00C0.
# Getting this backwards produces output that fails a normalisation check for
# the form the caller asked for, which is the one thing this must not do.
.CJK_NORM_FORMS <- c("nfc", "nfd", "nfkc", "nfkd", "nfkc_casefold")

# stringi exposes one function per form rather than a form argument.
.cjk_norm_fn <- function(form) {
  switch(form,
    nfc  = stringi::stri_trans_nfc,
    nfd  = stringi::stri_trans_nfd,
    nfkc = stringi::stri_trans_nfkc,
    nfkd = stringi::stri_trans_nfkd,
    nfkc_casefold = stringi::stri_trans_nfkc_casefold
  )
}


#' Apply Unicode normalisation
#'
#' `cjk_normalize()` puts text into one of the Unicode normalisation forms, so
#' that strings which look the same compare the same. It optionally removes
#' variation selectors first, which defeat an exact match on their own and
#' which only one of the forms takes out.
#'
#' @details
#' Two strings can render identically and still differ as data. Japanese
#' U+304C is one code point or two depending on where the text came
#' from; a compatibility ideograph and its unified equivalent are distinct
#' code points for the same character; an ideographic variation sequence adds
#' an invisible selector that only a font reacts to. Any of these will split
#' one token into two in a frequency count, a join or a `group_by()`.
#'
#' # Which form
#'
#' `"nfc"` and `"nfd"` are canonical: they preserve the identity of every
#' character and differ only in whether marks are composed. `"nfc"` is the
#' form almost all text is already in and the right default.
#'
#' `"nfkc"` and `"nfkd"` add compatibility folding, which is lossy by design.
#' On CJK text it narrows fullwidth ASCII, widens halfwidth katakana, turns
#' the ideographic space U+3000 into a plain space, and unpacks circled
#' numbers and squared kana -- U+3314 becomes the two characters
#' U+30AD U+30ED. That is the right trade for search and token
#' matching and the wrong one for anything that has to be shown back to a
#' reader. `"nfkc_casefold"` is `"nfkc"` plus case folding, for
#' case-insensitive matching of the Latin mixed into CJK text.
#'
#' `"nfkc_casefold"` also deletes every code point Unicode marks
#' `Default_Ignorable`, which the other four forms all keep. That is the
#' variation selectors below, and with them the zero-width joiner and
#' non-joiner, the zero-width space, the soft hyphen, the tag characters and
#' U+FEFF -- so a byte-order mark at the front of a string survives the other
#' forms and does not survive this one. For matching that is the point. If
#' you need the folding without the deletions, use `"nfkc"` and lowercase
#' separately.
#'
#' [to_halfwidth()] and [to_fullwidth()] are the narrow alternative: they move
#' text along the width axis and touch nothing else.
#'
#' # NFC is not a no-op on CJK
#'
#' Canonical normalisation is usually described as safe, and on Latin text it
#' is. On Han it is not. Compatibility ideographs have *singleton* canonical
#' mappings, so **`"nfc"` rewrites them just as `"nfkc"` does**: U+FA0C
#' becomes U+5140 and U+F900 becomes U+8C48. Of the 472 characters in the CJK
#' Compatibility Ideographs block, 460 are folded away by plain NFC; the 12
#' that survive -- U+FA0E, U+FA0F, U+FA11, U+FA13, U+FA14, U+FA1F, U+FA21,
#' U+FA23, U+FA24, U+FA27, U+FA28, U+FA29 -- are unified ideographs that were
#' encoded in that block by accident and have no mapping to apply. All 542
#' characters of the Supplement block are folded. So the block is not
#' preserved and not uniformly folded either: if the distinction between a
#' compatibility ideograph and its unified form carries meaning in your data,
#' as it can in Korean and Japanese name records, normalising at all will
#' destroy most of it. Keep the original column.
#'
#' # Variation selectors
#'
#' `drop_variation_selectors = TRUE` removes them before the form is applied.
#' They are removed first rather than afterwards because a selector blocks
#' canonical composition across itself, so stripping one after normalising
#' can leave text that is no longer in the form just requested.
#'
#' The set removed is Unicode's `Variation_Selector` property, not a list
#' written out here: the sixteen at U+FE00..U+FE0F, the 240 ideographic ones
#' at U+E0100..U+E01EF, and the Mongolian free variation selectors -- of
#' which there are four on a current ICU and three on one built against
#' Unicode 10.0, because U+180F arrived in Unicode 14.0. Taking the set from
#' the property rather than from a literal means the verb follows whichever
#' ICU is installed. Dropping
#' them merges the glyph variants of a character into one token, which is what
#' a frequency count wants and what a typesetter does not.
#'
#' `"nfc"`, `"nfd"`, `"nfkc"` and `"nfkd"` all leave every one of them in
#' place, so this argument is the only way to be rid of them under those
#' forms. `"nfkc_casefold"` removes them regardless, as part of the wider
#' deletion described above, and the argument is then redundant rather than
#' wrong.
#'
#' @inheritParams has_cjk
#' @param form One of `"nfc"`, `"nfd"`, `"nfkc"`, `"nfkd"` or
#'   `"nfkc_casefold"`. Defaults to `"nfc"`.
#' @param drop_variation_selectors Remove variation selectors before
#'   normalising. Defaults to `FALSE`.
#'
#' @return A character vector the same length as `x`. `NA` input gives `NA`;
#'   the empty string gives the empty string.
#' @seealso [to_halfwidth()] and [to_fullwidth()] for the width axis alone,
#'   [cjk_sort()] for comparison that ignores these differences without
#'   rewriting the text.
#' @examples
#' # the same syllable composed and decomposed, which nchar() can tell apart
#' both <- c("\u304c", "\u304b\u3099")
#' nchar(both)
#' nchar(cjk_normalize(both))
#'
#' # NFKC folds the width axis and more besides; NFC leaves both alone
#' cjk_normalize("\uff21\uff22\u3000\u2460", form = "nfkc")
#' cjk_normalize("\uff21\uff22\u3000\u2460", form = "nfc")
#'
#' # a compatibility ideograph is rewritten by plain NFC
#' sprintf("%X", utf8ToInt(cjk_normalize("\ufa0c")))
#'
#' # an ideographic variation sequence survives every form until dropped
#' ivs <- "\u8fbb\U000E0100"
#' nchar(cjk_normalize(ivs))
#' nchar(cjk_normalize(ivs, drop_variation_selectors = TRUE))
#' @export
cjk_normalize <- function(x, form = c("nfc", "nfd", "nfkc", "nfkd",
                                      "nfkc_casefold"),
                          drop_variation_selectors = FALSE) {
  form <- .cjk_arg_match(form, .CJK_NORM_FORMS, "form")
  if (!is.logical(drop_variation_selectors) ||
        length(drop_variation_selectors) != 1L ||
        is.na(drop_variation_selectors)) {
    stop("`drop_variation_selectors` must be TRUE or FALSE.", call. = FALSE)
  }
  x <- as.character(x)
  # Restores nothing on the current stringi, which already returns
  # character(0) here, and kept for the reason .cjk_trans_verb()'s identical
  # exit is kept: the contract is ours and the stringi version is unpinned.
  # The assumption is pinned by a test, so a change there surfaces as a
  # failure rather than as a verb quietly returning the wrong shape.
  if (length(x) == 0L) {
    return(character(0))
  }
  if (drop_variation_selectors) {
    x <- .cjk_stri(stringi::stri_replace_all_regex(
      x, "\\p{Variation_Selector}", ""
    ))
  }
  .cjk_stri(.cjk_norm_fn(form)(x))
}
