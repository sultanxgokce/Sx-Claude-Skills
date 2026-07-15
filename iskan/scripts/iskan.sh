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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_PARSE="$SCRIPT_DIR/lib/compose_parse.py"

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

# ── seans-getir (FAZ-2: K3 merdiveni) ───────────────────────────────────────────────────
#
# NEDEN: mtime-tahmini adversaryal-çürütüldü (paylaşılan-cwd'de rol-sahipliği ayırt-edilemez).
# Yerine KAYIT-tabanlı merdiven: (a) casing-reconcile → (b) kayıtlı-session-id-resume →
# (c) legacy-kimlik-imza eşleme → tek-anlamlı-değilse AÇIK-etiketli degraded-replay/SUSPECT.
#
# DEFAULT = KURU-KOŞU: hiçbir tmux-session açmaz/kapamaz, hiçbir claude-process başlatmaz,
# hiçbir dosya yazmaz — yalnız registry+tmux-ls+transkript-BAŞI okur. exit=3 (plan-exit).
# --apply bu fazda ÇALIŞMAZ (FAZ-3 Sultan-GO'suna kilitli) — guard exit=4.

# acquire_role_lock <session_id> — FAZ-3 apply-path primitifi (K3 madde-3: kilit-ömrü
# script-ömrü DEĞİL, PANE-PID'ine bağlı — bu yüzden flock fd'si script çıkışında KAPATILMAZ,
# çağıran (gelecek FAZ-3 apply-akışı) pane'in ömrü boyunca fd'yi açık tutar). Bu fazda
# --apply guard'ı erken exit ettiği için bu fonksiyon HENÜZ ÇAĞRILMIYOR — FAZ-3'ün üzerine
# inşa edeceği primitif olarak şimdiden yazılıp iskan.test.sh'te bağımsız doğrulanıyor.
acquire_role_lock() {
  local session_id="$1" lock_dir="${ISKAN_LOCK_DIR:-/tmp/iskan-locks}"
  mkdir -p "$lock_dir" 2>/dev/null || return 1
  local lock_file="$lock_dir/${session_id}.lock"
  exec {ISKAN_LOCK_FD}>"$lock_file" || return 1
  if ! flock -n "$ISKAN_LOCK_FD"; then
    echo "kırmızı: session-id ${session_id} zaten kilitli (başka bir pane sahiplenmiş)" >&2
    return 1
  fi
  echo "$ISKAN_LOCK_FD"
}

