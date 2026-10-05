# tidycjk 0.2.0

A release about the gap between what the package could do and what it said it
could do. 0.1.0 shipped with no bundled word segmenter, no romanisation and no
script conversion, on the reasoning that each needed a dictionary the package
could not carry. That was half right. The dictionaries were already installed
-- ICU carries them and
[stringi](https://CRAN.R-project.org/package=stringi) carries ICU, and stringi
has been a hard dependency since the first commit. Most of what follows is
that discovery being spent.

Four vignettes are new, and there were none before.

## Word segmentation now ships

* **`engine = "icu"` is a real word segmenter.** `cjk_segment("我今天很開心",
  engine = "icu")` returns `我` / `今天` / `很` / `開心` -- words, not
  characters -- using ICU's dictionary-based break iterators for Chinese and
  Japanese. It costs no new dependency.
* Anything in `...` reaches the engine, `locale` included -- though see
  "How the new verbs behave" below, because `locale` does not do what its
  name suggests here.
* `engine` still has no default, for the reason it always had: `"character"`
  answers a different question from the one a caller asking for words is
  asking, and would otherwise be the answer they got by accident.
* **This reverses a claim 0.1.0 made.** That release said no word segmenter
  could be bundled because jiebaR had been archived from CRAN. The archival
  was true and still is; the error was concluding from it that there was no
  bundled option, when one had been linked into a hard dependency the whole
  time.

* **`cjk_tokens()` gains `output`**, naming the token column. The default
  is still `"token"` and an existing column of that name is still
  replaced, as the help page has always said -- but a caller whose data
  already has a `token` column worth keeping now has somewhere else to put
  the tokens, which is the escape hatch
  [tidytext](https://CRAN.R-project.org/package=tidytext)'s
  `unnest_tokens()` provides and this did not. It follows `...` and so has
  to be given by its full name; an abbreviation is an engine argument, not
  this one.

* **A segmentation engine's element types are checked**, not only the list
  and its length. `as.character()` deparses a list rather than coercing it,
  so an engine returning `list(c(1, 2))` used to yield the single token
  `"c(1, 2)"` -- R code spelled out as data. That is the same failure the
  data frame check already caught at the outer level, one level down. An
  atomic element is still coerced, so integers and factors work as before.

## Transliteration

* **`cjk_romanize()`** romanises Han, kana and Hangul to the Latin alphabet.
  `ascii = TRUE` drops tone marks, which is what you want for a sort key.
* **`cjk_simplify()` and `cjk_traditionalize()`** convert between simplified
  and traditional Han.
* **`to_hiragana()` and `to_katakana()`** convert between the kana
  syllabaries. Halfwidth input is handled and composed on the way through:
  `to_katakana("ｶﾞ")` is the single character `ガ`.
* **`cjk_jamo()` and `cjk_compose_jamo()`** decompose Hangul syllables into
  jamo and put them back. The mapping is arithmetic in the standard, so the
  round trip is exact.

### Two of these are approximations, and say so

0.1.0's "Not in this release" section withheld traditional/simplified
conversion because character-level conversion "is wrong often enough to
matter". That remains true. It ships anyway, because a documented
approximation the caller can reason about is more useful than an absence, and
because the alternative most people reach for is worse. The limits are on the
help page and in `vignette("transliteration")`:

* Conversion is **context-aware on characters and blind to vocabulary**. The
  one-to-many cases resolve correctly from context -- `头发` gives `頭髮` and
  `发送` gives `發送`, `后天` gives `後天` while `皇后` stays `皇后` -- which
  is better than a per-character table can do; fourteen such pairs were
  checked and all fourteen were right. What it does not do is substitute
  regional vocabulary: `软件` becomes `軟件`, not Taiwan's `軟體`.
  [OpenCC](https://github.com/BYVoid/OpenCC) and its regional configurations
  are the answer there.
* Romanisation reads **all Han as Chinese**. Japanese kanji come back in
  pinyin -- `日本語` gives `rì běn yǔ`, not `nihongo`. The kana in the same
  string romanise correctly, which makes the output look plausible and is
  what makes it dangerous. Use a morphological analyser such as
  [gibasa](https://CRAN.R-project.org/package=gibasa) for Japanese.

## Sentences and n-grams

* **`cjk_sentences()`** splits text into sentences with ICU's sentence break
  iterator, which knows U+3002, U+FF01 and U+FF1F. A regular expression on
  `[.!?]` finds no boundary at all in Chinese or Japanese, which is the
  reason this exists. The spans are returned unmodified, so the pieces
  concatenate back to the input exactly; whitespace between two sentences
  stays attached to the first rather than being trimmed away.
* **`cjk_ngrams()`** returns every run of `n` consecutive characters.
  Character n-grams are the standard dictionary-free baseline for Chinese
  retrieval and classification -- most words are one or two characters, so
  bigrams capture the majority of them with no model, and they degrade
  gracefully on the names and coinages where a segmenter is least reliable.
  No gram is formed across whitespace.

* **`cjk_ngrams()` is about four times faster.** The inner loop built each
  gram with its own `paste()` call; it now pastes `n` shifted slices of the
  character vector column-wise, so the work is `n` vectorised calls per
  document rather than one closure call per gram. Output is byte-identical,
  which the differential test against a brute-force reference checks over
  300 random strings.

## Cleaning

* **`cjk_strip_punct()` removes punctuation by Unicode category**, not by a
  POSIX class. The usual spelling is unreliable on CJK twice over:
  `gsub("[[:punct:]]", "", x)` is resolved through the C library, so it
  removes nothing under `LC_ALL=C` and everything under a UTF-8 locale --
  the same script, two answers, no warning -- while `perl = TRUE` looks
  safer and is worse, PCRE's POSIX classes being ASCII-only unless `(*UCP)`
  is set, so it silently removes no CJK punctuation in any locale at all.
* **It keeps U+30FC.** The katakana-hiragana prolonged sound mark looks like
  a dash and is a modifier letter, carrying the long vowel in most Japanese
  loanwords. Testing the General_Category keeps it; any rule phrased about
  dashes removes it and quietly changes the words for coffee and ramen into
  something else.
* **`replacement` defaults to a space rather than `""`.** Deleting a full
  stop closes the gap, and the characters that flanked it become adjacent --
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
  is not even radical order across blocks -- every Extension A character
  sorts ahead of every base-block one. `locale = "zh"` sorts Han by pinyin;
  `"zh-u-co-stroke"` by stroke count.
* Both add two guards over calling stringi directly. `NA` is kept and sorts
  last, where `stri_sort()` drops it and silently shortens a column. And a
  locale whose language ICU has no collation for is an error, where stringi
  warns and falls back to the root collation -- a plausible-looking wrong
  order. An unrecognised *region* is not an error: `"zh-CH"` resolves to
  `"zh"` and still sorts by pinyin.

## Normalisation

* **`cjk_normalize()` applies the Unicode normalisation forms** -- `"nfc"`,
  `"nfd"`, `"nfkc"`, `"nfkd"` and `"nfkc_casefold"` -- so that strings which
  look the same compare the same. The package had been telling callers to
  "normalise first" without giving them a way to do it.
* **Plain NFC is not a no-op on Han, and the help page says so.** Compatibility
  ideographs have singleton canonical mappings, so `"nfc"` rewrites them
  exactly as `"nfkc"` does: 460 of the 472 characters in the CJK Compatibility
  Ideographs block are folded away, along with all 542 of the Supplement
  block. The 12 survivors are listed. If that distinction carries meaning in
  your data -- it can in Korean and Japanese name records -- keep the original
  column, because no form preserves it.
* **`drop_variation_selectors = TRUE` removes them first.** Before,
  not after: a variation selector has combining class zero and blocks
  canonical composition across itself, so stripping one *after* normalising
  can leave text that is no longer in the form just requested. `A` U+FE00
  U+0300 normalises to itself under NFC and to U+00C0 once the selector is
  gone.
* **`"nfkc_casefold"` deletes every `Default_Ignorable` code point**, which
  the other four forms keep: the variation selectors, the zero-width joiner
  and non-joiner, the zero-width space, the soft hyphen, the tag characters
  and U+FEFF. So a byte-order mark survives the other four and not this one.
  Documented rather than worked around -- it is what the form is defined to
  do, and every other verb in the package preserves a leading U+FEFF.
* `to_halfwidth()` and `to_fullwidth()` are unchanged and remain the narrow
  alternative: they move text along the width axis and touch nothing else.

## Layout

* **`cjk_wrap()`** wraps text to a width in terminal columns, completing the
  set with `cjk_pad()` and `cjk_truncate()`. Break positions come from ICU's
  implementation of the Unicode line breaking algorithm (Annex #14), so a
  line will not begin with `。` or `）` or split a small kana from what it
  follows -- none of which splitting every *n* columns would respect. Lines
  come back joined by `\n`, so the result is the same length as `x`.
  `indent` and `exdent` are supported.

## Messages and validation

* **An enumerated argument is now rejected by name.** `match.arg()` reports
  a value that is not character at all as `'arg' must be NULL or a
  character vector`, which names a variable the caller never wrote and
  never mentions the one they did. `cjk_pad(side = )` and
  `cjk_normalize(form = )` were the only two arguments in the package that
  could produce it; both now say `` `side` must be one of "right", "left",
  "both" `` and list the choices. Every value `match.arg()` accepted before
  is still accepted, including partial matching and `NULL` meaning the
  first choice.
* **`cjk_pad(width = )` no longer warns before erroring** on a closure or
  an environment. The check has to call `is.na()` so that an all-`NA`
  logical width can pass and propagate, and `is.na()` on a function warns;
  testing `is.atomic()` first keeps both properties.
* **Every error the package constructs is now tested to carry no call.** All
  36 message-constructing `stop()` calls pass `call. = FALSE`, so a message
  reads `Error: \`n\` must be a single positive whole number.` rather than
  repeating the whole `cjk_ngrams(x, n = "2")` back at the reader. That was a
  convention held up by nothing: `expect_error()` matches on the message,
  which `call.` does not change, so any one of the 36 could have been dropped
  without a single test noticing. A mutation sweep found four of them
  silently mutable, and the suite now asserts `conditionCall()` is `NULL`
  across 27 error paths -- and, for the three `stop()` calls that
  re-raise someone else's condition rather than construct a message, that
  the original call and message come through untouched. No message text
  changed.

## Documentation

* **The `Description` field had gone stale, and self-contradictory.** It
  described the package as normalising width forms "without the collateral
  damage of a full `NFKC` pass" -- which stopped being the whole story the
  moment `cjk_normalize()` was added, since a full NFKC fold is now exactly
  one of the things on offer. It also listed the preprocessing verbs
  without `cjk_strip_punct()`. Both are corrected; this is the text CRAN
  and every package index shows, so it should describe what the release
  actually contains.
* **An example comment in `?cjk_truncate` contradicted its own output.**
  "six columns is three ideographs" sat above a call returning `"\u4e2d..."`
  -- one ideograph, because the ellipsis is counted against the budget and
  costs three of the six columns. The arithmetic was right and read as a
  prediction of the output, which is the worst way for a comment to be
  right. It now says what the output shows, and a third call with
  `ellipsis = ""` demonstrates the original point properly.
* **`?cjk_romanize`'s timings were re-measured and two were wrong.** The
  passage quoted about thirty thousand characters a second as the general
  rate, which is in fact the *degraded* rate for one very long string; a
  column of short documents runs at nearer sixty thousand. And 200,000
  characters in one string take about five seconds rather than the eight
  stated. The ratios were all correct and are the durable part: a million
  characters still takes over two minutes, `cjk_segment(engine = "icu")`
  still gets through the same million in under half a second (about 320
  times cheaper), splitting a corpus into one row per document is still
  worth about a factor of two, and a bare
  `stringi::stri_trans_general()` still takes the same time to within one
  per cent. The section now says outright that the absolute figures are
  from one machine and that nothing in the test suite asserts them, because
  a timing assertion on a build machine fails for reasons unrelated to this
  package.
* **`?cjk_wrap` described its return length wrongly.** It said "the same
  length as `x`"; like `cjk_pad()` and `cjk_truncate()` it returns the
  length of the recycled inputs, so a `width` longer than `x` recycles `x`
  up to it.
* **`?tidycjk` gains an "Input encoding" section.** Text has to arrive as
  UTF-8 or with its encoding declared, and the release now says plainly
  what happens when it does not -- because it is not uniform and cannot be
  made so. Whether bytes are undecodable at all depends on the session's
  native encoding: undeclared GBK is an error in a UTF-8 locale and
  ordinary text in a GB18030 one, and both answers are correct. When the
  bytes genuinely cannot be read, the code-point verbs raise "`x` must be
  valid UTF-8" and name the legacy encodings, while the ICU-transform verbs
  return U+FFFD replacement characters, because that is what an ICU
  transform does with a byte it cannot decode. The advice is therefore to
  declare the encoding on the way in rather than rely on an error: a
  `\uFFFD` in the output means it was not declared.
* **`?cjk_segmenters` now states how the two engines divide zero-width
  characters**, which is in three groups rather than two and was previously
  left to be discovered. `"character"` keeps them all. `"icu"` drops U+200B
  in every position, because ICU calls the zero-width space "none"
  wherever it sits and the engine asks for "none" to be skipped, and drops
  U+200D, U+00AD, U+2060, a combining mark and a variation selector only
  when one begins the string. U+FEFF survives both, and the distinction
  matters: for that one the character is removed by stringi before ICU is
  called, so it is data loss rather than policy, which is why it is the
  only one the engines put back.

* **Four vignettes**, where there were none: `vignette("tidycjk")`,
  `vignette("segmentation")`, `vignette("width-and-layout")` and
  `vignette("transliteration")`.
* **Seven help pages omitted a coercion caveat that applies to them.**
  `?has_cjk` warns that a non-character `x` is coerced by R, so a numeric
  vector "is measured as R chooses to write it -- which moves with
  `options(scipen)` and `options(OutDec)`". Measuring it confirms the
  warning is true and that it applies to every verb taking `x`, including
  the eleven on seven pages that declared `x` as a bare "A character
  vector." and so said nothing about it: all eleven shift under
  `scipen = -100` or `OutDec = ","`. Those pages now inherit the shared
  parameter documentation, as the other twelve already did. On character input -- what the package is actually for --
  nothing is sensitive to any option tested, and `options(warn = 2)`
  produces no output difference either, so the verbs emit no warnings in
  ordinary use.
* **The figure pipeline was verified to reproduce, and two of its scripts
  could not be run as written.** `data-raw/` is in `.Rbuildignore`, so
  `R CMD check` never touches it, yet the gallery claims a figure "cannot
  drift from what the functions actually return". Re-running the generators
  against the current sources reproduces all eight artifacts
  byte-for-byte -- the six panels, the logo and the animated hero -- so the
  claim holds. But `data-raw/make-hero.R` requires a `HERO_OUT` environment
  variable that nothing documented: unset, `file.path("", ...)` resolves to
  the filesystem root and the device fails with a bare cairo "error while
  writing to output stream". Its companion `merge-hero.py` takes the same
  directory as a positional argument instead, which nothing documented
  either. Both now carry the two-line recipe, checked verbatim.
* **Four example blocks showed nothing but hex.** CJK literals in examples
  are written as `\uXXXX` escapes so that no CJK glyph reaches the LaTeX
  manual, and the rendered output beneath each call shows the real
  characters -- but `?cjk_ratio`, `?cjk_summary`, `?cjk_char_counts` and
  `?cjk_tokens` had no comment anywhere in their example block, so a reader
  of the website saw only code points and had to decode them to see what
  was being demonstrated. Each now says what its strings are, which is the
  convention the other twenty blocks already followed.
* **The same contradiction was in the transliteration vignette.** "Width
  forms are a separate concern" said an `NFKC` pass rewrites ligatures,
  Roman numerals and circled numbers, "none of which you asked for" -- and
  the section immediately after it introduces `cjk_normalize()` and calls
  `"nfkc"` the right tool for matching. The absolute phrasing is now scoped
  to the task it belongs to, a change of width, and points forward to the
  section that offers the wider fold deliberately. That makes four places
  where the same appended-text contradiction had to be unpicked: the
  `Description` field, `R/normalize.R`, the README and here.
* **The README's normalisation section had gone self-contradictory**, in
  the same way the `Description` field had: it opened by framing `NFKC` as
  the thing to avoid and then, three lines later, offered it. The two tools
  are now introduced together as one deliberate choice -- surgical or blunt
  -- under a heading that names both. Punctuation stripping and sorting also
  had no headings of their own, so a reader scanning the README found
  neither; both now do, and `cjk_blocks()` has joined the table that
  enumerates the API.
* **A hex logo**, and a README rebuilt around six generated figures and an
  animated comparison rather than 210 lines of prose. The figures are drawn by
  `data-raw/make-figures.R` using the package itself -- the terminal grids are
  positioned by `cjk_width()` -- so a figure cannot drift from what the
  functions return.
* The pkgdown site gains a theme, a light/dark switch and a Gallery article.

## Fixes to 0.1.0

Four things in this release are fixes in the sense a 0.1.0 user cares
about. The rest of what changed during development concerned code that had
never shipped, and is described under the features it belongs to rather
than dressed up as a fix.

* **A list argument was measured as the R code that builds it.** Every verb
  starts by coercing `x`, which is what lets a numeric or a factor column
  through and is deliberate. But `as.character()` does not coerce a list, it
  *deparses* it -- so `cjk_width(list(c("a", "b")))` answered **11**, the
  display width of the eleven-character string `c("a", "b")`, with no error and
  no warning. Every exported verb had this hole, and the list a caller has
  in hand is usually another verb's output: `cjk_jamo()`,
  `cjk_sentences()` and `cjk_segment()` all return one, and
  `cjk_compose_jamo(cjk_jamo(x))` -- the round trip this package's own help
  page described -- hit it squarely, handing back `c("\u1112", "\u1161",
  "\u11ab")` as a literal string. All of them now raise, naming the two ways
  out, and the three tidy verbs check a pulled list-column the same way.
  This is the check `cjk_segment()` already applied to what a *segmentation
  engine* returns, finally applied to what a *caller* passes in -- the
  likelier direction of the two. `NULL` is still accepted, and still gives
  `character(0)`: `is.atomic(NULL)` was `TRUE` until R 4.4.0 and is `FALSE`
  after it, so the guard admits it explicitly rather than inheriting a
  contract that changed under it.
* **`cjk_detect_language(han_only = )` no longer turns two malformed values
  into languages.** The check was written to stop `han_only = 1` coming back
  as the language `"1"`, and two cases slipped past it. `is.na(NaN)` is
  `TRUE`, so `NaN` was returned as the language `"NaN"`. Worse,
  `is.na(list(NA))` is `TRUE` while `as.character(list(NA))` is the *string*
  `"NA"` -- not a missing value, so a downstream `is.na()` would have called
  it a real answer. Both are now errors.
* **`cjk_segment()` and `cjk_tokens()` no longer delete a byte-order
  mark.** `stri_split_charclass()` reads a leading U+FEFF in its own input
  as a byte-order mark and drops it, and `omit_empty = TRUE` then discards
  the emptied piece -- so a mark beginning a non-CJK run disappeared from
  the `"character"` engine's output. `stri_split_boundaries()` drops a
  leading one, so the `"icu"` engine lost it at the start of a string while
  keeping one in the middle. This was not a policy about format
  characters: U+200B, U+200D, U+00AD and U+2060 are all zero-width and
  non-whitespace, and all four were already returned as tokens of their
  own. U+FEFF alone vanished, which made the engine disagree with its own
  documented rule. Both engines now count the leading run off and restore
  it, as five other verbs already did. Over a 611-string corpus this
  changes 15 results and adds 12 rows to `cjk_tokens()`; every one of them
  is a mark 0.1.0 had silently removed.
* **Every published URL now points at `tidycjk`.** The repository had been
  created as `tidyckj`, with the last two letters transposed, and the typo
  reached the `URL` and `BugReports` fields, the pkgdown site, the
  R-CMD-check badge and the `pak::pak()` install line. GitHub redirects the
  repository addresses, so the ones in the 0.1.0 tarball still resolve; it
  does not redirect a project Pages site, so the old documentation URL 404s
  and this release is what corrects it on CRAN.

## How the new verbs behave

Not fixes -- these verbs are new -- but the details most likely to surprise
you, gathered in one place.

* **A leading byte-order mark survives.** `stri_sort()`,
  `stri_split_boundaries()`, `stri_wrap()` and `stri_sub()` all read a
  leading U+FEFF as a byte-order mark and drop it, which 0.1.0 had already
  worked around for the verbs that go through code points. `cjk_sort()`,
  `cjk_sentences()`, `cjk_wrap()` and `cjk_jamo()` hide the whole leading
  run from stringi and restore it, so a mark from an Excel-written CSV is
  not silently deleted. A U+FEFF *elsewhere* in a string may still be lost
  to `cjk_wrap()`, because re-flowing can put it at the start of a segment;
  `?cjk_wrap` says so.
* **`cjk_sort()` is `x[cjk_order(x)]`,** so it can only reorder its input.
  A sort must not rewrite the values it was handed, and building it on
  `stri_sort()` -- which returns round-tripped values -- would let it.
* **`cjk_wrap()` switches to a greedy fit above 10,000 characters.**
  `stri_wrap()`'s default optimal fit segfaults on long input: a plain
  `stri_wrap(strrep("\u4e2d\u6587", 50000), 40)` takes R down, at any
  width, with no tidycjk involved. Greedy handles 200,000 characters in a
  fraction of a second, and for CJK the two agree exactly -- over 600
  generated CJK strings they produced identical output every time, because
  nearly every position is a break opportunity. Mixed CJK and Latin can
  differ.
* **`cjk_wrap()` re-flows rather than measures.** Existing newlines are
  whitespace to the algorithm and are replaced by the new breaks, so
  `"a\nb"` wrapped wide comes back as `"a b"`. A string of nothing but
  whitespace re-flows to `""`, where `cjk_pad()` would have kept it.
* **`cjk_wrap()` returns NFC, which no other layout verb does.** ICU's
  line-breaking works on normalised text, so `stri_wrap()` normalises and
  this verb inherits it: `cjk_wrap("\uf900", 2)` is U+8C48. A sweep of every
  code point in Unicode puts the affected set at 1,120: 460 of the 472
  assigned CJK Compatibility Ideographs, all 542 of the supplement, 34
  Hebrew presentation forms, 13 musical symbols, and 71 scattered
  singletons and composition exclusions such as the Kelvin and Ohm signs,
  Greek letters with an oxia and Devanagari letters with a nukta. That is
  exactly the set NFC changes, no more and no fewer: each is a duplicate of
  a character or sequence Unicode prefers, kept for compatibility. Everyday
  text, precomposed Latin and Hangul syllables included, is already NFC and
  passes through untouched. `cjk_pad()`, `cjk_truncate()` and
  `cjk_segment()` do not normalise. It is documented and pinned by a test
  over the whole block table rather than changed: `normalize = FALSE` would
  stop it, but that argument also turns off whitespace collapsing and makes
  `stri_wrap()` raise on any string containing a newline, which would break
  re-wrapping already-wrapped text -- and re-aligning re-flowed output
  against the input risks corrupting ordinary text to protect a deprecated
  corner of it. Call `cjk_normalize()` first if you want the normalisation
  to be explicit.
* **The jamo round trip returns NFC.** `cjk_compose_jamo()` is
  normalisation form C, so it composes everything composable and not only
  the jamo it was handed: an `e` followed by a combining acute comes back as
  the single character U+00E9. The guarantee is that re-joining the jamo and
  composing them equals `stri_trans_nfc(x)`, which is `x` whenever `x` was
  already NFC. The Hangul decomposition itself is exact -- verified over all
  11,172 syllables in the block, which decompose into 67 distinct conjoining
  jamo and recompose to the syllable they came from. Note the re-joining
  step: `cjk_jamo()` returns a list and `cjk_compose_jamo()` takes a
  character vector, so the two do not compose directly.
* **Kana conversion is a normalisation, not a reversible mapping.** On text
  holding both syllabaries it erases the distinction between them, and that
  distinction carries meaning -- katakana marks loanwords and emphasis -- so
  `to_katakana(to_hiragana(x))` returns `x` only when `x` was already all
  katakana.
* **The two segmentation engines do not tokenise punctuation alike.**
  `"icu"` drops punctuation and symbols along with whitespace;
  `"character"` keeps CJK punctuation as tokens, because those code points
  are in blocks `cjk_blocks()` lists. The same sentence therefore yields
  different token counts, and the gap is punctuation rather than a
  disagreement about where words end. An emoji goes the same way.
* **A locale ICU has no data for is an error, not a silent fallback.** ICU
  resolves an unknown locale to the root one, and stringi reports that with
  a warning most callers never see -- or, on stringi 1.6.2, with no warning
  at all. The four verbs taking a `locale` share one guard, which checks the
  language subtag against `stringi::stri_locale_list()` rather than watching
  for a warning that is not dependable. An unrecognised *region* still
  resolves to its language, so `"zh-CH"` and `"zh-u-co-stroke"` are valid.
* **`locale` does not change CJK word or sentence boundaries.** It is
  accepted and forwarded, and ICU may use it elsewhere, but the CJK
  dictionary is chosen by the script of the text. It *does* select the
  Annex #14 line-breaking style in `cjk_wrap()`, which is why that verb
  takes one.

## Notes

* **Two of the new tests were not portable to an older ICU, and the release
  notes had claimed otherwise.** Re-running the current suite on
  R 3.6.3 / stringi 1.5.3 / ICU 60.3 -- a configuration the submission
  notes said passed, but which had not been retried since the new verbs
  went in -- produced four failures. Two pinned the number of variation
  selectors at 260, which is a fact about the Unicode version rather than
  about the package: U+180F arrived in Unicode 14.0, so an ICU built
  against 10.0 knows 259. The set is now taken from ICU's own
  `Variation_Selector` property and the assertions are about every member
  of it, which is the standard the rest of the suite already held to. The
  other two asserted that an exported verb raises on undecodable bytes,
  which stringi 1.5.3 does not do -- it warns -- and which the test
  immediately above them in the same file already warned was not a
  portable assertion. That test now skips when stringi only warns. Both
  older stacks pass.
* **A test asserted nothing, four lines below a comment warning against
  exactly that.** `expect_identical(cjk_blocks(), cjk_blocks())` holds for
  any deterministic function and says nothing about the memoisation it sat
  inside -- which the surrounding comment had already said in so many
  words. It is replaced by the other half of what "the cache must be
  invisible" means: a caller who edits the tibble they were handed must not
  reach the table every other verb reads. Both new assertions were checked
  against a deliberately poisoned cache to confirm they fail when they
  should.

* **Eight contracts the suite stated but never actually tested.** A mutation
  sweep over the package's own parse tree flipped all 240 comparisons,
  boundaries and logical operators in `R/` one at a time and re-ran the
  suite; the ones nothing noticed marked the gaps. Not one was a bug --
  every case behaves as documented -- but none was pinned either. They
  were: that a Chinese full stop does not stop `cjk_detect_language()`
  seeing the Han around it (every Han fixture in the suite was
  punctuation-free, which left the commonest real input untested); that
  `to_fullwidth()` and `to_halfwidth()` convert both ends of the ASCII
  range, `!` and `~`, not just the letters in the middle; that a width --
  or an `n` -- of exactly `.Machine$integer.max` is accepted rather than
  refused one short of the limit; that `cjk_pad(pad = )` rejects a wrong
  type and a wrong length each on its own evidence; that a `width` which is
  entirely `NA` propagates while one that merely contains an `NA` is a type
  error; that `decreasing` is validated by all three of its clauses in both
  `cjk_sort()` and `cjk_order()`; and that a byte-order mark on **some**
  elements of a vector is handled element by element -- every earlier BOM
  test used a length-one input, so none could tell the cheap `any()` exit
  from a wrong one that would have left the mark in the output of six
  verbs. The eighth is internal: `.cjk_take_width()` answers `""` for a
  budget of zero columns, which is not reachable through `cjk_truncate()`
  but is the boundary the helper's own comment promises a caller.

* **The sweep also settled which operators cannot be tested, which is worth
  knowing too.** 221 of the 240 mutants die; of the 21 that live, 20 are
  equivalent -- no input distinguishes them. The BOM guards are
  optimisations whose slow path computes the same answer (`rep(x, 0L)` is
  `character(0)`, `substring(x, 1L)` is `x`) -- five of the twenty. The
  engine registry is parented on `emptyenv()`, so `inherits` cannot matter;
  `use.names = FALSE` is set on `unlist()` calls whose input has no names to
  drop; `fixed = TRUE` is set on patterns holding no metacharacter anyway;
  four guards are followed by a second guard that catches the same case;
  a run-numbering `cumsum()` is only ever read as a grouping key, so
  shifting every group's label by one changes no grouping; and
  `cjk_truncate()`'s two ellipsis boundaries meet at the same answer from
  either side. Those are left
  exactly as they are -- they document intent, and a test could only
  restate the source. That leaves exactly one branch genuinely untested,
  and it now says so in a comment: reaching the `pull()`-method lookup for
  a database-backed `tbl` would mean a backend package in `Suggests` for
  one branch's sake, or registering a method into dplyr's own namespace
  from a test, and neither is worth it. It stays because deleting it would
  relabel a backend's errors as bad input.

* **The tests now assert laws over the code point space, not examples.** A
  new `test-invariants.R` checks idempotence, round trips and agreement with
  the block table, and lets Unicode supply the input rather than a
  hand-picked character. That is what found the two defects above: every
  earlier test had chosen characters to illustrate a point, and neither a
  compatibility ideograph nor a list argument was a point anyone had
  thought to illustrate. The laws are that each of the five normal forms is
  a fixed point of itself, that `nfc(nfd(x))` is `nfc(x)` and likewise for
  NFKC, that `to_fullwidth()` and `to_halfwidth()` are idempotent and that
  fullwidth text survives a trip to halfwidth and back, that the kana
  conversions are idempotent, that `cjk_truncate()` and `cjk_pad()` are
  no-ops on a string that already fits, that one character is one token
  and one 1-gram, and that all thirteen transforms return one valid,
  non-missing UTF-8 string per input. Over all 111,012 code points in the
  block table: no violations.
  A one-off sweep of all **1,112,029** valid code points in Unicode
  confirmed `has_cjk()`, `cjk_ratio()` and `cjk_script()` agree with the
  block table in both directions -- no character wrongly called CJK and
  none wrongly left out -- and that `cjk_width()` is never missing and
  never outside 0:2. What is kept in the suite is every block boundary and
  the code point either side of it, which is where an interval lookup
  actually fails, rather than a minute of CI spent re-verifying static
  data on every job. The exhaustive in-block pass is `skip_on_cran()`;
  the sampled one, forty code points from every block, runs everywhere.
* **The Hangul round trip is verified in full**, not by example: all 11,172
  syllables decompose into 2 or 3 of 67 distinct conjoining jamo
  (U+1100-U+11C2, never the compatibility block) and recompose exactly.

* `RoxygenNote` replaces `Config/roxygen2/version`: `man/` is generated by
  roxygen2 7.3.2, and the file now records what actually built it.
* Still no compiled code, no bundled data, and no network requests.

## Still not in this release

* **Stroke counts, radicals and per-character readings.** These need the
  [Unihan database](https://www.unicode.org/charts/unihan.html);
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
  one function, exactly the hole closed everywhere else this release --
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
