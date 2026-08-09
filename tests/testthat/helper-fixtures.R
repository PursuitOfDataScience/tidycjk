# Real CJK strings, written as \u escapes so the test files stay pure ASCII.
# The romanisation and meaning of each is given so that a failure is readable
# without a Unicode chart to hand.

ZH <- "\u4e2d\u6587"                    # U+4E2D U+6587, "Chinese writing"
ZH_SENTENCE <- "\u6211\u4eca\u5929\u5f88\u958b\u5fc3"    # "I am very happy today"
ZH_HAPPY <- "\u958b\u5fc3"              # "happy" -- one word, two characters
JA_KANA <- "\u3053\u3093\u306b\u3061\u306f"          # "konnichiwa", hiragana only
JA_MIXED <- "\u65e5\u672c\u306e\u3053\u3068\u3070"        # "the Japanese language", 2 kanji + 4 kana
JA_KANJI_ONLY <- "\u6771\u4eac\u90fd"        # "Tokyo Metropolis" -- Japanese, no kana
JA_KATAKANA <- "\u30ab\u30bf\u30ab\u30ca"        # "katakana"
KO <- "\uc548\ub155\ud558\uc138\uc694"               # "annyeonghaseyo", Hangul syllables
KO_JAMO <- "\u3131\u3134"               # U+3131 U+3134, Hangul compatibility jamo
BOPOMOFO <- "\u3105\u3106"              # U+3105 U+3106, Mandarin phonetic symbols
KANBUN <- "\u3190\u3191"                # U+3190 U+3191, kanbun annotation marks

# Width and normalisation fixtures
HW_KA_VOICED <- "\uff76\uff9e"           # U+FF76 U+FF9E, halfwidth ka + voiced mark
FW_GA <- "\u30ac"                   # U+30AC, the single precomposed code point
HW_KA <- "\uff76"                    # U+FF76
FW_KA <- "\u30ab"                   # U+30AB
VOICED_MARK <- "\u309b"             # U+309B, spacing voiced sound mark
FW_DIGITS <- "\uff11\uff12\uff13"            # U+FF11 U+FF12 U+FF13
IDEOGRAPHIC_SPACE <- "\u3000"       # U+3000
IDEOGRAPHIC_STOP <- "\u3002"        # U+3002
EXT_B <- "\U00020000"           # first CJK Extension B ideograph
EXT_I <- "\U0002EBF0"           # first CJK Extension I ideograph (Unicode 15.1)
EXT_G <- "\U00030000"           # first CJK Extension G ideograph (Unicode 13.0)
EXT_H <- "\U00031350"           # first CJK Extension H ideograph (Unicode 15.0)
COMPAT_SUP <- "\U0002F800"      # first CJK Compatibility Ideograph Supplement

# Non-CJK fixtures that the width rules turn on
COMBINING <- "e\u0301"          # "e" + COMBINING ACUTE ACCENT (Mn)
ZWSP <- "a\u200bb"              # ZERO WIDTH SPACE (Cf) between two letters
