# Apply Unicode normalisation

`cjk_normalize()` puts text into one of the Unicode normalisation forms,
so that strings which look the same compare the same. It optionally
removes variation selectors first, which defeat an exact match on their
own and which only one of the forms takes out.

## Usage

``` r
cjk_normalize(
  x,
  form = c("nfc", "nfd", "nfkc", "nfkd", "nfkc_casefold"),
  drop_variation_selectors = FALSE
)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

- form:

  One of `"nfc"`, `"nfd"`, `"nfkc"`, `"nfkd"` or `"nfkc_casefold"`.
  Defaults to `"nfc"`.

- drop_variation_selectors:

  Remove variation selectors before normalising. Defaults to `FALSE`.

## Value

A character vector the same length as `x`. `NA` input gives `NA`; the
empty string gives the empty string.

## Details

Two strings can render identically and still differ as data. Japanese
U+304C is one code point or two depending on where the text came from; a
compatibility ideograph and its unified equivalent are distinct code
points for the same character; an ideographic variation sequence adds an
invisible selector that only a font reacts to. Any of these will split
one token into two in a frequency count, a join or a `group_by()`.

## Which form

`"nfc"` and `"nfd"` are canonical: they preserve the identity of every
character and differ only in whether marks are composed. `"nfc"` is the
form almost all text is already in and the right default.

`"nfkc"` and `"nfkd"` add compatibility folding, which is lossy by
design. On CJK text it narrows fullwidth ASCII, widens halfwidth
katakana, turns the ideographic space U+3000 into a plain space, and
unpacks circled numbers and squared kana – U+3314 becomes the two
characters U+30AD U+30ED. That is the right trade for search and token
matching and the wrong one for anything that has to be shown back to a
reader. `"nfkc_casefold"` is `"nfkc"` plus case folding, for
case-insensitive matching of the Latin mixed into CJK text.

`"nfkc_casefold"` also deletes every code point Unicode marks
`Default_Ignorable`, which the other four forms all keep. That is the
variation selectors below, and with them the zero-width joiner and
non-joiner, the zero-width space, the soft hyphen, the tag characters
and U+FEFF – so a byte-order mark at the front of a string survives the
other forms and does not survive this one. For matching that is the
point. If you need the folding without the deletions, use `"nfkc"` and
lowercase separately.

[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
and
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
are the narrow alternative: they move text along the width axis and
touch nothing else.

## NFC is not a no-op on CJK

Canonical normalisation is usually described as safe, and on Latin text
it is. On Han it is not. Compatibility ideographs have *singleton*
canonical mappings, so **`"nfc"` rewrites them just as `"nfkc"` does**:
U+FA0C becomes U+5140 and U+F900 becomes U+8C48. Of the 472 characters
in the CJK Compatibility Ideographs block, 460 are folded away by plain
NFC; the 12 that survive – U+FA0E, U+FA0F, U+FA11, U+FA13, U+FA14,
U+FA1F, U+FA21, U+FA23, U+FA24, U+FA27, U+FA28, U+FA29 – are unified
ideographs that were encoded in that block by accident and have no
mapping to apply. All 542 characters of the Supplement block are folded.
So the block is not preserved and not uniformly folded either: if the
distinction between a compatibility ideograph and its unified form
carries meaning in your data, as it can in Korean and Japanese name
records, normalising at all will destroy most of it. Keep the original
column.

## Variation selectors

`drop_variation_selectors = TRUE` removes them before the form is
applied. They are removed first rather than afterwards because a
selector blocks canonical composition across itself, so stripping one
after normalising can leave text that is no longer in the form just
requested.

The set removed is Unicode's `Variation_Selector` property, not a list
written out here: the sixteen at U+FE00..U+FE0F, the 240 ideographic
ones at U+E0100..U+E01EF, and the Mongolian free variation selectors –
of which there are four on a current ICU and three on one built against
Unicode 10.0, because U+180F arrived in Unicode 14.0. Taking the set
from the property rather than from a literal means the verb follows
whichever ICU is installed. Dropping them merges the glyph variants of a
character into one token, which is what a frequency count wants and what
a typesetter does not.

`"nfc"`, `"nfd"`, `"nfkc"` and `"nfkd"` all leave every one of them in
place, so this argument is the only way to be rid of them under those
forms. `"nfkc_casefold"` removes them regardless, as part of the wider
deletion described above, and the argument is then redundant rather than
wrong.

## See also

[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
and
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
for the width axis alone,
[`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)
for comparison that ignores these differences without rewriting the
text.

## Examples

``` r
# the same syllable composed and decomposed, which nchar() can tell apart
both <- c("\u304c", "\u304b\u3099")
nchar(both)
#> [1] 1 2
nchar(cjk_normalize(both))
#> [1] 1 1

# NFKC folds the width axis and more besides; NFC leaves both alone
cjk_normalize("\uff21\uff22\u3000\u2460", form = "nfkc")
#> [1] "AB 1"
cjk_normalize("\uff21\uff22\u3000\u2460", form = "nfc")
#> [1] "ＡＢ　①"

# a compatibility ideograph is rewritten by plain NFC
sprintf("%X", utf8ToInt(cjk_normalize("\ufa0c")))
#> [1] "5140"

# an ideographic variation sequence survives every form until dropped
ivs <- "\u8fbb\U000E0100"
nchar(cjk_normalize(ivs))
#> [1] 2
nchar(cjk_normalize(ivs, drop_variation_selectors = TRUE))
#> [1] 1
```
