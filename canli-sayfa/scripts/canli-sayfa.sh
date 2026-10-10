#!/usr/bin/env bash
# canli-sayfa.sh — filonun CANLI SAYFA kaydı. Her kutu kurduğu canlı sayfayı buraya yazar. Kayıt, canlı sayfaların
# tek listesidir; onu okuyan yüzeyler (ör. kokpit menüsü) `liste --json` çıktısını kullanır.
#
# KAYIT NEREDE: ortak dizinde, SAYFA BAŞINA BİR DOSYA (varsayılan /config/.claude/canli-sayfalar/<adres>.json).
#   Ortak dizin bütün kutulardan görünür; sayfa başına dosya olduğu için FARKLI sayfaların kayıtları birbirini
#   etkilemez. AYNI sayfaya iki kutu aynı anda yazarsa dosya başına kilit sırayla yazdırır (denetim tur 3):
#   ikinci yazan birincinin kaydını gördükten sonra yazar, sessiz ezme olmaz. Yazma geçici dosyaya, sonra taşıma.
#   Kilit dosyası (.<kayıt>.kilit) dizinde kalır; silinmez (silmek yeni bir yarış açar), boştur, listeye girmez.
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
#   · 2xx ama GÖVDE KORUMALI (1.2, A314 — MÜCESSEM ölçtü): tarayıcıda betikle yüklenen sayfa (ör. claude.ai artifact)
#     anonim isteğe 200 + boş kabuk döner; kod "açık" der, içerik yoktur. Çare: kaydeden `--imza "<dize>"` verir
#     (sayfanın KENDİ içeriğinden bir dize); araç anonim gövdeyi okur: imza gövdede YOKSA → giriş: kapalı (gövde
#     korumalı), VARSA → gerçekten açık (yine --herkese-acik evet ister). İmza verilmediyse 2xx eski kural (açık).
#     Gövde okunamazsa → ölçülemedi (rc 3); "kapalı" denmez — yanlış-yeşil üretmemek için.
#
# ORTAM (yalnız sınav ve kurulum için)
#   CANLI_SAYFA_DIZIN   kayıt dizini
#   CANLI_SAYFA_OLCER   adresi ölçen komut; adres son argüman olarak verilir, "<kod> <yönlenilen adres>" basar
#   CANLI_SAYFA_GOVDE   anonim gövdeyi basan komut; adres son argüman (varsayılan curl, 2 MB tavan, yönlenme izlenmez)
#   CANLI_SAYFA_KILIT_SURE  aynı sayfanın kilidini en çok kaç saniye beklesin (varsayılan 10)
# rc: 0 tamam · 1 doğrulamada sorunlu kayıt var / bozuk kayıt var · 2 kullanım ya da kural ihlali
#     3 ölçülemedi ya da canlı değil · 4 kapısız sayfa onaysız
set -uo pipefail
DIZIN="${CANLI_SAYFA_DIZIN:-/config/.claude/canli-sayfalar}"
hata() { echo "✗ $1" >&2; exit "${2:-2}"; }
command -v python3 >/dev/null 2>&1 || hata "ÖLÇÜLEMEDİ · python3 yok; kayıt okunamaz/yazılamaz" 3

