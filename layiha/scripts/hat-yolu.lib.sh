#!/usr/bin/env bash
# hat-yolu.lib.sh — layiha/fikir-hattının TEK yol-çözüm kapısı (L24 F1).
#
# NE: layiha hattının tüm veri-artefaktlarının (defter · aday-havuzu · bulgu-havuzu · MUCİT defteri ·
#   KAŞİF hafıza-dosyaları) yolunu tek yerden üretir. Paket-içi kardeş script'ler
#   (kasif-tara · mucit-suz · layiha-fabrikasi) bunu `<skill-dizini>/../layiha/scripts/` üzerinden
#   source eder — vendoring YOK, tek-ev.
#
# NİÇİN: bugün hatta DÖRT ayrı yol-felsefesi yan yana koşuyor —
#   (1) defter/aday-havuzu  : `git rev-parse --show-toplevel` (CWD)      → worktree-KÖR
#   (2) bulgu/MUCİT defteri : `--git-common-dir` + CELL_ID                → worktree-immün
#   (3) kill-switch bayrağı : sabit mutlak yol
#   (4) ntfy-state          : ortak-mount + cell son-eki
#   Sonuç ölçüldü (2026-07-25): tek container'da 17 ayrı layiha-defteri kopyası — 1'i 23 kayıt,
#   16'sı 18 kayıtta donmuş. Bu kitaplık (1)'i (2)'ye çeker; panzehrin gerekçesi zaten yazılı:
#   Nexus `scripts/hucre-baglam.lib.sh:22-29` ("--show-toplevel'dan DEĞİL ... --git-common-dir'den";
#   firsthand: dongu-defteri 3 worktree'de 54/4/47 ayrışmıştı).
#
# ⛔ ORTAK-MOUNT FALLBACK'İ YOK (Sultan-kararı K1, 2026-07-25). Git-kökü bulunamazsa bu kitaplık
#   `$HOME/.claude/...` gibi bir sığınağa DÜŞMEZ — RC=2 + tek-satır reçete verir. Gerekçe: `$HOME=/config`
#   ve `/config/.claude` 10 container'ın ORTAK fiziksel dizinidir; oraya düşen bir defter, "container'lar
#   birbirinin layihasını görmez" (İ1) değişmezini sessizce ve geri-alınamaz biçimde deler.
#   Emsal fail-closed: `seyir-defteri.sh` (git-kök yoksa `die`).
#
# SÖZLEŞME (hucre-baglam.lib.sh ile aynı felsefe):
#   Bu kitaplık YALNIZ DEFAULT üretir. Çağıranların mevcut env-kancaları (KASIF_HAVUZ · MUCIT_HAVUZ ·
#   MUCIT_DEFTER · LAYIHA_DEFTER · LAYIHA_ADAY_HAVUZ · LAYIHA_FABRIKA_BAYRAK …) `${VAR:-$(hat_yolu X)}`
#   kalıbıyla AYNEN üstün gelir. Kitaplık o kancaları OKUMAZ ve EZMEZ; yalnız fallback'lerini besler.
#
# YAN-ETKİSİZ: source etmek hiçbir değişken hesaplamaz, hiçbir dosya/dizin YAZMAZ, hiçbir çıkış yapmaz —
#   yalnız fonksiyon tanımlar. `set -euo pipefail` altında bare-source exit-0 kalır.
#
# KULLANIM:
#   source "<paket>/../layiha/scripts/hat-yolu.lib.sh"
#   HAVUZ="${KASIF_HAVUZ:-$(hat_yolu bulgu-havuzu)}" || exit 2
#
# OVERRIDE'LAR:
#   HAT_ROOT   — kök hesabını tamamen atlar (test/izole kullanım kancası)
#   CELL_ID    — hücre öneki; unset|s01 → kök'ün kendisi (bayt-aynılık), aksi → _agents/hucreler/<CELL_ID>
#
# Çıkış kodları: 0 OK · 2 git-kökü yok / bilinmeyen artefakt adı

