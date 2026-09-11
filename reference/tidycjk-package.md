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

The package has two layers. The **vector layer** takes an atomic
character vector and returns an atomic vector of the same length, in the
manner of stringr:
[`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md),
[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md),
[`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md),
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md),
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md),
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md),
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md),
[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
and
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md).
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
belongs to the same layer but returns a list, because the number of
tokens per string varies. The **tidy layer** takes
`verb(data, col, ...)` with the column unquoted and returns a tibble:
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md),
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
and
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md).

Every vector-layer function is vectorised, propagates `NA` element-wise,
and returns a zero-length vector of the right type for zero-length
input.

## Input encoding

Text has to reach R either as UTF-8 or with its encoding declared, which
means naming the encoding when the file is read:
`read.csv(f, encoding = "GBK")`, `readLines(f, encoding = "Shift_JIS")`,
or
[`stringi::stri_encode()`](https://rdrr.io/pkg/stringi/man/stri_encode.html)
afterwards. That is worth doing deliberately, because what happens
otherwise is not uniform and cannot be made so.

Whether a string of bytes is uninterpretable at all depends on the
session's native encoding: GBK bytes with no declaration are an error in
a UTF-8 locale and ordinary text in a GB18030 one, and both answers are
right. When the bytes genuinely cannot be read, the verbs do not all
report it the same way either – the ones that go through code points
raise "`x` must be valid UTF-8" and name the legacy encodings, while the
ones built on an ICU transform
([`cjk_normalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_normalize.md),
[`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md),
[`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md),
[`cjk_traditionalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md),
[`to_hiragana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md),
[`to_katakana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md),
[`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md),
[`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md))
hand back U+FFFD replacement characters, because that is what the
transform does with a byte it cannot decode.

So do not rely on an error to catch a mis-read file. Declare the
encoding on the way in; a `\uFFFD` in the output means it was not
declared.

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

tidycjk deliberately stops where another package already does the job:

- Chinese word segmentation –
  [jiebaR](https://CRAN.R-project.org/package=jiebaR), which
  [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
  shows how to register as an engine. It was archived from CRAN on
  2025-05-01, which is why it is not a dependency.

- Romanisation – [pinyin](https://CRAN.R-project.org/package=pinyin) and
  [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin).

- Traditional/simplified conversion –
  [tmcn](https://CRAN.R-project.org/package=tmcn) at the character
  level. Character-level conversion is context-blind and often wrong, so
  this package ships none; [OpenCC](https://github.com/BYVoid/OpenCC) is
  the phrase-level answer outside R.

- Japanese-specific utilities –
  [zipangu](https://CRAN.R-project.org/package=zipangu) and
  [Nippon](https://CRAN.R-project.org/package=Nippon).

- Tokenising whitespace-delimited text –
  [tidytext](https://CRAN.R-project.org/package=tidytext), whose
  `unnest_tokens()`
  [`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
  mirrors for text that has no spaces between words.

## Relationship to stringi

tidycjk does not re-implement Unicode. Display width comes from
[`stringi::stri_width()`](https://rdrr.io/pkg/stringi/man/stri_width.html)
and padding from
[`stringi::stri_pad()`](https://rdrr.io/pkg/stringi/man/stri_pad.html) –
[stringi](https://CRAN.R-project.org/package=stringi) – both of which
read the live Unicode tables in [ICU](https://icu.unicode.org), the
Unicode Consortium's C library. tidycjk adds the CJK-specific layer on
top and keeps the naming consistent with the rest of the package. If all
you need is the width of a string, call stringi directly.

## See also

Useful links:

- <https://pursuitofdatascience.github.io/tidycjk/>

- <https://github.com/PursuitOfDataScience/tidycjk>

- Report bugs at
  <https://github.com/PursuitOfDataScience/tidycjk/issues>

## Author

**Maintainer**: Youzhi Yu <yuyouzhi666@icloud.com>
