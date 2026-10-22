#!/usr/bin/env bash
# paket.test.sh — higgsfield-abonelik paketi YENİ YERİNDE çalışıyor mu?
# (TELLAL-BESIR-devir/DEVIR-SINAV.sh'ın Sx'e taşınmış hâli · 1.0.0 · görev gorev_01M4ZPG4W4PR6EB1YQ9E3DBM27)
#
# 🔴 Niçin: paketi kopyalamak, paketin çalıştığı anlamına GELMEZ. Bu ayrımı 7 Eylül'de pahalıya öğrendik:
# paket kredi tavanını ANLATIYORDU ama taşımıyordu, ve bunu ancak birileri kullanmaya kalkınca fark ederdik.
# Bu sınav, paketin ÇEKİRDEK vaatlerini kendi dizininden koşar.
#
# HERMETİK: ağa çıkmaz, kredi harcamaz, gerçek sır dosyasına ve gerçek deftere dokunmaz. Gerçek `higgsfield`
# CLI'si nerede kurulu olursa olsun ÇAĞRILMAZ: ya PATH'in başına sahte bir CLI konur ya da CLI'sız dar bir
# PATH kurulur. CI (lint.yml) her *.test.sh'ı koşturur; bu sınav orada da aynı şekilde koşar.
# KENDİ DİZİNİNDEN KOŞAR: paket kökü = bu dosyanın bir üst dizini; çağıran nereden çağırırsa çağırsın.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || { echo "paket kökü bulunamadı" >&2; exit 3; }
GECEN=0; KIRIK=0
onay() { if eval "$2" >/dev/null 2>&1; then GECEN=$((GECEN+1)); echo "  ✓ $1"; else KIRIK=$((KIRIK+1)); echo "  ✗ $1"; fi; }

# ── Sahte dünya ────────────────────────────────────────────────────────────────
#   $SAHTE/higgsfield → her çağrıda hata (rc 1): "CLI var ama ulaşılamıyor"
#   $DAR              → yalnız bash + python3 + dirname görünür: "CLI hiç yok"
#   $GOS/higgsfield   → `account status` "3000 credits" der; defter enjekte (TELLAL_HF_TSV) → ÇELİŞKİ beklenir
T="$(mktemp -d)"; trap '[ -n "${T:-}" ] && [ -d "$T" ] && rm -r -f "$T"' EXIT   # yalnız kendi geçici dizinini süpürür
SAHTE="$T/sahte"; mkdir -p "$SAHTE"
printf '#!/usr/bin/env bash\necho "[sahte higgsfield] ag yok" >&2\nexit 1\n' > "$SAHTE/higgsfield"; chmod +x "$SAHTE/higgsfield"
DAR="$T/dar"; mkdir -p "$DAR"
for a in bash python3 dirname; do ln -s "$(command -v "$a")" "$DAR/$a"; done
GOS="$T/gosterge"; mkdir -p "$GOS"
printf '#!/usr/bin/env bash\ncase "$*" in "account status") echo "ultra plan, 3000 credits" ;; *) echo "[sahte] desteklenmeyen: $*" >&2; exit 1 ;; esac\n' > "$GOS/higgsfield"; chmod +x "$GOS/higgsfield"
printf '%s\t-1.5\tspend\tflux_kontext\n' "$(python3 -c 'from datetime import datetime,timezone;print(datetime.now(timezone.utc).isoformat())')" > "$T/defter.tsv"

echo "── paket sınavı · $(pwd)"
onay "pozitif kontrol: sahte CLI gerçek CLI'yi GÖLGELİYOR (PATH başında)" '[ "$(PATH="$SAHTE:$PATH" command -v higgsfield)" = "$SAHTE/higgsfield" ]'
onay "pozitif kontrol: dar PATH'te CLI GÖRÜNMÜYOR"                        '! PATH="$DAR" /bin/bash -c "command -v higgsfield"'

