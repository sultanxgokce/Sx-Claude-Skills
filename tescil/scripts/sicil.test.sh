#!/usr/bin/env bash
# sicil.test.sh — Mühürdarlık sicil · ders çıkarma · askı (G11 · S9 · S10) sınavı. HERMETİK: geçici sicil dizini, el kitabı
# kopyası, tarif kaydı fikstürü; gerçek özlük dosyalarına DOKUNMAZ. Senaryo fonksiyonda; mutant kopyada hedef anahtar düşer.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
python3 -c "import yaml" 2>/dev/null || { echo "ÖLÇÜLEMEDİ: PyYAML yok"; exit 4; }
D1='2026-10-22 Sultan: saglanmadi (sohbet · session_X · "renk koyu değil" · beyan:SERDAR)'

kur() {  # kur <kök> — iki özlük (biri isabetsiz, biri isabet bölümü sonda olmayan), el kitabı kopyası, tarif kaydı
  local k="$1"; mkdir -p "$k/sicil"
  printf '# özlük\npersonel_no: "01.008"\npersona: MUHURDAR1\ndurum: aktif\ngecmis: []\n' > "$k/sicil/01.008.yaml"
  printf 'personel_no: "01.009"\npersona: BOZUK\nisabet:\n  - {"ts": "x", "gorev": "g", "kacirma": "h"}\ngecmis: []\n' > "$k/sicil/01.009.yaml"
  sed 's/^Bugün kural yok.*/- **D-001** (2026-10-22 · tür: e2e-check · kaçırmalar: fikstür) Sınav kuralı — PR #0/' "$HERE/../SKILL.md" > "$k/EL.md"
  printf '{"uzmanliklar":[{"id":"muhurdarlik","sicil_esigi":{"kacirma":3,"pencere":4}}]}' > "$k/tarif.json"
}
_sen() {  # _sen <sicil.sh> → geçen anahtarlar
  local S="$1" k="$T/k$RANDOM" o=""; kur "$k"
  local E=(env SICIL_DIZIN="$k/sicil" EL_KITABI="$k/EL.md" TARIF_KAYDI="$k/yok.json")
  local Y="$k/sicil/01.008.yaml"
  # a · isabet yazılır (kaçırma = mühür ✓ + Sultan sağlanmadı), YAML geçerli, öbür alanlar korunur
  "${E[@]}" bash "$S" isabet muhurdar1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --kaynak "$D1" --neden "renk koyu değil" --g-tur e2e-check --el-kitabi-surum 0.4.0 >/dev/null 2>&1
  [ $? -eq 0 ] && python3 -c "import yaml,sys;d=yaml.safe_load(open(sys.argv[1]));x=d['isabet'][-1];assert x['kacirma']=='e' and x['sultan']=='saglanmadi' and x['neden']=='renk koyu değil' and x['kaynak'].startswith('2026-10-22 Sultan') and d['persona']=='MUHURDAR1' and d['gecmis']==[]" "$Y" 2>/dev/null && o="$o a"
  # b · özlük dosyası yoksa yazılmaz, rc 3
  local n0; n0="$(cat "$k"/sicil/*.yaml | md5sum)"
  "${E[@]}" bash "$S" isabet MUHAKKIK --gorev g --gereklilik G1 --muhur ✓ --sultan katiliyorum --kaynak teslim:abc123 >/dev/null 2>"$k/e"; [ $? -eq 3 ] && grep -q "özlük dosyası YOK" "$k/e" && [ "$(cat "$k"/sicil/*.yaml | md5sum)" = "$n0" ] && o="$o b"
  # c · A06: kaynaksız ya da biçimsiz kaynak → rc 2, yazılmaz
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev g --gereklilik G1 --muhur ✓ --sultan saglanmadi --neden n >/dev/null 2>&1; local r1=$?
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev g --gereklilik G1 --muhur ✓ --sultan saglanmadi --neden n --kaynak "Sultan öyle dedi" >/dev/null 2>"$k/e"; local r2=$?
  [ $r1 -eq 2 ] && [ $r2 -eq 2 ] && grep -q "A06" "$k/e" && [ "$(cat "$k"/sicil/*.yaml | md5sum)" = "$n0" ] && o="$o c"
  # d · kaçırma DEĞİL: mühür ✗ + sağlanmadı (mühürdar yakaladı) · mühür ✓ + katılıyorum
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_B --gereklilik G1 --muhur ✗ --sultan saglanmadi --neden n --kaynak teslim:abc123 >/dev/null 2>&1
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_B --gereklilik G2 --muhur ✓ --sultan katiliyorum --kaynak teslim:abc123 >/dev/null 2>&1
  python3 -c "import yaml,sys;x=yaml.safe_load(open(sys.argv[1]))['isabet'];assert [i['kacirma'] for i in x]==['e','h','h']" "$Y" 2>/dev/null && o="$o d"
  # e · isabet bölümü dosyanın sonunda değilse eklenmez
  "${E[@]}" bash "$S" isabet BOZUK --gorev g --gereklilik G1 --muhur ✓ --sultan katiliyorum --kaynak teslim:abc123 >/dev/null 2>"$k/e"; [ $? -eq 2 ] && grep -q "sonunda değil" "$k/e" && o="$o e"
  # f · 'sağlanmadı' Sultan'ın cümlesi olmadan yazılmaz
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev g --gereklilik G1 --muhur ✓ --sultan saglanmadi --kaynak teslim:abc123 >/dev/null 2>&1; [ $? -eq 2 ] && o="$o f"
  # g · durum: 1 kaçırmalı mühür → ders-cikarma (askı yok)
  [ "$("${E[@]}" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["durum"])')" = ders-cikarma ] && o="$o g"
  # h · 2. kaçırmalı mühür (ayrı görev) → askida + gereken üç iş
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_C --gereklilik G3 --muhur ✓ --sultan saglanmadi --neden "yine koyu değil" --g-tur e2e-check --kaynak teslim:def456 >/dev/null 2>&1
  "${E[@]}" bash "$S" durum MUHURDAR1 > "$k/d" 2>&1; grep -q "^durum: askida" "$k/d" && grep -q "yeniden yeterlilik sınavı" "$k/d" && grep -q "el kitabı güncelleme" "$k/d" && o="$o h"
  # i · pencere: 9 temiz mühür daha → ilk kaçırma 10'un dışına düşer → askıdan çıkar (ders-cikarma)
  for i in 1 2 3 4 5 6 7 8 9; do "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev "gorev_T$i" --gereklilik G1 --muhur ✓ --sultan katiliyorum --kaynak teslim:abc123 >/dev/null 2>&1; done
  [ "$("${E[@]}" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["durum"], d["pencere"])')" = "ders-cikarma 10" ] && o="$o i"
  # j · eşik tarif kaydından okunur (3/4): aynı sicil, farklı eşik → farklı hüküm
  local Y2="$k/y2"; mkdir -p "$Y2"; cp "$k/sicil/01.008.yaml" "$Y2/"
  for i in 1 2; do env SICIL_DIZIN="$Y2" bash "$S" isabet MUHURDAR1 --gorev "gorev_X$i" --gereklilik G1 --muhur ✓ --sultan saglanmadi --neden n --kaynak teslim:abc123 >/dev/null 2>&1; done
  [ "$(env SICIL_DIZIN="$Y2" TARIF_KAYDI="$k/tarif.json" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["durum"],d["esik"]["pencere"],d["esik_kaynagi"])')" = "ders-cikarma 4 tarif kaydı" ] \
    && [ "$(env SICIL_DIZIN="$Y2" TARIF_KAYDI="$k/yok.json" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["durum"])')" = askida ] && o="$o j"
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_L --gereklilik G1 --muhur ✓ --sultan saglanmadi --neden "tek sefer" --g-tur cmd --kaynak teslim:abc123 >/dev/null 2>&1
  # k · ders: aynı tür ≥2 AYRI görevde → tekrar eden, Sultan'ın cümleleri taslakta, sonraki ders D-002
  "${E[@]}" bash "$S" ders MUHURDAR1 > "$k/ders" 2>&1; grep -q "e2e-check: 2 kaçırma · 2 görev — TEKRAR EDEN" "$k/ders" && grep -q 'Sultan: "renk koyu değil"' "$k/ders" \
    && grep -q 'Sultan: "yine koyu değil"' "$k/ders" && grep -q "Ders taslağı (D-002)" "$k/ders" && grep -q "cmd: 1 kaçırma · 1 görev$" "$k/ders" && [ "$(grep -c 'Ders taslağı' "$k/ders")" = 1 ] && o="$o k"
  # l · ders-bagla: günlükte olmayan derse bağlanmaz; olan derse bağlanır, özgün satır değişmez, ders listesinden düşer
  local ts; ts="$(python3 -c "import yaml,sys;print([x for x in yaml.safe_load(open(sys.argv[1]))['isabet'] if x.get('gorev')=='gorev_A'][0]['ts'])" "$Y")"
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$ts" --ders D-077 >/dev/null 2>&1; local rb=$?
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$ts" --ders D-001 >/dev/null 2>&1; local rg=$?
  [ $rb -eq 2 ] && [ $rg -eq 0 ] && python3 -c "import yaml,sys;x=yaml.safe_load(open(sys.argv[1]))['isabet'];a=[i for i in x if i.get('gorev')=='gorev_A'][0];b=x[-1];assert a['ders'] is None and b['tur']=='ders-bagi' and b['ders']=='D-001'" "$Y" 2>/dev/null \
    && "${E[@]}" bash "$S" ders MUHURDAR1 | grep -q "e2e-check: 1 kaçırma · 1 görev$" && o="$o l"
  # m · kaçırma olmayan satır derse bağlanmaz; aynı kaçırma ikinci kez bağlanmaz
  local tsh; tsh="$(python3 -c "import yaml,sys;print([x for x in yaml.safe_load(open(sys.argv[1]))['isabet'] if x.get('gorev')=='gorev_B'][0]['ts'])" "$Y")"
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$tsh" --ders D-001 >/dev/null 2>&1; local r3=$?
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$ts" --ders D-001 >/dev/null 2>&1; local r4=$?
  [ $r3 -eq 2 ] && [ $r4 -eq 2 ] && o="$o m"
  # n · başsız şapka hükmü işaretlenir ama yine bu mühürdarın siciline yazılır (S14)
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_Z --gereklilik G1 --muhur ✓ --sultan katiliyorum --kaynak teslim:abc123 --bassiz >/dev/null 2>&1
  python3 -c "import yaml,sys;assert yaml.safe_load(open(sys.argv[1]))['isabet'][-1]['bassiz']=='e'" "$Y" 2>/dev/null && o="$o n"
  echo "$o"
}
_k() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

