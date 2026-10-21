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
PKG="$T/pkg"; mkdir -p "$PKG"; cp "$HERE/kanit.py" "$HERE/kanit.sh" "$HERE/kart.sh" "$HERE/canli_borc.py" "$PKG/"   # kart.sh de kardeş: kapı canlı şartını ondan okur (yoksa ÖLÇÜLEMEDİ)
M="$PKG/mutant.sh"; sed 's/^  exit 1$/  exit 0/' "$G" > "$M"; chmod +x "$M"
bash "$M" bos --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "mutant (red kaldırıldı) izin veriyor → T1 bu mutantta düşerdi"
bash "$M" is-a --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "mutant sağlam işe de izin veriyor (ölçer sahte-kırmızı üretmiyor)"

echo "════ T10 · kanıt aracı yoksa YEŞİL DEMİYOR (rc=3) ════"
M2="$PKG/mutant2.sh"; sed 's|\$HERE/kanit.py|/yok/kanit.py|g' "$G" > "$M2"; chmod +x "$M2"
CIKTI="$(bash "$M2" is-a 2>&1)"; RC=$?
[ "$RC" -eq 3 ]; g $? "kanit.py yokken rc=3 (ölçülemedi, yeşil değil)"
grep -q "ÖLÇÜLEMEDİ" <<<"$CIKTI"; g $? "sebebi yazılı"
bash "$G" is-a --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "gerçek kapı aynı işte hâlâ rc=0 (mutasyon kaynağı bozdu, düzeneği değil)"

echo "════ T11 · CANLI sınıfı: cron/servis/sunucu kartı canlı kanıt olmadan GEÇMEZ; sarı canlı hiç geçmez; kayıt KARTA BAĞLI olmalı ════"
# Retro 17 Eki ders 1: "git'te düzeltildi ≠ canlıda çalışıyor". Kart cron/servis/sunucu içeriyorsa kapı yeşil ölçüm + 5/E ile
# YETİNMEZ: gerçek ateşleme kaydı (kanit.sh canli, yeşil) ister. Sarı canlı = ölçülmüş ama ateşleme yok → kart ne derse desin geçmez.
# Göz tur 1: "herhangi bir yeşil canlı" yetmez — kayıt bu işe BAĞLI olmalı: ölçüm de son ateşleme de kart açılışından SONRA.
LGK="$T/logk"; mkdir -p "$LGK"
printf 'henüz log yok\n' > "$LGK/yok.log"
bash "$KT" ac is-f --is "muhakkik-zil cron'u her saat çalsın" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$K" olcum is-f olc --asama tek -- echo 1 >/dev/null 2>&1; den is-f 1 5 E
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T11a 5+E + yeşil ölçüm ama canlı kanıt YOK → rc=1"
grep -q "canlı kanıt YOK" <<<"$CIKTI" && grep -q "kanit.sh canli" <<<"$CIKTI"; g $? "T11b sebebi ve yolu yazılı"
bash "$K" canli is-f zil --desen muhakkik-zil --kaynak "dosya:$LGK/yok.log" >/dev/null 2>&1
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T11c canlı SARI → rc=1 (sarı yeşil değildir)"
grep -q "canlı kanıt SARI" <<<"$CIKTI"; g $? "T11d sarı sebebi yazılı"
# eski/ilgisiz yeşil kayıt: ateşleme kart açılışından ÖNCE → bağlanamaz, saymaz
printf '%s muhakkik-zil çaldı (eski)\n' "$(date -u -d '-2 days' +%FT%TZ)" > "$LGK/eski.log"
bash "$K" canli is-f zil --desen muhakkik-zil --kaynak "dosya:$LGK/eski.log" >/dev/null 2>&1
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T11e2 yeşil ama ateşleme kart açılışından ÖNCE → işe bağlanamaz, rc=1"
grep -q "bağlanamadı" <<<"$CIKTI" && grep -q "kart açılışı" <<<"$CIKTI"; g $? "T11e3 sebebi yazılı: kayıt işe bağlanamadı (kart açılışından önce)"
sleep 1; printf '%s muhakkik-zil çaldı\n' "$(date -u +%FT%TZ)" > "$LGK/zil.log"
bash "$K" canli is-f zil --desen muhakkik-zil --kaynak "dosya:$LGK/zil.log" >/dev/null 2>&1
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "T11e canlı YEŞİL ve kart açılışından sonra → rc=0"
grep -q "canlı: 1 ateşleme kaydı" <<<"$CIKTI" && grep -q "komut:" <<<"$CIKTI" && grep -q "tail " <<<"$CIKTI"; g $? "T11f kapı ilk ateşlemeyi saatiyle ve okuyan komutla basıyor (göz görsün)"
# 🔴 göz tur 2: geleceğe tarihli ateşleme araçta sarıdır; manifest araç dışında kurgulansa bile kapı ÖLÇÜMDEN SONRAKİ ateşlemeyi reddeder (çift çit)
python3 - <<PY
import json,sys,datetime;sys.path.insert(0,'$HERE');import kanit
p='$T/_agents/fabrika/kanit/is-f/KANIT.json';m=json.load(open(p))
k=[x for x in m['kayitlar'] if x['etiket']=='zil'][-1];k['son_atesleme']['saat_iso']=(datetime.datetime.now().astimezone()+datetime.timedelta(hours=2)).isoformat(timespec='seconds')
m['imza']=kanit.imza(m['kayitlar']);json.dump(m,open(p,'w'))
PY
CIKTI="$(bash "$G" is-f 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T11o son ateşleme ölçümden 2 saat sonra (geleceğe tarihli) → bağlanmaz, rc=1"
grep -q "ÖLÇÜMDEN SONRA" <<<"$CIKTI"; g $? "T11o2 sebebi yazılı"
bash "$K" canli is-f zil --desen muhakkik-zil --kaynak "dosya:$LGK/zil.log" >/dev/null 2>&1
bash "$G" is-f --sessiz >/dev/null 2>&1; g $? "T11o3 araçla yeniden ölçülünce (gerçek saat) yine geçer"
kart is-g; bash "$K" olcum is-g olc --asama tek -- echo 1 >/dev/null 2>&1; den is-g 1 5 E
bash "$G" is-g --sessiz >/dev/null 2>&1; g $? "T11g canlısız kart (buton) canlı kaydı olmadan geçer (kapsam daralmadı)"
bash "$K" canli is-g c --desen x --kaynak "dosya:$LGK/yok.log" >/dev/null 2>&1
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
sleep 1; printf '%s kapi 2.14.0 ayağa kalktı\n' "$(date -u +%FT%TZ)" > "$LGK/kapi.log"
bash "$K" canli is-h kapi --desen kapi --kaynak "dosya:$LGK/kapi.log" >/dev/null 2>&1
bash "$G" is-h --sessiz >/dev/null 2>&1; g $? "T11k eski kart + bağlı yeşil canlı → geçer"

