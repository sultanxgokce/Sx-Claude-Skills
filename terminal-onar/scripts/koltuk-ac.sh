#!/usr/bin/env bash
# koltuk-ac.sh — bir KOLTUĞU (tmux oturumu) tek komutla ölç ve aç/yeniden aç (dilim 5/5 · 13 Ekim 2026).
#
#   koltuk-ac.sh durum <ad>              → JSON: {"ad","durum","tmux","claude","hal","son","rol","resume","yol"}
#   koltuk-ac.sh ac <ad> [--eski]        → açar; --eski = eski sohbete dön (ekip-ac.sh --resume-if-known)
#
# DURUM (üçü ayrı gösterilir, Sultan: "oturum kapandı/bozuldu/silindi — tekrar açmak çok basit olmalı"):
#   yok          = tmux oturumu yok
#   claude-yok   = oturum var, içinde Claude yok (kabuk/ölü)
#   takili       = Claude var ama TAKILI_SN (vars. 900 s) süredir ekran değişmedi ve soru/girdi beklemiyor
#   canli        = Claude var, hâl normal
# YOL (kim açar): kutuda `scripts/ekip-ac.sh` + aile kaydı varsa ve koltuk kayıtlı bir rolün tmux'uysa → ekip-ac.sh
#   (TEK-KANONİK KAPI: ikinci kopya açmaz; --eski → --resume-if-known). Koltuk ANA ise → onar.sh (K0), düşerse
#   merdiven (kademe.sh). İkisi de değilse → kayıtsız koltuk: AÇILMAZ, sebebi söylenir (kimliksiz Claude başka
#   kimliğe düşer — ölçülmüş vaka). Sır değeri yok; yazma yalnız ekip-ac.sh'nin kendi flock'lu kaydına.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ortak.sh"
TAKILI_SN="${TO_TAKILI_SN:-900}"
EKIP_AC="${TO_EKIP_AC:-$PROJE/scripts/ekip-ac.sh}"
KAYIT="${AILE_REGISTRY:-$PROJE/_agents/handoff/aile-registry.yaml}"
KOLTUK_BETIK="${TO_KOLTUK_BETIK:-$BETIK_DIZ/koltuk-bagla.sh}"

json_s() { printf '%s' "$1" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()),end="")'; }
gecerli() { [[ "$1" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; }

# tmux adı → kayıttaki rol (aile-registry: `- id: X` … `tmux: "x:0"`); kayıt yoksa boş
rol_bul() {
  [ -f "$KAYIT" ] || return 0
  python3 - "$KAYIT" "$1" <<'PY'
import re, sys
reg, ad = sys.argv[1], sys.argv[2]
cur=None
for line in open(reg, encoding='utf-8'):
    m = re.match(r'\s*-\s*id:\s*(\S+)', line)
    if m: cur = m.group(1); continue
    m = re.match(r'\s*tmux:\s*["\']?([^"\'#\s]+)', line)
    if m and cur:
        t = m.group(1).split(':')[0]
        if t == ad: print(cur); break
PY
}
# aile kaydında rolün session_id'si dolu ve transcript var mı (eski sohbete dönüş MÜMKÜN mü) — ekip-ac.sh ile aynı ölçüt
resume_var() {
  [ -f "$KAYIT" ] || return 1
  python3 - "$KAYIT" "$1" "${HOME:-/config}/.claude/projects" <<'PY'
import re, sys, os, glob
reg, rol, kok = sys.argv[1], sys.argv[2], sys.argv[3]
cur=None; sid=''
for line in open(reg, encoding='utf-8'):
    m = re.match(r'\s*-\s*id:\s*(\S+)', line)
    if m: cur = m.group(1); continue
    m = re.match(r'\s*session_id:\s*["\']?([0-9a-fA-F-]{36})', line)
    if m and cur == rol: sid = m.group(1); break
ok = bool(sid) and bool(glob.glob(os.path.join(kok, '*', sid + '.jsonl')))
sys.exit(0 if ok else 1)
PY
}
durum_olc() {  # $1 ad → DURUM CLAUDE HAL SON değişkenleri
  DURUM=yok; CLAUDE=0; HAL=""; SON=0; TMUX_VAR=0
  tmux_var "$1" || return 0
  TMUX_VAR=1
  local satir; satir="$(bash "$KOLTUK_BETIK" --liste 2>/dev/null | awk -F'\t' -v a="$1" '$1==a')"
  SON="$(printf '%s' "$satir" | cut -f2)"; CLAUDE="$(printf '%s' "$satir" | cut -f3)"; HAL="$(printf '%s' "$satir" | cut -f5)"
  [ "${CLAUDE:-0}" = 1 ] || { DURUM=claude-yok; return 0; }
  local simdi; simdi=$(date +%s)
  if [ "${SON:-0}" -gt 0 ] && [ $((simdi - SON)) -ge "$TAKILI_SN" ] && [ "$HAL" != soru ] && [ "$HAL" != girdi ]; then DURUM=takili; else DURUM=canli; fi
}
yol_bul() {  # $1 ad → YOL ∈ ekip-ac | onar | yok ; ROL
  ROL="$(rol_bul "$1")"
  if [ -n "$ROL" ] && [ -x "$EKIP_AC" ]; then YOL=ekip-ac
  elif [ "$1" = "$ANA_TMUX" ]; then YOL=onar
  else YOL=yok; fi
}

KOMUT="${1:-}"; AD="${2:-}"; shift 2 2>/dev/null || true
ESKI=0; for a in "$@"; do case "$a" in --eski) ESKI=1 ;; *) echo "bilinmeyen argüman: $a" >&2; exit 2 ;; esac; done
[ -n "$AD" ] && gecerli "$AD" || { echo 'kullanım: koltuk-ac.sh durum|ac <ad> [--eski]' >&2; exit 2; }

