# Generates man/figures/logo.png -- the hex sticker.
# Run with: Rscript data-raw/make-logo.R   (needs ragg and a CJK font)
#
# Sizes are worked out in pixels and converted: the device is res = 300, so
# grid's fontsize/lwd (points) scale by 300/72. Setting them in points by eye
# is how the first draft ended up four times too big.
library(grid)
library(ragg)

W <- 1200L; H <- 1386L                    # pointy-top regular hex: H = 2W/sqrt(3)
RES <- 300
px <- function(p) p * 72 / RES            # pixels -> points, for fontsize/lwd

CJK  <- "Noto Sans CJK SC"
SANS <- "DejaVu Sans"

ink_deep <- "#08101C"
ink_mid  <- "#1D3A61"
vermil   <- "#E2503F"
paper    <- "#F6F2EA"
muted    <- "#7C93B2"

hex_xy <- function(cx, cy, r, rot = 90) {
  a <- (seq(0, 300, by = 60) + rot) * pi / 180
  list(x = cx + r * cos(a), y = cy + r * sin(a))
}

agg_png("man/figures/logo.png", width = W, height = H, units = "px",
        background = "transparent", res = RES)

pushViewport(viewport(xscale = c(0, W), yscale = c(0, H)))

h <- hex_xy(W / 2, H / 2, H / 2)
grid.polygon(h$x, h$y, default.units = "native",
             gp = gpar(fill = radialGradient(c(ink_mid, ink_deep),
                                             cx1 = .5, cy1 = .66, r1 = 0,
                                             cx2 = .5, cy2 = .5,  r2 = .80),
                       col = NA))

hb <- hex_xy(W / 2, H / 2, H / 2 - 14)
grid.polygon(hb$x, hb$y, default.units = "native",
             gp = gpar(fill = NA, col = vermil, lwd = px(27), linejoin = "mitre"))
hi <- hex_xy(W / 2, H / 2, H / 2 - 48)
grid.polygon(hi$x, hi$y, default.units = "native",
             gp = gpar(fill = NA, col = paper, lwd = px(3), alpha = .28,
                       linejoin = "mitre"))

# Han / kana / Hangul, small, across the top
tops <- c("漢", "か", "한")
for (i in seq_along(tops)) {
  grid.text(tops[i], x = W / 2 + (i - 2) * 122, y = 1128,
            default.units = "native",
            gp = gpar(col = muted, fontfamily = CJK, fontsize = px(86)))
}

# focal glyph: zi4, "character"
grid.text("字", x = W / 2, y = 792, default.units = "native",
          gp = gpar(col = paper, fontfamily = CJK, fontsize = px(420)))

# a token boundary: one rule, cut in two
rule_y <- 512; half <- 210; gap <- 34
grid.lines(c(W / 2 - half, W / 2 - gap), c(rule_y, rule_y),
           default.units = "native",
           gp = gpar(col = vermil, lwd = px(13), lineend = "round"))
grid.lines(c(W / 2 + gap, W / 2 + half), c(rule_y, rule_y),
           default.units = "native",
           gp = gpar(col = vermil, lwd = px(13), lineend = "round"))

# wordmark, letterspaced by hand
wm <- strsplit("tidycjk", "")[[1]]
sp <- 96
x0 <- W / 2 - (length(wm) - 1) * sp / 2
for (i in seq_along(wm)) {
  grid.text(wm[i], x = x0 + (i - 1) * sp, y = 348, default.units = "native",
            gp = gpar(col = paper, fontfamily = SANS, fontsize = px(138)))
}

invisible(dev.off())
cat("wrote man/figures/logo.png\n")
