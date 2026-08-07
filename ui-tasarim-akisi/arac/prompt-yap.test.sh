#!/usr/bin/env bash
# prompt-yap.test.sh — iki kapının sınavı: Durak 0 (ürün niyeti) + ölçüm ön-koşulu.
# Hem yeni kapıları hem ESKİ davranışın regresyonunu kapsar (boş sözleşme kaçağı).
set -u

ARAC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(dirname "$ARAC")"
YAP="$ARAC/prompt-yap.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
GECTI=0; KALDI=0

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

echo "── 5 · ölçüm kapısı: TEMİZ önceki sayfada devam promptu üretilir"
mkdir -p "$T/temiz"
cp "$ARAC/fikstur/temiz/"*.html "$T/temiz/"
TEMIZ_ILK="$(ls "$T/temiz/"*.html | head -1)"
kapi "temiz önceki → rc=0" 0 bash "$YAP" "$T/sablon-devam.md" --onceki "$TEMIZ_ILK" \
     --dil "$T/tasarim/tasarim-dili.md" --estetik "$T/tasarim/estetik-yon.md"
icerir "önceki sayfa gövdesi gömüldü" "<!-- bilesen: Gezinme -->"

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

echo
echo "TOPLAM: $GECTI geçti · $KALDI kaldı"
[ "$KALDI" -eq 0 ]
