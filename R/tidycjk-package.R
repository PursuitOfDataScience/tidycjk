#' @keywords internal
#' @aliases tidycjk-package
#'
#' @section Output and naming contract:
#' The package has two layers. The **vector layer** takes an atomic character
#' vector and returns an atomic vector of the same length, in the manner of
#' \pkg{stringr}: [has_cjk()], [cjk_script()], [cjk_detect_language()],
#' [cjk_width()], [cjk_pad()], [cjk_truncate()], [cjk_ratio()],
#' [to_halfwidth()] and [to_fullwidth()]. The **tidy layer** takes
#' `verb(data, col, ...)` with the column unquoted and returns a tibble:
#' [cjk_summary()] and [cjk_char_counts()].
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
#' @section Relationship to stringi:
#' \pkg{tidycjk} does not re-implement Unicode. Display width comes from
#' [stringi::stri_width()] and padding from [stringi::stri_pad()], both of
#' which read ICU's live Unicode tables; \pkg{tidycjk} adds the CJK-specific
#' layer on top and keeps the naming consistent with the rest of the package.
#' If all you need is the width of a string, call \pkg{stringi} directly.
"_PACKAGE"
