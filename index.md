# tidycjk

Text tooling in R assumes that words are separated by whitespace, and
Chinese, Japanese and Korean writing does not oblige.

[tidytext](https://CRAN.R-project.org/package=tidytext) splits on
whitespace. Chinese and Japanese don’t use whitespace. Give `tidytext`
an English sentence and you get words; give it 我今天很開心 and you get
either one undifferentiated blob or six isolated characters. Neither is
right — 開心 (“happy”) is one word of two characters, and splitting it
destroys the signal you were trying to measure.

**tidycjk** tells you what script and language a text column is in, how
much of it is CJK, which characters it contains, how wide it will print,
and normalises the width variants away — as tidy verbs that return
tibbles.

## Installation

``` r

# install.packages("pak")
pak::pak("PursuitOfDataScience/tidycjk")
```

## The tidy layer

Three verbs take `(data, column)` and return a tibble, so they drop into
a [dplyr](https://CRAN.R-project.org/package=dplyr) pipeline. Two of
them summarise a text column;
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
is under Segmentation below.

``` r

library(tidycjk)

posts <- data.frame(
  id = 1:5,
  text = c(
    "我今天很開心",           # Chinese
    "こんにちは、元気ですか",   # Japanese, with kana
    "안녕하세요",              # Korean
    "東京都",                 # Japanese written without kana
    "no CJK here at all"
  )
)

cjk_summary(posts, text)
#> # A tibble: 1 × 4
#>   n_docs n_with_cjk prop_with_cjk mean_ratio
#>    <int>      <int>         <dbl>      <dbl>
#> 1      5          4           0.8        0.8
```

`prop_with_cjk` answers “how many of these rows are CJK at all”;
`mean_ratio` answers “how CJK are they”. A corpus of English with one
stray ideograph per row scores high on the first and near zero on the
second.

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

## Segmentation

[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
is the CJK-aware counterpart of
[tidytext](https://CRAN.R-project.org/package=tidytext)’s
`unnest_tokens()`. Where a word ends is a fact about a language rather
than about Unicode, so no segmenter is bundled and `engine` is required
— quietly handing back character tokens to someone who asked for words
is the mistake this package exists to avoid.

``` r

cjk_tokens(posts[1:2, ], text, engine = "character")
#> # A tibble: 17 × 3
#>       id text                   token
#>    <int> <chr>                  <chr>
#>  1     1 我今天很開心           我   
#>  2     1 我今天很開心           今   
#>  3     1 我今天很開心           天   
#>  4     1 我今天很開心           很   
#>  5     1 我今天很開心           開   
#>  6     1 我今天很開心           心   
#>  7     2 こんにちは、元気ですか こ   
#>  8     2 こんにちは、元気ですか ん   
#>  9     2 こんにちは、元気ですか に   
#> 10     2 こんにちは、元気ですか ち   
#> 11     2 こんにちは、元気ですか は   
#> 12     2 こんにちは、元気ですか 、   
#> 13     2 こんにちは、元気ですか 元   
#> 14     2 こんにちは、元気ですか 気   
#> 15     2 こんにちは、元気ですか で   
#> 16     2 こんにちは、元気ですか す   
#> 17     2 こんにちは、元気ですか か
```

``` r

cjk_segment("hello 中文 world", engine = "character")
#> [[1]]
#> [1] "hello" "中"    "文"    "world"
```

`"character"` is the one engine that needs no dictionary: one token per
CJK character, non-CJK runs split on whitespace. It is character
tokenisation, not word segmentation.

For real Chinese word segmentation, register
[jiebaR](https://CRAN.R-project.org/package=jiebaR). It was archived
from CRAN on 2025-05-01, so install it with
`remotes::install_github("qinwf/jiebaR")`, then:

``` r

register_cjk_segmenter("jiebar", function(x, ...) {
  worker <- jiebaR::worker(...)
  lapply(x, function(s) {
    if (is.na(s)) return(NA_character_)
    if (!nzchar(s)) return(character(0))
    as.character(jiebaR::segment(s, worker))
  })
})

cjk_segment("我今天很開心", engine = "jiebar")
```

The same shape works for any segmenter you can call from R.

## Which language is this?

``` r

cjk_script(posts$text)
#> [1] "han"      "hiragana" "hangul"   "han"      NA
cjk_detect_language(posts$text)
#> [1] NA         "japanese" "korean"   NA         NA
```

Row 4 is `NA`, and that is the interesting one. 東京都 is Tokyo
Metropolis — Japanese — but it is written entirely in Han characters,
and nothing in the script distinguishes it from Chinese. Any library
that answers `"chinese"` there is guessing, and it will be wrong on
Japanese input in a way you cannot detect downstream. `tidycjk` returns
`NA`.

If your corpus is known to be Chinese, ask for the guess explicitly, so
that the assumption is visible in the script rather than buried in a
default:

``` r

cjk_detect_language(posts$text, han_only = "chinese")
#> [1] "chinese"  "japanese" "korean"   "chinese"  NA
```

## Display width

[`nchar()`](https://rdrr.io/r/base/nchar.html) counts characters. A
terminal counts columns, and a CJK character takes two of them — which
is why every console table containing CJK text comes out ragged.

``` r

labels <- c("中文", "abcd", "日本語")

nchar(labels)      # all look comparable
#> [1] 2 4 3
cjk_width(labels)  # they are not
#> [1] 4 4 6
```

Pad and truncate by width and the columns line up:

``` r

cat(paste0("|", cjk_pad(labels, 8), "|"), sep = "\n")
#> |中文    |
#> |abcd    |
#> |日本語  |

cjk_truncate("我今天很開心", 8)
#> [1] "我今..."
```

## Fullwidth and halfwidth

The usual advice is to run `NFKC`. `NFKC` does fix width, and it also
rewrites ligatures, Roman numerals, circled numbers and compatibility
ideographs.
[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
changes width and nothing else.

``` r

to_halfwidth("１２３")          # fullwidth digits that would not parse
#> [1] "123"
as.numeric(to_halfwidth("１２３"))
#> [1] 123

to_halfwidth("½ Ⅸ ①")          # NFKC would mangle all three; this leaves them
#> [1] "½ Ⅸ ①"
```

Halfwidth katakana writes a voiced syllable as two code points.
Composing them into one is the difference between text that matches a
literal and text that silently doesn’t:

``` r

x <- "ｶﾞ"          # U+FF76 U+FF9E — two code points
nchar(x)
#> [1] 2
nchar(to_halfwidth(x))          # one: U+30AC
#> [1] 1
to_halfwidth(x) == "ガ"
#> [1] TRUE
```

## The vector layer

Everything above has a
[stringr](https://CRAN.R-project.org/package=stringr)-style counterpart
on plain character vectors:
[`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md),
[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md),
[`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md),
[`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md),
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md),
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md),
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md),
[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
and
[`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md).
All are vectorised, propagate `NA`, and return zero-length output for
zero-length input.

[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
exports the block table the whole package is built on, so the definition
of “CJK” can be read rather than guessed at.

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
```

## Related work

| Need | Use |
|----|----|
| Display width, width-aware padding | [stringi](https://CRAN.R-project.org/package=stringi) — `stri_width()` and `stri_pad()`, which [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md) and [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md) wrap |
| Chinese segmentation | [jiebaR](https://CRAN.R-project.org/package=jiebaR) — archived from CRAN 2025-05-01; register it as a `tidycjk` engine |
| Pinyin | [pinyin](https://CRAN.R-project.org/package=pinyin), [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin) |
| Traditional/simplified conversion | [tmcn](https://CRAN.R-project.org/package=tmcn); [OpenCC](https://github.com/BYVoid/OpenCC) outside R for phrase-level accuracy |
| Japanese utilities | [zipangu](https://CRAN.R-project.org/package=zipangu), [Nippon](https://CRAN.R-project.org/package=Nippon) |

## License

GPL (\>= 3).
