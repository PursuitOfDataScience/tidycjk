# Segmentation: the engine registry, the built-in engine, and the tidy verb.
#
# No word segmenter is bundled -- jiebaR was archived from CRAN -- so the
# registry is exercised with engines defined here.

test_that("the built-in engine is listed", {
  expect_true("character" %in% cjk_segmenters())
  expect_type(cjk_segmenters(), "character")
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
})

test_that("an engine can be supplied as a bare function", {
  expect_equal(
    cjk_segment("a-b", engine = function(x, ...) strsplit(x, "-"))[[1]],
    c("a", "b")
  )
})

test_that("an engine that breaks the contract is caught", {
  expect_error(cjk_segment(ZH, engine = function(x, ...) "not a list"),
               "must return a list")
  expect_error(cjk_segment(ZH, engine = function(x, ...) list()),
               "as long as")
})

test_that("register_cjk_segmenter() adds an engine", {
  register_cjk_segmenter("test_upper",
                         function(x, ...) lapply(toupper(x), identity))
  on.exit(rm("test_upper", envir = .cjk_engine_registry), add = TRUE)
  expect_true("test_upper" %in% cjk_segmenters())
  expect_equal(cjk_segment("abc", engine = "test_upper")[[1]], "ABC")
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
