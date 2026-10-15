#!/usr/bin/env bash
# imar-defter.test.sh — hâl zincirinin hermetik sınavı. Gerçek Bulgu Defteri'ne DOKUNMAZ
# (BULGU_KOK ile sahte kök; defter-yaz.py ve defter_ortak.py bu değişkeni tanır).
# Kapılar: gelen→seçildi (A06: kaynaksız damga YOK) → yapılıyor (seçilmeden inşa YOK) → canlı (sürüm+ölçüm)
#          → onaylandı (yalnız Sultan satırı) · sıra atlanamaz · damga tekrarı reddedilir.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# geçici dizin: kancanın yasakladığı dizgi yerine meşru yol (bileyi/guvenli-sil.sh); araç yoksa
# 'rm -r' ile devam eder (zorlamasız, geçici dizin için yeterli) — ölçüldü 13 Ekim, bekçi sarısı kapandı.
GS="/config/.claude/skills/bileyi/scripts/guvenli-sil.sh"
if [ -r "$GS" ]; then T="$(bash "$GS" --yeni defter-sinav)"; trap 'bash "$GS" "$T" >/dev/null 2>&1' EXIT
else T="$(mktemp -d)"; trap 'rm -r "$T" 2>/dev/null' EXIT; fi
mkdir -p "$T/bulgu-defteri"
printf '{"bulgular": [], "sonSayi": 0}\n' > "$T/bulgu-defteri/bulgular.json"
export BULGU_KOK="$T" BULGULAR_JSON="$T/bulgu-defteri/bulgular.json" DEFTER_KIM=sinav FIKIR_MEZARLIGI="$T/mezarlik.jsonl"
D="$REPO/scripts/imar-defter.py"; Y="/config/.ic-sayfa/defter-yaz.py"
GEC=0; DUS=0
kapi(){ local ad="$1" bek="$2"; shift 2; local out; out="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" -eq "$bek" ]; then echo "✅ $ad"; GEC=$((GEC+1)); else echo "❌ $ad: beklenen rc=$bek, gelen rc=$rc · $out"; DUS=$((DUS+1)); fi; }
konum(){ python3 "$D" zincir | awk -v n="$1" '$1==n{print $2}'; }
esit(){ if [ "$2" = "$3" ]; then echo "✅ $1 = $2"; GEC=$((GEC+1)); else echo "❌ $1: beklenen '$3', gelen '$2'"; DUS=$((DUS+1)); fi; }

