"""Genera supabase/seed.sql da data/fermate.csv.

Uso: python3 tools/genera_seed.py

L'andata segue l'ordine e gli orari del CSV. Il ritorno parte dallo stabilimento
all'orario di ritorno della linea e ripercorre le fermate in ordine inverso, senza
orari: le posizioni reali si registrano poi con la modalita' rilevatore.
"""
import csv
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
COLORI = {1: "#1565C0", 2: "#2E7D32", 3: "#C62828", 4: "#6A1B9A", 5: "#EF6C00"}


def q(s):
    return "'" + s.replace("'", "''") + "'"


def main():
    righe = list(csv.DictReader(open(ROOT / "data" / "fermate.csv", encoding="utf-8")))
    linee = {}
    for r in righe:
        linee.setdefault(int(r["linea"]), {"nome": r["nome_linea"], "fermate": []})["fermate"].append(r)

    out = ["-- Generato da tools/genera_seed.py: non modificare a mano.", ""]
    out.append("insert into public.linee (id, nome, colore) values")
    out.append(",\n".join(f"  ({n}, {q(l['nome'])}, {q(COLORI.get(n, '#1565C0'))})" for n, l in sorted(linee.items())) + ";")
    out.append("")
    valori = []
    for n, l in sorted(linee.items()):
        fermate = sorted(l["fermate"], key=lambda r: int(r["ordine"]))
        for r in fermate:
            stab = "STABILIMENTO" in r["fermata"].upper() or "ALENIA AERMACCHI" in r["fermata"].upper()
            valori.append(f"  ({n}, 'andata', {int(r['ordine'])}, {q(r['fermata'])}, {q(r['orario_andata'])}, {str(stab).lower()})")
        for i, r in enumerate(reversed(fermate), start=1):
            stab = "ALENIA AERMACCHI" in r["fermata"].upper()
            orario = "null"
            valori.append(f"  ({n}, 'ritorno', {i}, {q(r['fermata'])}, {orario}, {str(stab).lower()})")
    out.append("insert into public.fermate (linea_id, tratta, ordine, nome, orario, stabilimento) values")
    out.append(",\n".join(valori) + ";")
    out.append("")
    (ROOT / "supabase" / "seed.sql").write_text("\n".join(out), encoding="utf-8")
    print(f"{len(linee)} linee, {len(valori)} fermate")


if __name__ == "__main__":
    main()
