#!/usr/bin/env bash
# ekip-canli.sh — bir koltukta GERÇEKTEN çalışan ajan var mı? (DÜLGER · MUAVİN şartlı-kabul, 10 Ekim 2026)
#
# NİÇİN: ekip-notify "iletildi" diyor ama ajanın yaşadığını ölçmüyor. 10 Ekim'de iki ölçüm de yanıldı:
#   biri yalnız pane-komutuna baktı (dolu koltukta da "bash"), öteki yalnız çocuğa (torun görülmedi).
#   Zincir ÜÇ kademe: pane → başlatıcı → claude. Bu araç üçüne de bakar, ilk bulduğunda durur.
#
# 🔴 POZİTİF KONTROL ŞARTI: aynı ölçü bilinen-dolu bir koltukta (varsayılan: çağıranın kendi koltuğu)
#   "canlı" demiyorsa, sonuç koltuğun boşluğu değil PROBUN KÖRLÜĞÜDÜR → her satır "olcemedim", rc=3.
#   "Ölçemedim" asla "yok" sayılmaz; çağıran sinyalini yine bırakır (kalıcı iz kaybolmaz).
#
# Kullanım: ekip-canli.sh <ajan|all> [--kontrol <ajan>] [--derinlik N]
# Çıktı (TSV): ID<TAB>durum<TAB>kademe<TAB>not     durum ∈ canli · bekliyor · sinirda · yok · oturum-yok · olcemedim
#   canli    = ajan süreci var, ekranda onay-diyaloğu yok
#   bekliyor = ajan süreci var AMA ekranda izin/onay diyaloğu (insan tuşu bekliyor — ilerlemiyor)
#   sinirda  = ajan süreci var AMA ekrandaki SON sonuç satırı kullanım-sınırı mesajı (iş yapamaz; mesaj alsa da
#              yine sınır hatası döner). BASİRET, 11 Ekim 2026: dört koltuk 10 Ekim 22:24'ten itibaren 11 saat
#              sınırdaydı; bu araç "canli", notify "iletildi" dedi — ikisi de doğruydu, ikisi de "iş yapabilir mi"yi ölçmüyordu.
#   yok      = tmux oturumu var, derinlik içinde ajan süreci yok
# Çıkış: 0 ölçüldü · 1 kullanım/registry · 3 ölçemedim (pozitif kontrol düştü ya da kontrol koltuğu çözülemedi)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"
AJAN_RE="${EKIP_AJAN_RE:-(^|/)claude( |$)}"          # ajan sürecinin args deseni (başlatıcı 'baslat-claude.sh' EŞLEŞMEZ)
# 🔴 SATIR BAŞINA ÇAPALI: ilk yazımda "dialog waiting" serbest desendi ve kendi ekranımda, transkriptte geçen
#   bir MEKTUP METNİNE takıldı (yanlış pozitif, 10 Ekim). Diyalog imi TUI'nin kendi satırıdır, metin içi değil.
DIYALOG_RE="${EKIP_DIYALOG_RE:-^\s*dialog waiting · |^\s*Do you want to proceed\?|^\s*❯ 1\. Yes}"
# SINIR: ölçülen birebir satır (11 Ekim, dört koltukta aynı): "  ⎿  You've reached your Fable limit. Run /usage-credits …"
#   ÇAPA iki boşluk + ⎿ : başka bir koltuğun ekranı ALINTI olarak basıldığında (reisin ekranında) satırın başında
#   araç-sonucu imi olur ve desen tutmaz. Ayrıca yalnız SON sonuç satırına bakılır: Sultan /model ile koltuğu
#   açınca sınır satırı ekranda kalır ama altına yeni bir sonuç satırı düşer → artık "canli".
#   ⎿'den sonra düz boşluk + BÖLÜNMEZ boşluk (c2 a0) gelir — ölçüldü; ilk desen " +" gerçek koltukta tutmadı.
#   (Düz atama: "${X:-…}" içinde kesme işareti bash'te ayrıştırmayı bozuyor — ölçüldü, sözdizimi hatası.)
SINIR_RE="${EKIP_SINIR_RE:-}"; [ -n "$SINIR_RE" ] || SINIR_RE="^  ⎿.{1,3}You've (reached|hit) your [^ ]+ limit"
SONUC_RE="${EKIP_SONUC_RE:-^  ⎿ |^● }"
DERINLIK=3; KONTROL=""; HEDEF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kontrol)  [ $# -ge 2 ] || { echo "HATA: --kontrol değer ister" >&2; exit 1; }; KONTROL="$2"; shift ;;
    --derinlik) [ $# -ge 2 ] || { echo "HATA: --derinlik değer ister" >&2; exit 1; }; DERINLIK="$2"; shift ;;
    --*) echo "HATA: bilinmeyen bayrak $1" >&2; exit 1 ;;
    *) HEDEF="$1" ;;
  esac; shift
