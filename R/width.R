# Display width, and the two operations that need it.
#
# nchar() counts characters; a terminal counts columns. A CJK ideograph is one
# character and two columns, which is why every console table containing CJK
# text comes out ragged.
#
# The width itself is stringi's: stri_width() implements Unicode Annex #11
# against ICU's live tables, so it does not go stale at each Unicode release
# and it already gets the awkward cases right (combining marks and format
# characters are zero, and so are Hangul Jamo medial vowels and final
# consonants, which compose onto a preceding syllable rather than occupying a
# column of their own). Re-deriving that from a hand-written range table would
# be slower, staler and less correct. What this file adds is the CJK-facing
# API: consistent naming, and a width-aware truncate, which stringi does not
# have.

# `width` validation, shared by cjk_pad() and cjk_truncate().
#
# as.integer() alone is too permissive: as.integer("abc") is a warning and an
# NA, so a typo would come back as missing output rather than as an error. A
# genuinely missing width still propagates as NA, which is what every other
# function in the package does with NA.
.cjk_as_width <- function(width) {
  if (length(width) == 0L) {
    stop("`width` must have at least one element.", call. = FALSE)
  }
  if (!is.numeric(width) && !all(is.na(width))) {
    stop("`width` must be numeric.", call. = FALSE)
  }
  # Inf and anything beyond the integer range are numeric, so they clear the
  # check above and then coerce to NA -- with a bare "NAs introduced by
  # coercion" warning that names no argument. That is the same silent
  # missing-output failure the check above exists to prevent, so reject them
  # here. `cjk_pad(x, Inf)` is a plausible way to write "do not truncate" and
  # it used to return a vector of NA. NA and NaN still pass and still
  # propagate, as missing input does everywhere else in the package.
  present <- width[!is.na(width)]
  if (any(!is.finite(present)) ||
      any(abs(as.numeric(present)) > .Machine$integer.max)) {
    stop("`width` must be finite and within integer range.", call. = FALSE)
  }
  as.integer(width)
}

# Length of `x` and `width` recycled together, or an error. stringi recycles a
# ragged pair with a warning and returns a partial result; for a layout
# function that is worse than refusing, because the caller gets a plausible
# vector of the wrong length.
.cjk_recycled_length <- function(x, width) {
  n <- max(length(x), length(width))
  if (n %% length(x) != 0L || n %% length(width) != 0L) {
    # The lengths are named, because they are the one thing the caller cannot
    # see: they come from data, not from something just typed at the console.
    stop("`x` (", length(x), ") and `width` (", length(width),
         ") must be recyclable to a common length.", call. = FALSE)
  }
  n
}


#' Display width in terminal columns
#'
#' `cjk_width()` returns the number of columns each string occupies in a
#' monospaced terminal. CJK characters occupy two columns, not one, which is
#' the reason `nchar()` misaligns every console table containing CJK text.
#'
#' @details
#' Width follows Unicode Annex #11 (East Asian Width). Characters whose East
#' Asian Width is Wide or Fullwidth are two columns; combining marks and format
#' characters (general categories `Mn`, `Me`, `Cf`), C0 and C1 control codes,
#' and Hangul Jamo medial vowels and final consonants are zero; the rest are
#' one. Treat that as the shape of the answer rather than the whole of it:
#' recent ICU also gives two columns to several thousand symbols and
#' pictographs that Annex #11 itself calls neutral or ambiguous. Where a layout
#' turns on one particular character, measure it rather than deriving it from
#' this list.
#'
#' The computation is [stringi::stri_width()], which reads the Unicode tables
#' shipped with [ICU](https://icu.unicode.org), the Unicode Consortium's C
#' library. `cjk_width()` exists so that the width, the padding and the
#' truncation in a CJK pipeline all read the same way; if width is all you
#' need, `stri_width()` is the more direct call.
#'
#' East Asian Ambiguous characters render as two columns in a CJK-configured
#' terminal and one everywhere else, and no library can resolve that without
#' being told which terminal it is writing to. `cjk_width()` reports whatever
#' the ICU build behind your \pkg{stringi} decided, and that answer has moved:
#' ICU once called the whole class one column, and now gives two to several
#' hundred of them, the box-drawing characters and the degree sign among them.
#' Greek and Cyrillic letters have stayed at one throughout.
#'
#' So which side a given ambiguous character falls on is a property of the
#' \pkg{stringi} build in front of you, not of this package, and not something
#' this page can usefully enumerate. Measure it with `cjk_width()` if it
#' matters, and keep ambiguous-width characters out of any table that has to
#' line up on someone else's machine.
#'
#' @param x A character vector. Anything else is coerced with
#'   [as.character()]. That coercion is R's, not this package's, so a
#'   numeric vector is measured as R chooses to write it -- which moves
#'   with `options(scipen)` and `options(OutDec)`, and can therefore
#'   differ between sessions. Convert deliberately if you mean to
#'   measure numbers; these verbs are for text.
#'
#' @return An integer vector the same length as `x`. `NA` input gives `NA`; the
#'   empty string gives `0`.
#' @seealso [cjk_pad()] and [cjk_truncate()], which lay text out by width;
#'   [stringi::stri_width()] for the underlying computation.
#' @examples
#' # two characters, four columns
#' cjk_width("\u4e2d\u6587")
#'
#' # two characters, two columns
#' cjk_width("ab")
#'
#' # nchar() cannot tell these apart; cjk_width() can
#' nchar(c("\u4e2d\u6587", "abcd"))
#' cjk_width(c("\u4e2d\u6587", "abcd"))
#' @export
cjk_width <- function(x) {
  x <- as.character(x)
  if (length(x) == 0L) {
    return(integer(0))
  }
  w <- .cjk_stri(stringi::stri_width(x))
  # stri_width() already answers NA for NA, so on the stringi in front of you
  # this line changes nothing. It stays because DESCRIPTION imports stringi
  # without a version: the NA contract in ?cjk_width is this package's promise
  # to keep, not a behaviour to inherit. A test pins what stringi currently
  # does, so a change there shows up as a failure rather than as silence.
  w[is.na(x)] <- NA_integer_
  as.integer(w)
}


