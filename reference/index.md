# Package index

## Summarise a text column

Verbs taking `(data, column)` and returning a tibble, for a dplyr
pipeline.

- [`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md)
  : Summarise CJK content in a text column
- [`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
  : Count the CJK characters in a text column
- [`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
  : One row per token

## Segment

Splitting CJK text into words. Where a word ends is a fact about a
language rather than about Unicode, so the engine is a required,
pluggable choice. Dictionary-based segmentation for Chinese and Japanese
ships via ICU; further engines can be registered.

- [`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
  : Split CJK text into words
- [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
  [`register_cjk_segmenter()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
  : Segmentation engines

## Sentences and n-grams

Preprocessing that generic tooling gets wrong on CJK: sentence
terminators are U+3002, U+FF01 and U+FF1F rather than “.!?”, and
character n-grams are the dictionary-free baseline for Chinese.

- [`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md)
  : Split text into sentences
- [`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)
  : Character n-grams

## Order

ICU collation. R’s sort() puts Han in code point order, which is not
pronunciation, stroke or frequency.

- [`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)
  [`cjk_order()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)
  : Sort CJK text by pronunciation or stroke

## Detect & classify

- [`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md)
  : Does the text contain CJK characters?
- [`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
  : Which CJK script dominates the text?
- [`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md)
  : Which language is the text written in?
- [`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md)
  : What share of the text is CJK?

## Display width

Terminal columns rather than characters, so CJK tables line up.

- [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
  : Display width in terminal columns
- [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
  : Pad text to a display width
- [`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md)
  : Truncate text to a display width
- [`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)
  : Wrap text to a display width

## Normalise width variants

- [`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
  [`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
  : Normalise fullwidth and halfwidth forms

## Transliterate

Romanisation, Han script conversion, the kana syllabaries and Hangul
jamo. Exact for kana and jamo; an approximation, documented as such, for
romanisation and simplified/traditional conversion.

- [`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md)
  : Romanise CJK text
- [`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md)
  [`cjk_traditionalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md)
  : Convert between simplified and traditional Han
- [`to_hiragana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md)
  [`to_katakana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md)
  : Convert between hiragana and katakana
- [`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
  [`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
  : Decompose and recompose Hangul syllables

## Reference data

- [`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
  : The Unicode blocks 'tidycjk' recognises

## Package

- [`tidycjk`](https://pursuitofdatascience.github.io/tidycjk/reference/tidycjk-package.md)
  [`tidycjk-package`](https://pursuitofdatascience.github.io/tidycjk/reference/tidycjk-package.md)
  : tidycjk: Tidy Tools for Chinese, Japanese and Korean Text
