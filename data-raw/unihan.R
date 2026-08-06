# Build character-level reference data from the Unihan database.
#
# THIS SCRIPT IS NOT RUN AT BUILD TIME, CHECK TIME OR RUN TIME. It downloads
# roughly 8 MB from unicode.org and is run by hand when the maintainer wants to
# refresh the data. `data-raw/` is listed in .Rbuildignore, so nothing here
# reaches CRAN or a user's machine.
#
#   source("data-raw/unihan.R")
#   build_unihan()
#
# Licence
# -------
# The Unihan database is part of the Unicode Character Database and is
# published under the Unicode License Agreement (permissive, BSD-like, and
# compatible with GPL (>= 3)). It may be redistributed with attribution. When
# any of this data is actually shipped in the package, DESCRIPTION must gain a
# note naming the Unicode License and the UCD version, each dataset's help page
# must attribute the source, and inst/CITATION should reference the Unicode
# Consortium.
#
# Status
# ------
# NOTHING FROM THIS SCRIPT IS BUNDLED IN 0.1.0. It exists so that the eventual
# pinyin / stroke-count / radical layer is built by a reproducible download and
# parse, rather than by pasting character data into an R file by hand. Do not
# hand-write Unihan-derived data.
#
# What is deliberately NOT derivable from Unihan
# ----------------------------------------------
# Traditional/simplified conversion. Unihan's kTraditionalVariant and
# kSimplifiedVariant are character-level and frequently one-to-many: a single
# simplified character can correspond to several traditional ones and the
# correct choice depends on the surrounding word. Phrase-level conversion needs
# a dictionary such as OpenCC. Do not ship character-level conversion as though
# it were complete.

UNIHAN_URL <- "https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip"

# Fields worth extracting, and the Unihan file each lives in.
UNIHAN_FIELDS <- list(
  kMandarin     = "Unihan_Readings.txt",       # Mandarin reading, pinyin
  kCantonese    = "Unihan_Readings.txt",       # Jyutping
  kJapaneseOn   = "Unihan_Readings.txt",       # Sino-Japanese reading
  kJapaneseKun  = "Unihan_Readings.txt",       # native Japanese reading
  kHangul       = "Unihan_Readings.txt",       # Korean reading
  kDefinition   = "Unihan_Readings.txt",       # English gloss
  kTotalStrokes = "Unihan_DictionaryLikeData.txt",
  kRSUnicode    = "Unihan_IRGSources.txt",     # radical-stroke index
  kGradeLevel   = "Unihan_DictionaryLikeData.txt"
)


#' Download Unihan.zip to a cache directory and return the path.
#'
#' Kept separate from parsing so that a refresh does not re-download, and so
#' that an offline machine can point at an already-downloaded copy.
#' @noRd
fetch_unihan <- function(dest_dir = "data-raw/cache", force = FALSE) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  zip_path <- file.path(dest_dir, "Unihan.zip")
  if (force || !file.exists(zip_path)) {
    message("Downloading ", UNIHAN_URL)
    utils::download.file(UNIHAN_URL, zip_path, mode = "wb")
  }
  zip_path
}


#' Parse one Unihan field into a data frame of codepoint/value.
#'
#' The file format is one tab-separated record per line, `U+4E2D<TAB>kMandarin
#' <TAB>zhong`, with `#` comments and blank lines throughout.
#' @noRd
parse_unihan_field <- function(zip_path, field, file_name) {
  con <- unz(zip_path, file_name)
  on.exit(close(con), add = TRUE)
  lines <- readLines(con, warn = FALSE, encoding = "UTF-8")

  lines <- lines[!startsWith(lines, "#") & nzchar(lines)]
  parts <- strsplit(lines, "\t", fixed = TRUE)
  parts <- parts[lengths(parts) >= 3L]

  keys <- vapply(parts, `[[`, character(1), 2L)
  parts <- parts[keys == field]
  if (length(parts) == 0L) {
    warning("no records for ", field, " in ", file_name)
    return(data.frame(
      codepoint = integer(0), char = character(0), value = character(0)
    ))
  }

  cp <- strtoi(sub("^U\\+", "", vapply(parts, `[[`, character(1), 1L)), 16L)
  data.frame(
    codepoint = as.integer(cp),
    char = vapply(cp, intToUtf8, character(1)),
    value = vapply(parts, `[[`, character(1), 3L),
    stringsAsFactors = FALSE
  )
}


#' Build every field in UNIHAN_FIELDS into a single long data frame.
#' @noRd
build_unihan <- function(zip_path = fetch_unihan(), write = FALSE) {
  out <- lapply(names(UNIHAN_FIELDS), function(field) {
    df <- parse_unihan_field(zip_path, field, UNIHAN_FIELDS[[field]])
    if (nrow(df)) df$field <- field
    df
  })
  unihan <- do.call(rbind, out)

  message(nrow(unihan), " records across ",
          length(unique(unihan$field)), " fields, ",
          length(unique(unihan$codepoint)), " characters")

  # kTotalStrokes carries one or two space-separated counts (the second is the
  # Taiwan/Hong Kong reading where it differs); kRSUnicode is radical.strokes,
  # with a trailing apostrophe marking a simplified radical. Both need
  # splitting before they become useful columns -- deliberately left to the
  # release that actually ships them, so the shape can be designed against the
  # verbs that consume it.

  if (write) {
    stop(
      "Refusing to write. Before bundling any of this, add the Unicode ",
      "License note to DESCRIPTION, attribute the source on each dataset's ",
      "help page, and record the UCD version. See the header of this file.",
      call. = FALSE
    )
  }
  invisible(unihan)
}
