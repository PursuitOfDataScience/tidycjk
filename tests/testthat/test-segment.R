# Segmentation: the engine registry, the built-in engine, and the tidy verb.
#
# No word segmenter is bundled -- jiebaR was archived from CRAN -- so the
# registry is exercised with engines defined here.

test_that("the built-in engine is listed", {
  expect_true("character" %in% cjk_segmenters())
  expect_type(cjk_segmenters(), "character")
})

test_that("cjk_segmenters() orders by radix, not by the session's collation", {
  # cjk_segmenters() sorts method = "radix" so the list does not come back in a
  # different order on a machine with a different locale. With only "character"
  # registered there is nothing to order, so dropping the argument broke no
  # test -- the guarantee needs names that the two orders disagree about.
  on.exit(rm(list = intersect(c("a", "B", "Z", "_x"),
                             ls(.cjk_engine_registry)),
             envir = .cjk_engine_registry), add = TRUE)
  for (nm in c("a", "B", "Z", "_x")) register_cjk_segmenter(nm, identity)
  got <- cjk_segmenters()
  # radix is byte order: "B" < "Z" < "_x" < "a" < "character"
  expect_equal(got, c("B", "Z", "_x", "a", "character"))
  # The discriminating pair is B before a: byte order puts uppercase first and
  # every common collation does the opposite.
  expect_lt(which(got == "B"), which(got == "a"))
  expect_lt(which(got == "Z"), which(got == "a"))

  # Worth knowing before anyone tries to strengthen this: no test run under
  # testthat can catch the `method = "radix"` argument being dropped, because
  # testthat sets LC_COLLATE=C for reproducibility and under C collation plain
  # sort() and radix sort() agree exactly. The argument protects the *user's*
  # locale at run time, not the runner's. What the assertions above do catch is
  # any other wrong order -- reversed, collation-cased, unsorted -- so keep
  # them, and do not conclude from a surviving mutant that radix is pointless.
  # (Not asserted: a check on Sys.getlocale() here would couple this suite to
  # testthat's internals and fail on a testthat change, for no tidycjk reason.)
})

test_that("engine is required, with a message that says what to do", {
  # quietly returning character tokens to someone who asked for words is the
  # mistake this package exists to avoid, so the choice has to be explicit
  expect_error(cjk_segment(ZH), "no safe default")
  expect_error(cjk_segment(ZH), "character")
  expect_error(cjk_tokens(data.frame(text = ZH), text), "no safe default")
})

test_that("the character engine gives one token per CJK character", {
  expect_equal(
    cjk_segment(ZH, engine = "character")[[1]],
    c("\u4e2d", "\u6587")
  )
  expect_equal(
    length(cjk_segment(ZH_SENTENCE, engine = "character")[[1]]),
    6L
  )
})

test_that("the character engine keeps non-CJK runs whole", {
  expect_equal(
    cjk_segment("hello \u4e2d\u6587 world", engine = "character")[[1]],
    c("hello", "\u4e2d", "\u6587", "world")
  )
  expect_equal(
    cjk_segment("abc", engine = "character")[[1]],
    "abc"
  )
})

test_that("the character engine splits non-CJK runs on whitespace", {
  expect_equal(
    cjk_segment("one two  three", engine = "character")[[1]],
    c("one", "two", "three")
  )
  # whitespace only: nothing survives
  expect_equal(cjk_segment("   ", engine = "character")[[1]], character(0))
})

test_that("the ideographic space is whitespace, not a token", {
  # U+3000 is in the CJK Symbols and Punctuation block, so the plain block
  # test made it a token of its own -- a space counted as a word, while the
  # ASCII space beside it was dropped.
  expect_equal(
    cjk_segment(paste0("a", IDEOGRAPHIC_SPACE, "b"),
                engine = "character")[[1]],
    c("a", "b")
  )
  expect_equal(
    cjk_segment(paste0(ZH, IDEOGRAPHIC_SPACE, ZH), engine = "character")[[1]],
    c("\u4e2d", "\u6587", "\u4e2d", "\u6587")
  )
  expect_equal(
    cjk_segment(strrep(IDEOGRAPHIC_SPACE, 3), engine = "character")[[1]],
    character(0)
  )
  # it is still CJK everywhere else; only the tokeniser drops it
  expect_true(has_cjk(IDEOGRAPHIC_SPACE))
})

