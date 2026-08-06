#!/usr/bin/env bash
# koltuk-agaci.test.sh — baslat-claude.sh şablonundaki KOLTUK ÇALIŞMA ALANI bloğunu sınar.
# claude'u ÇAĞIRMAZ: blok, claude çağrısından önce biten bir parçadır; şablondan kesilip
# hermetik koşulur (gerçek depo, sahte rol, gerçek git — ağ YOK).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SABLON="$HERE/../templates/baslat-claude.sh"
gecti=0; kaldi=0
G(){ if [ "$2" = "$3" ]; then gecti=$((gecti+1)); printf '  ✅ %s\n' "$1"
     else kaldi=$((kaldi+1)); printf '  ❌ %s — beklenen [%s] gerçek [%s]\n' "$1" "$2" "$3"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# Bloğu şablondan kes (KOLTUK başlangıcı → _IZ_DIR satırı öncesi)
BLOK="$T/blok.sh"
awk '/^# ── KOLTUK ÇALIŞMA ALANI/{y=1} /^_IZ_DIR=/{y=0} y' "$SABLON" > "$BLOK"
[ -s "$BLOK" ] || { echo "HATA: blok şablondan kesilemedi (başlık değişmiş olabilir)"; exit 2; }

# gerçek depo kur: özellik dalı + kaydedilmemiş dosya (tez'in canlı durumu)
DEPO="$T/depo"; mkdir -p "$DEPO/scripts"
git init -q "$DEPO"; git -C "$DEPO" config user.email t@t; git -C "$DEPO" config user.name T
echo ilk > "$DEPO/a.txt"; git -C "$DEPO" add -A; git -C "$DEPO" commit -qm ilk
git -C "$DEPO" checkout -q -b faz-0-kurulum; echo iki >> "$DEPO/a.txt"
git -C "$DEPO" commit -qam ikinci
echo "kaydedilmemis" > "$DEPO/kirli.txt"     # ← ana ağaçta duran iş

kos(){ # kos <rol> <bayrak>
  ROL="$1" KOLTUK_AGACI="$2" SCRIPT_DIR="$DEPO/scripts" HOME="$T/ev" \
  bash -c 'set -u; ROL="$ROL"; SCRIPT_DIR="$SCRIPT_DIR"; . '"$BLOK"'; pwd' 2>"$T/err.txt"
}

echo "── G1: bayrak KAPALIYKEN hiçbir şey yapmaz (bayt-aynı davranış) ──"
mkdir -p "$T/ev"
cd "$DEPO"; NEREDE="$(kos yazar 0)"
G "G1a dizin değişmedi" "$DEPO" "$NEREDE"
G "G1b ağaç açılmadı" "0" "$(git -C "$DEPO" worktree list | tail -n +2 | wc -l)"
G "G1c uyarı basmadı" "0" "$(grep -c . "$T/err.txt" 2>/dev/null | head -1)"

echo "── G2: bayrak AÇIKKEN role ait ağaç açılır ──"
NEREDE="$(kos yazar 1)"
G "G2a yeni dizine geçildi" "$T/ev/koltuk/yazar" "$NEREDE"
G "G2b worktree kaydı oluştu" "1" "$(git -C "$DEPO" worktree list | tail -n +2 | wc -l)"
G "G2c koltuk satırı basıldı" "1" "$(grep -c '\[koltuk\] yazar' "$T/err.txt" | head -1)"

echo "── G3: TABAN o anki dal — origin/main DEĞİL ──"
DAL="$(git -C "$T/ev/koltuk/yazar" rev-parse --abbrev-ref HEAD)"
G "G3a kendi dalında" "koltuk/yazar" "$DAL"
G "G3b içerik özellik-dalından geldi" "2" "$(wc -l < "$T/ev/koltuk/yazar/a.txt")"

echo "── G4: ANA AĞACIN kaydedilmemiş işine DOKUNULMAZ ──"
G "G4a kirli dosya duruyor" "VAR" "$([ -f "$DEPO/kirli.txt" ] && echo VAR || echo YOK)"
G "G4b ana ağaç hâlâ kendi dalında" "faz-0-kurulum" "$(git -C "$DEPO" rev-parse --abbrev-ref HEAD)"

echo "── G5: ikinci çağrı MEVCUT ağacı kullanır (ikinci ağaç açmaz) ──"
NEREDE="$(kos yazar 1)"
G "G5a aynı dizin" "$T/ev/koltuk/yazar" "$NEREDE"
G "G5b hâlâ tek ağaç" "1" "$(git -C "$DEPO" worktree list | tail -n +2 | wc -l)"
G "G5c 'mevcut ağaç' dedi" "1" "$(grep -c 'mevcut ağaç' "$T/err.txt" | head -1)"

echo "── G6: ikinci ROL ayrı ağaç alır (asıl amaç) ──"
NEREDE="$(kos okuyucu 1)"
G "G6a ayrı dizin" "$T/ev/koltuk/okuyucu" "$NEREDE"
G "G6b iki ayrı ağaç" "2" "$(git -C "$DEPO" worktree list | tail -n +2 | wc -l)"

echo "── G7: git deposu DEĞİLSE fail-soft ama SESSİZ DEĞİL ──"
YOK="$T/gitsiz"; mkdir -p "$YOK/scripts"
NEREDE="$(ROL=x KOLTUK_AGACI=1 SCRIPT_DIR="$YOK/scripts" HOME="$T/ev" bash -c 'set -u; ROL="$ROL"; SCRIPT_DIR="$SCRIPT_DIR"; cd '"$YOK"'; . '"$BLOK"'; pwd' 2>"$T/err.txt")"
G "G7a dizin değişmedi (düşmedi)" "$YOK" "$NEREDE"
G "G7b sarı uyarı basıldı" "1" "$(grep -c '\[sari\]' "$T/err.txt" | head -1)"

echo
printf 'koltuk-agaci: %d geçti · %d kaldı\n' "$gecti" "$kaldi"
[ "$kaldi" -eq 0 ] || exit 1
