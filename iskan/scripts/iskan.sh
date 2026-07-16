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
      # FAZ-6 generator-hizası: İSKÂN-container'ları ekip-hazır doğar (tmux=oturum, git=ekip-notify REPO_ROOT)
      - INSTALL_PACKAGES=tmux|git|python3
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

# ── cf-yayin (FAZ-5: CF-hostname yayını — Access + DNS + tünel-ingress) ─────────────────
#
# NEDEN: FAZ-5 = İSKÂN'ın DIŞA-DÖNÜK ilk yeteneği — bir projeye CF-Access + DNS-CNAME +
# tünel-ingress ekler. EN YÜKSEK blast-radius: CF-tüneli 7 production-hostname'i (izole
# privacy-tenant'lar dahil) fronting eder. Bu yüzden üç panzehir KOD-seviyesinde:
#  (1) GO-kapısı: apply yalnız ISKAN_FAZ5_GO=1 ile; marker yoksa CF'e/host'a SIFIR-dokunuş (exit=4).
#  (2) REPO-FIRST: hostname-satırı cloudtop origin/main'de YOKSA apply RED (exit=1) —
#      host'a giden içerik working-tree'den DEĞİL `git show origin/main:`den beslenir.
#  (3) 7-HOSTNAME SERT-KAPI: her dokunuştan sonra 7 production-hostname curl'lenir;
#      HERHANGİ biri 302/401/403 dışına düşerse OTO-GERİ-AL (.bak restore + cloudflared
#      restart) + exit=1 — regresyonlu-durumda script "başarılı" ÇIKAMAZ.
#
# CF-yüzeyi cloudflare-erisim/cf.sh'e DELEGE edilir (owner-domain-dokunma, ADR-001):
# Access-app + policy + proxied-CNAME = `cf.sh onboard <host>` (idempotent, mevcut
# app/policy/kayıt varsa no-op). Tünel-ingress = setup-tunnel.sh (host'ta config.yml'i
# kendisi .bak'layıp yeniden-yazar + cloudflared restart eder).

ISKAN_PROD_HOSTS="${ISKAN_PROD_HOSTS:-pc code vekatip mmex medi huma m}"

# _cf_yedi_hostname_olc — 7 production-hostname'in http-kodlarını "h=KOD ..." tek-satır döner
_cf_yedi_hostname_olc() {
  local h out=""
  for h in $ISKAN_PROD_HOSTS; do
    out="${out}${h}=$(curl -sI -o /dev/null -w '%{http_code}' --max-time 10 "https://${h}.mmepanel.com" 2>/dev/null || echo 000) "
  done
  printf '%s' "$out"
}

# _cf_yedi_hostname_temiz_mi <ölçüm-satırı> — tüm kodlar 302/401/403 kümesinde mi (0=temiz)
_cf_yedi_hostname_temiz_mi() {
  local kod
  for kod in $(printf '%s' "$1" | grep -oE '=[0-9]+' | tr -d '='); do
    case "$kod" in 302|401|403) : ;; *) return 1 ;; esac
  done
  return 0
}

