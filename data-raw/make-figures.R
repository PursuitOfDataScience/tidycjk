# Generates the README / pkgdown figures into man/figures/.
# Run with: Rscript data-raw/make-figures.R   (needs ragg, a CJK font, tidycjk)
#
# Sizes are in pixels; grid wants points, hence px(). The terminal grids below
# are laid out with cjk_width() itself, so the figures are drawn by the
# function they illustrate.
library(grid); library(ragg); library(tidycjk)

RES <- 150
px  <- function(p) p * 72 / RES
CJK <- "Noto Sans CJK SC"; MONO <- "DejaVu Sans Mono"; SANS <- "DejaVu Sans"

ink   <- "#0C1728"; panel <- "#152943"
verm  <- "#E2503F"; mint  <- "#4FC3A1"
paper <- "#F6F2EA"; muted <- "#8AA2C0"

dev_open <- function(f, w, h) agg_png(file.path("man/figures", f), width = w,
                                      height = h, units = "px", res = RES,
                                      background = ink)
vp <- function(w, h) pushViewport(viewport(xscale = c(0, w), yscale = c(0, h)))

rrect <- function(x, y, w, h, fill, col = NA, lwd = 1, r = 10) {
  grid.roundrect(x = x, y = y, width = w, height = h, r = unit(r, "pt"),
                 just = c("left", "bottom"), default.units = "native",
                 gp = gpar(fill = fill, col = col, lwd = px(lwd)))
}
lab <- function(t, x, y, col = paper, size = 26, fam = SANS, just = "left") {
  grid.text(t, x = x, y = y, default.units = "native", just = just,
            gp = gpar(col = col, fontfamily = fam, fontsize = px(size)))
}

text_w <- function(t, size, fam = SANS) {
  convertWidth(grobWidth(textGrob(t, gp = gpar(fontfamily = fam,
                                               fontsize = px(size)))),
               "native", valueOnly = TRUE)
}

# Title plus trailing subtitle. The offset has to be measured: hardcoding it
# makes the subtitle collide as soon as the title gets longer.
title_pair <- function(ttl, sub, x, y, size = 27, subsize = 21, gap = 22) {
  grid.text(ttl, x = x, y = y, default.units = "native", just = "left",
            gp = gpar(col = paper, fontfamily = MONO, fontsize = px(size)))
  tw <- convertWidth(grobWidth(textGrob(ttl, gp = gpar(fontfamily = MONO,
                                                       fontsize = px(size)))),
                     "native", valueOnly = TRUE)
  grid.text(sub, x = x + tw + gap, y = y, default.units = "native", just = "left",
            gp = gpar(col = muted, fontfamily = SANS, fontsize = px(subsize)))
}

# Draw a string onto a terminal grid: every character occupies exactly
# cjk_width() cells, which is the whole point being illustrated.
#
# The cell must equal the monospace advance or the grid drifts apart. DejaVu
# Sans Mono advances 0.602 em, so cell = 0.602 * mono size, and a CJK glyph is
# sized to span two cells rather than left at its own 1 em (which reads loose).
MONO_ADV <- 0.602
cell_for <- function(mono_px) mono_px * MONO_ADV

draw_cells <- function(s, x0, y, mono_px, col = paper) {
  cell <- cell_for(mono_px); cjk_px <- 2 * cell
  chs <- strsplit(s, "")[[1]]; pos <- 0
  for (ch in chs) {
    w <- cjk_width(ch)
    if (ch != " ") {
      grid.text(ch, x = x0 + (pos + w / 2) * cell, y = y, default.units = "native",
                gp = gpar(col = col, fontsize = px(if (w == 2) cjk_px else mono_px),
                          fontfamily = if (w == 2) CJK else MONO))
    }
    pos <- pos + w
  }
  pos * cell
}

pad_n <- function(s, n) paste0(s, strrep(" ", n - nchar(s)))       # by characters
labels <- c("中文", "abcd", "日本語")
MPX <- 30; CELL <- cell_for(MPX)

## ---- fig-width: the ragged column, and the fix --------------------------
W <- 1040; H <- 470
dev_open("fig-width.png", W, H); vp(W, H)

