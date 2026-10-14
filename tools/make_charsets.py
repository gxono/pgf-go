"""Generates latex/pgf-go-charsets.lua, the tables that pgf-go.lua uses to read
SGF files in GBK, Big5, Shift_JIS (and EUC-JP) and EUC-KR.

Usage, from the repository root:

    python tools/make_charsets.py

Each table has one string per lead byte: the characters of the trail bytes
0x40 to 0xFE, in order, with U+FFFD where the pair is not defined. The tables
come from Python's codecs: gb18030 (two-byte part, a superset of GB2312 and
GBK), cp950 (Big5), cp932 (Shift_JIS; EUC-JP is converted to it) and cp949
(EUC-KR and UHC).
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRAILS = range(0x40, 0xFF)
REPLACEMENT = "�"

CHARSETS = [
    ("gbk", "gb18030", range(0x81, 0xFF)),
    ("big5", "cp950", range(0x81, 0xFF)),
    ("sjis", "cp932", list(range(0x81, 0xA0)) + list(range(0xE0, 0xFD))),
    ("euckr", "cp949", range(0x81, 0xFF)),
]


def row(codec, lead):
    chars = []
    for trail in TRAILS:
        try:
            c = bytes([lead, trail]).decode(codec)
        except UnicodeDecodeError:
            c = REPLACEMENT
        # Only one non-ASCII character per pair (so the Lua strings need no escapes).
        if len(c) != 1 or ord(c) < 0x80 or 0xD800 <= ord(c) <= 0xDFFF:
            c = REPLACEMENT
        chars.append(c)
    return "".join(chars)


def main():
    lines = [
        "-- pgf-go-charsets.lua: TABLAS PARA LEER ARCHIVOS SGF EN GBK, Big5, Shift_JIS (Y EUC-JP) Y EUC-KR.",
        "-- GENERADO POR tools/make_charsets.py; NO EDITAR A MANO. LO CARGA pgf-go.lua SOLO CUANDO HACE FALTA.",
        "-- CADA TABLA TIENE UNA CADENA POR BYTE INICIAL: LOS CARACTERES DE LOS BYTES 0x40 A 0xFE QUE LO",
        "-- SIGUEN, EN ORDEN (U+FFFD SI EL PAR NO EXISTE).",
        "return {",
    ]
    for name, codec, leads in CHARSETS:
        lines.append("\t%s = {" % name)
        for lead in leads:
            text = row(codec, lead)
            if set(text) != {REPLACEMENT}:
                lines.append("\t\t[0x%02X] = [[%s]]," % (lead, text))
        lines.append("\t},")
    lines.append("}")
    out = ROOT / "latex" / "pgf-go-charsets.lua"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{out}: {out.stat().st_size} bytes")


if __name__ == "__main__":
    main()
