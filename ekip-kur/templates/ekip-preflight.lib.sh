#!/usr/bin/env bash
# ekip-preflight.lib.sh — pane-durum sınıflandırma TEK-KAYNAĞI (ekip-notify.sh + ekip-durum.sh source eder)
# Kaynak-desen: ekip-kur master-skill (koordinasyon substratı).
# DOKTRİN: belirsiz → draft/DUR (veri-imhası > mesaj-gecikmesi; FN telafisiz, FP --force ile aşılır).
# CANLI-KALİBRASYON: RE/KOD değişkenleri go-live'da kalibre edilir (Claude-Code-TUI sürümüne göre).
# Kaynak-edildiğinde HİÇBİR yan-etki üretmez (yalnız fonksiyon+değişken tanımı).

BUSY_RE="${BUSY_RE:-esc to interrupt}"
MENU_RE="${MENU_RE:-❯ 1\.|Do you want|\(y/n\)}"
COMPACT_RE="${COMPACT_RE:-auto-compact|context left|compact yap|compact yapayım}"
COMPOSER_RE="${COMPOSER_RE:-^│ >}"          # composer-satırı deseni — KALİBRE-ET
GHOST_CODES="${GHOST_CODES:-2,90}"          # ghost SGR-kodları (dim, bright-black) — KALİBRASYON ZORUNLU
GHOST_TEXT_RE="${GHOST_TEXT_RE:-^Try \"|^\? for shortcuts}"  # bilinen placeholder-whitelist (fallback)

preflight_state() {  # $1=tmux-hedef → stdout: idle|busy|menu|compact
  local snap rc=0
  snap="$(tmux capture-pane -p -t "$1" 2>/dev/null | tail -25)" || rc=$?
  [ "$rc" -eq 0 ] || { echo busy; return; }   # R-1 fix: capture-FAIL → İDDİA ETME → busy/DUR
  [ -n "$snap" ] || { echo idle; return; }    # capture-OK-boş → idle
  printf '%s' "$snap" | grep -qE "$BUSY_RE"    && { echo busy;    return; }
  printf '%s' "$snap" | grep -qE "$MENU_RE"    && { echo menu;    return; }
  printf '%s' "$snap" | grep -qE "$COMPACT_RE" && { echo compact; return; }
  echo idle
}

composer_kind() {  # $1=tmux-hedef → stdout: empty | ghost | draft:<ilk40ch>
  local t="$1" plain content probe ansi verdict
  plain="$(tmux capture-pane -p -t "$t" 2>/dev/null | grep -E "$COMPOSER_RE" | tail -1)" || true
  content="$(printf '%s' "$plain" | sed -E 's/^│ > ?//; s/[[:space:]│]+$//; s/^[[:space:]]+//')"
  [ -n "$content" ] || { echo empty; return; }
  probe="$(printf '%s' "$content" | cut -c1-20)"
  ansi="$(tmux capture-pane -e -p -t "$t" 2>/dev/null | grep -F -- "$probe" | tail -1)" || true
  if [ -z "$ansi" ]; then
    # -e hattı hizalanamadı → SGR-kanıtı yok → whitelist tek-fallback; o da tutmazsa draft (güvenli-yön)
    if printf '%s' "$content" | grep -qE "$GHOST_TEXT_RE"; then echo ghost
    else echo "draft:$(printf '%s' "$content" | cut -c1-40)"; fi
    return
  fi
  verdict="$(printf '%s' "$ansi" | python3 -c '
import re, sys
content, ghost = sys.argv[1], set(sys.argv[2].split(","))
raw = sys.stdin.buffer.read().decode("utf-8", "replace")
pat = re.compile(r"\x1b\[([0-9;]*)m")
attrs=set(); chars=[]; amap=[]; pos=0
def eat(seg):
    for ch in seg: chars.append(ch); amap.append(frozenset(attrs))
for m in pat.finditer(raw):
    eat(raw[pos:m.start()])
    codes=(m.group(1) or "0").split(";"); i=0
    while i < len(codes):
        c = codes[i] or "0"
        if c=="0": attrs.clear()
        elif c=="22": attrs.discard("2")
        elif c=="39": attrs -= {a for a in attrs if a=="90" or a.startswith("38;")}
        elif c=="38" and i+1<len(codes) and codes[i+1]=="5" and i+2<len(codes):
            attrs.add(";".join(codes[i:i+3])); i+=2
        elif c=="38" and i+1<len(codes) and codes[i+1]=="2" and i+4<len(codes):
            attrs.add(";".join(codes[i:i+5])); i+=4
        else: attrs.add(c)
        i+=1
    pos=m.end()
eat(raw[pos:])
plain="".join(chars); idx=plain.find(content[:20])
if idx<0: print("draft"); raise SystemExit          # hizalanamadı → belirsiz → draft
n=min(len(content),60); seg=plain[idx:idx+n]; att=amap[idx:idx+n]
normal=any(ch.strip() and not (a & ghost) for ch,a in zip(seg,att))
print("draft" if normal else "ghost")
' "$content" "$GHOST_CODES" 2>/dev/null)" || verdict="draft"   # python-fail → belirsiz → draft
  if [ "$verdict" = ghost ]; then echo ghost
  else echo "draft:$(printf '%s' "$content" | cut -c1-40)"; fi
}
