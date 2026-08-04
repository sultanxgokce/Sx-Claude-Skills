#!/usr/bin/env bash
# ekip-onizleme.sh — bu kutudaki ekibin masalarını SÜZ → ONAR → LİSTELE.
#
# NE: Ekip-kaydındaki (registry) her üye için tmux-oturumu VAR mı, içinde Claude ÇALIŞIYOR mu
#     bakar; eksikleri kapatır; sonra Sultan-diline çevrilecek tabloyu basar (ajan adı · tmux adı ·
#     durum · geçmek/başlatmak için komut).
#
# ⚠️ NİYE GEREKLİ (nazir doğumu, 2026-07-28): `baslat-claude.sh` claude'u BULUNDUĞU terminalde
#     `exec` eder — tmux oturumu AÇMAZ. Dolayısıyla `for m in ...; do baslat-claude.sh $m; done`
#     ÇALIŞMAZ (ilk üyede exec eder, döngü biter). Ekibi ayağa kaldırmak sekme-sekme elle iş
#     hâline gelmişti (6 masa = 6 sekme). Bu script o boşluğu kapatır: oturumu KENDİ açar
#     (`new-session -d`), launcher'ı oturumun İÇİNDE koşturur.
#
# ONARIM SINIRLARI (yıkıcı-değil):
#   · oturum YOK              → `tmux new-session -d` ile açılır + launcher koşulur.
#   · oturum VAR, claude YOK  → pane BOŞTA bir kabuksa (bash/sh/zsh) `respawn-pane` ile launcher konur.
#                               Pane'de BAŞKA bir şey koşuyorsa DOKUNULMAZ (iş kesilmez) → raporlanır.
#   · oturum VAR, claude VAR  → DOKUNULMAZ.
#   · kayıtta-olmayan fazla oturum → YALNIZ RAPORLANIR. Oturum SİLİNMEZ (silme = veri-kaybı riski,
#                                    insan kararı). Bilinen sistem-oturumları ayrı işaretlenir.
#
# DÜRÜSTLÜK: ölçemediğini "yok" saymaz. tmux yoksa / registry yoksa exit=2 + sebep (sahte-yeşil yok).
# İ1: yalnız BU kutunun içine bakar — başka container'a/pane'e dokunmaz, ssh kullanmaz.
#
# Kullanım:
#   bash ekip-onizleme.sh              # süz + onar + listele (varsayılan)
#   bash ekip-onizleme.sh --kontrol    # SALT-OKUR: onarma, yalnız durumu bas
#   bash ekip-onizleme.sh --porcelain  # TAB-ayraçlı (skill tüketir)
# Env: EKIP_REPO_ROOT · EKIP_REGISTRY · EKIP_LAUNCHER (test/override)
# Çıkış: 0=hepsi ayakta · 1=eksik kaldı (onarılamayan) · 2=ortam/girdi hatası
set -uo pipefail

MOD="onar"; PORCELAIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --kontrol)   MOD="kontrol"; shift ;;
    --onar)      MOD="onar"; shift ;;
    --porcelain) PORCELAIN=1; shift ;;
    *) echo "kullanım: ekip-onizleme.sh [--kontrol|--onar] [--porcelain]" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 yok — kayıt okunamadı." >&2; exit 2; }
command -v tmux    >/dev/null 2>&1 || { echo "HATA: tmux yok — masalar ölçülemedi (bu kutuda tmux kurulu değil)." >&2; exit 2; }

# ── repo kökü ────────────────────────────────────────────────────────────────
ROOT="${EKIP_REPO_ROOT:-}"
[ -n "$ROOT" ] || ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || ROOT="$PWD"

# ── ekip-kaydı (tenant: ekip-registry · ana-hücre: aile-registry) ────────────
REG="${EKIP_REGISTRY:-}"
if [ -z "$REG" ]; then
  for c in "$ROOT/_agents/handoff/ekip-registry.yaml" "$ROOT/_agents/handoff/aile-registry.yaml"; do
    [ -f "$c" ] && { REG="$c"; break; }
  done
