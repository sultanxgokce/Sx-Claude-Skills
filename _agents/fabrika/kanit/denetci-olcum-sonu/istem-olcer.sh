#!/usr/bin/env bash
# istem-olcer.sh <fabrika dizini> — 188 satırlık bir sınav ölçümünün hangi kısmı göze (denetçi istemine) gidiyor?
# Geçici depo + gerçek kanit.sh/denetci.sh (verilen fabrikadan) + sahte göz (istemi kopyalar, 5/E döner). Gerçek göz çağrılmaz.
set -uo pipefail
FB="$(cd "$1" && pwd)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
( cd "$T" && git init -q -b main ) >/dev/null 2>&1; export KANIT_DEPO="$T"
printf '#!/usr/bin/env bash\ncp "$1" "%s/istem.md"; printf %%s '"'"'{"kod_puani":5,"dogru_sey":"E","ozet":"x","bulgular":[],"kanit_gorusu":"x"}'"'"'\n' "$T" > "$T/goz.sh"; chmod +x "$T/goz.sh"
bash "$FB/scripts/kanit.sh" olcum is-o sinav --asama tek -- python3 -c 'for i in range(184): print("  ✓ kapi %d" % i)
print("── SONUÇ: %d geçti · 0 kaldı ──" % 156)' >/dev/null 2>&1   # sonuç metni komutta düz geçmesin (dosyanın 1. satırı komut)
printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b\n' > "$T/d.patch"
DENETCI_KOMUT="$T/goz.sh" bash "$FB/scripts/denetci.sh" is-o --diff "$T/d.patch" >/dev/null 2>&1; echo "denetçi rc=$? · fabrika $(grep -m1 '^version:' "$FB/SKILL.md") · ölçülen denetci.sh sha256 $(sha256sum "$FB/scripts/denetci.sh" | cut -c1-16)"   # hangi kod ölçüldü (göz #392 tur 1)
python3 - "$T/istem.md" "$T/_agents/fabrika/kanit/is-o/olcum-sinav-tek.txt" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read().split("\n"); n = len(open(sys.argv[2], encoding="utf-8").read().splitlines())
b = s.index("--- olcum-sinav-tek.txt ---")
e = next((i for i in range(b + 1, len(s)) if s[i].startswith("--- olcum-") or s[i].startswith("=====")), len(s))
bol = s[b + 1:e]
print("başlık:", next(x for x in s if x.startswith("===== ÖLÇÜM")))
print("ölçüm dosyası %d satır → göze giden %d satır" % (n, len(bol)))
print("sonuç satırı göze gidiyor mu:", "EVET" if any(x.strip() == "── SONUÇ: 156 geçti · 0 kaldı ──" for x in bol) else "HAYIR")
cik = bol[:bol.index("--- stderr ---")] if "--- stderr ---" in bol else bol   # ölçüm dosyasının KENDİ stderr ayırıcısı hariç
print("ölçümün stdout'undan göze giden son satır: «%s»" % next((x for x in reversed(cik) if x.strip()), "(yok)"))
PY
