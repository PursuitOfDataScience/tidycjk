# Sort CJK text by pronunciation or stroke

`cjk_sort()` returns `x` ordered by an ICU collation; `cjk_order()`
returns the permutation that would do it, for reordering a data frame.

## Usage

``` r
cjk_sort(x, locale = NULL, decreasing = FALSE)

cjk_order(x, locale = NULL, decreasing = FALSE)
```

## Arguments

- x:

  A character vector.

- locale:

  ICU locale naming the collation, e.g. `"zh"`. `NULL`, the default,
  uses the session default – which is unlikely to order Han usefully, so
  name one.

- decreasing:

  Reverse the order.

## Value

`cjk_sort()` a character vector the same length as `x`; `cjk_order()` an
integer vector of indices.

## Details

[`sort()`](https://rdrr.io/r/base/sort.html) on Chinese gives code point
order, which is a real order and the wrong one. The unified ideographs
are laid out in KangXi radical-stroke order, so within the base block
sorting by code point sorts by radical. What it is not is phonetic,
which is what someone sorting a column of names is after. It also stops
being radical order across blocks: every Extension A character
(U+3400-U+4DBF) sorts ahead of every base-block one, so a rare character
lands nowhere near the common characters sharing its radical.

ICU carries real collations. With `locale = "zh"` Han sorts by pinyin,
so a column of Chinese surnames comes out in the order a Chinese reader
expects.

## Choosing the order

The collation is selected by the locale string, including the BCP 47
variants:

- `"zh"` – Mandarin pinyin.

- `"zh-u-co-stroke"` – stroke count, the convention in many indexes.

- `"zh-u-co-zhuyin"` – bopomofo order.

- `"ja"` and `"ko"` – Japanese and Korean.

A locale whose *language* ICU has no collation for is an error here
rather than the silent fallback to root collation stringi would
otherwise give you, because that fallback produces a plausible-looking
wrong order. An unrecognised *region* is not an error: `"zh-CH"`, a typo
for `"zh-CN"`, resolves to `"zh"` and still sorts by pinyin, which is
the right answer.

## Missing values

`NA` sorts last and is kept, so the result is always the same length as
`x`.
[`stringi::stri_sort()`](https://rdrr.io/pkg/stringi/man/stri_sort.html)
drops missing values by default, which would silently shorten a column.

## See also

[`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md),
whose `ascii = TRUE` output gives a sort key you can use where no ICU
locale is available.

## Examples

``` r
# Chinese surnames: Zhang, Wang, Li
x <- c("\u5f35", "\u738b", "\u674e")

sort(x)                        # code point order: not an order
#> [1] "張" "李" "王"
cjk_sort(x, locale = "zh")     # pinyin: Li, Wang, Zhang
#> [1] "李" "王" "張"

# stroke order instead
cjk_sort(x, locale = "zh-u-co-stroke")
#> [1] "王" "李" "張"

# reorder a data frame
df <- data.frame(name = x)
df[cjk_order(x, locale = "zh"), , drop = FALSE]
#>   name
#> 3   李
#> 2   王
#> 1   張
```
