#!/usr/bin/env bash
# muhurdar.sh — Mühürdarlık · Tescil vazifesinin usulü (G8 · Sultan D1 22 Eki "Üç alana böl"; kadro şeması §4-§5 tescil-teslim-sina).
# tescil-run.sh'ı yeniden yazmaz, ÜSTÜNE kurar. Usul adımları (şemadaki sırayla):
#   1 kapı   biçimsiz gereklilik belgesini reddeder ............ tescil-run (gereklilik.py → İSİMLİ-RED)
#   2 kapı   yazan = mühürdar ise koşuyu reddeder .............. BURADA (kendi işini mühürleyemez → İSİMLİ-RED kendi-isi)
#   3 beceri G1..Gn'yi kör sınar, 👤 Sultan denemesini atlar ... tescil-run (mekanik) + BURADA (öznel G → taze yargıç)
#   4 beceri kanıt JSON'u sınır + redaksiyonla mühürlenir ...... tescil-run (g-kosucu → sert-teslim)
#   5 👤     Sultan denemesi satırları teslim ekranında ........ BURADA YAPILMAZ (A06): MUHUR'da "SULTANDA" diye durur
# Kör: yargıç yalnız GEREKLILIK satırını, izole rubriği, G'nin `hedef:` dosyasını ve TAZE kanıtı görür; inşacının raporu,
#   transkripti, commit mesajı istem kurulurken HİÇ okunmaz. Temiz koşu: her öznel G kendi yeni oturumunda (codex --ephemeral /
#   claude -p), önceki G'nin yargısı sonrakine taşınmaz. Model: Codex erişilebilirse Codex, değilse Claude (karar 2);
#   Codex düşerse Claude'a geçilir ve MUHUR'a yazılır. Yargıcın bozuk/eksik cevabı GEÇTİ sayılmaz → EMIN-DEGILIM (eskalasyon).
#
# Kullanım:
#   AGENT_NAME=<mühürdar> muhurdar.sh <iş> --gereklilik <yol> --worktree <yol> --out <dizin> --yazan <inşacı>
#                                     [--head-sha <sha>] [--deneme <n>] [--tatbikat] [--bassiz]
#   --bassiz (S14 başsız şapka): taşıyan bekleme süresinde başlamadı, yedek koşu. Usul AYNI (biçim → kendi-işi → mekanik → kör
#            yargıç); mühür başlığı + özet başsız olduğunu taşır, sicil mühür kaydı bassiz: e (taşıyanın siciline). Kod yazmaz, birleştirmez.
# RC: tescil-run ile aynı — 0=GECTI · 1=KALDI · 2=kullanım/harness · 3=ESKALASYON|KATMAN2-BEKLIYOR · 4=İSİMLİ-RED
#     · 5=mühür basıldı ama özlüğü olan mühürdarın siciline DÜŞMEDİ (verdikt özette; özet `sicil: dusmedi …`)
# Ortam: MUHURDAR_MODEL=claude (Codex'i bilerek atla) · MUHURDAR_ZAMAN_ASIMI (sn, varsayılan 900)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/lib"

kullanim() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }
IS="${1:-}"; [ -n "$IS" ] || kullanim; case "$IS" in --*) kullanim ;; esac; shift
GEREKLILIK="" WORKTREE="" OUT="" YAZAN="" HEAD_SHA="" DENEME=1 TATBIKAT=() BASSIZ=()
while [ $# -gt 0 ]; do
  case "$1" in
    --gereklilik) GEREKLILIK="${2:-}"; shift 2 ;;
    --worktree)   WORKTREE="${2:-}"; shift 2 ;;
    --out)        OUT="${2:-}"; shift 2 ;;
    --yazan)      YAZAN="${2:-}"; shift 2 ;;
    --head-sha)   HEAD_SHA="${2:-}"; shift 2 ;;
    --deneme)     DENEME="${2:-1}"; shift 2 ;;
    --tatbikat)   TATBIKAT=(--tatbikat); shift ;;
    --bassiz)     BASSIZ=(--bassiz); shift ;;
    *) echo "muhurdar: bilinmeyen argüman: $1 (yargıca rapor/transkript verilemez — kör protokol)" >&2; exit 2 ;;
  esac
done
[ -n "$GEREKLILIK" ] && [ -n "$WORKTREE" ] && [ -n "$OUT" ] || kullanim
MUHURDAR="${AGENT_NAME:-}"
[ -n "$MUHURDAR" ] || { echo "muhurdar: mühürdarın kimliği yok (AGENT_NAME) — kim mühürlediği bilinmeden mühür basılmaz" >&2; exit 2; }
[ -n "$YAZAN" ] || { echo "muhurdar: --yazan (işi yapanın adı, kartın aldı'sı) zorunlu — 'kendi işini mühürleyemez' ölçülmeden koşulmaz" >&2; exit 2; }
ZA="${MUHURDAR_ZAMAN_ASIMI:-900}"; case "$ZA" in ''|*[!0-9]*|0) ZA=900 ;; esac
mkdir -p "$OUT"
TR=(bash "$HERE/tescil-run.sh" "$IS" --gereklilik "$GEREKLILIK" --worktree "$WORKTREE" --out "$OUT" --deneme "$DENEME"
    ${HEAD_SHA:+--head-sha "$HEAD_SHA"} ${TATBIKAT[@]+"${TATBIKAT[@]}"})

