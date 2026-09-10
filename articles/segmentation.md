# Segmenting CJK text

``` r

library(tidycjk)
```

## The problem

English tokenisation is mostly a solved problem because English writes
its word boundaries down. You split on whitespace and you are close
enough. In Chinese and Japanese there is no such signal:

> 我今天很開心

Six characters, no spaces, four words: `我` (I), `今天` (today), `很`
(very), `開心` (happy). Nothing in the *encoding* tells you that `今`
and `天` belong together while `很` stands alone. That is a fact about
Chinese, learned from a corpus, and Unicode makes no claim about it.
Unicode Annex \#29 defines word boundaries for scripts that mark them
and explicitly defers to dictionaries for those that do not (Unicode
Consortium 2024b).

This is why `tidycjk` does not have a single `tokenize()`. It has an
engine slot.

## Choosing an engine

``` r

cjk_segmenters()
#> [1] "character" "icu"
```

### `"icu"` — dictionary-based, and already installed

ICU ships dictionary-based break iterators for Chinese and Japanese, and
**stringi** ships ICU (Unicode Consortium 2024a; Gagolewski 2022). Since
**stringi** is already a hard dependency of this package, real word
segmentation costs nothing extra:

``` r

cjk_segment("我今天很開心", engine = "icu")
#> [[1]]
#> [1] "我"   "今天" "很"   "開心"

cjk_segment("今天天氣很好我們去公園散步", engine = "icu")
#> [[1]]
#> [1] "今天" "天氣" "很好" "我們" "去"   "公園" "散步"
```

Japanese works out of the box, and `locale` is accepted though it does
not change the result — see below:

``` r

cjk_segment("今日は良い天気ですね", engine = "icu", locale = "ja")
#> [[1]]
#> [1] "今日" "は"   "良い" "天気" "です" "ね"
```

Anything in `...` reaches the engine, which is how `locale` gets there.

What `"icu"` gives you is surface forms and nothing else: no part of
speech, no lemma, no user dictionary, and models lighter than the ones a
dedicated analyser carries. It is the right first choice and not the
last word.

### `"character"` — the honest baseline

``` r

cjk_segment("我今天很開心", engine = "character")
#> [[1]]
#> [1] "我" "今" "天" "很" "開" "心"
```