cmd_cf_yayin() {
  local proje="" mode=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --apply) mode="apply"; shift ;;
      -*) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
      *) proje="$1"; shift ;;
    esac
  done
  if [ -z "$proje" ] || [ -z "$mode" ]; then
    echo "kullanım: iskan.sh cf-yayin <proje> --dry-run|--apply" >&2
    exit 2
  fi

  local host="${proje}.mmepanel.com" cname="cloudtop-${proje}"
  local repo_dir="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
  local repo_compose="${ISKAN_REPO_COMPOSE:-$repo_dir/infra/docker-compose.server.yml}"
  local cf_sh="${ISKAN_CF_SH:-$HOME/.claude/skills/cloudflare-erisim/scripts/cf.sh}"
  local ssh_host="${ISKAN_SSH_HOST:-hostsrv}"
  local kanit_dir="${ISKAN_KANIT_DIR:-iskan/kanit/faz5}"

  # port: repo-compose'daki cloudtop-<proje> bloğundan (yoksa boş → doğrulanmadı-dili)
  local port=""
  [ -f "$repo_compose" ] && port="$(awk -v cn="$cname" '
    /container_name:/ { if ($0 ~ cn) { found=1 } else { found=0 } }
    found && /127\.0\.0\.1:[0-9]+:8443/ { match($0, /127\.0\.0\.1:[0-9]+:8443/); s=substr($0, RSTART, RLENGTH); split(s, a, ":"); print a[2]; exit }
  ' "$repo_compose")"

  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN cf-yayin — KURU-KOŞU (DEFAULT; CF-API'ye/host'a/dosyaya SIFIR-dokunuş) =="
    echo "proje: $proje · hostname: $host · hedef-servis: http://localhost:${port:-<port-çözülemedi: önce yeni-proje compose-bloğu>}"
    echo ""
    echo "-- PLAN (apply'da sırayla; her adım idempotent) --"
    echo "  1. CF-onboard (cf.sh onboard $host): Access-app + Allow-policy + proxied DNS-CNAME → tünel"
    echo "     (mevcut app/policy/kayıt varsa no-op; 7 mevcut hostname'in Access/DNS'ine DOKUNMAZ)"
    echo "  2. tünel-ingress-satırı: setup-tunnel.sh'te '$host → http://localhost:${port:-?}' (REPO-FIRST:"
    echo "     satır cloudtop origin/main'de YOKSA apply RED; host'a origin/main içeriği .bak'lı yazılır)"
    echo "  3. host'ta setup-tunnel.sh koşulur (config.yml'i kendisi .bak'lar + cloudflared restart)"
    echo "  4. 7-HOSTNAME SERT-KAPI: pc·code·vekatip·mmex·medi·huma·m curl → hepsi 302/401/403 değilse"
    echo "     OTO-GERİ-AL (.bak restore + cloudflared restart) + exit=1"
    echo ""
    # REPO-KANIT önizleme (salt-okur; repo erişilemezse doğrulanmadı-dili, dry-run yine plan-exit)
    if [ -d "$repo_dir/.git" ] && git -C "$repo_dir" show origin/main:infra/setup-tunnel.sh 2>/dev/null | grep -qi "$proje"; then
      echo "[yeşil] REPO-KANIT önizleme: '$proje' origin/main setup-tunnel.sh'te MEVCUT → apply repo-kapısını geçer"
    else
      echo "[doğrulanmadı] REPO-KANIT önizleme: '$proje' origin/main setup-tunnel.sh'te henüz YOK → apply RED eder (önce cloudtop-PR merge)"
    fi
    echo "== dry-run: hiçbir yazım/API-çağrısı yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  # ── --apply · KAPI-1: Sultan-GO marker (HER ŞEYDEN önce — CF'e/host'a SIFIR-dokunuş) ────
  if [ "${ISKAN_FAZ5_GO:-}" != "1" ]; then
    echo "[kırmızı] cf-yayin --apply: FAZ-5 Sultan-GO env-marker gerekli (ISKAN_FAZ5_GO=1) — CF-config'e/host'a SIFIR-dokunuş (DOCTRINE Değişmez-3)" >&2
    exit 4
  fi

  # ── KAPI-2: REPO-KANIT (D1 REPO-FIRST) — hostname origin/main'de yaşamalı ───────────────
  if ! command -v git >/dev/null 2>&1 || [ ! -d "$repo_dir/.git" ]; then
    echo "[kırmızı] cloudtop-repo bulunamadı: $repo_dir — REPO-FIRST kanıtlanamaz, hiçbir yere dokunulmadı" >&2
    exit 1
  fi
  git -C "$repo_dir" fetch -q origin main 2>/dev/null || { echo "[kırmızı] cloudtop origin fetch başarısız — hiçbir yere dokunulmadı" >&2; exit 1; }
  if ! git -C "$repo_dir" show origin/main:infra/setup-tunnel.sh 2>/dev/null | grep -qi "$proje"; then
    echo "[kırmızı] REPO-KANIT yok: '$proje' origin/main setup-tunnel.sh'te bulunamadı — önce cloudtop-PR merge (D1), hiçbir yere dokunulmadı" >&2
    exit 1
  fi
  if ! git -C "$repo_dir" show origin/main:infra/docker-compose.server.yml 2>/dev/null | grep -qE "container_name:[[:space:]]*${cname}\$"; then
    echo "[kırmızı] REPO-KANIT yok: '$cname' origin/main compose'unda bulunamadı (hostname arkasında servis olmalı) — hiçbir yere dokunulmadı" >&2
    exit 1
  fi
  echo "[yeşil] REPO-KANIT: '$proje' hostname-satırı + '$cname' compose-bloğu origin/main'de (D1 doğrulandı)"

  # port'u AUTHORİTATİF kaynaktan (origin/main) yeniden çöz
  port="$(git -C "$repo_dir" show origin/main:infra/docker-compose.server.yml 2>/dev/null | awk -v cn="$cname" '
    /container_name:/ { if ($0 ~ cn) { found=1 } else { found=0 } }
    found && /127\.0\.0\.1:[0-9]+:8443/ { match($0, /127\.0\.0\.1:[0-9]+:8443/); s=substr($0, RSTART, RLENGTH); split(s, a, ":"); print a[2]; exit }
  ')"
  [ -n "$port" ] || { echo "[kırmızı] '$cname' port'u origin/main compose'undan çözülemedi — hiçbir yere dokunulmadı" >&2; exit 1; }

  [ -f "$cf_sh" ] || { echo "[kırmızı] cf.sh bulunamadı: $cf_sh — hiçbir yere dokunulmadı" >&2; exit 1; }
  if ! command -v ssh >/dev/null 2>&1 || ! timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_host" true >/dev/null 2>&1; then
    echo "[kırmızı] $ssh_host erişilemedi — hiçbir yere dokunulmadı" >&2
    exit 1
  fi

  mkdir -p "$kanit_dir"
  echo "== İSKÂN cf-yayin — CANLI-APPLY (FAZ-5 Sultan-GO'lu) · $host → localhost:$port =="

  # ── BASELINE: 7-hostname ÖNCE ─────────────────────────────────────────────────────────
  local once sonra
  once="$(_cf_yedi_hostname_olc)"
  printf 'ÖNCE : %s\n' "$once" | tee "$kanit_dir/yedi-hostname-once.txt"
  if ! _cf_yedi_hostname_temiz_mi "$once"; then
    echo "[kırmızı] baseline zaten KİRLİ (302/401/403-dışı kod var) — dokunmadan DUR, SERDAR'a --waiting düş" >&2
    exit 1
  fi

  # ── ADIM-1: CF-onboard (Access-app + policy + DNS; cf.sh'e delege, idempotent) ─────────
  local onboard_out="$kanit_dir/cf-onboard.txt"
  if ! bash "$cf_sh" onboard "$host" > "$onboard_out" 2>&1; then
    echo "[kırmızı] cf.sh onboard başarısız (host'a HİÇ dokunulmadı) — çıktı: $onboard_out" >&2
    tail -5 "$onboard_out" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-1 cf-onboard tamam (Access+policy+DNS idempotent) — kanıt: $onboard_out"

  # ── ADIM-2: tünel-deploy (host setup-tunnel.sh'i origin/main içeriğiyle .bak'lı güncelle + koş) ─
  # İçerik working-tree'den DEĞİL origin/main'den akar (REPO-FIRST saf-hâli; bayat/kirli
  # working-tree host'a sızamaz). setup-tunnel.sh config.yml'i kendisi .bak'lar (satır 45).
  if ! timeout 15 ssh -o BatchMode=yes "$ssh_host" "cp -a /opt/cloudtop/setup-tunnel.sh /opt/cloudtop/setup-tunnel.sh.bak"; then
    echo "[kırmızı] host setup-tunnel.sh .bak alınamadı — host'a dokunulmadı, DUR" >&2
    exit 1
  fi
  if ! git -C "$repo_dir" show origin/main:infra/setup-tunnel.sh | timeout 15 ssh -o BatchMode=yes "$ssh_host" "cat > /opt/cloudtop/setup-tunnel.sh && chmod +x /opt/cloudtop/setup-tunnel.sh"; then
    echo "[kırmızı] host setup-tunnel.sh yazımı başarısız — geri-al: .bak restore" >&2
    timeout 15 ssh -o BatchMode=yes "$ssh_host" "cp -a /opt/cloudtop/setup-tunnel.sh.bak /opt/cloudtop/setup-tunnel.sh" || true
    exit 1
  fi
  local tunnel_out="$kanit_dir/setup-tunnel-kosu.txt"
  if ! timeout 300 ssh -o BatchMode=yes "$ssh_host" "setsid -w bash /opt/cloudtop/setup-tunnel.sh" > "$tunnel_out" 2>&1; then
    echo "[kırmızı] setup-tunnel.sh host-koşusu başarısız — OTO-GERİ-AL başlıyor (çıktı: $tunnel_out)" >&2
    timeout 60 ssh -o BatchMode=yes "$ssh_host" "cp -a /etc/cloudflared/config.yml.bak /etc/cloudflared/config.yml && cp -a /opt/cloudtop/setup-tunnel.sh.bak /opt/cloudtop/setup-tunnel.sh && systemctl restart cloudflared" || true
    exit 1
  fi
  echo "[yeşil] ADIM-2 tünel-deploy tamam (host .bak'lı, origin/main içerikli) — kanıt: $tunnel_out"

  # ── ADIM-3: 7-HOSTNAME SERT-KAPI (+ regresyonda OTO-GERİ-AL) ────────────────────────────
  sleep 5
  sonra="$(_cf_yedi_hostname_olc)"
  printf 'SONRA: %s\n' "$sonra" | tee "$kanit_dir/yedi-hostname-sonra.txt"
  if ! _cf_yedi_hostname_temiz_mi "$sonra"; then
    echo "[kırmızı] 7-HOSTNAME REGRESYON tespit edildi — OTO-GERİ-AL (.bak restore + cloudflared restart)" >&2
    timeout 60 ssh -o BatchMode=yes "$ssh_host" "cp -a /etc/cloudflared/config.yml.bak /etc/cloudflared/config.yml && cp -a /opt/cloudtop/setup-tunnel.sh.bak /opt/cloudtop/setup-tunnel.sh && systemctl restart cloudflared" || true
    sleep 5
    printf 'GERİ-AL-SONRASI: %s\n' "$(_cf_yedi_hostname_olc)" | tee -a "$kanit_dir/yedi-hostname-sonra.txt"
    echo "[kırmızı] DUR — SERDAR'a --waiting düş (kanıtlar: $kanit_dir/)" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-3 sert-kapı GEÇTİ: 7 hostname regresyonsuz"

  # ── ADIM-4: yeni-hostname Access-challenge (DNS-yayılımı için retry'li) ─────────────────
  local deneme kod=""
  for deneme in 1 2 3 4 5 6 7 8 9 10 11 12; do
    kod="$(curl -sI -o /dev/null -w '%{http_code}' --max-time 10 "https://$host" 2>/dev/null || echo 000)"
    case "$kod" in 302|403) break ;; esac
    sleep 10
  done
  printf '%s http=%s\n' "$host" "$kod" | tee "$kanit_dir/yeni-hostname-http.txt"
  case "$kod" in
    302|403) echo "[yeşil] ADIM-4: $host Access-challenge veriyor (http=$kod)" ;;
    *) echo "[kırmızı] ADIM-4: $host beklenen 302/403 vermedi (http=$kod) — 7-hostname temiz olduğundan GERİ-ALINMADI; DNS-yayılımı/ingress'i incele, SERDAR'a --waiting düş" >&2; exit 1 ;;
  esac

  echo "== cf-yayin bitti: $host CANLI + 7-hostname regresyonsuz — kanıtlar: $kanit_dir/ =="
  exit 0
}

# ── ekip-yerlestir (FAZ-6: ekip-yerleştirme — scaffold + tmux + kimlik-banner + rezerve-id) ─
#
# NEDEN: FAZ-6 = İSKÂN'ın "container aç" yeteneğinin "ekip yaşat"a dönüşümü. Kayıtlı bir
# İSKÂN-projesine koordinasyon-iskeletini (ekip-kur scaffold, headless) kurar + roster-üyelerini
# rezerve session-id'li tmux-oturumları olarak yerleştirir. K3 rezerve-id disiplini (FAZ-2'de
# kanıtlanan) burada İLK kez fabrika-yolu olur; b0019 (sid'siz-launcher görünmezliği) sistemik
# kapanır (baslat-claude.sh sarmalayıcısı = tek meşru başlatma-yolu).
#
# GO-KAPISI YOK (bilinçli, GEREKLILIK-sözleşmesi): FAZ-6 hedef-container-İÇİ iştir — host-compose'a,
# CF'e, diğer container'lara dokunmaz. Yetki = Sultan blanket-GO 2026-07-16 ("İSKÂN'ı bitir FAZ-5→9",
# k0074 GEREKLILIK başlık-satırı) + MÜHÜRDAR tescilde apply'ı BİZZAT koşar (B5: marker'sız,
# etkileşimsiz, timeout'suz dönmeli). Negatif-kapı = proje-çözümü (aşağıda).
#
# PROJE-ÇÖZÜMÜ (K4, fuzzy YASAK): cloudtop-repo origin/main compose-servis-listesinde
# container_name TAM-STRING eşleşmesi (case-sensitive, $-anchor). Kayıtsız/önek/case-farklı ad →
# abort rc=1 + ASCII-marker 'kayitsiz-proje'. iskan-registry ÜYELİK-kaydıdır, varlık-kapısı DEĞİL.
#
# İDEMPOTENT-APPLY: 2.+ koşu güvenli no-op (rc=0) — mevcut oturum/kayıt "atla/mevcut" raporlanır;
# rezerve-uuid'ler mevcut registry'den YENİDEN-KULLANILIR (asla yeniden üretilmez). Yan-fayda:
# host-restart sonrası koşu ölü tmux-oturumlarını AYNI rezerve-id'lerle tazeler.

