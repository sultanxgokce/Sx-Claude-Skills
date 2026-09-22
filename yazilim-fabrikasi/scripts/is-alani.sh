#!/usr/bin/env bash
# is-alani.sh — fabrika 1. adım (İZOLE): paylaşılan depoda GÜVENLİ çalışma alanı aç/kapat.
#
# NİÇİN VAR: depo birden çok ajanın ORTAK alanı. Dal, global ve değişken bir durum: sen `checkout -b`
# yapıp çalışırken başka bir ajan `checkout main` derse dal ayağının altından çekilir ve SONRAKİ
# commit'lerin ONUN dalına düşer (cloudtop 2026-08-04: aynı gün üç kez; biri başkasının PR'ına karıştı).
# Çözüm dikkat değil YAPI: iş kendi worktree'sinde yapılır. Orada dal senin, kimse çekemez.
#
# Fabrika sürümü (cloudtop scripts/is-alani.sh temel; iki ek):
#   · KAPSAM KONTROLÜ: `--dosyalar a,b,c` verilirse açık PR'ların dosyalarıyla çakışma aranır → çakışma rc=2, AÇMAZ.
#   · KALICI DİZİN: /config/projects/_wt (/tmp konteyner yeniden başlayınca silinir; kayıtsız iş kaybolur).
#
# Kullanım:
#   is-alani.sh ac <iş> [--dosyalar a,b,c]  → origin/main'den TAZE worktree: <KOK>/<depo>-<iş>, dal <iş>
#   is-alani.sh kontrol                     → güvenli(0) / riskli(1) / ölçülemedi(2)
#   is-alani.sh liste                       → açık çalışma alanları
#   is-alani.sh kapat <iş>                  → worktree'yi kaldırır; kayıtsız iş varsa SİLMEZ (rc=1)
#   is-alani.sh kanca-kur                   → pre-commit korumasını BU klonda kurar (idempotent)
# Ortam: IS_ALANI_DEPO (depo kökü) · IS_ALANI_KOK (alan dizini) · IS_ALANI_ANA (ana dal, vars. main)
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPO="${IS_ALANI_DEPO:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
KOK="${IS_ALANI_KOK:-/config/projects/_wt}"
ANA="${IS_ALANI_ANA:-main}"
KANCA_SABLON="$HERE/../sablon/pre-commit"

_hata() { printf '✗ %s\n' "$*" >&2; }
_bilgi() { printf '%s\n' "$*"; }

[ -n "$DEPO" ] || { _hata "git deposu bulunamadı"; exit 1; }
DEPO_AD="$(basename "$DEPO")"

# BULUNDUĞUN yer birincil çalışma ağacı mı? (linked worktree'de git-dir ile git-common-dir AYRIŞIR)
# Bilerek cwd'ye bakar, $DEPO'ya değil: IS_ALANI_DEPO dışarıdan verilmişken worktree içinden çağrılan
# `kontrol` yanlışlıkla "riskli" dememeli.
birincil_mi() {
  local d c
  d="$(git rev-parse --absolute-git-dir 2>/dev/null || echo x)"
  c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo y)"
  [ "$d" = "$c" ]
}

# kapsam_kontrol <dosyalar,virgüllü> → 0 temiz · 2 çakışma · 3 ölçülemedi (gh yok/yetkisiz)
kapsam_kontrol() {
  local dosyalar="$1" prs n cakisan=0
  command -v gh >/dev/null 2>&1 || { _bilgi "◻ kapsam kontrolü YAPILAMADI — gh yok (açık PR'lara bakılmadı)"; return 3; }
  prs="$(cd "$DEPO" && gh pr list --state open --limit 30 --json number --jq '.[].number' 2>/dev/null)" \
    || { _bilgi "◻ kapsam kontrolü YAPILAMADI — gh pr list düştü (yetki/ağ)"; return 3; }
  [ -n "$prs" ] || { _bilgi "✓ kapsam: açık PR yok"; return 0; }
  for n in $prs; do
    local pr_dosyalar ort
    pr_dosyalar="$(cd "$DEPO" && gh pr diff "$n" --name-only 2>/dev/null)" || continue
    ort="$(printf '%s\n' "$dosyalar" | tr ',' '\n' | grep -Fx -f <(printf '%s\n' "$pr_dosyalar") || true)"
    if [ -n "$ort" ]; then
      cakisan=$((cakisan+1))
      _bilgi "⚠ PR #$n şu dosyalara zaten dokunuyor: $(printf '%s' "$ort" | tr '\n' ' ')"
    fi
  done
  if [ "$cakisan" -gt 0 ]; then
    _hata "KAPSAM ÇAKIŞMASI — $cakisan açık PR aynı dosyaları değiştiriyor. DUR ve sor; alan AÇILMADI."
    return 2
  fi
  _bilgi "✓ kapsam: açık PR'larla dosya çakışması yok ($(printf '%s' "$prs" | wc -w) PR bakıldı)"
  return 0
}

