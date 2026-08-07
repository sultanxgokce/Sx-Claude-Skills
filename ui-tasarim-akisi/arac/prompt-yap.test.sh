#!/usr/bin/env bash
# prompt-yap.test.sh — iki kapının sınavı: Durak 0 (ürün niyeti) + ölçüm ön-koşulu.
# Hem yeni kapıları hem ESKİ davranışın regresyonunu kapsar (boş sözleşme kaçağı).
set -u

ARAC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(dirname "$ARAC")"
YAP="$ARAC/prompt-yap.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
GECTI=0; KALDI=0

# Sınav GERÇEK havuza yazmaz. Ölçülmüş vaka: bu satır yokken sınavın kendi koşusu
# kullanıcının canlı defterine 6 sahte kayıt düşürdü ("kutu: ui-tasarim-akisi").
# Sınav-verisi ile saha-verisi aynı deftere karışırsa defter yalan söylemeye başlar.
export UI_AKIS_HAVUZ="$T/sinav-havuzu.jsonl"

kapi() { # kapi <ad> <beklenen-rc> <komut...>
  local ad="$1" bek="$2"; shift 2
  local cikti rc
  cikti="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$bek" ]; then echo "  ✓ $ad (rc=$rc)"; GECTI=$((GECTI + 1))
  else echo "  ✗ $ad — beklenen rc=$bek, gelen rc=$rc"; echo "$cikti" | sed 's/^/      /'
       KALDI=$((KALDI + 1)); fi
  SON="$cikti"
}
icerir() {
  if printf '%s' "$SON" | grep -qF -- "$2"; then echo "  ✓ $1"; GECTI=$((GECTI + 1))
  else echo "  ✗ $1 — çıktıda yok: $2"; KALDI=$((KALDI + 1)); fi
}

# ── ortak fikstür ─────────────────────────────────────────────────────────────
mkdir -p "$T/tasarim"
printf '# dil\nrenk: #123456\n' > "$T/tasarim/tasarim-dili.md"
printf '# estetik\nkarakter: sakin\n'  > "$T/tasarim/estetik-yon.md"

# minimal şablon (Durak 0 yuvalı)
cat > "$T/sablon-niyetli.md" <<'MD'
# başlık
> bu satır çıktıya girmez
---
NIYET-BASI
{{URUN_NIYETI}}
NIYET-SONU
{{TASARIM_DILI}}
{{ESTETIK_YON}}
MD
# minimal devam şablonu (önceki HTML yuvalı, niyetsiz — eski akış)
cat > "$T/sablon-devam.md" <<'MD'
# başlık
> bu satır çıktıya girmez
---
{{ONCEKI_HTML}}
{{TASARIM_DILI}}
{{ESTETIK_YON}}
MD

niyet_yaz() { # niyet_yaz <dosya> <dolu|bos>
  if [ "$2" = "dolu" ]; then
    printf '## 1\nSeçim: A\nKendi cümlem: Kira takip eden bir kayıt aracı.\n\n## 2\nKendi cümlem: Günde bir, iki dakika.\n' > "$1"
  else
    printf '## 1\nSeçim: A\nKendi cümlem: Kira takip eden bir kayıt aracı.\n\n## 2\nKendi cümlem:\n' > "$1"
  fi
}

echo "── 1 · Durak 0 dosyası yoksa prompt üretilmez"
kapi "niyet dosyası yok → rc=2" 2 bash "$YAP" "$T/sablon-niyetli.md" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md" \
     --niyet "$T/tasarim/yok.md"
icerir "çözüm satırı gösterilir" "sablonlar/urun-niyeti.md"

echo "── 2 · boş 'Kendi cümlem:' → prompt üretilmez (şık seçmek yetmez)"
niyet_yaz "$T/tasarim/urun-niyeti.md" bos
kapi "yarım niyet → rc=2" 2 bash "$YAP" "$T/sablon-niyetli.md" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md" \
     --niyet "$T/tasarim/urun-niyeti.md"
icerir "hangi satır boş söylenir" "#2"

echo "── 3 · dolu niyet → üretilir ve gövdesi prompta GİRER"
niyet_yaz "$T/tasarim/urun-niyeti.md" dolu
kapi "dolu niyet → rc=0" 0 bash "$YAP" "$T/sablon-niyetli.md" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md" \
     --niyet "$T/tasarim/urun-niyeti.md"
icerir "niyet gövdesi gömüldü" "Kira takip eden bir kayıt aracı."
icerir "sözleşme de gömüldü" "renk: #123456"