# _ey_ssh <komut...> — timeout'lu batch-ssh (B5: hiçbir çağrı asılı kalamaz)
_ey_ssh() {
  timeout "${ISKAN_EY_SSH_TIMEOUT:-30}" ssh -o BatchMode=yes -o ConnectTimeout=5 "$EY_SSH_HOST" "$@"
}

# _ey_registry_sid <registry-içerik> <rol> — mevcut kayıttan rezerve session_id çözer (yoksa boş)
_ey_registry_sid() {
  python3 - "$2" <<PYEOF
import re, sys
rol = sys.argv[1]
icerik = """$1"""
cur = None
for ln in icerik.splitlines():
    m = re.match(r'\s*-\s*id:\s*(\S+)\s*$', ln)
    if m:
        cur = m.group(1)
        continue
    m = re.match(r'\s*session_id:\s*"?([0-9a-f-]{36})"?\s*$', ln)
    if m and cur == rol:
        print(m.group(1))
        break
PYEOF
}

# _ey_banner <proje> <rol> <gorev> <uuid> <pmode> — kimlik-banner içeriği (sözleşme-4:
# İSKÂN-imzası + rol + session-id + permission-mode; uuid AYRI ve ≤80-kolon tek-satırda)
_ey_banner() {
  local proje="$1" rol="$2" gorev="$3" uuid="$4" pmode="$5"
  cat <<EOF
================================================================
  İSKÂN kimlik-banner · proje: ${proje}
  rol: ${rol} · ekip-gorevi: ${gorev}
  permission-mode: ${pmode}
  rezerve session-id (kucuk-harf uuid, tek-satir):
  ${uuid}
  baslat: bash scripts/baslat-claude.sh ${rol}
================================================================
EOF
}

# _ey_iskan_registry_icerik — K2 TAM-şemalı iskan-registry.yaml içeriği üretir.
# Girdi: global EY_* değişkenleri + "rol<TAB>gorev<TAB>uuid" satırları (stdin).
_ey_iskan_registry_icerik() {
  cat <<EOF
# iskan-registry.yaml — İSKÂN K2 künye TEK-KAYNAĞI (FAZ-6'da doğdu; iskan.sh ekip-yerlestir yazar).
# Kanonik: cloudtop origin/main · host co-locate: /opt/cloudtop/infra/iskan-registry.yaml (bayt-eş) ·
# container-içi kopya: <repo_yolu>/iskan-registry.yaml (baslat-claude.sh okur, bayt-eş).
# SIR-DEĞERİ hiçbir alana yazılmaz (machine_identity_ref = yalnız AD/ref, bkz credentials.yaml).
proje: ${EY_PROJE}
container_adi: ${EY_CNAME}
hostname: ${EY_HOSTNAME}
port: ${EY_PORT}
config_dir: ${EY_HOST_CFG}
repo_yolu: ${EY_HEDEF_ICI}
ekip_registry_pointer: _agents/handoff/ekip-registry.yaml
cf_access_app: ${EY_HOSTNAME}
machine_identity_ref: null
uyeler:
EOF
  local rol gorev uuid
  while IFS=$'\t' read -r rol gorev uuid; do
    [ -n "$rol" ] || continue
    cat <<EOF
  - id: ${rol}
    tmux: "${rol}:0"
    cwd: ${EY_HEDEF_ICI}
    worktree_branch: null
    session_id: ${uuid}
    permission_mode: default
EOF
  done
}

# _ey_ekip_registry_icerik — scaffold ekip-registry.yaml roster-içeriği (ekip-notify.sh okur).
_ey_ekip_registry_icerik() {
  cat <<EOF
# ekip-registry.yaml — ${EY_PROJE} ekip koordinasyon TEK-KAYNAĞI (İSKÂN FAZ-6 ekip-yerlestir üretti).
# PARSE: ekip-notify.sh line-based okur → 'id:' ve 'tmux:' satırlarını bekler; düz-blok tut.
# ⚠️ tmux CASING KRİTİK: oturum-adları BÜYÜK/küçük-harf duyarlı — buradaki adlar tmux ls ile bayt-eş.
meta:
  ekip: "${EY_PROJE}-ekibi"
  uye_sayisi: ${EY_UYE_SAYISI}
  yonetici: ${EY_YONETICI}
  yayin_kanali: _agents/handoff/ekip-brief.md
  sinyal_defteri: _agents/handoff/ekip-sinyal.log
  tetik_scripti: scripts/ekip-notify.sh
  guncelleme: "$(date +%F)"

uyeler:
EOF
  local rol gorev uuid rol_kucuk
  while IFS=$'\t' read -r rol gorev uuid; do
    [ -n "$rol" ] || continue
    rol_kucuk="$(printf '%s' "$rol" | tr '[:upper:]' '[:lower:]')"
    cat <<EOF
  - id: ${rol}
    tmux: "${rol}:0"
    mod: kod
    rol: "İSKÂN FAZ-6 deneme-üyesi (${gorev})"
    kanallar: [ _agents/handoff/${rol_kucuk}-durum.md ]
    inbox: _agents/handoff/${rol_kucuk}-inbox.md
EOF
  done
}

# _ey_ad_hijyeni <ad> <marker> — ad ssh/docker/tmux komutlarına gömülür → dar-charset (injection-panzehiri).
# Büyük-harf BİLİNÇLİ geçirilir: 'ISKANTEST' charset'i geçer ama TAM-STRING eşleşmede düşer (K4-kanıt).
_ey_ad_hijyeni() {
  if ! printf '%s' "$1" | grep -qE '^[A-Za-z0-9-]+$'; then
    echo "[kırmızı] $2: '$1' — geçersiz ad-charset ([A-Za-z0-9-] dışı), hiçbir yere dokunulmadı" >&2
    return 1
  fi
}

# _ey_proje_cozumu <proje> — K4 proje-çözümü: cloudtop origin/main compose-servis-listesinde
# container_name TAM-STRING eşleşmesi (fuzzy/önek/case-farkı YASAK). Girdi: EY_REPO_DIR + EY_CNAME.
# Çıktı: EY_PORT set edilir; başarısızlıkta mesajı ('kayitsiz-proje' marker'ı dahil) kendisi basar, rc≠0.
_ey_proje_cozumu() {
  local proje="$1"
  # -e (dosya YA DA dizin): git-worktree'de .git bir gitdir-pointer DOSYASIDIR (firsthand-bulgu,
  # FAZ-7 canlı-koşu-1: -d kontrolü worktree'yi 'repo yok' sanıp düşürdü)
  if ! command -v git >/dev/null 2>&1 || [ ! -e "$EY_REPO_DIR/.git" ]; then
    echo "[kırmızı] cloudtop-repo bulunamadı: $EY_REPO_DIR — proje-çözümü yapılamaz, hiçbir yere dokunulmadı" >&2
    return 1
  fi
  git -C "$EY_REPO_DIR" fetch -q origin main 2>/dev/null || true   # offline'da son-fetch'lenmiş origin/main kullanılır
  local compose_main
  compose_main="$(git -C "$EY_REPO_DIR" show origin/main:infra/docker-compose.server.yml 2>/dev/null)"
  if [ -z "$compose_main" ]; then
    echo "[kırmızı] origin/main compose okunamadı ($EY_REPO_DIR) — proje-çözümü yapılamaz, hiçbir yere dokunulmadı" >&2
    return 1
  fi
  if ! printf '%s\n' "$compose_main" | grep -qE "container_name:[[:space:]]*${EY_CNAME}\$"; then
    echo "[kırmızı] kayitsiz-proje: '$proje' — compose-servis-listesinde (origin/main) '${EY_CNAME}' TAM-STRING eşleşmesi yok (K4: fuzzy/önek/case-farkı kabul edilmez), hiçbir yere dokunulmadı" >&2
    return 1
  fi
  EY_PORT="$(printf '%s\n' "$compose_main" | awk -v cn="$EY_CNAME" '
    /container_name:/ { if ($0 ~ cn"$") { found=1 } else { found=0 } }
    found && /127\.0\.0\.1:[0-9]+:8443/ { match($0, /127\.0\.0\.1:[0-9]+:8443/); s=substr($0, RSTART, RLENGTH); split(s, a, ":"); print a[2]; exit }
  ')"
  echo "[yeşil] proje-çözümü: '$proje' → ${EY_CNAME} (origin/main compose, TAM-STRING) · port=${EY_PORT:-?}"
  return 0
}

