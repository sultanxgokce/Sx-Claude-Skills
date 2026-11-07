#!/usr/bin/env bash
# gercek.sh — gerçek vaka: Nexus #1585'in başı (d94a05b7, yalnız kanıt; o gün zorunlu kipte ÖN GÖZ ÖLÇÜLEMEDİ ile kapandı).
#   Nexus deposunda o başa ayrık geçici worktree açılır; origin/main ve HEAD denetci.sh'i --on-goz (yalnız ön göz, denetim/yazım yok) ile koşar.
#   Gerçek DALGIÇ kullanılır (eski yolda boş fark → rc 2, model çağrılmaz). Worktree sonunda kaldırılır.
set -uo pipefail
K="$(git rev-parse --show-toplevel)"; N="${NEXUS:-/config/projects/Nexus}"; BAS=d94a05b7
T="$(mktemp -d)"; trap 'git -C "$N" worktree remove --force "$T/wt" >/dev/null 2>&1; find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$N" fetch -q origin 2>/dev/null; git -C "$N" worktree add -q --detach "$T/wt" "$BAS" || { echo "worktree açılamadı"; exit 3; }
mkdir -p "$T/eski" "$T/yeni"
git -C "$K" archive origin/main yazilim-fabrikasi | tar -x -C "$T/eski"; git -C "$K" archive HEAD yazilim-fabrikasi | tar -x -C "$T/yeni"
echo "dalın dosyaları (origin/main...$BAS):"; git -C "$T/wt" diff --name-only "origin/main...HEAD" | sed 's/^/  /'
kos() { ( cd "$T/wt" && ON_GOZ_TABAN="$(git -C "$T/wt" merge-base origin/main HEAD)" KANIT_DEPO="$T/wt" bash "$1/yazilim-fabrikasi/scripts/denetci.sh" erken-uyari-bekle-metni --on-goz < /dev/null 2>&1 ); }
E="$(kos "$T/eski")"; ERC=$?; Y="$(kos "$T/yeni")"; YRC=$?
echo "── eski (origin/main denetci.sh) rc=$ERC"; grep -E "zorunlu kip|DALGIÇ|ÖN GÖZ:" <<<"$E" | sed 's/^/  /'
echo "── yeni (HEAD denetci.sh) rc=$YRC"; grep -E "zorunlu kip|DALGIÇ|ÖN GÖZ:" <<<"$Y" | sed 's/^/  /'
[ "$ERC" -eq 3 ] && [ "$YRC" -eq 0 ] && grep -q "UYGULANAMAZ" <<<"$Y" && echo "SONUÇ: eski ölçülemedi (rc 3) → yeni uyumlu (rc 0, DALGIÇ uygulanamaz)" && exit 0
echo "SONUÇ: beklenen değil"; exit 1