test_that("the whitespace split does not depend on the locale", {
  # strsplit(x, "[[:space:]]+") resolves the class through the C library's
  # iswspace(), which calls U+3000 a space in a UTF-8 locale and not in a C
  # one. stringi asks ICU, which answers the same on every machine.
  spaces <- c(" ", "\u3000", "\u00a0", "\t", "\n")
  for (s in spaces) {
    expect_equal(
      cjk_segment(paste0("a", s, "b"), engine = "character")[[1]],
      c("a", "b"),
      info = sprintf("U+%04X", utf8ToInt(s))
    )
  }
})

test_that("the character engine handles runs past the tenth", {
  # grouping is by a numeric run id; if it were ever sorted as text, run 10
  # would come before run 2 and the tokens would come back out of order
  x <- paste0(rep(c("a ", "\u4e2d"), 8), collapse = "")
  toks <- cjk_segment(x, engine = "character")[[1]]
  expect_true(length(toks) > 10L)
  expect_equal(toks, rep(c("a", "\u4e2d"), 8))
})

test_that("the character engine handles mixed scripts", {
  expect_equal(
    cjk_segment(JA_MIXED, engine = "character")[[1]],
    c("\u65e5", "\u672c", "\u306e", "\u3053", "\u3068", "\u3070")
  )
  expect_equal(
    cjk_segment(EXT_B, engine = "character")[[1]],
    EXT_B
  )
})

test_that("cjk_segment() propagates NA and handles empty input", {
  expect_equal(cjk_segment(NA_character_, engine = "character")[[1]],
               NA_character_)
  expect_equal(cjk_segment("", engine = "character")[[1]], character(0))
  expect_equal(cjk_segment(character(0), engine = "character"), list())
  expect_type(cjk_segment(character(0), engine = "character"), "list")
})

test_that("cjk_segment() is vectorised and returns a parallel list", {
  x <- c(ZH, "", NA, "abc")
  out <- cjk_segment(x, engine = "character")
  expect_type(out, "list")
  expect_length(out, 4L)
  expect_equal(out[[1]], c("\u4e2d", "\u6587"))
  expect_equal(out[[2]], character(0))
  expect_equal(out[[3]], NA_character_)
  expect_equal(out[[4]], "abc")
})

test_that("an unknown engine is a clear error", {
  expect_error(cjk_segment(ZH, engine = "nope"), "Unknown engine")
  expect_error(cjk_segment(ZH, engine = "nope"), "character")  # lists options
  expect_error(cjk_segment(ZH, engine = 1), "single string or a function")
  expect_error(cjk_segment(ZH, engine = c("a", "b")), "single string")
  # the empty name has to be rejected before the registry lookup: exists("")
  # is an error, so this used to surface as R's "invalid first argument"
  expect_error(cjk_segment(ZH, engine = ""), "non-empty string")
  expect_error(cjk_segment(ZH, engine = ""), "character")  # still lists options
  expect_error(cjk_tokens(data.frame(text = ZH), text, engine = ""),
               "non-empty string")
})

test_that("dots reach the engine, and a colliding name does not", {
  # Documented in ?cjk_segmenters. `...` sits after `engine` in cjk_segment()
  # and after `data`/`col` in cjk_tokens(), so R's partial matching claims a
  # prefix of one of those before the dots see it. Pinned because the symptom
  # is not recognisable as an argument-matching problem.
  on.exit(rm(list = intersect("probe", ls(.cjk_engine_registry)),
             envir = .cjk_engine_registry), add = TRUE)
  register_cjk_segmenter("probe", function(x, ...) {
    list(paste0("dots:", paste(names(list(...)), collapse = ",")))
  })
  # a distinct name is forwarded, which is the documented use
  expect_equal(cjk_segment("a", "probe", cutoff = 1)[[1]], "dots:cutoff")
  expect_equal(cjk_tokens(data.frame(text = "a"), text, "probe",
                          cutoff = 1)$token, "dots:cutoff")
  # a prefix of `engine` is claimed by `engine`, which then fails its own check
  expect_error(cjk_segment("a", "probe", eng = 1),
               "single string or a function")
  # and in cjk_tokens() a prefix of `data` is claimed by `data`
  expect_error(cjk_tokens(data.frame(text = "a"), text, "probe", d = 1),
               "must be a data frame or tibble")
})

test_that("an engine can be supplied as a bare function", {
  expect_equal(
    cjk_segment("a-b", engine = function(x, ...) strsplit(x, "-"))[[1]],
    c("a", "b")
  )
})

