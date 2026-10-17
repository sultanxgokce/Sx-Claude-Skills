#!/usr/bin/env bash
# birlestirme-kapisi.test.sh — kapının GERÇEKTEN kapı olduğunu ölçer + mutasyon.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$HERE/birlestirme-kapisi.sh"; K="$HERE/kanit.sh"; KT="$HERE/kart.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; ( cd "$T" && git init -q -b main ) >/dev/null 2>&1
export KANIT_DEPO="$T" FABRIKA_TETIK=/nonexistent
kart() { bash "$KT" ac "$1" --is x --istedi S --aldi M --geri-alinamaz "${2:-h}" --para h --dis-yuzey h --yetki h >/dev/null 2>&1; }
den() { # den <iş> <tur> <puan> <E/H> [yazan] [denetci] [yedek] [yazan_model] [yedek_model]
  mkdir -p "$T/_agents/fabrika/kanit/$1"
  python3 - "$T/_agents/fabrika/kanit/$1/DENETIM-$2.json" "$2" "$1" "$3" "$4" "${5:-claude}" "${6:-codex}" "${7:-}" "${8:-}" "${9:-}" <<'PY'
import json,sys,datetime
p,tur,is_,puan,dogru,yazan,den,yedek,yazan_model,yedek_model=sys.argv[1:]
d={"tur":int(tur),"is":is_,"pr":"7","yazan":yazan,"denetci":den,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
 "kanit_durumu":"sağlam","sonuc":{"kod_puani":int(puan),"dogru_sey":dogru,"ozet":"o","bulgular":[],"kanit_gorusu":"k"}}
if yedek: d["yedek"]=yedek
if yazan_model: d["yazan_model"]=yazan_model
if yedek_model: d["yedek_model"]=yedek_model
json.dump(d,open(p,"w"))
PY
}

echo "════ T1 · hiçbir şey yok → engeller ════"
bash "$G" bos --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kart+kanıt+denetim yokken rc=1"

echo "════ T2 · kart+kanıt var ama DENETİM yok → engeller ════"
kart is-a; bash "$K" olcum is-a olc --asama tek -- echo 1 >/dev/null 2>&1
CIKTI="$(bash "$G" is-a 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "bağımsız göz koşmamışken rc=1"
grep -q "DENETİM kaydı YOK" <<<"$CIKTI"; g $? "sebebi yazılı"
# 🔴 rc'ye bakmak yetmiyor: bozuk tırnak yüzünden mesaj satırı yönlendirmeye dönüşmüştü ve rc aynı
# kalıyordu (23 Eyl, bağımsız göz turu sırasında yakalandı). Artık METNİN BASILDIĞINI da iddia ediyoruz.
grep -q 'FABRIKA_KAPISIZ="<en az 20 karakterlik gerekçe>"' <<<"$CIKTI"; g $? "kaçış satırı bozulmadan basılıyor"
grep -qv "No such file" <<<"$CIKTI"; g $? "yönlendirme hatası yok"

echo "════ T3 · puan 4 → engeller · 5 ama H → engeller ════"
den is-a 1 4 E; bash "$G" is-a --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "4/5 → rc=1"
den is-a 2 5 H; bash "$G" is-a --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "5 ama 'doğru şey' H → rc=1"

echo "════ T4 · 5+E → GEÇER ════"
den is-a 3 5 E
CIKTI="$(bash "$G" is-a 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "rc=0"
grep -q "GEÇTİ" <<<"$CIKTI"; g $? "GEÇTİ yazıyor"
grep -q "tur 3" <<<"$CIKTI"; g $? "son turu okudu (1 ve 2 değil)"

echo "════ T5 · yazan = denetçi → engeller (K1) ════"
kart is-b; bash "$K" olcum is-b olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b 1 5 E codex codex
CIKTI="$(bash "$G" is-b 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "aynı model → rc=1"
grep -q "bağımsız göz değil" <<<"$CIKTI"; g $? "K1 gerekçesi yazılı"

echo "════ T5b · yedek göz + farklı model → bağımsız SAYILIR (Sultan Y0006) ════"
kart is-b2; bash "$K" olcum is-b2 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b2 1 5 E claude "claude (sonnet-5) (YEDEK GÖZ: codex yok)" "codex yok" "opus-4" "sonnet-5"
CIKTI="$(bash "$G" is-b2 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "farklı model → yedek göz bağımsız, rc=0"
grep -q "K1 bağımsız SAYILDI" <<<"$CIKTI"; g $? "sebebi yazılı"

