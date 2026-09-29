#!/usr/bin/env bash
# canli-sayfa.sh — filonun CANLI SAYFA kaydı. Her kutu kurduğu canlı sayfayı buraya yazar; kokpitteki
# "Canlı sayfalar" menüsü bu kayıttan beslenir.
#
# KAYIT NEREDE: ortak dizinde, SAYFA BAŞINA BİR DOSYA (varsayılan /config/.claude/canli-sayfalar/<adres>.json).
#   Ortak dizin bütün kutulardan görünür; sayfa başına dosya olduğu için iki kutu aynı anda yazsa da
#   birbirinin kaydını ezmez. Yazma önce geçici dosyaya, sonra yerine taşınarak yapılır.
#
# KOMUTLAR
#   ekle    --adres https://… --ad "Kısa Ad" --ne "tek cümle" --kutu <kutu> --ekleyen <AJAN> [--herkese-acik evet]
#   liste   [--hepsi] [--json]        canlı kayıtlar (--hepsi: emekliler de) · --json: menünün okuduğu biçim
#   emekli  --adres https://… --gerekce "…"    kaydı silmez, durumunu emekli yapar
#   dogrula                           canlı kayıtların hepsini yeniden ölçer
#
# ÖLÇMEDEN KAYDETMEZ: ekle, adresi o an ölçer.
#   · cevap yok / 404 / 5xx                  → canlı değil, KAYDEDİLMEZ (rc 3)
#   · giriş kapısına yönleniyor ya da 401/403 → giriş: kapalı
#   · kapısız açılıyor (2xx)                  → giriş: açık; YALNIZ --herkese-acik evet ile kaydedilir (rc 4).
#     Sebep: kapı arkasında olması gereken bir sayfa kapısız yayına çıkmışsa bunu kayıt anında yakalamak.
#
# ORTAM (yalnız sınav ve kurulum için)
#   CANLI_SAYFA_DIZIN   kayıt dizini
#   CANLI_SAYFA_OLCER   adresi ölçen komut; adres son argüman olarak verilir, "<kod> <yönlenilen adres>" basar
# rc: 0 tamam · 1 doğrulamada sorunlu kayıt var / bozuk kayıt var · 2 kullanım ya da kural ihlali
#     3 ölçülemedi ya da canlı değil · 4 kapısız sayfa onaysız
set -uo pipefail
DIZIN="${CANLI_SAYFA_DIZIN:-/config/.claude/canli-sayfalar}"
hata() { echo "✗ $1" >&2; exit "${2:-2}"; }
command -v python3 >/dev/null 2>&1 || hata "ÖLÇÜLEMEDİ · python3 yok; kayıt okunamaz/yazılamaz" 3

olc() {  # olc <adres> → "<giris> <kod>" basar; rc 0 canlı · 3 canlı değil/ölçülemedi
  local a="$1" c kod yon
  if [ -n "${CANLI_SAYFA_OLCER:-}" ]; then c="$(bash -c "$CANLI_SAYFA_OLCER \"\$1\"" _ "$a" 2>/dev/null)"
  else command -v curl >/dev/null 2>&1 || { echo "olculemedi curl-yok"; return 3; }
       c="$(curl -s -o /dev/null -m 15 -w '%{http_code} %{redirect_url}' "$a" 2>/dev/null)"; fi
  kod="${c%% *}"; yon="${c#* }"; [ "$yon" = "$c" ] && yon=""
  case "$kod" in
    2[0-9][0-9]) echo "acik $kod"; return 0 ;;
    401|403) echo "kapali $kod"; return 0 ;;
    30[1-8]) case "$yon" in
               https://*.cloudflareaccess.com/*|*/cdn-cgi/access/login*) echo "kapali $kod"; return 0 ;;
               "") echo "olculemedi $kod-yonlenme-adresi-yok"; return 3 ;;
               *) echo "yonleniyor $kod"; return 0 ;;
             esac ;;
    *) echo "canli-degil ${kod:-cevap-yok}"; return 3 ;;
  esac
}

adres_duzelt() {  # adres_duzelt <ham> → düzgün adresi basar; kurala uymuyorsa rc 2
  python3 - "$1" <<'PY'
import re, sys
from urllib.parse import urlsplit
h = sys.argv[1].strip()
u = urlsplit(h)
if u.scheme != "https": sys.exit("adres https:// ile başlamalı")
if u.query or u.fragment or "?" in h or "#" in h: sys.exit("adreste soru işareti ya da # olamaz (adres satırı anahtar taşıyabilir)")
if u.username or u.password or "@" in u.netloc: sys.exit("adreste kullanıcı adı/parola olamaz")
if u.port: sys.exit("adreste port olamaz (canlı sayfa alan adıyla açılır)")
k = (u.hostname or "").lower()
if not re.fullmatch(r"([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}", k): sys.exit("alan adı düzgün değil: " + k)
y = u.path.rstrip("/")
if not re.fullmatch(r"(/[A-Za-z0-9._~-]+)*", y): sys.exit("adres yolu yalnız harf, rakam, nokta, tire içerebilir")
if any(p in (".", "..") for p in y.split("/")): sys.exit("adres yolunda . ya da .. olamaz")
print("https://" + k + y)
PY
}
dosya_adi() { printf '%s' "${1#https://}" | sed 's/[^a-z0-9A-Z.-]/_/g'; }

