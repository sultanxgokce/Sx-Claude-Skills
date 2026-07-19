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

# _iskan_mem_mb <mem_limit> — compose mem-limit değerini MB'a çevirir (k/m/g/çıplak-bayt);
# çözülemeyen biçimde BOŞ döner (WARN-kapısı sessiz-atlar — compose kendi hatasını verir).
_iskan_mem_mb() {
  printf '%s' "$1" | awk '
    /^[0-9]+[gG]$/ { printf "%d", substr($0, 1, length($0)-1) * 1024; next }
    /^[0-9]+[mM]$/ { printf "%d", substr($0, 1, length($0)-1); next }
    /^[0-9]+[kK]$/ { printf "%d", int(substr($0, 1, length($0)-1) / 1024); next }
    /^[0-9]+$/     { printf "%d", int($0 / 1048576); next }
  '
}

# _iskan_compose_blok <ad> <cname> <config_dir> <port> <mem_limit> — mihenk-şablon-baz (k0084):
# kendi config-dizini + ORTAK ./config/.claude (keyless Claude-login mirası — B2 zincir-blokajı
# fix'i: bu mount olmadan doğan ekip claude açamaz, setup-isolated.sh credentials'ı buradan bekler)
# + DEFAULT_WORKSPACE. BİLİNÇLİ-YOK'lar: ./config/projects/<ad> mount'u EKLENMEZ (proje-ağacı
# tenant'ın kendi config'inde yaşar — EY_HOST_PROJ deseni; ortak-projects mount'u onu GÖLGELERdi,
# b0024 sınıfı) · evraklar-köprüleri EKLENMEZ (mahremiyet-KARARI, röportaj/operatör açıkça isterse
# elle) · .agent-dashboard EKLENMEZ (mobil-panel görünürlük paketi ayrı-faz).
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
      - DEFAULT_WORKSPACE=/config/projects/${ad}
      - DOCKER_MODS=linuxserver/mods:universal-package-install
      # FAZ-6 generator-hizası: İSKÂN-container'ları ekip-hazır doğar (tmux=oturum, git=ekip-notify REPO_ROOT)
      - INSTALL_PACKAGES=tmux|git|python3
    volumes:
      - ${config_dir}:/config
      # ORTAK Claude master (keyless-login + skills + global CLAUDE.md mirası — mihenk-emsal k0084)
      - ./config/.claude:/config/.claude
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
# sebebi sayılır. BİLİNÇLİ-KÖPRÜ allowlist'i (P-Y1): ortak-tasarım path'leri (default yalnız
# ./config/.claude — keyless-login mirası, mount-paketinin kendisi) yeni-kesişim SAYILMAZ;
# ISKAN_B1_BILINCLI_KOPRU env'i ile daraltılıp/genişletilebilir (boş = allowlist kapalı).
# Döner: "0" (güvenli) veya >0 (allowlist-dışı yeni-kesişim sayısı, apply RED edilmeli).
_iskan_b1_check() {
  local repo_compose="$1" blok_dosyasi="$2"
  local combined; combined="$(mktemp)"
  cat "$repo_compose" "$blok_dosyasi" > "$combined" 2>/dev/null
  local before after
  before="$(python3 "$COMPOSE_PARSE" "$repo_compose" 2>/dev/null)"
  after="$(python3 "$COMPOSE_PARSE" "$combined" 2>/dev/null)"
  rm -f "$combined"
  python3 - "$before" "$after" "${ISKAN_B1_BILINCLI_KOPRU-./config/.claude}" <<'PYEOF'
import json, sys
before_raw, after_raw, allow_raw = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    before = json.loads(before_raw)["intersections"] if before_raw else []
    after = json.loads(after_raw)["intersections"] if after_raw else []
except Exception:
    print("parse-hatasi")
    sys.exit(0)
allow = {p for p in allow_raw.split() if p}
before_keys = {(i["path"], tuple(sorted(i["services"]))) for i in before}
new = [i for i in after
       if (i["path"], tuple(sorted(i["services"]))) not in before_keys
       and i["path"] not in allow]
print(len(new))
PYEOF
}

# _iskan_setup_script_icerik <ad> — infra/setup-<ad>.sh içeriğini basar (setup-mihenk.sh
# emsali: İNCE-SARMALAYICI, gerçek iş parametrik setup-isolated.sh'te — tek kaynak, drift YOK).
# B1 zincir-blokajı fix'i: provizyon adım-4'ün REPO-KANIT kapısı bu dosyayı origin/main'de
# ŞART koşar (iskan.sh cmd_provizyon) — üretmeyen zincir taze-tenant'ta garantili-kırmızıydı.
_iskan_setup_script_icerik() {
  local ad="$1" etiket
  etiket="${ad^}"
  cat <<EOF
#!/usr/bin/env bash
# cloudtop · İZOLE ${etiket} workspace (cloudtop-${ad}) — BİR KERELİK bootstrap (İSKÂN yeni-proje üreteci)
# İNCE SARMALAYICI: gerçek iş parametrik setup-isolated.sh'te (tek kaynak → drift YOK,
# vekatip/mmex/medigate/huma/mihenk ile birebir aynı kurulum + çok-oturum cs profili).
#
# Konteyner \`docker compose up -d --no-recreate cloudtop-${ad}\` ile ayağa kalktıktan SONRA
# çalıştır (İSKÂN-yolu: iskan.sh provizyon ${ad} --apply, ISKAN_FAZ9_GO=1 Sultan-GO'lu):
#   bash /opt/cloudtop/config/projects/cloudtop/infra/setup-${ad}.sh
set -euo pipefail
HERE="\$(cd "\$(dirname "\$0")" && pwd)"

bash "\$HERE/setup-isolated.sh" cloudtop-${ad} /config/projects/${ad} ${etiket}

echo "  Aç: https://${ad}.mmepanel.com  (önce CF Access app'i — iskan.sh cf-yayin ${ad})"
echo "  Ekip-yerleşimi AYRI adım: iskan.sh ekip-yerlestir ${ad} (kur zinciri adım 6/7)."
EOF
}

# _iskan_tunnel_satirlari_ekle <tunnel_dosya> <ad> <port> — setup-tunnel.sh'e üç dokunuş
# (P-Y2, cf-yayin adım-5 REPO-KANIT'ının beklediği içerik): <AD>_HOSTNAME değişken-satırı +
# ingress-çifti (http_status:404 catch-all'dan ÖNCE) + route-dns satırı. Söküm-simetrisi:
# üç satır da proje-token'ı içerir → _sokum_satir_cikar temiz geri-alır (ingress service-satırı
# çift-kuralıyla). rc=0 eklendi · rc=2 zaten-var (dokunulmadı) · rc=1 hata (çıpa-eksik /
# bash -n düştü → dosya yedekten geri-alınır, dokunulmamış-eş kalır).
_iskan_tunnel_satirlari_ekle() {
  local dosya="$1" ad="$2" port="$3" yedek rc
  yedek="$(mktemp)"
  cp -a "$dosya" "$yedek" || { rm -f "$yedek"; return 1; }
  python3 - "$dosya" "$ad" "$port" <<'PYEOF'
import re, sys
path, ad, port = sys.argv[1], sys.argv[2], sys.argv[3]
uvar = re.sub(r"[^A-Za-z0-9]", "_", ad).upper() + "_HOSTNAME"
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
if any(re.match(r"^" + re.escape(uvar) + r"=", l) for l in lines):
    sys.exit(2)
var_idx = [i for i, l in enumerate(lines) if re.match(r"^[A-Z0-9_]+_HOSTNAME=", l)]
catch_idx = [i for i, l in enumerate(lines) if re.match(r"^\s*-\s*service:\s*http_status:404", l)]
route_idx = [i for i, l in enumerate(lines) if re.match(r"^cloudflared tunnel route dns ", l)]
if not var_idx or not catch_idx or not route_idx:
    sys.exit(1)
# NOT (LB-1 söküm-simetrisi): ingress + route satırları RAW `ad`'ı yorum-etiketiyle taşır — böylece
# söküm'ün generic substring-remover'ı (_sokum_satir_cikar, RAW-token eşler) TİRELİ/özel-karakterli
# adlarda da bu satırları bulur. Aksi hâlde uvar (ad→[^A-Za-z0-9]→_ sanitize) raw-token'ı içermez
# (ör. my-proj→MY_PROJ_HOSTNAME) → söküm yalnız tanım-satırını siler, ingress/route öksüz kalır →
# tanımsız ${..._HOSTNAME} → gerçek setup-tunnel.sh set -u altında çöker.
# BİLİNEN-SINIR (F5-kuyruğu): _sokum_satir_cikar SUBSTRING eşler (pre-existing) → bir üst-küme
# hostname'in alt-dizesi olan ad (ör. 'hen' ⊂ 'mihenk') söküldüğünde komşunun satırlarını da
# siler. Kontrivan+operatör-eli; söküm-matcher'ını word-boundary'ye evirmek AYRI PR (söküm-sözleşmesi
# tested) → F5'e. Bugünkü gerçek adlar (mihenk/huma/medi/vekatip/code/pc/m) böyle çakışmaz.
var_line = uvar + '="${' + uvar + "_OVERRIDE:-" + ad + '.mmepanel.com}"          # İSKÂN workspace (cloudtop-' + ad + ", " + port + "; iskan.sh yeni-proje üretti)"
ingress_pair = ["  - hostname: ${" + uvar + "}   # " + ad + " (İSKÂN yeni-proje)", "    service: http://localhost:" + port]
route_line = 'cloudflared tunnel route dns "$TUNNEL" "$' + uvar + '" || true   # ' + ad + " (İSKÂN yeni-proje)"
inserts = sorted(
    [(max(var_idx) + 1, [var_line]), (catch_idx[0], ingress_pair), (max(route_idx) + 1, [route_line])],
    key=lambda t: t[0], reverse=True)
for pos, new_lines in inserts:
    lines[pos:pos] = new_lines
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PYEOF
  rc=$?
  if [ "$rc" = "2" ]; then rm -f "$yedek"; return 2; fi
  if [ "$rc" != "0" ] || ! bash -n "$dosya" 2>/dev/null; then
    cp -a "$yedek" "$dosya"
    rm -f "$yedek"
    return 1
  fi
  rm -f "$yedek"
  return 0
}

# _iskan_yp_kardesler <ad> <port> <setup_dosya> <tunnel_dosya> — DURAK-1 üçlüsünün compose-dışı
# iki kalemini idempotent yazar (setup-<ad>.sh + setup-tunnel 3-satır). rc≠0 = kırmızı, çağıran
# DURur. Hem taze-apply hem idempotent-geçiş (eksik-tamamlama) bu tek yoldan geçer.
_iskan_yp_kardesler() {
  local ad="$1" port="$2" setup_dosya="$3" tunnel_dosya="$4" rc
  if [ -f "$setup_dosya" ]; then
    echo "[yeşil] setup-script: $setup_dosya mevcut → atla (idempotent)"
  else
    _iskan_setup_script_icerik "$ad" > "$setup_dosya" || { echo "[kırmızı] setup-script yazılamadı: $setup_dosya" >&2; return 1; }
    chmod +x "$setup_dosya" 2>/dev/null || true
    if ! bash -n "$setup_dosya" 2>/dev/null; then
      echo "[kırmızı] setup-script bash -n kapısı DÜŞTÜ: $setup_dosya — dosyayı incele, DUR" >&2
      return 1
    fi
    echo "[yeşil] setup-script üretildi: $setup_dosya (İNCE-SARMALAYICI → setup-isolated.sh; provizyon adım-4 REPO-KANIT'ı bunu ister)"
  fi
  _iskan_tunnel_satirlari_ekle "$tunnel_dosya" "$ad" "$port"; rc=$?
  case "$rc" in
    0) echo "[yeşil] setup-tunnel: 3 satır eklendi — hostname-değişkeni + ingress-çifti (port $port) + route-dns ($tunnel_dosya, bash -n temiz; cf-yayin adım-5 REPO-KANIT'ı bunu ister)" ;;
    2) echo "[yeşil] setup-tunnel: '$ad' satırları zaten mevcut → atla (idempotent)" ;;
    *) echo "[kırmızı] setup-tunnel dokunuşu BAŞARISIZ (çıpa-eksik ya da bash -n düştü) — dosya dokunulmamış-eş geri-alındı: $tunnel_dosya" >&2; return 1 ;;
  esac
}

# _iskan_tunnel_cipa_var <tunnel_dosya> — setup-tunnel.sh'in üç çıpası (hostname-değişkeni ·
# http_status:404 catch-all · route-dns satırı) MEVCUT mu? rc=0 hepsi var · rc=1 en az biri yok.
# MAJOR-3 fix: taze-apply ön-kapısı compose'a dokunmadan ÖNCE bunu koşar — çıpasız-ama-mevcut
# tünel-dosyası 'sıfır-dokunuş fail-closed' vaadini kırmasın (compose yazıp kardeş-fail = yarım-yazım).
_iskan_tunnel_cipa_var() {
  local dosya="$1"
  [ -f "$dosya" ] || return 1
  grep -qE '^[A-Z0-9_]+_HOSTNAME=' "$dosya" \
    && grep -qE '^[[:space:]]*-[[:space:]]*service:[[:space:]]*http_status:404' "$dosya" \
    && grep -qE '^cloudflared tunnel route dns ' "$dosya"
}