#' Pad text to a display width
#'
#' `cjk_pad()` pads each string with a fill character until it occupies at
#' least `width` terminal columns. Unlike a pad that counts characters, it
#' produces columns that actually line up when the text is CJK.
#'
#' @inheritParams cjk_width
#' @param width Target display width in columns. Recycled against `x`; a pair
#'   of lengths that does not recycle cleanly is an error rather than a
#'   warning and a short result.
#' @param side Which side to add padding to: `"right"` (the default, which
#'   left-aligns the text), `"left"` or `"both"`.
#' @param pad A single character to pad with. Must be one column wide.
#'
#' @return A character vector the same length as the recycled inputs. Strings
#'   already at least `width` columns wide are returned unchanged --
#'   `cjk_pad()` never truncates. `NA` input, and an `NA` width, give `NA`.
#' @seealso [cjk_truncate()] for the other direction; [stringi::stri_pad()],
#'   which this wraps.
#' @examples
#' # both strings end up six columns wide
#' cjk_pad(c("\u4e2d\u6587", "abcd"), 6)
#'
#' # right-align instead
#' cjk_pad(c("\u4e2d\u6587", "abcd"), 6, side = "left")
#'
#' # a pad that counts characters rather than columns: nchar() calls the two
#' # strings 2 and 4 long, so the CJK cell is handed four spaces and comes out
#' # eight columns wide. (formatC() and format() are column-aware and get this
#' # right; sprintf("%-6s") counts bytes and under-fills instead.)
#' pad_by_char <- function(x, n) paste0(x, strrep(" ", pmax(n - nchar(x), 0)))
#' cat(paste0("|", pad_by_char(c("\u4e2d\u6587", "abcd"), 6), "|"), sep = "\n")
#' cat(paste0("|", cjk_pad(c("\u4e2d\u6587", "abcd"), 6), "|"), sep = "\n")
#' @export
cjk_pad <- function(x, width, side = "right", pad = " ") {
  x <- as.character(x)
  side <- match.arg(side, c("right", "left", "both"))
  if (!is.character(pad) || length(pad) != 1L || is.na(pad) ||
      nchar(pad) != 1L) {
    stop("`pad` must be a single, non-missing character.", call. = FALSE)
  }
  if (stringi::stri_width(pad) != 1L) {
    stop("`pad` must be one column wide.", call. = FALSE)
  }
  # Before the zero-length exit, so that a bad `width` is an error whatever the
  # length of `x` -- as `pad` already is. Otherwise cjk_pad(character(0), Inf)
  # returned quietly while cjk_pad("a", Inf) refused.
  width <- .cjk_as_width(width)
  if (length(x) == 0L) {
    return(character(0))
  }
  n <- .cjk_recycled_length(x, width)
  # stri_pad()'s `side` names the side the padding goes on, which is the same
  # convention as ours. Recycle here rather than leaving it to stringi, so that
  # a ragged pair is the error above rather than a warning and a short result.
  x <- rep_len(x, n)
  out <- .cjk_stri(stringi::stri_pad(x, width = rep_len(width, n),
                                     side = side, pad = pad))
  # stri_pad() strips one leading U+FEFF, reading it as a byte-order mark --
  # the same asymmetry .cjk_codepoints() works around, and unconditional here:
  # it happened even when the string was already wide enough and no padding was
  # added at all, so a documented no-op came back edited. The mark is zero
  # width, so putting it back cannot change the column count.
  lead_bom <- !is.na(x) & !is.na(out) & startsWith(x, "\uFEFF")
  if (any(lead_bom)) {
    out[lead_bom] <- paste0("\uFEFF", out[lead_bom])
  }
  out
}


