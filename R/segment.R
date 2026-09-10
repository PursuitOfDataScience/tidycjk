# Segmentation: splitting CJK text into words.
#
# This is the problem the package is named for, and the one piece of it that
# cannot be derived from the Unicode specification. Where a word begins and
# ends in CJK text is a statistical question about a language, not a property
# of a code point, so it needs a dictionary and a model. That is a heavy
# dependency, and which one is right depends on the language and the corpus.
#
# So the engine is pluggable. cjk_segment() dispatches on a name, the built-in
# engines are registered here, and register_cjk_segmenter() lets a caller add
# their own without waiting for this package to grow support for it. An engine
# is any function of (x, ...) returning a list of character vectors, parallel
# to x.
#
# Two engines ship with the package. "icu" is a real word segmenter, from the
# dictionaries ICU carries inside stringi; "character" is the dictionary-free
# baseline. `engine` still has no default, because the right answer depends on
# the language: "character" answers a different question from the one a
# caller asking for words is asking, and handing back its output silently is
# the mistake this package exists to avoid. Rather than guess, the choice is
# required. ?cjk_segmenters shows how to register jiebaR or gibasa as well.

# User-registered engines. Built-ins are not kept here, so a caller can shadow
# one deliberately but cannot delete it by accident.
.cjk_engine_registry <- new.env(parent = emptyenv())


# --- built-in engines -------------------------------------------------------

# The dictionary-free baseline: every CJK character is its own token, and each
# run of non-CJK text is split on whitespace; whitespace itself never survives
# as a token. It needs nothing and it is honest about what it is -- character
# tokenisation, not word segmentation.
# For Chinese it will split a two-character word in half, which is the very
# thing a real segmenter exists to prevent; for Japanese and Korean it is
# further off still. Use it as a baseline, or when a per-character unit is
# what you actually want.
.cjk_engine_character <- function(x, ...) {
  lapply(.cjk_codepoints(x), function(cp) {
    if (is.null(cp)) {
      return(NA_character_)
    }
    if (length(cp) == 0L) {
      return(character(0))
    }
    # U+3000, the ideographic space, sits in the CJK Symbols and Punctuation
    # block, so on the plain block test it became a token of its own: a space
    # counted as a word, while the ASCII space next to it was dropped. It is
    # the only whitespace code point in any block cjk_blocks() lists, so
    # excluding it here is enough to send it down the non-CJK branch, where
    # the whitespace split below removes it like any other space.
    is_cjk <- !is.na(.cjk_block_index(cp)) & cp != 0x3000L
    # group into maximal runs: each CJK character alone, each non-CJK run whole
    run <- cumsum(c(TRUE, is_cjk[-1] | is_cjk[-length(is_cjk)]))
    # One stringi call for the whole set of runs rather than one per run:
    # stri_enc_fromutf32() already maps a list of code point vectors to a
    # character vector, which is exactly what the vapply was assembling.
    pieces <- stringi::stri_enc_fromutf32(split(cp, run))
    # And the run's CJK-ness is is_cjk at the run's first position, which
    # !duplicated() picks out directly -- `run` is non-decreasing, so first
    # occurrences come out in run order. Which position is read does not
    # actually matter: a run is either one CJK character alone or a maximal
    # non-CJK stretch, so is_cjk is constant within it. The grouping above is
    # what guarantees that, and it is what this line depends on.
    #
    # Dropping the second split() is the point: split() coerces the run ids to
    # a factor, which sorts and stringifies them once per string, and profiling
    # a corpus of 30,000 put split()/as.factor() at about a third of the total.
    cjk_piece <- is_cjk[!duplicated(run)]
    out <- unlist(lapply(seq_along(pieces), function(i) {
      if (cjk_piece[[i]]) {
        pieces[[i]]
      } else {
        # stringi rather than strsplit(x, "[[:space:]]+"): TRE resolves
        # [[:space:]] through the C library's iswspace(), which calls U+3000
        # a space in a UTF-8 locale and not in a C one, so the same input
        # tokenised differently on two machines. ICU's WHITE_SPACE is the same
        # set everywhere, which is the property the rest of the package holds
        # to -- see the note on strsplit() in .cjk_take_width().
        unlist(
          stringi::stri_split_charclass(pieces[[i]], "\\p{WHITE_SPACE}",
                                        omit_empty = TRUE),
          use.names = FALSE
        )
      }
    }), use.names = FALSE)
    if (is.null(out)) character(0) else out
  })
}

