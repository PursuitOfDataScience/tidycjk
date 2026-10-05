# Invariants checked over the code point space rather than over examples.
#
# Every other test file picks characters that illustrate something. These
# assert laws -- idempotence, round trips, agreement with the block table --
# and let the whole of Unicode be the input. That found two things the
# example-driven tests had not: cjk_wrap() normalising (pinned in
# test-wrap.R) and every verb deparsing a list argument (test-ranges.R).
#
# The exhaustive versions are skipped on CRAN, where check time is not mine
# to spend; the sampled versions run everywhere. The sample is deterministic
# and stratified across the blocks, so a failure is reproducible.

cjk_cps <- function() {
  b <- cjk_blocks()
  cps <- sort(unique(unlist(Map(seq, b$start, b$end))))
  cps <- cps[!(cps >= 0xD800 & cps <= 0xDFFF)]   # surrogates are not code points
  cps[bitwAnd(cps, 0xFFFE) != 0xFFFE]            # nor are the plane noncharacters
}

cjk_sample <- function(per_block = 40L) {
  b <- cjk_blocks()
  out <- unlist(Map(function(s, e) {
    n <- e - s + 1L
    if (n <= per_block) s:e else as.integer(round(seq(s, e, length.out = per_block)))
  }, b$start, b$end))
  out <- sort(unique(out))
  out <- out[!(out >= 0xD800 & out <= 0xDFFF)]
  out[bitwAnd(out, 0xFFFE) != 0xFFFE]
}

# intToUtf8(multiple = TRUE) rather than vapply(): the vectorised form is
# what makes sweeping a million code points affordable at all.
chars_of <- function(cps) intToUtf8(cps, multiple = TRUE)

# The body every version runs, so the sampled and exhaustive forms cannot
# drift apart.
check_invariants <- function(cps) {
  x <- chars_of(cps)
  expect_false(anyNA(x))
  expect_true(all(nchar(x, "chars") == 1L))
  ws <- cps == 0x3000L                    # the one in-block whitespace character

  # classification follows the block table, by definition
  expect_true(all(has_cjk(x)))
  expect_equal(cjk_ratio(x), rep(1, length(x)))
  expect_false(anyNA(cjk_script(x)))

  # width is a small non-negative integer, never missing
  w <- cjk_width(x)
  expect_false(anyNA(w))
  expect_true(all(w %in% 0:2))

  # the fixed-width verbs are no-ops on a string that already fits
  expect_identical(cjk_truncate(x, w), x)
  expect_identical(cjk_pad(x, w), x)

  # one character is one token and one 1-gram, the ideographic space aside:
  # the character engine treats it as whitespace, so it yields neither
  seg <- cjk_segment(x, engine = "character")
  expect_identical(lengths(seg), ifelse(ws, 0L, 1L))
  expect_identical(unlist(seg[!ws], use.names = FALSE), x[!ws])
  g <- cjk_ngrams(x, 1L)
  expect_identical(lengths(g), ifelse(ws, 0L, 1L))
  expect_identical(unlist(g[!ws], use.names = FALSE), x[!ws])

  # every transform gives back valid, non-missing UTF-8 of the same length
  tf <- list(to_fullwidth, to_halfwidth, to_hiragana, to_katakana,
             cjk_romanize, cjk_simplify, cjk_traditionalize,
             function(z) cjk_strip_punct(z, replacement = ""),
             function(z) cjk_normalize(z, "nfc"),
             function(z) cjk_normalize(z, "nfd"),
             function(z) cjk_normalize(z, "nfkc"),
             function(z) cjk_normalize(z, "nfkd"),
             function(z) cjk_normalize(z, "nfkc_casefold"))
  for (f in tf) {
    out <- f(x)
    expect_length(out, length(x))
    expect_false(anyNA(out))
    expect_true(all(stringi::stri_enc_isutf8(out)))
  }

  # each normal form is a fixed point of itself, and the composition laws hold
  for (nm in c("nfc", "nfd", "nfkc", "nfkd", "nfkc_casefold")) {
    o <- cjk_normalize(x, nm)
    expect_identical(cjk_normalize(o, nm), o)
  }
  expect_identical(cjk_normalize(cjk_normalize(x, "nfd"), "nfc"),
                   cjk_normalize(x, "nfc"))
  expect_identical(cjk_normalize(cjk_normalize(x, "nfkd"), "nfkc"),
                   cjk_normalize(x, "nfkc"))

  # width conversion is idempotent, and fullwidth text survives a trip to
  # halfwidth and back. The other order is no identity: to_halfwidth() of
  # text that was fullwidth to begin with narrows it.
  fw <- to_fullwidth(x)
  expect_identical(to_fullwidth(fw), fw)
  expect_identical(to_fullwidth(to_halfwidth(fw)), fw)
  hw <- to_halfwidth(x)
  expect_identical(to_halfwidth(hw), hw)
  # kana conversion is idempotent in both directions
  expect_identical(to_hiragana(to_hiragana(x)), to_hiragana(x))
  expect_identical(to_katakana(to_katakana(x)), to_katakana(x))
}

test_that("the invariants hold across a sample of every block", {
  check_invariants(cjk_sample())
})

test_that("the invariants hold across every code point in every block", {
  skip_on_cran()
  check_invariants(cjk_cps())
})

test_that("the block table is exact at every boundary, and outside", {
  # The complement matters as much as the blocks: a character wrongly called
  # CJK is as much a bug as one wrongly left out, and until 0.2.0 nothing had
  # looked outside the table at all. A single exhaustive sweep of all
  # 1,112,029 valid code points found no disagreement in either direction;
  # re-running that on every CI job costs a minute to re-verify static data,
  # so what stays here is where an interval lookup actually goes wrong --
  # every block edge and the code point either side of it -- plus a spread
  # through the gaps between blocks.
  b <- cjk_blocks()
  edges <- sort(unique(c(b$start - 1L, b$start, b$end, b$end + 1L)))
  gaps <- as.integer(round(seq(1L, 0x10FFFF, length.out = 4000L)))
  cp <- sort(unique(c(edges, gaps)))
  cp <- cp[cp >= 1L & cp <= 0x10FFFF]
  cp <- cp[!(cp >= 0xD800 & cp <= 0xDFFF)]
  cp <- cp[bitwAnd(cp, 0xFFFE) != 0xFFFE]
  inb <- cjk_cps()
  ins <- cp %in% inb
  # the boundaries have to include both answers, or this proves nothing
  expect_true(any(ins))
  expect_true(any(!ins))
  x <- chars_of(cp)
  expect_identical(has_cjk(x), ins)
  expect_equal(cjk_ratio(x), as.numeric(ins))
  expect_identical(is.na(cjk_script(x)), !ins)
  w <- cjk_width(x)
  expect_false(anyNA(w))
  expect_true(all(w >= 0L & w <= 2L))
})

test_that("the Hangul jamo round trip is exact for every syllable", {
  # The mapping is arithmetic in the standard, so "exact" is testable in
  # full rather than by example: all 11,172 syllables of the block.
  syl <- 0xAC00:0xD7A3
  ss <- chars_of(syl)
  j <- cjk_jamo(ss)
  expect_true(all(lengths(j) %in% 2:3))
  expect_identical(
    cjk_compose_jamo(vapply(j, paste, character(1), collapse = "")), ss)
  # and the pieces are conjoining jamo, not the compatibility block
  cp <- vapply(unique(unlist(j)), utf8ToInt, integer(1))
  expect_true(all(cp >= 0x1100 & cp <= 0x11FF))
})
