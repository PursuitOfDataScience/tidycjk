# tidycjk

Tidy tools for Chinese, Japanese and Korean text. R’s text tooling
assumes words are separated by whitespace; CJK writing does not oblige.

![Padding by character count leaves a CJK column ragged; padding by
display width aligns it.](reference/figures/hero-width.svg)

## Installation

``` r

install.packages("tidycjk")
```

## What you get

|  |  |
|----|----|
| **Detect** | [`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md) · [`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md) · [`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md) · [`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md) |
| **Measure** | [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md) · [`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md) · [`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md) |
| **Lay out** | [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md) · [`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md) |
| **Normalise** | [`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md) · [`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md) |
| **Segment** | [`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md) · [`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md) · [`register_cjk_segmenter()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md) |

Every verb is vectorised and propagates `NA`. Three of them —
[`cjk_summary()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_summary.md),
[`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
and
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
— also take `(data, column)` and return a tibble straight into a
[dplyr](https://CRAN.R-project.org/package=dplyr) pipeline.

## Which script, which language?

![cjk_script and cjk_detect_language over five sample
strings.](reference/figures/fig-scripts.png)

``` r

library(tidycjk)

cjk_detect_language(c("こんにちは", "안녕하세요", "東京都"))
#> [1] "japanese" "korean"   NA
```

東京都 is Tokyo — Japanese — but it is written entirely in Han
characters, and nothing in the script separates it from Chinese.
Anything that answers `"chinese"` there is guessing. Ask for the guess
explicitly if you want it:

``` r

cjk_detect_language("東京都", han_only = "chinese")
#> [1] "chinese"
```

## How much of this is CJK?

![cjk_ratio over four sample strings, shown as filled
bars.](reference/figures/fig-ratio.png)

``` r

posts <- data.frame(
  id = 1:3,
  text = c("我今天很開心", "hello 中文 world", "no CJK here")
)

cjk_summary(posts, text)
#> # A tibble: 1 × 4
#>   n_docs n_with_cjk prop_with_cjk mean_ratio
#>    <int>      <int>         <dbl>      <dbl>
#> 1      3          2         0.667      0.381
```

`prop_with_cjk` answers “how many of these rows are CJK at all”;
`mean_ratio` answers “how CJK are they”.

## Width, not character count

![nchar padding leaves the right edge ragged; cjk_pad aligns
it.](reference/figures/fig-width.png)

``` r

labels <- c("中文", "abcd", "日本語")

nchar(labels)      # all look comparable
#> [1] 2 4 3
cjk_width(labels)  # they are not
#> [1] 4 4 6

cat(paste0("|", cjk_pad(labels, 8), "|"), sep = "\n")
#> |中文    |
#> |abcd    |
#> |日本語  |
```

## Fullwidth and halfwidth

![to_halfwidth narrows width forms and leaves everything else
alone.](reference/figures/fig-normalize.png)

The usual advice is `NFKC`, which fixes width and also rewrites
ligatures, Roman numerals and circled numbers.
[`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
changes width and nothing else.

``` r

as.numeric(to_halfwidth("１２３"))
#> [1] 123

nchar("ｶﾞ")                 # U+FF76 U+FF9E, two code points
#> [1] 2
to_halfwidth("ｶﾞ") == "ガ"   # composed into one
#> [1] TRUE
```

## Segmentation

Where a word ends is a fact about a language, not about Unicode, so no
dictionary is bundled and `engine` is required — quietly handing back
character tokens to someone who asked for words is the mistake this
package exists to avoid.

``` r

cjk_segment("hello 中文 world", engine = "character")
#> [[1]]
#> [1] "hello" "中"    "文"    "world"
```

`"character"` is the one engine needing no dictionary: one token per CJK
character, non-CJK runs split on whitespace. For real Chinese word
segmentation register
[jiebaR](https://CRAN.R-project.org/package=jiebaR) (archived from CRAN
2025-05-01, so `remotes::install_github("qinwf/jiebaR")`):

``` r

register_cjk_segmenter("jiebar", function(x, ...) {
  worker <- jiebaR::worker(...)
  lapply(x, function(s) as.character(jiebaR::segment(s, worker)))
})

cjk_segment("我今天很開心", engine = "jiebar")
```

[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
exports the block table the whole package is built on, so the definition
of “CJK” can be read rather than guessed at.

## Related work

| Need | Use |
|----|----|
| Display width, width-aware padding | [stringi](https://CRAN.R-project.org/package=stringi) — `stri_width()` and `stri_pad()`, which [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md) and [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md) wrap |
| Chinese segmentation | [jiebaR](https://CRAN.R-project.org/package=jiebaR) — register it as a `tidycjk` engine |
| Pinyin | [pinyin](https://CRAN.R-project.org/package=pinyin), [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin) |
| Traditional/simplified | [tmcn](https://CRAN.R-project.org/package=tmcn); [OpenCC](https://github.com/BYVoid/OpenCC) outside R |
| Japanese utilities | [zipangu](https://CRAN.R-project.org/package=zipangu), [Nippon](https://CRAN.R-project.org/package=Nippon) |

## License

GPL (\>= 3).
