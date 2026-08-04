#!/usr/bin/env bash
# cs-liste.test.sh — seans listesi kalabalık mı, gizlenen sayı söyleniyor mu, ad soruluyor mu?
#
# NİÇİN VAR (firsthand 2026-07-30): Sultan "kapanan sohbete dön deyince çok karmaşık bir
# cümbüşün içine düşüyorum" dedi. ÖLÇTÜM: liste 104 satır, 80'i KAPALI geçmiş (%88 tarih),
# canlı iş yalnız 11 satır. Ayrıca ^N ile açılan seansların adı SORULMUYORDU → listede "—"
# olarak birikiyordu ve hangisi olduğu bilinemiyordu.
#
# Bu sınama YALITILMIŞ koşar: cmd_feed fonksiyonu metinden çıkarılıp sahte veri kaynaklarıyla
# çağrılır. Makinedeki gerçek seans sayısına BAĞLI DEĞİL (yoksa CI'da 0 seansla sahte-yeşil
# yanardı — "atlandı ≠ geçti").
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/cs.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
[ -r "$S" ] || { echo "❌ bulunamadı: $S"; exit 1; }
bash -n "$S"; g $? "cs.sh sözdizimi"
command -v jq >/dev/null 2>&1 || { echo "❌ jq yok — kapı koşamaz (atlamak YEŞİL değildir)"; exit 1; }

# cmd_feed'i sahte kaynaklarla koştur. <limit-arg> → çıktı
_feed_dene() {
  local arg="${1:-}" kapali_sayi="${2:-40}"
  bash -c '
    set -uo pipefail
    EKIP_TAG="🏛 EKİP"; FEDERE_TAG="🛰 FİLO"; NOTES="/dev/null"; PREFS="/dev/null"
    require_jq(){ :; }
    # 2 canlı ekip seansı (üstte pinli beklenir)
    load_sessions(){ printf "1\tab\tsid-canli-1\tSERDAR\tidle\t%s · AILE\tnot1\n2\tcd\tsid-canli-2\tMOTOR\tbusy\t%s · AILE\t\n" "$EKIP_TAG" "$EKIP_TAG"; }
    # N kapalı seans (limit kadar kırpılmalı)
    load_closed_sessions(){ local n="${1:-20}" i=1
      while [ "$i" -le "$n" ] && [ "$i" -le '"$kapali_sayi"' ]; do
        printf "proje-x\tsid-kapali-%03d\tkapali-%03d\t3g\t\n" "$i" "$i"; i=$((i+1)); done; }
    eval "$(sed -n "/^cmd_feed()/,/^}/p" "'"$S"'")"
    cmd_feed '"$arg"'
  ' 2>&1
}

# ── G1 · varsayılan liste KIRPILIR (kalabalık kapısı)
o="$(_feed_dene "" 40)"
n_kapali="$(printf '%s\n' "$o" | grep -c 'kapali-' || true)"
[ "$n_kapali" -le 15 ] && g 0 "varsayılan listede kapalı seans ≤15 (ölçülen: $n_kapali)" \
                       || g 1 "varsayılan liste kırpılmıyor (kapalı=$n_kapali)"

# ── G2 · GİZLENEN SAYI SÖYLENİR (sessiz kırpma yasak — bugünkü üç arızanın ortak sınıfı)
printf '%s\n' "$o" | grep -q 'kapalı seans daha var' \
  && g 0 "gizlenen kapalı seans sayısı açıkça yazılıyor" \
  || g 1 "SESSİZ KIRPMA — gizlenen sayı söylenmiyor"
printf '%s\n' "$o" | grep -q '25 kapalı seans daha var' \
  && g 0 "gizlenen sayı DOĞRU (40-15=25)" \
  || g 1 "gizlenen sayı yanlış: $(printf '%s\n' "$o" | grep -o '[0-9]* kapalı seans daha var' | head -1)"

# ── G3 · --hepsi hepsini gösterir ve "daha var" satırı KALMAZ
o2="$(_feed_dene --hepsi 40)"
n2="$(printf '%s\n' "$o2" | grep -c 'kapali-' || true)"
[ "$n2" -eq 40 ] && g 0 "--hepsi tüm kapalıları gösteriyor (40)" || g 1 "--hepsi eksik gösteriyor ($n2)"
printf '%s\n' "$o2" | grep -q 'daha var' \
  && g 1 "--hepsi'de hâlâ 'daha var' diyor (yanıltıcı)" \
  || g 0 "--hepsi'de 'daha var' satırı YOK"

# ── G4 · gizlenecek şey yoksa satır BASILMAZ (gürültü yok)
o3="$(_feed_dene "" 5)"
printf '%s\n' "$o3" | grep -q 'daha var' \
  && g 1 "gizlenen yokken bile 'daha var' basıyor" \
  || g 0 "gizlenecek yoksa satır basılmıyor"

# ── G5 · EKİP satırları kapalı geçmişin ÜSTÜNDE (demirbaş üstte sabit)
ilk_ekip="$(printf '%s\n' "$o" | grep -n 'SERDAR' | head -1 | cut -d: -f1)"
ilk_kapali="$(printf '%s\n' "$o" | grep -n 'kapali-' | head -1 | cut -d: -f1)"
if [ -n "$ilk_ekip" ] && [ -n "$ilk_kapali" ] && [ "$ilk_ekip" -lt "$ilk_kapali" ]; then
  g 0 "ekip seansları kapalı geçmişin üstünde"
else
  g 1 "sıra yanlış (ekip=$ilk_ekip kapalı=$ilk_kapali)"
fi

# ── G6 · yeni seans AD SORUYOR ve motorun var olan ucunu kullanıyor (kopya yok)
grep -q 'Bu sohbetin adı ne olsun' "$S";        g $? "yeni seans yolunda ad soruluyor"
# ⚠️ ZAYIF KAPI TUZAĞI: ilk hâlim `grep 'cmd_new --ad'` idi ve ESKİ sürümde de YEŞİL yandı —
# çünkü o metin `cmd_new`in kendi argüman-ayrıştırma satırında da geçiyor. Kapı, koruduğunu
# sandığı şeyi denetlemiyordu. Artık ÇAĞRI YERİ aranıyor (değişkenle birlikte).
grep -qE 'cmd_new --ad "\$ad"' "$S";            g $? "ad motorun var olan --ad ucuna GEÇİRİLİYOR (çağrı yeri)"
# ^A bağlaması ve dağıtıcı argüman aktarımı
grep -q "ctrl-a:reload(cs _feed --hepsi)" "$S"; g $? "^A tüm geçmişi açan bağlama var"
grep -q '\^A tüm geçmiş' "$S";                  g $? "^A başlıkta duyuruluyor (gizli kısayol değil)"
grep -qE '_feed\).*shift; cmd_feed' "$S";       g $? "dağıtıcı --hepsi argümanını aktarıyor"

echo ""
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