# 🔴 göz (daraltılmış tur): canli-gerekir düşerse kapı H varsayıp canlı şartını ATLIYORDU (fail-open) → ÖLÇÜLEMEDİ rc=3
bash "$KT" ac is-k --is "bekçi cron'u" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$K" olcum is-k olc --asama tek -- echo 1 >/dev/null 2>&1; den is-k 1 5 E
printf '{bozuk json' > "$T/_agents/fabrika/kartlar/is-k.json"
CIKTI="$(bash "$G" is-k 2>&1)"; RC=$?
[ "$RC" -eq 3 ]; g $? "T11p kart okunamıyor (canli-gerekir düşer) → rc=3 ÖLÇÜLEMEDİ, yeşil değil"
grep -q "canlı şartı OKUNAMADI" <<<"$CIKTI"; g $? "T11p2 sebebi yazılı"
# iki çit üst üste (canli-gerekir rc + kart zamanı): bozuk JSON ikisine de takılır → mutant ikisini de kaldırır
M7="$PKG/mutant7.sh"; sed -e 's/^    if \[ "\$cg_rc" -ne 0 \] || .*; then$/    if false; then/' -e 's/^\[ ! -f "\$KART" \] || \[ "\$ckz" = "1" \] || {/true || {/' "$G" > "$M7"; chmod +x "$M7"
grep -q '^    if false; then' "$M7" && grep -q '^true || {' "$M7"; g $? "T11p3 mutant 7 üretildi (fail-closed çitler: canli-gerekir rc + kart zamanı kaldırıldı)"
bash "$M7" is-k --sessiz >/dev/null 2>&1; [ $? -ne 3 ]; g $? "T11p4 mutant 7: bozuk kartta ölçülemedi DEMİYOR → T11p bu mutantta düşerdi"

# 🔴 göz #353 tur 1: geçerli JSON ama 'zaman' okunamaz → işe bağlama ölçülemez → rc=3 (rc=1 'eksik' değil)
bash "$KT" ac is-l --is "zil cron'u" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$K" olcum is-l olc --asama tek -- echo 1 >/dev/null 2>&1; den is-l 1 5 E
sleep 1; printf '%s zil çaldı\n' "$(date -u +%FT%TZ)" > "$LGK/zil-l.log"
bash "$K" canli is-l zil --desen zil --kaynak "dosya:$LGK/zil-l.log" >/dev/null 2>&1
bash "$G" is-l --sessiz >/dev/null 2>&1; g $? "T11q önce sağlam: bağlı yeşil canlı ile geçer"
python3 - <<PY
import json;p='$T/_agents/fabrika/kartlar/is-l.json';k=json.load(open(p));k['zaman']='bozuk-saat';json.dump(k,open(p,'w'))
PY
CIKTI="$(bash "$G" is-l 2>&1)"; RC=$?
[ "$RC" -eq 3 ]; g $? "T11q2 kart 'zaman' çözülemez → rc=3 ÖLÇÜLEMEDİ (rc=1 değil)"
grep -q "açılış zamanı" <<<"$CIKTI" && grep -q "ÖLÇÜLEMEDİ" <<<"$CIKTI"; g $? "T11q3 sebebi yazılı"
M8="$PKG/mutant8.sh"; sed 's/^\[ ! -f "\$KART" \] || \[ "\$ckz" = "1" \] || {/true || {/' "$G" > "$M8"; chmod +x "$M8"
grep -q '^true || {' "$M8"; g $? "T11q4 mutant 8 üretildi (zaman-okunamadı kapısı kaldırıldı)"
bash "$M8" is-l --sessiz >/dev/null 2>&1; [ $? -ne 3 ]; g $? "T11q5 mutant 8: ölçülemediğini söylemiyor → T11q2 bu mutantta düşerdi"