# ICU's dictionary-based word segmenter, reached through stringi. This is a
# real segmenter -- it splits a six-character Chinese sentence into its four
# words rather than into
# six characters -- and it costs no new dependency, because stringi is already
# an Import and ICU ships the Chinese and Japanese dictionaries inside it.
#
# That is worth stating plainly, because the package shipped 0.1.0 saying no
# segmenter could be bundled. jiebaR being archived from CRAN was true and is
# still true; the error was concluding from it that there was no bundled
# option at all, when the one already linked into a hard dependency had been
# there the whole time.
#
# It is not a replacement for a language-specific analyser. ICU's model is
# lighter than MeCab's for Japanese and than jieba's tuned dictionaries for
# Chinese, it returns surface forms with no part of speech or lemma, and it
# takes no user dictionary. It is the right default and the wrong last word.
#
# `locale` is accepted and forwarded, but it does not choose the dictionary:
# ICU applies one combined Chinese-Japanese word list to Han and kana runs,
# selected by the script of the text. Measured over seven CJK strings under
# five locales, the output was identical every time. It is passed through
# because ICU may use it elsewhere and because the guard catches a typo --
# not because it switches models.
.cjk_engine_icu <- function(x, locale = NULL, ...) {
  x <- as.character(x)
  # skip_word_none drops everything ICU classifies as "none" -- whitespace,
  # punctuation and symbols alike. Note that this is NOT the same rule the
  # "character" engine follows: that one drops whitespace but keeps CJK
  # punctuation, because U+3002 and friends sit in a block cjk_blocks()
  # lists. The two engines therefore return different token counts for the
  # same string, and the difference is punctuation, not segmentation.
  out <- .cjk_locale_guard(
    .cjk_stri(stringi::stri_split_boundaries(
      x, type = "word", skip_word_none = TRUE, locale = locale
    )),
    locale, "break data", "Use a language such as \"zh\", \"ja\" or \"ko\"."
  )
  # stringi already returns NA for NA input and character(0) for "", which is
  # the engine contract; the coercion is only so an NA element is typed
  # NA_character_ rather than the logical NA a zero-token split can produce.
  lapply(out, function(tok) {
    if (length(tok) == 1L && is.na(tok)) NA_character_ else as.character(tok)
  })
}


.cjk_builtin_engines <- function() {
  list(character = .cjk_engine_character, icu = .cjk_engine_icu)
}


