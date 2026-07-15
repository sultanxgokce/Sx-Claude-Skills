#!/usr/bin/env bash
# iskan.sh — İSKÂN CLI dispatcher (FAZ-1: doctor).
#
# NEDEN: İSKÂN host-mutasyonuna (UC1/UC4/FAZ-4+) geçmeden önce çalışılan zeminin ne durumda
# olduğunu 3-durum dilinde (yeşil/kırmızı/doğrulanmadı; unknown≠fail) raporlar — Nexus
# scripts/doctor.sh + scripts/access-test.sh deseninin İSKÂN-domain'e uyarlanmış hâli.
#
# TASARIM KURALLARI (DOCTRINE Değişmez-3/5 ile hizalı):
#  - Report-only: hiçbir kontrol host'a/dosyaya yazmaz, yalnız okur/prob eder.
#  - Advisory: kırmızı bulgu script'in exit-kodunu değiştirmez (exit her-zaman 0) — divan-parity emsali.
#  - Sır-DEĞERİ asla stdout'a düşmez: yalnız dosya-adı/anahtar-adı/durum konuşulur (İ2/İ3 ruhu).
#
# Kullanım: bash iskan.sh doctor
set -uo pipefail

durum() { # durum <yeşil|kırmızı|doğrulanmadı> <ad> <detay> [remediation]
  local d="$1" ad="$2" detay="$3" fix="${4:-}"
  if [ -n "$fix" ]; then
    printf '[%s] %s: %s — %s\n' "$d" "$ad" "$detay" "$fix"
  else
    printf '[%s] %s: %s\n' "$d" "$ad" "$detay"
  fi
}

cmd_doctor() {
  echo "== İSKÂN doctor — ön-kontroller (report-only, advisory, unknown≠fail) =="

  # ── 1. hostsrv-taze-probe (K4: her koşuda TAZE probe, önbellek-güvenme) ──────────────────
  if ! command -v ssh >/dev/null 2>&1; then
    durum doğrulanmadı hostsrv-probe "ssh yok, prob edilemedi"
  elif timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 hostsrv true >/dev/null 2>&1; then
    durum yeşil hostsrv-probe "taze ssh hostsrv exit=0"
  else
    durum kırmızı hostsrv-probe "ssh hostsrv başarısız (timeout/reddedildi)" \
      "ssh-config + anahtar erişimini kontrol et (bkz DOCTRINE K4); izole-container ise access-request-emit dalına düş (İ4)"
  fi

  # ── 2. python3-varlık (iskan-host.sh compose-parse bağımlılığı) ─────────────────────────
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml" >/dev/null 2>&1; then
      durum yeşil python3 "$(python3 --version 2>&1) + PyYAML mevcut"
    else
      durum kırmızı python3 "python3 var ama PyYAML yok" "pip install pyyaml (iskan-host.sh lib/compose_parse.py bunsuz çalışmaz)"
    fi
  else
    durum kırmızı python3 "yok" "cloudtop-code INSTALL_PACKAGES'a python3 ekli olmalı (bkz Nexus scripts/doctor.sh emsali)"
  fi

  # ── 3. port-probe (ss + compose-grep) ───────────────────────────────────────────────────
  if command -v ss >/dev/null 2>&1; then
    durum yeşil port-probe-yerel "ss mevcut (host-port dinleme-sorgusu için gerekli)"
  else
    durum kırmızı port-probe-yerel "yerel ss yok" "iproute2 kur"
  fi
  REPO_COMPOSE="${ISKAN_REPO_COMPOSE:-/config/projects/cloudtop/infra/docker-compose.server.yml}"
  if [ -f "$REPO_COMPOSE" ]; then
    n_servis="$(grep -cE '^[[:space:]]{2}[A-Za-z0-9_-]+:[[:space:]]*$' "$REPO_COMPOSE" 2>/dev/null || echo 0)"
    durum yeşil compose-grep "repo-compose bulundu (${n_servis} servis-anahtarı, grep-tabanlı)"
  else
    durum doğrulanmadı compose-grep "repo-compose erişilemedi: $REPO_COMPOSE"
  fi

  # ── 4. identity-cap (4/4) + credentials-kayıt-uzlaşma ───────────────────────────────────
  CRED_YAML="${ISKAN_CREDENTIALS_YAML:-/config/projects/Nexus/_agents/credentials.yaml}"
  if [ ! -f "$CRED_YAML" ]; then
    durum doğrulanmadı identity-cap "credentials.yaml erişilemedi: $CRED_YAML"
    durum doğrulanmadı credentials-kayıt-uzlaşma "kaynak-dosya yoksa uzlaşma kontrol edilemez"
  else
    total="$(awk '/^machine_identities:/{f=1;next} f && /^[A-Za-z]/{exit} f && /^  - name:/{c++} END{print c+0}' "$CRED_YAML")"
    local_ok=0
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      [ -f "$HOME/.config/infisical/${name}.env" ] && local_ok=$((local_ok + 1))
    done < <(awk '/^machine_identities:/{f=1;next} f && /^[A-Za-z]/{exit} f && /^  - name:/{sub(/^  - name:[[:space:]]*/,""); print}' "$CRED_YAML")
    durum yeşil identity-cap "credentials.yaml: ${total} kayıtlı machine-identity, yerelde ${local_ok}/${total} identity.env mevcut"
    durum doğrulanmadı credentials-kayıt-uzlaşma "yalnız yerel-dosya+registry tutarlılığı kontrol edildi; Infisical-canlı-karşılaştırma bu fazın kapsamı-dışı (bkz Z11 drift-deseni, gelecek-faz)"
  fi

  echo "== bitti — advisory rapor, exit her-zaman 0 =="
}

case "${1:-}" in
  doctor)
    cmd_doctor
    exit 0
    ;;
  *)
    echo "kullanım: iskan.sh doctor" >&2
    exit 2
    ;;
esac
