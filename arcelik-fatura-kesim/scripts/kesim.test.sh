#!/usr/bin/env bash
# kesim.test.sh — bu becerinin PARASAL kurallarının sınavı. Ağa çıkmaz, gerçek defteri BOZMAZ.
#
# 🔴 NİÇİN VAR (derin kazı 2026-08-23, bulgular S1/S2/S3): bu becerinin kuralları doğrudan
#    parasal ve geri alınamaz — ama **tek bir kayıtlı sınavı yoktu**. Tek kanıt SKILL.md'deki
#    düzyazı ("7/7") idi; o da tek seferlik elle koşumdu, tekrarlanamıyordu.
#    Doktrin: "bitti = deterministik oracle; kanıtsız-yeşil YASAK."
#
# Sınanan üç kural:
#   S1 · IADE PAKETI DOKUMU → KESİLMEZ (zarar sebebi)
#   S2 · 'Malzeme İade'     → isim yanıltır, DÜZ FATURA olarak KESİLİR
#   S3 · kesim defteri ÜÇ DURUM: kesilmiş / kesilmemiş / ÖLÇÜLEMEDİ (asla "kesilmiş" değil)
set -uo pipefail
cd "$(dirname "$0")"
# 🔴 MUTASYON DÜRÜSTLÜĞÜ (ölçüldü 2026-08-23): mutasyon koşumları .pyc önbelleği bırakıyor;
#    kaynak geri alındıktan sonra sınav ESKİ bayt koduyla koşup YANLIŞ kırmızı verdi.
#    Önbellek yazımı kapalı — sınav her zaman diskteki kaynağı ölçer.
export PYTHONDONTWRITEBYTECODE=1
GECEN=0; DUSEN=0
gec(){ GECEN=$((GECEN+1)); printf '  ✓ %s\n' "$1"; }
dus(){ DUSEN=$((DUSEN+1)); printf '  ✗ %s\n' "$1"; }

echo "S1+S2 · tip → karar (isim yanıltır, TİP belirler)"
while IFS='|' read -r durum ad detay; do
  [[ "$durum" == "YESIL" ]] && gec "$ad ($detay)" || { [[ "$durum" == "KIRMIZI" ]] && dus "$ad — $detay"; }
