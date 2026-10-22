#!/usr/bin/env bash
# diploma.test.sh — Mühürdarlık diploma sınavı (G13) sınavı: diploma.sh + lib/diploma.py, gerçek muhurdar.sh/tescil-run üstünde.
# HERMETİK: sahte yargıçlar (PATH başında claude), geçici defter/katalog/sicil; gerçek model ve gerçek defter YOK.
# Kapılar fonksiyonda; geçen kapıların anahtarını basar. Gerçek betiklerde hepsi geçer; mutant kopyada hedef anahtar düşer.
# kabuk-testleri: sure=600
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUME="$(cd "$HERE/../sinav" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
ND="$(dirname "$(command -v node)")"; PY="$(dirname "$(command -v python3)")"
[ -n "$ND" ] || { echo "ÖLÇÜLEMEDİ: node yok"; exit 4; }

# sahte yargıçlar — istemi stdin'den okur (claude -p < istem), istemi saklar
mkdir -p "$T/y-durust" "$T/y-lastik" "$T/y-hepkaldi" "$T/y-bozuk"
cat > "$T/y-durust/claude" <<EOF
#!/usr/bin/env bash
i="\$(cat)"; n=\$(( \$(cat "$T/istem-n" 2>/dev/null || echo 0) + 1 )); echo \$n > "$T/istem-n"; printf '%s' "\$i" > "$T/istem-\$n.md"
if printf '%s' "\$i" | grep -qE 'çarpımlarını|FAILED \(|42 ms'; then k=KALDI; else k=GECTI; fi
printf '{"structured_output":{"karar":"%s","not":"sahte dürüst yargıç"}}' "\$k"
EOF
for y in lastik:GECTI hepkaldi:KALDI; do
  printf '#!/usr/bin/env bash\ncat >/dev/null\necho \x27{"structured_output":{"karar":"%s","not":"sabit"}}\x27\n' "${y#*:}" > "$T/y-${y%%:*}/claude"
done
printf '#!/usr/bin/env bash\ncat >/dev/null; echo bozuk-cevap\n' > "$T/y-bozuk/claude"
chmod +x "$T"/y-*/claude

# kusur başka G'de düşen küme (alt küme kuralı): beklenen G2, ama düşen yalnız G1
mkdir -p "$T/kume-yanlis-g"; cp -r "$KUME/dogru" "$KUME/uydurma" "$T/kume-yanlis-g/"; mkdir -p "$T/kume-yanlis-g/kusurlu"
cp -r "$KUME/kusurlu/eksik-cikti" "$T/kume-yanlis-g/kusurlu/baska-g"
printf '{"verdikt":"KALDI","kaldi":["G2"],"neden":"kusur G2de"}\n' > "$T/kume-yanlis-g/kusurlu/baska-g/beklenen.json"
mkdir -p "$T/kume-eksik"; cp -r "$KUME/dogru" "$KUME/kusurlu" "$T/kume-eksik/"; mkdir -p "$T/kume-eksik/uydurma"
printf '{"skills":[{"id":"tescil","version":"9.9.9"}]}\n' > "$T/katalog.json"
kume_iz() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum); }

