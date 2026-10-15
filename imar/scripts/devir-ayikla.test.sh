#!/usr/bin/env bash
# devir-ayikla.test.sh — DEVİR taşıma hattının hermetik sınavı. Gerçek seriye DOKUNMAZ (--ev sahte kök).
#
# NİÇİN VAR (ölçüldü 12 Ekim 2026): bu hatta BEŞ kez biçim kayması yaşandı (3·6·11·11·12 Ekim) ve beşi de
# ELLE yakalandı — ikisi iki gün sonra, altı ders kaybedildikten sonra. Hattın hiç sınavı yoktu: her onarım
# "artık tanıyor" diyordu ama bir sonraki kaymada yine sessizce sıfır taşıyacaktı. Her kayma burada FİKSTÜR.
#
# Çift yönlü: ALTIN fikstürler (gerçek biçimler okunmalı) ⟂ KIRMIZI fikstürler (kayıp/eksik yakalanmalı).
# Mutasyon kapıları: koruma sökülünce sınav KIRMIZIYA dönmeli — yoksa koruma süstür.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# geçici dizin: kancanın yasakladığı dizgi yerine meşru yol (bileyi/guvenli-sil.sh); araç yoksa
# 'rm -r' ile devam eder (zorlamasız, geçici dizin için yeterli) — ölçüldü 13 Ekim, bekçi sarısı kapandı.
GS="/config/.claude/skills/bileyi/scripts/guvenli-sil.sh"
if [ -r "$GS" ]; then T="$(bash "$GS" --yeni devir-sinav)"; trap 'bash "$GS" "$T" >/dev/null 2>&1' EXIT
else T="$(mktemp -d)"; trap 'rm -r "$T" 2>/dev/null' EXIT; fi
# 🔴 SINAV GERÇEKTEN HERMETİK OLSUN (15 Eki, İMAR filo becerisine taşınırken ölçüldü):
#    bu süit "hermetik" diyordu ama kutu-eksikleri defterinin yolunu betiğin KENDİ konumundan
#    türetiyordu, yani MİHENK'in GERÇEK defterine yazıyordu. Kanıt: gerçek defterde A6 fikstürünün
#    satırı duruyor ("falanca site kutudan okunamıyor", tur 2026-01-05). Kimse görmedi çünkü yazma
#    SESSİZCE BAŞARDI — eksik veri gibi değil, başarı gibi göründü.
export KUTU_EKSIGI_DEFTER="$T/kutu-eksikleri.md"
A="$REPO/scripts/devir-ayikla.py"; G="$REPO/scripts/imar-ikinci-goz.sh"; S="$REPO/scripts/tarayici/sayfa-metin.mjs"
GEC=0; DUS=0
kapi(){ local ad="$1" bek="$2"; shift 2; local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$bek" ]; then echo "✅ $ad"; GEC=$((GEC+1)); else echo "❌ $ad: beklenen rc=$bek, gelen rc=$rc · ${out:0:160}"; DUS=$((DUS+1)); fi; }
esit(){ if [ "$2" = "$3" ]; then echo "✅ $1 = $2"; GEC=$((GEC+1)); else echo "❌ $1: beklenen '$3', gelen '$2'"; DUS=$((DUS+1)); fi; }
icerir(){ local ad="$1" dosya="$2" desen="$3"; if grep -q -- "$desen" "$dosya" 2>/dev/null; then echo "✅ $ad"; GEC=$((GEC+1)); else echo "❌ $ad: '$desen' yok ($dosya)"; DUS=$((DUS+1)); fi; }
icermez(){ local ad="$1" dosya="$2" desen="$3"; if grep -q -- "$desen" "$dosya" 2>/dev/null; then echo "❌ $ad: '$desen' VAR ama olmamalı"; DUS=$((DUS+1)); else echo "✅ $ad"; GEC=$((GEC+1)); fi; }

# ——— sahte ev kurucu: her fikstür kendi temiz evinde koşar (sızıntı yok)
ev_kur(){ local e="$T/$1"; mkdir -p "$e/arastirma-serisi/gunluk" "$e/arastirma-serisi/goz"; printf '# DERSLER\n' > "$e/arastirma-serisi/DERSLER.md"; echo "$e"; }
# 🔴 'grep -c … || echo 0' iki satır basar (grep zaten 0 yazar) — bu tuzak bu evde ölçüldü (8 Ekim)
ders_say(){ local n; n="$(grep -c "^### D-" "$1/arastirma-serisi/DERSLER.md" 2>/dev/null)"; echo "${n:-0}"; }

echo "── ALTIN · beş biçim kayması da okunmalı ──"
# A1 · "## DEVİR" + "1. **başlık**" + "**Kanıt:**"  (ilk biçim, 2 Ekim)
E=$(ev_kur a1); F="$E/arastirma-serisi/gunluk/2026-01-01-tur.md"
cat > "$F" <<'EOF'
# Tur
## DEVİR
### Ne yaptım
- bir şey
### Dersler
1. **İlk iddia budur**
- **Kanıt:** kaynak (birincil). http://x
- **Ne olursa çürür:** tersi belgelenirse
2. **İkinci iddia**
- **Kanıt:** ölçüm
- **Ne olursa çürür:** ölçüm yinelenmezse
### Şu an neredeyim
buradayım
### Sıradaki tura kuyruk
yarın şunu yap
EOF
kapi "A1 klasik biçim taşınır" 0 python3 "$A" "$F" --ev "$E"
esit "A1 ders sayısı" "$(ders_say "$E")" "2"
icerir "A1 kuyruk yazıldı" "$E/arastirma-serisi/KUYRUK.md" "yarın şunu yap"

# A2 · "## 4 · DEVİR" + "**D-004 · başlık**" + "- KANIT:" (numaralı başlık + büyük harf alan, 3 ve 6 Ekim)
E=$(ev_kur a2); F="$E/arastirma-serisi/gunluk/2026-01-02-tur.md"
cat > "$F" <<'EOF'
## 4 · DEVİR
## Dersler
**D-004 · Dördüncü iddia**
- KANIT: kaynak (ikincil)
- NE OLURSA ÇÜRÜR: kaynak yalanlanırsa
## Şu an neredeyim
x
EOF
kapi "A2 numaralı DEVİR + D-no + büyük harf alan" 0 python3 "$A" "$F" --ev "$E"
esit "A2 ders sayısı" "$(ders_say "$E")" "1"
icerir "A2 ajanın numarası korunur" "$E/arastirma-serisi/DERSLER.md" "### D-004"
icermez "A2 çürütme 'yazılmamış' denmez" "$E/arastirma-serisi/DERSLER.md" "ÇÜRÜTME ŞARTI YAZILMAMIŞ"

# A3 · "## 2 · Dersler" + "### D-022 · başlık" (11 Ekim: iki günde altı ders kaybettiren biçim)
E=$(ev_kur a3); F="$E/arastirma-serisi/gunluk/2026-01-03-tur.md"
cat > "$F" <<'EOF'
# DEVİR
## 1 · Ne yaptım
- kazdım
## 2 · Dersler
### D-022 · Yirmi ikinci iddia
- **Kanıt:** kaynak (birincil)
- **Ne olursa çürür:** şu olursa
### D-023 · Yirmi üçüncü iddia
- **Kanıt:** satıcı fiyatı
- **Ne olursa çürür:** bu olursa
## 3 · Şu an neredeyim
x
## 4 · Sıradaki tura kuyruk
sıradaki iş
EOF
kapi "A3 markdown başlıklı ders + numaralı bölüm" 0 python3 "$A" "$F" --ev "$E"
esit "A3 ders sayısı (11 Ekim kaybı)" "$(ders_say "$E")" "2"
icerir "A3 numaralı kuyruk başlığı okunur" "$E/arastirma-serisi/KUYRUK.md" "sıradaki iş"

# A4 · DEVİR ÜST BAŞLIĞI YOK, dört bölüm var (12 Ekim) + "**Kutu eksiği:**" kalın yazım
E=$(ev_kur a4); F="$E/arastirma-serisi/gunluk/2026-01-04-tur.md"
cat > "$F" <<'EOF'
# MÜNECCİM turu
**Seçilen açı:** bir şey
## Ne yaptım
- baktım
## Dersler (en fazla 3)
### D-028 · Yirmi sekizinci iddia
- **Kanıt:** kaynak (birincil)
- **Ne olursa çürür:** şu olursa
## Şu an neredeyim
**Kutu eksiği:** falanca site kutudan okunamıyor
## Sıradaki tura kuyruk
devam
EOF
KE="$T/kutu-eksik-a4.md"; kapi "A4 DEVİR başlığı yokken içerikten okunur" 0 env KUTU_EKSIGI_DEFTER="$KE" python3 "$A" "$F" --ev "$E"
esit "A4 ders sayısı" "$(ders_say "$E")" "1"
icerir "A4 kutu eksiği deftere düştü" "$KE" "falanca site"
icermez "A4 kalın işareti sızmadı" "$KE" '\*\* falanca'

# A5 · idempotent: aynı tur iki kez işlenince ders ÇOĞALMAZ
kapi "A5 ikinci işleme (zaten taşınmış)" 0 python3 "$A" "$F" --ev "$E"
esit "A5 ders sayısı değişmedi" "$(ders_say "$E")" "1"

# A6 · numara çakışması: defterde D-028 varken ajan yine D-028 derse yeni numara verilir
F2="$E/arastirma-serisi/gunluk/2026-01-05-tur.md"; sed 's/2026-01-04/2026-01-05/' "$F" > "$F2"
kapi "A6 çakışan numarada yeni no" 0 python3 "$A" "$F2" --ev "$E"
esit "A6 ders sayısı 2" "$(ders_say "$E")" "2"
icerir "A6 çakışma D-029 oldu" "$E/arastirma-serisi/DERSLER.md" "### D-029"

echo "── KIRMIZI · kayıp ve eksik yakalanmalı ──"
# K1 · ders başlığı VAR ama hiçbiri okunamıyor → DERS KAYBI (rc 2), sessiz sıfır YASAK
E=$(ev_kur k1); F="$E/arastirma-serisi/gunluk/2026-01-06-tur.md"
printf '# DEVİR\n## Dersler\nD-099 çıplak satır, tanınmaz biçim\n- Kanıt: x\n## Şu an neredeyim\nx\n' > "$F"
kapi "K1 ders kaybı rc=2 (sessiz sıfır yasak)" 2 python3 "$A" "$F" --ev "$E"
esit "K1 hiçbir ders yazılmadı" "$(ders_say "$E")" "0"
# K2 · DEVİR de dört bölüm de yok → rc 1 (yazılmamış ≠ okunamadı)
E=$(ev_kur k2); F="$E/arastirma-serisi/gunluk/2026-01-07-tur.md"
printf '# Tur\nSadece serbest metin, hiçbir bölüm yok.\n' > "$F"
kapi "K2 DEVİR yok rc=1 (ayrı suçlama)" 1 python3 "$A" "$F" --ev "$E"
# K3 · çürütme şartı yazılmamış → taşınır ama EKSİK damgalanır
E=$(ev_kur k3); F="$E/arastirma-serisi/gunluk/2026-01-08-tur.md"
printf '# DEVİR\n## Dersler\n1. **Şartsız iddia**\n- **Kanıt:** kaynak\n## Şu an neredeyim\nx\n' > "$F"
kapi "K3 şartsız ders taşınır" 0 python3 "$A" "$F" --ev "$E"
icerir "K3 eksik damgası basıldı" "$E/arastirma-serisi/DERSLER.md" "ÇÜRÜTME ŞARTI YAZILMAMIŞ"
# K4 · tur dosyası yok → ölçülemedi
kapi "K4 dosya yok rc=3" 3 python3 "$A" "$T/olmayan-tur.md" --ev "$E"

echo "── İKİNCİ GÖZ · fail-closed, idempotent, ezmez ──"
E=$(ev_kur g1); F="$E/arastirma-serisi/gunluk/2026-01-09-tur.md"
cat > "$F" <<'EOF'
# DEVİR
## Dersler
### D-050 · Ellinci iddia
- **Kanıt:** kaynak
- **Ne olursa çürür:** şu olursa
## Şu an neredeyim
x
EOF
python3 "$A" "$F" --ev "$E" >/dev/null 2>&1
J="$E/arastirma-serisi/goz/2026-01-09-tur.goz.json"
printf '{"dersler":[{"no":"D-050","hukum":"curudu","gerekce":"kanıt iddiayı taşımıyor"}],"genel":"zayıf"}\n' > "$J"
kapi "G1 --damgala modelsiz damgalar (çürüyen → rc 1)" 1 env MUNECCIM_EV="$E" bash "$G" "$F" --damgala
icerir "G1 damga deftere basıldı" "$E/arastirma-serisi/DERSLER.md" "İkinci göz:"
esit "G1 damga tek" "$(grep -c 'İkinci göz:' "$E/arastirma-serisi/DERSLER.md")" "1"
kapi "G2 ikinci damgalama (idempotent)" 1 env MUNECCIM_EV="$E" bash "$G" "$F" --damgala
esit "G2 damga hâlâ tek (çift damga yok)" "$(grep -c 'İkinci göz:' "$E/arastirma-serisi/DERSLER.md")" "1"
# G3 · ders defteri YOKKEN çökmez ve günü ÖLÇÜLEMEDİ sayar (3), defteri yaratmaz.
# 🔴 SÖZLEŞME DEĞİŞTİ (14 Ekim): bu kapı eskiden rc=1 bekliyordu ("hüküm kodunu korur"). O sözleşme
# fail-open'dı: kütük 1'i "🔴 ÇÜRÜYEN" diye yazıyor, karne de günü KUSURSUZ sayıp damga sayacını
# ilerletiyordu — oysa damga deftere hiç basılmamıştı ve sonraki turun brifi o damgalardan besleniyor,
# yani ulaşmayan çürütme AYAKTA diye görünüyordu. 10 Ekim onarımı yalnız ÇÖKME kodunu hükümden
# ayırmıştı; "hüküm üreticiye ulaşmadı" hâli hâlâ hüküm sayılıyordu. Artık ikisi de 3'tür ve bu
# çarpışma zararsızdır: üçü de "ölçemedim" der, hiçbiri hüküm değildir.
E2=$(ev_kur g3); cp "$F" "$E2/arastirma-serisi/gunluk/"; cp "$J" "$E2/arastirma-serisi/goz/"; rm -f "$E2/arastirma-serisi/DERSLER.md"
out="$(MUNECCIM_EV="$E2" bash "$G" "$E2/arastirma-serisi/gunluk/2026-01-09-tur.md" --damgala 2>&1)"; rc=$?
esit "G3 defter yokken gün ÖLÇÜLEMEDİ (3), hüküm sayılmaz" "$rc" "3"
case "$out" in *"ders defteri YOK"*) echo "✅ G3 'damga basılamadı' söylendi"; GEC=$((GEC+1));; *) echo "❌ G3 sessiz geçti: ${out:0:120}"; DUS=$((DUS+1));; esac
case "$out" in *Traceback*) echo "❌ G3 Traceback sızdı"; DUS=$((DUS+1));; *) echo "✅ G3 Traceback yok"; GEC=$((GEC+1));; esac
# G4 · hüküm dosyası EZİLMEZ: ikinci koşu .goz.2.json'a gider (damgala değil, gerçek koşu yolu)
E3=$(ev_kur g4); cp "$F" "$E3/arastirma-serisi/gunluk/"; cp "$J" "$E3/arastirma-serisi/goz/"
MUNECCIM_EV="$E3" bash "$G" "$E3/arastirma-serisi/gunluk/2026-01-09-tur.md" --kuru >/dev/null 2>&1
if [ -f "$E3/arastirma-serisi/goz/2026-01-09-tur.goz.json" ]; then echo "✅ G4 ilk hüküm yerinde duruyor"; GEC=$((GEC+1)); else echo "❌ G4 ilk hüküm kayboldu"; DUS=$((DUS+1)); fi
# G5 · DEVİR başlığı yoksa göz de içerikten okur (12 Ekim)
E4=$(ev_kur g5); F4="$E4/arastirma-serisi/gunluk/2026-01-10-tur.md"
printf '# MÜNECCİM turu\n## Ne yaptım\n- x\n## Dersler\n### D-060 · Altmışıncı iddia\n- **Kanıt:** k\n- **Ne olursa çürür:** ş\n' > "$F4"
out="$(MUNECCIM_EV="$E4" bash "$G" "$F4" --kuru 2>&1)"; rc=$?
esit "G5 DEVİR başlıksız turda göz brif kurar" "$rc" "0"
case "$out" in *"DEVİR bölümü yok"*) echo "❌ G5 yanlış suçlama: DEVİR yok dedi"; DUS=$((DUS+1));; *) echo "✅ G5 içerikten okundu"; GEC=$((GEC+1));; esac
# G6 · tur dosyası yok
kapi "G6 tur yok rc=3" 3 env MUNECCIM_EV="$E4" bash "$G" "$T/yok.md"

