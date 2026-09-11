# Remove punctuation from CJK text

`cjk_strip_punct()` removes punctuation using Unicode's own category
rather than a POSIX class, so the same call removes the same characters
on every machine. It is the step before
[`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)
or
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
that stops punctuation becoming part of a token.

## Usage

``` r
cjk_strip_punct(x, replacement = " ", symbols = FALSE)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

- replacement:

  A single string to put in place of each removed character. Defaults to
  `" "`; see above for why it is not `""`.

- symbols:

  Also remove General_Category `S`: the fullwidth tilde U+FF5E, currency
  signs including U+FFE5, and mathematical operators. Defaults to
  `FALSE`, because a currency sign is often content.

## Value

A character vector the same length as `x`. `NA` gives `NA`, and a
leading byte-order mark is preserved.

## Details

The usual spelling, `gsub("[[:punct:]]", "", x)`, is unreliable on CJK
in two separate ways. R's default engine resolves `[:punct:]` through
the C library, so under `LC_ALL=C` it removes no CJK punctuation and
under a UTF-8 locale it removes all of it – the same script gives two
answers on two machines. Passing `perl = TRUE` does not fix it but hides
it: PCRE's POSIX classes are ASCII-only unless `(*UCP)` is set, so that
spelling silently removes nothing from Chinese or Japanese in any locale
at all.

This removes Unicode General_Category `P`, which is the ideographic full
stop U+3002, the ideographic comma U+3001, the fullwidth comma, question
mark and exclamation mark, the corner and fullwidth brackets, and the
katakana middle dot U+30FB that separates the parts of a transliterated
name – along with ASCII punctuation, so mixed text needs only one pass.

## What it deliberately keeps

U+30FC, the katakana-hiragana prolonged sound mark, is a *modifier
letter* and not punctuation. It looks like a dash and is not one: it
carries the long vowel in most Japanese loanwords, so removing it turns
the words for coffee and ramen into something else. Testing the category
keeps it; any rule phrased about dashes does not.

The ideographic space U+3000 is whitespace rather than punctuation and
is left alone too.
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
and
[`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)
already ignore whitespace, so there is nothing to do about it here.

## Why the default replaces rather than deletes

`replacement` defaults to a space, not `""`. Deleting a full stop closes
the gap it left, and the two characters that were on either side of it
become adjacent:
[`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)
then reports a bigram spanning a sentence boundary, a "word" that was
never written. A space keeps the boundary, and every verb here that
walks a string already declines to cross whitespace. Pass
`replacement = ""` when you want the characters closed up – for a
display string rather than for tokenising.

## See also

[`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)
and
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md),
the verbs this feeds;
[`cjk_normalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_normalize.md)
for folding width and compatibility variants.

## Examples

``` r
x <- "\u4ed6\u8aaa\uff08\u4eca\u5929\uff09\u3002\u771f\u597d"
cjk_strip_punct(x)
#> [1] "他說 今天  真好"
cjk_strip_punct(x, replacement = "")
#> [1] "他說今天真好"

# the prolonged sound mark is a letter, not a dash, and survives
cjk_strip_punct("\u30b3\u30fc\u30d2\u30fc\u3001\u30e9\u30fc\u30e1\u30f3")
#> [1] "コーヒー ラーメン"

# a space keeps n-grams from spanning the full stop
cjk_ngrams(cjk_strip_punct("\u597d\u3002\u5929"))
#> [[1]]
#> character(0)
#> 
cjk_ngrams(cjk_strip_punct("\u597d\u3002\u5929", replacement = ""))
#> [[1]]
#> [1] "好天"
#> 
```
