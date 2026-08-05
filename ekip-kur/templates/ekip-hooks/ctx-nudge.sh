#!/usr/bin/env bash
# ctx-nudge.sh — context-eşik nudge PostToolUse hook'u (ekip-kur koordinasyon substratı)
#
# NEDEN: compact'ların çoğu KULLANICI-tetikli olur; oturumlar session-limit'e çarpar, Sultan "compact öner"
# talimatını tek oturumda defalarca tekrarlar. Bu hook context ~%65'i aşınca ajana tek-satır hatırlatma
# enjekte eder — compact-önerme yükü Sultan'dan ajana geçer.
#
# DAVRANIŞ: transcript'in kuyruğundan son assistant-usage'ı okur; doluluk >= eşikse
# PostToolUse additionalContext basar. Oran-sınırlı (koşum: 90sn · nudge: 600sn/oturum).
# Fail-open: python3 yoksa / transcript okunamazsa SESSİZ çıkar. Hiçbir şeyi bloklamaz.
#
# Ayar: CTX_NUDGE_PCT (default 65) · CTX_NUDGE_WINDOW (boşsa MODEL-FARKINDALIK:
#   Fable/Mythos/[1m] → 1M · Opus-4.8/4.7 & Sonnet-5 → 500k (auto-compact penceresi) · değilse 200k.
#   ⚠️ transcript message.model ALIAS'siz gelir ("[1m]" suffix'i YOK; ör. bare "claude-opus-4-8")
#   → 1M-oturumu [1m]-string'iyle tespit ETMEZ → bare-ID map + 500k düzeltmesi eklendi.
#   Pencere DAİMA bir TAHMİN — kesin doluluk yalnız /context; nudge-mesajı bunu açıkça söyler.
# Kablo: .claude/settings.json → PostToolUse matcher "*".
# ÖZ-SERVİS COMPACT (opsiyonel): projede `scripts/ekip-selfcompact.sh` VARSA DANGER-mesajı onu önerir;
#   YOKSA jenerik "Sultan'a /compact öner + resume-anchor'ı diske yaz" fallback'ine düşer (portable).

STAMPDIR="${TMPDIR:-/tmp}/ctx-nudge-$(id -u)"
mkdir -p "$STAMPDIR" 2>/dev/null || exit 0
now="$(date +%s)"

# ucuz erken-çıkış: 90 sn'de en fazla 1 gerçek koşum (transcript parse maliyeti için)
runstamp="$STAMPDIR/run"
if [ -f "$runstamp" ]; then
  last="$(cat "$runstamp" 2>/dev/null || echo 0)"
  [ $(( now - last )) -lt "${CTX_NUDGE_RUN_INTERVAL:-90}" ] && exit 0
fi
echo "$now" > "$runstamp"

command -v python3 >/dev/null 2>&1 || exit 0

# K1=A: öz-servis-compact modülü (opsiyonel) VARSA yolunu python'a geçir; YOKSA jenerik-fallback.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
SELFCOMPACT="$PROJECT_DIR/scripts/ekip-selfcompact.sh"
[ -x "$SELFCOMPACT" ] && export EKIP_SELFCOMPACT_PATH="$SELFCOMPACT"

exec 3<&0
exec python3 - <<'PY'
import json, os, sys, time, hashlib

try:
    d = json.load(os.fdopen(3))
except Exception:
    sys.exit(0)

tp = d.get("transcript_path") or ""
if not tp or not os.path.isfile(tp):
    sys.exit(0)

PCT = int(os.environ.get("CTX_NUDGE_PCT", "65"))
WINDOW_ENV = os.environ.get("CTX_NUDGE_WINDOW", "")
NUDGE_INTERVAL = int(os.environ.get("CTX_NUDGE_INTERVAL", "600"))
stampdir = os.path.join(os.environ.get("TMPDIR", "/tmp"), f"ctx-nudge-{os.getuid()}")

# transcript kuyruğu: son ~256KB yeter (son assistant-usage'ı arıyoruz)
try:
    size = os.path.getsize(tp)
    with open(tp, "rb") as f:
        if size > 262144:
            f.seek(size - 262144)
            f.readline()  # kısmi satırı at
        tail = f.read().decode("utf-8", errors="ignore").splitlines()
except Exception:
    sys.exit(0)