echo "── SAYFA-METİN · ağsız, yerel dosyayla ──"
if [ -x /tmp/rootless/chs/chrome-headless-shell-linux64/chrome-headless-shell ] && [ -f "$REPO/motor/node_modules/ws/index.js" ]; then
  printf '<!doctype html><title>Sınav</title><body><p>%s</p></body>' "$(python3 -c "print('kutudaki ölçüm cümlesi '*20)")" > "$T/dolu.html"
  printf '<!doctype html><title>Boş</title><body><p>kısa</p></body>' > "$T/bos.html"
  kapi "S1 kullanım rc=4" 4 node "$S"
  kapi "S2 dolu yerel sayfa rc=0" 0 node "$S" "file://$T/dolu.html" --bekle 2
  kapi "S3 kısa sayfa rc=2 (boş/robot)" 2 node "$S" "file://$T/bos.html" --bekle 2
  kapi "S4 --ara bulunamadı rc=1" 1 node "$S" "file://$T/dolu.html" --bekle 2 --ara "bulunmayan cümle"
  kapi "S5 --ara bulundu rc=0" 0 node "$S" "file://$T/dolu.html" --bekle 2 --ara "ölçüm cümlesi"
else
  echo "⏭️  sayfa-metin sınavı ATLANDI (tarayıcı ya da ws yok) — ölçülemedi, geçti sayılmaz"
