#!/usr/bin/env bash
# ahi — AHÎ 4-Kademe Yetenek Fabrikası · CLI (FAZ-0a kabuk)
# Değişmez: value-safe (sır-değer basmaz) · owner-domain-dokunma (sync-skills.mjs'e yazmaz) · INERT/additive.
set -uo pipefail

AHI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # ahi/ kökü
# VERSION tek-kaynak = SKILL.md frontmatter (W5-A5: sabit-kopya v0.2.0 bump'ında ayrışmıştı — drift-dersi)
VERSION="$(awk -F': *' '/^version:/{print $2; exit}' "$AHI_DIR/SKILL.md" 2>/dev/null)"
: "${VERSION:=0.0.0}"

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*" >&2; }

usage() {
  cat <<'EOF'
ahi — AHÎ 4-Kademe Yetenek Fabrikası

KULLANIM: ahi <komut> [argümanlar]

  doctrine            Değişmezler Kitabı'nı (kanon) göster
  tiers [<kademe>]    Kademe-kart(lar)ını göster (cirak|kalfa|usta|pir)
  new <kademe> <ad>   Kademe-seç → standart-iskelet scaffold        [FAZ-1]
  check               Repo-parity drift-lint (catalog↔sync-targets; --strict=gate)
  check <skill>       O skill manifest-şema doğrulaması (ahi=dogfood)
  promote <skill>     Terfi-appraisal → yeşilse Sultan-törenine öner [FAZ-3]
  deprecate <s> "<m>" Soft-emeklilik (deprecated+sunset+successor)   [FAZ-3]
  classify            Yeni-işi anlat → hangi-kademe önerici          [FAZ-4]
  health              Sağlık-panosu                                  [FAZ-4]
  version             Sürüm
  --help | -h         Bu yardım

KADEMELER: Çırak(S1) → Kalfa(S2) → Usta(S3) → Pîr/Lonca(S4). Kademe atlanamaz.
KANON: ahi doctrine  ·  Detay: DOCTRINE.md + tiers/
EOF
}

cmd_doctrine() {
  local f="$AHI_DIR/DOCTRINE.md"
  [ -f "$f" ] || { red "DOCTRINE.md bulunamadı: $f"; return 1; }
  cat "$f"
}

cmd_tiers() {
  local k="${1:-}"
  if [ -n "$k" ]; then
    local f="$AHI_DIR/tiers/$k.md"
    [ -f "$f" ] || { red "Bilinmeyen kademe: $k (cirak|kalfa|usta|pir)"; return 1; }
    cat "$f"
  else
    grn "Kademeler (zanaat-rütbesi — tertipli, atlanamaz):"
    echo "  Çırak (S1) → Kalfa (S2) → Usta (S3) → Pîr/Lonca (S4)"
    echo "Detay: ahi tiers <kademe>   ·   Kart dosyaları:"
    ls "$AHI_DIR/tiers/" 2>/dev/null | sed 's/^/  - /'
  fi
}

pir_repo_of() {  # pir-registry'den own-repo yolu (FAZ-6/ADR-002; yoksa boş-string)
  local reg="$AHI_DIR/pir-registry.json"
  { [ -f "$reg" ] && command -v node >/dev/null 2>&1; } || { echo ""; return 0; }
  node -pe "try{(JSON.parse(require('fs').readFileSync('$reg','utf8')).pirler.find(p=>p.name==='$1')||{}).repo||''}catch(e){''}" 2>/dev/null || echo ""
}