echo "── 4 · ölçüm kapısı: ÖNCEKİ sayfa kırmızıysa devam promptu ÜRETİLMEZ"
mkdir -p "$T/kirli"
cp "$ARAC/fikstur/kirli/"*.html "$T/kirli/" 2>/dev/null
cp "$ARAC/fikstur/kapi-profili.json" "$T/kapi-profili.json"
ILK="$(ls "$T/kirli/"*.html | head -1)"
kapi "kırmızı önceki → rc=1" 1 bash "$YAP" "$T/sablon-devam.md" --onceki "$ILK" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "sebep söylenir" "yoğunluk kapısından GEÇMEDİ"

echo "── 5 · TIK KAPISI: yoğunluk temiz olsa bile tık ölçülmeden geçilmez"
mkdir -p "$T/temiz"
cp "$ARAC/fikstur/temiz/"*.html "$T/temiz/"
TEMIZ_ILK="$(ls "$T/temiz/"*.html | head -1)"
kapi "tık ölçümü yok → rc=3" 3 bash "$YAP" "$T/sablon-devam.md" --onceki "$TEMIZ_ILK" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "iki şeyin farkı söylenir" "tık BAKILMAMIŞ"
icerir "çözüm aracı gösterilir" "tik-kaydet.sh"

echo "── 5b · tık ölçülünce geçer"
bash "$ARAC/tik-kaydet.sh" "$TEMIZ_ILK" G1=3:2 G2=2:2 >/dev/null
kapi "tık taze → rc=0" 0 bash "$YAP" "$T/sablon-devam.md" --onceki "$TEMIZ_ILK" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "önceki sayfa gövdesi gömüldü" "<!-- bilesen: Gezinme -->"

echo "── 5c · BAYAT ölçüm 'temiz' sayılmaz (asıl saldırı yüzeyi)"
printf '<!-- degisti -->\n' >> "$TEMIZ_ILK"
kapi "sayfa değişti, ölçüm eski → rc=3" 3 bash "$YAP" "$T/sablon-devam.md" --onceki "$TEMIZ_ILK" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "bayat denir" "BAYAT"
bash "$ARAC/tik-kaydet.sh" "$TEMIZ_ILK" G1=3:2 G2=2:2 >/dev/null   # yeniden ölç

echo "── 5d · bütçe AŞIMI ölçülmüştür → rc=1 (bu 'bakılamadı' değil)"
bash "$ARAC/tik-kaydet.sh" "$TEMIZ_ILK" G1=3:7 >/dev/null
kapi "aşım → rc=1" 1 bash "$YAP" "$T/sablon-devam.md" --onceki "$TEMIZ_ILK" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "hangi görev aştı söylenir" "G1"
bash "$ARAC/tik-kaydet.sh" "$TEMIZ_ILK" G1=3:2 G2=2:2 >/dev/null   # temizle

echo "── 5e · tik-kaydet biçim denetimi"
kapi "bozuk biçim → rc=2" 2 bash "$ARAC/tik-kaydet.sh" "$TEMIZ_ILK" "G1=cok"
kapi "hiç görev yok → rc=2" 2 bash "$ARAC/tik-kaydet.sh" "$TEMIZ_ILK"

echo "── 6 · profil yoksa 'temiz' DEĞİL 'ölçülemedi' (rc=3)"
mkdir -p "$T/profilsiz/ekran"
cp "$ARAC/fikstur/temiz/"*.html "$T/profilsiz/ekran/"
P_ILK="$(ls "$T/profilsiz/ekran/"*.html | head -1)"
kapi "profilsiz → rc=3" 3 bash "$YAP" "$T/sablon-devam.md" --onceki "$P_ILK" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "ölçülemedi denir, temiz denmez" "ÖLÇÜLEMEDİ"

echo "── 7 · REGRESYON: boş sözleşme hâlâ kaçamıyor (v0.1.1 kazanımı)"
printf '# dil\n{{ }}\n' > "$T/tasarim/bos-dil.md"
kapi "boş yuvalı sözleşme → rc=2" 2 bash "$YAP" "$T/sablon-niyetli.md" \
     --dil "$T/tasarim/bos-dil.md" --estetik "$T/tasarim/estetik-yon.md" \
     --niyet "$T/tasarim/urun-niyeti.md"

echo "── 8 · REGRESYON: niyet yuvası OLMAYAN eski şablon çalışmaya devam eder"
cat > "$T/sablon-eski.md" <<'MD'
# başlık
> not
---
{{TASARIM_DILI}}
{{ESTETIK_YON}}
MD
kapi "niyetsiz eski şablon → rc=0" 0 bash "$YAP" "$T/sablon-eski.md" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"

