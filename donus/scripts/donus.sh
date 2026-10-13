#!/usr/bin/env bash
# donus.sh — TEK DÖNÜŞ SÖZLEŞMESİ (G-BANI-0006 · Sultan 13 Eki: "dönüş olunca sen otomatik tetiklenmiyorsun ya da işini bitiren
# ajan sana bilgi geçmiyor"). İşi bitiren/tıkanan/soran ajan TEK komutla döner; işi AÇAN anında uyanır.
#
#   donus.sh <NO> bitti|tikandi|soru "<tek satır>" [--kanit <yol>] [--ben <AD>] [--kime <AD>] [--kuru]
#     NO = G#### (/gorev ile açılan iş) ya da G-AJAN-#### (merkez içi iş, ör. G-BANI-0006)
#
# KUTUDA (izole oda): dönüşü kendi giden kutusuna yazar — dosya ADINDA numara (<BEN>-<NO>-<zaman>.md), ilk satır
#   "<NO> · <durum> · <satır>". Merkezin hızlı yolu (donus-hizli.sh, dakikada 3 tur) onu ≤60 sn içinde alır, zil görev
#   defterinden işi AÇANI bulup uyandırır. Kutu merkeze ssh YAPAMAZ — bu yüzden iş dosyayı DOĞRU ADLA bırakmaktır.
# MERKEZDE: dönüşü Nexus giden kutusuna yazar, açanı bulur (G#### → ~/.filo/gorev.jsonl · G-AJAN-#### → görev mektubu
#   _agents/handoff/*gorev*.md içinde "GOREV: <NO>" — gönderen dosya adının ilk parçası) ve ORTAK GÖNDERİCİYLE (aile-notify,
#   Enter doğrulamalı) çalar; durumu ~/.filo/gorev-durum.jsonl'a işler (`/filo gorevler` gösterir).
#
# DEĞİŞMEZLER: dönüş önce DİSKE yazılır (kalıcı işaret), zil sonra — zil düşerse dönüş kaybolmaz, rc 4 ile söylenir ·
#   içerik yalnız tek satır (gövde/ek yok; kanıt bir YOL) · sır/numara yazılmaz · sessiz yeşil yok.
# rc: 0 dönüş yazıldı (+ merkezde zil çaldı) · 2 kullanım · 3 açan bulunamadı (dönüş yazıldı, --kime ver) · 4 zil çalamadı (dönüş yazıldı)
set -uo pipefail
NEXUS="${DONUS_NEXUS:-/config/projects/Nexus}"
FILO_DIZ="${FILO_DIZ:-$HOME/.filo}"
NO="${1:-}"; DURUM="${2:-}"; SATIR="${3:-}"
[ $# -ge 3 ] && shift 3 || { sed -n '2,10p' "$0" >&2; exit 2; }
KANIT=""; BEN="${DONUS_BEN:-}"; KIME=""; KURU=0
while [ $# -gt 0 ]; do case "$1" in
  --kanit) KANIT="${2:-}"; shift 2 ;; --ben) BEN="${2:-}"; shift 2 ;; --kime) KIME="${2:-}"; shift 2 ;; --kuru) KURU=1; shift ;;
  *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;; esac; done
[[ "$NO" =~ ^G[0-9]{4}$ || "$NO" =~ ^G-[A-Z]{2,12}-[0-9]{4}$ ]] || { echo "HATA: numara biçimi: G0034 ya da G-BANI-0006 (verilen: '$NO')" >&2; exit 2; }
case "$DURUM" in bitti|tikandi|soru) ;; tıkandı|tikandı) DURUM=tikandi ;; *) echo "HATA: durum bitti|tikandi|soru olmalı" >&2; exit 2 ;; esac
[ -n "$SATIR" ] || { echo "HATA: tek satırlık özet boş" >&2; exit 2; }
case "$SATIR" in *$'\n'*) echo "HATA: özet TEK satır olmalı (ayrıntı dosyada/kanıtta)" >&2; exit 2 ;; esac
[ "${#SATIR}" -le 300 ] || { echo "HATA: özet 300 karakteri aşıyor — kısalt, ayrıntıyı --kanit'e koy" >&2; exit 2; }
[ -z "$BEN" ] && BEN="$(printf '%s' "${CLAUDE_AJAN:-KUTU}")"
BEN_DOSYA="$(printf '%s' "$BEN" | sed 's/ç/c/g;s/Ç/C/g;s/ğ/g/g;s/Ğ/G/g;s/ı/i/g;s/İ/I/g;s/ö/o/g;s/Ö/O/g;s/ş/s/g;s/Ş/S/g;s/ü/u/g;s/Ü/U/g' | tr -cd 'A-Za-z0-9_-')"
[ -n "$BEN_DOSYA" ] || BEN_DOSYA=KUTU
KIP="${DONUS_KIP:-}"
if [ -z "$KIP" ]; then
  if [ -f "$NEXUS/scripts/aile-notify.sh" ] && [ -f "$NEXUS/scripts/filo.py" ]; then KIP=merkez; else KIP=kutu; fi
