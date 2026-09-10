# Decompose and recompose Hangul syllables

`cjk_jamo()` splits each Hangul syllable into the jamo it is built from;
`cjk_compose_jamo()` puts them back together.

## Usage

``` r
cjk_jamo(x)

cjk_compose_jamo(x)
```

## Arguments

- x:

  A character vector.

## Value

`cjk_jamo()` returns a list the same length as `x`, each element a
character vector of jamo; `NA` gives `NA_character_` and the empty
string gives `character(0)`. `cjk_compose_jamo()` takes a character
vector and returns one.

## Details

A modern Hangul syllable is a composite. Unicode encodes 11,172 of them
precomposed in the Hangul Syllables block, each one algorithmically
derived from a leading consonant, a vowel and an optional trailing
consonant: `SIndex = (LIndex * 21 + VIndex) * 28 + TIndex`. Because the
relationship is arithmetic rather than tabulated, the decomposition is
exact for Hangul: no table can be out of date and no syllable is missed.

## The round trip returns NFC, which is not always the input

`cjk_compose_jamo()` is normalisation form C, so it composes everything
composable and not only the jamo it was handed. If `x` was already in
NFC – which text from almost any source is – the round trip returns it
unchanged. If it was not, the result is `x` normalised: an `e` followed
by a combining acute comes back as the single character `U+00E9`,
because that is what NFC is for.

So the guarantee is `cjk_compose_jamo(cjk_jamo(x))` equals
`stringi::stri_trans_nfc(x)`, which equals `x` exactly when `x` is
already NFC. Normalise first if you need to be certain.

That makes jamo the right unit for questions the syllable hides: which
initial consonants a corpus favours, whether two spellings differ only
in a final consonant, or how to sort by consonant. U+D55C is one
character to
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
and three jamo here.

Text that is not Hangul passes through unchanged, so it is safe to run
over a mixed column.

## See also

[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
to detect Hangul,
[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
for the blocks involved.

## Examples

``` r
# U+D55C U+AE00, "Hangul"
cjk_jamo("\ud55c\uae00")
#> [[1]]
#> [1] "ᄒ" "ᅡ"   "ᆫ"   "ᄀ" "ᅳ"   "ᆯ"  
#> 

# the round trip returns NFC, so already-NFC input comes back unchanged
rt <- function(x) {
  cjk_compose_jamo(vapply(cjk_jamo(x), paste, character(1), collapse = ""))
}
rt("\ud55c\uae00")
#> [1] "한글"

# input that was not NFC comes back normalised: "e" plus a combining
# acute becomes the single character U+00E9
rt("e\u0301")
#> [1] "é"
```
