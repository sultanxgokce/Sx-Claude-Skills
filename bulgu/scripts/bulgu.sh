#!/usr/bin/env bash
# bulgu.sh — filonun tek bulgu komutu (Sultan /goal K2). Kutunun kendi Bulgu Defteri'ne, defterin KENDİ
# kilitli yazıcısıyla (defter-yaz.py) yazar. Yeni yazıcı icat etmez; yalnız kapıdır.
# rc: 0 tamam · 1 yazıcı hatası · 2 kullanım · 3 bu kutuda defter kurulu değil (hiçbir şey yazılmadı)
set -uo pipefail
KOK="${BULGU_KOK:-/config/.ic-sayfa}"
YAZ="$KOK/defter-yaz.py"
JSON="$KOK/bulgu-defteri/bulgular.json"
ALANLAR="id no sayi baslik hal surum acan kaynak acilis tur notlar gecisler"
_kur_yok() { echo "⛔ bu kutuda Bulgu Defteri kurulu değil ($YAZ yok) — hiçbir şey yazılmadı. SERDAR'a yaz: kur.sh --kutu <kutu>" >&2; exit 3; }
k="${1:-}"; shift || true
case "$k" in
  yaz)
    baslik="${1:-}"; shift || true
    [ -n "$baslik" ] || { echo "kullanım: bulgu.sh yaz \"<başlık>\" --kim <AJAN> [--not \"…\"] [--etiket bug|ozellik]" >&2; exit 2; }
    kim=""; notu=""; etiket="bug"
    while [ $# -gt 0 ]; do case "$1" in
      --kim) [ $# -ge 2 ] || { echo "--kim değersiz" >&2; exit 2; }; kim="$2"; shift 2 ;;
      --not) [ $# -ge 2 ] || { echo "--not değersiz" >&2; exit 2; }; notu="$2"; shift 2 ;;
      --etiket) [ $# -ge 2 ] || { echo "--etiket değersiz" >&2; exit 2; }; etiket="$2"; shift 2 ;;
      *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
    [ -n "$kim" ] || { echo "--kim zorunlu (kaydı kim açıyor?)" >&2; exit 2; }
    case "$etiket" in bug|ozellik) ;; *) echo "--etiket bug ya da ozellik olmalı (K1: bulgu = bu iki etiketten biriyle görev)" >&2; exit 2 ;; esac
    # ── K1 (Sultan 14 Eki 2026, S-17): bulgu = türü bug/özellik olan GÖREV; TEK defter merkezî Görev Defteri'dir.
    #    Kutuda defter jetonu varsa kayıt ORAYA gider (kutu jetondan türer, beyan edilmez; kaynak_nereden = "bulgu komutu").
    #    Jeton yoksa eski kutu defterine düşer ve bunu SÖYLER — sessiz ikilik yok. Jeton değeri argv'ye/çıktıya düşmez (curl --config).
    JY="${DEFTER_JETON_YOL:-/config/defter-jeton}"; UC="${DEFTER_UC:-http://cloudtop-defter:8791}"
    if [ -r "$JY" ]; then
      govde="$(python3 -c 'import sys,json
b,kim,notu,et=sys.argv[1:5]
d={"tur":"gorev","adlar":[b],"etiket":et,"kaynak_kim":kim,"kaynak_nereden":"bulgu komutu","gorev_durumu":"acik"}
if notu.strip(): d["adimlar"]=["[kanıt] "+notu.strip()]
print(json.dumps(d,ensure_ascii=False))' "$baslik" "$kim" "$notu" "$etiket")"
      cfg="$(mktemp)"; trap 'rm -f -- "$cfg"' EXIT
      printf 'header = "x-defter-jeton: %s"\n' "$(tr -d '\n' < "$JY")" > "$cfg"
      cevap="$(curl -sS -m 15 --config "$cfg" -X POST -H 'content-type: application/json' --data-binary "$govde" "$UC/kayit" -w '\n%{http_code}' 2>&1)"; rc=$?
      rm -f -- "$cfg"
      if [ $rc -ne 0 ]; then echo "⛔ merkezî Görev Defteri'ne ulaşılamadı ($UC): $cevap — kayıt YAZILMADI (eski deftere de düşmedi: ikilik olmasın; sonra yeniden dene ya da SERDAR'a yaz)" >&2; exit 1; fi
      printf '%s' "$cevap" | python3 -c '
