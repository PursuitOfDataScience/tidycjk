# Which language is the text written in?

`cjk_detect_language()` infers the language of each string from the
scripts it contains, and returns `NA` when the scripts do not settle the
question.

## Usage

``` r
cjk_detect_language(x, han_only = NA_character_)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.

- han_only:

  What to return for a string written in Han characters only. Defaults
  to `NA_character_`, meaning "undecidable". Set it to `"chinese"` to
  opt into the guess.

## Value

A character vector the same length as `x`, holding `"japanese"`,
`"korean"`, `"chinese"`, the value of `han_only`, or `NA`.

## Details

The rules are applied in order:

1.  Hiragana or katakana present: `"japanese"`. Only Japanese uses kana.

2.  Kanbun annotation marks present: `"japanese"`. They exist to make
    Classical Chinese readable as Japanese.

3.  Hangul present: `"korean"`.

4.  Bopomofo present: `"chinese"`. Bopomofo annotates Mandarin.

5.  Han characters and nothing else from the list above: **`NA`** by
    default.

6.  No CJK writing system at all: `NA`.

Rule 5 is the point of the function. Japanese written without kana – a
headline, a shop sign, a personal name, a compound such as U+6771 U+4EAC
U+90FD (Tokyo Metropolis) – is not distinguishable from Chinese by
script alone, because both are writing the same Han characters. Any
package that answers `"chinese"` there is guessing, and it will be wrong
on Japanese input in a way the caller cannot detect. `tidycjk` returns
`NA` instead.

If your corpus is known to be Chinese and you want the guess anyway, ask
for it explicitly with `han_only = "chinese"`. Making it an argument
keeps the assumption in the script, where a reader of the analysis can
see it.

CJK punctuation and fullwidth forms are ignored here, even though
[`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md)
counts them, because all three languages share them.

## See also

[`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md),
which reports what is actually there rather than inferring from it.

## Examples

``` r
# kana settles it; hangul settles it
cjk_detect_language(c("\u3053\u3093\u306b\u3061\u306f", "\uc548\ub155"))
#> [1] "japanese" "korean"  

# U+6771 U+4EAC U+90FD is Tokyo Metropolis: Japanese, written without kana,
# and therefore indistinguishable from Chinese. The honest answer is NA.
cjk_detect_language("\u6771\u4eac\u90fd")
#> [1] NA

# opt in to the guess when you know the corpus is Chinese
cjk_detect_language("\u6771\u4eac\u90fd", han_only = "chinese")
#> [1] "chinese"
```
