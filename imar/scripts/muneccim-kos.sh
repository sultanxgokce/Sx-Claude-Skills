#!/usr/bin/env bash
# muneccim-kos.sh — MÜNECCİM'in İNSANSIZ (headless) araştırma turu.
#
# NİÇİN AYRI BİR BETİK: muneccim-baslat.sh bir tmux penceresi açıp İNTERAKTİF claude başlatır
# ve kimliğin elle yapıştırılmasını bekler. Günde 3 tur dönecek bir çark için bu uygun değil —
# insan eli isteyen hiçbir adım günde üç kez yapılmaz. Bu betik aynı kişiyi (MÜNECCİM) insansız
# koşturur: brifini dosyalardan kendisi kurar, turu koşar, devrini yazar, çıkar.
#
# Kullanım:
#   bash scripts/muneccim-kos.sh --kuru     # KURU KOŞUM: ne yapacağını basar, model çağırmaz
#   bash scripts/muneccim-kos.sh            # gerçek tur (model çağırır)
#   bash scripts/muneccim-kos.sh --aci "…"  # bugünün açısını dışarıdan ver (çark tetiklerse)
#
# Çıkış: 0 tur koştu · 2 kullanım · 3 ÖLÇÜLEMEDİ (konu/klasör yok) · 4 kilit meşgul (tur üst üste binmesin)
set -uo pipefail

