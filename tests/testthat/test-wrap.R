# cjk_wrap(): the third layout verb. What matters is that it budgets in
# columns like cjk_pad() and cjk_truncate(), not in characters.

test_that("cjk_wrap keeps every line inside the column budget", {
  x <- "\u6211\u4eca\u5929\u5f88\u958b\u5fc3\uff0c\u56e0\u70ba\u5929\u6c23\u975e\u5e38\u597d"
  lines <- strsplit(cjk_wrap(x, 12), "\n", fixed = TRUE)[[1]]
  expect_true(all(cjk_width(lines) <= 12))
  expect_gt(length(lines), 1L)
})

test_that("cjk_wrap budgets in columns, not characters", {
  # 8 CJK characters are 16 columns, so a 8-column budget must split them
  # into 4 lines of 2 -- a character-counting wrapper would give 1 line.
  lines <- strsplit(cjk_wrap(strrep("\u4e2d", 8), 4), "\n", fixed = TRUE)[[1]]
  expect_equal(length(lines), 4L)
  expect_true(all(cjk_width(lines) <= 4))
})

test_that("cjk_wrap returns one element per input string", {
  x <- c("\u4e2d\u6587\u4e2d\u6587", "hello there world", "")
  expect_length(cjk_wrap(x, 6), 3L)
  expect_equal(cjk_wrap("", 6), "")
})

test_that("cjk_wrap propagates NA and zero length", {
  expect_equal(cjk_wrap(NA, 5), NA_character_)
  expect_equal(cjk_wrap(c("\u4e2d", NA), 5)[[2]], NA_character_)
  expect_equal(cjk_wrap("\u4e2d", NA), NA_character_)
  expect_equal(cjk_wrap(character(0), 5), character(0))
})

test_that("cjk_wrap validates width the same way cjk_pad does", {
  expect_error(cjk_wrap("\u4e2d", Inf), "finite")
  expect_error(cjk_wrap("\u4e2d", "8"), "numeric")
  expect_error(cjk_wrap(character(0), Inf), "finite")
  expect_error(cjk_wrap(c("a", "b", "c"), c(2, 3)), "recyclable")
})

test_that("cjk_wrap validates indent and exdent", {
  expect_error(cjk_wrap("\u4e2d", 5, indent = -1), "`indent`")
  expect_error(cjk_wrap("\u4e2d", 5, exdent = NA), "`exdent`")
  expect_error(cjk_wrap("\u4e2d", 5, indent = c(1, 2)), "`indent`")
})

test_that("cjk_wrap applies exdent to continuation lines only", {
  x <- strrep("\u4e2d", 8)
  lines <- strsplit(cjk_wrap(x, 6, exdent = 2), "\n", fixed = TRUE)[[1]]
  expect_false(startsWith(lines[[1]], " "))
  expect_true(startsWith(lines[[2]], "  "))
})

test_that("cjk_wrap recycles width against x", {
  out <- cjk_wrap(c(strrep("\u4e2d", 4), strrep("\u4e2d", 4)), c(2, 8))
  expect_equal(length(strsplit(out[[1]], "\n", fixed = TRUE)[[1]]), 4L)
  expect_equal(length(strsplit(out[[2]], "\n", fixed = TRUE)[[1]]), 1L)
})

