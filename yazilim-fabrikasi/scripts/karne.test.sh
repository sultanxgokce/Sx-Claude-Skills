#!/usr/bin/env bash
# karne.test.sh — puan kalibrasyonu defterini sahte depoda koşturur.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KR="$HERE/karne.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; ( cd "$T" && git init -q -b main ) >/dev/null 2>&1; export KANIT_DEPO="$T"
den() { # den <iş> <tur> <puan> <E/H> <dk-önce>
  mkdir -p "$T/_agents/fabrika/kanit/$1"
  python3 - "$T/_agents/fabrika/kanit/$1/DENETIM-$2.json" "$2" "$3" "$4" "$5" "$1" <<'PY'
import json,sys,datetime
p,tur,puan,dogru,dk,is_=sys.argv[1:]
z=(datetime.datetime.now().astimezone()-datetime.timedelta(minutes=int(dk))).isoformat(timespec="seconds")
json.dump({"tur":int(tur),"is":is_,"pr":"12","yazan":"claude","denetci":"codex","zaman":z,"kanit_durumu":"sağlam","sonuc":{"kod_puani":int(puan),"dogru_sey":dogru,"ozet":"","bulgular":[],"kanit_gorusu":""}},open(p,"w"))
PY
}
echo "════ T1 · defter yokken ozet rc=3 ════"
bash "$KR" ozet >/dev/null 2>&1; [ $? -eq 3 ]; g $? "rc=3"
echo "════ T2 · yaz: son turu okur, süreyi ilk turdan hesaplar ════"
den is-a 1 3 H 30; den is-a 2 5 E 0
CIKTI="$(bash "$KR" yaz is-a 2>&1)"; g $? "yaz rc=0"
grep -q "tur 2" <<<"$CIKTI" && grep -q "GEÇTİ" <<<"$CIKTI" && grep -q "30" <<<"$CIKTI"; g $? "tur 2 · GEÇTİ · ~30 dk"
[ "$(wc -l < "$T/_agents/fabrika/karne.jsonl")" -eq 1 ]; g $? "deftere tek satır"
echo "════ T3 · kirildi: kanıtsız reddedilir, kanıtlı damgalar ════"
bash "$KR" kirildi is-a --neden "prod'da 500" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kanıtsız damga reddedildi"
bash "$KR" kirildi is-a --neden "prod'da 500" --kanit "#99" >/dev/null 2>&1; g $? "kanıtlı damga yazıldı"
echo "════ T4 · ozet: 5 alan/kırılan/tıkanan/ortalama ════"
den is-b 3 2 H 5; bash "$KR" yaz is-b >/dev/null 2>&1
den is-c 1 5 E 1; bash "$KR" yaz is-c >/dev/null 2>&1
CIKTI="$(bash "$KR" ozet 2>&1)"
grep -q "iş: 3" <<<"$CIKTI" && grep -q "5+E alan: 2" <<<"$CIKTI" && grep -q "KIRILAN (5 alıp sonradan kırılan): 1" <<<"$CIKTI" && grep -q "tıkanan: 1" <<<"$CIKTI"; g $? "sayımlar doğru (3 iş · 2 beş · 1 kırılan · 1 tıkanan)"
grep -q "ortalama tur: 2.0" <<<"$CIKTI"; g $? "ortalama tur 2.0"
echo "════ T5 · DENETIM yokken yaz rc=3 ════"
bash "$KR" yaz yok-is >/dev/null 2>&1; [ $? -eq 3 ]; g $? "rc=3"
find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
