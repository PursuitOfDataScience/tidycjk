# One row per token

`cjk_tokens()` segments a text column and returns one row per token,
carrying the other columns along. It is the CJK-aware counterpart of
[tidytext](https://CRAN.R-project.org/package=tidytext)'s
`unnest_tokens()`, which splits on whitespace and therefore returns CJK
sentences whole.

## Usage

``` r
cjk_tokens(data, col, engine, ...)
```

## Arguments

- data:

  A data frame or tibble containing a text column.

- col:

  The text column to scan, supplied unquoted. A non-character column is
  coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html); see
  [`has_cjk()`](https://pursuitofdatascience.github.io/tidyckj/reference/has_cjk.md)
  for why that makes a numeric column a poor thing to measure.

- engine:

  Name of a segmentation engine, or a function implementing one.
  Required; see
  [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segmenters.md).

- ...:

  Passed to the engine. Name these so they are not a prefix of `engine`
  (or of `data`/`col` in `cjk_tokens()`); see "Passing arguments to an
  engine" in
  [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segmenters.md).

## Value

`data`, as a tibble, with one row per token and an added `token` column.
Row order follows the input, and tokens within a row follow the text.

## Details

Rows that produce no tokens – empty strings, and text with nothing an
engine recognises – are dropped, as they are in tidytext. `NA` text
yields one row with an `NA` token, so a missing document does not
silently vanish from the output.

The token column is called `token` and is added to `data`; an existing
column of that name is replaced. As with
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segment.md),
`engine` is required.

Grouping is dropped, as it is by
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_summary.md):
the result is a plain tibble even when `data` is a `grouped_df`. Regroup
it afterwards if you need the groups back.

## See also

[`cjk_segment()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segment.md)
for the vector version,
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_char_counts.md)
when you want characters rather than words.

## Examples

``` r
df <- data.frame(
  id = 1:2,
  text = c("\u6211\u5f88\u958b\u5fc3", "hello \u4e2d\u6587")
)
cjk_tokens(df, text, engine = "character")
#> # A tibble: 7 × 3
#>      id text       token
#>   <int> <chr>      <chr>
#> 1     1 我很開心   我   
#> 2     1 我很開心   很   
#> 3     1 我很開心   開   
#> 4     1 我很開心   心   
#> 5     2 hello 中文 hello
#> 6     2 hello 中文 中   
#> 7     2 hello 中文 文   
```
