#!/usr/bin/env bash
# diploma-olcer.sh <tescil-scripts-dizini> — G13 diploma sınavı ölçümü (önce/sonra aynı komut).
# Geçici defter ve geçici sicil; gerçek diploma defterine ve gerçek sicile yazmaz (önce/sonra varlığı ölçülür).
# 1) lastik mühürdar (sahte, her öznel G'ye GEÇTİ) → küme onu ayırt etmeli (KALDI)
# 2) GERÇEK yargıç (Codex varsa Codex, yoksa Claude — muhurdar.sh'ın kendi seçimi) → hüküm ne çıkarsa o basılır
# 3) durum: geçerli → katalog sürümü değişince bayat
set -uo pipefail
S="$(cd "$1" && pwd)"; KD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kosu-$(date +%H%M%S)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
GERCEK_DEFTER=/config/projects/Nexus/_agents/orchestration/diploma-defteri.jsonl
iz() { [ -e "$GERCEK_DEFTER" ] && sha256sum < "$GERCEK_DEFTER" || echo yok; }
once_iz="$(iz)"
if [ ! -f "$S/diploma.sh" ] || [ ! -d "$S/../sinav" ]; then
  echo "── diploma sınavı: YOK (diploma.sh $( [ -f "$S/diploma.sh" ] && echo var || echo yok) · sınav kümesi $( [ -d "$S/../sinav" ] && echo var || echo yok))"
  echo "── kadro şeması §1b: sinav.kume = null → diploma alınamaz, Mühürdarlık 'planli'da kalır"
  echo "── SONUÇ: ✗ ölçülemedi — bir mühürdarın yeterliliği sınanamıyor"; exit 1
fi
mkdir -p "$T/d" "$T/lastik"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho \x27{"structured_output":{"karar":"GECTI","not":"lastik"}}\x27\n' > "$T/lastik/claude"; chmod +x "$T/lastik/claude"
printf '{"skills":[{"id":"tescil","version":"%s"}]}\n' "$(awk -F': *' '/^version:/{print $2; exit}' "$S/../SKILL.md")" > "$T/katalog.json"
export DIPLOMA_DEFTERI="$T/d/diploma-defteri.jsonl" TESCIL_KATALOG="$T/katalog.json" SICIL_DIZIN="$T/sicil"
echo "── 1 · lastik mühürdar (her öznel G'ye GEÇTİ diyen sahte yargıç)"
env PATH="$T/lastik:/usr/bin:/bin:$(dirname "$(command -v node)")" MUHURDAR_MODEL=claude bash "$S/diploma.sh" sina LASTIK-MUHURDAR --kanit "$T/k1"; r1=$?
echo "   rc $r1"
echo "── 2 · gerçek yargıç (muhurdar.sh seçer: $(command -v codex >/dev/null && echo 'Codex var → Codex' || echo 'Codex yok → Claude'))"
bash "$S/diploma.sh" sina OLCUM-MUHURDAR --kanit "$KD"; r2=$?
echo "   rc $r2"
python3 - "$KD/sonuc.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for k, v in d["ornekler"].items():
    print(f"   {k}: yargıç {v['yargic'] or '-'} · hüküm {v['verdikt']} · düşen {','.join(v['g_dusen']) or '-'} · beklenen {v['beklenen']} {','.join(v['beklenen_kaldi'])} · {'isabet' if v['isabet'] else 'ISKA'}")
PY
echo "── 3 · durum (gerçek sicil yazıcısıyla: geçici temiz özlük — göz #412 tur 5)"
mkdir -p "$T/sicil"; printf 'personel_no: "99.001"\npersona: OLCUM-MUHURDAR\ngecmis: []\n' > "$T/sicil/99.001.yaml"
bash "$S/diploma.sh" durum OLCUM-MUHURDAR > "$T/durum.log" 2>&1; r3=$?; cat "$T/durum.log"
grep -q "sicil temiz" "$T/durum.log"; r3s=$?
printf '{"skills":[{"id":"tescil","version":"99.0.0"}]}\n' > "$T/katalog.json"
bash "$S/diploma.sh" durum OLCUM-MUHURDAR; r4=$?
echo "── defter satırları: $(wc -l < "$DIPLOMA_DEFTERI") (geçici) · gerçek defter önce/sonra: $( [ "$once_iz" = "$(iz)" ] && echo AYNI || echo DEĞİŞTİ)"
ok=1; [ "$r1" -eq 1 ] || ok=0; [ "$r4" -eq 1 ] || ok=0; [ "$once_iz" = "$(iz)" ] || ok=0
[ "$r2" -eq 0 ] && [ "$r3" -eq 0 ] && [ "$r3s" -eq 0 ] || ok=0
[ "$ok" = 1 ] && echo "── SONUÇ: ✓ lastik mühürdar kaldı · gerçek yargıç geçti · diploma türetiliyor (geçerli + sicil temiz → sürüm değişince bayat) · gerçek defter dokunulmadı" \
              || echo "── SONUÇ: ✗ (lastik rc $r1 · gerçek rc $r2 · durum rc $r3/$r4 · sicil temiz rc $r3s)"
[ "$ok" = 1 ]
