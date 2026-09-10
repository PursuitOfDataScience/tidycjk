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

A character vector the same length as `x`, each element the wrapped text
with lines separated by `\n`. `NA` gives `NA`.

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

A `width` narrower than a single character cannot be honoured – a CJK
character needs two columns – and ICU emits the character anyway rather
than looping, so a line may exceed `width` in that case. It is the only
case where it can.

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

## Very long strings use a different fit

`stri_wrap()`'s default is an optimal-fit algorithm, and it crashes R on
a long string – `stri_wrap(strrep("\u4e2d\u6587", 50000), 40)`
segfaults, at any width. Strings longer than 10,000 characters are
therefore wrapped with the greedy algorithm, which handles the same
input without complaint. For CJK text the two agree exactly, because
nearly every position is a break opportunity: over 600 randomly
generated CJK strings the two produced identical output every time.
Mixed CJK and Latin can differ, where a long Latin word gives the
optimal fit something to optimise. The threshold is set well below the
length where the crash was seen, since it looks like stack exhaustion
and the true limit will move with the machine.

A leading byte-order mark survives, which takes work: stringi drops one.
A U+FEFF *elsewhere* in the string may not, because re-flowing can put
it at the start of a segment, where stringi reads it as a byte-order
mark again and removes it. Unicode deprecated U+FEFF for any use other
than marking the start of a stream, so this only bites text that is
already using it against the standard's advice – but it is a content
change, and this page would rather say so than have you find it.

Two behaviours differ from
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
and
[`cjk_truncate()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_truncate.md),
because this verb re-flows text rather than measuring it in place.
Existing newlines in `x` are whitespace to the algorithm and are
replaced by the new line breaks, so `"a\nb"` wrapped wide comes back as
`"a b"`; wrap the pieces separately if the original breaks are
meaningful. And a string of nothing but whitespace re-flows to `""`,
where
[`cjk_pad()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_pad.md)
would have kept it.

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
x <- "\u6211\u4eca\u5929\u5f88\u958b\u5fc3\uff0c\u56e0\u70ba\u5929\u6c23\u975e\u5e38\u597d"
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