#' Segmentation engines
#'
#' `cjk_segmenters()` lists the engines [cjk_segment()] can dispatch to, and
#' `register_cjk_segmenter()` adds one.
#'
#' @details
#' Where a word begins and ends in CJK text is a fact about a language, not
#' about Unicode, so it cannot be derived the way everything else in this
#' package is. It needs a dictionary and a statistical model, and which one is
#' right depends on the language and the corpus. \pkg{tidycjk} therefore
#' dispatches on a name rather than committing to one.
#'
#' Two engines ship with the package.
#'
#' `"icu"` is a real word segmenter. ICU carries dictionary-based break
#' iterators for Chinese and Japanese, and stringi carries ICU, so this costs
#' no dependency you have not already installed: a six-character Chinese
#' sentence comes back as its four words rather than as six characters.
#'
#' `locale` is accepted and forwarded, but it does not select the dictionary.
#' ICU applies a single combined Chinese-Japanese word list to Han and kana
#' runs, chosen by the script of the text, so Chinese and Japanese segment
#' the same way under `"zh"`, `"ja"` or the session default. It returns
#' surface forms only, with no part of speech, lemma or user dictionary, and
#' its models are lighter than MeCab's or jieba's tuned ones. It is the right
#' starting point and not the last word.
#'
#' `"character"` needs nothing at all: every CJK character becomes its own
#' token and runs of non-CJK text are split on whitespace. Whitespace is never
#' a token, the ideographic space U+3000 included, even though [has_cjk()]
#' counts it as CJK. It is character tokenisation rather than word
#' segmentation, and for Chinese it will cut two-character words in half. It
#' is a baseline, not an answer.
#'
#' # The two engines do not tokenise punctuation alike
#'
#' This matters when comparing counts, so it is worth stating rather than
#' leaving to be discovered. `"icu"` drops punctuation and symbols along with
#' whitespace; `"character"` keeps CJK punctuation as tokens, because those
#' code points are in blocks [cjk_blocks()] lists, and keeps a run of
#' non-CJK text whole up to the next space.
#'
#' The upshot is that the same sentence yields different token counts, and
#' the gap is punctuation rather than a disagreement about where words end.
#' An emoji is dropped by `"icu"` and kept by `"character"` for the same
#' reason. Filter or compare accordingly.
#'
#' # Registering another segmenter
#'
#' For Japanese, [gibasa](https://CRAN.R-project.org/package=gibasa) binds
#' MeCab and is on CRAN; it gives part of speech and lemma, which `"icu"` does
#' not.
#'
#' [jiebaR](https://CRAN.R-project.org/package=jiebaR), which binds
#' [cppjieba](https://github.com/yanyiwu/cppjieba), is the usual choice for
#' Chinese. It was archived from CRAN on 2025-05-01, so it cannot be a
#' dependency of a CRAN package and `install.packages()` will not find it;
#' install it from source with
#' `remotes::install_github("qinwf/jiebaR")`. Once you have it, four lines
#' make it an engine:
#'
#' ```
#' register_cjk_segmenter("jiebar", function(x, ...) {
#'   worker <- jiebaR::worker(...)
#'   lapply(x, function(s) {
#'     if (is.na(s)) return(NA_character_)
#'     if (!nzchar(s)) return(character(0))
#'     as.character(jiebaR::segment(s, worker))
#'   })
#' })
#' ```
#'
#' The same shape works for any segmenter you can call from R.
#'
#' # The engine contract
#'
#' An engine is any function taking `(x, ...)` -- a character vector and the
#' dots from [cjk_segment()] -- and returning a list the same length as `x`,
#' each element a character vector of tokens. `NA` input should give
#' `NA_character_` and the empty string should give `character(0)`;
#' [cjk_segment()] checks the shape and complains if an engine breaks the
#' contract. A plain list is required: a data frame is a list too, but
#' `length()` on one counts columns rather than elements, so it is refused
#' rather than quietly mistaken for a list of tokens.
#'
#' # Passing arguments to an engine
#'
#' Anything in `...` goes to the engine, which is how you configure one. Name
#' those arguments so that they are not a prefix of an argument of the verb
#' itself: `...` comes after `engine` in [cjk_segment()], and after `data` and
#' `col` in [cjk_tokens()], so R's partial matching claims a prefix of one of
#' those before the dots ever see it.
#'
#' It is worth knowing because the result does not look like an
#' argument-matching problem. `cjk_tokens(df, text, "mine", c = 1)` matches `c`
#' to `col`, which pushes the bare `text` into `engine`, where it resolves to
#' [graphics::text()] -- a function, so it is accepted as an engine -- and the
#' error you get is about plotting. Single letters and short prefixes are the
#' risk: `c`, `co`, `d`, `da`, `e`, `en`, `eng`. A longer name, or a closure
#' that captures the setting instead of passing it, avoids the question:
#'
#' ```
#' register_cjk_segmenter("mine", function(x, ...) my_segmenter(x, cutoff = 1))
#' ```
#'
#' # What registering does, and does not, undo
#'
#' A registration lasts for the rest of the session and there is no function
#' to remove one. Registering the same name again replaces it, which is the
#' way to correct an engine you got wrong.
#'
#' A name that matches a built-in shadows it. That is deliberate -- it is how
#' you substitute your own tokeniser for `"character"` without this package
#' getting a say -- but it is worth knowing that `"character"` is a natural
#' name for an engine and taking it hides the built-in for the session, with
#' nothing in [cjk_segmenters()] to show that anything changed. Pick a
#' distinct name unless shadowing is what you meant.
#'
#' @param name Name of the engine, a single string.
#' @param fn A function of `(x, ...)` returning a list of character vectors.
#'
#' @return `cjk_segmenters()` returns a character vector of engine names.
#'   `register_cjk_segmenter()` is called for its side effect and returns
#'   `name` invisibly.
#' @seealso [cjk_segment()], [cjk_tokens()].
#' @examples
#' cjk_segmenters()
#'
#' # an engine that splits on an explicit marker
#' register_cjk_segmenter("pipe", function(x, ...) strsplit(x, "|",
#'                                                          fixed = TRUE))
#' cjk_segment("\u4e2d\u6587|\u5f88\u597d", engine = "pipe")
#' @export
cjk_segmenters <- function() {
  # Radix order, not the session's collation: everything else in this package
  # orders deterministically, and the list of available engines should not come
  # back differently on a machine with a different locale.
  sort(unique(c(names(.cjk_builtin_engines()),
                ls(.cjk_engine_registry))),
       method = "radix")
}

