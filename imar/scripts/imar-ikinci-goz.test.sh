#!/usr/bin/env bash
# imar-ikinci-goz.test.sh — bağımsız gözün kendi sınavı. HERMETİK: gerçek araştırma serisine
# dokunmaz (kendi MUNECCIM_EV'ini kurar), modeli ÇAĞIRMAZ (yalnız --damgala ve --kuru yolları).
#
# NİÇİN VAR (ölçüldü 14 Ekim): İMAR'ın beş sınavı 126 kapı taşıyordu ve gözün KENDİ sınavı YOKTU —
# oysa iki günlük yanlış hüküm, bir çift damga ve bir ezilen hüküm dosyası hep bu betikten çıkmıştı.
# Ölçülmeyen yer sessizce bozulur; en çok onarılan betik en çok sınav isteyen betiktir.
#
# ÖLÇMEDİĞİ (dürüstlük): modelin fiilen ne hüküm verdiği. Model çağıran dal (gözün kendisi) burada
# koşmaz; ölçülen şey hükmün KAYDA ve DEFTERE nasıl döndüğüdür.
set -uo pipefail
BETIK="$(cd "$(dirname "$0")" && pwd)/imar-ikinci-goz.sh"
GECTI=0; KALDI=0
kapi(){ local ad="$1" bek="$2" gercek="$3"
  if [ "$bek" = "$gercek" ]; then GECTI=$((GECTI+1)); printf '  ✓ %s\n' "$ad"
  else KALDI=$((KALDI+1)); printf '  ✗ %s — beklenen %s, gelen %s\n' "$ad" "$bek" "$gercek"; fi; }

KOK="$(mktemp -d)"; trap 'rm -r "$KOK" 2>/dev/null' EXIT
kur(){ # kur <dizin> — taze bir ev: defterde D-100 ve D-101 var, D-999 YOK
  local e="$1"; mkdir -p "$e/arastirma-serisi/goz"
  cat > "$e/arastirma-serisi/DERSLER.md" <<'EOF'
# DERSLER

### D-100 · Birinci ders
- **Son doğrulama:** 2026-10-14

### D-101 · İkinci ders
- **Son doğrulama:** 2026-10-14
EOF
  cat > "$e/tur.md" <<'EOF'
# TUR
## 2 · Dersler
Dersler burada.
EOF
}
hukum(){ printf '%s\n' "$2" > "$1/arastirma-serisi/goz/tur.goz.json"; }
kos(){ local e="$1"; shift; MUNECCIM_EV="$e" bash "$BETIK" "$e/tur.md" "$@" >"$KOK/cikti" 2>&1; echo $?; }

echo "━━━ imar-ikinci-goz · kapılar ━━━"

# ── kullanım ve ön koşullar ────────────────────────────────────────────────
bash "$BETIK" >/dev/null 2>&1; kapi "G01 argümansız → kullanım (2)" 2 "$?"
MUNECCIM_EV="$KOK/yok" bash "$BETIK" "$KOK/olmayan.md" >/dev/null 2>&1
kapi "G02 tur dosyası yok → ÖLÇÜLEMEDİ (3)" 3 "$?"

E="$KOK/e-devirsiz"; kur "$E"; printf '# TUR\nbaşlıksız gövde\n' > "$E/tur.md"
kapi "G03 turda DEVİR/ders bölümü yok → 3" 3 "$(kos "$E")"

E="$KOK/e-kuru"; kur "$E"
kapi "G04 --kuru → 0 (model çağrılmaz)" 0 "$(kos "$E" --kuru)"
grep -q "^KURU: brif" "$KOK/cikti"; kapi "G05 --kuru brifi ve çıktı yolunu söyler" 0 "$?"

E="$KOK/e-damgasiz"; kur "$E"
kapi "G06 --damgala ama hüküm dosyası yok → 3" 3 "$(kos "$E" --damgala)"

