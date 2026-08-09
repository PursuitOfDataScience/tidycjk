## Submission notes

This is a new submission (0.1.0).

`tidycjk` provides tidy verbs for Chinese, Japanese and Korean text: script and
language classification, CJK ratio, per-character frequency tables, display
width in terminal columns, and fullwidth/halfwidth normalisation.

The package makes no network requests, at build time, check time or run time.
It contains no compiled code and bundles no data. Every example, test and
help-page computation is pure arithmetic over Unicode code points.

## Overlap with existing packages

Display width and width-aware padding are delegated to `stringi`
(`stri_width()`, `stri_pad()`) rather than re-implemented, so `cjk_width()` and
`cjk_pad()` are documented wrappers that exist for naming consistency within
the package; the help pages say so and point users to `stringi` directly if
that is all they need. `cjk_truncate()` has no `stringi` equivalent.

The genuinely new material is the tidy layer (`cjk_summary()`,
`cjk_char_counts()`), the script and language classification, and the surgical
width normaliser with halfwidth-katakana voiced-mark composition.

Related CRAN packages are named in the README and in `?tidycjk`, under
"Related packages": `jiebaR` for Chinese segmentation, `pinyin` and
`hanyupinyin` for romanisation, `tmcn` for character-level
traditional/simplified conversion, `zipangu` and `Nippon` for Japanese
utilities, and `tidytext`, whose `unnest_tokens()` `cjk_tokens()` mirrors.

## Test environments

* GitHub Actions:
  - ubuntu-latest: R-release, R-devel, R-oldrel-1
  - macOS-latest: R-release
  - windows-latest: R-release
* win-builder: R-devel and R-release

## R CMD check results

0 errors | 0 warnings | 0 notes

## Encoding

The package is about CJK text, but every file under `R/` and `tests/` is pure
ASCII: CJK strings are written with `\u` escapes and referred to in prose by
code point, so no checking host has to agree about the file encoding. Examples
therefore print real CJK output while the sources stay portable.

## Downstream dependencies

There are no reverse dependencies (checked with
`tools::package_dependencies(reverse = TRUE)`).
