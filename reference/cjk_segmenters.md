# Segmentation engines

`cjk_segmenters()` lists the engines
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segment.md)
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
bundles no word segmenter and dispatches on a name instead.

One engine ships with the package. `"character"` needs nothing at all:
every CJK character becomes its own token and runs of non-CJK text are
split on whitespace. It is character tokenisation rather than word
segmentation, and for Chinese it will cut two-character words in half.
It is a baseline, not an answer.

## Registering a word segmenter

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
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segment.md)
– and returning a list the same length as `x`, each element a character
vector of tokens. `NA` input should give `NA_character_` and the empty
string should give `character(0)`;
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segment.md)
checks the shape and complains if an engine breaks the contract.

## See also

[`cjk_segment()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_segment.md),
[`cjk_tokens()`](https://pursuitofdatascience.github.io/tidyckj/reference/cjk_tokens.md).

## Examples

``` r
cjk_segmenters()
#> [1] "character"

# an engine that splits on an explicit marker
register_cjk_segmenter("pipe", function(x, ...) strsplit(x, "|",
                                                         fixed = TRUE))
cjk_segment("\u4e2d\u6587|\u5f88\u597d", engine = "pipe")
#> [[1]]
#> [1] "中文" "很好"
#> 
```
