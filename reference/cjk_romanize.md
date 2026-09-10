# Romanise CJK text

Transliterates Han, kana and Hangul into the Latin alphabet: pinyin for
Chinese, romaji for Japanese kana, Revised-Romanisation-style output for
Korean.

## Usage

``` r
cjk_romanize(x, ascii = FALSE)
```

## Arguments

- x:

  A character vector.

- ascii:

  If `TRUE`, strip diacritics so the result is plain ASCII: pinyin tone
  marks are removed, so that `wo` with a caron becomes plain `wo`.
  Defaults to `FALSE`, which keeps them.

## Value

A character vector the same length as `x`. `NA` gives `NA`.

## Details

The mapping is ICU's `Any-Latin`, which handles all three scripts in one
pass, so mixed text does not need splitting first. Text that is already
Latin is left alone.

## What this is not

Romanisation is not a function of the code point alone, and ICU treats
it as though it were. Three consequences worth knowing before you trust
the output:

- **Han is always read as Chinese.** ICU routes every Han character
  through pinyin, whatever language surrounds it, so Japanese kanji come
  back with Chinese readings: U+65E5 U+672C U+8A9E ("Japanese language")
  romanises to `ri ben yu`, not `nihongo`. This is not a near miss to be
  cleaned up afterwards – it is the wrong language. Do not use
  `cjk_romanize()` on Japanese kanji.

- **No word spacing.** ICU inserts a space between Han syllables but not
  between scripts, so Han followed immediately by kana romanises to a
  run with no boundary where the script changes. Segment first with
  [`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
  if you need words.

- **Kana particles are spelled, not pronounced.** The Japanese topic
  particle U+306F romanises to `ha`, which is how it is written and not
  how it is said.

For Japanese specifically, a morphological analyser that knows the
reading – [gibasa](https://CRAN.R-project.org/package=gibasa), which
binds MeCab – is the right tool. This function is for Chinese, for kana,
and for getting a sortable ASCII key out of a CJK column.

## See also

[`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md)
for Han script conversion,
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
for word boundaries.

## Examples

``` r
# U+4E2D U+6587, "Chinese writing"
cjk_romanize("\u4e2d\u6587")            # pinyin, with tone marks
#> [1] "zhōng wén"
cjk_romanize("\u4e2d\u6587", ascii = TRUE)
#> [1] "zhong wen"

# Han is read as Chinese even in Japanese text -- see Details
cjk_romanize("\u65e5\u672c\u8a9e")
#> [1] "rì běn yǔ"

# kana and Hangul go through the same call
cjk_romanize(c("\u3053\u3093\u306b\u3061\u306f", "\uc548\ub155"))
#> [1] "kon'nichiha" "annyeong"   
```
