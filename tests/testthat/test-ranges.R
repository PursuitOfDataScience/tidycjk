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
  expect_equal(bounds("CJK Unified Ideographs Extension G"), c(0x30000, 0x3134F))
  expect_equal(bounds("CJK Unified Ideographs Extension H"), c(0x31350, 0x323AF))
  expect_equal(bounds("CJK Unified Ideographs Extension I"), c(0x2EBF0, 0x2EE5F))
  expect_equal(bounds("CJK Compatibility Ideographs"), c(0xF900, 0xFAFF))
  expect_equal(bounds("CJK Compatibility Ideographs Supplement"),
               c(0x2F800, 0x2FA1F))
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
  expect_equal(bounds("Bopomofo Extended"), c(0x31A0, 0x31BF))
  expect_equal(bounds("Kanbun"), c(0x3190, 0x319F))
  expect_equal(bounds("CJK Symbols and Punctuation"), c(0x3000, 0x303F))
  # split around Halfwidth Katakana, so it spans FF00-FFEF in two rows
  expect_equal(bounds("Halfwidth and Fullwidth Forms"), c(0xFF00, 0xFFEF))
})

test_that("every unified ideograph extension is covered, A through I", {
  # The table was written when Extension F was the last one. G, H and I are
  # ordinary ideographs, so leaving them out made has_cjk() answer FALSE for a
  # real Chinese character -- and Extension I sits at U+2EBF0, *below* G and H,
  # so the rows are in code point order rather than alphabetical order.
  tab <- cjk_blocks()
  ext <- grep("^CJK Unified Ideographs Extension ", tab$block, value = TRUE)
  expect_setequal(
    ext,
    paste("CJK Unified Ideographs Extension", c("A", "B", "C", "D", "E", "F",
                                                "G", "H", "I"))
  )
  expect_true(all(tab$script[tab$block %in% ext] == "han"))
  expect_equal(
    which(tab$block == "CJK Unified Ideographs Extension I") <
      which(tab$block == "CJK Unified Ideographs Extension G"),
    TRUE
  )
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
  expect_equal(.cjk_scripts_of(0x2EBF0), "han")  # Extension I
  expect_equal(.cjk_scripts_of(0x2F800), "han")  # Compatibility Supplement
  expect_equal(.cjk_scripts_of(0x30000), "han")  # Extension G
  expect_equal(.cjk_scripts_of(0x31350), "han")  # Extension H
})

test_that("code points outside every block give NA", {
  # ASCII, Latin-1, Cyrillic, and code points this table deliberately omits
  expect_true(all(is.na(.cjk_block_index(c(0x41, 0xE9, 0x0416)))))
  # U+31E0 is in CJK Strokes (U+31C0-U+31EF), and U+2F00 opens the Kangxi
  # radicals. Both are Script=Han in Unicode and both are out of scope here:
  # they are presentation forms for radicals and strokes rather than text, and
  # counting them would inflate cjk_ratio() on a column with no CJK writing in
  # it. Do not "fix" these by widening the table -- see ?cjk_blocks.
  expect_true(is.na(.cjk_block_index(0x31E0)))
  expect_true(is.na(.cjk_block_index(0x2F00)))
  # both ends of CJK Radicals Supplement, the block ?cjk_blocks names as
  # U+2E80-U+2EFF -- block bounds, matching the convention that page states
  expect_true(is.na(.cjk_block_index(0x2E80)))
  expect_true(is.na(.cjk_block_index(0x2EFF)))
  expect_true(is.na(.cjk_block_index(0x2FDF)))  # last of Kangxi Radicals
  expect_true(is.na(.cjk_block_index(0x31EF)))  # last of CJK Strokes
  expect_true(is.na(.cjk_block_index(0x3251)))  # CIRCLED NUMBER TWENTY ONE
  expect_true(is.na(.cjk_block_index(0x2A6E0))) # just past Extension B
})

test_that("the two documented edges of the table are where the docs say", {
  # Hangul Syllables stops at the last assigned syllable, not at the block
  # bound: U+D7A4-U+D7AF are inside the UCD block "Hangul Syllables" and are
  # unassigned, so they are deliberately out. ("just past Hangul Syllables"
  # was the old comment here, and it was wrong about which side of the block
  # boundary U+D7A4 falls on.)
  expect_true(has_cjk("\uD7A3"))
  expect_true(is.na(.cjk_block_index(0xD7A4)))
  expect_true(is.na(.cjk_block_index(0xD7AF)))
  expect_true(has_cjk("\uD7B0"))               # Hangul Jamo Extended-B starts
  # ...and everywhere else the block bound is used as-is, unassigned code
  # points included, so the exception really is an exception
  expect_true(has_cjk("\u3100"))               # unassigned, head of Bopomofo

  # The table is current to Unicode 16.0. Extension J (U+323B0-U+3347F) arrived
  # in Unicode 17.0 and is a known gap, documented in ?cjk_blocks. If this ever
  # fails, the table gained the block and the help page needs updating with it.
  expect_equal(max(cjk_blocks()$end), 0x323AFL)
  expect_false(has_cjk(stringi::stri_enc_fromutf32(list(0x323B0))))
})