echo "════ T5c · SAHTE yedek kaydı (yedek_model = yazan_model) → HÂLÂ ENGELLER (fail-closed) ════"
kart is-b3; bash "$K" olcum is-b3 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b3 1 5 E claude "claude (sonnet-5) (YEDEK GÖZ: codex yok)" "codex yok" "sonnet-5" "sonnet-5"
CIKTI="$(bash "$G" is-b3 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "yedek_model = yazan_model → sahte-yedek, rc=1 (fail-closed)"
grep -q "bağımsız göz değil" <<<"$CIKTI"; g $? "K1 gerekçesi yazılı"

echo "════ T5d · yedek alanı dolu ama model bilgisi YOK → HÂLÂ ENGELLER (fail-closed) ════"
kart is-b4; bash "$K" olcum is-b4 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b4 1 5 E claude "claude (YEDEK GÖZ: codex yok)" "codex yok"
CIKTI="$(bash "$G" is-b4 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "model alanları boş → ölçülemez, rc=1 (fail-closed)"

echo "════ T5e · 🔧 yedek gerekçesi '|' İÇERİYOR → alan kaymıyor (bağımsız göz #339) ════"
# 🔴 Eski pipe-ayracı: yedek metninde "|" varsa IFS='|' read alanları KAYDIRIRDI — eşit
# modeller (sonnet-5 = sonnet-5) farklı okunup K1 yanlışlıkla GEÇİLEBİLİRDİ. Her alan artık
# kendi satırında; "|" içeren serbest metin bile alan sınırını BOZAMAZ.
kart is-b5; bash "$K" olcum is-b5 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b5 1 5 E claude "claude (sonnet-5) (YEDEK GOZ: codex|yok|iki|deneme)" "codex|yok|iki|deneme" "sonnet-5" "sonnet-5"
CIKTI="$(bash "$G" is-b5 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "'|' içeren yedek metni + AYNI model → hâlâ reddeder (alan kaymadı)"
grep -q "bağımsız göz değil" <<<"$CIKTI"; g $? "K1 gerekçesi yazılı (yanlışlıkla bağımsız sayılmadı)"
kart is-b6; bash "$K" olcum is-b6 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b6 1 5 E claude "claude (sonnet-5) (YEDEK GOZ: codex|yok|iki|deneme)" "codex|yok|iki|deneme" "opus-4" "sonnet-5"
CIKTI="$(bash "$G" is-b6 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "'|' içeren yedek metni + FARKLI model → doğru okunur, bağımsız sayılır"

echo "════ T5g · 🔧 yedek gerekçesi YENİ SATIR İÇERİYOR → alan kaymıyor (bağımsız göz #339 tur 2) ════"
# 🔴 Satır-temelli okuma (sed -n Np) da kırılgandı: yedek metninde "\n" varsa sabit satır
# numaraları kayardı. shlex.quote + eval metinsel ayraca/satır-sayısına dayanmaz.
kart is-b7; bash "$K" olcum is-b7 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b7 1 5 E claude "claude (sonnet-5) (YEDEK GOZ: codex yok)" $'codex yok\niki deneme\nuc satir' "sonnet-5" "sonnet-5"
CIKTI="$(bash "$G" is-b7 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "yeni satır içeren yedek metni + AYNI model → hâlâ reddeder (alan kaymadı)"
grep -q "bağımsız göz değil" <<<"$CIKTI"; g $? "K1 gerekçesi yazılı (yanlışlıkla bağımsız sayılmadı)"
kart is-b8; bash "$K" olcum is-b8 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b8 1 5 E claude "claude (sonnet-5) (YEDEK GOZ: codex yok)" $'codex yok\niki deneme\nuc satir' "opus-4" "sonnet-5"
CIKTI="$(bash "$G" is-b8 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "yeni satır içeren yedek metni + FARKLI model → doğru okunur, bağımsız sayılır"

echo "════ T5h · 🔧 karar denetçi METNİNİN BİÇİMİNE bağlı değil (bağımsız göz #339 tur 3, CİDDİ) ════"
# 🔴 Eski hâl: fail-closed red yalnız `case "$denetci" in *"$yazan"*)` dalında uygulanıyordu.
# denetci metni yazanın adını İÇERMİYORSA (biçim farkı) — AYNI modelle alınmış bir yedek kaydı
# bile kontrolden geçip K1'i yanlışlıkla aşabilirdi. Karar artık `yedek` ALANININ VARLIĞI
# üzerinden verilir, denetci'nin tam biçimine duyarlı DEĞİL.
kart is-b9; bash "$K" olcum is-b9 olc --asama tek -- echo 1 >/dev/null 2>&1
den is-b9 1 5 E claude "codex" "codex yok" "sonnet-5" "sonnet-5"
CIKTI="$(bash "$G" is-b9 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "denetci metni yazanı İÇERMİYOR ama yedek AYNI modelle → hâlâ reddeder"
grep -q "bağımsız göz değil" <<<"$CIKTI"; g $? "K1 gerekçesi yazılı"

