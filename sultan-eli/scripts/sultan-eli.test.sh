#!/usr/bin/env bash
# sultan-eli.test.sh — kapının ÜÇ durumunu da ayrı ayrı kanıtlar.
# En kritik iddia: 3 (ölçemedim) ≠ 1 (insan yok). Bu ayrım kaybolursa kapı, yer-gerçeği
# yerine bilgisizliğe bağlanır ve ölçemediği her kutuda meşru Sultan'ı reddeder.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
K="$HERE/sultan-eli.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "PASS  $1"; else fail=$((fail+1)); echo "FAIL  $1 (beklenen=$2 gelen=$3)"; fi; }

KOK="$T/kayit"; mkdir -p "$KOK/proje"
export SULTAN_ELI_KOK="$KOK"

_satir() {  # $1=içerik $2=kaç saniye önce
  python3 - "$1" "$2" <<'PY'
import json,sys,datetime
ic, geri = sys.argv[1], int(sys.argv[2])
an = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=geri)
print(json.dumps({"type":"user","message":{"role":"user","content":ic},
                  "timestamp":an.isoformat().replace("+00:00","Z")}))
PY
}

# ── Ö · ölçemedim ≠ insan yok ────────────────────────────────────────────────
bash "$K" dogrula --imza sokum >/dev/null 2>&1
check "Ö1 kayıt hiç yokken exit 3 (ÖLÇÜLEMEDİ, '1' DEĞİL)" "3" "$?"
check "Ö2 'insan yok' demiyor" "1" \
      "$(bash "$K" dogrula --imza sokum 2>&1 | grep -c 'ÖLÇÜLEMEDİ')"

# ── Y · insan izi YOK ────────────────────────────────────────────────────────
# Kayıt VAR ama içinde yalnız ajanın kendi araç çağrıları var (bunlar <bash-input> taşımaz).
{ _satir "sıradan bir kullanıcı mesajı" 5
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]},"timestamp":"2026-08-04T15:00:00.000Z"}'
} > "$KOK/proje/a.jsonl"
bash "$K" dogrula --imza sokum >/dev/null 2>&1
check "Y1 kayıt var ama insan-! yok → exit 1" "1" "$?"
check "Y2 ajanın tool_use satırı insan sayılmıyor" "0" \
      "$(bash "$K" dogrula --imza Bash >/dev/null 2>&1; [ $? = 0 ] && echo 1 || echo 0)"

# ── V · insan izi VAR ────────────────────────────────────────────────────────
_satir "<bash-input> iskan sokum tez --apply</bash-input>" 5 >> "$KOK/proje/a.jsonl"
bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "V1 taze insan-! + imza eşleşiyor → exit 0" "0" "$?"

# ── İ · imza gerçekten bağlıyor (zaman-penceresine indirgenmiyor) ────────────
bash "$K" dogrula --imza "sunucu-kur" >/dev/null 2>&1
check "İ1 BAŞKA komutun insan-izi bu kapıyı AÇMIYOR" "1" "$?"
bash "$K" dogrula --imza ab >/dev/null 2>&1
check "İ2 anlamsız kısa imza reddedildi (kapı gevşetilemez)" "2" "$?"
bash "$K" dogrula >/dev/null 2>&1
check "İ3 imzasız çağrı reddedildi" "2" "$?"

# ── Z · zaman penceresi ──────────────────────────────────────────────────────
rm -f "$KOK/proje/a.jsonl"
_satir "<bash-input> iskan sokum tez --apply</bash-input>" 5000 > "$KOK/proje/a.jsonl"
bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "Z1 ESKİ insan-izi kapıyı açmıyor (dünkü onay bugüne geçmez)" "1" "$?"
SULTAN_ELI_PENCERE=99999 bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "Z1b pencere genişleyince aynı satır geçiyor (kontrol gerçekten zaman ölçüyor)" "0" "$?"

# ── B · BÜYÜK kayıt: fixture-yeşil ≠ gerçek-yeşil (regresyon) ────────────────
# NİÇİN: ilk sürüm (`tail | python3`) 14/14 fixture testini geçti ama GERÇEK oturum kaydında
#   insan-izi varken "yok" dedi. Bu blok, fixture'ı gerçeğe biraz daha yaklaştırır (kalabalık
#   dosya + sondan uzak eşleşme).
#   ⚠️ DÜRÜST SINIR: bu test, o vakayı YENİDEN ÜRETMİYOR — boruyu geri takan mutasyon
#   koşuldu ve B1 KIRILMADI. Yani B1 bir regresyon-kapısı değil, yalnız bir kalabalık-dosya
#   sağlamasıdır. Gerçek güvence testte değil, ÖLÇÜMDE: bu sürüm canlı kayıtta koşturulup
#   doğru cevap verdiği görüldü. Bunu "test kapattı" diye yazmak sahte-yeşil olurdu.
rm -f "$KOK/proje/a.jsonl"
_satir "<bash-input> iskan sokum tez --apply</bash-input>" 5 > "$KOK/proje/buyuk.jsonl"
python3 - "$KOK/proje/buyuk.jsonl" <<'PY'
import sys
with open(sys.argv[1],"a") as f:
    for i in range(600):
        f.write('{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]},"timestamp":"2026-08-04T15:00:00.000Z"}\n')
PY
bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "B1 büyük kayıtta insan-izi bulunuyor (erken-çıkış exit'i ters çevirmiyor)" "0" "$?"

# ── D · durum tanısı verdikt vermez ──────────────────────────────────────────
bash "$K" durum >/dev/null 2>&1
check "D1 durum her hâlde exit 0 (tanı, kapı değil)" "0" "$?"
check "D2 durum ölçüm yüzeyini söylüyor" "1" \
      "$(bash "$K" durum 2>&1 | grep -c 'ölçüm yüzeyi')"

# ── K · korkuluk-dürüstlüğü: kod kendi sınırını YAZILI taşıyor ───────────────
# Bu satır süs değil: bu dosyanın verdiği güvence abartılırsa ilk yanlış kullanım doğar.
check "K1 'kilit değil korkuluk' uyarısı kodda duruyor" "1" \
      "$(grep -c 'KİLİT DEĞİL' "$K")"
check "K2 kastı durdurmadığı açıkça yazılı" "1" \
      "$(grep -c 'KASTI durdurmaz' "$K")"

echo ""
echo "── SONUÇ: PASS=$pass FAIL=$fail ──"
[ "$fail" = "0" ] || exit 1
exit 0