onay "bogaz.lib.sh kaynak alınabiliyor"        '. scripts/bogaz.lib.sh'
# 🔴 MUAVIN'in ölçütü (2026-09-07): "kuralı BOZAN bir deneme, paketi alan kutuda KIRMIZIYA dönüyor mu?"
# bogaz.lib.sh eksikse `bogaz_kredi_tavani` 127 döner, `!` onu 0'a çevirir ve iddia GEÇMİŞ görünürdü —
# tavanın YOKLUĞU "tavan çalışıyor" diye okunurdu. Önce işlev TANIMLI mı diye sorulur, sonra ihlal denenir.
onay "kredi tavanı işlevi TANIMLI"             '. scripts/bogaz.lib.sh; declare -F bogaz_kredi_tavani'
onay "kredi tavanı ALTINDA geçiyor"            '. scripts/bogaz.lib.sh; bogaz_kredi_tavani 1.5 50 3'
onay "kredi tavanı ÜSTÜNDE REDDEDİYOR"         '. scripts/bogaz.lib.sh; declare -F bogaz_kredi_tavani && ! bogaz_kredi_tavani 32.5 50 3'
onay "kimlik kurucu sözdizimi sağlam"          'bash -n scripts/higgsfield-kimlik-kur.sh'
onay "kimlik kurucu SIRSIZ ortamda fail-closed" 'TELLAL_SIR_ENV=/dev/null bash scripts/higgsfield-kimlik-kur.sh; [ $? -ne 0 ]'
for B in scripts/*.sh; do onay "sözdizimi: $(basename "$B")" "bash -n '$B'"; done
# 🔴 MUAVIN'in isteği (2026-09-07): "krediyi defterden okuma ALIŞKANLIK olarak kalmasın, SINAVA İDDİA olarak
# girsin — kural, onu bozmanın kırmızıya döndüğü yerde yaşar."
onay "kredi okuyucu pakette ve sözdizimi sağlam"  'bash -n scripts/kredi-oku.sh'
# En kritik özellik: defteri okuyamıyorsa TAHMİN ETMEMELİ. Okunamayan defterin yerine göstergeyi koymak,
# önlemeye çalıştığımız arızanın kendisidir. İki hâl: CLI hiç yok · CLI var ama ulaşılamıyor.
onay "kredi okuyucu CLI YOKKEN REDDEDİYOR (tahmin etmez)"          'PATH="$DAR" /bin/bash scripts/kredi-oku.sh; [ $? -eq 1 ]'
onay "kredi okuyucu CLI ULAŞAMAYINCA REDDEDİYOR (sahte CLI hata)"  'PATH="$SAHTE:$PATH" /bin/bash scripts/kredi-oku.sh; [ $? -eq 1 ]'
# Başarı yolu da ağsız sınanır: enjekte defter 1,5 kredi harcama, sahte gösterge tam plan değeri → ÇELİŞKİ söylenmeli
onay "kredi okuyucu DEFTER↔GÖSTERGE çelişkisini SÖYLÜYOR (enjekte defter, ağsız)" 'out="$(PATH="$GOS:$PATH" TELLAL_HF_TSV="$T/defter.tsv" /bin/bash scripts/kredi-oku.sh)"; grep -q CELISKI <<<"$out"'
# Paketin kendi vaadi (1.0.0): betikler mutlak beceri yolundan çağrılır — göreli çağrı başka kutuda kırılıyordu.
onay "SKILL.md pakette ve sürüm damgalı (semver)"   'grep -q -E "^version: [0-9]+\.[0-9]+\.[0-9]+$" SKILL.md'
onay "SKILL.md betikleri GÖRELİ yoldan ÇAĞIRMIYOR (3DBM27)" '! grep -q -F -e "bash scripts/" -e "\$CLAUDE_PROJECT_DIR/scripts" -e "\`scripts/" SKILL.md'
onay "SKILL.md betikleri MUTLAK beceri yolundan çağırıyor"  'grep -q -F "/config/.claude/skills/higgsfield-abonelik/scripts/" SKILL.md'
onay "kredi tavanı belgesi pakette"            'test -s KREDI-TAVANI-OKU.md'
onay "defter şeması pakette"                   'test -s DEFTER-SEMA.md'
onay "taşınmayanlar listesi pakette (staging zinciri bu pakette yok — belgeli)" 'test -s DEVIR-YOKSAY.txt'

echo "── geçen=$GECEN kırık=$KIRIK"
[ "$KIRIK" -eq 0 ] || { echo "SONUC: KIRMIZI — paket yeni yerinde ÇALIŞMIYOR"; exit 1; }
echo "SONUC: GECTI"
