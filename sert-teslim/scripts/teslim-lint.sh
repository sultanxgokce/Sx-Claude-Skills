#!/bin/sh
# teslim-lint.sh — TESLİM-GATE'in mekanik denetçisi (matris-lint'in PARAMETRİK sarıcısı; kendi
# format-regex'i YOK — tek-gramer kuralı). 6-koşulun makine-denetlenebilir kısmını zorlar:
#   K1 matris: matris-lint TEMİZ + 0-bekliyor + 0-fail (engelli varsa yalnız KISMİ-modda geçer)
#   K3 A4-MUTABAKAT: a4/eslesme.json var + a4_dogrula.mjs SAYIMSAL geçer
#   K4 canlı-smoke: kanit/smoke.json var + rc=0
#   K6 veri-rejimi: matris'te sentetik/mock varsa teslim-raporunda disclaimer-satırı var
#   (K2 adversarial-TAM ve K5 açık-bulgu-kesişimi orkestra-düzeyinde denetlenir — bkz. SKILL.md)
# Kullanım: teslim-lint.sh <feature-dizini>   (içinde: MATRIS.md, kanit/, a4/, TESLIM-RAPORU.md)
set -eu

FEATURE_DIZIN="${1:?kullanım: teslim-lint.sh <feature-dizini>}"
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CORE="$SELF_DIR/../core"

MATRIS="$FEATURE_DIZIN/MATRIS.md"
KANIT="$FEATURE_DIZIN/kanit"
[ -f "$MATRIS" ] || { echo "teslim-lint: MATRIS.md yok: $MATRIS" >&2; exit 1; }
[ -d "$KANIT" ] || { echo "teslim-lint: kanit/ yok" >&2; exit 1; }

IHLAL=0
ihlal() { echo "teslim-lint İHLAL: $*" >&2; IHLAL=1; }

# ── K1a: format-denetimi (parametrik çağrı — tek-gramer) ─────────────
sh "$CORE/matris-lint.sh" "$MATRIS" "$KANIT" || IHLAL=1

