#!/usr/bin/env bash
# profil-dogrula.test.sh — hermetik. Ağırlık merkezi: doğrulayıcı AYIRT EDİYOR mu?
# Altın fikstür GEÇMELİ, her kırmızı fikstür DÜŞMELİ. Tek yönlü sınav yalnız katılaşmayı
# yakalar, GEVŞEMEYİ yakalamaz — bu yüzden ikisi birden var.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT:-$HERE/profil-dogrula.py}"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"
# 🔴 `kos ... | grep -q` KULLANMA: `set -o pipefail` açık, doğrulayıcı ihlalde rc=1 döner
#    ve boru o 1'i yutmaz — grep EŞLEŞSE BİLE kapı kırmızı görünür. İlk yazımda dört kapı
#    bu yüzden düştü; mesajlar DOĞRUYDU, ölçen ben yanlıştım. Çıktı önce değişkene alınır.
kos() { python3 "$D" "$1" 2>&1 || true; }
icerir() { case "$2" in (*"$1"*) return 0 ;; (*) return 1 ;; esac; }
rc_of() { python3 "$D" "$1" >/dev/null 2>&1; echo $?; }

# ── ALTIN: geçerli profil (asgari ama TAM) ────────────────────────────────────
cat > "$T/altin.json" <<'J'
{"sema":1,"profil":"devriye","kutu":"sinav","etiket":"· 🛡 DEVRİYE açık · /devriye-kapat",
 "bayrak":"/config/.sinav/devriye-modu",
 "yollar":{"repo_kok":"/r","kosu_kok":"/k","kanit_kok":"/n","defter_kok":"/d","hub":"/h"},
 "hat":{"canli":"ornek.test","defter_port":8790},
 "nobetler":[{"ad":"derin","ne_zaman":"03:00","komut":"tur.sh derin","kapi":"kapi.sh",
              "kirmizi_ne_demek":"tarama düştü","zorunlu":true}],
 "kapilar":[{"ad":"hizli","komut":"hizli.sh","kirmizi_ne_demek":"yüzey bozuk"}],
 "defter_semasi":{"alanlar":[{"ad":"kim","tur":"metin","zorunlu":true}]},
 "karne_alanlari":["gecen"],
 "kurulum_sinavi":[{"adim":"kur","beklenen":"8 nöbet"}],
 "damga_olcutu":"kanıt + puan"}
J
echo "════ P1 · ALTIN profil GEÇER (gevşeme değil, doğru kabul) ════"
[ "$(rc_of "$T/altin.json")" = 0 ]; g $? "P1a geçerli profil rc=0"
O="$(kos "$T/altin.json")"
icerir 'şema-1 geçerli' "$O"; g $? "P1b ne kabul ettiğini söylüyor"

_boz() { python3 - "$T/altin.json" "$T/k.json" "$1" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8")); exec(sys.argv[3])
json.dump(d,open(sys.argv[2],"w",encoding="utf-8"),ensure_ascii=False)
PY
}

echo "════ P2 · BİLİNMEYEN alan RED (sessizce atlanmaz) ════"
_boz 'd["uydurma_alan"]="x"'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P2a üst düzeyde bilinmeyen alan rc=1"
O="$(kos "$T/k.json")"
icerir 'BİLİNMEYEN üst alan' "$O"; g $? "P2b adıyla söyleniyor"
_boz 'd["nobetler"][0]["env"]={"A":"1"}'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P2c nöbet içinde bilinmeyen alan da rc=1"

echo "════ P3 · ZORUNLU alan BOŞ → kurulum üretilmez ════"
_boz 'd["yollar"]["hub"]=""'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P3a boş yol rc=1"
O="$(kos "$T/k.json")"
icerir 'zorunlu alan BOŞ: hub' "$O"; g $? "P3b hangi alan olduğu yazılı"
_boz 'd["nobetler"][0]["komut"]=""'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P3c boş nöbet komutu rc=1 (yeşil görünüp iş yapmayan nöbet)"
_boz 'del d["damga_olcutu"]'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P3d eksik zorunlu üst alan rc=1"

