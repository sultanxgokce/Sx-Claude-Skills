#!/usr/bin/env bash
# i1.test.sh — ORTAK RAF DİZİN-GENELİ İ1 TARAMASI. Ağa çıkmaz, dosya yazmaz.
#
# 🔴 NİÇİN VAR (MUAVİN ölçümü 2026-08-23 — adopsiyonu DURDURAN bulgu):
#    `/config/.claude/skills` 16 kutunun ORTAK gördüğü yerdir ve kanonik depo
#    (`Sx-Claude-Skills`) **PUBLIC**'tir. Ortak rafa yazılan her satır oraya adopte edilir.
#    Ölçüm: kanonik depoda zaten kuruma-özel veri deseni var (14 sayı / 5 dosya,
#    35 firma-adı / 11 dosya). Adopsiyon onu **büyütürdü** → MUAVİN paketlemeyi durdurdu.
#
# 🔴 NİÇİN SINAV, KONTROL LİSTESİ DEĞİL: bu kural becerilerin metinlerinde DÖRT yerde
#    yazılıydı ("ŞİRKETSİZ: burada firma adı, VKN, cari GEÇMEZ") ve yine de dokuz konumda
#    ihlal edilmişti. Mevcut sınavlar bunu görmedi çünkü hepsi MODÜL-BAŞIYDI: her sınav
#    yalnız kendi modülünü tarıyordu, ihlaller aradan geçiyordu. Tarama DİZİN-GENELİ olmalı.
#
# Ayırt edici test (her satır için): **"bu satır ikinci bir tüzel kişide de aynı mı kalır?"**
#   kalır  → protokol · şema · kuruş kuralı · tuzaklar · kapılar
#   kalmaz → ünvan · VKN · vergi dairesi · adres · posta kutusu etiketi · SAP · gerçek tutar
#
# ╔══════════════════════════════════════════════════════════════════════════════════════╗
# ║ 🔴 BU SINAVIN DEĞİŞMEZİ — SINAV DEĞER DEĞİL BİÇİM ARAR                               ║
# ║                                                                                      ║
# ║ Bu sınav hiçbir gerçek değeri BİLMEZ ve bilmemelidir. **Bilmediği şeyi sızdıramaz.** ║
# ║ Aradığı şey "şu VKN" değil, "bağlam içinde 10-11 haneli sayı"dır.                    ║
# ║                                                                                      ║
# ║ Niçin: denetçi, denetlediği şeyin bir örneğini kendi içinde taşırsa kendini          ║
# ║ denetleyemez. Bu sınavın atası tam bunu yapıyordu — gerçek VKN'yi, firma adını,      ║
# ║ cari adını ARAMA DESENİ olarak taşıyordu; sızıntı arayan sınavın kendisi sızıntıydı. ║
# ║                                                                                      ║
# ║ ⚠️ İKİ TUZAK, ikisi de denendi ve ikisi de yanlıştı:                                 ║
# ║   (a) kurnaz/geri-referanslı desen  → grep'te tutmadı, yalancı-pozitif üretti        ║
# ║   (b) izinli DEĞER listesi          → listeye bir gün gerçek bir değer eklenirse     ║
# ║       sızıntı arayan sınav sızıntıyı ELİYLE beyaz-listeler. Aynı hatanın tohumu.     ║
# ║                                                                                      ║
# ║ DOĞRUSU: fikstürün sahteliği YAPISINDAN anlaşılır (i1_sahte_suzgec.py) — tek hane    ║
# ║ tekrarı · artan/azalan ardışık dizi · ≤2 farklı hane. Bunun DIŞINDAKİ her sayı       ║
# ║ GERÇEK VARSAYILIR (fail-closed). Yeni fikstür yazan: BAKIŞTA SAHTE olsun.            ║
# ║ Gerçekçi görünen sahte değer yazma — onu bir daha kimse ayıramaz.                    ║
# ║                                                                                      ║
# ║ Muafiyet **dosya ADINA** göre verilir, DEĞERE göre değil (aşağıda SENTETIK).         ║
# ╚══════════════════════════════════════════════════════════════════════════════════════╝
set -uo pipefail
SUZGEC="$(cd "$(dirname "$0")" && pwd)/i1_sahte_suzgec.py"   # cd'den ÖNCE mutlaklaştır
cd "$(dirname "$0")/../.."          # /config/.claude/skills
export PYTHONDONTWRITEBYTECODE=1
GECEN=0; DUSEN=0

# Taranan beceriler — bu kutunun sorumlu olduğu raf bölümü
BECERILER="elogo-erisim elogo-portal-otomasyon arcelik-fatura-kesim arcelik-mail-erisim"

