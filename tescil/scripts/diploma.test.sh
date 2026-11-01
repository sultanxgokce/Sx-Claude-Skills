#!/usr/bin/env bash
# diploma.test.sh — Mühürdarlık diploma sınavı (G13) sınavı: diploma.sh + lib/diploma.py, gerçek muhurdar.sh/tescil-run üstünde.
# HERMETİK: sahte yargıçlar (PATH başında claude), geçici defter/katalog/sicil; gerçek model ve gerçek defter YOK.
# Kapılar fonksiyonda; geçen kapıların anahtarını basar. Gerçek betiklerde hepsi geçer; mutant kopyada hedef anahtar düşer.
# kabuk-testleri: sure=900
# Süre (CI #412: sıralı 24 senaryo × ~52 sn = 1245 sn, 600 sn tavanında kesildi): gerçek koşu ve her mutant AYRI süreçte, kendi
#   geçici kökü ve sahte yargıçlarıyla paralel koşar (DIPLOMA_PAR, varsayılan min(nproc, 8)). Çocuk kip (--tek) mutant DOĞURMAZ.
# Parça (CI 28 Eki: 4 çekirdekte 31 senaryo 879–884 sn, tavan 900 → rc 124): DIPLOMA_PARCA=k/n verilirse yalnız sıra numarası
#   (gerçek = 0, mutantlar 1…) n'ye bölümünden k-1 kalan senaryolar koşar; gerçek koşu ve onun kapıları 1. parçadadır. Parçaların
#   birleşimi tüm senaryolardır (her senaryo tam bir parçada). Verilmezse 1/1 = hepsi (yerel koşu değişmez). CI: diploma-1 · diploma-2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUME="$(cd "$HERE/../sinav" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
ND="$(dirname "$(command -v node)")"; PY="$(dirname "$(command -v python3)")"
[ -n "$ND" ] || { echo "ÖLÇÜLEMEDİ: node yok"; exit 4; }

# sahte yargıçlar — istemi stdin'den okur (claude -p < istem), istemi saklar
mkdir -p "$T/y-dalgali" "$T/y-durust" "$T/y-lastik" "$T/y-hepkaldi" "$T/y-bozuk"
cat > "$T/y-durust/claude" <<EOF
#!/usr/bin/env bash
i="\$(cat)"; n=\$(( \$(cat "$T/istem-n" 2>/dev/null || echo 0) + 1 )); echo \$n > "$T/istem-n"; printf '%s' "\$i" > "$T/istem-\$n.md"
# n2: yargıcın kendi koşusunun kökünde (iş ağacı + gereklilik dizini + çıktı) cevap anahtarı var mı, istem kümeyi işaret ediyor mu
k="\$(ls -dt "\${TMPDIR:-/tmp}"/diploma-kok-* 2>/dev/null | head -1)"
[ -n "\$k" ] && echo "\$(find "\$k" -name beklenen.json 2>/dev/null | wc -l) \$(printf '%s' "\$i" | grep -c '/sinav/')" >> "$T/anahtar-iz"
if printf '%s' "\$i" | grep -qE 'çarpımlarını|FAILED \(|42 ms|- \[ \]'; then k=KALDI; else k=GECTI; fi
printf '{"structured_output":{"karar":"%s","not":"sahte dürüst yargıç"}}' "\$k"
EOF
# dalgalı yargıç: tek numaralı çağrıda GEÇTİ (ıska üretir), çift numaralıda dürüst — ıskalanan örneğin yeniden koşusu çelişir
cat > "$T/y-dalgali/claude" <<EOF
#!/usr/bin/env bash
i="\$(cat)"; n=\$(( \$(cat "$T/dalga-n" 2>/dev/null || echo 0) + 1 )); echo \$n > "$T/dalga-n"
if [ \$((n % 2)) -eq 0 ] && printf '%s' "\$i" | grep -qE 'çarpımlarını|FAILED \(|42 ms|- \[ \]'; then k=KALDI; else k=GECTI; fi
printf '{"structured_output":{"karar":"%s","not":"dalgalı"}}' "\$k"
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
  # a · dürüst mühürdar: 9/9 isabet (türde 3) → GEÇTİ, §6 satırı tam alanlarla
  rm -f "$T/anahtar-iz"
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kanit "$T/kanit-a"; r=$?
  # n2 · cevap anahtarı yargıcın ağacına HİÇ girmez (göz #420 tur 1): her yargı çağrısında kökte 0 beklenen.json, istemde küme yolu yok
  [ "$(wc -l < "$T/anahtar-iz" 2>/dev/null)" -ge 8 ] && [ "$(sort -u "$T/anahtar-iz")" = "0 0" ] && o="$o n2"
  [ $r -eq 0 ] && [ "$(wc -l < "$D")" = 1 ] && python3 - "$D" 2>/dev/null <<'PY' && o="$o a"
