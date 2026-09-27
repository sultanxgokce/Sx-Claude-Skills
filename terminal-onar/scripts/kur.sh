#!/usr/bin/env bash
# kur.sh — bu kutuda terminali SIFIRDAN kurar ve merkeze kaydeder.
# Slash komutunun gövdesi: /terminal-kur
#
# 🔴 NE YAPMAZ: host tarafına (tünel · Access · merkez kaydı) DOKUNMAZ. Kutu ajanının
#    orada yetkisi yoktur ve olmamalıdır; bu betik yalnız kutunun içini kurar ve
#    merkeze düşecek satırı BASAR. Satırı merkeze MUAVİN işler.
#
# 🔴 SULTAN ONAYI: Claude Code güvenlik sınıflandırıcısı iki adımı reddediyor —
#    ttyd'yi başlatmak ("Expose Local Services") ve gözetimsiz ajan kademesini yazmak
#    ("Create Unsafe Agents"). Bu DOLANILMAZ. Sultan bir kez açık onay verir; betik
#    onaysız çalışmayı denemez, sebebini söyler ve durur. (SEDİR dersi §7.3)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/ortak.sh"

_bilgi() { printf '%s\n' "$*"; }
_hata()  { printf '✗ %s\n' "$*" >&2; }

ONAY="${TERMINAL_KUR_ONAY:-}"
if [ "$ONAY" != "sultan-verdi" ]; then
  cat >&2 <<SON
✗ Sultan onayı olmadan kurulmuyor.

Bu kurulum bu kutuda bir DIŞ YÜZEY açar (web terminali) ve gözetimsiz bir onarım
kademesi kurar. İkisi de Sultan'ın bir kez onay vermesi gereken sınıftandır; gizli
bir yolla aşılmaz.

Sultan onay verdiyse:  TERMINAL_KUR_ONAY=sultan-verdi bash $0
SON
  exit 3
fi

# ── 1 · ttyd ─────────────────────────────────────────────────────────────────
if [ ! -x "$TTYD_BIN" ]; then
  _bilgi "· ttyd indiriliyor → $TTYD_BIN"
  mkdir -p "$(dirname "$TTYD_BIN")"
  # Mimari tahmin EDİLMEZ, ölçülür.
  case "$(uname -m)" in
    x86_64) M=x86_64 ;; aarch64|arm64) M=aarch64 ;;
    *) _hata "bilinmeyen mimari: $(uname -m) — ttyd elle kurulmalı"; exit 4 ;;
  esac
  SURUM="${TTYD_SURUM:-1.7.7}"
  if ! curl -fsSL -o "$TTYD_BIN.indir" \
      "https://github.com/tsl0922/ttyd/releases/download/${SURUM}/ttyd.${M}"; then
    _hata "ttyd indirilemedi (sürüm $SURUM, mimari $M)"; exit 4
  fi
  chmod +x "$TTYD_BIN.indir" && mv "$TTYD_BIN.indir" "$TTYD_BIN"
fi
"$TTYD_BIN" --version >/dev/null 2>&1 || { _hata "ttyd çalışmıyor: $TTYD_BIN"; exit 4; }
_bilgi "✓ ttyd: $($TTYD_BIN --version 2>&1 | head -1)"

# ── 2 · parola ───────────────────────────────────────────────────────────────
# 🔴 Parola kasada yaşar. Yoksa ÜRETİLMEZ ve kurulum DURUR: sessizce üretilen bir
#    parola, kayıtsız bir sırdır ve sıfırdan kurulumda geri gelmez.
if ! sifre_yukle; then
  cat >&2 <<SON
✗ Parola kasada yok: $SIFRE_ANAHTAR

Sultan ayrı bir terminalde (sohbetin içinde DEĞİL — ilk parola öyle sızmıştı):
  read -rsp "parola: " $SIFRE_ANAHTAR; echo
  export $SIFRE_ANAHTAR
  bash /config/.claude/skills/vault-cek/scripts/vault-cek.sh put $SIFRE_ANAHTAR
  unset $SIFRE_ANAHTAR
SON
  exit 5
fi
_bilgi "✓ parola kasadan okundu ($SIFRE_ANAHTAR) — değeri hiçbir yere basılmadı"

# ── 3 · kurulum (onar.sh sıfırdan kurulumu da yapar) ────────────────────────
bash "$BETIK_DIZ/onar.sh" || { _hata "kurulum düştü — günlük: $GUNLUK"; exit 6; }

# ── 4 · bekçi (kutunun kalıcı cron'u) ───────────────────────────────────────
ODA_CRON="${TO_ODA_CRON:-$PROJE/.oda/cron}"
mkdir -p "$(dirname "$ODA_CRON")" 2>/dev/null
if [ -f "$ODA_CRON" ] && grep -q 'terminal-onar-bekci' "$ODA_CRON" 2>/dev/null; then
  _bilgi "· bekçi satırları zaten var"
else
  {
    printf 'TZ=Europe/Istanbul\n'
    printf '* * * * * bash %s/bekci.sh  # terminal-onar-bekci\n' "$BETIK_DIZ"
    printf '@reboot sleep 15; bash %s/komut.sh onar  # terminal-onar-acilis\n' "$BETIK_DIZ"
  } >> "$ODA_CRON"
  _bilgi "✓ bekçi kutunun kalıcı cron'una yazıldı: $ODA_CRON"
fi

# ── 5 · ölçüm (kurdum demek yetmez) ─────────────────────────────────────────
if ! bash "$BETIK_DIZ/durum.sh" >/dev/null 2>&1; then
  _hata "kurulum bitti ama DÜZEN SAĞLAM DEĞİL — durum.sh kırmızı"
  bash "$BETIK_DIZ/durum.sh" || true
  exit 7
fi
_bilgi "✓ beş parça da sağlam (durum.sh yeşil)"

# ── 6 · merkeze düşecek satır ───────────────────────────────────────────────
cat <<SON

── MERKEZE İLETİLECEK (bu satırı MUAVİN'e gönder) ──
kutu       : $KUTU
kapi_adres : cloudtop-$KUTU:$KAPI_PORT
kapi_taban : $TABAN
parola     : kasada · anahtar $SIFRE_ANAHTAR   (değer GÖNDERİLMEZ)

Merkez kaydı MUAVİN'de: kutu listesine bu üç alan yazılır, parolayı merkez
kasadan kendisi okur. Kutu tarafında yapılacak başka bir şey yok.
SON