done < <(python3 -c "
import sys; sys.path.insert(0,'.')
from tara import tip_bul, TIPLER
V=[('IADE PAKETI DOKUMU','KESME','iade paketi (düz)'),('İADE PAKETİ DÖKÜMÜ','KESME','iade paketi (tam Türkçe)'),('Iade Paketi Dokumu 20.08.2026','KESME','iade paketi (karışık)'),('FW: İADE PAKETI DOKUMU','KESME','iade paketi (iletilmiş)'),('Malzeme İade','KES','malzeme iade (tam Türkçe)'),('Malzeme Iade Bildirimi','KES','malzeme iade (noktasız I)'),('MALZEME İADE','KES','malzeme iade (büyük harf)'),('FIS PAKETI DOKUMU','KES','fiş paketi (düz)'),('FİŞ PAKETİ DÖKÜMÜ','KES','fiş paketi (tam Türkçe)'),('Fis Paketi Dokümü','KES','fiş paketi (karışık)'),('BİZ ödül puan bildirimi','SOR','ödül puan — KURAL YOK'),('Fatura talebi hk.','SOR','fatura talebi'),('Ne olduğu belirsiz bir konu','SOR','tanınmayan → fail-closed'),('','SOR','boş konu → fail-closed'),('Düzenlenmeyen faturalar hatırlatma','ATLA','uyarı maili'),
   ('Arçelik - Cari Hesap Mutabakatı Haziran/2026','ATLA','mutabakat — fatura değil'),
   ('(Hatırlatma-1-) Arçelik - Cari Hesap Mutabakatı','ATLA','mutabakat hatırlatması'),
   ('YS Haftalık Ödeme/ Mahsuplaştırma Bildirimi - Denk','ATLA','ödeme/denkleştirme dökümü'),
   ('FW: Fiş hurdası hk','ATLA','hurda kargo — lojistik'),
   ('Fis hurdasi hk','ATLA','hurda (noktasız)'),
   ('Hatırlatma: FIS PAKETI DOKUMU','KES','🔴 hatırlatma önekli FİŞ PAKETİ — KAÇMAMALI'),
   ('FW: HATIRLATMA - FİŞ PAKETİ DÖKÜMÜ','KES','🔴 aynısı, tam Türkçe'),
   ('(Hatırlatma-1-) İADE PAKETİ DÖKÜMÜ','KESME','🔴 hatırlatma önekli İADE — kesilmemeli'),
   ('Hatirlatma Malzeme İade','KES','hatırlatma önekli malzeme iade'),
   ('BİZPUAN ÖDÜL FATURA TALEBİ','TALEP','Bizpuan talebi — kanonda KES, SOR değil'),
   ('Eylül Ayı İskonto Fatura Talebi','TALEP','aylık iskonto talebi'),
   ('KLİMA MONTAJ DESTEK PRİM FATURA TALEBİ','TALEP','klima montaj prim talebi (14.10)'),
   ('Hatırlatma: Bizpuan Ödül Fatura Talebi','TALEP','🔴 hatırlatma önekli talep — uyari-ya düşmemeli'),
   ('FW: KLIMA MONTAJ DESTEK PRIM FATURA TALEBI','TALEP','iletilmiş, aksansız'),
   ('Düzenlenmemiş Görünen Bizpuan Faturalarınız Hakkında','SOR','toplu hatırlatma — talep DEĞİL'),
   ('Arçelik Pazarlama A.Ş Ödeme Listesi','ATLA','ödeme listesi — döküm (Sultan 18.10)'),
   ('Servis BizPuan- Harcanmayan Puanların Kullanımı','ATLA','harcanmayan puan duyurusu (Sultan 18.10)'),
   ('BİZPUAN ÖDÜL FATURA TALEBİ - Harcanmayan Puan','TALEP','🔴 talep, duyuru kuralına YUTULMAMALI')]
for k,b,a in V:
    _,kr=tip_bul(k)
    print(('YESIL' if kr==b else 'KIRMIZI')+'|'+a+'|'+(b if kr==b else f'beklenen={b} geldi={kr}'))
ad=[t[0] for t in TIPLER]
print(('YESIL' if ad.index('iade_paketi')<ad.index('fis_paketi') else 'KIRMIZI')+'|SIRA: iade deseni fişten ÖNCE|zarar kalkanı')
for paket in ('iade_paketi','fis_paketi','malzeme_iade'):
    print(('YESIL' if ad.index(paket)<ad.index('uyari') else 'KIRMIZI')+f'|SIRA: {paket} deseni uyari-dan ÖNCE|hatirlatma onekli paket kacmasin')
print(('YESIL' if ad.index('mutabakat')<ad.index('uyari') else 'KIRMIZI')+'|SIRA: mutabakat uyari-dan ÖNCE|dogru etiket')
for once in ('odul_puan','uyari','fatura_talebi'):
    print(('YESIL' if ad.index('fatura_talebi_kes')<ad.index(once) else 'KIRMIZI')+f'|SIRA: fatura_talebi_kes {once}-dan ÖNCE|talep SOR/ATLA-ya düşmesin')
")

echo
echo "S3 · kesim defteri — ÜÇ DURUM (altyapı hatası ASLA 'kesilmiş' olmaz)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf '{"sap":"SINAV-KESILMIS","fatura_no":"XXX2026000000001","tutar":"1.00","tarih":"2026-08-23","durum":"kesildi","kaydeden":"SINAV"}\n' > "$TMP/d.jsonl"
printf '{"sap":"SINAV-IPTAL","fatura_no":"XXX2026000000002","tutar":"1.00","tarih":"2026-08-23","durum":"iptal","kaydeden":"SINAV"}\n' >> "$TMP/d.jsonl"

uc_durum(){  # uc_durum <defter-yolu> <sap> <beklenen: True|False|None> <ad>
  local sonuc
  sonuc=$(ARCELIK_KESIM_DEFTERI="$1" python3 -c "
import sys; sys.path.insert(0,'.')
import tara; print(repr(tara.kesilmis_mi('$2')))
" 2>/dev/null)
  [[ "$sonuc" == "$3" ]] && gec "$4 → $3" || dus "$4 — beklenen=$3 geldi=${sonuc:-<yok>}"
}
uc_durum "$TMP/d.jsonl"            "SINAV-KESILMIS"  "True"  "defterde 'kesildi'"
uc_durum "$TMP/d.jsonl"            "SINAV-YOK"       "False" "defterde yok"
uc_durum "$TMP/d.jsonl"            "SINAV-IPTAL"     "None"  "defterde 'iptal' (insan kararı)"
uc_durum "$TMP/d.jsonl"            ""                "None"  "SAP okunamadı"
# 🔴 ASIL VAKA: defter erişilemez. Eskiden bu True ('kesilmiş') dönüyordu ve fatura SESSİZCE düşüyordu.
uc_durum "/config/olmayan-dizin/yok.jsonl" "SINAV-KESILMIS" "None" "defter AÇILAMIYOR (altyapı)"
# ⚠️ 'chmod 000 dosya' vakası GERÇEKÇİ DEĞİL: dosyanın sahibi biziz ve defter.sh açılışta
#    chmod 600 ile izni kendisi ONARIYOR. Onarılamayan bir arıza kullanılır: yolda DİZİN var.
mkdir -p "$TMP/dizin-engeli"
uc_durum "$TMP/dizin-engeli"       "SINAV-KESILMIS"  "None"  "defter yolunda DİZİN var (altyapı)"

echo
echo "S3b · defter.sh — rc sözleşmesi ve üzerine-yazmama"
rc_bekle(){  # rc_bekle <beklenen-rc> <ad> <args...>
  local bek="$1" ad="$2"; shift 2
  ARCELIK_KESIM_DEFTERI="$TMP/d.jsonl" bash defter.sh "$@" >/dev/null 2>&1
  local rc=$?
  [[ $rc -eq $bek ]] && gec "$ad (rc=$bek)" || dus "$ad — beklenen rc=$bek geldi rc=$rc"
}
rc_bekle 0 "sor: defterde YOK → yol açık"        sor "SINAV-YOK"
rc_bekle 1 "sor: KESİLMİŞ → DUR"                 sor "SINAV-KESILMIS"
rc_bekle 3 "sor: İPTAL kaydı → insan kararı"     sor "SINAV-IPTAL"
rc_bekle 1 "yaz: aynı SAP'a ÜZERİNE YAZMAZ"      yaz "SINAV-KESILMIS" "YYY2026000000001" "5.00"
ARCELIK_KESIM_DEFTERI="/config/olmayan-dizin/yok.jsonl" bash defter.sh sor "X" >/dev/null 2>&1
[[ $? -eq 5 ]] && gec "altyapı hatası KENDİ kodunu taşıyor (rc=5, 1 DEĞİL)" \
                || dus "altyapı hatası semantik koda çarpıyor — 'kesilmiş' sanılır"

echo
echo "S4 · fatura talebi — 'son kesilen' defterden okunur, okunamazsa ÖLÇÜLEMEDİ (asla 'yok' değil)"
printf '{"sap":"BIZPUAN-2026-08","fatura_no":"T1","tutar":"1.00","tarih":"2026-08-31","durum":"kesildi","kaydeden":"SINAV"}\n{"sap":"BIZPUAN-2026-09","fatura_no":"T2","tutar":"2.00","tarih":"2026-09-30","durum":"kesildi","kaydeden":"SINAV"}\n' > "$TMP/t.jsonl"
talep_bak(){  # talep_bak <defter> <tür> <beklenen-alt-dize> <ad>
  local o; o=$(ARCELIK_KESIM_DEFTERI="$1" python3 -c "
import sys; sys.path.insert(0,'.')
import tara; print(tara.son_kesilen('$2'))" 2>&1)
  [[ "$o" == *"$3"* ]] && gec "$4" || dus "$4 — geldi: $o"
}
talep_bak "$TMP/t.jsonl" bizpuan "BIZPUAN-2026-09 → T2" "son kesilen = EN SON kayıt"
talep_bak "$TMP/t.jsonl" klima "kayıt YOK" "türden kayıt yoksa açıkça YOK der"
talep_bak "/config/olmayan-dizin/yok.jsonl" bizpuan "ÖLÇÜLEMEDİ" "defter açılamıyor → ÖLÇÜLEMEDİ"
bu_bak(){  # bu_bak <defter> <tür> <konu> <mail-tarihi> <beklenen-alt-dize> <ad>
  local o; o=$(ARCELIK_KESIM_DEFTERI="$1" python3 -c "
import sys; sys.path.insert(0,'.')
import tara; print(tara.bu_talep(*sys.argv[1:4]))" "$2" "$3" "$4" 2>&1)
  [[ "$o" == *"$5"* ]] && gec "$6" || dus "$6 — geldi: $o"
}
bu_bak "$TMP/t.jsonl" bizpuan "BİZPUAN ÖDÜL FATURA TALEBİ -Ağustos 2026" 2026-09-03 "KESİLMİŞ: BIZPUAN-2026-08 → T1" "Ağustos talebi Ağustos kaydına eşlenir (en sona DEĞİL)"
bu_bak "$TMP/t.jsonl" iskonto "2026/9 Eylül Ayı İskonto Fatura Talebi" 2026-10-02 "defterde YOK (ISKONTO-2026-09)" "kesilmemiş talep 🔴 YOK der"
bu_bak "$TMP/t.jsonl" bizpuan "BİZPUAN ÖDÜL FATURA TALEBİ" 2026-10-02 "okunamadı" "dönem yoksa TAHMİN etmez"
bu_bak "$TMP/t.jsonl" bizpuan "BİZPUAN ÖDÜL FATURA TALEBİ Ağustos-Eylül 2026" 2026-10-02 "okunamadı" "iki ay geçiyorsa TAHMİN etmez"
bu_bak "/config/olmayan-dizin/yok.jsonl" bizpuan "BİZPUAN ÖDÜL FATURA TALEBİ -Eylül 2026" 2026-10-02 "ÖLÇÜLEMEDİ" "defter açılamıyor → ÖLÇÜLEMEDİ"
o=$(python3 -c "import sys; sys.path.insert(0,'.'); import tara; print(tara.talep_turu('KLİMA MONTAJ DESTEK PRİM FATURA TALEBİ'), tara.talep_turu('Ekim Ayı İskonto Fatura Talebi'))")
[[ "$o" == "klima iskonto" ]] && gec "talep türü konudan doğru (klima · iskonto)" || dus "talep türü yanlış: $o"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