# _identity_imza_ara <rol-id> <transkript-dizini> — transkript-BAŞINDA (ilk 60 satır)
# "🧑‍🚀 <ROL> geri-yüklendi" asistan-mesajı arar. Tam-dosya grep BİLİNÇLİ KULLANILMAZ:
# firsthand-bulgu (bu leg'in probe-turunda) — geç-satırlarda başka-rolü konu-eden metin
# (ör. bu görevin kendi transkriptinde "MIMSERDAR" adının konuşma-içinde geçmesi) sahte-
# eşleşme üretiyor; yalnız asistan'ın role="assistant" + text tam-imza-kalıbıyla BAŞLAYAN
# EN-ERKEN mesajı sayılır (SessionStart-hook içeriği role="assistant" DEĞİLDİR, elenir).
_identity_imza_ara() {
  local rol="$1" dizin="$2"
  [ -d "$dizin" ] || { echo ""; return 0; }
  python3 - "$rol" "$dizin" <<'PYEOF'
import json, re, sys, os, glob

rol, dizin = sys.argv[1], sys.argv[2]
pat = re.compile(r'^🧑‍🚀\s+(\S+)\s+geri-yüklendi')
# en-taze N dosya (performans-sınırı, dürüst-belgelendi: sınırsız-tarama yapılmaz)
files = sorted(glob.glob(os.path.join(dizin, "*.jsonl")), key=os.path.getmtime, reverse=True)[:200]

eslesen = []
for fp in files:
    try:
        with open(fp, encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= 60:
                    break
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                msg = obj.get("message") or {}
                if msg.get("role") != "assistant":
                    continue
                for block in msg.get("content") or []:
                    if not isinstance(block, dict) or block.get("type") != "text":
                        continue
                    m = pat.match((block.get("text") or "").strip())
                    if m and m.group(1) == rol:
                        eslesen.append(os.path.basename(fp).removesuffix(".jsonl"))
                        break
                else:
                    continue
                break
    except OSError:
        continue

print(",".join(eslesen))
PYEOF
}

cmd_seans_getir() {
  local container="" apply=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --container) container="${2:-}"; shift 2 ;;
      --apply) apply=1; shift ;;
      *) echo "bilinmeyen argüman: $1" >&2; echo "kullanım: iskan.sh seans-getir --container <ad> [--apply]" >&2; exit 2 ;;
    esac
  done
  [ -n "$container" ] || { echo "kullanım: iskan.sh seans-getir --container <ad> [--apply]" >&2; exit 2; }

  # FAZ-3: --apply artık ÇALIŞIR, ama yalnız açık Sultan-GO env-marker'ı ile (DOCTRINE Değişmez-3:
  # kod-değişikliği tek-başına yeterli-tetik OLMAMALI — operatör her-çağrıda GO'yu bilerek beyan eder).
  if [ "$apply" -eq 1 ] && [ "${ISKAN_FAZ3_GO:-}" != "1" ]; then
    echo "[kırmızı] seans-getir --apply: FAZ-3 Sultan-GO env-marker gerekli (ISKAN_FAZ3_GO=1) — kanıtsız/yanlışlıkla-tetiklemeyi önler (DOCTRINE Değişmez-3)" >&2
    exit 4
  fi

  local kanit_dir="${ISKAN_KANIT_DIR:-iskan/kanit/faz3}"
  local apply_workdir="${ISKAN_APPLY_WORKDIR:-/config/projects/Nexus}"

  if [ "$apply" -eq 1 ]; then
    mkdir -p "$kanit_dir"
    echo "== İSKÂN seans-getir — CANLI-APPLY (FAZ-3 Sultan-GO'lu; ölü-rolleri açar, canlıya dokunmaz) =="
  else
    echo "== İSKÂN seans-getir — KURU-KOŞU (DEFAULT; hiçbir seans açmaz/kapamaz/yazmaz) =="
  fi
  echo "hedef-container: $container"

  # FAZ-2 kapsamı: yalnız cloudtop-code (SERDAR-ailesi, kaynak=aile-registry.yaml) desteklenir.
  # Diğer İSKÂN-provizyonlu container'lar (K2 iskan-registry.yaml) FAZ-4+ ürünüdür, henüz yok.
  if [ "$container" != "cloudtop-code" ]; then
    echo "[doğrulanmadı] '$container' için K2 iskan-registry henüz yok (FAZ-4 provizyon-ürünü) — bu fazda yalnız cloudtop-code (aile-registry kaynağı) desteklenir"
    exit 3
  fi

  local aile_registry="${ISKAN_AILE_REGISTRY:-/config/projects/Nexus/_agents/handoff/aile-registry.yaml}"
  local reconcile_sh="${ISKAN_RECONCILE_SH:-/config/projects/Nexus/scripts/aile-tmux-reconcile.sh}"
  local transkript_dizin="${ISKAN_TRANSCRIPT_DIR:-$HOME/.claude/projects/-config-projects-Nexus}"
  local proje_registry="${ISKAN_PROJECT_REGISTRY:-}"   # K2 session_id kaynağı — bu proje için henüz yok (boş=atlanır)

  [ -f "$aile_registry" ] || { echo "[kırmızı] aile-registry bulunamadı: $aile_registry" >&2; exit 3; }
  echo "kaynak: aile-registry ($aile_registry)"

  # (a) reconcile-compose — casing-yeniden-adlandırma self-heal ihtimali (READ-ONLY: script
  # zaten default=dry-run, biz de --apply VERMİYORUZ → registry'ye hiç dokunulmaz).
  local reconcile_out=""
  if [ -f "$reconcile_sh" ]; then
    reconcile_out="$(bash "$reconcile_sh" 2>/dev/null || true)"
  fi

  # aile-registry'den (id, tmux-hedef) çıkar + canlı-tmux-ls ile karşılaştır → kapalı-üyeler.
  local live_sessions olu_roller
  live_sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)"

  olu_roller="$(python3 - "$aile_registry" <<PYEOF