# ── hat_root — birincil-checkout kökü (worktree-immün) ───────────────────────────────────────
# git-common-dir worktree'de bile ANA .git'i verir → parent = birincil checkout.
# CWD'den hesaplanır (script dizininden DEĞİL): paket ortak-mount'ta yaşar ve orası git-repo değildir
# (`git -C /config/.claude/skills/... rev-parse` → fatal). Script dizini taban alınsaydı veri
# ortak-mount'a düşer, üstelik sync'in `rmSync`'i bir sonraki kurulumda onu silerdi.
hat_root() {
  if [ -n "${HAT_ROOT:-}" ]; then printf '%s' "$HAT_ROOT"; return 0; fi
  local common parent
  common="$(git -C "$PWD" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -z "$common" ]; then
    printf 'HATA: burası bir proje (git) klasörü değil — layiha/fikir-hattı verisi yazılamaz.\n' >&2
    printf '      Ortak dizine yazmıyoruz (İ1 mahremiyeti). Çözüm: proje klasörüne geç, ya da yol ver:\n' >&2
    printf '      HAT_ROOT=/config/projects/<proje> %s ...\n' "${0##*/}" >&2
    return 2
  fi
  case "$common" in /*) ;; *) common="$PWD/$common" ;; esac
  parent="$(cd "$(dirname "$common")" 2>/dev/null && pwd)" || {
    printf 'HATA: git-kökü çözülemedi (%s). HAT_ROOT env ile yol ver.\n' "$common" >&2
    return 2
  }
  printf '%s' "$parent"
}

# ── hat_onek — hücre-scope'lu taban ──────────────────────────────────────────────────────────
# hucre-baglam.lib.sh:54-58 ile BAYT-AYNI dallanma: s01 (ya da unset) → kökün kendisi.
hat_onek() {
  local root; root="$(hat_root)" || return 2
  if [ "${CELL_ID:-s01}" = "s01" ]; then printf '%s' "$root"
  else printf '%s/_agents/hucreler/%s' "$root" "${CELL_ID}"; fi
}

# ── hat_yolu <artefakt> — tek çözüm noktası ──────────────────────────────────────────────────
# Bilinmeyen ad = sessiz-yanlış-yol yerine RC=2 (fail-closed; yazım hatası veriyi kaybettirmesin).
hat_yolu() {
  local ad="${1:-}" onek
  onek="$(hat_onek)" || return 2
  case "$ad" in
    handoff-dir)          printf '%s/_agents/handoff' "$onek" ;;
    kasif-dir)            printf '%s/_agents/kasif' "$onek" ;;
    kasif-knowledge-dir)  printf '%s/_agents/kasif/knowledge' "$onek" ;;
    mucit-dir)            printf '%s/_agents/mucit' "$onek" ;;

    layiha-defteri)       printf '%s/_agents/handoff/layiha-defteri.jsonl' "$onek" ;;
    aday-havuzu)          printf '%s/_agents/handoff/layiha-aday-havuzu.jsonl' "$onek" ;;
    bulgu-havuzu)         printf '%s/_agents/handoff/bulgu-havuzu.jsonl' "$onek" ;;
    mucit-defteri)        printf '%s/_agents/handoff/mucit-defteri.jsonl' "$onek" ;;
    mucit-defteri-layiha) printf '%s/_agents/handoff/mucit-defteri-layiha.jsonl' "$onek" ;;

    kasif-konular)        printf '%s/_agents/kasif/konular.md' "$onek" ;;
    kasif-kaynaklar)      printf '%s/_agents/kasif/kaynaklar.jsonl' "$onek" ;;
    kasif-yontem)         printf '%s/_agents/kasif/yontem.md' "$onek" ;;
    kasif-seyir)          printf '%s/_agents/kasif/seyir.jsonl' "$onek" ;;
    kasif-oneri)          printf '%s/_agents/kasif/oneri-havuzu.jsonl' "$onek" ;;
    kasif-tekrar)         printf '%s/_agents/kasif/tekrar.jsonl' "$onek" ;;
    *)
      printf 'HATA: bilinmeyen artefakt adı: %s\n' "${ad:-<boş>}" >&2
      printf '      geçerli: handoff-dir kasif-dir kasif-knowledge-dir mucit-dir layiha-defteri\n' >&2
      printf '               aday-havuzu bulgu-havuzu mucit-defteri mucit-defteri-layiha\n' >&2
      printf '               kasif-konular kasif-kaynaklar kasif-yontem kasif-seyir kasif-oneri kasif-tekrar\n' >&2
      return 2 ;;
  esac
}

# ── hat_tani — teşhis (hangi kök, hangi kaynak, hangi hücre) ─────────────────────────────────
# Sultan-yüzü script'ler "hangi deftere bakıyorum" satırını buradan basar (sessiz-yanlış-defter panzehiri).
hat_tani() {
  local root
  if [ -n "${HAT_ROOT:-}" ]; then root="$HAT_ROOT"; printf 'kök=%s (kaynak: HAT_ROOT override) · hücre=%s\n' "$root" "${CELL_ID:-s01}"; return 0; fi
  root="$(hat_root)" || return 2
  printf 'kök=%s (kaynak: git-common-dir) · hücre=%s\n' "$root" "${CELL_ID:-s01}"
}
