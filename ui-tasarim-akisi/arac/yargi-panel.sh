#!/usr/bin/env bash
# yargi-panel.sh — çapraz-AİLE kör yargıç panelini koşar (G1 hattının ağ kolu).
#
# Yargıç KÖRDÜR — politika olarak değil, KABİLİYET olarak: araçsız tek-atış tamamlama.
# Dosya yazamaz, motorun raporunu/transkriptini göremez, soru soramaz.
#
# DEĞER-GÜVENLİĞİ: kapı anahtarı yalnız 0600 curl-conf dosyasında yaşar; stdout/argv/log'a
# ASLA düşmez. Anahtarı bu betiğe argüman olarak VERME.
#
# Çıkış kodları:
#   0 çağrılar tamam (hüküm YOK — hükmü yargi-birlestir.py verir)
#   2 ÇALIŞTIRILAMADI: kapı sağlıksız, anahtar yok, model rafı yok, girdi eksik
#     (Teşhis freni: kapı sağlıksızken verdikt "KALDI" değil RC=2'dir — servis arızasını
#      tasarım kusuru sanmak otonom döngünün geri alamadığı hatadır.)
#
# Kullanım:
#   yargi-panel.sh --ekran-dir <dir> --sozlesme <MARKA-tasarim-dili.md> --out <dir> \
#                  [--rubrik <f>] [--cekirdek <f>] [--panel kimi,glm,qwen] [--paralel 4]
#   yargi-panel.sh --bir <ekran.html> --model <raf> --yargic <ad> --out <dir> ...
set -u

ARAC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAPI_URL="${KAPI_URL:-http://cloudtop-kapi:4000}"
ENVF="${KAPI_ENV_FILE:-$HOME/.claude/kapi.env}"
RUBRIK="$ARAC/rubrik/urun-ui-v1.md"
# ÇEKİRDEK ⟂ MARKA (L57/F5): --sozlesme kutunun MARKA dosyasıdır. Çekirdek filo kuralıdır
# ve prompta KENDİLİĞİNDEN girer — kutunun onu kopyalaması gerekmez (kopyalanan kural
# bayatlar). Enjekte edilmediği sürece rubrik M1 çekirdeğin on adını "sessiz icat" sanıyordu.
CEKIRDEK="${UI_AKIS_CEKIRDEK:-$ARAC/../cekirdek/sozlesme.md}"
PANEL="kimi,glm,qwen"
PARALEL=4
EKRAN_DIR=""; SOZLESME=""; OUT=""; BIR=""; MODEL=""; YARGIC=""

while [ $# -gt 0 ]; do
  case "$1" in
    --ekran-dir) EKRAN_DIR="$2"; shift 2 ;;
    --sozlesme)  SOZLESME="$2";  shift 2 ;;
    --cekirdek)  CEKIRDEK="$2";  shift 2 ;;
    --out)       OUT="$2";       shift 2 ;;
    --rubrik)    RUBRIK="$2";    shift 2 ;;
    --panel)     PANEL="$2";     shift 2 ;;
    --paralel)   PARALEL="$2";   shift 2 ;;
    --bir)       BIR="$2";       shift 2 ;;
    --model)     MODEL="$2";     shift 2 ;;
    --yargic)    YARGIC="$2";    shift 2 ;;
    *) echo "RC=2 bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done

[ -n "$OUT" ] || { echo "RC=2 --out zorunlu" >&2; exit 2; }
[ -f "$RUBRIK" ] || { echo "RC=2 rubrik yok: $RUBRIK — yargı yapılmadı" >&2; exit 2; }
# Fail-closed: çekirdek yoksa hüküm İSTENMEZ. "Yarım sözleşmeyle alınan kırmızı"
# tasarım kusuru sanılır; ölçülemeyen şeye hüküm verilmez.
[ -f "$CEKIRDEK" ] || { echo "RC=2 çekirdek sözleşme yok: $CEKIRDEK — yargı yapılmadı" >&2; exit 2; }
mkdir -p "$OUT"

# ── anahtar → 0600 conf (değer hiçbir yere basılmaz) ──────────────────────────
CONF="$OUT/.curl.conf"
if [ ! -s "$CONF" ]; then
  [ -f "$ENVF" ] || { echo "RC=2 kapı anahtar dosyası yok: $ENVF" >&2; exit 2; }
  ( umask 077
    k="$(grep -m1 '^KAPI_MASTER_KEY=' "$ENVF" | cut -d= -f2- | tr -d '\r\n')"
    [ -n "$k" ] && printf 'header = "Authorization: Bearer %s"\n' "$k" > "$CONF" )
fi
[ -s "$CONF" ] || { echo "RC=2 anahtar okunamadı ($ENVF içinde KAPI_MASTER_KEY yok)" >&2; exit 2; }