test_that("an engine returning NULL tokens gets an empty character vector", {
  # cjk_segment() normalises a NULL element to character(0) so that callers see
  # one shape. It is reachable through the public API -- a user-supplied engine
  # that returns NULL for a row it produced nothing for -- and cjk_tokens()
  # then drops that row rather than erroring on it.
  out <- cjk_segment(c(ZH, "x"), engine = function(x, ...) list(NULL, "x"))
  expect_equal(out[[1]], character(0))
  expect_equal(out[[2]], "x")
  tb <- cjk_tokens(data.frame(id = 1:2, text = c(ZH, "x")), text,
                   engine = function(x, ...) list(NULL, "x"))
  expect_equal(nrow(tb), 1L)
  expect_equal(tb$id, 2L)
})

test_that("an engine that breaks the contract is caught", {
  expect_error(cjk_segment(ZH, engine = function(x, ...) "not a list"),
               "must return a list")
  expect_error(cjk_segment(ZH, engine = function(x, ...) list()),
               "as long as")
})

test_that("the engine-contract error says which way the contract broke", {
  # ?cjk_segmenters invites callers to write their own engine, so this is the
  # error they are most likely to meet. One message for every way of breaking
  # the contract diagnosed none of them.
  expect_error(cjk_segment(ZH, engine = function(x, ...) "nope"),
               "not character")
  expect_error(cjk_segment(ZH, engine = function(x, ...) NULL), "not NULL")
  expect_error(cjk_segment(c("a", "b", "c"),
                           engine = function(x, ...) list(1, 2)),
               "3 element\\(s\\), the engine returned 2")
})

test_that("an engine returning a data frame is an error, not a token", {
  # A data frame IS a list and length() on one is its column count, so a
  # one-column frame of tokens for one input satisfied both halves of the old
  # check and came back as a bogus token instead of an error.
  expect_error(cjk_segment("a", engine = function(x, ...) data.frame(a = 1)),
               "not a data frame")
  expect_error(cjk_segment("a", engine = function(x, ...) tibble::tibble(a = 1)),
               "not a data frame")
  # a frame whose column count happens to match is still refused
  expect_error(
    cjk_segment(c("a", "b"),
                engine = function(x, ...) data.frame(p = 1, q = 2)),
    "not a data frame"
  )
  # and a plain list still works, which is what the contract asks for
  expect_equal(cjk_segment("a-b", engine = function(x, ...) strsplit(x, "-"))[[1]],
               c("a", "b"))
})

test_that("register_cjk_segmenter() adds an engine", {
  register_cjk_segmenter("test_upper",
                         function(x, ...) lapply(toupper(x), identity))
  on.exit(rm("test_upper", envir = .cjk_engine_registry), add = TRUE)
  expect_true("test_upper" %in% cjk_segmenters())
  expect_equal(cjk_segment("abc", engine = "test_upper")[[1]], "ABC")
})

test_that("a registration shadows a built-in, and re-registering replaces it", {
  # Documented in ?cjk_segmenters because it is a trap as much as a feature:
  # "character" is a natural name for a character-based engine, taking it hides
  # the built-in for the session, and cjk_segmenters() shows no sign of it.
  # Pinned so nobody "fixes" the shadowing without updating the help page.
  on.exit(rm(list = intersect("character", ls(.cjk_engine_registry)),
             envir = .cjk_engine_registry), add = TRUE)
  expect_equal(cjk_segment("a b", engine = "character")[[1]], c("a", "b"))

  register_cjk_segmenter("character", function(x, ...) list("SHADOWED"))
  expect_equal(cjk_segment("a b", engine = "character")[[1]], "SHADOWED")
  # the name is still listed exactly once, which is why the change is invisible
  expect_equal(sum(cjk_segmenters() == "character"), 1L)

  # re-registering the same name replaces it, which is the way to fix a wrong
  # engine given that nothing removes one
  register_cjk_segmenter("character", function(x, ...) list("AGAIN"))
  expect_equal(cjk_segment("a b", engine = "character")[[1]], "AGAIN")

  # and the built-in was never deleted, only covered: it returns once the
  # registry entry goes
  rm("character", envir = .cjk_engine_registry)
  expect_equal(cjk_segment("a b", engine = "character")[[1]], c("a", "b"))
})

