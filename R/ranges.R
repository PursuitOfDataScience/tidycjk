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
# Some blocks are split into more than one row, because a row carries one
# script label and these blocks hold two. The halfwidth katakana
# (U+FF65-U+FF9F) sit inside the Halfwidth and Fullwidth Forms block
# (U+FF00-U+FFEF), and the katakana is the more informative label, so the
# enclosing block is split around it. The kana extension blocks are split where
# Unicode's Script property changes between hiragana and katakana: Kana
# Supplement after its first code point, Kana Extended-A at U+1B120 and Small
# Kana Extension at U+1B155. One code point lands on the wrong side: U+1B123,
# HIRAGANA DIGRAPH KOTO, which Unicode 18.0 placed among the katakana of Kana
# Extended-A. Splitting a row out for one archaic digraph is not worth it, and
# for language detection the two labels mean the same thing.
#
# A script that has an extension block needs every one of them, or the verbs
# answer FALSE for a real character: Bopomofo Extended (U+31A0-U+31BF) holds 32
# of the 75 bopomofo letters Unicode has assigned so far, so omitting it made
# has_cjk() wrong for the Minnan and Hakka letters, and the four kana extension
# blocks (hentaigana, archaic and small kana, the Minnan tone letters) were
# missing for the same reason until 0.2.0. Blocks holding radicals, strokes or
# circled and squared compatibility symbols are deliberately out of scope;
# see ?cjk_blocks.
#
# The ideographic extensions are NOT in alphabetical order and must not be put
# into it: Unicode allocated Extension I (U+2EBF0) in the gap left below
# Extension G (U+30000), so code point order puts I before G and H. Sorting the
# table by name would break the findInterval() invariant above.
#
# The table is current to Unicode 18.0, which added no block in scope here;
# Extension J (U+323B0-U+3347F) arrived in 17.0. data-raw/verify-tables.py is
# the cross-check to run after each Unicode release.
#
# Every range is a Unicode block bound, or a split inside one, except Hangul
# Syllables, which stops at U+D7A3 rather than U+D7AF because U+D7A4-U+D7AF are
# unassigned. Do not "correct" that to the block bound; see ?cjk_blocks.

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
    c(0x31A0,  0x31BF),
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
    c(0x1AFF0, 0x1AFFF),
    c(0x1B000, 0x1B000),
    c(0x1B001, 0x1B0FF),
    c(0x1B100, 0x1B11F),
    c(0x1B120, 0x1B12F),
    c(0x1B130, 0x1B154),
    c(0x1B155, 0x1B16F),
    c(0x20000, 0x2A6DF),
    c(0x2A700, 0x2B73F),
    c(0x2B740, 0x2B81F),
    c(0x2B820, 0x2CEAF),
    c(0x2CEB0, 0x2EBEF),
    c(0x2EBF0, 0x2EE5F),
    c(0x2F800, 0x2FA1F),
    c(0x30000, 0x3134F),
    c(0x31350, 0x323AF),
    c(0x323B0, 0x3347F)
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
      "Bopomofo Extended",
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
      "Kana Extended-B",
      "Kana Supplement",
      "Kana Supplement",
      "Kana Extended-A",
      "Kana Extended-A",
      "Small Kana Extension",
      "Small Kana Extension",
      "CJK Unified Ideographs Extension B",
      "CJK Unified Ideographs Extension C",
      "CJK Unified Ideographs Extension D",
      "CJK Unified Ideographs Extension E",
      "CJK Unified Ideographs Extension F",
      "CJK Unified Ideographs Extension I",
      "CJK Compatibility Ideographs Supplement",
      "CJK Unified Ideographs Extension G",
      "CJK Unified Ideographs Extension H",
      "CJK Unified Ideographs Extension J"
    ),
    script = c(
      "hangul",
      "punctuation",
      "hiragana",
      "katakana",
      "bopomofo",
      "hangul",
      "kanbun",
      "bopomofo",
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
      "katakana",
      "katakana",
      "hiragana",
      "hiragana",
      "katakana",
      "hiragana",
      "katakana",
      "han",
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
  # findInterval() maps NA and NaN to NA, so !is.na(idx) has already excluded
  # every missing code point and the is.na() below cannot fire. It stays as a
  # guard on the subscripted assignment rather than on the lookup: an NA
  # reaching `hit` would make the out[hit] assignment error rather than return
  # NA, and NA in, NA out is what every verb in the package promises.
  hit[hit] <- !is.na(cp[hit]) & cp[hit] <= tab$end[idx[hit]]
  out[hit] <- idx[hit]
  out
}

