#!/usr/bin/env bash
# sicil-olcer.sh <tescil/scripts dizini> (Sultan kararları sahte doğrulayıcıyla verilir — geçidin yerine) — GERÇEK sicil dizininin KOPYASINDA (gerçeğe dokunmaz): Sultan'ın 'sağlanmadı'sı mühürdarın
#   siciline düşüyor mu, iki kaçırmalı mühürde askı hesaplanıyor mu, seviye-lint yeni bölümü bozuyor mu (şema §6 'ÖLÇÜLMEDİ' notu).
set -uo pipefail
S="$(cd "$1" && pwd)"; G=/config/projects/Nexus/_agents/federe/sicil; L=/config/projects/Nexus/scripts/seviye-lint.sh
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
cp -r "$G" "$T/sicil"; mkdir -p "$T/k"
printf '#!/usr/bin/env bash\nf="%s/k/${1#teslim:}.json"; [ -f "$f" ] || exit 1; cat "$f"\n' "$T" > "$T/dogrula.sh"; chmod +x "$T/dogrula.sh"
for g in gorev_OLCUM1 gorev_OLCUM2; do printf '{"gorev":"%s","satirlar":{"G1":{"sultan":"saglanmadi","neden":"ölçüm: renk koyu değil"}}}' "$g" > "$T/k/$g.json"; done
export SICIL_KAYNAK_DOGRULA="$T/dogrula.sh"
AD="$(grep -l 'rol_sinifi: MUHURDAR' "$T"/sicil/*.yaml | head -1 | xargs grep -m1 '^persona:' | awk '{print $2}')"
SEVIYE_SICIL_DIR="$T/sicil" bash "$L" > "$T/lint-once" 2>&1; l0=$?
if [ -f "$S/sicil.sh" ]; then
  for g in gorev_OLCUM1 gorev_OLCUM2; do
    SICIL_DIZIN="$T/sicil" bash "$S/sicil.sh" isabet "$AD" --gorev $g --gereklilik G1 --muhur ✓ --sultan saglanmadi --neden "ölçüm: renk koyu değil" --g-tur e2e-check --kaynak "teslim:$g" >/dev/null 2>&1
  done
  d="$(SICIL_DIZIN="$T/sicil" TARIF_KAYDI=/yok bash "$S/sicil.sh" durum "$AD" 2>&1 | grep '^durum:')"
  SICIL_DIZIN="$T/sicil" bash "$S/sicil.sh" isabet MUHAKKIK --gorev gorev_OLCUM1 --gereklilik G1 --muhur ✓ --sultan saglanmadi --kaynak teslim:gorev_OLCUM1 >/dev/null 2>&1; rm_=$?
else
  d="durum: (sicil yazıcısı YOK — Sultan'ın 'sağlanmadı'sı mühürdarın hiçbir kaydına düşmüyor)"; rm_=yok
fi
SEVIYE_SICIL_DIR="$T/sicil" bash "$L" > "$T/lint-sonra" 2>&1; l1=$?
n="$(python3 -c "import yaml,glob,sys;print(sum(len([x for x in (yaml.safe_load(open(f)) or {}).get('isabet') or [] if x.get('kacirma')=='e']) for f in glob.glob(sys.argv[1]+'/*.yaml')))" "$T/sicil")"
echo "── mühürdar: $AD (özlük dosyası: $(grep -l "persona: $AD" "$T"/sicil/*.yaml | xargs -n1 basename))"
echo "── iki görevde Sultan 'sağlanmadı' (mühürdar ✓ vermişti) → sicildeki kaçırma satırı: $n"
echo "── $d"
echo "── özlüğü olmayan MUHAKKIK'e yazım: rc $rm_ (3 = yazılmadı)"
echo "── seviye-lint (gerçek sicil kopyası): önce rc $l0 · sonra rc $l1 · çıktı $(diff -q "$T/lint-once" "$T/lint-sonra" >/dev/null && echo AYNI || echo FARKLI)"
ok=0; [ "$n" = 2 ] && [ "$d" = "durum: askida" ] && [ "$rm_" = 3 ] && [ $l1 -eq 0 ] && diff -q "$T/lint-once" "$T/lint-sonra" >/dev/null && ok=1
echo "── SONUÇ: $([ $ok = 1 ] && echo '✓ sicil yazılıyor · askı hesaplanıyor · özlüksüz yazılmıyor · seviye-lint etkilenmiyor' || echo '✗')"
[ $ok = 1 ] && exit 0
exit 1