echo "════ G11 · S10 · Mühürdarlık sicil · ders çıkarma · askı (sicil.sh) ════"
S0="$(_sen "$HERE/sicil.sh")"
_k a "$S0"; g $? "a isabet özlük dosyasına yazılır (kaçırma = mühür ✓ + Sultan sağlanmadı), Sultan'ın cümlesi + kaynağı satırda, öbür alanlar korunur"
_k b "$S0"; g $? "b özlük dosyası yoksa (MUHAKKİK vakası) yazılmaz, rc 3, hiçbir dosya değişmez"
_k c "$S0"; g $? "c A06: kaynaksız ya da biçimsiz kaynakla Sultan'ın hükmü yazılmaz (rc 2)"
_k d "$S0"; g $? "d kaçırma değil: mühür ✗ + sağlanmadı (mühürdar yakaladı) · mühür ✓ + katılıyorum"
_k e "$S0"; g $? "e isabet bölümü dosyanın sonunda değilse eklenmez (YAML bozulmasın)"
_k f "$S0"; g $? "f 'sağlanmadı' Sultan'ın tek cümlesi olmadan yazılmaz"
_k g "$S0"; g $? "g 1 kaçırmalı mühür → ders-cikarma, askı yok (S10)"
_k h "$S0"; g $? "h son 10'da 2 kaçırmalı mühür → askida + el kitabı güncelleme + yeniden sınav (S10)"
_k i "$S0"; g $? "i pencere 10 mühür: ilk kaçırma dışarı düşünce askı kalkar (ders-cikarma)"
_k j "$S0"; g $? "j eşik tarif kaydından okunur (3/4 → askı yok), kayıt yoksa S10 varsayılanı (2/10 → askı)"
_k k "$S0"; g $? "k ders çıkarma: aynı tür ≥2 ayrı görevde = tekrar eden → D-002 taslağı Sultan'ın cümleleriyle"
_k l "$S0"; g $? "l ders-bagla: günlükte olmayan derse bağlanmaz; olana ters kayıtla bağlanır, özgün satır değişmez, açık listeden düşer"
_k m "$S0"; g $? "m kaçırma olmayan satır derse bağlanmaz; aynı kaçırma iki kez bağlanmaz"
_k n "$S0"; g $? "n başsız şapka hükmü işaretli (bassiz e), yine bu mühürdarın siciline yazılır (S14)"