test_that("register_cjk_segmenter() validates its arguments", {
  expect_error(register_cjk_segmenter(1, identity), "single, non-empty string")
  expect_error(register_cjk_segmenter("", identity), "non-empty")
  expect_error(register_cjk_segmenter(c("a", "b"), identity), "single")
  expect_error(register_cjk_segmenter("ok", "not a function"), "must be a function")
})

test_that("cjk_tokens() returns one row per token and keeps other columns", {
  df <- data.frame(id = 1:2, text = c(ZH, "hello \u4e2d"))
  out <- cjk_tokens(df, text, engine = "character")

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("id", "text", "token"))
  expect_equal(nrow(out), 4L)
  expect_equal(out$token, c("\u4e2d", "\u6587", "hello", "\u4e2d"))
  expect_equal(out$id, c(1L, 1L, 2L, 2L))
})

test_that("cjk_tokens() drops rows that produce no tokens", {
  df <- data.frame(id = 1:3, text = c(ZH, "", "   "))
  out <- cjk_tokens(df, text, engine = "character")
  expect_equal(nrow(out), 2L)
  expect_equal(unique(out$id), 1L)
})

test_that("cjk_tokens() keeps NA documents as a single NA token", {
  df <- data.frame(id = 1:2, text = c(NA_character_, ZH))
  out <- cjk_tokens(df, text, engine = "character")
  expect_equal(nrow(out), 3L)
  expect_true(is.na(out$token[1]))
  expect_equal(out$id[1], 1L)
})

test_that("cjk_tokens() gives a typed zero-row tibble when nothing tokenises", {
  out <- cjk_tokens(data.frame(text = c("", "")), text, engine = "character")
  expect_equal(nrow(out), 0L)
  expect_true("token" %in% names(out))
  expect_type(out$token, "character")

  empty <- cjk_tokens(data.frame(text = character(0)), text,
                      engine = "character")
  expect_equal(nrow(empty), 0L)
  expect_true("token" %in% names(empty))
  expect_type(empty$token, "character")
})

test_that("cjk_tokens() accepts tibbles and unquoted columns", {
  tb <- tibble::tibble(body = ZH)
  expect_equal(nrow(cjk_tokens(tb, body, engine = "character")), 2L)
})

test_that("cjk_tokens() accepts a grouped data frame and drops the grouping", {
  # stringsAsFactors is explicit because it only defaulted to FALSE in R 4.0.0,
  # and DESCRIPTION claims R (>= 3.5.0). Without it, `g` arrives as a factor on
  # an older R, cjk_tokens() carries the column through unchanged as it should,
  # and the comparison below fails against a character vector -- a bug in the
  # test rather than in the package.
  df <- dplyr::group_by(
    data.frame(g = c("a", "b"), text = c(ZH, "x y"), stringsAsFactors = FALSE),
    g
  )
  out <- cjk_tokens(df, text, engine = "character")
  expect_equal(nrow(out), 4L)
  expect_equal(out$g, c("a", "a", "b", "b"))
  # documented: a plain tibble, as cjk_summary() also returns
  expect_false(inherits(out, "grouped_df"))
})

test_that("cjk_tokens() composes with the rest of the package", {
  df <- data.frame(text = c(ZH, JA_MIXED))
  out <- cjk_tokens(df, text, engine = "character")
  expect_equal(nrow(out), 8L)
  expect_true(all(has_cjk(out$token)))
  expect_equal(sum(cjk_width(out$token)), 16L)
})

test_that("a registered word segmenter keeps a multi-character word whole", {
  # the documented registration shape, with a two-entry dictionary standing in
  # for a real one: U+4ECA U+5929 ("today") is one word of two characters, and
  # the character engine cuts it in half
  register_cjk_segmenter("test_dict", function(x, ...) {
    lapply(x, function(s) {
      if (is.na(s)) {
        return(NA_character_)
      }
      if (!nzchar(s)) {
        return(character(0))
      }
      unlist(strsplit(gsub("\u4eca\u5929", "|\u4eca\u5929|", s), "|",
                      fixed = TRUE))
    })
  })
  on.exit(rm("test_dict", envir = .cjk_engine_registry), add = TRUE)

  today <- "\u4eca\u5929"
  expect_equal(length(cjk_segment(today, engine = "character")[[1]]), 2L)
  expect_true(today %in% cjk_segment(today, engine = "test_dict")[[1]])
  expect_equal(cjk_segment(NA_character_, engine = "test_dict")[[1]],
               NA_character_)
  expect_equal(cjk_segment("", engine = "test_dict")[[1]], character(0))
})
