#!/usr/bin/env bash
# kadro-denetle.test.sh — bekçinin kendi sınavı: ALTIN (gerçek veri) yeşil geçer, her kural için BOZULMUŞ kopya kırmızı döner.
# Tek yönlü fikstür yalnız katılaşmayı yakalar, gevşemeyi yakalamaz — bu yüzden iki yön de var.
set -u
AD="$(cd "$(dirname "$0")" && pwd)"; VERI="$AD/../veri"; BEKCI="${KADRO_BEKCI:-$AD/kadro-denetle.py}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
gecen=0; kalan=0
declare -A DESEN
ok() { gecen=$((gecen+1)); echo "ok   $1"; }
kt() { kalan=$((kalan+1)); echo "KIRMIZI $1"; }

# kopya <ad> <python-bozucu>: veri dizinini $T/<ad>'a kopyalar, bozucuyu uygular. Bozucu `v` (tarifler) ve `t` (terimler) üstünde çalışır.
kopya() {
  mkdir -p "$T/$1"; cp "$VERI"/*.json "$T/$1/"
  KD="$T/$1" python3 - "$2" <<'PY'
import json, os, sys
kd = os.environ["KD"]
v = json.load(open(kd + "/kadro-tarifleri.json", encoding="utf-8"))
t = json.load(open(kd + "/terim-kaydi.json", encoding="utf-8"))
exec(sys.argv[1])
json.dump(v, open(kd + "/kadro-tarifleri.json", "w", encoding="utf-8"), ensure_ascii=False)
json.dump(t, open(kd + "/terim-kaydi.json", "w", encoding="utf-8"), ensure_ascii=False)
PY
}
# bozuk <ad> <beklenen-rc> <çıktıda-geçen> <python-bozucu> [bekçi-bayrakları…]
bozuk() {
  local ad="$1" rc="$2" desen="$3" boz="$4"; shift 4
  DESEN[$ad]="$desen"
  kopya "$ad" "$boz"; local o; o="$(python3 "$BEKCI" --veri "$T/$ad" "$@" 2>&1)"; local r=$?
  if [ "$r" -eq "$rc" ] && printf '%s' "$o" | grep -qF -- "$desen"; then ok "$ad → rc=$rc ve «$desen»"; else kt "$ad → beklenen rc=$rc «$desen», gelen rc=$r: $(printf '%s' "$o" | tail -3 | tr '\n' '|')"; fi
}

# ── ALTIN: gerçek veri kırmızı vermez ──
o="$(python3 "$BEKCI" 2>&1)"; r=$?
[ "$r" -eq 0 ] && printf '%s' "$o" | grep -q 'kirmizi=0' && ok "altın: gerçek veri rc=0 kirmizi=0" || kt "altın: rc=$r $(printf '%s' "$o" | tail -2 | tr '\n' '|')"
printf '%s' "$o" | grep -q 'SARI 4 kapi_yolu' && ok "altın: yazılmamış kapı SARI olarak görünür (sessiz geçmez)" || kt "altın: null kapı sarı vermedi"

# ── KIRMIZI: her kural için bir bozulma ──
bozuk k-tur        1 "adım türü"        "v['usuller'][0]['adimlar'][2]['tur']='sultan-eli'"
bozuk k-tarif      1 "sultan_eli_tarifi" "del v['usuller'][0]['adimlar'][4]['sultan_eli_tarifi']"
bozuk k-yedek      1 "yedek dolu değil"  "v['vazifeler'][0]['yedek']=None"
bozuk k-kalibr     1 "kalibrasyon"       "v['vazifeler'][2]['id']='kalibrasyon'; v['uzmanliklar'][0]['vazifeler'][2]='kalibrasyon'; v['usuller'][2]['vazife']='kalibrasyon'"
bozuk k-cakisir    1 "vazife tescil cakisir 'tatbikat' diyor"       "v['vazifeler'][0]['cakisir']=['tatbikat']"
bozuk k-karist     1 "terim personel karistirilan 'uzmanlik' diyor"       "t['terimler'][0]['karistirilan']=['uzmanlik']; t['terimler'][0]['ayirt_testi']='x'"
bozuk k-ayirt      1 "ayirt_testi yok"   "[x for x in t['terimler'] if x['id']=='kapi-giris'][0]['ayirt_testi']=None"
bozuk k-kapiyol    1 "dosya olarak yok"  "v['usuller'][0]['adimlar'][0]['kapi_yolu']='yok/boyle/bir/betik.sh'"
bozuk k-benzersiz  1 "terim kimliği 'personel' iki kez" "x=dict(t['terimler'][0]); x['ad']='Personel ikinci'; t['terimler'].append(x)"
bozuk k-adikiz     1 "terim adı 'Personel' iki kez"     "x=dict(t['terimler'][0]); x['id']='personel-ikinci'; t['terimler'].append(x)"
bozuk k-surum      1 "usul tescil-teslim-sina: sema_surumu 2 olmalı"       "v['usuller'][0]['sema_surumu']=1"
bozuk k-kaynak     1 "sx:yok/dosya.json yok" "t['terimler'][0]['kaynak']=['sx:yok/dosya.json']"
bozuk k-model      1 "vazife tescil: model 'gpt'"           "v['vazifeler'][0]['model']='gpt'"
bozuk k-sira       1 "ardışık değil"     "v['usuller'][0]['adimlar'][3]['sira']=9"
bozuk k-esik       1 "uzmanlık muhurdarlik: sicil_esigi"       "v['uzmanliklar'][0]['sicil_esigi']={'kacirma':11,'pencere':10}"
bozuk k-bicim      1 "biçimi tanınmıyor" "t['terimler'][0]['kaynak']=['http://x']"
bozuk k-durum      1 "terim personel: durum 'onaylandi'"           "t['terimler'][0]['durum']='onaylandi'"
bozuk k-beceri     1 "beceri_id zorunlu" "del v['usuller'][0]['adimlar'][2]['beceri_id']"
bozuk k-uzm-ikiz   1 "uzmanlık kimliği 'muhurdarlik' iki kez" "v['uzmanliklar'].append(dict(v['uzmanliklar'][0]))"
bozuk k-vaz-ikiz   1 "vazife kimliği 'tescil' iki kez"       "v['vazifeler'].append(dict(v['vazifeler'][0]))"
bozuk k-usul-ikiz  1 "usul kimliği 'tescil-teslim-sina' iki kez" "v['usuller'].append(dict(v['usuller'][0]))"
bozuk k-idsiz      1 "id (metin) eksik"  "del v['vazifeler'][1]['id']"
bozuk k-nesne      1 "nesne olmalı"      "v['vazifeler'].append('metin')"
bozuk k-adim-nesne 1 "usul tescil-teslim-sina adım: nesne olmalı" "v['usuller'][0]['adimlar'].append(5)"
bozuk k-liste      1 "usuller liste olmalı" "v['usuller']={}"
bozuk k-koleksiyon-yok 1 "usuller liste olmalı (yok ya da NoneType)" "del v['usuller']"
bozuk k-bos-uzm    1 "uzmanliklar boş"    "v['uzmanliklar']=[]"
bozuk k-bos-terim  1 "terimler liste olmalı ve boş olmamalı" "t['terimler']=[]"
bozuk k-terim-idsiz 1 "terim: id (metin) eksik" "del t['terimler'][3]['id']"
bozuk k-terim-idsayi 1 "terim: id (metin) eksik" "t['terimler'][3]['id']=7"
bozuk k-elkitabi   1 "el_kitabi 'olmayan-beceri' katalogda yok" "v['uzmanliklar'][0]['el_kitabi']='olmayan-beceri'"
bozuk k-unvan      1 "unvan boş"          "v['uzmanliklar'][0]['unvan']=''"
bozuk k-kor        1 "kor evet/hayır"     "v['vazifeler'][0]['kor']='evet'"
bozuk k-tetik      1 "usul tescil-teslim-sina: tetik boş" "v['usuller'][0]['tetik']=''"
bozuk k-cikti      1 "cikti boş"          "v['usuller'][1]['cikti']=None"
bozuk k-katman     1 "katman 'beceri-x'"  "t['terimler'][0]['katman']='beceri-x'"
bozuk k-kaynak-tip 1 "kaynak öğesi metin olmalı" "t['terimler'][0]['kaynak']=[5]"
bozuk k-yol-kacis  1 "depo içi göreli yol olmalı" "v['usuller'][0]['adimlar'][0]['kapi_yolu']='../../etc/hostname'"
bozuk k-yol-mutlak 1 "depo içi göreli yol olmalı" "v['usuller'][0]['adimlar'][0]['kapi_yolu']='/etc/hostname'"
bozuk k-sx-kacis   1 "yol göreli olmalı"  "t['terimler'][0]['kaynak']=['sx:../../etc/hostname']"
bozuk k-hepsi-bos  1 "boş tarif kaydı temiz sayılmaz" "v['uzmanliklar']=[]; v['vazifeler']=[]; v['usuller']=[]; t['terimler']=[]"
# beklenmeyen biçim çökerse yeşil değil, ölçülemedi (rc=3)
bozuk o-cokme      3 "beklenmeyen biçimde durdu" "v['vazifeler'][0]['cakisir']=5"

# ── SARI: rc=0 ama görünür; --siki ile rc=1 ──
bozuk s-katalog 0 "katalogda yok"   "v['usuller'][0]['adimlar'][2]['beceri_id']='olmayan-beceri'"
bozuk s-katalog-siki 1 "katalogda yok" "v['usuller'][0]['adimlar'][2]['beceri_id']='olmayan-beceri'" --siki
bozuk s-terim   0 "terimi yok"      "t['terimler']=[x for x in t['terimler'] if x['ad']!='Teslim sınama']"

# ── ÖLÇÜLEMEDİ: rc=3, yeşil değil ──
mkdir -p "$T/yok" && cp "$VERI/kadro-tarifleri.json" "$T/yok/"
o="$(python3 "$BEKCI" --veri "$T/yok" 2>&1)"; r=$?; [ "$r" -eq 3 ] && ok "terim-kaydi.json yok → rc=3" || kt "terim-kaydi yok: rc=$r"
echo '{"skills": []}' > "$T/bos-katalog.json"
o="$(python3 "$BEKCI" --katalog "$T/bos-katalog.json" 2>&1)"; r=$?; [ "$r" -eq 3 ] && printf '%s' "$o" | grep -q 'boş katalog' && ok "boş katalog → rc=3" || kt "boş katalog: rc=$r"
o="$(NEXUS_KOK=/yok/kok python3 "$BEKCI" 2>&1)"; r=$?; [ "$r" -eq 0 ] && printf '%s' "$o" | grep -q 'ÖLÇÜLEMEDİ, temiz sayılmaz' && ok "nexus kökü okunamayınca SARI ölçülemedi (yeşil değil)" || kt "kök yok: rc=$r"

# ── MUTASYON: bekçinin bir kuralı kapatılırsa ilgili sınav KIRMIZIYA dönmeli (kapı gerçekten kapı mı) ──
mutant() {  # mutant <ad> <python-yerine-koy: eski||yeni> <sınanan-bozulma-adı>
  local ad="$1" eski="${2%%||*}" yeni="${2##*||}" hedef="$3"
  MUT="$T/mut-$ad.py"; python3 - "$BEKCI" "$MUT" "$eski" "$yeni" <<'PY'
import sys
k, m, e, y = sys.argv[1:5]
s = open(k, encoding="utf-8").read()
assert e in s, "mutasyon hedefi bulunamadı: " + e
open(m, "w", encoding="utf-8").write(s.replace(e, y, 1))
PY
  [ $? -eq 0 ] || { kt "mutasyon $ad: hedef bulunamadı"; return; }
  local o r
  o="$(python3 "$MUT" --veri "$T/$hedef" --kok "$AD/../.." 2>&1)"; r=$?
  if ! printf '%s' "$o" | grep -qF -- "${DESEN[$hedef]}"; then ok "mutasyon $ad öldürüldü (kural kapalıyken «${DESEN[$hedef]}» çıkmıyor → sınav bunu yakalar)"; else kt "mutasyon $ad YAŞIYOR: kural kapalı olduğu halde $hedef hâlâ «${DESEN[$hedef]}» diyor"; fi
}
mutant yedek     'if v.get("acil") == "evet":||if False:'                                  k-yedek
mutant cakisir   'elif v["id"] not in vaz[c].get("cakisir", []):||elif False:'              k-cakisir
mutant kapiyol   'elif not os.path.isfile(os.path.join(kok, a["kapi_yolu"])):||elif False:' k-kapiyol
mutant kalibr    'YASAK_VAZIFE_ID = ("kalibrasyon",)||YASAK_VAZIFE_ID = ()'                 k-kalibr
mutant karist    'elif tid not in idler[k].get("karistirilan", []):||elif False:'           k-karist
mutant tarif     'if a["tur"] == "sultan_eli" and not a.get("sultan_eli_tarifi"):||if False:' k-tarif
mutant benzersiz 'if t.get("id") in idler:||if False:'                                      k-benzersiz
mutant adikiz    'if t.get("ad") in adlar:||if False:'                                       k-adikiz
mutant vazikiz   'if kid in sonuc:||if False:'                                          k-vaz-ikiz
mutant idsiz     'if not isinstance(kid, str) or not kid:||if False:'                    k-idsiz
mutant bosuzm    'if not liste:||if False:'                                              k-bos-uzm
mutant terimbos  'if not isinstance(ham, list) or not ham:||if False:'                  k-bos-terim
mutant terimid   'if not isinstance(t.get("id"), str) or not t.get("id"):||if False:'   k-terim-idsiz
mutant elkitabi  'if u.get("el_kitabi") not in katalog_idleri:||if False:'               k-elkitabi
mutant kor       'if not isinstance(v.get("kor"), bool):||if False:'                    k-kor
mutant yolkacis  'elif not repo_ici(a["kapi_yolu"]):||elif False:'                       k-yol-kacis
mutant katman    'if t.get("katman") not in KATMANLAR:||if False:'                       k-katman
mutant nesne     'if not isinstance(kayit, dict):||if False:'                            k-nesne
mutant sira      'if [a.get("sira") for a in adimlar] != list(range(1, len(adimlar) + 1)):||if False:' k-sira

echo "toplam=$((gecen+kalan)) geçen=$gecen kırmızı=$kalan"
[ "$kalan" -eq 0 ]