# _ey_on_kapilar <ssh_ok> — apply ön-kapıları: ssh + container-Up + araçlar (tmux/git/python3).
# rc≠0 = kırmızı (mesajı kendisi basar; sh -c = builtin-tuzağı panzehiri).
_ey_on_kapilar() {
  if [ "$1" != "1" ]; then
    echo "[kırmızı] $EY_SSH_HOST erişilemedi — hiçbir yere dokunulmadı" >&2
    return 1
  fi
  if [ "$(_ey_ssh "docker inspect -f '{{.State.Running}}' $EY_CNAME 2>/dev/null" 2>/dev/null)" != "true" ]; then
    echo "[kırmızı] $EY_CNAME çalışmıyor (docker inspect Running≠true) — hiçbir yere dokunulmadı" >&2
    return 1
  fi
  local arac eksik=""
  for arac in tmux git python3; do
    _ey_ssh "docker exec $EY_CNAME sh -c 'command -v $arac' >/dev/null 2>&1" || eksik="$eksik $arac"
  done
  if [ -n "$eksik" ]; then
    echo "[kırmızı] $EY_CNAME içinde eksik araç:${eksik} — araç-provizyonu gerekli (compose INSTALL_PACKAGES=tmux|git|python3 + servis-scoped recreate), hiçbir yere dokunulmadı" >&2
    return 1
  fi
  echo "[yeşil] ön-kapılar: ssh + container-Up + araçlar (tmux/git/python3) tamam"
}

# _ey_ekip_roster_oku <ekip-registry-içerik> — roster'ı "rol:gorev" çiftleri olarak basar
# (meta.yonetici eşleşen üye 'yonetici', diğerleri 'uye'). FAZ-7 roster-köprüsünün parser'ı.
# İçerik stdin'den akar (BİLİNÇLİ — heredoc'a """-gömme deseni, içerik '"' ile bitince
# Python-string'ini kırar; firsthand-bulgu, test-37 ilk-koşusu).
_ey_ekip_roster_oku() {
  printf '%s\n' "$1" | python3 -c '
import re, sys
yonetici = None
ids = []
in_uyeler = False
for ln in sys.stdin:
    if re.match(r"^uyeler:", ln):
        in_uyeler = True
        continue
    if not in_uyeler:
        m = re.match(r"\s*yonetici:\s*(\S+)", ln)
        if m:
            yonetici = m.group(1)
        continue
    m = re.match(r"\s*-\s*id:\s*(\S+)\s*$", ln)
    if m:
        ids.append(m.group(1))
out = []
for i in ids:
    out.append(i + (":yonetici" if i == yonetici else ":uye"))
print(" ".join(out))
'
}

# _ey_uye_satirlari <roster> <reg_mevcut> — roster'ı "rol\tgorev\tuuid\tkaynak" satırlarına açar;
# uuid mevcut-kayıttan YENİDEN-KULLANILIR (asla yeniden-üretilmez), yoksa uuid4 üretilir (küçük-harf).
# Yan-etki (bilinçli — subshell'de yan-etki kaybolur): EY_UYE_SATIRLARI + EY_YONETICI + EY_UYE_SAYISI.
_ey_uye_satirlari() {
  local roster="$1" reg_mevcut="$2" girdi rol gorev sid kaynak
  EY_YONETICI=""; EY_UYE_SAYISI=0; EY_UYE_SATIRLARI=""
  for girdi in $roster; do
    rol="${girdi%%:*}"; gorev="${girdi#*:}"
    [ "$gorev" = "$girdi" ] && gorev="uye"
    [ "$gorev" = "yonetici" ] && [ -z "$EY_YONETICI" ] && EY_YONETICI="$rol"
    EY_UYE_SAYISI=$((EY_UYE_SAYISI + 1))
    sid=""; kaynak="yeni"
    if [ -n "$reg_mevcut" ]; then
      sid="$(_ey_registry_sid "$reg_mevcut" "$rol")"
      [ -n "$sid" ] && kaynak="mevcut"
    fi
    if [ -z "$sid" ]; then
      sid="$(python3 -c 'import uuid; print(uuid.uuid4())')"   # uuid4 = küçük-harf (G6/G7 sözleşmesi)
    fi
    EY_UYE_SATIRLARI="${EY_UYE_SATIRLARI}${rol}	${gorev}	${sid}	${kaynak}
"
  done
  [ -n "$EY_YONETICI" ] || EY_YONETICI="${roster%%:*}"
}

# _ey_pane_ac <rol> <gorev> <sid> — kimlik-banner dosyası (yoksa yaz) + tmux-oturumu (yoksa aç).
# Girdi: EY_PROJE/EY_CNAME/EY_HEDEF_ICI/EY_HOST_PROJ. EY_PANE_SONUC=acildi|mevcut set eder; rc≠0=hata.
# ⚠️ SHELL=/bin/bash ŞART (canlı-vaka, FAZ-6 koşu-1/2): tmux pane-komutunu default-shell'le koşar;
# abc'nin passwd-shell'i /bin/false → SHELL-override'sız pane anında ölür, son-oturumla birlikte
# tmux-server de kapanır ("no server running"). SHELL env'i default-shell'i ezer.
_ey_pane_ac() {
  local rol="$1" gorev="$2" sid="$3"
  EY_PANE_SONUC=""
  # banner-dosyası (uuid mevcut-kayıttan geldiği için içerik deterministik; yoksa yaz)
  if ! _ey_ssh "test -f '$EY_HOST_PROJ/_iskan/banner-$rol.txt'" 2>/dev/null; then
    if ! _ey_banner "$EY_PROJE" "$rol" "$gorev" "$sid" "default" | _ey_ssh "mkdir -p '$EY_HOST_PROJ/_iskan' && cat > '$EY_HOST_PROJ/_iskan/banner-$rol.txt' && chown -R 1000:1000 '$EY_HOST_PROJ/_iskan'"; then
      echo "[kırmızı] banner yazımı başarısız: $rol" >&2
      return 1
    fi
  fi
  # tmux-oturumu (soket /tmp/tmux-1000; TERM detached-new-session için sabitlenir)
  if _ey_ssh "docker exec -u 1000 $EY_CNAME tmux has-session -t $rol 2>/dev/null"; then
    EY_PANE_SONUC="mevcut"
    return 0
  fi
  if ! _ey_ssh "docker exec -u 1000 -e TERM=xterm-256color -e HOME=/config -e SHELL=/bin/bash $EY_CNAME tmux new-session -d -s $rol -c $EY_HEDEF_ICI"; then
    echo "[kırmızı] tmux new-session başarısız: $rol" >&2
    return 1
  fi
  _ey_ssh "docker exec -u 1000 -e TERM=xterm-256color -e HOME=/config -e SHELL=/bin/bash $EY_CNAME tmux send-keys -t $rol 'clear; cat _iskan/banner-$rol.txt' Enter" || \
    echo "[doğrulanmadı] banner send-keys başarısız ($rol) — oturum açık, banner elle: cat _iskan/banner-$rol.txt"
  EY_PANE_SONUC="acildi"
}