case "$KOMUT" in
  durum)
    durum_olc "$AD"; yol_bul "$AD"
    RES=false; [ "$YOL" = ekip-ac ] && resume_var "$ROL" && RES=true
    printf '{"ad":%s,"durum":"%s","tmux":%s,"claude":%s,"hal":%s,"son":%s,"rol":%s,"resume":%s,"yol":"%s","ana":%s}\n' \
      "$(json_s "$AD")" "$DURUM" "$([ $TMUX_VAR = 1 ] && echo true || echo false)" "$([ "${CLAUDE:-0}" = 1 ] && echo true || echo false)" \
      "$(json_s "${HAL:-}")" "${SON:-0}" "$(json_s "${ROL:-}")" "$RES" "$YOL" "$([ "$AD" = "$ANA_TMUX" ] && echo true || echo false)"
    ;;
  ac)
    durum_olc "$AD"; yol_bul "$AD"
    gunluk "koltuk-ac: $AD durum=$DURUM yol=$YOL eski=$ESKI"
    case "$YOL" in
      ekip-ac)
        # takılı/Claude'suz oturumu önce kapat — ekip-ac.sh "canlı" sanıp yalnız attach komutunu basar, Claude geri gelmez
        if [ "$DURUM" = claude-yok ] || [ "$DURUM" = takili ]; then tmux kill-session -t "=$AD" 2>/dev/null; gunluk "koltuk-ac: $AD ($DURUM) kapatıldı, yeniden doğacak"; fi
        if [ "$DURUM" = canli ]; then echo "zaten canlı: $AD (ikinci kopya açılmaz)"; exit 0; fi
        ARG=(); [ $ESKI = 1 ] && ARG=(--resume-if-known)
        if bash "$EKIP_AC" "$ROL" "${ARG[@]}"; then echo "açıldı: $AD ← ekip-ac.sh $ROL ${ARG[*]:-}"; exit 0
        else echo "açılamadı: ekip-ac.sh $ROL rc=$?" >&2; exit 1; fi ;;
      onar)
        if bash "$BETIK_DIZ/onar.sh" >/dev/null 2>&1; then echo "açıldı: $AD (onar.sh K0)"; exit 0; fi
        setsid nohup bash "$BETIK_DIZ/kademe.sh" --kaynak dugme >/dev/null 2>&1 < /dev/null &
        echo "K0 yetmedi; onarım merdiveni başlatıldı (K1→K3)"; exit 3 ;;
      *)
        echo "açılamadı: '$AD' kayıtlı bir koltuk değil (aile kaydında rolü yok ya da kutuda ekip-ac.sh yok) — kimliksiz Claude açılmaz; önce işe alma (madde 6)" >&2; exit 4 ;;
    esac ;;
  *) echo 'kullanım: koltuk-ac.sh durum|ac <ad> [--eski]' >&2; exit 2 ;;
esac
