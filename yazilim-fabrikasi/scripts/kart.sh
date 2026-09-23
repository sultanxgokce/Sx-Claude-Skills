#!/usr/bin/env bash
# kart.sh — fabrika 0. adım (KABUL): iş kartını ARAÇ yazar; sınıfı dört soruyla ARAÇ sorar (K6).
#
# Kartlar BİRİNCİL depo kökünde yaşar: <depo>/_agents/fabrika/kartlar/<iş>.json (worktree'ler ortak görür).
# Dört sınıf sorusu cevapsız kart AÇILMAZ. Biri "e" ya da "?" ise → sultan=true (şüphede sınıf YUKARI).
#
# Kullanım:
#   kart.sh ac <iş> --is "tek cümle" --istedi <kim> --aldi <ajan> \
#          --geri-alinamaz e|h|? --para e|h|? --dis-yuzey e|h|? --yetki e|h|? [--kanit "nerede olacak"] [--oda <oda>]
#   kart.sh bitti <iş> [--pr N]        durum=bitti; son DENETIM puanını ve KANIT durumunu karta işler (worktree'den de çağrılabilir)
#   kart.sh tikandi <iş> --yol devam|daralt|geri-al --neden "..."
#   kart.sh sultan-dedi <iş> --karar <devam|daralt|geri-al> --oturum <ref> --soz "<verbatim ≤15 kelime>" --beyan <AJAN>
#          Sultan'ın SÖZLÜ kararını KARTA işler (D1 deseni). Üç parça zorunlu: oturum-ref · kırpık · beyan.
#          🔴 A06: onay ÜRETMEZ, alınan onayı AKTARIR. Ref'siz beyan sayılmaz; uyduran kartta yakalanır.
#   kart.sh goster <iş> · kart.sh liste [--acik]
# Ortam: FABRIKA_TETIK (oda-tetik.sh yolu; --oda verilirse tetik atılır, düşerse iş düşmez) · KANIT_DEPO
# rc: 0 · 1 kullanım/eksik cevap · 3 ölçülemedi
set -uo pipefail
_hata() { printf '✗ %s\n' "$*" >&2; }
TETIK="${FABRIKA_TETIK:-/config/projects/Nexus/scripts/oda-tetik.sh}"

birincil_kok() {  # worktree içinden çağrılsa da BİRİNCİL depo kökü
  local c; c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  dirname "$c"
}
DEPO="${KANIT_DEPO:-$(birincil_kok)}"; [ -n "$DEPO" ] || { _hata "depo kökü bulunamadı"; exit 3; }
KD="$DEPO/_agents/fabrika/kartlar"; mkdir -p "$KD"

CMD="${1:-}"; IS="${2:-}"; shift 2 2>/dev/null || true
IS_C=""; ISTEDI=""; ALDI=""; GA=""; PARA=""; DIS=""; YETKI=""; KANIT=""; ODA=""; PR=""; YOL=""; NEDEN=""
KARAR=""; OTURUM=""; SOZ=""; BEYAN=""
while [ $# -gt 0 ]; do case "$1" in
  --is) IS_C="$2"; shift 2 ;; --istedi) ISTEDI="$2"; shift 2 ;; --aldi) ALDI="$2"; shift 2 ;;
  --geri-alinamaz) GA="$2"; shift 2 ;; --para) PARA="$2"; shift 2 ;; --dis-yuzey) DIS="$2"; shift 2 ;; --yetki) YETKI="$2"; shift 2 ;;
  --kanit) KANIT="$2"; shift 2 ;; --oda) ODA="$2"; shift 2 ;; --pr) PR="$2"; shift 2 ;; --yol) YOL="$2"; shift 2 ;; --neden) NEDEN="$2"; shift 2 ;;
  --karar) KARAR="$2"; shift 2 ;; --oturum) OTURUM="$2"; shift 2 ;; --soz) SOZ="$2"; shift 2 ;; --beyan) BEYAN="$2"; shift 2 ;;
  --acik) ACIK=1; shift ;; *) _hata "tanınmayan argüman: $1"; exit 1 ;; esac; done

