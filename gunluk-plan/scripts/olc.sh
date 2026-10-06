#!/usr/bin/env bash
# /gunluk-plan ADIM-1 — yedi kaynağı ölç. Ölçemediğini "ölçemedim" diye bas (sessiz atlama yok).
# SALT-OKUR: hiçbir dosyaya yazmaz.
set -uo pipefail
# 🔴 SINANABİLİRLİK: kök ve beceri dizini ezilebilir olmalı — yoksa bu aracın kendi sınavı
#    gerçek depoya ve gerçek deftere dokunmak zorunda kalır (ölçüm, ölçtüğü şeyi değiştirir).
KOK="${GUNLUK_PLAN_KOK:-$(git rev-parse --show-toplevel 2>/dev/null || echo /config/projects/Nexus)}"
SK="${GUNLUK_PLAN_SK:-/config/.claude/skills}"
gun="$(date +%Y-%m-%d)"

bolum(){ printf '\n━━━ %s ━━━\n' "$1"; }
olcemedim(){ printf '  ⚠️ ölçemedim: %s\n' "$1"; }

printf '📊 GÜNÜN ÖLÇÜMÜ · %s · oda: %s\n' "$gun" "$(basename "$KOK")"

bolum "1/7 · Aktif layihalar (araştırma bitti, inşa bekliyor)"
if [ -x "$SK/layiha/scripts/layiha-defteri.sh" ] || [ -f "$SK/layiha/scripts/layiha-defteri.sh" ]; then
  # 🔴 KOD DESENİ ODA-ÖNEKLİ (2026-08-29 onarımı): defter satırları `  [s01-L13]` biçiminde
  #   basılıyor; eski desen `^  \[L` bunu HİÇ yakalamıyordu → araç 59 aktif layiha varken
  #   "toplam aktif: 0" diyordu. Ölçüm aracının kendisi kördü ve günün planı ona dayanıyordu.
  #   Sıfır sessizce basılıyordu; sahte-boşluk, gerçek boşluktan ayırt edilemiyordu.
  # Tek koşum, iki kullanım: liste iki kez çağrılmaz (ikinci çağrı arada değişebilirdi).
  _lay="$(bash "$SK/layiha/scripts/layiha-defteri.sh" liste --aktif 2>/dev/null)" || _lay=""
  if [ -z "$_lay" ]; then
    olcemedim "layiha defteri okunamadı (sıfır SAYILMADI)"
  else
    printf '%s\n' "$_lay" | head -3
    n="$(printf '%s\n' "$_lay" | grep -cE '^  \[[^]]+\]')" || n=0
    printf '  toplam aktif: %s\n' "$n"
  fi
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

bolum "6/7 · Dün nerede bıraktım (KENDİ izimin son satırları)"
# 🔴 BAŞKASININ DEFTERİ OKUTULUYORDU (CEZERÎ bildirdi, 2026-10-06; ben de aynı sabah çarptım):
#    bu kaynak SERDAR'ın defterini ÇİVİLİ yoldan okuyordu. Yani ölçüm aracı, hangi ajan
#    koşarsa koşsun ona SERDAR'ın izini "dün nerede bıraktım" diye sunuyordu. İki ayrı zarar:
#    (a) yanlış ize bakan ajan yanlış plan yazar; (b) başka bir ajanın günlük izi, onu
#    görmesi gerekmeyen odalara sızar. Çare: kimliği SORMAK ve bulamayınca SUSMAK —
#    "ölçemedim" demek, başkasının defterini basmaktan iyidir (unknown ≠ başkasının verisi).
#    Kimlik TEK KAYNAKTAN sorulur: `cipa.sh ajan`. Burada ikinci bir türetme YOK.
#    🔴 İKİNCİ TÜRETME YOK — ORTAM DEĞİŞKENİNE DE BAKMAZ (bağımsız göz tur-1, 2026-10-06):
#    ilk yazımda `GUNLUK_PLAN_AJAN` doluysa çıpa aracına hiç sormuyordum. Bu, "tek kaynak"
#    iddiasını çürütüyordu: aynı kimlik iki yerde hesaplanıyor ve ilk değişimde ayrışır
#    (o değişkenin katlama/çakışma kuralları çıpa aracının içinde yaşıyor, burada değil).
#    Açık ayar hâlâ işler — ama ARACIN İÇİNDEN, çünkü kimlik sırasının sahibi o.
_ajan_sor() {
  local a arac
  arac="${GUNLUK_PLAN_CIPA_ARAC:-$SK/gunluk-plan/scripts/cipa.sh}"
  [ -f "$arac" ] || return 1
  a="$(bash "$arac" ajan 2>/dev/null)" || return 1
  [ -n "$a" ] && printf '%s' "$a"
}
_ajan6="$(_ajan_sor)" || _ajan6=""
if [ -z "$_ajan6" ] || [ "$_ajan6" = "bilinmiyor" ]; then
  olcemedim "kimliğimi soramadım (çıpa aracı eski ya da yok) — BAŞKASININ defterini basmıyorum"
else
  _d=""
  for _y in "$KOK/_agents/handoff/$_ajan6-defter.md" \
            "$(ls -t "$KOK/_agents/handoff/$_ajan6-konum-"*.md 2>/dev/null | head -1)"; do
    [ -n "$_y" ] && [ -f "$_y" ] && { _d="$_y"; break; }
  done
  if [ -n "$_d" ]; then
    printf '  kaynak: %s (ajan: %s)\n' "$(basename "$_d")" "$_ajan6"
    tail -12 "$_d"
  else
    olcemedim "bu ajanın ($_ajan6) kendi izi bulunamadı — aradığım: $_ajan6-defter.md · $_ajan6-konum-*.md"
    printf '  ℹ️ başka bir ajanın defteri BİLEREK basılmadı (yanlış iz + sızıntı).\n'
  fi
fi

bolum "7/7 · Ortam (dallanma güvenli mi)"
git -C "$KOK" status -sb 2>/dev/null | head -1
printf '  commit'"'"'siz dosya: %s\n' "$(git -C "$KOK" status --porcelain 2>/dev/null | wc -l)"
printf '  main'"'"'den geride: %s commit\n' "$(git -C "$KOK" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"

printf '\n✅ ölçüm bitti — şimdi DÖRT ELEKTEN geçir (SKILL.md ADIM-2), sonra planı sun.\n'
