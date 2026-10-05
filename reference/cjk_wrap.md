# Wrap text to a display width

Breaks each string into lines no wider than `width` terminal columns,
completing the layout set with
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
and
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md).
Like them, it counts columns rather than characters.

## Usage

``` r
cjk_wrap(x, width, indent = 0L, exdent = 0L, locale = NULL)
```

## Arguments

- x:

  A character vector. Anything else is coerced with
  [`as.character()`](https://rdrr.io/r/base/character.html). That
  coercion is R's, not this package's, so a numeric vector is measured
  as R chooses to write it – which moves with `options(scipen)` and
  `options(OutDec)`, and can therefore differ between sessions. Convert
  deliberately if you mean to measure numbers; these verbs are for text.
  A list is *not* coerced –
  [`as.character()`](https://rdrr.io/r/base/character.html) deparses one
  rather than coercing it, so the text measured would be the R code that
  builds the list – so a list, a data frame or a function is an error
  naming what to do instead.

- width:

  Target width in columns. Recycled against `x`.

- indent:

  Columns to indent the first line of each string by.

- exdent:

  Columns to indent every line after the first by.

- locale:

  ICU locale selecting the line-breaking style, e.g. `"ja"` or
  `"ja@lb=strict"`. `NULL`, the default, uses the session default –
  which means the result depends on where it is run; see Details.

## Value

A character vector the same length as the recycled inputs, each element
the wrapped text with lines separated by `\n`. `NA` gives `NA`. As in
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
and
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md),
a `width` longer than `x` recycles `x` up to it rather than being an
error.

## Details

The break positions come from ICU's implementation of Unicode Annex
\#14, the line breaking algorithm, which is what makes this more than
[`strwrap()`](https://rdrr.io/r/base/strwrap.html) with a different
counter. CJK text is mostly breakable *between* characters – there are
no spaces to break at – but not everywhere: a closing bracket may not
begin a line, an opening bracket may not end one, and the ideographic
full stop U+3002 may not start one either. Splitting every `width`
columns would put breaks in all three places. Latin runs inside the same
string still break on spaces. A fourth rule, about small kana, holds
only in some locales – see below.

Lines are returned joined by `\n`, so the result is the same length as
`x` and can go straight to [`cat()`](https://rdrr.io/r/base/cat.html).
`strsplit(out, "\n", fixed = TRUE)` gives the lines separately.

A line comes out wider than `width` only where no break is allowed
inside it, and then ICU emits it whole rather than looping. That happens
in three cases: a character wider than the budget (a CJK character needs
two columns, so `width = 1` cannot be honoured), a run with no break
opportunity in it, such as a long Latin word or a stretch of a URL, and
an `indent` or `exdent` that leaves no room for the text after it.

## The break style depends on the locale

Annex \#14 defines three line-breaking styles – strict, normal and loose
– and which one applies is tailored per locale. The difference that
shows up in CJK text is small kana: under `"en"` a small kana may not
begin a line, and under `"ja"`, which uses the looser style, it may. So
the same call wraps Japanese differently depending on the session
locale, which is why `locale` is an argument here rather than left
implicit. Name it when the output has to be reproducible, and
`"ja@lb=strict"` if you want the strict style for Japanese.

The rules that hold whatever the locale are the ones about punctuation:
a closing bracket or an ideographic full stop never begins a line, and
an opening bracket never ends one.

## Lines are filled greedily

Each line takes as much text as fits before the next break opportunity
would overflow it, which is what a terminal does. `stri_wrap()`'s own
default is an optimal fit that evens out line lengths across a
paragraph; it is not used here, because its cost grows far faster than
the text (40,000 characters of CJK exhaust 1.5 GB of memory), and
because the breaks it picks for the start of a paragraph depend on how
the paragraph ends, so appending a sentence can re-flow every line above
it. Greedy breaks depend only on the text up to them.

A leading byte-order mark survives, which takes work: stringi drops one.
A U+FEFF *elsewhere* in the string may not, because re-flowing can put
it at the start of a segment, where stringi reads it as a byte-order
mark again and removes it. Unicode deprecated U+FEFF for any use other
than marking the start of a stream, so this only bites text that is
already using it against the standard's advice – but it is a content
change, and this page would rather say so than have you find it.

Three behaviours differ from
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
and
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md),
because this verb re-flows text rather than measuring it in place.
Existing newlines in `x` are whitespace to the algorithm and are
replaced by the new line breaks, so `"a\nb"` wrapped wide comes back as
`"a b"`; wrap the pieces separately if the original breaks are
meaningful. A string of nothing but whitespace re-flows to `""`, where
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
would have kept it.

And the output is in normalisation form C. ICU's line-breaking works on
normalised text, so `stri_wrap()` normalises, and 1,120 code points
therefore come back changed. 1,002 of them are the CJK Compatibility
Ideographs (U+F900-U+FAD9 and U+2F800-U+2FA1D): `cjk_wrap("\uf900", 2)`
is U+8C48. The other 118 are the Hebrew presentation forms, a handful of
musical symbols, and 71 scattered singletons and composition exclusions:
the Kelvin, Ohm and Angstrom signs, Greek letters with an oxia,
Devanagari letters with a nukta, and U+2329 and U+232A, which become the
CJK angle brackets U+3008 and U+3009. These are exactly the code points
NFC changes, no more and no fewer, each a duplicate of a character or
sequence Unicode prefers and kept for compatibility. Everyday text,
precomposed Latin and Hangul syllables included, is already NFC and
passes through untouched.
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md),
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md)
and
[`cjk_segment()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_segment.md)
do **not** normalise, so this is the one layout verb that can change a
character. Undoing it would mean re-aligning re-flowed output against
the input, which risks corrupting ordinary text to protect a deprecated
corner of it; running
[`cjk_normalize()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_normalize.md)
first is the way to make the normalisation explicit and expected.

## See also

[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
and
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md)
for the fixed-width forms,
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
for the measurement itself.

## Examples

``` r
# "I am happy today, because the weather is very good"
x <- paste0("\u6211\u4eca\u5929\u5f88\u958b\u5fc3\uff0c",
              "\u56e0\u70ba\u5929\u6c23\u975e\u5e38\u597d")
cat(cjk_wrap(x, 12), "\n")
#> 我今天很開
#> 心，因為天氣
#> 非常好 

# every line is within the budget, measured in columns
cjk_width(strsplit(cjk_wrap(x, 12), "\n", fixed = TRUE)[[1]])
#> [1] 10 12  6

# hanging indent
cat(cjk_wrap(x, 12, exdent = 2), "\n")
#> 我今天很開
#>   心，因為天
#>   氣非常好 

# the strict style, so a small kana never begins a line
cat(cjk_wrap("\u304d\u3087\u3046\u306f\u3068\u3066\u3082\u3044\u3044",
             6, locale = "ja@lb=strict"), "\n")
#> きょう
#> はとて
#> もいい 
```
