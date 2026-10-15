#!/usr/bin/env bash
# nobet-kancasi.sh — PostToolUse kancası: her araç çağrısından sonra bağlam doluluğunu ölçer ve
# eşik aşıldıysa ajanın önüne SULTAN'IN İSTEDİĞİ UYARI SATIRINI koyar (additionalContext).
#
# NİÇİN kanca: "asla kaçmasın" ancak mekanik olursa tutar. Ajanın 40 araçta bir ölçmesi iyi niyettir;
# kanca her çağrıda ölçer (ucuz: transkript kuyruğu, ~30 ms) ve ajan uyarıyı görmeden edemez.
# Kanca BLOKLAMAZ, hiçbir şeyi değiştirmez; yalnız bağlam satırı ekler. Ölçemezse sessiz "temiz" DEMEZ:
# pencere bilinmiyorsa bunu da söyler (seyrek), transkript yoksa susar (ölçecek şey yok).
#
# Oran sınırı (oturum başına): koşum 60 sn · %70 satırı 300 sn · %80+ satırı 90 sn · ölçülemedi 900 sn
# Ayar: BAGLAM_NOBETI_KAPALI=1 (susturur) · BAGLAM_NOBETI_STAMP=<dizin> · baglam-olc.py'nin ayarları
# Kablo: /config/.claude/settings.json → hooks.PostToolUse matcher "*" (paylaşılan dosya; tek satır)
set -u
[ "${BAGLAM_NOBETI_KAPALI:-0}" = "1" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="${BAGLAM_NOBETI_STAMP:-${TMPDIR:-/tmp}/baglam-nobeti-$(id -u)}"
mkdir -p "$STAMP" 2>/dev/null || exit 0

girdi="$(cat 2>/dev/null || true)"
tp="$(printf '%s' "$girdi" | python3 -c 'import sys,json
try: d=json.load(sys.stdin); print(d.get("transcript_path") or "")
except Exception: print("")' 2>/dev/null)"
[ -n "$tp" ] && [ -f "$tp" ] || exit 0
key="$(printf '%s' "$tp" | sha1sum | cut -c1-12)"
now="$(date +%s)"

taze(){ # taze <damga> <saniye> → 0 = henüz süre dolmadı
  local f="$STAMP/$1" s="$2" son
  [ -f "$f" ] || return 1
  son="$(cat "$f" 2>/dev/null || echo 0)"
  [ $(( now - son )) -lt "$s" ]
}
damga(){ echo "$now" > "$STAMP/$1" 2>/dev/null || true; }

taze "kos-$key" "${BAGLAM_NOBETI_KOSUM_SN:-60}" && exit 0
damga "kos-$key"

olcum="$(python3 "$KOK/baglam-olc.py" "$tp" 2>/dev/null)"; rc=$?
pct="$(printf '%s' "$olcum" | sed -n 's/.*pct=\([0-9]*\).*/\1/p')"
pencere="$(printf '%s' "$olcum" | sed -n 's/.*pencere=\([0-9]*\).*/\1/p')"
kaynak="$(printf '%s' "$olcum" | sed -n 's/.*kaynak=\([a-z]*\).*/\1/p')"
model="$(printf '%s' "$olcum" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"

case "$rc" in
  0) exit 0 ;;
  1) taze "u70-$key" "${BAGLAM_NOBETI_UYARI_SN:-300}" && exit 0; damga "u70-$key"
     msg="⚠️ BAĞLAM %${pct} DOLU — yakında compact gerekecek; çıpalar tazeleniyor. (baglam-nobeti · pencere $((pencere/1000))k·${kaynak} · ${model}) KURAL: bu satır cevabının İLK satırı olsun; çıpanı diske yaz (cipa-bul.sh hangi dosyalar olduğunu söyler), soru AÇMA, işine devam et." ;;
  2) taze "u80-$key" "${BAGLAM_NOBETI_COMPACT_SN:-90}" && exit 0; damga "u80-$key"
     ek=""; [ "${pct:-0}" -ge "${BAGLAM_ESIK_DUR:-90}" ] && ek=' Ayrıca: "yeni büyük iş almıyorum; önce compact" — gerçekten yeni büyük iş başlatma.'
     msg="🔴 BAĞLAM %${pct} DOLU — COMPACT ÖNERİYORUM. (baglam-nobeti · pencere $((pencere/1000))k·${kaynak} · ${model}) KURAL: cevabının İLK satırı, kalın, başka her şeyden önce: **🔴 BAĞLAM %${pct} DOLU — COMPACT ÖNERİYORUM. Çıpalar tazelendi (…); \"/compact\" deyin, kaldığım yerden aynen sürerim.** Bu satırı Sultan compact deyene kadar HER cevapta tekrarla. Çıpalar (cipa-bul.sh) yazılmadan 'tazelendi' deme.${ek}" ;;
  *) taze "olc-$key" "${BAGLAM_NOBETI_OLCULEMEDI_SN:-900}" && exit 0; damga "olc-$key"
     sebep="$(printf '%s' "$olcum" | sed -n 's/.*sebep=\([^ ]*\).*/\1/p')"
     [ "$sebep" = "pencere-bilinmiyor" ] || exit 0
     msg="ℹ️ baglam-nobeti: bağlam doluluğu ÖLÇÜLEMEDİ — model '${model}' için pencere kanonda yok (${sebep}). Bu sessizlik 'temiz' demek DEĞİL; /context ile kendin bak ya da BAGLAM_PENCERE=<pencere> ver." ;;
esac

python3 -c 'import sys,json
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":sys.argv[1]}},ensure_ascii=False))' "$msg"
exit 0
