# Segmentation engines

`cjk_segmenters()` lists the engines
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
can dispatch to, and `register_cjk_segmenter()` adds one.

## Usage

``` r
cjk_segmenters()

register_cjk_segmenter(name, fn)
```

## Arguments

- name:

  Name of the engine, a single string.

- fn:

  A function of `(x, ...)` returning a list of character vectors.

## Value

`cjk_segmenters()` returns a character vector of engine names.
`register_cjk_segmenter()` is called for its side effect and returns
`name` invisibly.

## Details

Where a word begins and ends in CJK text is a fact about a language, not
about Unicode, so it cannot be derived the way everything else in this
package is. It needs a dictionary and a statistical model, and which one
is right depends on the language and the corpus. tidycjk therefore
dispatches on a name rather than committing to one.

Two engines ship with the package.

`"icu"` is a real word segmenter. ICU carries dictionary-based break
iterators for Chinese and Japanese, and stringi carries ICU, so this
costs no dependency you have not already installed: a six-character
Chinese sentence comes back as its four words rather than as six
characters.

`locale` is accepted and forwarded, but it does not select the
dictionary. ICU applies a single combined Chinese-Japanese word list to
Han and kana runs, chosen by the script of the text, so Chinese and
Japanese segment the same way under `"zh"`, `"ja"` or the session
default. It returns surface forms only, with no part of speech, lemma or
user dictionary, and its models are lighter than MeCab's or jieba's
tuned ones. It is the right starting point and not the last word.

`"character"` needs nothing at all: every CJK character becomes its own
token and runs of non-CJK text are split on whitespace. Whitespace is
never a token, the ideographic space U+3000 included, even though
[`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md)
counts it as CJK. It is character tokenisation rather than word
segmentation, and for Chinese it will cut two-character words in half.
It is a baseline, not an answer.

## The two engines do not tokenise punctuation alike

This matters when comparing counts, so it is worth stating rather than
leaving to be discovered. `"icu"` drops punctuation and symbols along
with whitespace; `"character"` keeps CJK punctuation as tokens, because
those code points are in blocks
[`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
lists, and keeps a run of non-CJK text whole up to the next space.

The upshot is that the same sentence yields different token counts, and
the gap is punctuation rather than a disagreement about where words end.
An emoji is dropped by `"icu"` and kept by `"character"` for the same
reason. Filter or compare accordingly.

## Registering another segmenter

For Japanese, [gibasa](https://CRAN.R-project.org/package=gibasa) binds
MeCab and is on CRAN; it gives part of speech and lemma, which `"icu"`
does not.

[jiebaR](https://CRAN.R-project.org/package=jiebaR), which binds
[cppjieba](https://github.com/yanyiwu/cppjieba), is the usual choice for
Chinese. It was archived from CRAN on 2025-05-01, so it cannot be a
dependency of a CRAN package and
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
will not find it; install it from source with
`remotes::install_github("qinwf/jiebaR")`. Once you have it, four lines
make it an engine:

    register_cjk_segmenter("jiebar", function(x, ...) {
      worker <- jiebaR::worker(...)
      lapply(x, function(s) {
        if (is.na(s)) return(NA_character_)
        if (!nzchar(s)) return(character(0))
        as.character(jiebaR::segment(s, worker))
      })
    })

The same shape works for any segmenter you can call from R.

## The engine contract

An engine is any function taking `(x, ...)` – a character vector and the
dots from
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
– and returning a list the same length as `x`, each element a character
vector of tokens. `NA` input should give `NA_character_` and the empty
string should give `character(0)`;
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
checks the shape and complains if an engine breaks the contract. A plain
list is required: a data frame is a list too, but
[`length()`](https://rdrr.io/r/base/length.html) on one counts columns
rather than elements, so it is refused rather than quietly mistaken for
a list of tokens.

## Passing arguments to an engine

Anything in `...` goes to the engine, which is how you configure one.
Name those arguments so that they are not a prefix of an argument of the
verb itself: `...` comes after `engine` in
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md),
and after `data` and `col` in
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md),
so R's partial matching claims a prefix of one of those before the dots
ever see it.

It is worth knowing because the result does not look like an
argument-matching problem. `cjk_tokens(df, text, "mine", c = 1)` matches
`c` to `col`, which pushes the bare `text` into `engine`, where it
resolves to [`graphics::text()`](https://rdrr.io/r/graphics/text.html) –
a function, so it is accepted as an engine – and the error you get is
about plotting. Single letters and short prefixes are the risk: `c`,
`co`, `d`, `da`, `e`, `en`, `eng`. A longer name, or a closure that
captures the setting instead of passing it, avoids the question:

    register_cjk_segmenter("mine", function(x, ...) my_segmenter(x, cutoff = 1))

## What registering does, and does not, undo

A registration lasts for the rest of the session and there is no
function to remove one. Registering the same name again replaces it,
which is the way to correct an engine you got wrong.

A name that matches a built-in shadows it. That is deliberate – it is
how you substitute your own tokeniser for `"character"` without this
package getting a say – but it is worth knowing that `"character"` is a
natural name for an engine and taking it hides the built-in for the
session, with nothing in `cjk_segmenters()` to show that anything
changed. Pick a distinct name unless shadowing is what you meant.

## See also

[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md),
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_tokens.md).

## Examples

``` r
cjk_segmenters()
#> [1] "character" "icu"      

# an engine that splits on an explicit marker
register_cjk_segmenter("pipe", function(x, ...) strsplit(x, "|",
                                                         fixed = TRUE))
cjk_segment("\u4e2d\u6587|\u5f88\u597d", engine = "pipe")
#> [[1]]
#> [1] "中文" "很好"
#> 
```