cmd_yeni_proje() {
  # FAZ-9 port-override: --port <n> (arg) > ISKAN_PORT (env) > _iskan_pick_port (default).
  # NEDEN: pick_port floor=8449 — floor-ALTI canon-rezerve portlar (mihenk=8448, Sultan-onaylı)
  # pick'ten asla çıkamaz; override operatörün AÇIK beyanıdır. Override verilmediğinde
  # davranış bayt-aynı korunur (golden: mevcut fixture'lar değişmeden geçer).
  # D6 tuzak-fix ("sessiz-ölü ekip"): default mem-limit 512m → 2g. claude tek-üye ~357-657MB
  # RSS ölçüldü (templates/baslat-claude.sh kur-reçetesi: "compose'ta mem_limit >= 2g") — 512m
  # default'unda doğan ekip sessizce OOM-ölüyordu.
  local ad="" mode="" mem_limit="2g" port_override="${ISKAN_PORT:-}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --apply) mode="apply"; shift ;;
      --mem-limit) mem_limit="${2:-2g}"; shift 2 ;;
      --port) port_override="${2:-}"; shift 2 ;;
      -*) echo "bilinmeyen argüman: $1" >&2; exit 2 ;;
      *) ad="$1"; shift ;;
    esac
  done
  if [ -z "$ad" ] || [ -z "$mode" ]; then
    echo "kullanım: iskan.sh yeni-proje <ad> [--mem-limit <val>] [--port <n>] --dry-run|--apply" >&2
    exit 2
  fi
  # LB-2 fix: kardeş-komutlar (kur/provizyon/sokum/cf-yayin/ekip-yerlestir) gibi yeni-proje de
  # ad-hijyeninden geçmeli — bu PR `ad`'ı ilk kez HOST'ta koşan üretilmiş betiklere (setup-<ad>.sh
  # içeriği + setup-tunnel default-değeri) gömüyor → tırnaksız gömme + dosya-adı = komut-enjeksiyonu
  # + path-traversal yüzeyi. Dar-charset ([A-Za-z0-9-]) bunu kapatır. (bash -n üretilen betiği kör
  # kontrol eder: $(...) geçerli-sözdizimidir → yalnız charset-gate yakalar.)
  _ey_ad_hijyeni "$ad" "yeni-proje" || exit 1
  # ek-guard (re-verify MAJOR): ad'dan tünel-değişkeni <AD>_HOSTNAME türetilir → GEÇERLİ bash-
  # identifier olmalı. Rakam-başı (9proj→9PROJ_HOSTNAME) bash-atama DEĞİL komut sayılır, $9
  # konumsal-parametre olur → `bash -n` KÖR geçer (sözdizimsel geçerli) ama runtime `set -u`
  # altında 'bad substitution' ile çöker → yalancı-yeşil + repoya bozuk artefakt. Harf-başı ŞART.
  if ! printf '%s' "$ad" | LC_ALL=C grep -qE '^[A-Za-z]'; then
    echo "[kırmızı] yeni-proje: '$ad' harf ile başlamıyor — tünel-değişkeni (\${AD}_HOSTNAME) geçerli bash-identifier olmalı (rakam-başı runtime 'bad substitution' üretir; bash -n kör geçer), hiçbir yere dokunulmadı" >&2
    exit 1
  fi
  if [ -n "$port_override" ] && ! printf '%s' "$port_override" | grep -qE '^[0-9]+$'; then
    echo "[kırmızı] --port/ISKAN_PORT sayısal olmalı, gelen: '$port_override'" >&2
    exit 2
  fi

  # 2g-altı açık-beyan WARN'lanır ama hard-fail EDİLMEZ (kullanıcı bilinçli küçük verebilir).
  local mem_mb
  mem_mb="$(_iskan_mem_mb "$mem_limit")"
  if [ -n "$mem_mb" ] && [ "$mem_mb" -lt 2048 ]; then
    echo "[uyarı] mem_limit ${mem_limit} 2g-altı — claude ≥2g ister ('sessiz-ölü ekip' tuzağı, bkz templates/baslat-claude.sh kur-reçetesi); bilinçli-küçük değilse --mem-limit 2g kullan"
  fi

  local repo_compose="${ISKAN_REPO_COMPOSE:-/config/projects/cloudtop/infra/docker-compose.server.yml}"
  [ -f "$repo_compose" ] || { echo "[kırmızı] repo-compose bulunamadı: $repo_compose" >&2; exit 1; }

  local cname="cloudtop-${ad}" config_dir="./config-${ad}"

  # DURAK-1 üçlüsünün compose-dışı kalemleri (P-Y2): setup-<ad>.sh + setup-tunnel dokunuşu.
  # Yollar repo_compose'un dizininden türer → testler fixture-dizinle hermetik kalır.
  local repo_infra setup_dosya tunnel_dosya
  repo_infra="$(dirname "$repo_compose")"
  setup_dosya="$repo_infra/setup-${ad}.sh"
  tunnel_dosya="${ISKAN_REPO_TUNNEL:-$repo_infra/setup-tunnel.sh}"

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
    if [ -n "$port_override" ]; then
      # override-çakışma kapısı: rezerve-port zaten compose'da bir servise bağlıysa RED
      # (pick_port'un doğal kaçınması override'da geçerli değil → açıkça kontrol edilir).
      if grep -qE "\"127\.0\.0\.1:${port_override}:8443\"" "$repo_compose"; then
        echo "[kırmızı] port-override ${port_override} zaten repo-compose'da kullanımda — RED (çakışan servise dokunulmadı)" >&2
        exit 1
      fi
      port="$port_override"
      echo "[yeşil] port-kaynağı: operatör-override (--port/ISKAN_PORT) → ${port} (pick_port atlandı)"
    else
      port="$(_iskan_pick_port "$repo_compose")"
    fi
    blok="$(_iskan_compose_blok "$ad" "$cname" "$config_dir" "$port" "$mem_limit")"
    blok_dosyasi="$(mktemp)"
    printf '%s\n' "$blok" > "$blok_dosyasi"
    yeni_kesisim="$(_iskan_b1_check "$repo_compose" "$blok_dosyasi")"
  fi

  if [ "$mode" = "dry-run" ] && [ "$mevcut" = "1" ]; then
    echo "== İSKÂN yeni-proje — KURU-KOŞU (DEFAULT; hiçbir dosya yazılmaz, host'a dokunulmaz) =="
    echo "proje: $ad · container: $cname · port: 127.0.0.1:${port:-?}:8443 (mevcut-bloktan okundu)"
    echo "[yeşil] '$cname' bloğu ZATEN repo-compose'da (idempotent) — apply'da yeniden-yazım YAPILMAYACAK"
    echo "-- DURAK-1 ÜÇLÜ-DURUM (compose + setup-script + tünel-satırı; eksikler apply'da tamamlanır) --"
    if [ -f "$setup_dosya" ]; then
      echo "  [yeşil] setup-script: $setup_dosya MEVCUT"
    else
      echo "  [doğrulanmadı] setup-script: $setup_dosya YOK — apply üretir (provizyon adım-4 REPO-KANIT'ı ister)"
    fi
    if [ ! -f "$tunnel_dosya" ]; then
      echo "  [doğrulanmadı] setup-tunnel: $tunnel_dosya BULUNAMADI — apply RED eder (fail-closed; ISKAN_REPO_TUNNEL ile yol ver)"
    elif ! _iskan_tunnel_cipa_var "$tunnel_dosya"; then
      echo "  [doğrulanmadı] setup-tunnel: $tunnel_dosya çıpasız (hostname-değişkeni/http_status:404/route-dns eksik) — apply RED eder (sıfır-dokunuş)"
    elif grep -q "${ad}.mmepanel.com" "$tunnel_dosya"; then
      echo "  [yeşil] setup-tunnel: '$ad' satırları MEVCUT ($tunnel_dosya)"
    else
      echo "  [doğrulanmadı] setup-tunnel: '$ad' satırları YOK — apply ekler (cf-yayin adım-5 REPO-KANIT'ı ister)"
    fi
    echo "-- MANİFEST-DOKUNUŞ (bilgilendirme — bu çağrıda hiçbir dosya yazılmadı) --"
    echo "  - ${repo_compose} (blok mevcut → repo-yazımı GEREKMİYOR)"
    echo "  - host-deploy + docker-compose up (AYRI adım: iskan-host.sh --apply, cloudtop-PR merge'i SONRASI)"
    echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN yeni-proje — KURU-KOŞU (DEFAULT; hiçbir dosya yazılmaz, host'a dokunulmaz) =="
    echo "proje: $ad · container: $cname · port: 127.0.0.1:${port}:8443 · mem_limit: $mem_limit"
    echo "-- B1 (kesişim-guard, önizleme) -- yeni-kesişim: ${yeni_kesisim} $([ "$yeni_kesisim" = "0" ] && echo '(GÜVENLİ)' || echo '(RED-adayı — apply reddedilecek)') · bilinçli-köprü allowlist: ${ISKAN_B1_BILINCLI_KOPRU-./config/.claude}"
    echo "-- ÜRETİLECEK COMPOSE-BLOK --"
    printf '%s\n' "$blok"
    echo "-- DURAK-1 ÜÇLÜ (apply compose-bloğuna ek üretecek; P-Y2) --"
    echo "  - setup-script: $setup_dosya (İNCE-SARMALAYICI → setup-isolated.sh cloudtop-$ad /config/projects/$ad ${ad^})"
    if [ ! -f "$tunnel_dosya" ]; then
      echo "  - [doğrulanmadı] setup-tunnel: $tunnel_dosya BULUNAMADI — apply RED eder (fail-closed; ISKAN_REPO_TUNNEL ile yol ver)"
    elif ! _iskan_tunnel_cipa_var "$tunnel_dosya"; then
      echo "  - [doğrulanmadı] setup-tunnel: $tunnel_dosya çıpasız (hostname-değişkeni/http_status:404/route-dns eksik) — apply RED eder (sıfır-dokunuş)"
    elif grep -q "${ad}.mmepanel.com" "$tunnel_dosya"; then
      echo "  - [yeşil] setup-tunnel: '$ad' satırları ZATEN mevcut ($tunnel_dosya) → apply atlar"
    else
      echo "  - setup-tunnel: 3-satır eklenecek ($tunnel_dosya — hostname-değişkeni + ingress-çifti [port $port] + route-dns)"
    fi
    echo "-- MANİFEST-DOKUNUŞ (bilgilendirme — bu çağrıda hiçbir dosya yazılmadı) --"
    echo "  - ${repo_compose} (REPO-FIRST: yalnız bu tek-blok eklenecek, başka satıra dokunulmayacak)"
    echo "  - ${setup_dosya} + ${tunnel_dosya} (DURAK-1 üçlüsünün kalan iki kalemi)"
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
    echo "== İSKÂN yeni-proje — İDEMPOTENT GEÇİŞ (DURAK-1 üçlü-tamamlayıcı) =="
    echo "[yeşil] '$cname' bloğu ZATEN repo-compose'da (port: ${port:-?}) — compose'a yeniden-yazım YOK"
    if [ ! -f "$tunnel_dosya" ]; then
      echo "[kırmızı] setup-tunnel bulunamadı: $tunnel_dosya — üçlü tamamlanamaz (fail-closed; ISKAN_REPO_TUNNEL ile yol ver), başka hiçbir dosyaya dokunulmadı" >&2
      exit 1
    fi
    if [ -z "$port" ]; then
      echo "[kırmızı] '$cname' port'u mevcut-bloktan çözülemedi — tünel-satırı üretilemez, DUR (başka hiçbir dosyaya dokunulmadı)" >&2
      exit 1
    fi
    _iskan_yp_kardesler "$ad" "$port" "$setup_dosya" "$tunnel_dosya" || exit 1
    echo "== bitti — idempotent-geçiş: compose'a dokunulmadı, eksik kardeş-kalemler tamamlandı (varsa) =="
    exit 0
  fi

  if [ "$yeni_kesisim" != "0" ]; then
    rm -f "$blok_dosyasi"
    echo "[kırmızı] yeni-proje --apply: B1 volume-path kesişim-guard tetiklendi (${yeni_kesisim} yeni-kesişim) — RED, hiçbir dosya yazılmadı" >&2
    exit 1
  fi

  # DURAK-1 üçlü ön-kapısı (P-Y2 + MAJOR-3): compose'a dokunmadan ÖNCE tünel-dosyası hem VAR hem
  # ÇIPALI olmalı (varlık-only kontrol yetmez — çıpasız-ama-mevcut dosya compose yazıldıktan sonra
  # kardeş-fail'e düşüp 'sıfır-dokunuş' vaadini kırardı). Fail-closed sıfır-dokunuş.
  if [ ! -f "$tunnel_dosya" ]; then
    rm -f "$blok_dosyasi"
    echo "[kırmızı] setup-tunnel bulunamadı: $tunnel_dosya — DURAK-1 üçlüsü tamamlanamaz, hiçbir dosya yazılmadı (ISKAN_REPO_TUNNEL ile yol ver)" >&2
    exit 1
  fi
  if ! _iskan_tunnel_cipa_var "$tunnel_dosya"; then
    rm -f "$blok_dosyasi"
    echo "[kırmızı] setup-tunnel çıpasız: $tunnel_dosya üç çıpanın (hostname-değişkeni · http_status:404 · route-dns) hepsini içermiyor — tünel-satırı üretilemez, compose'a dokunulmadan DUR (sıfır-dokunuş, hiçbir dosya yazılmadı)" >&2
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
  if ! _iskan_yp_kardesler "$ad" "$port" "$setup_dosya" "$tunnel_dosya"; then
    echo "[kırmızı] DURAK-1 üçlüsü YARIM kaldı: compose-blok yazıldı ama kardeş-kalem düştü — hepsi git-tracked, geri-al: git checkout -- <dosya>; DUR" >&2
    exit 1
  fi
  echo "proje: $ad · container: $cname · port: 127.0.0.1:${port}:8443 · mem_limit: $mem_limit · B1-yeni-kesişim: 0"
  echo "== bitti — DURAK-1 üçlüsü (compose-blok + setup-script + tünel-satırları) yalnız git-tracked repo'ya yazıldı; commit/push/PR + host-deploy AYRI adımlardır (REPO-FIRST, D1) =="
  exit 0
}

