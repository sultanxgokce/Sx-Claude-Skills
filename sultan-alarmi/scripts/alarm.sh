#!/usr/bin/env bash
# sultan-alarmi — Sultan yüzünden duran iş için TEK biçimli alarm: terminal kırmızı satır + (isteğe bağlı) telefon + tekrar sınırı + yükseltme.
#   alarm.sh bicim  --is "<iş>" --kim "<kim duruyor>" --ne "<ne gerekiyor, tek tık>"
#   alarm.sh gonder --is … --kim … --ne … [--telefon] [--kuru] [--tekrar-dk N]    (varsayılan: yalnız terminal; telefon AÇIK istek ister)
#   alarm.sh tara   [--esik-gun N]                                                  (aday listesi; GÖNDERMEZ)
#   alarm.sh ders   "<öğrenilen tek satır>"                                         (SKILL.md ders defterine tarihli satır ekler)
# rc: 0 tamam · 2 kullanım/biçim reddi · 3 ölçülemedi (tara: hiçbir kaynak okunamadı)
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DIZIN="${SULTAN_ALARMI_DIZIN:-${HOME:-/tmp}/.cache/sultan-alarmi}"
WA="${SULTAN_ALARMI_WA:-/config/.claude/skills/whatsapp-gonder/scripts/wa-gonder.sh}"   # tek telefon kanalı (Sultan 31 Eki: ntfy kullanmıyor)
GOREV_SH="${SULTAN_ALARMI_GOREV_SH:-/config/projects/cloudtop/infra/defter-gecit/gorev/gorev.sh}"
KAPIMDA_SH="${SULTAN_ALARMI_KAPIMDA_SH:-/config/.claude/skills/kapimda/scripts/kapimda.sh}"
SIMDI="${SULTAN_ALARMI_SIMDI:-$(date +%s)}"
TEKRAR_DK_VARS="${SULTAN_ALARMI_TEKRAR_DK:-60}"; YUKSELT_N="${SULTAN_ALARMI_YUKSELT_N:-3}"
kullanim(){ sed -n 2,7p "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
CMD="${1:-}"; [ -n "$CMD" ] && shift || kullanim

IS=""; KIM=""; NE=""; TEL=0; KURU=0; TEKRAR_DK="$TEKRAR_DK_VARS"; ESIK_GUN=1
while [ $# -gt 0 ]; do case "$1" in
  --is|--kim|--ne|--tekrar-dk|--esik-gun) [ $# -ge 2 ] || { echo "değer eksik: $1" >&2; exit 2; }
     case "$1" in --is) IS="$2" ;; --kim) KIM="$2" ;; --ne) NE="$2" ;; --tekrar-dk) TEKRAR_DK="$2" ;; --esik-gun) ESIK_GUN="$2" ;; esac; shift 2 ;;
  --telefon) TEL=1; shift ;; --kuru) KURU=1; shift ;;
  *) [ "$CMD" = ders ] && [ -z "$IS" ] && { IS="$1"; shift; continue; }; echo "bilinmeyen: $1" >&2; kullanim ;;
esac; done
case "$TEKRAR_DK$ESIK_GUN" in *[!0-9]*|"") echo "sayı bekleniyor (--tekrar-dk/--esik-gun)" >&2; exit 2 ;; esac

satir_denetle(){  # biçim kapısı: üç alan dolu, tek satır, tavan, sır yok
  local a
  for a in "$IS" "$KIM" "$NE"; do
    [ -n "$a" ] || { echo "RED: üç alan da dolu olmalı (iş · kim duruyor · ne gerekiyor)" >&2; return 2; }
    case "$a" in *$'\n'*) echo "RED: alanlar tek satır olmalı" >&2; return 2 ;; esac
    [ "${#a}" -le 160 ] || { echo "RED: alan 160 karakteri aşıyor" >&2; return 2; }
  done
  printf '%s %s %s' "$IS" "$KIM" "$NE" | grep -qiE 'sk-[a-z0-9]{12,}|ghp_[a-z0-9]{12,}|(password|parola|token|secret)[=:] *[^ ]+' \
    && { echo "RED: alarma sır yazılamaz" >&2; return 2; }
  return 0
}
metin(){ printf '🚨🔴 SULTAN ALARMI — %s · %s · %s' "$IS" "$KIM" "$NE"; }
kutuk(){ mkdir -p "$DIZIN"; python3 - "$DIZIN/kutuk.jsonl" "$SIMDI" "$IS" "$KIM" "$NE" "$1" "$2" "$3" <<'PY'
import sys,json
p,ts,i,k,n,tekrar,tel,not_=sys.argv[1:9]
open(p,'a',encoding='utf-8').write(json.dumps({"ts":int(ts),"is":i,"kim":k,"ne":n,"tekrar":int(tekrar),"telefon":tel,"not":not_},ensure_ascii=False)+"\n")
PY
}