#' @rdname cjk_segmenters
#' @export
register_cjk_segmenter <- function(name, fn) {
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
      !nzchar(name)) {
    stop("`name` must be a single, non-empty string.", call. = FALSE)
  }
  if (!is.function(fn)) {
    stop("`fn` must be a function.", call. = FALSE)
  }
  assign(name, fn, envir = .cjk_engine_registry)
  invisible(name)
}

.cjk_get_engine <- function(engine) {
  if (is.function(engine)) {
    return(engine)
  }
  if (!is.character(engine) || length(engine) != 1L || is.na(engine)) {
    stop("`engine` must be a single string or a function.", call. = FALSE)
  }
  # exists("") is an error rather than FALSE, so the empty name has to be
  # rejected here or it surfaces as R's "invalid first argument".
  if (!nzchar(engine)) {
    stop("`engine` must be a non-empty string. Available: ",
         paste0("\"", cjk_segmenters(), "\"", collapse = ", "), ".",
         call. = FALSE)
  }
  if (exists(engine, envir = .cjk_engine_registry, inherits = FALSE)) {
    return(get(engine, envir = .cjk_engine_registry, inherits = FALSE))
  }
  builtin <- .cjk_builtin_engines()
  if (!is.null(builtin[[engine]])) {
    return(builtin[[engine]])
  }
  stop("Unknown engine \"", engine, "\". Available: ",
       paste0("\"", cjk_segmenters(), "\"", collapse = ", "), ".",
       call. = FALSE)
}


#' Split CJK text into words
#'
#' `cjk_segment()` splits each string into tokens. Chinese and Japanese do not
#' put spaces between words, so splitting on whitespace returns the whole
#' sentence as one token; this dispatches to a segmentation engine instead.
#'
#' @details
#' Two engines ship with the package. `"icu"` is a real word segmenter, using
#' the dictionary ICU carries inside \pkg{stringi}, so it costs no dependency
#' you have not already installed. `"character"` tokenises by character rather
#' than by word.
#'
#' `engine` is required and has no default, because `"character"` answers a
#' different question from the one a caller asking for words is asking, and
#' quietly returning it would be the mistake this package exists to avoid.
#' The two also differ on punctuation: `"icu"` drops it, `"character"` keeps
#' CJK punctuation as tokens. [cjk_segmenters()] lists what is available and
#' shows how to register another.
#'
#' @inheritParams has_cjk
#' @param engine Name of a segmentation engine, or a function implementing
#'   one. Required; see [cjk_segmenters()].
#' @param ... Passed to the engine. Name these so they are not a prefix of
#'   `engine` (or of `data`/`col` in [cjk_tokens()]); see "Passing arguments to
#'   an engine" in [cjk_segmenters()].
#'
#' @return A list the same length as `x`, each element a character vector of
#'   tokens. `NA` input gives `NA_character_`; the empty string gives
#'   `character(0)`.
#' @seealso [cjk_tokens()] for the tidy version, [cjk_segmenters()] for the
#'   engines and for registering one.
#' @examples
#' # a real word segmenter: four words, not six characters
#' cjk_segment("\u6211\u4eca\u5929\u5f88\u958b\u5fc3", engine = "icu")
#'
#' # the dictionary-free baseline, one token per CJK character
#' cjk_segment("\u6211\u4eca\u5929\u5f88\u958b\u5fc3", engine = "character")
#'
#' # non-CJK runs stay whole and are split on whitespace
#' cjk_segment("hello \u4e2d\u6587 world", engine = "character")
#' @export
cjk_segment <- function(x, engine, ...) {
  if (missing(engine)) {
    stop("`engine` must be given; there is no safe default. Use ",
         "engine = \"character\" for character tokenisation, or register a ",
         "word segmenter -- see ?cjk_segmenters. Available: ",
         paste0("\"", cjk_segmenters(), "\"", collapse = ", "), ".",
         call. = FALSE)
  }
  x <- as.character(x)
  if (length(x) == 0L) {
    return(list())
  }
  fn <- .cjk_get_engine(engine)
  out <- fn(x, ...)
  # Three failures rather than one. ?cjk_segmenters invites callers to write
  # their own engine, so this is the error they are most likely to meet, and
  # one message for every way of breaking the contract diagnosed none of them.
  #
  # The data frame case is not hypothetical: a data frame IS a list, and
  # length() on one is its column count, so an engine handing back a one-column
  # frame of tokens for one input satisfied both halves of the old check and
  # produced a bogus token instead of an error.
  if (!is.list(out)) {
    stop("The segmentation engine must return a list, not ", class(out)[[1L]],
         ".", call. = FALSE)
  }
  if (inherits(out, "data.frame")) {
    stop("The segmentation engine must return a list, not a data frame: ",
         "length() of a data frame is its column count, so a frame can pass ",
         "a length check while holding the wrong thing.", call. = FALSE)
  }
  if (length(out) != length(x)) {
    stop("The segmentation engine must return a list as long as `x`: `x` has ",
         length(x), " element(s), the engine returned ", length(out), ".",
         call. = FALSE)
  }
  lapply(out, function(tok) {
    if (is.null(tok)) character(0) else as.character(tok)
  })
}