import json, re, sys
d = json.loads(open(sys.argv[1]).readline())
assert set(d) == {"ts", "personel", "uzmanlik", "el_kitabi", "el_kitabi_surum", "kume_sha", "sonuc", "gecti", "kanit"}, d
assert d["personel"] == "MUHAKKİK" and d["uzmanlik"] == "muhurdarlik" and d["el_kitabi"] == "tescil"
assert d["el_kitabi_surum"] == "9.9.9" and re.fullmatch(r"[0-9a-f]{64}", d["kume_sha"]) and d["gecti"] == "e"
assert d["sonuc"] == {"dogru": "3/3", "kusurlu": "3/3", "uydurma": "3/3"}, d["sonuc"]
PY
  [ -f "$T/kanit-a/sonuc.json" ] && [ "$(ls "$T/kanit-a"/*.MUHUR.md 2>/dev/null | wc -l)" = 9 ] \
    && python3 -c "import json,sys;d=json.load(open(sys.argv[1]))['ornekler'];assert all(v['yargic']=='G2=claude' for v in d.values()) and any(v['oznel_notlar'] for v in d.values())" "$T/kanit-a/sonuc.json" 2>/dev/null && o="$o a2"
  # n · yargıç cevap anahtarını görmez: beklenen.json'un 'neden' cümleleri hiçbir isteme girmez
  [ "$(cat "$T/istem-n" 2>/dev/null)" -ge 8 ] && ! grep -qE "çarpar diyor|riskler bölümü yok|2 FAIL \+ 1 ERROR|hiçbirinin komutu|sıfıra bölüp|3 bitti 2 bitmedi|dürüstçe söylüyor" "$T"/istem-*.md && o="$o n"
  # e2 · telemetri geçici köke gitti (her örnek bir satır), gerçek tescil telemetrisine değil
  python3 -c "import json,sys;assert json.load(open(sys.argv[1]))['telemetri_gecici_satir']==9" "$T/kanit-a/sonuc.json" 2>/dev/null && o="$o e2"
  # e · sınav gerçek sicile ve kümeye dokunmaz (telemetri/çıktı geçici kökte)
  [ "$(sha256sum "$T/sicil/01.099.yaml")" = "$sic_once" ] && [ "$(ls "$T/sicil")" = 01.099.yaml ] && [ "$(kume_iz "$KUME")" = "$iz_once" ] && o="$o e"
  # b · lastik mühür (hep GEÇTİ): kusurlu öznel + iki uydurma kaçar → KALDI
  _d "$s" y-lastik "$D" -- sina MUHAKKİK --kanit "$T/kanit-x"; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['gecti']=='h' and d['sonuc']=={'dogru':'3/3','kusurlu':'2/3','uydurma':'0/3'},d" "$D" 2>/dev/null && o="$o b"
  # c · hep KALDI: doğru teslimleri de düşürür → KALDI
  _d "$s" y-hepkaldi "$D" -- sina MUHAKKİK --kanit "$T/kanit-x"; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['sonuc']['dogru']=='0/3' and d['gecti']=='h',d" "$D" 2>/dev/null && o="$o c"
  # d · bozuk yargıç → EMIN-DEGILIM (eskalasyon) hiçbir türde isabet değil, çökme yok
  _d "$s" y-bozuk "$D" -- sina MUHAKKİK --kanit "$T/kanit-x"; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['sonuc']=={'dogru':'0/3','kusurlu':'2/3','uydurma':'0/3'},d" "$D" 2>/dev/null && o="$o d"
  # l · kusur başka G'de düştü → isabet sayılmaz (yanlış sebeple KALDI)
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kanit "$T/kanit-x" --kume "$T/kume-yanlis-g"; r=$?
  [ $r -eq 1 ] && python3 -c "import json,sys;d=json.loads(open(sys.argv[1]).readlines()[-1]);assert d['sonuc']['kusurlu']=='0/1',d" "$D" 2>/dev/null && o="$o l"
  local n_once; n_once="$(wc -l < "$D")"
  # o · son koşu kaldı → önceki geçen diploma DÜŞER (yenilenen sınavı kaldıran geçerli görünmez)
  _d "$s" y-durust "$D" -- durum MUHAKKİK; [ $? -eq 1 ] && grep -q "durum: yok" "$T/son.log" && grep -q "DÜŞTÜ" "$T/son.log" && o="$o o"
  # r · dalgalı yargıç: ıskalanan örneğin yeniden koşusu çelişir → KARARSIZ → ÖLÇÜLEMEDİ, deftere sahte hüküm yazılmaz
  rm -f "$T/dalga-n"; local n_r; n_r="$(wc -l < "$D")"
  _d "$s" y-dalgali "$D" -- sina MUHAKKİK --kanit "$T/kanit-r"; r=$?
  [ $r -eq 3 ] && [ "$(wc -l < "$D")" = "$n_r" ] && grep -q "KARARSIZ" "$T/son.log" && grep -q "ÇELİŞTİ" "$T/son.log" \
    && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d['olculemedi']=='kararsiz' and len(d['kararsiz'])>=1" "$T/kanit-r/sonuc.json" 2>/dev/null && o="$o r"
  # f · türü boş küme → koşulmaz, deftere yazılmaz
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kanit "$T/kanit-x" --kume "$T/kume-eksik"; r=$?
  [ $r -eq 3 ] && [ "$(wc -l < "$D")" = "$n_once" ] && grep -q "uydurma" "$T/son.log" && o="$o f"
  # g · defter dizini yok → ölçülemedi
  _d "$s" y-durust "$T/yok/d.jsonl" -- sina MUHAKKİK --kanit "$T/kanit-x"; [ $? -eq 3 ] && [ ! -e "$T/yok" ] && o="$o g"
  # j · sınavın yazan adıyla personel → kullanım
  _d "$s" y-durust "$D" -- sina diploma-sınavı --kanit "$T/kanit-x"; [ $? -eq 2 ] && [ "$(wc -l < "$D")" = "$n_once" ] && o="$o j"
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kanit "$T/kanit-x"; [ $? -eq 0 ] || echo "  (yeniden geçen koşu düştü)" >&2
  # q · --kanit zorunlu (geçici dizin kanıt sayılmaz) → kullanım, deftere yazılmaz
  _d "$s" y-durust "$D" -- sina MUHAKKİK; [ $? -eq 2 ] && [ "$(wc -l < "$D")" = "$((n_once + 1))" ] && o="$o q"
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
  # h5 · sicil ölçülemezken diploma GEÇERLİ değil (göz #412 tur 6): özlüksüz sicil → ölçülemedi rc 3; bayat yine bayat (sicilden bağımsız)
  mkdir -p "$T/sicil-bos"
  _d "$s" y-durust "$D" SICIL_DIZIN="$T/sicil-bos" -- durum MUHAKKİK; local h5a=$?; local h5l; h5l="$(cat "$T/son.log")"
  printf '{"skills":[{"id":"tescil","version":"9.9.10"}]}\n' > "$T/katalog.json"
  _d "$s" y-durust "$D" SICIL_DIZIN="$T/sicil-bos" -- durum MUHAKKİK; local h5b=$?
  printf '{"skills":[{"id":"tescil","version":"9.9.9"}]}\n' > "$T/katalog.json"
  [ $h5a -eq 3 ] && printf '%s' "$h5l" | grep "durum: ölçülemedi" >/dev/null && printf '%s' "$h5l" | grep "sicil ölçülemedi" >/dev/null \
    && ! printf '%s' "$h5l" | grep "durum: gecerli" >/dev/null && [ $h5b -eq 1 ] && grep -q "durum: bayat" "$T/son.log" && o="$o h5"
  # p · bozuk (yarım yazılmış) satır sessizce atlanmaz → ölçülemedi, satır numarasıyla
  cp "$D" "$T/defter/bozuk.jsonl"; printf '{"ts": "2026-10-22T09:00:00Z", "personel": "MUHAKKİK", "gec\n' >> "$T/defter/bozuk.jsonl"
  _d "$s" y-durust "$T/defter/bozuk.jsonl" -- durum MUHAKKİK; [ $? -eq 3 ] && grep -q "bozuk: 1" "$T/son.log" && o="$o p"
  # p2 · sina bozuk satırlı deftere yazar ama bozukluğu SÖYLER (geri okuma bozuğu da görür)
  cp "$T/defter/bozuk.jsonl" "$T/defter/bozuk2.jsonl"
  _d "$s" y-durust "$T/defter/bozuk2.jsonl" -- sina MUHAKKİK --kanit "$T/kanit-x"; [ $? -eq 0 ] && grep -q "⚠ bozuk: 1 satır" "$T/son.log" && o="$o p2"
  # p4 · bozuk satır ters kayıtla kapatılır (göz #412 tur 5): kapatınca durum yeniden ölçülür (son geçerli koşu), satır SİLİNMEZ;
  #      geçerli satır kapatılamaz, aynı satır iki kez kapatılamaz, gerekçesiz kapatılamaz
  cp "$T/defter/bozuk.jsonl" "$T/defter/bozuk3.jsonl"; local bn; bn="$(wc -l < "$T/defter/bozuk3.jsonl")"
  _d "$s" y-durust "$T/defter/bozuk3.jsonl" -- bozuk-kapat 1 --gerekce "geçerli satır denemesi burada"; local k1=$?
  _d "$s" y-durust "$T/defter/bozuk3.jsonl" -- bozuk-kapat "$bn" --gerekce "kısa"; local k2=$?
  _d "$s" y-durust "$T/defter/bozuk3.jsonl" -- bozuk-kapat "$bn" --gerekce "sınav süreci yazım ortasında öldü"; local k3=$?
  _d "$s" y-durust "$T/defter/bozuk3.jsonl" -- bozuk-kapat "$bn" --gerekce "sınav süreci yazım ortasında öldü"; local k4=$?
  _d "$s" y-durust "$T/defter/bozuk3.jsonl" -- durum MUHAKKİK; local k5=$?
  [ $k1 -eq 2 ] && [ $k2 -eq 2 ] && [ $k3 -eq 0 ] && [ $k4 -eq 2 ] && [ $k5 -eq 0 ] && grep -q "durum: gecerli" "$T/son.log" \
    && [ "$(wc -l < "$T/defter/bozuk3.jsonl")" = "$((bn + 1))" ] && grep -q '"gec$' "$T/defter/bozuk3.jsonl" && o="$o p4"
  # p3 · yazım yarım kalmaz (göz #412 tur 4): kısa yazımda defter eski hâline kesilir, rc 3; satır sonu eksik (yarım kalmış)
  #      deftere yeni satır yapışmaz — kendi satırında, okunur
  cp "$D" "$T/defter/kes.jsonl"; local kb; kb="$(md5sum < "$T/defter/kes.jsonl")"
  printf '{"ts": "yarim' > "$T/defter/nl.jsonl"
  DIPLOMA_DEFTERI="$T/defter/kes.jsonl" python3 - "$s/lib/diploma.py" kes <<'PY' >/dev/null 2>&1; local p3a=$?