_d() {  # _d <scripts-dir> <yargıç> <defter> [ortam…] -- diploma argümanları
  local s="$1" y="$2" df="$3"; shift 3; local ev=(); while [ "$1" != -- ]; do ev+=("$1"); shift; done; shift
  rm -f "$T"/istem-*
  mkdir -p "$T/tmp"; env TMPDIR="$T/tmp" PATH="$T/$y:$ND:$PY:/usr/bin:/bin" MUHURDAR_MODEL=claude DIPLOMA_DEFTERI="$df" TESCIL_KATALOG="$T/katalog.json" \
    SICIL_DIZIN="$T/sicil" ${ev[@]+"${ev[@]}"} bash "$s/diploma.sh" "$@" > "$T/son.log" 2>&1
}
_son() { tail -1 "$1" 2>/dev/null; }
_sen() {  # _sen <scripts-dir> → geçen kapı anahtarları
  local s="$1" o="" D="$T/defter/d.jsonl" r
  find "$T/defter" "$T/sicil" -mindepth 1 -delete 2>/dev/null; mkdir -p "$T/defter" "$T/sicil"
  printf 'persona: MUHAKKİK\npersonel_no: 01.099\n' > "$T/sicil/01.099.yaml"; local sic_once; sic_once="$(sha256sum "$T/sicil/01.099.yaml")"
  local iz_once; iz_once="$(kume_iz "$KUME")"
  # a · dürüst mühürdar: 6/6 isabet → GEÇTİ, §6 satırı tam alanlarla
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kanit "$T/kanit-a"; r=$?
  [ $r -eq 0 ] && [ "$(wc -l < "$D")" = 1 ] && python3 - "$D" 2>/dev/null <<'PY' && o="$o a"
import json, re, sys
d = json.loads(open(sys.argv[1]).readline())
assert set(d) == {"ts", "personel", "uzmanlik", "el_kitabi", "el_kitabi_surum", "kume_sha", "sonuc", "gecti", "kanit"}, d
assert d["personel"] == "MUHAKKİK" and d["uzmanlik"] == "muhurdarlik" and d["el_kitabi"] == "tescil"
assert d["el_kitabi_surum"] == "9.9.9" and re.fullmatch(r"[0-9a-f]{64}", d["kume_sha"]) and d["gecti"] == "e"
assert d["sonuc"] == {"dogru": "2/2", "kusurlu": "2/2", "uydurma": "2/2"}, d["sonuc"]
PY
  [ -f "$T/kanit-a/sonuc.json" ] && [ "$(ls "$T/kanit-a"/*.MUHUR.md 2>/dev/null | wc -l)" = 6 ] \
    && python3 -c "import json,sys;d=json.load(open(sys.argv[1]))['ornekler'];assert all(v['yargic']=='G2=claude' for v in d.values()) and any(v['oznel_notlar'] for v in d.values())" "$T/kanit-a/sonuc.json" 2>/dev/null && o="$o a2"
  # n · yargıç cevap anahtarını görmez: beklenen.json'un 'neden' cümleleri hiçbir isteme girmez
  [ "$(cat "$T/istem-n" 2>/dev/null)" -ge 5 ] && ! grep -qE "çarpar diyor|riskler bölümü yok|2 FAIL \+ 1 ERROR|hiçbirinin komutu" "$T"/istem-*.md && o="$o n"
  # e2 · telemetri geçici köke gitti (her örnek bir satır), gerçek tescil telemetrisine değil
  python3 -c "import json,sys;assert json.load(open(sys.argv[1]))['telemetri_gecici_satir']==6" "$T/kanit-a/sonuc.json" 2>/dev/null && o="$o e2"
  # e · sınav gerçek sicile ve kümeye dokunmaz (telemetri/çıktı geçici kökte)
  [ "$(sha256sum "$T/sicil/01.099.yaml")" = "$sic_once" ] && [ "$(ls "$T/sicil")" = 01.099.yaml ] && [ "$(kume_iz "$KUME")" = "$iz_once" ] && o="$o e"
  # b · lastik mühür (hep GEÇTİ): kusurlu öznel + iki uydurma kaçar → KALDI
  _d "$s" y-lastik "$D" -- sina MUHAKKİK; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['gecti']=='h' and d['sonuc']=={'dogru':'2/2','kusurlu':'1/2','uydurma':'0/2'},d" "$D" 2>/dev/null && o="$o b"
  # c · hep KALDI: doğru teslimleri de düşürür → KALDI
  _d "$s" y-hepkaldi "$D" -- sina MUHAKKİK; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['sonuc']['dogru']=='0/2' and d['gecti']=='h',d" "$D" 2>/dev/null && o="$o c"
  # d · bozuk yargıç → EMIN-DEGILIM (eskalasyon) hiçbir türde isabet değil, çökme yok
  _d "$s" y-bozuk "$D" -- sina MUHAKKİK; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['sonuc']=={'dogru':'0/2','kusurlu':'1/2','uydurma':'0/2'},d" "$D" 2>/dev/null && o="$o d"
  # l · kusur başka G'de düştü → isabet sayılmaz (yanlış sebeple KALDI)
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kume "$T/kume-yanlis-g"; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['sonuc']['kusurlu']=='0/1',d" "$D" 2>/dev/null && o="$o l"
  local n_once; n_once="$(wc -l < "$D")"
  # o · son koşu kaldı → önceki geçen diploma DÜŞER (yenilenen sınavı kaldıran geçerli görünmez)
  _d "$s" y-durust "$D" -- durum MUHAKKİK; [ $? -eq 1 ] && grep -q "durum: yok" "$T/son.log" && grep -q "DÜŞTÜ" "$T/son.log" && o="$o o"
  # f · türü boş küme → koşulmaz, deftere yazılmaz
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kume "$T/kume-eksik"; r=$?
  [ $r -eq 3 ] && [ "$(wc -l < "$D")" = "$n_once" ] && grep -q "uydurma" "$T/son.log" && o="$o f"
  # g · defter dizini yok → ölçülemedi
  _d "$s" y-durust "$T/yok/d.jsonl" -- sina MUHAKKİK; [ $? -eq 3 ] && [ ! -e "$T/yok" ] && o="$o g"
  # j · sınavın yazan adıyla personel → kullanım
  _d "$s" y-durust "$D" -- sina diploma-sınavı; [ $? -eq 2 ] && [ "$(wc -l < "$D")" = "$n_once" ] && o="$o j"
  _d "$s" y-durust "$D" -- sina MUHAKKİK; [ $? -eq 0 ] || echo "  (yeniden geçen koşu düştü)" >&2
  # h · durum: geçerli → katalog sürümü değişince bayat → katalog yoksa SKILL.md'ye düşer ve söyler
  _d "$s" y-durust "$D" -- durum MUHAKKİK; r=$?; [ $r -eq 0 ] && grep -q "durum: gecerli" "$T/son.log" && o="$o h"
  printf '{"skills":[{"id":"tescil","version":"9.9.10"}]}\n' > "$T/katalog.json"
  _d "$s" y-durust "$D" -- durum MUHAKKİK; r=$?; [ $r -eq 1 ] && grep -q "durum: bayat" "$T/son.log" && grep -q "9.9.9 → 9.9.10" "$T/son.log" && o="$o h2"
  _d "$s" y-durust "$D" TESCIL_KATALOG="$T/katalog-yok.json" -- durum MUHAKKİK; r=$?
  [ $r -eq 1 ] && grep -q "SKILL.md (katalog okunamadı)" "$T/son.log" && o="$o h3"
  printf '{"skills":[{"id":"tescil","version":"9.9.9"}]}\n' > "$T/katalog.json"
  # h4 · sınav kümesi değişince (yeni örnek / değişen rubrik) diploma bayat
  find "$T/kume-degisik" -mindepth 1 -delete 2>/dev/null; mkdir -p "$T/kume-degisik"; cp -r "$KUME/." "$T/kume-degisik/"
  echo "ek kural" >> "$T/kume-degisik/kusurlu/eksik-cikti/rubrik.md"
  _d "$s" y-durust "$D" -- durum MUHAKKİK --kume "$T/kume-degisik"; [ $? -eq 1 ] && grep -q "durum: bayat" "$T/son.log" && grep -q "sınav kümesi değişti" "$T/son.log" && o="$o h4"
  # k · Türkçe ad katlaması: MUHAKKIK yazımı MUHAKKİK'in diplomasını bulur; başka ad bulmaz
  _d "$s" y-durust "$D" -- durum MUHAKKIK; [ $? -eq 0 ] && o="$o k"
  _d "$s" y-durust "$D" -- durum HENDESE; [ $? -eq 1 ] && grep -q "durum: yok" "$T/son.log" && o="$o k2"
  # m · defter yok → durum ölçülemedi (yok DEĞİL)
  _d "$s" y-durust "$T/defter/yok.jsonl" -- durum MUHAKKİK; [ $? -eq 3 ] && o="$o m"
  # i · sicil askıda → diploma askıda (sahte sicil.py ile)
  cp "$s/lib/sicil.py" "$T/sicil.py.yedek" 2>/dev/null || : > "$T/sicil.py.yedek-yok"
  printf 'import json\nprint(json.dumps({"durum":"askida"}))\n' > "$s/lib/sicil.py"
  _d "$s" y-durust "$D" -- durum MUHAKKİK; r=$?; [ $r -eq 1 ] && grep -q "durum: askida" "$T/son.log" && grep -q "yeniden sınav" "$T/son.log" && o="$o i"
  if [ -f "$T/sicil.py.yedek" ]; then cp "$T/sicil.py.yedek" "$s/lib/sicil.py"; rm -f "$T/sicil.py.yedek"; else rm -f "$s/lib/sicil.py" "$T/sicil.py.yedek-yok"; fi
  echo "$o"
}
BEK="a a2 n e e2 b c d l o f g j h h2 h3 h4 k k2 m i"
# gerçek betikler bir kopyada koşulur (kapı i sahte sicil.py yazar — gerçek dosyaya dokunmamak için); el kitabı kökü aynı kalır
_kopya_gercek() { local d="$T/gercek/scripts"; mkdir -p "$d"; cp -r "$HERE/." "$d/"; cp "$HERE/../SKILL.md" "$T/gercek/SKILL.md"; ln -s "$KUME" "$T/gercek/sinav"; echo "$d"; }
echo "── gerçek betikler"
GS="$(_kopya_gercek)"; GER="$(_sen "$GS")"
for k in $BEK; do case " $GER " in *" $k "*) g 0 "kapı $k" ;; *) g 1 "kapı $k" ;; esac; done

