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
# No word segmenter is bundled, and `engine` has no default. jiebaR was the
# obvious candidate and it was archived from CRAN on 2025-05-01, so it cannot
# be a dependency of a CRAN package; and the only engine we can ship without
# one, "character", answers a different question from the one a caller asking
# for words is asking. Rather than quietly hand back character tokens, the
# choice is required. ?cjk_segmenters shows how to register jiebaR in four
# lines if you have it.

# User-registered engines. Built-ins are not kept here, so a caller can shadow
# one deliberately but cannot delete it by accident.
.cjk_engine_registry <- new.env(parent = emptyenv())


# --- built-in engines -------------------------------------------------------

# The dictionary-free baseline: every CJK character is its own token, and each
# run of non-CJK text is split on whitespace. It needs nothing and it is
# honest about what it is -- character tokenisation, not word segmentation.
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
    is_cjk <- !is.na(.cjk_block_index(cp))
    # group into maximal runs: each CJK character alone, each non-CJK run whole
    run <- cumsum(c(TRUE, is_cjk[-1] | is_cjk[-length(is_cjk)]))
    pieces <- vapply(split(cp, run), function(g) {
      stringi::stri_enc_fromutf32(list(g))
    }, character(1), USE.NAMES = FALSE)
    cjk_piece <- vapply(split(is_cjk, run), function(g) g[[1]], logical(1),
                        USE.NAMES = FALSE)
    out <- unlist(lapply(seq_along(pieces), function(i) {
      if (cjk_piece[[i]]) {
        pieces[[i]]
      } else {
        w <- unlist(strsplit(pieces[[i]], "[[:space:]]+"), use.names = FALSE)
        w[nzchar(w)]
      }
    }), use.names = FALSE)
    if (is.null(out)) character(0) else out
  })
}

.cjk_builtin_engines <- function() {
  list(character = .cjk_engine_character)
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
#' bundles no word segmenter and dispatches on a name instead.
#'
#' One engine ships with the package. `"character"` needs nothing at all:
#' every CJK character becomes its own token and runs of non-CJK text are
#' split on whitespace. It is character tokenisation rather than word
#' segmentation, and for Chinese it will cut two-character words in half. It
#' is a baseline, not an answer.
#'
#' # Registering a word segmenter
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
#' contract.
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
#' `engine` is required and has no default. The only engine \pkg{tidycjk} can
#' ship without a dictionary is `"character"`, which tokenises by character
#' rather than by word -- a different answer from the one you are asking for,
#' and quietly returning it would be the mistake this package exists to avoid.
#' [cjk_segmenters()] lists what is available and shows how to register a real
#' word segmenter.
#'
#' @inheritParams has_cjk
#' @param engine Name of a segmentation engine, or a function implementing
#'   one. Required; see [cjk_segmenters()].
#' @param ... Passed to the engine.
#'
#' @return A list the same length as `x`, each element a character vector of
#'   tokens. `NA` input gives `NA_character_`; the empty string gives
#'   `character(0)`.
#' @seealso [cjk_tokens()] for the tidy version, [cjk_segmenters()] for the
#'   engines and for registering one.
#' @examples
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
  if (!is.list(out) || length(out) != length(x)) {
    stop("The segmentation engine must return a list as long as `x`.",
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
  v <- as.character(dplyr::pull(data, {{ col }}))
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