# ── sağlıklı yol: hüküm deftere ULAŞIYOR ──────────────────────────────────
E="$KOK/e-temiz"; kur "$E"
hukum "$E" '{"dersler":[{"no":"D-100","hukum":"ayakta","gerekce":"çürütemedim"},{"no":"D-101","hukum":"olculemedi","gerekce":"metinden çıkmaz"}],"genel":"temiz gün"}'
kapi "G07 çürüyen yok, hepsi damgalandı → 0" 0 "$(kos "$E" --damgala)"
grep -q "göz hükmü: 2 ders işlendi" "$KOK/cikti"; kapi "G08 işlenen ders sayısı basılır" 0 "$?"
grep -q '\*\*İkinci göz:\*\* ayakta (çürütülemedi)' "$E/arastirma-serisi/DERSLER.md"; kapi "G09 ayakta damgası 'çürütülemedi' der (doğru demez)" 0 "$?"
grep -q '\*\*İkinci göz:\*\* ölçülemedi' "$E/arastirma-serisi/DERSLER.md"; kapi "G10 ölçülemedi damgası basılır" 0 "$?"
kapi "G11 ikinci koşu çift damga basmaz → 0" 0 "$(kos "$E" --damgala)"
kapi "G12 damga sayısı hâlâ 2" 2 "$(grep -c 'İkinci göz:' "$E/arastirma-serisi/DERSLER.md")"
grep -q "zaten damgalı 2" "$KOK/cikti"; kapi "G13 'zaten damgalı' sayısı söylenir" 0 "$?"
kapi "G14 --damgala hüküm dosyasını çatallamaz (.goz.2.json yok)" 0 "$(ls "$E/arastirma-serisi/goz" | grep -c 'goz\.2\.json')"

E="$KOK/e-curuk"; kur "$E"
hukum "$E" '{"dersler":[{"no":"D-100","hukum":"curudu","gerekce":"kanıt iddiayı taşımıyor"},{"no":"D-101","hukum":"ayakta","gerekce":"çürütemedim"}],"genel":"bir çürük"}'
kapi "G15 bir ders çürüdü ve damgalandı → 1" 1 "$(kos "$E" --damgala)"
grep -q '\*\*İkinci göz:\*\* 🔴 ÇÜRÜDÜ' "$E/arastirma-serisi/DERSLER.md"; kapi "G16 çürüme damgası defterde kırmızı" 0 "$?"

# ── 🔴 asıl kapı: hüküm ÜRETİCİYE ULAŞMADIYSA gün ÖLÇÜLEMEDİ ──────────────
E="$KOK/e-ulasmadi"; kur "$E"
hukum "$E" '{"dersler":[{"no":"D-100","hukum":"ayakta","gerekce":"ulaşır"},{"no":"D-999","hukum":"curudu","gerekce":"defterde böyle ders yok"}],"genel":"damga eksik"}'
kapi "G17 hüküm defterde yerini bulamadı → 3 (1 DEĞİL)" 3 "$(kos "$E" --damgala)"
grep -q "ÖLÇÜLEMEDİ: 1 hüküm defterde yerini bulamadı" "$KOK/cikti"; kapi "G18 kaç hükmün ulaşmadığı söylenir" 0 "$?"

E="$KOK/e-defteryok"; kur "$E"; rm -f "$E/arastirma-serisi/DERSLER.md"
hukum "$E" '{"dersler":[{"no":"D-100","hukum":"curudu","gerekce":"çürük"}],"genel":"defter yok"}'
kapi "G19 ders defteri hiç yok → 3 (1 DEĞİL)" 3 "$(kos "$E" --damgala)"
grep -q "hüküm üreticiye ULAŞMADI" "$KOK/cikti"; kapi "G20 sebep 'üreticiye ulaşmadı' diye yazılır" 0 "$?"

