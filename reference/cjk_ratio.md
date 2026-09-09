# What share of the text is CJK?

`cjk_ratio()` reports the proportion of each string's characters that
fall in a CJK Unicode block, from 0 to 1. It is the natural way to find
the rows of a mixed corpus that are actually CJK, as opposed to the ones
carrying a single stray ideograph.

## Usage

``` r
cjk_ratio(x)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

## Value

A numeric vector the same length as `x`, between 0 and 1. `NA` input
gives `NA`. The empty string gives `NA` rather than 0, because the ratio
is 0/0 and undefined.

## Details

Characters are counted as Unicode code points, so an ideograph from a
supplementary plane counts once, not twice. The denominator is every
character in the string, including spaces and Latin punctuation.

## See also

[`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md)
for the yes/no version,
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md)
for the column-level summary.

## Examples

``` r
cjk_ratio(c("\u4e2d\u6587", "half \u4e2d\u6587", "none", "", NA))
#> [1] 1.0000000 0.2857143 0.0000000        NA        NA
```