# ——— cron dar PATH ile koşar; claude'a ihtiyacı olan betik kendi yolunu kendi bulur
# (ölçüldü 3 Ekim: ilk otomatik yuva "claude komutu yok" diye düştü). Çağıran zincir
# onarılsa bile bu betik TEK BAŞINA da koşabilmeli — savunma çağıranda değil, kullananda.
for _d in "$HOME"/.nvm/versions/node/*/bin; do
  [ -x "$_d/claude" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH";; esac
done
export PATH

KURU=0; ACI=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kuru) KURU=1; shift;;
    --aci) ACI="${2:-}"; shift 2;;
    -h|--help) sed -n '3,16p' "$0"; exit 0;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2;;
  esac
done

EV="${MUNECCIM_EV:?MUNECCIM_EV yok — profil çözülmedi (imar-profil.py cozumle)}"
SERI="$EV/arastirma-serisi"
KONU="$SERI/KONU.md"
DEFTER="$SERI/KAYIT-DEFTERI.md"
GUNLUK="$SERI/gunluk"
DERSLER="$SERI/DERSLER.md"
KUYRUK="$SERI/KUYRUK.md"
KILIT="/tmp/muneccim-kos.lock"
BUGUN="$(date +%F)"

# ——— ön-kapılar: ölçemediğini söyle, uydurma ———
[ -d "$SERI" ] || { echo "ÖLÇÜLEMEDİ: seri klasörü yok ($SERI)" >&2; exit 3; }
[ -s "$KONU" ] || { echo "ÖLÇÜLEMEDİ: KONU.md boş — kimlik kuralı: konu açılmadan araştırma YOK" >&2; exit 3; }
# Konu kapalıysa bu bir ARIZA değil, bekleme hâlidir (Seri-2 kapanışı, 8 Ekim): rc=5 → zamanlayıcı
# yuvayı "konu kapalı" diye atlar; kota harcanmaz, model çağrılmaz, alarm çalmaz.
if head -1 "$KONU" | grep -q "KONU KAPALI"; then echo "konu kapalı — yeni konu açılana dek tur yok ($KONU)"; exit 5; fi
command -v claude >/dev/null 2>&1 || { echo "ÖLÇÜLEMEDİ: claude komutu yok" >&2; exit 3; }
mkdir -p "$GUNLUK"

# ——— brif: kişi-katmanından kurulur (oturum hafızasından DEĞİL) ———
BRIF="$(mktemp)"; trap 'rm -f "$BRIF"' EXIT
{
  echo "Sen MÜNECCİM'sin — MİHENK'in tek-konuya adanmış araştırma görevlisi."
  echo "Bu İNSANSIZ bir turdur: kimse ekranda değil, soru soramazsın, onay isteyemezsin."
  echo
  echo "## Konun (değişmez)"
  sed -n '1,40p' "$KONU"
  echo
  if [ -s "$DERSLER" ]; then
    # 🔴 tail -n 60 KEYFİ bir kesitti ve çürütülmüş dersi ayakta olanla aynı tonda gösteriyordu
    # (ölçüldü 14 Ekim: 15 dersin 4'ü çürük, kesitte yalnız 2'si vardı). Ayırıcı araç:
    if [ -r "$(dirname "$0")/dersler-brif.py" ] && python3 "$(dirname "$0")/dersler-brif.py" "$DERSLER" --son 8 2>/dev/null; then :
    else
      echo "## Kendi derslerin (geçmiş turlardan — ÖNCE BUNLARI OKU)"
      echo "_(ayırıcı araç koşmadı; ham kesit veriliyor — çürütülmüş dersler de bu listede olabilir)_"
      tail -n 60 "$DERSLER"
    fi
    echo
  else
    echo "## Kendi derslerin: HENÜZ YOK (ilk tur) — bu turun sonunda en fazla 3 ders yazacaksın."
    echo
  fi
  if [ -s "$KUYRUK" ]; then
    echo "## Sıradaki tura bırakılan kuyruk (önceki tur yazdı)"
    sed -n '/^## Açık/,/^## Kapanan/p' "$KUYRUK" | head -n 20
    echo
  fi
  # Kutudaki araçlar: tur "kutuda X yok" diye iki gün kanıtsız kaldı, araç kurulunca da haberi olmazdı.
  # Araç listesi brife girer; ARAÇ EKLENDİĞİNDE BU BLOK GÜNCELLENİR (bu satır onun tetiğidir).
  echo "## Kanıt kapısı — bağımsız gözün bu seride EN ÇOK çürüttüğü üç kalıp (ölçüldü 14 Ekim · 6 çürütme)"
  echo "- **Satıcının kendi sayfası kanıt değildir** (3 çürütme): liste fiyatı, forum beyanı, satıcının ısmarladığı anket"
  echo "  bir fiyatın yayımlandığını gösterir, birinin o parayı ÖDEDİĞİNİ göstermez. Kanıt sınıfını 'kaynak (satıcı)' yaz."
  echo "- **\"Bulamadım\" ≠ \"yok\"** (2 çürütme): okuduğun sayfalarda geçmiyorsa ders 'şu N sayfada geçmiyor' der,"
  echo "  'yükümlülük yok' demez. Olumsuz iddia ancak aranan yerler sayılırsa yazılır."
  echo "- **İddia kanıttan büyük olmasın** (2 çürütme): tek ülkenin resmî sayfası 'AB deseni' sonucunu taşımaz;"
  echo "  koyduğun her onay işaretinin altında o satırı taşıyan alıntı olmalı."
  echo "Bu üç kalıbı tekrarlayan ders bu gece yine çürür; çürük ders defterde kalır ama üstüne inşa edilmez."
  echo
  echo "## Kutudaki araçlar (bunlar VAR — 'kutuda yok' demeden önce dene)"
  echo "- PDF → metin: node $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/pdf/pdf-metin.mjs <dosya|url> [--sayfa 1-5] [--ara \"cümle\"]"
  echo "- Robot kapılı sayfa (EUR-Lex, ELI, curl'e 'verify you are not a robot' döndüren siteler) → node scripts/tarayici/sayfa-metin.mjs <url> [--ara \"cümle\"] [--bekle sn]: GERÇEK tarayıcıyla açar, düz metni basar (ViDA direktifi 102 K karakter okundu, 12 Ekim). Görsel-kod (captcha) isteyen sayfayı geçemez, rc 2 döner."
  echo "  (rc=2 → metin katmanı yok, taranmış görüntü; OCR yok. Bunu 'okunamadı' diye dürüstçe yaz.)"
  echo "- Bir araç gerçekten yoksa DEVİR'e tek satır yaz: 'Kutu eksiği: <ne, niçin gerekti>' — o satır deftere düşer, insan görür."
  echo
  echo "## Nerede kaldın (kayıt defterinin sonu)"
  tail -n 25 "$DEFTER" 2>/dev/null || echo "(defter boş)"
  echo
  [ -n "$ACI" ] && { echo "## Bu turun açısı (dışarıdan verildi)"; echo "$ACI"; echo; }
  cat <<'KURAL'
## Bu turda yapacakların (sıra değişmez)
1. Yukarıdaki dersleri ve defteri oku; üç satırla "nerede kaldık" yaz.
2. Henüz kazılmamış TEK bir açı seç (açı dışarıdan verildiyse onu kullan).
3. O açıyı araştır. Her olgusal iddia kaynağa-tıklanır olmalı (iddia → URL → alıntı).
   Şikayet ≠ ödeme, ilgi ≠ talep: ayrı işaretle. Emin değilsen "düşük güven" yaz.
4. DEVİR yaz (bu tur bitmiş sayılmaz yoksa):
   - ne yaptım (3-5 satır)
   - EN FAZLA 3 ders · her biri: İDDİA · KANIT · NE OLURSA ÇÜRÜR
   - şu an neredeyim
   - sıradaki tura kuyruk (tek cümle)
   Devir biçimi: DEVIR-SABLONU.md ile aynı dört başlık.
5. Boş tur onurludur: yeni bir şey çıkmadıysa "bu turda yeni sinyal yok" de ve niçin olduğunu yaz.
   Uydurma bulgu, dolgu cümle, "muhtemelen/olmalı" YASAK.

Çıktını tek parça markdown olarak ver; başına "# MÜNECCİM turu" yaz.
KURAL
} > "$BRIF"

BOYUT="$(wc -c < "$BRIF")"; SATIR="$(wc -l < "$BRIF")"
CIKTI="$GUNLUK/$BUGUN-tur.md"

if [ "$KURU" = "1" ]; then
  echo "KURU KOŞUM — model ÇAĞRILMADI"
  echo "  ev        : $EV"
  echo "  konu      : $(head -1 "$KONU" | cut -c1-70)"
  DSAY=0; [ -s "$DERSLER" ] && DSAY="$(wc -l < "$DERSLER")"
  echo "  dersler   : $DSAY satır"
  echo "  brif      : $SATIR satır · $BOYUT bayt"
  echo "  araçlar   : $(grep -q 'Kutudaki araçlar' "$BRIF" && echo 'brifte VAR (pdf-metin)' || echo 'brifte YOK')"
  echo "  çıktı     : $CIKTI"
  echo "  kilit     : $KILIT"
  exit 0
fi

# ——— tek tur aynı anda: üst üste binen turlar defteri bozar ———
exec 9>"$KILIT"
flock -n 9 || { echo "KİLİT MEŞGUL: önceki tur sürüyor — bu tur atlandı" >&2; exit 4; }

BAS="$(date -Iseconds)"
claude -p "$(cat "$BRIF")" > "$CIKTI" 2>"$CIKTI.hata"; RC=$?
BIT="$(date -Iseconds)"

if [ "$RC" -ne 0 ] || [ ! -s "$CIKTI" ]; then
  echo "TUR DÜŞTÜ (rc=$RC) — hata: $CIKTI.hata" >&2
  printf '\n## %s — [TUR DÜŞTÜ] rc=%s · brif %s satır · hata: %s\n' \
    "$BIT" "$RC" "$SATIR" "$(tail -c 200 "$CIKTI.hata" 2>/dev/null | tr '\n' ' ')" >> "$DEFTER"
  exit 1
fi

# ——— makbuz: tur koştuysa iz kalır; sessizlik 'temiz' sayılmaz ———
printf '\n## %s — [TUR] insansız koşu · brif %s satır · çıktı %s bayt · süre %s→%s · dosya: gunluk/%s\n' \
  "$BIT" "$SATIR" "$(wc -c < "$CIKTI")" "${BAS#*T}" "${BIT#*T}" "$(basename "$CIKTI")" >> "$DEFTER"
# ——— KAPI: devir kişi katmanına taşınır; devir yoksa tur YARIM damgalanır ———
AYIKLA="$(dirname "$0")/devir-ayikla.py"
if [ -f "$AYIKLA" ]; then
  TASIMA="$(python3 "$AYIKLA" "$CIKTI" 2>&1)"; ARC=$?
  echo "$TASIMA"
  if [ "$ARC" -eq 1 ]; then
    printf '## %s — [YARIM] tur DEVİR yazmadı; dersler ve kuyruk taşınamadı. Sıradaki tur önce bunu kapatır.\n' \
      "$(date -Iseconds)" >> "$DEFTER"
  elif [ "$ARC" -eq 2 ]; then
    # "yazılmamış" ile "okunamadı" ayrı suçlamadır (ölçüldü 11 Ekim: iki turun 6 dersi yazılmıştı, kapı okuyamadı ve sustu)
    printf '## %s — [YARIM] DEVİR yazıldı ama ayıklayıcı OKUYAMADI (biçim kaydı): %s\n' \
      "$(date -Iseconds)" "$TASIMA" >> "$DEFTER"
  else
    printf '## %s — [DEVİR] %s\n' "$(date -Iseconds)" "$TASIMA" >> "$DEFTER"
  fi
fi
echo "✅ tur koştu → $CIKTI"
