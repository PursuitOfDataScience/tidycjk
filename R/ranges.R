# The Unicode block table, and the vectorised code-point lookup that every
# other file in the package is built on.
#
# The table is sorted by `start` and has no overlapping ranges, which is what
# lets findInterval() resolve a whole corpus of code points in one pass. A
# per-character regex would be correct but unusably slow on a real column of
# text, so the invariants above are load-bearing: .cjk_block_index() is wrong
# if the table is ever left unsorted or allowed to overlap. There is a test
# that asserts both.
#
# Two ranges in the specification overlap: Halfwidth Katakana (U+FF65-U+FF9F)
# sits inside Halfwidth and Fullwidth Forms (U+FF00-U+FFEF). The katakana is
# the more informative label, so the enclosing block is split around it.
#
# The ideographic extensions are NOT in alphabetical order and must not be put
# into it: Unicode allocated Extension I (U+2EBF0) in the gap left below
# Extension G (U+30000), so code point order puts I before G and H. Sorting the
# table by name would break the findInterval() invariant above.

# The table is a constant, but .cjk_block_index() is called once per element of
# the input vector, so rebuilding it there means rebuilding it for every string
# in the corpus. Building it once and caching it is the difference between a
# constant cost and a per-element one.
.cjk_cache <- new.env(parent = emptyenv())

.cjk_ranges <- function() {
  cached <- .cjk_cache$ranges
  if (!is.null(cached)) {
    return(cached)
  }
  # start, end, block, script -- ascending by start, no overlaps.
  m <- rbind(
    c(0x1100,  0x11FF),
    c(0x3000,  0x303F),
    c(0x3040,  0x309F),
    c(0x30A0,  0x30FF),
    c(0x3100,  0x312F),
    c(0x3130,  0x318F),
    c(0x3190,  0x319F),
    c(0x31F0,  0x31FF),
    c(0x3400,  0x4DBF),
    c(0x4E00,  0x9FFF),
    c(0xA960,  0xA97F),
    c(0xAC00,  0xD7A3),
    c(0xD7B0,  0xD7FF),
    c(0xF900,  0xFAFF),
    c(0xFF00,  0xFF64),
    c(0xFF65,  0xFF9F),
    c(0xFFA0,  0xFFEF),
    c(0x20000, 0x2A6DF),
    c(0x2A700, 0x2B73F),
    c(0x2B740, 0x2B81F),
    c(0x2B820, 0x2CEAF),
    c(0x2CEB0, 0x2EBEF),
    c(0x2EBF0, 0x2EE5F),
    c(0x2F800, 0x2FA1F),
    c(0x30000, 0x3134F),
    c(0x31350, 0x323AF)
  )
  tab <- list(
    start = m[, 1],
    end = m[, 2],
    block = c(
      "Hangul Jamo",
      "CJK Symbols and Punctuation",
      "Hiragana",
      "Katakana",
      "Bopomofo",
      "Hangul Compatibility Jamo",
      "Kanbun",
      "Katakana Phonetic Extensions",
      "CJK Unified Ideographs Extension A",
      "CJK Unified Ideographs",
      "Hangul Jamo Extended-A",
      "Hangul Syllables",
      "Hangul Jamo Extended-B",
      "CJK Compatibility Ideographs",
      "Halfwidth and Fullwidth Forms",
      "Halfwidth Katakana",
      "Halfwidth and Fullwidth Forms",
      "CJK Unified Ideographs Extension B",
      "CJK Unified Ideographs Extension C",
      "CJK Unified Ideographs Extension D",
      "CJK Unified Ideographs Extension E",
      "CJK Unified Ideographs Extension F",
      "CJK Unified Ideographs Extension I",
      "CJK Compatibility Ideographs Supplement",
      "CJK Unified Ideographs Extension G",
      "CJK Unified Ideographs Extension H"
    ),
    script = c(
      "hangul",
      "punctuation",
      "hiragana",
      "katakana",
      "bopomofo",
      "hangul",
      "kanbun",
      "katakana",
      "han",
      "han",
      "hangul",
      "hangul",
      "hangul",
      "han",
      "fullwidth",
      "katakana",
      "fullwidth",
      "han",
      "han",
      "han",
      "han",
      "han",
      "han",
      "han",
      "han",
      "han"
    )
  )
  .cjk_cache$ranges <- tab
  tab
}

