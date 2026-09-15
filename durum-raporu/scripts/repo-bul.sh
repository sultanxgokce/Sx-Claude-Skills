#!/usr/bin/env bash
# repo-bul.sh — kutunun PROJE KÖKÜNÜ bulur (ekip kaydının bulunduğu dizin).
# 🔴 NİÇİN VAR (MUAVİN, 2026-09-15 paketleme): beceri AKAR'da proje AĞACININ İÇİNDE doğdu; oradan
# `pwd` her zaman doğru kökü veriyordu. Global dizine (/config/.claude/skills) kurulunca cwd artık
# proje olmayabilir → kayıt bulunamaz. Bu, filo'nun bilinen "taşıyınca sessizce kırılır" sınıfıdır
# (kanca senkronu vakası, cloudtop #469). Sıra: açık ayar → cwd → cwd'nin üst dizinleri → boş.
repo_bul() {
  local aday="${CLAUDE_PROJECT_DIR:-}" d
  if [ -n "$aday" ] && [ -f "$aday/_agents/handoff/ekip-registry.yaml" ]; then printf '%s' "$aday"; return 0; fi
  d="$(pwd)"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -f "$d/_agents/handoff/ekip-registry.yaml" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  # Son çare: ayar verilmişse onu döndür (hata iletisi yolu göstersin), yoksa cwd.
  printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}"; return 1
}