import re, sys
reg_path = sys.argv[1]
live = """$live_sessions""".split()
live_set = set(live)

lines = open(reg_path, encoding="utf-8").read().splitlines()
cur_role = None
for ln in lines:
    m = re.match(r'\s*-\s*id:\s*(\S+)', ln)
    if m:
        cur_role = m.group(1)
        continue
    m = re.match(r'\s*tmux:\s*"([^"]*)"', ln)
    if m and cur_role:
        tmux_target = m.group(1)
        tmux_session = tmux_target.split(":")[0]
        if tmux_session and tmux_session not in live_set:
            print(f"{cur_role}\t{tmux_session}")
        cur_role = None
PYEOF
)"

  if [ -z "$olu_roller" ]; then
    echo "[yeşil] kapalı-üye yok — aile-registry'deki tüm roller canlı tmux'ta bulundu"
    if [ "$apply" -eq 1 ]; then
      echo "== bitti — apply istendi ama açılacak-ölü-rol yok (idempotent-no-op); hiçbir tmux/dosya değişmedi =="
      exit 0
    fi
    echo "== bitti — kuru-koşu, hiçbir yazım yapılmadı (plan-exit) =="
    exit 3
  fi

  echo ""
  if [ "$apply" -eq 1 ]; then
    echo "-- kapalı-üyeler (kaynak: aile-registry, tmux-ls ile karşılaştırıldı) — GERÇEK-APPLY --"
  else
    echo "-- kapalı-üyeler (kaynak: aile-registry, tmux-ls ile karşılaştırıldı) --"
  fi
  local rol tmux_adi
  local rezerve_file="$kanit_dir/rezerve-ids.md"
  [ "$apply" -eq 1 ] && : > "$rezerve_file"
  while IFS=$'\t' read -r rol tmux_adi; do
    [ -n "$rol" ] || continue
    echo "[kırmızı] $rol (kayıtlı-tmux: $tmux_adi) — canlı tmux-ls'te yok"

    # reconcile bu rol için canlı-renamed bir aday buldu mu?
    if printf '%s\n' "$reconcile_out" | grep -qE "^${rol}[[:space:]].*GÜNCELLENECEK"; then
      echo "  → (a) reconcile-aday VAR (casing-yeniden-adlandırma) — aile-tmux-reconcile.sh --apply ile self-heal edilebilir; seans-getir bunu UYGULAMAZ (ayrı-araç, ayrı-onay)"
      continue
    fi

    # (b) kayıtlı-session-id-resume (K2 proje-registry; bu proje için henüz YOK → atlanır)
    kayitli_id=""
    if [ -n "$proje_registry" ] && [ -f "$proje_registry" ]; then
      kayitli_id="$(python3 - "$proje_registry" "$rol" <<'PYEOF'
import re, sys
reg_path, rol = sys.argv[1], sys.argv[2]
lines = open(reg_path, encoding="utf-8").read().splitlines()
cur_id = None
match = False
for ln in lines:
    m = re.match(r'\s*-\s*id:\s*(\S+)', ln)
    if m:
        match = (m.group(1) == rol)
        continue
    m = re.match(r'\s*session_id:\s*(\S+)', ln)
    if m and match and m.group(1) != "null":
        print(m.group(1))
        break
