#!/usr/bin/env bash
# sikistirma-ortami.test.sh — yerli otomatik sıkıştırma eşiği (600k) başlatıcıya ve bekçiye GİRDİ Mİ, ÇALIŞTIRILARAK ölçülür (gorev_…880TAK · 26 Eki 2026).
#
# Niçin: Sultan "600k (%60) tüm filoya, yeni oturumlarda açık, kontrol mekanizması olsun" dedi; SERDAR yolu çizdi: ortak settings.json
# 13 kutuda ortak → oraya yazılmaz, eşik OTURUMA ortamla verilir (CLAUDE_CODE_AUTO_COMPACT_WINDOW, ölçüldü: claude 2.1.310 ayar
# dosyasının üstüne çıkar). Bu sınav üç şeyi ölçer: (1) claude_baslat'ın tmux'a YAZDIĞI satır öneki taşıyor mu (ana koltuk + kurtarıcı
# aynı yardımcıdan geçer) · (2) öneğin kaynağı tek yer mi (TO_AUTOCOMPACT) ve kaldırılınca sınav DÜŞÜYOR mu (mutant) ·
# (3) bekçinin sikistirma_denetle'si ortam / hesap ayarı / eksik / sapmış değer / koşan claude yok hâllerini doğru ayırıyor mu.
# Hermetik: sahte tmux (send-keys günlüğe), sahte claude_pid, sahte /proc ağacı; gerçek tmux'a ve claude'a DOKUNULMAZ.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT
mkdir -p "$T/bin" "$T/proje" "$T/durum"

# ── sahte tmux: pane 'bash' görünür, send-keys günlüğe yazılır ───────────────
cat > "$T/bin/tmux" <<EOF
#!/usr/bin/env bash
case "\$1" in display) echo bash ;; list-panes) echo %1 ;; send-keys) echo "send-keys \$*" >> "$T/tmux.log" ;; *) exit 0 ;; esac
EOF
chmod +x "$T/bin/tmux"

# Çalışma kopyası: ortak.sh'ın sonuna sahte kutu + sıfır bekleme; claude_baslat DEPODAKİ BAYTLARDIR (onar.sh'tan sed ile çıkarılır),
# claude_pid sahtesi ilk çağrıda "yok" (K0 DUR dalı tetiklenmesin), sonrakilerde "doğdu" der.
hazirla() {  # $1 = hedef dizin · $2 = onar.sh süzgeci (sed ifadesi; boş = aynen)
  mkdir -p "$1"; cp -r "$KOK/scripts" "$1/"
  [ -n "${2:-}" ] && sed -i "$2" "$1/scripts/onar.sh"
  cat >> "$1/scripts/ortak.sh" <<'EOF'
export PATH="$TO_SAHTE_BIN:$PATH"
sleep() { :; }
EOF
  { echo '#!/usr/bin/env bash'; echo 'set -u'; echo '. "$(dirname "$0")/ortak.sh"'
    echo 'claude_pid() { if [ -f "$TO_DURUM_DIZ/dogdu" ]; then echo 4242; return 0; fi; : > "$TO_DURUM_DIZ/dogdu"; return 1; }'
    sed -n '/^claude_baslat() {/,/^}/p' "$1/scripts/onar.sh"
    echo 'claude_baslat "$1" "$2"'; } > "$1/scripts/baslat-sinav.sh"
}
EK=()   # ek ortam atamaları (dizi: boşluklu değer bölünmesin)
kos() { # kos <çalışma dizini> <komut…>  (ek ortam: EK dizisi)
  local m="$1"; shift
  env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" TO_BEKCI_YOK=1 \
      TO_BECERI_KOK="$m" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" TO_BEKLE_ADIM=0.01 ${EK[@]+"${EK[@]}"} "$@"
}
sifirla() { rm -f "$T/tmux.log" "$T/durum/dogdu"; }

M="$T/calisma"; hazirla "$M"
echo "── 1) claude_baslat'ın tmux'a yazdığı satır ──"
sifirla; kos "$M" bash "$M/scripts/baslat-sinav.sh" sinav-ana "claude -n sinav --permission-mode auto" >/dev/null 2>&1; rc=$?
kapi "K1 başlatma 'doğdu' ile döndü (rc 0)" "0" "$rc"
satir=$(grep 'send-keys' "$T/tmux.log" 2>/dev/null | grep -- '-l' | head -1)
kapi "K1b yazılan satırda bellek öneğinden SONRA, komuttan ÖNCE 600k eşiği" "e" \
  "$(printf '%s' "$satir" | grep -q 'MALLOC_ARENA_MAX=2 CLAUDE_CODE_AUTO_COMPACT_WINDOW=600k claude -n sinav' && echo e || echo h)"