# ── mutasyonlar: her biri gerçek kopyada tek satır bozar; hedef kapı düşmeli ─────────────────────────────
_mut() {  # _mut <ad> <hedef-kapı> <python-replace: eski> <yeni>
  local d="$T/m-$1"; mkdir -p "$d/scripts"; cp -r "$GS/." "$d/scripts/"; cp "$T/gercek/SKILL.md" "$d/SKILL.md"; ln -s "$KUME" "$d/sinav"
  python3 - "$d/scripts/lib/diploma.py" "$3" "$4" <<'PY' || { g 1 "mutant $1: çapa tutmadı"; return; }
import sys
p, eski, yeni = sys.argv[1:4]
s = open(p).read()
assert s.count(eski) == 1, "capa"
open(p, "w").write(s.replace(eski, yeni))
PY
  local c; c="$(_sen "$d/scripts")"
  case " $c " in *" $2 "*) g 1 "mutant $1 → kapı $2 hâlâ geçiyor" ;; *) g 0 "mutant $1 → kapı $2 düştü" ;; esac
}
echo "── mutasyonlar"
_mut alt-kume l 'isabet = verdikt == "KALDI" and set(bek.get("kaldi") or []) <= set(dusen)' 'isabet = verdikt == "KALDI"'
_mut eskalasyon-isabet d 'isabet = verdikt == "GECTI"' 'isabet = verdikt != "KALDI"'
# sicil ayrımı yalnız mühürdar sicile yazıyorsa ölçülebilir (yazıcı Sx #411'de) — yoksa ÖLÇÜLEMEDİ der, yeşil saymaz
if grep -q 'sicil.py" muhur' "$HERE/muhurdar.sh"; then
_mut sicil-ayrimi-yok e 'env = dict(os.environ, AGENT_NAME=personel, SICIL_DIZIN=os.path.join(kok, "sicil-yok"))' 'env = dict(os.environ, AGENT_NAME=personel)'
else echo "  ÖLÇÜLEMEDİ mutant sicil-ayrimi-yok: muhurdar.sh sicile yazmıyor (yazıcı Sx #411) — kapı e bugün yalnız sicil dosyasının değişmediğini ölçer"; fi
_mut surum-skill a '                    return s["version"], "katalog"' '                    return skill_surum(), "katalog"'
_mut bayat-yok h2 '    elif d.get("el_kitabi_surum") != surum:' '    elif False:'
_mut aski-yok i '    if sic == "askida":' '    if False:'
_mut ad-katlama-yok k '    return s.strip().replace("İ", "I").replace("ı", "i").casefold()' '    return s.strip().casefold()'
_mut bos-tur f '    if bos:' '    if False:'
_mut defter-yok-yok m '        hata(f"diploma defteri yok: {DEFTER} — ölçülemedi (yok DEĞİL)", 3)' '        satirlar = []'
_mut yargic-izi-yok a2 '                    yargic = satir[8:].strip()' '                    yargic = ""'
_mut son-kosu-yok o '    d = benim[-1]' '    d = ([x for x in benim if x.get("gecti") == "e"] or benim)[-1]'
_mut kume-bayat-yok h4 '    elif d.get("kume_sha") != kume_sha:' '    elif False:'
_mut telemetri-gercek e2 '    k = os.path.join(kok, "_agents", "tescil", kart)' '    k = os.path.join(kok, "x", kart)'
_mut kume-sha a '    return ornekler, h.hexdigest()' '    return ornekler, ""'
echo "diploma.test: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