fi
# ── açan ──────────────────────────────────────────────────────────────────────────────────────────────────────
acan_bul() {
  [ -n "$KIME" ] && { printf '%s' "$KIME"; return 0; }
  if [[ "$NO" =~ ^G[0-9]{4}$ ]]; then
    [ -f "$FILO_DIZ/gorev.jsonl" ] && python3 -c 'import json,sys
k=""
for s in open(sys.argv[1], encoding="utf-8"):
    try: d=json.loads(s)
    except ValueError: continue
    if d.get("no")==sys.argv[2]: k=d.get("kim") or ""
print(k, end="")' "$FILO_DIZ/gorev.jsonl" "$NO"
    return 0
  fi
  local m; m="$(grep -lE "^GOREV: ${NO}([^0-9]|$)" "$NEXUS"/_agents/handoff/*gorev*.md 2>/dev/null | head -1)"
  [ -n "$m" ] && basename "$m" | cut -d- -f1
}
# ── giden kutusu ──────────────────────────────────────────────────────────────────────────────────────────────
if [ "$KIP" = merkez ]; then KOK="$NEXUS"
else
  KOK="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$KOK" ] || [ ! -d "$KOK/0-teslimat" ]; then
    ilk="$(ls -d /config/projects/*/0-teslimat 2>/dev/null | head -1)"; KOK="${ilk%/0-teslimat}"   # cwd bir projede değilse ilk proje
    [ -d "$KOK/0-teslimat" ] || { echo "HATA: giden kutusu bulunamadı (proje kökünde 0-teslimat/ yok)" >&2; exit 2; }
  fi
fi
GIDEN="$KOK/0-teslimat/giden"
ACAN="$(acan_bul)"
ZAMAN="$(date +%Y%m%d-%H%M%S)"
DOSYA="$GIDEN/${BEN_DOSYA}-${NO}-${ZAMAN}.md"
# İlk 5 satır sözleşmesi (zil yalnız bunlara bakar): numara·durum · "→ AÇAN" başlığı · HEDEF · GOREV · DURUM
ICERIK="$(printf '%s · %s · %s\n# DÖNÜŞ · %s → %s · %s · %s\nHEDEF: merkez\nGOREV: %s\nDURUM: %s\n%s\n%s\n' \
  "$NO" "$DURUM" "$SATIR" "$BEN" "${ACAN:-MERKEZ}" "$NO" "$DURUM" "$NO" "$DURUM" "${KANIT:+KANIT: $KANIT}" "$SATIR")"
if [ "$KURU" = 1 ]; then echo "(kuru) yazılacaktı: $DOSYA · açan: ${ACAN:-bilinmiyor} · kip: $KIP"; printf '%s\n' "$ICERIK"; exit 0; fi
mkdir -p "$GIDEN" || { echo "HATA: $GIDEN açılamadı" >&2; exit 2; }
printf '%s\n' "$ICERIK" > "$DOSYA.yeni" && mv "$DOSYA.yeni" "$DOSYA" || { echo "HATA: dönüş yazılamadı" >&2; exit 2; }
if [ "$KIP" = kutu ]; then
  echo "↩ dönüş bırakıldı: $DOSYA"
  echo "  merkez ≤60 sn içinde alır ve işi açanı uyandırır (yedek: kurye :14/:44)."
  exit 0
fi
# ── merkez: açanı ORTAK GÖNDERİCİYLE çal + durum defteri ───────────────────────────────────────────────────────
durum_yaz() { mkdir -p "$FILO_DIZ"; python3 -c 'import json,sys,datetime
print(json.dumps({"an": datetime.datetime.now().astimezone().isoformat(timespec="seconds"), "no": sys.argv[1], "durum": sys.argv[2],
                  "oda": "code", "dosya": sys.argv[3], "zil": sys.argv[4]}, ensure_ascii=False))' "$NO" "$DURUM" "$(basename "$DOSYA")" "$1" >> "$FILO_DIZ/gorev-durum.jsonl"; }
if [ -z "$ACAN" ]; then
  durum_yaz acan-yok
  echo "⚠ dönüş yazıldı ($DOSYA) ama işi AÇAN bulunamadı — kimse uyandırılmadı. Yeniden: --kime <AD>" >&2; exit 3
fi
# aile kaydındaki kimlik (Türkçe harfli: MUAVİN) — ASCII yazılmış açan da eşlenir
KAYIT="${AILE_REGISTRY:-$NEXUS/_agents/handoff/aile-registry.yaml}"
ID="$(python3 -c 'import re,sys,unicodedata
def k(s): return unicodedata.normalize("NFKD", s.translate(str.maketrans("İIıĞğÜüŞşÖöÇç","IIiGgUuSsOoCc"))).encode("ascii","ignore").decode().upper()
hedef=k(sys.argv[2]); ids=[]
try: ids=[m.group(1) for m in re.finditer(r"^\s*-\s*id:\s*(\S+)", open(sys.argv[1], encoding="utf-8").read(), re.M)]
except OSError: pass
print(next((i for i in ids if k(i)==hedef), sys.argv[2]), end="")' "$KAYIT" "$ACAN")"
MESAJ="[donus] $NO · $DURUM · $BEN: $SATIR → $(realpath --relative-to="$NEXUS" "$DOSYA" 2>/dev/null || echo "$DOSYA")"
if bash "$NEXUS/scripts/aile-notify.sh" "$ID" "$MESAJ" > /tmp/donus-zil.$$ 2>&1; then
  durum_yaz durtuldu; rm -f /tmp/donus-zil.$$
  echo "↩ dönüş yazıldı ve $ID uyandırıldı: $NO · $DURUM"; exit 0
fi
durum_yaz ulasmadi
echo "⚠ dönüş yazıldı ($DOSYA) ama $ID'nin zili ÇALAMADI:" >&2; tail -2 /tmp/donus-zil.$$ >&2; rm -f /tmp/donus-zil.$$; exit 4
