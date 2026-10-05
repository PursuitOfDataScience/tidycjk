# Convert between hiragana and katakana

`to_hiragana()` maps katakana to hiragana and `to_katakana()` maps the
other way. Kanji, Latin text and punctuation are untouched.

## Usage

``` r
to_hiragana(x)

to_katakana(x)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.
  A list is *not* coerced –
  [`as.character()`](https://rdrr.io/r/base/character.html) deparses one
  rather than coercing it, so the text measured would be the R code that
  builds the list – so a list, a data frame or a function is an error
  naming what to do instead.

## Value

A character vector the same length as `x`. `NA` gives `NA`.

## Details

The two kana syllabaries encode the same sounds, so this conversion is
unambiguous – unlike
[`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md)
or
[`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md),
there is no context that could change the answer. It is the
normalisation you want before comparing or grouping Japanese text, where
the same word may be written either way for emphasis.

It is a normalisation, not a reversible mapping. Applied to text holding
both syllabaries it erases the distinction between them, and that
distinction means something: katakana marks loanwords, onomatopoeia and
emphasis. `to_katakana(to_hiragana(x))` turns any hiragana in `x` into
katakana, and it is not exact even on text that was all katakana,
because ICU's mapping makes a few choices of its own: the small katakana
U+30F5 and U+30F6 become the full-size hiragana U+304B and U+3051, and
the digraphs U+30FF (*koto*) and U+309F (*yori*) are spelled out as two
kana each. Run it one way, and keep the original if you need to go back.

Halfwidth katakana is handled too, and composed while it is: the
halfwidth voiced KA is two code points, U+FF76 and U+FF9E, and
`to_katakana()` returns the single character U+30AC. So no width
conversion is needed first, though
[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
and
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
remain the way to move along the width axis without touching the
syllabary.

## See also

[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
for the width axis,
[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
to see which kana a string is in.

## Examples

``` r
to_hiragana("\u30ab\u30bf\u30ab\u30ca")   # katakana -> hiragana
#> [1] "かたかな"
to_katakana("\u3072\u3089\u304c\u306a")   # and back
#> [1] "ヒラガナ"

# kanji is left alone
to_katakana("\u65e5\u672c\u8a9e\u3067\u3059")
#> [1] "日本語デス"
```