echo "════ P4 · KAPISIZ nöbet RED (üçüncü kural) ════"
_boz 'd["nobetler"][0]["kapi"]=""'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P4a kapısız nöbet rc=1"
O="$(kos "$T/k.json")"
icerir 'KAPISIZ' "$O"; g $? "P4b sebebi 'kapısız' diye söyleniyor"
O="$(kos "$T/k.json")"
icerir 'gürültüdür' "$O"; g $? "P4c niçini yazılı"
_boz 'del d["nobetler"][0]["kirmizi_ne_demek"]'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P4d 'kırmızı ne demek' eksikse de rc=1"

echo "════ P5 · yapısal bozukluklar ════"
_boz 'd["nobetler"]=[]'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P5a nöbetsiz profil rc=1"
_boz 'd["kapilar"]=[]'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P5b kapısız profil rc=1"
_boz 'd["sema"]=2'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P5c başka şema sürümü rc=1"
_boz 'd["nobetler"].append(dict(d["nobetler"][0]))'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P5d AYNI ADLI iki nöbet rc=1 (hangisi düştü ayırt edilemez)"
_boz 'd["nobetler"][0]["zorunlu"]="evet"'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P5e 'zorunlu' metin verilirse rc=1 (evet/hayır olmalı)"
_boz 'd["defter_semasi"]["alanlar"]=[]'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P5f alansız defter şeması rc=1"

echo "════ P6 · okuma hataları 'ihlal' DEĞİL, ayrı sınıf (rc=2) ════"
printf '{bozuk json' > "$T/bozuk.json"
[ "$(rc_of "$T/bozuk.json")" = 2 ]; g $? "P6a ayrıştırılamayan dosya rc=2"
[ "$(rc_of "$T/yok.json")" = 2 ]; g $? "P6b olmayan dosya rc=2"
python3 "$D" >/dev/null 2>&1; [ $? -eq 2 ]; g $? "P6c argümansız çağrı rc=2"

echo "════ P7 · İSTEĞE BAĞLI alanlar geçerliliği bozmaz ════"
_boz 'd["surum"]="1.0"; d["nobetler"][0]["aciklama"]="not"'
[ "$(rc_of "$T/k.json")" = 0 ]; g $? "P7 bilinen isteğe-bağlı alanlar rc=0"

echo "════ P8 · GERÇEK profil (MÜTEVELLİ/akar) — varsa ölçülür ════"
GP=/config/projects/Nexus/_agents/handoff/gelen-akar/devriye-profil.sema1.json
if [ -f "$GP" ]; then
  [ "$(rc_of "$GP")" = 0 ]; g $? "P8 canlı profil şema-1'e UYUYOR (iddia ölçüldü)"
else
  echo "  ATLANDI: canlı profil bu ağaçta yok (yeşil DEĞİL)"
fi

echo "════ P10 · YALNIZCA-BOŞLUK da BOŞTUR (göz tur-1; sınavımda belgelenmişti) ════"
_boz 'd["yollar"]["hub"]="   "'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P10a boşluklardan ibaret yol rc=1"
_boz 'd["nobetler"][0]["kapi"]=" "'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P10b boşluk-kapı da KAPISIZ sayılıyor"
O="$(kos "$T/k.json")"; icerir 'KAPISIZ' "$O"; g $? "P10c sebebi kapısız diye söyleniyor"

echo "════ P11 · BİLİNMEYEN alan kuralı HER KATTA (göz tur-1) ════"
_boz 'd["defter_semasi"]["uydurma"]="x"'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P11a defter şemasının KENDİ anahtarında bilinmeyen alan rc=1"
_boz 'd["defter_semasi"]["alanlar"][0]["uydurma"]="x"'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P11b alan nesnesinde bilinmeyen alan rc=1"
_boz 'd["kapilar"][0]["uydurma"]="x"'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P11c kapı nesnesinde bilinmeyen alan rc=1"