echo "── 9 · kanonik şablonlar Durak 0 yuvasını taşıyor"
for f in tasarim-promptu.md devam-promptu.md; do
  if grep -q '{{URUN_NIYETI}}' "$SKILL/sablonlar/$f"; then
    echo "  ✓ $f yuvayı taşıyor"; GECTI=$((GECTI + 1))
  else echo "  ✗ $f yuvayı taşımıyor"; KALDI=$((KALDI + 1)); fi
done
if grep -q '^Kendi cümlem:' "$SKILL/sablonlar/urun-niyeti.md"; then
  echo "  ✓ urun-niyeti.md zorunlu cümle satırlarını taşıyor"; GECTI=$((GECTI + 1))
else echo "  ✗ urun-niyeti.md zorunlu satırları taşımıyor"; KALDI=$((KALDI + 1)); fi

echo "── 10 · ÇEKİRDEK sözleşme çağrılmadan, kendiliğinden prompta girer"
kapi "çekirdek otomatik → rc=0" 0 bash "$YAP" "$T/sablon-eski.md" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "çekirdek işaret standardı girdi" "<!-- bilesen: Ad -->"
icerir "çekirdek çıktı sözleşmesi girdi" "Tek dosya."
icerir "marka değerleri de girdi" "renk: #123456"

echo '── 11 · MARKA ":" ayraçlı liste olabilir (PATH gibi), sırayla eklenir'
printf '# ek marka\nkademe: kucuk\n' > "$T/tasarim/ek-marka.md"
kapi "iki marka dosyası → rc=0" 0 bash "$YAP" "$T/sablon-eski.md" \
     --dil "$T/tasarim/tasarim-dili.md:$T/tasarim/ek-marka.md" \
     --estetik "$T/tasarim/estetik-yon.md"
icerir "birinci marka girdi" "renk: #123456"
icerir "ikinci marka girdi" "kademe: kucuk"

echo "── 12 · listede EKSİK dosya varsa hangisi olduğu söylenir"
kapi "eksik marka parçası → rc=2" 2 bash "$YAP" "$T/sablon-eski.md" \
     --dil "$T/tasarim/tasarim-dili.md:$T/tasarim/yok.md" \
     --estetik "$T/tasarim/estetik-yon.md"
icerir "eksik olan parça adlandırılır" "yok.md"

echo "── 13 · HEX ÇİTİ: çekirdeğe renk DEĞERİ sızarsa koşu reddedilir"
printf '# sahte cekirdek\nzemin: #ffffff\n' > "$T/sahte-cekirdek.md"
kapi "değerli çekirdek → rc=2" 2 env UI_AKIS_CEKIRDEK="$T/sahte-cekirdek.md" \
     bash "$YAP" "$T/sablon-eski.md" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "sebep söylenir" "Çekirdek kuralı taşır, değeri değil"
icerir "sızan satır gösterilir" "#ffffff"

echo "── 14 · gerçek çekirdek dosyası hex çitinden GEÇER (kendi kuralına uyar)"
if grep -qEi '#[0-9a-f]{3}([0-9a-f]{3})?\b|rgba?\(|hsla?\(' "$SKILL/cekirdek/sozlesme.md"; then
  echo "  ✗ çekirdekte renk değeri var"; KALDI=$((KALDI + 1))
else echo "  ✓ çekirdekte sıfır renk değeri"; GECTI=$((GECTI + 1)); fi

echo "── 15 · REGRESYON: çekirdek yuvasız/slotsuz — dolmamış yuva taramasını tetiklemez"
if grep -q '{{' "$SKILL/cekirdek/sozlesme.md"; then
  echo "  ✗ çekirdekte yuva var — her koşuyu rc=2 yapardı"; KALDI=$((KALDI + 1))
else echo "  ✓ çekirdekte yuva yok"; GECTI=$((GECTI + 1)); fi

echo "── 16 · REGRESYON: sınav GERÇEK havuza yazmadı (sınav-verisi ⟂ saha-verisi)"
GERCEK="$HOME/.claude/tasarim-havuz.jsonl"
if [ ! -f "$GERCEK" ] || ! grep -q '"kutu": *"ui-tasarim-akisi"' "$GERCEK"; then
  echo "  ✓ canlı defterde sınav kaydı yok"; GECTI=$((GECTI + 1))
else echo "  ✗ sınav canlı deftere yazmış: $GERCEK"; KALDI=$((KALDI + 1)); fi
if [ -s "$UI_AKIS_HAVUZ" ]; then
  echo "  ✓ sınav kendi geçici defterine yazdı"; GECTI=$((GECTI + 1))
else echo "  ✗ sınav havuzu boş — izolasyon test edilemedi"; KALDI=$((KALDI + 1)); fi

echo
echo "TOPLAM: $GECTI geçti · $KALDI kaldı"
[ "$KALDI" -eq 0 ]