fi
[ -n "$REG" ] && [ -f "$REG" ] || {
  echo "HATA: ekip-kaydı bulunamadı (_agents/handoff/{ekip,aile}-registry.yaml) — kök: $ROOT" >&2
  echo "   → doğru dizinde misin? EKIP_REGISTRY=<yol> ile de verebilirsin." >&2
  exit 2; }

LAUNCHER="${EKIP_LAUNCHER:-$ROOT/scripts/baslat-claude.sh}"
SLUG="$(basename "$ROOT")"

# ── roster: 'id' + 'tmux' satırları (iki registry şeması da bu deseni taşır) ──
ROSTER="$(python3 - "$REG" <<'PY'
import re, sys
cur=None; out=[]
for ln in open(sys.argv[1], encoding="utf-8", errors="replace"):
    m = re.match(r'\s*-\s*id:\s*"?([^"\s]+)"?\s*$', ln)
    if m: cur = m.group(1); out.append([cur, ""]); continue
    m = re.match(r'\s*tmux:\s*"?([^"\s]+)"?\s*$', ln)
    if m and out and out[-1][0] == cur:
        out[-1][1] = m.group(1).split(":")[0]
for i, t in out:
    if i: print("%s\t%s" % (i, t or i))
PY
)" || { echo "HATA: ekip-kaydı okunamadı: $REG" >&2; exit 2; }
[ -n "$ROSTER" ] || { echo "HATA: ekip-kaydında üye yok: $REG (boş roster → sahte-yeşil basmam)" >&2; exit 2; }

# ── canlı ölçüm ──────────────────────────────────────────────────────────────
_oturumlar() { tmux ls -F '#{session_name}' 2>/dev/null || true; }

# ⚠️ PANE-BAĞLI TESPİT (NÂZIR bulgusu, 2026-07-28 — İLK SÜRÜMÜN HATASI):
#   İlk sürüm `ps`i GLOBAL tarayıp `claude --name <masa>` görünce "çalışıyor" diyordu; sürecin o
#   tmux pane'inde olup olmadığına BAKMIYORDU. Ajanlar tarayıcı-sekmesi terminalinde (tmux DIŞINDA)
#   koşarken skill "✅ çalışıyor" deyip `tmux attach -t <masa>` öneriyordu → kullanıcı BOŞ KABUĞA
#   bağlanıyordu. Üstelik onarım tarafı da riskliydi: global-tarama bir gün kaçırsa aynı ajan İKİNCİ
#   kez başlatılır, aynı session-id ile çift oturum açılırdı.
#   Panzehir: bir masa ancak claude o masanın pane SÜREÇ-AĞACINDA ise "çalışıyor" sayılır.
#   Ayrıca tmux DIŞINDA koşan claude ayrı bir durum olarak raporlanır (onarım ONA DOKUNMAZ).
#
# _pane_claude_masalar → "oturum<TAB>masa" (yalnız pane alt-ağacındakiler)
_pane_claude_masalar() {
  local panes; panes="$(tmux list-panes -a -F '#{session_name}|#{pane_pid}' 2>/dev/null || true)"
  [ -n "$panes" ] || return 0
  printf '%s\n' "$panes" | python3 -c '
import sys, re, subprocess
panes = [l.strip().split("|") for l in sys.stdin if "|" in l]
try:
    ps = subprocess.run(["ps","-eo","pid,ppid,args"], capture_output=True, text=True, timeout=15).stdout
except Exception:
    sys.exit(0)
cocuk = {}; arg = {}
for ln in ps.splitlines()[1:]:
    p = ln.split(None, 2)
    if len(p) < 3: continue
    try: pid, ppid = int(p[0]), int(p[1])
    except ValueError: continue
    arg[pid] = p[2]; cocuk.setdefault(ppid, []).append(pid)
desen = re.compile(r"claude .*--name (\S+)")
for sess, pp in panes:
    try: kok = int(pp)
    except ValueError: continue
    yigin = [kok]; gorulen = set()
    while yigin:
        pid = yigin.pop()
        if pid in gorulen: continue
        gorulen.add(pid)
        m = desen.search(arg.get(pid, ""))
        if m: print("%s\t%s" % (sess, m.group(1)))
        yigin.extend(cocuk.get(pid, []))
' 2>/dev/null
}

