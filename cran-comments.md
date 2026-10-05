## Submission

This is an update to tidycjk, from 0.1.0 to 0.2.0.

0.2.0 adds word segmentation through a built-in `"icu"` engine, width-aware
wrapping, sentence splitting, character n-grams, punctuation removal,
Unicode normalisation, locale-aware ordering, romanisation, simplified and
traditional Han conversion, kana conversion and Hangul jamo decomposition.
That is fourteen new exports, all reached through 'stringi' and its 'ICU',
so `Imports` is unchanged. Four vignettes are new. The package still makes
no network requests, contains no compiled code and bundles no data.

## Why this follows 0.1.0 so soon

0.1.0 was published on 2026-09-09. It has bugs that give wrong answers
rather than errors, fixed here and listed under "Fixes to 0.1.0" in NEWS.md:

* every verb measured a list argument as the R code that builds it, so
  `cjk_width(list(c("a", "b")))` answered 11;
* Korean and Chinese text containing the katakana middle dot U+30FB was
  reported as Japanese;
* `has_cjk()` answered `FALSE` for real letters of the scripts it covers:
  the four kana extension blocks and CJK Extension J were missing from the
  block table, which is now current to Unicode 18.0.

Its DESCRIPTION also points at a documentation site that no longer exists:
the repository had been created with its name misspelled, and GitHub does
not redirect a renamed project's Pages site. This release corrects the
`URL` field.

## R CMD check results

0 errors | 1 warning | 2 notes, on R 4.4.1 (Linux x86_64). All three are
properties of the build host, not of the package:

* WARNING: `qpdf` is not installed, so PDF size reduction is not checked.
* NOTE: the host has no network, so the check cannot verify the clock.
* NOTE: no `tidy`, so HTML validation of the manual is skipped.

On R 4.6.0 on the same host: 0 errors | 0 warnings | 1 note (no `tidy`).

## Test environments

* Linux (x86_64), R 4.4.1: `R CMD check --as-cran`, and again with
  `_R_CHECK_DEPENDS_ONLY_=true`.
* Linux (x86_64), R 4.6.0: `R CMD check --as-cran`.
* GitHub Actions: macOS and Windows (R release), Ubuntu (R devel, release
  and oldrel-1).
* The full test suite on R 4.4.1 and R 4.5.3 (ICU 74.1), on R 4.1.0
  (stringi 1.6.2, ICU 60.3), and on R 3.6.3 (stringi 1.5.3, ICU 60.3), the
  last with dplyr 1.0.5 and so as evidence about the R floor rather than a
  supported configuration. On R 4.4.1 also under eight locales: `C`,
  `en_US.UTF-8`, `ja_JP.utf8`, `ko_KR.utf8`, `zh_CN.utf8`, `ja_JP.eucjp`,
  `zh_CN.gb18030` and `ko_KR.euckr`.

There are 2,416 expectations, all passing. On the CRAN path one exhaustive
sweep over the block table is `skip_on_cran()`, leaving 2,351, and
`checking tests` takes about 13 seconds. The two tests about undecodable
bytes skip outside a UTF-8 locale, where those bytes are ordinary native
text, and on stringi versions that warn rather than raise on invalid UTF-8.

## Notes

* Possibly misspelled words in DESCRIPTION are technical terms (CJK,
  fullwidth, halfwidth, ideographic, jamo, NFKC, POSIX, syllabaries,
  pluggable, registrable), package names, or British spellings: the package
  declares `Language: en-GB`.
* `urlchecker::url_check()` finds all 21 URLs in the package correct, and
  the bibliography's 10 URLs and 3 DOIs resolve.

## Reverse dependencies

None: `tools::package_dependencies("tidycjk", reverse = TRUE)` against the
current CRAN index returns nothing.
