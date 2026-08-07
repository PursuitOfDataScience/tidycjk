# Display width in terminal columns

`cjk_width()` returns the number of columns each string occupies in a
monospaced terminal. CJK characters occupy two columns, not one, which
is the reason [`nchar()`](https://rdrr.io/r/base/nchar.html) misaligns
every console table containing CJK text.

## Usage

``` r
cjk_width(x)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html).

## Value

An integer vector the same length as `x`. `NA` input gives `NA`; the
empty string gives `0`.

## Details

Width follows Unicode Annex \#11 (East Asian Width). Characters whose
East Asian Width is Wide or Fullwidth are two columns; combining marks
and format characters (general categories `Mn`, `Me`, `Cf`), C0 and C1
control codes, and Hangul Jamo medial vowels and final consonants are
zero; everything else is one.

The computation is
[`stringi::stri_width()`](https://rdrr.io/pkg/stringi/man/stri_width.html),
which reads the Unicode tables shipped with
[ICU](https://icu.unicode.org), the Unicode Consortium's C library.
`cjk_width()` exists so that the width, the padding and the truncation
in a CJK pipeline all read the same way; if width is all you need,
`stri_width()` is the more direct call.

East Asian Ambiguous characters – Greek letters, some box-drawing, the
degree sign – are one column. They render as two in a CJK-configured
terminal and one everywhere else, and no library can resolve that
without knowing the terminal.

## See also

[`cjk_pad()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_pad.md)
and
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_truncate.md),
which lay text out by width;
[`stringi::stri_width()`](https://rdrr.io/pkg/stringi/man/stri_width.html)
for the underlying computation.

## Examples

``` r
# two characters, four columns
cjk_width("\u4e2d\u6587")
#> [1] 4

# two characters, two columns
cjk_width("ab")
#> [1] 2

# nchar() cannot tell these apart; cjk_width() can
nchar(c("\u4e2d\u6587", "abcd"))
#> [1] 2 4
cjk_width(c("\u4e2d\u6587", "abcd"))
#> [1] 4 4
```