cmd_check() {
  command -v node >/dev/null 2>&1 || { red "node bulunamadı (validate*.mjs gerektirir)"; return 2; }
  local target="${1:-}"
  # argümansız / --repo / --strict → repo-parity drift-lint (FAZ-2; ADR-001: catalog/sync-targets'a YAZMAZ, yalnız-raporlar)
  if [ -z "$target" ] || [ "$target" = "--repo" ] || [ "$target" = "--strict" ]; then
    node "$AHI_DIR/schema/validate-repo.mjs" "$AHI_DIR/.." "$@"; return $?
  fi
  # <skill> → manifest-şema-valid (FAZ-0b). 'ahi' = dogfood (kendi manifesti).
  # Pîr/S4 own-repo hedefleri (FAZ-6): Sx-altında bulunamazsa pir-registry'den çözülür.
  local mani prepo
  if [ "$target" = "ahi" ]; then mani="$AHI_DIR/ahi.manifest.yaml"
  else
    mani="$AHI_DIR/../$target/ahi.manifest.yaml"
    [ -f "$mani" ] || mani="$target/ahi.manifest.yaml"
    if [ ! -f "$mani" ]; then
      prepo="$(pir_repo_of "$target")"
      [ -n "$prepo" ] && mani="$prepo/ahi.manifest.yaml"
    fi
  fi
  [ -f "$mani" ] || { red "manifest bulunamadı: $mani"; return 1; }
  node "$AHI_DIR/schema/validate.mjs" "$mani"
}

cmd_new() {
  local tier="${1:-}" name="${2:-}" apply=0
  [ "${3:-}" = "--apply" ] && apply=1
  case "$tier" in cirak|kalfa|usta|pir) ;; *) red "geçersiz kademe: '$tier' (cirak|kalfa|usta|pir)"; return 2 ;; esac
  [ -n "$name" ] || { red "ad gerekli: ahi new <kademe> <ad> [--apply]"; return 2; }
  echo "$name" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$' || { red "geçersiz slug: '$name' (kebab-case a-z0-9; ör. ornek-skill)"; return 2; }
  local gg
  case "$tier" in
    cirak) gg="işi yapıyor" ;;
    kalfa) gg="planlı + paketli + her-projede güvenilir tekrarlanabilir" ;;
    usta)  gg="standarttan-türetilmiş bileşik iş-sistemi" ;;
    pir)   gg="ölçülen + kendini-geliştiren yaşayan-sistem" ;;
  esac
  if [ "$tier" = "pir" ]; then
    ylw "Pîr (S4 · yaşayan-sistem) = KENDİ-REPO (skill-dizini değil)."
    echo "  Rehber: 'ahi tiers pir' — kendi-repo iskeleti (DOCTRINE/CONTRACT/ROADMAP/ADR) + remote+CI zorunlu (Lonca emsali)."
    return 0
  fi
  local tdir="$AHI_DIR/templates/$tier"
  [ -d "$tdir" ] || { red "şablon yok: $tdir"; return 1; }
  local dest="$AHI_DIR/../$name" rel
  if [ "$apply" -ne 1 ]; then
    ylw "DRY-RUN (yazma-öncesi DURAK) — onaylarsan --apply ekle:"
    echo "  kademe : $tier   ad: $name"
    echo "  hedef  : $dest/"
    echo "  generic-goal (default): \"$gg\""
    echo "  üretilecek:"
    while IFS= read -r rel; do echo "    $name/${rel#./}"; done < <(cd "$tdir" && find . -type f)
    echo "  → onay: ahi new $tier $name --apply"
    return 0
  fi
  [ -e "$dest" ] && { red "hedef zaten var: $dest (üzerine yazılmaz)"; return 2; }
  while IFS= read -r rel; do
    rel="${rel#./}"; mkdir -p "$dest/$(dirname "$rel")"
    sed -e "s|{{NAME}}|$name|g" -e "s|{{TIER}}|$tier|g" -e "s|{{GENERIC_GOAL}}|$gg|g" "$tdir/$rel" > "$dest/$rel"
  done < <(cd "$tdir" && find . -type f)
  if grep -rq '{{' "$dest" 2>/dev/null; then
    red "dolmamış placeholder kaldı — sevk-RED:"; grep -rn '{{' "$dest" >&2; return 1
  fi
  grn "✓ üretildi: $dest/"
  echo "--- ahi check $name ---"; cmd_check "$name"
}