# _ey_registry_dagit <reg_yeni> <reg_mevcut_host> — iskan-registry K2 içeriğini ÜÇ kopyaya bayt-eş
# dağıtır: host co-locate (EY_HOST_REGISTRY) + repo working-tree (EY_REPO_DIR/infra, commit/PR ayrı-adım)
# + container-içi (EY_HOST_PROJ, baslat-claude.sh kaynağı). Her kopya md5-karşılaştırmalı idempotent.
_ey_registry_dagit() {
  local reg_yeni="$1" reg_mevcut="$2"
  local md5_yeni; md5_yeni="$(printf '%s\n' "$reg_yeni" | md5sum | cut -d' ' -f1)"
  if [ "$(printf '%s\n' "$reg_mevcut" | md5sum | cut -d' ' -f1)" = "$md5_yeni" ]; then
    echo "[yeşil] iskan-registry (host): içerik-eş, mevcut → atla"
  else
    if ! printf '%s\n' "$reg_yeni" | _ey_ssh "mkdir -p '$(dirname "$EY_HOST_REGISTRY")' && cat > '$EY_HOST_REGISTRY'"; then
      echo "[kırmızı] iskan-registry host-yazımı başarısız: $EY_HOST_REGISTRY" >&2
      return 1
    fi
    echo "[yeşil] iskan-registry (host): yazıldı → $EY_HOST_REGISTRY"
  fi
  # repo-kopyası (co-locate; PR bu dosyadan açılır — apply repo'ya YALNIZ bu dosyayı yazar)
  if [ -w "$EY_REPO_DIR/infra" ] || [ -w "$EY_REPO_DIR" ]; then
    if [ -f "$EY_REPO_DIR/infra/iskan-registry.yaml" ] && \
       [ "$(md5sum "$EY_REPO_DIR/infra/iskan-registry.yaml" | cut -d' ' -f1)" = "$md5_yeni" ]; then
      echo "[yeşil] iskan-registry (repo): içerik-eş, mevcut → atla"
    else
      printf '%s\n' "$reg_yeni" > "$EY_REPO_DIR/infra/iskan-registry.yaml"
      echo "[yeşil] iskan-registry (repo): yazıldı → $EY_REPO_DIR/infra/iskan-registry.yaml (commit/PR ayrı-adım, REPO-FIRST)"
    fi
  else
    echo "[doğrulanmadı] iskan-registry (repo): $EY_REPO_DIR yazılabilir değil — repo-kopyası atlandı (host+container kopyaları yazıldı)"
  fi
  # container-içi kopya (baslat-claude.sh okur)
  if _ey_ssh "test -f '$EY_HOST_PROJ/iskan-registry.yaml'" 2>/dev/null && \
     [ "$(_ey_ssh "md5sum '$EY_HOST_PROJ/iskan-registry.yaml'" 2>/dev/null | cut -d' ' -f1)" = "$md5_yeni" ]; then
    echo "[yeşil] iskan-registry (container-içi): içerik-eş, mevcut → atla"
  else
    if ! printf '%s\n' "$reg_yeni" | _ey_ssh "cat > '$EY_HOST_PROJ/iskan-registry.yaml' && chown 1000:1000 '$EY_HOST_PROJ/iskan-registry.yaml'"; then
      echo "[kırmızı] iskan-registry container-içi kopya yazımı başarısız" >&2
      return 1
    fi
    echo "[yeşil] iskan-registry (container-içi): yazıldı (baslat-claude.sh kaynağı)"
  fi
}

