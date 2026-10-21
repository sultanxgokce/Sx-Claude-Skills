#!/usr/bin/env bash
# baglam-karti.sh — ENİS bağlam kartı KAYIT DEFTERİ: her istek ve her cevap Görev Defteri'nde tek adım (Sultan buradan görür).
#
# NİÇİN VAR (MUAVİN şablonu 18 Eki §3 · SERDAR gün planı C, gorev 2M0CV): bağlam kartı oda mektubuyla taşınır; kaydı
# elle yazmak hem unutulur hem mahremiyet sızdırır (karar cümlesi ya da kart metni kayda düşebilir). Bu araç:
#   · mektubu şablona göre DOĞRULAR (yanlış biçimli istek/cevap kayda da girmez, taşınmaz da),
#   · kayda YALNIZ şablonun izin verdiği alanları yazar: kim · ufuk · son an / durum · kapı.
#     🔴 Karar cümlesi ve kart metni HİÇBİR yere yazılmaz (ne deftere ne ekrana).
#   · FAIL-CLOSED: kayıt yazılamazsa rc≠0 → taşıyıcı kartı GÖNDERMEZ ("kayıt yazılamıyorsa kart da dönmez").
#
# Kullanım:
#   baglam-karti.sh kaydet <mektup.md> [--kuru] [--gorev <gorev_id>]
#     İstek dosya adı:  <MAISET|SERDAR>-ENIS-baglam-karti-<YYYYMMDD>-<n>.md
#     Cevap dosya adı:  ENIS-<MAISET|SERDAR>-baglam-karti-<YYYYMMDD>-<n>.md
#     --kuru : doğrular ve yazılacak adımı basar; deftere DOKUNMAZ → rc 3 (taşıma izni DEĞİL).
# rc: 0 kayıt yazıldı (ya da bu adım zaten yazılıydı) → taşınabilir
#     1 kayıt YAZILAMADI (jeton yok · defter ulaşılamaz · reddetti · 200 ama kayıt doğrulanamadı) → kart DÖNMEZ
#     2 kullanım ya da biçim hatası → kayda girmedi, kart DÖNMEZ
#     3 kuru koşum: biçim doğru ama kayıt YAZILMADI → kart DÖNMEZ (yalnız rc 0 taşıma iznidir)
# Ortam: DEFTER_JETON_YOL (vars. /config/defter-jeton; değer argv'ye/çıktıya düşmez) · DEFTER_UC (vars. http://cloudtop-defter:8791)
#        BAGLAM_KARTI_GOREV (vars. kayıt defteri görevi gorev_01M557ADY4KHRGS99DQ6E2M0CV)
set -uo pipefail

GOREV="${BAGLAM_KARTI_GOREV:-gorev_01M557ADY4KHRGS99DQ6E2M0CV}"
JY="${DEFTER_JETON_YOL:-/config/defter-jeton}"; UC="${DEFTER_UC:-http://cloudtop-defter:8791}"

_kullanim() { sed -n '/^# Kullanım:/,/^set -uo/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//' >&2; exit 2; }

[ "${1:-}" = "kaydet" ] || _kullanim
shift; DOSYA=""; KURU=0
while [ $# -gt 0 ]; do case "$1" in
  --kuru) KURU=1; shift ;;
  --gorev) [ $# -ge 2 ] || { echo "--gorev değersiz" >&2; exit 2; }; GOREV="$2"; shift 2 ;;
  -h|--help) _kullanim ;;
  -*) echo "bilinmeyen: $1" >&2; exit 2 ;;
  *) [ -z "$DOSYA" ] || { echo "tek mektup verilir: $1" >&2; exit 2; }; DOSYA="$1"; shift ;;
esac; done
[ -n "$DOSYA" ] || _kullanim
[ -r "$DOSYA" ] || { echo "⛔ mektup okunamadı: $DOSYA — kayıt yok, kart dönmez" >&2; exit 2; }
[[ "$GOREV" =~ ^gorev_[0-9A-Z]+$ ]] || { echo "⛔ görev kimliği biçimsiz: $GOREV" >&2; exit 2; }

# Doğrulama + adım metni (python: Türkçe harf ve çok satırlı alan güvenli). Çıktı yalnız ADIM metnidir; hata stderr'e, rc 2.
ADIM="$(python3 - "$DOSYA" <<'PY'
import os, re, sys
from datetime import datetime
yol = sys.argv[1]; ad = os.path.basename(yol)
def red(n): print("⛔ %s — %s · kayıt yok, kart dönmez" % (ad, n), file=sys.stderr); sys.exit(2)
ISTEYEN = ("MAISET", "SERDAR")
m_i = re.fullmatch(r"(MAISET|SERDAR)-ENIS-baglam-karti-(\d{8})-(\d+)\.md", ad)
m_c = re.fullmatch(r"ENIS-(MAISET|SERDAR)-baglam-karti-(\d{8})-(\d+)\.md", ad)
if not (m_i or m_c):
    red("dosya adı şablona uymuyor (istek: <MAISET|SERDAR>-ENIS-baglam-karti-<YYYYMMDD>-<n>.md · cevap: ENIS-<MAISET|SERDAR>-baglam-karti-<YYYYMMDD>-<n>.md)")
kim, gun, n = (m_i or m_c).groups()
try: datetime.strptime(gun, "%Y%m%d")
except ValueError: red("dosya adındaki tarih geçersiz: %s" % gun)
kimlik = "%s-%s" % (gun, n)
try: metin = open(yol, encoding="utf-8").read()
except UnicodeDecodeError: red("mektup UTF-8 değil")
def alan(ad_):
    # "Ad:  değer" — aynı alan iki kez yazılmışsa belirsizdir, reddedilir
    b = re.findall(r"^%s:[ \t]*(.*?)[ \t]*$" % re.escape(ad_), metin, re.M)
    if len(b) > 1: red("'%s' alanı birden çok kez yazılmış" % ad_)
    return b[0] if b else None
