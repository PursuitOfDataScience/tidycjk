# Convert between simplified and traditional Han

`cjk_simplify()` maps traditional Han characters to simplified;
`cjk_traditionalize()` maps the other way. Characters outside Han, and
characters with no counterpart, are left alone.

## Usage

``` r
cjk_simplify(x)

cjk_traditionalize(x)
```

## Arguments

- x:

  A character vector.

## Value

A character vector the same length as `x`. `NA` gives `NA`.

## Details

This is ICU's `Simplified-Traditional` pair, and it is context-aware
rather than a per-character table. Simplified to traditional is
genuinely one-to-many – U+53D1 is U+767C ("to send") or U+9AEE ("hair")
depending on the word, and U+5E72 is U+4E7E, U+5E79 or U+5E72 – and ICU
picks correctly from the surrounding characters. Fourteen such pairs
were checked, including the ones where the same character splits both
ways ("after" against "empress", "inside" against "kilometre"), and
every one came out right.

What it does not do is substitute regional vocabulary. The two standards
differ in the words they use as well as in glyph shape, and that is
lexical rather than orthographic. The simplified word for "software",
U+8F6F U+4EF6, converts to U+8EDF U+4EF6 – the correct characters, and
the wrong word in Taiwan, where the term is U+8EDF U+9AD4. "Mouse"
becomes U+9F20 U+6A19 rather than U+6ED1 U+9F20.

So use these for script conversion, which is what they are good at, and
reach for [OpenCC](https://github.com/BYVoid/OpenCC) when you need
Taiwanese or Hong Kong idiom – its regional configurations are what
carry that.

## See also

[`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md),
[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
for the width axis.

## Examples

``` r
# U+6F22 U+5B57 / U+6C49 U+5B57, "Han characters"
cjk_simplify("\u6f22\u5b57")        # traditional -> simplified
#> [1] "汉字"
cjk_traditionalize("\u6c49\u5b57")  # and back
#> [1] "漢字"

# context decides a one-to-many character: "hair" vs "to send"
cjk_traditionalize(c("\u5934\u53d1", "\u53d1\u9001"))
#> [1] "頭髮" "發送"

# but regional vocabulary is not substituted: the Taiwanese word differs
cjk_traditionalize("\u8f6f\u4ef6")  # -> U+8EDF U+4EF6, not U+8EDF U+9AD4
#> [1] "軟件"
```
