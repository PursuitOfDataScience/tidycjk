## Submission notes

This is an update (0.2.0) to a package already on CRAN. The previous version
is 0.1.0.

The release adds word segmentation, transliteration, width-aware wrapping,
sentence splitting, character n-grams, locale-aware ordering, Unicode
normalisation and punctuation removal -- fourteen new exports, all reached
through `stringi`/ICU, so it takes no new dependency. `Imports` is
unchanged.

New exported functions: `cjk_wrap()`, `cjk_romanize()`, `cjk_simplify()`,
`cjk_traditionalize()`, `to_hiragana()`, `to_katakana()`, `cjk_jamo()`,
`cjk_compose_jamo()`, `cjk_sentences()`, `cjk_ngrams()`, `cjk_sort()`,
`cjk_order()`, `cjk_normalize()` and `cjk_strip_punct()`. `cjk_segment()`
gains a built-in `"icu"` engine, which is a
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

Two bugs present in 0.1.0 are also fixed:

* `cjk_detect_language(han_only = )` accepted `NaN` and `list(NA)`,
  returning them as the detected languages `"NaN"` and the string `"NA"`.
  Both are now errors.
* Every verb deparsed a list argument instead of rejecting it.
  `as.character()` does not coerce a list, it deparses one, so
  `cjk_width(list(c("a", "b")))` answered **11** -- the display width of the
  eleven-character string `c("a", "b")`, R source measured as if it were text,
  with no error and no warning. This was reachable rather than theoretical:
  `cjk_jamo()`, `cjk_sentences()` and `cjk_segment()` all return lists, and
  the jamo round trip written the obvious way handed back
  `c("\u1112", "\u1161", "\u11ab")` as a literal string. A shared guard now
  raises, naming the two ways out, and the three tidy verbs check a pulled
  list-column the same way. `NULL`, numeric, logical and factor input are
  all still coerced exactly as before. This is the check `cjk_segment()`
  already applied to what a segmentation *engine* returns, applied at last
  to what a *caller* passes in.

## Overlap with existing packages

Display width and padding remain thin, documented wrappers over `stringi`
(`stri_width()`, `stri_pad()`, and now `stri_wrap()` for `cjk_wrap()`), which
the help pages say explicitly while pointing at `stringi` for callers who
need only that. The transliteration verbs are likewise documented as ICU
transforms.

What the package adds over calling ICU directly is a single contract across
the verbs -- `NA` in, `NA` out; zero length in, zero length out; a ragged
recycle is an error -- and guards where ICU's own behaviour is quietly wrong
for this use. Three examples:

* `stri_sort()` drops missing values, so `cjk_sort()` keeps them and
  preserves length. It is also built on `stri_order()` rather than
  `stri_sort()`, so it can only reorder its input, never return
  round-tripped values.
* An unusable locale makes ICU fall back to the root one. Every verb taking
  a `locale` -- `cjk_sort()`, `cjk_order()`, `cjk_sentences()`,
  `cjk_wrap()` and `cjk_segment(engine = "icu")` -- turns that into an
  error, checked against `stri_locale_list()` rather than against a
  warning, because stringi 1.6.2 does not emit one.
* Several stringi entry points drop a leading U+FEFF; the verbs that call
  them restore it, so text from a BOM-carrying CSV is not silently edited.
* One inherited behaviour is documented rather than guarded, because
  guarding it would cost more than it saves. `stri_wrap()` normalises to
  NFC, ICU's line-breaking being defined on normalised text, so
  `cjk_wrap()` returns NFC where `cjk_pad()`, `cjk_truncate()` and
  `cjk_segment()` do not: `cjk_wrap("\uf900", 2)` is U+8C48. A sweep of
  every code point in Unicode puts the affected set at 1,120 and shows it
  is exactly the set NFC changes: 460 of the 472 assigned CJK
  compatibility ideographs, all 542 of the supplement, 34 Hebrew
  presentation forms, 13 musical symbols, and 71 scattered singletons and
  composition exclusions (the Kelvin and Ohm signs, Greek letters with an
  oxia, Devanagari letters with a nukta and the like), each a duplicate of
  a character or sequence Unicode prefers. `normalize = FALSE`
  would stop it, but the same argument turns off whitespace collapsing and
  makes `stri_wrap()` raise on any string containing a newline, which would
  break re-wrapping already-wrapped text. `?cjk_wrap` says all of this, and
  a test over the whole block table pins the set so a change upstream
  surfaces as a failure.
