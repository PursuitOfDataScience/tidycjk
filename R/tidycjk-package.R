#' @keywords internal
#' @aliases tidycjk-package
#'
#' @section Output and naming contract:
#' The package has two layers. The **vector layer** takes an atomic character
#' vector and returns an atomic vector of the same length, in the manner of
#' \pkg{stringr}: [has_cjk()], [cjk_script()], [cjk_detect_language()],
#' [cjk_width()], [cjk_pad()], [cjk_truncate()], [cjk_ratio()],
#' [to_halfwidth()] and [to_fullwidth()]. [cjk_segment()] belongs to the same
#' layer but returns a list, because the number of tokens per string varies.
#' The **tidy layer** takes `verb(data, col, ...)` with the column unquoted and
#' returns a tibble: [cjk_summary()], [cjk_char_counts()] and [cjk_tokens()].
#'
#' Every vector-layer function is vectorised, propagates `NA` element-wise,
#' and returns a zero-length vector of the right type for zero-length input.
#'
#' @section What counts as CJK:
#' A character is CJK when its code point falls in one of the Unicode blocks
#' listed by [cjk_blocks()]. That set is deliberately wide: it includes the
#' ideographs and the three phonetic scripts, but also CJK punctuation and the
#' halfwidth and fullwidth forms, because a text column that has been through a
#' CJK input method carries those too. [cjk_script()] tells you which of them
#' you actually have, so the wide definition never hides the detail.
#'
#' @section Related packages:
#' \pkg{tidycjk} deliberately stops where another package already does the job:
#'
#' * Chinese word segmentation --
#'   [jiebaR](https://CRAN.R-project.org/package=jiebaR), which
#'   [cjk_segmenters()] shows how to register as an engine. It was archived
#'   from CRAN on 2025-05-01, which is why it is not a dependency.
#' * Romanisation -- [pinyin](https://CRAN.R-project.org/package=pinyin) and
#'   [hanyupinyin](https://CRAN.R-project.org/package=hanyupinyin).
#' * Traditional/simplified conversion --
#'   [tmcn](https://CRAN.R-project.org/package=tmcn) at the character level.
#'   Character-level conversion is context-blind and often wrong, so this
#'   package ships none; [OpenCC](https://github.com/BYVoid/OpenCC) is the
#'   phrase-level answer outside R.
#' * Japanese-specific utilities --
#'   [zipangu](https://CRAN.R-project.org/package=zipangu) and
#'   [Nippon](https://CRAN.R-project.org/package=Nippon).
#' * Tokenising whitespace-delimited text --
#'   [tidytext](https://CRAN.R-project.org/package=tidytext), whose
#'   `unnest_tokens()` [cjk_tokens()] mirrors for text that has no spaces
#'   between words.
#'
#' @section Relationship to stringi:
#' \pkg{tidycjk} does not re-implement Unicode. Display width comes from
#' [stringi::stri_width()] and padding from [stringi::stri_pad()] --
#' [stringi](https://CRAN.R-project.org/package=stringi) -- both of which
#' read the live Unicode tables in [ICU](https://icu.unicode.org), the
#' Unicode Consortium's C library. \pkg{tidycjk} adds the CJK-specific
#' layer on top and keeps the naming consistent with the rest of the package.
#' If all you need is the width of a string, call \pkg{stringi} directly.
"_PACKAGE"
