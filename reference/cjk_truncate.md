# Truncate text to a display width

`cjk_truncate()` shortens each string so that it fits in `width`
terminal columns, appending an ellipsis when anything was removed.
Because CJK characters are two columns wide, truncating by character
count overshoots the available space by up to a factor of two.

## Usage

``` r
cjk_truncate(x, width, ellipsis = "...")
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

- width:

  Maximum display width in columns. Recycled against `x`; a pair of
  lengths that does not recycle cleanly is an error.

- ellipsis:

  String to append when the text was shortened. Defaults to `"..."`. The
  single-character ellipsis U+2026 is one column rather than three, so
  more of the text survives.

## Value

A character vector the same length as the recycled inputs. Strings that
already fit are returned unchanged. `NA` input, and an `NA` width, give
`NA`.

## Details

The result is never wider than `width`. When a string has to be
shortened, the ellipsis is included in the budget, so the kept text is
trimmed to `width - cjk_width(ellipsis)` columns. If `width` is too
small even for the ellipsis, the ellipsis itself is truncated.

Cuts never separate a combining mark from the character it modifies: a
zero-width character immediately after the cut point is carried along
with it.

## See also

[`cjk_pad()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_pad.md)
for the other direction;
[`cjk_width()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_width.md)
for the measure both use.

## Examples

``` r
# six columns is three ideographs
cjk_truncate("\u4e2d\u6587\u4e2d\u6587\u4e2d\u6587", 6)
#> [1] "中..."

# ASCII, same budget
cjk_truncate("abcdefghij", 6)
#> [1] "abc..."

# already fits, so nothing happens
cjk_truncate("\u4e2d\u6587", 10)
#> [1] "中文"
```
