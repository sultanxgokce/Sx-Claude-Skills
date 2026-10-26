#!/usr/bin/env bash
# supur.test.sh — geçidin çıkış kutusu → sicil.sh supur → teslim-isle (WPZ5FK) + muhurdar.sh mühür kopyası. HERMETİK: geçici sicil,
# sahte doğrulayıcı (geçidin yerine; Sultan'ın kararını fikstürden basar), sahte mühür kopyası. Gerçek özlüğe DOKUNMAZ.
# kabuk-testleri: sure=120
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
python3 -c "import yaml" 2>/dev/null || { echo "ÖLÇÜLEMEDİ: PyYAML yok"; exit 4; }

kur() {  # kur <kök> → sicil, kararlar, doğrulayıcı, mühür kopyaları (gorev_T tam karar, gorev_E eksik karar, gorev_N mühür kopyası yok)
  local k="$1"; mkdir -p "$k/sicil" "$k/kararlar" "$k/kok"
  printf 'personel_no: "01.008"\npersona: MUHURDAR1\ngecmis: []\n' > "$k/sicil/01.008.yaml"
  printf '{"gorev":"gorev_T","satirlar":{"G1":{"sultan":"katiliyorum"},"G2":{"sultan":"saglanmadi","neden":"ton sert"}}}' > "$k/kararlar/gorev_T.json"
  printf '{"gorev":"gorev_E","satirlar":{"G1":{"sultan":"katiliyorum"}}}' > "$k/kararlar/gorev_E.json"
  printf '{"gorev":"gorev_N","satirlar":{"G1":{"sultan":"katiliyorum"}}}' > "$k/kararlar/gorev_N.json"
  printf '#!/usr/bin/env bash\nf="%s/kararlar/${1#teslim:}.json"; [ -f "$f" ] || exit 1; cat "$f"\n' "$k" > "$k/dogrula.sh"; chmod +x "$k/dogrula.sh"
  local gv
  for gv in gorev_T gorev_E; do
    mkdir -p "$k/kok/$gv"
    printf '{"g":[{"id":"G1","tur":"cmd"},{"id":"G2","tur":"llm-yargi"}]}' > "$k/kok/$gv/gereklilik.json"
    printf '{"kart":"%s","verdikt":"KALDI","g_dusen":["G1"],"muhurdar":"MUHURDAR1","tescil_skill_version":"0.9.0"}' "$gv" > "$k/kok/$gv/muhur-ozet.json"
  done
}

