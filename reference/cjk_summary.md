# Summarise CJK content in a text column

`cjk_summary()` reports how much of a text column is CJK: how many
entries contain any CJK at all, what share of entries that is, and the
mean share of each entry's characters that are CJK.

## Usage

``` r
cjk_summary(data, col)
```

## Arguments

- data:

  A data frame or tibble containing a text column.

- col:

  The text column to scan, supplied unquoted.

## Value

A one-row tibble with columns `n_docs` (all entries), `n_with_cjk`
(entries holding at least one CJK character), `prop_with_cjk` and
`mean_ratio`. `prop_with_cjk` is `NA` for a zero-row column, and
`mean_ratio` is `NA` when no entry has a ratio to contribute.

## Details

`prop_with_cjk` counts an entry once however much CJK it holds, so it
answers "how many of these documents are CJK at all". `mean_ratio`
averages
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_ratio.md)
over the entries that have one, so it answers "how CJK are they". A
corpus of English with one ideograph per row scores high on the first
and near zero on the second.

`NA` entries never count as containing CJK, and they do count towards
`n_docs` – so they are in the denominator of `prop_with_cjk` and dilute
it: a column that is half missing cannot score above 0.5. `mean_ratio`
is the one figure they are dropped from, along with empty strings,
because neither has a ratio to contribute.

Grouping is ignored: the result is always one row for the whole column.
Use
[`dplyr::group_modify()`](https://dplyr.tidyverse.org/reference/group_map.html)
if you need it per group.

## See also

[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_char_counts.md)
for the per-character breakdown,
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_ratio.md)
for the per-row measure this averages.

## Examples

``` r
df <- data.frame(
  text = c("\u4e2d\u6587", "mixed \u4e2d\u6587 text", "plain ASCII", NA)
)
cjk_summary(df, text)
#> # A tibble: 1 × 4
#>   n_docs n_with_cjk prop_with_cjk mean_ratio
#>    <int>      <int>         <dbl>      <dbl>
#> 1      4          2           0.5      0.385
```