# 🔴 göz #353 tur 2: dilimsiz kart zamanı ↔ dilimli ateşleme → TypeError değil, karşılaştırma yerel dilimde yapılır; python düşerse rc=3
python3 - <<PY
import json;p='$T/_agents/fabrika/kartlar/is-l.json';k=json.load(open(p));k['zaman']='2020-01-01T00:00:00';json.dump(k,open(p,'w'))   # dilimsiz, eski tarih
PY
CIKTI="$(bash "$G" is-l 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "T11r dilimsiz kart zamanı: çökmez, yerel dilimde bağlanır → geçer"
M9="$PKG/mutant9.sh"; sed 's/return d.astimezone() if d.tzinfo is None else d/return d/' "$G" > "$M9"; chmod +x "$M9"
grep -q '^        return d$' "$M9"; g $? "T11r2 mutant 9 üretildi (dilim düzeltmesi kaldırıldı)"
CIKTI="$(bash "$M9" is-l 2>&1)"; RC=$?
[ "$RC" -eq 3 ]; g $? "T11r3 mutant 9: TypeError → python düşer → kapı ÖLÇÜLEMEDİ rc=3 der (rc=1 'canlı yok' DEĞİL)"
grep -q "DÜŞTÜ" <<<"$CIKTI"; g $? "T11r4 düşme sebebi yazılı"
M10="$PKG/mutant10.sh"; sed 's/^\[ "\$cpy_rc" -eq 0 \] || {/true || {/' "$G" > "$M10"; chmod +x "$M10"
sed -i 's/return d.astimezone() if d.tzinfo is None else d/return d/' "$M10"
bash "$M10" is-l --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T11r5 mutant 10 (rc denetimi de kaldırıldı): çöküş 'canlı yok' rc=1'e dönüşüyor → T11r3 bu mutantta düşerdi"

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
M5="$PKG/mutant5.sh"; sed 's/(bagli_l if neden is None else kopuk)/(bagli_l if True else kopuk)/' "$G" > "$M5"; chmod +x "$M5"
grep -q 'bagli_l if True else kopuk' "$M5"; g $? "T12g mutant 5 üretildi (işe bağlama kaldırıldı)"
bash "$K" canli is-i eski --desen muhakkik-zil --kaynak "dosya:$LGK/eski.log" >/dev/null 2>&1
bash "$M5" is-i --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T12h mutant 5: kart açılışından önceki yeşil kayıt GEÇİYOR → T11e2 bu mutantta düşerdi"
bash "$G" is-i --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T12i gerçek kapı eski kaydı bağlamıyor, rc=1"
M6="$PKG/mutant6.sh"; sed 's/datetime.timedelta(minutes=5)/datetime.timedelta(days=36500)/' "$G" > "$M6"; chmod +x "$M6"
grep -q 'days=36500' "$M6"; g $? "T12j mutant 6 üretildi (gelecek payı 100 yıl)"
python3 - <<PY
import json,sys,datetime;sys.path.insert(0,'$HERE');import kanit
p='$T/_agents/fabrika/kanit/is-i/KANIT.json';m=json.load(open(p))
k=[x for x in m['kayitlar'] if x['etiket']=='eski'][-1];k['son_atesleme']['saat_iso']=(datetime.datetime.now().astimezone()+datetime.timedelta(hours=2)).isoformat(timespec='seconds')
m['imza']=kanit.imza(m['kayitlar']);json.dump(m,open(p,'w'))
PY
bash "$M6" is-i --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T12k mutant 6: geleceğe tarihli kayıt GEÇİYOR → T11o bu mutantta düşerdi"
bash "$G" is-i --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T12l gerçek kapı geleceğe tarihli kaydı reddediyor"

