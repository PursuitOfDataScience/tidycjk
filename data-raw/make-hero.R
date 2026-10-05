# Generates man/figures/hero-width.svg's two states.
#
# Run with:
#   HERO_OUT=/some/scratch/dir Rscript data-raw/make-hero.R
#   python3 data-raw/merge-hero.py /some/scratch/dir
#
# HERO_OUT is required and is where state-a.svg and state-b.svg are written;
# unset, file.path("", ...) resolves to the filesystem root and the device
# fails with a bare cairo "error while writing to output stream". The merge
# step takes the same directory as its first argument -- it does not read
# HERO_OUT -- and writes man/figures/hero-width.svg relative to the working
# directory, so run both from the package root.
#
# The cairo SVG device turns every glyph into a <path>, so the result needs no
# CJK font on the reader's machine. data-raw/merge-hero.py crossfades them.
library(grid); library(tidycjk)

CJK <- "Noto Sans CJK SC"; MONO <- "DejaVu Sans Mono"; SANS <- "DejaVu Sans"
ink <- "#0C1728"; panel <- "#152943"
verm <- "#E2503F"; mint <- "#4FC3A1"; paper <- "#F6F2EA"; muted <- "#8AA2C0"

W <- 900; H <- 300
MPX <- 26; ADV <- 0.602; CELL <- MPX * ADV

draw_cells <- function(s, x0, y) {
  chs <- strsplit(s, "")[[1]]; pos <- 0
  for (ch in chs) {
    w <- cjk_width(ch)
    if (ch != " ")
      grid.text(ch, x = x0 + (pos + w / 2) * CELL, y = y, default.units = "native",
                gp = gpar(col = paper, fontsize = if (w == 2) 2 * CELL else MPX,
                          fontfamily = if (w == 2) CJK else MONO))
    pos <- pos + w
  }
  pos * CELL
}

labels <- c("中文", "abcd", "日本語")
pad_n  <- function(s, n) paste0(s, strrep(" ", n - nchar(s)))

state <- function(ttl, sub, strs, edge, mark) {
  pushViewport(viewport(xscale = c(0, W), yscale = c(0, H)))
  grid.rect(gp = gpar(fill = ink, col = NA))
  grid.roundrect(x = 30, y = 34, width = 840, height = 232, r = unit(9, "pt"),
                 just = c("left", "bottom"), default.units = "native",
                 gp = gpar(fill = panel, col = NA))
  grid.text(ttl, x = 62, y = 232, just = "left", default.units = "native",
            gp = gpar(col = paper, fontfamily = MONO, fontsize = 24))
  grid.text(sub, x = 62, y = 204, just = "left", default.units = "native",
            gp = gpar(col = muted, fontfamily = SANS, fontsize = 17))
  rows <- c(160, 118, 76)
  for (i in seq_along(strs)) {
    grid.text("|", x = 66, y = rows[i], default.units = "native",
              gp = gpar(col = muted, fontfamily = MONO, fontsize = MPX))
    wpx <- draw_cells(strs[i], 78, rows[i])
    grid.text("|", x = 78 + wpx + 5, y = rows[i], default.units = "native",
              gp = gpar(col = edge, fontfamily = MONO, fontsize = MPX))
  }
  grid.text(mark, x = 700, y = 232, just = "left", default.units = "native",
            gp = gpar(col = edge, fontfamily = SANS, fontsize = 19))
  popViewport()
}

out <- Sys.getenv("HERO_OUT")
svg(file.path(out, "state-a.svg"), width = W / 72, height = H / 72, bg = ink)
state("nchar()", "counts characters", pad_n(labels, 8), verm, "ragged")
invisible(dev.off())
svg(file.path(out, "state-b.svg"), width = W / 72, height = H / 72, bg = ink)
state("cjk_width()", "counts terminal columns", cjk_pad(labels, 8), mint, "aligned")
invisible(dev.off())
cat("wrote state-a.svg, state-b.svg\n")