hedef = alan("HEDEF")
if m_i:
    if (hedef or "").lower() != "enis": red("istekte 'HEDEF: enis' yok")
    karar = alan("Karar")
    if not karar: red("'Karar' satırı boş ya da yok")
    ufuk = alan("Ufuk")
    if ufuk not in ("bugün", "bu hafta"): red("'Ufuk' bugün ya da bu hafta olmalı (olan: %s)" % (ufuk or "yok"))
    son = alan("Son an") or ""
    try: datetime.strptime(son, "%Y-%m-%d %H:%M")
    except ValueError: red("'Son an' YYYY-MM-DD HH:MM biçiminde olmalı (olan: %s)" % (son or "yok"))
    print("istek %s · %s · ufuk %s · son an %s" % (kimlik, kim, ufuk, son))
else:
    # Cevap isteyenin kutusuna gider: SERDAR merkezde, MAİŞET kendi odasında. Yanlış kutuya giden kart kayda girmez.
    beklenen = {"SERDAR": "merkez", "MAISET": "maiset"}[kim]
    if (hedef or "").lower() != beklenen: red("cevapta 'HEDEF: %s' olmalı (olan: %s)" % (beklenen, hedef or "yok"))
    durum = alan("Durum")
    if durum not in ("verildi", "kapalı", "dayanak yok"): red("'Durum' verildi | kapalı | dayanak yok olmalı (olan: %s)" % (durum or "yok"))
    kapi = (alan("Kapı") or "").split(" ")[0]
    kart = alan("Kart")
    if durum == "verildi":
        if not kart: red("durum verildi ama 'Kart' boş")
        # Kapıdan geçmeyen kart gönderilmez: yumuşatılmaz, kısaltılmaz → 'Durum: kapalı' dönmeli
        if kapi != "geçti": red("durum verildi ama 'Kapı: geçti' değil — kapıdan geçmeyen kart gönderilmez (Durum: kapalı dönmeli)")
    else:
        if kart: red("durum '%s' iken kart metni taşınmaz" % durum)
        kapi = "—"
    print("cevap %s · %s · durum %s · kapı %s" % (kimlik, kim, durum, kapi))
PY
)" || exit 2

# Kuru koşum rc 3: yalnız rc 0 "kayıt yazıldı, taşı" demektir; kayıtsız başarı kodu yok (bağımsız göz tur 2)
if [ "$KURU" -eq 1 ]; then echo "🧪 kuru: $GOREV ← $ADIM (deftere YAZILMADI · taşıma)"; exit 3; fi

[ -r "$JY" ] || { echo "⛔ defter jetonu yok ($JY) — kayıt YAZILMADI, kart dönmez (taşıyıcı merkezde MUAVİN'dir; SERDAR'a: jeton-dagit)" >&2; exit 1; }
govde="$(python3 -c 'import sys,json; print(json.dumps({"adimlar":[sys.argv[1]]},ensure_ascii=False))' "$ADIM")"
cfg="$(mktemp)"; trap 'rm -f -- "$cfg"' EXIT
printf 'header = "x-defter-jeton: %s"\n' "$(tr -d '\n' < "$JY")" > "$cfg"
cevap="$(curl -sS -m 15 --config "$cfg" -X PATCH -H 'content-type: application/json' --data-binary "$govde" "$UC/kayit/$GOREV" -w '\n%{http_code}' 2>&1)"; rc=$?
rm -f -- "$cfg"
[ $rc -eq 0 ] || { echo "⛔ Görev Defteri'ne ulaşılamadı ($UC): $cevap — kayıt YAZILMADI, kart dönmez" >&2; exit 1; }
printf '%s' "$cevap" | python3 -c '
import sys,json
t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
try: j=json.loads(g or "{}")
except Exception: j={"hata":"yanit_bozuk"}
if kod!="200": print("⛔ defter reddetti http=%s · %s — kayıt YAZILMADI, kart dönmez" % (kod, j.get("hata") or ""), file=sys.stderr); sys.exit(1)
# 200 tek başına yetmez (bağımsız göz tur 3): gövde geçerli olmalı VE adım kayıtta görünmeli; yoksa kayıt doğrulanamadı → rc 1
# adimlar LİSTE olmalı (tur 4): metin olsaydı 'in' alt-metin eşleşmesi yapar, adım yazılmadan rc 0 verirdi
# 🔴 GERÇEK defterin biçimi NESNE listesidir: {"deger": "<adım metni>", "anahtar", "kutu", "ts"} (canlı sınav 21 Eki; sahte sunucu düz metin sanıyordu,
#   bu yüzden her geçerli yazım rc 1 verirdi). Eşleşme adım METNİNE: nesnede "deger", düz metin kayıtta kendisi — tam eşitlik, alt-metin DEĞİL.
k=j.get("kayit") if isinstance(j,dict) else None
yazili=[(x.get("deger") if isinstance(x,dict) else x) for x in k["adimlar"]] if isinstance(k,dict) and isinstance(k.get("adimlar"),list) else None
if not isinstance(j.get("degisti") if isinstance(j,dict) else None, bool) or yazili is None or sys.argv[2] not in yazili:
    print("⛔ defter 200 döndü ama kayıt doğrulanamadı (gövde bozuk ya da adım kayıtta yok) — kart dönmez", file=sys.stderr); sys.exit(1)
print("📒 %s · %s · %s" % (sys.argv[1], sys.argv[2], "adım yazıldı" if j["degisti"] else "bu adım zaten yazılıydı"))' "$GOREV" "$ADIM"