echo "── MUTASYON (tescil kopyasında, kontrol şartlı) ──"
_kopya() { local d="$T/m-$1"; mkdir -p "$d"; cp -r "$HERE/.." "$d/tescil"; echo "$d/tescil/scripts"; }
k0="$(_kopya kontrol)"; [ "$(_sen "$k0/sicil.sh")" = "$S0" ] && [ -n "$S0" ]; g $? "kontrol kopyası gerçek betikle aynı kapıları geçiyor"
_m() {  # _m <anahtar> <eski> <yeni> <açıklama>   (hedef: lib/sicil.py)
  local d; d="$(_kopya "$1-$RANDOM")"
  python3 - "$d/lib/sicil.py" "$2" "$3" <<'PY' || { g 1 "mutant ($4): desen tutmadı"; return; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding='utf-8').read(); o=s; s=s.replace(a,b,1); assert s!=o; open(p,'w',encoding='utf-8').write(s)
PY
  ! _k "$1" "$(_sen "$d/sicil.sh")"; g $? "mutant ($4) → '$1' kapısı düşüyor"
}
_m c '    if not (D1.match(kaynak) or TESLIM.match(kaynak)):' '    if False:' "Sultan kaydı aranmıyor (A06)"
_m b '    if not bulunan:
        hata(' '    if not bulunan:
        return os.path.join(SICIL_DIZIN, ad + ".yaml")
        hata(' "özlük yoksa yeni dosya açıyor"
_m d '"kacirma": "e" if (a["muhur"] == "✓" and a["sultan"] == "saglanmadi") else "h",' '"kacirma": "e" if a["sultan"] == "saglanmadi" else "h",' "mühürdarın yakaladığı da kaçırma sayılıyor"
_m i '    pencere = gorevler[-e["pencere"]:]' '    pencere = gorevler' "pencere yok sayılıyor"
_m j '    try:
        with open(TARIF_KAYDI' '    return VARSAYILAN_ESIK, "varsayılan (Sultan S10)"
    try:
        with open(TARIF_KAYDI' "eşik tarif kaydından okunmuyor"
_m k 'len({x.get("gorev") for x in xs}) >= 2}' 'len(xs) >= 1}' "tek kaçırma da tekrar eden sayılıyor"
_m l '    if a["ders"] not in gunluk_dersleri():' '    if False:' "günlükte olmayan derse bağlanıyor"
_m e '    if "isabet" in ust and ust[-1] != "isabet":' '    if False:' "isabet sonda değilken ekleniyor"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
