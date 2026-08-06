# Pad text to a display width

`cjk_pad()` pads each string with a fill character until it occupies at
least `width` terminal columns. Unlike a pad that counts characters, it
produces columns that actually line up when the text is CJK.

## Usage

``` r
cjk_pad(x, width, side = "right", pad = " ")
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html).

- width:

  Target display width in columns. Recycled against `x`.

- side:

  Which side to add padding to: `"right"` (the default, which
  left-aligns the text), `"left"` or `"both"`.

- pad:

  A single character to pad with. Must be one column wide.

## Value

A character vector the same length as the recycled inputs. Strings
already at least `width` columns wide are returned unchanged –
`cjk_pad()` never truncates. `NA` input gives `NA`.

## See also

[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_truncate.md)
for the other direction;
[`stringi::stri_pad()`](https://rdrr.io/pkg/stringi/man/stri_pad.html),
which this wraps.

## Examples

``` r
# both strings end up six columns wide
cjk_pad(c("\u4e2d\u6587", "abcd"), 6)
#> [1] "中文  " "abcd  "

# right-align instead
cjk_pad(c("\u4e2d\u6587", "abcd"), 6, side = "left")
#> [1] "  中文" "  abcd"

# what nchar()-based padding does to the same input
cat(paste0("|", formatC(c("\u4e2d\u6587", "abcd"), width = -6), "|"),
    sep = "\n")
#> |中文  |
#> |abcd  |
cat(paste0("|", cjk_pad(c("\u4e2d\u6587", "abcd"), 6), "|"),
    sep = "\n")
#> |中文  |
#> |abcd  |
```