govde() {  # govde <adres> → anonim gövdeyi stdout'a basar; rc≠0 = okunamadı. Girdi okumaz (dogrula döngüsü).
  if [ -n "${CANLI_SAYFA_GOVDE:-}" ]; then bash -c "$CANLI_SAYFA_GOVDE \"\$1\"" _ "$1" 2>/dev/null </dev/null
  else command -v curl >/dev/null 2>&1 || return 3
       curl -s -m 15 --max-filesize 2000000 "$1" 2>/dev/null </dev/null; fi
}
olc() {  # olc <adres> [imza] → "<giris> <kod>" basar; rc 0 canlı · 3 canlı değil/ölçülemedi
  local a="$1" im="${2:-}" c kod yon g
  # ölçer girdiyi OKUYAMAZ: dogrula kayıtları satır satır okurken ölçer o satırları yutmasın
  if [ -n "${CANLI_SAYFA_OLCER:-}" ]; then c="$(bash -c "$CANLI_SAYFA_OLCER \"\$1\"" _ "$a" 2>/dev/null </dev/null)"
  else command -v curl >/dev/null 2>&1 || { echo "olculemedi curl-yok"; return 3; }
       c="$(curl -s -o /dev/null -m 15 -w '%{http_code} %{redirect_url}' "$a" 2>/dev/null </dev/null)"; fi
  kod="${c%% *}"; yon="${c#* }"; [ "$yon" = "$c" ] && yon=""
  case "$kod" in
    2[0-9][0-9])
      [ -n "$im" ] || { echo "acik $kod"; return 0; }
      # 1.2: imza verildiyse kod yetmez, gövde okunur. Okunamadı → ölçülemedi ("kapalı" sayılmaz: yanlış-yeşil kapısı).
      g="$(govde "$a")" || { echo "olculemedi $kod-govde-okunamadi"; return 3; }
      if printf '%s' "$g" | grep -qF -- "$im"; then echo "acik $kod"; else echo "kapali $kod-govde-korumali"; fi; return 0 ;;
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
# Dosya adı adresten BİRE BİR üretilir: iki ayrı adres aynı ada düşemez (denetim tur 2: eğik çizgi alt çizgiye
# çevrilince /a/b ile /a_b aynı dosyaya yazıyordu). Adresteki her özel karakter kendi koduna döner.
dosya_adi() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1][len("https://"):], safe=".-_~"))' "$1"; }
ayni_adres_mi() {  # ayni_adres_mi <dosya> <adres> → dosya yoksa ya da aynı adresin kaydıysa 0; başka adresin kaydıysa 1; okunamıyorsa 2
  [ -e "$1" ] || return 0
  # bozuk (okunamayan ya da adres alanı olmayan) kayıt DELİLDİR: üstüne yazılmaz, elle incelenir (denetim tur 1, kart canli-sayfa-araci)
  python3 -c 'import json,sys
try: k = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception: sys.exit(2)
a = k.get("adres") if isinstance(k, dict) else None
if not isinstance(a, str) or not a: sys.exit(2)   # okunuyor ama kayıt değil ({} · adres yok · liste): yine bozuk
sys.exit(0 if a == sys.argv[2] else 1)' "$1" "$2"
}
# hedef_kontrol <dosya> <adres> <fiil> → hedef başka adresin ya da bozuk bir kaydıysa rc 3 ile çıkar
hedef_kontrol() {
  ayni_adres_mi "$1" "$2"; case $? in
    0) ;;
    1) hata "bu dosya adında BAŞKA bir adresin kaydı var; $3: $1" 3 ;;
    *) hata "bu dosya adında BOZUK bir kayıt var (okunamıyor); $3, elle incelenmeli: $1" 3 ;;
  esac
}

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

tek_cumle_denetle() {  # tek_cumle_denetle <alan> <değer> → cümle bitiminden sonra yeni söz başlıyorsa çıkar
  # menüde tek satır yer var: "Şu işi yapar." yeter; ikinci cümle, noktalı virgül zinciri kabul edilmez
  if printf '%s' "$2" | grep -qE '[.!?;…][[:space:]]+[^[:space:]]'; then
    hata "$1 tek cümle olmalı: nokta, soru, ünlem ya da noktalı virgülden sonra yeni söz başlıyor"; fi
}

