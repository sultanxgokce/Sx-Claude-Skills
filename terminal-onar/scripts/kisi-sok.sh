#!/usr/bin/env bash
# kisi-sok.sh — kisi-kur.sh'ın GERİ ALMA eşi (A5-2 · görev …A5Y3P). Host/konteyner KÖK işidir.
#
#   kisi-sok.sh [--kutu K] [--kisi aysenur] [--kullanici ayse] [--uid 2001] [--uygula] [--kok DİZİN]
#   rc 4 = uygulamada bir adım BAŞARISIZ (diğerleri yine denenir; tekrar koşmak güvenli)
#   VARSAYILAN = KURU KİP: ne yapacağını ADIM ADIM basar, hiçbir şeyi değiştirmez (rc 0). --uygula yalnız Sultan/host elinde, KÖK ile.
#   --kok DİZİN: tüm yolları o dizin altına taşır ve süreç/kullanıcı/grup adımlarını ATLAR (sınav kum havuzu).
# Söker (hepsi İDEMPOTENT; olmayan şey "zaten yok" basılır, hata sayılmaz):
#   1 süreçler        ttyd-kisi (ayse) ve köprü (koltuk-koprusu.py) — yalnız KENDİ komut satırlarıyla eşleşen süreçler
#   2 soketler        /run/kisi/koprusu.sock, /run/kisi/<kullanici>-ttyd.sock; sonra /run/kisi (boşsa)
#   3 istemci kopyası /opt/kisi/kisi-istemci.py; sonra /opt/kisi (boşsa)
#   4 kullanıcı+grup  yalnız uid beklenenle AYNIYSA ve kullanıcının çalışan süreci kalmadıysa
# 🔴 DOKUNMAZ: /config/.terminal-onar/kisi/izin.json (Sultan'ın yazdığı koltuk listesi) ve köprü kütüğü/izi (denetim kaydı kalır).
# 🔴 Kullanıcı başka uid ile varsa DURUR (başkasının hesabını silmez).
# Geri alınan: kisi-kur.sh --uygula ile yeniden kurulur (izin dosyası dokunulmadığı için liste korunur).
set -euo pipefail
KUTU=""; KISI="aysenur"; KULLANICI="ayse"; UID_="2001"; UYGULA=0; KOK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --kutu) KUTU="$2"; shift 2 ;; --kisi) KISI="$2"; shift 2 ;; --kullanici) KULLANICI="$2"; shift 2 ;; --uid) UID_="$2"; shift 2 ;;
    --uygula) UYGULA=1; shift ;; --kok) KOK="$2"; shift 2 ;;
    -h|--help) sed -n 2,16p "$0"; exit 0 ;;
    *) echo "kisi-sok: bilinmeyen bayrak: $1" >&2; exit 1 ;;
  esac
done
[[ "$KULLANICI" =~ ^[a-z][a-z0-9_-]{0,30}$ ]] || { echo "kisi-sok: kullanıcı adı geçersiz" >&2; exit 1; }
[[ "$KISI" =~ ^[a-z0-9-]{1,32}$ ]] || { echo "kisi-sok: kişi kimliği geçersiz" >&2; exit 1; }
[[ "$UID_" =~ ^[0-9]{4,5}$ ]] && [ "$UID_" -ge 1001 ] || { echo "kisi-sok: uid 1001 ve üstü, 4-5 haneli olmalı" >&2; exit 1; }
[ -n "$KUTU" ] || KUTU="$(hostname 2>/dev/null | sed 's/^cloudtop-//')"
[[ "$KUTU" =~ ^[a-z0-9._-]{1,40}$ ]] || { echo "kisi-sok: kutu adı geçersiz: $KUTU" >&2; exit 1; }
if [ "$UYGULA" = 1 ] && [ -z "$KOK" ] && [ "$(id -u)" != 0 ]; then echo "kisi-sok: --uygula KÖK ister (host elinde); kuru koş" >&2; exit 2; fi