import importlib.util, os, sys
sp = importlib.util.spec_from_file_location("dp", sys.argv[1]); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
asil = os.write
def yarim(fd, b):
    asil(fd, b[:len(b) // 2]); return len(b) // 2   # disk dolu: kısa yazım
if sys.argv[2] == "kes":
    os.write = yarim
try:
    m.defter_ekle({"ts": "t", "personel": "P"})
except SystemExit as e:
    sys.exit(e.code)
PY
  DIPLOMA_DEFTERI="$T/defter/nl.jsonl" python3 - "$s/lib/diploma.py" tam <<'PY' >/dev/null 2>&1; local p3b=$?
import importlib.util, os, sys
sp = importlib.util.spec_from_file_location("dp", sys.argv[1]); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
m.defter_ekle({"ts": "t", "personel": "P"})
PY
  [ $p3a -eq 3 ] && [ "$(md5sum < "$T/defter/kes.jsonl")" = "$kb" ] && [ $p3b -eq 0 ] && python3 - "$T/defter/nl.jsonl" <<'PY' 2>/dev/null && o="$o p3"
import json, sys
L = open(sys.argv[1], encoding="utf-8").read().split("\n")
assert L[0] == '{"ts": "yarim' and json.loads(L[1]) == {"ts": "t", "personel": "P"} and L[2] == "", L
PY
  # m · defter yok → durum ölçülemedi (yok DEĞİL)
  _d "$s" y-durust "$T/defter/yok.jsonl" -- durum MUHAKKİK; [ $? -eq 3 ] && o="$o m"
  # i2 · GERÇEK sicil.py ile sözleşme (durum --json): iki ayrı görevde kaçırma → askida; temiz özlük → sicil temiz
  #      (#411 main'de: yazıcı yoksa kapı düşer — ÖLÇÜLEMEDİ'ye kaçış yok, göz #412 tur 5)
    mkdir -p "$T/sicil-aski" "$T/sicil-temiz"
    printf 'personel_no: "01.099"\npersona: MUHAKKİK\ngecmis: []\nisabet:\n' > "$T/sicil-aski/01.099.yaml"
    for x in A B; do printf '  - {"ts": "2026-10-22T00:00:0%s.000001Z", "gorev": "gorev_%s", "gereklilik": "G1", "muhur": "✓", "sultan": "saglanmadi", "kacirma": "e", "bassiz": "h", "el_kitabi_surum": "9.9.9", "ders": null, "neden": "x", "kaynak": "teslim:%s"}\n' "$( [ $x = A ] && echo 1 || echo 2)" $x $x >> "$T/sicil-aski/01.099.yaml"; done
    printf 'personel_no: "01.099"\npersona: MUHAKKİK\ngecmis: []\n' > "$T/sicil-temiz/01.099.yaml"
    _d "$s" y-durust "$D" SICIL_DIZIN="$T/sicil-aski" TARIF_KAYDI="$T/yok.json" -- durum MUHAKKIK; r=$?
    [ $r -eq 1 ] && grep -q "durum: askida" "$T/son.log" && grep -q "sicil askida" "$T/son.log" \
      && _d "$s" y-durust "$D" SICIL_DIZIN="$T/sicil-temiz" TARIF_KAYDI="$T/yok.json" -- durum MUHAKKİK && grep -q "durum: gecerli" "$T/son.log" && grep -q "sicil temiz" "$T/son.log" && o="$o i2"
  # i · sicil askıda → diploma askıda (sahte sicil.py ile)
  cp "$s/lib/sicil.py" "$T/sicil.py.yedek" 2>/dev/null || : > "$T/sicil.py.yedek-yok"
  printf 'import json\nprint(json.dumps({"durum":"askida"}))\n' > "$s/lib/sicil.py"
  _d "$s" y-durust "$D" -- durum MUHAKKİK; r=$?; [ $r -eq 1 ] && grep -q "durum: askida" "$T/son.log" && grep -q "yeniden sınav" "$T/son.log" && o="$o i"
  if [ -f "$T/sicil.py.yedek" ]; then cp "$T/sicil.py.yedek" "$s/lib/sicil.py"; rm -f "$T/sicil.py.yedek"; else rm -f "$s/lib/sicil.py" "$T/sicil.py.yedek-yok"; fi
  # s · SIGKILL artığı (kart muhurdar-diploma-kume-gucu): finally koşmaz, kök kalır → kök .sahip izi (pid + açılış saati) taşır;
  #     sonraki sınav sahibi ölmüş ya da pid'i başka sürece geçmiş kökü siler; canlı sahipli ve izsiz köke DOKUNMAZ.
  mkdir -p "$T/y-yavas" "$T/tmp"; printf '#!/usr/bin/env bash\ncat >/dev/null; sleep 60\n' > "$T/y-yavas/claude"; chmod +x "$T/y-yavas/claude"
  find "$T/tmp" -mindepth 1 -delete 2>/dev/null
  env TMPDIR="$T/tmp" PATH="$T/y-yavas:$ND:$PY:/usr/bin:/bin" MUHURDAR_MODEL=claude DIPLOMA_DEFTERI="$D" TESCIL_KATALOG="$T/katalog.json" \
    SICIL_DIZIN="$T/sicil" setsid bash "$s/diploma.sh" sina MUHAKKİK --kanit "$T/kanit-s" > "$T/son-s.log" 2>&1 < /dev/null &
  local sp=$! t0=0 olu=""
  until olu="$(ls -d "$T/tmp"/diploma-kok-* 2>/dev/null | head -1)"; [ -n "$olu" ] && [ -f "$olu/.sahip" ] || [ $t0 -ge 100 ]; do sleep 0.1; t0=$((t0+1)); done
  kill -9 -- "-$sp" 2>/dev/null; wait "$sp" 2>/dev/null
  [ -n "$olu" ] && [ -d "$olu" ] && [ -f "$olu/.sahip" ] && o="$o s1"
  local canli="$T/tmp/diploma-kok-canli" izsiz="$T/tmp/diploma-kok-izsiz" yeniden="$T/tmp/diploma-kok-yeniden" bozuk="$T/tmp/diploma-kok-bozuk"
  mkdir -p "$canli" "$izsiz" "$yeniden" "$bozuk"; echo "abc 123" > "$bozuk/.sahip"   # bozuk iz: sayı olmayan pid
  echo "$$ $(python3 -c "import sys;print(open(f'/proc/{sys.argv[1]}/stat').read().rsplit(')',1)[1].split()[19])" "$$")" > "$canli/.sahip"
  echo "$$ 1" > "$yeniden/.sahip"   # canlı pid, yanlış açılış saati = pid başka sürece verilmiş
  _d "$s" y-durust "$D" -- sina MUHAKKİK --kanit "$T/kanit-s2"; r=$?
  [ -n "$olu" ] && [ ! -e "$olu" ] && [ ! -e "$yeniden" ] && grep -q "süpürüldü: 2 eski sınav kökü" "$T/son.log" && o="$o s2"
  [ -d "$canli" ] && o="$o s3"
  [ -d "$izsiz" ] && o="$o s4"
  [ $r -eq 0 ] && [ "$(ls -d "$T/tmp"/diploma-kok-* 2>/dev/null | wc -l)" = 3 ] && o="$o s5"
  # s6 · bozuk sahip izi (sayı olmayan pid) süpürmeyi çökertmez, o köke dokunulmaz (göz #420 tur 1)
  [ $r -eq 0 ] && [ -d "$bozuk" ] && ! grep -q "Traceback" "$T/son.log" && o="$o s6"
  echo "$o"
}
BEK="a a2 n e e2 b c d l o r f g j q h h2 h3 h4 h5 k k2 p p2 p3 p4 m i"
BEK="$BEK i2"
BEK="$BEK s1 s2 s3 s4 s5 s6 n2"   # SIGKILL artığı süpürmesi (kart muhurdar-diploma-kume-gucu)   # gerçek sicil yazıcısıyla sözleşme (Sx #411 birleşti) — koşulsuz
# gerçek betikler bir kopyada koşulur (kapı i sahte sicil.py yazar — gerçek dosyaya dokunmamak için); el kitabı kökü aynı kalır
_kopya_gercek() { local d="$T/gercek/scripts"; mkdir -p "$d"; cp -r "$HERE/." "$d/"; cp "$HERE/../SKILL.md" "$T/gercek/SKILL.md"; ln -s "$KUME" "$T/gercek/sinav"; echo "$d"; }

# ── ÇOCUK KİP: tek senaryo (gerçek ya da tek mutant), kendi $T'sinde; sonucu "SONUC <anahtarlar>" / "CAPA" basar, DOĞURMAZ ──
if [ "${1:-}" = "--tek" ]; then
  GS="$(_kopya_gercek)"
  if [ "$2" = gercek ]; then echo "SONUC $(_sen "$GS")"; exit 0; fi
  d="$T/m"; mkdir -p "$d/scripts"; cp -r "$GS/." "$d/scripts/"; cp "$T/gercek/SKILL.md" "$d/SKILL.md"; ln -s "$KUME" "$d/sinav"
  python3 - "$d/scripts/lib/diploma.py" "$3" "$4" <<'PY' || { echo CAPA; exit 0; }
import sys
p, eski, yeni = sys.argv[1:4]
s = open(p).read()
assert s.count(eski) == 1, "capa"
open(p, "w").write(s.replace(eski, yeni))
PY
  echo "SONUC $(_sen "$d/scripts")"; exit 0
fi

PARCA="${DIPLOMA_PARCA:-1/1}"
[[ "$PARCA" =~ ^([1-9][0-9]*)/([1-9][0-9]*)$ ]] && [ "${BASH_REMATCH[1]}" -le "${BASH_REMATCH[2]}" ] \
  || { echo "ÖLÇÜLEMEDİ: DIPLOMA_PARCA '$PARCA' biçimsiz (k/n, 1 ≤ k ≤ n)"; exit 2; }
PK="${BASH_REMATCH[1]}"; PN="${BASH_REMATCH[2]}"; SNO=0; KOSAN=0; GERCEK_BENDE=h
_benim() { local i=$SNO; SNO=$((SNO+1)); [ $((i % PN)) -eq $((PK - 1)) ] && KOSAN=$((KOSAN+1)); }
PAR="${DIPLOMA_PAR:-$(n=$(nproc 2>/dev/null || echo 2); [ "$n" -gt 8 ] && n=8; echo "$n")}"
SIRA=()   # "ad|kapı" — sonuçlar bu sırayla okunur (çıktı paralel koşuya rağmen kararlı)
_bas() {  # _bas <ad> [eski yeni] — çocuğu arka planda başlatır, PAR'ı aşmaz
  while [ "$(jobs -rp | wc -l)" -ge "$PAR" ]; do wait -n 2>/dev/null || :; done
  bash "${BASH_SOURCE[0]}" --tek "$@" > "$T/sonuc-$1.out" 2>&1 < /dev/null &
}
_mut() {  # _mut <ad> <hedef-kapı> <python-replace: eski> <yeni> — bu parçanın değilse koşmaz, sırada yer almaz
  local k=$KOSAN; _benim; [ "$KOSAN" -gt "$k" ] || return 0
  SIRA+=("$1|$2"); _bas "$1" "$3" "$4"
}
k0=$KOSAN; _benim; [ "$KOSAN" -gt "$k0" ] && { GERCEK_BENDE=e; _bas gercek; }
_mut alt-kume l 'isabet = verdikt == "KALDI" and set(bek.get("kaldi") or []) <= set(dusen)' 'isabet = verdikt == "KALDI"'
_mut eskalasyon-isabet d 'isabet = verdikt == "GECTI"' 'isabet = verdikt != "KALDI"'
# sicil ayrımı: muhurdar.sh her mühürde sicile yazar (Sx #411) — koşulsuz ölçülür
_mut sicil-ayrimi-yok e 'env = dict(os.environ, AGENT_NAME=personel, SICIL_DIZIN=os.path.join(kok, "sicil-yok"))' 'env = dict(os.environ, AGENT_NAME=personel)'
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
_mut sicil-json-yok i2 '[sys.executable, sicil, "durum", personel, "--json"]' '[sys.executable, sicil, "durum", personel]'
_mut bozuk-yutulur p '    if bozuk:
        # bozuk' '    if False:
        # bozuk'
_mut yeniden-yok r '                if not isabet:
                    # yargıç dalgalanması' '                if False:
                    # yargıç dalgalanması'
_mut kararsiz-yutulur r '                    if isabet2:
                        kararsiz.append(kart)' '                    if isabet2:
                        isabet = True'
_mut kume-sha a '    return ornekler, h.hexdigest()' '    return ornekler, ""'
_mut sicilsiz-gecerli h5 '    elif sic is None:   # göz #412 tur 6' '    elif False:   # göz #412 tur 6'
_mut ters-kayit-yok p4 '    return [d for d in satirlar if not d.get("tur")], [n for n in bozuk if n not in kapali]' '    return [d for d in satirlar if not d.get("tur")], bozuk'
_mut kapat-dogrulamasiz p4 '    if a.satir not in bozuk:' '    if False:'
_mut yarim-kalir p3 '            os.ftruncate(fd, boy)' '            pass'
_mut satir-sonu-yok p3 '            veri = b"\n" + veri' '            pass'
_mut supur-yok s2 '    supurulen = kok_supur()' '    supurulen = 0'
_mut iz-yok s1 '    with open(os.path.join(kok, ".sahip"), "w", encoding="utf-8") as f:' '    with open(os.devnull, "w", encoding="utf-8") as f:'
_mut canli-silinir s3 '        if _surec_baslangici(pid) != bas:' '        if True:'
_mut pid-yeniden-gorulmez s2 '        if _surec_baslangici(pid) != bas:' '        if _surec_baslangici(pid) is None:'
_mut anahtar-kopyalanir n2 '        if os.path.isfile(os.path.join(ornek, ad)) and ad != "beklenen.json":' '        if os.path.isfile(os.path.join(ornek, ad)):'
_mut bozuk-iz-cokertir s6 '            pid = int(pid)   # bozuk iz' '            pid = pid   # bozuk iz'
_mut izsiz-silinir s4 '            with open(os.path.join(d, ".sahip"), encoding="utf-8") as f:
                pid, bas = f.read().split()' '            pid, bas = "1", "x"'
wait
_oku() { sed -n 's/^SONUC //p; s/^\(CAPA\)$/\1/p' "$T/sonuc-$1.out" | tail -1; }
echo "── parça $PK/$PN: $KOSAN / $SNO senaryo · gerçek koşu: $([ $GERCEK_BENDE = e ] && echo bu parçada || echo "1. parçada")"
[ "$KOSAN" -gt 0 ]; g $? "parça $PK/$PN en az bir senaryo koşar (n senaryodan büyük olamaz)"
if [ $GERCEK_BENDE = e ]; then
echo "── gerçek betikler"
GER="$(_oku gercek)"
[ -n "$GER" ] || { echo "  ✗ gerçek koşu sonuç basmadı:"; tail -5 "$T/sonuc-gercek.out"; }
for k in $BEK; do case " $GER " in *" $k "*) g 0 "kapı $k" ;; *) g 1 "kapı $k" ;; esac; done
fi
echo "── mutasyonlar (paralel $PAR)"
for x in "${SIRA[@]}"; do
  ad="${x%%|*}"; kp="${x#*|}"; c="$(_oku "$ad")"
  if [ "$c" = CAPA ]; then g 1 "mutant $ad: çapa tutmadı"
  elif [ -z "$c" ] && ! grep -q '^SONUC' "$T/sonuc-$ad.out"; then g 1 "mutant $ad: koşu sonuç basmadı"
  else case " $c " in *" $kp "*) g 1 "mutant $ad → kapı $kp hâlâ geçiyor" ;; *) g 0 "mutant $ad → kapı $kp düştü" ;; esac; fi
done
echo "diploma.test: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
