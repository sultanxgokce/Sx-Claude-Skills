#!/usr/bin/env bash
# hafta-kapanis.test.sh — kapanış kapısının kapıları (hermetik: mktemp depo, sabit tarih) + 3 mutant.
# Bağ: retro.py gerekir (kardeş beceri). Yoksa rc=3 ÖLÇÜLEMEDİ basar — sahte yeşil YOK (#359 önce birleşir).
# kabuk-testleri: sure=120
set -uo pipefail
B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$B/hafta-kapanis.py"
RP="${HAFTA_KAPANIS_RETRO_PY:-$B/../../retro/scripts/retro.py}"
if [ ! -f "$RP" ]; then echo "◻ ÖLÇÜLEMEDİ: retro.py yok ($RP) — retro becerisi (#359) birleşmeden bu sınav koşamaz"; exit 3; fi
export HAFTA_KAPANIS_RETRO_PY="$RP"
G=0; K=0
ok(){ G=$((G+1)); echo "  ✓ $1"; }
kirmizi(){ K=$((K+1)); echo "  ✗ $1"; }
kapi(){ local ad="$1" bek="$2"; shift 2; local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$bek" ]; then ok "$ad (rc=$rc)"; else kirmizi "$ad: rc=$rc beklenen $bek :: $(echo "$out" | head -4 | tr '\n' ' ')"; fi; CIKTI="$out"; }
icerir(){ if grep -qF -- "$2" <<<"$1"; then ok "$3"; else kirmizi "$3 :: '$2' yok :: $(echo "$1" | head -5 | tr '\n' ' ')"; fi; }
icermez(){ if grep -qF -- "$2" <<<"$1"; then kirmizi "$3 :: '$2' VAR"; else ok "$3"; fi; }

export RETRO_BUGUN=2026-10-17
T="$(mktemp -d)"; trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$T"' EXIT
KOK="$T/depo"; mkdir -p "$KOK/_agents/bani" "$KOK/_agents/mirahur" "$KOK/_agents/handoff" "$KOK/_agents/fabrika/kartlar" "$KOK/_agents/fabrika/kanit/is-b"
export RETRO_KOK="$KOK" RETRO_BEKCI_LOG="$T/bekci.log" RETRO_REGISTRY="$KOK/_agents/handoff/aile-registry.yaml"
printf '# B\n## ÇIPA 2026-10-15 10:00\n[BÂNİ → SERDAR] 10:05 · iş bitti\n' > "$KOK/_agents/bani/NOTES.md"
printf '# M\n## ÇIPA 2026-10-01\n[MİRAHUR → SERDAR] 10:00 · geçen ay\n' > "$KOK/_agents/mirahur/NOTES.md"   # bu hafta iz yok → ÇALIŞMADI
printf '{"is":"is-b","aldi":"BANI","zaman":"2026-10-15T10:00:00+03:00","durum":"tikandi","bitis":"2026-10-16T10:00:00+03:00"}' > "$KOK/_agents/fabrika/kartlar/is-b.json"
printf '2026-10-15T14:34:31Z | KAPISIZ | a\n2026-10-01T14:34:31Z | KAPISIZ | eski\n' > "$KOK/_agents/fabrika/kacis-defteri.log"
: > "$T/bekci.log"
printf 'uyeler:\n  - id: SERDAR\n  - id: BÂNİ\n  - id: MİRAHUR\n' > "$RETRO_REGISTRY"
RD="$KOK/_agents/handoff/retro/2026-W42"; KP="$RD/KAPANIS.md"; M="$RD/MERKEZ.md"

echo "— H1 retro becerisi yoksa SARI (sahte yeşil yok)"
mkdir -p "$T/yalniz/scripts" "$T/ev"; cp "$H" "$T/yalniz/scripts/"
kapi "H1a retro.py bulunamaz → rc=3" 3 env -u HAFTA_KAPANIS_RETRO_PY HOME="$T/ev" python3 "$T/yalniz/scripts/hafta-kapanis.py" olc --hafta 2026-W42 --kok "$KOK"
icerir "$CIKTI" "ÖLÇÜLEMEDİ" "H1b sarı dili"
kapi "H1c hafta biçimsiz → retro.py hata → rc=2" 2 python3 "$H" olc --hafta 2026-42 --kok "$KOK"

echo "— H2 hiç retro yok → AÇIK"
kapi "H2a boş hafta → rc=1 AÇIK" 1 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "K1 katılım: OK 0 · EKSİK 1 (BÂNİ)" "H2b K1 kırmızı: BÂNİ iz var retro yok; MİRAHUR serbest"
[ ! -f "$M" ] && ok "H2c kapı MERKEZ.md üretmedi (salt ölçer)" || kirmizi "H2c kapı MERKEZ.md yazdı!"
icerir "$(cat "$KP")" "_durum: AÇIK" "H2d KAPANIS.md yazıldı, durum AÇIK"
icerir "$(cat "$KP")" "_sultan_onay: (bekliyor" "H2e onay satırı BOŞ — araç üretmedi (A06)"

echo "— H3 kutu retrosu + merkez iskeleti var, ders/damga yok → AÇIK"
python3 "$RP" kutu BÂNİ --koltuk bani:0 >/dev/null
python3 - "$RD/BÂNİ.md" <<'PY'
import re,sys;p=sys.argv[1];s=open(p,encoding="utf-8").read()
s=re.sub(r"- B1\) .*","- B1) canlı kanıt sınıfı kapıda",s); s=re.sub(r"- Z1\) .*","- Z1) rm ile kanıt sildim · ölçü: 1 tur",s)
s=re.sub(r"- A1\) .*","- A1) denetci.sh daralt okumuyor",s); s=re.sub(r"- D1\) .*","- D1) kart depo başına açılır",s)
s=re.sub(r"- Ö1\) .*","- Ö1) denetci.sh daralt tanısın\n- Ö2) canli-ayarla ayrı kart",s); open(p,"w",encoding="utf-8").write(s)
PY
python3 "$RP" lint "$RD/BÂNİ.md" >/dev/null || kirmizi "fikstür: kutu retrosu geçersiz"
python3 "$RP" merkez >/dev/null; [ -f "$M" ] && ok "H3a fikstür: MERKEZ.md iskeleti" || kirmizi "H3a MERKEZ.md yok"
SHA_M="$(sha256sum "$M" | cut -c1-16)"
kapi "H3b K1 yeşil (BÂNİ OK · MİRAHUR ÇALIŞMADI), K2-K4 kırmızı → rc=1" 1 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "✓ K1 katılım: OK 1" "H3c K1 yeşil"
[ "$(sha256sum "$M" | cut -c1-16)" = "$SHA_M" ] && ok "H3c2 kapı MERKEZ.md'ye dokunmadı (sha aynı; merkez komutu çağrılmaz)" || kirmizi "H3c2 MERKEZ.md değişti!"
cp "$RD/BÂNİ.md" "$T/B.yedek"; sed -i 's/^- Z1) .*/- Z1) ölçüsüz zaman kaybı/' "$RD/BÂNİ.md"
kapi "H3c3 kutu retrosu lint düşerse K1 GEÇERSİZ → kırmızı" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "GEÇERSİZ 1 (BÂNİ)" "H3c4 GEÇERSİZ adı"
cp "$T/B.yedek" "$RD/BÂNİ.md"
icerir "$CIKTI" "✗ K2 dersler → görev (D1): MERKEZ.md'de yazılı ders yok" "H3d K2 ders yok"
icerir "$CIKTI" "✗ K3 süzüm" "H3e K3 damgasız"
icerir "$CIKTI" "2/2 kaçış/tıkanma ders damgası almadı" "H3f K4 kaçış + tıkanma sayıldı (eski kaçış dışarıda)"
icerir "$CIKTI" "kart:is-b (tıkanma)" "H3g tıkanma anahtarı kart adıyla"

echo "— H4 merkez dolu: dersler + D1 görevler + süzüm damgası + kaçış damgası → ONAY BEKLİYOR"
python3 - "$M" <<'PY'
import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read()
s=s.replace("denetci.sh daralt tanısın →","denetci.sh daralt tanısın → gorev_01M54APFDAHKN72VKBWTGKSAAM")
s=s.replace("canli-ayarla ayrı kart →","canli-ayarla ayrı kart → RED: sahip doğrulaması tasarlanmadan açılmaz")
s=s.replace("- M1) <ders> · kaynak: <AJAN D<n> | ölçüm>","- M1) kart depo başına açılır · kaynak: BÂNİ D1\n- M2) daraltma hat adımı eksik · kaynak: ölçüm (3 tur 4/H)")
s=s.replace("- <gorev_… · ders M<n>>",'- gorev_01M54ARD0YSNPSY5HVQFTPCP7J · ders M1 · D1: 2026-10-18 Sultan: onay (sohbet · oturum-ref-1 · "kart depo başına, tamam" · beyan:SERDAR)\n- gorev_01M54B2Y4QT7VWTJX10AFR7M76 · ders M2 · D1: 2026-10-18 Sultan: onay (sohbet · oturum-ref-1 · "daraltma adımı hatta girsin" · beyan:SERDAR)')
s+="\n## Kaçış ve tıkanma\n- 2026-10-15T14:34:31Z → M1\n- kart:is-b → M2\n"
open(p,"w",encoding="utf-8").write(s)
PY
kapi "H4a dört kapı yeşil, onay yok → rc=5 ONAY BEKLİYOR" 5 python3 "$H" olc --hafta 2026-W42
icerir "$(cat "$KP")" "_durum: ONAY BEKLİYOR" "H4b durum"
icerir "$(cat "$KP")" "| K2 | dersler → görev (D1) | ✓ YEŞİL | 2 ders, hepsi görev defterine D1" "H4c K2 iki ders, ikisi de görev + D1"
icerir "$(cat "$KP")" "| K4 | kaçış/tıkanma → ders | ✓ YEŞİL | 2 kaçış" "H4d K4 yeşil"
icerir "$(cat "$KP")" "_sultan_onay: (bekliyor" "H4e onay hâlâ boş — araç KAPANDI demedi, D1 üretmedi (A06)"
icermez "$(cat "$KP")" "_durum: KAPANDI" "H4f onaysız KAPANDI yok"

echo "— H5 onay satırı biçimsiz → AÇIK; H6 D1 biçimli → KAPANDI ve korunur"
sed -i 's/^_sultan_onay: .*/_sultan_onay: onaylandı/' "$KP"
kapi "H5a biçimsiz onay → rc=1" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "D1 biçimi değil" "H5b gerekçe"
icerir "$(cat "$KP")" "_sultan_onay: onaylandı" "H5c satır korunur (araç insan satırını ezmez)"
sed -i 's/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: hafta kapansın (sohbet · oturum-ref-2 · "tamam kapat" · beyan:SERDAR)/' "$KP"
kapi "H6a D1 onay → rc=0 KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
icerir "$(cat "$KP")" "_durum: KAPANDI" "H6b durum KAPANDI"
kapi "H6c yeniden ölçüm onayı korur, KAPANDI kalır" 0 python3 "$H" olc --hafta 2026-W42
icerir "$(cat "$KP")" '"tamam kapat" · beyan:SERDAR' "H6d onay satırı aynen"

sed -i 's/^_sultan_onay: \(.*\)$/_sultan_onay: \1 ve ek metin/' "$KP"
kapi "H6e geçerli D1 + kuyruk metni → BİÇİMSİZ (tam satır eşleşmesi), AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "D1 biçimi değil" "H6f gerekçe"
sed -i 's/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: hafta kapansın (sohbet · oturum-ref-2 · "tamam kapat" · beyan:SERDAR)/' "$KP"
kapi "H6g düzeltildi → KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
U16='bir iki üç dört beş altı yedi sekiz dokuz on on bir on iki on üç'   # 16 kelime, 66 karakter
sed -i "s/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: kapat (sohbet · oturum-ref-3 · \"$U16\" · beyan:SERDAR)/" "$KP"
kapi "H6h kırpık 16 kelime (120 karakter altı) → BİÇİMSİZ, AÇIK (karakter ≠ kelime)" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "kırpık 16 kelime (>15)" "H6i gerekçe kelime sayısı"
U15='bir iki üç dört beş altı yedi sekiz dokuz on on bir on iki on'           # 15 kelime
sed -i "s/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: kapat (sohbet · oturum-ref-3 · \"$U15\" · beyan:SERDAR)/" "$KP"
kapi "H6j kırpık 15 kelime → KAPANDI (sınır dahil)" 0 python3 "$H" olc --hafta 2026-W42
sed -i 's/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: hafta kapansın (sohbet · oturum-ref-2 · "tamam kapat" · beyan:SERDAR)/' "$KP"
echo "— H7 K2 kenarları (kopya MERKEZ üstünde)"
cp "$M" "$T/M.yedek"
sed -i 's/ · D1: 2026-10-18 Sultan: onay (sohbet · oturum-ref-1 · "kart depo başına, tamam" · beyan:SERDAR)/ · D1: onaylandı/' "$M"
kapi "H7a D1 biçimsiz görev satırı → K2 kırmızı → AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "D1 damgası biçimsiz" "H7b gerekçe"
cp "$T/M.yedek" "$M"; sed -i 's/ · D1: 2026-10-18 Sultan: onay (sohbet/ · D1: not: 2026-10-18 Sultan: onay (sohbet/' "$M"
kapi "H7a2 görev D1 başına yabancı metin → biçimsiz (tam eşleşme)" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "D1 damgası biçimsiz" "H7a3 gerekçe"
cp "$T/M.yedek" "$M"; sed -i "s/\"kart depo başına, tamam\"/\"$U16\"/" "$M"
kapi "H7a4 görev D1 kırpığı 16 kelime → K2 kırmızı" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "kırpık 16 kelime (>15)" "H7a5 gerekçe"
cp "$T/M.yedek" "$M"; sed -i '/ · ders M2 · D1: /d' "$M"
kapi "H7c ders görevsiz (M2) → AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "ders→görev D1 eksik: M2" "H7d eksik ders adı"
cp "$T/M.yedek" "$M"; sed -i 's/ · ders M2 · D1: / · ders M2 · D1: /; /^- gorev_01M54B2Y4QT7VWTJX10AFR7M76/c\- M2 → RED: hat adımı ayrı layiha, bu hafta görev değil' "$M"
kapi "H7c2 RED satırı dersi KAPSAMAZ (göz tur 2) → AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "ders→görev D1 eksik: M2" "H7c3 RED yolu yok"
cp "$T/M.yedek" "$M"; sed -i 's/^- M2) daraltma hat adımı eksik .*/- M2) <ders> · kaynak: <AJAN D<n> | ölçüm>/' "$M"
kapi "H7e yer tutuculu ders sayılmaz: K2 1 ders yeşil, ama kaçışın bağlandığı M2 artık yazılı değil → K4 kırmızı → AÇIK" 1 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "1 ders, hepsi" "H7f yer tutucu ders sayılmadı (K2)"; icerir "$CIKTI" "kart:is-b → M2 (ders yazılı değil)" "H7g K4 silinen derse bağ kırmızı"
cp "$T/M.yedek" "$M"

echo "— H8 K4 kenarı"
sed -i '/^- kart:is-b → /d' "$M"
kapi "H8a tıkanma damgası silinince AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "1/2 kaçış/tıkanma ders damgası almadı: kart:is-b (tıkanma)" "H8b eksik anahtar"
cp "$T/M.yedek" "$M"; sed -i 's/^- kart:is-b → M2$/- kart:is-b → RED: tıkanma dersi M1 ile aynı kök/' "$M"
kapi "H8b2 RED damgası kaçışı kapsamaz (göz tur 2) → AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "kart:is-b (tıkanma)" "H8b3 RED'li anahtar eksik sayıldı"
cp "$T/M.yedek" "$M"; sed -i 's/^- kart:is-b → M2$/- kart:is-b → M9/' "$M"
kapi "H8b4 yazılı olmayan derse bağ (M9) → AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "kart:is-b → M9 (ders yazılı değil)" "H8b5 gerekçe"
cp "$T/M.yedek" "$M"; kapi "H8c geri alındı → KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
printf '{bozuk json' > "$KOK/_agents/fabrika/kartlar/is-x.json"
kapi "H8d okunamayan kart → K4 SARI → rc=3 ÖLÇÜLEMEDİ (sessiz atlama yok)" 3 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "1 kart okunamadı, tıkanma kümesi eksik olabilir: is-x.json" "H8e bozuk kart adı"
icerir "$(cat "$KP")" "_durum: ÖLÇÜLEMEDİ" "H8f durum ÖLÇÜLEMEDİ (KAPANDI değil)"
rm -f "$KOK/_agents/fabrika/kartlar/is-x.json"; kapi "H8g bozuk kart kalkınca KAPANDI" 0 python3 "$H" olc --hafta 2026-W42

echo "— H9 açık haftalar dizinden türetilir"
mkdir -p "$KOK/_agents/handoff/retro/2026-W41"
kapi "H9a W41 kapanışsız → rc=1" 1 python3 "$H" acik; icerir "$CIKTI" "2026-W41 — KAPANIS.md yok" "H9b W41 listede"; icermez "$CIKTI" "2026-W42" "H9c W42 KAPANDI listede değil"
python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$KOK/_agents/handoff/retro/2026-W41"
kapi "H9d açık hafta yok → rc=0" 0 python3 "$H" acik
kapi "H9e retro dizini yok → rc=3" 3 python3 "$H" acik --kok "$T/ev"

echo "— M mutasyon (kopya üstünde; her mutant en az bir kapıyı kızartmalı)"
mut(){ local ad="$1" sed_="$2"; shift 2; local MR="$T/mut-$RANDOM.py"; sed -e "$sed_" "$H" > "$MR"
  if cmp -s "$MR" "$H"; then kirmizi "$ad: sed hiçbir şeyi değiştirmedi"; return; fi
  if "$@" "$MR" >/dev/null 2>&1; then kirmizi "$ad: mutant YAŞIYOR (kapı ısırmadı)"; else ok "$ad: mutant ısırıldı"; fi; }
# M1: görev satırındaki D1 denetimi kalkınca biçimsiz D1 geçer (H7a kırmızı beklerken yeşil olur)
sed -i 's/ · D1: 2026-10-18 Sultan: onay (sohbet · oturum-ref-1 · "kart depo başına, tamam" · beyan:SERDAR)/ · D1: onaylandı/' "$M"
m_d1(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -ne 0 ]; }
mut "M1 görev D1 denetimi kalkınca biçimsiz damga geçer (kapı yakalar)" '/gecerli, sebep = d1_gecerli(g.group(3))/{n;s/if gecerli:/if True:/}' m_d1
cp "$T/M.yedek" "$M"
# M2: K4 eksik denetimi kalkınca damgasız tıkanma geçer
sed -i '/^- kart:is-b → /d' "$M"
m_k4(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -ne 0 ]; }
mut "M2 K4 eksik denetimi kalkınca damgasız kaçış geçer (kapı yakalar)" 's/^    if eksik or yok:$/    if False:/' m_k4
cp "$T/M.yedek" "$M"
# M3: onay D1 denetimi kalkınca 'onaylandı' KAPANDI sayılır (A06 kapısı)
sed -i 's/^_sultan_onay: .*/_sultan_onay: onaylandı/' "$KP"
m_onay(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -ne 0 ]; }
mut "M3 onay D1 denetimi kalkınca biçimsiz onay haftayı kapatır (kapı yakalar)" '/gecerli, sebep = d1_gecerli(v)/{n;s/if gecerli:/if True:/}' m_onay

