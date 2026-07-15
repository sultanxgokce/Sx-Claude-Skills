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

  if [ "$apply" -eq 1 ]; then
    echo "[kırmızı] seans-getir --apply: FAZ-3 Sultan-GO gerekli — bu fazda --apply ÇALIŞMAZ (bkz DOCTRINE Değişmez-3, K3 madde-4)" >&2
    exit 4
  fi

  echo "== İSKÂN seans-getir — KURU-KOŞU (DEFAULT; hiçbir seans açmaz/kapamaz/yazmaz) =="
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
    echo "== bitti — kuru-koşu, hiçbir yazım yapılmadı (plan-exit) =="
    exit 3
  fi

  echo ""
  echo "-- kapalı-üyeler (kaynak: aile-registry, tmux-ls ile karşılaştırıldı) --"
  local rol tmux_adi
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
      continue
    fi

    # (c) legacy-kimlik-imza eşleme (transkript-başı grep, İ3-uyumlu: yalnız dosya-adı/id konuşulur)
    eslesenler="$(_identity_imza_ara "$rol" "$transkript_dizin")"
    n_eslesen=0
    [ -n "$eslesenler" ] && n_eslesen="$(($(printf '%s' "$eslesenler" | tr -cd ',' | wc -c) + 1))"
    if [ "$n_eslesen" -eq 1 ]; then
      echo "  → (c) legacy-kimlik-imza: TEK-anlamlı eşleşme (session-id=$eslesenler) — resume-source=legacy-transkript"
    elif [ "$n_eslesen" -gt 1 ]; then
      echo "  → (c) legacy-kimlik-imza: ${n_eslesen} ADAY (belirsiz) — SUSPECT-mismatch etiketli, sessiz-devam YASAK; gerçek-apply'de --fork-session + Sultan'a-sor"
    else
      echo "  → (c) legacy-kimlik-imza: 0 aday — resume-source=degraded-replay (dosya-tabanlı replay: kimlik+STATE/LEDGER/handoff), AÇIK-etiketli"
    fi
  done <<< "$olu_roller"

  echo ""
  echo "== bitti — kuru-koşu, hiçbir tmux/claude-process açılmadı/kapanmadı, hiçbir dosya yazılmadı (plan-exit) =="
  exit 3
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
  *)
    echo "kullanım: iskan.sh doctor | iskan.sh seans-getir --container <ad> [--apply]" >&2
    exit 2
    ;;
esac
