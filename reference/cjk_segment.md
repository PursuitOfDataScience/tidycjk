# Split CJK text into words

`cjk_segment()` splits each string into tokens. Chinese and Japanese do
not put spaces between words, so splitting on whitespace returns the
whole sentence as one token; this dispatches to a segmentation engine
instead.

## Usage

``` r
cjk_segment(x, engine, ...)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

- engine:

  Name of a segmentation engine, or a function implementing one.
  Required; see
  [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md).

- ...:

  Passed to the engine. Name these so they are not a prefix of `engine`
  (or of `data`/`col` in
  [`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md));
  see "Passing arguments to an engine" in
  [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md).

## Value

A list the same length as `x`, each element a character vector of
tokens. `NA` input gives `NA_character_`; the empty string gives
`character(0)`.

## Details

Two engines ship with the package. `"icu"` is a real word segmenter,
using the dictionary ICU carries inside stringi, so it costs no
dependency you have not already installed. `"character"` tokenises by
character rather than by word.

`engine` is required and has no default, because `"character"` answers a
different question from the one a caller asking for words is asking, and
quietly returning it would be the mistake this package exists to avoid.
The two also differ on punctuation: `"icu"` drops it, `"character"`
keeps CJK punctuation as tokens.
[`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
lists what is available and shows how to register another.

## See also

[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
for the tidy version,
[`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
for the engines and for registering one.

## Examples

``` r
# a real word segmenter: four words, not six characters
cjk_segment("\u6211\u4eca\u5929\u5f88\u958b\u5fc3", engine = "icu")
#> [[1]]
#> [1] "我"   "今天" "很"   "開心"
#> 

# the dictionary-free baseline, one token per CJK character
cjk_segment("\u6211\u4eca\u5929\u5f88\u958b\u5fc3", engine = "character")
#> [[1]]
#> [1] "我" "今" "天" "很" "開" "心"
#> 

# non-CJK runs stay whole and are split on whitespace
cjk_segment("hello \u4e2d\u6587 world", engine = "character")
#> [[1]]
#> [1] "hello" "中"    "文"    "world"
#> 
```
