#!/usr/bin/env bash
# onizleme.test.sh — DÖRDÜNCÜ TANIĞIN sınavı. Ağa çıkmaz, gerçek defterlere DOKUNMAZ.
#
# 🔴 NİÇİN VAR (ölçüldü 2026-08-23, derin kazı E2):
#    Önizleme, doğrulama zincirinin dördüncü tanığıdır: kapı → UBL → ÖNİZLEME → portal.
#    Dayanağı elle yazılmış bir sözlükten çözüyordu ve anahtarı FATURA NUMARASIYDI.
#    Araya 12 TL'lik bir görünüm-testi faturası girip numaralar kayınca:
#      · 12,00 TL'lik belge  → "dayanak <büyük tutar> · FARK VAR"  = YALANCI KIRMIZI
#      · <büyük tutar> TL'lik → dayanak satırı HİÇ BASILMADI       = TANIKSIZ GEÇTİ
#    Zincirin en pahalı belgesi, denetimden SESSİZCE çıktı.
#    Kök neden: dayanağın kimliği fatura numarası DEĞİL, **SAP belge no**dur. Kesim
#    defterinde anahtar zaten SAP'tı; burada numara kullanmak tutarsızlıktı.
#
# Sınanan üç şey:
#   Ö1 · SAP belgenin KENDİSİNDEN okunur (cbc:Note), dosya adından değil
#   Ö2 · dayanak SAP üzerinden numara defterinden çözülür; numara kaysa bile doğru kalır
#   Ö3 · dayanak ÇÖZÜLEMEZSE sessiz kalmaz — kırmızı blok + rc=4 ("ölçemedim" ≠ "eşit")
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
GECEN=0; DUSEN=0
gec(){ GECEN=$((GECEN+1)); printf '  ✓ %s\n' "$1"; }
dus(){ DUSEN=$((DUSEN+1)); printf '  ✗ %s\n' "$1"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Fikstür: iki belge. Numaralar BİLEREK "kaymış" — küçük tutarlı belge …002'yi almış,
# büyük tutarlı belge …003'te. Eski (numara anahtarlı) mantık tam burada yalan söylüyordu.
belge(){  # belge <dosya> <numara> <sap> <matrah> <kdv> <odenecek>
cat > "$TMP/$1" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
 xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
 xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2">
 <cbc:ID>$2</cbc:ID>
 <cbc:IssueDate>2026-08-20</cbc:IssueDate>
 <cbc:InvoiceTypeCode>SATIS</cbc:InvoiceTypeCode>
 <cbc:DocumentCurrencyCode>TRY</cbc:DocumentCurrencyCode>
 <cbc:Note>Fiş paketi SAP Belge No: $3</cbc:Note>
 <cac:TaxTotal><cbc:TaxAmount currencyID="TRY">$5</cbc:TaxAmount></cac:TaxTotal>
 <cac:LegalMonetaryTotal>
  <cbc:LineExtensionAmount currencyID="TRY">$4</cbc:LineExtensionAmount>
  <cbc:TaxExclusiveAmount currencyID="TRY">$4</cbc:TaxExclusiveAmount>
  <cbc:TaxInclusiveAmount currencyID="TRY">$6</cbc:TaxInclusiveAmount>
  <cbc:PayableAmount currencyID="TRY">$6</cbc:PayableAmount>
 </cac:LegalMonetaryTotal>
</Invoice>
XML
}
belge "SINAV-A.xml" "SNV2026000000002" "SINAV-SAP-KUCUK" "10.00"   "2.00"   "12.00"
belge "SINAV-B.xml" "SNV2026000000003" "SINAV-SAP-BUYUK" "1000.00" "200.00" "1200.00"
belge "SINAV-C.xml" "SNV2026000000009" "SINAV-SAP-KAYIP" "5.00"    "1.00"   "6.00"

# Sahte numara defteri: SAP → tutar. Dikkat: numaralar defterde BAŞKA sırada —
# yani "numara ile eşle" mantığı burada kesin yanılır, "SAP ile eşle" doğru bulur.
cat > "$TMP/numara.jsonl" <<'J'
{"numara":"SNV2026000000003","onek":"SNV","yil":2026,"sira":3,"sap":"SINAV-SAP-KUCUK","tutar":"12.00","tarih":"2026-08-23T00:00:00","veren":"SINAV"}
{"numara":"SNV2026000000002","onek":"SNV","yil":2026,"sira":2,"sap":"SINAV-SAP-BUYUK","tutar":"1200.00","tarih":"2026-08-23T00:00:01","veren":"SINAV"}
J

kos(){ ELOGO_NUMARA_DEFTERI="$TMP/numara.jsonl" python3 - "$@" <<'PY'
import sys, os, glob, io, contextlib
sys.path.insert(0, ".")
import numara_defteri as nd
nd.DEFTER = os.environ["ELOGO_NUMARA_DEFTERI"]
import onizleme
onizleme.nd = nd

# 🔴 ÜRETİM YOLUNDAN GEÇ (2026-09-09). Buradaki döngü eskiden `dayanak_coz`un ve
#    `__main__` bloğunun mantığını ELLE yeniden yazıyordu. Sonuç: sınav FİKRİ ölçüyor,
#    GÖNDERİLEN kodu ölçmüyordu — kapı silinse bile yeşil kalıyordu. Artık gerçek
#    `raporla()` çağrılır; çıktısı ayrıştırılıp aynı satır biçimi üretilir.
tampon = io.StringIO()
with contextlib.redirect_stdout(tampon):
    rc = onizleme.raporla(sys.argv[1])
metin = tampon.getvalue()

# raporla() insan-yüzlü basar; sınav makine-yüzlü satır ister. Belgeleri yeniden okuyup
# dayanağı ÜRETİM FONKSİYONUNDAN sorarak eşleştiriyoruz (kopya mantık YOK).
for d in sorted(glob.glob(sys.argv[1])):
    f = onizleme.oku(d)
    sap = f.get("sap", "")
    day = onizleme.dayanak_coz(sap) if sap else None
    print(f"{f['numara']}|{sap}|{day}|{f['odenecek']}")
sys.exit(rc)
PY
}

echo "Ö1 · SAP belgenin KENDİSİNDEN okunuyor mu (dosya adı YANILTICI seçildi)"
cp "$TMP/SINAV-A.xml" "$TMP/yanlis-ad_SINAV-SAP-BUYUK.xml"
sonuc=$(python3 -c "
import sys; sys.path.insert(0,'.')
import onizleme; print(onizleme.oku('$TMP/yanlis-ad_SINAV-SAP-BUYUK.xml')['sap'])")
[[ "$sonuc" == "SINAV-SAP-KUCUK" ]] \
  && gec "SAP cbc:Note'tan okundu (dosya adı 'BUYUK' diyordu, belge 'KUCUK')" \
  || dus "SAP dosya adından okunmuş — belge içeriği kazanmalıydı (geldi: $sonuc)"
rm -f "$TMP/yanlis-ad_SINAV-SAP-BUYUK.xml"

echo
echo "Ö2 · numara KAYMIŞKEN dayanak doğru eşleşiyor mu"
cikti=$(kos "$TMP/SINAV-[AB].xml"); rc=$?
bek_a="SNV2026000000002|SINAV-SAP-KUCUK|12.00|12.00"
bek_b="SNV2026000000003|SINAV-SAP-BUYUK|1200.00|1200.00"
grep -qxF "$bek_a" <<<"$cikti" && gec "küçük belge → dayanak 12,00 (numarası …002, defterde …003)" \
  || dus "küçük belge yanlış eşleşti: $(grep 'SINAV-SAP-KUCUK' <<<"$cikti")"
grep -qxF "$bek_b" <<<"$cikti" && gec "büyük belge → dayanak 1200,00 (numarası …003, defterde …002)" \
  || dus "büyük belge yanlış eşleşti: $(grep 'SINAV-SAP-BUYUK' <<<"$cikti")"
[[ $rc -eq 0 ]] && gec "iki belge de tanıklı → rc=0" || dus "tanıklı belgede rc=$rc"

echo
echo "Ö3 · dayanak ÇÖZÜLEMEZSE sessiz kalmıyor mu ('ölçemedim' ≠ 'eşit')"
cikti=$(kos "$TMP/SINAV-C.xml"); rc=$?
grep -q "SINAV-SAP-KAYIP|None" <<<"$cikti" \
  && gec "defterde olmayan SAP → dayanak None (uydurulmuyor)" \
  || dus "defterde olmayan SAP için dayanak uydurulmuş: $cikti"
[[ $rc -eq 4 ]] && gec "tanıksız belge rc=4 ile bildiriliyor (sessiz geçmiyor)" \
  || dus "tanıksız belge rc=$rc ile SESSİZCE geçti — asıl kusur bu"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
