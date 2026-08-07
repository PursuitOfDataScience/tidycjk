# Package index

## Summarise a text column

Verbs taking `(data, column)` and returning a tibble, for a dplyr
pipeline.

- [`cjk_summary()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_summary.md)
  : Summarise CJK content in a text column
- [`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_char_counts.md)
  : Count the CJK characters in a text column
- [`cjk_tokens()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_tokens.md)
  : One row per token

## Segment

Splitting CJK text into words. Where a word ends is a fact about a
language rather than about Unicode, so no segmenter is bundled and the
engine is a required, pluggable choice.

- [`cjk_segment()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segment.md)
  : Split CJK text into words
- [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segmenters.md)
  [`register_cjk_segmenter()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segmenters.md)
  : Segmentation engines

## Detect & classify

- [`has_cjk()`](https://pursuitofdatascience.github.io/tidyckj/reference/has_cjk.md)
  : Does the text contain CJK characters?
- [`cjk_script()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_script.md)
  : Which CJK script dominates the text?
- [`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_detect_language.md)
  : Which language is the text written in?
- [`cjk_ratio()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_ratio.md)
  : What share of the text is CJK?

## Display width

Terminal columns rather than characters, so CJK tables line up.

- [`cjk_width()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_width.md)
  : Display width in terminal columns
- [`cjk_pad()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_pad.md)
  : Pad text to a display width
- [`cjk_truncate()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_truncate.md)
  : Truncate text to a display width

## Normalise width variants

- [`to_halfwidth()`](https://pursuitofdatascience.github.io/tidyckj/reference/to_halfwidth.md)
  [`to_fullwidth()`](https://pursuitofdatascience.github.io/tidyckj/reference/to_halfwidth.md)
  : Normalise fullwidth and halfwidth forms

## Reference data

- [`cjk_blocks()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_blocks.md)
  : The Unicode blocks 'tidycjk' recognises

## Package

- [`tidycjk`](https://pursuitofdatascience.github.io/tidyckj/reference/tidycjk-package.md)
  [`tidycjk-package`](https://pursuitofdatascience.github.io/tidyckj/reference/tidycjk-package.md)
  : tidycjk: Tidy Tools for Chinese, Japanese and Korean Text
