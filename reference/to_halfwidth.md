# Normalise fullwidth and halfwidth forms

`to_halfwidth()` narrows fullwidth ASCII to ASCII, and `to_fullwidth()`
widens ASCII to fullwidth. Both widen halfwidth katakana to its
fullwidth form. Nothing else in the string is touched.

## Usage

``` r
to_halfwidth(x, compose = TRUE)

to_fullwidth(x)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

- compose:

  Fold a syllable and a following voiced mark into the single
  precomposed code point. Defaults to `TRUE`. `FALSE` leaves the pair as
  two code points, which is occasionally what you want if you are
  counting marks rather than characters.

## Value

A character vector the same length as `x`. `NA` input gives `NA`; the
empty string gives the empty string.

## Why not NFKC

`NFKC` normalisation does fix character width, and it is what most
advice recommends. It also rewrites ligatures, superscripts and
subscripts, Roman numerals, circled and parenthesised numbers, the
no-break space, and the CJK compatibility ideographs. A user who wants
fullwidth digits narrowed before parsing them as numbers almost never
wants the rest of that, and the damage is silent. These functions change
width and nothing else.

## What is mapped

- Fullwidth ASCII U+FF01-U+FF5E and ASCII U+0021-U+007E, which differ by
  a constant offset of `0xFEE0`.

- The ideographic space U+3000 and the ASCII space U+0020.

- Halfwidth katakana U+FF61-U+FF9F, which always maps *to* the fullwidth
  form – in both directions. This is the ordinary Japanese convention
  (alphanumerics halfwidth, katakana fullwidth), and it is forced: the
  voiced syllables have no halfwidth form of their own, so fullwidth is
  the only representation that survives a round trip.

That is the whole of it, and the rest of the Halfwidth and Fullwidth
Forms block is left alone – which is worth naming, because those code
points sit immediately beside the ones above. The fullwidth currency and
sign forms U+FFE0-U+FFE6 (cent, pound, not, macron, broken bar, yen,
won) keep their width, so `to_halfwidth()` narrows the digits of a price
and leaves the currency symbol fullwidth. So do the halfwidth Hangul
jamo U+FFA0-U+FFDC, the halfwidth symbol forms U+FFE8-U+FFEE, and the
fullwidth white parentheses U+FF5F and U+FF60. None of them is ASCII on
either side, and fullwidth ASCII is what these functions promise; `NFKC`
maps all of them, along with everything else named under "Why not NFKC"
above.

## Voiced marks

Halfwidth katakana writes a voiced syllable as two code points, a bare
syllable followed by a voiced sound mark. Mapping those to fullwidth
one-for-one leaves the pair intact, so the text still has two code
points where a reader sees one character, and it will not match a
literal written the normal way.

With `compose = TRUE`, the default, the pair is folded into the single
precomposed code point: U+FF76 U+FF9E becomes U+30AC, one character,
rather than U+30AB followed by U+309B. Voicing adds one to the base
throughout the ka, sa, ta and ha rows, and to the katakana iteration
mark U+30FD; the semi-voiced mark adds two and applies to the ha row
only. Five characters break the arithmetic and are mapped explicitly:
U+30A6 voices to U+30F4, and the wa-row characters U+30EF, U+30F0,
U+30F1 and U+30F2 voice into U+30F7 to U+30FA. Every pair agrees with
Unicode NFC composition.

Composition applies to katakana, which is what the width mapping
produces. Both the spacing marks (U+309B, U+309C) and the combining
marks (U+3099, U+309A) are recognised, so katakana that arrived already
decomposed is composed too.

`to_fullwidth()` always composes, because a fullwidth string carrying an
uncomposed voiced mark is not a form anyone wants.

## One deliberate difference from NFKC and from ICU

The Unicode compatibility decomposition of U+FF9E is the *combining*
mark U+3099, so `NFKC` maps the halfwidth voiced mark onto a combining
character, and so does [ICU](https://icu.unicode.org)'s
`Halfwidth-Fullwidth` transform. These functions map it to the *spacing*
mark U+309B instead, and U+FF9F to U+309C.

The difference is only visible with `compose = FALSE`, and the spacing
mark is the safer of the two there: a combining mark left loose attaches
itself to whatever character happens to precede it. ICU shows the hazard
on its own transform – `"a"` followed by U+FF9E comes back as U+FF41
U+3099, a fullwidth `a` wearing a voiced sound mark. With
`compose = TRUE`, the default, the question does not arise: the mark is
folded into the syllable and no bare mark survives either way.

## See also

[`cjk_normalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_normalize.md)
for the Unicode normalisation forms, which fold width along with much
else,
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
for measuring the result.

## Examples

``` r
# fullwidth digits will not parse as numbers until they are narrowed
to_halfwidth("\uff11\uff12\uff13")
#> [1] "123"
as.numeric(to_halfwidth("\uff11\uff12\uff13"))
#> [1] 123

# halfwidth katakana is widened, and the voiced mark is composed:
# U+FF76 U+FF9E (two code points) becomes U+30AC (one)
to_halfwidth("\uff76\uff9e")
#> [1] "ガ"
nchar(to_halfwidth("\uff76\uff9e"))
#> [1] 1
nchar(to_halfwidth("\uff76\uff9e", compose = FALSE))
#> [1] 2

# ASCII round-trips exactly, in both directions
to_halfwidth(to_fullwidth("abc 123"))
#> [1] "abc 123"
to_fullwidth("abc")
#> [1] "ａｂｃ"
```