fi

echo "── MUTASYON · koruma sökülünce sınav kırmızıya dönmeli ──"
mut(){ # ad · python-yama · hedef — koruma sökülünce ders KAYBOLMALI
  local ad="$1" yama="$2" hedef="$3" kopya="$T/mut-$(date +%s%N).py"
  cp "$hedef" "$kopya"; python3 -c "$yama" "$kopya" || { echo "❌ MUT $ad: yama uygulanamadı (desen değişmiş)"; DUS=$((DUS+1)); return; }
  local E=$(ev_kur "m$(date +%s%N)"); local F="$E/arastirma-serisi/gunluk/2026-01-11-tur.md"
  cat > "$F" <<'EOF'
# DEVİR
## 2 · Dersler
### D-070 · Yetmişinci iddia
- **Kanıt:** k
- **Ne olursa çürür:** ş
## Şu an neredeyim
x
EOF
  python3 "$kopya" "$F" --ev "$E" >/dev/null 2>&1
  local n; n=$(ders_say "$E")
  if [ "$n" = "0" ]; then echo "✅ MUT $ad: koruma sökülünce ders KAYBOLDU (koruma gerçek)"; GEC=$((GEC+1));
  else echo "❌ MUT $ad: koruma söküldü ama sınav yeşil kaldı — kapı SÜS"; DUS=$((DUS+1)); fi
}
mut "markdown ders başlığı tanıma" '
import sys
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
a="|#{1,4}\\s*D-\\d+"
assert s.count(a)==2, "desen %d kez bulundu, 2 bekleniyordu" % s.count(a)
open(p,"w",encoding="utf-8").write(s.replace(a,""))' "$A"
# sessiz-sıfır kapısı: söküldüğünde rc 0 döner (kayıp sessiz) — ayrı ölç
kopya="$T/mut-sessiz.py"; cp "$A" "$kopya"; python3 - "$kopya" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
s=re.sub(r'\n\s*if aday and not dersler:\n(?:.*\n)*?\s*return 2\n', '\n', s, count=1)
open(p,"w",encoding="utf-8").write(s)
PY
E=$(ev_kur mut2); F="$E/arastirma-serisi/gunluk/2026-01-12-tur.md"
printf '# DEVİR\n## Dersler\nD-099 çıplak satır\n- Kanıt: x\n## Şu an neredeyim\nx\n' > "$F"
out="$(python3 "$kopya" "$F" --ev "$E" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then echo "✅ MUT sessiz-sıfır kapısı: sökülünce kayıp SESSİZ oldu (rc 0) — kapı gerçek"; GEC=$((GEC+1));
else echo "❌ MUT sessiz-sıfır: sökülünce de rc=$rc — kapı başka yerden geliyor"; DUS=$((DUS+1)); fi

echo
echo "— $GEC geçti · $DUS düştü"
[ "$DUS" -eq 0 ]