# ── provizyon (FAZ-9: container-İÇİ dev-araç kurulumu — setup-<proje>.sh tetikleyicisi) ──
#
# NEDEN: FAZ-9 = gerçek-dogfood. Container doğduktan (H1, iskan-host.sh --apply) sonra
# içine dev-araç kurulumu (nvm+node+claude+cs; kardeş-desen: infra/setup-huma.sh →
# setup-isolated.sh) İKİNCİ host-dokunuşudur (H2) → kendi Sultan-GO kapısı ISKAN_FAZ9_GO.
# FAZ-4 konvansiyonu AYNEN (iskan-host.sh GO-kapısı emsali): marker-yokken --apply →
# exit=4 + stderr'de marker-adı; dry-run DEFAULT → plan-exit=3, host'a SIFIR-dokunuş.
#
# GUARD-ZİNCİRİ (--apply; biri düşerse host'a SIFIR-dokunuş):
#  1. GO-marker (deterministik, ağ-bağımsız — İLK kapı)
#  2. REPO-KANIT: setup-script origin/main'de VAR ve host'un koşacağı working-tree kopyası
#     origin/main ile bayt-eş (D1 REPO-FIRST: host'a giden içerik merge-edilmiş içeriktir;
#     setup-isolated.sh bağımlılığı da aynı kapıdan geçer)
#  3. ssh-erişim taze-probe (K4)
#  4. container-running ön-koşulu (hedef ayakta değilse kurulum anlamsız → RED)
# Sır-DEĞERİ hiçbir çıktıya düşmez (yalnız yol/durum konuşulur).
cmd_provizyon() {
  local proje="" mode="dry-run"
  while [ $# -gt 0 ]; do
    case "$1" in
      --apply) mode="apply"; shift ;;
      --dry-run) mode="dry-run"; shift ;;
      -*) echo "bilinmeyen argüman: $1" >&2; echo "kullanım: iskan.sh provizyon <proje> [--apply]" >&2; exit 2 ;;
      *) proje="$1"; shift ;;
    esac
  done
  [ -n "$proje" ] || { echo "kullanım: iskan.sh provizyon <proje> [--apply]" >&2; exit 2; }

  local cname="cloudtop-${proje}"
  local repo_dir="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
  local setup_rel="infra/setup-${proje}.sh"
  # host-yol gerçeği (firsthand, deploy-host.sh): cloudtop-repo host'ta
  # /opt/cloudtop/config/projects/cloudtop olarak mount'ludur → setup-script oradan koşar.
  local host_setup="${ISKAN_HOST_SETUP_PATH:-/opt/cloudtop/config/projects/cloudtop/${setup_rel}}"
  local ssh_host="${ISKAN_SSH_HOST:-hostsrv}"
  local ssh_opts=(-o BatchMode=yes -o ConnectTimeout=8)

  # ── 1. GO-kapısı (DOCTRINE Değişmez-3; FAZ-4 exit=4 + stderr-marker konvansiyonu AYNEN) ──
  if [ "$mode" = "apply" ] && [ "${ISKAN_FAZ9_GO:-}" != "1" ]; then
    echo "[kırmızı] provizyon --apply: FAZ-9 Sultan-GO env-marker gerekli (ISKAN_FAZ9_GO=1) — host'a SIFIR-dokunuş" >&2
    exit 4
  fi

  # ── REPO-KANIT ölçümü (dry-run: bilgi · apply: sert-kapı) ────────────────────────────────
  local repo_kanit="doğrulanmadı" f
  if command -v git >/dev/null 2>&1 && [ -d "$repo_dir/.git" ]; then
    git -C "$repo_dir" fetch -q origin main 2>/dev/null || true
    repo_kanit="yeşil"
    for f in "$setup_rel" "infra/setup-isolated.sh"; do
      if ! git -C "$repo_dir" show "origin/main:$f" >/dev/null 2>&1; then
        repo_kanit="kırmızı: $f origin/main'de YOK (önce cloudtop-PR merge edilmeli)"
        break
      fi
      if ! git -C "$repo_dir" show "origin/main:$f" 2>/dev/null | cmp -s - "$repo_dir/$f" 2>/dev/null; then
        repo_kanit="kırmızı: $f working-tree ≠ origin/main (host merge-edilmemiş içerik koşardı — D1 ihlali)"
        break
      fi
    done
  fi

  # ── ssh + container probe (dry-run: best-effort · apply: sert-kapı) ──────────────────────
  local ssh_ok=0 calisiyor="?"
  if command -v ssh >/dev/null 2>&1 && timeout 8 ssh "${ssh_opts[@]}" "$ssh_host" true >/dev/null 2>&1; then
    ssh_ok=1
    calisiyor="$(timeout 10 ssh "${ssh_opts[@]}" "$ssh_host" "docker ps --format '{{.Names}}'" 2>/dev/null | grep -cx "$cname" || true)"
  fi

  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN provizyon — KURU-KOŞU (DEFAULT; host'a/container'a SIFIR-dokunuş) =="
    echo "proje: $proje · container: $cname · setup-script (host-yolu): $host_setup"
    echo "-- GUARD-ÖNİZLEME (apply'da sert-kapı) --"
    echo "  1. GO-marker: apply yalnız ISKAN_FAZ9_GO=1 ile (yokken exit=4)"
    case "$repo_kanit" in
      yeşil) echo "  2. [yeşil] REPO-KANIT: $setup_rel + setup-isolated.sh origin/main'de VE working-tree bayt-eş" ;;
      kırmızı*) echo "  2. [$repo_kanit]" ;;
      *) echo "  2. [doğrulanmadı] REPO-KANIT: cloudtop-repo/git erişilemedi ($repo_dir)" ;;
    esac
    if [ "$ssh_ok" = "1" ]; then
      echo "  3. [yeşil] ssh-probe: taze $ssh_host exit=0"
      echo "  4. container-running: '$cname' host'ta $calisiyor kopya (apply 1 ister)"
    else
      echo "  3. [doğrulanmadı] ssh-probe: $ssh_host erişilemedi — canlı-durum önizlenemedi"
      echo "  4. [doğrulanmadı] container-running: ssh'sız ölçülemedi"
    fi
    echo "-- PLAN (apply'da tek-mutasyon) --"
    echo "  ssh $ssh_host 'setsid -w bash $host_setup' (container-İÇİ kurulum; komşu container'lara dokunmaz)"
    echo "  sonrası-doğrulama: docker exec -u 1000 $cname bash -lc 'command -v claude' (dürüst-kanıt)"
    echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  # ── APPLY (GO'lu; guard-zinciri sert) ─────────────────────────────────────────────────────
  echo "== İSKÂN provizyon — CANLI-APPLY (FAZ-9 Sultan-GO'lu; yalnız $cname İÇİNE kurulum) =="
  case "$repo_kanit" in
    yeşil) echo "[yeşil] REPO-KANIT: $setup_rel + setup-isolated.sh origin/main'de ve bayt-eş (D1)" ;;
    kırmızı*) echo "[$repo_kanit] — host'a dokunulmadı" >&2; exit 1 ;;
    *) echo "[kırmızı] REPO-KANIT ölçülemedi: cloudtop-repo/git erişilemedi ($repo_dir) — fail-closed, host'a dokunulmadı" >&2; exit 1 ;;
  esac
  if [ "$ssh_ok" != "1" ]; then
    echo "[kırmızı] ssh-probe: $ssh_host erişilemedi — host'a dokunulmadı" >&2
    exit 1
  fi
  if [ "$calisiyor" != "1" ]; then
    echo "[kırmızı] container-running ön-koşulu: '$cname' host'ta $calisiyor kopya (beklenen 1; önce H1 container-create) — host'a dokunulmadı" >&2
    exit 1
  fi

  local kanit_dir="${ISKAN_KANIT_DIR:-iskan/kanit/faz9}"
  mkdir -p "$kanit_dir"
  local out_dosya="$kanit_dir/provizyon-${proje}.txt"
  # setsid -w: ssh-oturumu düşse kurulum yarım kalmaz (iskan-host.sh R2 emsali)
  if ! timeout 1800 ssh "${ssh_opts[@]}" "$ssh_host" "setsid -w bash '$host_setup' 2>&1" > "$out_dosya"; then
    echo "[kırmızı] setup-script başarısız (çıktı: $out_dosya) — DUR, SERDAR'a --waiting düş" >&2
    tail -20 "$out_dosya" >&2
    exit 1
  fi
  echo "[yeşil] setup-script koştu: $host_setup (çıktı: $out_dosya)"

  # dürüst-kanıt: kurulum-sonrası claude-binary gerçekten var mı. NVM-FARKINDA probe ŞART
  # (canlı-vaka k0084-H2: claude nvm-altında /config/.nvm/.../bin/claude; çıplak 'bash -lc'
  # nvm-source etmediğinden FALSE-RED üretti — setup-isolated.sh:100-102 doğrulama-deseni aynalanır).
  local claude_yolu
  claude_yolu="$(timeout 30 ssh "${ssh_opts[@]}" "$ssh_host" "docker exec -u abc $cname bash -lc 'export NVM_DIR=\$HOME/.nvm; [ -s \$NVM_DIR/nvm.sh ] && . \$NVM_DIR/nvm.sh; export PATH=\$HOME/.local/bin:\$PATH; command -v claude'" 2>/dev/null || true)"
  if [ -n "$claude_yolu" ]; then
    echo "[yeşil] doğrulama: claude-binary container-içinde mevcut ($claude_yolu)"
  else
    echo "[kırmızı] doğrulama: claude-binary container-içinde BULUNAMADI — kurulum eksik, kanıt: $out_dosya" >&2
    exit 1
  fi
  echo "== provizyon bitti: $cname dev-araçlı — kanıtlar: $kanit_dir/ =="
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
  # LC_ALL=C ŞART: UTF-8 collation'da [A-Za-z] aralığı 'ü' gibi lokal-harfleri de eşler (firsthand-bulgu)
  if ! printf '%s' "$1" | LC_ALL=C grep -qE '^[A-Za-z0-9-]+$'; then
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

  # ── MOUNT-FARKINDA hedef-yol çözümü (k0084-H4 canlı-bulgu: paylaşımlı-mount gölgelenmesi) ──
  # EY_HEDEF_ICI'nin (container-görünür hedef-dizin) HOST-tarafı yolu servis-bloğunun volume-
  # eşlemelerinden türetilir; EN-UZUN container-hedef-önek kazanır. İki sınıf da doğru çözülür:
  #  - tek-mount (iskantest: ./config-<ad>:/config)          → <root>/config-<ad>/projects/<ad>
  #  - paylaşımlı-mount (huma/mihenk: ./config/projects/<ad>:/config/projects/<ad>) → mount'un kendisi
  # Aksi hâlde artefaktlar (registry container-kopyası, baslat-claude.sh, _iskan/ banner'lar)
  # gölgelenen alt-yola düşer → container hiçbirini görmez (canlı-vaka: G6 üçlü-bayt-eş kırıldı).
  local ey_host_root="${ISKAN_HOST_COMPOSE_ROOT:-/opt/cloudtop}"
  # bazı çağıranlar (evergreen-kaydet) hedef-dizin kavramı taşımaz → default'la çöz (set -u güvenli)
  local ey_hedef="${EY_HEDEF_ICI:-/config/projects/${proje}}"
  local ey_cozulen
  ey_cozulen="$(printf '%s\n' "$compose_main" | awk -v cn="$EY_CNAME" -v hedef="$ey_hedef" -v root="$ey_host_root" '
    BEGIN { bestlen=0 }
    /container_name:/ { f = ($0 ~ cn"$") }
    f && /^[[:space:]]*-[[:space:]]/ {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/"/, "", line)
      n = split(line, a, ":")
      if (n < 2) next
      src = a[1]; dst = a[2]
      if (src !~ /^\.?\//) next                      # yalnız yol-eşlemeleri (port/named-volume değil)
      if (dst == hedef) { m = dst } else if (index(hedef, dst "/") == 1) { m = dst } else next
      if (length(m) > bestlen) { bestlen = length(m); bestsrc = src; bestdst = m }
    }
    END {
      if (bestlen > 0) {
        suffix = substr(hedef, length(bestdst) + 1)
        if (bestsrc ~ /^\.\//) { sub(/^\.\//, "", bestsrc); bestsrc = root "/" bestsrc }
        print bestsrc suffix
      }
    }
  ')"
  if [ -n "$ey_cozulen" ]; then
    EY_HOST_PROJ="$ey_cozulen"
    echo "[yeşil] hedef-yol çözümü (mount-farkında): $ey_hedef (container) → $EY_HOST_PROJ (host)"
  else
    echo "[doğrulanmadı] compose-volume'den hedef-yol çözülemedi — varsayılan kullanılacak: ${EY_HOST_PROJ:-<tanımsız>}"
  fi
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
# İKİNCİL CHARSET-KAPISI (G-a, P1c): rol/görev fullmatch [A-Za-z0-9-]+ değilse rc=1 fail-closed.
# NEDEN buraya da: roster üyeleri aşağıda tırnaksız ssh/docker/tmux komutlarına gömülür; köprü
# (ekip-modeli-iskan-kopru.sh) kendi charset-kapısını koşar AMA container-içi ekip-registry.yaml
# roster-kaynağı o köprüyü BYPASS eder — hijyen tüketim-noktasında da zorlanmalı.
_ey_uye_satirlari() {
  local roster="$1" reg_mevcut="$2" girdi rol gorev sid kaynak
  EY_YONETICI=""; EY_UYE_SAYISI=0; EY_UYE_SATIRLARI=""
  for girdi in $roster; do
    rol="${girdi%%:*}"; gorev="${girdi#*:}"
    [ "$gorev" = "$girdi" ] && gorev="uye"
    # LC_ALL=C ŞART: UTF-8 collation'da [A-Za-z] aralığı 'ü' gibi lokal-harfleri de eşler (firsthand-bulgu)
    if ! printf '%s' "$rol" | LC_ALL=C grep -qE '^[A-Za-z0-9-]+$' || ! printf '%s' "$gorev" | LC_ALL=C grep -qE '^[A-Za-z0-9-]+$'; then
      echo "[kırmızı] roster-hijyeni: '$girdi' — üye-adı/görev [A-Za-z0-9-] dışı karakter içeriyor (ikincil charset-kapısı; üye-adları ssh/docker/tmux komutlarına gömülür → fail-closed), hiçbir yere dokunulmadı" >&2
      return 1
    fi
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
    # D6 tuzak-fix: hardcoded deneme-roster fallback'i (denekAlfa/denekBeta) KALDIRILDI —
    # roster-kaynağı yokken sessizce SAHTE-EKİP doğuyordu (üstelik uye-ekle ile doğan gerçek
    # üyeyi registry'den silme riskiyle, G5-vakası emsali). Dürüst-kırmızı tek doğru davranış.
    echo "[kırmızı] roster-kaynağı yok: ne ISKAN_EY_ROSTER (açık-override) ne container-içi _agents/handoff/ekip-registry.yaml okunabildi — ekip-registry.yaml gerekli, sahte-ekip doğurulmaz (hiçbir yere dokunulmadı)" >&2
    exit 1
  fi

  # roster satırları: "rol<TAB>gorev<TAB>uuid<TAB>kaynak" (uuid: mevcut-kayıttan YENİDEN-KULLAN, yoksa üret)
  _ey_uye_satirlari "$roster" "$reg_mevcut" || exit 1
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
    if ! tar -C "$staging" -cf - . | _ey_ssh "mkdir -p '$EY_HOST_PROJ' && tar -C '$EY_HOST_PROJ' -xf - && chown -R 1000:1000 '$EY_HOST_PROJ'"; then
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
  _ey_uye_satirlari "$roster_mevcut $uye:$gorev" "$reg_mevcut" || exit 1
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

# ── evergreen-kaydet (FAZ-8: evergreen-kapama — kalıcı-iz manifest-yazımı) ─────────────────
#
# NEDEN: FAZ-8 = "İSKÂN'ın ürettiği iz sıfırdan-rebuild'de geri gelsin". Kayıtlı bir İSKÂN-
# projesinin kalıcı izlerini iki evergreen-manifest'e yazar (REPO-FIRST: lokal cloudtop-repo
# working-tree dosyaları; commit/PR AYRI adım):
#   1. infra/provider-inventory.yaml — cloudflare.tunnel.ingress + access_apps hostname-kaydı
#   2. infra/backup.sh — docker-inspect container-listesine cloudtop-<proje>
# HOST-APPLY YOK: çalışan-container'a/host-servise/CF'e dokunmaz → GO-marker gerekmez (B6 ayak-a:
# yalnız repo-dosyası + bash -n sözdizim-kapısı; ayak-b [gerçek dry-koşu] host-restic ister, FAZ-9).
# Güvenlik: yazımdan önce .bak · backup.sh yazımı sonrası bash -n (bozuksa .bak-restore + rc=1) ·
# idempotent (mevcut-satır → 'mevcut → atla'; 2.+ koşu no-op rc=0) · kayıtsız-proje K4-kapısı
# (_ey_proje_cozumu REUSE: origin/main compose TAM-STRING, fuzzy/önek/case-farkı YASAK).
#
# NOT (provider-inventory): dosya geçerli-YAML DEĞİL (serbest-metin scalar'lar, satır ~91;
# firsthand 2026-07-16) → yaml-parse YASAK, ekleme metin-temelli blok-konum ile yapılır
# (ingress-öğesi access_apps-anahtarından hemen önce; access_apps-öğesi son 4-boşluk öğeden sonra).

# _eg_inventory_ekle <dosya> <ing_line|-> <acc_line|-> — provider-inventory'ye metin-temelli ekleme.
# '-' = o bölüm atlanır (zaten mevcut). Marker bulunamazsa rc≠0 + dosyaya DOKUNMAZ.
_eg_inventory_ekle() {
  ING_LINE="$2" ACC_LINE="$3" python3 - "$1" <<'PYEOF'
import os, re, sys
path = sys.argv[1]
ing, acc = os.environ["ING_LINE"], os.environ["ACC_LINE"]
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
if ing != "-":
    idx = next((i for i, l in enumerate(lines) if re.match(r"^  access_apps:", l)), None)
    if idx is None:
        print("[kırmızı] provider-inventory: '  access_apps:' anahtarı bulunamadı — format değişti, dosyaya dokunulmadı", file=sys.stderr)
        sys.exit(1)
    lines.insert(idx, ing)  # ingress-bloğunun son öğesi olarak (access_apps'ten hemen önce)
if acc != "-":
    idx = next((i for i, l in enumerate(lines) if re.match(r"^  access_apps:", l)), None)
    if idx is None:
        print("[kırmızı] provider-inventory: '  access_apps:' anahtarı bulunamadı — format değişti, dosyaya dokunulmadı", file=sys.stderr)
        sys.exit(1)
    son = idx
    for j in range(idx + 1, len(lines)):
        if re.match(r"^    - \S", lines[j]):
            son = j
        elif re.match(r"^  \S", lines[j]):
            break
    lines.insert(son + 1, acc)
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PYEOF
}

# _eg_backup_ekle <dosya> <token> — backup.sh docker-inspect argüman-listesine container ekler.
# 'docker inspect ... >' satırı bulunamazsa rc≠0 + dosyaya DOKUNMAZ.
_eg_backup_ekle() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
path, token = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8", errors="replace").read()
yeni, n = re.subn(r"(?m)^(\s*docker inspect )([^>\n]*?)(\s*>)",
                  lambda m: m.group(1) + m.group(2).rstrip() + " " + token + m.group(3),
                  src, count=1)
if n != 1:
    print("[kırmızı] backup.sh: 'docker inspect ... >' satırı bulunamadı — format değişti, dosyaya dokunulmadı", file=sys.stderr)
    sys.exit(1)
open(path, "w", encoding="utf-8").write(yeni)
PYEOF
}

cmd_evergreen_kaydet() {
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
    echo "kullanım: iskan.sh evergreen-kaydet <proje> --dry-run|--apply" >&2
    exit 2
  fi
  _ey_ad_hijyeni "$proje" "evergreen-kaydet" || exit 1

  # K4 kayıt-kapısı: origin/main compose TAM-STRING (kayıtsız → 'kayitsiz-proje' rc≠0, sıfır-yazım)
  EY_REPO_DIR="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
  EY_CNAME="cloudtop-${proje}"
  EY_PORT=""
  _ey_proje_cozumu "$proje" || exit 1

  local host="${proje}.mmepanel.com"
  local inv="$EY_REPO_DIR/infra/provider-inventory.yaml"
  local bkp="$EY_REPO_DIR/infra/backup.sh"
  [ -f "$inv" ] || { echo "[kırmızı] provider-inventory bulunamadı: $inv — hiçbir yere dokunulmadı" >&2; exit 1; }
  [ -f "$bkp" ] || { echo "[kırmızı] backup.sh bulunamadı: $bkp — hiçbir yere dokunulmadı" >&2; exit 1; }

  # eklenecek satırlar (G6 awk-blok-sınırlarının İÇİNE düşecek girintilerle)
  local ing_line="      - ${host}   # İSKÂN-container (${EY_CNAME}, ${EY_PORT:-port-?}; iskan.sh cf-yayin ürünü — evergreen-kaydet kaydı)"
  local acc_line="    - ${host}     # İSKÂN-container (${EY_CNAME}; evergreen-kaydet kaydı)"

  # mevcutluk-tespiti (idempotency temeli; blok-sınırlı — G6 awk-deseniyle hizalı)
  local ing_var=0 acc_var=0 bkp_var=0
  awk '/ingress:/{f=1} /access_apps:/{f=0} f' "$inv" | grep -qF "$host" && ing_var=1
  awk '/access_apps:/{f=1} f' "$inv" | grep -qF "$host" && acc_var=1
  grep -E '^[[:space:]]*docker inspect ' "$bkp" | grep -qE "(^|[[:space:]])${EY_CNAME}([[:space:]]|>|\$)" && bkp_var=1

  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN evergreen-kaydet — evergreen-onizleme (KURU-KOŞU; hiçbir dosyaya yazılmaz) =="
    echo "proje: $proje · hostname: $host · container: $EY_CNAME · repo: $EY_REPO_DIR"
    echo "hedefler = REPO-FIRST lokal working-tree (host-apply YOK; commit/PR ayrı-adım)"
    echo ""
    echo "-- infra/provider-inventory.yaml --"
    if [ "$ing_var" = "1" ]; then echo "  [atla/mevcut] tunnel.ingress: $host zaten kayıtlı"; else echo "  EKLENECEK (tunnel.ingress):"; echo "  + $ing_line"; fi
    if [ "$acc_var" = "1" ]; then echo "  [atla/mevcut] access_apps: $host zaten kayıtlı"; else echo "  EKLENECEK (access_apps):"; echo "  + $acc_line"; fi
    echo "-- infra/backup.sh --"
    if [ "$bkp_var" = "1" ]; then echo "  [atla/mevcut] docker-inspect listesi: $EY_CNAME zaten kayıtlı"; else echo "  EKLENECEK (docker-inspect argüman-listesine): + $EY_CNAME"; fi
    echo ""
    echo "== dry-run: hiçbir yazım yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  # ── APPLY (yalnız lokal repo-dosyaları; her dosyaya yazımdan önce .bak) ──────────────────
  echo "== İSKÂN evergreen-kaydet — APPLY ($proje → evergreen-manifestler, REPO-FIRST) =="
  local yazildi=0

  if [ "$ing_var" = "1" ] && [ "$acc_var" = "1" ]; then
    echo "[yeşil] provider-inventory: $host her iki bölümde mevcut → atla"
  else
    cp -a "$inv" "$inv.bak" || { echo "[kırmızı] .bak alınamadı: $inv — dokunulmadı" >&2; exit 1; }
    local ing_arg="-" acc_arg="-"
    [ "$ing_var" = "0" ] && ing_arg="$ing_line"
    [ "$acc_var" = "0" ] && acc_arg="$acc_line"
    if ! _eg_inventory_ekle "$inv" "$ing_arg" "$acc_arg"; then
      cp -a "$inv.bak" "$inv" || true
      echo "[kırmızı] provider-inventory yazımı başarısız — .bak geri-alındı" >&2
      exit 1
    fi
    yazildi=1
    echo "[yeşil] provider-inventory: yazıldı (+.bak) — ingress:$([ "$ing_var" = "0" ] && echo eklendi || echo mevcut) · access_apps:$([ "$acc_var" = "0" ] && echo eklendi || echo mevcut)"
  fi

  if [ "$bkp_var" = "1" ]; then
    echo "[yeşil] backup.sh: $EY_CNAME docker-inspect listesinde mevcut → atla"
  else
    cp -a "$bkp" "$bkp.bak" || { echo "[kırmızı] .bak alınamadı: $bkp — dokunulmadı" >&2; exit 1; }
    if ! _eg_backup_ekle "$bkp" "$EY_CNAME"; then
      cp -a "$bkp.bak" "$bkp" || true
      echo "[kırmızı] backup.sh yazımı başarısız — .bak geri-alındı" >&2
      exit 1
    fi
    # B6 ayak-a: sözdizim-kapısı — bozuksa yazım GEÇERSİZ, .bak-restore + rc=1
    if ! bash -n "$bkp" 2>/dev/null; then
      cp -a "$bkp.bak" "$bkp" || true
      echo "[kırmızı] backup.sh bash -n sözdizim-kapısı DÜŞTÜ — .bak geri-alındı, yazım iptal (rc=1)" >&2
      exit 1
    fi
    yazildi=1
    echo "[yeşil] backup.sh: $EY_CNAME docker-inspect listesine eklendi (+.bak, bash -n temiz)"
  fi

  echo ""
  if [ "$yazildi" = "1" ]; then
    echo "== evergreen-kaydet bitti: $proje kalıcı-izleri manifestlerde (REPO-FIRST — commit/PR ayrı-adım; parity P8/P9 doğrular) =="
  else
    echo "== evergreen-kaydet bitti: $proje zaten tam-kayıtlı — no-op (idempotent, rc=0) =="
  fi
  exit 0
}

# ── sokum (k0083: TAM-SÖKÜM — "sökülemeyen sancak doğamaz" ilkesinin kapanış-yarısı) ──────
#
# NEDEN: İSKÂN'ın doğurduğu bir projeyi AYNI araçla, telafisiz-silme olmadan geri-alır:
# tmux-kapat → servis-scoped container-down → ingress-çıkar (+8-hostname sert-kapı) →
# CF-offboard (cf.sh delegesi) → 5-manifest LOKAL repo-first geri-alım → config-dizini ARŞİVE-TAŞI.
# Üç panzehir kod-seviyesinde (GEREKLILIK k0083 TASARIM-KARARLARI):
#  (1) GO-kapısı İLK adım: apply yalnız ISKAN_SOKUM_GO=1; marker-yokken host'a/CF'e/dosyaya
#      SIFIR-dokunuş (exit=4). dry-run DEFAULT (plan-exit=3).
#  (2) SERT-SINIRLAR: arg'sız `docker compose down` ve -v bayrağı YASAK (deneme-1 tam-filo
#      incident'i) — down HER ZAMAN servis-arg'lı tek-komut; silme YOK, tek meşru yol arşiv-taşıma.
#  (3) 8-HOSTNAME SERT-KAPI (7-prod + mihenk): ingress-çıkarma sonrası herhangi biri 302/401/403
#      dışına düşerse config.yml .bak-restore + cloudflared restart + exit=1.
# KOMŞU-KANIT: 7 komşu (6-çekirdek + mihenk) ÖNCE/SONRA StartedAt + config-hash; fark → exit=1.
# CF-silme cf.sh offboard'a DELEGE (ham-CF-API bu dosyaya gömülmez — token ikinci-yüzeye yayılmaz).

# _sokum_compose_cikar <dosya> <cname> — compose'dan servis-bloğunu (önündeki İSKÂN-yorum
# satırları + bir ayraç-boşluk dahil) çıkarır. Blok yoksa rc=2 (iz-yok), dosyaya dokunmaz.
_sokum_compose_cikar() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
path, cname = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
key = next((i for i, l in enumerate(lines) if re.match(r'^  ' + re.escape(cname) + r':\s*$', l)), None)
if key is None:
    sys.exit(2)
start = key
j = key - 1
while j >= 0 and re.match(r'^  #', lines[j]):
    start = j; j -= 1
if start > 0 and lines[start - 1].strip() == "":
    start -= 1
end = key + 1
while end < len(lines) and (lines[end].strip() == "" or lines[end].startswith("    ")):
    end += 1
while end - 1 > key and lines[end - 1].strip() == "":
    end -= 1                      # ayraç-boşluğu komşuya bırak (tek-blank separatör korunur)
del lines[start:end]
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PYEOF
}

# _sokum_satir_cikar <dosya> <token> — token geçen satırları çıkarır (case-insensitive:
# ISKANTEST_HOSTNAME de yakalanır); çıkan satır ingress `- hostname:` ise hemen-ardındaki
# `service:` satırı da (tokensiz eş) çıkar. Token yoksa rc=2, dosyaya dokunmaz.
_sokum_satir_cikar() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
path, token = sys.argv[1], sys.argv[2].lower()
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
out, skip_service, removed = [], False, 0
for l in lines:
    if skip_service and re.match(r'^\s*service:', l):
        skip_service = False; removed += 1; continue
    skip_service = False
    if token in l.lower():
        removed += 1
        if re.match(r'^\s*-\s*hostname:', l):
            skip_service = True
        continue
    out.append(l)
if removed == 0:
    sys.exit(2)
open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
PYEOF
}

