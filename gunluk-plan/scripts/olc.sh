#!/usr/bin/env bash
# /gunluk-plan ADIM-1 — yedi kaynağı ölç. Ölçemediğini "ölçemedim" diye bas (sessiz atlama yok).
# SALT-OKUR: hiçbir dosyaya yazmaz.
set -uo pipefail
KOK="$(git rev-parse --show-toplevel 2>/dev/null || echo /config/projects/Nexus)"
SK=/config/.claude/skills
gun="$(date +%Y-%m-%d)"

bolum(){ printf '\n━━━ %s ━━━\n' "$1"; }
olcemedim(){ printf '  ⚠️ ölçemedim: %s\n' "$1"; }

printf '📊 GÜNÜN ÖLÇÜMÜ · %s · oda: %s\n' "$gun" "$(basename "$KOK")"

bolum "1/7 · Aktif layihalar (araştırma bitti, inşa bekliyor)"
if [ -x "$SK/layiha/scripts/layiha-defteri.sh" ] || [ -f "$SK/layiha/scripts/layiha-defteri.sh" ]; then
  bash "$SK/layiha/scripts/layiha-defteri.sh" liste --aktif 2>/dev/null | head -3
  n=$(bash "$SK/layiha/scripts/layiha-defteri.sh" liste --aktif 2>/dev/null | grep -c '^  \[L')
  printf '  toplam aktif: %s\n' "${n:-0}"
else olcemedim "layiha defteri bulunamadı"; fi

bolum "2/7 · Sultan'ın kapısı"
if [ -f "$SK/kapimda/scripts/kapimda.sh" ]; then
  bash "$SK/kapimda/scripts/kapimda.sh" liste --hepsi 2>/dev/null | head -12
else olcemedim "kapimda yazıcısı bulunamadı"; fi

bolum "3/7 · Açık PR'lar (yaşıyla — bayat olan yarım iştir)"
if command -v gh >/dev/null 2>&1; then
  gh pr list --state open --limit 20 --json number,title,createdAt \
    -q '.[]|"  #\(.number)  \(.createdAt[0:10])  \(.title[0:70])"' 2>/dev/null || olcemedim "gh listeleyemedi"
else olcemedim "gh kurulu değil"; fi

bolum "4/7 · Odalardan gelen (son 7 gün)"
if [ -f /config/.federe/tetik-inbox.md ]; then
  tail -25 /config/.federe/tetik-inbox.md | grep -E "$(date +%Y-%m)" | tail -8 || printf '  (bu ay kayıt yok)\n'
else olcemedim "federe gelen kutusu yok"; fi

bolum "5/7 · Kendi kuyruğum (devam eden)"
printf '  → görev listesi harness tarafında; TaskList ile oku (script göremez)\n'

bolum "6/7 · Dün nerede bıraktım (defterin son satırları)"
d="$KOK/_agents/handoff/serdar-defter.md"
[ -f "$d" ] && tail -12 "$d" || olcemedim "defter bulunamadı: $d"

bolum "7/7 · Ortam (dallanma güvenli mi)"
git -C "$KOK" status -sb 2>/dev/null | head -1
printf '  commit'"'"'siz dosya: %s\n' "$(git -C "$KOK" status --porcelain 2>/dev/null | wc -l)"
printf '  main'"'"'den geride: %s commit\n' "$(git -C "$KOK" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"

printf '\n✅ ölçüm bitti — şimdi DÖRT ELEKTEN geçir (SKILL.md ADIM-2), sonra planı sun.\n'
