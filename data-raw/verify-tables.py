"""Check tidycjk's hand-written Unicode tables against an independent source.

NOT RUN AT BUILD, CHECK OR RUN TIME -- `data-raw/` is in .Rbuildignore. Run it
by hand (`python3 data-raw/verify-tables.py`) after touching .cjk_ranges(),
.cjk_halfwidth_katakana(), .cjk_voiced_map() or .cjk_semivoiced_map(), and
after each Unicode release.

R has no Unicode database to check those tables against, which is the whole
problem: a hand-written table is only as good as the last person to proofread
it. Python's `unicodedata` is a separate implementation of the same standard,
so it makes an independent referee. It checks that

  * the block table is sorted and non-overlapping, which .cjk_block_index()
    relies on for its findInterval() lookup to be correct;
  * no block of letters is MISSING from the block table -- the one check a test
    written against the table cannot make, since what is absent from the table
    is invisible to it. Every assigned code point the referee names as a letter
    of a script tidycjk covers must be in the table or in OUT_OF_SCOPE;
  * every halfwidth katakana mapping agrees with NFKC;
  * every voiced and semi-voiced pair agrees with NFC, and that no katakana
    that NFC can compose is missing from the table;
  * the two documented divergences from NFKC (U+FF9E and U+FF9F map to the
    spacing marks U+309B/U+309C rather than the combining U+3099/U+309A) are
    exactly that and nothing more.

Written for this package on the first pass, it found five genuine errors: the
four wa-row voiced compositions and the katakana iteration mark were all
missing from the composition table. The coverage check added afterwards found a
sixth: Bopomofo Extended (U+31A0-U+31BF) was absent from the block table, so
has_cjk() answered FALSE for the Minnan and Hakka bopomofo letters.

It also reports how many assigned code points a hand-written East Asian Width
range table would get wrong. That number is why cjk_width() delegates to
stringi/ICU instead of carrying its own table.
"""
import unicodedata as ud
import sys

VOICED_MARK = chr(0x3099)      # COMBINING KATAKANA-HIRAGANA VOICED SOUND MARK
SEMIVOICED_MARK = chr(0x309A)  # COMBINING ... SEMI-VOICED SOUND MARK

fail = []
def check(cond, msg):
    if not cond:
        fail.append(msg)

# ---------------------------------------------------------------- block table
RANGES = [
    (0x1100, 0x11FF, "Hangul Jamo", "hangul"),
    (0x3000, 0x303F, "CJK Symbols and Punctuation", "punctuation"),
    (0x3040, 0x309F, "Hiragana", "hiragana"),
    (0x30A0, 0x30FF, "Katakana", "katakana"),
    (0x3100, 0x312F, "Bopomofo", "bopomofo"),
    (0x3130, 0x318F, "Hangul Compatibility Jamo", "hangul"),
    (0x3190, 0x319F, "Kanbun", "kanbun"),
    (0x31A0, 0x31BF, "Bopomofo Extended", "bopomofo"),
    (0x31F0, 0x31FF, "Katakana Phonetic Extensions", "katakana"),
    (0x3400, 0x4DBF, "CJK Unified Ideographs Extension A", "han"),
    (0x4E00, 0x9FFF, "CJK Unified Ideographs", "han"),
    (0xA960, 0xA97F, "Hangul Jamo Extended-A", "hangul"),
    (0xAC00, 0xD7A3, "Hangul Syllables", "hangul"),
    (0xD7B0, 0xD7FF, "Hangul Jamo Extended-B", "hangul"),
    (0xF900, 0xFAFF, "CJK Compatibility Ideographs", "han"),
    (0xFF00, 0xFF64, "Halfwidth and Fullwidth Forms", "fullwidth"),
    (0xFF65, 0xFF9F, "Halfwidth Katakana", "katakana"),
    (0xFFA0, 0xFFEF, "Halfwidth and Fullwidth Forms", "fullwidth"),
    (0x20000, 0x2A6DF, "CJK Unified Ideographs Extension B", "han"),
    (0x2A700, 0x2B73F, "CJK Unified Ideographs Extension C", "han"),
    (0x2B740, 0x2B81F, "CJK Unified Ideographs Extension D", "han"),
    (0x2B820, 0x2CEAF, "CJK Unified Ideographs Extension E", "han"),
    (0x2CEB0, 0x2EBEF, "CJK Unified Ideographs Extension F", "han"),
    # Not alphabetical, and must not be sorted into alphabetical order:
    # Unicode put Extension I below Extension G in code point order.
    (0x2EBF0, 0x2EE5F, "CJK Unified Ideographs Extension I", "han"),
    (0x2F800, 0x2FA1F, "CJK Compatibility Ideographs Supplement", "han"),
    (0x30000, 0x3134F, "CJK Unified Ideographs Extension G", "han"),
    (0x31350, 0x323AF, "CJK Unified Ideographs Extension H", "han"),
]

