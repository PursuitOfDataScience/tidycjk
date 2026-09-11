# Split text into sentences

Splits each string into sentences using ICU's sentence break iterator,
which knows the CJK terminators – the ideographic full stop U+3002, the
fullwidth exclamation mark U+FF01 and the fullwidth question mark U+FF1F
– as well as the ASCII ones.

## Usage

``` r
cjk_sentences(x, locale = NULL)
```

## Arguments

- x:

  A character vector.

- locale:

  ICU locale for the break iterator, e.g. `"ja"`. `NULL`, the default,
  uses the session default. See Details – it does not change where CJK
  sentences break.

## Value

A list the same length as `x`, each element a character vector of
sentences. `NA` gives `NA_character_`; the empty string gives
`character(0)`.

## Details

A regular expression on `[.!?]` finds no boundary at all in Chinese or
Japanese text, because neither uses those characters to end a sentence.
This is the reason the function exists: it is the sentence-level
counterpart of
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md),
and the usual first step before sentence-level classification,
translation or embedding.

Boundaries follow Unicode Annex \#29. `locale` is accepted and
forwarded, but do not expect it to change where CJK sentences break:
across Chinese, Japanese, Korean and mixed text it gave identical output
under `"zh"`, `"ja"`, `"ko"`, `"en"` and the session default. ICU can
tailor break rules per locale in principle, and a locale it has no break
data for is an error here rather than a silent fallback, which is why
the argument is worth having at all.

## What comes back

The spans are ICU's, returned unmodified, which has one visible
consequence: whitespace that sits between two sentences stays attached
to the end of the first. Nothing is trimmed, because trimming would make
this verb edit text rather than divide it. Call
[`trimws()`](https://rdrr.io/r/base/trimws.html) on the result if you
want it gone.

## A limitation worth knowing

Abbreviations are a hard case in Latin text and ICU's default rules do
not carry an abbreviation list, so `"Dr. Smith went home."` splits after
`"Dr. "`. CJK text does not have the problem, because the terminator is
unambiguous. If your corpus is mixed and abbreviation-heavy, check the
result before trusting it.

## See also

[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
for words,
[`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)
for character n-grams.

## Examples

``` r
# "I am happy today. And you?"
cjk_sentences("\u6211\u4eca\u5929\u5f88\u958b\u5fc3\u3002\u4f60\u5462\uff1f")
#> [[1]]
#> [1] "我今天很開心。" "你呢？"        
#> 

# ASCII terminators work too, and mixed text is fine
cjk_sentences("First one. \u4e2d\u6587\u4e5f\u53ef\u4ee5\u3002")
#> [[1]]
#> [1] "First one. "  "中文也可以。"
#> 

# One row per sentence, the way cjk_tokens() gives one row per token.
# There is no tidy verb for this because the list is already the hard
# part; rep() over lengths() is the whole of the rest.
docs <- data.frame(
  id = 1:2,
  text = c("\u6211\u5f88\u958b\u5fc3\u3002\u4f60\u5462\uff1f", "One. Two.")
)
sents <- cjk_sentences(docs$text)
data.frame(
  id = rep(docs$id, lengths(sents)),
  sentence = unlist(sents, use.names = FALSE)
)
#>   id   sentence
#> 1  1 我很開心。
#> 2  1     你呢？
#> 3  2      One. 
#> 4  2       Two.
```
