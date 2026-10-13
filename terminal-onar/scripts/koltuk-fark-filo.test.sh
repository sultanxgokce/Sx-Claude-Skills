#!/usr/bin/env bash
# koltuk-fark-filo.test.sh — filo koşucusunun sınıflaması (fark-olceri-127). Hermetik: sahte ssh, gerçek host YOK.
# Ölçülen: 'terminalsiz' YALNIZ kutunun kendi açık beyanıyla; rc 127 (tar/komut yok) ve tanınmayan rc → ÖLÇÜLEMEDİ.
set -u
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
g=0; k=0; kapi() { if [ "$2" = "$3" ]; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }
mkdir -p "$T/bin"
cat > "$T/bin/ssh" <<'S'
#!/usr/bin/env bash
cmd="${@: -1}"; cat >/dev/null 2>&1 || true
case "$cmd" in
  *cloudtop-temiz*)    echo '{"ozet":{"toplam":2,"gorunur":2,"gizli":0,"dusen":0,"hayalet":0,"sekme":0,"sekme_okunamayan":0},"oturumlar":[],"hayalet":[],"sekme":[]}'; exit 0 ;;
  *cloudtop-tmuxsuz*)  echo '{"terminalsiz":"tmux kurulu değil"}'; exit 3 ;;
  *cloudtop-nodesuz*)  echo '{"terminalsiz":"node yok"}'; exit 3 ;;
  *cloudtop-tarsiz*)   echo 'sh: 1: tar: not found' >&2; exit 127 ;;
  *cloudtop-bozuk*)    echo 'beklenmedik' ; exit 5 ;;
esac
exit 0
S
chmod +x "$T/bin/ssh"
o="$(PATH="$T/bin:$PATH" bash "${FILO_BETIK:-$D/koltuk-fark-filo.sh}" --kaynak "$D/.." cloudtop-temiz cloudtop-tmuxsuz cloudtop-nodesuz cloudtop-tarsiz cloudtop-bozuk 2>&1)"; rc=$?
kapi "N1 temiz kutu temiz sayılır" "1" "$(grep -c '^✓ cloudtop-temiz' <<<"$o")"
kapi "N2 kutunun kendi beyanı (tmux yok / node yok) → terminalsiz" "2" "$(grep -cE '^– cloudtop-(tmuxsuz|nodesuz): terminalsiz' <<<"$o")"
kapi "N3 rc 127 (tar yok) → ÖLÇÜLEMEDİ, terminalsiz DEĞİL" "1|0" "$(grep -c '^? cloudtop-tarsiz' <<<"$o")|$(grep -c '^– cloudtop-tarsiz' <<<"$o")"
kapi "N4 tanınmayan rc → ÖLÇÜLEMEDİ" "1" "$(grep -c '^? cloudtop-bozuk' <<<"$o")"
kapi "N5 ölçülemeyen varken genel rc 2 (temiz sayılmaz)" "2" "$rc"
kapi "N6 özet: terminalli 3 (1 temiz + 2 ölçülemedi) · terminalsiz 2" "1" "$(grep -c 'terminalli 3: temiz 1 · DÜŞEN/hayalet olan 0 · ölçülemedi 2 · terminalsiz 2' <<<"$o")"
echo "GEÇEN: $g · KALAN: $k"; [ "$k" -eq 0 ]