PYEOF
)"
    fi
    if [ -n "$kayitli_id" ]; then
      echo "  → (b) kayıtlı-id-resume: session_id=$kayitli_id (K2-registry'de bulundu; sahiplik=bu-rol) — gerçek-resume adayı"
      if [ "$apply" -eq 1 ]; then
        _iskan_apply_ac "$rol" "$tmux_adi" "resume" "$kayitli_id" "$apply_workdir" "$rezerve_file"
      fi
      continue
    fi

    # (c) legacy-kimlik-imza eşleme (transkript-başı grep, İ3-uyumlu: yalnız dosya-adı/id konuşulur)
    eslesenler="$(_identity_imza_ara "$rol" "$transkript_dizin")"
    n_eslesen=0
    [ -n "$eslesenler" ] && n_eslesen="$(($(printf '%s' "$eslesenler" | tr -cd ',' | wc -c) + 1))"
    if [ "$n_eslesen" -eq 1 ]; then
      echo "  → (c) legacy-kimlik-imza: TEK-anlamlı eşleşme (session-id=$eslesenler) — resume-source=legacy-transkript"
      if [ "$apply" -eq 1 ]; then
        _iskan_apply_ac "$rol" "$tmux_adi" "resume" "$eslesenler" "$apply_workdir" "$rezerve_file"
      fi
    elif [ "$n_eslesen" -gt 1 ]; then
      echo "  → (c) legacy-kimlik-imza: ${n_eslesen} ADAY (belirsiz) — SUSPECT-mismatch etiketli, sessiz-devam YASAK; gerçek-apply'de --fork-session + Sultan'a-sor"
      if [ "$apply" -eq 1 ]; then
        echo "  → [kırmızı] apply ATLANDI: SUSPECT-mismatch otomatik-çözülmez (kod-tasarımı gereği) — bu rol bu koşuda AÇILMADI, Sultan'a-sor"
      fi
    else
      echo "  → (c) legacy-kimlik-imza: 0 aday — resume-source=degraded-replay (dosya-tabanlı replay: kimlik+STATE/LEDGER/handoff), AÇIK-etiketli"
      if [ "$apply" -eq 1 ]; then
        local yeni_uuid
        yeni_uuid="$(python3 -c 'import uuid; print(uuid.uuid4())')"
        _iskan_apply_ac "$rol" "$tmux_adi" "degraded" "$yeni_uuid" "$apply_workdir" "$rezerve_file"
      fi
    fi
  done <<< "$olu_roller"

  echo ""
  if [ "$apply" -eq 1 ]; then
    echo "== bitti — apply tamamlandı; kanıt: $kanit_dir/ (rezerve-ids.md + bu çıktı çağıran-tarafından kaydedilir) =="
    exit 0
  fi
  echo "== bitti — kuru-koşu, hiçbir tmux/claude-process açılmadı/kapanmadı, hiçbir dosya yazılmadı (plan-exit) =="
  exit 3
}

# _iskan_apply_ac <rol> <tmux_adi> <mod:resume|degraded> <deger:session-id> <workdir> <rezerve_file>
# GERÇEK-MUTASYON: tmux new-session (-d, verilen workdir'de) + claude başlatma. acquire_role_lock ile
# ROL-adı üzerinden kilitlenir (aynı-rolü eş-zamanlı iki-çağrı açmasın); kilit script-ömrü boyunca açık
# kalır (tam pane-ömrü-boyu kilit = FAZ-3-sonrası genişletme, bkz PR-body dürüst-şerh).
_iskan_apply_ac() {
  local rol="$1" tmux_adi="$2" mod="$3" deger="$4" workdir="$5" rezerve_file="$6"

  if tmux has-session -t "$tmux_adi" 2>/dev/null; then
    echo "  → [yeşil] $rol zaten canlı (idempotent-atla) — tekrar açılmadı"
    return 0
  fi

  local lock_fd
  lock_fd="$(acquire_role_lock "$tmux_adi")" || {
    echo "  → [kırmızı] flock-çakışma: $tmux_adi başka bir çağrı tarafından kilitlenmiş — bu koşuda AÇILMADI" >&2
    return 1
  }

  if [ "$mod" = "resume" ]; then
    local transkript_yolu="$transkript_dizin/${deger}.jsonl"
    tmux new-session -d -s "$tmux_adi" -n "$tmux_adi" -c "$workdir" \
      exec env CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 claude --dangerously-skip-permissions --resume "$transkript_yolu"
    echo "  → [yeşil] AÇILDI: $tmux_adi (gerçek-resume, session_id=$deger, workdir=$workdir)"
    printf '%s\tresume\t%s\t%s\n' "$rol" "$deger" "$tmux_adi" >> "$rezerve_file"
  else
    tmux new-session -d -s "$tmux_adi" -n "$tmux_adi" -c "$workdir" \
      exec claude --dangerously-skip-permissions --session-id "$deger"
    echo "  → [yeşil] AÇILDI: $tmux_adi (degraded-replay, rezerve session_id=$deger, workdir=$workdir — bir SONRAKİ kurtarma gerçek-resume olur)"
    printf '%s\tdegraded\t%s\t%s\n' "$rol" "$deger" "$tmux_adi" >> "$rezerve_file"
  fi

  eval "exec ${lock_fd}>&-" 2>/dev/null || true
}