kilit_al() {  # kilit_al <kayıt dosyası> → aynı sayfaya yazanlar sırayla girer; kilit süreç bitince kalkar
  mkdir -p "$DIZIN" 2>/dev/null || hata "kayıt dizini açılamadı: $DIZIN" 3
  command -v flock >/dev/null 2>&1 || hata "ÖLÇÜLEMEDİ · flock yok; aynı sayfaya eşzamanlı yazım güvenceye alınamaz" 3
  exec 9>"$DIZIN/.$(basename "$1").kilit" || hata "kilit dosyası açılamadı" 3
  flock -w "${CANLI_SAYFA_KILIT_SURE:-10}" 9 || hata "bu sayfanın kaydına başka bir süreç yazıyor, kilit alınamadı; biraz sonra yeniden dene: $1" 3
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
adres=""; ad=""; ne=""; kutu=""; ekleyen=""; acik=""; gerekce=""; imza=""; hepsi=0; json=0
while [ "$#" -gt 0 ]; do
  # değer isteyen seçenek değersiz verilirse DUR (denetim tur 3: kaydırma düşüyor, döngü aynı seçenekte dönüyordu)
  case "$1" in --adres|--ad|--ne|--kutu|--ekleyen|--herkese-acik|--gerekce|--imza) [ "$#" -ge 2 ] || hata "$1 bir değer ister" ;; esac
  case "$1" in
    --adres) adres="${2:-}"; shift 2 ;;   --ad) ad="${2:-}"; shift 2 ;;
    --ne) ne="${2:-}"; shift 2 ;;         --kutu) kutu="${2:-}"; shift 2 ;;
    --ekleyen) ekleyen="${2:-}"; shift 2 ;; --herkese-acik) acik="${2:-}"; shift 2 ;;
    --gerekce) gerekce="${2:-}"; shift 2 ;; --imza) imza="${2:-}"; shift 2 ;; --hepsi) hepsi=1; shift ;;
    --json) json=1; shift ;;
    *) hata "tanınmayan bayrak: $1" ;;
  esac
done

case "$komut" in
  ekle)
    [ -n "$adres" ] || hata "--adres gerekli"
    a="$(adres_duzelt "$adres" 2>&1)" || hata "adres kurala uymuyor: $a"
    metin_denetle "ad" "$ad" 40; metin_denetle "ne" "$ne" 140; tek_cumle_denetle "ne" "$ne"
    [ "$(printf '%s' "$ad" | wc -w)" -le 4 ] || hata "ad en çok dört kelime olabilir"
    printf '%s' "$kutu" | grep -qE '^[a-z0-9][a-z0-9-]{0,30}$' || hata "--kutu gerekli (küçük harf, rakam, tire): hangi kutunun sayfası"
    printf '%s' "$ekleyen" | grep -qE '^[A-Za-zÇĞİÖŞÜÂÎÛçğıöşüâîû-]{2,24}$' || hata "--ekleyen gerekli: kaydı yazan ajanın adı"
    if [ -n "$imza" ]; then   # imza: sayfanın kendi içeriğinden bir dize; tek satır, kısa, sır değil (gövdede aranır, kayda yazılır)
      [ "${#imza}" -ge 4 ] && [ "${#imza}" -le 80 ] || hata "--imza 4-80 karakter olmalı: sayfanın kendi içeriğinden, anonim gövdede aranacak bir dize"
      case "$imza" in *$'\n'*|*$'\t'*) hata "--imza tek satır olmalı" ;; esac
      if printf '%s' "$imza" | grep -qEi '(parola|sifre|şifre|password|token|secret|apikey|api_key)[[:space:]]*[:=]|sk-[A-Za-z0-9]{16,}|[A-Za-z0-9+/_-]{32,}'; then
        hata "--imza sır gibi görünen bir değer içeriyor (değer basılmadı)"; fi
    fi
    o="$(olc "$a" "$imza")"; r=$?
    [ "$r" -eq 0 ] || hata "CANLI DEĞİL ya da ölçülemedi ($o): $a — sayfa açılmadan kayda girmez" 3
    giris="${o%% *}"; olcu="kod"; case "$o" in *-govde-korumali) olcu="govde" ;; esac
    [ -n "$imza" ] && [ "$giris" = acik ] && olcu="govde"   # imza gövdede bulundu: açıklık koddan değil içerikten ölçüldü
    if [ "$giris" = acik ] && [ "$acik" != evet ]; then
      hata "bu sayfa GİRİŞ KAPISI OLMADAN açılıyor ($o): $a — bilerek herkese açıksa --herkese-acik evet ile yeniden kaydet; değilse önce giriş kapısını kur (betikle yüklenen korumalı sayfaysa --imza ile içerik imzası ver)" 4
    fi
    f="$DIZIN/$(dosya_adi "$a").json"
    kilit_al "$f"    # hedef okuma + yazma tek kilit altında: aynı sayfaya eşzamanlı yazım sıraya girer
    hedef_kontrol "$f" "$a" "üzerine yazılmadı"
    j="$(python3 - "$f" "$a" "$ad" "$ne" "$kutu" "$ekleyen" "$giris" "$olcu" "$imza" <<'PY'
