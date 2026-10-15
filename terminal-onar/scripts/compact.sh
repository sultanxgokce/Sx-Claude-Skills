#!/usr/bin/env bash
# compact.sh — KUTU İÇİNDEN zorunlu compact (Sultan 14 Eki: "bir kutunun reisi o kutudaki tüm ajanları compact yapabilmeli …
#   contexti artmış uzun süredir compact yapmayanları MUTLAKA compact yapması gerekiyor"). Merkezdeki filo.py compact-kurali'nin
#   kutu-içi ikizi: ssh yok, kayıtlar yerel (HOME=/config), tek komut.
#
#   komut.sh compact [--esik 60] [--koltuk <ad>] [--uygula] [--json]
#       Kutudaki Claude koltuklarını ölçer: bağlam % (son yanıt kullanımı ÷ pencere) + son compact (kayıttaki compact_boundary) + hâl.
#       Eşik üstü koltuk "compact gerek". --uygula: BOŞ koltuğa /compact gider (C-u · metin · 0,5 sn · Enter — tek çağrıda gönderilmez,
#       TUI göndermez); çalışan / girdi (taslak var) / dış-olay bekleyen koltuk KUYRUĞA girer (compact-bekleyen.jsonl), tuş gitmez.
#   komut.sh compact-bekle [--uygula]
#       Kuyruk turu (bekçi her dakika kuyruk doluysa çağırır): koltuk boşaldıysa /compact; bu arada eşiğin altına inmişse (biri
#       compact etmiş) ya da koltuk kapanmışsa kuyruktan düşer; 24 saat / 60 deneme sonra VAZGEÇİLİR (ekrana + günlüğe, sessiz değil).
#
# 🔴 YETKİ: --uygula AGENT_NAME ister; kimliksiz RET. Reis adı biliniyorsa (TO_REIS ya da $DURUM_DIZ/reis) yalnız o ad uygular;
#    başkası "ölçebilir, uygulayamaz". Kuyruk turu (bekçi, kimliksiz) kaydın `kim` alanıyla koşar ve onu HER TURDA yeniden sınar:
#    reis biliniyorsa kim == reis, değilse kim dolu; tutmayan kayıt gönderilmeden düşer (göz tur 1).
# 🔴 ÖLÇÜLEMEYEN KOLTUK compact EDİLMEZ: oturum kaydı bulunamazsa (sid yok / dosya yok) "ölçülemedi" basılır, tuş gitmez.
# 🔴 PAYDA TAHMİNİ: kayıt model adını "[1m]" eki olmadan yazabiliyor → yüzde 200k paydayla tahmindir, satırda "~" ile işaretli.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; . "$D/ortak.sh"
[ -n "${SAHTE:-}" ] && [ -d "$SAHTE/bin" ] && PATH="$SAHTE/bin:$PATH"   # hermetik sınav: ortak.sh PATH'i öne alır, sahte tmux geri öne gelsin
KUYRUK="${TO_COMPACT_KUYRUK:-$DURUM_DIZ/compact-bekleyen.jsonl}"
ESIK="${TO_COMPACT_ESIK:-60}"; UYGULA=0; JSON=0; TEK=""; MOD="olc"; TAVAN_DENEME="${TO_COMPACT_TAVAN:-60}"; TAVAN_SN="${TO_COMPACT_TAVAN_SN:-86400}"
while [ $# -gt 0 ]; do
  case "$1" in
    --esik) ESIK="$2"; shift 2 ;; --koltuk) TEK="$2"; shift 2 ;; --uygula) UYGULA=1; shift ;; --json) JSON=1; shift ;;
    --bekle) MOD="bekle"; shift ;;
    *) echo "compact.sh: tanınmayan argüman: $1" >&2; exit 2 ;;
  esac
done
case "$ESIK" in ''|*[!0-9]*) echo "compact.sh: --esik sayı olmalı ($ESIK)" >&2; exit 2 ;; esac

