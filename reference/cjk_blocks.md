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
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
if you need to see exactly which code points a text contains.

All ten blocks of unified ideographs are covered – the base block and
Extensions A through I. They are not in alphabetical order, because
Unicode allocated Extension I (U+2EBF0) below Extension G (U+30000)
rather than after Extension H, and this table is in code point order.

Ten is every block there was as of Unicode 16.0, which is what this
table is current to. Unicode 17.0 added Extension J at U+323B0-U+3347F,
and it is not here, so
[`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md)
answers `FALSE` for an Extension J ideograph. That is a known limit of
this version of the table rather than a judgement about the block, and
it is the same gap the table once had at Extensions G, H and I.

Ranges are Unicode block bounds, with one exception. Hangul Syllables
stops at U+D7A3, the last assigned syllable, rather than at U+D7AF where
the block ends; the twelve code points in between are unassigned, and
calling them hangul would be reporting text that cannot exist. Elsewhere
the block bound is used as-is, so a handful of unassigned code points
inside a covered block – U+3100 to U+3104 at the head of Bopomofo, for
instance – do count.

Each phonetic script is covered in full, extension blocks included, so
Bopomofo Extended (U+31A0-U+31BF) is here alongside Bopomofo. What is
deliberately absent is everything that is neither a letter, an
ideograph, CJK punctuation nor a width variant: the radical blocks
(U+2E80-U+2EFF and the Kangxi radicals at U+2F00-U+2FDF), CJK Strokes
(U+31C0-U+31EF), and the parenthesised, circled and squared
compatibility symbols in Enclosed CJK Letters and Months and CJK
Compatibility. Those are typographic presentation forms rather than
text, and counting them as CJK would inflate
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md)
on a column that contains no CJK writing at all.

The `script` column takes one of eight values. Six of them name a
writing system – `"han"`, `"hiragana"`, `"katakana"`, `"hangul"`,
`"bopomofo"`, `"kanbun"` – and two are ancillary: `"punctuation"` for
the CJK Symbols and Punctuation block, and `"fullwidth"` for the
width-variant forms. Only the six writing systems are consulted by
[`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md).

## See also

[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
for the dominant script of a string,
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
for a per-character breakdown.

## Examples

``` r
cjk_blocks()
#> # A tibble: 27 × 5
#>    block                              script      start   end n_codepoints
#>    <chr>                              <chr>       <int> <int>        <int>
#>  1 Hangul Jamo                        hangul       4352  4607          256
#>  2 CJK Symbols and Punctuation        punctuation 12288 12351           64
#>  3 Hiragana                           hiragana    12352 12447           96
#>  4 Katakana                           katakana    12448 12543           96
#>  5 Bopomofo                           bopomofo    12544 12591           48
#>  6 Hangul Compatibility Jamo          hangul      12592 12687           96
#>  7 Kanbun                             kanbun      12688 12703           16
#>  8 Bopomofo Extended                  bopomofo    12704 12735           32
#>  9 Katakana Phonetic Extensions       katakana    12784 12799           16
#> 10 CJK Unified Ideographs Extension A han         13312 19903         6592
#> # ℹ 17 more rows

# the blocks that make up "han"
subset(cjk_blocks(), script == "han")
#> # A tibble: 12 × 5
#>    block                                   script  start    end n_codepoints
#>    <chr>                                   <chr>   <int>  <int>        <int>
#>  1 CJK Unified Ideographs Extension A      han     13312  19903         6592
#>  2 CJK Unified Ideographs                  han     19968  40959        20992
#>  3 CJK Compatibility Ideographs            han     63744  64255          512
#>  4 CJK Unified Ideographs Extension B      han    131072 173791        42720
#>  5 CJK Unified Ideographs Extension C      han    173824 177983         4160
#>  6 CJK Unified Ideographs Extension D      han    177984 178207          224
#>  7 CJK Unified Ideographs Extension E      han    178208 183983         5776
#>  8 CJK Unified Ideographs Extension F      han    183984 191471         7488
#>  9 CJK Unified Ideographs Extension I      han    191472 192095          624
#> 10 CJK Compatibility Ideographs Supplement han    194560 195103          544
#> 11 CJK Unified Ideographs Extension G      han    196608 201551         4944
#> 12 CJK Unified Ideographs Extension H      han    201552 205743         4192
```