# 🔴 İZİNLİ SAHTE DEĞERLER: sınav fikstürleri gerçek gibi görünmemeli. Bu liste
#    GENİŞLETİLİRKEN dikkat: buraya bir gerçek değer eklemek, kapıyı sessizce delmektir.
# 🔴 SINAV DEĞER DEĞİL, BİÇİM ARAR (Sultan kuralı 2026-08-23).
#    Buranın ilk hâli kurnaz bir geri-referanslı ERE'ydi ve grep'te tutmadı.
#    İkinci hâli AÇIK DEĞER LİSTESİYDİ — ve o da aynı hatanın tohumuydu: bir gün
#    listeye gerçek bir değer eklenirse, sızıntı arayan sınav sızıntıyı ELİYLE
#    beyaz-listeler. Değer listesi tutmak, denetçiyi yeniden sızıntı yapar.
#    Doğrusu: fikstürün SAHTE OLDUĞU YAPISINDAN anlaşılmalı — tek haneli tekrar
#    (1111111111) ya da artan/azalan dizi (1234567890). Bunu grep yapamaz; ayrı
#    bir süzgeç yapar ve hiçbir gerçek değeri BİLMESİ gerekmez.
IZINLI_ALIAS='ornekfirma|baskafirma|ornek\.com|example\.com|<kutu>@<firma>|sinav@ornek'

bul(){  # bul "<ad>" "<desen>" [ek-eleme]
  local ad="$1" desen="$2" ek="${3:-}" cikti
  cikti=$(grep -rInE "$desen" --include='*.py' --include='*.sh' --include='*.md' --include='*.json' \
            $BECERILER 2>/dev/null | grep -v '__pycache__' || true)
  # sahte fikstürleri ve kuralın KENDİSİNİ anlatan satırları ele
  cikti=$(python3 "$SUZGEC" <<<"$cikti" || true)
  [[ -n "$ek" ]] && cikti=$(grep -vE "$ek" <<<"$cikti" || true)
  # kuralı ANLATAN satırlar (ŞİRKETSİZ ilanı, ayırt edici test, bu sınavın kendisi) sayılmaz
  cikti=$(grep -vE 'ŞİRKETSİZ|şirketsiz|İ1|i1\.test|ayırt edici|GEÇMEZ|yazılmaz|kalmaz|kutu-yerel' <<<"$cikti" || true)
  if [[ -z "$cikti" ]]; then
    GECEN=$((GECEN+1)); printf '  ✓ %s\n' "$ad"
  else
    DUSEN=$((DUSEN+1)); printf '  ✗ %s — %s konum:\n' "$ad" "$(wc -l <<<"$cikti")"
    # 🔴 DEĞER BASILMAZ: yalnız dosya:satır. Sızıntıyı raporlarken sızdırmak olmaz.
    awk -F: '{printf "      %s:%s\n", $1, $2}' <<<"$cikti" | head -12
  fi
}

echo "İ1 · ORTAK RAFTA KURUMA-ÖZEL VERİ (değer BASILMAZ, yalnız konum)"
bul "VKN/TCKN sınıfı sayı yok"        '\b[0-9]{10,11}\b'
bul "posta kutusu etiketi yok"        'urn:mail:[A-Za-z0-9._-]+@[A-Za-z0-9.-]+' "$IZINLI_ALIAS"
bul "tüzel kişi ünvanı yok"           '(LİMİTED|LIMITED) (ŞİRKET|SIRKET)|ANONİM ŞİRKET' 'ÖRNEK|BAŞKA ÖRNEK'
bul "SAP belge no yok"                '\b[0-9]{15,20}\b'
bul "e-posta adresi yok"              '[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.(com|tr|net|org)' "$IZINLI_ALIAS|noreply|example"

echo
echo "İ1b · GÖVDE ŞİRKETSİZ Mİ — kimlik yalnız ÇAĞRI SINIRINDAN gelmeli"
# Gövde dosyaları bir tüzel kişiyi SABİT olarak taşımamalı: Taraf(...) çağrısı gövdede
# LİTERAL argümanlarla kurulmuşsa, o kimlik oraya gömülmüş demektir.
govde_taraf=$(grep -rInE '^[A-Z_]+ *= *Taraf\(' --include='*.py' $BECERILER 2>/dev/null \
  | grep -v '__pycache__' || true)
if [[ -z "$govde_taraf" ]]; then
  GECEN=$((GECEN+1)); echo "  ✓ gövdede sabit Taraf tanımı yok (kimlik çağrı parametresi)"
else
  DUSEN=$((DUSEN+1)); echo "  ✗ gövdede sabit Taraf tanımı VAR:"
  awk -F: '{printf "      %s:%s\n", $1, $2}' <<<"$govde_taraf"
fi