# ── yetki ──
reis_adi() { [ -n "${TO_REIS:-}" ] && { printf '%s' "$TO_REIS"; return; }; [ -f "$DURUM_DIZ/reis" ] && tr -d '\n' < "$DURUM_DIZ/reis"; }
yetki_kapisi() {
  [ "$UYGULA" = 1 ] || return 0
  local kim="${AGENT_NAME:-}" reis; reis="$(reis_adi)"
  [ -n "$kim" ] || { echo "⛔ --uygula kimliksiz koşturulamaz: AGENT_NAME yok (ölçmek serbest, uygulamak reisin)" >&2; return 1; }
  if [ -n "$reis" ] && [ "$kim" != "$reis" ]; then echo "⛔ --uygula yalnız kutu reisinin ($reis); sen: $kim — ölçüm basıldı, tuş gitmedi" >&2; return 1; fi
  return 0
}

# ── oturum kaydı: koltuk → sid → jsonl (sahte: TO_OTURUM_DIZ/<ad>.jsonl) ──
oturum_dosyasi() {  # $1 = koltuk adı → yol basar; yoksa RC=1 + neden stderr
  local ad="$1" sid f
  if [ -n "${TO_OTURUM_DIZ:-}" ]; then f="$TO_OTURUM_DIZ/$ad.jsonl"; [ -f "$f" ] && { echo "$f"; return 0; }; echo "sahte kayıt yok" >&2; return 1; fi
  sid="$(claude_oturumu "$ad" 2>/dev/null)" || { echo "canlı Claude yok" >&2; return 1; }
  [ "$sid" != "?" ] && [ -n "$sid" ] || { echo "sohbet kimliği bilinmiyor" >&2; return 1; }
  f="$(find "$HOME/.claude/projects" "$HOME"/.claude/hesaplar/*/projects -maxdepth 2 -name "$sid.jsonl" 2>/dev/null | head -1)"
  [ -n "$f" ] || { echo "kayıt dosyası yok ($sid)" >&2; return 1; }
  echo "$f"
}
olc_json() { node "$D/../kapi/compact-olc.mjs" "$1" 2>/dev/null; }
j() { printf '%s' "$1" | jq -r "$2" 2>/dev/null; }
once() {  # epoch → "2 sa önce"
  local e="$1" s; [ -n "$e" ] && [ "$e" != null ] && [ "$e" != - ] || { echo "hiç"; return; }
  s=$(( $(date +%s) - e )); if [ $s -lt 3600 ]; then echo "$((s/60)) dk önce"; elif [ $s -lt 86400 ]; then echo "$((s/3600)) sa önce"; else echo "$((s/86400)) g önce"; fi
}

# ── /compact gönderimi: C-u · metin · 0,5 sn · Enter (aile-compact-core dersi: gömülü Enter TUI'de göndermez) ──
compact_gonder() {  # $1 = koltuk (tmux oturumu) · $2 = kim adına (yetkili ad; kuyruk turunda kaydın sahibi)
  tmux send-keys -t "=$1" C-u 2>/dev/null || return 1
  tmux send-keys -t "=$1" -- "/compact" 2>/dev/null || return 1
  sleep "${TO_COMPACT_BEKLE_SN:-0.5}"
  tmux send-keys -t "=$1" Enter 2>/dev/null || return 1
  gunluk "compact gönderildi: $1 (kim: ${2:-?})"
}
# Kuyruk kaydının yetkisi (göz tur 1 · ciddi): bekçi kimliksiz koşar, yetki KAYITTAN gelir — kayıt yazılırken reis kapısından geçmişti.
# Yine de her turda yeniden sınanır: reis biliniyorsa kim == reis, bilinmiyorsa kim dolu ve '?' değil. Tutmayan kayıt GÖNDERİLMEDEN düşer.
kayit_yetkili() {  # $1 = kim → 0 yetkili, 1 değil
  local kim="$1" reis; reis="$(reis_adi)"
  [ -n "$kim" ] && [ "$kim" != "?" ] && [ "$kim" != null ] || return 1
  [ -z "$reis" ] || [ "$kim" = "$reis" ] || return 1
  return 0
}
kuyruga_al() {  # $1 ad · $2 yuzde · $3 hal · $4 kim
  mkdir -p "$(dirname "$KUYRUK")"
  grep -qF "\"koltuk\":\"$1\"" "$KUYRUK" 2>/dev/null && return 0   # zaten kuyrukta
  printf '{"an":"%s","epoch":%s,"koltuk":"%s","yuzde":%s,"hal":"%s","deneme":0,"kim":"%s"}\n' "$(date -Iseconds)" "$(date +%s)" "$1" "$2" "$3" "$4" >> "$KUYRUK"
  gunluk "compact kuyruğa: $1 (%$2, $3)"
}

