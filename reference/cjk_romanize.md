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
it as though it were. Four consequences worth knowing before you trust
the output:

- **Han is always read as Chinese.** ICU routes every Han character
  through pinyin, whatever language surrounds it, so Japanese kanji come
  back with Chinese readings: U+65E5 U+672C U+8A9E ("Japanese language")
  romanises to `ri ben yu`, not `nihongo`. This is not a near miss to be
  cleaned up afterwards – it is the wrong language. Do not use
  `cjk_romanize()` on Japanese kanji.

- **A character with two readings gets one.** ICU reads each Han
  character on its own, so a polyphonic character gets its most common
  reading whatever word it is in: U+94F6 U+884C ("bank") romanises to
  `yin xing` rather than `yin hang`, and U+97F3 U+4E50 ("music") to
  `yin le` rather than `yin yue` (tone marks omitted here). Treat the
  output as a sort or search key, not as pinyin to show a reader.

- **No word spacing.** ICU inserts a space between Han syllables but not
  between scripts, so Han followed immediately by kana romanises to a
  run with no boundary where the script changes. Segment first with
  [`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
  if you need words.

- **Kana particles are spelled, not pronounced.** The Japanese topic
  particle U+306F romanises to `ha`, which is how it is written and not
  how it is said.

## It is slow, by a wide margin

ICU's transliterator is the most expensive thing this package calls. On
a column of 5,000 twenty-character Chinese documents, romanising ran at
a median of about 45,000 characters a second (95% CI 43,500 to 45,600)
and took about 27 times as long as `cjk_segment(engine = "icu")` on the
same column (95% CI 24 to 29; the closest of the pairs was 17 times).
The cost is ICU's: a bare `stringi::stri_trans_general(x, "Any-Latin")`
takes the same time (ratio 1.01, 95% CI 0.99 to 1.02), and there is no
faster route to the same answer.

It also gets slower per character as one string gets longer, so the same
100,000 characters took 1.4 times as long pasted into a single string as
kept as a column (95% CI 1.35 to 1.43). Keep a corpus as one row per
document, and romanise once into a column you keep rather than inside a
loop.

Those figures are medians of 30 paired, interleaved runs on one machine
(an AMD EPYC 7702, ICU 74.1) and will move with the CPU, the load and
the ICU build; the ratios are the durable part. Nothing in the test
suite asserts them, because a timing assertion on a CRAN build machine
fails for reasons that have nothing to do with this package.

For Japanese specifically, a morphological analyser that knows the
reading is the right tool:
[gibasa](https://CRAN.R-project.org/package=gibasa), which binds MeCab.
This function is for Chinese, for kana, and for getting a sortable ASCII
key out of a CJK column.

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
