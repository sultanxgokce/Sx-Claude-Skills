#!/usr/bin/env bash
# mesveret.sh — Meşveret Seansı (Kuzey Yıldızı 1.2): Sultan'la madde madde bulgu toplama seansının diskteki kaydı.
# Yeni defter KURMAZ: madde Bulgu Havuzu'na `bulgu.sh yaz` ile düşer (merkezî görev defteri, havuz durumu);
# önem Sultan'ın sözüyle D1 adımı olarak `gorev.sh adim` ile işlenir (A06: önem uydurulmaz).
# rc: 0 tamam · 2 kullanım · 3 Bulgu Defteri kurulu değil / seans yok · 4 kayıt yazıldı ama önem adımı yazılamadı
set -uo pipefail

KOK="${MESVERET_KOK:-$HOME/.cache/mesveret}"
BULGU="${MESVERET_BULGU:-/config/.claude/skills/bulgu/scripts/bulgu.sh}"
GOREV="${MESVERET_GOREV:-}"
if [ -z "$GOREV" ]; then
  for c in /config/.claude/skills/gunluk-plan/scripts/gorev.sh /config/projects/cloudtop/infra/defter-gecit/gorev/gorev.sh; do
    [ -f "$c" ] && { GOREV="$c"; break; }
  done
fi
SAAT="${MESVERET_SAAT:-}"   # sınav için sabit zaman
now() { [ -n "$SAAT" ] && echo "$SAAT" || date -Iseconds; }
gun() { [ -n "$SAAT" ] && echo "${SAAT:0:10}" || date +%F; }
kullanim() {
  cat <<'K' >&2
kullanım:
  mesveret.sh basla [--oda <oda>] [--konu "…"]
  mesveret.sh madde <seans> "<başlık>" --kim <AD> --etiket bug|ozellik --sik A|B|C [--not "…"] [--gorsel <yol>] [--oda <oda>]
  mesveret.sh onem  <seans> <madde-no> --onem 1|2|3 --soz "<Sultan sözü>" --oturum <ref> [--beyan <AD>]
  mesveret.sh durum <seans> · bitir <seans> · liste
K
  exit 2
}
seans_yolu() { echo "$KOK/$1.json"; }
# Değişmez 1: her madde AYNI şablonla açılır — şablon tek yerde yaşar
sablon() { echo "🔎 **Madde $1'i çalışıyoruz**" >&2; echo "A) Sen anlat · B) Ben önereyim · C) Etkileşimli gidelim" >&2; }
seans_var() { [ -f "$(seans_yolu "$1")" ] || { echo "⛔ seans yok: $1 ($KOK)" >&2; exit 3; }; }
py() { python3 - "$@"; }

cmd="${1:-}"; [ -n "$cmd" ] || kullanim; shift
case "$cmd" in
  basla)
    oda=""; konu=""
    while [ $# -gt 0 ]; do case "$1" in
      --oda) [ $# -ge 2 ] || kullanim; oda="$2"; shift 2;;
      --konu) [ $# -ge 2 ] || kullanim; konu="$2"; shift 2;;
      *) kullanim;; esac; done
    [ -x "$BULGU" ] || { echo "⛔ bulgu.sh yok ($BULGU) — Bulgu Havuzu'na yazılamaz, seans açılmadı" >&2; exit 3; }
    mkdir -p "$KOK"
    id="mes_$(gun)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    py "$(seans_yolu "$id")" "$id" "$oda" "$konu" "$(now)" <<'PY'