# ── ölçüm: tüm Claude koltukları ──
liste() { bash "$D/koltuk-bagla.sh" --liste; }
olc_hepsi() {  # satır: ad<TAB>hal<TAB>yuzde|-<TAB>son_compact|-<TAB>payda_tahmin<TAB>neden
  local L; L="$(liste)" || { echo "koltuklar ölçülemedi (koltuk-bagla --liste)" >&2; return 3; }
  printf '%s\n' "$L" | while IFS=$'\t' read -r ad etk claude tur hal ne; do
    [ -n "$ad" ] || continue; [ "$claude" = 1 ] || continue
    [ -z "$TEK" ] || [ "$TEK" = "$ad" ] || continue
    if f="$(oturum_dosyasi "$ad" 2>"$DURUM_DIZ/.compact-neden")"; then
      o="$(olc_json "$f")"; y="$(j "$o" '.yuzde // empty')"; sc="$(j "$o" '.son_compact // empty')"; pt="$(j "$o" '.payda_tahmin')"; ne2="$(j "$o" '.olculemedi // empty')"
      [ -n "$y" ] && printf '%s\t%s\t%s\t%s\t%s\t\n' "$ad" "$hal" "$y" "${sc:--}" "$pt" || printf '%s\t%s\t-\t-\t-\t%s\n' "$ad" "$hal" "${ne2:-kullanım satırı yok}"
    else printf '%s\t%s\t-\t-\t-\t%s\n' "$ad" "$hal" "$(cat "$DURUM_DIZ/.compact-neden")"; fi
  done
}

