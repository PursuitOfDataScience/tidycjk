# Width, padding, truncation and wrapping

``` r

library(tidycjk)
```

## One character is not one column

This is the whole vignette in one comparison:

``` r

labels <- c("中文", "abcd", "日本語")

nchar(labels)      # characters
#> [1] 2 4 3
cjk_width(labels)  # terminal columns
#> [1] 4 4 6
```

`中文` is two characters and four columns. Unicode Annex \#11 assigns
every character an East Asian Width, and the values `Wide` and
`Fullwidth` mean two columns in a monospaced terminal (Unicode
Consortium 2024a).
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
reports that number.

Everything that goes wrong with CJK in a console follows from code that
used the first number where it needed the second.

``` r

pad_by_char <- function(x, n) paste0(x, strrep(" ", n - nchar(x)))

cat(paste0("|", pad_by_char(labels, 8), "|"), sep = "\n")
#> |中文      |
#> |abcd    |
#> |日本語     |
```

Three lines that should be the same width, and are not. Now with the
column count:

``` r

cat(paste0("|", cjk_pad(labels, 8), "|"), sep = "\n")
#> |中文    |
#> |abcd    |
#> |日本語  |
```

## `cjk_pad()`

Pads to a width in columns. `side` names the side the padding goes on,
and `pad` must itself be one column wide — a two-column pad character
cannot hit an odd target, so it is rejected rather than allowed to
overshoot.

``` r

cjk_pad("中文", 10)
#> [1] "中文      "
cjk_pad("中文", 10, side = "left")
#> [1] "      中文"
cjk_pad("中文", 10, side = "both")
#> [1] "   中文   "
cjk_pad("中文", 10, pad = ".")
#> [1] "中文......"
```

A width already exceeded is left alone rather than truncated — padding
and truncation are separate verbs on purpose:

``` r

cjk_width(cjk_pad("日本語テキスト", 4))
#> [1] 14
```

## `cjk_truncate()`

Cuts to a width, again in columns, appending an ellipsis that is itself
counted against the budget:

``` r

cjk_truncate("我今天很開心", 8)
#> [1] "我今..."
cjk_width(cjk_truncate("我今天很開心", 8))
#> [1] 7
```

The cut never lands inside a character. Because a CJK character is two
columns, an odd budget can leave one column unused, and leaving it empty
is the only correct option:

``` r

cjk_truncate("中文中文", 5, ellipsis = "")
#> [1] "中文"
cjk_width(cjk_truncate("中文中文", 5, ellipsis = ""))
#> [1] 4
```

## `cjk_wrap()`

Breaks a string into lines that each fit the budget. This is where
counting columns stops being sufficient, because *where* you are allowed
to break is its own question.

``` r

x <- "我今天很開心，因為天氣非常好而且朋友來看我"
cat(cjk_wrap(x, 14))
#> 我今天很開心，
#> 因為天氣非常好
#> 而且朋友來看我
```

Every line is inside the budget:

``` r

cjk_width(strsplit(cjk_wrap(x, 14), "\n", fixed = TRUE)[[1]])
#> [1] 14 14 14
```

### Why this is not “split every N columns”

CJK text is *mostly* breakable between any two characters — there are no
spaces to break at — but not everywhere. Unicode Annex \#14 defines the
positions (Unicode Consortium 2024b), and several are forbidden:

- a closing bracket `）` may not begin a line;
- a full stop `。` may not begin a line;
- an opening bracket `（` may not end one.

Those three hold whatever the locale. A fourth — whether a small kana
may be separated from the character it follows — does **not**: Annex
\#14 defines strict, normal and loose styles, and which applies is
tailored per locale. Under `"en"` a small kana never begins a line;
under `"ja"`, which uses the looser style, it may. Pass `locale` when
the output has to be reproducible, and `"ja@lb=strict"` for the strict
style:

``` r

kana <- "きょうはとてもいいてんきですっしゃちょ"
cat(cjk_wrap(kana, 6, locale = "ja@lb=strict"))
#> きょう
#> はとて
#> もいい
#> てんき
#> ですっ
#> しゃ
#> ちょ
```

A naive chunker violates all four.
[`cjk_wrap()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_wrap.md)
uses ICU’s implementation of the algorithm, so the break positions are
the ones a typesetter would choose:

``` r

cat(cjk_wrap("他說（今天天氣很好）。我們去公園散步。", 12))
#> 他說（今天
#> 天氣很好）。
#> 我們去公園散
#> 步。
```

Notice that no line begins with `。` or `）`.

Latin runs inside the same string still break on spaces, so mixed text
behaves the way you would expect from both sides:

``` r

cat(cjk_wrap("tidycjk 讓中日韓文字在終端機裡對齊 and it handles Latin too", 20))
#> tidycjk 讓中日韓文
#> 字在終端機裡對齊 and
#> it handles Latin too
```

### Indents

``` r

cat(cjk_wrap(x, 14, exdent = 2))
#> 我今天很開心，
#>   因為天氣非常
#>   好而且朋友來
#>   看我
```

## The shared contract

All three layout verbs behave identically at the edges, which is what
makes them safe inside a pipeline:

``` r

cjk_pad(c("中", NA), 6)
#> [1] "中    " NA
cjk_truncate(character(0), 6)
#> character(0)
cjk_wrap(NA, 6)
#> [1] NA
```

A `width` that is `Inf` or outside integer range is an error rather than
a silent `NA`. `cjk_pad(x, Inf)` is a plausible way to write “do not
truncate”, and it used to return missing values with only a coercion
warning:

``` r

cjk_pad("中文", Inf)
#> Error:
#> ! `width` must be finite and within integer range.
```

Ragged recycling is an error too, naming both lengths, because a
plausible vector of the wrong length is worse for a layout function than
a refusal:

``` r

cjk_pad(c("a", "b", "c"), c(2, 3))
#> Error:
#> ! `x` (3) and `width` (2) must be recyclable to a common length.
```

## Ambiguous width

Some characters — Greek, Cyrillic, a few punctuation marks — are
`Ambiguous` in Annex \#11: two columns in a legacy East Asian font, one
otherwise. There is no context-free answer, and ICU has changed its
treatment more than once.
[`cjk_width()`](https://pursuitofdatascience.github.io/tidycjk/reference/cjk_width.md)
reports what ICU reports on your machine. If your output must align in a
specific terminal, measure there rather than assuming:

``` r

cjk_width(c("α", "→", "±"))
#> [1] 1 1 1
```

## References

Unicode Consortium. 2024a. *Unicode Standard Annex \#11: East Asian
Width*. Unicode Consortium. <https://www.unicode.org/reports/tr11/>.

Unicode Consortium. 2024b. *Unicode Standard Annex \#14: Unicode Line
Breaking Algorithm*. Unicode Consortium.
<https://www.unicode.org/reports/tr14/>.
