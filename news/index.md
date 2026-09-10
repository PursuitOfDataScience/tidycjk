# Changelog

## tidycjk 0.2.0

A release about the gap between what the package could do and what it
said it could do. 0.1.0 shipped with no bundled word segmenter, no
romanisation and no script conversion, on the reasoning that each needed
a dictionary the package could not carry. That was half right. The
dictionaries were already installed – ICU carries them and
[stringi](https://CRAN.R-project.org/package=stringi) carries ICU, and
stringi has been a hard dependency since the first commit. Most of what
follows is that discovery being spent.

Four vignettes are new, and there were none before.

### Word segmentation now ships

- **`engine = "icu"` is a real word segmenter.**
  `cjk_segment("我今天很開心", engine = "icu")` returns `我` / `今天` /
  `很` / `開心` – words, not characters – using ICU’s dictionary-based
  break iterators for Chinese and Japanese. It costs no new dependency.
- `locale` is accepted and forwarded, but it does *not* select the
  dictionary: ICU applies one combined Chinese-Japanese word list to Han
  and kana runs, chosen by the script of the text. Seven CJK strings
  under five locales segment identically. Anything in `...` reaches the
  engine.
- `engine` still has no default, for the reason it always had:
  `"character"` answers a different question from the one a caller
  asking for words is asking, and would otherwise be the answer they got
  by accident.
- **This reverses a claim 0.1.0 made.** That release said no word
  segmenter could be bundled because jiebaR had been archived from CRAN.
  The archival was true and still is; the error was concluding from it
  that there was no bundled option, when one had been linked into a hard
  dependency the whole time.

### Transliteration

- **[`cjk_romanize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_romanize.md)**
  romanises Han, kana and Hangul to the Latin alphabet. `ascii = TRUE`
  drops tone marks, which is what you want for a sort key.
- **[`cjk_simplify()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md)
  and
  [`cjk_traditionalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_simplify.md)**
  convert between simplified and traditional Han.
- **[`to_hiragana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md)
  and
  [`to_katakana()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md)**
  convert between the kana syllabaries. Halfwidth input is handled and
  composed on the way through: `to_katakana("ｶﾞ")` is the single
  character `ガ`.
- **[`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
  and
  [`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)**
  decompose Hangul syllables into jamo and put them back. The mapping is
  arithmetic in the standard, so the round trip is exact.

#### Two of these are approximations, and say so

0.1.0’s “Not in this release” section withheld traditional/simplified
conversion because character-level conversion “is wrong often enough to
matter”. That remains true. It ships anyway, because a documented
approximation the caller can reason about is more useful than an
absence, and because the alternative most people reach for is worse. The
limits are on the help page and in
[`vignette("transliteration")`](https://pursuitofdatascience.github.io/tidycjk/articles/transliteration.md):

- Conversion is **context-aware on characters and blind to vocabulary**.
  The one-to-many cases resolve correctly from context – `头发` gives
  `頭髮` and `发送` gives `發送`, `后天` gives `後天` while `皇后` stays
  `皇后` – which is better than a per-character table can do; fourteen
  such pairs were checked and all fourteen were right. What it does not
  do is substitute regional vocabulary: `软件` becomes `軟件`, not
  Taiwan’s `軟體`. [OpenCC](https://github.com/BYVoid/OpenCC) and its
  regional configurations are the answer there.
- Romanisation reads **all Han as Chinese**. Japanese kanji come back in
  pinyin – `日本語` gives `rì běn yǔ`, not `nihongo`. The kana in the
  same string romanise correctly, which makes the output look plausible
  and is what makes it dangerous. Use a morphological analyser such as
  [gibasa](https://CRAN.R-project.org/package=gibasa) for Japanese.

### Sentences and n-grams

- **[`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md)**
  splits text into sentences with ICU’s sentence break iterator, which
  knows U+3002, U+FF01 and U+FF1F. A regular expression on `[.!?]` finds
  no boundary at all in Chinese or Japanese, which is the reason this
  exists. The spans are returned unmodified, so the pieces concatenate
  back to the input exactly; whitespace between two sentences stays
  attached to the first rather than being trimmed away.
- **[`cjk_ngrams()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ngrams.md)**
  returns every run of `n` consecutive characters. Character n-grams are
  the standard dictionary-free baseline for Chinese retrieval and
  classification – most words are one or two characters, so bigrams
  capture the majority of them with no model, and they degrade
  gracefully on the names and coinages where a segmenter is least
  reliable. No gram is formed across whitespace.

### Ordering

- **[`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)
  and
  [`cjk_order()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)**
  sort CJK text by an ICU collation.
  [`sort()`](https://rdrr.io/r/base/sort.html) on Chinese gives code
  point order, which is a real order and the wrong one: the unified
  ideographs are laid out in KangXi radical-stroke order, so sorting by
  code point sorts by radical within the base block. It is not phonetic,
  which is what sorting a column of names calls for, and it is not even
  radical order across blocks – every Extension A character sorts ahead
  of every base-block one. `locale = "zh"` sorts Han by pinyin;
  `"zh-u-co-stroke"` by stroke count.
- Both add two guards over calling stringi directly. `NA` is kept and
  sorts last, where `stri_sort()` drops it and silently shortens a
  column. And a locale whose language ICU has no collation for is an
  error, where stringi warns and falls back to the root collation – a
  plausible-looking wrong order. An unrecognised *region* is not an
  error: `"zh-CH"` resolves to `"zh"` and still sorts by pinyin.

### Layout

- **[`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)**
  wraps text to a width in terminal columns, completing the set with
  [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
  and
  [`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md).
  Break positions come from ICU’s implementation of the Unicode line
  breaking algorithm (Annex
  [\#14](https://github.com/PursuitOfDataScience/tidycjk/issues/14)), so
  a line will not begin with `。` or `）` or split a small kana from
  what it follows – none of which splitting every *n* columns would
  respect. Lines come back joined by `\n`, so the result is the same
  length as `x`. `indent` and `exdent` are supported.

### Documentation

- **Four vignettes**, where there were none:
  [`vignette("tidycjk")`](https://pursuitofdatascience.github.io/tidycjk/articles/tidycjk.md),
  [`vignette("segmentation")`](https://pursuitofdatascience.github.io/tidycjk/articles/segmentation.md),
  [`vignette("width-and-layout")`](https://pursuitofdatascience.github.io/tidycjk/articles/width-and-layout.md)
  and
  [`vignette("transliteration")`](https://pursuitofdatascience.github.io/tidycjk/articles/transliteration.md).
- **A hex logo**, and a README rebuilt around six generated figures and
  an animated comparison rather than 210 lines of prose. The figures are
  drawn by `data-raw/make-figures.R` using the package itself – the
  terminal grids are positioned by
  [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
  – so a figure cannot drift from what the functions return.
- The pkgdown site gains a theme, a light/dark switch and a Gallery
  article.

### Fixes

- **`cjk_detect_language(han_only = )` no longer turns two malformed
  values into languages.** The check was written to stop `han_only = 1`
  coming back as the language `"1"`, and two cases slipped past it.
  `is.na(NaN)` is `TRUE`, so `NaN` was returned as the language `"NaN"`.
  Worse, `is.na(list(NA))` is `TRUE` while `as.character(list(NA))` is
  the *string* `"NA"` – not a missing value, so a downstream
  [`is.na()`](https://rdrr.io/r/base/NA.html) would have called it a
  real answer. Both are now errors. Present since 0.1.0.
- **Kana conversion is a normalisation, not a reversible mapping, and
  the documentation said otherwise.**
  [`?to_hiragana`](https://pursuitofdatascience.github.io/tidycjk/reference/to_hiragana.md)
  called it “lossless” and
  [`vignette("transliteration")`](https://pursuitofdatascience.github.io/tidycjk/articles/transliteration.md)
  said it “round-trips exactly”. Both are true only when the input is
  already in a single syllabary. On mixed text the distinction between
  the two is erased – and it carries meaning, since katakana marks
  loanwords and emphasis – so `to_katakana(to_hiragana(x))` does not
  return `x`.
- **`locale` does not change where CJK sentences break either, and
  [`?cjk_sentences`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md)
  no longer implies it does.** Same correction as for the segmentation
  engine: identical output across Chinese, Japanese, Korean and mixed
  text under `"zh"`, `"ja"`, `"ko"`, `"en"` and the session default.
- **[`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)
  no longer crashes R on a long string.** `stri_wrap()`’s default
  optimal-fit algorithm segfaults on long input – a plain
  `stri_wrap(strrep("\u4e2d\u6587", 50000), 40)` takes the session down,
  at any width, with no tidycjk involved. Strings over 10,000 characters
  now go through the greedy algorithm, which handles 200,000 characters
  in a fraction of a second. For CJK the two agree exactly: over 600
  randomly generated CJK strings they produced identical output every
  time, because nearly every position is a break opportunity. Mixed CJK
  and Latin can differ. The threshold is deliberately far below where
  the crash was seen, since it looks like stack exhaustion and the real
  limit moves with the machine.
- **The jamo round trip returns NFC, and the documentation claimed it
  returned the input.**
  [`?cjk_jamo`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
  said recomposition was “guaranteed to return the original” and the
  vignette’s table called it reversible. That holds only when the input
  is already in NFC.
  [`cjk_compose_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
  is normalisation form C, so it composes everything composable and not
  only the jamo it was handed: an `e` followed by a combining acute
  comes back as the single character U+00E9. The guarantee is now stated
  as `cjk_compose_jamo(cjk_jamo(x))` equalling `stri_trans_nfc(x)`,
  which is `x` whenever `x` was already NFC. The decomposition of Hangul
  itself is still exact.
- **A leading byte-order mark is no longer silently deleted by
  [`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md),
  [`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md),
  [`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)
  or
  [`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md).**
  0.1.0 had already fixed this for the verbs that go through code
  points; the new ones call stringi directly, and `stri_sort()`,
  `stri_split_boundaries()`, `stri_wrap()` and `stri_sub()` all read a
  leading U+FEFF as a byte-order mark and drop it. The consequences were
  worth the name:
  [`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)
  returned a vector holding *different strings* from the one it was
  given, so `x[cjk_order(x)]` and `cjk_sort(x)` disagreed;
  [`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md)
  was not lossless, which is the promise its help page rests on; and the
  [`cjk_jamo()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_jamo.md)
  round trip was not exact. All four now hide the mark from stringi and
  restore it, counting the whole leading run rather than a single mark.
- [`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)
  is now implemented as `x[cjk_order(x)]`, so it can only ever reorder
  its input – a sort cannot rewrite the values it was handed.
- **The locale guard now works on older stringi, where it used to do
  nothing.** It detected an unusable locale by watching for the
  “resource bundle lookup” warning, and stringi 1.6.2 does not emit that
  warning at all – so on an older installation the guard was silently
  inert, which is exactly the failure it exists to prevent. It now
  checks the language subtag against
  [`stringi::stri_locale_list()`](https://rdrr.io/pkg/stringi/man/stri_locale_list.html),
  which is present in every stringi tested and gives the same verdict on
  each. An unrecognised region still resolves to its language, so
  `"zh-CH"` and `"zh-u-co-stroke"` remain valid.
- **A typo in a `locale` is now an error everywhere, not just in one
  place.** ICU falls back to the root locale when it has no data for the
  one asked for, and stringi reports that as a warning most callers
  never see – so `cjk_segment(engine = "icu", locale = "jp")` quietly
  selected a different break iterator, and the output looked right.
  [`cjk_sort()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sort.md)
  guarded against this from the start;
  [`cjk_sentences()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_sentences.md)
  and the `"icu"` engine did not. All three now share one guard. An
  unrecognised *region* is still fine: `"zh-CH"` resolves to `"zh"`.
- **`cjk_ngrams(x, n = )` rejects an `n` past the integer range.** It
  used to coerce to `NA` with a bare “NAs introduced by coercion”
  warning naming no argument, then fail on the comparison a few frames
  down – the same failure `.cjk_as_width()` was written to prevent for
  `width`.
- **[`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)
  is about five times faster on a column.** It called `stri_wrap()` once
  per string; it now makes one call per *distinct* width, which for the
  usual scalar `width` is a single call. Measured at 0.23s to 0.05s over
  2,000 rows.
- **The two segmentation engines do not tokenise punctuation alike, and
  the help page now says so.** `"icu"` drops punctuation and symbols
  along with whitespace; `"character"` keeps CJK punctuation as tokens,
  because those code points are in blocks
  [`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
  lists. The same sentence therefore yields different token counts – and
  the gap is punctuation, not a disagreement about where words end. An
  emoji is dropped by one and kept by the other for the same reason.
- **[`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)
  re-flows rather than measures, and two consequences are now
  documented.** Existing newlines in the input are whitespace to the
  algorithm and are replaced by the new breaks, so `"a\nb"` wrapped wide
  comes back as `"a b"`. A string of nothing but whitespace re-flows to
  `""`, where
  [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
  would have kept it.
- Every published URL now points at `tidycjk`. The repository had been
  created as `tidyckj`, with the last two letters transposed, and the
  typo reached the `URL` and `BugReports` fields, the pkgdown site, the
  R-CMD-check badge and the
  [`pak::pak()`](https://pak.r-lib.org/reference/pak.html) install line.
  GitHub redirects the repository addresses, so the ones in the 0.1.0
  tarball still resolve; it does not redirect a project Pages site, so
  the old documentation URL 404s and this release is what corrects it on
  CRAN.

### Notes

- `RoxygenNote` replaces `Config/roxygen2/version`: `man/` is generated
  by roxygen2 7.3.2, and the file now records what actually built it.
- Still no compiled code, no bundled data, and no network requests.

### Still not in this release

- **Stroke counts, radicals and per-character readings.** These need the
  [Unihan database](https://www.unicode.org/charts/unihan.html);
  `data-raw/unihan.R` downloads and parses it, but nothing is bundled
  yet.
- **Vertical text layout.** Unicode Annex
  [\#50](https://github.com/PursuitOfDataScience/tidycjk/issues/50)
  assigns each character an orientation for vertical writing. Nothing
  here models it.
- **Encoding detection.**
  [`stringi::stri_enc_detect()`](https://rdrr.io/pkg/stringi/man/stri_enc_detect.html)
  exists and is unreliable on short CJK samples, which is exactly when
  it would be used. It is not wrapped rather than wrapped badly.

## tidycjk 0.1.0

CRAN release: 2026-09-09

First release.

`tidycjk` is a tidy toolkit for Chinese, Japanese and Korean text:
script and language classification, display width, width normalisation,
and a pluggable word-segmentation engine that the caller names, as verbs
that return tibbles. The package itself has no compiled code, bundles no
data, and makes no network requests.

### Tidy layer

- `cjk_summary(data, col)` reports `n_docs`, `n_with_cjk`,
  `prop_with_cjk` and `mean_ratio` for a text column.
- `cjk_char_counts(data, col)` returns one row per distinct CJK
  character with its code point, script, Unicode block and count.

### Segmentation

- `cjk_segment(x, engine)` splits CJK text into words, and
  `cjk_tokens(data, col, engine)` is the tidy version, returning one row
  per token.
- The engine is pluggable and **required**.
  [`cjk_segmenters()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
  lists what is available and
  [`register_cjk_segmenter()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
  adds an engine: any function of `(x, ...)` returning a list of
  character vectors.
- No word segmenter is bundled, and `engine` has no default.
  [jiebaR](https://CRAN.R-project.org/package=jiebaR) was the obvious
  candidate and was archived from CRAN on 2025-05-01, so it cannot be a
  dependency of a CRAN package.
  [`?cjk_segmenters`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segmenters.md)
  shows the four lines that register it once you have installed it from
  source.
- The one engine that ships is `"character"`: one token per CJK
  character, with runs of non-CJK text split on whitespace. It is
  character tokenisation rather than word segmentation and says so on
  its help page. Making it the silent default would have handed
  character tokens to callers asking for words, which is the mistake
  this package exists to avoid, so the choice is explicit instead.

### Vector layer

- [`has_cjk()`](https://pursuitofdatascience.github.io/tidycjk/reference/has_cjk.md),
  [`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
  and
  [`cjk_ratio()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_ratio.md)
  classify and measure.
- [`cjk_detect_language()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_detect_language.md)
  infers the language from the scripts present.
- [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md),
  [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
  and
  [`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md)
  work in terminal columns rather than characters.
- [`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
  and
  [`to_fullwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
  normalise width variants.
- [`cjk_blocks()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_blocks.md)
  exports the Unicode block table the package is built on, covering
  every unified ideograph block through Extension I as well as the
  phonetic scripts, CJK punctuation and the width variants.

### Notes on the design

- **Language detection returns `NA` rather than guessing.** Japanese
  written without kana is not distinguishable from Chinese by script
  alone, so a Han-only string gets `NA`.
  `cjk_detect_language(x, han_only = "chinese")` opts into the guess and
  keeps the assumption visible in the calling code.

- **Width is delegated to
  [stringi](https://CRAN.R-project.org/package=stringi).**
  [`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
  and
  [`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
  wrap
  [`stringi::stri_width()`](https://rdrr.io/pkg/stringi/man/stri_width.html)
  and
  [`stringi::stri_pad()`](https://rdrr.io/pkg/stringi/man/stri_pad.html),
  which read the live Unicode tables in [ICU](https://icu.unicode.org),
  the Unicode Consortium’s C library. A hand-maintained range table
  would go stale at every Unicode release, and the version commonly
  copied around is already wrong for tens of thousands of assigned code
  points: it stops below the supplementary planes, so every ideograph in
  Extensions B through I comes out one column instead of two.
  [`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md)
  has no `stringi` equivalent and is implemented here.

- **Normalisation is surgical.**
  [`to_halfwidth()`](https://pursuitofdatascience.github.io/tidycjk/reference/to_halfwidth.md)
  maps fullwidth ASCII, the ideographic space and halfwidth katakana,
  and touches nothing else. `NFKC` additionally rewrites ligatures,
  superscripts, Roman numerals, circled numbers, the no-break space and
  the CJK compatibility ideographs, which is almost never wanted.

- **Voiced marks are composed by default.** Halfwidth katakana writes a
  voiced syllable as two code points; `compose = TRUE` folds them into
  the single precomposed character, so `"ｶﾞ"` becomes `"ガ"`. Every pair
  in the composition table agrees with Unicode NFC, including the five
  that break the base-plus-one rule.

- **Ties never depend on the locale.**
  [`cjk_script()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_script.md)
  and
  [`cjk_char_counts()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_char_counts.md)
  break ties by first appearance rather than by collation order.

### Not in this release

- **Pinyin, stroke counts and radicals.** These need the [Unihan
  database](https://www.unicode.org/charts/unihan.html).
  `data-raw/unihan.R` downloads and parses it, but no character data is
  hand-written or bundled yet.
  [pinyin](https://CRAN.R-project.org/package=pinyin) and
  [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin) are on
  CRAN today.
- **Traditional/simplified conversion.** The [Unihan
  database](https://www.unicode.org/charts/unihan.html) gives
  character-level mappings only, and character-level conversion is wrong
  often enough to matter: one simplified character can map to several
  traditional ones and the right choice is context-dependent. Shipping
  it as if it were complete would be a disservice.
  [tmcn](https://CRAN.R-project.org/package=tmcn) offers character-level
  conversion today; [OpenCC](https://github.com/BYVoid/OpenCC) is the
  phrase-level answer outside R.