import json,sys
p,id,oda,konu,t=sys.argv[1:6]
json.dump({"seans":id,"acilis":t,"oda":oda,"konu":konu,"maddeler":[],"durum":"acik"},open(p,"w"),ensure_ascii=False,indent=1)
PY
    echo "$id"
    sablon 1
    ;;
  madde)
    [ $# -ge 2 ] || kullanim; seans="$1"; baslik="$2"; shift 2
    kim=""; etiket=""; sik=""; notu=""; gorsel=""; oda=""
    while [ $# -gt 0 ]; do case "$1" in
      --kim) [ $# -ge 2 ] || kullanim; kim="$2"; shift 2;;
      --etiket) [ $# -ge 2 ] || kullanim; etiket="$2"; shift 2;;
      --sik) [ $# -ge 2 ] || kullanim; sik="$2"; shift 2;;
      --not) [ $# -ge 2 ] || kullanim; notu="$2"; shift 2;;
      --gorsel) [ $# -ge 2 ] || kullanim; gorsel="$2"; shift 2;;
      --oda) [ $# -ge 2 ] || kullanim; oda="$2"; shift 2;;
      *) kullanim;; esac; done
    seans_var "$seans"
    [ -n "$kim" ] || { echo "--kim zorunlu" >&2; exit 2; }
    case "$etiket" in bug|ozellik) ;; *) echo "--etiket bug ya da ozellik" >&2; exit 2;; esac
    # G2: Sultan'ın o maddede seçtiği şık (A sen anlat · B ben önereyim · C etkileşimli) kayıtsız madde yazılmaz
    case "$sik" in A|B|C) ;; *) echo "--sik A, B ya da C (Sultan'ın seçtiği şık) zorunlu; madde yazılmadı" >&2; exit 2;; esac
    [ ${#baslik} -ge 5 ] || { echo "başlık çok kısa" >&2; exit 2; }
    [ -x "$BULGU" ] || { echo "⛔ bulgu.sh yok ($BULGU) — madde kaydedilmedi" >&2; exit 3; }
    no=$(py "$(seans_yolu "$seans")" <<'PY'
import json,sys; print(len(json.load(open(sys.argv[1]))["maddeler"])+1)
PY
)
    [ -z "$oda" ] && oda=$(py "$(seans_yolu "$seans")" <<'PY'
import json,sys; print(json.load(open(sys.argv[1])).get("oda",""))
PY
)
    tam_not="Meşveret Seansı $seans · madde $no · şık: $sik · önem: sorulmadı"
    [ -n "$notu" ] && tam_not="$notu — $tam_not"
    [ -n "$gorsel" ] && tam_not="$tam_not · görsel: $gorsel"
    args=(yaz "$baslik" --kim "$kim" --etiket "$etiket" --not "$tam_not")
    [ -n "$oda" ] && args+=(--oda "$oda")
    cikti=$("$BULGU" "${args[@]}" 2>&1); rc=$?
    if [ $rc -ne 0 ]; then echo "⛔ Bulgu Havuzu'na yazılamadı (rc=$rc): $cikti" >&2; exit 3; fi
    gid=$(printf '%s\n' "$cikti" | grep -oE 'gorev_[0-9A-Z]+' | head -1)
    [ -n "$gid" ] || { echo "⛔ Bulgu Havuzu kayıt kimliği okunamadı (bulgu.sh çıktısı: ${cikti:0:120}) — madde seansa YAZILMADI" >&2; exit 3; }
    py "$(seans_yolu "$seans")" "$no" "$baslik" "$gid" "$etiket" "$gorsel" "$(now)" "$sik" <<'PY'
import json,sys
p,no,baslik,gid,etiket,gorsel,t,sik=sys.argv[1:9]
d=json.load(open(p)); d["maddeler"].append({"no":int(no),"baslik":baslik,"gorev":gid,"etiket":etiket,"gorsel":gorsel,"sik":sik,"zaman":t,"onem":None})
json.dump(d,open(p,"w"),ensure_ascii=False,indent=1)
PY
    echo "madde $no kaydedildi → ${gid:-?} (havuz)"
    echo "Bu maddenin önemi? 1 (düşük) · 2 (orta) · 3 (yüksek)" >&2
    ;;
  onem)
    [ $# -ge 2 ] || kullanim; seans="$1"; no="$2"; shift 2
    onem=""; soz=""; oturum=""; beyan="${AGENT_NAME:-REİS}"
    while [ $# -gt 0 ]; do case "$1" in
      --onem) [ $# -ge 2 ] || kullanim; onem="$2"; shift 2;;
      --soz) [ $# -ge 2 ] || kullanim; soz="$2"; shift 2;;
      --oturum) [ $# -ge 2 ] || kullanim; oturum="$2"; shift 2;;
      --beyan) [ $# -ge 2 ] || kullanim; beyan="$2"; shift 2;;
      *) kullanim;; esac; done
    seans_var "$seans"
    case "$onem" in 1|2|3) ;; *) echo "--onem 1, 2 ya da 3" >&2; exit 2;; esac
    # A06: Sultan'ın sözü ve oturum referansı olmadan önem YAZILMAZ — reis önemi üretemez.
    [ -n "$soz" ] && [ -n "$oturum" ] || { echo "⛔ A06: --soz (Sultan'ın verbatim sözü) ve --oturum (ref) zorunlu; önem yazılmadı" >&2; exit 2; }
    gid=$(py "$(seans_yolu "$seans")" "$no" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); m=[x for x in d["maddeler"] if x["no"]==int(sys.argv[2])]
