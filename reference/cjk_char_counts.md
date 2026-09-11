# Count the CJK characters in a text column

`cjk_char_counts()` returns one row per distinct CJK character in a text
column, with the script and Unicode block it belongs to and how often it
occurred. It is the frequency table you would otherwise write by hand
before every CJK analysis.

## Usage

``` r
cjk_char_counts(data, col)
```

## Arguments

- data:

  A data frame or tibble containing a text column.

- col:

  The text column to scan, supplied unquoted. A non-character column is
  coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html); see
  [`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md)
  for why that makes a numeric column a poor thing to measure.

## Value

A tibble with one row per distinct character and columns `char`,
`codepoint` (integer), `script`, `block` and `n`. A column with no CJK
in it gives a zero-row tibble with those columns.

## Details

Only CJK characters appear; Latin letters, digits and whitespace are
dropped. "CJK" means any block listed by
[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md),
so ideographic punctuation and fullwidth forms are included and are
labelled as such in `script` – which makes this the quickest way to find
out that a column you thought was clean is full of fullwidth spaces.

Rows are ordered by descending count, and ties are broken by first
appearance in the column rather than by the session's collation, so the
output does not change with the locale.

Grouping is ignored: the counts are always for the whole column. Use
[`dplyr::group_modify()`](https://dplyr.tidyverse.org/reference/group_map.html)
if you need them per group.

## See also

[`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md)
for the column-level figures,
[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
for the block table these labels come from.

## Examples

``` r
df <- data.frame(
  text = c("\u4e2d\u6587\u4e2d\u6587",
           "\u65e5\u672c\u306e\u3053\u3068\u3070",
           "ascii only")
)
cjk_char_counts(df, text)
#> # A tibble: 8 × 5
#>   char  codepoint script   block                      n
#>   <chr>     <int> <chr>    <chr>                  <int>
#> 1 中        20013 han      CJK Unified Ideographs     2
#> 2 文        25991 han      CJK Unified Ideographs     2
#> 3 日        26085 han      CJK Unified Ideographs     1
#> 4 本        26412 han      CJK Unified Ideographs     1
#> 5 の        12398 hiragana Hiragana                   1
#> 6 こ        12371 hiragana Hiragana                   1
#> 7 と        12392 hiragana Hiragana                   1
#> 8 ば        12400 hiragana Hiragana                   1
```
