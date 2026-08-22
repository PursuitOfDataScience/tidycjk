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
* Locally on Linux (x86_64, glibc): R 4.4.1, R 4.5.3 and R 4.6.0, the last of
  these against dplyr 1.2.1. Also checked with `_R_CHECK_DEPENDS_ONLY_=true`,
  so the tests and examples run with only the declared dependencies available,
  and with the strict `_R_CHECK_LENGTH_1_LOGIC2_` and
  `_R_CHECK_LENGTH_1_CONDITION_` settings. The test suite additionally passes
  under `LC_ALL=C`, which is what the ASCII-only sources are for.
* The declared floor, `R (>= 3.5.0)`, was exercised as well: the test suite
  passes under R 3.6.3 with tibble 3.1.0 and stringi 1.5.3. That run used
  dplyr 1.0.5, which is below the declared `dplyr (>= 1.1.0)`, so it is
  evidence about the R version rather than a supported configuration; the one
  test that skips there is the one asserting how invalid UTF-8 is reported,
  because stringi 1.5.3 warns where later versions raise an error, and the
  test says so.

## R CMD check results

0 errors | 0 warnings | 1 note

The one note is "New submission", from the CRAN incoming feasibility check.

## Spelling

The package is written in British English, which the `Language: en-GB`
field in DESCRIPTION declares. About forty words in DESCRIPTION and the
help pages are still flagged, and every one of them falls into one of
four groups:

* Unicode and CJK vocabulary: "Bopomofo", "Hangul", "jamo", "Kanbun",
  "Kangxi", "NFKC", "fullwidth", "halfwidth", "precomposed",
  "uncomposed", "segmenter".
* The two katakana row names "sa" and "wa".
* Fragments of code points. A range written "U+2EBF0" or "U+2EFF" is
  split by aspell into pieces such as "EBF" and "EFF"; a package about
  Unicode blocks cannot avoid naming ranges.
* Package names, including this one: "stringi", "tibble", "tibbles",
  "tidytext", "tidyverse", "tidycjk", "jiebaR", "pinyin", "hanyupinyin",
  "tmcn", "zipangu", "Nippon", "cppjieba", "OpenCC".

Possessives of the above ("tidycjk's", "R's") account for the rest. All
are spelled as intended.

## Encoding

The package is about CJK text, but every file under `R/` and `tests/` is pure
ASCII: CJK strings are written with `\u` escapes and referred to in prose by
code point, so no checking host has to agree about the file encoding. Examples
therefore print real CJK output while the sources stay portable.

## Downstream dependencies

There are no reverse dependencies (checked with
`tools::package_dependencies(reverse = TRUE)`).