test_that("every phonetic script is covered including its extension block", {
  # Bopomofo Extended holds 32 of the 75 assigned bopomofo letters -- the
  # Minnan and Hakka ones. Omitting it made has_cjk() answer FALSE, and
  # cjk_script() NA, for an ordinary letter of a script the package claims to
  # cover: the same bug the ideograph extensions had.
  tab <- cjk_blocks()
  expect_equal(
    as.numeric(unlist(tab[tab$block == "Bopomofo Extended", c("start", "end")])),
    c(0x31A0, 0x31BF)
  )
  expect_equal(.cjk_scripts_of(0x31A0), "bopomofo")   # BOPOMOFO LETTER BU
  expect_equal(.cjk_scripts_of(0x31BF), "bopomofo")
  # U+31A0 U+31A1, Minnan letters BU and ZI
  expect_true(has_cjk("\u31a0\u31a1"))
  expect_equal(cjk_script("\u31a0\u31a1"), "bopomofo")
  expect_equal(cjk_ratio("\u31a0\u31a1"), 1)
  # bopomofo annotates Mandarin, so it settles the language either way
  expect_equal(cjk_detect_language("\u31a0\u31a1"), "chinese")
  expect_equal(
    cjk_char_counts(data.frame(text = "\u31a0"), text)$block,
    "Bopomofo Extended"
  )
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

test_that("the cached block table is stable across calls", {
  # .cjk_ranges() memoises, because .cjk_block_index() is called once per
  # element and rebuilding the table there made it a per-element cost. The
  # cache must be invisible: same value every time, and no caller mutates it.
  #
  # Comparing two calls to each other would only say the function is
  # deterministic, which it would be with no cache at all. Emptying the cache
  # and watching it fill puts the memoisation itself under test.
  rm(list = ls(.cjk_cache), envir = .cjk_cache)
  expect_length(ls(.cjk_cache), 0L)
  first <- .cjk_ranges()
  expect_identical(ls(.cjk_cache), "ranges")
  expect_identical(.cjk_ranges(), first)
  # cjk_blocks() is the exported view of the same table. Comparing it to
  # itself was the assertion the comment above warns against -- it holds
  # for any deterministic function and says nothing about the cache. What
  # matters is the other half of "invisible": a caller who edits the tibble
  # they were handed must not reach the table everything else reads.
  handed_out <- cjk_blocks()
  handed_out$block[[1L]] <- "MUTATED"
  expect_false(identical(cjk_blocks()$block[[1L]], "MUTATED"))
  expect_false(any(.cjk_ranges()$block == "MUTATED"))
  before <- .cjk_ranges()
  invisible(cjk_char_counts(data.frame(text = ZH), text))
  invisible(cjk_script(ZH))
  expect_identical(.cjk_ranges(), before)
})

test_that("code point splitting distinguishes NA from the empty string", {
  cps <- .cjk_codepoints(c("A", "", NA))
  expect_equal(cps[[1]], 0x41L)
  expect_equal(cps[[2]], integer(0))
  expect_null(cps[[3]])
  expect_equal(.cjk_codepoints(character(0)), list())
})

test_that("the encoding handler rewrites stringi's message and nothing else", {
  # Version-independent: drive .cjk_stri() directly rather than relying on any
  # particular stringi deciding to raise. Older stringi (1.5.3) only *warns*
  # on invalid UTF-8 in stri_enc_toutf32(), so a sweep over the exported verbs
  # is not a portable assertion -- see the next test.
  expect_error(
    .cjk_stri(stop("invalid UTF-8 byte sequence detected; try calling ...")),
    "must be valid UTF-8"
  )
  expect_error(
    .cjk_stri(stop("invalid UTF-8 byte sequence detected; try calling ...")),
    "stri_encode"
  )
  # the rewritten message must not name the stringi function the caller never
  # called, which is the whole point of the handler
  err <- tryCatch(.cjk_stri(stop("invalid UTF-8 byte sequence detected")),
                  error = function(e) conditionMessage(e))
  expect_false(grepl("stri_enc_toutf8", err, fixed = TRUE))
})

test_that("mis-encoded input is reported in tidycjk's own terms", {
  bad <- rawToChar(as.raw(c(0x61, 0xFF, 0x62)))
  errs <- inherits(
    try(stringi::stri_enc_toutf32(bad), silent = TRUE), "try-error"
  )
  skip_if_not(errs, "this stringi warns rather than errors on invalid UTF-8")
  verbs <- list(
    function() has_cjk(bad),
    function() cjk_script(bad),
    function() cjk_ratio(bad),
    function() cjk_detect_language(bad),
    function() cjk_width(bad),
    function() cjk_pad(bad, 10),
    function() cjk_truncate(bad, 2),
    function() to_halfwidth(bad),
    function() to_fullwidth(bad),
    function() cjk_segment(bad, engine = "character"),
    function() cjk_summary(data.frame(t = bad), t),
    function() cjk_char_counts(data.frame(t = bad), t),
    function() cjk_tokens(data.frame(t = bad), t, engine = "character")
  )
  for (f in verbs) {
    expect_error(f(), "must be valid UTF-8")
  }
})

test_that("errors that are not about encoding are re-thrown untouched", {
  # the handler matches on the message, so it must not relabel anything else
  expect_error(cjk_pad("a", 5, pad = "\u3000"), "one column")
  expect_error(cjk_truncate("abc", 5, ellipsis = NA_character_), "single")
  expect_error(cjk_pad("abc", "5"), "numeric")
  expect_error(.cjk_stri(stop("something else entirely")), "something else")
})

test_that("a leading byte-order mark survives into the code points", {
  # stri_enc_toutf32() treats a *leading* U+FEFF as a byte-order mark and drops
  # it. Excel on Windows writes UTF-8 CSVs with one and read.csv() hands it
  # back on the first field of the first row, so this is ordinary input, not a
  # curiosity. The values, not just the lengths, are pinned: a mark that came
  # back in the wrong position would pass a length check.
  bom <- "\uFEFF"
  zh <- "\u4e2d"
  expect_equal(.cjk_codepoints(paste0(bom, zh))[[1]], c(0xFEFFL, 0x4E2DL))
  # a mark anywhere but the front was never dropped, and still is not
  expect_equal(.cjk_codepoints(paste0(zh, bom, zh))[[1]],
               c(0x4E2DL, 0xFEFFL, 0x4E2DL))
  # a lone mark, and two in a row
  expect_equal(.cjk_codepoints(bom)[[1]], 0xFEFFL)
  expect_equal(.cjk_codepoints(paste0(bom, bom))[[1]], c(0xFEFFL, 0xFEFFL))
  # the detection must not disturb NA, "" or ordinary strings
  cps <- .cjk_codepoints(c(paste0(bom, zh), "ab", NA, zh))
  expect_equal(cps[[1]], c(0xFEFFL, 0x4E2DL))
  expect_equal(cps[[2]], c(0x61L, 0x62L))
  expect_null(cps[[3]])
  expect_equal(cps[[4]], 0x4E2DL)
  # NA and "" keep their documented, distinct shapes
  expect_null(.cjk_codepoints(NA)[[1]])
  expect_equal(.cjk_codepoints("")[[1]], integer(0))
})

test_that("the byte-order mark reaches the verbs built on those code points", {
  # Dropping it made cjk_ratio() answer 1 for a string only half of which is
  # CJK, and made to_halfwidth() delete a character while promising to change
  # width and nothing else. Both consequences, pinned.
  bom <- "\uFEFF"
  zh <- "\u4e2d"
  expect_equal(cjk_ratio(paste0(bom, zh)), 0.5)
  expect_equal(utf8ToInt(to_halfwidth(paste0(bom, zh))), c(0xFEFFL, 0x4E2DL))
  # U+FEFF is in no CJK block, so it never counts as CJK and costs no columns
  expect_true(is.na(.cjk_block_index(0xFEFF)))
  expect_false(has_cjk(bom))
  expect_equal(cjk_width(paste0(bom, zh)), 2L)
  expect_equal(nrow(cjk_char_counts(data.frame(t = paste0(bom, zh)), t)), 1L)
})

test_that("a BOM on some elements only is handled element by element", {
  # The three BOM helpers all guard their work behind an any() over the
  # elements that need it, which is a cheap exit for the common no-BOM
  # vector. A vector where only *some* elements carry one is the case that
  # tells that gate apart from a wrong one: an all() there would skip the
  # whole vector because of the elements with nothing to do, leaving the
  # mark in the output of every verb below. Every earlier BOM test used a
  # length-one input, so none of them could see it.
  bom <- "\uFEFF"
  zh <- "\u4e2d"
  mixed <- c(paste0(bom, zh), zh, NA)
  # the detector reports per element, including across an NA
  expect_identical(.cjk_leading_bom(mixed), c(1L, 0L, 0L))
  expect_identical(.cjk_leading_bom(c(NA, paste0(bom, bom, zh))), c(0L, 2L))
  # strip and restore are inverses on a mixed vector, NA included
  n <- .cjk_leading_bom(mixed)
  expect_identical(.cjk_strip_bom(mixed, n), c(zh, zh, NA))
  expect_identical(.cjk_restore_bom(.cjk_strip_bom(mixed, n), n), mixed)
  # and the mark survives into the verbs built on them
  expect_identical(cjk_segment(mixed, engine = "character")[[1L]],
                   c(bom, zh))
  expect_identical(cjk_segment(mixed, engine = "character")[[2L]], zh)
  expect_identical(cjk_strip_punct(c(paste0(bom, zh, "\uff0c"),
                                     paste0(zh, "\uff0c")),
                                   replacement = ""),
                   c(paste0(bom, zh), zh))
  expect_equal(cjk_ratio(mixed), c(0.5, 1, NA))
  # Every verb that carries a BOM across has its own any() gate, so each
  # needs the mixed vector: cjk_pad() restores the mark after stri_pad()
  # eats it, and the rest strip and restore around their own work.
  expect_identical(cjk_pad(mixed, 4L),
                   c(paste0(bom, zh, "  "), paste0(zh, "  "), NA))
  expect_identical(cjk_wrap(mixed, 4L), c(paste0(bom, zh), zh, NA))
  expect_identical(cjk_truncate(mixed, 4L), c(paste0(bom, zh), zh, NA))
  expect_identical(cjk_sentences(mixed)[[1L]], paste0(bom, zh))
  expect_identical(to_halfwidth(mixed), c(paste0(bom, zh), zh, NA))
  expect_identical(cjk_simplify(mixed), c(paste0(bom, zh), zh, NA))
  # and the mark is never *added* to the element that arrived without one
  for (out in list(cjk_pad(mixed, 4L), cjk_wrap(mixed, 4L),
                   cjk_truncate(mixed, 4L), to_halfwidth(mixed),
                   cjk_simplify(mixed), cjk_strip_punct(mixed))) {
    expect_false(startsWith(out[[2L]], bom))
  }
})

test_that("the BOM detector must not be built out of stringi", {
  # stringi strips a leading BOM from the *pattern* too, so a pattern of U+FEFF
  # alone arrives empty: stri_startswith_fixed() then warns and returns NA, and
  # that NA reaching any() made .cjk_codepoints() error on every non-NA input.
  # base startsWith() is immune. This test exists so nobody "simplifies" the
  # detector back to the stringi call.
  expect_true(startsWith("\uFEFF\u4e2d", "\uFEFF"))
  expect_false(startsWith("\u4e2d\uFEFF", "\uFEFF"))

  # stringi's side is recorded, not asserted. Requiring the warning would make
  # this file fail the day stringi stops stripping BOMs from patterns -- a fix
  # on their side, not a defect here, since the detector is base startsWith().
  # So the check tolerates either answer and the invariant below carries the
  # weight.
  observed <- withCallingHandlers(
    tryCatch(stringi::stri_startswith_fixed("\uFEFF\u4e2d", "\uFEFF"),
             error = function(e) NA),
    warning = function(w) invokeRestart("muffleWarning")
  )
  expect_true(is.na(observed) || isTRUE(observed))
  # what must hold whichever way stringi goes
  expect_equal(.cjk_codepoints("\uFEFF\u4e2d")[[1]], c(0xFEFFL, 0x4E2DL))
})

test_that("the NA guards are belt-and-braces, and stringi still agrees", {
  # Three lines in R/ exist only to enforce the package's NA contract when the
  # thing underneath might not: the NA restore in cjk_width(), the one in
  # .cjk_rewidth(), and the is.na() inside .cjk_block_index()'s subscripted
  # assignment. Mutation-testing showed all three can be deleted without a
  # single test failing, because base R and the current stringi already do the
  # work -- which is exactly why the fact needs pinning rather than assuming.
  # DESCRIPTION imports stringi with no version bound, so if any of these
  # change, this test is the thing that notices.
  expect_true(is.na(stringi::stri_width(NA_character_)))
  expect_equal(stringi::stri_width(c("ab", NA, "")), c(2L, NA, 0L))
  expect_true(is.na(stringi::stri_enc_fromutf32(list(NULL))))
  expect_true(is.na(findInterval(NA_integer_, c(1L, 5L))))
  expect_true(is.na(findInterval(NaN, c(1L, 5L))))

  # ...and the contract itself, which must hold whichever layer delivers it
  expect_true(is.na(cjk_width(NA_character_)))
  expect_true(is.na(to_halfwidth(NA_character_)))
  expect_true(is.na(to_fullwidth(NA_character_)))
  expect_true(is.na(.cjk_block_index(NA_integer_)))
  expect_true(is.na(.cjk_block_index(NaN)))
  expect_equal(.cjk_block_index(c(0x4E2DL, NA_integer_))[[2]], NA_integer_)
})

test_that("the fixtures are what helper-fixtures.R says they are", {
  # Every fixture carries a prose claim, and roughly twelve hundred assertions
  # reason from those claims -- "JA_MIXED is 2 kanji + 4 kana, so kana wins" is
  # how a reader checks that a test tests what it says. Nothing verified the
  # claims themselves, so a mis-edited fixture would surface as a puzzling
  # failure somewhere else, or as a test quietly proving something different.
  #
  # Checked with the package's own block lookup, so this needs no network and
  # no Unicode tables beyond the ones tidycjk already ships.
  scripts <- function(x) .cjk_scripts_of(.cjk_codepoints(x)[[1]])

  expect_equal(scripts(JA_KANA), rep("hiragana", 5L))
  expect_equal(scripts(JA_MIXED), c("han", "han", rep("hiragana", 4L)))
  expect_equal(scripts(JA_KANJI_ONLY), rep("han", 3L))
  expect_equal(scripts(JA_KATAKANA), rep("katakana", 4L))
  expect_equal(scripts(KO), rep("hangul", 5L))
  expect_equal(scripts(ZH), rep("han", 2L))
  expect_equal(scripts(ZH_SENTENCE), rep("han", 6L))
  expect_equal(scripts(BOPOMOFO), rep("bopomofo", 2L))
  expect_equal(scripts(KANBUN), rep("kanbun", 2L))
  expect_equal(scripts(KO_JAMO), rep("hangul", 2L))

  # each extension fixture is the FIRST code point of the block it names, which
  # is what makes it a boundary test rather than an arbitrary sample
  tab <- cjk_blocks()
  first_of <- function(block) tab$start[match(block, tab$block)]
  expect_equal(utf8ToInt(EXT_B), first_of("CJK Unified Ideographs Extension B"))
  expect_equal(utf8ToInt(EXT_G), first_of("CJK Unified Ideographs Extension G"))
  expect_equal(utf8ToInt(EXT_H), first_of("CJK Unified Ideographs Extension H"))
  expect_equal(utf8ToInt(EXT_I), first_of("CJK Unified Ideographs Extension I"))
  expect_equal(utf8ToInt(COMPAT_SUP),
               first_of("CJK Compatibility Ideographs Supplement"))

  # the normalisation fixtures, and the spacing/combining distinction the
  # ?to_halfwidth divergence turns on
  expect_equal(utf8ToInt(HW_KA_VOICED), c(0xFF76L, 0xFF9EL))
  expect_equal(utf8ToInt(HW_KA), 0xFF76L)
  expect_equal(utf8ToInt(FW_KA), 0x30ABL)
  expect_equal(utf8ToInt(FW_GA), 0x30ACL)
  expect_equal(utf8ToInt(VOICED_MARK), 0x309BL)
  expect_true(stringi::stri_detect_charclass(VOICED_MARK, "\\p{Sk}"))
  expect_true(stringi::stri_detect_charclass("\u3099", "\\p{Mn}"))
  expect_equal(utf8ToInt(FW_DIGITS), c(0xFF11L, 0xFF12L, 0xFF13L))
  expect_equal(utf8ToInt(IDEOGRAPHIC_SPACE), 0x3000L)
  expect_equal(utf8ToInt(IDEOGRAPHIC_STOP), 0x3002L)

  # the two non-CJK fixtures the width rules turn on: Mn and Cf, both 0 columns
  expect_true(stringi::stri_detect_charclass("\u0301", "\\p{Mn}"))
  expect_true(stringi::stri_detect_charclass("\u200b", "\\p{Cf}"))
  expect_equal(cjk_width("\u0301"), 0L)
  expect_equal(cjk_width("\u200b"), 0L)
})

test_that("supplementary-plane characters are one code point, not two", {
  expect_equal(length(.cjk_codepoints(EXT_B)[[1]]), 1L)
  expect_equal(.cjk_codepoints(EXT_B)[[1]], 0x20000L)
})


test_that("the two reported shapes for undecodable bytes are what ?tidycjk says", {
  # ?tidycjk states that a byte sequence R cannot decode is reported two
  # ways: the code-point path raises our message, the ICU-transform path
  # returns U+FFFD. Both are stringi's behaviour rather than ours, so this
  # pins the claim the documentation rests on.
  #
  # Skipped outside a UTF-8 locale on purpose, and this is the point of the
  # documented caveat: in a GB18030 or C locale these same bytes are
  # interpretable in the native encoding and nothing is wrong with them.
  skip_if_not(grepl("UTF-8|utf8", Sys.getlocale("LC_CTYPE"), ignore.case = TRUE),
              "needs a UTF-8 locale; see ?tidycjk on input encoding")
  zh <- "\u4e2d\u6587"
  gbk <- rawToChar(iconv(zh, "UTF-8", "GBK", toRaw = TRUE)[[1]])
  skip_if(is.na(gbk) || !nzchar(gbk), "iconv has no GBK on this build")
  expect_false(validUTF8(gbk))

  # And skipped unless stringi actually raises, which is the caveat the
  # test above this one already records: stringi 1.5.3 only *warns* on
  # invalid UTF-8 in stri_enc_toutf32(), so on that build nothing reaches
  # our handler and there is no error to assert. Writing the sweep without
  # this guard is what made the test fail on R 3.6.3.
  raises <- tryCatch({
    suppressWarnings(stringi::stri_enc_toutf32(gbk)); FALSE
  }, error = function(e) TRUE)
  skip_if_not(raises, "this stringi warns rather than raises on invalid UTF-8")

  # the code-point path raises, and names the legacy encodings
  expect_error(suppressWarnings(has_cjk(gbk)), "must be valid UTF-8")
  expect_error(suppressWarnings(has_cjk(gbk)), "GBK")

  # the ICU-transform path returns replacement characters instead
  out <- suppressWarnings(cjk_normalize(gbk))
  expect_false(grepl("must be valid", out, fixed = TRUE))
  expect_true(grepl("\ufffd", out, fixed = TRUE))
  expect_true(grepl("\ufffd", suppressWarnings(cjk_romanize(gbk)), fixed = TRUE))

  # and text whose encoding IS declared goes through untouched
  declared <- iconv(gbk, "GBK", "UTF-8")
  expect_equal(declared, zh)
  expect_true(has_cjk(declared))
  expect_equal(cjk_normalize(declared), zh)
})


test_that("an enumerated argument is rejected by name, not as 'arg'", {
  # match.arg() reports a non-character value as "'arg' must be NULL or a
  # character vector", which names a variable the caller never wrote. The
  # other 34 messages in this package all name their argument, so the two
  # enumerated ones are held to the same standard.
  for (v in list(NA, 1, list(1), TRUE, data.frame(a = 1))) {
    expect_error(cjk_pad("a", 8, side = v), "`side` must be one of",
                 fixed = TRUE)
    expect_error(cjk_normalize("a", form = v), "`form` must be one of",
                 fixed = TRUE)
  }
  # and the message lists the choices
  expect_error(cjk_pad("a", 8, side = NA), "\"right\", \"left\", \"both\"",
               fixed = TRUE)
  expect_error(cjk_normalize("a", form = NA), "\"nfkc_casefold\"",
               fixed = TRUE)

  # every value match.arg() accepted before is still accepted, unchanged:
  # partial matching, NULL meaning the first choice, and the defaults
  expect_equal(cjk_pad("ab", 6, side = "l"), cjk_pad("ab", 6, side = "left"))
  expect_equal(cjk_pad("ab", 6, side = "b"), cjk_pad("ab", 6, side = "both"))
  expect_equal(cjk_pad("ab", 6, side = NULL), cjk_pad("ab", 6))
  expect_equal(cjk_normalize("a", form = NULL), cjk_normalize("a"))
  expect_equal(cjk_normalize("\uff21", form = "nfkc"), "A")
  # an unmatched value keeps match.arg's own wording, which lists the choices
  expect_error(cjk_pad("a", 8, side = "middle"), "should be one of")
  expect_error(cjk_normalize("a", form = "NFC"), "should be one of")
})


test_that("a list argument is an error, not the R code that builds it", {
  # as.character() deparses a list rather than coercing it, so every verb
  # measured `c("a", "b")` -- eleven characters of R source -- as if a caller
  # had passed that string. cjk_width(list(c("a", "b"))) answered 11. The
  # list a caller has in hand is normally another verb's output, which is
  # what made this reachable rather than theoretical.
  L <- list(c("a", "b"))
  one <- list(has_cjk, cjk_ratio, cjk_script, cjk_detect_language, cjk_width,
              cjk_jamo, cjk_compose_jamo, cjk_romanize, cjk_simplify,
              cjk_traditionalize, to_hiragana, to_katakana, to_fullwidth,
              to_halfwidth, cjk_normalize, cjk_strip_punct, cjk_sentences,
              cjk_sort, cjk_order)
  for (f in one) {
    expect_error(f(L), "must be an atomic vector")
  }
  expect_error(cjk_ngrams(L, 1L), "must be an atomic vector")
  for (f in list(cjk_pad, cjk_truncate, cjk_wrap)) {
    expect_error(f(L, 4L), "must be an atomic vector")
  }
  # the same for anything else as.character() would deparse rather than coerce
  for (v in list(data.frame(a = 1), mean, globalenv(), quote(f(1)))) {
    expect_error(cjk_width(v), "must be an atomic vector")
  }
  # and the message names a way out rather than only the fault
  e <- tryCatch(cjk_width(L), error = function(e) e)
  expect_match(conditionMessage(e), "unlist\\(\\)")
  expect_match(conditionMessage(e), "vapply")

  # The documented jamo round trip needs the re-joining step, and saying so
  # is now enforced: the direct composition is an error.
  zh <- "\ud55c\uae00"
  expect_error(cjk_compose_jamo(cjk_jamo(zh)), "must be an atomic vector")
  expect_identical(
    cjk_compose_jamo(vapply(cjk_jamo(zh), paste, character(1), collapse = "")),
    zh)

  # a list-column reaching the tidy verbs is caught the same way, and names
  # `col` rather than `x` because that is the argument the caller wrote
  df <- data.frame(id = 1:2)
  df$t <- list(c("a", "b"), "\u4e2d")
  for (f in list(cjk_summary, cjk_char_counts)) {
    expect_error(f(df, t), "`col` must be an atomic vector")
  }
  expect_error(cjk_tokens(df, t, engine = "character"),
               "`col` must be an atomic vector")
})

test_that("the coercions the guard is careful to keep still work", {
  # The point of coercing at all is that a factor or a numeric column goes
  # through; only the shapes as.character() deparses are refused. NULL is
  # the one that needs saying out loud: is.atomic(NULL) was TRUE until
  # R 4.4.0 and is FALSE after it, so an is.atomic() guard alone would have
  # started rejecting it halfway through the versions this package supports.
  expect_identical(cjk_width(NULL), integer(0))
  expect_identical(to_fullwidth(NULL), character(0))
  expect_identical(has_cjk(NULL), logical(0))
  expect_identical(cjk_jamo(NULL), list())
  expect_identical(cjk_width(character(0)), integer(0))
  expect_identical(cjk_width(factor("\u4e2d")), 2L)
  expect_identical(has_cjk(factor(c("\u4e2d", "a"))), c(TRUE, FALSE))
  expect_identical(cjk_width(123), 3L)
  expect_identical(cjk_width(TRUE), 4L)
  expect_identical(cjk_width(NA), NA_integer_)
})

test_that("every error the package constructs carries no call", {
  # All 36 message-constructing stop() calls pass call. = FALSE, so an error
  # reads as this package's own sentence rather than as an R traceback naming
  # a function the caller may not know they were in. Nothing enforced that: a
  # mutation flipping call. = FALSE to TRUE survived the whole suite, because
  # the message text -- which is all expect_error() looks at -- is unchanged.
  # conditionCall() is what tells them apart. The three remaining stop()
  # calls re-raise a foreign condition and must NOT strip its call; that is
  # the last test in this file.
  nocall <- function(expr) {
    e <- tryCatch(expr, error = function(e) e)
    expect_s3_class(e, "error")
    expect_null(conditionCall(e))
  }
  zh <- "\u4e2d\u6587"
  nocall(cjk_segment(zh, engine = 1))
  nocall(cjk_segment(zh, engine = "nope"))
  nocall(cjk_segment(zh, engine = ""))
  nocall(cjk_tokens(data.frame(t = zh), t, engine = "character",
                    output = NA_character_))
  nocall(cjk_tokens(data.frame(t = zh), t))
  nocall(cjk_pad(zh, "wide"))
  nocall(cjk_pad(zh, Inf))
  nocall(cjk_pad(zh, integer(0)))
  nocall(cjk_pad(zh, 6, pad = NA))
  nocall(cjk_pad(zh, 6, side = NA))
  nocall(cjk_truncate(zh, 6, ellipsis = NA))
  nocall(cjk_wrap(zh, 6, indent = -1))
  nocall(cjk_wrap(zh, 6, locale = "nonsense"))
  nocall(cjk_sort(zh, locale = "nonsense"))
  nocall(cjk_sort(zh, decreasing = NA))
  nocall(cjk_sentences(zh, locale = "nonsense"))
  nocall(cjk_ngrams(zh, n = 0))
  nocall(cjk_normalize(zh, form = NA))
  nocall(cjk_normalize(zh, drop_variation_selectors = NA))
  nocall(cjk_strip_punct(zh, replacement = NA_character_))
  nocall(cjk_strip_punct(zh, symbols = NA))
  nocall(cjk_romanize(zh, ascii = NA))
  nocall(to_halfwidth(zh, compose = NA))
  nocall(cjk_detect_language(zh, han_only = 1))
  nocall(register_cjk_segmenter("", function(x, ...) as.list(x)))
  nocall(register_cjk_segmenter("ok", "not a function"))
  nocall(cjk_summary(matrix(zh), t))
  nocall(.cjk_stri(stop("invalid UTF-8 byte sequence detected")))
})

test_that("no stop() in the package can be reached without call. = FALSE", {
  # The structural counterpart to the tests either side of it. Enumerating error
  # paths by hand covers only the paths I thought of: a mutation sweep found
  # call. = FALSE silently flippable at four sites, and the hand-written list
  # still does not reach every one of the 36. Walking the namespace's own
  # syntax trees needs no such list -- it sees every stop() there is, in
  # nested handlers included, and it reads the installed package rather than
  # R/*.R so it works where CRAN runs tests from and no sources are shipped.
  ns <- asNamespace("tidycjk")
  stops <- list()
  walk <- function(e, where) {
    if (!is.call(e)) {
      return(invisible(NULL))
    }
    if (identical(e[[1L]], quote(stop))) {
      stops[[length(stops) + 1L]] <<- list(where = where, call = e)
    }
    # Recurse by passing e[[i]] as an argument rather than looping over
    # as.list(e). A call can hold the empty symbol -- the second slot of
    # x[, 1] -- and binding that to a loop variable makes the next use of it
    # an "argument is missing" error, even from identical(); handing it to a
    # function instead lets it arrive harmlessly as a name.
    recurse <- function(part) {
      if (is.function(part)) part <- body(part)
      walk(part, where)
    }
    for (i in seq_along(e)) {
      recurse(e[[i]])
    }
    invisible(NULL)
  }
  for (nm in ls(ns, all.names = TRUE)) {
    obj <- get(nm, envir = ns)
    if (is.function(obj)) walk(body(obj), nm)
  }
  # Sanity: the walk found the stop() calls rather than silently nothing.
  expect_gt(length(stops), 30L)

  reraise <- character(0)
  bad <- character(0)
  for (s in stops) {
    args <- as.list(s$call)[-1L]
    nms <- names(args)
    if (!is.null(nms) && "call." %in% nms) {
      if (!identical(args[["call."]], FALSE)) {
        bad <- c(bad, paste0(s$where, ": call. = ",
                             paste(deparse(args[["call."]]), collapse = " ")))
      }
    } else if (length(args) == 1L && is.symbol(args[[1L]])) {
      # stop(e) re-raises a condition built elsewhere; stripping its call
      # would relabel someone else's failure as ours. Tested just below.
      reraise <- c(reraise, s$where)
    } else {
      bad <- c(bad, paste0(s$where, ": ",
                           paste(deparse(s$call), collapse = " ")))
    }
  }
  expect_identical(bad, character(0))
  # And the exceptions are only ever the three relabelling handlers, so a
  # fourth bare stop(e) has to be added deliberately rather than by drift.
  expect_setequal(reraise, c(".cjk_pull", ".cjk_stri", ".cjk_trans"))
})

test_that("a foreign error is re-raised with its call and message intact", {
  # The counterpart to the convention above. .cjk_stri() and .cjk_pull()
  # relabel exactly one failure each and re-throw everything else with
  # stop(e) -- so for those the call must survive, not be stripped. Testing
  # only the no-call side would let a handler that swallowed every error into
  # its own message pass, which is the mistake both comments warn against.
  e0 <- simpleError("totally unrelated failure", call = quote(f(1)))
  for (expr in list(
    quote(.cjk_stri(stop(e0))),
    quote(.cjk_pull(stop(e0), data.frame(a = 1)))
  )) {
    e <- tryCatch(eval(expr), error = function(e) e)
    expect_identical(conditionMessage(e), "totally unrelated failure")
    expect_identical(conditionCall(e), quote(f(1)))
  }
})