case "$CMD" in
bicim) satir_denetle || exit 2; metin; echo ;;
gonder)
  satir_denetle || exit 2
  mkdir -p "$DIZIN"; ANAHTAR="$(printf '%s' "$IS" | tr 'A-ZÇĞİÖŞÜ' 'a-zçğiöşü' | sha1sum | cut -c1-16)"; DURUM="$DIZIN/durum.tsv"; touch "$DURUM"
  exec 9>>"$DIZIN/durum.kilit"; flock 9   # okuma-karar-yazma tek kilitte: eşzamanlı iki gönderim aynı alarmı iki kez basmasın
  SON=0; SAY=0
  while IFS=$'\t' read -r k s c; do [ "$k" = "$ANAHTAR" ] && { SON="$s"; SAY="$c"; }; done < "$DURUM"
  if [ "$SAY" -gt 0 ] && [ $((SIMDI - SON)) -lt $((TEKRAR_DK * 60)) ]; then
    echo "sustu: '$IS' için alarm $(( (SIMDI - SON) / 60 )) dk önce basıldı (tekrar sınırı $TEKRAR_DK dk)"; kutuk "$SAY" - sustu; exit 0
  fi
  SAY=$((SAY + 1))
  # kuru koşu DURUM yazmaz: yazarsa sonraki gerçek alarm "sustu" olur ve yükseltme sayacı kuruyla artar
  [ "$KURU" -eq 1 ] || { { grep -v "^$ANAHTAR	" "$DURUM" 2>/dev/null; printf '%s\t%s\t%s\n' "$ANAHTAR" "$SIMDI" "$SAY"; } > "$DURUM.yeni" && mv "$DURUM.yeni" "$DURUM"; }
  flock -u 9
  M="$(metin)"
  if [ "$SAY" -ge "$YUKSELT_N" ]; then M="$M · TEKRAR $SAY — YÜKSELTİLDİ"; fi
  if [ -z "${NO_COLOR:-}" ]; then printf '\033[1;31m%s\033[0m\n' "$M"; else printf '%s\n' "$M"; fi
  if [ "$TEL" -eq 0 ]; then kutuk "$SAY" yok terminal; exit 0; fi
  if [ "${SULTAN_EKRANDA:-0}" = 1 ]; then echo "(telefon atlandı: Sultan ekranda)"; kutuk "$SAY" atlandi ekranda; exit 0; fi
  if [ "$KURU" -eq 1 ]; then echo "(kuru: telefona gidecekti → WhatsApp)"; kutuk "$SAY" kuru -; exit 0; fi
  # ntfy çıkarıldı: http 200'ü Sultan'a ulaştı demek değildi (31 Eki ölçümü: 22 'gitti' alarmın hiçbiri görülmedi).
  bash "$WA" "$M" >/dev/null 2>&1; WA_RC=$?
  if [ "$WA_RC" -eq 0 ]; then echo "whatsapp: gitti"; kutuk "$SAY" gitti "wa=0"
  else kutuk "$SAY" hata "wa=$WA_RC"; echo "UYARI: telefon bildirimi gitmedi (WhatsApp rc=$WA_RC); terminal satırı basıldı" >&2; exit 0; fi ;;
tara)
  OK=0; KAY=""
  if K="$("$KAPIMDA_SH" liste 2>/dev/null)"; then OK=1
    while IFS= read -r l; do case "$l" in "🚦 SENDE · "*) a="${l#🚦 SENDE · }"; printf 'ADAY|%s|Sultan kapısı|kapımda kartını aç: kapimda liste\n' "$a" ;; esac; done <<<"$K"
  else KAY="$KAY kapımda"; fi
  if G="$("$GOREV_SH" liste 2>/dev/null)"; then OK=1
    BUGUN="$(date -d "@$SIMDI" +%F)"
    while IFS= read -r l; do
      set -- $l; [ "${3:-}" = "onay-bekliyor" ] || continue
      TARIH="$(printf '%s' "$l" | grep -o '(son: [0-9-]*' | tail -1 | grep -o '[0-9-]*$')"
      [ -n "$TARIH" ] || { echo "ADAYSIZ|$1|yaş ölçülemedi (son: yok)"; continue; }
      YAS=$(( ( $(date -d "$BUGUN" +%s) - $(date -d "$TARIH" +%s) ) / 86400 ))
      [ "$YAS" -ge "$ESIK_GUN" ] && printf 'ADAY|%s (%s gündür onay bekliyor)|%s|Sultan ekranında onay bekleyenler: tek tık onay ya da ret\n' "$(printf '%s' "$l" | cut -c1-200 | sed 's/^[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *[^ ]* *//; s/  (son:.*//')" "$YAS" "$6"
    done <<<"$G"
  else KAY="$KAY defter"; fi
  echo "ÖLÇEMEDİM: sabah paketi · Engel paneli · Sultan karar soruları · Sultan-eli bekleyen iş (v0.1.0 kapsamında değil; 'aday yok' bu kaynaklar için hüküm DEĞİLDİR)"
  [ -n "$KAY" ] && echo "OKUNAMADI:$KAY"
  [ "$OK" -eq 1 ] || exit 3 ;;
ders)
  [ -n "$IS" ] || kullanim
  D="$KOK/../DERSLER.md"; printf -- '- %s — %s\n' "$(date -d "@$SIMDI" +%F)" "$IS" >> "$D"; echo "ders eklendi: $D" ;;
*) kullanim ;;
esac