import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
try: j=json.loads(g or "{}")
except Exception: j={"hata":"yanit_bozuk"}
if kod!="201": print("⛔ merkezî defter reddetti http=%s · %s · %s" % (kod, j.get("hata"), j.get("bekleniyor") or j.get("alanlar") or ""), file=sys.stderr); sys.exit(1)
k=j["kayit"]; print("📌 %s · %s · %s — %s (açan: %s) · Görev Defteri" % (k["id"], k["canli"].get("kutu") or k.get("ekleyen_kutu"), k["canli"].get("etiket"), k["adlar"][0]["deger"], k["canli"].get("kaynak_kim")))'
    else
      [ -f "$YAZ" ] || _kur_yok
      echo "ℹ bu kutuda defter jetonu yok ($JY) — kayıt ESKİ kutu defterine yazılıyor (merkeze taşınması için SERDAR'a: jeton-dagit)" >&2
      if [ -n "$notu" ]; then python3 "$YAZ" yeni --baslik "$baslik" --kim "$kim" --not "$notu" --kok "$KOK"
      else python3 "$YAZ" yeni --baslik "$baslik" --kim "$kim" --kok "$KOK"; fi
    fi ;;
  liste)
    [ -f "$YAZ" ] || _kur_yok; python3 "$YAZ" listele --kok "$KOK" ;;
  hal)
    # Hâl geçişi (13 Eki, MUAVİN): acik → uygulandi → canli; 'onaylandi' İNSANINDIR (A06) — bu kapı onu reddeder.
    [ -f "$YAZ" ] || _kur_yok
    no="${1:-}"; yeni="${2:-}"; shift 2 2>/dev/null || { echo "kullanım: bulgu.sh hal <S-N> <acik|uygulandi|canli> --kim <AJAN> --gerekce \"…\"" >&2; exit 2; }
    case "$yeni" in acik|uygulandi|canli) ;; onaylandi) echo "⛔ 'onaylandi' yalnız insanın tikidir (A06) — ajan yazamaz" >&2; exit 2 ;;
      *) echo "bilinmeyen hâl: $yeni (acik|uygulandi|canli)" >&2; exit 2 ;; esac
    [[ "$no" =~ ^S-[0-9]+$ ]] || { echo "kayıt numarası S-N biçiminde olmalı: $no" >&2; exit 2; }
    kim=""; gerekce=""
    while [ $# -gt 0 ]; do case "$1" in
      --kim) [ $# -ge 2 ] || { echo "--kim değersiz" >&2; exit 2; }; kim="$2"; shift 2 ;;
      --gerekce) [ $# -ge 2 ] || { echo "--gerekce değersiz" >&2; exit 2; }; gerekce="$2"; shift 2 ;;
      *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
    [ -n "$kim" ] || { echo "--kim zorunlu (geçişi kim yapıyor?)" >&2; exit 2; }
    [ -n "$gerekce" ] || { echo "--gerekce zorunlu (niçin bu hâle geçti? kanıt/PR/commit)" >&2; exit 2; }
    python3 "$YAZ" hal "$no" --hal "$yeni" --gerekce "$gerekce" --kim "$kim" --kok "$KOK" ;;
  sema)
    [ -f "${1:-$JSON}" ] || _kur_yok
    python3 - "${1:-$JSON}" "$ALANLAR" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8")); alan = sys.argv[2].split()
b = d.get("bulgular", []) if isinstance(d, dict) else []
ok = [x for x in b if all(k in x for k in alan) and isinstance(x.get("sayi"), int)]
print(json.dumps({"toplam": len(b), "sema_gecen": len(ok), "gecmeyen": len(b) - len(ok),
                  "son_gecen": [x["no"] + " " + str(x.get("acan")) for x in ok[-3:]]}, ensure_ascii=False))
PY
    ;;
  *) sed -n '2,4p' "$0"; echo "komutlar: yaz · liste · hal · sema"; exit 2 ;;
esac