One token per CJK character; runs of non-CJK text split on whitespace.
Whitespace is never a token — including the ideographic space U+3000,
even though
[`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md)
counts it as CJK, because it is a space and treating it as a word would
inflate every count.

This is *character* tokenisation, not word segmentation. For Chinese it
cuts two-character words in half. It is genuinely useful when a
per-character unit is what you want — character frequency, or a
character-level model — and misleading if you call its output “words”.

``` r

cjk_segment("hello 中文 world", engine = "character")
#> [[1]]
#> [1] "hello" "中"    "文"    "world"
```

### Why there is no default

`engine` is required. There is a real temptation to default it to
`"character"`, and the reason not to is that it answers a *different
question* from the one a caller asking for words is asking, while
looking like an answer to theirs. Silence there is the failure mode this
package exists to prevent.

Even now that `"icu"` exists the choice stays explicit, for the original
reason rather than a new one: `"character"` still answers a different
question, and it is still the answer a caller would get by accident.

### `locale` does not pick the dictionary

It is natural to assume it does, and it does not. ICU applies one
combined Chinese–Japanese word list to Han and kana runs, selected by
the *script of the text* rather than by the locale (Unicode Consortium
2024a). Segmenting seven CJK strings under `"zh"`, `"ja"`, `"ko"`,
`"en"` and the session default gives identical output in every case.

`locale` is still accepted and forwarded — ICU may use it elsewhere, and
a locale ICU has no break data for is an error rather than a silent
fallback — but do not expect `locale = "ja"` to change how Japanese
segments.

## In a pipeline

[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md)
takes `(data, column)` and returns one row per token, in the manner of
**tidytext**’s `unnest_tokens()` (Silge and Robinson 2016):

``` r

posts <- data.frame(
  id = 1:3,
  text = c("我今天很開心", "今天天氣很好", "hello 中文 world")
)

cjk_tokens(posts, text, engine = "icu")
#> # A tibble: 10 × 3
#>       id text             token
#>    <int> <chr>            <chr>
#>  1     1 我今天很開心     我   
#>  2     1 我今天很開心     今天 
#>  3     1 我今天很開心     很   
#>  4     1 我今天很開心     開心 
#>  5     2 今天天氣很好     今天 
#>  6     2 今天天氣很好     天氣 
#>  7     2 今天天氣很好     很好 
#>  8     3 hello 中文 world hello
#>  9     3 hello 中文 world 中文 
#> 10     3 hello 中文 world world
```

Grouping is dropped, and other columns are carried along, so the usual
counting follows directly:

``` r

tok <- cjk_tokens(posts, text, engine = "icu")
sort(table(tok$token), decreasing = TRUE)[1:5]
#> 
#>  今天 hello world  中文  天氣 
#>     2     1     1     1     1
```

## Registering another engine

An engine is any function of `(x, ...)` returning a list the same length
as `x`, each element a character vector of tokens. `NA` in gives
`NA_character_`; the empty string gives `character(0)`.
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
checks the shape and complains if an engine breaks the contract, rather
than passing a malformed result downstream.

### gibasa, for Japanese

[gibasa](https://CRAN.R-project.org/package=gibasa) binds MeCab (Kudo et
al. 2004; Kato 2025) and is on CRAN. It gives part of speech and lemma,
which ICU does not:

``` r

register_cjk_segmenter("mecab", function(x, ...) {
  lapply(x, function(s) {
    if (is.na(s)) return(NA_character_)
    if (!nzchar(s)) return(character(0))
    gibasa::tokenize(data.frame(doc_id = 1, text = s))$token
  })
})

cjk_segment("今日は良い天気ですね", engine = "mecab")
```

### jiebaR, for Chinese

jiebaR was archived from CRAN on 2025-05-01, so it cannot be a
dependency of a CRAN package; install it from source with
`remotes::install_github("qinwf/jiebaR")`. Then:

``` r

register_cjk_segmenter("jiebar", function(x, ...) {
  worker <- jiebaR::worker(...)
  lapply(x, function(s) {
    if (is.na(s)) return(NA_character_)
    if (!nzchar(s)) return(character(0))
    as.character(jiebaR::segment(s, worker))
  })
})
```

### A caution about argument matching

`...` sits after `engine` in
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md),
and after `data` and `col` in
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md),
so R’s partial matching claims a prefix of one of those before the dots
see it. `cjk_tokens(df, text, "mine", c = 1)` matches `c` to `col`,
pushes bare `text` into `engine`, resolves it to
[`graphics::text()`](https://rdrr.io/r/graphics/text.html) — a function,
so it is accepted — and the error you get is about plotting. Name engine
arguments so they are not a prefix of `col`, `data` or `engine`, or
capture the setting in a closure:

``` r

register_cjk_segmenter("mine", function(x, ...) my_segmenter(x, cutoff = 1))
```

## Comparing engines

Because engines share a contract, comparing them is a
[`lapply()`](https://rdrr.io/r/base/lapply.html):

``` r

x <- "今天天氣很好"
vapply(c("icu", "character"),
       function(e) paste(cjk_segment(x, engine = e)[[1]], collapse = " | "),
       character(1))
#>                           icu                     character 
#>          "今天 | 天氣 | 很好" "今 | 天 | 天 | 氣 | 很 | 好"
```

That is the intended way to decide: run the candidates over a sample of
*your* corpus and read the disagreements, rather than trusting a
benchmark computed on someone else’s text.

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

Silge, Julia, and David Robinson. 2016. “Tidytext: Text Mining and
Analysis Using Tidy Data Principles in R.” *Journal of Open Source
Software* 1 (3): 37. <https://doi.org/10.21105/joss.00037>.

Unicode Consortium. 2024a. *International Components for Unicode*.
<https://icu.unicode.org/>.

Unicode Consortium. 2024b. *Unicode Standard Annex \#29: Unicode Text
Segmentation*. Unicode Consortium.
<https://www.unicode.org/reports/tr29/>.