echo "════ T13 · GEÇERSİZ ilan (4K938): geçersiz canlı yeşil sayılmaz, sarı gibi engeldir; ilan kapıyı gevşetmez ════"
bash "$KT" ac is-m --is "zil-m cron'u her saat çalsın" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$KT" ac is-n --is "buton rengi düzelsin" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
sleep 1; printf '%s zil-m çaldı\n' "$(date -u +%FT%TZ)" > "$LGK/zil-m.log"
for i in is-m is-n; do bash "$K" olcum $i olc --asama tek -- echo 1 >/dev/null 2>&1; den $i 1 5 E; bash "$K" canli $i zil --desen zil-m --kaynak "dosya:$LGK/zil-m.log" >/dev/null 2>&1; done
bash "$G" is-m --sessiz >/dev/null 2>&1; g $? "T13a önce: canlı kartı bağlı yeşil canlıyla geçer"
bash "$G" is-n --sessiz >/dev/null 2>&1; g $? "T13a2 önce: canlısız kart (yeşil canlı kaydıyla) geçer"
bash "$K" gecersiz is-m zil --neden "log satırı başka sunucunun zil kaydıydı" --kim M >/dev/null 2>&1
bash "$K" gecersiz is-n zil --neden "log satırı başka sunucunun zil kaydıydı" --kim M >/dev/null 2>&1
CIKTI="$(bash "$G" is-m 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "T13b geçersiz ilan edilen yeşil canlı SAYILMAZ → rc=1"
grep -q "SARI ya da GEÇERSİZ" <<<"$CIKTI" && grep -q "kanit.sh canli" <<<"$CIKTI"; g $? "T13c sebebi ve yolu yazılı (yeniden ölç)"
bash "$G" is-n --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T13d canlısız kartta da geçersiz canlı ENGEL (sarı gibi) → rc=1"
# mutantlar tam kopyada (kanit.py kardeş); kontrol kopyası değişmeden aynı sonucu vermeli — kopya erken düşüp tesadüfen geçirmesin
cp "$G" "$PKG/kontrol13.sh"; bash "$PKG/kontrol13.sh" is-n --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T13e kontrol kopyası (mutasyonsuz) gerçek kapıyla aynı: rc=1"
M9="$PKG/mutant9.sh"; sed 's/k\["etkin_renk"\] in ("sari","gecersiz")/k["etkin_renk"] in ("sari",)/' "$G" > "$M9"
grep -q 'in ("sari",)' "$M9"; g $? "T13f mutant 9 üretildi (geçersiz canlı engel listesinden çıktı)"
bash "$M9" is-n --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T13g mutant 9: geçersiz canlı canlısız kartı GEÇİRİYOR → T13d bu mutantta düşerdi"
M10="$PKG/mutant10.sh"; sed 's/y=\[k for k in c if k\["etkin_renk"\]=="yesil"\]/y=[k for k in c if k.get("renk")=="yesil"]/; s/k\["etkin_renk"\] in ("sari","gecersiz")/k.get("renk")=="sari"/' "$G" > "$M10"
grep -q 'k.get("renk")=="yesil"' "$M10"; g $? "T13h mutant 10 üretildi (kapı etkin renk yerine ham rengi okuyor)"
bash "$M10" is-m --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T13i mutant 10: geçersiz yeşil canlıyı SAYIYOR → T13b bu mutantta düşerdi"
sleep 1; printf '%s zil-m çaldı\n' "$(date -u +%FT%TZ)" > "$LGK/zil-m.log"
bash "$K" canli is-m zil --desen zil-m --kaynak "dosya:$LGK/zil-m.log" >/dev/null 2>&1
bash "$G" is-m --sessiz >/dev/null 2>&1; g $? "T13j yeniden ölçülünce ilan uygulanmaz (eski ölçüme aitti) → geçer"
bash "$PKG/kontrol13.sh" is-m --sessiz >/dev/null 2>&1; g $? "T13j2 kontrol kopyası geçen durumu da geçiriyor (kopyada içe aktarım düşmüyor)"
bash "$K" gecersiz is-m olc --neden "echo 1 iddiayı ölçmüyordu, vekil ölçüttü" --kim M >/dev/null 2>&1
CIKTI="$(bash "$G" is-m 2>&1)"; RC=$?
grep -q "⛔ GEÇERSİZ: olcum-olc-tek.txt" <<<"$CIKTI" && grep -q "vekil ölçüttü" <<<"$CIKTI"; g $? "T13k ölçüm ilanı kapı çıktısında görünür (sessiz kalmaz; hükmü göz verir)"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo "════ T13 · DARALTMA kaydı: eski cümleye verilmiş 5/E yeni cümleyi doğrulamaz (PCP7J) ════"
kart is-dar; bash "$K" olcum is-dar olc --asama tek -- echo 1 >/dev/null 2>&1
den is-dar 1 2 H; den is-dar 2 2 H; den is-dar 3 5 E
bash "$G" is-dar --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "daraltma yokken 3. tur 5/E → geçer (gerileme yok)"
( cd "$T" && bash "$KT" daralt is-dar --kalan "kalan yarı yeterince uzun bir cümle burada" --cumle "daraltılmış cümle yeterince uzun burada" --oturum ref-d >/dev/null 2>&1 ); g $? "kart daraltıldı (tur sıfırı 3)"
CIKTI="$(bash "$G" is-dar 2>&1)"; RC=$?
[ "$RC" -eq 1 ]; g $? "daraltma sonrası tur yokken son 5/E (tur 3 = sıfırdan önce) GEÇMEZ"
grep -q "daraltmadan ÖNCE" <<<"$CIKTI"; g $? "sebep yazılı: son denetim daraltmadan önce"
den is-dar 4 5 E
CIKTI="$(bash "$G" is-dar 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "daraltma SONRASI 5/E tur → geçer"
grep -q "kart daraltılmış (tur sıfırı 3" <<<"$CIKTI" && grep -q "karar: reis" <<<"$CIKTI"; g $? "kapı daraltma kaydını ve reis kararını BASTI (eskiden hiç okumuyordu)"
echo "════ T13b · MUTASYON: daraltma kontrolü kaldırılınca eski 5/E geçer (kapı gerçek) ════"
M13="$HERE/.mut13.tmp.sh"; python3 - "$G" "$M13" <<'PYM'
import sys; s=open(sys.argv[1]).read()
eski='yeni cümle denetlenmedi, birleştirme YOK"; eksik=$((eksik+1))'
assert eski in s, "mutasyon hedefi yok"
open(sys.argv[2],"w").write(s.replace(eski,'yeni cümle denetlenmedi"; :'))
PYM
grep -q 'yeni cümle denetlenmedi"; :' "$M13"; g $? "T13b mutant üretildi (daraltma çiti kaldırıldı)"
rm -f "$T/_agents/fabrika/kanit/is-dar/DENETIM-4.json"
bash "$M13" is-dar --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "mutant: daraltma çiti kalkınca eski 5/E GEÇİYOR → T13 bu mutantta düşerdi"
bash "$G" is-dar --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "gerçek kapı aynı durumda hâlâ reddediyor"
rm -f "$M13"

echo "════ T14 · KANIT TEK KURALLA: iş alanı · PR başı · birincil aynı sırayla; birincilden --pr ile çağrı iş alanındaki kanıtı bulur (retro W42 ders M3) ════"
# Gerçek düzen: çıplak origin · birincil klon (main) · iş alanı worktree (dal = iş adı) · PR başı origin'de refs/pull/<N>/head.
# Kart birincilde (kart tek kaynak), kanıt ve DENETİM iş alanında — 15 Eki compact-kurali vakasının birebir kurulumu.
R="$(mktemp -d)"; ( cd "$R" && git init -q --bare uzak.git && git clone -q uzak.git ana && cd ana && git config user.email t@t && git config user.name T \
  && echo x > f && git add f && git commit -qm "chore: ilk" && git push -q origin HEAD:main ) >/dev/null 2>&1
P="$R/ana"
alan() { # alan <dal> → iş alanı worktree (dal adı = kart adı; önekli olabilir)
  git -C "$P" worktree add -q -b "$1" "$R/alan-${1//\//-}" >/dev/null 2>&1; echo "$R/alan-${1//\//-}"; }
kanitla() { # kanitla <ağaç> <iş> <puan> <E/H> → ağaçta imzalı kanıt + DENETIM-1
  ( cd "$1" && KANIT_DEPO="$1" bash "$K" olcum "$2" olc --asama tek -- echo 1 >/dev/null 2>&1 )
  python3 - "$1/_agents/fabrika/kanit/$2/DENETIM-1.json" "$2" "$3" "$4" <<'PY'
import json,sys,datetime
p,is_,puan,dogru=sys.argv[1:]
json.dump({"tur":1,"is":is_,"pr":"7","yazan":"claude","denetci":"codex","zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
 "kanit_durumu":"sağlam","sonuc":{"kod_puani":int(puan),"dogru_sey":dogru,"ozet":"o","bulgular":[],"kanit_gorusu":"k"}},open(p,"w"))
PY
}
kartP() { ( cd "$P" && KANIT_DEPO="$P" bash "$KT" ac "$1" --is "örnek iş cümlesi burada" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h >/dev/null 2>&1 ); }
kapi() { ( cd "$1" && shift && env -u KANIT_DEPO bash "$G" "$@" 2>&1 ); }   # KANIT_DEPO yok: kapı birincili git'ten bulur (canlıdaki gibi)