tetik() {  # tetik <oda> <başlık> <gövde>
  [ -n "$1" ] || return 0
  if [ ! -x "$TETIK" ]; then echo "· tetik atılmadı: $TETIK yok (mesaj kartta duruyor)"; return 0; fi
  local f; f="$(mktemp)"; printf '%s\n' "$3" > "$f"
  bash "$TETIK" gonder "$1" "$f" --ajan "${ALDI:-fabrika}" --baslik "$2" >/dev/null 2>&1 && echo "✓ tetik: $1 ← $2" || echo "· tetik düştü (mesaj kartta duruyor, iş düşmez)"
  rm -f "$f"
}

case "$CMD" in
  ac)
    [ -n "$IS" ] && [ -n "$IS_C" ] && [ -n "$ISTEDI" ] && [ -n "$ALDI" ] || { _hata "gerekli: <iş> --is --istedi --aldi"; exit 1; }
    for v in GA PARA DIS YETKI; do case "${!v}" in e|h|\?) ;; *) _hata "dört sınıf sorusu cevapsız kart AÇILMAZ: --geri-alinamaz --para --dis-yuzey --yetki (e|h|?)"; exit 1 ;; esac; done
    [ -f "$KD/$IS.json" ] && { _hata "kart zaten var: $IS (goster ile bak)"; exit 1; }
    python3 - "$KD/$IS.json" "$IS" "$IS_C" "$ISTEDI" "$ALDI" "$GA" "$PARA" "$DIS" "$YETKI" "$KANIT" "$ODA" <<'PY'
import json,sys,datetime
yol,is_,cumle,istedi,aldi,ga,para,dis,yetki,kanit,oda=sys.argv[1:]
cev={"geri_alinamaz":ga,"para":para,"dis_yuzey":dis,"yetki":yetki}
siniflar=[k for k,v in cev.items() if v in("e","?")]
kart={"is":is_,"cumle":cumle,"istedi":istedi,"aldi":aldi,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
      "sinif_cevaplari":cev,"siniflar":siniflar,"sultan":bool(siniflar),"kanit_nerede":kanit,"oda":oda,"durum":"acik","gecmis":[]}
json.dump(kart,open(yol,"w"),ensure_ascii=False,indent=2)
print(f"✓ kart açıldı: {is_} · sınıf: {', '.join(siniflar) if siniflar else 'yok'} · {'SULTAN\'A GİDER' if siniflar else 'ekipte biter, gün sonu özetine girer'}")
PY
    tetik "$ODA" "iş alındı: $IS" "$IS_C · sahip $ALDI · istedi $ISTEDI · sınıf: ${GA}${PARA}${DIS}${YETKI}"
    ;;
  bitti|tikandi)
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    [ "$CMD" = "tikandi" ] && { [ -n "$YOL" ] && [ -n "$NEDEN" ] || { _hata "tikandi --yol devam|daralt|geri-al --neden gerekiyor"; exit 1; }; }
    # kanıt/denetim: çağrıldığı ağaçtan (worktree olabilir) okunur
    WT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEPO")"; DZ="$WT/_agents/fabrika/kanit/$IS"
    python3 - "$KD/$IS.json" "$CMD" "$PR" "$YOL" "$NEDEN" "$DZ" <<'PY'