done
[ -n "$HEDEF" ] || { echo "kullanım: ekip-canli.sh <ajan|all> [--kontrol <ajan>] [--derinlik N]" >&2; exit 1; }
[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 1; }
command -v tmux >/dev/null || { echo "HATA: tmux yok" >&2; exit 1; }
tmux() { command tmux ${EKIP_TMUX_SOCK:+-L "$EKIP_TMUX_SOCK"} "$@"; }   # sınav ayrı tmux sunucusunda koşar (EKIP_TMUX_SOCK)

# registry: ID<TAB>session
MEMBERS="$(python3 - "$REGISTRY" <<'PY'
import re, sys
cur=None
for line in open(sys.argv[1], encoding="utf-8"):
    m=re.match(r"\s*-\s*id:\s*(\S+)", line)
    if m: cur=m.group(1); continue
    m=re.match(r'\s*tmux:\s*"?([^"\s]+)"?', line)
    if m and cur: print(cur+"\t"+m.group(1).split(":")[0]); cur=None
PY
)"
oturum_of() { printf '%s\n' "$MEMBERS" | awk -F'\t' -v id="$(printf '%s' "$1" | tr a-z A-Z)" 'toupper($1)==id{print $2; exit}'; }

# sinir_eski <pid>: ekrandaki sınır satırı bu süreçten ÖNCE mi yazıldı? (BASİRET, 11 Ekim 2026)
#   NİÇİN: koltuk --resume ile yeniden açılınca ekran eski konuşmayı ve dünkü sınır mesajını yeniden basar;
#   "son sonuç satırı" kuralı onu bugünkü hüküm sanıp yeni açılmış koltuğu "sinirda" diyordu — notify de
#   mesajı engelliyordu (ölçüldü 17:3x: beş koltuk 17:31'de açık, ölçüm dördüne sinirda dedi).
#   Ölçü: süreç argümanındaki oturum kimliği → konuşma kaydı → son sınır kaydının zamanı < süreç başlangıcı.
#   Karşılaştırılamazsa (kayıt yok, kimlik yok) 1 döner → sinirda hükmü KORUNUR (bilinmeyen ≠ temiz).
sinir_eski() {
  local pid="$1" args sid basla
  args="$(ps -o args= -p "$pid" 2>/dev/null)"
  sid="$(printf '%s' "$args" | grep -oE -- '--(resume|session-id) [0-9a-f-]{36}' | awk '{print $2}')"
  [ -n "$sid" ] || return 1
  basla="$(( $(date +%s) - $(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0) ))"
  python3 -I - "$sid" "$basla" "${EKIP_KAYIT_KOK:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}" <<'PYI'
import sys, glob, json, datetime
sid, basla, kok = sys.argv[1], int(sys.argv[2]), sys.argv[3]
yol = glob.glob(f"{kok}/*/{sid}.jsonl")
if not yol: sys.exit(1)
# 🔴 YALNIZ GERÇEK SINIR OLAYI sayılır (isApiErrorMessage:true). Düz metin araması kayıttaki ALINTILARI da
#   sayıyordu (sınav dosyası diff'i, mektup, kanal yazısı) — DÜLGER'in kendi kaydında ölçüldü 11 Ekim 17:4x:
#   153 eşleşmeden yalnız 7'si gerçek olay; kalanı alıntı. Alıntı süreçten yeniyse "sinirda" hükmü yanlış kalırdı.
#   Aynı aile: ölçüm aracı kendini ölçüyor.
son = None
for l in open(yol[0], encoding="utf-8"):
    if "reached your" in l or "hit your" in l:
        try: d = json.loads(l)
        except Exception: continue
        if d.get("isApiErrorMessage") is True and d.get("timestamp"): son = d["timestamp"]
if not son: sys.exit(1)
t = datetime.datetime.fromisoformat(son.replace("Z", "+00:00")).timestamp()
sys.exit(0 if t < basla else 1)
PYI
}