# ── adım 1 · biçim kapısı ÖNCE (usul sırası; göz #409 tur 1): biçimsiz belge kendi-işi olsa da 'gereklilik-*' reddini alır ──
if [ ! -f "$GEREKLILIK" ] || [ -n "$(python3 "$LIB/gereklilik.py" parse "$GEREKLILIK" 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["red"]["ad"] if d["red"] else "")' 2>/dev/null || echo bozuk)" ]; then
  "${TR[@]}"; exit $?   # tescil-run İSİMLİ-RED MUHUR'unu yazar (gereklilik-eksik | gereklilik-jenerik)
fi

# ── adım 2 · kendi işini mühürleyemez (kadro şeması §7: iş anında ölçülür) ──────────────────────────────
# Türkçe harf katlama: 'MUHAKKİK'.casefold() 'MUHAKKIK' ile eşleşmez — taşıyıcı MUHAKKİK (Sultan D1 22 Eki), iki yazım da yaşıyor
ayni="$(python3 -c 'import sys; k=lambda s: s.strip().replace("İ","I").replace("ı","i").casefold(); print(1 if k(sys.argv[1])==k(sys.argv[2]) else 0)' "$YAZAN" "$MUHURDAR")"
if [ "$ayni" = 1 ]; then
  python3 "$LIB/muhur.py" red --out "$OUT" --kart "$IS" --deneme "$DENEME" --ad "kendi-isi" \
    --sebep "işi yapan ($YAZAN) ile mühürdar ($MUHURDAR) aynı — kendi işini mühürleyemez (G8, kadro şeması §7); başka mühürdar ya da başsız şapka" \
    ${HEAD_SHA:+--head-sha "$HEAD_SHA"} >/dev/null
  echo "muhurdar: İSİMLİ-RED kendi-isi — $YAZAN kendi işini mühürleyemez"
  exit 4
fi

# ── adım 1 · 3 · 4 · mekanik G'ler (tescil-run: biçim kapısı + taze koşu + redaksiyon) ───────────────────
"${TR[@]}"; rc=$?
[ "$rc" -eq 3 ] || [ "$rc" -le 1 ] || [ "$rc" -eq 4 ] || exit "$rc"
[ "$rc" -eq 4 ] && exit 4
ACIK="$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1])).get("oznel_acik") or []))' "$OUT/muhur-ozet.json" 2>/dev/null)"

# ── adım 3 · öznel G'ler: her biri TAZE bir yargıç oturumunda, kör istemle ────────────────────────────────
SEMA="$OUT/.yargic-sema.json"
printf '%s' '{"type":"object","additionalProperties":false,"required":["karar","not"],"properties":{"karar":{"type":"string","enum":["GECTI","KALDI","EMIN-DEGILIM"]},"not":{"type":"string"}}}' > "$SEMA"
K2=(); YARGIC=""
codex_var() { [ "${MUHURDAR_MODEL:-}" != claude ] && command -v codex >/dev/null 2>&1; }
for G in $ACIK; do
  D="$OUT/yargi-$G"; mkdir -p "$D"; find "$D" -mindepth 1 -delete 2>/dev/null
  # Kör istem: YALNIZ gereklilik satırı + rubrik + hedef dosya + mekanik kanıtların sonuç tablosu. Worktree taranmaz.
  if ! python3 "$LIB/kor-istem.py" "$OUT/gereklilik.json" "$G" "$WORKTREE" "$OUT" "$(cd "$(dirname "$GEREKLILIK")" && pwd)" > "$D/istem.md" 2> "$D/istem.err"; then
    K2+=(--katman2 "$G=EMIN-DEGILIM:kör istem kurulamadı ($(head -1 "$D/istem.err"))"); YARGIC="${YARGIC:+$YARGIC,}$G=yok"; continue
  fi
  model=""; yrc=1
  if codex_var; then
    model=codex
    timeout -k 30 "$ZA" codex exec -s read-only --skip-git-repo-check --ephemeral -C "$D" --output-schema "$SEMA" -o "$D/cevap.json" \
      "$(cat "$D/istem.md")" </dev/null >"$D/log" 2>&1; yrc=$?
    [ "$yrc" -eq 0 ] || echo "muhurdar: $G codex düştü (rc $yrc) → Claude ile yeni oturum" >&2
  fi
  # Codex düşerse — zaman aşımı DAHİL (göz #409 tur 2) — Claude'a yeni oturumla geçilir
  [ "$yrc" -eq 124 ] && model="codex(zaman-aşımı)"
  if [ "$yrc" -ne 0 ]; then
    if command -v claude >/dev/null 2>&1; then
      model="${model:+$model→}claude"
      timeout -k 30 "$ZA" claude -p --output-format json --json-schema "$(cat "$SEMA")" < "$D/istem.md" > "$D/claude.json" 2>"$D/log"; yrc=$?
      python3 -c "import json,sys;d=json.load(open(sys.argv[1]));r=d.get('structured_output') or d.get('result');print(r if isinstance(r,str) else json.dumps(r,ensure_ascii=False))" "$D/claude.json" > "$D/cevap.json" 2>/dev/null
    else
      model="${model:+$model→}yok"
    fi
  fi
  [ "$yrc" -eq 124 ] && model="$model(zaman-aşımı)"   # Claude da aşarsa
  YARGIC="${YARGIC:+$YARGIC,}$G=$model"
  karar="$(python3 - "$D/cevap.json" <<'PY' 2>/dev/null