# ── yeni-proje (FAZ-4: UC1 container-provizyon motoru) ──────────────────────────────────
#
# NEDEN: FAZ-4 = İSKÂN'ın İLK host-mutasyonu — DOCTRINE Değişmez-1 (REPO-FIRST) + Değişmez-2
# (B1 volume-guard) + Değişmez-3 (Sultan-GO + negatif-kapı) burada somutlaşır. Bu fonksiyon
# YALNIZ git-tracked repo'ya yazar (append-only, tek-blok); host-deploy AYRI adım (iskan-host.sh
# --apply, SERDAR-onaylı cloudtop-PR merge'i SONRASI) — REPO-FIRST sırası kod-seviyesinde
# zorlanır: bu fonksiyon hiçbir ssh/docker komutu ÇALIŞTIRMAZ.
#
# Port-seçimi + repo-yazımı flock ile atomik (B4 tasarımının repo-fazı; host-fazı port-lock'u
# ayrıca iskan-host.sh --apply'da host-tarafında tutulur).

# _iskan_pick_port <repo_compose> — mevcut "127.0.0.1:<port>:8443" portlarını tarar, 8449'dan
# başlayarak ilk-boş portu döner (saf-fn, hiçbir yazım yapmaz).
_iskan_pick_port() {
  local repo_compose="$1" floor=8449 port
  local used
  used="$(grep -oE '"127\.0\.0\.1:[0-9]+:8443"' "$repo_compose" 2>/dev/null | grep -oE ':[0-9]+:' | tr -d ':' | sort -un)"
  port="$floor"
  while printf '%s\n' "$used" | grep -qx "$port"; do
    port=$((port + 1))
  done
  echo "$port"
}

