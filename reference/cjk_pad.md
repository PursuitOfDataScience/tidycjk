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
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

- width:

  Target display width in columns. Recycled against `x`; a pair of
  lengths that does not recycle cleanly is an error rather than a
  warning and a short result.

- side:

  Which side to add padding to: `"right"` (the default, which
  left-aligns the text), `"left"` or `"both"`.

- pad:

  A single character to pad with. Must be one column wide.

## Value

A character vector the same length as the recycled inputs. Strings
already at least `width` columns wide are returned unchanged –
`cjk_pad()` never truncates. `NA` input, and an `NA` width, give `NA`.

## See also

[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md)
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

# a pad that counts characters rather than columns: nchar() calls the two
# strings 2 and 4 long, so the CJK cell is handed four spaces and comes out
# eight columns wide. (formatC() and format() are column-aware and get this
# right; sprintf("%-6s") counts bytes and under-fills instead.)
pad_by_char <- function(x, n) paste0(x, strrep(" ", pmax(n - nchar(x), 0)))
cat(paste0("|", pad_by_char(c("\u4e2d\u6587", "abcd"), 6), "|"), sep = "\n")
#> |中文    |
#> |abcd  |
cat(paste0("|", cjk_pad(c("\u4e2d\u6587", "abcd"), 6), "|"), sep = "\n")
#> |中文  |
#> |abcd  |
```
