#!/usr/bin/env bash
# wa-oku.test.sh — gelen-okuma istemcisinin davranışı (Sx #594 göz tur 1: "wa-oku doğrudan sınanmamış").
# Yöntem: gerçek geçit çağrılmaz. PATH'e sahte `curl` konur: -d gövdesini saklar, -o dosyasına FAKE_YANIT'ı yazar,
# FAKE_KOD'u (http kodu) basar, FAKE_RC ile çıkar. Sınanan: imleç okuma/yazma, --kuru, --bastan, hata kodları, jeton gizliliği.
set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="${WA_OKU_SUT:-$BURASI/wa-oku.sh}"
T="$(mktemp -d)"; trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$T"' EXIT
gecen=0; kalan=0
g() { if [ "$1" = 0 ]; then echo "  ✓ $2"; gecen=$((gecen+1)); else echo "  ✗ $2"; kalan=$((kalan+1)); fi; }
command -v python3 >/dev/null || { echo "❌ python3 YOK — bu sınama sessizce atlanamaz."; exit 1; }

mkdir -p "$T/bin"
cat > "$T/bin/curl" <<'C'
#!/usr/bin/env bash
cikti=""; onceki=""
for a in "$@"; do
  case "$onceki" in -o) cikti="$a" ;; -d) printf '%s' "$a" > "$FAKE_GOVDE" ;; esac
  onceki="$a"
done
[ -n "$cikti" ] && [ -n "${FAKE_YANIT:-}" ] && cp "$FAKE_YANIT" "$cikti"
printf '%s' "${FAKE_KOD:-200}"
exit "${FAKE_RC:-0}"
C
chmod +x "$T/bin/curl"
cat > "$T/iki.json" <<'J'
{"ok": true, "sayi": 2, "son_sira": 42, "mesajlar": [
 {"sira": 41, "ts": "2026-10-30T10:00:00", "sohbet": "aile", "gonderen_adi": "Resul", "metin": "merhaba"},
 {"sira": 42, "ts": "2026-10-30T10:01:00", "sohbet": "aile", "benden": true, "grup": true, "metin": "selam"}]}
J
printf '{"ok": false, "hata": "x"}' > "$T/bozuk.json"
oku() { PATH="$T/bin:$PATH" WA_JETON=GIZLI-JETON-123 WA_IMLEC="$T/imlec" FAKE_GOVDE="$T/govde" bash "$S" "$@" >"$T/o" 2>&1 </dev/null; }

FAKE_YANIT="$T/iki.json" oku; rc=$?
g $rc "W1 200 + iki mesaj → rc 0"
grep -q '#41 · .* ← Resul' "$T/o" && grep -q '#42 .*\[grup\] → (benden)' "$T/o"; g $? "W2 mesajlar gönderen/yön/grup ile basılır"
[ "$(cat "$T/imlec" 2>/dev/null)" = 42 ]; g $? "W3 imleç son_sira'ya ilerler"
[ "$(stat -c %a "$T/imlec")" = 600 ]; g $? "W4 imleç dosyası 600 izinli"
grep -q '"sonra": 0' "$T/govde"; g $? "W5 imleç yokken istek sonra=0"
FAKE_YANIT="$T/iki.json" oku --sayi 5
grep -q '"sonra": 42' "$T/govde" && grep -q '"sayi": 5' "$T/govde"; g $? "W6 kayıtlı imleç ve --sayi isteğe girer"
FAKE_YANIT="$T/iki.json" oku --bastan
grep -q '"sonra": 0' "$T/govde"; g $? "W7 --bastan imleci yok sayar"
echo 7 > "$T/imlec"; FAKE_YANIT="$T/iki.json" oku --kuru
[ "$(cat "$T/imlec")" = 7 ]; g $? "W8 --kuru imleci İLERLETMEZ"
FAKE_YANIT="$T/iki.json" FAKE_KOD=401 oku; rc=$?
[ "$rc" = 4 ] && grep -q 'reddetti (http=401)' "$T/o"; g $? "W9 geçit reddi → rc 4"
FAKE_KOD=000 FAKE_RC=7 oku; rc=$?
[ "$rc" = 3 ] && grep -q 'ULAŞILAMIYOR' "$T/o"; g $? "W10 geçide ulaşılamıyor → rc 3"
echo 7 > "$T/imlec"; FAKE_YANIT="$T/bozuk.json" oku; rc=$?
[ "$rc" = 4 ] && [ "$(cat "$T/imlec")" = 7 ]; g $? "W11 ok:false gövde → rc 4, imleç değişmez"
oku --sayi abc; [ $? = 2 ]; g $? "W12 --sayi sayı değilse rc 2"
FAKE_YANIT="$T/iki.json" FAKE_KOD=401 oku
! grep -q 'GIZLI-JETON-123' "$T/o"; g $? "W13 jeton (sır) çıktıya düşmez"

echo "wa-oku: geçen=$gecen kalan=$kalan"
[ "$kalan" -eq 0 ]
