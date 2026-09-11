# Romanisation, script conversion and kana

``` r

library(tidycjk)
```

## Four conversions, four different levels of trust

This vignette covers the transforms that change *what characters are
there* rather than how wide they are. They are grouped together because
they share an implementation — ICU’s transliterators, via **stringi**
(Unicode Consortium 2024; Gagolewski 2022) — and they should not be
trusted equally.

| Conversion | Reversible? | Context-free? | Trust |
|----|----|----|----|
| [`to_hiragana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md) / [`to_katakana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md) | within one syllabary | yes | complete |
| [`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md) / [`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md) | returns NFC | yes | complete |
| [`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md) | no | context-aware | good |
| [`cjk_traditionalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md) | no | context-aware | good on characters, blind to regional vocabulary |
| [`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md) | no | no | Chinese yes, Japanese no |

The rest of this vignette is why.

## Kana: safe, with one thing to know

Hiragana and katakana encode the same sounds. The mapping is one to one
and carries no context, so the answer never depends on the surrounding
words.

``` r

to_hiragana("カタカナ")
#> [1] "かたかな"
to_katakana("ひらがな")
#> [1] "ヒラガナ"

to_hiragana(to_katakana("ひらがな"))
#> [1] "ひらがな"
```

That round trip is exact because the input was already in one syllabary.
On mixed text it is not, and cannot be: converting to a single syllabary
erases the distinction between the two, and that distinction carries
meaning — katakana marks loanwords, onomatopoeia and emphasis.

``` r

x <- "アか"                      # one katakana, one hiragana
to_hiragana(x)                    # both become hiragana
#> [1] "あか"
to_katakana(to_hiragana(x))       # ... and cannot be told apart again
#> [1] "アカ"
```

So the conversion is safe in the sense that matters — it never guesses —
but run it in one direction, as a normalisation, rather than expecting
to undo it.

Kanji, Latin and punctuation are untouched, so it is safe on a mixed
column:

``` r

to_katakana("日本語のtext です")
#> [1] "日本語ノtext デス"
```

This is the normalisation you want before grouping Japanese text, where
the same word is often written either way for emphasis.

Halfwidth katakana is handled too, and composed on the way through. `ｶﾞ`
is two code points — the kana and a combining voiced mark — and comes
back as the single character `ガ`:

``` r

to_hiragana("ｶﾀｶﾅ")
#> [1] "かたかな"
to_katakana("ｶﾞ")
#> [1] "ガ"
nchar(to_katakana("ｶﾞ"))
#> [1] 1
```

## Hangul jamo: safe

A modern Hangul syllable is built from a leading consonant, a vowel and
an optional trailing consonant, and Unicode encodes all 11,172
combinations precomposed. The relationship is arithmetic —
`SIndex = (LIndex * 21 + VIndex) * 28 + TIndex` — so the decomposition
is exact rather than tabulated: no table can be out of date and no
syllable is missed.

``` r

cjk_jamo("한글")
#> [[1]]
#> [1] "ᄒ" "ᅡ"   "ᆫ"   "ᄀ" "ᅳ"   "ᆯ"
```

``` r

back <- vapply(cjk_jamo("한글"), paste, character(1), collapse = "")
cjk_compose_jamo(back)
#> [1] "한글"
```

One caveat on the round trip:
[`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
is normalisation form C, so it composes everything composable, not only
the jamo it was given. Text that was already in NFC — almost anything
you will meet — comes back unchanged. Text that was not comes back
normalised:

``` r

x <- "e\u0301"                        # e followed by a combining acute
cjk_compose_jamo(paste(cjk_jamo(x)[[1]], collapse = ""))
#> [1] "é"
```

That is `é` as a single code point. The guarantee is that the round trip
returns `stringi::stri_trans_nfc(x)`, which is `x` whenever `x` is
already NFC.

Jamo are the right unit for questions the syllable hides — which initial
consonants a corpus favours, or whether two spellings differ only in a
final consonant. The same syllable counts three different ways, each
right for a different question — `한` is one character to
[`nchar()`](https://rdrr.io/r/base/nchar.html), two terminal columns to
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md),
and three jamo here:

``` r

nchar("한")
#> [1] 1
cjk_width("한")
#> [1] 2
lengths(cjk_jamo("한"))
#> [1] 3
```

## Simplified and traditional Han: right on characters, blind to vocabulary

``` r

cjk_simplify("漢字")
#> [1] "汉字"
cjk_traditionalize("汉字")
#> [1] "漢字"
```

It is better than it looks. Simplified → traditional is genuinely
one-to-many — simplified `发` is `發` (“to send”) or `髮` (“hair”), and
`干` is `乾`, `幹` or `干` — and ICU resolves these **from context**,
not character by character:

``` r

cjk_traditionalize(c("头发", "发送"))   # hair, send
#> [1] "頭髮" "發送"
cjk_traditionalize(c("干净", "树干"))   # clean, tree trunk
#> [1] "乾淨" "樹幹"
cjk_traditionalize(c("后天", "皇后"))   # after, empress — 后 splits both ways
#> [1] "後天" "皇后"
```

All six are right. Over fourteen such pairs, including `面条`/`面对` and
`里面`/`公里`, every one came out correct.

What ICU does *not* do is substitute regional vocabulary. The two
standards differ in the words they use, not only in glyph shape, and
that is lexical:

``` r

cjk_traditionalize(c("软件", "鼠标", "网络"))
#> [1] "軟件" "鼠標" "網絡"
```

Those are the correct characters and the wrong words in Taiwan, where
the terms are `軟體`, `滑鼠` and `網路`. No character mapping can reach
that, and it is what [OpenCC](https://github.com/BYVoid/OpenCC) (Kuo
2024) and its regional configurations exist for. Use these functions for
script conversion; reach for OpenCC when you need Taiwanese or Hong Kong
idiom.

## Romanisation: depends entirely on the language

``` r

cjk_romanize("中文")
#> [1] "zhōng wén"
cjk_romanize("中文", ascii = TRUE)
#> [1] "zhong wen"
```

For Chinese this is pinyin, with tone marks unless you ask for ASCII,
and it is good. `ascii = TRUE` gives a sortable, greppable key for a CJK
column, which is often the real reason to romanise at all.

``` r

cjk_romanize(c("こんにちは", "안녕하세요"))
#> [1] "kon'nichiha"    "annyeonghaseyo"
```

Three caveats, in increasing order of severity.

**Han readings are per character.** A character with several readings
gets ICU’s preferred one regardless of the word it appears in.

**No boundary between scripts.** ICU spaces Han syllables but does not
insert a break where the script changes:

``` r

cjk_romanize("漢字カナ")
#> [1] "hàn zìkana"
```

Segment first with
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
if you need word boundaries in the output.

**Japanese kanji come back as Chinese.** This is the severe one. ICU
routes every Han character through pinyin regardless of the surrounding
language, so `日本語` romanises to `rì běn yǔ` rather than `nihongo`,
and `私` to `sī` rather than `watashi`:

``` r

cjk_romanize("私は日本語を話します")
#> [1] "sīha rì běn yǔwo huàshimasu"
```

That is not an approximation of the Japanese reading — it is the Chinese
one. The kana in the same string romanise correctly, which makes the
output look plausible at a glance and is exactly what makes it
dangerous. Note too that the particle `は` gives `ha`, which is how it
is written rather than how it is said.

For Japanese, use a morphological analyser that carries readings —
**gibasa** binds MeCab and returns them (Kudo et al. 2004; Kato 2025).
[`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md)
is for Chinese, for kana, and for producing an ASCII sort key.

## Width forms are a separate concern

[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
and
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
change width and nothing else. The usual advice for fullwidth text is an
`NFKC` pass, which does fix width — and also rewrites ligatures, Roman
numerals and circled numbers, none of which a change of width asked for.
When that wider fold *is* what you want, it is
[`cjk_normalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_normalize.md)
in the next section rather than a side effect here:

``` r

as.numeric(to_halfwidth("１２３"))
#> [1] 123

to_halfwidth("½ Ⅸ ①")   # NFKC rewrites all three; this leaves them
#> [1] "½ Ⅸ ①"
```

The one composition it does perform is voiced halfwidth katakana, where
a single syllable is written as two code points. Composing them is the
difference between text that matches a literal and text that silently
does not:

``` r

x <- "ｶﾞ"
nchar(x)
#> [1] 2
nchar(to_halfwidth(x))
#> [1] 1
to_halfwidth(x) == "ガ"
#> [1] TRUE
```

## Normalisation is the fourth axis

Width, script, syllabary — and then the code points themselves.
[`cjk_normalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_normalize.md)
applies the Unicode normalisation forms (Whistler 2024), which is what
decides whether two strings that render identically compare equal:

``` r

both <- c("\u304c", "\u304b\u3099")   # composed, then KA + voiced mark
nchar(both)
#> [1] 1 2
nchar(cjk_normalize(both))
#> [1] 1 1
```

`"nfkc"` is the blunt instrument the width verbs exist to avoid, and it
is the right tool when matching rather than display is the goal:

``` r

cjk_normalize("ＡＢ　①", form = "nfkc")
#> [1] "AB 1"
cjk_normalize("ＡＢ　①", form = "nfc")
#> [1] "ＡＢ　①"
```

**Canonical normalisation is not a no-op on Han.** Compatibility
ideographs have singleton canonical mappings, so `"nfc"` rewrites them
just as `"nfkc"` does — this is the part that surprises people who reach
for NFC because it is supposed to be the safe one:

``` r

block <- vapply(c(0xF900:0xFA6D, 0xFA70:0xFAD9), intToUtf8, character(1))
sum(cjk_normalize(block, "nfc") != block)   # folded away by plain NFC
#> [1] 460
sum(cjk_normalize(block, "nfc") == block)   # and the survivors
#> [1] 12
```

The twelve survivors are unified ideographs that were encoded in the
compatibility block by accident and have no mapping to apply. So the
block is neither preserved nor uniformly folded: if the distinction
between a compatibility ideograph and its unified form means something
in your data, as it can in Korean and Japanese name records, keep the
original column.

Variation selectors are the other thing that defeats an exact match, and
four of the five forms leave them alone:

``` r

ivs <- "辻\U000E0100"
nchar(cjk_normalize(ivs))
#> [1] 2
nchar(cjk_normalize(ivs, drop_variation_selectors = TRUE))
#> [1] 1
```

They are dropped *before* the form is applied, not after — a selector
has combining class zero and blocks canonical composition across itself,
so stripping one afterwards can leave text that is no longer in the form
you just asked for.

## References

Gagolewski, Marek. 2022. “stringi: Fast and Portable Character String
Processing in R.” *Journal of Statistical Software* 103 (2): 1–59.
<https://doi.org/10.18637/jss.v103.i02>.

Kato, Akiru. 2025. *gibasa: An Alternative ’Rcpp’ Wrapper of ’MeCab’*.
<https://CRAN.R-project.org/package=gibasa>.

Kudo, Taku, Kaoru Yamamoto, and Yuji Matsumoto. 2004. “Applying
Conditional Random Fields to Japanese Morphological Analysis.”
*Proceedings of the 2004 Conference on Empirical Methods in Natural
Language Processing (EMNLP)*, 230–37.

Kuo, Carbo. 2024. *OpenCC: Open Chinese Convert*.
<https://github.com/BYVoid/OpenCC>.

Unicode Consortium. 2024. *International Components for Unicode*.
<https://icu.unicode.org/>.

Whistler, Ken. 2024. *Unicode Standard Annex \#15: Unicode Normalization
Forms*. Unicode Standard Annex No. 15. The Unicode Consortium.
<https://www.unicode.org/reports/tr15/>.