# invariants findInterval() depends on
starts = [r[0] for r in RANGES]
check(starts == sorted(starts), "block table is not sorted by start")
for a, b in zip(RANGES, RANGES[1:]):
    check(a[1] < b[0], f"overlap: {a[2]} {a[1]:X} >= {b[2]} {b[0]:X}")
for s, e, name, _ in RANGES:
    check(s <= e, f"inverted range {name}")

SAMPLES = {
    0x4E2D: "han", 0x6587: "han", 0x3400: "han", 0xF900: "han",
    0x20000: "han", 0x3042: "hiragana", 0x30AB: "katakana",
    0xFF76: "katakana", 0xAC00: "hangul", 0x1100: "hangul",
    0x3131: "hangul", 0x3105: "bopomofo", 0x3190: "kanbun",
    0x3002: "punctuation", 0xFF01: "fullwidth",
}
def lookup(cp):
    for s, e, blk, sc in RANGES:
        if s <= cp <= e:
            return sc
    return None
for cp, want in SAMPLES.items():
    check(lookup(cp) == want, f"U+{cp:04X} -> {lookup(cp)}, expected {want}")
    try:
        ud.name(chr(cp))
    except ValueError:
        fail.append(f"U+{cp:04X} is unassigned")

# The referee is only as current as the Python build. Extensions G, H and I
# arrived in Unicode 13.0, 15.0 and 15.1, so an older `unicodedata` cannot
# confirm them and says so rather than staying silent about the gap.
print(f"referee: Python unicodedata, UCD {ud.unidata_version}")
def any_assigned(start, end):
    # A block whose start is unassigned is normal (U+3040 opens Hiragana and
    # is a reserved code point); a block with nothing assigned anywhere is one
    # this Python has never heard of.
    return any(ud.name(chr(cp), "") for cp in range(start, end + 1))
unknown = sorted({name for start, end, name, _ in RANGES
                  if not any_assigned(start, end)})
if unknown:
    print("  block newer than the referee, not verifiable here: "
          + ", ".join(unknown))

# ------------------------------------------------------------ block coverage
# The check the sortedness assertions above cannot make: is a whole block of
# letters missing? Bopomofo Extended (U+31A0-U+31BF) was, for the first release
# -- 32 of the 75 assigned bopomofo letters -- and nothing here noticed, because
# what is absent from the table is invisible to a test written against the
# table. So work the other way round: enumerate every assigned code point the
# referee names as a LETTER of a script tidycjk claims to cover, and require it
# to be either in RANGES or in the explicit out-of-scope list below.
#
# Each entry in OUT_OF_SCOPE is a deliberate omission with its reason. Adding to
# it is a scope decision; a NEW block of letters showing up as a failure here is
# a bug. ?cjk_blocks documents the same boundary for users.
# Prefix matching is literal, so a name that merely *contains* one of these is
# not enumerated. Three groups were missed on the first pass and are spelled out
# here: the halfwidth letter forms are named "HALFWIDTH KATAKANA LETTER ..." and
# "HALFWIDTH HANGUL LETTER ...", which do not start with the katakana or hangul
# prefixes, so 106 assigned letters were invisible to the sweep -- including
# every character in the Halfwidth Katakana row, the one row this table carves
# out of its neighbour and therefore the likeliest to be disturbed by an edit.
# "BOPOMOFO FINAL LETTER" likewise does not start with "BOPOMOFO LETTER", which
# is why removing Bopomofo Extended reports 27 letters uncovered rather than 32.
LETTER_PREFIXES = (
    "CJK UNIFIED IDEOGRAPH", "CJK COMPATIBILITY IDEOGRAPH",
    "HIRAGANA LETTER", "KATAKANA LETTER",
    "BOPOMOFO LETTER", "BOPOMOFO FINAL LETTER",
    "HANGUL SYLLABLE", "HANGUL LETTER", "HANGUL CHOSEONG",
    "HANGUL JUNGSEONG", "HANGUL JONGSEONG",
    "HALFWIDTH KATAKANA LETTER", "HALFWIDTH HANGUL LETTER",
)
OUT_OF_SCOPE = [
    (0x1AFF0, 0x1AFFE, "Kana Extended-B: Minnan tone letters"),
    (0x1B000, 0x1B0FF, "Kana Supplement: archaic kana and hentaigana"),
    (0x1B100, 0x1B12F, "Kana Extended-A: hentaigana"),
    (0x1B130, 0x1B16F, "Small Kana Extension"),
]
def in_scope_ranges(cp):
    return any(s <= cp <= e for s, e, _, _ in RANGES)