# M4: bozuk kart SARI'ya çevrilmezse H8d yeşil döner
printf '{bozuk json' > "$KOK/_agents/fabrika/kartlar/is-x.json"
m_bozuk(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -eq 3 ]; }
mut "M4 bozuk kart sessiz atlanınca sarı kaybolur (kapı yakalar)" 's/^    if bozuk:$/    if False:/' m_bozuk
rm -f "$KOK/_agents/fabrika/kartlar/is-x.json"
# M5: onay tam-eşleşme gevşeyince kuyruk metinli D1 kapatır
sed -i 's/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: hafta kapansın (sohbet · oturum-ref-2 · "tamam kapat" · beyan:SERDAR) ve ek metin/' "$KP"
kapi "M5-önkoşul: kuyruklu D1 gerçek araçta AÇIK" 1 python3 "$H" olc --hafta 2026-W42
m_kuyruk(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -ne 0 ]; }
mut "M5 onay D1 tam eşleşmesi gevşeyince kuyruklu onay kapatır (kapı yakalar)" 's/    m = D1_RE.fullmatch(v.strip())/    m = D1_RE.search(v.strip())/' m_kuyruk

# M6: K4'te "ders yazılı değil" denetimi kalkınca M9 bağı geçer
sed -i 's/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: hafta kapansın (sohbet · oturum-ref-2 · "tamam kapat" · beyan:SERDAR)/' "$KP"
sed -i 's/^- kart:is-b → M2$/- kart:is-b → M9/' "$M"
kapi "M6-önkoşul: M9 gerçek araçta AÇIK" 1 python3 "$H" olc --hafta 2026-W42
m_m9(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -ne 0 ]; }
mut "M6 yazılı-ders denetimi kalkınca M9 bağı geçer (kapı yakalar)" 's/    yok = \[f"{a} → M{n} (ders yazılı değil)" for a, n in damga.items() if a in anahtarlar and n not in dersler\]/    yok = []/' m_m9
cp "$T/M.yedek" "$M"

