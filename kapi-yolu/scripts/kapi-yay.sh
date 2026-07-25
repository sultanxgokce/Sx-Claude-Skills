#!/usr/bin/env bash
# ============================================================================
# kapi-yay.sh — kapı şeridinin FİLOYA YAYILIM planı (kapi-yolu · Usta).
#
# NE YAPAR: yer-gerçeğini okur (harness · ortak mount · kanonik dosyalar ·
#           dağıtım-kopyası tazeliği · filo listesi) ve her kutu için
#           çalıştırılacak TEK komutu basar.
# NE YAPMAZ: `docker`/`ssh`/`curl` KOŞMAZ · başka kutuya DOKUNMAZ ·
#            .bashrc/PATH DEĞİŞTİRMEZ · sır OKUMAZ/BASMAZ.
#            (Kurulumu `setup-kapi.sh` yapar — bu script yalnız yolu gösterir.)
#
# KURU-KOŞU VARSAYILANDIR. Tek yazma-eylemi `--uygula`: kanonik kapı
# dosyalarının ORTAK mount'a (10/10 kutunun gördüğü yer) dağıtım-kopyasını
# basmak. Kutuların kendi PATH/.bashrc adımına yine DOKUNULMAZ.
#
# Kullanım:  bash kapi-yay.sh [--kuru|--uygula] [--json]
# Çıkış:     0 = rapor üretildi (kuru-koşu daima 0) · 1 = --uygula başarısız · 2 = kullanım
# ============================================================================
set -u

MOD="kuru"; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --kuru)   MOD="kuru" ;;
    --uygula) MOD="uygula" ;;
    --json)   JSON=1 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "bilinmeyen argüman: $1 (kullanım: --kuru|--uygula [--json])" >&2; exit 2 ;;
  esac
  shift
done

ORTAK="${KAPI_ORTAK_DIR:-/config/.claude}"
REPO="${KAPI_REPO:-/config/projects/cloudtop}"
KANON_DIR="${KAPI_KANON_DIR:-$REPO/infra/kapi}"
KOPYA_DIR="$ORTAK/kapi"
COMPOSE="$REPO/infra/docker-compose.server.yml"
DOSYALAR="bin/kapi setup-kapi.sh istemci-anahtar.sh"   # dağıtılan İSTEMCİ yüzeyi (host kurucusu DEĞİL)
MIN_HARNESS="2.1.129"                                   # geçit-model-keşfi (manifest requires_harness ile AYNI)

s_ok=0; s_uyari=0
say()  { printf '  %s\n' "$*"; }
bas()  { printf '\n== %s ==\n' "$*"; }
ok()   { say "✅ $*"; s_ok=$((s_ok+1)); }
uyar() { say "⚠️  $*"; s_uyari=$((s_uyari+1)); }
sha()  { sha256sum "$1" 2>/dev/null | cut -c1-12; }

surum_yeterli() { [ "$(printf '%s\n%s\n' "$MIN_HARNESS" "$1" | sort -V | head -1)" = "$MIN_HARNESS" ]; }

# ── 1) harness (geçit-model-keşfi) ──────────────────────────────────────────
HV="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
if   [ -z "$HV" ];              then HARNESS="bilinmiyor"
elif surum_yeterli "$HV";       then HARNESS="uygun"
else                                 HARNESS="eski"; fi

# ── 2) yer-gerçeği ──────────────────────────────────────────────────────────
[ -d "$ORTAK/skills" ] && ORTAK_D="var" || ORTAK_D="yok"

kanon_eksik=""; kopya_eksik=""; bayat=""
for f in $DOSYALAR; do
  [ -f "$KANON_DIR/$f" ] || kanon_eksik="$kanon_eksik $f"
  if [ -f "$KOPYA_DIR/$f" ]; then
    if [ -f "$KANON_DIR/$f" ] && [ "$(sha "$KANON_DIR/$f")" != "$(sha "$KOPYA_DIR/$f")" ]; then
      bayat="$bayat $f"
    fi
  else
    kopya_eksik="$kopya_eksik $f"
  fi
done
[ -z "$kanon_eksik" ] && KANON_D="tam" || KANON_D="eksik"
if   [ -n "$kopya_eksik" ]; then KOPYA_DURUM="eksik"
elif [ -n "$bayat" ];       then KOPYA_DURUM="BAYAT"
elif [ "$KANON_D" = tam ];  then KOPYA_DURUM="senkron"
else                             KOPYA_DURUM="doğrulanamadı(kanon-görünmez)"; fi

# ── 3) filo listesi (compose görünürse; varsayma) ───────────────────────────
FILO=""
[ -f "$COMPOSE" ] && FILO="$(grep -oE '^[[:space:]]*container_name:[[:space:]]*\S+' "$COMPOSE" | awk '{print $2}' | tr '\n' ' ')"