# ── TEK ÇAĞRI kolu (panel kolu kendini bununla çağırır) ───────────────────────
if [ -n "$BIR" ]; then
  [ -n "$MODEL" ] && [ -n "$YARGIC" ] || { echo "RC=2 --bir için --model + --yargic gerek" >&2; exit 2; }
  EKRAN="$(basename "$BIR" .html)"
  CIKTI="$OUT/${EKRAN}__${YARGIC}.json"
  GOVDE="$OUT/.${EKRAN}__${YARGIC}.istek.json"
  # RESUME: hatasız yanıt varsa yeniden çağırma (kesilen koşu kaldığı yerden sürer)
  if [ -s "$CIKTI" ] && python3 -c 'import json,sys; sys.exit(1 if "error" in json.load(open(sys.argv[1])) else 0)' "$CIKTI" 2>/dev/null; then
    echo "atlandı (mevcut): $(basename "$CIKTI")"; exit 0
  fi
  python3 "$ARAC/yargi-istek-yap.py" --rubrik "$RUBRIK" --ekran "$BIR" \
    --model "$MODEL" --out "$GOVDE" --cekirdek "$CEKIRDEK" ${SOZLESME:+--sozlesme "$SOZLESME"} \
    || { echo "RC=2 istek gövdesi kurulamadı — yargı istenmedi" >&2; exit 2; }
  for _ in 1 2; do
    curl -sS --max-time "${ZAMAN_ASIMI:-420}" -K "$CONF" \
      -H 'content-type: application/json' -H 'anthropic-version: 2023-06-01' \
      -d "@$GOVDE" "$KAPI_URL/v1/messages" > "$CIKTI" 2>"$CIKTI.err" \
    && python3 -c 'import json,sys; sys.exit(1 if "error" in json.load(open(sys.argv[1])) else 0)' "$CIKTI" \
    && break
    sleep 5
  done
  echo "bitti: $(basename "$CIKTI")"
  exit 0
fi

# ── PANEL kolu ────────────────────────────────────────────────────────────────
[ -n "$EKRAN_DIR" ] || { echo "RC=2 --ekran-dir zorunlu" >&2; exit 2; }
ls "$EKRAN_DIR"/*.html >/dev/null 2>&1 || { echo "RC=2 ekran yok: $EKRAN_DIR/*.html" >&2; exit 2; }

# Teşhis freni: kapı sağlıksızsa hüküm ÜRETME
KOD="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$KAPI_URL/health/liveliness" || echo 000)"
[ "$KOD" = "200" ] || { echo "RC=2 kapı sağlıksız (liveliness=$KOD) — yargı yapılmadı" >&2; exit 2; }

curl -sS --max-time 15 -K "$CONF" "$KAPI_URL/v1/models" > "$OUT/.modeller.json" \
  || { echo "RC=2 /v1/models okunamadı" >&2; exit 2; }

PANEL="$PANEL" python3 - "$OUT/.modeller.json" "$OUT/.panel.txt" <<'PY'
import json, os, sys
ids = sorted(m.get("id", "") for m in json.load(open(sys.argv[1])).get("data", []))
eksik, secim = [], []
for aile in os.environ["PANEL"].split(","):
    aile = aile.strip()
    aday = [i for i in ids if aile.lower() in i.lower()]
    if not aday:
        eksik.append(aile); continue
    secim.append((aile, sorted(aday, key=len)[0]))
with open(sys.argv[2], "w") as f:
    for aile, model in secim:
        f.write("%s %s\n" % (aile, model)); print("yargıç: %s → %s" % (aile, model))
if eksik:
    print("EKSİK AİLE (kapıda rafı yok): %s" % ", ".join(eksik))
# Panel en az 2 aile ister: tek yargıç panel değildir (yeter sayı sağlanamaz).
sys.exit(0 if len(secim) >= 2 else 2)
PY
[ $? -eq 0 ] || { echo "RC=2 panel kurulamadı (en az 2 ayrı AİLE gerek)" >&2; exit 2; }

ISLER="$OUT/.isler.txt"; : > "$ISLER"
for E in "$EKRAN_DIR"/*.html; do
  while read -r AD MODEL; do printf '%s %s %s\n' "$E" "$MODEL" "$AD" >> "$ISLER"; done < "$OUT/.panel.txt"
done
echo "toplam çağrı: $(wc -l < "$ISLER")"
while read -r E MODEL AD; do
  bash "$ARAC/yargi-panel.sh" --bir "$E" --model "$MODEL" --yargic "$AD" \
       --out "$OUT" --rubrik "$RUBRIK" --cekirdek "$CEKIRDEK" ${SOZLESME:+--sozlesme "$SOZLESME"} &
  while [ "$(jobs -rp | wc -l)" -ge "$PARALEL" ]; do wait -n 2>/dev/null || break; done
done < "$ISLER"
wait

echo "== panel bitti: $(ls "$OUT"/*__*.json 2>/dev/null | wc -l) yanıt =="
echo "sıradaki: python3 $ARAC/yargi-birlestir.py --rubrik $RUBRIK --yanit $OUT --ekran-dir $EKRAN_DIR"