echo
echo "İ1c · KUTU-YEREL TÜREV YERİNDE Mİ"
TUREV="${ELOGO_TUREV:-/config/projects/MMEx/_agents/fatura}"
# 🔴 Bu bölüm KUTU kapısıdır: türev yalnız MMEx kutusunda yaşar. Temiz CI makinesinde (CI=true) dizin
#    hiç yoksa ölçülemez → "ÖLÇÜLEMEDİ" basılır ve sayılmaz. Başka HER yerde (kutu dahil) dizin yoksa
#    KIRMIZI kalır — yoksa türevin taşınması/silinmesi sessizce yeşile döner.
#    Atlama YALNIZ üç koşul birlikteyken: CI=true · ELOGO_TUREV AÇIKÇA VERİLMEMİŞ · varsayılan dizin yok.
#    Açıkça verilmiş ama yanlış/eksik yol yapılandırma hatasıdır → CI'da da KIRMIZI (denetçi tur 2).
if [[ ! -d "$TUREV" && "${CI:-}" == "true" && -z "${ELOGO_TUREV:-}" ]]; then
  echo "  ⚠ ÖLÇÜLEMEDİ: kutu-yerel türev dizini bu makinede yok (CI) — İ1c sayılmadı"
else
for f in taraflar.py mmex_fatura.py numara_olcum.py OKU-BENI.md; do
  if [[ -f "$TUREV/$f" ]]; then GECEN=$((GECEN+1)); echo "  ✓ türev: $f"
  else DUSEN=$((DUSEN+1)); echo "  ✗ türev EKSİK: $f — kimlik nereye gitti?"; fi
done
fi
# 🔴 Türev, gövdeyi import EDER; gövde türevi ETMEZ. Ters bağımlılık İ1'i geri getirir.
# 🔴 Desen DAR olmalı: ilk hâli çıplak 'taraflar' arıyordu ve Türkçe bir yorum
#    cümlesindeki "taraflardan ÖNCE" ifadesini bulguya çevirdi (yalancı-pozitif).
#    Aranan şey bir KELİME değil, bir BAĞIMLILIK: import ifadesi.
ters=$(grep -rInE '^\s*(from|import)\s+taraflar\b' --include='*.py' $BECERILER 2>/dev/null | grep -v '__pycache__' || true)
if [[ -z "$ters" ]]; then
  GECEN=$((GECEN+1)); echo "  ✓ gövde türevi import ETMİYOR (bağımlılık yönü doğru)"
else
  DUSEN=$((DUSEN+1)); echo "  ✗ gövde türeve bağlanmış — İ1 geri sızar:"; echo "$ters" | head -3
fi

echo
echo "İ1d · KALINTI — temizlenen dosyanın temizlenmemiş KOPYASI kalmasın"
# 🔴 MUAVİN'in BİÇİM taraması bunu buldu, benim DEĞER taramam GÖRMEDİ (2026-08-23):
#    `elogo_gonder.py` temizlendi ama `elogo_gonder.py.oncesi` yanında duruyordu —
#    BAŞKA BİR DOSYA olduğu için temizlikten etkilenmemişti, içinde 22 Ağustos hâli vardı.
#    Bu, temizliği boşa çıkaran kalıntı sınıfıdır: "dosyayı düzelttim" dersin ve
#    düzeltmediğin bir kopyası yanında durur. `__pycache__` de aynı sınıf.
#    Yedek istiyorsan kutu-yerel türevde tut — ortak rafta DEĞİL.
# 🔴 ŞİDDET AYRIMI (bilinçli): iki kalıntı sınıfı aynı şey değil.
#   (a) ELLE YAZILMIŞ yedek (.oncesi/.bak/.orig/~) → BULGU. Temizlikten etkilenmez,
#       içinde eski hâl durur, ve kimse onu tazelemez. MUAVİN'in bulduğu tam buydu.
#   (b) ÜRETİLEN bayt kodu (__pycache__) → UYARI, rc'yi bozmaz. Her python koşumunda
#       yeniden doğar; kırmızı yapmak kapıyı "her zaman kırmızı"ya çevirir ve o kırmızı
#       NORMALLEŞİR — kapının kendisi işe yaramaz hâle gelir. Ama görünmez de olmamalı:
#       bugün mutasyon koşumunda bayat .pyc YANLIŞ KIRMIZI üretti (C-kaydı).
elle_yedek=$(find $BECERILER \( -name '*.oncesi' -o -name '*.bak' -o -name '*.orig' \
           -o -name '*.yedek*' -o -name '*~' -o -name '*.eski' \) 2>/dev/null || true)
if [[ -z "$elle_yedek" ]]; then
  GECEN=$((GECEN+1)); echo "  ✓ ortak rafta elle yazılmış yedek/kalıntı dosya yok"
else
  DUSEN=$((DUSEN+1)); echo "  ✗ KALINTI VAR — temizlik bunları KAPSAMAZ:"
  sed 's/^/      /' <<<"$elle_yedek" | head -8
fi
uretilen=$(find $BECERILER -name '__pycache__' -type d 2>/dev/null || true)
if [[ -n "$uretilen" ]]; then
  echo "  ⚠ üretilmiş bayt kodu var (rc'yi bozmaz, ama bayat .pyc yanlış kırmızı üretebilir):"
  sed 's/^/      /' <<<"$uretilen" | head -4
  echo "      temizlik:  find <beceri> -name '*.pyc' -delete"
fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