# Vectorised code point -> row of .cjk_ranges(). NA where the code point is
# outside every block. This is the one place findInterval() is called.
.cjk_block_index <- function(cp) {
  tab <- .cjk_ranges()
  out <- rep(NA_integer_, length(cp))
  if (length(cp) == 0L) {
    return(out)
  }
  idx <- findInterval(cp, tab$start)
  hit <- !is.na(idx) & idx > 0L
  hit[hit] <- !is.na(cp[hit]) & cp[hit] <= tab$end[idx[hit]]
  out[hit] <- idx[hit]
  out
}

# Split a character vector into code points. Returns a list parallel to `x`;
# an NA string becomes NULL, an empty string becomes integer(0). Everything
# downstream distinguishes those two cases, so the difference matters.
.cjk_codepoints <- function(x) {
  x <- as.character(x)
  if (length(x) == 0L) {
    return(list())
  }
  cps <- stringi::stri_enc_toutf32(x)
  # stri_enc_toutf32() maps NA to NULL; normalise anything else that is not a
  # plain integer vector to NULL as well, so callers only handle one shape.
  lapply(seq_along(cps), function(i) {
    v <- cps[[i]]
    if (is.null(v) || is.na(x[[i]])) NULL else as.integer(v)
  })
}

# Per-string script vector, NA for non-CJK characters. Used by cjk_script(),
# cjk_detect_language() and cjk_char_counts().
.cjk_scripts_of <- function(cp) {
  idx <- .cjk_block_index(cp)
  .cjk_ranges()$script[idx]
}


#' The Unicode blocks 'tidycjk' recognises
#'
#' `cjk_blocks()` returns the block table that every other function in the
#' package consults. It is the package's definition of "CJK", written down and
#' exported so that it can be inspected rather than guessed at.
#'
#' @details
#' The table is sorted by `start` and contains no overlapping ranges, which is
#' what allows a whole corpus of code points to be classified with a single
#' [findInterval()] call rather than a per-character regular expression.
#'
#' Two of the rows deserve comment. Halfwidth Katakana (U+FF65-U+FF9F) is a
#' sub-range of the Halfwidth and Fullwidth Forms block; because the katakana
#' label is the more useful one, the enclosing block appears as two rows either
#' side of it. And the halfwidth Hangul jamo at U+FFA0-U+FFDC are reported as
#' `"fullwidth"` rather than `"hangul"`, because this table follows the block
#' boundaries rather than the Unicode Script property; use [cjk_char_counts()]
#' if you need to see exactly which code points a text contains.
#'
#' All nine blocks of unified ideographs are covered, through Extension I. They
#' are not in alphabetical order, because Unicode allocated Extension I
#' (U+2EBF0) below Extension G (U+30000) rather than after Extension H, and
#' this table is in code point order.
#'
#' The `script` column takes one of eight values. Six of them name a writing
#' system -- `"han"`, `"hiragana"`, `"katakana"`, `"hangul"`, `"bopomofo"`,
#' `"kanbun"` -- and two are ancillary: `"punctuation"` for the CJK Symbols and
#' Punctuation block, and `"fullwidth"` for the width-variant forms. Only the
#' six writing systems are consulted by [cjk_detect_language()].
#'
#' @return A tibble with one row per block and columns `block` (the Unicode
#'   block name), `script` (tidycjk's script label), `start` and `end` (the
#'   inclusive code point bounds, as integers) and `n_codepoints`.
#' @seealso [cjk_script()] for the dominant script of a string,
#'   [cjk_char_counts()] for a per-character breakdown.
#' @examples
#' cjk_blocks()
#'
#' # the blocks that make up "han"
#' subset(cjk_blocks(), script == "han")
#' @export
cjk_blocks <- function() {
  tab <- .cjk_ranges()
  tibble::tibble(
    block = tab$block,
    script = tab$script,
    start = as.integer(tab$start),
    end = as.integer(tab$end),
    n_codepoints = as.integer(tab$end - tab$start + 1)
  )
}