kartP is-ck; A="$(alan is-ck)"; kanitla "$A" is-ck 5 E
CIKTI="$(kapi "$P" is-ck --pr 7)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "kanıt yeri: iş alanı ($A, dal iş adıyla aynı)" <<<"$CIKTI"; g $? "🔴 BİRİNCİLDEN çağrı iş alanındaki kanıtı buldu → GEÇTİ (15 Eki'de 'kanıt YOK' deyip kaçışa itmişti)"
CIKTI="$(kapi "$A" is-ck)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "kanıt yeri: çağrılan ağaç ($A" <<<"$CIKTI"; g $? "iş alanının içinden çağrı aynı kanıtı buldu (aynı kural, aynı sonuç)"
# iş alanı kapandı, kanıt PR'ın dalında: PR başından okunur
( cd "$A" && git add -A _agents && git commit -qm "docs: kanıt" && git push -q origin "HEAD:refs/pull/7/head" ) >/dev/null 2>&1
git -C "$P" worktree remove --force "$A" >/dev/null 2>&1
CIKTI="$(kapi "$P" is-ck --pr 7)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "kanıt yeri: PR #7 başı" <<<"$CIKTI"; g $? "iş alanı kapalıyken kanıt PR #7 başından okundu → GEÇTİ"
[ -z "$(git -C "$P" status --porcelain -uall | grep -v '^?? _agents/fabrika/kartlar/')" ] && [ ! -e "$P/_agents/fabrika/kanit/is-ck" ]; g $? "PR başı okuması birincil ağaca DOKUNMADI (kanıt geçici yere çıkarıldı)"
CIKTI="$(kapi "$P" is-ck)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "kanıt yeri: hiçbir yerde (arandı: dalı 'is-ck' olan ağaçlar · birincil depo)" <<<"$CIKTI"; g $? "--pr verilmezse PR başına bakılmaz; aranan yerler sayılır, kapı kapalı (rc=1)"
# bayat kopya: birincilde eski 5/E kopyası var, iş alanında güncel 3/E → iş alanı esas, kapı GEÇMEZ
kartP is-bayat; B="$(alan is-bayat)"; kanitla "$B" is-bayat 3 E
mkdir -p "$P/_agents/fabrika/kanit"; cp -r "$B/_agents/fabrika/kanit/is-bayat" "$P/_agents/fabrika/kanit/"
python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));d['sonuc']['kod_puani']=5;json.dump(d,open(p,'w'))" "$P/_agents/fabrika/kanit/is-bayat/DENETIM-1.json"
CIKTI="$(kapi "$P" is-bayat --pr 8)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "kanıt yeri: iş alanı ($B" <<<"$CIKTI"; g $? "🔴 birincildeki BAYAT 5/E kopyası kapıyı açmaz — dalı iş adıyla aynı olan iş alanı esas (3/E → rc=1)"
# önekli dal (hendese/<iş>): önek atılır
kartP is-onek; C="$(alan hendese/is-onek)"; kanitla "$C" is-onek 5 E
CIKTI="$(kapi "$P" is-onek)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "kanıt yeri: iş alanı ($C" <<<"$CIKTI"; g $? "önekli dal (hendese/is-onek) iş adıyla eşleşir"

echo "════ T14b · KAÇIŞ DEFTERİ FİKSTÜRÜ: W42'nin 9 kapısız birleştirmesi — yalnız 'kanıt başka yerde' sınıfı kapıdan geçer, gerisi KAPALI kalır ════"
# Satırlar Nexus _agents/fabrika/kacis-defteri.log'dan BİREBİR (gerekçe alanı). Sınıf: kanit-yeri = kanıt vardı ama kapı başka yerde aradı ·
# tavan = Sultan onaylı tavan/daraltma, son puan 5/E değil · kanitsiz = kanıt kaydı yoktu. Yalnız kanit-yeri bu işle kapanır;
# öteki sınıflarda kaçış Sultan kararıdır ve kapı GEVŞEMEZ. 09:45 satırı puan yazmıyor; 'daralt' = tıkanmış iş, 5/E değil → 4/E ile canlandırılır.
KACIS="$(cat <<'LOG'
2026-10-12T13:47:10Z | KAPISIZ | Sultan kararı 12 Eki 'Birleştir, zamanlayıcı sonra (önerim)' (D1 kartta) · bağımsız göz 4 tur son 3/5·E, tek kalan bulgu K4 canlı cron kurulumu yapısal olarak birleşmeden sonra · CI 5/5 yeşil
2026-10-12T16:02:47Z | KAPISIZ | yalnız ölçüm kaydı (_agents/ belgeler); kod yok; tek-kapi işinin 4 tur Codex denetimi #1115'te; CI yeşil, CLEAN
2026-10-12T16:09:07Z | KAPISIZ | tek dosya küçük değişiklik, sınav 54/54 + CI yeşil CLEAN; sınıfsız; reis SERDAR
2026-10-15T09:45:30Z | KAPISIZ | Sultan sohbette 'tamamdir onay verdim devam' dedi (15 Eki); kart enis-kasa-f1 daralt: canli kurye teslimi host yolu, arac+sinav 14 kapi, CI yesil
2026-10-15T09:48:12Z | KAPISIZ | Sultan sohbette 'olur birlestir' (15 Eki); kart filo-havuz-toplayici daralt: 4 tur 4/E, 12 kapi, CI yesil; havuz dosyasi depo disi
2026-10-15T09:48:17Z | KAPISIZ | Sultan sohbette 'olur birlestir' (15 Eki); kart posta-sevk daralt (BANI): tur 4 4/H tek bulgu okundu gorunurlugu ayri kartta (#1138), CI yesil
2026-10-15T10:42:55Z | KAPISIZ | Sultan 'olur birlestir' (15 Eki, yetki sınıfı); compact-kurali kanıt+DENETIM-1..3 iş alanında/PR'da, kapı birincil depoda aradığı için göremedi
2026-10-15T14:34:31Z | KAPISIZ | Sultan onayı 15 Eki (sohbet session_01Ge4BawKcUrcm1pdV8WANyF 'karar ikisini de birleştir'): tur 4 4/E, tek bulgu (hâl defteri eşzamanlılık) denetimden sonra 6500e1d7 ile düzeltildi, CI yeşil; kapsam reis kararıyla dara
2026-10-15T18:50:33Z | KAPISIZ | Sultan onayı 15 Eki (sohbet session_01Ge4BawKcUrcm1pdV8WANyF 'önerin kabul edildi'): yetki sınıfı, tur 3 Codex 4/E tavan, tek bulgu uçtan uca Doğrulat zinciri (düğme panelde ayrı PR); CI 14/14 yeşil
LOG
)"
declare -A SINIF=([2026-10-12T13:47:10Z]=tavan:3:E [2026-10-12T16:02:47Z]=kanitsiz [2026-10-12T16:09:07Z]=kanitsiz [2026-10-15T09:45:30Z]=tavan:4:E
  [2026-10-15T09:48:12Z]=tavan:4:E [2026-10-15T09:48:17Z]=tavan:4:H [2026-10-15T10:42:55Z]=kanit-yeri:5:E [2026-10-15T14:34:31Z]=tavan:4:E [2026-10-15T18:50:33Z]=tavan:4:E)
[ "$(grep -c . <<<"$KACIS")" = 9 ] && [ "${#SINIF[@]}" = 9 ]; g $? "fikstür: 9 satır, 9 sınıf"
gecen_sinif=""; n=0; hepsi=0
while IFS=' |' read -r ts _; do
  [ -n "$ts" ] || continue; n=$((n+1)); s="${SINIF[$ts]:-}"; [ -n "$s" ] || { hepsi=1; continue; }
  is_="is-kacis-$n"; kartP "$is_"; D_="$(alan "$is_")"
  IFS=: read -r tur puan dogru <<<"$s"
  [ "$tur" = kanitsiz ] || kanitla "$D_" "$is_" "$puan" "$dogru"
  kapi "$P" "$is_" --pr "9$n" >/dev/null; rc=$?
  [ "$rc" -eq 0 ] && gecen_sinif="$gecen_sinif $tur"
  [ "$tur" = kanit-yeri ] && [ "$rc" -ne 0 ] && hepsi=1
  [ "$tur" != kanit-yeri ] && [ "$rc" -eq 0 ] && hepsi=1
done <<<"$KACIS"
[ "$hepsi" = 0 ] && [ "$gecen_sinif" = " kanit-yeri" ]; g $? "🔴 9 kaçışın yalnız 'kanıt başka yerde' olanı (15 Eki 10:42) artık kapıdan geçer; 8'i (tavan · kanıtsız) KAPALI kalır — kapı gevşemedi (geçen:$gecen_sinif)"

echo "════ T14 · CANLI BORÇ (5WYQMW): dağıtım birleşmeden SONRA ise kapı kayıtlı borçla geçer; kart BİTMEZ; ödenmezse kırmızı ════"
# (T13 daraltma bölümü $T'yi sildi → mutantlar için kardeş dosyalar yeniden konur)
mkdir -p "$T" "$PKG"; cp "$HERE/kanit.py" "$HERE/kanit.sh" "$HERE/kart.sh" "$HERE/canli_borc.py" "$PKG/"
# Kural: borç kapıyı gevşetmez, görünür kılar. Sınıfsız kartta yazan sahip; SINIFLI kartta Sultan kararı (sultan-dedi) ŞART (A06).
borckart() { bash "$KT" ac "$1" --is "boşta bekçisi cron'u $1" --istedi S --aldi M --geri-alinamaz "${2:-h}" --para h --dis-yuzey h --yetki h --canli e >/dev/null 2>&1; bash "$K" olcum "$1" olc --asama tek -- echo 1 >/dev/null 2>&1; den "$1" 1 5 E; }
kj() { python3 -c "import json,sys;k=json.load(open('$T/_agents/fabrika/kartlar/$1.json'));print(eval(sys.argv[1]))" "$2"; }
GR="kutuda dağıtım birleşmeden sonra Sultan elinde; cron ancak sabah paketiyle canlıya iner"
borckart is-b1
bash "$G" is-b1 --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T14a borçsuz canlı-gerekli kart canlı kayıt YOKKEN rc=1 (borç yokken kapı AYNEN kapalı)"
bash "$KT" canli-borc is-b1 --yazan X --gerekce "$GR" >/dev/null 2>&1; [ $? -ne 0 ] && [ "$(kj is-b1 "k.get('canli_borc')")" = "None" ]; g $? "T14b borcu kartın sahibi OLMAYAN yazamaz (aldi M ≠ X) ve kayıt YAZILMAZ"
bash "$KT" canli-borc is-b1 --yazan M --gerekce "sonra bakarız" >/dev/null 2>&1; [ $? -ne 0 ] && [ "$(kj is-b1 "k.get('canli_borc')")" = "None" ]; g $? "T14c 20 karakterden kısa gerekçe reddedilir ve kayıt YAZILMAZ"
bash "$KT" canli-borc is-b1 --yazan M --gerekce "$GR" >/dev/null 2>&1; g $? "T14d sınıfsız kartta sahibi (M) geçerli gerekçeyle borç yazar"
bash "$KT" canli-borc is-b1 --yazan M --gerekce "$GR" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "T14e ikinci borç yazılmaz"
CIKTI="$(bash "$G" is-b1 2>&1)"; RC=$?
[ "$RC" -eq 0 ]; g $? "T14f 5+E + kayıtlı geçerli borç → kapı GEÇER (rc=0)"
grep -q "CANLI BORÇ" <<<"$CIKTI" && grep -q "kart BİTMEZ" <<<"$CIKTI"; g $? "T14g kapı borcu YÜKSEK SESLE basar (sessiz geçmez)"
CIKTI="$(bash "$KT" bitti is-b1 --pr 91 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && [ "$(kj is-b1 "k['durum']")" = "canli-borclu" ] && [ "$(kj is-b1 "k['bitis']")" = "None" ]; g $? "T14h kart.sh bitti → durum 'canli-borclu' (bitti DEĞİL), bitiş yok"
grep -q "CANLI BORÇLU" <<<"$CIKTI"; g $? "T14i çıktı borçlu olduğunu ve ödeme yolunu söyler"
bash "$KT" borclar >/dev/null 2>&1; g $? "T14j taze borç: kart.sh borclar rc=0 (süresinde)"
bash "$KT" bitti is-b1 --pr 91 --gorev-bitti --olcum "sonra=1" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "T14k borçlu kartta --gorev-bitti reddedilir (görev canlı kayıt ödenmeden bitmez)"
# 24 saat: borç zamanını 30 saat geriye al → borclar kırmızı
python3 - "$T/_agents/fabrika/kartlar/is-b1.json" <<'PY'
import json,sys,datetime
p=sys.argv[1]; k=json.load(open(p)); k["canli_borc"]["zaman"]=(datetime.datetime.now().astimezone()-datetime.timedelta(hours=30)).isoformat(timespec="seconds"); json.dump(k,open(p,"w"))
PY
CIKTI="$(bash "$KT" borclar 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "SÜRE AŞILDI" <<<"$CIKTI"; g $? "T14l 24 saati aşan borç → borclar rc=1 + SÜRE AŞILDI (bekçi/nabız bunu okur)"
# ödeme: borçtan SONRA alınan bağlı yeşil canlı kayıt
mkdir -p "$LGK"; sleep 1; printf '%s boşta-bekcisi çaldı\n' "$(date -u +%FT%TZ)" > "$LGK/b1.log"
bash "$K" canli is-b1 bb --desen boşta-bekcisi --kaynak "dosya:$LGK/b1.log" >/dev/null 2>&1
# kanıt, çağrılan ağaçtan okunur (bitti ile aynı kural): ağaç = sahte depo
IFS=$'\t' read -r BD _ <<<"$(cd "$T" && bash "$KT" canli-borc-durum is-b1 2>&1)"
[ "$BD" = odendi ]; g $? "T14m borçtan sonra bağlı yeşil canlı kayıt → durum 'odendi'"
(cd "$T" && bash "$KT" bitti is-b1 --pr 91 >/dev/null 2>&1); [ "$(kj is-b1 "k['durum']")" = "bitti" ] && [ "$(kj is-b1 "k['canli_borc']['odendi'] is not None")" = "True" ]; g $? "T14n ödenen borçta kart.sh bitti → 'bitti' ve ödeme anı kartta"
bash "$KT" borclar >/dev/null 2>&1; g $? "T14o ödenen borç artık listede yok (rc=0)"
# geçersiz borç: kartın sahibi sonradan değişmiş/elle bozulmuş → kapı GEÇİRMEZ, bitti kapanmaz
borckart is-b2; bash "$KT" canli-borc is-b2 --yazan M --gerekce "$GR" >/dev/null 2>&1
python3 - "$T/_agents/fabrika/kartlar/is-b2.json" <<'PY'
import json,sys
p=sys.argv[1]; k=json.load(open(p)); k["canli_borc"]["yazan"]="BASKA"; json.dump(k,open(p,"w"))
PY
CIKTI="$(bash "$G" is-b2 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "canlı borç GEÇERSİZ" <<<"$CIKTI"; g $? "T14p elle bozulmuş borç (yazan ≠ sahip) → kapı rc=1 ve sebep yazılı"
bash "$KT" bitti is-b2 --pr 92 >/dev/null 2>&1; [ $? -ne 0 ] && [ "$(kj is-b2 "k['durum']")" = "acik" ]; g $? "T14q geçersiz borçla kart.sh bitti reddedilir ve kart AÇIK kalır"
# sarı canlı + borç: ölçülmüş ama ateşleme yok = tam da borç durumu → geçer
borckart is-b3; bash "$K" canli is-b3 yok --desen boşta-bekcisi --kaynak "dosya:$LGK/yok.log" >/dev/null 2>&1
bash "$G" is-b3 --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T14r sarı canlı, borç YOK → rc=1 (T11c ile aynı)"
bash "$KT" canli-borc is-b3 --yazan M --gerekce "$GR" >/dev/null 2>&1
bash "$G" is-b3 --sessiz >/dev/null 2>&1; g $? "T14s sarı canlı + geçerli borç → rc=0"
# SINIFLI kart: ajan Sultan adına borç yazamaz (A06)
borckart is-b4 e
bash "$KT" canli-borc is-b4 --yazan M --gerekce "$GR" >/dev/null 2>&1; [ $? -ne 0 ] && [ "$(kj is-b4 "k.get('canli_borc')")" = "None" ]; g $? "T14t SINIFLI kartta Sultan kararı olmadan borç YAZILAMAZ (A06)"
CIKTI="$(bash "$KT" canli-borc is-b4 --yazan M --gerekce "$GR" 2>&1)"; grep -q "SINIFLI" <<<"$CIKTI" && grep -q "sultan-dedi" <<<"$CIKTI"; g $? "T14u sebep ve yol (sultan-dedi --karar canli-borc) söylenir"
bash "$KT" sultan-dedi is-b4 --karar canli-borc --oturum "sohbet-0043" --soz "canlı borç onay" --beyan M --gerekce "dağıtım Sultan elinde, kapı kilitleniyor" >/dev/null 2>&1
bash "$KT" canli-borc is-b4 --yazan M --gerekce "$GR" >/dev/null 2>&1; g $? "T14v sultan-dedi canli-borc işlendikten SONRA sınıflı kartta borç yazılır"
bash "$G" is-b4 --sessiz >/dev/null 2>&1; g $? "T14w sınıflı kart + Sultan kararlı borç → kapı geçer"
# göz tur 1: Sultan kararının zamanı bozuk/eksik ya da borçtan SONRA ise karar geçerli SAYILMAZ (fail-closed)
borckart is-b6 e; bash "$KT" sultan-dedi is-b6 --karar canli-borc --oturum "sohbet-0043" --soz "canlı borç onay" --beyan M --gerekce "dağıtım Sultan elinde, kapı kilitleniyor" >/dev/null 2>&1
python3 - "$T/_agents/fabrika/kartlar/is-b6.json" <<'PY'
import json,sys
p=sys.argv[1]; k=json.load(open(p)); k["sultan_kararlari"][0]["zaman"]="bozuk-zaman"; json.dump(k,open(p,"w"))
PY
bash "$KT" canli-borc is-b6 --yazan M --gerekce "$GR" >/dev/null 2>&1; [ $? -ne 0 ] && [ "$(kj is-b6 "k.get('canli_borc')")" = "None" ]; g $? "T14zb sınıflı kartta Sultan kararının zamanı BOZUK → karar sayılmaz, borç yazılmaz (fail-closed)"
python3 - "$T/_agents/fabrika/kartlar/is-b6.json" <<'PY'
import json,sys
p=sys.argv[1]; k=json.load(open(p)); k["sultan_kararlari"][0].pop("zaman"); json.dump(k,open(p,"w"))
PY
bash "$KT" canli-borc is-b6 --yazan M --gerekce "$GR" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "T14zc kararın zamanı EKSİK → karar sayılmaz"
python3 - "$T/_agents/fabrika/kartlar/is-b6.json" <<'PY'
import json,sys,datetime
p=sys.argv[1]; k=json.load(open(p)); k["sultan_kararlari"][0]["zaman"]=(datetime.datetime.now().astimezone()+datetime.timedelta(hours=1)).isoformat(timespec="seconds"); json.dump(k,open(p,"w"))
PY
bash "$KT" canli-borc is-b6 --yazan M --gerekce "$GR" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "T14zd karar borçtan SONRAYA tarihli → sayılmaz (sıra: önce Sultan, sonra borç)"
# MUTASYON: borç kapıyı gerçekten belirliyor (süs değil)
MB1="$PKG/mutant-borc1.sh"; sed 's/gecerli) borc_gecer=1 ;;/gecerli) borc_gecer=0 ;;/' "$G" > "$MB1"; chmod +x "$MB1"
grep -q 'gecerli) borc_gecer=0' "$MB1"; g $? "T14x mutant üretildi (geçerli borç artık geçirmiyor)"
bash "$MB1" is-b3 --sessiz >/dev/null 2>&1; [ $? -eq 1 ]; g $? "T14y mutant: borç geçirmiyor → T14f/T14s bu mutantta düşerdi"
MB2="$PKG/mutant-borc2.sh"; sed 's/gecerli) borc_gecer=1 ;;/gecerli|gecersiz|yok) borc_gecer=1 ;;/' "$G" > "$MB2"; chmod +x "$MB2"
bash "$MB2" is-b2 --sessiz >/dev/null 2>&1; [ $? -eq 0 ]; g $? "T14z mutant 2: geçersiz borç da geçiriyor → T14p bu mutantta düşerdi"
cp "$PKG/canli_borc.py" "$PKG/canli_borc.py.asil"; sed -i 's/and zaman(sk.get("zaman")) is not None and zaman(sk.get("zaman")) <= bz/and (zaman(sk.get("zaman")) or bz) <= bz/' "$PKG/canli_borc.py"
borckart is-b7 e; bash "$PKG/kart.sh" sultan-dedi is-b7 --karar canli-borc --oturum "sohbet-0043" --soz "canlı borç onay" --beyan M --gerekce "dağıtım Sultan elinde, kapı kilitleniyor" >/dev/null 2>&1
python3 - "$T/_agents/fabrika/kartlar/is-b7.json" <<'PY'
import json,sys
p=sys.argv[1]; k=json.load(open(p)); k["sultan_kararlari"][0]["zaman"]="bozuk-zaman"; json.dump(k,open(p,"w"))
PY
bash "$PKG/kart.sh" canli-borc is-b7 --yazan M --gerekce "$GR" >/dev/null 2>&1; MR2=$?
cp "$PKG/canli_borc.py.asil" "$PKG/canli_borc.py"
[ "$MR2" -eq 0 ]; g $? "T14ze mutant 4: eski fail-open (bozuk zaman = borç anı) geri gelince bozuk kararlı borç yazılıyor → T14zb bu mutantta düşerdi"
cp "$PKG/canli_borc.py" "$PKG/canli_borc.py.asil"; sed -i 's/        if not ok:/        if False:/' "$PKG/canli_borc.py"
borckart is-b5 e; bash "$PKG/kart.sh" canli-borc is-b5 --yazan M --gerekce "$GR" >/dev/null 2>&1; MR=$?
cp "$PKG/canli_borc.py.asil" "$PKG/canli_borc.py"
[ "$MR" -eq 0 ]; g $? "T14za mutant 3: sınıflı Sultan-kararı denetimi kalkınca ajan borç yazabiliyor → T14t bu mutantta düşerdi"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