cmd_ekip_yerlestir() {
  local proje="" mode=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --apply) mode="apply"; shift ;;
      -*) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
      *) proje="$1"; shift ;;
    esac
  done
  if [ -z "$proje" ] || [ -z "$mode" ]; then
    echo "kullanım: iskan.sh ekip-yerlestir <proje> --dry-run|--apply" >&2
    exit 2
  fi
  _ey_ad_hijyeni "$proje" "kayitsiz-proje" || exit 1

  EY_REPO_DIR="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
  EY_SSH_HOST="${ISKAN_SSH_HOST:-hostsrv}"
  EY_PROJE="$proje"
  EY_CNAME="cloudtop-${proje}"
  EY_HOSTNAME="${proje}.mmepanel.com"
  EY_HOST_CFG="/opt/cloudtop/config-${proje}"
  EY_HEDEF_ICI="${ISKAN_EY_HEDEF_DIR:-/config/projects/${proje}}"
  EY_HOST_PROJ="${EY_HOST_CFG}/projects/${proje}"
  EY_HOST_REGISTRY="${ISKAN_HOST_REGISTRY:-/opt/cloudtop/infra/iskan-registry.yaml}"
  local ekipkur_dir="${ISKAN_EKIPKUR_DIR:-$SCRIPT_DIR/../../ekip-kur}"
  local tmpl_baslat="$SCRIPT_DIR/../templates/baslat-claude.sh"

  # ── PROJE-ÇÖZÜMÜ (K4: TAM-STRING, origin/main authoritative; fetch best-effort) ──────────
  _ey_proje_cozumu "$proje" || exit 1

  # ── mevcut-durum okuması (dry-run: best-effort teşhis · apply: idempotency-temeli) ────────
  local ssh_ok=0 reg_mevcut="" scaffold_var="" tmux_canli="" ekip_reg=""
  if command -v ssh >/dev/null 2>&1 && _ey_ssh true >/dev/null 2>&1; then
    ssh_ok=1
    reg_mevcut="$(_ey_ssh "cat '$EY_HOST_REGISTRY' 2>/dev/null" 2>/dev/null || true)"
    scaffold_var="$(_ey_ssh "test -f '$EY_HOST_PROJ/scripts/ekip-notify.sh' && echo VAR" 2>/dev/null || true)"
    tmux_canli="$(_ey_ssh "docker exec -u 1000 $EY_CNAME tmux list-sessions -F '#{session_name}' 2>/dev/null" 2>/dev/null || true)"
    ekip_reg="$(_ey_ssh "cat '$EY_HOST_PROJ/_agents/handoff/ekip-registry.yaml' 2>/dev/null" 2>/dev/null || true)"
  fi
  # rezerve-uuid çözümü: host-registry ÖNCE (canlı-kaynak), yoksa repo-origin/main (merge-sonrası kaynak)
  if [ -z "$reg_mevcut" ]; then
    reg_mevcut="$(git -C "$EY_REPO_DIR" show origin/main:infra/iskan-registry.yaml 2>/dev/null || true)"
  fi

  # ── ROSTER-KAYNAĞI (FAZ-7 roster-köprüsü): ISKAN_EY_ROSTER (açık-override) → container-içi
  # ekip-registry.yaml → FAZ-6 SABİT default. Köprüsüz hâl G5-vakasıydı: hardcoded 2-üye default,
  # uye-ekle'yle doğan 3. üyeyi registry'nin üç kopyasından da SİLERDİ (md5-farklı → üzerine-yaz).
  local roster=""
  if [ -n "${ISKAN_EY_ROSTER:-}" ]; then
    roster="$ISKAN_EY_ROSTER"
    echo "[yeşil] roster-kaynağı: ISKAN_EY_ROSTER (açık-override)"
  elif [ -n "$ekip_reg" ]; then
    roster="$(_ey_ekip_roster_oku "$ekip_reg")"
    [ -n "$roster" ] && echo "[yeşil] roster-kaynağı: container-içi ekip-registry.yaml ($(printf '%s\n' "$roster" | wc -w | tr -d ' ') üye)"
  fi
  if [ -z "$roster" ]; then
    # SABİT FAZ-6 deneme-roster'ı (camelCase BİLİNÇLİ — ASCII, Türkçe-İ casing-tuzağı yok)
    roster="denekAlfa:yonetici denekBeta:uye"
    echo "[yeşil] roster-kaynağı: FAZ-6 SABİT default (ekip-registry henüz yok/erişilemedi)"
  fi

  # roster satırları: "rol<TAB>gorev<TAB>uuid<TAB>kaynak" (uuid: mevcut-kayıttan YENİDEN-KULLAN, yoksa üret)
  _ey_uye_satirlari "$roster" "$reg_mevcut"
  local rol gorev sid kaynak

  # ── DRY-RUN: tam-önizleme, SIFIR-yazım (plan-exit=3) ─────────────────────────────────────
  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN ekip-yerlestir — KURU-KOŞU (DEFAULT; host'a/container'a/dosyaya SIFIR-dokunuş) =="
    echo "proje: $proje · container: $EY_CNAME · hedef-dizin (container-içi): $EY_HEDEF_ICI"
    if [ "$ssh_ok" = "1" ]; then
      echo "[yeşil] hostsrv-probe: taze ssh exit=0 (canlı-durum aşağıda 'mevcut → atla' olarak işaretlendi)"
    else
      echo "[doğrulanmadı] hostsrv erişilemedi — canlı-durum probu yapılamadı; adımlar 'yeni' varsayımıyla önizlendi"
    fi
    echo ""
    echo "-- PLAN (apply'da sırayla; her adım idempotent) --"
    if [ -n "$scaffold_var" ]; then
      echo "  1. scaffold-iskelet (ekip-kur/scaffold.sh headless → $EY_HOST_PROJ): (mevcut → atla)"
    else
      echo "  1. scaffold-iskelet (ekip-kur/scaffold.sh headless → $EY_HOST_PROJ) + ekip-ac geçici-kopya + git init + uid-1000 sahiplik"
    fi
    echo "  2. roster (SABİT, GEREKLILIK-bağlayıcı; tmux-oturum adları BİREBİR bu casing):"
    local kaynak_eki durum_eki
    while IFS=$'\t' read -r rol gorev sid kaynak; do
      [ -n "$rol" ] || continue
      kaynak_eki="rezerv-uuid: $kaynak"
      if printf '%s\n' "$tmux_canli" | grep -qx "$rol"; then durum_eki="tmux: mevcut → atla"; else durum_eki="tmux: yeni-oturum açılacak"; fi
      echo "     - ${rol} (${gorev}) · ${kaynak_eki} (${sid}) · ${durum_eki}"
    done <<< "$EY_UYE_SATIRLARI"
    echo "  3. kimlik-banner (her pane'de kalıcı: İSKÂN-imzası + rol + rezerve-uuid ≤80-kolon-tek-satır + permission-mode)"
    echo "  4. baslat-claude.sh sarmalayıcısı (b0019 panzehiri: registry'den rol-kaydı çözer; claude yoksa dürüst-kırmızı 'claude-binary yok')"
    echo "  5. iskan-registry.yaml K2 tam-şema yazımı: host-co-locate ($EY_HOST_REGISTRY) + repo ($EY_REPO_DIR/infra/) + container-içi kopya — üçü bayt-eş"
    echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  # ── APPLY (GO'suz — FAZ-6 sözleşmesi; idempotent; her adım value-safe log) ────────────────
  echo "== İSKÂN ekip-yerlestir — APPLY (hedef-container-içi; idempotent; diğer container'lara dokunmaz) =="

  _ey_on_kapilar "$ssh_ok" || exit 1

  # ── ADIM-1: scaffold-iskelet (yoksa kur; varsa atla) ─────────────────────────────────────
  if [ -n "$scaffold_var" ]; then
    echo "[yeşil] ADIM-1 scaffold: mevcut → atla ($EY_HOST_PROJ/scripts/ekip-notify.sh var)"
  else
    [ -f "$ekipkur_dir/scaffold.sh" ] || { echo "[kırmızı] ekip-kur/scaffold.sh bulunamadı: $ekipkur_dir — hiçbir yere dokunulmadı" >&2; exit 1; }
    local staging; staging="$(mktemp -d)"
    if ! bash "$ekipkur_dir/scaffold.sh" "$staging" >/dev/null 2>&1; then
      rm -rf "$staging"
      echo "[kırmızı] scaffold.sh staging-koşusu başarısız — host'a dokunulmadı" >&2
      exit 1
    fi
    # ekip-ac geçici şablon-kopya (scaffold put-listesinde yok — kalıcı-fix ekip-kur bölgesinde, SERDAR'a emit)
    if [ -f "$ekipkur_dir/templates/ekip-ac.sh" ]; then
      cp "$ekipkur_dir/templates/ekip-ac.sh" "$staging/scripts/ekip-ac.sh"
      chmod +x "$staging/scripts/ekip-ac.sh"
    fi
    # gerçek-roster'lı ekip-registry (şablon-örnek UYE1/UYE2'nin yerine)
    _ey_ekip_registry_icerik < <(printf '%s' "$EY_UYE_SATIRLARI" | cut -f1-3) > "$staging/_agents/handoff/ekip-registry.yaml"
    if ! tar -C "$staging" -cf - . | _ey_ssh "mkdir -p '$EY_HOST_PROJ' && tar -C '$EY_HOST_PROJ' -xf - && chown -R 1000:1000 '$EY_HOST_CFG/projects'"; then
      rm -rf "$staging"
      echo "[kırmızı] scaffold host-taşıması başarısız (tar-pipe) — kısmi-yazım olabilir, incele + yeniden-koş (idempotent)" >&2
      exit 1
    fi
    rm -rf "$staging"
    echo "[yeşil] ADIM-1 scaffold: iskelet + ekip-ac + roster'lı ekip-registry $EY_HOST_PROJ'a kuruldu (uid-1000)"
  fi

  # ── ADIM-2: baslat-claude.sh sarmalayıcısı (dosya-bazlı idempotent) ──────────────────────
  if _ey_ssh "test -f '$EY_HOST_PROJ/scripts/baslat-claude.sh'" 2>/dev/null; then
    echo "[yeşil] ADIM-2 baslat-claude.sh: mevcut → atla"
  else
    [ -f "$tmpl_baslat" ] || { echo "[kırmızı] şablon yok: $tmpl_baslat" >&2; exit 1; }
    if ! _ey_ssh "cat > '$EY_HOST_PROJ/scripts/baslat-claude.sh' && chmod +x '$EY_HOST_PROJ/scripts/baslat-claude.sh' && chown 1000:1000 '$EY_HOST_PROJ/scripts/baslat-claude.sh'" < "$tmpl_baslat"; then
      echo "[kırmızı] baslat-claude.sh yazımı başarısız" >&2
      exit 1
    fi
    echo "[yeşil] ADIM-2 baslat-claude.sh: yazıldı (b0019 panzehiri — tek meşru başlatma-yolu)"
  fi

  # ── ADIM-3: git init (ekip-notify REPO_ROOT çözümü; container-içi, uid-1000) ─────────────
  if ! _ey_ssh "docker exec -u 1000 $EY_CNAME bash -c 'cd $EY_HEDEF_ICI && { [ -d .git ] && echo mevcut || git init -q; }'"; then
    echo "[kırmızı] git init başarısız ($EY_CNAME:$EY_HEDEF_ICI)" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-3 git init: tamam (mevcut ise atlandı)"

  # ── ADIM-4: iskan-registry.yaml K2 tam-şema — host + repo + container-içi ÜÇÜ BAYT-EŞ ────
  local reg_yeni; reg_yeni="$(_ey_iskan_registry_icerik < <(printf '%s' "$EY_UYE_SATIRLARI" | cut -f1-3))"
  _ey_registry_dagit "$reg_yeni" "$reg_mevcut" || exit 1

  # ── ADIM-5: kimlik-banner dosyaları + tmux-oturumları (üye-bazlı idempotent) ─────────────
  # ⚠️ fd-3 döngüsü ŞART (canlı-vaka, koşu-1): döngü-içi ssh-çağrıları stdin'i YER — here-string
  # stdin'den beslenirse 2. üyenin satırı ssh tarafından tüketilir, döngü tek-üyede biter.
  local acilan=0 atlanan=0
  while IFS=$'\t' read -r -u 3 rol gorev sid kaynak; do
    [ -n "$rol" ] || continue
    _ey_pane_ac "$rol" "$gorev" "$sid" || exit 1
    if [ "$EY_PANE_SONUC" = "mevcut" ]; then
      echo "[yeşil] ADIM-5 $rol: tmux-oturumu mevcut → atla (rezerve-uuid korunur: $sid)"
      atlanan=$((atlanan + 1))
    else
      echo "[yeşil] ADIM-5 $rol: tmux-oturumu AÇILDI ($gorev, rezerve-uuid: $sid, cwd=$EY_HEDEF_ICI)"
      acilan=$((acilan + 1))
    fi
  done 3<<< "$EY_UYE_SATIRLARI"

  echo ""
  echo "== ekip-yerlestir bitti: $proje · açılan=$acilan atlanan-mevcut=$atlanan · registry 3-kopya bayt-eş (host+repo+container-içi) =="
  echo "   (repo-kopyası commit/PR AYRI adımdır — REPO-FIRST; G6/G7 origin/main'den okur)"
  exit 0
}

# ── uye-ekle (FAZ-7: UC3 tek-üye iskânı) ────────────────────────────────────────────────
#
# NEDEN: FAZ-7 = FAZ-6 ekip-yerleştirme-mekaniğinin (rezerve-uuid + tmux + banner + sarmalayıcı)
# TEK-ÜYE operasyonuna indirgenmesi — filo-çağında "takıma adam ekle"nin standart yolu. FAZ-6
# fonksiyonları REUSE edilir (_ey_proje_cozumu / _ey_pane_ac / _ey_registry_dagit / _ey_banner),
# kopyalanmaz.
#
# HEDEF-SINIF AYRIMI (İ1, mahremiyet-duvarı):
#  (a) izole/İSKÂN-hedef → hafif-kimlik-üreteci yolu (KÂHYA/ise-alim ÇAĞRILMAZ); dry-run çıktısı
#      HER koşulda 'sultan-bildirim' satırı basar (idempotent/mevcut→atla önizlemesi DAHİL).
#  (b) Nexus-ailesi evi (cloudtop-code, TAM-STRING) → CANLI-invoke YOK: dürüst-yönlendirme
#      ('ise-alim' marker'ı) + rc≠0. İSKÂN'ın Nexus-katkısı yalnız _ue_kahya_adaptor'dur.
#
# ÇAKIŞMA-KORUMASI: var-olan üye tekrar eklenemez → rc≠0 + 'uye-zaten-var' (rezerv-id çakışması /
# çift-kimlik felaket-sınıfı). Bu yüzden apply BİLİNÇLİ idempotent-DEĞİL — dry-run her durumda rc=3.
#
# GO-KAPISI YOK (bilinçli): FAZ-7 GO'suz fazdır — Sultan blanket-GO 2026-07-16 ("İSKÂN'ı bitir
# FAZ-5→9"); hedef-container-İÇİ iştir, host-compose'a/CF'e/diğer container'lara dokunmaz.