cmd_promote() {
  local skill="${1:-}"
  [ -n "$skill" ] || { red "kullanım: ahi promote <skill>"; return 2; }
  local sdir="$AHI_DIR/../$skill" mani="$AHI_DIR/../$skill/ahi.manifest.yaml"
  if [ ! -f "$mani" ]; then  # Pîr own-repo (FAZ-6): registry'den çöz
    local prepo0; prepo0="$(pir_repo_of "$skill")"
    [ -n "$prepo0" ] && { sdir="$prepo0"; mani="$prepo0/ahi.manifest.yaml"; }
  fi
  [ -f "$mani" ] || { red "manifest bulunamadı: $mani"; return 1; }
  local tier next
  tier="$(grep -m1 '^tier:' "$mani" | awk '{print $2}')"
  case "$tier" in
    cirak) next=kalfa ;; kalfa) next=usta ;; usta) next=pir ;;
    pir) ylw "$skill zaten Pîr (en-üst) — terfi yok, mezuniyet."; return 0 ;;
    *) red "manifest tier okunamadı: '$tier'"; return 1 ;;
  esac
  echo "Terfi-appraisal: $skill  ($tier → $next)   [eşik: N=2 proje · min-yaş=30g · objective-evidence]"
  local targets="$AHI_DIR/../sync-targets.json" pass=1
  local projcount reqcount first_epoch agedays checkrc
  projcount="$(node -pe "try{JSON.parse(require('fs').readFileSync('$targets','utf8')).install['$skill']?.length||0}catch(e){0}" 2>/dev/null || echo 0)"
  reqcount="$(awk '/^requires:/{f=1} f&&/^  - /{c++} /^[a-z_]/&&!/^requires:/{if(f)f=0} END{print c+0}' "$mani")"
  first_epoch="$(cd "$AHI_DIR/.." && git log --diff-filter=A --format=%at -- "$skill/" 2>/dev/null | tail -1)"
  agedays="manuel"; [ -n "$first_epoch" ] && agedays=$(( ( $(date +%s) - first_epoch ) / 86400 ))
  chk() { if [ "$1" = "1" ]; then grn "  ✓ $2"; else red "  ✗ $2"; pass=0; fi; }
  cmd_check "$skill" >/dev/null 2>&1; checkrc=$?
  chk "$([ "$checkrc" -eq 0 ] && echo 1 || echo 0)" "ahi check temiz"
  case "$next" in
    kalfa) chk "$([ -f "$sdir/SKILL.md" ] && echo 1 || echo 0)" "paketli (SKILL.md var)" ;;
    usta)
      chk "$([ "$reqcount" -ge 2 ] && echo 1 || echo 0)" "≥2 skill besteliyor (requires=$reqcount)"
      chk "$([ "$projcount" -ge 2 ] && echo 1 || echo 0)" "≥2-projede-aktif (install=$projcount)" ;;
    pir)
      # FAZ-6: mekanik ön-problar (nihai-karar yine MANUEL-BEYAN/Sultan-gate — pass=0 korunur)
      local prepo1; prepo1="$(pir_repo_of "$skill")"
      if [ -n "$prepo1" ] && [ -d "$prepo1" ]; then
        chk "$([ -f "$prepo1/ahi.manifest.yaml" ] && echo 1 || echo 0)" "own-repo manifest var ($prepo1)"
        chk "$([ -f "$prepo1/ROADMAP.md" ] && echo 1 || echo 0)" "kendi-roadmap var (ROADMAP.md)"
        if git -C "$prepo1" remote get-url origin >/dev/null 2>&1; then grn "  ✓ remote var"; else ylw "  ⚠ remote YOK (Pîr-mezuniyet remote+CI ister)"; fi
      else
        ylw "  ⚠ pir-registry'de own-repo kaydı yok — ahi/pir-registry.json'a ekle (ADR-002)"
      fi
      ylw "  ⚠ Usta→Pîr nihai-karar (kendini-besleyen-döngü kanıtı) = MANUEL-BEYAN (Sultan-gate; yukarıdakiler ön-probdur)"; pass=0 ;;
  esac
  if [ "$agedays" = "manuel" ]; then ylw "  ⚠ min-yaş: git-geçmişi-yok (manuel-beyan)"; else chk "$([ "$agedays" -ge 30 ] && echo 1 || echo 0)" "min-yaş ≥30g (yaş=${agedays}g)"; fi
  echo
  if [ "$pass" = "1" ]; then
    grn "→ ÖNERİ: $skill '$next' kademesine HAZIR görünüyor. Terfi = SULTAN-TÖRENİ (hibrit)."
    echo "  AHÎ otomatik-terfi ETMEZ; Sultan onaylarsa manifest tier→'$next' (+usta ise requires-doğrula)."
  else
    ylw "→ Henüz hazır değil (yukarıdaki ✗/⚠). Objective-evidence tamamlanınca tekrar dene."
  fi
}

