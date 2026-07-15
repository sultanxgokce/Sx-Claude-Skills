#!/usr/bin/env bash
# iskan-host.sh — İSKÂN SALT-OKUR sunucu-görüş katmanı (FAZ-1; GO: hayır, host'a yazmaz).
#
# NEDEN: FAZ-4+ (container-provizyon) host'a ilk yazma-dokunuşunu yapmadan ÖNCE aynı
# gözlem-yüzeyinin salt-okur hâli kurulur — compose-parse, config-hash snapshot (B2),
# volume-path kesişim-kümesi (B1), host↔repo md5-drift (D1-durağı), port-flock TASARIMI (B4).
#
# DEĞİŞMEZLER (DOCTRINE'den):
#  - Put-only: bu dosyada silme-primitifi YOKTUR ve olmayacaktır — yalnız okuma-komutları
#    (cat/md5sum/ss/docker inspect/docker ps). Bkz GEREKLILIK G1 (put-only-gate).
#  - --dry-run HİÇBİR yazım yapmadan plan basar ve plan-exit sözleşmesi gereği exit=3 döner.
#  - Sır-DEĞERİ asla stdout'a düşmez.
#
# Kullanım: bash iskan-host.sh --dry-run
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_PARSE="$SCRIPT_DIR/lib/compose_parse.py"

REPO_COMPOSE="${ISKAN_REPO_COMPOSE:-/config/projects/cloudtop/infra/docker-compose.server.yml}"
HOST_COMPOSE_PATH="${ISKAN_HOST_COMPOSE_PATH:-/opt/cloudtop/docker-compose.server.yml}"
PORT_LOCK_PATH="${ISKAN_PORT_LOCK_PATH:-/opt/cloudtop/.iskan-port.lock}"
SSH_HOST="${ISKAN_SSH_HOST:-hostsrv}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=8)

hostsrv_okur() { # bir salt-okur komutu hostsrv'de çalıştırır; erişilemezse boş+1 döner
  timeout 10 ssh "${SSH_OPTS[@]}" "$SSH_HOST" "$1" 2>/dev/null
}

hostsrv_ulasilir() {
  command -v ssh >/dev/null 2>&1 && timeout 8 ssh "${SSH_OPTS[@]}" "$SSH_HOST" true >/dev/null 2>&1
}

case "${1:-}" in
  --dry-run) ;;
  *) echo "kullanım: iskan-host.sh --dry-run" >&2; exit 2 ;;
esac

echo "== İSKÂN host-görüş (SALT-OKUR, FAZ-1) =="

# ── repo-compose oku (yerel, git-tracked) ────────────────────────────────────────────────
REPO_JSON=""
if [ ! -f "$REPO_COMPOSE" ]; then
  echo "[doğrulanmadı] repo-compose: bulunamadı ($REPO_COMPOSE)"
elif ! command -v python3 >/dev/null 2>&1; then
  echo "[doğrulanmadı] repo-compose: python3 yok, parse edilemedi"
else
  REPO_JSON="$(python3 "$COMPOSE_PARSE" "$REPO_COMPOSE" 2>/dev/null)"
  if [ -n "$REPO_JSON" ]; then
    n_servis="$(printf '%s' "$REPO_JSON" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["services"]))' 2>/dev/null || echo '?')"
    echo "[yeşil] repo-compose: ${n_servis} servis okundu"
  else
    echo "[kırmızı] repo-compose: parse-hatası ($REPO_COMPOSE)"
  fi
fi

# ── B1: volume-path envanteri (guard'ın FAZ-4'te bir ADAY-bloğa karşı kullanacağı taban-küme) ─
# NOT: B1'in guard-fiili "yeni bir compose-bloğu MEVCUT kümeyle kesişmez" biçimindedir — burada
# henüz aday-blok yok (FAZ-1'de --proje parametresi tanımlı değil). Bugünkü servisler arası
# paylaşım büyük ölçüde KASITLI (compose-yorumlarında "ORTAK"/"köprü" etiketli: .claude,
# evraklar, evraklarnbf, .agent-dashboard) — bu yüzden mevcut-kesişimi [kırmızı] olarak
# etiketlemek yanlış-alarm üretir. Burada yalnız envanteri çıkarır, karar üretmeyiz.
echo "-- B1 VOLUME-PATH ENVANTERİ (FAZ-4 guard'ının aday-karşılaştırma tabanı) --"
if [ -n "$REPO_JSON" ]; then
  n_int="$(printf '%s' "$REPO_JSON" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["intersections"]))' 2>/dev/null || echo '?')"
  if [ "$n_int" = "0" ]; then
    echo "[bilgi] paylaşılan-host-path yok (0 servisler-arası kesişim)"
  else
    echo "[bilgi] ${n_int} servisler-arası paylaşılan-host-path (mevcut-tasarım, çoğu bilinçli-köprü — bkz compose-yorumları); FAZ-4'te yeni-aday bu kümeyle karşılaştırılıp gerçek-çakışmada --apply RED edilecek:"
    printf '%s' "$REPO_JSON" | python3 -c 'import json,sys; [print("   ", i) for i in json.load(sys.stdin)["intersections"]]' 2>/dev/null
  fi