#' Truncate text to a display width
#'
#' `cjk_truncate()` shortens each string so that it fits in `width` terminal
#' columns, appending an ellipsis when anything was removed. Because CJK
#' characters are two columns wide, truncating by character count overshoots
#' the available space by up to a factor of two.
#'
#' @details
#' The result is never wider than `width`. When a string has to be shortened,
#' the ellipsis is included in the budget, so the kept text is trimmed to
#' `width - cjk_width(ellipsis)` columns. If `width` is too small even for the
#' ellipsis, the ellipsis itself is truncated.
#'
#' Cuts never separate a combining mark from the character it modifies: a
#' zero-width character immediately after the cut point is carried along with
#' it.
#'
#' @inheritParams cjk_width
#' @param width Maximum display width in columns. Recycled against `x`; a pair
#'   of lengths that does not recycle cleanly is an error.
#' @param ellipsis String to append when the text was shortened. Defaults to
#'   `"..."`. The single-character ellipsis U+2026 is one column rather than
#'   three, so more of the text survives.
#'
#' @return A character vector the same length as the recycled inputs. Strings
#'   that already fit are returned unchanged. `NA` input, and an `NA` width,
#'   give `NA`.
#' @seealso [cjk_pad()] for the other direction; [cjk_width()] for the measure
#'   both use.
#' @examples
#' # six columns is three ideographs
#' cjk_truncate("\u4e2d\u6587\u4e2d\u6587\u4e2d\u6587", 6)
#'
#' # ASCII, same budget
#' cjk_truncate("abcdefghij", 6)
#'
#' # already fits, so nothing happens
#' cjk_truncate("\u4e2d\u6587", 10)
#' @export
cjk_truncate <- function(x, width, ellipsis = "...") {
  x <- as.character(x)
  if (!is.character(ellipsis) || length(ellipsis) != 1L || is.na(ellipsis)) {
    stop("`ellipsis` must be a single, non-missing string.", call. = FALSE)
  }
  # Validated ahead of the zero-length exit, for the reason given in cjk_pad().
  width <- .cjk_as_width(width)
  if (length(x) == 0L) {
    return(character(0))
  }
  n <- .cjk_recycled_length(x, width)
  x <- rep_len(x, n)
  width <- rep_len(width, n)

  ell_w <- as.integer(stringi::stri_width(ellipsis))
  full_w <- cjk_width(x)
  # Split to code points once for the whole vector, as the width above already
  # is. .cjk_codepoints() is vectorised but carries a fixed per-call cost -- an
  # encoding-error handler and a byte-order-mark scan -- and calling it from
  # inside the loop paid that cost once per element instead of once per vector.
  # Measured on 50,000 strings that was about a third of cjk_truncate()'s total
  # time, for no answer that differs.
  #
  # Conditional, because a column that all fits never needs the code points at
  # all and splitting it anyway was slower than the per-element version it
  # replaced. Only an element wider than its budget reaches cps[[i]], and that
  # is exactly what makes this any() true, so the NULL can never be indexed.
  shorten <- !is.na(full_w) & !is.na(width) & full_w > width
  cps <- if (any(shorten)) .cjk_codepoints(x) else NULL
  ell_cp <- .cjk_codepoints(ellipsis)[[1L]]

  vapply(seq_len(n), function(i) {
    s <- x[[i]]
    w <- width[[i]]
    if (is.na(s) || is.na(w)) {
      return(NA_character_)
    }
    # The fit test comes first, ahead of the non-positive-width shortcut. A
    # string of nothing but zero-width characters -- a combining mark, a format
    # character, a lone byte-order mark -- occupies no columns and therefore
    # fits in nought of them, and "strings that already fit are returned
    # unchanged" has to hold there too. The other order answered "" for
    # cjk_truncate("\uFEFF", 0), deleting a character while promising not to.
    if (!is.na(full_w[[i]]) && full_w[[i]] <= w) {
      return(s)
    }
    if (w <= 0L) {
      return("")
    }
    if (w < ell_w) {
      # No room for the marker itself; trim the marker to the budget.
      return(.cjk_take_width(ell_cp, w))
    }
    paste0(.cjk_take_width(cps[[i]], w - ell_w), ellipsis)
  }, character(1))
}

# Longest prefix of the code points `cp` that fits in `w` columns.
#
# Cumulative width is non-decreasing, so counting the positions that stay
# within budget gives the prefix length directly. That also means a combining
# mark can never be orphaned: it adds nothing to the running total, so if its
# base character fit then so does the mark.
#
# Takes code points rather than a string because the caller splits the whole
# vector in one pass; see the hoist in cjk_truncate(). The split is by code
# point, via the same UTF-32 round trip the rest of the package uses.
# strsplit(s, "") would be the obvious way to do it and is wrong here: on a
# string R has not marked as UTF-8 it splits bytes rather than characters, so
# the same call gives a different answer in a non-UTF-8 locale.
.cjk_take_width <- function(cp, w) {
  if (w <= 0L) {
    return("")
  }
  if (is.null(cp) || length(cp) == 0L) {
    return("")
  }
  chars <- stringi::stri_enc_fromutf32(as.list(cp))
  keep <- sum(cumsum(as.integer(stringi::stri_width(chars))) <= w)
  if (keep == 0L) {
    return("")
  }
  stringi::stri_enc_fromutf32(list(cp[seq_len(keep)]))
}