print(m[0]["gorev"] if m else "")
PY
)
    [ -n "$gid" ] || { echo "⛔ madde $no bu seansta yok" >&2; exit 3; }
    d1="D1 $(gun) Sultan: önem $onem (sohbet · $oturum · \"$soz\" · beyan:$beyan) · Meşveret $seans madde $no"
    rc=0
    if [ -n "$GOREV" ] && [ -f "$GOREV" ]; then
      bash "$GOREV" adim "$gid" "$d1" >/dev/null 2>&1 || rc=4
    else rc=4; fi
    # Havuza işlenmeyen önem seansa da işlenmez: durum/özet havuzla ayrışmasın (göz tur 1, bulgu 1)
    if [ $rc -eq 4 ]; then echo "⚠ önem görevin adımına İŞLENEMEDİ ($gid) — gorev.sh yok ya da reddetti; seansta 'sorulmadı' kaldı, yeniden dene" >&2; exit 4; fi
    py "$(seans_yolu "$seans")" "$no" "$onem" "$soz" "$oturum" <<'PY'
import json,sys
p,no,onem,soz,ot=sys.argv[1:6]
d=json.load(open(p))
for m in d["maddeler"]:
    if m["no"]==int(no): m["onem"]=int(onem); m["onem_soz"]=soz; m["onem_oturum"]=ot
json.dump(d,open(p,"w"),ensure_ascii=False,indent=1)
PY
    echo "madde $no önem $onem → $gid (D1 adımı yazıldı)"
    sablon "$((no+1))"
    ;;
  durum)
    [ $# -ge 1 ] || kullanim; seans_var "$1"
    py "$(seans_yolu "$1")" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); m=d["maddeler"]; eksik=[x["no"] for x in m if x["onem"] is None]
print(f"seans={d['seans']} durum={d['durum']} oda={d.get('oda','') or '-'} madde={len(m)} onem_eksik={len(eksik)} sıradaki={len(m)+1}")
for x in m: print(f"  {x['no']}. {x['baslik']} → {x['gorev'] or '?'} · şık {x.get('sik') or '?'} · önem {x['onem'] if x['onem'] is not None else 'sorulmadı'}")
PY
    ;;
  bitir)
    [ $# -ge 1 ] || kullanim; seans_var "$1"
    py "$(seans_yolu "$1")" "$(now)" <<'PY'
import json,sys
p,t=sys.argv[1:3]; d=json.load(open(p)); d["durum"]="bitti"; d["kapanis"]=t
json.dump(d,open(p,"w"),ensure_ascii=False,indent=1)
m=d["maddeler"]; eksik=[x["no"] for x in m if x["onem"] is None]
print(f"Meşveret Seansı bitti: {len(m)} madde kaydedildi · görevler: {' '.join((x['gorev'] or '?')[-6:] for x in m) or '-'} · önemi sorulmayan: {len(eksik)} · şıklar: {' '.join(x.get('sik') or '?' for x in m) or '-'}")
PY
    ;;
  liste)
    mkdir -p "$KOK"; ls -1 "$KOK"/mes_*.json 2>/dev/null | while read -r f; do
      py "$f" <<'PY'
import json,sys; d=json.load(open(sys.argv[1])); print(f"{d['seans']}\t{d['durum']}\t{len(d['maddeler'])} madde\t{d.get('konu','')}")
PY
    done
    ;;
  *) kullanim;;
esac