def excused(cp):
    return any(s <= cp <= e for s, e, _ in OUT_OF_SCOPE)

uncovered = {}
for cp in range(0x0, 0x40000):
    name = ud.name(chr(cp), "")
    if not name or not name.startswith(LETTER_PREFIXES):
        continue
    if in_scope_ranges(cp) or excused(cp):
        continue
    uncovered.setdefault(name.rsplit(" ", 1)[0], []).append(cp)
for kind, cps in sorted(uncovered.items()):
    fail.append(f"{len(cps)} assigned '{kind}' code point(s) are in no block "
                f"of .cjk_ranges() and not excused, from U+{cps[0]:04X} to "
                f"U+{cps[-1]:04X}")
print(f"letters of covered scripts left uncovered: {sum(map(len, uncovered.values()))}")

# ------------------------------------------------------ halfwidth katakana map
KATA = [
    0x3002, 0x300C, 0x300D, 0x3001, 0x30FB, 0x30F2,
    0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9,
    0x30E3, 0x30E5, 0x30E7, 0x30C3,
    0x30FC, 0x30A2, 0x30A4, 0x30A6, 0x30A8, 0x30AA,
    0x30AB, 0x30AD, 0x30AF, 0x30B1, 0x30B3,
    0x30B5, 0x30B7, 0x30B9, 0x30BB, 0x30BD,
    0x30BF, 0x30C1, 0x30C4, 0x30C6, 0x30C8,
    0x30CA, 0x30CB, 0x30CC, 0x30CD, 0x30CE,
    0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB,
    0x30DE, 0x30DF, 0x30E0, 0x30E1, 0x30E2,
    0x30E4, 0x30E6, 0x30E8,
    0x30E9, 0x30EA, 0x30EB, 0x30EC, 0x30ED,
    0x30EF, 0x30F3,
    0x309B, 0x309C,
]
check(len(KATA) == 0xFF9F - 0xFF61 + 1,
      f"katakana map has {len(KATA)} entries, expected 63")

# NFKC is the authority for compatibility-width mappings, EXCEPT the two voiced
# marks: tidycjk deliberately emits the spacing form (U+309B/U+309C) where NFKC
# gives the combining form (U+3099/U+309A), matching ICU's Halfwidth-Fullwidth
# transform. Assert the divergence is exactly that and nothing more.
SPACING_FOR = {0x3099: 0x309B, 0x309A: 0x309C}
for i, want in enumerate(KATA):
    cp = 0xFF61 + i
    got = ud.normalize("NFKC", chr(cp))
    check(len(got) == 1, f"U+{cp:04X}: NFKC is not a single code point")
    nfkc = ord(got)
    if cp in (0xFF9E, 0xFF9F):
        check(SPACING_FOR.get(nfkc) == want,
              f"U+{cp:04X}: table says U+{want:04X}, NFKC says U+{nfkc:04X} "
              f"whose spacing counterpart is U+{SPACING_FOR.get(nfkc, 0):04X}")
        check(ud.combining(chr(nfkc)) != 0 and ud.combining(chr(want)) == 0,
              f"U+{cp:04X}: expected a combining/spacing pair")
    else:
        check(nfkc == want,
              f"U+{cp:04X}: table says U+{want:04X}, NFKC says U+{nfkc:04X}")

# ------------------------------------------------------------- voiced marks
_rows = [0x30AB, 0x30AD, 0x30AF, 0x30B1, 0x30B3,
         0x30B5, 0x30B7, 0x30B9, 0x30BB, 0x30BD,
         0x30BF, 0x30C1, 0x30C4, 0x30C6, 0x30C8,
         0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB,
         0x30FD]  # katakana iteration mark, also base + 1
VOICED = dict(zip(_rows, [c + 1 for c in _rows]))
VOICED.update({0x30A6: 0x30F4, 0x30EF: 0x30F7,
               0x30F0: 0x30F8, 0x30F1: 0x30F9, 0x30F2: 0x30FA})