#' One row per token
#'
#' `cjk_tokens()` segments a text column and returns one row per token,
#' carrying the other columns along. It is the CJK-aware counterpart of
#' [tidytext](https://CRAN.R-project.org/package=tidytext)'s
#' `unnest_tokens()`, which splits on whitespace and therefore
#' returns CJK sentences whole.
#'
#' @details
#' Rows that produce no tokens -- empty strings, and text with nothing an
#' engine recognises -- are dropped, as they are in \pkg{tidytext}. `NA` text
#' yields one row with an `NA` token, so a missing document does not silently
#' vanish from the output.
#'
#' The token column is called `token` and is added to `data`; an existing
#' column of that name is replaced. As with [cjk_segment()], `engine` is
#' required.
#'
#' Grouping is dropped, as it is by [cjk_summary()]: the result is a plain
#' tibble even when `data` is a `grouped_df`. Regroup it afterwards if you need
#' the groups back.
#'
#' @inheritParams cjk_summary
#' @inheritParams cjk_segment
#'
#' @return `data`, as a tibble, with one row per token and an added `token`
#'   column. Row order follows the input, and tokens within a row follow the
#'   text.
#' @seealso [cjk_segment()] for the vector version, [cjk_char_counts()] when
#'   you want characters rather than words.
#' @examples
#' df <- data.frame(
#'   id = 1:2,
#'   text = c("\u6211\u5f88\u958b\u5fc3", "hello \u4e2d\u6587")
#' )
#' cjk_tokens(df, text, engine = "character")
#' @export
cjk_tokens <- function(data, col, engine, ...) {
  if (missing(engine)) {
    stop("`engine` must be given; there is no safe default. Use ",
         "engine = \"character\" for character tokenisation, or register a ",
         "word segmenter -- see ?cjk_segmenters. Available: ",
         paste0("\"", cjk_segmenters(), "\"", collapse = ", "), ".",
         call. = FALSE)
  }
  v <- as.character(.cjk_pull(dplyr::pull(data, {{ col }}), data))
  toks <- cjk_segment(v, engine = engine, ...)
  # A row is repeated once per token, so a row that tokenised to nothing is
  # dropped by having its index repeated zero times. An NA document is not one
  # of those: the engine contract gives it a single NA token, so it keeps a row.
  n <- lengths(toks)

  out <- tibble::as_tibble(data)
  out <- out[rep(seq_len(nrow(out)), times = n), , drop = FALSE]
  flat <- unlist(toks, use.names = FALSE)
  # unlist() of nothing is NULL, and assigning NULL would drop the column
  # rather than create an empty one
  out$token <- if (is.null(flat)) character(0) else flat
  out
}
