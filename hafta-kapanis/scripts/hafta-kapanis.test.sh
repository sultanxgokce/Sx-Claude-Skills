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

echo "— H10 K6 Doğrulat → beceri PR · hüküm kanon D13 oracle'ında (tek ölçüm; kapı çağırır, kuralı kopyalamaz)"
# sahte D13 oracle'ı — KURAL İÇERMEZ, yalnız arayüz: rc + "  ✗ <ad> · <neden>" / "  ? <ad> · <neden>" satırları; argümanları kaydeder.
# Gerçek oracle (cloudtop #691) + gerçek gh ile tümleşik ölçüm kanıttadır.
cat > "$T/d13" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$(dirname "$0")/d13-arg"
c="$(dirname "$0")/d13-cevap"; rc="$(head -1 "$c")"; tail -n +2 "$c"; exit "$rc"
EOF
chmod +x "$T/d13"; d13(){ printf '%s\n' "$@" > "$T/d13-cevap"; }
export HAFTA_KAPANIS_D13="$T/d13"
cp "$T/M.yedek" "$M"; sed -i 's/^_sultan_onay: .*/_sultan_onay: 2026-10-18 Sultan: hafta kapansın (sohbet · oturum-ref-2 · "tamam kapat" · beyan:SERDAR)/' "$KP"
d13 0 "DOĞRULAT RETRO KAPISI · seans yok · kapı açık"
kapi "H10-önkoşul: seans kaydı yokken KAPANDI (K6 yeşil, bunu söyler)" 0 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "✓ K6 Doğrulat dersleri → beceri PR: bu hafta Doğrulat seans kaydı yok" "H10-önkoşul2 K6 dili"
DG="$KOK/_agents/handoff/retro/dogrulat"; mkdir -p "$DG"
cat > "$DG/2026-10-16.md" <<'EOF'
# Doğrulat seansı retrosu — 2026-10-16
beceri-pr: bekliyor
## Ölçüm
- 40 → 3
## Pürüzler → ders → nereye işlendi
1. Zil meşgulü hata saydı → cloudtop #676 (birleşti)
2. Bitiş sinyali yok → protokol: parti sonu aile-notify
3. AÇIK: dış yüzeyde ekran görülmedi → gorev_01M55490W8TSGAD8SGF3H78ZGB
EOF
cp "$DG/2026-10-16.md" "$T/DG.yedek"
BEYANSIZ="  ✗ 2026-10-16 · beceri-pr satırı yok ya da 'bekliyor'"
d13 1 "DOĞRULAT RETRO KAPISI · 1 seans · 0 işlendi · 1 İŞLENMEMİŞ → hafta kapanmaz" "$BEYANSIZ"
kapi "H10a oracle 'işlenmemiş' → K6 kırmızı → AÇIK rc=1" 1 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "2026-10-16.md: beceri-pr satırı yok ya da 'bekliyor' (kanon D13) — dersleri: 1 “Zil meşgulü hata saydı”; 2 “Bitiş sinyali yok”; 3 “AÇIK: dış yüzeyde ekran görülmedi”" "H10b eksik seans oracle gerekçesi + DERSLERİYLE"
icerir "$(cat "$T/d13-arg")" "--dizin $DG --gun " "H10b2 oracle bu kökün dogrulat dizinini ölçtü (kural kopyalanmadı, çağrıldı)"
icerir "$(cat "$KP")" "| K6 | Doğrulat dersleri → beceri PR | ✗ KIRMIZI |" "H10c KAPANIS.md'de K6 satırı"
icerir "$(cat "$KP")" "_durum: AÇIK" "H10d onay VAR olsa da hafta AÇIK (onay işlenmemiş dersi kapatmaz)"
d13 1 "x" "  ✗ 2026-10-16 · cloudtop#900 birleşmemiş (beyan var, iş yok)"
kapi "H10p oracle 'beyan var, PR birleşmemiş' → kırmızı, gerekçe oracle'dan" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "2026-10-16.md: cloudtop#900 birleşmemiş (beyan var, iş yok) (kanon D13) — dersleri: 1 “Zil" "H10p2 gerekçe + dersler"
d13 0 "DOĞRULAT RETRO KAPISI · 1 seans · 1 işlendi · kapı açık (gh doğrulamalı)"
kapi "H10e oracle 'hepsi işlendi' → KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "1 Doğrulat seansı işlenmiş (kanon D13" "H10f yeşil dili"
d13 2 "DOĞRULAT RETRO KAPISI · 1 seans · ÖLÇÜLEMEDİ (gh doğrulamalı)" "  ? 2026-10-16 · cloudtop#902 gh'den okunamadı"
kapi "H10t oracle '? ölçülemedi' → K6 SARI → rc=3 (ölçülemedi ≠ işlendi)" 3 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "kanon D13 ölçülemedi: 2026-10-16.md: cloudtop#902 gh'den okunamadı" "H10t2 gerekçe"
cp "$DG/2026-10-16.md" "$DG/2026-10-15.md"
d13 2 "x" "  ? 2026-10-15 · cloudtop#902 gh'den okunamadı" "  ✗ 2026-10-16 · cloudtop#900 birleşmemiş (beyan var, iş yok)"
kapi "H10y bir seans kırmızı + öteki ölçülemedi → KIRMIZI, ölçülemeyen de raporda (göz #365 tur 3)" 1 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "ayrıca ölçülemedi: 2026-10-15.md: cloudtop#902 gh'den okunamadı" "H10y2 ölçülemeyen gizlenmedi"
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/2026-10-15.md"
d13 2 "ÖLÇÜLEMEDİ: gh yok — referans doğrulanamaz"
kapi "H10z oracle rc=2 ve seans adı yok (gh yok) → K6 SARI" 3 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "kanon D13 ölçülemedi (rc=2): ÖLÇÜLEMEDİ: gh yok" "H10z2 gerekçe"
d13 1 "x" "  satır biçimi değişti"
kapi "H10zc oracle rc=1 ama seans adı okunamıyor → SARI (sessiz yeşil yok)" 3 python3 "$H" olc --hafta 2026-W42
d13 0 "ok"
kapi "H10za oracle yok (cloudtop #691 birleşmeden) → K6 SARI → ÖLÇÜLEMEDİ" 3 python3 "$H" olc --hafta 2026-W42 --d13 "$T/yok.sh"; icerir "$CIKTI" "kanon D13 oracle'ı yok" "H10za2 gerekçe"
d13 1 "x" "  ✗ 2026-10-20 · beceri-pr satırı yok ya da 'bekliyor'"
kapi "H10zb oracle listesindeki SONRAKİ haftanın seansı bu haftayı tutmaz → KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
printf '# Doğrulat seansı — 2026-10-16\nbeceri-pr: cloudtop#676\n## Ölçüm\n- 10 → 2\n' > "$DG/2026-10-16.md"; d13 0 ok
kapi "H10i ders bölümü olmayan seans → AÇIK (oracle yeşil olsa da)" 1 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "2026-10-16.md: ders bölümü yok" "H10j gerekçe"
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/2026-10-16.md"
cp "$T/DG.yedek" "$DG/2026-10-05.md"; d13 1 "x" "  ✗ 2026-10-05 · beceri-pr satırı yok ya da 'bekliyor'"
kapi "H10k başka haftanın işlenmemiş seansı bu haftayı tutmaz → KAPANDI" 0 python3 "$H" olc --hafta 2026-W42
kapi "H10l ...ama kendi haftasında (W41) kırmızı" 1 python3 "$H" olc --hafta 2026-W41; icerir "$CIKTI" "2026-10-05.md: beceri-pr satırı yok" "H10m W41 gerekçe"
python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$KOK/_agents/handoff/retro/2026-W41"
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/2026-10-05.md"
printf '# taslak seans\nbeceri-pr: cloudtop#676\n## Pürüzler → ders\n1. x\n' > "$DG/taslak.md"
kapi "H10n adında tarih olmayan seans dosyası → K6 SARI → rc=3 (bu hafta değil sayılmaz)" 3 python3 "$H" olc --hafta 2026-W42; icerir "$CIKTI" "taslak.md (adında tarih yok)" "H10o gerekçe"
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/taslak.md"
for g in 13 14; do { printf '# seans\nbeceri-pr: bekliyor\n## Pürüzler → ders → nereye işlendi\n'; for i in $(seq 1 15); do printf '%s. ders %s-%s uzunca bir cümle, işlenmedi → protokol notu\n' "$i" "$g" "$i"; done; } > "$DG/2026-10-$g.md"; done
d13 1 "x" "  ✗ 2026-10-13 · beceri-pr satırı yok ya da 'bekliyor'" "  ✗ 2026-10-14 · beceri-pr satırı yok ya da 'bekliyor'"
kapi "H10u 2 seans × 15 ders, işlenmemiş → AÇIK" 1 python3 "$H" olc --hafta 2026-W42
icerir "$CIKTI" "15 “ders 14-15 uzunca bir cümle, işlenmedi”" "H10w son seansın son dersi de raporda — kesilmez (göz #365 tur 2)"
icerir "$(cat "$KP")" "“ders 14-15 uzunca bir cümle, işlenmedi”" "H10x KAPANIS.md'de de tam liste"
m_k6_kesik(){ local o; o="$(python3 "$1" olc --hafta 2026-W42 2>&1)"; grep -qF "15 “ders 14-15 uzunca bir cümle, işlenmedi”" <<<"$o"; }
mut "M15 rapor kesilince son seansın dersleri kaybolur (kapı yakalar)" 's/{ek}"   # kesilmez/{ek}"[:400]   # kesilmez/' m_k6_kesik
m_k6_ders(){ local o; o="$(python3 "$1" olc --hafta 2026-W42 2>&1)"; grep -qF "“ders 13-1 uzunca bir cümle, işlenmedi”" <<<"$o"; }
mut "M16 dersler rapordan düşünce yalnız seans adı kalır (kapı yakalar)" "s/ — dersleri: {ders_soz}\")$/\")/" m_k6_ders
python3 -c "import os,sys; [os.remove(x) for x in sys.argv[1:]]" "$DG/2026-10-13.md" "$DG/2026-10-14.md"
# K6 mutantları (kopya üstünde) — her biri doğru davranışın tam rc'sini bekler (sarıya kaçmak da yakalanır)
cp "$T/DG.yedek" "$DG/2026-10-16.md"; d13 1 "x" "$BEYANSIZ"
m_k6_red(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -eq 1 ]; }
mut "M8 oracle'ın ✗ satırları yok sayılınca işlenmemiş seans geçer (kapı yakalar)" 's/kirmizi = \[(ad, n) for k, ad, n in satirlar if k == "✗"\]/kirmizi = []/' m_k6_red
mut "M10 K6 olc'a bağlı olmazsa işlenmemiş seans haftayı kapatır (kapı yakalar)" '/K.append(("K6", /d' m_k6_red
m_k6_sari(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -eq 3 ]; }
m_k6_sari_yok(){ python3 "$1" olc --hafta 2026-W42 --d13 "$T/yok.sh" >/dev/null 2>&1; [ $? -eq 3 ]; }
mut "M18 oracle yokken sessiz geçilince işlenmemiş hafta kapanır (kapı yakalar)" "s/^    if not d13:$/    if False:/" m_k6_sari_yok
d13 2 "ÖLÇÜLEMEDİ: gh yok — referans doğrulanamaz"
mut "M19 oracle rc=2 (adsız) yeşil sayılınca ölçülemeyen hafta kapanır (kapı yakalar)" 's/ or (r.returncode != 0 and not satirlar):$/:/' m_k6_sari
d13 1 "x" "  satır biçimi değişti"
mut "M20 oracle rc=1 ama ad okunamayınca sessiz geçilirse yeşil olur (kapı yakalar)" 's/ or (r.returncode != 0 and not satirlar):$/:/' m_k6_sari
d13 2 "x" "  ? 2026-10-16 · cloudtop#902 gh'den okunamadı"
mut "M14 oracle '?' satırı yok sayılınca ölçülemeyen PR yeşil olur (kapı yakalar)" 's/bilinmez = \[(ad, n) for k, ad, n in satirlar if k == "?" and ad in seanslar\]/bilinmez = []/' m_k6_sari
cp "$DG/2026-10-16.md" "$DG/2026-10-15.md"; d13 2 "x" "  ? 2026-10-15 · cloudtop#902 gh'den okunamadı" "  ✗ 2026-10-16 · cloudtop#900 birleşmemiş (beyan var, iş yok)"
m_k6_gizli(){ local o; o="$(python3 "$1" olc --hafta 2026-W42 2>&1)"; grep -qF "cloudtop#902 gh'den okunamadı" <<<"$o"; }
mut "M17 kırmızı rapor ölçülemeyeni yutunca sorun görünmez (kapı yakalar)" 's/^        ek = f" · ayrıca ölçülemedi: .*/        ek = ""/' m_k6_gizli
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/2026-10-15.md"
printf '# taslak\n' > "$DG/taslak.md"; d13 0 ok
mut "M11 tarihsiz seans sessiz atlanınca sarı kaybolur (kapı yakalar)" 's/^    if tarihsiz or okunamadi:$/    if False:/' m_k6_sari
python3 -c "import os,sys; os.remove(sys.argv[1])" "$DG/taslak.md"
d13 1 "x" "  ✗ 2026-10-20 · beceri-pr satırı yok ya da 'bekliyor'"
m_k6_hafta(){ python3 "$1" olc --hafta 2026-W42 >/dev/null 2>&1; [ $? -eq 0 ]; }
mut "M21 oracle listesi haftaya süzülmezse sonraki haftanın seansı W42'yi tutar (kapı yakalar)" 's/^            if a == ad:$/            if True:/' m_k6_hafta

echo; echo "GECEN=$G DUSEN=$K"
[ "$K" -eq 0 ]
