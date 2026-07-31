#!/usr/bin/env bash
# baslat-claude.sh — İSKÂN FAZ-6 başlatma-sarmalayıcısı (b0019'un sistemik cevabı).
#
# NEDEN: sid'siz-launcher görünmezliği (b0019) — bir rol claude'u elle/rastgele session-id'yle
# açarsa K3 rezerve-id disiplini kırılır (kurtarmada gerçek-resume imkânsızlaşır). Bu sarmalayıcı
# TEK meşru başlatma-yoludur: iskan-registry'den rol-kaydını (rezerve session-id + permission-mode)
# çözer ve claude'u HER ZAMAN o kimlikle başlatır.
#
# DÜRÜST-KIRMIZI SÖZLEŞMESİ: claude-binary yoksa sahte-yeşil BASMAZ — exit≠0 + ASCII-marker
# 'claude-binary yok' + kur-reçetesi (İSKÂN GEREKLILIK G9 sözleşmesi; marker locale/ı-i tuzağına bağışık).
#
# Kullanım: bash scripts/baslat-claude.sh <rol>
# Registry: default = <script-dizini>/../iskan-registry.yaml (container-içi co-locate kopya;
#           kanonik kaynak cloudtop origin/main infra/iskan-registry.yaml). ISKAN_REGISTRY ile override.
set -uo pipefail

ROL="${1:-}"
[ -n "$ROL" ] || { echo "kullanim: baslat-claude.sh <rol>" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REG="${ISKAN_REGISTRY:-$SCRIPT_DIR/../iskan-registry.yaml}"
[ -f "$REG" ] || { echo "[kirmizi] iskan-registry bulunamadi: $REG (once iskan.sh ekip-yerlestir --apply kosulmali)" >&2; exit 1; }

# rol-kaydı çözümü: line-based python3 (PyYAML gerektirmez — İSKÂN-container'larında python3 garanti)
KAYIT="$(python3 - "$REG" "$ROL" <<'PYEOF'
import re, sys
reg, rol = sys.argv[1], sys.argv[2]
cur = None
rec = {}
for ln in open(reg, encoding="utf-8"):
    m = re.match(r'\s*-\s*id:\s*(\S+)\s*$', ln)
    if m:
        cur = m.group(1)
        continue
    for key in ("session_id", "permission_mode"):
        m = re.match(r'\s*' + key + r':\s*"?([^"\s]+)"?\s*$', ln)
        if m and cur == rol:
            rec[key] = m.group(1)
sid = rec.get("session_id")
if sid and sid != "null":
    print(sid, rec.get("permission_mode", "default"))
PYEOF
)"

if [ -z "$KAYIT" ]; then
  echo "[kirmizi] rol-kayitsiz: '$ROL' — registry'de uye-kaydi/rezerve-session-id yok ($REG)" >&2
  exit 1
fi
SID="${KAYIT%% *}"
PMODE="${KAYIT##* }"

if ! command -v claude >/dev/null 2>&1; then
  echo "[kirmizi] claude-binary yok — bu container'da claude kurulu degil (mem-cap geregi canli-claude FAZ-9 kapsami; sahte-yesil basilmaz)."
  echo "kur-recetesi: (1) compose'ta mem_limit >= 2g (claude ~357-657MB RSS olculdu) (2) nvm+node kur (3) npm install -g @anthropic-ai/claude-code"
  echo "rol=$ROL rezerve-session-id=$SID permission-mode=$PMODE (kayit hazir — binary gelince AYNI komut calisir)"
  exit 1
fi

# ── İLK AÇILIŞ mı, YENİDEN AÇILIŞ mı? ────────────────────────────────────────
# ⚠️ NİÇİN (2026-07-31, NÂZIR bildirdi → firsthand ölçüldü): kutu yeniden yaratılınca
#   `--session-id` o kimlikle İKİNCİ kez çağrılıyordu ve claude bunu reddediyor:
#     claude --session-id <var olan> --print …  → exit 1 · "Session ID … is already in use."
#   Etkileşimli kipte bu, üyeyi "oturum eski, özetten devam?" menüsünde asılı bırakıyordu.
#   MÜDÜR menüyü kendi AÇAMAZ (pane'e tuş göndermek haklı olarak yasak) → her yeniden
#   başlatma her odada bir insan-eli istiyordu. 10 kutuluk filoda 1 restart = 10 müdahale.
#
# ÖLÇÜLEN ÇÖZÜM (aynı turda üç koşuyla kanıtlandı):
#     claude --resume <var olan>  → exit 0 · üstelik önceki konuşmayı HATIRLIYOR (gerçek devam)
#     claude --resume <yeni id>   → exit 1 · "No conversation found with session ID: …"
#
# Yani SONDANIN KENDİSİ PROB'dur: önce --resume denenir, "konuşma yok" derse ilk-açılıştır
# ve --session-id ile taze başlatılır. Böylece transcript ağacına HİÇ dokunmuyoruz —
# o ağaca dokunan tek yer `ekip-ac.sh :: _transcript_var_mi` olarak kalıyor (yüzey-daraltması
# değişmezi korunur; ikinci bir dokunuş eklemek o güvenceyi sessizce zayıflatırdı).
# ⚠️ PROB İÇİN `--print` KULLANILMAZ: her açılışta gerçek bir model çağrısı yapardı VE
#   ekibin sohbetine sahte bir mesaj eklerdi (üye açtığında "hazir" diye bir alışveriş görürdü).
#   Bunun yerine launcher KENDİ izini tutar: ilk başarılı açılışta bir işaret dosyası bırakır.
#   Böylece ne transcript ağacına dokunuyoruz ne de jeton harcıyoruz.
_IZ_DIR="${BASLAT_IZ_DIR:-$HOME/.claude-baslat}"
_IZ="$_IZ_DIR/$SID.acildi"
mkdir -p "$_IZ_DIR" 2>/dev/null || true

# İşaret VARSA önce --resume, YOKSA önce --session-id. Yanılırsak claude'un kendi hata
# metni bizi düzeltir → iki yönde de düşmeden geçeriz (işaret kaybolsa da doğru çalışır).
if [ -f "$_IZ" ]; then _once="resume"; else _once="taze"; fi

_hata="$(mktemp)"; trap 'rm -f "$_hata"' EXIT

if [ "$_once" = "resume" ]; then
  if claude --resume "$SID" --name "$ROL" --permission-mode "$PMODE" 2>"$_hata"; then exit 0; fi
  if grep -qi "no conversation found" "$_hata"; then
    echo "[sari] iz vardi ama konusma yok (temizlenmis olabilir) — taze aciliyor" >&2
    : > "$_IZ"
    exec claude --session-id "$SID" --name "$ROL" --permission-mode "$PMODE"
  fi
else
  if claude --session-id "$SID" --name "$ROL" --permission-mode "$PMODE" 2>"$_hata"; then
    : > "$_IZ"; exit 0
  fi
  if grep -qi "already in use" "$_hata"; then
    echo "[sari] iz yoktu ama oturum VAR — devam ediliyor (iz onariliyor)" >&2
    : > "$_IZ"
    exec claude --resume "$SID" --name "$ROL" --permission-mode "$PMODE"
  fi
fi

# Tanımadığımız bir hata: sahte-yeşil basmayız, körlemesine taze oturum da açmayız
# (geçmişi olan bir kimliği yanlışlıkla ezme riski). Ham çıktıyı gösterip düşeriz.
echo "[kirmizi] claude beklenmedik sekilde dustu (rol=$ROL sid=$SID). Ham cikti:" >&2
sed 's/^/       | /' "$_hata" >&2
exit 1