rows <- c(320, 262, 204)
panels <- list(
  list(x = 46,  ttl = "nchar()",     sub = "counts characters",
       edge = verm, strs = pad_n(labels, 8),  mark = "ragged"),
  list(x = 556, ttl = "cjk_width()", sub = "counts terminal columns",
       edge = mint, strs = cjk_pad(labels, 8), mark = "aligned")
)
for (p in panels) {
  rrect(p$x, 130, 440, 300, panel, r = 12)
  lab(p$ttl, p$x + 28, 398, paper, 27, MONO)
  lab(p$sub, p$x + 28, 366, muted, 20)
  for (i in seq_along(p$strs)) {
    bx <- p$x + 32
    grid.text("|", x = bx, y = rows[i], default.units = "native",
              gp = gpar(col = muted, fontfamily = MONO, fontsize = px(MPX)))
    wpx <- draw_cells(p$strs[i], bx + 12, rows[i], MPX)
    grid.text("|", x = bx + 12 + wpx + 6, y = rows[i], default.units = "native",
              gp = gpar(col = p$edge, fontfamily = MONO, fontsize = px(MPX)))
  }
  lab(p$mark, p$x + 28, 162, p$edge, 21)
}
title_pair("cjk_pad(labels, 8)", "pad to a width, not to a character count",
           46, 72, size = 22, subsize = 22, gap = 26)
invisible(dev.off())

## ---- fig-scripts: what script, and what language ------------------------
W <- 1040; H <- 450
dev_open("fig-scripts.png", W, H); vp(W, H)

txt <- c("我今天很開心", "こんにちは", "안녕하세요", "東京都", "no CJK here")
scr <- cjk_script(txt); lng <- cjk_detect_language(txt)
rows <- rev(seq(116, 316, length.out = 5))

lab("text",                   62, 372, muted, 21)
lab("cjk_script()",          450, 372, muted, 21, MONO)
lab("cjk_detect_language()", 706, 372, muted, 21, MONO)
grid.lines(c(46, 994), c(352, 352), default.units = "native",
           gp = gpar(col = "#2A415F", lwd = px(2)))

for (i in seq_along(txt)) {
  hit <- is.na(lng[i]) && !is.na(scr[i])
  if (hit) rrect(46, rows[i] - 24, 948, 48, "#1E3350", r = 8)
  draw_cells(txt[i], 62, rows[i], MPX)
  lab(ifelse(is.na(scr[i]), "NA", scr[i]), 450, rows[i],
      ifelse(is.na(scr[i]), muted, paper), 24, MONO)
  lab(ifelse(is.na(lng[i]), "NA", lng[i]), 706, rows[i],
      ifelse(is.na(lng[i]), ifelse(hit, verm, muted), mint), 24, MONO)
}
lab("東京都 is Tokyo, written only in Han. Nothing in the script separates it",
    46, 70, muted, 21, CJK)
lab("from Chinese, so the answer is NA rather than a guess.", 46, 40, muted, 21)
invisible(dev.off())

## ---- fig-normalize: width forms, and nothing else -----------------------
W <- 1040; H <- 430
dev_open("fig-normalize.png", W, H); vp(W, H)

show <- list(
  list(inp = "１２３", out = to_halfwidth("１２３"),
       note = "fullwidth digits now parse as a number"),
  list(inp = "ｶﾞ",    out = to_halfwidth("ｶﾞ"),
       note = "two code points composed into one"),
  list(inp = "½ Ⅸ ①", out = to_halfwidth("½ Ⅸ ①"),
       note = "left alone — NFKC would rewrite all three")
)
rows <- c(316, 226, 136)
title_pair("to_halfwidth()", "changes width, and only width", 46, 386)
for (i in seq_along(show)) {
  s <- show[[i]]
  rrect(46, rows[i] - 34, 948, 74, panel, r = 10)
  grid.text(s$inp, x = 80, y = rows[i] + 6, default.units = "native", just = "left",
            gp = gpar(col = paper, fontfamily = CJK, fontsize = px(34)))
  grid.text("→", x = 250, y = rows[i] + 6, default.units = "native",
            gp = gpar(col = verm, fontfamily = SANS, fontsize = px(30)))
  grid.text(s$out, x = 300, y = rows[i] + 6, default.units = "native", just = "left",
            gp = gpar(col = mint, fontfamily = CJK, fontsize = px(34)))
  lab(sprintf("%d cp → %d cp", nchar(s$inp), nchar(s$out)),
      470, rows[i] + 6, muted, 20, MONO)
  lab(s$note, 620, rows[i] + 6, muted, 20)
}
lab("no ligature, Roman numeral or circled number is touched", 46, 60, muted, 21)
invisible(dev.off())

## ---- fig-ratio: how much of this is CJK ---------------------------------
W <- 1040; H <- 400
dev_open("fig-ratio.png", W, H); vp(W, H)