else
  echo "[doğrulanmadı] repo-compose okunamadığından envanter çıkarılamadı"
fi

# ── B2: config-hash snapshot (host, salt-okur docker inspect) ───────────────────────────
echo "-- B2 CONFIG-HASH SNAPSHOT (host) --"
if hostsrv_ulasilir; then
  hostsrv_okur 'docker ps --format "{{.Names}}" | while read -r n; do h=$(docker inspect "$n" --format "{{index .Config.Labels \"com.docker.compose.config-hash\"}}" 2>/dev/null); echo "  $n: ${h:-yok}"; done'
else
  echo "  [doğrulanmadı] hostsrv erişilemedi"
fi

# ── D1: host↔repo compose yapısal-drift (compose-diff) ──────────────────────────────────
echo "-- COMPOSE-DIFF (repo git-tracked ⟷ host-deployed, D1-durağı) --"
if ! hostsrv_ulasilir; then
  echo "  [doğrulanmadı] hostsrv erişilemedi, host-dosyası okunamadı"
elif [ -z "$REPO_JSON" ]; then
  echo "  [doğrulanmadı] repo-compose okunamadığından karşılaştırılamadı"
else
  HOST_RAW="$(hostsrv_okur "cat '$HOST_COMPOSE_PATH'")"
  if [ -z "$HOST_RAW" ]; then
    echo "  [doğrulanmadı] host-dosyası okunamadı: $HOST_COMPOSE_PATH"
  else
    HOST_JSON="$(printf '%s' "$HOST_RAW" | python3 "$COMPOSE_PARSE" - 2>/dev/null)"
    if [ -z "$HOST_JSON" ]; then
      echo "  [doğrulanmadı] host-dosyası parse-edilemedi"
    elif [ "$REPO_JSON" = "$HOST_JSON" ]; then
      echo "  [yeşil] yapısal-eş (servis/volume/port kümesi birebir)"
    else
      echo "  [kırmızı] YAPISAL-FARK bulundu (yalnız görüntüleniyor, hiçbir dosya yazılmadı):"
      diff <(printf '%s\n' "$REPO_JSON") <(printf '%s\n' "$HOST_JSON") | head -40 | sed 's/^/    /'
    fi
  fi
fi

# ── B4: port-flock tasarımı (bu fazda yalnız belge/iskelet — enforce FAZ-4'te) ──────────
echo "-- PORT --"
echo "  port-flock tasarımı (B4, FAZ-4'te uygulanacak): ${PORT_LOCK_PATH} — host-flock, port-seçim+compose-yazım atomik olur, paralel iki İSKÂN aynı portu alamaz."
if [ -n "$REPO_JSON" ]; then
  echo "  repo-declared portlar:"
  printf '%s' "$REPO_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for name, svc in sorted(d["services"].items()):
    for p in svc["ports"]:
        print(f"    {name}: {p}")
' 2>/dev/null
fi
if hostsrv_ulasilir; then
  echo "  host-dinleyen-portlar (ss -ltn, salt-okur):"
  hostsrv_okur "ss -ltn 2>/dev/null | awk 'NR>1{print \$4}' | sed 's/.*://' | sort -un" | sed 's/^/    /'
else
  echo "  [doğrulanmadı] hostsrv erişilemedi, dinleyen-port listesi alınamadı"
fi

# ── MANİFEST-DOKUNUŞ (gelecekteki gerçek-apply için, bu çağrıda HİÇBİRİ yazılmadı) ───────
echo "-- MANIFEST-DOKUNUŞ (bilgilendirme — bu çağrıda hiçbir dosya yazılmadı) --"
echo "  - ${REPO_COMPOSE} (yeni compose-blok; REPO-FIRST, D1)"
echo "  - cloudtop infra/setup-tunnel.sh (hostname-satırı, FAZ-5)"
echo "  - cloudtop infra/bootstrap/inventory.yaml (repos: kaydı)"
echo "  - iskan-registry.yaml (K2 şema; şablon bu depoda, gerçek-dosya cloudtop/infra'da FAZ-4'te doğar)"

echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
exit 3