test_that("cjk_wrap respects the line-break rules the vignette promises", {
  # vignette("width-and-layout") names these four; they are ICU's, so a
  # change in its tables should surface here rather than in the prose.
  brk <- function(s, w) strsplit(cjk_wrap(s, w), "\n", fixed = TRUE)[[1]]
  first <- function(L) substr(L, 1, 1)
  last  <- function(L) substr(L, nchar(L), nchar(L))

  br <- brk("\u4ed6\u8aaa\uff08\u4eca\u5929\u5929\u6c23\u5f88\u597d\uff09\u6211\u5011\u53bb\u516c\u5712\u6563\u6b65", 10)
  expect_false(any(first(br) %in% c("\uff09", "\u300d", "\u300f", "\u3015")))
  expect_false(any(last(br)  %in% c("\uff08", "\u300c", "\u300e", "\u3014")))

  st <- brk("\u4eca\u5929\u5929\u6c23\u5f88\u597d\u3002\u6211\u5011\u53bb\u516c\u5712\u6563\u6b65\u3002", 10)
  expect_false(any(first(st) %in% c("\u3002", "\u3001", "\uff0c")))

  # The small-kana rule is NOT locale-independent: Annex #14 has strict,
  # normal and loose styles and ICU tailors them per locale. Under "ja" the
  # loose style lets a small kana begin a line, so this must name the style
  # rather than assume the session's. Asserting it unqualified passed under
  # en_US and C and failed under ja_JP and ko_KR.
  kana <- "\u304d\u3087\u3046\u306f\u3068\u3066\u3082\u3044\u3044\u3066\u3093\u304d\u3067\u3059\u3063\u3057\u3083\u3061\u3087"
  strict <- strsplit(cjk_wrap(kana, 6, locale = "ja@lb=strict"), "\n",
                     fixed = TRUE)[[1]]
  expect_false(any(substr(strict, 1, 1) %in%
                     c("\u3083", "\u3085", "\u3087", "\u3063")))
})

test_that("cjk_wrap exposes the locale that decides the break style", {
  # The bug this guards: cjk_wrap() used to inherit the session locale with
  # no way to override, so the same call wrapped Japanese differently
  # depending on where it ran.
  kana <- "\u304d\u3087\u3046\u306f\u3068\u3066\u3082\u3044\u3044\u3066\u3093\u304d\u3067\u3059\u3063\u3057\u3083\u3061\u3087"
  sm <- function(l) {
    any(substr(strsplit(cjk_wrap(kana, 6, locale = l), "\n",
                        fixed = TRUE)[[1]], 1, 1) %in%
        c("\u3083", "\u3085", "\u3087", "\u3063"))
  }
  expect_false(sm("ja@lb=strict"))   # strict: never
  expect_true(sm("ja@lb=loose"))     # loose: allowed
  # and a locale ICU has no break data for is an error, as elsewhere
  expect_error(cjk_wrap("abc", 5, locale = "not-a-locale"), "break data")
})

test_that("cjk_wrap keeps a leading byte-order mark", {
  # Re-flowing text is not licence to delete a character from it.
  y <- "\ufeff\u4e2d\u6587"
  expect_equal(nchar(cjk_wrap(y, 20)), nchar(y))
  expect_true(startsWith(cjk_wrap(y, 20), "\ufeff"))
})

test_that("a long string wraps instead of crashing R", {
  # stri_wrap()'s default optimal fit segfaults on long input -- a plain
  # stri_wrap(strrep(<2 CJK chars>, 50000), 40) takes R down. cjk_wrap()
  # switches to the greedy algorithm above 10,000 characters. This test is
  # here because the failure mode is a crash, not a wrong answer, so nothing
  # else in the suite would survive to report it.
  big <- strrep("\u4e2d\u6587", 12000)          # 24,000 characters
  expect_gt(nchar(big), .CJK_WRAP_GREEDY_ABOVE)
  lines <- strsplit(cjk_wrap(big, 40), "\n", fixed = TRUE)[[1]]
  expect_true(all(cjk_width(lines) <= 40))
  expect_equal(paste(lines, collapse = ""), big)
})

test_that("short strings keep stringi's optimal fit", {
  # The greedy switch must not change anything below the threshold.
  s <- "hello there world wide"
  expect_lt(nchar(s), .CJK_WRAP_GREEDY_ABOVE)
  expect_equal(cjk_wrap(s, 8),
               paste(stringi::stri_wrap(s, 8, simplify = TRUE),
                     collapse = "\n"))
})