* `cjk_strip_punct()` exists because the obvious spelling is wrong on CJK
  in two different ways. `gsub("[[:punct:]]", "", x)` resolves the class
  through the C library, so it removes no CJK punctuation under `LC_ALL=C`
  and all of it under a UTF-8 locale; `perl = TRUE` looks like the careful
  choice and is worse, PCRE's POSIX classes being ASCII-only without
  `(*UCP)`, so it removes nothing from Chinese or Japanese in any locale.
  Testing Unicode's General_Category also keeps U+30FC, the prolonged sound
  mark that carries the long vowel in most Japanese loanwords, which any
  rule phrased about dash-like characters removes.
* `cjk_normalize()` is more than a form selector over `stri_trans_nfc()`
  and friends. It removes variation selectors *before* applying the form
  rather than after, because a selector has combining class zero and blocks
  canonical composition across itself -- strip one afterwards and the
  result can fail a normalisation check for the form just requested. Its
  help page also documents what plain NFC does to Han, which is the thing
  callers reaching for the "safe" form do not expect: singleton canonical
  mappings mean 460 of the 472 CJK compatibility ideographs are rewritten
  by `"nfc"` exactly as by `"nfkc"`.

Related CRAN packages are named in the README, in `?tidycjk` and in the
vignettes: `gibasa` (MeCab) and `jiebaR` for segmentation, `pinyin` and
`hanyupinyin` for romanisation, `tmcn` for traditional/simplified
conversion, `zipangu` and `Nippon` for Japanese utilities, and `tidytext`,
whose `unnest_tokens()` `cjk_tokens()` mirrors.

## Backward compatibility with 0.1.0

Checked rather than assumed. Both versions were installed side by side and
every 0.1.0 export was run under each over the same 611-string corpus --
which includes the empty string, whitespace, the ideographic space, one and
two leading byte-order marks, a zero-width space, a combining mark, `NA`,
fullwidth forms, halfwidth katakana, bopomofo, kanbun, supplementary-plane
ideographs and 600 random mixed-script strings. Twenty-four calls covering
all sixteen exports and their argument variants: **twenty-one return
byte-identical results.**

The three differences are all intended and all in NEWS:

* `cjk_segmenters()` now also lists `"icu"`. Nothing was removed.
* `cjk_segment(engine = "character")` and `cjk_tokens()` now return a
  byte-order mark that 0.1.0 deleted -- 15 of the 611 strings, and 12 extra
  `cjk_tokens()` rows. Every one is a character the old code removed
  without saying so, and U+FEFF was the only zero-width character it
  happened to.
* `cjk_detect_language(han_only = NaN)` and `han_only = list(NA)` are now
  errors where 0.1.0 returned the languages `"NaN"` and the string `"NA"`.
  Every well-formed `han_only` -- a string, `NA`, `NA_character_` -- behaves
  exactly as before, and the two malformed ones were the bug.

Every 0.1.0 `\usage` section is also byte-identical to its 0.2.0
counterpart, so no signature changed.

## Test environments

Every environment below was re-run against the final 0.2.0 sources rather
than carried over from development, which is how the two non-portable
assertions noted under R 4.1.0 were found. The suite is 2,259 assertions on
a current R; the lower counts on older or non-UTF-8 configurations are
skips with stated reasons, not absences.

