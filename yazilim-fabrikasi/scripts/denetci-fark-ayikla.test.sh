#!/usr/bin/env bash
# denetci-fark-ayikla.test.sh — "kanıt farka ikinci kez girmesin" kapıları.
#
# NİÇİN AYRI DOSYA: denetci.test.sh o sırada açık bir PR'ın (#327, mutantları paralel koşar)
# elindeydi; aynı dosyayı büyütmek onun kapılarını ezerdi. O PR indikten sonra bu bölüm
# denetci.test.sh'e taşınır (görev notu: gorev_01M4ZSKHD1Y1FFT8P6Z5YMPTF9).
#
# HERMETİK: gerçek depoya, gerçek denetçiye (codex/claude) DOKUNMAZ — denetçi DENETCI_KOMUT
# ile sahte bir betiktir ve aldığı istemi diske bırakır; kapılar o istemi okur.
set -uo pipefail
export DALGIC_KAPALI=1   # ön-göz (ZP640T) sınavda KAPALI: gerçek model çağrısı yok; kendi sınavı denetci.test.sh T-ONGOZ
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-   # denetçi bitiş zili sınavda KAPALI (gerçek koltuklara çalmasın); zil kapısı kendi sahtesini verir
cd "$(dirname "$0")"
D="$PWD/denetci.sh"
GECEN=0; DUSEN=0
kapi() { local ad="$1" bek="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }
iceren() { local ad="$1" ara="$2" dosya="$3"
  if grep -qF -- "$ara" "$dosya" 2>/dev/null; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad ('$ara' $dosya içinde yok)"; fi; }
icermeyen() { local ad="$1" ara="$2" dosya="$3"
  if grep -qF -- "$ara" "$dosya" 2>/dev/null; then DUSEN=$((DUSEN+1)); echo "  ✗ $ad ('$ara' var, olmamalı)"
  else GECEN=$((GECEN+1)); echo "  ✓ $ad"; fi; }

KOK="$(mktemp -d)"; trap 'rm -r -f "$KOK" 2>/dev/null' EXIT
IS="ayikla-sinavi"
DZ="$KOK/_agents/fabrika/kanit/$IS"; mkdir -p "$DZ" "$KOK/_agents/fabrika/kartlar"

# Araç imzalı KANIT.json yerine sınav kipi: denetci.sh kanıt durumunu okuyamazsa rc=2 verir.
# Kanıt manifestini gerçek araçla üretiyoruz ki "kanıt yok" yoluna sapmayalım.
( cd "$KOK" && git init -q . && git config user.email s@s && git config user.name s && \
  echo baslangic > okunacak.txt && git add -A && git commit -q -m "chore: sinav deposu" )
KANIT_DEPO="$KOK" python3 "$PWD/kanit.py" olcum "$IS" sinav --asama tek -- echo olctum >/dev/null 2>&1

# Sahte kart (dört sınıf sorusu cevaplı) — denetci.sh kartı birincil depodan okur
cat > "$KOK/_agents/fabrika/kartlar/$IS.json" <<'JSON'
{"is":"ayikla-sinavi","cumle":"sinav","istedi":"sinav","aldi":"sinav",
 "cevaplar":{"geri_alinamaz":"h","para":"h","dis_yuzey":"h","yetki":"h"},
 "siniflar":[],"sultan":false,"durum":"acik"}
JSON

# Sahte denetçi: aldığı istemi diske bırakır, sonra geçerli bir JSON basar (5/E → rc=0)
cat > "$KOK/sahte-denetci.sh" <<'SH'
#!/usr/bin/env bash
cp "$1" "$ISTEM_IZI"
printf '{"kod_puani":5,"dogru_sey":"E","ozet":"sinav","bulgular":[],"kanit_gorusu":"sinav"}\n'
SH
chmod +x "$KOK/sahte-denetci.sh"

# ── FARK: bir üretim kodu dosyası + ÜÇ kanıt dosyası (şişkinliğin kaynağı)
mk_fark() {  # mk_fark <hedef> <kanit-dosya-govde-bayt>
  # 🔴 SIRA GERÇEĞE UYGUN: git farkı yolları sıralar, `_agents/…` üretim kodundan ÖNCE gelir.
  #    Asıl zarar bu sıradan doğdu: kırpma sondan keser, yani istemden DIŞARI itilen şey kodun
  #    kendisi oldu. Kanıt bloklarını sona koyan bir fikstür, yanan turu hiç yeniden üretmezdi.
  local hedef="$1" sisme="$2" i
  {
    for i in 1 2 3; do
      printf 'diff --git a/_agents/fabrika/kanit/%s/olcum-sisme-%s.txt b/_agents/fabrika/kanit/%s/olcum-sisme-%s.txt\n' "$IS" "$i" "$IS" "$i"
      printf -- '--- /dev/null\n+++ b/_agents/fabrika/kanit/%s/olcum-sisme-%s.txt\n@@ -0,0 +1 @@\n' "$IS" "$i"
      printf '+'; head -c "$sisme" /dev/zero | tr '\0' 'K'; printf '\n'
    done
    printf 'diff --git a/uretim/kod.py b/uretim/kod.py\n--- a/uretim/kod.py\n+++ b/uretim/kod.py\n'
    printf '@@ -1 +1 @@\n-eski satir\n+URETIM-KODU-BURADA\n'
  } > "$hedef"
}
FARK="$KOK/fark.patch"; mk_fark "$FARK" 40000

kos() {  # kos [ek-ortam...] → DENETIM kaydını ve istem izini bırakır
  rm -f "$KOK/istem-izi.txt" "$DZ"/DENETIM-*.json
  env KANIT_DEPO="$KOK" DENETCI_KOMUT="$KOK/sahte-denetci.sh" ISTEM_IZI="$KOK/istem-izi.txt" \
      DENETCI_KIRP_ESIK=110000 "$@" bash "$D" "$IS" --diff "$FARK" --depo "$KOK"
}

echo "A · 🔴 kanıt dosyaları farktan AYIKLANIR, üretim kodu KALIR"
kapi "A1 denetim koşar ve geçer (5/E)" 0 kos
iceren "A2 🔴 ÜRETİM KODU farkı denetçiye ULAŞIR" "URETIM-KODU-BURADA" "$KOK/istem-izi.txt"
icermeyen "A3 🔴 kanıt dosyasının farkı istemde İKİNCİ kez görünmez" "+++ b/_agents/fabrika/kanit/$IS/olcum-sisme-1.txt" "$KOK/istem-izi.txt"
iceren "A4 ayıklandığı denetçiye SÖYLENİR (sessiz ayıklama yok)" "kanıt dosyası" "$KOK/istem-izi.txt"
iceren "A5 kanıt manifesti yine AYRI gider" "KANIT MANİFESTİ" "$KOK/istem-izi.txt"

echo "B · 🔴 kırpılma: asıl zarar buydu"
kapi "B1 ayıklamalı koşumda istem eşiğin ALTINA düşer (kırpılma yok)" 0 kos
icermeyen "B2 🔴 kırpılma uyarısı istemde YOK" "KIRPILDI" "$KOK/istem-izi.txt"
# (göz #436 tur 1, SYV3F) ayıklama kapalıyken istem eskiden KIRPILIP gönderiliyordu (üretim kodu dışarı itilir, tur yanardı);
#   artık istem tavanı her kipte geçerli → gönderim durur, tur yanmaz. Ayıklamanın değeri B1-B2'de: aynı fark tavanın ALTINA iner.
kos DENETCI_KANIT_AYIKLA=0 > "$KOK/b3.out" 2>&1; _rc=$?
[ "$_rc" -eq 1 ] && { GECEN=$((GECEN+1)); echo "  ✓ B3 ayıklama KAPATILINCA şişkin istem → rc 1, kırpılıp gönderilmez"; } || { DUSEN=$((DUSEN+1)); echo "  ✗ B3 rc=$_rc (beklenen 1)"; }
iceren "B4 neden söyleniyor: İŞİ BÖL" "İŞİ BÖL" "$KOK/b3.out"
[ ! -e "$KOK/istem-izi.txt" ] && { GECEN=$((GECEN+1)); echo "  ✓ B5 🔴 ayıklama kapalıyken denetçiye istem GİTMEDİ (kırpık istemle tur yanmaz)"; } || { DUSEN=$((DUSEN+1)); echo "  ✗ B5 istem gitti"; }

echo "C · 🔴 kayıt: 'fark eksikti' ile 'kanıt ayrı gitti' sonradan ayırt edilsin"
kos >/dev/null 2>&1
kapi "C1 DENETIM kaydında kanit_ayiklandi.dosya = 3" 0 python3 -c "
import json,glob,sys
d=json.load(open(sorted(glob.glob('$DZ/DENETIM-*.json'))[-1],encoding='utf-8'))
a=d.get('kanit_ayiklandi') or {}
assert a.get('dosya')==3, a
assert a.get('bayt',0) > 100000, a
assert d['kirpildi']['oldu'] is False, d['kirpildi']
"
kos DENETCI_KANIT_AYIKLA=0 >/dev/null 2>&1   # kos önceki DENETIM kayıtlarını siler → koşudan sonra kayıt SIFIR olmalı
[ "$(ls "$DZ"/DENETIM-*.json 2>/dev/null | wc -l)" -eq 0 ] && { GECEN=$((GECEN+1)); echo "  ✓ C2 ayıklama kapalıyken şişkin istemde DENETIM kaydı yazılmaz (tur yakılmadı)"; } || { DUSEN=$((DUSEN+1)); echo "  ✗ C2 ayıklama kapalıyken tur yandı"; }

echo "D · 🔴 ayıklama farkı BOZMAZ (yalnız kanıt yolu düşer)"
printf 'diff --git a/uretim/a.py b/uretim/a.py\n--- a/uretim/a.py\n+++ b/uretim/a.py\n@@ -1 +1 @@\n-x\n+SADECE-KOD\n' > "$KOK/kodsuz.patch"
kapi "D1 kanıt dosyası HİÇ yoksa fark olduğu gibi geçer" 0 \
  env KANIT_DEPO="$KOK" DENETCI_KOMUT="$KOK/sahte-denetci.sh" ISTEM_IZI="$KOK/istem-izi.txt" \
      bash "$D" "$IS" --diff "$KOK/kodsuz.patch" --depo "$KOK"
iceren "D2 kanıtsız farkta kod yine ULAŞIR" "SADECE-KOD" "$KOK/istem-izi.txt"
icermeyen "D3 kanıtsız farkta 'ayıklandı' notu BASILMAZ (yalan söylemez)" "kanıt dosyası" "$KOK/istem-izi.txt"

echo "E · 🔴 bağımsız gözün tur-1 bulguları"
# E1-E2 (bulgu 1): benzer ADLI üretim dosyası ayıklanmamalı. Eşleşme KÖKTEN olmalı, alt dize değil.
{ printf 'diff --git a/docs/_agents/fabrika/kanit/okuma.md b/docs/_agents/fabrika/kanit/okuma.md\n'
  printf -- '--- /dev/null\n+++ b/docs/_agents/fabrika/kanit/okuma.md\n@@ -0,0 +1 @@\n+BENZER-ADLI-URETIM\n'
  printf 'diff --git a/_agents/fabrika/kanit/%s/olcum-x.txt b/_agents/fabrika/kanit/%s/olcum-x.txt\n' "$IS" "$IS"
  printf -- '--- /dev/null\n+++ b/_agents/fabrika/kanit/%s/olcum-x.txt\n@@ -0,0 +1 @@\n+GERCEK-KANIT\n' "$IS"
} > "$KOK/benzer.patch"
rm -f "$KOK/istem-izi.txt"
kapi "E1 benzer adlı yolda denetim koşar" 0 \
  env KANIT_DEPO="$KOK" DENETCI_KOMUT="$KOK/sahte-denetci.sh" ISTEM_IZI="$KOK/istem-izi.txt" \
      bash "$D" "$IS" --diff "$KOK/benzer.patch" --depo "$KOK"
iceren "E2 🔴 docs/_agents/fabrika/kanit/… ÜRETİM dosyası AYIKLANMAZ (kökten eşleşme)" "BENZER-ADLI-URETIM" "$KOK/istem-izi.txt"
icermeyen "E3 gerçek kanıt yolu yine ayıklanır" "GERCEK-KANIT" "$KOK/istem-izi.txt"

# E4-E6 (bulgu 2): fark TAMAMEN kanıttan oluşuyorsa ayıklama yine çalışır (devre dışı kalmaz)
{ printf 'diff --git a/_agents/fabrika/kanit/%s/olcum-yalniz.txt b/_agents/fabrika/kanit/%s/olcum-yalniz.txt\n' "$IS" "$IS"
  printf -- '--- /dev/null\n+++ b/_agents/fabrika/kanit/%s/olcum-yalniz.txt\n@@ -0,0 +1 @@\n+YALNIZ-KANIT-ICERIGI\n' "$IS"
} > "$KOK/yalniz-kanit.patch"
rm -f "$KOK/istem-izi.txt" "$DZ"/DENETIM-*.json
kapi "E4 yalnız-kanıt farkında denetim koşar (durmaz)" 0 \
  env KANIT_DEPO="$KOK" DENETCI_KOMUT="$KOK/sahte-denetci.sh" ISTEM_IZI="$KOK/istem-izi.txt" \
      bash "$D" "$IS" --diff "$KOK/yalniz-kanit.patch" --depo "$KOK"
icermeyen "E5 🔴 yalnız-kanıt farkı AYIKLANIR (eski kapı burada devre dışı kalıyordu)" "YALNIZ-KANIT-ICERIGI" "$KOK/istem-izi.txt"
iceren "E6 🔴 kod farkının BOŞ olduğu denetçiye SÖYLENİR (eksik sanılmasın)" "ÜRETİM KODU farkı BOŞTUR" "$KOK/istem-izi.txt"
kapi "E7 yalnız-kanıt turunda kayıt dosya=1 der" 0 python3 -c "
import json,glob
d=json.load(open(sorted(glob.glob('$DZ/DENETIM-*.json'))[-1],encoding='utf-8'))
assert (d.get('kanit_ayiklandi') or {}).get('dosya')==1, d.get('kanit_ayiklandi')
"

echo "F · 🔴 bu sınavı kim çağırıyor (yazmak koşturmaz)"
kapi "F1 CI keşfi bu dosyayı BULUR (find ile türetilen listede)" 0 bash -c '
KOK="$(cd "$(dirname "'"$D"'")/../.." && pwd)"
cd "$KOK" || exit 1
mapfile -t T < <(find . -name "*.test.sh" -not -path "./.git/*" | sort)
printf "%s\n" "${T[@]}" | grep -qx "./yazilim-fabrikasi/scripts/denetci-fark-ayikla.test.sh"'

echo "G · 🔴 tur-2 bulgusu: boşluklu ve tırnaklı yollar ayıklayıcıdan KAÇMASIN"
# git, özel karakterli yolu tırnaklar: diff --git "a/x y" "b/x y". Eski desen (\S+) boşlukta kesilir
# ve tırnaklı biçimi hiç tanımaz → eşleşme düşer, blok korunur, istem yeniden şişer.
{ printf 'diff --git "a/_agents/fabrika/kanit/%s/olcum bosluklu.txt" "b/_agents/fabrika/kanit/%s/olcum bosluklu.txt"\n' "$IS" "$IS"
  printf -- '--- /dev/null\n+++ "b/_agents/fabrika/kanit/%s/olcum bosluklu.txt"\n@@ -0,0 +1 @@\n+TIRNAKLI-KANIT\n' "$IS"
  printf 'diff --git a/_agents/fabrika/kanit/%s/olcum duz bosluk.txt b/_agents/fabrika/kanit/%s/olcum duz bosluk.txt\n' "$IS" "$IS"
  printf -- '--- /dev/null\n+++ b/_agents/fabrika/kanit/%s/olcum duz bosluk.txt\n@@ -0,0 +1 @@\n+BOSLUKLU-KANIT\n' "$IS"
  printf 'diff --git a/uretim/kod.py b/uretim/kod.py\n--- a/uretim/kod.py\n+++ b/uretim/kod.py\n@@ -1 +1 @@\n-e\n+URETIM-KODU-BURADA\n'
} > "$KOK/bosluk.patch"
rm -f "$KOK/istem-izi.txt" "$DZ"/DENETIM-*.json
kapi "G1 boşluklu/tırnaklı yollu farkta denetim koşar" 0 \
  env KANIT_DEPO="$KOK" DENETCI_KOMUT="$KOK/sahte-denetci.sh" ISTEM_IZI="$KOK/istem-izi.txt" \
      bash "$D" "$IS" --diff "$KOK/bosluk.patch" --depo "$KOK"
icermeyen "G2 🔴 TIRNAKLI kanıt yolu ayıklanır (eski desen bunu hiç tanımıyordu)" "TIRNAKLI-KANIT" "$KOK/istem-izi.txt"
icermeyen "G3 🔴 BOŞLUKLU kanıt yolu ayıklanır (eski desen boşlukta kesiliyordu)" "BOSLUKLU-KANIT" "$KOK/istem-izi.txt"
iceren "G4 üretim kodu yine ULAŞIR" "URETIM-KODU-BURADA" "$KOK/istem-izi.txt"
kapi "G5 kayıt iki kanıt dosyasını da sayar (dosya=2)" 0 python3 -c "
import json,glob
d=json.load(open(sorted(glob.glob('$DZ/DENETIM-*.json'))[-1],encoding='utf-8'))
assert (d.get('kanit_ayiklandi') or {}).get('dosya')==2, d.get('kanit_ayiklandi')
"
# G6: yol ÖLÇÜLEMEZSE ayıklama ŞÜPHEDE AYIKLAMAZ — blok korunur (yanlış ayıklama daha pahalı)
{ printf 'diff --git garip-baslik-yol-okunamaz\n'
  printf '@@ -0,0 +1 @@\n+YOLU-OKUNAMAYAN-BLOK\n'
} > "$KOK/okunamaz.patch"
rm -f "$KOK/istem-izi.txt"
kapi "G6 yolu okunamayan blokta denetim koşar" 0 \
  env KANIT_DEPO="$KOK" DENETCI_KOMUT="$KOK/sahte-denetci.sh" ISTEM_IZI="$KOK/istem-izi.txt" \
      bash "$D" "$IS" --diff "$KOK/okunamaz.patch" --depo "$KOK"
iceren "G7 🔴 yol ÖLÇÜLEMEDİYSE blok KORUNUR (şüphede ayıklamaz)" "YOLU-OKUNAMAYAN-BLOK" "$KOK/istem-izi.txt"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