_semi = [0x30CF, 0x30D2, 0x30D5, 0x30D8, 0x30DB]
SEMI = dict(zip(_semi, [c + 2 for c in _semi]))

# every pair in the table must match NFC composition
for base, want in VOICED.items():
    got = ud.normalize("NFC", chr(base) + VOICED_MARK)
    check(len(got) == 1 and ord(got) == want,
          f"voiced U+{base:04X}: table says U+{want:04X}, NFC says "
          f"{' '.join('U+%04X' % ord(c) for c in got)}")
for base, want in SEMI.items():
    got = ud.normalize("NFC", chr(base) + SEMIVOICED_MARK)
    check(len(got) == 1 and ord(got) == want,
          f"semi-voiced U+{base:04X}: table says U+{want:04X}, NFC says "
          f"{' '.join('U+%04X' % ord(c) for c in got)}")

# ...and completeness: no katakana may compose that the table does not know
for cp in range(0x30A0, 0x3100):
    for mark, table, kind in ((VOICED_MARK, VOICED, "voiced"),
                              (SEMIVOICED_MARK, SEMI, "semi-voiced")):
        got = ud.normalize("NFC", chr(cp) + mark)
        if len(got) == 1 and cp not in table:
            fail.append(f"U+{cp:04X} {kind}-composes to U+{ord(got):04X} "
                        f"but is missing from the table")

# the halfwidth voiced mark must compose the same way the fullwidth one does
ka_hw = ud.normalize("NFKC", chr(0xFF76)) + ud.normalize("NFKC", chr(0xFF9E))
check(ord(ud.normalize("NFC", ka_hw)) == 0x30AC,
      "U+FF76 U+FF9E should normalise to U+30AC")

# ------------------------------------------------------------- display width
# The East Asian Width ranges commonly copied around as a hand-written wcwidth
# table. tidycjk does NOT use these -- cjk_width() delegates to stringi/ICU --
# and this measures why: how many assigned code points the list gets wrong.
WIDE_HANDWRITTEN = [(0x1100, 0x115F), (0x2E80, 0x303E), (0x3041, 0x33FF),
             (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xA000, 0xA4CF),
             (0xA960, 0xA97F), (0xAC00, 0xD7A3), (0xF900, 0xFAFF),
             (0xFE10, 0xFE19), (0xFE30, 0xFE6F), (0xFF00, 0xFF60),
             (0xFFE0, 0xFFE6), (0x1F300, 0x1F64F), (0x1F900, 0x1F9FF)]
# Both directions, because either one alone flatters the hand-written table.
# Counting only the false positives -- code points it calls wide that are not --
# gave a couple of hundred and was reported as what the table "would get wrong".
# The false negatives are the real story: the list stops below the
# supplementary planes, so every ideograph in Extensions B through I is called
# one column. Those are exactly the blocks this package had to add in a bug fix.
ASSIGNED = ("Cn", "Co", "Cs")
too_wide = sum(
    1
    for s, e in WIDE_HANDWRITTEN
    for cp in range(s, e + 1)
    if ud.category(chr(cp)) not in ASSIGNED
    and ud.east_asian_width(chr(cp)) not in ("W", "F")
)
in_range = lambda cp: any(s <= cp <= e for s, e in WIDE_HANDWRITTEN)
too_narrow = sum(
    1
    for cp in range(0x0, 0x40000)
    if not in_range(cp)
    and ud.category(chr(cp)) not in ASSIGNED
    and ud.east_asian_width(chr(cp)) in ("W", "F")
)
disagree = too_wide + too_narrow
print(f"  of which called wide and are not: {too_wide}; "
      f"wide and missed entirely: {too_narrow}")
print(f"assigned code points a hand-written width table would get "
      f"wrong: {disagree}")

# the specific assertions the R test suite makes about width
check(sum(2 if ud.east_asian_width(c) in "WF" else 1
          for c in "中文") == 4, "width of U+4E2D U+6587 should be 4")
check(ud.category(chr(0x200B)) == "Cf",
      f"U+200B is {ud.category(chr(0x200B))}, expected Cf (width 0 needs this)")
check(ud.category(chr(0x0301)) == "Mn", "U+0301 should be Mn")
check(ud.east_asian_width(chr(0x00B0)) == "A",
      "U+00B0 should be East Asian Ambiguous (documented as width 1)")

