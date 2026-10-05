# tidycjk: Tidy Tools for Chinese, Japanese and Korean Text

A tidy toolkit for text that is written in Chinese, Japanese or Korean.
Most text tooling in R assumes that words are separated by whitespace,
which CJK writing does not use, so ordinary summaries of a text column
either treat a sentence as one undifferentiated blob or split it into
isolated characters. Word segmentation is a pluggable engine, with
dictionary-based segmentation for Chinese and Japanese supplied through
'ICU' and further engines registrable by the caller, because where a
word ends is a fact about a language and not about Unicode. 'tidycjk'
classifies characters by Unicode block, reports which script and which
language a text is written in, measures how much of a text is CJK, and
turns those measurements into tibbles that slot straight into a
'tidyverse' workflow. It also measures display width in terminal
columns, pads, truncates and wraps to a width rather than to a character
count, and normalises fullwidth and halfwidth forms surgically –
including composing halfwidth katakana voiced marks into single code
points – while offering the Unicode normalisation forms separately for
when a full 'NFKC' fold is what is wanted. Romanisation, conversion
between simplified and traditional Han, conversion between the two kana
syllabaries, and decomposition of Hangul syllables into jamo are
provided on the same vectorised contract. Sentence segmentation,
character n-grams, punctuation removal by Unicode category and
locale-aware ordering cover the preprocessing that generic tooling gets
wrong on CJK, where the sentence terminators are ideographic, a code
point sort is not an alphabetical one, and the POSIX punctuation class
is resolved by the C library rather than by Unicode. Language detection
deliberately returns NA rather than guessing when a text is written in
Han characters only, because Japanese written without kana cannot be
distinguished from Chinese by script alone. Everything is derived from
the Unicode specification; the package makes no network requests and
needs no compiled code of its own.

## Output and naming contract

The package has two layers. The **vector layer** takes a character
vector and returns a vector of the same length, in the manner of
stringr: detection
([`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md),
[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md),
[`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md),
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md)),
layout
([`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md),
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md),
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md),
[`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)),
normalisation and cleaning
([`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md),
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md),
[`cjk_normalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_normalize.md),
[`cjk_strip_punct()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_strip_punct.md)),
transliteration
([`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md),
[`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md),
[`cjk_traditionalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md),
[`to_hiragana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md),
[`to_katakana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md),
[`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md))
and ordering
([`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md),
and
[`cjk_order()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md),
which returns the indices instead).
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md),
[`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md),
[`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)
and
[`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
belong to the same layer but return a list, because the number of pieces
per string varies. The **tidy layer** takes `verb(data, col, ...)` with
the column unquoted and returns a tibble:
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md),
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
and
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md).

Every vector-layer function is vectorised, propagates `NA` element-wise
(the ordering verbs keep it and sort it last), and returns a zero-length
result of the right type for zero-length input. Arguments are checked
before that exit, so a bad argument is an error whatever the length of
the input.

## Input encoding

Text has to reach R either as UTF-8 or with its encoding declared, which
means naming the encoding when the file is read:
`read.csv(f, fileEncoding = "GBK")`,
`readLines(file(f, encoding = "Shift_JIS"))`, `readr`'s
`locale(encoding = "EUC-KR")`, or
[`stringi::stri_encode()`](https://rdrr.io/pkg/stringi/man/stri_encode.html)
afterwards. (The `encoding` argument of
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) and
[`readLines()`](https://rdrr.io/r/base/readLines.html) is not the one to
use: it only labels the strings, so GBK bytes stay GBK and
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) fails on them
outright in a UTF-8 session.)

Whether a string of bytes can be read at all depends on the session's
native encoding: GBK bytes with no declaration are invalid in a UTF-8
locale and ordinary text in a GB18030 one, and both answers are right.
When the bytes cannot be read, every verb stops with "`x` must be valid
UTF-8", naming the argument and the legacy encodings, before doing any
work; none of them hands back replacement characters or quietly drops
the bytes it could not read. A string marked `"bytes"` is refused the
same way, because its characters cannot be read either.

## What counts as CJK

A character is CJK when its code point falls in one of the Unicode
blocks listed by
[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md).
That set is deliberately wide: it includes the ideographs and the three
phonetic scripts, but also CJK punctuation and the halfwidth and
fullwidth forms, because a text column that has been through a CJK input
method carries those too.
[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
tells you which of them you actually have, so the wide definition never
hides the detail.

## Related packages

tidycjk bundles one word segmenter, one romaniser and one script
converter, all of them ICU's. These go further, each in its own
direction:

- Japanese morphological analysis:
  [gibasa](https://CRAN.R-project.org/package=gibasa), a MeCab binding
  that gives part of speech, lemma and reading, which the `"icu"` engine
  does not. [audubon](https://CRAN.R-project.org/package=audubon)
  collects Japanese text utilities.

- Segmentation with a model rather than a word list:
  [udpipe](https://CRAN.R-project.org/package=udpipe), whose Universal
  Dependencies models cover Chinese, Japanese and Korean and are
  downloaded separately.

- Chinese segmentation with jieba's tuned dictionaries:
  [jiebaR](https://CRAN.R-project.org/package=jiebaR), archived from
  CRAN on 2025-05-01 and installable from GitHub;
  [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
  shows how to register it as an engine.

- Pinyin: [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin).

- Regional vocabulary in simplified/traditional conversion, which ICU
  does not attempt: [OpenCC](https://github.com/BYVoid/OpenCC), outside
  R.

- Tokenising whitespace-delimited text:
  [tidytext](https://CRAN.R-project.org/package=tidytext), whose
  `unnest_tokens()`
  [`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
  mirrors for text that has no spaces between words.

## Relationship to stringi

tidycjk does not re-implement Unicode. Width, padding and wrapping come
from
[`stringi::stri_width()`](https://rdrr.io/pkg/stringi/man/stri_width.html),
[`stringi::stri_pad()`](https://rdrr.io/pkg/stringi/man/stri_pad.html)
and
[`stringi::stri_wrap()`](https://rdrr.io/pkg/stringi/man/stri_wrap.html);
words, sentences and ordering from ICU's break iterators and collators;
romanisation and script and kana conversion from ICU transforms. All of
it is reached through
[stringi](https://CRAN.R-project.org/package=stringi), which carries
[ICU](https://icu.unicode.org), the Unicode Consortium's C library.
tidycjk adds the CJK layer on top: one contract across the verbs, and
guards where ICU's own behaviour is quietly wrong for this use. If all
you need is the width of a string, call stringi directly.

## See also

Useful links:

- <https://pursuitofdatascience.github.io/tidycjk/>

- <https://github.com/PursuitOfDataScience/tidycjk>

- Report bugs at
  <https://github.com/PursuitOfDataScience/tidycjk/issues>

## Author

**Maintainer**: Youzhi Yu <yuyouzhi666@icloud.com>
