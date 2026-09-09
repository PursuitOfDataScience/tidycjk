# Which CJK script dominates the text?

`cjk_script()` returns the script that accounts for the most CJK
characters in each string: one of `"han"`, `"hiragana"`, `"katakana"`,
`"hangul"`, `"bopomofo"`, `"kanbun"`, `"punctuation"` or `"fullwidth"`.

## Usage

``` r
cjk_script(x)
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

A character vector the same length as `x`. Strings with no CJK
characters – and `NA` strings, and `""` – give `NA`.

## Details

Only CJK characters vote. Latin letters, digits and whitespace are
ignored entirely, so a string of English with two ideographs in it is
`"han"` rather than something averaged over the whole string.

Ties are broken by first appearance in the string – not alphabetically
and not by the session's collation – so the result never depends on the
locale.

## See also

[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
for the script labels,
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
for the full per-character breakdown rather than just the winner.

## Examples

``` r
# Chinese, Japanese, Korean, then a string with no CJK at all
cjk_script(c("\u4e2d\u6587", "\u3053\u3093\u306b\u3061\u306f",
             "\uc548\ub155", "ascii"))
#> [1] "han"      "hiragana" "hangul"   NA        

# mixed Han and kana: four kana outvote two ideographs
cjk_script("\u65e5\u672c\u306e\u3053\u3068\u3070")
#> [1] "hiragana"
```
