# The block table and the findInterval() lookup built on it.

test_that("the block table holds the invariants findInterval() needs", {
  tab <- cjk_blocks()
  expect_false(is.unsorted(tab$start))
  expect_true(all(tab$start <= tab$end))
  # no overlaps: each range must start after the previous one ends
  expect_true(all(tab$start[-1] > tab$end[-nrow(tab)]))
})

test_that("every required Unicode block is present with the right bounds", {
  tab <- cjk_blocks()
  bounds <- function(block) {
    r <- tab[tab$block == block, ]
    as.numeric(c(min(r$start), max(r$end)))
  }
  expect_equal(bounds("CJK Unified Ideographs"), c(0x4E00, 0x9FFF))
  expect_equal(bounds("CJK Unified Ideographs Extension A"), c(0x3400, 0x4DBF))
  expect_equal(bounds("CJK Unified Ideographs Extension B"), c(0x20000, 0x2A6DF))
  expect_equal(bounds("CJK Unified Ideographs Extension C"), c(0x2A700, 0x2B73F))
  expect_equal(bounds("CJK Unified Ideographs Extension D"), c(0x2B740, 0x2B81F))
  expect_equal(bounds("CJK Unified Ideographs Extension E"), c(0x2B820, 0x2CEAF))
  expect_equal(bounds("CJK Unified Ideographs Extension F"), c(0x2CEB0, 0x2EBEF))
  expect_equal(bounds("CJK Compatibility Ideographs"), c(0xF900, 0xFAFF))
  expect_equal(bounds("Hiragana"), c(0x3040, 0x309F))
  expect_equal(bounds("Katakana"), c(0x30A0, 0x30FF))
  expect_equal(bounds("Katakana Phonetic Extensions"), c(0x31F0, 0x31FF))
  expect_equal(bounds("Halfwidth Katakana"), c(0xFF65, 0xFF9F))
  expect_equal(bounds("Hangul Syllables"), c(0xAC00, 0xD7A3))
  expect_equal(bounds("Hangul Jamo"), c(0x1100, 0x11FF))
  expect_equal(bounds("Hangul Compatibility Jamo"), c(0x3130, 0x318F))
  expect_equal(bounds("Hangul Jamo Extended-A"), c(0xA960, 0xA97F))
  expect_equal(bounds("Hangul Jamo Extended-B"), c(0xD7B0, 0xD7FF))
  expect_equal(bounds("Bopomofo"), c(0x3100, 0x312F))
  expect_equal(bounds("Kanbun"), c(0x3190, 0x319F))
  expect_equal(bounds("CJK Symbols and Punctuation"), c(0x3000, 0x303F))
  # split around Halfwidth Katakana, so it spans FF00-FFEF in two rows
  expect_equal(bounds("Halfwidth and Fullwidth Forms"), c(0xFF00, 0xFFEF))
})

test_that("the halfwidth katakana carve-out leaves no gap", {
  tab <- cjk_blocks()
  ff <- tab[tab$start >= 0xFF00 & tab$end <= 0xFFEF, ]
  ff <- ff[order(ff$start), ]
  expect_equal(as.numeric(ff$start), c(0xFF00, 0xFF65, 0xFFA0))
  expect_equal(as.numeric(ff$end), c(0xFF64, 0xFF9F, 0xFFEF))
  # contiguous cover of the whole FF00-FFEF span
  expect_equal(sum(as.numeric(ff$n_codepoints)), 0xFFEF - 0xFF00 + 1)
})

test_that("code point lookup resolves to the right block", {
  expect_equal(.cjk_scripts_of(0x4E2D), "han")
  expect_equal(.cjk_scripts_of(0x3042), "hiragana")
  expect_equal(.cjk_scripts_of(0x30AB), "katakana")
  expect_equal(.cjk_scripts_of(0xFF76), "katakana")
  expect_equal(.cjk_scripts_of(0xAC00), "hangul")
  expect_equal(.cjk_scripts_of(0x3105), "bopomofo")
  expect_equal(.cjk_scripts_of(0x3190), "kanbun")
  expect_equal(.cjk_scripts_of(0x3002), "punctuation")
  expect_equal(.cjk_scripts_of(0xFF01), "fullwidth")
  expect_equal(.cjk_scripts_of(0x20000), "han")
})

test_that("code points outside every block give NA", {
  # ASCII, Latin-1, Cyrillic, and the gaps between CJK blocks
  expect_true(all(is.na(.cjk_block_index(c(0x41, 0xE9, 0x0416)))))
  expect_true(is.na(.cjk_block_index(0x31E0)))  # between Kanbun and Katakana Ext
  expect_true(is.na(.cjk_block_index(0xD7A4)))  # just past Hangul Syllables
  expect_true(is.na(.cjk_block_index(0x2A6E0))) # just past Extension B
})

test_that("boundary code points are inside their block, neighbours are out", {
  tab <- .cjk_ranges()
  expect_true(all(!is.na(.cjk_block_index(tab$start))))
  expect_true(all(!is.na(.cjk_block_index(tab$end))))
  # one below the lowest start and one above the highest end are outside
  expect_true(is.na(.cjk_block_index(min(tab$start) - 1)))
  expect_true(is.na(.cjk_block_index(max(tab$end) + 1)))
})

test_that("lookup is vectorised and handles empty and NA input", {
  expect_equal(length(.cjk_block_index(integer(0))), 0L)
  expect_true(is.na(.cjk_block_index(NA_integer_)))
  expect_equal(
    is.na(.cjk_block_index(c(0x4E2D, 0x41, 0xAC00))),
    c(FALSE, TRUE, FALSE)
  )
})

test_that("cjk_blocks() is a tibble with the documented shape", {
  tab <- cjk_blocks()
  expect_s3_class(tab, "tbl_df")
  expect_named(tab, c("block", "script", "start", "end", "n_codepoints"))
  expect_type(tab$start, "integer")
  expect_type(tab$end, "integer")
  expect_equal(tab$n_codepoints, as.integer(tab$end - tab$start + 1))
  expect_setequal(
    unique(tab$script),
    c("han", "hiragana", "katakana", "hangul", "bopomofo", "kanbun",
      "punctuation", "fullwidth")
  )
})

test_that("code point splitting distinguishes NA from the empty string", {
  cps <- .cjk_codepoints(c("A", "", NA))
  expect_equal(cps[[1]], 0x41L)
  expect_equal(cps[[2]], integer(0))
  expect_null(cps[[3]])
  expect_equal(.cjk_codepoints(character(0)), list())
})

test_that("supplementary-plane characters are one code point, not two", {
  expect_equal(length(.cjk_codepoints(EXT_B)[[1]]), 1L)
  expect_equal(.cjk_codepoints(EXT_B)[[1]], 0x20000L)
})