_sen() {  # _sen <scripts-dir> → geçen anahtarlar
  local S="$1/sicil.sh" k="$T/k$RANDOM" o=""; kur "$k"
  local E=(env SICIL_DIZIN="$k/sicil" SICIL_KAYNAK_DOGRULA="$k/dogrula.sh" SICIL_MUHUR_KOK="$k/kok")
  local KUTU="$k/cikis.jsonl" Y="$k/sicil/01.008.yaml"
  # a · tam karar + mühür kopyası var → bir kez işlenir, iki satır (G1 ✗/katılıyorum, G2 ✓/sağlanmadı = kaçırma), kaynak kaydı tutulur
  printf '{"gorev":"gorev_T","kaynak":"teslim:gorev_T"}\n' > "$KUTU"
  "${E[@]}" bash "$S" supur --kutu "$KUTU" > "$k/c1" 2>&1; local r1=$?
  [ $r1 -eq 0 ] && grep -q "1 işlendi" "$k/c1" && python3 -c "
import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); s=[x for x in d['isabet'] if not x.get('tur')]
assert len(s)==2 and {x['gereklilik'] for x in s}=={'G1','G2'}; k=[x for x in s if x['gereklilik']=='G2'][0]
assert k['kacirma']=='e' and k['neden']=='ton sert' and k['kaynak']=='teslim:gorev_T'" "$Y" 2>/dev/null && o="$o a"
  # b · ikinci süpürme aynı kararı yeniden yazmaz (idempotent): satır sayısı sabit, 'zaten işli'. Mühür kopyası temizlenmiş olsa bile
  #     işlenen kaynak işli kalır (temizlik işlenmişi "bekliyor"a döndürmez)
  find "$k/kok/gorev_T" -mindepth 1 -delete; rmdir "$k/kok/gorev_T"
  "${E[@]}" bash "$S" supur --kutu "$KUTU" > "$k/c2" 2>&1; local r2=$?
  [ $r2 -eq 0 ] && grep -q "1 zaten işli" "$k/c2" && [ "$(grep -c '"gorev": "gorev_T"' "$Y")" = 2 ] && o="$o b"
  # c · aynı görevin tekrar eden kutu satırları tek iş sayılır (geçit her hükümde satır yazar)
  local k2="$T/k$RANDOM"; kur "$k2"; printf '{"gorev":"gorev_T","kaynak":"teslim:gorev_T"}\n{"gorev":"gorev_T","kaynak":"teslim:gorev_T"}\n' > "$k2/cikis.jsonl"
  env SICIL_DIZIN="$k2/sicil" SICIL_KAYNAK_DOGRULA="$k2/dogrula.sh" SICIL_MUHUR_KOK="$k2/kok" bash "$S" supur --kutu "$k2/cikis.jsonl" > "$k2/c" 2>&1
  grep -q "1 işlendi" "$k2/c" && [ "$(grep -c '"gorev": "gorev_T"' "$k2/sicil/01.008.yaml")" = 2 ] && o="$o c"
  # d · Sultan'ın kararı eksikse (mühürde G2 var, kararda yok) kısmi yazılmaz, kutuda KALIR (bekliyor), rc 0
  local k3="$T/k$RANDOM"; kur "$k3"; printf '{"gorev":"gorev_E","kaynak":"teslim:gorev_E"}\n' > "$k3/cikis.jsonl"
  env SICIL_DIZIN="$k3/sicil" SICIL_KAYNAK_DOGRULA="$k3/dogrula.sh" SICIL_MUHUR_KOK="$k3/kok" bash "$S" supur --kutu "$k3/cikis.jsonl" > "$k3/c" 2>&1; local r4=$?
  [ $r4 -eq 0 ] && grep -q "1 bekliyor" "$k3/c" && ! grep -q isabet "$k3/sicil/01.008.yaml" && [ ! -s "$k3/cikis.jsonl.islendi" ] && o="$o d"
  # e · mühür kopyası yoksa bekliyor (yazılmaz); kopya sonradan gelince aynı satır işlenir
  local k4="$T/k$RANDOM"; kur "$k4"; printf '{"gorev":"gorev_N","kaynak":"teslim:gorev_N"}\n' > "$k4/cikis.jsonl"
  env SICIL_DIZIN="$k4/sicil" SICIL_KAYNAK_DOGRULA="$k4/dogrula.sh" SICIL_MUHUR_KOK="$k4/kok" bash "$S" supur --kutu "$k4/cikis.jsonl" > "$k4/c" 2>&1
  grep -q "1 bekliyor" "$k4/c" && grep -q "mühür dizini yok" "$k4/c" && ! grep -q isabet "$k4/sicil/01.008.yaml" && o="$o e"
  # f · A06: doğrulayıcı yoksa hüküm YAZILMAZ (kutudaki satır işaret, kaynak değil) → bekliyor, işlenmez
  local k5="$T/k$RANDOM"; kur "$k5"; printf '{"gorev":"gorev_T","kaynak":"teslim:gorev_T"}\n' > "$k5/cikis.jsonl"
  env SICIL_DIZIN="$k5/sicil" SICIL_MUHUR_KOK="$k5/kok" bash "$S" supur --kutu "$k5/cikis.jsonl" > "$k5/c" 2>&1
  grep -q "1 bekliyor" "$k5/c" && ! grep -q isabet "$k5/sicil/01.008.yaml" && o="$o f"
  # g · bozuk satır ve biçimsiz kaynak sessiz geçilmez: rc 4 + sayı; geçerli satır yine işlenir
  local k6="$T/k$RANDOM"; kur "$k6"; printf 'bu json değil\n{"gorev":"gorev_T","kaynak":"uydurma"}\n{"gorev":"gorev_T","kaynak":"teslim:gorev_T"}\n' > "$k6/cikis.jsonl"
  env SICIL_DIZIN="$k6/sicil" SICIL_KAYNAK_DOGRULA="$k6/dogrula.sh" SICIL_MUHUR_KOK="$k6/kok" bash "$S" supur --kutu "$k6/cikis.jsonl" > "$k6/c" 2>&1; local r7=$?
  [ $r7 -eq 4 ] && grep -q "2 bozuk" "$k6/c" && grep -q "1 işlendi" "$k6/c" && o="$o g"
  # h · kutu yoksa hata değil: yapılacak şey yok (rc 0)
  env SICIL_DIZIN="$k/sicil" bash "$S" supur --kutu "$k/yok.jsonl" > "$k/c8" 2>&1; local r8=$?
  [ $r8 -eq 0 ] && grep -q "yapılacak şey yok" "$k/c8" && o="$o h"
  # i · kutu verilmemişse kullanım hatası (ortam da yok)
  env -u SICIL_CIKIS_KUTUSU SICIL_DIZIN="$k/sicil" bash "$S" supur > "$k/c9" 2>&1; local r9=$?
  [ $r9 -eq 2 ] && grep -q "çıkış kutusu verilmedi" "$k/c9" && o="$o i"
  # j · muhurdar.sh mühür kopyasını bırakır (kod kancası): kopya bloğu aynı kaynakta durur ve tatbikatı dışlar
  grep -q 'cp "$OUT/muhur-ozet.json" "$OUT/gereklilik.json" "$_KOK/$IS/"' "$1/muhurdar.sh" && grep -q 'TATBIKAT\[\*\]' "$1/muhurdar.sh" && o="$o j"
  echo "$o"
}