# Run a stringi call on user text and translate the one error it is likely to
# raise.
#
# stringi reports mis-encoded input as "invalid UTF-8 byte sequence detected;
# try calling stri_enc_toutf8()" -- naming a function the caller never called,
# in a package they may not know they are using. Every exported function here
# reaches stringi eventually, so every one of them surfaced that. A column read
# out of a file written in a legacy CJK encoding, without that encoding being
# named, is much the likeliest way to arrive here, and saying so states the fix
# as well as the fault. Anything else stringi raises is re-thrown untouched,
# so this cannot relabel an unrelated failure.
.cjk_stri <- function(expr, name = "x") {
  tryCatch(expr, error = function(e) {
    if (!grepl("UTF-8", conditionMessage(e), fixed = TRUE)) {
      stop(e)
    }
    stop("`", name, "` must be valid UTF-8. Text read from a file written in ",
         "a legacy CJK encoding (GBK, Big5, Shift_JIS, EUC-KR) needs that ",
         "encoding named when the file is read, or converting afterwards ",
         "with stringi::stri_encode().", call. = FALSE)
  })
}

# Refuse text that cannot be decoded, before any verb does work on it.
#
# Left to stringi, undecodable bytes were reported five different ways
# depending on which entry point a verb happened to reach first: our message
# from the code-point verbs, U+FFFD replacement characters from the ICU
# transforms, the raw bytes handed back by cjk_sentences() and cjk_sort(), a
# bare "invalid multibyte string" from nchar() in cjk_wrap(), and the bad byte
# silently dropped by the "icu" engine. Only the first is an answer. So every
# verb now checks once, on the way in, with a call that raises on invalid
# UTF-8 (stri_length() does; stri_numbytes() and stri_enc_isutf8() do not), and
# the message names the argument.
#
# What counts as undecodable still depends on the session, and has to: the
# same GBK bytes are invalid UTF-8 in a UTF-8 locale and ordinary native text
# in a GB18030 one. A string marked "bytes" is refused outright, because
# stringi cannot read one at all and its own message says only that the
# encoding is unsupported.
.cjk_check_encoding <- function(x, name = "x") {
  if (length(x) == 0L) {
    return(invisible(x))
  }
  if (any(Encoding(x) == "bytes")) {
    stop("`", name, "` is marked as \"bytes\", so its characters cannot be ",
         "read. Declare the encoding it was written in, with iconv() or ",
         "stringi::stri_encode(), before passing it here.", call. = FALSE)
  }
  .cjk_stri(stringi::stri_length(x), name)
  invisible(x)
}

# Coerce the text argument, rejecting what as.character() would deparse.
#
# Every verb here starts by coercing `x`, which lets a numeric or a factor
# column through and is deliberate. But as.character() does not coerce a
# list, it *deparses* it: cjk_width(list(c("a", "b"))) answered 11, the
# display width of the eleven-character string `c("a", "b")` -- R source code
# measured as if it were text, with no error and no warning. cjk_segment()
# already caught exactly this for what an engine returns; this is the same
# check for what a caller passes in, which is the likelier direction. The
# list a caller has in hand is usually another verb's output --
# cjk_jamo(), cjk_sentences() and cjk_segment() all return one -- so the
# message names the two ways out rather than only the fault.
#
# NULL is admitted explicitly: is.atomic(NULL) was TRUE until R 4.4.0 and is
# FALSE after it, and `character(0)` in, `character(0)` out has to hold on
# both sides of that change.
.cjk_as_text <- function(x, name = "x") {
  if (!is.null(x) && !is.atomic(x)) {
    stop("`", name, "` must be an atomic vector, not ", class(x)[[1L]],
         ". as.character() deparses a list rather than coercing it, so the ",
         "text measured would have been the R code that builds it. Use ",
         "unlist() to flatten it, or vapply(x, paste, character(1), ",
         "collapse = \"\") to keep one string per element.", call. = FALSE)
  }
  x <- as.character(x)
  .cjk_check_encoding(x, name)
  x
}

# One place to match an enumerated argument.
#
# match.arg() names a variable the caller never wrote: a value that is not
# character at all is "'arg' must be NULL or a character vector", and a string
# that matches no choice is "'arg' should be one of ...", with match.arg()'s
# own call attached. Every other argument in this package is rejected by
# name, so the two enumerated ones are held to the same standard. The
# matching itself stays match.arg's, including its partial matching and its
# NULL-means-the-first-choice contract, so only the message changes and no
# accepted value becomes rejected. (The first version of this guard caught
# only the non-character case, so `side = "top"` still reached the reader as
# 'arg'.)
.cjk_arg_match <- function(value, choices, name) {
  refuse <- function() {
    stop("`", name, "` must be one of ",
         paste0("\"", choices, "\"", collapse = ", "), ".", call. = FALSE)
  }
  if (!is.null(value) && (!is.character(value) || anyNA(value))) {
    refuse()
  }
  tryCatch(match.arg(value, choices), error = function(e) refuse())
}

