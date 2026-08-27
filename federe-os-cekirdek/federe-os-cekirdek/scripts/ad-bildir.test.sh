#!/usr/bin/env bash
# ad-bildir.test.sh — kutu-tarafı ad bildiriminin golden'ı (L64 · K3)
#
# NİÇİN: Bu betik İ1 sınırından geçen tek yeni yoldur. En kritik testler
#   "ne GÖNDERMEDİĞİ" üzerinedir: gövdeye ad dışında bir şey sızarsa mahremiyet
#   sözleşmesi kırılır ve bunu geri almanın yolu yoktur.
# HERMETİK: yalnız $TMPDIR; ağa çıkmaz (federe.sh sahte bir kayıtçıyla değiştirilir).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SUT="$HERE/ad-bildir.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS  $1"; }
kotu() { FAIL=$((FAIL+1)); echo "FAIL  $1 — beklenen [$2] · gelen [$3]"; }
esit() { if [ "$2" = "$3" ]; then ok "$1"; else kotu "$1" "$2" "$3"; fi; }
var()  { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else kotu "$1" "içerir: $3" "$2"; fi; }
yok()  { if printf '%s' "$2" | grep -q -- "$3"; then kotu "$1" "SIZDI: $3" "$2"; else ok "$1"; fi; }

# sahte federe.sh — gönderileni dosyaya yazar, ağa çıkmaz
SAHTE="$T/federe.sh"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" > "$SAHTE_CIKTI"\n' > "$SAHTE"
chmod +x "$SAHTE"
export SAHTE_CIKTI="$T/gonderilen.txt"

KOK="$T/kutu"; mkdir -p "$KOK/_agents/ekip-os"
kos() { AD_BILDIR_FEDERE="$SAHTE" AD_BILDIR_KOK="$KOK" bash "$SUT" "$@"; }

cat > "$KOK/_agents/ekip-os/ekip-registry.yaml" <<'EOF'
uyeler:
  - id: NAKKAS
    rol: "UI/Pano ustasi — Sultan'in gordugu arayuz"
    tmux: "nakkas:0"
    session_id: "abc-123-gizli"
    cwd: /config/projects/gizli-yol
    inbox: _agents/handoff/nakkas-inbox.md
  - id: SEYYAH
    rol: "kesif"
    session_id: "def-456-gizli"
EOF

echo "=== G1 · sözdizimi ==="
bash -n "$SUT" 2>/dev/null; esit "G1 bash -n" "0" "$?"

echo
echo "=== G2 · PROVA varsayılan: hiçbir şey gönderilmez ==="
rm -f "$SAHTE_CIKTI"
O="$(kos 2>&1)"; esit "G2a prova rc=3" "3" "$?"
esit "G2b hiçbir şey gönderilmedi" "0" "$([ -f "$SAHTE_CIKTI" ] && echo 1 || echo 0)"
var  "G2c ne göndereceğini gösteriyor" "$O" "NAKKAS,SEYYAH"

echo
echo "=== G3 · 🔴 İ1 · gövdede AD DIŞINDA hiçbir şey YOK (en kritik kapı) ==="
kos --gonder >/dev/null 2>&1; esit "G3a gönderim rc=0" "0" "$?"
G="$(cat "$SAHTE_CIKTI")"
var "G3b adlar var"                "$G" "NAKKAS,SEYYAH"
yok "G3c ROL sızmadı"              "$G" "UI/Pano"
yok "G3d SESSION-ID sızmadı"       "$G" "abc-123-gizli"
yok "G3e CWD/yol sızmadı"          "$G" "gizli-yol"
yok "G3f INBOX yolu sızmadı"       "$G" "nakkas-inbox"
yok "G3g ikinci session-id de yok" "$G" "def-456-gizli"

echo
echo "=== G4 · hedef merkez, başlık sabit ==="
var "G4a hedef s01" "$G" "gonder s01"
var "G4b başlık uye-adlari" "$G" "uye-adlari"

echo
echo "=== G5 · BOŞ bildirim GÖNDERİLMEZ (ölçemedim ≠ kimse yok) ==="
printf 'uyeler: []\n' > "$KOK/_agents/ekip-os/ekip-registry.yaml"
rm -f "$SAHTE_CIKTI"
O="$(kos --gonder 2>&1)"; esit "G5a boş kayıt rc=2" "2" "$?"
esit "G5b gönderim YAPILMADI" "0" "$([ -f "$SAHTE_CIKTI" ] && echo 1 || echo 0)"
var  "G5c gerekçe yazılı" "$O" "aynı şey değildir"

echo
echo "=== G6 · KAYIT YOKSA uydurma YAPILMAZ ==="
rm -f "$KOK/_agents/ekip-os/ekip-registry.yaml"
rm -f "$SAHTE_CIKTI"
O="$(kos --gonder 2>&1)"; esit "G6a kayıtsız kutu rc=2" "2" "$?"
esit "G6b gönderim YAPILMADI" "0" "$([ -f "$SAHTE_CIKTI" ] && echo 1 || echo 0)"
var  "G6c bakılan yerleri söylüyor" "$O" "ekip-registry.yaml"

echo
echo "=== G7 · UZUN liste KIRPILMAZ, reddedilir ==="
{ printf 'uyeler:\n'; for i in $(seq 1 60); do printf '  - id: COKUZUNAJANADIBURADA%02d\n' "$i"; done; } \
  > "$KOK/_agents/ekip-os/ekip-registry.yaml"
rm -f "$SAHTE_CIKTI"
O="$(kos --gonder 2>&1)"; esit "G7a uzun liste rc=2" "2" "$?"
esit "G7b gönderim YAPILMADI" "0" "$([ -f "$SAHTE_CIKTI" ] && echo 1 || echo 0)"
var  "G7c kırpmadığını söylüyor" "$O" "KIRPILMADI"

echo
echo "=== G8 · SALT-OKUR: kaynak kayıt değişmez ==="
cat > "$KOK/_agents/ekip-os/ekip-registry.yaml" <<'EOF'
uyeler:
  - id: ALFA
EOF
ONCE="$(sha256sum "$KOK/_agents/ekip-os/ekip-registry.yaml" | cut -d' ' -f1)"
kos >/dev/null 2>&1; kos --gonder >/dev/null 2>&1
esit "G8 kayıt BAYT-AYNI" "$ONCE" "$(sha256sum "$KOK/_agents/ekip-os/ekip-registry.yaml" | cut -d' ' -f1)"

echo
echo "=== G9 · tanınmayan bayrak yutulmaz ==="
kos --uydurma >/dev/null 2>&1; esit "G9 rc=2" "2" "$?"

echo
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