metin_denetle() {  # metin_denetle <alan> <değer> <en çok> → kurala uymuyorsa çıkar
  local alan="$1" d="$2" n="$3"
  [ -n "$d" ] || hata "$alan boş olamaz"
  [ "${#d}" -le "$n" ] || hata "$alan en çok $n karakter olabilir (${#d})"
  case "$d" in *$'\n'*|*$'\t'*) hata "$alan tek satır olmalı" ;; esac
  # Sultan'ın okuyacağı metin: dosya yolu, komut, kod imi olmaz
  if printf '%s' "$d" | grep -qE '`|\$\(|(^|[[:space:]])/[a-z]+/|\.(sh|py|js|json|md|yaml)([[:space:]]|$)|https?://'; then
    hata "$alan Sultan'ın okuyacağı dille yazılmalı: dosya yolu, komut, adres ya da kod imi içeremez"; fi
  # sır deseni: değer basılmadan reddedilir
  if printf '%s' "$d" | grep -qEi '(parola|sifre|şifre|password|token|secret|apikey|api_key)[[:space:]]*[:=]|sk-[A-Za-z0-9]{16,}|[A-Za-z0-9+/_-]{32,}'; then
    hata "$alan sır gibi görünen bir değer içeriyor (değer basılmadı)"; fi
}

yaz() {  # yaz <dosya> <json metni> → atomik
  mkdir -p "$DIZIN" 2>/dev/null || hata "kayıt dizini açılamadı: $DIZIN" 3
  local g="$DIZIN/.$(basename "$1").$$.yeni"
  printf '%s\n' "$2" > "$g" 2>/dev/null && mv -fT "$g" "$1" 2>/dev/null || { find "$g" -delete 2>/dev/null; hata "kayıt yazılamadı: $1" 3; }
  # yazdığını geri oku: "yazdım" demek yetmez
  python3 -c 'import json,sys; json.load(open(sys.argv[1],encoding="utf-8"))' "$1" 2>/dev/null || hata "kayıt yazıldı ama geri okunamadı: $1" 3
}

topla() {  # topla <hepsi:0|1> → JSON: {"sayfalar":[…],"bozuk":[dosya adları]}
  python3 - "$DIZIN" "$1" <<'PY'
import glob, json, os, sys
d, hepsi = sys.argv[1], sys.argv[2] == "1"
S, B = [], []
ALAN = ("adres", "ad", "ne", "kutu", "ekleyen", "giris", "durum", "eklendi")
for f in sorted(glob.glob(os.path.join(d, "*.json"))):
    try:
        k = json.load(open(f, encoding="utf-8"))
        if not all(isinstance(k.get(a), str) and k[a] for a in ALAN): raise ValueError
        if k["durum"] not in ("canli", "emekli") or not k["adres"].startswith("https://"): raise ValueError
    except Exception:
        B.append(os.path.basename(f)); continue
    if hepsi or k["durum"] == "canli": S.append(k)
S.sort(key=lambda k: (k["kutu"], k["ad"].lower()))
print(json.dumps({"sayfalar": S, "bozuk": B}, ensure_ascii=False))
PY
}

komut="${1:-}"; [ "$#" -gt 0 ] && shift
adres=""; ad=""; ne=""; kutu=""; ekleyen=""; acik=""; gerekce=""; hepsi=0; json=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --adres) adres="${2:-}"; shift 2 ;;   --ad) ad="${2:-}"; shift 2 ;;
    --ne) ne="${2:-}"; shift 2 ;;         --kutu) kutu="${2:-}"; shift 2 ;;
    --ekleyen) ekleyen="${2:-}"; shift 2 ;; --herkese-acik) acik="${2:-}"; shift 2 ;;
    --gerekce) gerekce="${2:-}"; shift 2 ;; --hepsi) hepsi=1; shift ;;
    --json) json=1; shift ;;
    *) hata "tanınmayan bayrak: $1" ;;
  esac
done

case "$komut" in
  ekle)
    [ -n "$adres" ] || hata "--adres gerekli"
    a="$(adres_duzelt "$adres" 2>&1)" || hata "adres kurala uymuyor: $a"
    metin_denetle "ad" "$ad" 40; metin_denetle "ne" "$ne" 140
    [ "$(printf '%s' "$ad" | wc -w)" -le 4 ] || hata "ad en çok dört kelime olabilir"
    printf '%s' "$kutu" | grep -qE '^[a-z0-9][a-z0-9-]{0,30}$' || hata "--kutu gerekli (küçük harf, rakam, tire): hangi kutunun sayfası"
    printf '%s' "$ekleyen" | grep -qE '^[A-Za-zÇĞİÖŞÜÂÎÛçğıöşüâîû-]{2,24}$' || hata "--ekleyen gerekli: kaydı yazan ajanın adı"
    o="$(olc "$a")"; r=$?
    [ "$r" -eq 0 ] || hata "CANLI DEĞİL ya da ölçülemedi ($o): $a — sayfa açılmadan kayda girmez" 3
    giris="${o%% *}"
    if [ "$giris" = acik ] && [ "$acik" != evet ]; then
      hata "bu sayfa GİRİŞ KAPISI OLMADAN açılıyor ($o): $a — bilerek herkese açıksa --herkese-acik evet ile yeniden kaydet; değilse önce giriş kapısını kur" 4
    fi
    f="$DIZIN/$(dosya_adi "$a").json"
    j="$(python3 - "$f" "$a" "$ad" "$ne" "$kutu" "$ekleyen" "$giris" <<'PY'