cmd_deprecate() {
  local skill="${1:-}" msg="${2:-}" successor="${3:-}"
  [ -n "$skill" ] || { red "kullanım: ahi deprecate <skill> \"<mesaj>\" <successor|yok>  ·  geri-al: ahi deprecate <skill> --undo"; return 2; }
  local mani="$AHI_DIR/../$skill/ahi.manifest.yaml"
  [ -f "$mani" ] || { red "manifest bulunamadı: $mani"; return 1; }
  if [ "$msg" = "--undo" ]; then
    sed -i '/^# EMEKLİLİK:/d; /^deprecated:/d; /^sunset:/d; /^successor:/d' "$mani"
    grn "✓ $skill emeklilik geri-alındı (reversible)"; return 0
  fi
  [ -n "$msg" ] || { red "emeklilik-mesajı gerekli"; return 2; }
  [ -n "$successor" ] || { red "successor gerekli (DOCTRINE §9): halef-skill VEYA 'yok'"; return 2; }
  grep -q "^deprecated:" "$mani" && { ylw "$skill zaten emekli. Geri-al: ahi deprecate $skill --undo"; return 0; }
  local sunset; sunset="$(date -d '+90 days' +%F 2>/dev/null || date -v+90d +%F 2>/dev/null || echo 'TODO-90g')"
  { echo ""; echo "# EMEKLİLİK: $msg"; echo "deprecated: true"; echo "sunset: \"$sunset\""; echo "successor: \"$successor\""; } >> "$mani"
  grn "✓ $skill soft-emekli (deprecated=true · sunset=$sunset · successor=$successor)"
  echo "  npm-deprecate deseni: işaretlenir+uyarır AMA kaldırılmaz+reversible. Geri-al: ahi deprecate $skill --undo"
}

cmd_classify() {
  cat <<'EOF'
AHÎ Kademe-Sınıflandırıcı — yeni işi şu 4 soruyla sınıfla:

  1) TEK projede mi yaşayacak, basit mi?
       → evet ......................................... ÇIRAK  (S1 · yerel)
  2) Birçok projede tek-komutla on/off + güvenilir-tekrarlanabilir, ama TEK skill mi?
       → evet ......................................... KALFA  (S2 · paketli)
  3) Tek skill'in yapamayacağı geniş iş — BİRKAÇ skill'i BESTELİYOR mu?
       → evet, bileşik iş-sistemi ..................... USTA   (S3 · bileşik)
  4) Çalışma-prensibi + sürekli-büyüyen, kendi-repolu, kendini-geliştiren mi?
       → evet, yaşayan-sistem ......................... PÎR/LONCA (S4)