sifirla; EK=(TO_AUTOCOMPACT=500k CLAUDE_CODE_AUTO_COMPACT_WINDOW=900k); kos "$M" bash "$M/scripts/baslat-sinav.sh" sinav-ana "claude -n sinav" >/dev/null 2>&1
EK=(); kapi "K2 standart SABİT: dış ortam başka değer verse de satırda 600k (kaçış yok)" "e" "$(grep -q 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=600k claude -n sinav' "$T/tmux.log" 2>/dev/null && ! grep -q '500k\|900k' "$T/tmux.log" && echo e || echo h)"
# kurtarıcı aynı yardımcıdan geçer: onar.sh adım 4 claude_baslat'ı çağırır (statik, bayt-aynı yardımcı)
kapi "K3 ana koltuk (iki dal) + kurtarıcı aynı claude_baslat ile açılır (ikinci başlatma yolu yok)" "3" "$(grep -c 'claude_baslat "\$' "$KOK/scripts/onar.sh")"

echo "── 2) mutant: önek onar.sh'tan kaldırılınca sınav DÜŞER ──"
MU="$T/mutant"; hazirla "$MU" 's/ \$SIKISTIRMA_ENV / /'
sifirla; kos "$MU" bash "$MU/scripts/baslat-sinav.sh" sinav-ana "claude -n sinav" >/dev/null 2>&1
kapi "M1 mutant satırda eşik YOK (K1b bunu yakalar; yeşil görünmez)" "h" "$(grep -q 'CLAUDE_CODE_AUTO_COMPACT_WINDOW' "$T/tmux.log" 2>/dev/null && echo e || echo h)"
kapi "M1b mutant gerçekten uygulandı (onar.sh farklı)" "h" "$(cmp -s "$M/scripts/onar.sh" "$MU/scripts/onar.sh" && echo e || echo h)"

echo "── 3) bekçi: sikistirma_denetle sahte /proc ile ──"
P="$T/proc"; mkdir -p "$P/11" "$P/12" "$P/13" "$P/14" "$P/15" "$T/hesap/a" "$T/hesap/b"
printf 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=600k\0PATH=x\0' > "$P/11/environ"                      # ortam standart
printf 'CLAUDE_CONFIG_DIR=%s/hesap/a\0PATH=x\0' "$T" > "$P/12/environ"                          # ortam yok, hesap ayarı 600000
printf 'PATH=x\0' > "$P/13/environ"                                                              # ikisi de yok (kök ayar da yok)
printf 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=900k\0CLAUDE_CONFIG_DIR=%s/hesap/a\0' "$T" > "$P/14/environ"  # ortam SAPMIŞ (ayar iyi olsa da)
printf 'CLAUDE_CONFIG_DIR=%s/hesap/b\0' "$T" > "$P/15/environ"                                   # ortam yok, ayar 'auto'
mkdir -p "$P/16" "$P/17"; printf 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=600\0CLAUDE_CONFIG_DIR=%s/hesap/a\0' "$T" > "$P/16/environ"   # '600' ≠ '600k' (göz tur 1)
printf 'CLAUDE_CODE_AUTO_COMPACT_WINDOW=600000\0CLAUDE_CONFIG_DIR=%s/hesap/a\0' "$T" > "$P/17/environ"                      # '600000' de standart yazım değil
echo '{"autoCompactWindow":600000}' > "$T/hesap/a/settings.json"
echo '{"autoCompactWindow":"auto"}' > "$T/hesap/b/settings.json"
den() { EK=("TO_PROC=$P" "TO_CLAUDE_PIDLER=$1"); kos "$M" bash -c '. "$TO_BECERI_KOK/scripts/ortak.sh"; sikistirma_denetle' 2>/dev/null; }
kapi "B1 ortam 600k + hesap ayarı 600000 → güncel" "güncel" "$(den "11 12")"
kapi "B2 ortamsız+ayarsız · sapmış ortam · 'auto' ayar · '600' · '600000' → beşi eşiksiz, sapma değeriyle (yalnız tam '600k' açık)" "5 koltuk eşiksiz: 13 14(ortam=900k) 15 16(ortam=600) 17(ortam=600000)" "$(den "11 12 13 14 15 16 17")"
kapi "B3 koşan claude yok → ölçülemedi (yeşil değil)" "ölçülemedi: koşan claude yok" "$(den "")"
EK=("TO_PROC=$P" "TO_CLAUDE_PIDLER="); kos "$M" bash -c '. "$TO_BECERI_KOK/scripts/ortak.sh"; sikistirma_denetle' >/dev/null 2>&1; kapi "B3b … rc 3" "3" "$?"
kapi "B4 bekçi her turda ölçer ve yalnız DEĞİŞİNCE günlüğe yazar (statik)" "e" \
  "$(grep -q '_sk="\$(sikistirma_denetle' "$KOK/scripts/bekci.sh" && grep -q 'sikistirma.son' "$KOK/scripts/bekci.sh" && echo e || echo h)"

echo "SONUÇ: geçen=$gecen kalan=$kalan"
[ "$kalan" = 0 ]