# ── K1b: 0-bekliyor + 0-fail (durum-kolonu sayımı) ───────────────────
SAYIM=$(awk 'BEGIN{FS="|"; b=0; f=0; k=0; e=0}
  $2 ~ /^[ \t]*M[0-9]+[ \t]*$/ {
    d=$10; gsub(/^[ \t]+|[ \t]+$/,"",d)
    if (d=="bekliyor") b++
    else if (d=="fail") f++
    else if (d=="kanitli") k++
    else e++
  }
  END{printf "%d %d %d %d", b, f, k, e}' "$MATRIS")
BEKLIYOR=$(echo "$SAYIM" | cut -d' ' -f1)
FAIL=$(echo "$SAYIM" | cut -d' ' -f2)
KANITLI=$(echo "$SAYIM" | cut -d' ' -f3)
DIGER=$(echo "$SAYIM" | cut -d' ' -f4)
echo "teslim-lint sayım: kanitli=$KANITLI bekliyor=$BEKLIYOR fail=$FAIL engelli/OLCULEMEZ=$DIGER"
[ "$BEKLIYOR" -eq 0 ] || ihlal "$BEKLIYOR satır hâlâ 'bekliyor' — teslim ÇIKAMAZ"
[ "$FAIL" -eq 0 ] || ihlal "$FAIL satır 'fail' — teslim ÇIKAMAZ"
[ "$KANITLI" -gt 0 ] || ihlal "hiç kanitli-satır yok — boş-matris teslim değildir"

# ── K1c: §1.5 SAYAÇ-BASELINE — gate_cmds hash-sabit + counter-floor (filtreli-koşum gaming-kilit) ─
# baseline.json varsa ZORUNLU-denetlenir (yoksa geriye-uyum: baseline-kurulmamış eski-teslim atlanır).
RAPOR="$FEATURE_DIZIN/TESLIM-RAPORU.md"
BASELINE="$FEATURE_DIZIN/baseline.json"
if [ -f "$BASELINE" ]; then
  BL_OUT=$(node "$CORE/sayac_baseline.mjs" --baseline "$BASELINE" --kanit "$KANIT") || ihlal "§1.5 sayaç-baseline DÜŞTÜ (yukarıdaki sayac-baseline İHLAL satırları)"
  SAYAC_KANITSIZ=$(printf '%s' "$BL_OUT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).sayac_kanitsiz))}catch{process.stdout.write("false")}})')
  if [ "$SAYAC_KANITSIZ" = "true" ]; then
    # doktrin §1.5: hiç sayaçlı-runner yoksa teslim-raporu 'SAYAÇ-KANITSIZ' manşeti taşımalı
    if [ -f "$RAPOR" ]; then
      grep -q 'SAYAÇ-KANITSIZ' "$RAPOR" || ihlal "sayaçlı-runner yok/geçmedi → teslim-raporu 'SAYAÇ-KANITSIZ' manşeti taşımalı (sessiz-yeşil YOK)"
    else
      ihlal "sayaçlı-runner yok/geçmedi ama TESLIM-RAPORU.md yok — manşet-denetimi yapılamadı"
    fi
  fi
else
  # baseline.json YOK: sayaçlı-runner gate-kanıtı varsa §1.5-kontrolü atlanmış demektir → GÖRÜNÜR UYARI.
  # (Grandfather: F1-öncesi mühürlü-teslimler geçer; KUR gelecek-teslimlerde baseline.json'ı ZORUNLU üretir.)
  if ls "$KANIT"/gate-*.json >/dev/null 2>&1 && \
     node -e 'const fs=require("fs"),p=process.argv[1];let c=false;for(const f of fs.readdirSync(p)){if(/^gate-.*\.json$/.test(f)){try{if(JSON.parse(fs.readFileSync(p+"/"+f,"utf8")).counters)c=true}catch{}}}process.exit(c?0:1)' "$KANIT"; then
    echo "teslim-lint UYARI: baseline.json YOK ama sayaçlı gate-kanıtı var — §1.5 sayaç-kontrolü ATLANDI (grandfather; KUR gelecek-teslimde baseline.json ZORUNLU üretmeli)" >&2
  fi
fi

# ── K3: A4-MUTABAKAT sayımsal-doğrulama ──────────────────────────────
if [ -f "$FEATURE_DIZIN/a4/eslesme.json" ] && [ -f "$FEATURE_DIZIN/a4/cumleler.json" ]; then
  node "$CORE/a4_dogrula.mjs" \
    --cumleler "$FEATURE_DIZIN/a4/cumleler.json" \
    --eslesme "$FEATURE_DIZIN/a4/eslesme.json" \
    --matris "$MATRIS" >"$FEATURE_DIZIN/a4/dogrulama.json" \
    || ihlal "A4-MUTABAKAT sayımsal-doğrulama DÜŞTÜ (a4/dogrulama.json'a bak)"
else
  ihlal "A4-MUTABAKAT eksik: a4/cumleler.json + a4/eslesme.json gerekli (taze-subagent koşumu)"
fi

# ── K4: canlı-smoke kanıtı — DÖRTLÜ-DENETİM (elle-'{"rc":0}' sömürüsünü kapatır) ─────
# smoke.json trust_boundary'nin ürettiği GERÇEK kanıt-şeması olmalı: rc=0 + komut_sha256(64-hex) +
# started_at/finished_at + finished_at>started_at. Elle-uydurma bu alanları taşımaz → FAIL.
# (Tam config-smoke-hash bağı = F4/FAZ-2; bu, şekil-doğrulamasıyla bypass'ı kapatan fix-now.)
if [ -f "$KANIT/smoke.json" ]; then
  SMOKE_OK=$(node -e '
    try {
      const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const hexOk = typeof j.komut_sha256 === "string" && /^[0-9a-f]{64}$/.test(j.komut_sha256);
      const tsOk = typeof j.started_at === "string" && typeof j.finished_at === "string"
                   && Date.parse(j.finished_at) >= Date.parse(j.started_at);
      if (j.rc !== 0) { console.log("rc:" + j.rc); process.exit(0); }
      if (!hexOk) { console.log("hash-yok"); process.exit(0); }
      if (!tsOk) { console.log("timestamp-gecersiz"); process.exit(0); }
      console.log("OK");
    } catch (e) { console.log("gecersiz-json"); }
  ' "$KANIT/smoke.json")
  [ "$SMOKE_OK" = "OK" ] || ihlal "canlı-smoke dörtlü-denetim düştü ($SMOKE_OK) — trust_boundary-kanıtı değil/rc≠0"
else
  ihlal "canlı-smoke kanıtı yok: kanit/smoke.json"
fi

# ── UNTRUSTED-QUOTE çit-dengesi (talimat-günlüğü) — açılan her ```untrusted kapanmalı ─
TG="$FEATURE_DIZIN/TALIMAT-GUNLUGU.md"
if [ -f "$TG" ]; then
  FENCE=$(grep -c '```untrusted' "$TG" || true)
  CLOSE=$(awk '/```untrusted/{u=1;next} /```/{if(u){c++;u=0}} END{print c+0}' "$TG")
  [ "$FENCE" = "$CLOSE" ] || ihlal "UNTRUSTED-QUOTE çit-dengesizliği: $FENCE açılış / $CLOSE kapanış (sayfa/DB-metni açık-çitte kalmış olabilir)"
fi

# ── K6: veri-rejimi disclaimer'ı ─────────────────────────────────────
RAPOR="$FEATURE_DIZIN/TESLIM-RAPORU.md"
if grep -qE '\|[ \t]*(sentetik|mock)[ \t]*\|' "$MATRIS"; then
  if [ -f "$RAPOR" ]; then
    grep -qiE 'sentetik|mock' "$RAPOR" || ihlal "matris sentetik/mock-kanıt içeriyor ama raporda disclaimer yok"
  else
    ihlal "TESLIM-RAPORU.md yok (disclaimer-denetimi yapılamadı)"
  fi
fi

if [ "$IHLAL" -eq 0 ]; then
  echo "teslim-lint: GATE-TEMİZ ($FEATURE_DIZIN) — mekanik-koşullar sağlandı"
  exit 0
fi
echo "teslim-lint: GATE-KAPALI — yukarıdaki ihlaller kapanmadan teslim-raporu GEÇERSİZ" >&2
exit 1