Değişmez: TERFİ atlanamaz; DOĞUM her-kademede olabilir (born-at-tier appraisal).
Çoğu iş Kalfa/Usta'da "yeterince olgun" kalır — hedef-kademe ≠ en-üst.
Üret: ahi new <kademe> <ad>   ·   Kanon: ahi doctrine   ·   Terfi: ahi promote <skill>
EOF
}

cmd_health() {
  local repo="$AHI_DIR/.." d name mani tier dep managed=0 unmanaged=0 deprecated=0
  echo "AHÎ Sağlık-Panosu"
  printf "  %-26s %-8s %s\n" "SKILL" "KADEME" "DURUM"
  printf "  %-26s %-8s %s\n" "--------------------------" "------" "-----"
  for d in "$repo"/*/; do
    name="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || continue
    mani="$d/ahi.manifest.yaml"
    if [ -f "$mani" ]; then
      tier="$(grep -m1 '^tier:' "$mani" | awk '{print $2}')"; [ -n "$tier" ] || tier="?"
      if grep -q '^deprecated:' "$mani"; then
        dep="emekli (sunset:$(grep -m1 '^sunset:' "$mani" | awk '{print $2}' | tr -d '"'))"; deprecated=$((deprecated+1))
      else dep="aktif"; fi
      managed=$((managed+1))
    else tier="—"; dep="unmanaged (AHÎ-yönetimsiz)"; unmanaged=$((unmanaged+1)); fi
    printf "  %-26s %-8s %s\n" "$name" "$tier" "$dep"
  done
  # Pîr/S4 kendi-repolu sistemler (pir-registry.json — FAZ-6/ADR-002; Sx-alt-dizini değildir)
  local reg="$AHI_DIR/pir-registry.json" pname prepo
  if [ -f "$reg" ] && command -v node >/dev/null 2>&1; then
    while IFS=$'\t' read -r pname prepo; do
      [ -n "$pname" ] || continue
      if [ -f "$prepo/ahi.manifest.yaml" ]; then
        if node "$AHI_DIR/schema/validate.mjs" "$prepo/ahi.manifest.yaml" >/dev/null 2>&1; then
          printf "  %-26s %-8s %s\n" "$pname" "pir" "aktif (own-repo: $prepo)"; managed=$((managed+1))
        else
          printf "  %-26s %-8s %s\n" "$pname" "pir" "manifest GEÇERSİZ ($prepo)"; managed=$((managed+1))
        fi
      else
        printf "  %-26s %-8s %s\n" "$pname" "pir" "manifest YOK ($prepo — görünmez-mount/izole?)"; unmanaged=$((unmanaged+1))
      fi
    done < <(node -pe "try{JSON.parse(require('fs').readFileSync('$reg','utf8')).pirler.map(p=>p.name+'\t'+p.repo).join('\n')}catch(e){''}" 2>/dev/null)
  fi
  echo
  echo "Özet: $managed AHÎ-yönetimli · $unmanaged yönetimsiz · $deprecated emekli"
  echo "--- repo-parity (özet) ---"
  command -v node >/dev/null 2>&1 && node "$AHI_DIR/schema/validate-repo.mjs" "$repo" 2>&1 | head -1 || echo "  (node yok)"
}

stub() { ylw "[$1] FAZ-$2'de gelir (şu an kabuk). Kanon hazır: ahi doctrine"; }

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    doctrine)        cmd_doctrine ;;
    tiers)           cmd_tiers "${1:-}" ;;
    new)             cmd_new "$@" ;;
    check)           cmd_check "${1:-}" ;;
    promote)         cmd_promote "${1:-}" ;;
    deprecate)       cmd_deprecate "$@" ;;
    classify)        cmd_classify ;;
    health)          cmd_health ;;
    version|--version) echo "ahi $VERSION" ;;
    ""|-h|--help|help) usage ;;
    *)               red "Bilinmeyen komut: $cmd"; echo; usage; return 2 ;;
  esac
}

main "$@"