One test is `skip_on_cran()`: an exhaustive pass over all 111,012 code
points in the package's block table, asserting idempotence of each of the
five normalisation forms, the NFC and NFKC composition laws, that
fullwidth text survives `to_halfwidth()` followed by `to_fullwidth()`,
that the layout verbs are no-ops on a string that already fits, that one
character is one token and one 1-gram, and that all thirteen transforms
return one valid, non-missing UTF-8 string per input. It takes about twelve seconds, which
is not CRAN's time to spend; a sampled version -- forty code points from
every block -- runs everywhere, as does a boundary pass over every block
edge and the code point either side of it. On the CRAN path the suite is
2,195 assertions with that one skip, and `checking tests` takes 15s.

A one-off sweep of all 1,112,029 valid code points in Unicode confirmed
`has_cjk()`, `cjk_ratio()` and `cjk_script()` agree with the block table in
both directions -- no character wrongly called CJK, none wrongly left out --
and that `cjk_width()` is never missing and never outside 0:2. That result
is recorded rather than re-run on every job, since the table is static
data; what stays in the suite is the boundary pass, boundaries being where
an interval lookup actually fails.

* Locally on Linux (x86_64, glibc), R 4.4.1:
  - `R CMD check --as-cran`.
  - Again with `_R_CHECK_DEPENDS_ONLY_=true`, so examples, tests and the
    vignette rebuild all run with only the declared dependencies available,
    and with the strict `_R_CHECK_LENGTH_1_LOGIC2_` and
    `_R_CHECK_LENGTH_1_CONDITION_` settings. Clean.
  - The test suite passes under eight locales: `C`, `en_US.UTF-8`, the CJK
    UTF-8 locales `ja_JP.utf8`, `ko_KR.utf8` and `zh_CN.utf8`, and the
    legacy CJK encodings `ja_JP.eucjp`, `zh_CN.gb18030` and `ko_KR.euckr`.
    The CJK locales are checked because ICU tailors the Annex #14
    line-breaking style per locale, and `LC_COLLATE` changes what `sort()`
    returns. The four UTF-8 locales run the whole suite; `C` and the three
    legacy encodings skip two tests and say why. Both concern how
    undecodable bytes are reported, and both skip for the same reason:
    outside a UTF-8 locale the bytes in question are ordinary text in the
    native encoding, so there is nothing for either test to assert. One of
    the two additionally skips where stringi only warns rather than raising,
    which older versions do.
* Newer R on the same host: R 4.5.3 (dplyr 1.2.1, tibble 3.3.1), full suite
  passing; and R 4.6.0, where `R CMD check --as-cran` reports no errors, no
  warnings, and only notes that are properties of the host.
* Older R and, importantly, older ICU, on the same Linux host:
  - R 4.1.0 with stringi 1.6.2 / **ICU 60.3** (the machine above has ICU
    74.1), which reports Unicode 10.0. The full suite passes. This is the
    pair the package's own documentation cites as having changed East Asian
    Width, so it is a real test of the ICU-version independence the tests
    are written for -- and it earned its place again in this release: two
    new tests pinned the number of Unicode variation selectors at 260,
    which is true of Unicode 15.1 and false of 10.0, and two more asserted
    an error that stringi 1.5.3 reports as a warning. All four now assert
    the property rather than the build, or skip with a reason.
  - R 3.6.3 with stringi 1.5.3, tibble 3.1.0 and testthat 3.0.2. The package
    installs and the full suite passes, which exercises the declared
    `R (>= 3.5.0)` floor. That run has dplyr 1.0.5, below the declared
    `dplyr (>= 1.1.0)`, so it is evidence about the R version rather than a
    supported configuration.
  - The spread of R versions earned its place again this release. The new
    guard on list arguments has to admit `NULL`, and `is.atomic(NULL)`
    changed from `TRUE` to `FALSE` in R 4.4.0 -- measured here as `TRUE` on
    3.6.3 and 4.1.0, `FALSE` on 4.6.0. An `is.atomic()` test alone would
    therefore have started rejecting `NULL` halfway through the versions
    this package supports, so the guard tests `is.null()` first. Counts,
    all with zero failures: 2,234 assertions on R 3.6.3 (3 skips), 2,238 on
    R 4.1.0 (2 skips), 2,259 on R 4.4.1 (no skips), 2,195 on R 4.6.0
    against the installed package.
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