# _global_claude_masalar → makinedeki TÜM claude --name değerleri (pane-dışı tespiti için)
_global_claude_masalar() { ps -eo args 2>/dev/null | sed -n 's/.*claude .*--name \([^ ][^ ]*\).*/\1/p' | sort -u; }
_pane_komut() { tmux display-message -p -t "$1:0" '#{pane_current_command}' 2>/dev/null || true; }

ONARIM=""   # rapor satırları

_onar_masa() { # <id> <session>
  local id="$1" s="$2"
  [ "$MOD" = "onar" ] || return 0
  [ -f "$LAUNCHER" ] || { ONARIM+="  · $id: başlatıcı yok ($LAUNCHER) — onarılamadı"$'\n'; return 0; }
  if ! _oturumlar | grep -qx "$s"; then
    if tmux new-session -d -s "$s" -c "$ROOT" "bash '$LAUNCHER' '$id'" 2>/dev/null; then
      ONARIM+="  · $id: oturum yoktu → açıldı ve Claude başlatıldı"$'\n'
    else
      ONARIM+="  · $id: oturum açılamadı (tmux new-session başarısız)"$'\n'
    fi
    return 0
  fi
  # oturum var, claude yok → pane boşta bir kabuksa yerine launcher koy
  local k; k="$(_pane_komut "$s")"
  case "$k" in
    bash|sh|zsh|"")
      if tmux respawn-pane -k -t "$s:0" -c "$ROOT" "bash '$LAUNCHER' '$id'" 2>/dev/null; then
        ONARIM+="  · $id: masa boştaydı → Claude başlatıldı"$'\n'
      else
        ONARIM+="  · $id: masa boştaydı ama başlatılamadı (respawn-pane başarısız)"$'\n'
      fi ;;
    *) ONARIM+="  · $id: masada '$k' koşuyor — DOKUNULMADI (iş kesilmesin; elle bak)"$'\n' ;;
  esac
}

# _masada_mi <oturum> <masa-id> — claude O oturumun pane-ağacında mı?
_masada_mi() { printf '%s\n' "$PANE_LIST" | grep -qx "$1"$'\t'"$2"; }

# ── 1. tur: ölç + onar ───────────────────────────────────────────────────────
PANE_LIST="$(_pane_claude_masalar)"
GLOBAL_LIST="$(_global_claude_masalar)"
while IFS=$'\t' read -r id s; do
  [ -n "$id" ] || continue
  _masada_mi "$s" "$id" && continue                             # masasında çalışıyor → dokunma
  if printf '%s\n' "$GLOBAL_LIST" | grep -qx "$id"; then
    # tmux DIŞINDA koşuyor (ör. tarayıcı-sekmesi terminali). İkinci kopya başlatmak AYNI
    # session-id ile çakışma üretir → onarım YAPILMAZ, yalnız raporlanır (NÂZIR bulgusu).
    ONARIM+="  · $id: tmux DIŞINDA çalışıyor — dokunulmadı (ikinci kopya açmak çakışma üretir)"$'\n'
    continue
  fi
  _onar_masa "$id" "$s"
done <<< "$ROSTER"

# onarımdan sonra Claude'un ayağa kalkması birkaç saniye sürer → kısa bekleme (yalnız onar modunda)
if [ "$MOD" = "onar" ] && [ -n "$ONARIM" ]; then sleep 6; fi

# ── 2. tur: taze ölçüm (rapor bunun üstünden) ────────────────────────────────
OTURUMLAR="$(_oturumlar)"
PANE_LIST="$(_pane_claude_masalar)"
GLOBAL_LIST="$(_global_claude_masalar)"