ac() {
  local is="" dosyalar=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dosyalar) dosyalar="${2:-}"; shift 2 ;;
      *) is="$1"; shift ;;
    esac
  done
  [ -n "$is" ] || { _hata "iş adı gerekiyor: is-alani.sh ac <iş> [--dosyalar a,b,c]"; exit 1; }
  git -C "$DEPO" fetch -q origin || { _hata "fetch düştü — taze başlangıç garanti edilemez, DURDUM"; exit 1; }
  if git -C "$DEPO" show-ref --verify --quiet "refs/heads/$is"; then
    _hata "'$is' dalı zaten var — başka ad seç ya da önce kapat (asla zorla üstüne yazma)"; exit 1
  fi
  if [ -n "$dosyalar" ]; then
    kapsam_kontrol "$dosyalar"; local krc=$?
    [ "$krc" -eq 2 ] && exit 2
  else
    _bilgi "· kapsam: dosya listesi verilmedi (--dosyalar a,b,c) — açık PR çakışmasına bakılmadı"
  fi
  local yol="$KOK/$DEPO_AD-$is"
  mkdir -p "$KOK"
  [ -e "$yol" ] && { _hata "$yol zaten var"; exit 1; }
  git -C "$DEPO" worktree add -q -b "$is" "$yol" "origin/$ANA" || { _hata "worktree açılamadı"; exit 1; }
  _bilgi "✓ çalışma alanı hazır (origin/$ANA üstünde, TAZE)"
  _bilgi "  cd $yol"
  _bilgi "  ⚠ worktree PAYLAŞILAN KAYNAĞI izole etmez: port · veritabanı · kilit dosyası ortaktır;"
  _bilgi "    port cevap veriyorsa SENİN süreç mi bak; kilit çakışırsa elle birleştirme, yeniden üret."
  _bilgi "  bitince: bash $HERE/is-alani.sh kapat $is"
}

kontrol() {
  local dal
  dal="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [ -z "$dal" ]; then _bilgi "◻ ölçülemedi — dal okunamadı"; return 2; fi
  if ! birincil_mi; then
    _bilgi "✓ güvenli — kendi çalışma alanındasın (dal: $dal)"; return 0
  fi
  if [ "$dal" = "$ANA" ]; then
    _bilgi "✓ güvenli — paylaşılan ağaçta ve $ANA üstündesin (commit için worktree aç)"; return 0
  fi
  _bilgi "⚠ RİSKLİ — PAYLAŞILAN ağaçta '$dal' dalındasın."
  _bilgi "  Başka bir ajan dal değiştirirse commit'in ONUN dalına düşer (2026-08-04'te 3 kez oldu)."
  _bilgi "  Yapılacak: bash $HERE/is-alani.sh ac <iş>  → kendi alanında çalış"
  return 1
}

liste() { git -C "$DEPO" worktree list | sed 's/^/  /'; }

kapat() {
  local is="${1:-}"
  [ -n "$is" ] || { _hata "iş adı gerekiyor"; exit 1; }
  local yol="$KOK/$DEPO_AD-$is"
  if [ -d "$yol" ]; then
    local kirli
    kirli="$(git -C "$yol" status --porcelain 2>/dev/null | wc -l)"
    if [ "$kirli" -gt 0 ]; then
      _hata "$yol içinde $kirli kayıtsız değişiklik var — önce commit'le ya da bilinçli sil (iş kaybı yok)"
      exit 1
    fi
    git -C "$DEPO" worktree remove "$yol" || { _hata "worktree kaldırılamadı"; exit 1; }
    _bilgi "✓ çalışma alanı kaldırıldı: $yol"
  else
    _bilgi "· çalışma alanı zaten yok: $yol"
  fi
  git -C "$DEPO" branch -d "$is" 2>/dev/null && _bilgi "✓ dal silindi: $is" \
    || _bilgi "· dal silinmedi (squash-merge sonrası -d reddeder; iş merge olduysa: git branch -D $is)"
}

kanca_kur() {
  local mevcut
  mkdir -p "$DEPO/.githooks"
  if [ ! -f "$DEPO/.githooks/pre-commit" ]; then
    cp "$KANCA_SABLON" "$DEPO/.githooks/pre-commit" && chmod +x "$DEPO/.githooks/pre-commit" \
      && _bilgi "✓ pre-commit kancası kopyalandı (.githooks/pre-commit)" \
      || { _hata "kanca kopyalanamadı"; exit 1; }
  else
    _bilgi "· .githooks/pre-commit zaten var — dokunulmadı"
  fi
  mevcut="$(git -C "$DEPO" config core.hooksPath 2>/dev/null || echo "")"
  if [ "$mevcut" = ".githooks" ]; then
    _bilgi "· koruma zaten kurulu (core.hooksPath=.githooks)"
  elif [ -n "$mevcut" ]; then
    _hata "core.hooksPath başka bir yere bakıyor ($mevcut) — üstüne YAZMADIM; elle karar ver"; exit 1
  else
    git -C "$DEPO" config core.hooksPath .githooks || { _hata "ayarlanamadı"; exit 1; }
    _bilgi "✓ koruma kuruldu (core.hooksPath=.githooks)"
  fi
  [ -x "$DEPO/.githooks/pre-commit" ] && _bilgi "✓ pre-commit yerinde ve çalıştırılabilir" \
    || { _hata "pre-commit çalıştırılamaz — koruma ETKİSİZ"; exit 1; }
}

case "${1:-kontrol}" in
  ac)        shift; ac "$@" ;;
  kanca-kur) kanca_kur ;;
  kontrol)   kontrol ;;
  liste)     liste ;;
  kapat)     shift; kapat "$@" ;;
  *)         sed -n '1,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
