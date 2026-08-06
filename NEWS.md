# tidycjk 0.1.0

First release.

`tidycjk` is a tidy toolkit for Chinese, Japanese and Korean text. This release
covers the layer that follows exactly from the Unicode specification: no data
downloads, no compiled code, no network access at build time or run time.

## Tidy layer

* `cjk_summary(data, col)` reports `n_docs`, `n_with_cjk`, `prop_with_cjk` and
  `mean_ratio` for a text column.
* `cjk_char_counts(data, col)` returns one row per distinct CJK character with
  its code point, script, Unicode block and count.

## Vector layer

* `has_cjk()`, `cjk_script()` and `cjk_ratio()` classify and measure.
* `cjk_detect_language()` infers the language from the scripts present.
* `cjk_width()`, `cjk_pad()` and `cjk_truncate()` work in terminal columns
  rather than characters.
* `to_halfwidth()` and `to_fullwidth()` normalise width variants.
* `cjk_blocks()` exports the Unicode block table the package is built on.

## Notes on the design

* **Language detection returns `NA` rather than guessing.** Japanese written
  without kana is not distinguishable from Chinese by script alone, so a
  Han-only string gets `NA`. `cjk_detect_language(x, han_only = "chinese")`
  opts into the guess and keeps the assumption visible in the calling code.

* **Width is delegated to stringi.** `cjk_width()` and `cjk_pad()` wrap
  `stringi::stri_width()` and `stringi::stri_pad()`, which read ICU's live
  Unicode tables. A hand-maintained range table would go stale at every Unicode
  release and would already be wrong for a few hundred assigned code points.
  `cjk_truncate()` has no stringi equivalent and is implemented here.

* **Normalisation is surgical.** `to_halfwidth()` maps fullwidth ASCII, the
  ideographic space and halfwidth katakana, and touches nothing else. `NFKC`
  additionally rewrites ligatures, superscripts, Roman numerals, circled
  numbers, the no-break space and the CJK compatibility ideographs, which is
  almost never wanted.

* **Voiced marks are composed by default.** Halfwidth katakana writes a voiced
  syllable as two code points; `compose = TRUE` folds them into the single
  precomposed character, so `"ｶﾞ"` becomes `"ガ"`. Every pair in
  the composition table agrees with Unicode NFC, including the five that break
  the base-plus-one rule.

* **Ties never depend on the locale.** `cjk_script()` and `cjk_char_counts()`
  break ties by first appearance rather than by collation order.

## Not in this release

* **Segmentation.** Splitting a CJK sentence into words needs a dictionary and
  a statistical model. The engine question is unresolved; `jiebaR` exists for
  Chinese today.
* **Pinyin, stroke counts and radicals.** These need the Unihan database.
  `data-raw/unihan.R` downloads and parses it, but no character data is
  hand-written or bundled yet. `pinyin` and `hanyupinyin` are on CRAN today.
* **Traditional/simplified conversion.** Unihan gives character-level mappings
  only, and character-level conversion is wrong often enough to matter: one
  simplified character can map to several traditional ones and the right choice
  is context-dependent. Shipping it as if it were complete would be a
  disservice. `tmcn` offers character-level conversion today; OpenCC is the
  phrase-level answer outside R.
