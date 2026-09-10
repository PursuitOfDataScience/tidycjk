# Introduction to tidycjk

## Overview

Almost every text tool in R assumes that a word is a run of characters
between two spaces. That assumption is invisible until it fails, and it
fails completely on Chinese, Japanese and Korean, because Chinese and
Japanese do not put spaces between words at all. Hand `我今天很開心` to
a whitespace tokeniser and it returns one token: the whole sentence.
Split it per character instead and you get six, which cuts `開心`
(“happy”) in half and destroys the very signal you were trying to
measure.

The problem is not only segmentation. A CJK character occupies **two**
terminal columns but counts as **one** character, so
[`nchar()`](https://rdrr.io/r/base/nchar.html) and the width of a
printed table disagree, and every console table containing CJK text
comes out ragged. Fullwidth digits `１２３` look like digits and do not
parse as a number. A Japanese place name written only in Han characters
cannot be told from Chinese by script alone — and most libraries guess
anyway.

**tidycjk** addresses these as separate, honest problems, each derived
from the Unicode specification (Unicode Consortium 2024b, 2024c, 2024d)
rather than from heuristics:

| Task | Function(s) |
|----|----|
| Detect | [`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md), [`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md), [`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md), [`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md) |
| Summarise a column | [`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md), [`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md) |
| Segment | [`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md), [`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md), [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md), [`register_cjk_segmenter()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md) |
| Sentences, n-grams | [`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md), [`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md) |
| Order | [`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md), [`cjk_order()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md) |
| Measure width | [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md) |
| Lay out | [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md), [`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md), [`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md) |
| Normalise width | [`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md), [`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md) |
| Romanise | [`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md) |
| Convert Han | [`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md), [`cjk_traditionalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md) |
| Convert kana | [`to_hiragana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md), [`to_katakana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md) |
| Hangul jamo | [`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md), [`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md) |
| Reference data | [`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md) |

``` r

library(tidycjk)
```

## Two layers, one contract

Every verb works on a plain character vector, in the manner of
**stringr**. Three of them —
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md),
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
and
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
— also take `(data, column)` and return a tibble, so they drop into a
**dplyr** pipeline without an adaptor (Wickham 2014).

The contract is the same throughout, and it is worth stating once
because the rest of this vignette relies on it. Every vector-layer verb
is vectorised: `NA` in gives `NA` out, zero-length input gives
zero-length output, and nothing silently recycles a ragged pair — a
mismatch is an error rather than a warning and a short answer.

The tidy verbs answer about the column rather than about each row, so
they summarise rather than map.
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
and
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
return no rows for an empty column;
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md)
always returns exactly one, with `NA` where there was nothing to
average.

``` r

posts <- data.frame(
  id = 1:5,
  text = c(
    "我今天很開心",            # Chinese
    "こんにちは、元気ですか",  # Japanese, with kana
    "안녕하세요",              # Korean
    "東京都",                  # Japanese written without kana
    "no CJK here at all"
  )
)

cjk_summary(posts, text)
#> # A tibble: 1 × 4
#>   n_docs n_with_cjk prop_with_cjk mean_ratio
#>    <int>      <int>         <dbl>      <dbl>
#> 1      5          4           0.8        0.8
```

`prop_with_cjk` answers “how many of these rows contain any CJK at all”;
`mean_ratio` answers “how CJK are they”. They come apart exactly where
you would want them to: a corpus of English with one stray ideograph per
row scores near 1 on the first and near 0 on the second.

``` r

cjk_char_counts(posts, text)
#> # A tibble: 25 × 5
#>    char  codepoint script   block                      n
#>    <chr>     <int> <chr>    <chr>                  <int>
#>  1 我        25105 han      CJK Unified Ideographs     1
#>  2 今        20170 han      CJK Unified Ideographs     1
#>  3 天        22825 han      CJK Unified Ideographs     1
#>  4 很        24456 han      CJK Unified Ideographs     1
#>  5 開        38283 han      CJK Unified Ideographs     1
#>  6 心        24515 han      CJK Unified Ideographs     1
#>  7 こ        12371 hiragana Hiragana                   1
#>  8 ん        12435 hiragana Hiragana                   1
#>  9 に        12395 hiragana Hiragana                   1
#> 10 ち        12385 hiragana Hiragana                   1
#> # ℹ 15 more rows
```

## Detection, and the value of refusing to guess

[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
reports the dominant script;
[`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md)
reports the language.

``` r

cjk_script(posts$text)
#> [1] "han"      "hiragana" "hangul"   "han"      NA
cjk_detect_language(posts$text)
#> [1] NA         "japanese" "korean"   NA         NA
```

Rows one, four and five come back `NA`. Row five is uninteresting — it
has no CJK in it at all. Rows one and four are the point. `東京都` is
Tokyo Metropolis — unambiguously Japanese — but it is written entirely
in Han characters, and **nothing in the script distinguishes it from
Chinese**. Japanese written without kana and Chinese are the same
character set. Any library that answers `"chinese"` there is guessing,
and it will be wrong on Japanese input in a way you cannot detect
downstream, because the output looks exactly like a confident correct
answer.

`tidycjk` returns `NA`. If your corpus is known to be Chinese, ask for
the guess explicitly, so that the assumption lives in your script where
a reader can see it rather than in a library default where they cannot:

``` r

cjk_detect_language(posts$text, han_only = "chinese")
#> [1] "chinese"  "japanese" "korean"   "chinese"  NA
```

## Segmentation

Where a word ends is a fact about a language, not about Unicode, so it
needs a dictionary. `tidycjk` dispatches on an engine name rather than
committing to one, and two engines ship with the package.

`"icu"` is a real word segmenter, using the dictionary-based break
iterators that ICU carries (Unicode Consortium 2024a) and **stringi**
exposes (Gagolewski 2022):

``` r

cjk_segment("我今天很開心", engine = "icu")
#> [[1]]
#> [1] "我"   "今天" "很"   "開心"
```

`我 / 今天 / 很 / 開心` — words, not characters. `"character"` is the
dictionary-free baseline, and the contrast shows what a segmenter is
for:

``` r

cjk_segment("我今天很開心", engine = "character")
#> [[1]]
#> [1] "我" "今" "天" "很" "開" "心"
```

In a pipeline,
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
is the CJK-aware counterpart of **tidytext**’s `unnest_tokens()` (Silge
and Robinson 2016):

``` r

cjk_tokens(posts[1:2, ], text, engine = "icu")
#> # A tibble: 8 × 3
#>      id text                   token     
#>   <int> <chr>                  <chr>     
#> 1     1 我今天很開心           我        
#> 2     1 我今天很開心           今天      
#> 3     1 我今天很開心           很        
#> 4     1 我今天很開心           開心      
#> 5     2 こんにちは、元気ですか こんにちは
#> 6     2 こんにちは、元気ですか 元気      
#> 7     2 こんにちは、元気ですか です      
#> 8     2 こんにちは、元気ですか か
```

[`vignette("segmentation", package = "tidycjk")`](https://pursuitofdatascience.github.io/tidycjk/articles/segmentation.md)
covers the engines, their limits, and how to register **gibasa** (Kato
2025) or jiebaR.

## Sentences and n-grams

Two preprocessing steps that generic tooling gets wrong. A regular
expression on `[.!?]` finds no sentence boundary at all in Chinese,
because the terminator is `。`:

``` r

cjk_sentences("我今天很開心。你呢？天氣很好！")
#> [[1]]
#> [1] "我今天很開心。" "你呢？"         "天氣很好！"
```

Character n-grams are the dictionary-free baseline for Chinese retrieval
and classification. Most words are one or two characters, so bigrams
capture the majority of them with no model at all, and they hold up on
the names and coinages where a segmenter is least reliable:

``` r

cjk_ngrams("中文很好")
#> [[1]]
#> [1] "中文" "文很" "很好"
```

No gram is formed across whitespace, so nothing straddles two words of a
Latin run.

## Sorting

[`sort()`](https://rdrr.io/r/base/sort.html) on Chinese gives code point
order, and it is worth being precise about what that is. Within the base
block it is *not* arbitrary: the unified ideographs are arranged in
KangXi radical-stroke order, so code point order really is radical
order. It is simply not the order anyone sorting a name column wants,
because it is not phonetic — and it stops being radical order across
blocks, since every Extension A character sorts before every base-block
one, leaving a rare character nowhere near its radical-mates:

``` r

x <- c("張", "王", "李")   # Zhang, Wang, Li

sort(x)
#> [1] "張" "李" "王"
cjk_sort(x, locale = "zh")             # pinyin
#> [1] "李" "王" "張"
cjk_sort(x, locale = "zh-u-co-stroke") # stroke count
#> [1] "王" "李" "張"
```

## Width, and why your tables are ragged

[`nchar()`](https://rdrr.io/r/base/nchar.html) counts characters. A
terminal counts columns, and Unicode Annex \#11 assigns CJK characters
two of them (Unicode Consortium 2024b).

``` r

labels <- c("中文", "abcd", "日本語")

nchar(labels)
#> [1] 2 4 3
cjk_width(labels)
#> [1] 4 4 6
```

Pad to a width rather than to a character count and the column lines up:

``` r

cat(paste0("|", cjk_pad(labels, 8), "|"), sep = "\n")
#> |中文    |
#> |abcd    |
#> |日本語  |
```

Truncation and wrapping follow the same rule. Wrapping additionally
respects the Unicode line breaking algorithm (Unicode Consortium 2024c),
so it will not put a break before a closing bracket or a full stop:

``` r

cat(cjk_wrap("我今天很開心，因為天氣非常好而且朋友來看我", 12))
#> 我今天很開
#> 心，因為天氣
#> 非常好而且朋
#> 友來看我
```

[`vignette("width-and-layout", package = "tidycjk")`](https://pursuitofdatascience.github.io/tidycjk/articles/width-and-layout.md)
goes further.

## Normalisation and transliteration

[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
narrows fullwidth forms and does **only** that — unlike an `NFKC` pass,
which also rewrites ligatures, Roman numerals and circled numbers:

``` r

as.numeric(to_halfwidth("１２３"))
#> [1] 123
to_halfwidth("½ Ⅸ ①")   # NFKC would mangle all three
#> [1] "½ Ⅸ ①"
```

Romanisation, Han script conversion, kana conversion and Hangul jamo
decomposition are all available on the same contract:

``` r

cjk_romanize("中文")
#> [1] "zhōng wén"
cjk_simplify("漢字")
#> [1] "汉字"
to_hiragana("カタカナ")
#> [1] "かたかな"
cjk_jamo("한")
#> [[1]]
#> [1] "ᄒ" "ᅡ"   "ᆫ"
```

Each has limits worth knowing before you trust it — romanisation is
per-character, and simplified/traditional conversion is too. They are
documented honestly in
[`vignette("transliteration", package = "tidycjk")`](https://pursuitofdatascience.github.io/tidycjk/articles/transliteration.md).

## What tidycjk is built on

[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
exports the block table the whole package rests on, so the definition of
“CJK” can be read rather than guessed at:

``` r

head(cjk_blocks(), 8)
#> # A tibble: 8 × 5
#>   block                       script      start   end n_codepoints
#>   <chr>                       <chr>       <int> <int>        <int>
#> 1 Hangul Jamo                 hangul       4352  4607          256
#> 2 CJK Symbols and Punctuation punctuation 12288 12351           64
#> 3 Hiragana                    hiragana    12352 12447           96
#> 4 Katakana                    katakana    12448 12543           96
#> 5 Bopomofo                    bopomofo    12544 12591           48
#> 6 Hangul Compatibility Jamo   hangul      12592 12687           96
#> 7 Kanbun                      kanbun      12688 12703           16
#> 8 Bopomofo Extended           bopomofo    12704 12735           32
nrow(cjk_blocks())
#> [1] 27
```

Nothing here makes a network request, and the package needs no compiled
code of its own.

## References

Gagolewski, Marek. 2022. “stringi: Fast and Portable Character String
Processing in R.” *Journal of Statistical Software* 103 (2): 1–59.
<https://doi.org/10.18637/jss.v103.i02>.

Kato, Akiru. 2025. *gibasa: An Alternative ’Rcpp’ Wrapper of ’MeCab’*.
<https://CRAN.R-project.org/package=gibasa>.

Silge, Julia, and David Robinson. 2016. “Tidytext: Text Mining and
Analysis Using Tidy Data Principles in R.” *Journal of Open Source
Software* 1 (3): 37. <https://doi.org/10.21105/joss.00037>.

Unicode Consortium. 2024a. *International Components for Unicode*.
<https://icu.unicode.org/>.

Unicode Consortium. 2024b. *Unicode Standard Annex \#11: East Asian
Width*. Unicode Consortium. <https://www.unicode.org/reports/tr11/>.

Unicode Consortium. 2024c. *Unicode Standard Annex \#14: Unicode Line
Breaking Algorithm*. Unicode Consortium.
<https://www.unicode.org/reports/tr14/>.

Unicode Consortium. 2024d. *Unicode Standard Annex \#29: Unicode Text
Segmentation*. Unicode Consortium.
<https://www.unicode.org/reports/tr29/>.

Wickham, Hadley. 2014. “Tidy Data.” *Journal of Statistical Software* 59
(10): 1–23. <https://doi.org/10.18637/jss.v059.i10>.