rt <- c("我今天很開心", "hello 中文 world", "東京都 2024", "no CJK here")
rv <- cjk_ratio(rt)
rows <- rev(seq(110, 290, length.out = 4))
title_pair("cjk_ratio()", "share of the string that is CJK", 46, 344)
for (i in seq_along(rt)) {
  draw_cells(rt[i], 62, rows[i], 26)
  bx <- 500; bw <- 360
  rrect(bx, rows[i] - 14, bw, 28, panel, r = 6)
  if (rv[i] > 0) rrect(bx, rows[i] - 14, bw * rv[i], 28,
                       if (rv[i] == 1) mint else "#3E9BD6", r = 6)
  lab(sprintf("%.2f", rv[i]), bx + bw + 22, rows[i],
      if (rv[i] == 0) muted else paper, 23, MONO)
}
lab("1.00 is entirely CJK; 0.00 has none. The denominator is every code point,",
    46, 58, muted, 21)
lab("spaces and Latin punctuation included.", 46, 30, muted, 21)
invisible(dev.off())

## ---- fig-tokens: the two engines, side by side -----------------------
cells_w <- function(s, mono_px) sum(cjk_width(strsplit(s, "")[[1]])) * cell_for(mono_px)

W <- 1040; H <- 430
dev_open("fig-tokens.png", W, H); vp(W, H)

src <- "\u6211\u4eca\u5929\u5f88\u958b\u5fc3"          # "I am very happy today"
rows <- list(
  list(y = 196, eng = "icu",       col = mint,
       lab = "engine = \"icu\"",       note = "words"),
  list(y =  86, eng = "character", col = "#3E9BD6",
       lab = "engine = \"character\"", note = "characters")
)

title_pair("cjk_segment()", "one sentence, two engines", 46, 384)
rrect(46, 300, 948, 62, panel, r = 10)
draw_cells(src, 78, 330, 30)

# Chips start after the widest label, measured -- hardcoding the offset is
# what made the first version of this figure overprint them.
chip_x <- 46 + max(vapply(rows, function(r) text_w(r$lab, 19, MONO),
                          numeric(1))) + 26

for (r in rows) {
  lab(r$lab, 46, r$y + 42, muted, 19, MONO)
  x <- chip_x
  for (t in cjk_segment(src, engine = r$eng)[[1]]) {
    tw <- cells_w(t, 30) + 40
    rrect(x, r$y + 14, tw, 56, "#1E3350", col = r$col, lwd = 2, r = 8)
    draw_cells(t, x + 20, r$y + 42, 30)
    x <- x + tw + 14
  }
  lab(sprintf("%d %s", length(cjk_segment(src, engine = r$eng)[[1]]), r$note),
      x + 8, r$y + 42, r$col, 20)
}
lab("\"icu\" uses ICU's dictionary; \"character\" needs none and cuts words in half",
    46, 34, muted, 21)
invisible(dev.off())

## ---- fig-blocks: the table the package is built on ----------------------
W <- 1040; H <- 430
dev_open("fig-blocks.png", W, H); vp(W, H)

bl <- head(as.data.frame(cjk_blocks()), 6)
title_pair("cjk_blocks()", "the definition of \"CJK\", readable rather than guessed at",
           46, 384)
lab("block",  62, 340, muted, 20); lab("script", 540, 340, muted, 20)
lab("range",  730, 340, muted, 20)
lab("size",   978, 340, muted, 20, just = "right")
grid.lines(c(46, 994), c(322, 322), default.units = "native",
           gp = gpar(col = "#2A415F", lwd = px(2)))

rows <- rev(seq(70, 290, length.out = 6))
for (i in seq_len(nrow(bl))) {
  if (i %% 2 == 1) rrect(46, rows[i] - 20, 948, 42, panel, r = 6)
  lab(bl$block[i], 62, rows[i], paper, 21)
  pw <- text_w(bl$script[i], 18, MONO) + 30      # pill fits its label
  rrect(540, rows[i] - 15, pw, 30, "#1E3350", r = 7)
  lab(bl$script[i], 540 + 15, rows[i], mint, 18, MONO)
  lab(sprintf("U+%04X-U+%04X", bl$start[i], bl$end[i]), 730, rows[i], muted, 19, MONO)
  lab(format(bl$n_codepoints[i], big.mark = ","), 978, rows[i], paper, 19, MONO,
      just = "right")
}
invisible(dev.off())

cat("wrote 6 figures\n")
