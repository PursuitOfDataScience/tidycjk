# tidycjk 0.2.0

A release about the gap between what the package could do and what it said it
could do. 0.1.0 shipped with no bundled word segmenter, no romanisation and no
script conversion, on the reasoning that each needed a dictionary the package
could not carry. That was half right. The dictionaries were already
installed: ICU carries them,
[stringi](https://CRAN.R-project.org/package=stringi) carries ICU, and stringi
has been a hard dependency since the first commit. Most of what follows is
that discovery being spent.

Four vignettes are new, and there were none before.

## Word segmentation now ships

* **`engine = "icu"` is a real word segmenter.** `cjk_segment("我今天很開心",
  engine = "icu")` returns `我` / `今天` / `很` / `開心`, words rather than
  characters, using ICU's dictionary-based break iterators for Chinese and
  Japanese. It costs no new dependency.
* Anything in `...` reaches the engine, `locale` included, though see "How
  the new verbs behave" below, because `locale` does not do what its name
  suggests here.
* `engine` still has no default, for the reason it always had: `"character"`
  answers a different question from the one a caller asking for words is
  asking, and would otherwise be the answer they got by accident.
* **This reverses a claim 0.1.0 made.** That release said no word segmenter
  could be bundled because jiebaR had been archived from CRAN. The archival
  was true and still is; the error was concluding from it that there was no
  bundled option, when one had been linked into a hard dependency the whole
  time.
* **`cjk_tokens()` gains `output`**, naming the token column. The default is
  still `"token"`, and an existing column of that name is still replaced,
  but a caller whose data already has a `token` column worth keeping now has
  somewhere else to put the tokens, the escape hatch
  [tidytext](https://CRAN.R-project.org/package=tidytext)'s `unnest_tokens()`
  provides. It follows `...`, so it has to be given by its full name.
* **A segmentation engine's element types are checked**, not only the list
  and its length. `as.character()` deparses a list rather than coercing it,
  so an engine returning `list(c(1, 2))` used to yield the single token
  `"c(1, 2)"`. An atomic element is still coerced, so integers and factors
  work as before.

## Transliteration

* **`cjk_romanize()`** romanises Han, kana and Hangul to the Latin alphabet.
  `ascii = TRUE` drops tone marks, which is what you want for a sort key.
* **`cjk_simplify()` and `cjk_traditionalize()`** convert between simplified
  and traditional Han.
* **`to_hiragana()` and `to_katakana()`** convert between the kana
  syllabaries. Halfwidth input is handled and composed on the way through:
  `to_katakana("ｶﾞ")` is the single character `ガ`.
* **`cjk_jamo()` and `cjk_compose_jamo()`** decompose Hangul syllables into
  jamo and put them back, by the syllable arithmetic in the Unicode standard
  rather than by normalisation. The round trip is exact, and text that is not
  Hangul passes through untouched: an accented letter keeps its accent, and a
  compatibility ideograph, which NFD and NFC would both replace with its
  unified form, stays as it is.

### Two of these are approximations, and say so

0.1.0's "Not in this release" section withheld traditional/simplified
conversion because character-level conversion "is wrong often enough to
matter". That is true of a character table, and ICU's transform is not one.
The limits that remain are on the help pages and in
`vignette("transliteration")`:

* Conversion is **context-aware on characters and blind to vocabulary**. The
  one-to-many cases resolve from context: `头发` gives `頭髮` and `发送` gives
  `發送`, `后天` gives `後天` while `皇后` stays `皇后`, and all twenty such
  words checked for this release came out right. What it does not do is
  substitute regional vocabulary: `软件` becomes `軟件`, not Taiwan's `軟體`.
  [OpenCC](https://github.com/BYVoid/OpenCC) and its regional configurations
  are the answer there.
* Romanisation reads **each Han character alone, and as Chinese**. A
  character with two readings gets its commoner one whatever the word, so
  `银行` ("bank") comes back `yín xíng` rather than `yín háng`; and Japanese
  kanji come back in pinyin, `日本語` giving `rì běn yǔ` rather than
  `nihongo`. Use it for a sort or search key, and a morphological analyser
  such as [gibasa](https://CRAN.R-project.org/package=gibasa) for Japanese
  readings.

## Sentences and n-grams

* **`cjk_sentences()`** splits text into sentences with ICU's sentence break
  iterator, which knows U+3002, U+FF01 and U+FF1F. A regular expression on
  `[.!?]` finds no boundary at all in Chinese or Japanese, which is the
  reason this exists. The spans are returned unmodified, so the pieces
  concatenate back to the input exactly; whitespace between two sentences
  stays attached to the first rather than being trimmed away.
* **`cjk_ngrams()`** returns every run of `n` consecutive characters.
  Character n-grams are the standard dictionary-free baseline for Chinese
  retrieval and classification: most words are one or two characters, so
  bigrams capture the majority of them with no model, and they degrade
  gracefully on the names and coinages where a segmenter is least reliable.
  No gram is formed across whitespace.

## Cleaning

* **`cjk_strip_punct()` removes punctuation by Unicode category**, not by a
  POSIX class. The usual spelling is unreliable on CJK twice over.
  `gsub("[[:punct:]]", "", x)` is resolved through the C library, so it
  removes nothing under `LC_ALL=C` and everything under a UTF-8 locale: the
  same script, two answers, no warning. `perl = TRUE` looks safer and is
  worse, PCRE's POSIX classes being ASCII-only unless `(*UCP)` is set, so it
  silently removes no CJK punctuation in any locale at all.
* **It keeps U+30FC.** The katakana-hiragana prolonged sound mark looks like
  a dash and is a modifier letter, carrying the long vowel in most Japanese
  loanwords. Testing the General_Category keeps it; any rule phrased about
  dashes removes it and quietly changes the words for coffee and ramen into
  something else.
* **`replacement` defaults to a space rather than `""`.** Deleting a full
  stop closes the gap, and the characters that flanked it become adjacent, so
  `cjk_ngrams()` then reports a bigram spanning a sentence boundary, a word
  that was never written. A space keeps the boundary, and every verb here
  that walks a string already declines to cross whitespace.
* `symbols = TRUE` additionally removes General_Category `S`: the fullwidth
  tilde, currency signs and mathematical operators. It is off by default
  because a currency sign is often content.

## Ordering

* **`cjk_sort()` and `cjk_order()`** sort CJK text by an ICU collation.
  `sort()` on Chinese gives code point order, which is a real order and the
  wrong one: the unified ideographs are laid out in KangXi radical-stroke
  order, so sorting by code point sorts by radical within the base block. It
  is not phonetic, which is what sorting a column of names calls for, and it
  is not even radical order across blocks, since every Extension A character
  sorts ahead of every base-block one. `locale = "zh"` sorts Han by pinyin;
  `"zh-u-co-stroke"` by stroke count.
* Both add two guards over calling stringi directly. `NA` is kept and sorts
  last, where `stri_sort()` drops it and silently shortens a column. And a
  locale whose language ICU has no collation for is an error, where stringi
  warns and falls back to the root collation, a plausible-looking wrong
  order. An unrecognised *region* is not an error: `"zh-CH"` resolves to
  `"zh"` and still sorts by pinyin.

## Normalisation

* **`cjk_normalize()` applies the Unicode normalisation forms** (`"nfc"`,
  `"nfd"`, `"nfkc"`, `"nfkd"` and `"nfkc_casefold"`) so that strings which
  look the same compare the same. The package had been telling callers to
  "normalise first" without giving them a way to do it.
* **Plain NFC is not a no-op on Han, and the help page says so.**
  Compatibility ideographs have singleton canonical mappings, so `"nfc"`
  rewrites them exactly as `"nfkc"` does: 460 of the 472 characters in the
  CJK Compatibility Ideographs block are folded away, along with all 542 of
  the Supplement block. The 12 survivors are listed. If that distinction
  carries meaning in your data, as it can in Korean and Japanese name
  records, keep the original column, because no form preserves it.
* **`drop_variation_selectors = TRUE` removes them first.** Before, not
  after: a variation selector has combining class zero and blocks canonical
  composition across itself, so stripping one *after* normalising can leave
  text that is no longer in the form just requested. `A` U+FE00 U+0300
  normalises to itself under NFC and to U+00C0 once the selector is gone.
* **`"nfkc_casefold"` deletes every `Default_Ignorable` code point**, which
  the other four forms keep: the variation selectors, the zero-width joiner
  and non-joiner, the zero-width space, the soft hyphen, the tag characters
  and U+FEFF. So a byte-order mark survives the other four and not this one.
  It is documented rather than worked around, because it is what the form is
  defined to do; every other verb in the package preserves a leading U+FEFF.
* `to_halfwidth()` and `to_fullwidth()` are unchanged and remain the narrow
  alternative: they move text along the width axis and touch nothing else.

## Layout

* **`cjk_wrap()`** wraps text to a width in terminal columns, completing the
  set with `cjk_pad()` and `cjk_truncate()`. Break positions come from ICU's
  implementation of the Unicode line breaking algorithm (Annex #14), so a
  line never begins with `。` or `）` and an opening bracket never ends one,
  none of which splitting every *n* columns would respect. Lines are filled
  greedily and come back joined by `\n`, so the result is the same length as
  `x`. `indent` and `exdent` are supported.

## Messages and validation

* **Undecodable text is one error from every verb.** Left to stringi, the
  same bytes were reported five different ways depending on which entry
  point a verb reached first: our message from the code-point verbs, U+FFFD
  replacement characters from the ICU transforms, the raw bytes handed back
  by `cjk_sentences()` and `cjk_sort()`, a bare "invalid multibyte string"
  from `cjk_wrap()`, and the bad byte silently dropped by the `"icu"` engine.
  Every verb now stops with "`x` must be valid UTF-8" before doing any work,
  naming the argument (`col` in the tidy verbs, and `pad`, `ellipsis` and
  `replacement` for the arguments that carry text of their own). A string
  marked `"bytes"` is refused the same way.
* **An enumerated argument is rejected by name.** `match.arg()` names a
  variable the caller never wrote: a value that is not character becomes
  "'arg' must be NULL or a character vector", and a string matching no
  choice "'arg' should be one of", both with `match.arg()`'s own call
  attached. `cjk_pad(side = )` and `cjk_normalize(form = )` now say
  `` `side` must be one of "right", "left", "both" ``, listing the choices.
  Every value `match.arg()` accepted before is still accepted, including
  partial matching and `NULL` meaning the first choice.
* **A bad `locale` is an error whatever the input.** The check used to run
  inside the call to stringi, so `cjk_sort(character(0), locale = "xx")` and
  `cjk_wrap(NA, 5, locale = "xx")` passed. It now runs first. The language
  is matched without regard to case, as BCP 47 specifies, so `"ZH"` and
  `"Zh-Hant"` are accepted; `"root"` and `"und"` ask for ICU's root locale
  by name; and `""` means the session default, as it does to stringi.
* `cjk_wrap()` refuses an `indent` or `exdent` past the integer range by
  name, rather than handing stringi an `NA` it reports in its own terms.
* **`cjk_pad(width = )` no longer warns before its error** on a closure or
  an environment. The check has to call `is.na()` so that an all-`NA` logical
  width can pass and propagate, and `is.na()` on a function warns; testing
  `is.atomic()` first keeps both properties.
* **Every error the package constructs carries no call**, so a message
  reads `` Error: `n` must be a single positive whole number. `` rather than
  repeating the whole call back at the reader. A test walks the installed
  namespace to keep it that way, and checks that the three handlers which
  re-raise someone else's condition leave its call and message untouched.

## Documentation

* **`?tidycjk` is brought up to date.** Its contract section lists every
  verb rather than the 0.1.0 ones. Its "Input encoding" section gives working
  ways to read a legacy file, `read.csv(f, fileEncoding = "GBK")` and
  `readLines(file(f, encoding = "Shift_JIS"))`; the `encoding` argument of
  those functions only labels strings, and `read.csv(f, encoding = "GBK")`
  fails outright in a UTF-8 session. And its related packages are ones you
  can install: 0.1.0 pointed at pinyin, tmcn, zipangu and Nippon, all four of
  which are archived from CRAN.
* **An example comment in `?cjk_truncate` contradicted its own output.**
  "six columns is three ideographs" sat above a call returning one
  ideograph, because the ellipsis is counted against the budget and costs
  three of the six columns. It now says what the output shows, and a third
  call with `ellipsis = ""` makes the original point properly.
* **Example blocks say what their strings are.** CJK literals in examples
  are written as `\uXXXX` escapes so that no CJK glyph reaches the LaTeX
  manual, and `?cjk_ratio`, `?cjk_summary`, `?cjk_char_counts` and
  `?cjk_tokens` had no comment saying what those escapes spell.
* A hex logo, and a pkgdown site with a theme, a light/dark switch and a
  Gallery article that walks every verb over real text.

## Fixes to 0.1.0

Seven things in this release are fixes in the sense a 0.1.0 user cares
about. The rest of what changed during development concerned code that had
never shipped, and is described under the features it belongs to rather
than dressed up as a fix.

* **A list argument was measured as the R code that builds it.** Every verb
  starts by coercing `x`, which is what lets a numeric or a factor column
  through. But `as.character()` does not coerce a list, it *deparses* it, so
  `cjk_width(list(c("a", "b")))` answered **11**, the display width of the
  eleven-character string `c("a", "b")`, with no error and no warning. Every
  exported verb had this hole, and the list a caller has in hand is usually
  another verb's output. All of them now raise, naming the two ways out, and
  the three tidy verbs check a pulled list-column the same way. `NULL` is
  still accepted, and still gives `character(0)`: `is.atomic(NULL)` was
  `TRUE` until R 4.4.0 and is `FALSE` after it, so the guard admits it
  explicitly rather than inheriting a contract that changed under it.
* **Korean and Chinese text containing the katakana middle dot was called
  Japanese.** `cjk_detect_language()` takes any kana as proof of Japanese,
  and U+30FB sits in the Katakana block, but it is punctuation that Chinese
  and Korean text use too, to separate the parts of a transliterated name.
  So `"서울・부산"` ("Seoul / Busan") came back `"japanese"`. The dot, and its
  halfwidth form U+FF65, no longer count as kana.
* **Real letters of the covered scripts were not CJK.** `?cjk_blocks` said
  every phonetic script was covered in full, extension blocks included, and
  four kana blocks were missing: Kana Supplement, Kana Extended-A, Kana
  Extended-B and Small Kana Extension, which hold the hentaigana, the archaic
  and small kana and the Minnan tone letters. Extension J, the 4,298
  ideographs Unicode 17.0 added, was missing too. `has_cjk()` answered
  `FALSE` for all of them. The table is now current to Unicode 18.0, and
  the kana blocks are split where Unicode's Script property changes, so each
  letter is labelled hiragana or katakana as it should be.
* **`cjk_detect_language(han_only = )` no longer turns two malformed values
  into languages.** `is.na(NaN)` is `TRUE`, so `NaN` was returned as the
  language `"NaN"`; and `is.na(list(NA))` is `TRUE` while
  `as.character(list(NA))` is the *string* `"NA"`, not a missing value, so a
  downstream `is.na()` would have called it a real answer. Both are now
  errors.
* **`cjk_segment()` and `cjk_tokens()` no longer delete a byte-order
  mark.** `stri_split_charclass()` reads a leading U+FEFF in its own input
  as a byte-order mark and drops it, and `omit_empty = TRUE` then discards
  the emptied piece, so a mark beginning a non-CJK run disappeared from the
  `"character"` engine's output. U+FEFF was the only zero-width character
  this happened to. Both engines now count the leading run off and restore
  it, as the other verbs already did.
* **An unknown engine is an error even for empty input.** The engine was
  looked up after the zero-length exit, so `cjk_segment(character(0),
  engine = "nope")` and a zero-row `cjk_tokens()` returned quietly. An engine
  you register yourself is still not called on an empty vector.
* **Every published URL now points at `tidycjk`.** The repository had been
  created as `tidyckj`, with the last two letters transposed, and the typo
  reached the `URL` and `BugReports` fields, the pkgdown site, the
  R-CMD-check badge and the `pak::pak()` install line. GitHub redirects the
  repository addresses, so the ones in the 0.1.0 tarball still resolve; it
  does not redirect a project Pages site, so the old documentation URL 404s
  and this release is what corrects it on CRAN.

## How the new verbs behave

Not fixes, since these verbs are new, but the details most likely to
surprise you, gathered in one place.

* **A leading byte-order mark survives.** `stri_sort()`,
  `stri_split_boundaries()` and `stri_wrap()` all read a leading U+FEFF as a
  byte-order mark and drop it. `cjk_sort()`, `cjk_sentences()` and
  `cjk_wrap()` hide the whole leading run from stringi and restore it, and
  the jamo verbs work on code points, so a mark from an Excel-written CSV is
  not silently deleted. A U+FEFF *elsewhere* in a string may still be lost to
  `cjk_wrap()`, because re-flowing can put it at the start of a segment;
  `?cjk_wrap` says so.
* **`cjk_sort()` is `x[cjk_order(x)]`,** so it can only reorder its input.
  A sort must not rewrite the values it was handed, and building it on
  `stri_sort()`, which returns round-tripped values, would let it.
* **`cjk_wrap()` fills lines greedily, as a terminal does.** stringi's own
  default is an optimal fit that evens out line lengths, and it is not used:
  its cost grows far faster than the text (40,000 characters of CJK exhaust
  1.5 GB of memory), and appending text can re-flow every line above it,
  which it did in 424 of 2,000 random trials where the greedy fill never
  does.
* **`cjk_wrap()` re-flows rather than measures.** Existing newlines are
  whitespace to the algorithm and are replaced by the new breaks, so
  `"a\nb"` wrapped wide comes back as `"a b"`. A string of nothing but
  whitespace re-flows to `""`, where `cjk_pad()` would have kept it.
* **`cjk_wrap()` returns NFC, which no other layout verb does.** ICU's
  line-breaking works on normalised text, so `stri_wrap()` normalises and
  this verb inherits it: `cjk_wrap("豈", 2)` is U+8C48. A sweep of every
  code point in Unicode puts the affected set at 1,120: 460 of the 472
  assigned CJK Compatibility Ideographs, all 542 of the supplement, 34
  Hebrew presentation forms, 13 musical symbols, and 71 scattered
  singletons and composition exclusions such as the Kelvin and Ohm signs,
  Greek letters with an oxia and Devanagari letters with a nukta. That is
  exactly the set NFC changes, no more and no fewer: each is a duplicate of
  a character or sequence Unicode prefers, kept for compatibility. Everyday
  text, precomposed Latin and Hangul syllables included, is already NFC and
  passes through untouched. `normalize = FALSE` would stop it, but that
  argument also turns off whitespace collapsing and makes `stri_wrap()`
  raise on any string containing a newline, so it is documented and pinned
  by a test rather than changed. Call `cjk_normalize()` first if you want the
  normalisation to be explicit.
* **Kana conversion is a normalisation, not a reversible mapping.** On text
  holding both syllabaries it erases the distinction between them, and that
  distinction carries meaning: katakana marks loanwords and emphasis. ICU
  also maps the small katakana U+30F5 and U+30F6 to full-size hiragana and
  spells out the digraphs U+30FF and U+309F, so even all-katakana text does
  not always survive `to_katakana(to_hiragana(x))`.
* **The two segmentation engines do not tokenise punctuation alike.**
  `"icu"` drops punctuation and symbols along with whitespace;
  `"character"` keeps CJK punctuation as tokens, because those code points
  are in blocks `cjk_blocks()` lists. The same sentence therefore yields
  different token counts, and the gap is punctuation rather than a
  disagreement about where words end. An emoji goes the same way.
* **A locale ICU has no data for is an error, not a silent fallback.** ICU
  resolves an unknown locale to the root one, and stringi reports that with
  a warning most callers never see, or, on stringi 1.6.2, with no warning
  at all. Every verb taking a `locale`, and the `"icu"` engine, shares one
  guard, which checks the language subtag against
  `stringi::stri_locale_list()` rather than watching for a warning that is
  not dependable. An unrecognised *region* still resolves to its language,
  so `"zh-CH"` and `"zh-u-co-stroke"` are valid.
* **`locale` does not change CJK word or sentence boundaries.** It is
  accepted and forwarded, but the CJK dictionary is chosen by the script of
  the text: seven Chinese, Japanese and Korean strings segment and split
  identically under `"zh"`, `"ja"`, `"ko"`, `"en"` and the session default.
  It *does* select the Annex #14 line-breaking style in `cjk_wrap()`, which
  is why that verb takes one.

## Notes

* **The tests assert laws over the code point space, not only examples.**
  `test-invariants.R` checks, over every code point in the block table, that
  each normal form is a fixed point of itself, that `nfc(nfd(x))` is
  `nfc(x)` and likewise for NFKC, that the width and kana conversions are
  idempotent, that fullwidth text survives a trip to halfwidth and back,
  that the jamo round trip is the identity, that the layout verbs leave text
  that already fits alone, and that every transform returns one valid UTF-8
  string per input. All 11,172 Hangul syllables decompose into 2 or 3 of 67
  conjoining jamo and recompose exactly. The exhaustive pass is
  `skip_on_cran()`; a sampled pass and every block boundary run everywhere.
* A sweep of all 1,112,029 valid code points confirms that `has_cjk()`,
  `cjk_ratio()` and `cjk_script()` agree with the block table in both
  directions, no character wrongly called CJK and none wrongly left out, and
  that `cjk_width()` is never missing and never outside 0:2.
* `RoxygenNote` replaces `Config/roxygen2/version`: `man/` is generated by
  roxygen2 7.3.2, and the file now records what actually built it.
* Still no compiled code, no bundled data, and no network requests.

## Still not in this release

* **Stroke counts, radicals, and readings other than ICU's Mandarin.**
  These need the [Unihan database](https://www.unicode.org/charts/unihan.html);
  `data-raw/unihan.R` downloads and parses it, but nothing is bundled yet.
* **Vertical text layout.** Unicode Annex #50 assigns each character an
  orientation for vertical writing. Nothing here models it.
* **Encoding detection.** `stringi::stri_enc_detect()` exists and is
  unreliable on short CJK samples, which is exactly when it would be used. It
  is not wrapped rather than wrapped badly.
* **`cjk_compose_jamo()` taking the list `cjk_jamo()` returns.** It would
  make the round trip compose directly instead of needing the `vapply()`
  step, and the case for it is real: that boilerplate sits in the middle of
  this package's own worked example. Declined because it would reopen, for
  one function, exactly the hole closed everywhere else this release:
  `cjk_sentences()` and `cjk_segment()` also return lists, and
  `cjk_compose_jamo(cjk_sentences(x))` would then quietly paste sentences
  together instead of saying no. One function that guesses is worse than
  one line of boilerplate, and the error now names the line to write.

# tidycjk 0.1.0

First release.

`tidycjk` is a tidy toolkit for Chinese, Japanese and Korean text: script and
language classification, display width, width normalisation, and a pluggable
word-segmentation engine that the caller names, as verbs that return tibbles.
The package itself has no compiled code, bundles no data, and makes no network
requests.

## Tidy layer

* `cjk_summary(data, col)` reports `n_docs`, `n_with_cjk`, `prop_with_cjk` and
  `mean_ratio` for a text column.
* `cjk_char_counts(data, col)` returns one row per distinct CJK character with
  its code point, script, Unicode block and count.

## Segmentation

* `cjk_segment(x, engine)` splits CJK text into words, and
  `cjk_tokens(data, col, engine)` is the tidy version, returning one row per
  token.
* The engine is pluggable and **required**. `cjk_segmenters()` lists what is
  available and `register_cjk_segmenter()` adds an engine: any function of
  `(x, ...)` returning a list of character vectors.
* No word segmenter is bundled, and `engine` has no default.
  [jiebaR](https://CRAN.R-project.org/package=jiebaR) was the obvious
  candidate and was archived from CRAN on 2025-05-01, so it cannot be a
  dependency of a CRAN package. `?cjk_segmenters` shows the four lines that
  register it once you have installed it from source.
* The one engine that ships is `"character"`: one token per CJK character,
  with runs of non-CJK text split on whitespace. It is character tokenisation
  rather than word segmentation and says so on its help page. Making it the
  silent default would have handed character tokens to callers asking for
  words, which is the mistake this package exists to avoid, so the choice is
  explicit instead.

## Vector layer

* `has_cjk()`, `cjk_script()` and `cjk_ratio()` classify and measure.
* `cjk_detect_language()` infers the language from the scripts present.
* `cjk_width()`, `cjk_pad()` and `cjk_truncate()` work in terminal columns
  rather than characters.
* `to_halfwidth()` and `to_fullwidth()` normalise width variants.
* `cjk_blocks()` exports the Unicode block table the package is built on,
  covering every unified ideograph block through Extension I as well as the
  phonetic scripts, CJK punctuation and the width variants.

## Notes on the design

* **Language detection returns `NA` rather than guessing.** Japanese written
  without kana is not distinguishable from Chinese by script alone, so a
  Han-only string gets `NA`. `cjk_detect_language(x, han_only = "chinese")`
  opts into the guess and keeps the assumption visible in the calling code.

* **Width is delegated to [stringi](https://CRAN.R-project.org/package=stringi).**
  `cjk_width()` and `cjk_pad()` wrap `stringi::stri_width()` and
  `stringi::stri_pad()`, which read the live Unicode tables in
  [ICU](https://icu.unicode.org), the Unicode Consortium's C library. A
  hand-maintained range table would go stale at every Unicode release, and the
  version commonly copied around is already wrong for tens of thousands of
  assigned code points: it stops below the supplementary planes, so every
  ideograph in Extensions B through I comes out one column instead of two.
  `cjk_truncate()` has no `stringi` equivalent and is implemented here.

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

* **Pinyin, stroke counts and radicals.** These need the
  [Unihan database](https://www.unicode.org/charts/unihan.html).
  `data-raw/unihan.R` downloads and parses it, but no character data is
  hand-written or bundled yet.
  [pinyin](https://CRAN.R-project.org/package=pinyin) and
  [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin) are on CRAN
  today.
* **Traditional/simplified conversion.** The
  [Unihan database](https://www.unicode.org/charts/unihan.html) gives
  character-level mappings
  only, and character-level conversion is wrong often enough to matter: one
  simplified character can map to several traditional ones and the right choice
  is context-dependent. Shipping it as if it were complete would be a
  disservice. [tmcn](https://CRAN.R-project.org/package=tmcn) offers
  character-level conversion today; [OpenCC](https://github.com/BYVoid/OpenCC)
  is the phrase-level answer outside R.