SATIRLAR=""; AYAKTA=0; TOPLAM=0; DISARIDA=0
while IFS=$'\t' read -r id s; do
  [ -n "$id" ] || continue
  TOPLAM=$((TOPLAM+1))
  if _masada_mi "$s" "$id"; then
    durum="calisiyor"; AYAKTA=$((AYAKTA+1)); komut="tmux attach -t $s"
  elif printf '%s\n' "$GLOBAL_LIST" | grep -qx "$id"; then
    # ÇALIŞIYOR ama masasında değil → `tmux attach` BOŞ KABUĞA bağlar; o komutu ÖNERME.
    durum="tmux-disi"; DISARIDA=$((DISARIDA+1))
    komut="çalıştığı sekmeye/pencereye dön — 'tmux attach' seni boş kabuğa bağlar"
  elif printf '%s\n' "$OTURUMLAR" | grep -qx "$s"; then
    durum="masa-bos"; komut="tmux attach -t $s   # sonra: bash scripts/baslat-claude.sh $id"
  else
    durum="oturum-yok"; komut="tmux new-session -d -s $s -c $ROOT \"bash scripts/baslat-claude.sh $id\""
  fi
  SATIRLAR+="$id"$'\t'"$s"$'\t'"$durum"$'\t'"$komut"$'\n'
done <<< "$ROSTER"

# kayıtta-olmayan oturumlar (YALNIZ rapor — silinmez)
FAZLA=""
while read -r s; do
  [ -n "$s" ] || continue
  printf '%s\n' "$ROSTER" | cut -f2 | grep -qx "$s" && continue
  FAZLA+="$s "
done <<< "$OTURUMLAR"

RC=0; [ "$AYAKTA" -eq "$TOPLAM" ] || RC=1

if [ "$PORCELAIN" = "1" ]; then
  printf '%s' "$SATIRLAR"
  printf '#OZET\tslug=%s\tayakta=%s\ttmux-disi=%s\ttoplam=%s\tfazla=%s\tmod=%s\n' "$SLUG" "$AYAKTA" "$DISARIDA" "$TOPLAM" "${FAZLA:-yok}" "$MOD"
  [ -n "$ONARIM" ] && printf '%s' "$ONARIM" | sed 's/^  · /#ONARIM\t/'
  exit "$RC"
fi

_ek=""; [ "$DISARIDA" -gt 0 ] && _ek="  · $DISARIDA ajan tmux DIŞINDA çalışıyor"
echo "👥 EKİP · $SLUG · $AYAKTA/$TOPLAM masa ayakta$_ek   (kayıt: ${REG#"$ROOT"/})"
echo ""
# NOT: sütun-hizalama (printf %-20s) KULLANILMAZ — Türkçe adlar (MUAVİN, MİMAR…) çok-baytlı
# harf taşır, printf BAYT sayar → tablo kayar. Satır-blok biçimi bu tuzağa bağışık.
while IFS=$'\t' read -r id s d k; do
  [ -n "$id" ] || continue
  case "$d" in
    calisiyor)  isaret="✅ çalışıyor" ;;
    tmux-disi)  isaret="🟡 tmux DIŞINDA çalışıyor" ;;
    masa-bos)   isaret="⚠️ masa boş (oturum var, Claude yok)" ;;
    *)          isaret="❌ oturum yok" ;;
  esac
  echo "  $isaret — $id   [tmux: $s]"
  echo "      $k"
done <<< "$SATIRLAR"
echo ""
[ -n "$ONARIM" ] && { echo "🔧 ONARIM:"; printf '%s' "$ONARIM"; }
[ -n "$FAZLA" ] && echo "ℹ️  kayıtta olmayan oturum(lar): $FAZLA(silinmedi — sistem oturumu olabilir)"
echo "çıkış: tmux içinde Ctrl+b ardından d"
exit "$RC"