ctx = None
model = ""
for line in reversed(tail):
    if '"usage"' not in line:
        continue
    try:
        obj = json.loads(line)
        msg = obj.get("message") or {}
        u = msg.get("usage") or {}
        it = u.get("input_tokens")
        if it is None:
            continue
        ctx = it + (u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
        model = str(msg.get("model") or "")
        break
    except Exception:
        continue

if ctx is None:
    sys.exit(0)

# pencere: env-override > model-sezgisi (Fable/Mythos/[1m] = 1M) > 200k
def _default_window(m):
    m = m.lower()
    if "fable" in m or "mythos" in m or "[1m]" in m:
        return 1000000
    # Opus-4.8/4.7 & Sonnet-5: transcript'te bare-ID gelir ([1m] YOK). 1M-tier'in auto-compact
    # penceresi ~500k. Önceki 200k varsayımı bu modeller için ~2.5× şişik false-alarm üretiyordu.
    if any(t in m for t in ("opus-4-8", "opus-4.8", "opus-4-7", "opus-4.7", "sonnet-5", "sonnet5")):
        return 500000
    return 200000

try:
    WINDOW = int(WINDOW_ENV) if WINDOW_ENV else _default_window(model)
    if WINDOW <= 0:
        WINDOW = _default_window(model)
except Exception:
    WINDOW = _default_window(model)
WIN_SRC = "env" if WINDOW_ENV else "tahmin"

pct = round(100.0 * ctx / WINDOW)
if pct < PCT:
    sys.exit(0)
# >%100 = pencere-varsayımı bu modelden küçük (örn. 1M-pencereli oturum) → yüzdeyi klampla,
# mutlak-token'ı göster; kalibrasyon CTX_NUDGE_WINDOW env'iyle yapılır.
pct_txt = f"%{pct}" if pct <= 100 else f">%100 (pencere-varsayımı {WINDOW // 1000}k — CTX_NUDGE_WINDOW ile kalibre et)"

# nudge oran-sınırı: oturum-başına 600 sn'de 1
key = hashlib.sha1(tp.encode()).hexdigest()[:12]
nstamp = os.path.join(stampdir, f"nudge-{key}")
now = time.time()
try:
    if now - os.path.getmtime(nstamp) < NUDGE_INTERVAL:
        sys.exit(0)
except OSError:
    pass
try:
    open(nstamp, "w").write(str(int(now)))
except OSError:
    pass

# 2+ compact geçmiş mi? (yalnız nudge anında, tam-dosya tek tarama)
compacts = 0
try:
    with open(tp, "rb") as f:
        compacts = f.read().count(b"isCompactSummary")
except Exception:
    pass

ASK_PCT = int(os.environ.get("CTX_NUDGE_ASK_PCT", "80"))
SELFCOMPACT = os.environ.get("EKIP_SELFCOMPACT_PATH", "")
head = (f"ℹ️ ctx-nudge: eşik-tahmini aşıldı — ~{pct_txt} (~{ctx // 1000}k / pencere {WINDOW // 1000}k·{WIN_SRC}). "
        "⚠️ Bu bir TAHMİN — körlemesine güvenme: /context ile GERÇEK doluluğu doğrula. ")
if pct >= ASK_PCT:
    # DANGER-tier: temiz faz-sınırında bloke-soru meşru
    if SELFCOMPACT:
        # K1=A: öz-servis-compact modülü mevcut → onu öner
        msg = head + ("DANGER-bölgesi: ÖZ-SERVİS COMPACT akışı — (1) resume-anchor'ı diske yaz (kaldığın-yeri kalıcı-diske); "
            "(2) TEMİZ faz-sınırındaysan Sultan'a AskUserQuestion sor: 'Şimdi hafızamı temizleyip (compact) "
            "kaldığım yerden devam edeyim mi? [Evet / Hayır / Sonra]'; (3) EVET derse "
            f"`bash {SELFCOMPACT} --self` koş ve turu DERHAL bitir — "
            "arka-plan watcher compact'i yapıp seni kimliğinle geri-yükler. Sultan onaylamadan compact'leme.")
    else:
        # K1=A jenerik-fallback: öz-servis-compact modülü YOK → Sultan'a /compact öner + anchor-yaz
        msg = head + ("DANGER-bölgesi: (1) resume-anchor'ı diske yaz (kaldığın-yeri kalıcı-diske — kim, nerede kaldın, sıradaki adım); "
            "(2) TEMİZ faz-sınırındaysan Sultan'a /compact öner: 'Şimdi hafızamı temizleyip (compact) kaldığım yerden devam "
            "edeyim mi?'. Sultan onaylamadan compact'leme.")
else:
    # ERKEN-tier: bloke-soru AÇMA (menü koordinasyon-akışını böler); yalnız anchor-yaz + devam
    msg = head + (f"ERKEN-uyarı (~%{PCT}-{ASK_PCT} arası, henüz DANGER değil): BLOKE-SORU/menü AÇMA — "
        "koordinasyon-akışını böler ve yöneticinin sana ping'ini engeller. Sadece resume-anchor'ını "
        "diske yaz (kaldığın-yeri kalıcı-diske) ki her an güvenle compact'lenebilesin, sonra işine DEVAM ET. "
        f"Compact-sorusunu ancak ~%{ASK_PCT}'i geçip TEMİZ bir faz-sınırına geldiğinde sor.")
if compacts >= 2:
    msg += " (2+ compact geçmiş — doğrulanırsa faz-sınırında oturum-bölmeyi de değerlendir.)"

print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg}},
                 ensure_ascii=False))
sys.exit(0)
PY