import json, sys, datetime
f, a, ad, ne, kutu, ek, giris, olcu, imza = sys.argv[1:10]
simdi = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
try: eski = json.load(open(f, encoding="utf-8"))
except Exception: eski = {}
k = {"v": 1, "adres": a, "ad": ad, "ne": ne, "kutu": kutu, "ekleyen": ek, "giris": giris, "giris_olcu": olcu, "durum": "canli",
     "eklendi": eski.get("eklendi") if isinstance(eski.get("eklendi"), str) and eski.get("eklendi") else simdi,
     "olculdu": simdi}
if imza: k["imza"] = imza   # dogrula aynı imzayla yeniden ölçer
print(json.dumps(k, ensure_ascii=False))
PY
    )" || hata "kayıt üretilemedi" 3
    yaz "$f" "$j"
    if [ "$olcu" = govde ] && [ "$giris" = kapali ]; then echo "✓ kayda girdi: $ad · $a · giriş: kapali (gövde korumalı: imza anonim gövdede yok) · kutu: $kutu"
    else echo "✓ kayda girdi: $ad · $a · giriş: $giris · kutu: $kutu"; fi
    ;;
  emekli)
    [ -n "$adres" ] || hata "--adres gerekli"
    a="$(adres_duzelt "$adres" 2>&1)" || hata "adres kurala uymuyor: $a"
    [ "${#gerekce}" -ge 10 ] || hata "--gerekce gerekli (en az 10 karakter): sayfa niçin kalktı"
    metin_denetle "gerekçe" "$gerekce" 200      # gerekçe de ortak kayda yazılır: aynı dil ve sır kuralları
    f="$DIZIN/$(dosya_adi "$a").json"; [ -f "$f" ] || hata "böyle bir kayıt yok: $a" 1
    kilit_al "$f"
    hedef_kontrol "$f" "$a" "dokunulmadı"
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
    if k.get("giris_olcu") == "govde": im += " · gövdeden ölçüldü"
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
    while IFS=$'\t' read -r a g im ad; do
      [ -n "$a" ] || continue; n=$((n + 1)); [ "$im" = "-" ] && im=""   # boş imza "-" taşınır: ardışık sekme read'de çöker, sütun kayardı
      o="$(olc "$a" "$im")"; r=$?; y="${o%% *}"   # kayıttaki imzayla: gövde korumalı sayfa yine gövdeden ölçülür
      if [ "$r" -ne 0 ]; then echo "✗ AÇILMIYOR   $ad · $a ($o)"; k=1
      elif [ "$y" != "$g" ]; then echo "✗ KAPI DEĞİŞTİ $ad · $a (kayıtta: $g · şimdi: $y)"; k=1
      else echo "✓ $ad · $a ($o)"; fi
    done < <(printf '%s' "$t" | python3 -c 'import json,sys
for k in json.load(sys.stdin)["sayfalar"]: print(k["adres"], k["giris"], k.get("imza") or "-", k["ad"], sep="\t")')
    b="$(printf '%s' "$t" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["bozuk"]))')"
    [ "$b" -eq 0 ] || { echo "✗ bozuk kayıt: $b"; k=1; }
    echo "── $n sayfa ölçüldü"
    exit "$k"
    ;;
  *) echo "kullanım: canli-sayfa.sh ekle|liste|emekli|dogrula  (ayrıntı: dosyanın başı)" >&2; exit 2 ;;
esac
exit 0