# _sokum_backup_cikar <dosya> <token> — backup.sh docker-inspect argüman-listesinden container'ı
# çıkarır (satır SİLİNMEZ — komşu container'lar aynı satırda; _eg_backup_ekle'nin tersi).
# Token argüman-listesinde yoksa rc=2, dosyaya dokunmaz.
_sokum_backup_cikar() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
path, token = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8", errors="replace").read()
hit = [0]
def repl(m):
    args = m.group(2).split()
    if token not in args:
        return m.group(0)
    hit[0] += 1
    return m.group(1) + " ".join(a for a in args if a != token) + m.group(3)
yeni = re.sub(r"(?m)^(\s*docker inspect )([^>\n]*?)(\s*>)", repl, src, count=1)
if hit[0] == 0:
    sys.exit(2)
open(path, "w", encoding="utf-8").write(yeni)
PYEOF
}

# _sokum_registry_kunye_cikar <dosya> <proje> — iskan-registry'den künye-bloğunu çıkarır,
# dosyanın kendisi ve başlık-yorumları KALIR (aksiyon-6b: registry-dosyası silinmez).
# Dosyadaki künye başka projeninse ya da yoksa rc=2, dosyaya dokunmaz.
_sokum_registry_kunye_cikar() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
path, proje = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
if not any(re.match(r'^proje:\s*' + re.escape(proje) + r'\s*$', l) for l in lines):
    sys.exit(2)