echo "════ T6 · kanıt manifesti elle boyanırsa → engeller ════"
kart is-c; bash "$K" olcum is-c olc --asama tek -- echo 1 >/dev/null 2>&1; den is-c 1 5 E
bash "$G" is-c --sessiz >/dev/null 2>&1; g $? "önce temiz: rc=0"
python3 - <<PY
import json;p='$T/_agents/fabrika/kanit/is-c/KANIT.json';m=json.load(open(p));m['kayitlar'][0]['renk']='yesil-boyali';json.dump(m,open(p,'w'))
PY
CIKTI="$(bash "$G" is-c 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "boyanmış manifest → rc=1"
grep -q "BOZUK" <<<"$CIKTI"; g $? "sebebi yazılı"

echo "════ T7 · kart yoksa engeller (0. adım atlanamaz) ════"
mkdir -p "$T/_agents/fabrika/kanit/is-d"; bash "$K" olcum is-d olc --asama tek -- echo 1 >/dev/null 2>&1; den is-d 1 5 E
CIKTI="$(bash "$G" is-d 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "kartsız → rc=1"
grep -q "kart YOK" <<<"$CIKTI"; g $? "sebebi yazılı"

echo "════ T8 · sınıf işi GEÇER ama Sultan uyarısı basar (A06) ════"
kart is-e e; bash "$K" olcum is-e olc --asama tek -- echo 1 >/dev/null 2>&1; den is-e 1 5 E
CIKTI="$(bash "$G" is-e 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "5+E ile geçer"
grep -q "SINIF İŞİ" <<<"$CIKTI" && grep -q "onay ÜRETMEZ" <<<"$CIKTI"; g $? "Sultan kararı olduğunu söylüyor, onay üretmiyor"

echo "════ T9 · MUTASYON: kapıyı bozunca sınav kırmızı veriyor mu ════"
# 🔴 Mutant, betiğin KARDEŞLERİYLE aynı dizinde durmalı. Önceki sürümde mutantı /tmp'ye koymuştum;
# $HERE yanlış çözülüp kanit.py bulunamıyordu ve T10 "rc=3" ile YANLIŞ SEBEPTEN yeşil veriyordu.
PKG="$T/pkg"; mkdir -p "$PKG"; cp "$HERE/kanit.py" "$HERE/kanit.sh" "$PKG/"
M="$PKG/mutant.sh"; sed 's/^  exit 1$/  exit 0/' "$G" > "$M"; chmod +x "$M"
bash "$M" bos --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "mutant (red kaldırıldı) izin veriyor → T1 bu mutantta düşerdi"
bash "$M" is-a --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "mutant sağlam işe de izin veriyor (ölçer sahte-kırmızı üretmiyor)"

echo "════ T10 · kanıt aracı yoksa YEŞİL DEMİYOR (rc=3) ════"
M2="$PKG/mutant2.sh"; sed 's|\$HERE/kanit.py|/yok/kanit.py|g' "$G" > "$M2"; chmod +x "$M2"
CIKTI="$(bash "$M2" is-a 2>&1)"; RC=$?
[ "$RC" -eq 3 ]; g $? "kanit.py yokken rc=3 (ölçülemedi, yeşil değil)"
grep -q "ÖLÇÜLEMEDİ" <<<"$CIKTI"; g $? "sebebi yazılı"
bash "$G" is-a --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "gerçek kapı aynı işte hâlâ rc=0 (mutasyon kaynağı bozdu, düzeneği değil)"

