## Submission notes

This is an update (0.2.0) to a package already on CRAN. The previous version
is 0.1.0.

The release adds word segmentation, transliteration and two NLP preprocessing
verbs, all reached through `stringi`/ICU, so it takes no new dependency.
`Imports` is unchanged.

New exported functions: `cjk_wrap()`, `cjk_romanize()`, `cjk_simplify()`,
`cjk_traditionalize()`, `to_hiragana()`, `to_katakana()`, `cjk_jamo()`,
`cjk_compose_jamo()`, `cjk_sentences()`, `cjk_ngrams()`, `cjk_sort()` and
`cjk_order()`. `cjk_segment()` gains a built-in `"icu"` engine, which is a
dictionary-based word segmenter rather than the character-level baseline
0.1.0 shipped.

The package still makes no network requests at build, check or run time,
contains no compiled code, and bundles no data.

Four vignettes are new; 0.1.0 had none.

## One correction to 0.1.0's documentation

0.1.0 stated that no word segmenter could be bundled because `jiebaR` had
been archived. The archival was correct, but the conclusion was not: ICU
carries dictionary-based break iterators for Chinese and Japanese and
`stringi` carries ICU, which has been an `Imports` dependency since the first
release. NEWS says so plainly rather than presenting the engine as new work.

A bug present in 0.1.0 is also fixed: `cjk_detect_language(han_only = )`
accepted `NaN` and `list(NA)`, returning them as the detected languages
`"NaN"` and the string `"NA"`. Both are now errors.

## Overlap with existing packages

Display width and padding remain thin, documented wrappers over `stringi`
(`stri_width()`, `stri_pad()`, and now `stri_wrap()` for `cjk_wrap()`), which
the help pages say explicitly while pointing at `stringi` for callers who
need only that. The transliteration verbs are likewise documented as ICU
transforms.

What the package adds over calling ICU directly is a single contract across
the verbs -- `NA` in, `NA` out; zero length in, zero length out; a ragged
recycle is an error -- and guards where ICU's own behaviour is quietly wrong
for this use. Two examples: `stri_sort()` drops missing values, so
`cjk_sort()` keeps them and preserves length; and a locale ICU has no data
for produces a warning and a silent fallback to the root collation, which
`cjk_sort()`, `cjk_sentences()` and the `"icu"` engine turn into an error.

Related CRAN packages are named in the README, in `?tidycjk` and in the
vignettes: `gibasa` (MeCab) and `jiebaR` for segmentation, `pinyin` and
`hanyupinyin` for romanisation, `tmcn` for traditional/simplified
conversion, `zipangu` and `Nippon` for Japanese utilities, and `tidytext`,
whose `unnest_tokens()` `cjk_tokens()` mirrors.

## Test environments

* Locally on Linux (x86_64, glibc), R 4.4.1:
  - `R CMD check --as-cran`.
  - Again with `_R_CHECK_DEPENDS_ONLY_=true`, so examples, tests and the
    vignette rebuild all run with only the declared dependencies available,
    and with the strict `_R_CHECK_LENGTH_1_LOGIC2_` and
    `_R_CHECK_LENGTH_1_CONDITION_` settings. Clean.
  - The test suite passes under eight locales: `C`, `en_US.UTF-8`, the three
    CJK UTF-8 locales `ja_JP.utf8`, `ko_KR.utf8` and `zh_CN.utf8`, and the
    three legacy CJK encodings `ja_JP.eucjp`, `zh_CN.gb18030` and
    `ko_KR.euckr`. The CJK locales matter here: ICU tailors the Annex #14
    line-breaking style per locale, and a test that assumed the strict style
    passed under C and en_US while failing under ja_JP, so `cjk_wrap()` now
    takes a `locale` argument naming the style. `ko_KR.euckr` caught a
    second one, where a test compared against `sort()`, whose order follows
    `LC_COLLATE`.
    `LC_ALL=C` is also what the ASCII-only sources under `R/` and `tests/`
    are for. One test skips under it, and says why: it asserts how invalid
    UTF-8 is reported, and the installed stringi warns where later versions
    raise an error.
* Newer R on the same host: R 4.5.3 (dplyr 1.2.1, tibble 3.3.1), full suite
  passing; and R 4.6.0, where `R CMD check --as-cran` reports no errors, no
  warnings, and only notes that are properties of the host.
* Older R and, importantly, older ICU, on the same Linux host:
  - R 4.1.0 with stringi 1.6.2 / **ICU 60.3** (the machine above has ICU
    74.1). The full suite passes. This is the pair the package's own
    documentation cites as having changed East Asian Width, so it is a real
    test of the ICU-version independence the tests are written for.
  - R 3.6.3 with stringi 1.5.3, tibble 3.1.0 and testthat 3.0.2. The package
    installs and the full suite passes, which exercises the declared
    `R (>= 3.5.0)` floor. That run has dplyr 1.0.5, below the declared
    `dplyr (>= 1.1.0)`, so it is evidence about the R version rather than a
    supported configuration.
* GitHub Actions, on every push: macOS-latest (release), windows-latest
  (release), ubuntu-latest (devel, release, oldrel-1).

## Tests and ICU versions

Several of the new verbs are ICU transforms, and ICU's tables are not fixed
by the Unicode standard -- its pinyin readings, its CJK word dictionary, its
simplified/traditional mapping and its collations can all differ between
builds. The tests therefore assert the properties that must hold on any ICU
(romanisation leaves no Han behind; `ascii = TRUE` yields pure ASCII;
segmentation is lossless and produces multi-character tokens; a simplified
character converts differently in two different words) rather than pinning
the particular values this machine's ICU produces. That follows the existing
practice in `tests/testthat/test-width.R`, which deliberately does not assert
a column count for East Asian Ambiguous characters, ICU having changed it
between versions.

## One upstream crash worked around

`stringi::stri_wrap()`'s default optimal-fit algorithm segfaults on a long
string: `stri_wrap(strrep("\u4e2d\u6587", 50000), 40)` brings R down on this
machine, at any width, with no tidycjk in the call. `cjk_wrap()` switches to
the greedy algorithm above 10,000 characters to avoid handing stringi input
that crashes the session. The two agree exactly on CJK text.

## R CMD check results

0 errors | 0 warnings | 0 notes on the maintainer's machine, once the notes
that are properties of that host are set aside: `qpdf` and HTML `tidy` are
not installed there, and it has no network access to verify the system clock.

## Spelling

The package is written in British English, declared by `Language: en-GB`.
The words aspell flags fall into the same four groups as in 0.1.0 --
Unicode and CJK vocabulary, katakana row names, fragments of code point
ranges such as "EBF" from "U+2EBF0", and package names -- with these added
by this release: "romanise", "romanisation", "romaji", "romaja", "jamo",
"collation", "hiragana", "katakana", "pinyin", "bopomofo", "zhuyin",
"KangXi", "gibasa", "OpenCC" and "cjdict". All are spelled as intended.

## Encoding

Every file under `R/` and `tests/` is pure ASCII: CJK strings are written
with `\u` escapes and referred to in prose by code point, so no checking host
has to agree about the file encoding, and no CJK glyph reaches the LaTeX
manual. Examples still print real CJK output. The vignettes contain literal
CJK, which is rendered by pandoc to HTML and never typeset by LaTeX.

## Downstream dependencies

There are no reverse dependencies (checked with
`tools::package_dependencies(reverse = TRUE)`).