import json, sys, re
try:
    d = json.load(open(sys.argv[1]))
    k = d.get("karar"); n = re.sub(r"[\r\n]+", " ", str(d.get("not", "")))[:300]
    print(f"{k}:{n}" if k in ("GECTI", "KALDI", "EMIN-DEGILIM") else "")
except Exception:
    print("")
PY
)"
  # bozuk / eksik / zaman aşımı → GEÇTİ DEĞİL (SKILL.md §3: emin değilim = eskalasyon)
  [ -n "$karar" ] || karar="EMIN-DEGILIM:yargıç geçerli karar dönmedi (model $model, rc $yrc)"
  K2+=(--katman2 "$G=$karar")
done

# ── MUHUR: yargıcın GÖRDÜĞÜ kanıtla mühürlenir — mekanik G'ler YENİDEN KOŞULMAZ (göz #409 tur 2: yan etkili ya da kararsız bir G'de
#    yargıç bir ölçüme, mühür başka ölçüme dayanırdı). Bu koşunun mekanik ölçümü tazedir; öznel kararlar + mühürdar başlığı işlenir.
SHA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("worktree_head_sha") or "")' "$OUT/muhur-ozet.json" 2>/dev/null)"
[ -n "$SHA" ] || SHA="$(git -C "$WORKTREE" rev-parse HEAD 2>/dev/null)"
python3 "$LIB/muhur.py" uret --out "$OUT" --kart "$IS" --deneme "$DENEME" --head-sha "$SHA" ${K2[@]+"${K2[@]}"} \
  ${TATBIKAT[@]+"${TATBIKAT[@]}"} ${BASSIZ[@]+"${BASSIZ[@]}"} --muhurdar "$MUHURDAR" --yazan "$YAZAN" ${YARGIC:+--yargic "$YARGIC"} >/dev/null; rc=$?
bash "$HERE/muhur-lint.sh" "$OUT" >/dev/null 2>&1 || echo "muhurdar: muhur-lint UYARI (report-only, verdikt etkilenmez)" >&2
# sicil (G11 · S10): her mühür mühürdarın siciline düşer — pencere bunlardan sayılır; Sultan'ın satırları sonra teslim-isle ile gelir.
#   Özlük dosyası yoksa mühür DÜŞMEZ, söylenir (özlük KÂHYA'nın işi). Özlük VARKEN yazım düşerse sessiz geçilmez (göz #411 tur 4):
#   pencere bir olay eksik sayardı → özete `sicil: dusmedi …` ve rc 5. Verdikt değişmez (MUHUR.md + özette durur).
_VER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("verdikt",""))' "$OUT/muhur-ozet.json" 2>/dev/null)"
if [ -n "$_VER" ] && [ "$_VER" != RED ]; then
  if ! python3 "$LIB/sicil.py" muhur "$MUHURDAR" --gorev "$IS" --verdikt "$_VER" --yoksa-gec ${BASSIZ[@]+"${BASSIZ[@]}"} \
    --el-kitabi-surum "$(awk -F': *' '/^version:/{print $2; exit}' "$HERE/../SKILL.md")" >/dev/null 2>"$OUT/.sicil.err"; then
    _SE="$(grep -m1 -v '^Traceback' "$OUT/.sicil.err")"
    echo "muhurdar: sicile mühür kaydı DÜŞMEDİ — $_SE (rc 5; pencere bu mühürü saymaz, sicile elle bakılmalı)" >&2
    python3 - "$OUT/muhur-ozet.json" "dusmedi: $_SE" <<'PYS' 2>/dev/null
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["sicil"] = sys.argv[2]; json.dump(d, open(p, "w"), ensure_ascii=False, indent=1)
PYS
    rc=5
  fi
fi
V="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["verdikt"], "· 👤 Sultanda:", " ".join(d.get("sultan_denemesi") or []) or "yok")' "$OUT/muhur-ozet.json" 2>/dev/null)"
echo "muhurdar: $IS · mühürdar $MUHURDAR · yazan $YAZAN · verdikt $V${YARGIC:+ · yargıç $YARGIC}${BASSIZ[@]:+ · BAŞSIZ ŞAPKA}"
exit "$rc"