if [ "$MOD" = olc ]; then
  yetki_kapisi || exit 5
  OLC="$(olc_hepsi)" || exit 3
  gerek=0; gonderildi=0; kuyruk=0; olculemedi=0; JS="["
  [ "$JSON" = 1 ] || echo "── compact ölçümü · kutu $KUTU · eşik %$ESIK$([ "$UYGULA" = 1 ] && echo " · UYGULA (${AGENT_NAME:-?})" || echo " · yalnız ölçüm")"
  while IFS=$'\t' read -r ad hal y sc pt neden; do
    [ -n "$ad" ] || continue
    if [ "$y" = "-" ]; then olculemedi=$((olculemedi+1)); karar="ölçülemedi: $neden"
    elif [ "$y" -ge "$ESIK" ]; then
      gerek=$((gerek+1))
      if [ "$UYGULA" = 1 ]; then
        if [ "$hal" = bos ]; then compact_gonder "$ad" "${AGENT_NAME:-?}" && { gonderildi=$((gonderildi+1)); karar="⟳ /compact GÖNDERİLDİ"; } || karar="⛔ gönderilemedi (tmux)"
        else kuyruga_al "$ad" "$y" "$hal" "${AGENT_NAME:-?}"; kuyruk=$((kuyruk+1)); karar="⏳ KUYRUKTA ($hal — boşalınca)"; fi
      else karar="⚠ compact gerek$([ "$hal" = bos ] && echo " (boş: --uygula ile gider)" || echo " ($hal: --uygula ile kuyruğa)")"; fi
    else karar="tamam"; fi
    if [ "$JSON" = 1 ]; then JS="$JS$([ "$JS" != "[" ] && echo ,){\"koltuk\":\"$ad\",\"hal\":\"$hal\",\"yuzde\":$([ "$y" = - ] && echo null || echo "$y"),\"payda_tahmin\":$([ "$pt" = true ] && echo true || echo false),\"son_compact\":$([ "$sc" = - ] && echo null || echo "$sc"),\"karar\":\"$karar\"}"
    else printf '  %-18s %-10s %5s  ⟳ %-12s %s\n' "$ad" "$hal" "$([ "$y" = - ] && echo '—' || echo "$([ "$pt" = true ] && echo '~')%$y")" "$(once "$sc")" "$karar"; fi
  done <<< "$OLC"
  if [ "$JSON" = 1 ]; then echo "$JS]"; else
    echo "── $gerek compact gerek · $gonderildi gönderildi · $kuyruk kuyrukta · $olculemedi ölçülemedi$([ -s "$KUYRUK" ] && echo " · bekleyen kuyruk: $(grep -c . "$KUYRUK") ($KUYRUK)")"
    [ "$gerek" -gt 0 ] && [ "$UYGULA" = 0 ] && echo "   uygulamak: komut.sh compact --uygula   (AGENT_NAME=<reis>)"; fi
  exit 0
fi

# ── kuyruk turu ──
[ -s "$KUYRUK" ] || { [ "$JSON" = 1 ] || echo "compact kuyruğu boş"; exit 0; }
OLC="$(TEK="" olc_hepsi)" || exit 3
SIMDI=$(date +%s); KAL=""; gonderildi=0; dustu=0; kalan=0; vaz=0
while IFS= read -r satir; do
  [ -n "$satir" ] || continue
  ad="$(j "$satir" .koltuk)"; den="$(j "$satir" .deneme)"; ep="$(j "$satir" .epoch)"; kim="$(j "$satir" .kim)"
  if ! kayit_yetkili "$kim"; then echo "  ⛔ $ad · kuyruk kaydı YETKİSİZ (kim: ${kim:-yok}, reis: $(reis_adi || echo bilinmiyor)) — gönderilmeden düştü" >&2; dustu=$((dustu+1)); gunluk "compact kuyruk yetkisiz düştü: $ad (kim: ${kim:-yok})"; continue; fi
  cur="$(printf '%s\n' "$OLC" | awk -F'\t' -v a="$ad" '$1==a')"
  if [ -z "$cur" ]; then echo "  $ad · kuyruktan düştü (koltuk artık yok ya da Claude kapalı)"; dustu=$((dustu+1)); gunluk "compact kuyruk düştü: $ad (koltuk yok)"; continue; fi
  hal="$(printf '%s' "$cur" | cut -f2)"; y="$(printf '%s' "$cur" | cut -f3)"
  if [ "$y" != "-" ] && [ "$y" -lt "$ESIK" ]; then echo "  $ad · kuyruktan düştü (bu arada compact edilmiş: %$y)"; dustu=$((dustu+1)); gunluk "compact kuyruk düştü: $ad (artık %$y)"; continue; fi
  if [ "$hal" = bos ]; then
    if [ "$UYGULA" = 1 ]; then
      if compact_gonder "$ad" "$kim"; then echo "  $ad · ⟳ /compact GÖNDERİLDİ (kuyruktan, $kim adına, deneme $((den+1)))"; gonderildi=$((gonderildi+1)); continue; fi
      echo "  $ad · gönderilemedi (tmux), kuyrukta kalır"
    else echo "  $ad · BOŞ, gönderilebilir (--uygula yok)"; fi
  else echo "  $ad · hâlâ $hal, bekliyor (deneme $((den+1)))"; fi
  if [ $((den+1)) -ge "$TAVAN_DENEME" ] || [ $((SIMDI - ep)) -ge "$TAVAN_SN" ]; then
    echo "  🔴 $ad · VAZGEÇİLDİ ($((den+1)) deneme / $(( (SIMDI-ep)/3600 )) sa) — koltuk hiç boşalmadı, elle bak" >&2; vaz=$((vaz+1)); gunluk "compact VAZGEÇİLDİ: $ad"; continue; fi
  kalan=$((kalan+1)); KAL="$KAL$(printf '%s' "$satir" | jq -c --argjson d "$((den+1))" '.deneme=$d')"$'\n'
done < "$KUYRUK"
printf '%s' "$KAL" > "$KUYRUK"
echo "── compact-bekle: $gonderildi gönderildi · $dustu düştü · $kalan kuyrukta · $vaz vazgeçildi"