echo "── supur: çıkış kutusu → teslim-isle ──"
SON="$(_sen "$HERE" | tail -1)"
for x in a b c d e f g h i j; do
  case "$SON" in *" $x"*) g 0 "$x";; *) g 1 "$x";; esac
done

# mutantlar: kopyada hedef satır bozulur; sınav o anahtarı KAYBETMELİ
mut() {  # mut <anahtar> <dosya> <eski> <yeni> <ad>
  local M="$T/m$RANDOM"; mkdir -p "$M/lib"; cp "$HERE"/sicil.sh "$HERE"/muhurdar.sh "$M/"; cp "$HERE"/lib/*.py "$M/lib/"
  python3 - "$M/$2" "$3" "$4" <<'PY'
import sys; p,a,b=sys.argv[1:4]; s=open(p,encoding="utf-8").read(); assert s.count(a)==1,("mutant çapası yok",a); open(p,"w",encoding="utf-8").write(s.replace(a,b))
PY
  local sonuc; sonuc="$(_sen "$M" | tail -1)"
  case "$sonuc" in *" $1"*) g 1 "mutant ($5) YAKALANMADI — $1 yine geçti";; *) g 0 "mutant ($5) yakalandı";; esac
}
mut b lib/sicil.py '        if kay in islendi:' '        if False:' "işlenen kaynak tekrar işleniyor"
mut c lib/sicil.py '            kaynaklar.setdefault(kay, g)' '            kaynaklar[kay + str(len(kaynaklar))] = g' "tekrar satırlar ayrı iş"
mut d lib/sicil.py '        elif "satırlar yok" in p.stderr or p.returncode == 3:' '        elif False:' "eksik karar kısmi/reddedildi sayılıyor"
mut f lib/sicil.py '        if p.returncode == 0 or "zaten işlendi" in p.stderr:' '        if True:' "teslim-isle hatası işlenmiş sayılıyor"
mut g lib/sicil.py '    return 4 if sayi["reddedildi"] or bozuk else 0' '    return 0' "bozuk satır sessiz geçiliyor"
mut e lib/sicil.py '        except (OSError, ValueError, AssertionError):
            sayi["bekliyor"]' '        except ValueError:
            sayi["bekliyor"]' "mühür dizini yokluğu çöküyor"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