head = []
for l in lines:
    if l.startswith("#"):
        head.append(l)
    else:
        break
open(path, "w", encoding="utf-8").write("\n".join(head) + "\n")
PYEOF
}

# _sokum_komsu_kanit <ssh_host> <komşu-listesi> — her komşu için "ad|StartedAt|config-md5" basar
_sokum_komsu_kanit() {
  local ssh_host="$1" komsular="$2" c
  for c in $komsular; do
    timeout 15 ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_host" \
      "printf '%s|%s|%s\n' '$c' \"\$(docker inspect -f '{{.State.StartedAt}}' $c 2>/dev/null)\" \"\$(docker inspect -f '{{json .Config}}' $c 2>/dev/null | md5sum | cut -d' ' -f1)\"" 2>/dev/null \
      || printf '%s|PROBE-FAIL|PROBE-FAIL\n' "$c"
  done
}

cmd_sokum() {
  local proje="" mode="dry-run"    # dry-run DEFAULT (GEREKLILIK: plan-önizleme exit=3)
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --apply) mode="apply"; shift ;;
      -*) echo "bilinmeyen argüman: $1" >&2; echo "kullanım: iskan.sh sokum <proje> [--dry-run|--apply]" >&2; exit 2 ;;
      *) proje="$1"; shift ;;
    esac
  done
  [ -n "$proje" ] || { echo "kullanım: iskan.sh sokum <proje> [--dry-run|--apply]" >&2; exit 2; }
  _ey_ad_hijyeni "$proje" "sokum" || exit 1

  # ── GO-KONTROLÜ = apply'ın İLK adımı (aksiyon-15): marker yoksa host'a/CF'e/dosyaya/ssh'a
  # SIFIR-dokunuş — bu satırın ÜSTÜNDE hiçbir probe/fetch/yazım yoktur.
  if [ "$mode" = "apply" ] && [ "${ISKAN_SOKUM_GO:-}" != "1" ]; then
    echo "[kırmızı] sokum --apply: Sultan-GO env-marker gerekli (ISKAN_SOKUM_GO=1) — host'a/CF'e/dosyaya SIFIR-dokunuş (DOCTRINE Değişmez-3)" >&2
    exit 4
  fi

  local repo_dir="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
  local ssh_host="${ISKAN_SSH_HOST:-hostsrv}"
  local host_root="${ISKAN_HOST_COMPOSE_ROOT:-/opt/cloudtop}"
  local host_compose="${ISKAN_HOST_COMPOSE:-$host_root/docker-compose.server.yml}"
  local cfd_config="${ISKAN_CLOUDFLARED_CONFIG:-/etc/cloudflared/config.yml}"
  local arsiv_root="${ISKAN_SOKUM_ARSIV_DIR:-$host_root/_sokum-arsiv}"
  local cf_sh="${ISKAN_CF_SH:-$HOME/.claude/skills/cloudflare-erisim/scripts/cf.sh}"
  local kanit_dir="${ISKAN_KANIT_DIR:-iskan/kanit/sokum}"
  local sokum_hosts="${ISKAN_SOKUM_HOSTS:-$ISKAN_PROD_HOSTS mihenk}"   # 8-set (aksiyon-7: +mihenk)
  local komsular="${ISKAN_SOKUM_KOMSULAR:-cloudtop cloudtop-code cloudtop-vekatip cloudtop-mmex cloudtop-medigate cloudtop-huma cloudtop-mihenk}"
  local cname="cloudtop-${proje}" hostname="${proje}.mmepanel.com"
  local host_cfg="$host_root/config-${proje}"

  # ── DURUM-TESPİTİ (aksiyon-10): K4 compose-kaydı → yoksa arşiv-probe ile üç-yol ayrımı ────
  # 'zaten-sokuk' = kayıt YOK ∧ arşiv VAR (rc=0, idempotent) · İKİSİ DE yok = 'kayitsiz-proje' (rc≠0).
  local cozum_out cozum_rc
  cozum_out="$(EY_REPO_DIR="$repo_dir" EY_CNAME="$cname" _ey_proje_cozumu "$proje" 2>&1)"; cozum_rc=$?
  if [ "$cozum_rc" != "0" ]; then
    if printf '%s' "$cozum_out" | grep -q 'kayitsiz-proje'; then
      local arsiv_izi=""
      arsiv_izi="$(timeout 15 ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_host" \
        "ls -d ${arsiv_root}/${proje}-* 2>/dev/null | head -1" 2>/dev/null || true)"
      if [ -n "$arsiv_izi" ]; then
        # P1d zaten-sokuk tamamlayıcısı: bayat kur-izi apply'da temizlenir (dry-run yazmaz, uyarır)
        local kur_state_zs dokunuldu=0
        kur_state_zs="$(_kur_state_path "$proje")"
        if [ -f "$kur_state_zs" ]; then
          if [ "$mode" = "apply" ]; then
            rm -f "$kur_state_zs"
            # MAJOR fix (ADIM-8 simetrisi): rm-başarısızlığı SESSİZ yutulmasın — re-check + kırmızı
            if [ -f "$kur_state_zs" ]; then
              echo "[kırmızı] bayat kur-durum-dosyası silinemedi: $kur_state_zs — elle sil (yoksa sonraki 'kur $proje --devam' sökülmüş projeyi yarım-kurulu sanar)" >&2
              exit 1
            fi
            echo "[yeşil] bayat kur-durum-dosyası temizlendi: $kur_state_zs (zaten-sokuk tamamlayıcısı)"
            dokunuldu=1
          else
            echo "[uyarı] bayat kur-durum-dosyası duruyor: $kur_state_zs — sokum --apply (ISKAN_SOKUM_GO=1) temizler"
          fi
        fi
        # 'dokunulmadı' çelişkisi fix: state silindiğinde iddiayı ayrıştır (host/CF/manifest'e dokunulmadı;
        # yalnız lokal kur-izi temizlendi) — Doğrulama Protokolü 'kanıtla' ruhu (silinen dosya = dokunuş)
        if [ "$dokunuldu" = "1" ]; then
          echo "[yeşil] zaten-sokuk: '$proje' compose-kaydı yok + arşiv-izi mevcut ($arsiv_izi) — söküm daha önce tamamlanmış; host/CF/manifest'e dokunulmadı, yalnız bayat lokal kur-izi temizlendi (idempotent, rc=0)"
        else
          echo "[yeşil] zaten-sokuk: '$proje' compose-kaydı yok + arşiv-izi mevcut ($arsiv_izi) — söküm daha önce tamamlanmış, hiçbir şeye dokunulmadı (idempotent, rc=0)"
        fi
        exit 0
      fi
      printf '%s\n' "$cozum_out" >&2
      echo "[kırmızı] sokum: '$proje' için ne compose-kaydı ne arşiv-izi var (arşiv-probe: ${arsiv_root}/${proje}-*) — kayitsiz-proje, hiçbir şeye dokunulmadı" >&2
      exit 1
    fi
    printf '%s\n' "$cozum_out" >&2
    exit 1
  fi
  printf '%s\n' "$cozum_out" | grep '^\[yeşil\] proje-çözümü' || true

  # 5-manifest (LOKAL repo-first geri-alım yüzeyi)
  local m_compose="$repo_dir/infra/docker-compose.server.yml"
  local m_tunnel="$repo_dir/infra/setup-tunnel.sh"
  local m_inv="$repo_dir/infra/provider-inventory.yaml"
  local m_bkp="$repo_dir/infra/backup.sh"
  local m_reg="$repo_dir/infra/iskan-registry.yaml"

  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN sokum — KURU-KOŞU (DEFAULT; host'a/CF'e/dosyaya SIFIR-dokunuş) =="
    echo "proje: $proje · container: $cname · hostname: $hostname · arşiv-hedefi: ${arsiv_root}/${proje}-<tarih>/"
    if command -v ssh >/dev/null 2>&1 && timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_host" true >/dev/null 2>&1; then
      echo "[yeşil] hostsrv-probe: taze ssh exit=0"
    else
      echo "[doğrulanmadı] $ssh_host erişilemedi — canlı-durum probu yapılamadı; plan varsayımsal-önizlendi"
    fi
    echo ""
    echo "-- PLAN (apply'da sırayla; İLK KIRMIZIDA DUR; telafisiz-silme YOK) --"
    echo "  0. KOMŞU-KANIT ÖNCE: $komsular → StartedAt + config-hash ($kanit_dir/komsu-once.txt)"
    echo "  1. tmux-seansları kapat: docker exec -u 1000 $cname tmux kill-server (container yoksa atla)"
    echo "  2. container-down YALNIZ servis-arg'lı (arg'sız down ve -v YASAK — aksiyon-16):"
    echo "     docker compose -f $host_compose down $cname"
    echo "  3. cloudflared ingress'ten $hostname çıkar (.bak'lı) + restart → 8-HOSTNAME SERT-KAPI"
    echo "     ($sokum_hosts): 302/401/403-dışı → .bak-restore + restart + exit=1"
    echo "  4. CF geri-alım: cf.sh offboard $hostname --apply (tek-kayıt-assertion cf.sh'te; delege)"
    echo "  5. 5-manifest LOKAL repo-first geri-alım (.bak'lı; tombstone/iz-sıfır assertion):"
    echo "     - $m_compose (servis-bloğu çıkar)"
    echo "     - $m_tunnel (hostname-satırları + ingress-çifti; bash -n kapısı)"
    echo "     - $m_inv (ingress + access_apps satırları)"
    echo "     - $m_bkp (docker-inspect argümanından $cname; bash -n kapısı)"
    echo "     - $m_reg (künye-bloğu çıkar; DOSYA SİLİNMEZ, başlık-yorumları kalır)"
    echo "  6. ARŞİVE-TAŞI (down-DOĞRULANDIKTAN sonra; aksiyon-11): $host_cfg → ${arsiv_root}/${proje}-<tarih>/"
    echo "     (taşıma-öncesi dosya-sayısı+du kanıta; mv = tek meşru yol, rm YOK)"
    echo "  7. KOMŞU-KANIT SONRA: StartedAt/config-hash ÖNCE ile bayt-eş değilse exit=1"
    echo "  8. kur-durum-dosyası temizliği: $(_kur_state_path "$proje") (varsa silinir — F4 söküm-oracle'ı: state-dosyası-silinmiş)"
    echo "== dry-run: hiçbir yazım/silme/API-çağrısı yapılmadı (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi

  # ═══ APPLY (ISKAN_SOKUM_GO=1 doğrulandı — yukarıdaki İLK-adım kapısında) ═══════════════════
  mkdir -p "$kanit_dir"
  echo "== İSKÂN sokum — CANLI-APPLY (Sultan-GO'lu) · $proje TAM-SÖKÜM =="

  # ön-kapılar: ssh + cf.sh offboard-yüzeyi + manifest-dosyaları
  if ! command -v ssh >/dev/null 2>&1 || ! timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_host" true >/dev/null 2>&1; then
    echo "[kırmızı] $ssh_host erişilemedi — hiçbir yere dokunulmadı" >&2; exit 1
  fi
  [ -f "$cf_sh" ] || { echo "[kırmızı] cf.sh bulunamadı: $cf_sh — hiçbir yere dokunulmadı" >&2; exit 1; }
  grep -q 'offboard' "$cf_sh" || { echo "[kırmızı] cf.sh'te offboard-komutu yok (ön-PR merge edilmemiş?) — hiçbir yere dokunulmadı" >&2; exit 1; }
  local f
  for f in "$m_compose" "$m_tunnel" "$m_inv" "$m_bkp" "$m_reg"; do
    [ -f "$f" ] || { echo "[kırmızı] manifest bulunamadı: $f — hiçbir yere dokunulmadı" >&2; exit 1; }
  done

  # ── ADIM-0: KOMŞU-KANIT ÖNCE + 8-hostname baseline ─────────────────────────────────────
  local komsu_once komsu_sonra
  komsu_once="$(_sokum_komsu_kanit "$ssh_host" "$komsular")"
  printf '%s\n' "$komsu_once" | tee "$kanit_dir/komsu-once.txt"
  if printf '%s' "$komsu_once" | grep -q 'PROBE-FAIL'; then
    echo "[kırmızı] komşu-kanıt ÖNCE eksik (PROBE-FAIL) — komşu-güvenliği kanıtlanamaz, DUR (hiçbir şeye dokunulmadı)" >&2
    exit 1
  fi
  local once sonra
  once="$(ISKAN_PROD_HOSTS="$sokum_hosts" _cf_yedi_hostname_olc)"
  printf 'ÖNCE : %s\n' "$once" | tee "$kanit_dir/sekiz-hostname-once.txt"
  if ! _cf_yedi_hostname_temiz_mi "$once"; then
    echo "[kırmızı] baseline zaten KİRLİ (302/401/403-dışı kod var) — dokunmadan DUR, SERDAR'a raporla" >&2
    exit 1
  fi

  # ── ADIM-1: tmux-seansları kapat (container ayakta değilse atla — down zaten hedef) ──────
  if [ "$(timeout 15 ssh -o BatchMode=yes "$ssh_host" "docker inspect -f '{{.State.Running}}' $cname 2>/dev/null" 2>/dev/null)" = "true" ]; then
    timeout 20 ssh -o BatchMode=yes "$ssh_host" "docker exec -u 1000 $cname tmux kill-server 2>/dev/null" >/dev/null 2>&1 || true
    echo "[yeşil] ADIM-1 tmux: kill-server gönderildi ($cname)"
  else
    echo "[yeşil] ADIM-1 tmux: $cname zaten ayakta değil → atla"
  fi

  # ── ADIM-2: container-down — YALNIZ servis-arg'lı (arg'sız down / -v YASAK, aksiyon-16) ──
  if ! timeout 120 ssh -o BatchMode=yes "$ssh_host" "docker compose -f $host_compose down $cname" > "$kanit_dir/compose-down.txt" 2>&1; then
    echo "[kırmızı] ADIM-2 compose-down başarısız — çıktı: $kanit_dir/compose-down.txt; DUR" >&2
    tail -5 "$kanit_dir/compose-down.txt" >&2
    exit 1
  fi
  if timeout 15 ssh -o BatchMode=yes "$ssh_host" "docker ps -a --format '{{.Names}}'" 2>/dev/null | grep -qx "$cname"; then
    echo "[kırmızı] ADIM-2 down-doğrulama düştü: $cname hâlâ docker ps -a'da — DUR (arşiv-taşıma yapılmadı)" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-2 container-down: $cname kaldırıldı (servis-scoped; komşulara dokunulmadı)"

  # ── ADIM-3: cloudflared ingress'ten hostname çıkar (.bak'lı) + restart + 8-HOSTNAME KAPI ──
  if ! timeout 15 ssh -o BatchMode=yes "$ssh_host" "cp -a $cfd_config ${cfd_config}.bak"; then
    echo "[kırmızı] ADIM-3 config.yml .bak alınamadı — ingress'e dokunulmadı, DUR" >&2
    exit 1
  fi
  # hostname-satırı + hemen-ardındaki service-satırı (2-satır ingress-öğesi) çıkar
  if ! timeout 15 ssh -o BatchMode=yes "$ssh_host" "sed -i '/hostname: ${hostname}/,+1d' $cfd_config"; then
    echo "[kırmızı] ADIM-3 ingress-çıkarma (sed) başarısız — .bak-restore" >&2
    timeout 60 ssh -o BatchMode=yes "$ssh_host" "cp -a ${cfd_config}.bak $cfd_config" || true
    exit 1
  fi
  # restart AYRI + uzun-tavan: cloudflared graceful-stop 90sn'e dek sürebilir (firsthand, canlı-koşu-1:
  # 20sn'de rc=124 'deactivating' — kısa-timeout sağlıklı restart'ı sahte-kırmızıya çevirdi)
  if ! timeout 200 ssh -o BatchMode=yes "$ssh_host" "systemctl restart cloudflared"; then
    echo "[kırmızı] ADIM-3 cloudflared restart başarısız — .bak-restore + restart" >&2
    timeout 200 ssh -o BatchMode=yes "$ssh_host" "cp -a ${cfd_config}.bak $cfd_config && systemctl restart cloudflared" || true
    exit 1
  fi
  sleep 5
  sonra="$(ISKAN_PROD_HOSTS="$sokum_hosts" _cf_yedi_hostname_olc)"
  printf 'SONRA: %s\n' "$sonra" | tee "$kanit_dir/sekiz-hostname-sonra.txt"
  if ! _cf_yedi_hostname_temiz_mi "$sonra"; then
    echo "[kırmızı] 8-HOSTNAME REGRESYON — OTO-GERİ-AL (.bak restore + cloudflared restart)" >&2
    timeout 200 ssh -o BatchMode=yes "$ssh_host" "cp -a ${cfd_config}.bak $cfd_config && systemctl restart cloudflared" || true
    sleep 5
    printf 'GERİ-AL-SONRASI: %s\n' "$(ISKAN_PROD_HOSTS="$sokum_hosts" _cf_yedi_hostname_olc)" | tee -a "$kanit_dir/sekiz-hostname-sonra.txt"
    echo "[kırmızı] DUR — SERDAR'a gözlenen-vs-beklenen raporla (kanıt: $kanit_dir/)" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-3 ingress-çıkarma + 8-hostname sert-kapı GEÇTİ (regresyon yok)"

  # ── ADIM-4: CF geri-alım — cf.sh offboard delegesi (tek-kayıt-assertion cf.sh içinde) ────
  if ! bash "$cf_sh" offboard "$hostname" --apply > "$kanit_dir/cf-offboard.txt" 2>&1; then
    echo "[kırmızı] ADIM-4 cf.sh offboard başarısız — çıktı: $kanit_dir/cf-offboard.txt; DUR" >&2
    tail -5 "$kanit_dir/cf-offboard.txt" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-4 cf-offboard tamam (Access-app + DNS-CNAME geri-alındı) — kanıt: $kanit_dir/cf-offboard.txt"

  # ── ADIM-5: 5-manifest LOKAL repo-first geri-alım (.bak'lı; iz-sıfır assertion) ──────────
  local rc
  for f in "$m_compose" "$m_tunnel" "$m_inv" "$m_bkp" "$m_reg"; do
    cp -a "$f" "$f.bak" || { echo "[kırmızı] .bak alınamadı: $f — bu dosyaya dokunulmadı, DUR" >&2; exit 1; }
  done
  _sokum_compose_cikar "$m_compose" "$cname"; rc=$?
  case "$rc" in
    0) echo "[yeşil] ADIM-5 compose: $cname servis-bloğu çıkarıldı" ;;
    2) echo "[yeşil] ADIM-5 compose: iz yok → atla" ;;
    *) cp -a "$m_compose.bak" "$m_compose" || true; echo "[kırmızı] ADIM-5 compose-çıkarma başarısız — .bak geri-alındı, DUR" >&2; exit 1 ;;
  esac
  _sokum_satir_cikar "$m_tunnel" "$proje"; rc=$?
  case "$rc" in
    0) if bash -n "$m_tunnel" 2>/dev/null; then
         echo "[yeşil] ADIM-5 setup-tunnel: $proje satırları çıkarıldı (bash -n temiz)"
       else
         cp -a "$m_tunnel.bak" "$m_tunnel" || true
         echo "[kırmızı] ADIM-5 setup-tunnel bash -n kapısı DÜŞTÜ — .bak geri-alındı, DUR" >&2; exit 1
       fi ;;
    2) echo "[yeşil] ADIM-5 setup-tunnel: iz yok → atla" ;;
    *) cp -a "$m_tunnel.bak" "$m_tunnel" || true; echo "[kırmızı] ADIM-5 setup-tunnel çıkarma başarısız — .bak geri-alındı, DUR" >&2; exit 1 ;;
  esac
  _sokum_satir_cikar "$m_inv" "$proje"; rc=$?
  case "$rc" in
    0) echo "[yeşil] ADIM-5 provider-inventory: $proje satırları çıkarıldı" ;;
    2) echo "[yeşil] ADIM-5 provider-inventory: iz yok → atla" ;;
    *) cp -a "$m_inv.bak" "$m_inv" || true; echo "[kırmızı] ADIM-5 provider-inventory çıkarma başarısız — .bak geri-alındı, DUR" >&2; exit 1 ;;
  esac
  _sokum_backup_cikar "$m_bkp" "$cname"; rc=$?
  case "$rc" in
    0) if bash -n "$m_bkp" 2>/dev/null; then
         echo "[yeşil] ADIM-5 backup.sh: $cname docker-inspect listesinden çıkarıldı (bash -n temiz)"
       else
         cp -a "$m_bkp.bak" "$m_bkp" || true
         echo "[kırmızı] ADIM-5 backup.sh bash -n kapısı DÜŞTÜ — .bak geri-alındı, DUR" >&2; exit 1
       fi ;;
    2) echo "[yeşil] ADIM-5 backup.sh: iz yok → atla" ;;
    *) cp -a "$m_bkp.bak" "$m_bkp" || true; echo "[kırmızı] ADIM-5 backup.sh çıkarma başarısız — .bak geri-alındı, DUR" >&2; exit 1 ;;
  esac
  _sokum_registry_kunye_cikar "$m_reg" "$proje"; rc=$?
  case "$rc" in
    0) echo "[yeşil] ADIM-5 iskan-registry: $proje künye-bloğu çıkarıldı (dosya + başlık-yorumları KALDI)" ;;
    2) echo "[yeşil] ADIM-5 iskan-registry: künye başka projenin / iz yok → atla" ;;
    *) cp -a "$m_reg.bak" "$m_reg" || true; echo "[kırmızı] ADIM-5 iskan-registry çıkarma başarısız — .bak geri-alındı, DUR" >&2; exit 1 ;;
  esac
  # tombstone-yasak assertion (aksiyon-14): 5 dosyada iz SIFIR olmalı
  local iz_toplam=0 n
  for f in "$m_compose" "$m_tunnel" "$m_inv" "$m_bkp" "$m_reg"; do
    n="$(grep -ci "$proje" "$f" 2>/dev/null || true)"
    [ "$n" = "0" ] || { echo "[kırmızı] iz-sıfır assertion düştü: $f içinde $n '$proje' izi kaldı" >&2; iz_toplam=$((iz_toplam + n)); }
  done
  [ "$iz_toplam" = "0" ] || { echo "[kırmızı] ADIM-5 tombstone-yasak assertion başarısız — .bak'lardan incele, DUR" >&2; exit 1; }
  echo "[yeşil] ADIM-5 iz-sıfır assertion: 5 manifest '$proje'-izi 0 (.bak'lar working-tree'de, COMMIT'LENMEZ)"

  # ── ADIM-6: config-dizini ARŞİVE-TAŞI (down ADIM-2'de doğrulandı; aksiyon-11) ────────────
  local tarih arsiv_hedef
  tarih="$(date +%F)"
  arsiv_hedef="${arsiv_root}/${proje}-${tarih}"
  if timeout 15 ssh -o BatchMode=yes "$ssh_host" "test -d '$host_cfg'" 2>/dev/null; then
    if timeout 15 ssh -o BatchMode=yes "$ssh_host" "test -e '$arsiv_hedef'" 2>/dev/null; then
      echo "[kırmızı] ADIM-6 arşiv-hedefi zaten var: $arsiv_hedef — üzerine-taşıma YAPILMAZ, DUR" >&2
      exit 1
    fi
    timeout 30 ssh -o BatchMode=yes "$ssh_host" \
      "printf 'dosya-sayısı=%s du=%s\n' \"\$(find '$host_cfg' | wc -l)\" \"\$(du -sh '$host_cfg' | cut -f1)\"" \
      2>/dev/null | tee "$kanit_dir/arsiv-kanit.txt"
    if ! timeout 60 ssh -o BatchMode=yes "$ssh_host" "mkdir -p '$arsiv_root' && mv '$host_cfg' '$arsiv_hedef'"; then
      echo "[kırmızı] ADIM-6 arşiv-taşıma başarısız — config-dizini yerinde duruyor, DUR" >&2
      exit 1
    fi
    timeout 30 ssh -o BatchMode=yes "$ssh_host" \
      "printf 'arşiv-sonrası: config-dir=%s arşiv-ilk-yol=%s\n' \"\$(test -d '$host_cfg' && echo VAR || echo YOK)\" \"\$(find '$arsiv_hedef' -mindepth 1 -print -quit)\"" \
      2>/dev/null | tee -a "$kanit_dir/arsiv-kanit.txt"
    echo "[yeşil] ADIM-6 arşiv: $host_cfg → $arsiv_hedef (mv; telafisiz-silme YOK)"
  else
    echo "[doğrulanmadı] ADIM-6: $host_cfg host'ta yok — arşiv-taşıma atlandı (daha önce taşınmış olabilir)"
  fi

  # ── ADIM-7: KOMŞU-KANIT SONRA (aksiyon-8): ÖNCE ile bayt-eş değilse exit=1 ───────────────
  komsu_sonra="$(_sokum_komsu_kanit "$ssh_host" "$komsular")"
  printf '%s\n' "$komsu_sonra" | tee "$kanit_dir/komsu-sonra.txt"
  if [ "$komsu_once" != "$komsu_sonra" ]; then
    echo "[kırmızı] KOMŞU-KANIT FARKI: söküm sırasında bir komşunun StartedAt/config-hash'i değişti — diff'i incele ($kanit_dir/komsu-once.txt vs komsu-sonra.txt), SERDAR'a raporla" >&2
    exit 1
  fi
  echo "[yeşil] ADIM-7 komşu-kanıt: $komsular ÖNCE=SONRA bayt-eş (recreate/restart=0)"

  # ── ADIM-8: kur-durum-dosyası temizliği (P1d) — söküm-sonrası bayat kur-izi kalmasın ─────
  # (kalırsa bir-sonraki 'kur <proje>' sökülmüş projeyi --devam ile "yarım-kurulu" sanır;
  # F4 söküm-rubriğinin 'state-dosyası-silinmiş' oracle'ı bu mekanizmaya bağlı)
  local kur_state
  kur_state="$(_kur_state_path "$proje")"
  if [ -f "$kur_state" ]; then
    rm -f "$kur_state"
    if [ -f "$kur_state" ]; then
      echo "[kırmızı] ADIM-8 kur-durum-dosyası silinemedi: $kur_state — elle sil, söküm diğer-adımlarıyla TAMAM" >&2
      exit 1
    fi
    echo "[yeşil] ADIM-8 kur-durum-dosyası silindi: $kur_state"
  else
    echo "[yeşil] ADIM-8 kur-durum-dosyası zaten yok: $kur_state"
  fi

  echo ""
  echo "== sokum bitti: $proje TAM-SÖKÜLDÜ — container-down + CF-geri-alım + 5-manifest iz-sıfır (lokal, commit/PR ayrı-adım) + arşiv dolu + kur-izi temiz · kanıt: $kanit_dir/ =="
  exit 0
}

