# Does the text contain CJK characters?

`has_cjk()` reports, for each element, whether the string contains at
least one character from a CJK Unicode block.

## Usage

``` r
has_cjk(x)
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

A logical vector the same length as `x`. `NA` input gives `NA`; the
empty string gives `FALSE`.

## Details

"CJK" here means any block listed by
[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md),
which includes CJK punctuation and the halfwidth and fullwidth forms as
well as the ideographs and the phonetic scripts. That is deliberate – a
column typed with a CJK input method carries the punctuation too – but
it does mean that a string of nothing but ideographic full stops
(U+3002) is `TRUE`. Use
[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
when you need to know *which* kind of CJK you have.

## See also

[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md)
for how much of the text is CJK,
[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
for which script it is.

## Examples

``` r
# U+4E2D U+6587, "Chinese writing"
has_cjk(c("\u4e2d\u6587", "plain ASCII", NA))
#> [1]  TRUE FALSE    NA

# the ideographic full stop U+3002 counts, by design
has_cjk("\u3002")
#> [1] TRUE
```