0 errors | 1 warning | 3 notes on the maintainer's machine. All four are
properties of that host rather than of the package:

* WARNING: `qpdf` is not installed, so the check cannot test PDF size
  reduction.
* NOTE: no `tidy`, so HTML validation of the manual is skipped.
* NOTE: no network access, so the check cannot verify the system clock
  ("unable to verify current time").
* NOTE: CRAN incoming feasibility, reporting the maintainer address and
  days since the last update.

The same tarball on R 4.6.0 checks with 0 errors, 0 warnings and 2 notes:
that host has `qpdf` and a usable clock, so only the incoming-feasibility
and HTML-manual notes remain.

## Spelling

The package is written in British English, declared by `Language: en-GB`.
`spelling::spell_check_package()` flags 77 words, and every one falls into
one of five groups:

* **Unicode and CJK vocabulary**: "bopomofo", "fullwidth", "halfwidth",
  "hangul", "jamo", "Kanbun", "Kangxi", "KangXi", "NFKC", "precomposed",
  "uncomposed", "romaji", "syllabaries", "segmenter", "segmenters",
  "transliterator", "transliterators", "subtag", "Unihan", "caron" -- some
  in both capitalisations, since they begin sentences as well as appearing
  inline.
* **The two katakana row names** "sa" and "wa", which `?to_halfwidth` names
  when describing which rows take a voiced mark.
* **Fragments of code point ranges.** A range written "U+2EBF0" or
  "U+FFDC" is split by aspell into pieces such as "EBF", "FFDC", "FEFF" and
  "AF". Sixteen of the 77 are these. A package about Unicode blocks cannot
  avoid naming ranges. "BCP" is the same kind of thing, from "BCP 47".
* **Package, tool and standard names**: "stringi", "stringr", "dplyr",
  "tibble", "tibbles", "tidytext", "tidyverse", "pkgdown", "roxygen",
  "Lifecycle", "gibasa", "MeCab", "jiebaR", "cppjieba", "pinyin",
  "hanyupinyin", "tmcn", "zipangu", "OpenCC", "NLP", "CMD", "glibc",
  "PCRE's" -- the last two from `?cjk_strip_punct`, which has to name the
  two regular-expression engines whose POSIX classes it exists to avoid.
* **Possessives and a few ordinary words aspell lacks**: "ICU's", "R's",
  "MeCab's", "jieba's", "tidycjk's" -- in both straight and typographic
  apostrophe forms, since pandoc converts them in the vignettes -- plus
  "composable", "chunker", "greppable", "segfaults" and "ramen" -- the
  last from `?cjk_strip_punct`, naming a word the prolonged sound mark
  appears in.

All are spelled as intended.

## Encoding

Every file under `R/` and `tests/` is pure ASCII: CJK strings are written
with `\u` escapes and referred to in prose by code point, so no checking host
has to agree about the file encoding, and no CJK glyph reaches the LaTeX
manual. Examples still print real CJK output. The vignettes contain literal
CJK, which is rendered by pandoc to HTML and never typeset by LaTeX.

## URLs

`urlchecker::url_check()` reports no problems: all 20 URLs in DESCRIPTION,
`R/`, `man/`, the vignettes and the README resolve. The bibliography's ten
URLs and three DOIs were checked separately, since `urlchecker` does not
scan BibTeX, and all thirteen resolve too.

## Downstream dependencies

`tools::package_dependencies("tidycjk", reverse = TRUE)` against a current
CRAN index returns `character(0)`: no reverse dependencies.