# ICU falls back to the root locale when it has no data for the one asked
# for, and the fallback is a different answer wearing the right answer's
# clothes: a sort that is not by pronunciation, a break iterator that is not
# the style you named. Every verb here that takes a `locale` routes through
# this, so a typo is an error in all of them rather than in one.
#
# The check is on the language subtag, looked up in ICU's own locale list,
# rather than on the warning stringi emits. That warning is not dependable:
# stringi 1.8.7 raises "resource bundle lookup ..." for an unknown locale and
# stringi 1.6.2 raises nothing at all, so a guard built on it was silently
# inert on older installations -- which is the very failure it exists to
# prevent. stri_locale_list() is present in both and agrees on every case.
#
# Only the language is checked. An unrecognised region resolves to the
# language and still gives the right answer -- "zh-CH", a typo for "zh-CN",
# sorts by pinyin -- and BCP 47 extensions such as "zh-u-co-stroke" and
# "ja@lb=strict" are the documented way to pick a variant, so neither may be
# rejected. The language is compared without case, because BCP 47 subtags are
# case-insensitive and ICU treats them so: "ZH" and "Zh-Hant" sort exactly as
# "zh" and "zh-Hant" do. "root" and "und" are ICU's names for the root locale
# itself, so asking for one by name is not the fallback this guard prevents.
#
# `locale = NULL` means the session default and is not checked; that is not
# the caller's typo to answer for. stringi reads "" the same way, so it is
# treated as NULL rather than reported as a locale ICU lacks.
#
# The check runs before a verb does anything else, the zero-length and all-NA
# exits included, so a bad locale is an error whatever the length of `x`;
# checking inside the call to stringi let cjk_sort(character(0), locale =
# "xx") and cjk_wrap(NA, 5, locale = "xx") through.
.cjk_locale_langs <- local({
  langs <- NULL
  function() {
    if (is.null(langs)) {
      langs <<- unique(tolower(sub("[-_@].*$", "",
                                   stringi::stri_locale_list())))
    }
    langs
  }
})

.cjk_check_locale <- function(locale, what, hint) {
  if (is.null(locale)) {
    return(NULL)
  }
  if (!is.character(locale) || length(locale) != 1L || is.na(locale)) {
    stop("`locale` must be a single string, or NULL.", call. = FALSE)
  }
  if (!nzchar(locale)) {
    return(NULL)
  }
  lang <- tolower(sub("[-_@].*$", "", locale))
  if (!(lang %in% c(.cjk_locale_langs(), "root", "und"))) {
    stop("ICU has no ", what, " for locale \"", locale, "\". It would fall ",
         "back to the root locale, which is a different answer that looks ",
         "like the one you asked for. ", hint, call. = FALSE)
  }
  locale
}

# How many U+FEFF each element begins with.
#
# Several stringi entry points -- stri_enc_toutf32(), stri_sort(), stri_wrap(),
# stri_split_boundaries(), stri_sub() -- read a *leading* U+FEFF as a
# byte-order mark and drop it. .cjk_codepoints() works around it for the verbs
# that go through code points; the verbs that call stringi directly need the
# same guard, or they silently delete a character from text they promised only
# to reorder, re-flow or divide.
#
# The whole leading run is counted rather than a single mark. Removing one
# from "\uFEFF\uFEFF" leaves another for stringi to drop in turn, so a
# one-for-one patch was still short by one.
#
# base regexpr(), not a stringi matcher: stringi strips the mark from the
# *pattern* too, so a pattern of U+FEFF alone arrives empty and is rejected.
# The detector must not be built out of the thing doing the stripping.
.cjk_leading_bom <- function(x) {
  n <- integer(length(x))
  ok <- !is.na(x)
  if (any(ok)) {
    n[ok] <- attr(regexpr("^\uFEFF*", x[ok], useBytes = FALSE),
                  "match.length")
  }
  n
}

.cjk_strip_bom <- function(x, n) {
  hit <- !is.na(x) & n > 0L
  if (any(hit)) x[hit] <- substring(x[hit], n[hit] + 1L)
  x
}

.cjk_restore_bom <- function(x, n) {
  hit <- !is.na(x) & n > 0L
  if (any(hit)) x[hit] <- paste0(strrep("\uFEFF", n[hit]), x[hit])
  x
}