# ── kur (D6: UC1 tam-yaşamdöngüsü ZİNCİRLEYİCİSİ — duraklı durum-makinesi) ────────────────
#
# NEDEN: mimSerdar §4.2 — "komut duraklı bir durum-makinesidir". kur HİÇBİR alt-komutu yeniden
# yazmaz: mevcut alt-komutları CLI-invoke ederek FAZ-sırasıyla BESTELER (owner-domain-dokunma
# ruhu içeride de geçerli — alt-komut sözleşmeleri kur'un kanonu). GO-marker'ları ASLA bypass
# etmez ve KENDİSİ export ETMEZ: her adım kendi GO'sunu (ISKAN_FAZ4_GO/FAZ9_GO/FAZ5_GO) kendi
# ortamından bekler; kur yalnız SIRALAR ve durumu raporlar (GO-yok exit=4 AYNEN iletilir).
#
# ZİNCİR (UC1 tam-yaşamdöngüsü, FAZ-sırası):
#   1. yeni-proje --dry-run → --apply   compose-blok repo-yazımı        (ISKAN_FAZ4_GO)
#   2. DURAK-1: cloudtop-PR merge       REPO-FIRST İNSAN-durağı — origin/main'de compose-blok
#                                       görünene dek zincir bekler (exit=0 "adım-tamam"; --devam)
#   3. iskan-host.sh --apply --proje    host-doğum (servis-scoped up)   (ISKAN_FAZ4_GO)
#   4. provizyon --apply                container-İÇİ dev-araç kurulumu (ISKAN_FAZ9_GO)
#   5. cf-yayin --apply                 CF-hostname yayını              (ISKAN_FAZ5_GO)
#   6. ekip-yerlestir --apply           ekip-yerleştirme                (GO'suz, FAZ-6 sözleşmesi)
#   7. evergreen-kaydet --apply         kalıcı-iz manifest-yazımı       (host-apply yok)
#
# Durum-dosyası: ${ISKAN_STATE_DIR:-$HOME/.claude}/iskan-kur-<proje>.state — git-DIŞI, tek-satır:
# son-tamamlanan-adım-adı. --devam oradan sürer · --durum salt-oku basar · dosya yoksa baştan.
# --dry-run: TÜM zincir dry-run modunda uçtan-uca (hiçbir yazma — durum-dosyası DAHİL), exit=3.
# Fail-closed: ilk kırmızıda DUR (adım-adı + exit-code + remediation); sonraki adıma atlamak YASAK.
# 3-Çit: mahrem-tenant adları (vekatip/mmex/medigate/huma/mihenk) İSKÂN-doğumu DEĞİLDİR → RED.
# Exit-kontratı (aile-uyumlu): 0 adım/zincir-tamam · 1 genel-fail · 2 usage · 3 dry-run-plan ·
# 4 GO-yok (alt-komuttan AYNEN iletilir).