# --------------------------------- the tables above are only transcriptions
#
# Everything up to here checks the literals in THIS file against the referee.
# That is only worth anything if the literals still match the package. They are
# hand-copied out of R/, and the moment to copy them is exactly the moment this
# script tells you to run it -- so a stale transcription would sail through
# every check above and report success about a table the package no longer has.
#
# So parse the R sources and diff them against the literals. No R needed: the
# tables are plain hex literals in a fixed layout, and a parse that stops
# finding them is itself a failure rather than a silent pass.
import io
import os
import re

_HERE = os.path.dirname(os.path.abspath(__file__))
_R = os.path.join(_HERE, os.pardir, "R")


def _read(name):
    with io.open(os.path.join(_R, name), encoding="utf-8") as fh:
        return fh.read()


def _slice(text, start_pat, source):
    """An R function body, from its opening line to the matching '\n}'."""
    m = re.search(start_pat, text)
    if m is None:
        fail.append(f"cannot find {start_pat!r} in {source} -- parser is stale")
        return ""
    rest = text[m.end():]
    end = rest.find("\n}")
    if end < 0:
        fail.append(f"cannot find the end of {start_pat!r} in {source}")
        return ""
    return rest[:end]


def _hex_all(text):
    return [int(h, 16) for h in re.findall(r"0x([0-9A-Fa-f]+)", text)]


try:
    ranges_src = _read("ranges.R")
    normalize_src = _read("normalize.R")
except OSError as exc:                       # pragma: no cover, dev-only
    fail.append(f"cannot read R/ sources: {exc}")
    ranges_src = normalize_src = ""

if ranges_src:
    # .cjk_ranges(): the rbind() of (start, end) pairs, then the block and
    # script character vectors, in the same order.
    body = _slice(ranges_src, r"\.cjk_ranges <- function\(\) \{", "R/ranges.R")
    rbind = body[body.find("m <- rbind("):body.find("  tab <- list(")]
    pairs = [(int(a, 16), int(b, 16)) for a, b in
             re.findall(r"c\(\s*0x([0-9A-Fa-f]+),\s*0x([0-9A-Fa-f]+)\s*\)",
                        rbind)]
    blocks = re.findall(r'"([^"]+)"', body[body.find("block = c("):
                                           body.find("script = c(")])
    scripts = re.findall(r'"([^"]+)"', body[body.find("script = c("):])
    r_ranges = [(s_, e_, b_, sc_) for (s_, e_), b_, sc_
                in zip(pairs, blocks, scripts)]
    check(len(pairs) == len(blocks) == len(scripts),
          f"R/ranges.R is internally ragged: {len(pairs)} ranges, "
          f"{len(blocks)} block names, {len(scripts)} script labels")
    check(r_ranges == RANGES,
          "RANGES here no longer matches .cjk_ranges() in R/ranges.R -- "
          "re-copy it, then re-run; every block check above was against the "
          "stale copy")

if normalize_src:
    kata = _hex_all(_slice(normalize_src,
                           r"\.cjk_halfwidth_katakana <- function\(\) \{",
                           "R/normalize.R"))
    check(kata == KATA,
          "KATA in this file no longer matches .cjk_halfwidth_katakana()")

    vm = _slice(normalize_src, r"\.cjk_voiced_map <- function\(\) \{",
                "R/normalize.R")
    v_rows = _hex_all(vm[vm.find("rows <- c("):vm.find("list(")])
    v_from = _hex_all(vm[vm.find("from = c("):vm.find("to   = c(")])
    v_to = _hex_all(vm[vm.find("to   = c("):])
    r_voiced = dict(zip(v_rows + v_from, [c + 1 for c in v_rows] + v_to))
    check(r_voiced == VOICED,
          "VOICED in this file no longer matches .cjk_voiced_map()")

    sv = _slice(normalize_src, r"\.cjk_semivoiced_map <- function\(\) \{",
                "R/normalize.R")
    s_rows = _hex_all(sv[sv.find("rows <- c("):sv.find("list(")])
    check(dict(zip(s_rows, [c + 2 for c in s_rows])) == SEMI,
          "SEMI in this file no longer matches .cjk_semivoiced_map()")

print("transcriptions checked against R/: "
      f"{'in sync' if not fail else 'SEE FAILURES BELOW'}")

print(f"\n{len(fail)} failure(s)")
for f in fail:
    print("  FAIL:", f)
sys.exit(1 if fail else 0)
