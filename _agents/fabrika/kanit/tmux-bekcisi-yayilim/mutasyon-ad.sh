#!/usr/bin/env bash
# Her bekci.sh bozmasının düşürdüğü kapıları ADIYLA basar; sonuç satırı yoksa ÖLÇÜLEMEDİ. $1 = beceri kökü
set -u; K="$1"; T="$(mktemp -d)"; trap 'rm -r -f -- "$T"' EXIT
kos() { local d="$T/$1"; mkdir -p "$d"; cp -r "$K/scripts" "$d/"
  [ -n "$2" ] && python3 -c 'import sys; p=sys.argv[1]; s=open(p).read(); assert sys.argv[2] in s; open(p,"w").write(s.replace(sys.argv[2],sys.argv[3],1))' "$d/scripts/bekci.sh" "$2" "$3"
  local o; o="$(TB_KIC=1 timeout 60 bash "$d/scripts/tmux-bekcisi.test.sh" 2>&1)"
  if ! printf '%s' "$o" | grep -q '^SONUÇ:'; then echo "$1: ÖLÇÜLEMEDİ (sonuç satırı yok)"; return; fi
  echo "$1: $(printf '%s' "$o" | grep '^SONUÇ:') · düşen: $(printf '%s\n' "$o" | grep -oE '✗ [A-Z][0-9a-z]+' | sed 's/✗ //' | paste -sd' ')"; }
kos pozitif '' ''
kos bekci-kurmaz '_tb="$(tmux_bekcisi_kur)"
' '_tb=güncel
'
kos bekci-hep-yazar '[ "$_tb" != güncel ] && [' 'true || ['
kos bekci-durakta-kurar '[ -f "$DURUM_DIZ/duraklat" ] && exit 0
' '_tb="$(tmux_bekcisi_kur)"; [ -f "$DURUM_DIZ/duraklat" ] && exit 0
'
kos bekci-hatada-durur 'then gunluk "bekçi: tmux bekçisi: $_tb"; fi' 'then gunluk "bekçi: tmux bekçisi: $_tb"; exit 1; fi'
kos bekci-tekrar-yazar '&& [ "$_tb" != "$(cat "$DURUM_DIZ/tmux-bekcisi.son" 2>/dev/null)" ]' ''
