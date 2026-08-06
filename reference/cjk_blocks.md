# The Unicode blocks 'tidycjk' recognises

`cjk_blocks()` returns the block table that every other function in the
package consults. It is the package's definition of "CJK", written down
and exported so that it can be inspected rather than guessed at.

## Usage

``` r
cjk_blocks()
```

## Value

A tibble with one row per block and columns `block` (the Unicode block
name), `script` (tidycjk's script label), `start` and `end` (the
inclusive code point bounds, as integers) and `n_codepoints`.

## Details

The table is sorted by `start` and contains no overlapping ranges, which
is what allows a whole corpus of code points to be classified with a
single [`findInterval()`](https://rdrr.io/r/base/findInterval.html) call
rather than a per-character regular expression.

Two of the rows deserve comment. Halfwidth Katakana (U+FF65-U+FF9F) is a
sub-range of the Halfwidth and Fullwidth Forms block; because the
katakana label is the more useful one, the enclosing block appears as
two rows either side of it. And the halfwidth Hangul jamo at
U+FFA0-U+FFDC are reported as `"fullwidth"` rather than `"hangul"`,
because this table follows the block boundaries rather than the Unicode
Script property; use
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_char_counts.md)
if you need to see exactly which code points a text contains.

The `script` column takes one of eight values. Six of them name a
writing system – `"han"`, `"hiragana"`, `"katakana"`, `"hangul"`,
`"bopomofo"`, `"kanbun"` – and two are ancillary: `"punctuation"` for
the CJK Symbols and Punctuation block, and `"fullwidth"` for the
width-variant forms. Only the six writing systems are consulted by
[`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_detect_language.md).

## See also

[`cjk_script()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_script.md)
for the dominant script of a string,
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_char_counts.md)
for a per-character breakdown.

## Examples

``` r
cjk_blocks()
#> # A tibble: 22 × 5
#>    block                              script      start   end n_codepoints
#>    <chr>                              <chr>       <int> <int>        <int>
#>  1 Hangul Jamo                        hangul       4352  4607          256
#>  2 CJK Symbols and Punctuation        punctuation 12288 12351           64
#>  3 Hiragana                           hiragana    12352 12447           96
#>  4 Katakana                           katakana    12448 12543           96
#>  5 Bopomofo                           bopomofo    12544 12591           48
#>  6 Hangul Compatibility Jamo          hangul      12592 12687           96
#>  7 Kanbun                             kanbun      12688 12703           16
#>  8 Katakana Phonetic Extensions       katakana    12784 12799           16
#>  9 CJK Unified Ideographs Extension A han         13312 19903         6592
#> 10 CJK Unified Ideographs             han         19968 40959        20992
#> # ℹ 12 more rows

# the blocks that make up "han"
subset(cjk_blocks(), script == "han")
#> # A tibble: 8 × 5
#>   block                              script  start    end n_codepoints
#>   <chr>                              <chr>   <int>  <int>        <int>
#> 1 CJK Unified Ideographs Extension A han     13312  19903         6592
#> 2 CJK Unified Ideographs             han     19968  40959        20992
#> 3 CJK Compatibility Ideographs       han     63744  64255          512
#> 4 CJK Unified Ideographs Extension B han    131072 173791        42720
#> 5 CJK Unified Ideographs Extension C han    173824 177983         4160
#> 6 CJK Unified Ideographs Extension D han    177984 178207          224
#> 7 CJK Unified Ideographs Extension E han    178208 183983         5776
#> 8 CJK Unified Ideographs Extension F han    183984 191471         7488
```
