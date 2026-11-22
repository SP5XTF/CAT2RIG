#!/usr/bin/env python3
"""Generuje tabelę obsługiwanych radiów (Markdown) z katalogu RadioModel.all.
   python3 scripts/radio_table.py en   > tabela po angielsku
   python3 scripts/radio_table.py pl   > tabela po polsku
"""
import re, sys, pathlib

SRC = pathlib.Path(__file__).resolve().parent.parent / "Sources/CAT2RIGCore/RadioModels.swift"

def models():
    text = SRC.read_text(encoding="utf-8")
    body = text[text.index("public static let all"):text.index("public static let defaultModel")]
    for m in re.finditer(r'^\s*(icom|yaesu|yaesuOld|kenwood)\((.*)\),\s*$', body, re.M):
        kind, args = m.group(1), m.group(2)
        pos = re.findall(r'"([^"]*)"', args)
        name = pos[1]
        if 'L("' in args:          # „inny model CI-V”
            continue
        kw = dict(re.findall(r'(\w+):\s*("[^"]*"|0x[0-9A-Fa-f]+|\w+)', args))
        addr = re.search(r'0x([0-9A-Fa-f]+)', args)
        maker = kw.get("maker", '"Icom"' if kind == "icom" else '"Yaesu"' if kind.startswith("yaesu") else '"Kenwood"').strip('"')
        yield dict(
            maker=maker, name=name, kind=kind,
            civ=addr.group(1).upper() if kind == "icom" else "",
            baud=kw.get("baud", {"icom": "19200", "yaesu": "38400", "yaesuOld": "4800"}.get(kind, "")),
            ptt=kw.get("ptt", "true") == "true",
            data=(kind == "icom" and kw.get("data", "true") == "true") or kind == "yaesu",
            hamlib=kw.get("hamlib", ""),
            verified=kw.get("verified", "false") == "true",
        )

PROTO = {"en": {"icom": "CI-V", "yaesu": "Yaesu text CAT", "yaesuOld": "Yaesu binary CAT", "kenwood": "Kenwood CAT"},
         "pl": {"icom": "CI-V", "yaesu": "Yaesu CAT tekstowy", "yaesuOld": "Yaesu CAT binarny", "kenwood": "Kenwood CAT"}}
HEAD = {"en": "| Maker | Model | Protocol | CI-V | Baud | CAT PTT | DATA | Hamlib # | Verified |",
        "pl": "| Producent | Model | Protokół | CI-V | Prędkość | PTT CAT | DATA | Hamlib nr | Sprawdzone |"}

def table(lang):
    out = [HEAD[lang], "|---|---|---|---|---|---|---|---|---|"]
    for r in models():
        out.append("| {maker} | {name} | {p} | {civ} | {baud} | {ptt} | {data} | {hamlib} | {ver} |".format(
            p=PROTO[lang][r["kind"]], ptt="✓" if r["ptt"] else "–", data="✓" if r["data"] else "–",
            ver="✓" if r["verified"] else "", **{k: r[k] for k in ("maker", "name", "civ", "baud", "hamlib")}))
    return "\n".join(out)

if __name__ == "__main__":
    print(table(sys.argv[1] if len(sys.argv) > 1 else "en"))
