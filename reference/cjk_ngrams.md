# Character n-grams

Returns every run of `n` consecutive characters in each string.
Character n-grams are the standard dictionary-free baseline for Chinese
information retrieval and text classification, and for many tasks they
are competitive with word segmentation while needing no model at all.

## Usage

``` r
cjk_ngrams(x, n = 2L)
```

## Arguments

- x:

  A character vector.

- n:

  Size of each gram, a single positive whole number. Defaults to `2`,
  the usual choice for Chinese.

## Value

A list the same length as `x`, each element a character vector of
n-grams in order of occurrence, with repeats kept. `NA` gives
`NA_character_`; the empty string gives `character(0)`.

## Details

For a language that writes word boundaries, n-grams are a crude feature.
For Chinese they are not: most words are one or two characters, so
character bigrams capture the majority of them without a dictionary, and
they degrade gracefully on the out-of-vocabulary terms – names, slang,
new coinages – where a segmenter is least reliable. Compare against
`cjk_segment(engine = "icu")` on your own corpus rather than assuming
either wins.

Characters are counted as code points, the same unit
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md)
uses, so a supplementary-plane ideograph counts once. A combining mark
or a variation selector is a code point too, and therefore its own
position in the window: a base character followed by a selector
contributes two grams rather than one. That is consistent with the rest
of the package, and it is worth knowing if your corpus carries
ideographic variation sequences.

## Whitespace ends a window

An n-gram is never formed across a space, so no gram spans two words of
a Latin run or two sides of an ideographic space U+3000. Punctuation is
kept, because in CJK it is often informative and it is cheap to filter
afterwards; whitespace is not, because a gram containing one is an
artefact of layout.

A string shorter than `n` characters yields `character(0)` rather than a
padded gram.

## See also

[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
for word tokens,
[`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md)
for sentences.

## Examples

``` r
# U+4E2D U+6587 U+5F88 U+597D, "Chinese is good"
cjk_ngrams("\u4e2d\u6587\u5f88\u597d")
#> [[1]]
#> [1] "中文" "文很" "很好"
#> 

# trigrams, and the short-string case
cjk_ngrams("\u4e2d\u6587\u5f88\u597d", n = 3)
#> [[1]]
#> [1] "中文很" "文很好"
#> 
cjk_ngrams("\u4e2d")
#> [[1]]
#> character(0)
#> 

# no gram is formed across the space
cjk_ngrams("\u4e2d\u6587 \u4f60\u597d")
#> [[1]]
#> [1] "中文" "你好"
#> 
```