# Split a character vector into code points. Returns a list parallel to `x`;
# an NA string becomes NULL, an empty string becomes integer(0). Everything
# downstream distinguishes those two cases, so the difference matters.
.cjk_codepoints <- function(x) {
  x <- .cjk_as_text(x)
  if (length(x) == 0L) {
    return(list())
  }
  cps <- .cjk_stri(stringi::stri_enc_toutf32(x))
  # stri_enc_toutf32() reads a *leading* U+FEFF as a byte-order mark and drops
  # it, so the character never reaches anything downstream. That is not a
  # hypothetical input: Excel on Windows writes UTF-8 CSVs with a BOM, and
  # read.csv() hands the mark back on the first field of the first row. The
  # consequences were a wrong number and a silent edit -- cjk_ratio() answered
  # 1 for "\uFEFF\u4E2D", a two-character string only half of which is CJK, and
  # to_halfwidth() deleted the mark outright, against a documented promise to
  # change width and nothing else.
  #
  # A U+FEFF anywhere but the front is kept, so prefixing one character makes
  # stringi keep this one too; the placeholder is then dropped again. The
  # detection is one vectorised pass and only the affected elements are
  # re-converted, so an ordinary corpus pays almost nothing. Testing after the
  # conversion above means the string is already known to be valid UTF-8.
  #
  # The test has to be base startsWith(), not stri_startswith_fixed(): stringi
  # strips the leading BOM from the *pattern* as well, so a pattern of U+FEFF
  # alone arrives empty, which stringi rejects with a warning and an NA. That
  # NA then reaches the if() below as `any(NA)` and errors out. The trap is the
  # very behaviour this block exists to work around, so the detector must not
  # be built out of the thing doing it.
  lead_bom <- !is.na(x) & startsWith(x, "\uFEFF")
  if (any(lead_bom)) {
    kept <- .cjk_stri(stringi::stri_enc_toutf32(paste0(" ", x[lead_bom])))
    cps[lead_bom] <- lapply(kept, function(v) v[-1L])
  }
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
#' A block appears as more than one row where a single script label would be
#' wrong for part of it. Halfwidth Katakana (U+FF65-U+FF9F) is a sub-range of
#' the Halfwidth and Fullwidth Forms block; because the katakana label is the
#' more useful one, the enclosing block appears as two rows either side of it.
#' Kana Supplement, Kana Extended-A and Small Kana Extension each hold both
#' hiragana and katakana, so each is split where the script changes.
#' Otherwise the labels follow block boundaries rather than the Unicode Script
#' property: the halfwidth Hangul jamo at U+FFA0-U+FFDC are reported as
#' `"fullwidth"` rather than `"hangul"`, and the one hiragana digraph among the
#' katakana of Kana Extended-A (U+1B123) as `"katakana"`. Use
#' [cjk_char_counts()] if you need to see exactly which code points a text
#' contains.
#'
#' All eleven blocks of unified ideographs are covered: the base block and
#' Extensions A through J. They are not in alphabetical order, because Unicode
#' allocated Extension I (U+2EBF0) below Extension G (U+30000) rather than after
#' Extension H, and this table is in code point order.
#'
#' The table is current to Unicode 18.0. A block Unicode adds after that is
#' not here until the table is updated, and [has_cjk()] answers `FALSE` for its
#' characters in the meantime; that is how Extension J, added in Unicode 17.0,
#' came to be missing from 0.1.0.
#'
#' Ranges are Unicode block bounds, with one exception. Hangul Syllables stops
#' at U+D7A3, the last assigned syllable, rather than at U+D7AF where the block
#' ends; the twelve code points in between are unassigned, and calling them
#' hangul would be reporting text that cannot exist. Elsewhere the block bound
#' is used as-is, so a handful of unassigned code points inside a covered block
#' (U+3100 to U+3104 at the head of Bopomofo, for instance) do count.
#'
#' Each phonetic script is covered in full, extension blocks included: Bopomofo
#' Extended (U+31A0-U+31BF) alongside Bopomofo, and the hentaigana, archaic and
#' small kana and the Minnan tone letters of Kana Supplement, Kana Extended-A,
#' Kana Extended-B and Small Kana Extension alongside Hiragana and Katakana.
#' What is deliberately absent is everything that is neither a letter, an
#' ideograph, CJK punctuation nor a width variant: the radical blocks
#' (U+2E80-U+2EFF and the Kangxi radicals at U+2F00-U+2FDF), CJK Strokes
#' (U+31C0-U+31EF) and the Ideographic Description Characters (U+2FF0-U+2FFF);
#' the vertical presentation forms in Vertical Forms (U+FE10-U+FE1F) and CJK
#' Compatibility Forms (U+FE30-U+FE4F); and the parenthesised, circled and
#' squared compatibility symbols in Enclosed CJK Letters and Months, CJK
#' Compatibility and Enclosed Ideographic Supplement. Those are typographic
#' presentation forms rather than text, and counting them as CJK would inflate
#' [cjk_ratio()] on a column that contains no CJK writing at all. Also outside
#' are the specialist marks of Ideographic Symbols and Punctuation
#' (U+16FE0-U+16FFF), and the two bopomofo tone marks Unicode placed in
#' Spacing Modifier Letters, U+02EA and U+02EB, far from any CJK block.
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
