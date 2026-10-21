#!/usr/bin/env bash
# mmex-olcer.sh <git ref> — mmex'in BİÇİMİ: kutu deposunda bulgu-havuzu.jsonl YOK, bulgular kutunun ev dizinindeki
# Bulgu Defteri'nde (<ev>/.ic-sayfa/bulgu-defteri/bulgular.json). Verilen ref'teki bileyi bu kutuda ölçebiliyor mu?
# Gerçek mmex buradan görünmez (izole kutu); bu, biçimin taklididir — kayıtlar sahte, alan adları gerçek defterle aynı.
# Ortam değişkeni VERİLMEZ: yol yalnız HOME'dan türemeli.
set -uo pipefail
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
git archive "$1" bileyi | tar -x -C "$T" || exit 3
mkdir -p "$T/mmex/_agents/handoff" "$T/ev/.ic-sayfa/bulgu-defteri"; : > "$T/mmex/_agents/handoff/layiha-aday-havuzu.jsonl"
python3 - "$T/ev/.ic-sayfa/bulgu-defteri/bulgular.json" <<'PY'
import json, sys
from datetime import date
b = date.today().isoformat() + "T10:00:00+0300"
k = [{"id": "S%04d" % n, "no": "S-%d" % n, "sayi": n, "baslik": "aron golge dusus olcutu yanlis", "hal": "acik", "surum": 1,
      "acan": "CEZERI", "kaynak": "CEZERI", "acilis": b, "tur": "kusur", "notlar": [], "gecisler": []} for n in (2, 9, 17, 31)]
json.dump({"bulgular": k, "sonSayi": 31, "proje": "mmex"}, open(sys.argv[1], "w"), ensure_ascii=False)
PY
cd "$T/mmex" && env -u BILEYI_KUTU_DEFTERI HOME="$T/ev" BILEYI_ANAHTAR="$T/anahtar-yok" python3 "$T/bileyi/scripts/bileyi.py" --depo "$T/mmex" olc --gun 0 > "$T/o" 2>&1; rc=$?
echo "ref $1 ($(git -C "$OLDPWD" rev-parse --short "$1" 2>/dev/null)) · bileyi olc rc=$rc"
grep -E 'iz:|havuz:|ÖLÇEMED|aron golge' "$T/o" | sed "s|$T|<geçici>|g" | head -6
# HÜKÜM (göz #391 tur 2: rc 0 yeşili 🟡 satırlarla birlikte okunsun): bu ölçümün sorduğu YALNIZ kutu defterinin okunup okunmadığı.
# mmex'te merkez havuz ve sürtünme raporu YOKTUR — onların 🟡 satırı beklenen hâldir, bu ölçümün konusu değildir.
printf 'HÜKÜM · kutu defteri okundu: %s · defterdeki tekrar bulundu: %s · (çıktıda "4 × …" satırı ilk 3 kimliği basar — araç biçimi)\n' \
  "$(grep -q 'iz: kutu-defteri: .* — 4 kayıt' "$T/o" && echo EVET || echo HAYIR)" "$(grep -q '4 × aron golge' "$T/o" && echo EVET || echo HAYIR)"