# _iskan_compose_blok <ad> <cname> <config_dir> <port> <mem_limit> — HÜMA-şablon-baz, minimal
# (test-projesi/izole-provizyon → yalnız kendi config-dizini mount edilir; kişisel-proje/ortak-
# köprü mount'ları GENEL-şablonun kapsamı-dışı, gelecek-fazda proje-türüne göre parametrize edilir).
_iskan_compose_blok() {
  local ad="$1" cname="$2" config_dir="$3" port="$4" mem_limit="$5"
  cat <<EOF
  # ── İSKÂN FAZ-4 provizyon: ${ad} (iskan.sh yeni-proje ile üretildi) ────────────────
  ${cname}:
    image: lscr.io/linuxserver/code-server:latest
    container_name: ${cname}
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=\${TZ:-Europe/Istanbul}
      - DOCKER_MODS=linuxserver/mods:universal-package-install
      - INSTALL_PACKAGES=python3
    volumes:
      - ${config_dir}:/config
    ports:
      - "127.0.0.1:${port}:8443"
    restart: unless-stopped
    mem_limit: ${mem_limit}
    healthcheck:
      test: ["CMD-SHELL", "bash -c '</dev/tcp/127.0.0.1/8443' || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s
    logging:
      driver: json-file
      options: { max-size: "50m", max-file: "3" }
EOF
}

# _iskan_b1_check <repo_compose> <blok_dosyasi> — B1 kesişim-guard: aday-blok EKLENMEDEN-ÖNCE
# ve EKLENDİKTEN-SONRA compose_parse.py intersections kümesini karşılaştırır; yalnız YENİ
# ortaya-çıkan kesişimler (mevcut-kasıtlı-paylaşımlar DIŞARIDA — FAZ-1 firsthand-bulgusu) RED
# sebebi sayılır. Döner: "0" (güvenli) veya >0 (yeni-kesişim sayısı, apply RED edilmeli).
_iskan_b1_check() {
  local repo_compose="$1" blok_dosyasi="$2"
  local combined; combined="$(mktemp)"
  cat "$repo_compose" "$blok_dosyasi" > "$combined" 2>/dev/null
  local before after
  before="$(python3 "$COMPOSE_PARSE" "$repo_compose" 2>/dev/null)"
  after="$(python3 "$COMPOSE_PARSE" "$combined" 2>/dev/null)"
  rm -f "$combined"
  python3 - "$before" "$after" <<'PYEOF'
import json, sys
before_raw, after_raw = sys.argv[1], sys.argv[2]
try:
    before = json.loads(before_raw)["intersections"] if before_raw else []
    after = json.loads(after_raw)["intersections"] if after_raw else []
except Exception:
    print("parse-hatasi")
    sys.exit(0)
before_keys = {(i["path"], tuple(sorted(i["services"]))) for i in before}
new = [i for i in after if (i["path"], tuple(sorted(i["services"]))) not in before_keys]
print(len(new))
PYEOF
}

cmd_yeni_proje() {
  local ad="" mode="" mem_limit="512m"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --apply) mode="apply"; shift ;;
      --mem-limit) mem_limit="${2:-512m}"; shift 2 ;;
      -*) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
      *) ad="$1"; shift ;;
    esac
  done
  if [ -z "$ad" ] || [ -z "$mode" ]; then
    echo "kullanım: iskan.sh yeni-proje <ad> [--mem-limit <val>] --dry-run|--apply" >&2
    exit 2
  fi

  local repo_compose="${ISKAN_REPO_COMPOSE:-/config/projects/cloudtop/infra/docker-compose.server.yml}"
  [ -f "$repo_compose" ] || { echo "[kırmızı] repo-compose bulunamadı: $repo_compose" >&2; exit 1; }

  local cname="cloudtop-${ad}" config_dir="./config-${ad}"

  # İDEMPOTENCY (FAZ-4 devral-gereği): blok zaten repo-compose'daysa RED değil GEÇİŞ —
  # dry-run mevcut-hâli önizler (exit 3), apply yeniden-yazmadan başarıyla geçer (exit 0).
  # (repo-first akışında blok bir-kez merge edildikten sonra üreteç tekrar-koşulabilir olmalı.)
  local mevcut=0
  if grep -qE "container_name:[[:space:]]*${cname}\$" "$repo_compose"; then
    mevcut=1
  fi

  local port blok blok_dosyasi="" yeni_kesisim=0
  if [ "$mevcut" = "1" ]; then
    port="$(awk -v cn="$cname" '
      /container_name:/ { if ($0 ~ cn) { found=1 } else { found=0 } }
      found && /127\.0\.0\.1:[0-9]+:8443/ { match($0, /127\.0\.0\.1:[0-9]+:8443/); s=substr($0, RSTART, RLENGTH); split(s, a, ":"); print a[2]; exit }
    ' "$repo_compose")"
  else
    port="$(_iskan_pick_port "$repo_compose")"
    blok="$(_iskan_compose_blok "$ad" "$cname" "$config_dir" "$port" "$mem_limit")"
    blok_dosyasi="$(mktemp)"
    printf '%s\n' "$blok" > "$blok_dosyasi"
    yeni_kesisim="$(_iskan_b1_check "$repo_compose" "$blok_dosyasi")"
  fi

  if [ "$mode" = "dry-run" ] && [ "$mevcut" = "1" ]; then
    echo "== İSKÂN yeni-proje — KURU-KOŞU (DEFAULT; hiçbir dosya yazılmaz, host'a dokunulmaz) =="
    echo "proje: $ad · container: $cname · port: 127.0.0.1:${port:-?}:8443 (mevcut-bloktan okundu)"
    echo "[yeşil] '$cname' bloğu ZATEN repo-compose'da (idempotent) — apply'da yeniden-yazım YAPILMAYACAK"
    echo "-- MANİFEST-DOKUNUŞ (bilgilendirme — bu çağrıda hiçbir dosya yazılmadı) --"
    echo "  - ${repo_compose} (blok mevcut → repo-yazımı GEREKMİYOR)"
    echo "  - host-deploy + docker-compose up (AYRI adım: iskan-host.sh --apply, cloudtop-PR merge'i SONRASI)"
    echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN yeni-proje — KURU-KOŞU (DEFAULT; hiçbir dosya yazılmaz, host'a dokunulmaz) =="
    echo "proje: $ad · container: $cname · port: 127.0.0.1:${port}:8443 · mem_limit: $mem_limit"
    echo "-- B1 (kesişim-guard, önizleme) -- yeni-kesişim: ${yeni_kesisim} $([ "$yeni_kesisim" = "0" ] && echo '(GÜVENLİ)' || echo '(RED-adayı — apply reddedilecek)')"
    echo "-- ÜRETİLECEK COMPOSE-BLOK --"
    printf '%s\n' "$blok"
    echo "-- MANİFEST-DOKUNUŞ (bilgilendirme — bu çağrıda hiçbir dosya yazılmadı) --"
    echo "  - ${repo_compose} (REPO-FIRST: yalnız bu tek-blok eklenecek, başka satıra dokunulmayacak)"
    echo "  - host-deploy + docker-compose up (AYRI adım: iskan-host.sh --apply, cloudtop-PR merge'i SONRASI)"
    rm -f "$blok_dosyasi"
    echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  # --apply: Sultan-GO kapısı (DOCTRINE Değişmez-3) — marker yoksa repo'ya BİLE dokunulmaz.
  # (idempotent-geçişten de ÖNCE: GO'suz --apply her koşulda exit≠0, G3 negatif-kapı sözleşmesi.)
  if [ "${ISKAN_FAZ4_GO:-}" != "1" ]; then
    [ -n "$blok_dosyasi" ] && rm -f "$blok_dosyasi"
    echo "[kırmızı] yeni-proje --apply: FAZ-4 Sultan-GO env-marker gerekli (ISKAN_FAZ4_GO=1) — repo'ya/host'a SIFIR-dokunuş (DOCTRINE Değişmez-3)" >&2
    exit 4
  fi

  if [ "$mevcut" = "1" ]; then
    echo "== İSKÂN yeni-proje — İDEMPOTENT GEÇİŞ =="
    echo "[yeşil] '$cname' bloğu ZATEN repo-compose'da (port: ${port:-?}) — yeniden-yazım YOK, hiçbir dosyaya dokunulmadı"
    exit 0
  fi

  if [ "$yeni_kesisim" != "0" ]; then
    rm -f "$blok_dosyasi"
    echo "[kırmızı] yeni-proje --apply: B1 volume-path kesişim-guard tetiklendi (${yeni_kesisim} yeni-kesişim) — RED, hiçbir dosya yazılmadı" >&2
    exit 1
  fi

  echo "== İSKÂN yeni-proje — REPO-YAZIMI (FAZ-4 Sultan-GO'lu; yalnız git-tracked repo'ya yazar, host'a DOKUNMAZ) =="
  local lock_file="${ISKAN_PORT_LOCK_PATH:-$(dirname "$repo_compose")/.iskan-port.lock}"
  exec {ISKAN_YP_LOCKFD}>"$lock_file" || { rm -f "$blok_dosyasi"; echo "[kırmızı] port-lock açılamadı: $lock_file" >&2; exit 1; }
  if ! flock -w 10 "$ISKAN_YP_LOCKFD"; then
    rm -f "$blok_dosyasi"
    echo "[kırmızı] port-lock alınamadı (10sn zaman-aşımı, başka bir yeni-proje eş-zamanlı çalışıyor olabilir)" >&2
    exit 1
  fi
  {
    printf '\n'
    cat "$blok_dosyasi"
  } >> "$repo_compose"
  eval "exec ${ISKAN_YP_LOCKFD}>&-" 2>/dev/null || true
  rm -f "$blok_dosyasi"

  echo "[yeşil] compose-blok eklendi: $repo_compose (append-only, mevcut hiçbir satıra dokunulmadı)"
  echo "proje: $ad · container: $cname · port: 127.0.0.1:${port}:8443 · mem_limit: $mem_limit · B1-yeni-kesişim: 0"
  echo "== bitti — yalnız git-tracked repo yazıldı; commit/push/PR + host-deploy AYRI adımlardır (REPO-FIRST, D1) =="
  exit 0
}

case "${1:-}" in
  doctor)
    cmd_doctor
    exit 0
    ;;
  seans-getir)
    shift
    cmd_seans_getir "$@"
    ;;
  yeni-proje)
    shift
    cmd_yeni_proje "$@"
    ;;
  *)
    echo "kullanım: iskan.sh doctor | iskan.sh seans-getir --container <ad> [--apply] | iskan.sh yeni-proje <ad> [--mem-limit <val>] --dry-run|--apply" >&2
    exit 2
    ;;
esac