P() { printf '%s%s' "$KOK" "$1"; }
RUN="$(P /run/kisi)"; OPT="$(P /opt/kisi)"; IZIN="$(P /config/.terminal-onar/kisi/izin.json)"
SOKET="$RUN/koprusu.sock"; TTYD_SOKET="$RUN/${KULLANICI}-ttyd.sock"
n=0; adim() { n=$((n+1)); printf '\nADIM %d — %s\n' "$n" "$1"; }
HATA=0
yap() { printf '  $ %s\n' "$*"; [ "$UYGULA" = 1 ] || return 0; "$@" && return 0; echo "  ✗ BAŞARISIZ (rc=$?): $*" >&2; HATA=$((HATA+1)); return 1; }
[ "$UYGULA" = 1 ] && echo "kisi-sok: UYGULA kipi · kutu=$KUTU · kişi=$KISI · kullanıcı=$KULLANICI($UID_)" || echo "kisi-sok: KURU KİP (hiçbir şey değişmez) · kutu=$KUTU · kişi=$KISI · kullanıcı=$KULLANICI($UID_)"

# süreç eşleme: komut satırı program adıyla BAŞLAYAN iki süreç (^ ile bağlı: başka bir komutun metninde bu adı geçirmesi eşleşme sayılmaz — bash -c "…koltuk-koprusu.py…" kendi kabuğunu öldürürdü); kendi kabuğumuz ve atalarımız hariç
sureckler() {
  local desen="$1" p ata; ata=" $$ $PPID "
  for p in $(pgrep -f -- "$desen" 2>/dev/null || true); do case "$ata" in *" $p "*) ;; *) echo "$p" ;; esac; done
}
adim "süreçler (ttyd-kisi, köprü)"
if [ -n "$KOK" ]; then echo "  (kum havuzu: süreç adımı atlandı)"; else
  for d in "^ttyd -i $TTYD_SOKET( |\$)" "^python3 [^ ]*koltuk-koprusu\.py( |\$)"; do
    pids="$(sureckler "$d" | tr '\n' ' ')"
    if [ -z "${pids// /}" ]; then echo "  ✓ zaten yok: ${d#^}"; else yap kill $pids || true; fi
  done
fi

adim "soketler ve $RUN"
for f in "$SOKET" "$TTYD_SOKET"; do if [ -e "$f" ]; then yap rm -f "$f" || true; else echo "  ✓ zaten yok: $f"; fi; done
if [ -d "$RUN" ]; then yap rmdir --ignore-fail-on-non-empty "$RUN" || true; else echo "  ✓ zaten yok: $RUN"; fi

adim "istemci kopyası $OPT"
if [ -e "$OPT/kisi-istemci.py" ]; then yap rm -f "$OPT/kisi-istemci.py" || true; else echo "  ✓ zaten yok: $OPT/kisi-istemci.py"; fi
if [ -d "$OPT" ]; then yap rmdir --ignore-fail-on-non-empty "$OPT" || true; fi

adim "kullanıcı ve grup ($KULLANICI)"
if [ -n "$KOK" ]; then echo "  (kum havuzu: kullanıcı adımı atlandı)"
elif ! getent passwd "$KULLANICI" >/dev/null 2>&1; then echo "  ✓ zaten yok"
else
  [ "$(id -u "$KULLANICI")" = "$UID_" ] || { echo "  ✗ '$KULLANICI' başka uid ile var ($(id -u "$KULLANICI")) — DURDU, başkasının hesabı silinmez" >&2; exit 3; }
  if pgrep -u "$KULLANICI" >/dev/null 2>&1; then echo "  ✗ '$KULLANICI' çalışan süreci var — önce süreçler durmalı, DURDU" >&2; exit 3; fi
  if yap userdel "$KULLANICI"; then
    getent group "$KULLANICI" >/dev/null 2>&1 && yap groupdel "$KULLANICI" || true
  else echo "  ✗ kullanıcı silinemedi — grup silinmedi (yarım durum bırakılmaz)" >&2; fi
fi

echo; [ -e "$IZIN" ] && echo "  ⚠ DOKUNULMADI (Sultan verisi): $IZIN" || true
[ "$HATA" -eq 0 ] || { echo "kisi-sok: TAMAMLANAMADI — $HATA adım başarısız (yukarıdaki ✗ satırları); tekrar koşmak güvenli (idempotent)" >&2; exit 4; }
[ "$UYGULA" = 1 ] && echo "kisi-sok: bitti." || echo "kisi-sok: KURU KİP bitti — hiçbir şey değişmedi. Gerçek söküm: Sultan/host elinde --uygula."
