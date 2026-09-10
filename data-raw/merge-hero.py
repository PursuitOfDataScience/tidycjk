#!/usr/bin/env python3
"""Crossfade two cairo SVGs into man/figures/hero-width.svg.

R's cairo SVG device emits every glyph as a <path>, so the animation carries
its own outlines and renders identically without a CJK font installed. The two
files reuse ids (glyph0-1, clip1, ...), so each side is namespaced first.
"""
import re, sys, os

def load(path, pfx):
    s = open(path, encoding="utf-8").read()
    for name in sorted(set(re.findall(r'id="([^"]+)"', s)), key=len, reverse=True):
        new = f"{pfx}-{name}"
        s = s.replace(f'id="{name}"', f'id="{new}"')
        s = s.replace(f'href="#{name}"', f'href="#{new}"')
        s = s.replace(f"url(#{name})", f"url(#{new})")
    defs = re.search(r"<defs>(.*?)</defs>", s, re.S).group(1)
    body = s[s.index("</defs>") + len("</defs>"):s.rindex("</svg>")]
    return defs, body

sp = sys.argv[1]
a_defs, a_body = load(os.path.join(sp, "state-a.svg"), "a")
b_defs, b_body = load(os.path.join(sp, "state-b.svg"), "b")

W, H, DUR = 900, 300, "7s"
KEYS = "0;0.35;0.45;0.85;1"

out = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img"
     aria-labelledby="hero-title hero-desc">
<title id="hero-title">nchar() leaves CJK columns ragged; cjk_width() aligns them</title>
<desc id="hero-desc">Three labels padded to width 8. Padding by character count
leaves the right edge ragged, because a CJK character occupies two terminal
columns. Padding by display width lines the edge up.</desc>
<defs>{a_defs}{b_defs}</defs>
<g>{a_body}</g>
<g opacity="0">{b_body}
  <animate attributeName="opacity" values="0;0;1;1;0" keyTimes="{KEYS}"
           dur="{DUR}" repeatCount="indefinite" calcMode="spline"
           keySplines="0 0 1 1;.4 0 .2 1;0 0 1 1;.4 0 .2 1"/>
</g>
</svg>
'''
os.makedirs("man/figures", exist_ok=True)
open("man/figures/hero-width.svg", "w", encoding="utf-8").write(out)
print(f"wrote man/figures/hero-width.svg ({len(out)} bytes)")