# ── bozuk hüküm dosyası ───────────────────────────────────────────────────
E="$KOK/e-bozuk"; kur "$E"; hukum "$E" 'bu JSON değil'
kapi "G21 geçerli hüküm yok → 3" 3 "$(kos "$E" --damgala)"
E="$KOK/e-derssiz"; kur "$E"; hukum "$E" '{"genel":"dersler alanı yok"}'
kapi "G22 'dersler' alanı yok → 3" 3 "$(kos "$E" --damgala)"

# ── --damgala gerçekten modelsiz mi (iddianın sınavı) ─────────────────────
E="$KOK/e-modelsiz"; kur "$E"
hukum "$E" '{"dersler":[{"no":"D-100","hukum":"ayakta","gerekce":"x"},{"no":"D-101","hukum":"ayakta","gerekce":"y"}],"genel":"modelsiz"}'
MUNECCIM_EV="$E" PATH="/usr/bin:/bin" bash "$BETIK" "$E/tur.md" --damgala >/dev/null 2>&1
kapi "G23 --damgala PATH'te model yokken de koşar → 0" 0 "$?"

# ── MUTASYON: kapılar ısırıyor mu ─────────────────────────────────────────
mut(){ # mut <ad> <python-yama> <senaryo-dizini> <beklenen-rc>
  local ad="$1" yama="$2" e="$3" bek="$4"
  local kopya="$KOK/mut.sh"; cp "$BETIK" "$kopya"
  python3 - "$kopya" "$yama" <<'PY'
import sys
p,mod=sys.argv[1],sys.argv[2]
s=open(p,encoding="utf-8").read()
if mod=="bulunamadi":  # kapıyı öldür: uyarıya geri dön
    s=s.replace('if bulunamadi:\n    print("ÖLÇÜLEMEDİ: %d hüküm defterde yerini bulamadı',
                'if False:\n    print("ÖLÇÜLEMEDİ: %d hüküm defterde yerini bulamadı',1)
elif mod=="defteryok":
    s=s.replace('          % (dersler_y,curuyen,d.get("genel","")), file=sys.stderr)\n    sys.exit(3)',
                '          % (dersler_y,curuyen,d.get("genel","")), file=sys.stderr)\n    sys.exit(1 if curuyen else 0)',1)
open(p,"w",encoding="utf-8").write(s)
PY
  MUNECCIM_EV="$e" bash "$kopya" "$e/tur.md" --damgala >/dev/null 2>&1
  local rc=$?
  if [ "$rc" = "$bek" ]; then GECTI=$((GECTI+1)); printf '  ✓ %s (kapı öldü → rc=%s, yani kapı ısırıyor)\n' "$ad" "$rc"
  else KALDI=$((KALDI+1)); printf '  ✗ %s — kapı öldürüldü ama rc hâlâ %s: kapı ISIRMIYOR\n' "$ad" "$rc"; fi; }

E="$KOK/m-ulasmadi"; kur "$E"
hukum "$E" '{"dersler":[{"no":"D-100","hukum":"ayakta","gerekce":"ulaşır"},{"no":"D-999","hukum":"curudu","gerekce":"ulaşmaz"}],"genel":"m"}'
mut "G24 mutasyon: ulaşmayan hüküm kapısı" bulunamadi "$E" 1

E="$KOK/m-defteryok"; kur "$E"; rm -f "$E/arastirma-serisi/DERSLER.md"
hukum "$E" '{"dersler":[{"no":"D-100","hukum":"curudu","gerekce":"çürük"}],"genel":"m"}'
mut "G25 mutasyon: defter yok kapısı" defteryok "$E" 1

# ── gerçek seriye dokunmadı mı ────────────────────────────────────────────
kapi "G26 hermetik: sınav gerçek ev değişkenini sızdırmaz" 0 "$(env | grep -c '^MUNECCIM_EV=')"

echo "━━━ geçti $GECTI · kaldı $KALDI ━━━"
[ "$KALDI" -eq 0 ]