# _ue_kahya_adaptor <kahya_json_dosyasi> <session_id> — KÂHYA-şeması (agent-registry.json ajan-kaydı:
# id/workdir/persona/…) → iskan-registry K2 üye-bloğu dönüşümü. İSKÂN'ın Nexus-hedefe TEK katkısı
# budur (İ1: canlı KÂHYA-invoke YOK; birim-test fixture'lı, bkz iskan.test.sh).
_ue_kahya_adaptor() {
  local json_dosya="$1" sid="$2"
  python3 - "$json_dosya" "$sid" <<'PYEOF'
import json, sys
kayit = json.load(open(sys.argv[1], encoding="utf-8"))
sid = sys.argv[2]
aid = kayit["id"]
cwd = kayit.get("workdir") or "null"
print(f"""  - id: {aid}
    tmux: "{aid}:0"
    cwd: {cwd}
    worktree_branch: null
    session_id: {sid}
    permission_mode: {kayit.get('permission_mode', 'default')}""")
PYEOF
}

# _ue_agentmd_icerik <uye> <gorev> — hafif-kimlik-dosyası içeriği (mihenk Katman-2 deseni:
# rol-adı + görev-çerçevesi + ekip-bağlamı). Girdi: EY_PROJE/EY_CNAME/EY_YONETICI globals.
_ue_agentmd_icerik() {
  local uye="$1" gorev="$2"
  local uye_kucuk; uye_kucuk="$(printf '%s' "$uye" | tr '[:upper:]' '[:lower:]')"
  cat <<EOF
# ${uye} — ${EY_PROJE} ekip-üyesi (İSKÂN hafif-kimlik)

> Üretici: İSKÂN uye-ekle (FAZ-7 hafif-kimlik-üreteci). KÂHYA/ise-alim izole-hedefte ÇAĞRILMAZ (İ1
> mahremiyet-duvarı) — kimliğin bu dosya + iskan-registry kaydıdır.

## Kimlik
- rol-adı: ${uye} · görev: ${gorev} · proje: ${EY_PROJE} (container: ${EY_CNAME})
- rezerve session-id kaydı: iskan-registry.yaml (repo-kökünde; baslat-claude.sh okur — sid'siz başlatma YASAK)
- başlatma: \`bash scripts/baslat-claude.sh ${uye}\`

## Görev-çerçevesi
- ${EY_PROJE} ekibinin '${gorev}' üyesisin; yönetici: ${EY_YONETICI}.
- Koordinasyon: _agents/handoff/ekip-brief.md (yayın) · _agents/handoff/${uye_kucuk}-durum.md (durum) ·
  scripts/ekip-notify.sh (tetik).

## Ekip-bağlamı
- roster tek-kaynağı: _agents/handoff/ekip-registry.yaml (tmux-adları BÜYÜK/küçük-harf duyarlı, bayt-eş).
- Nexus-ailesi merkez-kimlikleri bu projede GEÇERSİZ (İ1) — başka rol/kimlik devralma.
EOF
}

cmd_uye_ekle() {
  local proje="" uye="" gorev="uye" mode=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --apply) mode="apply"; shift ;;
      --gorev) gorev="${2:-uye}"; shift 2 ;;
      -*) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
      *) if [ -z "$proje" ]; then proje="$1"; elif [ -z "$uye" ]; then uye="$1"; else echo "fazla argüman: $1" >&2; exit 2; fi; shift ;;
    esac
  done
  if [ -z "$proje" ] || [ -z "$uye" ] || [ -z "$mode" ]; then
    echo "kullanım: iskan.sh uye-ekle <proje> <uye> [--gorev <görev>] --dry-run|--apply" >&2
    exit 2
  fi
  _ey_ad_hijyeni "$proje" "kayitsiz-proje" || exit 1
  _ey_ad_hijyeni "$uye" "gecersiz-uye-adi" || exit 1

  # ── HEDEF-SINIF AYRIMI (İ1): Nexus-ailesi evi (cloudtop-code) → CANLI-invoke YOK ─────────
  if [ "$proje" = "cloudtop-code" ] || [ "cloudtop-${proje}" = "cloudtop-code" ]; then
    echo "[kırmızı] Nexus-ailesi evi hedeflendi ('$proje' → cloudtop-code): İSKÂN burada üye AÇMAZ — Nexus-ailesi üyesi /ise-alim (KÂHYA, Sultan-eşli röportaj+onay) ile alınır. İSKÂN'ın Nexus-katkısı yalnız KÂHYA-şema→registry-satırı adaptörüdür (_ue_kahya_adaptor, birim-test fixture'lı). Hiçbir yere dokunulmadı." >&2
    exit 1
  fi

  EY_REPO_DIR="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
  EY_SSH_HOST="${ISKAN_SSH_HOST:-hostsrv}"
  EY_PROJE="$proje"
  EY_CNAME="cloudtop-${proje}"
  EY_HOSTNAME="${proje}.mmepanel.com"
  EY_HOST_CFG="/opt/cloudtop/config-${proje}"
  EY_HEDEF_ICI="${ISKAN_EY_HEDEF_DIR:-/config/projects/${proje}}"
  EY_HOST_PROJ="${EY_HOST_CFG}/projects/${proje}"
  EY_HOST_REGISTRY="${ISKAN_HOST_REGISTRY:-/opt/cloudtop/infra/iskan-registry.yaml}"

  # ── PROJE-ÇÖZÜMÜ (K4: TAM-STRING; 'kayitsiz-proje' marker'ı helper'da) ───────────────────
  _ey_proje_cozumu "$proje" || exit 1

  # ── mevcut-durum (best-effort): ekip-registry roster + iskan-registry + tmux ──────────────
  local ssh_ok=0 ekip_reg="" reg_mevcut="" tmux_canli=""
  if command -v ssh >/dev/null 2>&1 && _ey_ssh true >/dev/null 2>&1; then
    ssh_ok=1
    ekip_reg="$(_ey_ssh "cat '$EY_HOST_PROJ/_agents/handoff/ekip-registry.yaml' 2>/dev/null" 2>/dev/null || true)"
    reg_mevcut="$(_ey_ssh "cat '$EY_HOST_REGISTRY' 2>/dev/null" 2>/dev/null || true)"
    tmux_canli="$(_ey_ssh "docker exec -u 1000 $EY_CNAME tmux list-sessions -F '#{session_name}' 2>/dev/null" 2>/dev/null || true)"
  fi
  [ -n "$reg_mevcut" ] || reg_mevcut="$(git -C "$EY_REPO_DIR" show origin/main:infra/iskan-registry.yaml 2>/dev/null || true)"

  # roster (mevcut): ekip-registry (birincil) → iskan-registry uyeler (fallback, görev bilinmez → uye)
  local roster_mevcut=""
  [ -n "$ekip_reg" ] && roster_mevcut="$(_ey_ekip_roster_oku "$ekip_reg")"
  if [ -z "$roster_mevcut" ] && [ -n "$reg_mevcut" ]; then
    roster_mevcut="$(printf '%s\n' "$reg_mevcut" | awk '/^uyeler:/{f=1} f && /- id:/{printf "%s:uye ", $NF}')"
  fi

  # çakışma-tespiti (rezerv-id çakışması / çift-kimlik felaket-sınıfı)
  local uye_mevcut=0 m
  for m in $roster_mevcut; do
    [ "${m%%:*}" = "$uye" ] && uye_mevcut=1
  done

  # rezerve-uuid önizlemesi (mevcut kayıttan yeniden-kullanım; apply'da da aynı kaynak)
  local sid kaynak="yeni"
  sid="$(_ey_registry_sid "$reg_mevcut" "$uye")"
  [ -n "$sid" ] && kaynak="mevcut"

  # ── DRY-RUN: tam-önizleme, SIFIR-yazım (plan-exit=3 HER durumda) ──────────────────────────
  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN uye-ekle — KURU-KOŞU (DEFAULT; host'a/container'a/dosyaya SIFIR-dokunuş) =="
    echo "proje: $proje · container: $EY_CNAME · yeni-üye: $uye ($gorev) · hedef-dizin: $EY_HEDEF_ICI"
    # İ1 sözleşmesi: izole-hedef dry-run HER koşulda (idempotent/mevcut→atla önizlemesi DAHİL)
    # 'sultan-bildirim' satırı basar — üye-iskânı Sultan'dan gizli olamaz.
    echo "[sultan-bildirim] izole-hedef üye-iskânı: '$uye' → $proje — Sultan'a bildirilir (İ1: KÂHYA/ise-alim izole-hedefte ÇAĞRILMAZ; kimlik İSKÂN hafif-üretecinden)"
    if [ "$ssh_ok" = "1" ]; then
      echo "[yeşil] hostsrv-probe: taze ssh exit=0 (canlı-durum aşağıda işaretlendi)"
    else
      echo "[doğrulanmadı] hostsrv erişilemedi — canlı-durum probu yapılamadı; adımlar 'yeni' varsayımıyla önizlendi"
    fi
    echo ""
    echo "-- PLAN (apply'da sırayla) --"
    if [ "$uye_mevcut" = "1" ]; then
      echo "  ⚠ '$uye' ZATEN roster'da (mevcut → atla önizlemesi) — apply bu durumda rc≠0 + 'uye-zaten-var' basar (çakışma-koruması: rezerv-id çakışması/çift-kimlik felaket-sınıfı)"
    else
      local sid_eki
      if [ "$kaynak" = "mevcut" ]; then sid_eki="rezerv-uuid: mevcut ($sid)"; else sid_eki="rezerv-uuid: yeni (apply-anında uuid4, küçük-harf)"; fi
      local tmux_eki="tmux: yeni-oturum açılacak"
      printf '%s\n' "$tmux_canli" | grep -qx "$uye" && tmux_eki="tmux: mevcut → atla"
      echo "  1. hafif-kimlik-dosyası: $EY_HEDEF_ICI/_agents/$uye/AGENT.md (İSKÂN-üreteci; KÂHYA çağrılmaz)"
      echo "  2. ekip-registry.yaml roster-append: $uye ($gorev) + uye_sayisi güncelle (container-içi tek-kaynak)"
      echo "  3. kimlik-banner + tmux-oturumu: $uye · $sid_eki · $tmux_eki"
      echo "  4. iskan-registry.yaml K2 yeniden-üretim (tüm-roster): host-co-locate + repo + container-içi — üçü bayt-eş"
    fi
    echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  # ── APPLY (GO'suz — FAZ-7 sözleşmesi; hedef-container-içi; diğer container'lara dokunmaz) ─
  echo "== İSKÂN uye-ekle — APPLY (tek-üye iskânı: $uye → $proje) =="

  if [ "$uye_mevcut" = "1" ]; then
    echo "[kırmızı] uye-zaten-var: '$uye' roster'da kayıtlı (rezerv-id çakışması/çift-kimlik felaket-sınıfı) — hiçbir yere dokunulmadı" >&2
    exit 1
  fi

  _ey_on_kapilar "$ssh_ok" || exit 1

  if [ -z "$ekip_reg" ]; then
    echo "[kırmızı] ekip-registry.yaml okunamadı ($EY_HOST_PROJ/_agents/handoff/) — önce 'iskan.sh ekip-yerlestir $proje --apply' koşulmalı (uye-ekle mevcut-ekibe ekler), hiçbir yere dokunulmadı" >&2
    exit 1
  fi

  # tam-roster (mevcut + yeni-üye) → satırlar (uuid'ler mevcut-kayıttan YENİDEN-KULLANILIR)
  _ey_uye_satirlari "$roster_mevcut $uye:$gorev" "$reg_mevcut"
  [ -n "$sid" ] || sid="$(printf '%s' "$EY_UYE_SATIRLARI" | awk -F'\t' -v u="$uye" '$1==u{print $3}')"

  # ── ADIM-1: hafif-kimlik-dosyası (İ1: KÂHYA/ise-alim ÇAĞRILMAZ; dosya-bazlı idempotent) ──
  if _ey_ssh "test -f '$EY_HOST_PROJ/_agents/$uye/AGENT.md'" 2>/dev/null; then
    echo "[yeşil] ADIM-1 hafif-kimlik: mevcut → atla ($EY_HEDEF_ICI/_agents/$uye/AGENT.md var)"
  else
    if ! _ue_agentmd_icerik "$uye" "$gorev" | _ey_ssh "mkdir -p '$EY_HOST_PROJ/_agents/$uye' && cat > '$EY_HOST_PROJ/_agents/$uye/AGENT.md' && chown -R 1000:1000 '$EY_HOST_PROJ/_agents/$uye'"; then
      echo "[kırmızı] hafif-kimlik-dosyası yazımı başarısız: $uye" >&2
      exit 1
    fi
    echo "[yeşil] ADIM-1 hafif-kimlik: yazıldı → $EY_HEDEF_ICI/_agents/$uye/AGENT.md (İSKÂN-üreteci)"
  fi

  # ── ADIM-2: ekip-registry roster-append (üye-bloğu + uye_sayisi + guncelleme) ─────────────
  # içerik env-değişkenle akar (BİLİNÇLİ — heredoc'a """-gömme deseni, içerik '"' içerince/bitince
  # Python-string'ini kırabilir; firsthand-bulgu, roster-parser test-37 ilk-koşusu)
  local ekip_reg_yeni
  ekip_reg_yeni="$(EKIP_REG_ICERIK="$ekip_reg" python3 - "$uye" "$gorev" "$(date +%F)" <<'PYEOF'
import os, re, sys
uye, gorev, bugun = sys.argv[1], sys.argv[2], sys.argv[3]
icerik = os.environ["EKIP_REG_ICERIK"]
out = []
for ln in icerik.splitlines():
    m = re.match(r'(\s*uye_sayisi:\s*)(\d+)\s*$', ln)
    if m:
        out.append(f"{m.group(1)}{int(m.group(2)) + 1}")
        continue
    m = re.match(r'(\s*guncelleme:\s*).*$', ln)
    if m:
        out.append(f'{m.group(1)}"{bugun}"')
        continue
    out.append(ln)
blok = f"""  - id: {uye}
    tmux: "{uye}:0"
    mod: kod
    rol: "İSKÂN FAZ-7 tek-üye iskânı ({gorev})"
    kanallar: [ _agents/handoff/{uye.lower()}-durum.md ]
    inbox: _agents/handoff/{uye.lower()}-inbox.md"""
print("\n".join(out).rstrip("\n") + "\n" + blok)
PYEOF
)"
  if [ -z "$ekip_reg_yeni" ] || ! printf '%s\n' "$ekip_reg_yeni" | grep -q "id: $uye"; then
    echo "[kırmızı] ekip-registry dönüşümü başarısız (yeni-üye bloğu üretilemedi) — hiçbir yere yazılmadı" >&2
    exit 1
  fi
  if ! printf '%s\n' "$ekip_reg_yeni" | _ey_ssh "cat > '$EY_HOST_PROJ/_agents/handoff/ekip-registry.yaml' && chown 1000:1000 '$EY_HOST_PROJ/_agents/handoff/ekip-registry.yaml'"; then
    echo "[kırmızı] ekip-registry yazımı başarısız" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-2 ekip-registry: $uye ($gorev) roster'a eklendi (uye_sayisi güncellendi)"

  # ── ADIM-3: kimlik-banner + tmux-oturumu (FAZ-6 mekaniği, _ey_pane_ac REUSE) ──────────────
  _ey_pane_ac "$uye" "$gorev" "$sid" || exit 1
  if [ "$EY_PANE_SONUC" = "mevcut" ]; then
    echo "[yeşil] ADIM-3 $uye: tmux-oturumu mevcut → atla (rezerve-uuid korunur: $sid)"
  else
    echo "[yeşil] ADIM-3 $uye: tmux-oturumu AÇILDI ($gorev, rezerve-uuid: $sid, cwd=$EY_HEDEF_ICI)"
  fi

  # ── ADIM-4: iskan-registry K2 yeniden-üretim (tüm-roster) → 3-kopya bayt-eş ───────────────
  local reg_yeni; reg_yeni="$(_ey_iskan_registry_icerik < <(printf '%s' "$EY_UYE_SATIRLARI" | cut -f1-3))"
  _ey_registry_dagit "$reg_yeni" "$reg_mevcut" || exit 1

  echo ""
  echo "== uye-ekle bitti: $uye → $proje ($gorev, rezerve-uuid: $sid) · registry 3-kopya bayt-eş =="
  echo "   [sultan-bildirim] üye-iskânı Sultan'a raporlanır; repo-kopyası commit/PR AYRI adımdır (REPO-FIRST)"
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
  cf-yayin)
    shift
    cmd_cf_yayin "$@"
    ;;
  ekip-yerlestir)
    shift
    cmd_ekip_yerlestir "$@"
    ;;
  uye-ekle)
    shift
    cmd_uye_ekle "$@"
    ;;
  *)
    echo "kullanım: iskan.sh doctor | iskan.sh seans-getir --container <ad> [--apply] | iskan.sh yeni-proje <ad> [--mem-limit <val>] --dry-run|--apply | iskan.sh cf-yayin <proje> --dry-run|--apply | iskan.sh ekip-yerlestir <proje> --dry-run|--apply | iskan.sh uye-ekle <proje> <uye> [--gorev <görev>] --dry-run|--apply" >&2
    exit 2
    ;;
esac