echo "════ T11 · CANLI sınıfı: cron/servis/sunucu kartı canlı kanıt olmadan GEÇMEZ; sarı canlı hiç geçmez ════"
# Retro 17 Eki ders 1: "git'te düzeltildi ≠ canlıda çalışıyor" — 119 işte en büyük bulgu kümesi. Kart cron/servis/sunucu
# içeriyorsa kapı yeşil ölçüm + 5/E ile YETİNMEZ: gerçek ateşleme kaydı (kanit.sh canli, yeşil) ister. Sarı canlı = ölçülmüş
# ama ateşleme yok → kart ne derse desin geçmez (sarı yeşil değildir).
bash "$KT" ac is-f --is "muhakkik-zil cron'u her saat çalsın" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$K" olcum is-f olc --asama tek -- echo 1 >/dev/null 2>&1; den is-f 1 5 E
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T11a 5+E + yeşil ölçüm ama canlı kanıt YOK → rc=1"
grep -q "canlı kanıt YOK" <<<"$CIKTI" && grep -q "kanit.sh canli" <<<"$CIKTI"; g $? "T11b sebebi ve yolu yazılı"
bash "$K" canli is-f zil --kaynak "x" -- bash -c 'echo "henüz log yok"' >/dev/null 2>&1
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T11c canlı SARI → rc=1 (sarı yeşil değildir)"
grep -q "canlı kanıt SARI" <<<"$CIKTI"; g $? "T11d sarı sebebi yazılı"
bash "$K" canli is-f zil --kaynak "cloudtop-code · journalctl" -- bash -c 'echo "2026-10-17T07:02:35 muhakkik-zil çaldı"' >/dev/null 2>&1
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "T11e canlı YEŞİL → rc=0"
grep -q "canlı: 1 ateşleme" <<<"$CIKTI" && grep -q "07:02:35" <<<"$CIKTI"; g $? "T11f kapı ilk ateşlemeyi saatiyle söylüyor"
kart is-g; bash "$K" olcum is-g olc --asama tek -- echo 1 >/dev/null 2>&1; den is-g 1 5 E
bash "$G" is-g --sessiz >/dev/null 2>&1; g $? "T11g canlısız kart (buton) canlı kaydı olmadan geçer (kapsam daralmadı)"
bash "$K" canli is-g c --kaynak x -- true >/dev/null 2>&1
bash "$G" is-g --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T11h ölçülmüş ama SARI canlı → canlısız kartta da rc=1"
# eski kart (canli_gerekir alanı yok) → alan yokken kelimeden türetilir: eski cron kartı da canlı ister (kapsam dışı kalmaz)
bash "$KT" ac is-h --is "kutu kapısı servisini 15 sunucuda yenile" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
python3 - <<PY
import json;p='$T/_agents/fabrika/kartlar/is-h.json';k=json.load(open(p));k.pop('canli_gerekir',None);k.pop('canli_sebep',None);json.dump(k,open(p,'w'))
PY
bash "$K" olcum is-h olc --asama tek -- echo 1 >/dev/null 2>&1; den is-h 1 5 E
CIKTI="$(bash "$G" is-h 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T11i alanı olmayan ESKİ servis/sunucu kartı: cümleden türetilir, canlı yok → rc=1"
grep -q "cümlede" <<<"$CIKTI"; g $? "T11j kapı canlı şartının nereden geldiğini söylüyor"
bash "$K" canli is-h kapi --kaynak "x" -- bash -c 'echo "2026-10-17 07:02:35 kapi 2.14.0 ayağa kalktı"' >/dev/null 2>&1
bash "$G" is-h --sessiz >/dev/null 2>&1; g $? "T11k eski kart + yeşil canlı → geçer"

echo "════ T12 · MUTASYON: canlı kontrolleri kaldırılınca kapı açılır (kapı gerçek, süs değil) ════"
M3="$PKG/mutant3.sh"; sed 's/^\s*\[ "\$cg" = "E" \] && \[ "\$cy" -eq 0 \]/false/' "$G" > "$M3"; chmod +x "$M3"
grep -q '^false' "$M3"; g $? "T12a mutant 3 üretildi (kart canlı şartı kaldırıldı)"
bash "$KT" ac is-i --is "boşta bekçisi cron'u" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$K" olcum is-i olc --asama tek -- echo 1 >/dev/null 2>&1; den is-i 1 5 E
bash "$M3" is-i --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T12b mutant 3: cron kartı canlı kayıtsız GEÇİYOR → T11a/T11i bu mutantta düşerdi"
bash "$G" is-i --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T12c gerçek kapı aynı işte hâlâ rc=1"
M4="$PKG/mutant4.sh"; sed 's/^\s*\[ "\$cs" -gt 0 \]/false/' "$G" > "$M4"; chmod +x "$M4"
grep -q '^false' "$M4"; g $? "T12d mutant 4 üretildi (sarı canlı engeli kaldırıldı)"
bash "$M4" is-g --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T12e mutant 4: sarı canlı GEÇİYOR → T11h bu mutantta düşerdi"
bash "$G" is-g --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T12f gerçek kapı sarıyı hâlâ tutuyor"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