import json, sys, datetime
f, a, ad, ne, kutu, ek, giris = sys.argv[1:8]
simdi = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
try: eski = json.load(open(f, encoding="utf-8"))
except Exception: eski = {}
k = {"v": 1, "adres": a, "ad": ad, "ne": ne, "kutu": kutu, "ekleyen": ek, "giris": giris, "durum": "canli",
     "eklendi": eski.get("eklendi") if isinstance(eski.get("eklendi"), str) and eski.get("eklendi") else simdi,
     "olculdu": simdi}
print(json.dumps(k, ensure_ascii=False))
PY
    )" || hata "kayıt üretilemedi" 3
    yaz "$f" "$j"
    echo "✓ kayda girdi: $ad · $a · giriş: $giris · kutu: $kutu"
    echo "  kokpitteki Canlı sayfalar menüsünde görünür (menü kaydı en geç birkaç dakikada okur)"
    ;;
  emekli)
    [ -n "$adres" ] || hata "--adres gerekli"
    a="$(adres_duzelt "$adres" 2>&1)" || hata "adres kurala uymuyor: $a"
    [ "${#gerekce}" -ge 10 ] || hata "--gerekce gerekli (en az 10 karakter): sayfa niçin kalktı"
    f="$DIZIN/$(dosya_adi "$a").json"; [ -f "$f" ] || hata "böyle bir kayıt yok: $a" 1
    j="$(python3 - "$f" "$gerekce" <<'PY'
import json, sys, datetime
k = json.load(open(sys.argv[1], encoding="utf-8"))
k["durum"] = "emekli"; k["emekli_gerekce"] = sys.argv[2]
k["emekli_oldu"] = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
print(json.dumps(k, ensure_ascii=False))
PY
    )" || hata "kayıt okunamadı: $f" 3
    yaz "$f" "$j"; echo "✓ emekli edildi: $a (kayıt duruyor, menüden kalktı)"
    ;;
  liste)
    t="$(topla "$hepsi")" || hata "kayıt okunamadı" 3
    if [ "$json" -eq 1 ]; then printf '%s\n' "$t"
    else python3 - "$t" "$DIZIN" <<'PY'
import json, sys
t = json.loads(sys.argv[1])
print(f"canlı sayfalar · kayıt: {sys.argv[2]}")
for k in t["sayfalar"]:
    im = {"kapali": "kapı arkasında", "acik": "HERKESE AÇIK", "yonleniyor": "yönleniyor"}.get(k["giris"], k["giris"])
    print(f"  {k['kutu']:<10} {k['ad']:<28} {k['adres']}  ({im}{' · emekli' if k['durum'] == 'emekli' else ''})")
    print(f"  {'':<10} {k['ne']}")
print(f"── {len(t['sayfalar'])} sayfa" + (f" · BOZUK KAYIT: {len(t['bozuk'])} ({', '.join(t['bozuk'])})" if t["bozuk"] else ""))
PY
    fi
    printf '%s' "$t" | python3 -c 'import json,sys; sys.exit(1 if json.load(sys.stdin)["bozuk"] else 0)' || exit 1
    ;;
  dogrula)
    t="$(topla 0)" || hata "kayıt okunamadı" 3
    k=0; n=0
    while IFS=$'\t' read -r a g ad; do
      [ -n "$a" ] || continue; n=$((n + 1))
      o="$(olc "$a")"; r=$?; y="${o%% *}"
      if [ "$r" -ne 0 ]; then echo "✗ AÇILMIYOR   $ad · $a ($o)"; k=1
      elif [ "$y" != "$g" ]; then echo "✗ KAPI DEĞİŞTİ $ad · $a (kayıtta: $g · şimdi: $y)"; k=1
      else echo "✓ $ad · $a ($o)"; fi
    done < <(printf '%s' "$t" | python3 -c 'import json,sys
for k in json.load(sys.stdin)["sayfalar"]: print(k["adres"], k["giris"], k["ad"], sep="\t")')
    b="$(printf '%s' "$t" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["bozuk"]))')"
    [ "$b" -eq 0 ] || { echo "✗ bozuk kayıt: $b"; k=1; }
    echo "── $n sayfa ölçüldü"
    exit "$k"
    ;;
  *) echo "kullanım: canli-sayfa.sh ekle|liste|emekli|dogrula  (ayrıntı: dosyanın başı)" >&2; exit 2 ;;
esac
exit 0
