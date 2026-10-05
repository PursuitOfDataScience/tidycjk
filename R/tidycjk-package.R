#' @keywords internal
#' @aliases tidycjk-package
#'
#' @section Output and naming contract:
#' The package has two layers. The **vector layer** takes a character vector
#' and returns a vector of the same length, in the manner of \pkg{stringr}:
#' detection ([has_cjk()], [cjk_script()], [cjk_detect_language()],
#' [cjk_ratio()]), layout ([cjk_width()], [cjk_pad()], [cjk_truncate()],
#' [cjk_wrap()]), normalisation and cleaning ([to_halfwidth()],
#' [to_fullwidth()], [cjk_normalize()], [cjk_strip_punct()]),
#' transliteration ([cjk_romanize()], [cjk_simplify()],
#' [cjk_traditionalize()], [to_hiragana()], [to_katakana()],
#' [cjk_compose_jamo()]) and ordering ([cjk_sort()], and [cjk_order()], which
#' returns the indices instead). [cjk_segment()], [cjk_sentences()],
#' [cjk_ngrams()] and [cjk_jamo()] belong to the same layer but return a
#' list, because the number of pieces per string varies.
#' The **tidy layer** takes `verb(data, col, ...)` with the column unquoted and
#' returns a tibble: [cjk_summary()], [cjk_char_counts()] and [cjk_tokens()].
#'
#' Every vector-layer function is vectorised, propagates `NA` element-wise
#' (the ordering verbs keep it and sort it last), and returns a zero-length
#' result of the right type for zero-length input. Arguments are checked
#' before that exit, so a bad argument is an error whatever the length of the
#' input.
#'
#' @section Input encoding:
#' Text has to reach R either as UTF-8 or with its encoding declared, which
#' means naming the encoding when the file is read: `read.csv(f, fileEncoding
#' = "GBK")`, `readLines(file(f, encoding = "Shift_JIS"))`, `readr`'s
#' `locale(encoding = "EUC-KR")`, or [stringi::stri_encode()] afterwards.
#' (The `encoding` argument of `read.csv()` and `readLines()` is not the one
#' to use: it only labels the strings, so GBK bytes stay GBK and
#' `read.csv()` fails on them outright in a UTF-8 session.)
#'
#' Whether a string of bytes can be read at all depends on the session's
#' native encoding: GBK bytes with no declaration are invalid in a UTF-8
#' locale and ordinary text in a GB18030 one, and both answers are right.
#' When the bytes cannot be read, every verb stops with "`x` must be valid
#' UTF-8", naming the argument and the legacy encodings, before doing any
#' work; none of them hands back replacement characters or quietly drops the
#' bytes it could not read. A string marked `"bytes"` is refused the same
#' way, because its characters cannot be read either.
#'
#' @section What counts as CJK:
#' A character is CJK when its code point falls in one of the Unicode blocks
#' listed by [cjk_blocks()]. That set is deliberately wide: it includes the
#' ideographs and the three phonetic scripts, but also CJK punctuation and the
#' halfwidth and fullwidth forms, because a text column that has been through a
#' CJK input method carries those too. [cjk_script()] tells you which of them
#' you actually have, so the wide definition never hides the detail.
#'
#' @section Related packages:
#' \pkg{tidycjk} bundles one word segmenter, one romaniser and one script
#' converter, all of them ICU's. These go further, each in its own direction:
#'
#' * Japanese morphological analysis:
#'   [gibasa](https://CRAN.R-project.org/package=gibasa), a MeCab binding that
#'   gives part of speech, lemma and reading, which the `"icu"` engine does
#'   not. [audubon](https://CRAN.R-project.org/package=audubon) collects
#'   Japanese text utilities.
#' * Segmentation with a model rather than a word list:
#'   [udpipe](https://CRAN.R-project.org/package=udpipe), whose Universal
#'   Dependencies models cover Chinese, Japanese and Korean and are
#'   downloaded separately.
#' * Chinese segmentation with jieba's tuned dictionaries:
#'   [jiebaR](https://CRAN.R-project.org/package=jiebaR), archived from CRAN
#'   on 2025-05-01 and installable from GitHub; [cjk_segmenters()] shows how
#'   to register it as an engine.
#' * Pinyin: [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin).
#' * Regional vocabulary in simplified/traditional conversion, which ICU does
#'   not attempt: [OpenCC](https://github.com/BYVoid/OpenCC), outside R.
#' * Tokenising whitespace-delimited text:
#'   [tidytext](https://CRAN.R-project.org/package=tidytext), whose
#'   `unnest_tokens()` [cjk_tokens()] mirrors for text that has no spaces
#'   between words.
#'
#' @section Relationship to stringi:
#' \pkg{tidycjk} does not re-implement Unicode. Width, padding and wrapping
#' come from [stringi::stri_width()], [stringi::stri_pad()] and
#' [stringi::stri_wrap()]; words, sentences and ordering from ICU's break
#' iterators and collators; romanisation and script and kana conversion from
#' ICU transforms. All of it is reached through
#' [stringi](https://CRAN.R-project.org/package=stringi), which carries
#' [ICU](https://icu.unicode.org), the Unicode Consortium's C library.
#' \pkg{tidycjk} adds the CJK layer on top: one contract across the verbs,
#' and guards where ICU's own behaviour is quietly wrong for this use. If
#' all you need is the width of a string, call \pkg{stringi} directly.
"_PACKAGE"
