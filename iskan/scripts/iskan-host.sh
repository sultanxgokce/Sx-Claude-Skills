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

# ── --apply (FAZ-4: iskan.sh yeni-proje'nin YAZMA-KARDEŞİ · R1-R5 SERVİS-SCOPED reçete) ──
#
# NEDEN: --dry-run yüzeyinin write-sibling'i. yeni-proje --apply YALNIZ git-tracked repo'ya
# yazar (host'a dokunmaz, D1 REPO-FIRST); bu fonksiyon o REPO-FIRST sırası KANITLANDIKTAN
# (origin/main'de aday-servis MERGED) SONRA host-doğumu yapar.
#
# ⚠️ İNCİDENT-PANZEHİRİ (2026-07-15 deneme-1 öz-giyotini — k0071 devral-reçetesi R1-R5):
# deneme-1'de bu adım deploy-host.sh + up.sh (TÜM-FİLO recreate) koştu → motor kendi
# container'ını da recreate etti, ekip düştü. Bu sürüm o yolu YAPISAL olarak kullanmaz:
#  R1: host-mutasyonu YALNIZ servis-scoped `docker compose up -d --no-recreate <aday>` —
#      up.sh / tüm-filo up / pin.yml bu dosyada ÇAĞRILMAZ (ayrı hardening-kartı b0018).
#  R2: apply host'ta `setsid -w` ile koşar (ssh-oturumu düşse iş yarım kalmaz) ve aday
#      ZATEN-çalışıyorsa up hiç çağrılmaz (kendi-container'ını hedefleme imkânsızlaşır).
#  R4: apply'dan HEMEN önce drift-kapısı — repo-desired (origin/main) ⟷ host-deployed
#      compose yapısal-eş DEĞİLSE apply REDDEDİLİR (uzlaştırma AYRI Sultan-onaylı adım).
# Guard-katmanları (biri eksikse host'a SIFIR-dokunuş): GO-marker → REPO-KANIT → drift-kapısı.
cmd_apply() {
  local proje=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --proje) proje="${2:-}"; shift 2 ;;
      *) echo "bilinmeyen argüman: $1" >&2; echo "kullanım: iskan-host.sh --apply --proje <ad>" >&2; exit 2 ;;
    esac
  done
  [ -n "$proje" ] || { echo "kullanım: iskan-host.sh --apply --proje <ad>" >&2; exit 2; }
  local cname="cloudtop-${proje}"
  local kanit_dir="${ISKAN_KANIT_DIR:-iskan/kanit/faz4}"
  local repo_dir="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"

  # ── GO-kapısı (DOCTRINE Değişmez-3) — marker yoksa host'a SIFIR-dokunuş ─────────────────
  if [ "${ISKAN_FAZ4_GO:-}" != "1" ]; then
    echo "[kırmızı] iskan-host.sh --apply: FAZ-4 Sultan-GO env-marker gerekli (ISKAN_FAZ4_GO=1) — host'a SIFIR-dokunuş" >&2
    exit 4
  fi

  # ── REPO-KANIT önkoşulu (D1 REPO-FIRST sırası kod-seviyesinde zorlanır) ─────────────────
  if ! command -v git >/dev/null 2>&1 || [ ! -d "$repo_dir/.git" ]; then
    echo "[kırmızı] cloudtop-repo bulunamadı: $repo_dir — REPO-FIRST kanıtlanamaz, host'a dokunulmadı" >&2
    exit 1
  fi
  git -C "$repo_dir" fetch -q origin main 2>/dev/null || { echo "[kırmızı] cloudtop origin fetch başarısız — host'a dokunulmadı" >&2; exit 1; }
  if ! git -C "$repo_dir" show "origin/main:infra/docker-compose.server.yml" 2>/dev/null | grep -qE "container_name:[[:space:]]*${cname}\$"; then
    echo "[kırmızı] REPO-KANIT yok: '${cname}' origin/main'de bulunamadı — REPO-FIRST (D1) önce cloudtop-PR merge edilmeli, host'a dokunulmadı" >&2
    exit 1
  fi
  echo "[yeşil] REPO-KANIT: '${cname}' origin/main'de mevcut (D1 sırası doğrulandı)"

  if ! hostsrv_ulasilir; then
    echo "[kırmızı] hostsrv erişilemedi — host'a dokunulmadı" >&2
    exit 1
  fi

  mkdir -p "$kanit_dir"

  # ── R4 · DRİFT-KAPISI (ZORUNLU, fail-closed) — repo-desired ⟷ host-deployed yapısal-eş mi?
  # Eş DEĞİLSE (ya da ölçülemiyorsa) apply REDDEDİLİR: drift-uzlaştırma AYRI Sultan-onaylı
  # adımdır, bu script reconcile KOŞMAZ — DUR + `aile-notify --waiting` ile SERDAR'a soft-blocker.
  local drift_kanit="$kanit_dir/drift-kapisi.txt"
  local repo_desired_json host_deployed_json
  repo_desired_json="$(git -C "$repo_dir" show "origin/main:infra/docker-compose.server.yml" 2>/dev/null | python3 "$COMPOSE_PARSE" - 2>/dev/null)"
  host_deployed_json="$(hostsrv_okur "cat '$HOST_COMPOSE_PATH'" | python3 "$COMPOSE_PARSE" - 2>/dev/null)"
  if [ -z "$repo_desired_json" ] || [ -z "$host_deployed_json" ]; then
    echo "[kırmızı] R4 drift-kapısı: repo/host compose ölçülemedi (fail-closed) — apply REDDEDİLDİ, host'a dokunulmadı" | tee "$drift_kanit" >&2
    exit 5
  fi
  if [ "$repo_desired_json" != "$host_deployed_json" ]; then
    {
      echo "== R4 DRİFT-KAPISI: drift ≠ 0 → apply REDDEDİLDİ (host'a SIFIR-dokunuş) =="
      echo "repo-desired (origin/main) ⟷ host-deployed ($HOST_COMPOSE_PATH) yapısal-fark:"
      diff <(printf '%s\n' "$repo_desired_json") <(printf '%s\n' "$host_deployed_json") | head -60
      echo "sonraki-adım: DUR — drift-uzlaştırma AYRI Sultan-onaylı adım; aile-notify --waiting ile SERDAR'a bildir."
    } > "$drift_kanit"
    echo "[kırmızı] R4 drift-kapısı: drift ≠ 0 — apply REDDEDİLDİ (kanıt: $drift_kanit); SERDAR'a --waiting düş" >&2
    exit 5
  fi
  echo "[yeşil] R4 drift-kapısı: drift = 0 (repo-desired ⟷ host-deployed yapısal-eş) — apply'a geçilebilir" | tee "$drift_kanit"

  # ── B2 SNAPSHOT — ÖNCE (diğer TÜM canlı-container'ların config-hash'i) ──────────────────
  local b2_once="$kanit_dir/b2-once.txt"
  hostsrv_okur 'docker ps --format "{{.Names}}" | while read -r n; do h=$(docker inspect "$n" --format "{{index .Config.Labels \"com.docker.compose.config-hash\"}}" 2>/dev/null); echo "$n $h"; done | sort' > "$b2_once"
  echo "[yeşil] B2 önce-snapshot: $b2_once ($(wc -l < "$b2_once") container)"

  # ── G9 KANITI — ÖNCE: mevcut container'ların StartedAt listesi ──────────────────────────
  local g9_kanit="$kanit_dir/g9-startedat.txt"
  {
    echo "== G9 İNCİDENT-PANZEHİRİ kanıtı — apply-ÖNCESİ mevcut container StartedAt listesi =="
    hostsrv_okur 'docker ps --format "{{.Names}}" | while read -r n; do echo "$n $(docker inspect -f "{{.State.StartedAt}}" "$n")"; done | sort'
  } > "$g9_kanit"

  # ── R2-guard: aday ZATEN çalışıyorsa up HİÇ çağrılmaz (idempotent + öz-hedefleme imkânsız) ─
  local calisiyor
  calisiyor="$(hostsrv_okur "docker ps --format '{{.Names}}'" | grep -cx "$cname" || true)"
  if [ "$calisiyor" = "0" ]; then
    # ── R1+R2 · GERÇEK-MUTASYON (TEK nokta): servis-scoped, --no-recreate, setsid'li ───────
    # NOT: /opt/cloudtop'tan koşulur → compose-proje-adı 'cloudtop' (mevcut filoyla aynı),
    # ./config-<ad> göreli-volume /opt/cloudtop altına çözülür. pin.yml BİLİNÇLİ dışarıda (R3).
    local apply_out_dosya="$kanit_dir/apply-cikti.txt"
    if ! timeout 300 ssh "${SSH_OPTS[@]}" "$SSH_HOST" \
        "cd /opt/cloudtop && setsid -w docker compose -f /opt/cloudtop/docker-compose.server.yml up -d --no-recreate ${cname} 2>&1" > "$apply_out_dosya"; then
      echo "[kırmızı] servis-scoped up başarısız (çıktı: $apply_out_dosya) — DUR, SERDAR'a --waiting düş" >&2
      cat "$apply_out_dosya" >&2
      exit 1
    fi
    echo "[yeşil] R1 servis-scoped up koştu (yalnız ${cname}; --no-recreate) — çıktı: $apply_out_dosya"
  else
    echo "[yeşil] '${cname}' zaten çalışıyor — R2-guard: up HİÇ çağrılmadı (idempotent geçiş)"
  fi

  # ── G4: doğum-kanıtı ──────────────────────────────────────────────────────────────────
  local sonuc_rc=0
  local n_canli
  n_canli="$(hostsrv_okur "docker ps --format '{{.Names}}'" | grep -cx "$cname" || true)"
  if [ "$n_canli" != "1" ]; then
    echo "[kırmızı] doğum-doğrulaması BAŞARISIZ: '${cname}' host'ta ${n_canli} kopya (beklenen 1) — B2-after yine alınacak, SERDAR'a bildir" >&2
    sonuc_rc=1
  else
    echo "[yeşil] doğum-doğrulaması: '${cname}' host'ta TAM-1 çalışıyor"
  fi

  # ── B2 SNAPSHOT — SONRA + DİFF (G7: diğer container'lar DEĞİŞMEDİ) ──────────────────────
  local b2_sonra="$kanit_dir/b2-sonra.txt"
  hostsrv_okur 'docker ps --format "{{.Names}}" | while read -r n; do h=$(docker inspect "$n" --format "{{index .Config.Labels \"com.docker.compose.config-hash\"}}" 2>/dev/null); echo "$n $h"; done | sort' > "$b2_sonra"
  local diff_out="$kanit_dir/b2-diff.txt"
  {
    echo "== B2 config-hash diff (${cname} HARİÇ diğer container'lar İÇİN 'değişmedi' beklenir) =="
    diff <(grep -v "^${cname} " "$b2_once") <(grep -v "^${cname} " "$b2_sonra") > /tmp/iskan-b2-diff.$$ 2>&1
    if [ -s /tmp/iskan-b2-diff.$$ ]; then
      echo "[kırmızı] FARK bulundu (scope-ihlal belirtisi — DUR, SERDAR'a --waiting düş):"
      cat /tmp/iskan-b2-diff.$$
    else
      echo "[yeşil] hash-eş / md5-eş — diğer container'ların config-hash'i DEĞİŞMEDİ (UNCHANGED)"
    fi
  } > "$diff_out"
  if grep -q 'FARK bulundu' "$diff_out"; then sonuc_rc=1; fi
  rm -f /tmp/iskan-b2-diff.$$
  echo "[yeşil] B2 diff-kanıtı: $diff_out"
  cat "$diff_out"

  # ── G9 KANITI — SONRA: iskantest StartedAt + 'mevcutların hiçbiri recreate-edilmedi' ────
  local aday_started
  aday_started="$(hostsrv_okur "docker inspect -f '{{.State.StartedAt}}' ${cname}")"
  {
    echo ""
    echo "== apply-SONRASI: ${cname} StartedAt = ${aday_started:-ALINAMADI} =="
    echo "beklenen: yukarıdaki apply-öncesi listedeki TÜM mevcut container StartedAt'leri bu değerden KÜÇÜK"
    echo "(= hiçbiri ${cname} doğarken recreate-edilmedi; deneme-1 öz-giyotin incident'inin panzehir-kanıtı)"
    local ihlal=0
    while read -r n s; do
      [ "$n" = "$cname" ] && continue
      [ -z "$n" ] && continue
      if [ "$s" \< "$aday_started" ]; then
        echo "  [yeşil] $n ($s) < ${cname} → recreate-EDİLMEDİ"
      else
        echo "  [kırmızı] $n ($s) ≥ ${cname} → RECREATE-ŞÜPHESİ"
        ihlal=1
      fi
    done < <(grep -E '^cloudtop' "$g9_kanit" 2>/dev/null | grep -v "^${cname} ")
    if [ "$ihlal" = "0" ] && [ -n "$aday_started" ]; then
      echo "SONUÇ: [yeşil] tüm mevcut container'lar ${cname}'ten ÖNCE başlamış — recreate-edilmedi (G9 GEÇTİ)"
    else
      echo "SONUÇ: [kırmızı] G9 ihlal-şüphesi — DUR, SERDAR'a --waiting düş"
    fi
  } >> "$g9_kanit"
  if grep -q 'RECREATE-ŞÜPHESİ' "$g9_kanit"; then sonuc_rc=1; fi
  echo "[yeşil] G9 kanıtı: $g9_kanit"

  # ── G5: healthz + python3 (retry'li — package-install/mod-init doğumdan sonra sürebilir) ─
  local port
  port="$(awk -v cn="$cname" '
    /container_name:/ { if ($0 ~ cn) { found=1 } else { found=0 } }
    found && /127\.0\.0\.1:[0-9]+:8443/ { match($0, /127\.0\.0\.1:[0-9]+:8443/); s=substr($0, RSTART, RLENGTH); split(s, a, ":"); print a[2]; exit }
  ' "$repo_dir/infra/docker-compose.server.yml")"
  local health_out="$kanit_dir/healthz.txt"
  if [ -n "$port" ]; then
    local deneme hc=""
    for deneme in 1 2 3 4 5 6 7 8 9 10 11 12; do
      hc="$(hostsrv_okur "curl -sk -o /dev/null -w 'http_code=%{http_code}' https://127.0.0.1:${port}/ ; echo; curl -s -o /dev/null -w 'http_code=%{http_code}' http://127.0.0.1:${port}/ ; echo")"
      if printf '%s' "$hc" | grep -qE 'http_code=(200|302)'; then break; fi
      sleep 10
    done
    printf '%s\n' "$hc" > "$health_out"
    printf '%s' "$hc" | grep -qE 'http_code=(200|302)' || sonuc_rc=1
  else
    echo "[doğrulanmadı] port çözülemedi, healthz atlandı" > "$health_out"
    sonuc_rc=1
  fi
  cat "$health_out"

  # NOT: `docker exec <c> command -v …` ÇALIŞMAZ — `command` shell-builtin'dir, exec'e
  # doğrudan verilemez (rc=127, hata stderr'e düşer); bash -c sarmalaması ŞART (firsthand-probe).
  local py_out="$kanit_dir/python3-check.txt"
  local deneme2
  for deneme2 in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do
    hostsrv_okur "docker exec ${cname} bash -c 'command -v python3'" > "$py_out" 2>&1
    grep -q python3 "$py_out" && break
    sleep 10
  done
  grep -q python3 "$py_out" || sonuc_rc=1
  echo "python3: $(cat "$py_out")"

  # ── B4: port-flock temizliği (repo-fazı kilidi tutulmuyor-mu, bayat-kilit yok-mu) ───────
  local lock_file="${ISKAN_PORT_LOCK_PATH:-$repo_dir/infra/.iskan-port.lock}"
  local flock_kanit="$kanit_dir/port-flock-temizlik.txt"
  if [ -e "$lock_file" ] && command -v flock >/dev/null 2>&1 && ! flock -n -x "$lock_file" true 2>/dev/null; then
    echo "[kırmızı] port-flock HÂLÂ TUTULUYOR: $lock_file (eş-zamanlı yeni-proje?)" > "$flock_kanit"
  else
    echo "[yeşil] port-flock temiz: $lock_file tutulmuyor (bayat-kilit yok)" > "$flock_kanit"
  fi
  cat "$flock_kanit"

  if [ "$sonuc_rc" != "0" ]; then
    echo "== iskan-host.sh --apply: [kırmızı] en az bir doğrulama DÜŞTÜ (exit=1) — DUR, kanıtlarla SERDAR'a --waiting düş: $kanit_dir/ ==" >&2
    exit 1
  fi
  echo "== iskan-host.sh --apply bitti: tüm doğrulamalar [yeşil] — kanıtlar: $kanit_dir/ =="
}

case "${1:-}" in
  --dry-run) ;;
  --apply)
    shift
    cmd_apply "$@"
    exit 0
    ;;
  *) echo "kullanım: iskan-host.sh --dry-run | iskan-host.sh --apply --proje <ad>" >&2; exit 2 ;;
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
