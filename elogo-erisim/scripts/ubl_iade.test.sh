#!/usr/bin/env bash
# ubl_iade.test.sh — UBL-TR iade faturası kurucusunun sınavı.
#
# NİÇİN BU SINAV AĞIR: e-Fatura'da iptal YOK, sandbox YOK, her çağrı kontör yakıyor.
# Yani üretim ortamında "dene-gör" imkânımız hiç yok. Bu modül bedelsiz koşabilen TEK
# katman olduğu için, güvenliğin tamamı buraya yükleniyor.
#
# Sınav ağsızdır: hiçbir kapıya çıkmaz, kimlik istemez, kontör harcamaz.
set -uo pipefail
cd "$(dirname "$0")"

GECEN=0; KALAN=0
kapi() { # kapi "<ad>" "<beklenen>" "<gerçek>"
  if [[ "$2" == "$3" ]]; then GECEN=$((GECEN+1)); printf '  ✓ %s\n' "$1"
  else KALAN=$((KALAN+1)); printf '  ✗ %s\n     beklenen: %s\n     gerçek  : %s\n' "$1" "$2" "$3"; fi
}
icerir() { # icerir "<ad>" "<iğne>" "<samanlık>"
  if [[ "$3" == *"$2"* ]]; then GECEN=$((GECEN+1)); printf '  ✓ %s\n' "$1"
  else KALAN=$((KALAN+1)); printf '  ✗ %s — bulunamadı: %s\n' "$1" "$2"; fi
}
icermez() {
  if [[ "$3" != *"$2"* ]]; then GECEN=$((GECEN+1)); printf '  ✓ %s\n' "$1"
  else KALAN=$((KALAN+1)); printf '  ✗ %s — olmamalıydı ama var: %s\n' "$1" "$2"; fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── fikstür: TAM veri (uydurma taraflar — gerçek cari YAZILMAZ) ───────────────
cat > "$TMP/tam.json" <<'JSON'
{
  "duzenleyen": {"unvan": "ÖRNEK ALICI LTD. ŞTİ.", "vkn": "1111111111",
                 "vergi_dairesi": "Örnek VD", "adres": "Örnek Mah. Deneme Cad. No:1",
                 "il": "Ankara", "ilce": "Çankaya"},
  "muhatap":    {"unvan": "ÖRNEK SATICI A.Ş.",   "vkn": "2222222222",
                 "vergi_dairesi": "Deneme VD", "il": "İstanbul", "ilce": "Kadıköy"},
  "tarih": "2026-08-21",
  "dayanaklar": [{"fatura_no": "ABC2026000000123", "tarih": "2026-08-19"}],
  "kalemler": [
    {"ad": "60x120 seramik", "miktar": "1",  "birim": "C62",
     "birim_fiyat_kurus": 120000, "kdv_orani": 20, "aciklama": "kırık — depo fişiyle iade"},
    {"ad": "seviye klipsi",  "miktar": "4",  "birim": "C62",
     "birim_fiyat_kurus": 2550,  "kdv_orani": 20}
  ]
}
JSON

echo "── A · TAM veri kurulabilmeli ───────────────────────────────────────────"
CIK="$(python3 ubl_iade.py kur "$TMP/tam.json" 2>&1)"; RC=$?
kapi   "A1 · kur RC=0"                    "0" "$RC"
icerir "A2 · XML bildirimi"               '<?xml version="1.0" encoding="UTF-8"?>' "$CIK"
icerir "A3 · UBL-TR özelleştirmesi"       "<cbc:CustomizationID>TR1.2</cbc:CustomizationID>" "$CIK"
icerir "A4 · belge tipi IADE"             "<cbc:InvoiceTypeCode>IADE</cbc:InvoiceTypeCode>" "$CIK"
icerir "A5 · VUK 229 şerhi"               "İADE FATURASIDIR" "$CIK"
icerir "A6 · dayanak fatura no"           "ABC2026000000123" "$CIK"
icerir "A7 · dayanak sarmalı"             "<cac:BillingReference>" "$CIK"
icerir "A8 · satır sayısı"                "<cbc:LineCountNumeric>2</cbc:LineCountNumeric>" "$CIK"

echo "── B · PARA — kuruş aritmetiği, float sızıntısı yok ─────────────────────"
# matrah = 1×1200,00 + 4×25,50 = 1200,00 + 102,00 = 1302,00 · KDV %20 = 260,40
icerir "B1 · matrah 1302.00"              '<cbc:LineExtensionAmount currencyID="TRY">1302.00' "$CIK"
icerir "B2 · KDV 260.40"                  '<cbc:TaxAmount currencyID="TRY">260.40' "$CIK"
icerir "B3 · genel toplam 1562.40"        '<cbc:PayableAmount currencyID="TRY">1562.40' "$CIK"
icerir "B4 · satır KDV oranı"             "<cbc:Percent>20</cbc:Percent>" "$CIK"
# B5 — "E+" ARAMASI ARTIK YETMEZ (2026-08-22): gömülü XSLT'nin base64'ünde "E+" dizisi
# rastlantısal olarak geçiyor ve kapı YANLIŞ-POZİTİF veriyordu. Kapı gevşetilmedi,
# KESKİNLEŞTİRİLDİ: kaba dizi yerine gerçek bilimsel-gösterim deseni aranıyor.
# Aradığımız şey para alanına sızmış float artığıydı (ör. 1.5E+10), base64 gürültüsü değil.
if printf '%s' "$CIK" | grep -qE '>[0-9]+\.?[0-9]*[Ee][+-][0-9]+<'; then
  DUSEN=$((DUSEN+1)); echo "  ✗ B5 · bilimsel gösterim SIZDI (para alanında)"
else
  GECEN=$((GECEN+1)); echo "  ✓ B5 · bilimsel gösterim sızmadı (eleman-içi desen)"
fi
icermez "B6 · float kuyruğu sızmadı"      ".00000" "$CIK"

echo "── C · NUMARA — üretilmiyor, e-Logo atacak (Sultan gözlemi) ─────────────"
icerir "C1 · cbc:ID boş bırakıldı"        "<cbc:ID />" "$CIK"
python3 - "$TMP" <<'PY'
import json,sys
t=sys.argv[1]; d=json.load(open(f"{t}/tam.json",encoding="utf-8"))
d["numara_modu"]="verilen"; d["fatura_no"]="XYZ2026000000999"
json.dump(d,open(f"{t}/verilen.json","w",encoding="utf-8"))
d2=json.load(open(f"{t}/tam.json",encoding="utf-8")); d2["numara_modu"]="verilen"
json.dump(d2,open(f"{t}/verilen-nosuz.json","w",encoding="utf-8"))
PY
CIK2="$(python3 ubl_iade.py kur "$TMP/verilen.json" 2>&1)"
icerir "C2 · 'verilen' modunda numara yazılır" "XYZ2026000000999" "$CIK2"
python3 ubl_iade.py kur "$TMP/verilen-nosuz.json" >/dev/null 2>&1
kapi   "C3 · 'verilen' ama no yoksa RED"  "2" "$?"

echo "── D · FAIL-CLOSED — eksik veriyle belge ÜRETİLMEZ ──────────────────────"
python3 - "$TMP" <<'PY'
import json,sys
t=sys.argv[1]
tam=json.load(open(f"{t}/tam.json",encoding="utf-8"))
def yaz(ad, f):
    d=json.loads(json.dumps(tam)); f(d); json.dump(d,open(f"{t}/{ad}.json","w",encoding="utf-8"))
yaz("kdvsiz",   lambda d: d["kalemler"][0].pop("kdv_orani"))
yaz("vknsiz",   lambda d: d["muhatap"].update(vkn=""))
yaz("vkn9",     lambda d: d["muhatap"].update(vkn="123456789"))
yaz("dayanaksiz", lambda d: d.update(dayanaklar=[]))
yaz("kalemsiz", lambda d: d.update(kalemler=[]))
yaz("tarihsiz", lambda d: d.update(tarih="21.08.2026"))
yaz("unvansiz", lambda d: d["duzenleyen"].update(unvan="   "))
PY

for f in kdvsiz vknsiz vkn9 dayanaksiz kalemsiz tarihsiz unvansiz; do
  OUT="$(python3 ubl_iade.py kur "$TMP/$f.json" 2>&1)"; R=$?
  kapi    "D · $f → RC=2"                 "2" "$R"
  icermez "D · $f → XML ÜRETİLMEDİ"       "<cbc:InvoiceTypeCode>" "$OUT"
done

echo "── E · EKSİKLER ADIYLA söylenir (sessiz reddetme yok) ───────────────────"
E1="$(python3 ubl_iade.py denetle "$TMP/kdvsiz.json" 2>&1)"
icerir "E1 · kdv_orani adıyla anılır"     "kdv_orani" "$E1"
icerir "E2 · 'dahil/hariç' tuzağı anlatılır" "bayrağından türetilemez" "$E1"
E3="$(python3 ubl_iade.py denetle "$TMP/dayanaksiz.json" 2>&1)"
icerir "E3 · GİB 1150 gerekçesi yazılı"   "1150" "$E3"
E4="$(python3 ubl_iade.py denetle "$TMP/tam.json" 2>&1)"
kapi   "E4 · tam veride denetle RC=0"     "0" "$?"
icerir "E5 · tam veride 'eksik yok'"      "eksik alan yok" "$E4"

echo "── F · ŞİRKETSİZ — gövdede firma/iş verisi OLMAMALI (paketleme md.1) ────"
GOVDE="$(cat ubl_iade.py)"
icermez "F1 · VKN gövdeye kaçmamış"       "3840044863" "$GOVDE"
icermez "F2 · firma adı gövdeye kaçmamış" "FAHRİ" "$GOVDE"
icermez "F3 · cari adı gövdeye kaçmamış"  "Baloğlu" "$GOVDE"
icermez "F4 · kutu adı gövdeye kaçmamış"  "sedir" "$GOVDE"

echo "── G · AĞSIZ — bu modül hiçbir kapıya çıkmaz ────────────────────────────"
icermez "G1 · requests yok"               "import requests" "$GOVDE"
icermez "G2 · zeep/SOAP yok"              "zeep" "$GOVDE"
icermez "G3 · urllib çağrısı yok"         "urlopen" "$GOVDE"
icermez "G4 · socket yok"                 "import socket" "$GOVDE"

echo "── I · ÜRETİCİ ZORUNLU ALANLARI (kaynak: Logo 'Zorunlu Bilgiler', 2026-08-21) ───"
icerir "I1 · vergi TÜRÜ kodu yazılıyor"   "<cbc:TaxTypeCode>0015</cbc:TaxTypeCode>" "$CIK"
icerir "I2 · vergi türü adı"              "<cbc:Name>KDV</cbc:Name>" "$CIK"
icerir "I3 · TaxCategory sarmalı"         "<cac:TaxCategory>" "$CIK"
python3 - "$TMP" <<'PY2'
import json,sys
t=sys.argv[1]; tam=json.load(open(f"{t}/tam.json",encoding="utf-8"))
def yaz(ad,f):
    d=json.loads(json.dumps(tam)); f(d); json.dump(d,open(f"{t}/{ad}.json","w",encoding="utf-8"))
yaz("vdsiz",     lambda d: d["duzenleyen"].pop("vergi_dairesi"))
yaz("adressiz",  lambda d: d["duzenleyen"].pop("adres"))
yaz("muhatap-vdsiz", lambda d: d["muhatap"].pop("vergi_dairesi"))
PY2
for f in vdsiz adressiz; do
  OUT="$(python3 ubl_iade.py kur "$TMP/$f.json" 2>&1)"; R=$?
  kapi    "I · duzenleyen $f → RC=2"      "2" "$R"
  icermez "I · duzenleyen $f → XML YOK"   "<cbc:InvoiceTypeCode>" "$OUT"
done
I4="$(python3 ubl_iade.py denetle "$TMP/vdsiz.json" 2>&1)"
icerir "I4 · gerekçe ÜRETİCİye dayanıyor" "üretici:" "$I4"
python3 ubl_iade.py kur "$TMP/muhatap-vdsiz.json" >/dev/null 2>&1
kapi   "I5 · MUHATAP vergi dairesiz GEÇER (üretici: 'varsa')" "0" "$?"

echo "── H · TCKN tarafı (şahıs muhatap) ──────────────────────────────────────"
python3 - "$TMP" <<'PY'
import json,sys
t=sys.argv[1]; d=json.load(open(f"{t}/tam.json",encoding="utf-8"))
d["muhatap"]["vkn"]="12345678901"
json.dump(d,open(f"{t}/tckn.json","w",encoding="utf-8"))
PY
H="$(python3 ubl_iade.py kur "$TMP/tckn.json" 2>&1)"
icerir "H1 · 11 hane → schemeID TCKN"     'schemeID="TCKN"' "$H"
icerir "H2 · 10 hane → schemeID VKN"      'schemeID="VKN"' "$H"

echo
printf 'SONUÇ: %d geçti, %d kaldı\n' "$GECEN" "$KALAN"
[[ "$KALAN" -eq 0 ]]