ISKAN_KUR_ADIMLAR="yeni-proje durak1-cloudtop-pr iskan-host provizyon cf-yayin ekip-yerlestir evergreen-kaydet"
ISKAN_KUR_IZOLE="vekatip mmex medigate huma mihenk"

_kur_state_path() { echo "${ISKAN_STATE_DIR:-$HOME/.claude}/iskan-kur-$1.state"; }

_kur_state_yaz() { # <state-dosyası> <adım-adı> — git-DIŞI durum-dosyasına son-tamamlanan adımı yazar
  mkdir -p "$(dirname "$1")" 2>/dev/null || return 1
  printf '%s\n' "$2" > "$1"
}

_kur_adim_no() { # <adım-adı> → 1..7 (bilinmeyen → 0)
  local i=0 a
  for a in $ISKAN_KUR_ADIMLAR; do
    i=$((i + 1))
    [ "$a" = "$1" ] && { echo "$i"; return 0; }
  done
  echo 0
}

_kur_adim_ad() { # <1..7> → adım-adı
  local i=0 a
  for a in $ISKAN_KUR_ADIMLAR; do
    i=$((i + 1))
    [ "$i" = "$1" ] && { echo "$a"; return 0; }
  done
}

_kur_go_marker() { # <adım-adı> → adımın beklediği Sultan-GO marker-ADI (GO'suz adımda boş)
  case "$1" in
    yeni-proje|iskan-host) echo "ISKAN_FAZ4_GO" ;;
    provizyon) echo "ISKAN_FAZ9_GO" ;;
    cf-yayin) echo "ISKAN_FAZ5_GO" ;;
    *) echo "" ;;
  esac
}

# _kur_cli <adım> <proje> <mod:dry-run|apply> — alt-komutu CLI-invoke eder (besteler, YENİDEN
# YAZMAZ; env aynen akar → GO-marker'lar adımın kendi ortamından okunur, kur dokunmaz).
_kur_cli() {
  local adim="$1" proje="$2" mod="$3"
  if [ "$adim" = "iskan-host" ]; then
    if [ "$mod" = "dry-run" ]; then
      bash "$SCRIPT_DIR/iskan-host.sh" --dry-run
    else
      bash "$SCRIPT_DIR/iskan-host.sh" --apply --proje "$proje"
    fi
    return $?
  fi
  bash "$SCRIPT_DIR/iskan.sh" "$adim" "$proje" "--$mod"
}

# _kur_durak1_probe <cname> [no-fetch] — DURAK-1 REPO-FIRST salt-oku probe'u: compose-blok cloudtop
# origin/main'de görünüyor mu? rc=0 görünür · rc=1 görünmez (merge bekleniyor) · rc=2 ölçülemedi.
# no-fetch (re-verify MINOR fix): --durum "salt-oku, hiçbir dosya yazılmaz" sözleşmesindedir —
# fetch .git metadata (FETCH_HEAD/refs) yazar. --durum çağrısı fetch'i ATLAR (son-fetch'lenmiş
# origin/main'i okur); zincir/devam/dry-run zaten ağ-probe'u yapan akışlar → fetch'lerini korur.
_kur_durak1_probe() {
  local cname="$1" repo_dir="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
  command -v git >/dev/null 2>&1 || return 2
  [ -e "$repo_dir/.git" ] || return 2
  [ "${2:-}" = "no-fetch" ] || git -C "$repo_dir" fetch -q origin main 2>/dev/null || true   # offline'da son-fetch'lenmiş origin/main
  local compose_main
  compose_main="$(git -C "$repo_dir" show origin/main:infra/docker-compose.server.yml 2>/dev/null)"
  [ -n "$compose_main" ] || return 2
  printf '%s\n' "$compose_main" | grep -qE "container_name:[[:space:]]*${cname}\$"
}