# ── 4) --uygula: TEK yazma-eylemi (ortak dağıtım-kopyası) ───────────────────
if [ "$MOD" = "uygula" ]; then
  bas "UYGULA — ortak dağıtım-kopyası"
  if [ "$KANON_D" != tam ]; then
    uyar "kanonik dosyalar eksik ($KANON_DIR ←$kanon_eksik) → kopya basılamaz."
    say  "   Bu kutu cloudtop reposunu görmüyor ya da checkout dalı eski."
    say  "   --uygula'yı repoyu GÖREN ve kapı dosyaları CHECKOUT'ta olan kutuda koş."
    exit 1
  fi
  for f in $DOSYALAR; do
    mkdir -p "$KOPYA_DIR/$(dirname "$f")" || exit 1
    install -m 0755 "$KANON_DIR/$f" "$KOPYA_DIR/$f" || exit 1
    ok "kopya: $KOPYA_DIR/$f (sha:$(sha "$KOPYA_DIR/$f"))"
  done
  KOPYA_DURUM="senkron"; kopya_eksik=""; bayat=""
  say "Kutulara DOKUNULMADI — her kutunun kendi PATH/.bashrc adımı aşağıdaki komutla yapılır."
fi

# ── 5) rapor ────────────────────────────────────────────────────────────────
if [ "$JSON" -eq 1 ]; then
  printf '{"mod":"%s","harness":"%s","harness_surum":"%s","min_harness":"%s","ortak_mount":"%s","kanon":"%s","kopya_durum":"%s","filo":"%s"}\n' \
    "$MOD" "$HARNESS" "${HV:-}" "$MIN_HARNESS" "$ORTAK_D" "$KANON_D" "$KOPYA_DURUM" "${FILO% }"
  exit 0
fi

echo "=== KAPI YAYILIM RAPORU (mod: $MOD) ==="

bas "yer-gerçeği"
case "$HARNESS" in
  uygun) ok "harness $HV — geçit-model-keşfi destekli (≥$MIN_HARNESS)" ;;
  eski)  uyar "harness $HV < $MIN_HARNESS — şerit açılır ama /model menüsünde kapı modelleri GÖRÜNMEZ; seçim 'kapi <model>' ile yapılır" ;;
  *)     uyar "harness sürümü okunamadı — /model menüsü desteği DOĞRULANMADI (unknown ≠ fail)" ;;
esac
[ "$ORTAK_D" = var ] && ok "ortak yapılandırma mount'u: $ORTAK (10/10 kutuda AYNI dosya)" \
                     || uyar "ortak mount görünmüyor: $ORTAK"
[ "$KANON_D" = tam ] && ok "kanonik kapı dosyaları tam: $KANON_DIR ($DOSYALAR)" \
                     || uyar "kanonik dosya eksik ($KANON_DIR ←$kanon_eksik) — kutu repoyu görmüyor ya da checkout dalı eski"
case "$KOPYA_DURUM" in
  senkron) ok "ortak dağıtım-kopyası tam ve kanonla senkron: $KOPYA_DIR" ;;
  BAYAT)   uyar "ortak dağıtım-kopyası BAYAT ←$bayat → tazele: bash $0 --uygula" ;;
  eksik)   uyar "ortak dağıtım-kopyası eksik ←$kopya_eksik → 8/10 izole kutu kapıyı göremez; bas: bash $0 --uygula" ;;
  *)       uyar "dağıtım-kopyası kanonla karşılaştırılamadı ($KOPYA_DURUM)" ;;
esac

bas "sınır (ölçülmüş — varsayım değil)"
say "cloudtop reposu YALNIZ cloudtop ve cloudtop-code kutularında mount'lu; kalan 8 kutu"
say "(vekatip · mmex · medigate · huma · mihenk · tellal · akar · s02) yalnız KENDİ projesini görür."
say "→ başlatıcıyı repo-yolundan çağırmak o kutularda ÇALIŞMAZ; ortak dağıtım-kopyası şarttır."
say "Ağ sınır DEĞİL: tüm kutular aynı iç ağda; kapıya erişim engeli yok."
say "Doğrula (host'ta, salt-oku):"
say "  docker exec <kutu> sh -c 'ls /config/projects; ls -l $KOPYA_DIR/bin/kapi'"

bas "kutu başına TEK komut (host'ta koşulur — Sultan onayı ister)"
if [ -n "$FILO" ]; then
  for c in $FILO; do
    printf '  docker exec -u abc %-18s bash %s/setup-kapi.sh\n' "$c" "$KOPYA_DIR"
  done
  say ""
  say "Aynı komut 10/10 kutuda AYNI — kurucu kendi konumundan çözülür (repo görünürlüğü gerekmez)."
  say "İdempotent: tekrar koşmak .bashrc'yi bozmaz, duplike blok üretmez."
  say "Kapatmak (kutu bazında): .bashrc'deki '# >>> kapi >>>' bloğunu sök ya da"
  say "  bash /config/projects/ocak/scripts/model-modu.sh geri  (izleri cerrahi söker)"
else
  uyar "filo listesi okunamadı ($COMPOSE görünmüyor) — bu kutu izole. Yalnız kendi adımın:"
  say  "  bash $KOPYA_DIR/setup-kapi.sh"
fi

bas "geri-alma"
say "  bash /config/projects/ocak/scripts/model-modu.sh geri     # disk izlerini cerrahi söker"
say "  yeni pencerede: claude                                    # varsayılan şerit (hep çalışır)"

bas "özet"
echo "  $s_ok yeşil · $s_uyari uyarı · mod=$MOD"
[ "$MOD" = "kuru" ] && echo "  KURU-KOŞU: hiçbir dosya yazılmadı. Uygulamak için: bash $0 --uygula"
exit 0
