# tidycjk: Tidy Tools for Chinese, Japanese and Korean Text

A tidy toolkit for text that is written in Chinese, Japanese or Korean.
Most text tooling in R assumes that words are separated by whitespace,
which CJK writing does not use, so ordinary summaries of a text column
either treat a sentence as one undifferentiated blob or split it into
isolated characters. 'tidycjk' classifies characters by Unicode block,
reports which script and which language a text is written in, measures
how much of a text is CJK, and turns those measurements into tibbles
that slot straight into a 'tidyverse' workflow. It also measures display
width in terminal columns, pads and truncates to a width rather than to
a character count, and normalises fullwidth and halfwidth forms
surgically – including composing halfwidth katakana voiced marks into
single code points – without the collateral damage of a full 'NFKC'
pass. Language detection deliberately returns NA rather than guessing
when a text is written in Han characters only, because Japanese written
without kana cannot be distinguished from Chinese by script alone.
Everything is derived from the Unicode specification; the package makes
no network requests and needs no compiled code of its own.

## Output and naming contract

The package has two layers. The **vector layer** takes an atomic
character vector and returns an atomic vector of the same length, in the
manner of stringr:
[`has_cjk()`](https://pursuitofdatascience.github.io/tidyckj/reference/has_cjk.md),
[`cjk_script()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_script.md),
[`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_detect_language.md),
[`cjk_width()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_width.md),
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_pad.md),
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_truncate.md),
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_ratio.md),
[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidyckj/reference/to_halfwidth.md)
and
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidyckj/reference/to_halfwidth.md).
The **tidy layer** takes `verb(data, col, ...)` with the column unquoted
and returns a tibble:
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_summary.md)
and
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_char_counts.md).

Every vector-layer function is vectorised, propagates `NA` element-wise,
and returns a zero-length vector of the right type for zero-length
input.

## What counts as CJK

A character is CJK when its code point falls in one of the Unicode
blocks listed by
[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_blocks.md).
That set is deliberately wide: it includes the ideographs and the three
phonetic scripts, but also CJK punctuation and the halfwidth and
fullwidth forms, because a text column that has been through a CJK input
method carries those too.
[`cjk_script()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_script.md)
tells you which of them you actually have, so the wide definition never
hides the detail.

## Relationship to stringi

tidycjk does not re-implement Unicode. Display width comes from
[`stringi::stri_width()`](https://rdrr.io/pkg/stringi/man/stri_width.html)
and padding from
[`stringi::stri_pad()`](https://rdrr.io/pkg/stringi/man/stri_pad.html),
both of which read ICU's live Unicode tables; tidycjk adds the
CJK-specific layer on top and keeps the naming consistent with the rest
of the package. If all you need is the width of a string, call stringi
directly.

## See also

Useful links:

- <https://pursuitofdatascience.github.io/tidyckj/>

- <https://github.com/PursuitOfDataScience/tidyckj>

- Report bugs at
  <https://github.com/PursuitOfDataScience/tidyckj/issues>

## Author

**Maintainer**: Youzhi Yu <yuyouzhi666@icloud.com>
