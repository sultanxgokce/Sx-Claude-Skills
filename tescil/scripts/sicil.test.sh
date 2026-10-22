#!/usr/bin/env bash
# sicil.test.sh — Mühürdarlık sicil · ders çıkarma · askı (G11 · S9 · S10) sınavı. HERMETİK: geçici sicil dizini, el kitabı
# kopyası, tarif kaydı ve SAHTE doğrulayıcı (geçidin yerine: Sultan'ın kayıtlı kararlarını fikstürden basar); gerçek özlük
# dosyalarına DOKUNMAZ. Senaryo fonksiyonda; mutant kopyada hedef anahtar düşer.
# kabuk-testleri: sure=480   (yerelde 154 sn ölçüldü — 23 mutant tam senaryoyu koşar; CI payı)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
python3 -c "import yaml" 2>/dev/null || { echo "ÖLÇÜLEMEDİ: PyYAML yok"; exit 4; }
ND="$(dirname "$(command -v node)")"; [ -n "$ND" ] || { echo "ÖLÇÜLEMEDİ: node yok"; exit 4; }

kur() {  # kur <kök> — özlükler, el kitabı kopyası, tarif kaydı, Sultan kararları + sahte doğrulayıcı, sahte mühür dizini, küçük iş ağacı
  local k="$1"; mkdir -p "$k/sicil" "$k/kararlar" "$k/md"
  printf '# özlük\npersonel_no: "01.008"\npersona: MUHURDAR1\ndurum: aktif\ngecmis: []\n' > "$k/sicil/01.008.yaml"
  printf 'personel_no: "01.009"\npersona: BOZUK\nisabet:\n  - {"ts": "x", "gorev": "g", "kacirma": "h"}\ngecmis: []\n' > "$k/sicil/01.009.yaml"
  sed 's/^Bugün kural yok.*/- **D-001** (2026-10-22 · tür: e2e-check · kaçırmalar: fikstür) Sınav kuralı — PR #0/' "$HERE/../SKILL.md" > "$k/EL.md"
  printf '{"uzmanliklar":[{"id":"muhurdarlik","sicil_esigi":{"kacirma":3,"pencere":4}}]}' > "$k/tarif.json"
  kr() { printf '%s' "$2" > "$k/kararlar/$1.json"; }
  kr A '{"gorev":"gorev_A","satirlar":{"G2":{"sultan":"saglanmadi","neden":"renk koyu değil"}}}'
  kr B '{"gorev":"gorev_B","satirlar":{"G1":{"sultan":"saglanmadi","neden":"n"},"G2":{"sultan":"katiliyorum"}}}'
  kr C '{"gorev":"gorev_C","satirlar":{"G3":{"sultan":"saglanmadi","neden":"yine koyu değil"}}}'
  kr F '{"gorev":"gorev_F","satirlar":{"G1":{"sultan":"saglanmadi"}}}'
  kr L '{"gorev":"gorev_L","satirlar":{"G1":{"sultan":"saglanmadi","neden":"tek sefer"}}}'
  kr X1 '{"gorev":"gorev_X1","satirlar":{"G1":{"sultan":"saglanmadi","neden":"n"}}}'
  kr X2 '{"gorev":"gorev_X2","satirlar":{"G1":{"sultan":"saglanmadi","neden":"n"}}}'
  kr Z '{"gorev":"gorev_Z","satirlar":{"G1":{"sultan":"katiliyorum"}}}'
  kr T '{"gorev":"gorev_T","satirlar":{"G1":{"sultan":"katiliyorum"},"G2":{"sultan":"saglanmadi","neden":"ton sert"}}}'
  kr TK '{"gorev":"gorev_TK","satirlar":{"G1":{"sultan":"katiliyorum"}}}'
  kr W '{"gorev":"gorev_W","satirlar":{"G1":{"sultan":"katiliyorum"},"G2":{"sultan":"saglanmadi","neden":"x"}}}'
  kr TN '{"gorev":"gorev_T","satirlar":{"G1":{"sultan":"katiliyorum"},"G2":{"sultan":"saglanmadi"}}}'
  kr TV '{"gorev":"gorev_T","satirlar":{"G1":{"sultan":"katiliyorum"},"G2":{"sultan":"evet-sayilir","neden":"x"}}}'
  # kes.py — yazım kesici: KES_DIZIN altındaki N. yazma açılışında (KES_N) ya da yerine koymada (KES_REPLACE) OSError;
  #   KES_GECIK=sn yerine koymayı geciktirir (eşzamanlı yazım yarışını her koşuda aynı kurar)
  cat > "$k/kes.py" <<'PY'
import builtins, os, runpy, sys
n = [0]; asil = builtins.open
def kesik(f, mode="r", *x, **kw):
    if any(c in mode for c in "wa") and str(f).startswith(os.environ["KES_DIZIN"]) and not str(f).endswith(".kilit"):   # kilit yazım değil
        n[0] += 1
        if n[0] == int(os.environ.get("KES_N", "0")):
            raise OSError("kes: yazım yarıda")
    return asil(f, mode, *x, **kw)
def kesik_replace(*x, **kw):
    raise OSError("kes: yerine koyma yarıda")
asil_replace = os.replace
def gec_replace(*x, **kw):   # okuma ile yerine koyma arasını açar: kilitsiz iki yazım burada birbirini siler
    import time; time.sleep(float(os.environ["KES_GECIK"])); return asil_replace(*x, **kw)
builtins.open = kesik
if os.environ.get("KES_REPLACE"):
    os.replace = kesik_replace
elif os.environ.get("KES_GECIK"):
    os.replace = gec_replace
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")
PY
  printf '#!/usr/bin/env bash\nf="%s/kararlar/${1#teslim:karar-}.json"; [ -f "$f" ] || exit 1; cat "$f"\n' "$k" > "$k/dogrula.sh"; chmod +x "$k/dogrula.sh"
  printf '{"g":[{"id":"G1","tur":"cmd"},{"id":"G2","tur":"llm-yargi"},{"id":"G3","tur":"sultan-denemesi"}]}' > "$k/md/gereklilik.json"
  printf '{"kart":"gorev_T","verdikt":"KALDI","g_dusen":["G1"],"muhurdar":"MUHURDAR1","tescil_skill_version":"0.4.0"}' > "$k/md/muhur-ozet.json"
  mkdir -p "$k/md2"; cp "$k/md/gereklilik.json" "$k/md2/"; sed 's/MUHURDAR1/BASKASI/' "$k/md/muhur-ozet.json" > "$k/md2/muhur-ozet.json"
  local W="$k/is"; mkdir -p "$W/g"; git -C "$W" init -q -b main; echo merhaba > "$W/c.txt"; git -C "$W" add -A; git -C "$W" -c user.email=a@b -c user.name=a commit -qm x
  printf 'KART: is-r\nGOAL: selam\nTIP: docs\nVITES: TAM\nG1: selam\n  tur: cmd\n  komut: grep -q merhaba c.txt\n  davranis: evet\n' > "$W/g/GEREKLILIK.md"
}
_sen() {  # _sen <scripts-dir> → geçen anahtarlar
  local SD="$1" S="$1/sicil.sh" k="$T/k$RANDOM" o=""; kur "$k"
  local E=(env SICIL_DIZIN="$k/sicil" EL_KITABI="$k/EL.md" TARIF_KAYDI="$k/yok.json" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh")
  local Y="$k/sicil/01.008.yaml" n0
  # a · Sultan'ın DOĞRULANMIŞ kaydıyla isabet yazılır (kaçırma = mühür ✓ + sağlanmadı), öbür alanlar korunur
  "${E[@]}" bash "$S" isabet muhurdar1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --kaynak teslim:karar-A --g-tur e2e-check --el-kitabi-surum 0.4.0 >/dev/null 2>&1
  [ $? -eq 0 ] && python3 -c "import yaml,sys;d=yaml.safe_load(open(sys.argv[1]));x=d['isabet'][-1];assert x['kacirma']=='e' and x['neden']=='renk koyu değil' and x['kaynak']=='teslim:karar-A' and d['persona']=='MUHURDAR1' and d['gecmis']==[]" "$Y" 2>/dev/null && o="$o a"
  n0="$(cat "$k"/sicil/*.yaml | md5sum)"
  # b · özlük dosyası yoksa yazılmaz, rc 3
  "${E[@]}" bash "$S" isabet MUHAKKIK --gorev gorev_Z --gereklilik G1 --muhur ✓ --sultan katiliyorum --kaynak teslim:karar-Z >/dev/null 2>"$k/e"; [ $? -eq 3 ] && grep -q "özlük dosyası YOK" "$k/e" && [ "$(cat "$k"/sicil/*.yaml | md5sum)" = "$n0" ] && o="$o b"
  # Y12: boş özlük — c(r3) ve u kendi kuralını ölçsün diye (a'nın A/G2 satırı orada yok; yoksa tekrar denetimi (aa) onları maskeler)
  local Y12="$k/y12"; mkdir -p "$Y12"; printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$Y12/01.008.yaml"
  local n12; n12="$(md5sum < "$Y12/01.008.yaml")"
  # c · A06: doğrulayıcı yoksa rc 3 · uydurma kaynak rc 2 · kayıt bu satırı doğrulamıyorsa rc 2 — hiçbiri yazılmaz
  env SICIL_DIZIN="$k/sicil" bash "$S" isabet MUHURDAR1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --kaynak teslim:karar-A >/dev/null 2>"$k/e"; local r1=$?; grep -q "DOĞRULANAMADI" "$k/e"; local g1=$?
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --kaynak teslim:karar-UYDURMA >/dev/null 2>&1; local r2=$?
  env SICIL_DIZIN="$Y12" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" isabet MUHURDAR1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan katiliyorum --kaynak teslim:karar-A >/dev/null 2>&1; local r3=$?
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_B --gereklilik G2 --muhur ✓ --sultan saglanmadi --neden x --kaynak teslim:karar-A >/dev/null 2>&1; local r4=$?
  [ $r1 -eq 3 ] && [ $g1 -eq 0 ] && [ $r2 -eq 2 ] && [ $r3 -eq 2 ] && [ $r4 -eq 2 ] && [ "$(cat "$k"/sicil/*.yaml | md5sum)" = "$n0" ] && [ "$(md5sum < "$Y12/01.008.yaml")" = "$n12" ] && o="$o c"
  # d · kaçırma DEĞİL: mühür ✗ + sağlanmadı (mühürdar yakaladı) · mühür ✓ + katılıyorum
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_B --gereklilik G1 --muhur ✗ --sultan saglanmadi --kaynak teslim:karar-B >/dev/null 2>&1
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_B --gereklilik G2 --muhur ✓ --sultan katiliyorum --kaynak teslim:karar-B >/dev/null 2>&1
  python3 -c "import yaml,sys;x=yaml.safe_load(open(sys.argv[1]))['isabet'];assert [i['kacirma'] for i in x]==['e','h','h']" "$Y" 2>/dev/null && o="$o d"
  # e · isabet bölümü dosyanın sonunda değilse eklenmez
  printf '{"gorev":"g","satirlar":{"G1":{"sultan":"katiliyorum"}}}' > "$k/kararlar/BZ.json"
  "${E[@]}" bash "$S" isabet BOZUK --gorev g --gereklilik G1 --muhur ✓ --sultan katiliyorum --kaynak teslim:karar-BZ >/dev/null 2>"$k/e"; [ $? -eq 2 ] && grep -q "sonunda değil" "$k/e" && o="$o e"
  # f · 'sağlanmadı' Sultan'ın tek cümlesi (ne argümanda ne kayıtta) olmadan yazılmaz
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_F --gereklilik G1 --muhur ✓ --sultan saglanmadi --kaynak teslim:karar-F >/dev/null 2>&1; [ $? -eq 2 ] && o="$o f"
  # g · 1 kaçırmalı mühür → ders-cikarma (askı yok)
  [ "$("${E[@]}" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["durum"])')" = ders-cikarma ] && o="$o g"
  # h · 2. kaçırmalı mühür (ayrı görev) → askida + gereken üç iş
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_C --gereklilik G3 --muhur ✓ --sultan saglanmadi --g-tur e2e-check --kaynak teslim:karar-C >/dev/null 2>&1
  "${E[@]}" bash "$S" durum MUHURDAR1 > "$k/d" 2>&1; grep -q "^durum: askida" "$k/d" && grep -q "yeniden yeterlilik sınavı" "$k/d" && grep -q "el kitabı güncelleme" "$k/d" && o="$o h"
  # p · mühür kaydı: özlük yoksa rc 3; varsa 'tur: muhur' satırı, isabet sayılmaz
  "${E[@]}" bash "$S" muhur MUHAKKIK --gorev g --verdikt GECTI >/dev/null 2>&1; local rp=$?
  "${E[@]}" bash "$S" muhur MUHURDAR1 --gorev gorev_T1 --verdikt GECTI >/dev/null 2>&1
  [ $rp -eq 3 ] && python3 -c "import yaml,sys;x=yaml.safe_load(open(sys.argv[1]))['isabet'][-1];assert x['tur']=='muhur' and x['gorev']=='gorev_T1'" "$Y" 2>/dev/null && o="$o p"
  # i · pencere MÜHÜR kayıtlarından: Sultan satırı gelmeyen 9 temiz mühür ilk kaçırmayı 10'un dışına iter → askı kalkar
  for i in 2 3 4 5 6 7 8 9; do "${E[@]}" bash "$S" muhur MUHURDAR1 --gorev "gorev_T$i" --verdikt GECTI >/dev/null 2>&1; done
  [ "$("${E[@]}" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["durum"], d["pencere"], d["muhur_sayisi"])')" = "ders-cikarma 10 12" ] && o="$o i"
  # j · eşik tarif kaydından okunur (3/4), kayıt yoksa S10 varsayılanı (2/10)
  local Y2="$k/y2"; mkdir -p "$Y2"; cp "$k/sicil/01.008.yaml" "$Y2/"
  for x in X1 X2; do env SICIL_DIZIN="$Y2" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" isabet MUHURDAR1 --gorev "gorev_$x" --gereklilik G1 --muhur ✓ --sultan saglanmadi --kaynak "teslim:karar-$x" >/dev/null 2>&1; done
  [ "$(env SICIL_DIZIN="$Y2" TARIF_KAYDI="$k/tarif.json" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["durum"],d["esik"]["pencere"],d["esik_kaynagi"])')" = "ders-cikarma 4 tarif kaydı" ] \
    && [ "$(env SICIL_DIZIN="$Y2" TARIF_KAYDI="$k/yok.json" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["durum"])')" = askida ] && o="$o j"
  # k · ders: aynı tür ≥2 AYRI görevde → tekrar eden (Sultan'ın cümleleri, D-002); tek görevli tür tekrar sayılmaz
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_L --gereklilik G1 --muhur ✓ --sultan saglanmadi --g-tur cmd --kaynak teslim:karar-L >/dev/null 2>&1
  "${E[@]}" bash "$S" ders MUHURDAR1 > "$k/ders" 2>&1; grep -q "e2e-check: 2 kaçırma · 2 görev — TEKRAR EDEN" "$k/ders" && grep -q 'Sultan: "renk koyu değil"' "$k/ders" \
    && grep -q 'Sultan: "yine koyu değil"' "$k/ders" && grep -q "Ders taslağı (D-002)" "$k/ders" && grep -q "cmd: 1 kaçırma · 1 görev$" "$k/ders" && [ "$(grep -c 'Ders taslağı' "$k/ders")" = 1 ] && o="$o k"
  # l · ders-bagla: günlükte olmayan derse bağlanmaz; olana ters kayıtla bağlanır, özgün satır değişmez, açık listeden düşer
  local ts; ts="$(python3 -c "import yaml,sys;print([x for x in yaml.safe_load(open(sys.argv[1]))['isabet'] if x.get('gorev')=='gorev_A'][0]['ts'])" "$Y")"
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$ts" --ders D-077 >/dev/null 2>&1; local rb=$?
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$ts" --ders D-001 >/dev/null 2>&1; local rg=$?
  [ $rb -eq 2 ] && [ $rg -eq 0 ] && python3 -c "import yaml,sys;x=yaml.safe_load(open(sys.argv[1]))['isabet'];a=[i for i in x if i.get('gorev')=='gorev_A'][0];b=x[-1];assert a['ders'] is None and b['tur']=='ders-bagi' and b['ders']=='D-001'" "$Y" 2>/dev/null \
    && "${E[@]}" bash "$S" ders MUHURDAR1 | grep -q "e2e-check: 1 kaçırma · 1 görev$" && o="$o l"
  # m · kaçırma olmayan satır derse bağlanmaz; aynı kaçırma iki kez bağlanmaz
  local tsh; tsh="$(python3 -c "import yaml,sys;print([x for x in yaml.safe_load(open(sys.argv[1]))['isabet'] if x.get('gorev')=='gorev_B'][0]['ts'])" "$Y")"
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$tsh" --ders D-001 >/dev/null 2>&1; local r5=$?
  "${E[@]}" bash "$S" ders-bagla MUHURDAR1 --isabet-ts "$ts" --ders D-001 >/dev/null 2>&1; local r6=$?
  [ $r5 -eq 2 ] && [ $r6 -eq 2 ] && o="$o m"
  # n · başsız şapka hükmü işaretlenir, yine bu mühürdarın siciline yazılır (S14)
  "${E[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_Z --gereklilik G1 --muhur ✓ --sultan katiliyorum --kaynak teslim:karar-Z --bassiz >/dev/null 2>&1
  python3 -c "import yaml,sys;assert yaml.safe_load(open(sys.argv[1]))['isabet'][-1]['bassiz']=='e'" "$Y" 2>/dev/null && o="$o n"
  # q · teslim-isle: Sultan'ın tek kararı → sınanan her satır (👤 atlanır), mühür ✗ düşen G'de; iki kez işlenmez; kısmi karar ve başkasının mühürü reddedilir
  local c0; c0="$(python3 -c "import yaml,sys;print(len(yaml.safe_load(open(sys.argv[1]))['isabet']))" "$Y")"
  "${E[@]}" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1; local q1=$?
  "${E[@]}" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1; local q2=$?
  "${E[@]}" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-TK --muhur-dir "$k/md" >/dev/null 2>&1; local q3=$?
  "${E[@]}" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md2" >/dev/null 2>&1; local q4=$?
  "${E[@]}" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-W --muhur-dir "$k/md" >/dev/null 2>&1; local q5=$?
  "${E[@]}" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-TN --muhur-dir "$k/md" >/dev/null 2>&1; local q6=$?
  [ $q1 -eq 0 ] && [ $q2 -eq 2 ] && [ $q3 -eq 2 ] && [ $q4 -eq 2 ] && [ $q5 -eq 2 ] && [ $q6 -eq 2 ] && python3 - "$Y" "$c0" <<'PY' 2>/dev/null && o="$o q"
import yaml, sys
x = yaml.safe_load(open(sys.argv[1]))["isabet"][int(sys.argv[2]):]
assert [(i["gereklilik"], i["muhur"], i["sultan"], i["kacirma"]) for i in x] == [("G1", "✗", "katiliyorum", "h"), ("G2", "✓", "saglanmadi", "e")], x
assert x[1]["neden"] == "ton sert" and x[1]["g_tur"] == "llm-yargi" and x[1]["el_kitabi_surum"] == "0.4.0"
PY
  # w · teslim tek yazım (göz #411 tur 3): 2. yazma açılışı düşse de teslim ya TAM yazılır; yerine koyma düşerse dosya aynı, geçici dosya
  #     kalmaz, yeniden deneme geçer — kısmi sicil + 'zaten işlendi' kilidi yok
  local Y6="$k/y6" Y6b="$k/y6b" P="$SD/lib/sicil.py"; mkdir -p "$Y6" "$Y6b"
  printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$Y6/01.008.yaml"; cp "$Y6/01.008.yaml" "$Y6b/"
  env SICIL_DIZIN="$Y6" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" KES_DIZIN="$Y6" KES_N=2 python3 "$k/kes.py" "$P" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1
  env SICIL_DIZIN="$Y6" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1
  local w0; w0="$(md5sum < "$Y6b/01.008.yaml")"
  env SICIL_DIZIN="$Y6b" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" KES_DIZIN="$Y6b" KES_REPLACE=1 python3 "$k/kes.py" "$P" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1; local w1=$?
  local w2; w2="$(md5sum < "$Y6b/01.008.yaml")"; local w3; w3="$(find "$Y6b" -type f ! -name '.*.kilit' | wc -l)"
  env SICIL_DIZIN="$Y6b" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1; local w4=$?
  [ $w1 -eq 3 ] && [ "$w2" = "$w0" ] && [ "$w3" = 1 ] && [ $w4 -eq 0 ] && python3 - "$Y6/01.008.yaml" "$Y6b/01.008.yaml" <<'PY' 2>/dev/null && o="$o w"
import yaml, sys
for p in sys.argv[1:]:
    assert [i["gereklilik"] for i in yaml.safe_load(open(p))["isabet"]] == ["G1", "G2"], p
PY
  # x · teslim yolunda da hüküm yalnız katiliyorum|saglanmadi (göz #411 tur 3): kayıttaki geçersiz değer sicile yazılmaz
  local Y7="$k/y7"; mkdir -p "$Y7"; printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$Y7/01.008.yaml"
  local x0; x0="$(md5sum < "$Y7/01.008.yaml")"
  env SICIL_DIZIN="$Y7" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" teslim-isle MUHURDAR1 --kaynak teslim:karar-TV --muhur-dir "$k/md" >/dev/null 2>"$k/e"
  [ $? -eq 2 ] && grep -q "geçersiz hüküm: G2" "$k/e" && [ "$(md5sum < "$Y7/01.008.yaml")" = "$x0" ] && o="$o x"
  # y · eşzamanlı yazım (göz #411 tur 4): okuma→yerine koyma kilitli — geciktirilmiş iki mühür kaydı birbirini silmez; aynı kararı
  #     işleyen iki eşzamanlı teslim-isle'den yalnız biri yazar (zaten-işlendi denetimi kilidin içinde)
  local Y9="$k/y9" Y9b="$k/y9b"; mkdir -p "$Y9" "$Y9b"
  printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$Y9/01.008.yaml"; cp "$Y9/01.008.yaml" "$Y9b/"
  env SICIL_DIZIN="$Y9" KES_DIZIN="$k/yok" KES_GECIK=0.6 python3 "$k/kes.py" "$P" muhur MUHURDAR1 --gorev gorev_Y1 --verdikt GECTI >/dev/null 2>&1 &
  local yp1=$!
  env SICIL_DIZIN="$Y9" KES_DIZIN="$k/yok" KES_GECIK=0.6 python3 "$k/kes.py" "$P" muhur MUHURDAR1 --gorev gorev_Y2 --verdikt GECTI >/dev/null 2>&1 &
  local yp2=$!; wait $yp1; local y1=$?; wait $yp2; local y2=$?
  env SICIL_DIZIN="$Y9b" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" KES_DIZIN="$k/yok" KES_GECIK=0.6 python3 "$k/kes.py" "$P" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1 &
  local yp3=$!
  env SICIL_DIZIN="$Y9b" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" KES_DIZIN="$k/yok" KES_GECIK=0.6 python3 "$k/kes.py" "$P" teslim-isle MUHURDAR1 --kaynak teslim:karar-T --muhur-dir "$k/md" >/dev/null 2>&1 &
  local yp4=$!; wait $yp3; local y3=$?; wait $yp4; local y4=$?
  [ $y1 -eq 0 ] && [ $y2 -eq 0 ] && [ "$((y3 + y4))" -eq 2 ] && python3 - "$Y9/01.008.yaml" "$Y9b/01.008.yaml" <<'PY' 2>/dev/null && o="$o y"
import yaml, sys
assert sorted(i["gorev"] for i in yaml.safe_load(open(sys.argv[1]))["isabet"]) == ["gorev_Y1", "gorev_Y2"]
assert [i["gereklilik"] for i in yaml.safe_load(open(sys.argv[2]))["isabet"]] == ["G1", "G2"]
PY
  # z · muhurdar.sh: özlük VARKEN sicil yazımı düşerse sessiz değil — rc 5 + özette 'sicil: dusmedi'; özlük/sicil yoksa atlanır (rc mühürün)
  local Y8="$k/y8"; mkdir -p "$Y8"
  printf 'personel_no: "01.008"\npersona: MUHURDAR1\nisabet: []\ngecmis: []\n' > "$Y8/01.008.yaml"   # isabet sonda değil → yazılamaz
  env PATH="$ND:$PATH" SICIL_DIZIN="$Y8" AGENT_NAME=MUHURDAR1 bash "$SD/muhurdar.sh" is-r --gereklilik "$k/is/g/GEREKLILIK.md" --worktree "$k/is" --out "$k/out-z" --yazan HENDESE >/dev/null 2>&1; local z1=$?
  env PATH="$ND:$PATH" SICIL_DIZIN="$k/sicil-yok" AGENT_NAME=MUHURDAR1 bash "$SD/muhurdar.sh" is-r --gereklilik "$k/is/g/GEREKLILIK.md" --worktree "$k/is" --out "$k/out-z2" --yazan HENDESE >/dev/null 2>&1; local z2=$?
  [ $z1 -eq 5 ] && [ $z2 -eq 0 ] && python3 - "$k/out-z/muhur-ozet.json" "$k/out-z2/muhur-ozet.json" <<'PY' 2>/dev/null && o="$o z"
import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
assert a["verdikt"] == "GECTI" and a["sicil"].startswith("dusmedi:") and "sonunda değil" in a["sicil"] and "sicil" not in b
PY
  # k2 · iki tekrar eden tür → iki AYRI ders kimliği (D-002 · D-003), bağlama komutları da kendi kimliğiyle (göz #411 tur 5)
  local Y10="$k/y10"; mkdir -p "$Y10"; printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$Y10/01.008.yaml"
  local E10=(env SICIL_DIZIN="$Y10" EL_KITABI="$k/EL.md" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh")
  "${E10[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --g-tur e2e-check --kaynak teslim:karar-A >/dev/null 2>&1
  "${E10[@]}" bash "$S" isabet MUHURDAR1 --gorev gorev_C --gereklilik G3 --muhur ✓ --sultan saglanmadi --g-tur e2e-check --kaynak teslim:karar-C >/dev/null 2>&1
  for x in X1 X2; do "${E10[@]}" bash "$S" isabet MUHURDAR1 --gorev "gorev_$x" --gereklilik G1 --muhur ✓ --sultan saglanmadi --g-tur cmd --kaynak "teslim:karar-$x" >/dev/null 2>&1; done
  "${E10[@]}" bash "$S" ders MUHURDAR1 > "$k/ders2" 2>&1
  [ "$(grep -c 'Ders taslağı (D-00[23])' "$k/ders2")" = 2 ] && grep -q "Ders taslağı (D-002)" "$k/ders2" && grep -q "Ders taslağı (D-003)" "$k/ders2" \
    && [ "$(grep -c -- '--ders D-002 ' "$k/ders2")" = 1 ] && [ "$(grep -c -- '--ders D-003 ' "$k/ders2")" = 1 ] \
    && [ "$("${E10[@]}" bash "$S" ders MUHURDAR1 --json | python3 -c 'import json,sys;print(" ".join(sorted(json.load(sys.stdin)["ders_kimlikleri"].values())))')" = "D-002 D-003" ] && o="$o k2"
  # s · pencere mühür OLAYI sayar: aynı görevin 10 yeniden mühürü eski iki kaçırmayı pencere dışına iter → temiz
  local Y4="$k/y4"; mkdir -p "$Y4"; printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$Y4/01.008.yaml"   # boş özlük
  for x in X1 X2; do env SICIL_DIZIN="$Y4" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" isabet MUHURDAR1 --gorev "gorev_$x" --gereklilik G1 --muhur ✓ --sultan saglanmadi --kaynak "teslim:karar-$x" >/dev/null 2>&1; done
  local s1; s1="$(env SICIL_DIZIN="$Y4" TARIF_KAYDI="$k/yok.json" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["durum"])')"
  for i in 1 2 3 4 5 6 7 8 9 10; do env SICIL_DIZIN="$Y4" bash "$S" muhur MUHURDAR1 --gorev gorev_R --verdikt GECTI >/dev/null 2>&1; done
  [ "$s1" = askida ] && [ "$(env SICIL_DIZIN="$Y4" TARIF_KAYDI="$k/yok.json" bash "$S" durum MUHURDAR1 --json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["durum"],d["muhur_sayisi"])')" = "temiz 12" ] && o="$o s"
  # u · Sultan'ın cümlesi değiştirilemez: --neden kayıttakinden farklıysa rc 2, yazılmaz
  env SICIL_DIZIN="$Y12" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" isabet MUHURDAR1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --neden "Sultan bunu demedi" --kaynak teslim:karar-A >/dev/null 2>&1
  [ $? -eq 2 ] && [ "$(md5sum < "$Y12/01.008.yaml")" = "$n12" ] && o="$o u"
  # aa · aynı Sultan kaydının aynı satırı iki kez yazılmaz (iki kaçırma sayılırdı) — denetim kilidin içinde
  local Y11="$k/y11"; mkdir -p "$Y11"; printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$Y11/01.008.yaml"
  env SICIL_DIZIN="$Y11" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" isabet MUHURDAR1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --kaynak teslim:karar-A >/dev/null 2>&1; local a1=$?
  env SICIL_DIZIN="$Y11" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" bash "$S" isabet MUHURDAR1 --gorev gorev_A --gereklilik G2 --muhur ✓ --sultan saglanmadi --kaynak teslim:karar-A >/dev/null 2>&1; local a2=$?
  [ $a1 -eq 0 ] && [ $a2 -eq 2 ] && [ "$(python3 -c "import yaml,sys;print(len(yaml.safe_load(open(sys.argv[1]))['isabet']))" "$Y11/01.008.yaml")" = 1 ] && o="$o aa"
  # v · Türkçe harf: özlükte 'MUHAKKİK', çağrıda 'MUHAKKIK' → aynı kişi (casefold İ'yi i̇ yapar, eşleşmezdi)
  local Y5="$k/y5"; mkdir -p "$Y5"; printf 'personel_no: "01.020"\npersona: MUHAKKİK\ngecmis: []\n' > "$Y5/01.020.yaml"
  env SICIL_DIZIN="$Y5" bash "$S" muhur MUHAKKIK --gorev g --verdikt GECTI >/dev/null 2>&1 && env SICIL_DIZIN="$Y5" bash "$S" muhur muhakkik --gorev g2 --verdikt GECTI >/dev/null 2>&1 && o="$o v"
  # r · muhurdar.sh her mühürde mühürdarın siciline 'tur: muhur' satırı yazar (pencere bundan sayılır)
  local Y3="$k/y3"; mkdir -p "$Y3"; cp "$k/sicil/01.008.yaml" "$Y3/"
  env PATH="$ND:$PATH" SICIL_DIZIN="$Y3" AGENT_NAME=MUHURDAR1 bash "$SD/muhurdar.sh" is-r --gereklilik "$k/is/g/GEREKLILIK.md" --worktree "$k/is" --out "$k/out-r" --yazan HENDESE >/dev/null 2>&1
  python3 -c "import yaml,sys;x=yaml.safe_load(open(sys.argv[1]))['isabet'][-1];assert x['tur']=='muhur' and x['gorev']=='is-r' and x['verdikt']=='GECTI'" "$Y3/01.008.yaml" 2>/dev/null && o="$o r"
  echo "$o"
}
_k() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

echo "════ G11 · S10 · Mühürdarlık sicil · ders çıkarma · askı (sicil.sh) ════"
S0="$(_sen "$HERE")"
_k a "$S0"; g $? "a isabet Sultan'ın DOĞRULANMIŞ kaydıyla yazılır (kaçırma = mühür ✓ + sağlanmadı; cümle kayıttan), öbür alanlar korunur"
_k b "$S0"; g $? "b özlük dosyası yoksa (MUHAKKİK vakası) yazılmaz, rc 3, hiçbir dosya değişmez"
_k c "$S0"; g $? "c A06: doğrulayıcı yoksa rc 3 · uydurma kaynak rc 2 · kayıt satırı doğrulamıyorsa (hüküm ya da görev farklı) rc 2 — yazılmaz"
_k d "$S0"; g $? "d kaçırma değil: mühür ✗ + sağlanmadı (mühürdar yakaladı) · mühür ✓ + katılıyorum"
_k e "$S0"; g $? "e isabet bölümü dosyanın sonunda değilse eklenmez (YAML bozulmasın)"
_k f "$S0"; g $? "f 'sağlanmadı' Sultan'ın tek cümlesi olmadan yazılmaz"
_k g "$S0"; g $? "g 1 kaçırmalı mühür → ders-cikarma, askı yok (S10)"
_k h "$S0"; g $? "h son 10'da 2 kaçırmalı mühür → askida + el kitabı güncelleme + yeniden sınav (S10)"
_k p "$S0"; g $? "p mühür kaydı: özlük yoksa rc 3; varsa 'tur: muhur' satırı (isabet sayılmaz)"
_k i "$S0"; g $? "i pencere MÜHÜR kayıtlarından: Sultan satırı gelmeyen temiz mühürler de pencereyi ilerletir → askı kalkar"
_k j "$S0"; g $? "j eşik tarif kaydından okunur (3/4 → askı yok), kayıt yoksa S10 varsayılanı (2/10 → askı)"
_k k "$S0"; g $? "k ders çıkarma: aynı tür ≥2 ayrı görevde = tekrar eden → D-002 taslağı Sultan'ın cümleleriyle; tek görevli tür sayılmaz"
_k k2 "$S0"; g $? "k2 iki tekrar eden tür → iki ayrı ders kimliği (D-002 · D-003), bağlama komutları kendi kimliğiyle"
_k l "$S0"; g $? "l ders-bagla: günlükte olmayan derse bağlanmaz; olana ters kayıtla bağlanır, özgün satır değişmez"
_k m "$S0"; g $? "m kaçırma olmayan satır derse bağlanmaz; aynı kaçırma iki kez bağlanmaz"
_k n "$S0"; g $? "n başsız şapka hükmü işaretli (bassiz e), yine bu mühürdarın siciline yazılır (S14)"
_k q "$S0"; g $? "q teslim-isle: Sultan'ın tek kararı → sınanan her satır (👤 atlanır, düşen G'de mühür ✗); tekrar · kısmi karar · başkasının mühürü · başka görevin mühürü · cümlesiz sağlanmadı reddedilir"
_k w "$S0"; g $? "w teslim tek yazım: 2. yazım açılışı düşse de teslim tam; yerine koyma düşerse dosya aynı, geçici dosya kalmaz, yeniden deneme geçer"
_k x "$S0"; g $? "x teslim yolunda geçersiz hüküm (katiliyorum|saglanmadi dışı) sicile yazılmaz, rc 2"
_k y "$S0"; g $? "y eşzamanlı yazım kilitli: geciktirilmiş iki mühür kaydı ikisi de durur; aynı kararla iki eşzamanlı teslimden yalnız biri yazar"
_k z "$S0"; g $? "z muhurdar.sh: özlük varken sicil yazımı düşerse rc 5 + özette 'sicil: dusmedi'; özlük/sicil yoksa atlanır, rc mühürün"
_k s "$S0"; g $? "s pencere mühür OLAYI sayar: aynı görevin 10 yeniden mühürü eski kaçırmaları dışarı iter (askida → temiz)"
_k u "$S0"; g $? "u Sultan'ın cümlesi kayıttan gelir; farklı --neden ile yazılmaz (A06)"
_k aa "$S0"; g $? "aa aynı Sultan kaydının aynı satırı iki kez yazılmaz (iki kaçırma sayılırdı)"
_k v "$S0"; g $? "v Türkçe harf katlama: özlükte MUHAKKİK, çağrıda MUHAKKIK/muhakkik → aynı kişi"
_k r "$S0"; g $? "r muhurdar.sh her mühürde mühürdarın siciline mühür kaydı yazar"

echo "── MUTASYON (tescil kopyasında, kontrol şartlı) ──"
_kopya() { local d="$T/m-$1"; mkdir -p "$d"; cp -r "$HERE/.." "$d/tescil"; echo "$d/tescil/scripts"; }
k0="$(_kopya kontrol)"; [ "$(_sen "$k0")" = "$S0" ] && [ -n "$S0" ]; g $? "kontrol kopyası gerçek betikle aynı kapıları geçiyor"
_m() {  # _m <anahtar> <dosya> <eski> <yeni> <açıklama>
  local d; d="$(_kopya "$1-$RANDOM")"
  python3 - "$d/$2" "$3" "$4" <<'PY' || { g 1 "mutant ($5): desen tutmadı"; return; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding='utf-8').read(); o=s; s=s.replace(a,b,1); assert s!=o; open(p,'w',encoding='utf-8').write(s)
PY
  ! _k "$1" "$(_sen "$d")"; g $? "mutant ($5) → '$1' kapısı düşüyor"
}
_m c lib/sicil.py '    if not komut:
        hata(' '    if not komut:
        return {"gorev": "gorev_A", "satirlar": {"G2": {"sultan": "saglanmadi", "neden": "uyduruldu"}}}
        hata(' "doğrulayıcı yoksa hüküm uyduruluyor (A06)"
_m c lib/sicil.py '    if karar.get("gorev") != a["gorev"] or ks.get("sultan") != a["sultan"]:' '    if False:' "kayıt satırı doğrulamasa da yazılıyor"
_m b lib/sicil.py '    if not bulunan:
        hata(' '    if not bulunan:
        return os.path.join(SICIL_DIZIN, ad + ".yaml")
        hata(' "özlük yoksa yeni dosya açıyor"
_m d lib/sicil.py '"kacirma": "e" if (a["muhur"] == "✓" and a["sultan"] == "saglanmadi") else "h",' '"kacirma": "e" if a["sultan"] == "saglanmadi" else "h",' "mühürdarın yakaladığı da kaçırma sayılıyor"
_m i lib/sicil.py '        if not isinstance(x, dict) or x.get("tur") not in (None, "muhur"):' '        if not isinstance(x, dict) or x.get("tur") is not None:' "pencere mühür kayıtlarını saymıyor"
_m j lib/sicil.py '    try:
        with open(TARIF_KAYDI' '    return VARSAYILAN_ESIK, "varsayılan (Sultan S10)"
    try:
        with open(TARIF_KAYDI' "eşik tarif kaydından okunmuyor"
_m k lib/sicil.py 'len({x.get("gorev") for x in xs}) >= 2}' 'len(xs) >= 1}' "tek kaçırma da tekrar eden sayılıyor"
_m l lib/sicil.py '    if a["ders"] not in gunluk_dersleri():' '    if False:' "günlükte olmayan derse bağlanıyor"
_m k2 lib/sicil.py 'f"D-{taban + i:03d}" for i, t in enumerate(tekrar)}' 'sonraki for t in tekrar}' "tekrar eden türlerin hepsi aynı ders kimliğini alıyor"
_m e lib/sicil.py '    if "isabet" in ust and ust[-1] != "isabet":' '    if False:' "isabet sonda değilken ekleniyor"
_m q lib/sicil.py 'sinanan = [g for g in ger["g"] if g["tur"] != "sultan-denemesi"]' 'sinanan = list(ger["g"])' "teslim-isle 👤 satırına da isabet yazıyor"
_m q lib/sicil.py '        if any(x.get("kaynak") == a["kaynak"].strip() for x in isabetler(d)[0]):' '        if False:' "aynı teslim iki kez işleniyor"
_m q lib/sicil.py '    if oz.get("kart") != karar["gorev"]:' '    if False:' "teslim-isle başka görevin mühürünü kabul ediyor"
_m w lib/sicil.py '    ekle_toplu(yol, satirlar, islenmedi)   # tek yazım: kısmi teslim olmaz' '    [ekle_toplu(yol, [s_], islenmedi if i == 0 else None) for i, s_ in enumerate(satirlar)]' "teslim satır satır yazılıyor (yarıda kalırsa kısmi sicil)"
_m w lib/sicil.py '            os.unlink(gecici)' '            pass' "yarıda kalan yazım geçici dosyayı bırakıyor"
_m x lib/sicil.py '    if gecersiz:' '    if False:' "teslim yolunda geçersiz hüküm yazılıyor"
_m y lib/sicil.py '    fcntl.flock(kilit, fcntl.LOCK_EX)' '    pass' "yazım kilitsiz (eşzamanlı iki yazım birbirini siler)"
_m y lib/sicil.py '    if onkosul:
        onkosul(oku(yol))' '    pass' "kilit içi zaten-işlendi denetimi düşüyor"
_m z muhurdar.sh '    rc=5' '    :' "muhurdar.sh düşen sicil yazımını yutuyor"
_m z muhurdar.sh ' --yoksa-gec \' ' \' "özlüğü olmayan mühürdar da 'düşmedi' sayılıyor"
_m s lib/sicil.py '        if x.get("tur") == "muhur" or x.get("gorev") not in son:' '        if x.get("gorev") not in son:' "pencere olay yerine görev sayıyor"
_m u lib/sicil.py '    if a.get("neden") and (a["neden"].strip() != (ks.get("neden") or "").strip()):' '    if False:' "Sultan'ın cümlesi değiştirilebiliyor"
_m aa lib/sicil.py '               for x in isabetler(d)[0]):' '               for x in []):' "aynı isabet iki kez yazılıyor"
_m m lib/sicil.py 'for b in isabetler(d)[1]):' 'for b in []):' "aynı kaçırma iki derse bağlanıyor"
_m v lib/sicil.py '    return (ad or "").strip().replace("İ", "I").replace("ı", "i").casefold()' '    return (ad or "").strip().casefold()' "Türkçe harf katlanmıyor"
_m r muhurdar.sh 'if [ -n "$_VER" ] && [ "$_VER" != RED ]; then' 'if false; then' "muhurdar.sh siciline mühür kaydı yazmıyor"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