cmd_kur() {
  local proje="" mode="zincir" benimse=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --devam) mode="devam"; shift ;;
      --durum) mode="durum"; shift ;;
      --benimse) benimse=1; shift ;;
      -*) echo "bilinmeyen argüman: $1" >&2; echo "kullanım: iskan.sh kur <proje> [--dry-run|--devam|--durum] [--benimse]" >&2; exit 2 ;;
      *) proje="$1"; shift ;;
    esac
  done
  [ -n "$proje" ] || { echo "kullanım: iskan.sh kur <proje> [--dry-run|--devam|--durum] [--benimse]" >&2; exit 2; }
  _ey_ad_hijyeni "$proje" "kur" || exit 1

  # ── 3-Çit: mahrem-tenant reddi (her moddan ÖNCE — izole aile İSKÂN-doğumu değildir) ──────
  local proje_kucuk iz
  proje_kucuk="$(printf '%s' "$proje" | tr '[:upper:]' '[:lower:]')"
  for iz in $ISKAN_KUR_IZOLE; do
    if [ "$proje_kucuk" = "$iz" ]; then
      echo "[kırmızı] 3-Çit: '$proje' mahrem-tenant sınıfı (izole-container ailesi: $ISKAN_KUR_IZOLE) — İSKÂN-doğumu DEĞİL, kur REDDEDİLDİ (hiçbir adım koşulmadı, hiçbir yere dokunulmadı)" >&2
      exit 1
    fi
  done

  local cname="cloudtop-${proje}" state_file son_adim="" n
  state_file="$(_kur_state_path "$proje")"
  [ -f "$state_file" ] && son_adim="$(head -1 "$state_file" | tr -d '[:space:]')"

  # benimse-rızası resume-komutlarında TAŞINIR (MAJOR fix): slug-kapısı yalnız state-boşken ateşler;
  # adım-1 GO-durağında exit=4 olunca state yazılmaz → sonraki --devam de state-boş → kapı yeniden
  # ateşler. Bu yüzden bastığımız her resume-komutu '--benimse'yi korumalı ki tavsiyeyi izleyen
  # kullanıcı kapıya yeniden çarpmasın (herhangi bir adım tamamlanınca state dolar, kapı susar).
  local benimse_suffix=""
  [ "$benimse" = "1" ] && benimse_suffix=" --benimse"

  # ── SLUG ŞÜPHELİ-DURUM KAPISI (G-b, P1f): compose-kaydı (origin/main) VAR ∧ bu makinede
  # kur-izi YOK → container bu zincirden doğmamış (yaşayan/prod container ya da başka-makine
  # doğumu olabilir). Adımların idempotent-geçişleri onu sessizce benimseyip İÇİNE tmux-ekip
  # yerleştirebilirdi (3-Çit yalnız 5 mahrem adı tanır) → zincir/devam modunda fail-closed RED;
  # bilinçli-devralma `--benimse` ile. dry-run salt-oku olduğundan RED edilmez, uyarı basılır.
  # probe rc=2 (ölçülemedi) kapıyı tetiklemez — zincirin kendi DURAK-1'i zaten fail-closed ölçer.
  if [ "$mode" != "durum" ] && [ -z "$son_adim" ] && _kur_durak1_probe "$cname"; then
    if [ "$benimse" = "1" ]; then
      if [ "$mode" = "dry-run" ]; then
        echo "[uyarı] slug-kapısı önizleme: '$cname' compose'da (origin/main) kayıtlı, kur-izi yok — --benimse verildi (gerçek koşuda BİLİNÇLİ-devralınır; bu dry-run hiçbir şey yazmaz)"
      else
        echo "[uyarı] slug-kapısı: '$cname' compose'da (origin/main) kayıtlı ama bu makinede kur-izi yok — --benimse ile BİLİNÇLİ-devralındı (adımlar idempotent-geçişlerle sürer)"
      fi
    elif [ "$mode" = "dry-run" ]; then
      echo "[uyarı] slug-kapısı önizleme: '$cname' compose'da (origin/main) ZATEN kayıtlı ama bu makinede kur-izi yok ($state_file) — gerçek koşu REDDEDİLİR; bilinçli-devralma: bash iskan.sh kur $proje --benimse"
    else
      echo "[kırmızı] slug-kapısı: '$cname' compose'da (origin/main) ZATEN kayıtlı AMA bu makinede kur-izi yok ($state_file) — mevcut/yaşayan container'a zincir-yerleşimi riski (G-b), hiçbir adım koşulmadı; bilinçli-devralma: bash iskan.sh kur $proje --benimse" >&2
      exit 1
    fi
  fi

  # ── --durum: salt-oku durum-raporu (hiçbir adım koşulmaz, hiçbir dosya yazılmaz) ─────────
  if [ "$mode" = "durum" ]; then
    echo "== İSKÂN kur — DURUM (salt-oku) =="
    echo "proje: $proje · durum-dosyası: $state_file"
    if [ -z "$son_adim" ]; then
      echo "durum: hiç koşulmamış — zincir baştan başlar (adım 1/7: yeni-proje)"
      if _kur_durak1_probe "$cname" no-fetch; then
        echo "not: '$cname' compose'da (origin/main) ZATEN kayıtlı ama kur-izi yok → çıplak 'kur' slug-kapısında REDDEDİLİR; bilinçli-devralma gerekir: bash iskan.sh kur $proje --benimse"
      fi
    else
      n="$(_kur_adim_no "$son_adim")"
      if [ "$n" = "0" ]; then
        echo "[doğrulanmadı] durum-dosyası tanınmayan adım-adı içeriyor: '$son_adim' — dosyayı incele/sil, zincir baştan güvenli (adımlar idempotent)"
      elif [ "$n" -ge 7 ]; then
        echo "son-tamamlanan: $son_adim (adım $n/7)"
        echo "durum: zincir TAMAM (7/7) — yapılacak adım kalmadı"
      else
        echo "son-tamamlanan: $son_adim (adım $n/7)"
        echo "sıradaki: $(_kur_adim_ad $((n + 1))) (adım $((n + 1))/7) — sürdürmek için: bash iskan.sh kur $proje --devam$benimse_suffix"
      fi
    fi
    exit 0
  fi

  # ── başlangıç-adımı çözümü ────────────────────────────────────────────────────────────────
  local baslangic=1
  if [ "$mode" = "devam" ]; then
    if [ -n "$son_adim" ]; then
      n="$(_kur_adim_no "$son_adim")"
      if [ "$n" = "0" ]; then
        echo "[kırmızı] kur --devam: durum-dosyası tanınmayan adım-adı içeriyor ('$son_adim') — dosyayı incele/sil ($state_file), sonra baştan koş (fail-closed)" >&2
        exit 1
      fi
      if [ "$n" -ge 7 ]; then
        echo "[yeşil] kur --devam: zincir zaten TAMAM (son-tamamlanan: $son_adim, 7/7) — no-op"
        exit 0
      fi
      baslangic=$((n + 1))
      echo "[yeşil] kur --devam: son-tamamlanan=$son_adim → adım $baslangic/7'den sürülüyor (kaynak: $state_file)"
    else
      echo "[doğrulanmadı] kur --devam: durum-dosyası yok ($state_file) — baştan başlanıyor (adım 1/7)"
    fi
  elif [ "$mode" = "zincir" ] && [ -n "$son_adim" ]; then
    echo "[uyarı] durum-dosyası mevcut (son-tamamlanan: $son_adim) — baştan koşuluyor (adımlar idempotent); kaldığın yerden sürmek için: bash iskan.sh kur $proje --devam$benimse_suffix"
  fi

  if [ "$mode" = "dry-run" ]; then
    echo "== İSKÂN kur — ZİNCİR KURU-KOŞU (7 adım uçtan-uca dry-run; hiçbir yazma — durum-dosyası DAHİL) =="
  else
    echo "== İSKÂN kur — ZİNCİR (duraklı durum-makinesi; GO-marker'lar bypass EDİLMEZ, yalnız sıralanır) =="
  fi
  echo "proje: $proje · container: $cname · durum-dosyası: $state_file"

  local i adim rc out go
  for i in 1 2 3 4 5 6 7; do
    [ "$i" -lt "$baslangic" ] && continue
    adim="$(_kur_adim_ad "$i")"
    echo ""
    echo "──── kur adım $i/7: $adim ────"

    # ── DURAK-1 (adım 2): CLI-invoke değil, REPO-FIRST İNSAN-durağı (salt-oku probe) ────────
    if [ "$adim" = "durak1-cloudtop-pr" ]; then
      _kur_durak1_probe "$cname"; rc=$?
      if [ "$rc" = "0" ]; then
        echo "[yeşil] DURAK-1: '$cname' compose-bloğu cloudtop origin/main'de GÖRÜNÜYOR — merge tamam, zincir sürüyor"
        [ "$mode" = "dry-run" ] || _kur_state_yaz "$state_file" "$adim" || { echo "[kırmızı] durum-dosyası yazılamadı: $state_file" >&2; exit 1; }
        continue
      fi
      if [ "$mode" = "dry-run" ]; then
        if [ "$rc" = "2" ]; then
          echo "[doğrulanmadı] DURAK-1 önizleme: cloudtop-repo/origin-main okunamadı — gerçek koşuda ölçülemezse zincir DURur (fail-closed)"
        else
          echo "[doğrulanmadı] DURAK-1 önizleme: '$cname' origin/main'de henüz YOK — gerçek koşuda zincir burada DURur (cloudtop-PR merge beklenir)"
        fi
        continue
      fi
      if [ "$rc" = "2" ]; then
        echo "[kırmızı] DURAK-1 ölçülemedi: cloudtop-repo/origin-main okunamadı (fail-closed, ilerlenmedi) — remediation: ISKAN_CLOUDTOP_REPO_DIR + git-erişimini kontrol et" >&2
        exit 1
      fi
      echo ""
      echo "== kur DURAK-1'de duraklatıldı (hata DEĞİL — İNSAN-durağı, exit=0 adım-tamam) =="
      echo "   Sultan-dili: yeni container'ın tarifi (compose-bloğu) cloudtop deposuna yazıldı ama henüz"
      echo "   ana-dala alınmadı. Sıradaki el İNSANDA: cloudtop-PR'ı aç/merge et; origin/main'de blok"
      echo "   görününce zinciri sürdür: bash iskan.sh kur $proje --devam$benimse_suffix"
      echo "   (REPO-FIRST güvencesi: merge görünmeden host-adımı (adım 3) zaten kendini REDDeder.)"
      exit 0
    fi

    # ── normal adım: mevcut alt-komut CLI-invoke (kur hiçbirini yeniden yazmaz) ──────────────
    if [ "$mode" = "dry-run" ]; then
      out="$(_kur_cli "$adim" "$proje" dry-run 2>&1)"; rc=$?
      printf '%s\n' "$out"
      if [ "$rc" = "3" ]; then
        echo "[yeşil] kur-plan: '$adim' dry-run plan-exit=3 (yazma yok)"
        continue
      fi
      # DURAK-1-bağımlı bekleyen-durumlar: doğum-öncesi 'kayitsiz-proje' ve roster-doğmamışlık
      # dry-run'da kırmızı DEĞİL doğrulanmadı'dır (gerçek koşuda DURAK-1/roster-kaynağı çözer).
      if printf '%s' "$out" | grep -q 'kayitsiz-proje'; then
        echo "[doğrulanmadı] kur-plan: '$adim' şu an 'kayitsiz-proje' der (exit=$rc) — DURAK-1 merge'i SONRASI kayıtlı olur; zincir-önizlemesi sürüyor"
        continue
      fi
      if printf '%s' "$out" | grep -q 'roster-kaynağı yok'; then
        echo "[doğrulanmadı] kur-plan: '$adim' roster-kaynağı bekliyor (exit=$rc) — gerçek koşuda ISKAN_EY_ROSTER ver ya da ekip-registry.yaml doğmuş olmalı; zincir-önizlemesi sürüyor"
        continue
      fi
      echo "[kırmızı] kur-plan: '$adim' dry-run beklenmeyen exit=$rc (plan-exit=3 değil) — zincir-önizlemesi DURDU (fail-closed); remediation: adımı tek-başına koş + çıktıyı incele" >&2
      exit 1
    fi

    # apply: adım-1'de sözleşme gereği ÖNCE önizleme (yeni-proje --dry-run → --apply)
    if [ "$adim" = "yeni-proje" ]; then
      out="$(_kur_cli yeni-proje "$proje" dry-run 2>&1)"; rc=$?
      printf '%s\n' "$out"
      if [ "$rc" != "3" ]; then
        echo "[kırmızı] kur adım 1/7 önizlemesi: yeni-proje --dry-run beklenmeyen exit=$rc (plan-exit=3 değil) — DUR (fail-closed); remediation: yeni-proje'yi tek-başına koş" >&2
        exit 1
      fi
    fi
    _kur_cli "$adim" "$proje" apply
    rc=$?
    if [ "$rc" = "0" ]; then
      _kur_state_yaz "$state_file" "$adim" || { echo "[kırmızı] durum-dosyası yazılamadı: $state_file" >&2; exit 1; }
      echo "[yeşil] kur adım $i/7 tamam: $adim (durum-dosyasına işlendi)"
      continue
    fi
    if [ "$rc" = "4" ]; then
      go="$(_kur_go_marker "$adim")"
      {
        echo ""
        echo "== kur GO-durağında DURDU (adım $i/7: $adim — alt-komutun exit=4'ü AYNEN iletiliyor) =="
        echo "   Sultan-dili: bu adım Sultan'ın açık onay-işaretini bekliyor: ${go:-adımın kendi GO-markeri}."
        echo "   kur GO'yu ASLA kendisi vermez/export etmez; onay verilince adımın ortamında ${go:-GO}=1 ile:"
        echo "   bash iskan.sh kur $proje --devam$benimse_suffix"
      } >&2
      exit 4
    fi
    {
      echo ""
      echo "[kırmızı] kur adım $i/7 KIRMIZI: $adim exit=$rc — zincir DURDU (fail-closed; sonraki adıma ATLANMADI)"
      echo "   remediation: yukarıdaki adım-çıktısını incele; adımı tek-başına koş → düzelince: bash iskan.sh kur $proje --devam$benimse_suffix"
    } >&2
    exit 1
  done

  if [ "$mode" = "dry-run" ]; then
    echo ""
    echo "== kur dry-run: 7-adım zincir-planı uçtan-uca basıldı; hiçbir yazım yapılmadı — durum-dosyası dahil (plan-exit sözleşmesi, exit=3) =="
    exit 3
  fi
  echo ""
  echo "== kur zincir TAMAM: $proje 7/7 — durum-dosyası: $state_file =="
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
  evergreen-kaydet)
    shift
    cmd_evergreen_kaydet "$@"
    ;;
  provizyon)
    shift
    cmd_provizyon "$@"
    ;;
  sokum)
    shift
    cmd_sokum "$@"
    ;;
  kur)
    shift
    cmd_kur "$@"
    ;;
  *)
    echo "kullanım: iskan.sh doctor | iskan.sh seans-getir --container <ad> [--apply] | iskan.sh yeni-proje <ad> [--mem-limit <val>] [--port <n>] --dry-run|--apply | iskan.sh cf-yayin <proje> --dry-run|--apply | iskan.sh ekip-yerlestir <proje> --dry-run|--apply | iskan.sh uye-ekle <proje> <uye> [--gorev <görev>] --dry-run|--apply | iskan.sh evergreen-kaydet <proje> --dry-run|--apply | iskan.sh provizyon <proje> [--apply] | iskan.sh sokum <proje> [--dry-run|--apply] | iskan.sh kur <proje> [--dry-run|--devam|--durum] [--benimse]" >&2
    exit 2
    ;;
esac