# tek koltuğu ölç → "durum<TAB>kademe<TAB>not"
olc() {
  local ses="$1" pid kademe=0 bulunan="" sira cocuk args
  tmux has-session -t "$ses" 2>/dev/null || { printf 'oturum-yok\t-\ttmux oturumu yok\n'; return; }
  pid="$(tmux list-panes -t "$ses" -F '#{pane_pid}' 2>/dev/null | head -1)"
  [ -n "$pid" ] || { printf 'olcemedim\t-\tpane pid okunamadı\n'; return; }
  sira="$pid"
  while [ "$kademe" -lt "$DERINLIK" ] && [ -n "$sira" ]; do
    for cocuk in $sira; do
      args="$(ps -o args= -p "$cocuk" 2>/dev/null)"
      if printf '%s' "$args" | grep -Eq "$AJAN_RE"; then bulunan="$cocuk"; break 2; fi
    done
    kademe=$((kademe+1))
    sira="$(for cocuk in $sira; do pgrep -P "$cocuk"; done 2>/dev/null | tr '\n' ' ')"
  done
  [ -n "$bulunan" ] || { printf 'yok\t%s\t%s kademe içinde ajan süreci yok\n' "$DERINLIK" "$DERINLIK"; return; }
  case "$kademe" in 0) k=pane ;; 1) k=cocuk ;; 2) k=torun ;; *) k="kademe$kademe" ;; esac
  # izin kipi: süreç argümanından (--permission-mode X); yoksa "kip=?" — başlatıcısız (elle) açılmış koltuk demektir
  local kip; kip="$(ps -o args= -p "$bulunan" 2>/dev/null | grep -o -- '--permission-mode [A-Za-z]*' | awk '{print $2}')"
  kip="kip=${kip:-?}"
  local ekran son; ekran="$(tmux capture-pane -p -t "$ses" 2>/dev/null)"
  son="$(printf '%s\n' "$ekran" | grep -E "$SONUC_RE" | tail -1)"
  if printf '%s' "$son" | grep -Eq "$SINIR_RE" && ! sinir_eski "$bulunan"; then
    printf 'sinirda\t%s\tpid=%s · %s · son sonuç kullanım-sınırı (süreç var, iş yapamaz)\n' "$k" "$bulunan" "$kip"
  elif printf '%s' "$son" | grep -Eq "$SINIR_RE"; then
    printf 'canli\t%s\tpid=%s · %s · ekrandaki sınır satırı ÖNCEKİ süreçten (yeniden açıldı; ilk iş sınavı)\n' "$k" "$bulunan" "$kip"
  elif printf '%s\n' "$ekran" | grep -Eq "$DIYALOG_RE"; then
    printf 'bekliyor\t%s\tpid=%s · %s · ekranda onay-diyaloğu (insan tuşu bekliyor)\n' "$k" "$bulunan" "$kip"
  else
    printf 'canli\t%s\tpid=%s · %s\n' "$k" "$bulunan" "$kip"
  fi
}

# --- pozitif kontrol: bilinen-dolu koltuk = --kontrol ya da çağıranın kendi koltuğu ---
if [ -z "$KONTROL" ] && [ -n "${TMUX_PANE:-}" ]; then
  KONTROL="$(tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null || true)"
fi
KONTROL_SES=""; [ -n "$KONTROL" ] && KONTROL_SES="$(oturum_of "$KONTROL")"
[ -n "$KONTROL_SES" ] || KONTROL_SES="$KONTROL"
KOR=""
if [ -z "$KONTROL_SES" ]; then
  KOR="pozitif kontrol yok (tmux dışı ve --kontrol verilmedi)"
else
  KSONUC="$(olc "$KONTROL_SES")"; KDURUM="${KSONUC%%	*}"
  case "$KDURUM" in canli|bekliyor|sinirda) ;; *) KOR="pozitif kontrol düştü: $KONTROL → $KDURUM (prob kör)" ;; esac
fi

# --- hedefler ---
if [ "$(printf '%s' "$HEDEF" | tr A-Z a-z)" = all ]; then
  LISTE="$(printf '%s\n' "$MEMBERS" | cut -f1)"
else
  LISTE="$(printf '%s' "$HEDEF" | tr a-z A-Z)"
  [ -n "$(oturum_of "$LISTE")" ] || { echo "HATA: registry'de üye yok: $HEDEF" >&2; exit 1; }
fi
RC=0
while read -r ID; do
  [ -n "$ID" ] || continue
  if [ -n "$KOR" ]; then printf '%s\tolcemedim\t-\t%s\n' "$ID" "$KOR"; RC=3; continue; fi
  printf '%s\t%s\n' "$ID" "$(olc "$(oturum_of "$ID")")"
done <<< "$LISTE"
[ -n "$KOR" ] && echo "⚠️ ÖLÇEMEDİM — $KOR; 'yok' DEMEDİM, sinyalini yine bırak" >&2
exit $RC