import json,sys,os,glob,datetime
yol,cmd,pr,yolu,neden,dz=sys.argv[1:]
k=json.load(open(yol)); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
den=sorted(glob.glob(os.path.join(dz,"DENETIM-[0-9]*.json")),key=lambda p:int(p.rsplit("-",1)[1].split(".")[0]))
son=json.load(open(den[-1]))["sonuc"] if den else None
kanit=os.path.exists(os.path.join(dz,"KANIT.json"))
k["durum"]=cmd; k["bitis"]=simdi; k["pr"]=pr or k.get("pr","")
k["puan"]={"kod":son["kod_puani"],"dogru":son["dogru_sey"],"tur":len(den)} if son else None
k["kanit_var"]=kanit
if cmd=="tikandi": k["tikanma"]={"yol":yolu,"neden":neden}
k["gecmis"].append({"zaman":simdi,"olay":cmd})
json.dump(k,open(yol,"w"),ensure_ascii=False,indent=2)
uyari=""
if cmd=="bitti" and not kanit: uyari=" ⚠ KANIT YOK (kanıtsız bitti sayılmaz — gün sonu özetinde işaretlenir)"
if cmd=="bitti" and son and not(son["kod_puani"]==5 and son["dogru_sey"]=="E"): uyari+=" ⚠ son denetim 5+E DEĞİL"
print(f"✓ kart {cmd}: {k['is']} · puan {k['puan']} · kanıt {'var' if kanit else 'YOK'}{uyari}")
PY
    tetik "$(python3 -c "import json;print(json.load(open('$KD/$IS.json')).get('oda',''))")" "iş $CMD: $IS" "$(python3 -c "import json;k=json.load(open('$KD/$IS.json'));print(k['cumle'],'· puan',k.get('puan'),'· pr',k.get('pr'))")"
    ;;
  sultan-dedi)
    # 🔴 Sultan'ın sözlü kararı KARTA girer, komut satırında kalmaz. Niçin: bir yetki kapısını
    #    serbest bir metinle açmak, kapıyı hiç koymamakla neredeyse aynıdır (bağımsız göz,
    #    23 Eyl: "komutu çalıştırabilen herkes 20 karakterlik herhangi bir metinle açabiliyor").
    #    Karta yazmak da uydurmayı imkânsız kılmaz — ama uydurmayı KAYITLI, yapılandırılmış ve
    #    sonradan denetlenebilir bir yalan hâline getirir. A06'nın verebileceği en güçlü şey budur.
    [ -n "$IS" ] || { _hata "iş adı gerekiyor"; exit 1; }
    [ -f "$KD/$IS.json" ] || { _hata "kart YOK: $KD/$IS.json"; exit 1; }
    eksik=""
    [ -n "$KARAR" ] || eksik="$eksik --karar"
    [ -n "$OTURUM" ] || eksik="$eksik --oturum"
    [ -n "$SOZ" ] || eksik="$eksik --soz"
    [ -n "$BEYAN" ] || eksik="$eksik --beyan"
    [ -z "$eksik" ] || { _hata "eksik:$eksik — ref'siz ya da kırpıksız beyan SAYILMAZ (D1 deseni)"; exit 1; }
    python3 - "$KD/$IS.json" "$KARAR" "$OTURUM" "$SOZ" "$BEYAN" <<'PY' || exit 1
import json,sys,datetime
yol,karar,oturum,soz,beyan=sys.argv[1:]
k=json.load(open(yol,encoding="utf-8"))
k.setdefault("sultan_kararlari",[]).append({
  "karar":karar,"oturum":oturum,"soz":soz,"beyan":beyan,
  "zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds")})
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"\u2713 Sultan karari karta islendi: {karar} \u00b7 oturum {oturum} \u00b7 beyan {beyan}")
PY
    ;;
  goster) [ -f "$KD/$IS.json" ] && cat "$KD/$IS.json" || { _hata "kart yok: $IS"; exit 3; } ;;
  liste)
    ls "$KD"/*.json >/dev/null 2>&1 || { echo "◻ kart yok"; exit 0; }
    python3 - "$KD" "${ACIK:-0}" <<'PY'
import json,sys,glob,os
kd,acik=sys.argv[1],sys.argv[2]=="1"
for p in sorted(glob.glob(os.path.join(kd,"*.json"))):
    k=json.load(open(p))
    if acik and k["durum"]!="acik": continue
    print(f"{k['durum']:8} {k['is']:30} {'SULTAN' if k['sultan'] else 'ekip  '} {k['aldi']:10} {k['zaman'][:16]}  {k['cumle'][:60]}")
PY
    ;;
  *) sed -n '1,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