# M7: kelime sınırı kalkınca 16 kelimelik kırpık haftayı kapatır
sed -i "s/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: kapat (sohbet · oturum-ref-3 · \"$U16\" · beyan:SERDAR)/" "$KP"
kapi "M7-önkoşul: 16 kelime gerçek araçta AÇIK" 1 python3 "$H" olc --hafta 2026-W42
m_kelime(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -ne 0 ]; }
mut "M7 kırpık kelime sınırı kalkınca 16 kelimelik onay kapatır (kapı yakalar)" 's/^    if n > D1_KIRPIK_KELIME:$/    if False:/' m_kelime

echo "— H10 K6 Doğrulat dersleri → BİRLEŞMİŞ beceri PR (Sultan katı kuralı 17 Eki; işlenmemiş ders varsa hafta kapanmaz)"
# sahte gh (hermetik): PR durumu tablodan; tabloda yoksa "PR değil"; GH_COK=1 → ağ hatası (ölçülemedi)
cat > "$T/gh" <<'EOF'
#!/usr/bin/env bash
[ "${GH_COK:-0}" = 1 ] && { echo "error connecting to api.github.com" >&2; exit 1; }
n="$3"; repo="$5"; d="$(awk -v k="$repo#$n" '$1==k{print $2}' "$(dirname "$0")/gh-tablo")"
[ -n "$d" ] && { echo "$d"; exit 0; }
echo "GraphQL: Could not resolve to a PullRequest with the number of $n. (repository.pullRequest)" >&2; exit 1
EOF
chmod +x "$T/gh"; printf 'sultanxgokce/cloudtop#676 MERGED\nsultanxgokce/Sx-Claude-Skills#370 MERGED\nx/y#371 MERGED\nsultanxgokce/cloudtop#900 OPEN\nsultanxgokce/cloudtop#901 CLOSED\n' > "$T/gh-tablo"
export HAFTA_KAPANIS_GH="$T/gh"
cp "$T/M.yedek" "$M"; sed -i 's/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: hafta kapansın (sohbet · oturum-ref-2 · "tamam kapat" · beyan:SERDAR)/' "$KP"
kapi "H10-önkoşul: seans kaydı yokken KAPANDI (K6 yeşil, bunu söyler)" 0 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "✓ K6 Doğrulat dersleri → beceri PR: bu hafta Doğrulat seans kaydı yok" "H10-önkoşul2 K6 dili"
DG="$KOK/_agents/handoff/retro/dogrulat"; mkdir -p "$DG"
cat > "$DG/2026-10-16.md" <<'EOF'
# Doğrulat seansı retrosu — 2026-10-16
## Ölçüm
- 40 → 3
## Pürüzler → ders → nereye işlendi
1. Zil meşgulü hata saydı → cloudtop #676 (birleşti)
2. Bitiş sinyali yok → protokol: parti sonu aile-notify; kalıcı: gorev_01M554915VR3GXP09XEDYGNCNC
3. AÇIK: dış yüzeyde ekran görülmedi → gorev_01M55490W8TSGAD8SGF3H78ZGB (kare şartı)
## Sonraki seans için ölçülecek
- tık sayısı #1 hedef
EOF
kapi "H10a PR'sız ders (2) + AÇIK ders (3) → K6 kırmızı → AÇIK rc=1" 1 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "2026-10-16.md: 2/3 ders PR'a işlenmedi (madde 2: PR yok; 3: AÇIK)" "H10b eksik seans dersleri ve gerekçesiyle (görev kimliği PR yerine geçmez; ders dışı bölüm sayılmaz)"
icerir "$(cat "$KP")" "| K6 | Doğrulat dersleri → beceri PR | ✗ KIRMIZI |" "H10c KAPANIS.md'de K6 satırı"
icerir "$(cat "$KP")" "_durum: AÇIK" "H10d onay VAR olsa da hafta AÇIK (onay işlenmemiş dersi kapatmaz)"
cp "$DG/2026-10-16.md" "$T/DG.yedek"
ders2(){ sed -i "s|^2\. .*|2. $1|" "$DG/2026-10-16.md"; }
sed -i 's|^3\. AÇIK: dış yüzeyde .*|3. Dış yüzeyde kare şartı → https://github.com/x/y/pull/371|' "$DG/2026-10-16.md"
ders2 "Bitiş sinyali → Sx #370 muhakkik --done adımı"
kapi "H10e üç ders de BİRLEŞMİŞ PR'a bağlı (depo #N · /pull/N) → KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "1 Doğrulat seansı, 3 dersin hepsi birleşmiş bir PR'a işlenmiş" "H10f yeşil dili"
ders2 "AÇIK: Bitiş sinyali → Sx #370 sürüyor"
kapi "H10g birleşmiş PR'ı olsa da AÇIK işaretli ders işlenmemiş → AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "1/3 ders PR'a işlenmedi (madde 2: AÇIK)" "H10h gerekçe"
ders2 "Bitiş sinyali → cloudtop #900 (inceleniyor)"
kapi "H10p PR kaynağında AÇIK (OPEN, metinde etiketsiz) → işlenmemiş (göz #365 tur 1)" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "madde 2: cloudtop #900 open" "H10p2 gerekçe PR durumundan"
ders2 "Bitiş sinyali → cloudtop #901"
kapi "H10q kapatılmış (birleşmemiş) PR → işlenmemiş" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "madde 2: cloudtop #901 closed" "H10q2 gerekçe"
ders2 "Bitiş sinyali → cloudtop #12345 (issue)"
kapi "H10r PR olmayan numara (issue) → işlenmemiş (göz #365 tur 1)" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "madde 2: cloudtop #12345 PR değil" "H10r2 gerekçe"
ders2 "Bitiş sinyali → #370"
kapi "H10s depo adı olmadan #N (hangi depo?) → işlenmemiş" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "madde 2: depo adı olmadan #N" "H10s2 gerekçe"
ders2 "Bitiş sinyali → Sx #370 muhakkik --done adımı"
kapi "H10t gh cevap veremez → K6 SARI → rc=3 ÖLÇÜLEMEDİ (ölçülemedi ≠ işlendi)" 3 env GH_COK=1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "PR durumu ölçülemedi (gh)" "H10t2 gerekçe"
cp "$T/DG.yedek" "$DG/2026-10-16.md"
printf '# Doğrulat seansı — 2026-10-16\n## Ölçüm\n- 10 → 2\n' > "$DG/2026-10-16.md"
kapi "H10i ders bölümü olmayan seans → AÇIK" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "2026-10-16.md: ders bölümü yok" "H10j gerekçe"
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/2026-10-16.md"
cp "$T/DG.yedek" "$DG/2026-10-05.md"
kapi "H10k başka haftanın işlenmemiş seansı bu haftayı tutmaz → KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
kapi "H10l ...ama kendi haftasında (W41) kırmızı" 1 python3 "$H" olc --hafta 2026-W41; icerir "$CIKTI" "2026-10-05.md: 2/3 ders" "H10m W41 gerekçe"
python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$KOK/_agents/handoff/retro/2026-W41"
printf '# taslak seans\n## Pürüzler → ders\n1. x → cloudtop #676\n' > "$DG/taslak.md"
kapi "H10n adında tarih olmayan seans dosyası → K6 SARI → rc=3 ÖLÇÜLEMEDİ (bu hafta değil sayılmaz)" 3 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "taslak.md (adında tarih yok)" "H10o gerekçe"
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/taslak.md"
cp "$T/DG.yedek" "$DG/2026-10-16.md"
# K6 mutantları (kopya üstünde)
m_k6_bagli(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -ne 0 ]; }
m_k6_bagli_2(){ local o; o="$(python3 "$1" olc --hafta 2026-W42 2>&1)"; grep -qF "madde 2: PR yok" <<<"$o"; }
mut "M8 PR yok denetimi kalkınca görev kimlikli ders işlenmiş sayılır (kapı yakalar)" 's/        return "islenmedi", "depo adı olmadan #N" if ciplak else "PR yok"/        return ("islenmedi", "depo adı olmadan #N") if ciplak else ("islendi", "")/' m_k6_bagli_2
sed -i 's|^3\. AÇIK: dış yüzeyde .*|3. Dış yüzeyde kare şartı → https://github.com/x/y/pull/371|' "$DG/2026-10-16.md"
ders2 "AÇIK: Bitiş sinyali → Sx #370 sürüyor"
mut "M9 AÇIK denetimi kalkınca birleşmiş PR'lı AÇIK ders geçer (kapı yakalar)" 's/^    if ACIK_RE.search(tx):$/    if False:/' m_k6_bagli
ders2 "Bitiş sinyali → cloudtop #900 (inceleniyor)"
mut "M12 PR durumu sorulmazsa (referans var = işlendi) açık PR haftayı kapatır (kapı yakalar)" 's/    if any(x == "MERGED" for _, x in durumlar):/    if durumlar:/' m_k6_bagli
ders2 "Bitiş sinyali → #370"
mut "M13 çıplak #N kabul edilince depo belirsiz referans geçer (kapı yakalar)" 's/        return "islenmedi", "depo adı olmadan #N" if ciplak else "PR yok"/        return ("islendi", "") if ciplak else ("islenmedi", "PR yok")/' m_k6_bagli
ders2 "Bitiş sinyali → Sx #370 muhakkik --done adımı"
m_k6_gh(){ GH_COK=1 python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -eq 3 ]; }
mut "M14 gh hatası sessiz geçilince ölçülemeyen PR yeşil olur (kapı yakalar)" 's/^    if olcemedi:$/    if False:/' m_k6_gh
cp "$T/DG.yedek" "$DG/2026-10-16.md"
mut "M10 K6 olc'a bağlı olmazsa işlenmemiş ders haftayı kapatır (kapı yakalar)" '/K.append(("K6", /d' m_k6_bagli
printf '# taslak\n' > "$DG/taslak.md"
m_k6_tarih(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -eq 3 ]; }
mut "M11 tarihsiz seans sessiz atlanınca sarı kaybolur (kapı yakalar)" 's/^    if tarihsiz or okunamadi:$/    if False:/' m_k6_tarih
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/taslak.md"

echo; echo "GECEN=$G DUSEN=$K"
[ "$K" -eq 0 ]
