#!/usr/bin/env bash
# iskan-host.sh — İSKÂN sunucu-görüş + FAZ-4 host-doğum katmanı (--dry-run SALT-OKUR; --apply GO'lu).
#
# NEDEN: FAZ-4+ (container-provizyon) host'a ilk yazma-dokunuşunu yapmadan ÖNCE aynı
# gözlem-yüzeyinin salt-okur hâli kurulur — compose-parse, config-hash snapshot (B2),
# volume-path kesişim-kümesi (B1), host↔repo md5-drift (D1-durağı), port-flock TASARIMI (B4).
#
# DEĞİŞMEZLER (DOCTRINE'den):
#  - Put-only: bu dosyada SİLME-primitifi YOKTUR ve olmayacaktır. --dry-run yüzeyi yalnız
#    okuma-komutları koşar (cat/md5sum/ss/docker inspect/docker ps). --apply'da mutasyon İKİ
#    tek-noktadadır: container-mutasyon tek-noktası = R1 (servis-scoped up) · dosya-mutasyon
#    tek-noktası = COMPOSE-SENKRON (.bak-TS yedekli tmp+mv, BAYT re-verify'lı; silme yok).
#    Bkz GEREKLILIK G1 (put-only-gate).
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

# ── COMPOSE-SENKRON (G1 zincir-fix; cmd_apply içinde R4'ten HEMEN ÖNCE koşar) ─────────────
#
# NEDEN (tecrube-defteri G1): apply zincirinde origin/main YALNIZ karşılaştırma+kanıt için
# okunuyordu; `up`ın fiilen okuduğu compose = HOST'taki dosya. Yeni-tenant bloğunu host'a
# taşıyan hiçbir adım yoktu → her doğum elle-bridge'e muhtaçtı. Bu adım o köprüyü kurar:
# origin/main → host TAM-DOSYA eşitleme (cf-yayin ADIM-2 `git show origin/main | ssh cat>`
# deseninin sertleştirilmişi; cerrahi blok-ekleme YAGNI-merceğiyle İPTAL edildi).
#
# KAPILAR (fail-closed; --force YOK — uzlaştırma AYRI Sultan-onaylı adım olarak kalır):
#  1. 3-durum host-probe: dosya YOK → bootstrap-reddi exit=5 · ölçülemedi → exit=5 (unknown≠yok).
#  2. no-op kapısı BAYT-eş (md5): yapısal-eşlik YETMEZ — bayat cname-bloğu (ör. eski elle-bridge
#     kalıntısı mem_limit) yapısal-görünmez olduğundan yalnız BAYT-eşlik no-op sayılır
#     (doktrin-merceği MAJOR-1: D6 512m sessiz-OOM tuzağının dosya-düzeyi panzehiri).
#  3. beklenen-delta kapısı: compose_parse --haric <cname> İKİ taraftan adayı düşürür; kalanlar
#     yapısal-eş DEĞİLSE körü-körüne ezme YOK → fark-raporu kanıta + exit=5.
#  4. yazım: .bak-<TS> host-yedek → tmp+mv atomik → re-verify BAYT (ssh-cat md5 == origin/main
#     md5); düşerse .bak-restore + exit=1. docker-up BU ADIMDA ASLA çağrılmaz (container-
#     mutasyon tek-noktası R1'de kalır).
# Çıkış-kontratı: return 0 tamam/no-op · exit=1 yazım-fail (.bak-restore denendi) · exit=5
# fail-closed (R4 emsalleriyle hizalı). GO/dry-run kapıları cmd_apply'ın kendi kapılarıdır —
# YENİ GO-marker İCAT EDİLMEZ (ISKAN_FAZ4_GO şemsiyesi).
COMPOSE_SENKRON_YAZDI=0
_compose_senkron() { # <proje> <cname> <repo_dir> <kanit_dir>
  local proje="$1" cname="$2" repo_dir="$3" kanit_dir="$4"
  local senkron_kanit="$kanit_dir/compose-senkron.txt"
  local fark_kanit="$kanit_dir/compose-senkron-fark.txt"

  # 1) host compose 3-durum probe (VAR/YOK/ölçülemedi — unknown ≠ yok, fail-closed)
  local probe
  probe="$(hostsrv_okur "test -f '$HOST_COMPOSE_PATH' && echo VAR || echo YOK" | tr -d '[:space:]')"
  if [ "$probe" = "YOK" ]; then
    echo "[kırmızı] COMPOSE-SENKRON: host'ta compose-dosyası YOK ($HOST_COMPOSE_PATH) — boş-host'a tam-filo yazmak bootstrap işidir, İSKÂN-doğumu değil; apply REDDEDİLDİ (host'a dokunulmadı)" | tee "$senkron_kanit" >&2
    exit 5
  elif [ "$probe" != "VAR" ]; then
    echo "[kırmızı] COMPOSE-SENKRON: host compose ölçülemedi (fail-closed) — apply REDDEDİLDİ, host'a dokunulmadı" | tee "$senkron_kanit" >&2
    exit 5
  fi

  # 2) içerikleri BAYT-doğru indir (pipe/dosya — komut-ikamesi kuyruk-newline yutar, md5 bozar)
  local repo_tmp host_tmp
  repo_tmp="$(mktemp)" && host_tmp="$(mktemp)" || { echo "[kırmızı] COMPOSE-SENKRON: mktemp başarısız (fail-closed)" >&2; exit 5; }
  git -C "$repo_dir" show "origin/main:infra/docker-compose.server.yml" > "$repo_tmp" 2>/dev/null
  hostsrv_okur "cat '$HOST_COMPOSE_PATH'" > "$host_tmp"
  if [ ! -s "$repo_tmp" ] || [ ! -s "$host_tmp" ]; then
    rm -f "$repo_tmp" "$host_tmp"
    echo "[kırmızı] COMPOSE-SENKRON: repo/host compose ölçülemedi (fail-closed) — apply REDDEDİLDİ, host'a dokunulmadı" | tee "$senkron_kanit" >&2
    exit 5
  fi
  local repo_md5 host_md5
  repo_md5="$(md5sum "$repo_tmp" | awk '{print $1}')"
  host_md5="$(md5sum "$host_tmp" | awk '{print $1}')"

  # 3) no-op kapısı: yalnız BAYT-eş no-op'tur (yapısal-eş ama bayt-farklı = YAZILIR)
  if [ "$repo_md5" = "$host_md5" ]; then
    echo "[yeşil] COMPOSE-SENKRON: host zaten origin/main ile BAYT-eş (md5=$repo_md5) — yazım YOK (no-op)" | tee "$senkron_kanit"
    rm -f "$repo_tmp" "$host_tmp"
    return 0
  fi

  # 4) beklenen-delta kapısı: aday İKİ taraftan düşürülünce kalanlar yapısal-eş mi?
  local repo_stripped host_stripped
  repo_stripped="$(python3 "$COMPOSE_PARSE" --haric "$cname" "$repo_tmp" 2>/dev/null)"
  host_stripped="$(python3 "$COMPOSE_PARSE" --haric "$cname" "$host_tmp" 2>/dev/null)"
  if [ -z "$repo_stripped" ] || [ -z "$host_stripped" ]; then
    rm -f "$repo_tmp" "$host_tmp"
    echo "[kırmızı] COMPOSE-SENKRON: compose parse-edilemedi (fail-closed) — apply REDDEDİLDİ, host'a dokunulmadı" | tee "$senkron_kanit" >&2
    exit 5
  fi
  if [ "$repo_stripped" != "$host_stripped" ]; then
    {
      echo "== COMPOSE-SENKRON BEKLENMEDİK-FARK: fark yalnız-${cname}-delta değil → yazım REDDEDİLDİ (host'a dokunulmadı) =="
      echo "repo (origin/main, ${cname} hariç) ⟷ host ($HOST_COMPOSE_PATH, ${cname} hariç) yapısal-fark:"
      diff <(printf '%s\n' "$repo_stripped") <(printf '%s\n' "$host_stripped") | head -60
      echo "md5: repo=$repo_md5 · host=$host_md5"
      echo "muhtemel-neden: tamamlanmamış söküm (host'ta ölü tenant-bloğu) ya da elle host-düzenlemesi."
      echo "sonraki-adım: DUR — körü-körüne ezme YOK; uzlaştırma AYRI Sultan-onaylı adım (aile-notify --waiting ile SERDAR'a bildir)."
    } > "$fark_kanit"
    rm -f "$repo_tmp" "$host_tmp"
    echo "[kırmızı] COMPOSE-SENKRON: fark yalnız-${cname}-delta değil — körü-körüne ezme YOK; uzlaştırma AYRI Sultan-onaylı adım (kanıt: $fark_kanit). muhtemel-neden: tamamlanmamış söküm (host'ta ölü tenant-bloğu)" >&2
    exit 5
  fi

  # 5) TAM-DOSYA yazım: .bak-TS → tmp+mv (atomik) → BAYT re-verify; düşerse .bak-restore
  local ts bak_path
  ts="$(date +%Y%m%d-%H%M%S)"
  bak_path="${HOST_COMPOSE_PATH}.bak-${ts}"
  if ! timeout 30 ssh "${SSH_OPTS[@]}" "$SSH_HOST" "cp -a '$HOST_COMPOSE_PATH' '$bak_path'" 2>/dev/null; then
    rm -f "$repo_tmp" "$host_tmp"
    echo "[kırmızı] COMPOSE-SENKRON: host .bak alınamadı ($bak_path) — dosyaya dokunulmadı, apply REDDEDİLDİ (fail-closed)" | tee "$senkron_kanit" >&2
    exit 5
  fi
  if ! timeout 60 ssh "${SSH_OPTS[@]}" "$SSH_HOST" "cat > '${HOST_COMPOSE_PATH}.iskan-tmp' && mv '${HOST_COMPOSE_PATH}.iskan-tmp' '$HOST_COMPOSE_PATH'" < "$repo_tmp" 2>/dev/null; then
    echo "[kırmızı] COMPOSE-SENKRON: yazım başarısız — .bak-restore deneniyor ($bak_path)" | tee "$senkron_kanit" >&2
    timeout 30 ssh "${SSH_OPTS[@]}" "$SSH_HOST" "cp -a '$bak_path' '$HOST_COMPOSE_PATH'" 2>/dev/null \
      || echo "[kırmızı] .bak-restore da başarısız — host'ta elle geri-al: $bak_path" >&2
    rm -f "$repo_tmp" "$host_tmp"
    exit 1
  fi
  local sonra_md5
  sonra_md5="$(hostsrv_okur "cat '$HOST_COMPOSE_PATH'" | md5sum | awk '{print $1}')"
  if [ "$sonra_md5" != "$repo_md5" ]; then
    echo "[kırmızı] COMPOSE-SENKRON re-verify DÜŞTÜ: yazım-sonrası host-md5 ($sonra_md5) ≠ origin/main-md5 ($repo_md5) — .bak-restore deneniyor" | tee "$senkron_kanit" >&2
    timeout 30 ssh "${SSH_OPTS[@]}" "$SSH_HOST" "cp -a '$bak_path' '$HOST_COMPOSE_PATH'" 2>/dev/null \
      || echo "[kırmızı] .bak-restore da başarısız — host'ta elle geri-al: $bak_path" >&2
    rm -f "$repo_tmp" "$host_tmp"
    exit 1
  fi
  rm -f "$repo_tmp" "$host_tmp"
  COMPOSE_SENKRON_YAZDI=1
  {
    echo "== COMPOSE-SENKRON: origin/main → host TAM-DOSYA eşitleme TAMAM =="
    echo "önce : host-md5=$host_md5 (host-yedek: $bak_path)"
    echo "sonra: host-md5=$sonra_md5 == origin/main-md5=$repo_md5 (BAYT re-verify GEÇTİ)"
    echo "beklenen-delta kapısı: fark yalnız-${cname} (komşular yapısal-eş) doğrulandı; docker-up bu adımda ÇAĞRILMADI (container-mutasyon tek-noktası R1)"
  } > "$senkron_kanit"
  echo "[yeşil] COMPOSE-SENKRON: host compose origin/main'e eşitlendi (BAYT re-verify md5=$sonra_md5 · host-yedek: $bak_path) — kanıt: $senkron_kanit"
  return 0
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
#  R4: apply'dan HEMEN önce drift-kapısı — COMPOSE-SENKRON'dan (aday-scoped beklenen-delta
#      eşitleme) SONRA bağımsız-ikinci-göz: repo-desired (origin/main) ⟷ host-deployed compose
#      yapısal-eş DEĞİLSE apply REDDEDİLİR (GENEL drift-uzlaştırması AYRI Sultan-onaylı adım).
# Guard-katmanları (biri eksikse host-container'lara SIFIR-dokunuş): GO-marker → REPO-KANIT →
# COMPOSE-SENKRON (kendi fail-closed kapılarıyla) → drift-kapısı.
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

  # ── COMPOSE-SENKRON (G1 zincir-fix) — R4'ten HEMEN ÖNCE: origin/main → host compose
  # aday-scoped beklenen-delta eşitlemesi (kapılar+kontrat fonksiyon başlığında).
  _compose_senkron "$proje" "$cname" "$repo_dir" "$kanit_dir"

  # ── R4 · DRİFT-KAPISI (ZORUNLU, fail-closed) — repo-desired ⟷ host-deployed yapısal-eş mi?
  # COMPOSE-SENKRON-sonrası bağımsız İKİNCİ-göz (savunma-derinliği). Eş DEĞİLSE (ya da
  # ölçülemiyorsa) apply REDDEDİLİR: senkron yalnız aday-scoped delta'yı kapatır; GENEL
  # drift-uzlaştırması AYRI Sultan-onaylı adımdır, bu script genel-reconcile KOŞMAZ —
  # DUR + `aile-notify --waiting` ile SERDAR'a soft-blocker.
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
    # R2×SENKRON kanıt-sözleşmesi (doktrin-merceği R6): aday çalışırken dosya bu koşuda
    # güncellendiyse dosya≠çalışan-config makası kanıta ZORUNLU not düşülür (sahte-taze yasak).
    if [ "$COMPOSE_SENKRON_YAZDI" = "1" ]; then
      echo "[uyarı] COMPOSE-SENKRON notu: dosya güncellendi, çalışan-config ESKİ — recreate ayrı Sultan-alanı" | tee -a "$kanit_dir/compose-senkron.txt"
    fi
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

# ── HOST-KAPASİTE (P1e): yeni ~2g-tenant kabaca SIĞAR mı — salt-okur free/df ölçümü ──────
# Karar VERMEZ, bilgi basar (dry-run yüzeyi; kur zincirinin adım-3 önizlemesinde operatör
# doğum-öncesi kapasiteyi görsün — analiz-bulgusu: host geçmişte %93-disk'e sessizce dayanmıştı).
# Eşikler env'le: ISKAN_KAPASITE_MEM_MB (default 2048 = 2g-tenant) · ISKAN_KAPASITE_DISK_G (default 10).
echo "-- HOST-KAPASİTE (yeni ~2g-tenant ön-izlemesi, salt-okur) --"
if hostsrv_ulasilir; then
  MEM_AVAIL_MB="$(hostsrv_okur "free -m | awk '/^Mem:/{print \$7}'" | tr -d '[:space:]')"
  DISK_AVAIL_G="$(hostsrv_okur "df -BG /opt | awk 'NR==2{gsub(/G/,\"\",\$4); print \$4}'" | tr -d '[:space:]')"
  GEREKEN_MB="${ISKAN_KAPASITE_MEM_MB:-2048}"
  GEREKEN_DISK_G="${ISKAN_KAPASITE_DISK_G:-10}"
  # MINOR fix: operatör-eşiği de sayısal-doğrulanır (ölçüm gibi) — bozuk ISKAN_KAPASITE_* değeri
  # ham 'integer expression expected' + SAHTE [kırmızı] SIĞMAZ üretmesin; doğrusu [doğrulanmadı].
  if ! printf '%s' "$GEREKEN_MB" | grep -qE '^[0-9]{1,12}$'; then
    echo "  [doğrulanmadı] RAM eşiği geçersiz (ISKAN_KAPASITE_MEM_MB='${GEREKEN_MB}' sayısal değil) — SIĞAR/SIĞMAZ verilemez"
  elif printf '%s' "$MEM_AVAIL_MB" | grep -qE '^[0-9]{1,12}$'; then
    if [ "$MEM_AVAIL_MB" -ge "$GEREKEN_MB" ]; then
      echo "  [yeşil] RAM: avail ${MEM_AVAIL_MB}MB ≥ ${GEREKEN_MB}MB → ${GEREKEN_MB}MB'lık tenant SIĞAR"
    else
      echo "  [kırmızı] RAM: avail ${MEM_AVAIL_MB}MB < ${GEREKEN_MB}MB → SIĞMAZ (önce kapasite aç: uyut/temizle/büyüt)"
    fi
  else
    echo "  [doğrulanmadı] RAM ölçülemedi (free-çıktısı sayısal-parse edilemedi)"
  fi
  if ! printf '%s' "$GEREKEN_DISK_G" | grep -qE '^[0-9]{1,12}$'; then
    echo "  [doğrulanmadı] disk eşiği geçersiz (ISKAN_KAPASITE_DISK_G='${GEREKEN_DISK_G}' sayısal değil) — SIĞAR/SIĞMAZ verilemez"
  elif printf '%s' "$DISK_AVAIL_G" | grep -qE '^[0-9]{1,12}$'; then
    if [ "$DISK_AVAIL_G" -ge "$GEREKEN_DISK_G" ]; then
      echo "  [yeşil] disk(/opt): boş ${DISK_AVAIL_G}G ≥ ${GEREKEN_DISK_G}G"
    else
      echo "  [kırmızı] disk(/opt): boş ${DISK_AVAIL_G}G < ${GEREKEN_DISK_G}G → imaj+config için DAR (önce temizlik)"
    fi
  else
    echo "  [doğrulanmadı] disk ölçülemedi (df-çıktısı sayısal-parse edilemedi)"
  fi
else
  echo "  [doğrulanmadı] hostsrv erişilemedi — kapasite ölçülemedi (SIĞAR/SIĞMAZ verilemez)"
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
echo "  (plan) --apply'da COMPOSE-SENKRON koşar (R4'ten önce): bayt-eş → no-op; fark yalnız-aday-delta ise origin/main → host TAM-DOSYA eşitleme (.bak-TS + tmp+mv + BAYT re-verify); komşu-fark → fail-closed exit=5 (körü-körüne ezme YOK, uzlaştırma ayrı Sultan-adımı)"

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