python3 "$Y" yeni --baslik "Sınav fikri A" --hal acik --not "sınav" --kim sinav >/dev/null || { echo "ÖLÇÜLEMEDİ: sahte deftere yazılamadı"; exit 3; }
python3 "$Y" yeni --baslik "Sınav fikri B" --hal acik --not "sınav" --kim sinav >/dev/null
esit "yeni kayıt 'gelen'"            "$(konum S-1)" "gelen"
kapi "A06: kaynaksız seçildi reddi"   2 python3 "$D" secildi S-1
kapi "eşik altı otomatik reddi"       2 python3 "$D" secildi S-1 --otomatik --puan 74
kapi "seçilmeden yapılıyor reddi"     2 python3 "$D" yapiliyor S-1 --not x
kapi "gelen→canlı atlama reddi"       2 python3 "$D" canli S-1 --surum a --olcum b
kapi "gelen→onay reddi"               2 python3 "$D" onaylandi S-1 --sultan "olsun"
esit "redlerden sonra hâlâ 'gelen'"  "$(konum S-1)" "gelen"
kapi "Sultan satırıyla seçildi"       0 python3 "$D" secildi S-1 --sultan "bunu yapalım"
esit "konum seçildi"                  "$(konum S-1)" "seçildi"
kapi "ikinci seçildi damgası reddi"   2 python3 "$D" secildi S-1 --sultan "yine"
kapi "otomatik ≥75 seçildi (B)"       0 python3 "$D" secildi S-2 --otomatik --puan 75
kapi "yapılıyor notsuz reddi"         2 python3 "$D" yapiliyor S-1
kapi "yapılıyor"                      0 python3 "$D" yapiliyor S-1 --not "demoya kondu"
esit "konum yapılıyor"                "$(konum S-1)" "yapılıyor"
kapi "canlı ölçümsüz reddi"           2 python3 "$D" canli S-1 --surum abc
kapi "canlı"                          0 python3 "$D" canli S-1 --surum abc1234 --olcum "10 ölçüde 3 uyarı"
esit "konum canlı"                    "$(konum S-1)" "canlı"
kapi "A06: Sultan satırsız onay reddi" 2 python3 "$D" onaylandi S-1
esit "red sonrası hâlâ canlı"         "$(konum S-1)" "canlı"
kapi "onaylandı (Sultan satırı)"      0 python3 "$D" onaylandi S-1 --sultan "tamam, onaylıyorum"
esit "konum onaylandı"                "$(konum S-1)" "onaylandı"
# öldürme (M10): yalnız gelen/seçildi, yalnız Sultan satırıyla, mezarlığa sebebiyle düşer
python3 "$Y" yeni --baslik "Sınav fikri C" --hal acik --not "sınav" --kim sinav >/dev/null
kapi "A06: Sultan satırsız öldürme reddi" 2 python3 "$D" oldur S-3
kapi "onaylanmış kayıt öldürülemez"      2 python3 "$D" oldur S-1 --sultan "öldür"
kapi "öldür (Sultan satırı)"            0 python3 "$D" oldur S-3 --sultan "bunu istemiyorum" --not "pazar yok"
esit "konum öldü"                        "$(konum S-3)" "öldü"
M="$(grep -c '"kayit": "S-3"' "$FIKIR_MEZARLIGI" 2>/dev/null)"; esit "mezarlıkta kayıt" "${M:-0}" "1"
out="$(python3 "$D" zincir | head -1)"
if printf '%s' "$out" | grep -q "gelen 0 → seçildi 1 → yapılıyor 0 → canlı 0 → onaylandı 1 · mezarlık 1"; then echo "✅ sayım doğru"; GEC=$((GEC+1)); else echo "❌ sayım: $out"; DUS=$((DUS+1)); fi
# 🔴 KUTU ÇİVİSİ SÖKÜLDÜ: gerçek mezarlık yolu artık PROFİLDEN gelir (IMAR_GERCEK_MEZARLIK).
#    Eski satır /config/projects/mihenk/... diye çiviliydi; başka kutuda o dosya YOK olduğu için
#    grep 0 döner ve kapı DAİMA yeşil basardı — yani sızıntıyı değil dosyanın yokluğunu ölçerdi.
#    Yol verilmediyse kapı "ölçülemedi" der ve geçti SAYILMAZ (sessiz yeşil yok).
if [ -n "${IMAR_GERCEK_MEZARLIK:-}" ] && [ -f "${IMAR_GERCEK_MEZARLIK}" ]; then
  G2="$(grep -c "Sınav fikri" "$IMAR_GERCEK_MEZARLIK" 2>/dev/null)"; esit "gerçek mezarlığa sızıntı" "${G2:-0}" "0"
else
  echo "⏭️  gerçek mezarlığa sızıntı kapısı ATLANDI (IMAR_GERCEK_MEZARLIK yok ya da dosya yok) — ölçülemedi, geçti sayılmaz"
fi
# gerçek deftere sızmadı mı (negatif kontrol)
G="$(python3 -c "import json;d=json.load(open('/config/.ic-sayfa/bulgu-defteri/bulgular.json'));print(sum(1 for k in (d if isinstance(d,list) else d.get('bulgular',[])) if 'Sınav fikri' in k.get('baslik','')))")"
esit "gerçek deftere sızıntı" "$G" "0"
echo "— $GEC geçti · $DUS düştü"
[ "$DUS" -eq 0 ]