echo "════ P12 · YANLIŞ TÜR sessizce geçmez (göz tur-1: eksik else) ════"
_boz 'd["kurulum_sinavi"]="liste degil"'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P12a kurulum_sinavi liste değilse rc=1"
_boz 'd["karne_alanlari"]={"a":1}'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P12b karne_alanlari liste değilse rc=1"
_boz 'd["etiket"]=5'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P12c metin olması gereken alan sayıysa rc=1"
_boz 'd["defter_semasi"]="nesne degil"'
[ "$(rc_of "$T/k.json")" = 1 ]; g $? "P12d defter_semasi nesne değilse rc=1"

echo "════ P13 · KAPI BAĞI: adlı güçlü, serbest tarif UYARI (RED değil) ════"
# 🔴 Niçin RED değil: şemada `kapi` alanının `kapilar`dan bir AD olması gerektiği YAZILMAMIŞTI.
#    Teslimden sonra sözleşmeyi sıkılaştırıp karşı tarafın işini reddetmek, kuralı sonradan
#    koyup geçmişi suçlamak olurdu — bedelini bugün imza-sürüm işinde ölçtük.
_boz 'd["nobetler"][0]["kapi"]="hizli"'      # kapilar[0].ad == "hizli"
O="$(kos "$T/k.json")"
[ "$(rc_of "$T/k.json")" = 0 ]; g $? "P13a ADLI kapıya bağlı nöbet rc=0"
icerir 'SERBEST TARİF' "$O"; [ $? -ne 0 ]; g $? "P13b adlı bağda uyarı YOK"
_boz 'd["nobetler"][0]["kapi"]="boyle-bir-kapi-yok"'
O="$(kos "$T/k.json")"
[ "$(rc_of "$T/k.json")" = 0 ]; g $? "P13c serbest tarif GEÇERLİ (rc=0) — sözleşme sonradan sıkılmaz"
icerir 'SERBEST TARİF' "$O"; g $? "P13d ama SUSULMUYOR — zayıf bağ olduğu söyleniyor"
icerir 'zayıf bağ' "$O"; g $? "P13e niçin zayıf olduğu yazılı"
_boz 'd["nobetler"][0]["kapi"]="hizli"'

echo "════ P9 · MUTASYON: kapısız-nöbet kuralı koparılınca P4 kırmızıya döner ════"
M="$T/mutant.py"
sed 's@^                if _bos(n.get("kapi")):@                if False:@' "$D" > "$M"
if cmp -s "$M" "$D"; then g 1 "P9a mutant FARKSIZ (çapa bayat)"; else
  _boz 'd["nobetler"][0]["kapi"]=""; d["nobetler"][0]["kirmizi_ne_demek"]="x"'
  python3 - "$T/k.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p,encoding="utf-8"))
d["nobetler"][0]["kapi"]="dolu"   # zorunlu-bos kapisini gecsin ki YALNIZ 3. kural olculsun
json.dump(d,open(p,"w",encoding="utf-8"),ensure_ascii=False)
PY
  python3 - "$T/k.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p,encoding="utf-8"))
d["nobetler"][0]["kapi"]=" "      # bos DEGIL ama anlamsiz: _bos gormez, bu kasitli
json.dump(d,open(p,"w",encoding="utf-8"),ensure_ascii=False)
PY
  # asil mutasyon olcumu: kapi GERCEKTEN bos
  _boz 'd["nobetler"][0]["kapi"]=""'
  MUT_RC=$(MUTANT="$M" python3 "$M" "$T/k.json" >/dev/null 2>&1; echo $?)
  ASIL_RC=$(rc_of "$T/k.json")
  [ "$ASIL_RC" = 1 ]; g $? "P9a asıl araç kapısız nöbeti REDDEDİYOR"
  # mutantta 'zorunlu bos' kapisi hala tutar; o yuzden mutasyonun ETKISI mesaj duzeyinde olculur
  MUT_CIKTI="$(python3 "$M" "$T/k.json" 2>&1 || true)"
  MUTANT_MESAJ="$(printf '%s' "$MUT_CIKTI" | grep -c 'KAPISIZ' || true)"
  [ "$MUTANT_MESAJ" = 0 ]; g $? "P9b MUTASYON: kural ölünce 'KAPISIZ' teşhisi KAYBOLUYOR (kapı gerçek)"
fi

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
