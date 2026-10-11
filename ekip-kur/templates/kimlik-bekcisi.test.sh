#!/usr/bin/env bash
# kimlik-bekcisi.test.sh — bekçinin sınavı (ŞABLON sürümü). HERMETİK: fikstürü kendi kurar, gerçek ağaca dokunmaz.
# Kaynak: MAİŞET/BASİRET 11 Ekim 2026 (10/10, mutasyonlu). Şablonda kutu dosyası yok; temiz kopya ŞABLONDAN
# ve küçük bir sahte ekipten (iki koltuk) üretilir. Ağırlık merkezi MUTASYON: her kapı tek tek bozulur,
# bekçinin kırmızı verdiği ölçülür. Bozulduğunda kırmızı vermeyen kapı süstür.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
BEKCI="$D/kimlik-bekcisi.sh"
GECTI=0; DUSTU=0
ESAS="$(mktemp -d)"; trap 'command rm -r "$ESAS"' EXIT

kur() {  # temiz kopya: $1 hedef dizin — iki koltuk (REIS · KALFA), hepsi gerçek
  local d="$1"; mkdir -p "$d/_agents/handoff" "$d/.claude" "$d/scripts"
  cat > "$d/_agents/handoff/ekip-registry.yaml" <<Y
meta:
  ekip: "sinav-ekibi"
  yonetici: REIS
uyeler:
  - id: REIS
    tmux: "reis:0"
    mod: kod
    rol: "ekibi yönetir, işi dağıtır"
  - id: KALFA
    tmux: "kalfa:0"
    mod: kod
    rol: "işi yapar, reise rapor verir"
  - id: MÜŞİR
    tmux: "musir:0"
    mod: salt-okur
    rol: "aksanlı kimlik — yönergede doğru yazılınca yeşil kalmalı"
Y
  python3 -I - "$D/settings-hook-snippet.json" "$d/.claude/settings.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); json.dump({"hooks":d["hooks"]},open(sys.argv[2],"w"))
PY
  printf '# Sınav ekibi\n\nKoltuklar: **REIS** (yönetir) · **KALFA** (yapar) · **MÜŞİR** (danışır).\n' > "$d/CLAUDE.md"
  for id in reis kalfa müşir; do
    printf '# %s görev kartı\n\n**Tek cümle**: sınav koltuğu.\n' "$id" > "$d/_agents/handoff/$id-gorev-brifi.md"
  done
  cp "$D/ekip-self-recognition.sh" "$d/scripts/"
}
bekle() {  # $1=ad $2=beklenen-rc $3=dizin
  local out rc; out="$(KIMLIK_KOK="$3" bash "$BEKCI" 2>&1)"; rc=$?
  if [ "$rc" = "$2" ]; then GECTI=$((GECTI+1)); printf '  ✓ %s (rc=%s)\n' "$1" "$rc"
  else DUSTU=$((DUSTU+1)); printf '  ✗ %s — beklenen rc=%s, gelen rc=%s\n%s\n' "$1" "$2" "$rc" "$(tail -3 <<<"$out" | sed 's/^/      /')"; fi
}
n=0; yeni() { n=$((n+1)); local d="$ESAS/k$n"; kur "$d"; echo "$d"; }

echo "kimlik-bekcisi sınavı (şablon)"
d=$(yeni); bekle "temiz kopya YEŞİL (pozitif kontrol)" 0 "$d"

d=$(yeni); sed -i '0,/rol: ".*"/s//rol: "İSKÂN FAZ-6 deneme-üyesi (uye)"/' "$d/_agents/handoff/ekip-registry.yaml"
bekle "M1 rol yer tutucuya döndü → KIRMIZI" 1 "$d"

d=$(yeni); sed -i '0,/^\s*rol:.*$/{/^\s*rol:.*$/d}' "$d/_agents/handoff/ekip-registry.yaml"
bekle "M2 bir üyenin rol satırı silindi → KIRMIZI" 1 "$d"

d=$(yeni); command rm "$d/.claude/settings.json"
bekle "M3 settings.json silindi → KIRMIZI" 1 "$d"

d=$(yeni); printf '{"hooks":{"SessionStart":[]}}\n' > "$d/.claude/settings.json"
bekle "M4 kanca listeden çıkarıldı → KIRMIZI" 1 "$d"

d=$(yeni); command rm "$d/CLAUDE.md"
bekle "M5 proje yönergesi silindi → KIRMIZI" 1 "$d"

d=$(yeni); sed -i 's/\*\*KALFA\*\* (yapar)/kalfa (yapar)/' "$d/CLAUDE.md"; grep -qF '**KALFA**' "$d/CLAUDE.md" && echo "  ! M6 mutasyonu uygulanamadı"
bekle "M6 yönerge bir koltuğu kalın anmıyor (küçük harf hitap değil) → KIRMIZI" 1 "$d"

d=$(yeni); command rm "$d/_agents/handoff/kalfa-gorev-brifi.md"
bekle "M7 bir görev kartı silindi → KIRMIZI" 1 "$d"

d=$(yeni); sed -i '/görev kartın:/d' "$d/scripts/ekip-self-recognition.sh"
bekle "M8 kanca kartı basmayı bıraktı → KIRMIZI" 1 "$d"

d=$(yeni); command rm "$d/_agents/handoff/ekip-registry.yaml"
bekle "M9 registry yok → ÖLÇEMEDİM (yeşil değil)" 3 "$d"

d=$(yeni); sed -i 's/\*\*MÜŞİR\*\* (danışır)/**MUSIR** (danışır)/' "$d/CLAUDE.md"
bekle "M10 aksanlı kimlik yönergede sadeleşmiş yazılmış (MUSIR) → yine hitap, YEŞİL" 0 "$d"

d=$(yeni); sed -i 's/ · \*\*MÜŞİR\*\* (danışır)//' "$d/CLAUDE.md"
bekle "M11 aksanlı kimlik yönergeden silindi → KIRMIZI" 1 "$d"

echo "SONUÇ: $GECTI geçti · $DUSTU düştü"
[ "$DUSTU" -eq 0 ]
