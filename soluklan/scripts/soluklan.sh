#!/usr/bin/env bash
# soluklan.sh — bağlam dolmadan ÖNCE durup değerlendiren, çıpalayan ve sonrasını planlayan kapı.
#
# NİÇİN VAR (Sultan-direktifi): bağlam %60'ı geçince compact önerilecek. Ama bir compact,
#   hazırlıksız yapılırsa plan transkriptle birlikte gider. Bu araç sıranın mekanik yarısıdır:
#   ÖNCE çıpa diske yazılır, SONRA öneri üretilir.
#
# 🔴 ÖLÇEMEDİĞİM ŞEY (dürüst sınır, baştan yazıyorum): bu araç bağlam doluluğunu ÖLÇEMEZ.
#   Onu yalnız ajanın kendi göstergesi bilir. Doluluk DIŞARIDAN verilir (--doluluk).
#   Verilmezse araç "ölçemedim" der ve yeşil basmaz — tahmin ETMEZ.
#
# 🔴 VAR OLAN ARACIN KAPATMADIĞI AÇIK: `cipa.sh compact-onerisi` yalnız DOSYA VAR MI diye
#   bakıyor. Dünün çıpası da bir dosyadır; onunla compact'e girmek, kaybolmayacağını sandığın
#   bir planın BAYATINI korumaktır. Bu araç tazeliği de ölçer: çıpa BUGÜNÜN mü, ve içinde
#   yarım/açık madde var mı. Bayat çıpa = çıpa yok (fail-closed).
#
# Komutlar:
#   soluklan.sh hazir-mi [--doluluk N] [--esik N]   sıra tamam mı? rc=0 hazır · 1 eşik altı
#                                                   · 3 çıpa yok/bayat · 4 doluluk verilmedi
#   soluklan.sh oneri --doluluk N [--esik N]        Sultan'a sunulacak metin (hazır değilse ÜRETMEZ)
#   soluklan.sh sonrasi                              compact SONRASI: çıpayı geri oku + kontrol listesi
#   soluklan.sh cipa-yolu                            kullanılan çıpanın yolu
#
# Çıkış: 0 tamam · 1 eşik altı · 2 kullanım/ortam · 3 çıpa yok ya da bayat · 4 ölçemedim
set -uo pipefail

ESIK="${SOLUKLAN_ESIK:-60}"
CIPA_ARAC="${SOLUKLAN_CIPA_ARAC:-/config/.claude/skills/gunluk-plan/scripts/cipa.sh}"
BUGUN="${SOLUKLAN_BUGUN:-$(date +%F)}"

kullanim() { sed -n '/^# Komutlar:/,/^# Çıkış:/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

_cipa_yolu() {
  [ -f "$CIPA_ARAC" ] || return 1
  bash "$CIPA_ARAC" yol 2>/dev/null
}

# Çıpa TAZE mi: dosya var · BUGÜNÜN tarihini taşıyor · en az bir madde satırı var.
# Niçin üçü birden: boş bir çıpa dosyası da "var"dır ama hiçbir şey korumaz.
_cipa_durumu() { # yazdırır: yok | bayat:<tarih> | bos | taze
  local y; y="$(_cipa_yolu)" || { printf 'yok'; return; }
  [ -n "$y" ] && [ -f "$y" ] || { printf 'yok'; return; }
  local govde; govde="$(cat "$y" 2>/dev/null)"
  [ -n "$govde" ] || { printf 'yok'; return; }
  if ! printf '%s' "$govde" | grep -q "$BUGUN"; then
    local t; t="$(printf '%s' "$govde" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
    printf 'bayat:%s' "${t:-tarihsiz}"; return
  fi
  printf '%s' "$govde" | grep -qE '^- \[' || { printf 'bos'; return; }
  printf 'taze'
}

_acik_madde_sayisi() {
  local y; y="$(_cipa_yolu)" || { echo 0; return; }
  [ -f "$y" ] || { echo 0; return; }
  grep -cE '^- \[[ ~]\]' "$y" 2>/dev/null || echo 0
}

DOLULUK=""; KOMUT="${1:-}"; [ -n "$KOMUT" ] || kullanim; shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --doluluk) [ $# -ge 2 ] || { echo "HATA: --doluluk değer ister" >&2; exit 2; }; DOLULUK="$2"; shift 2 ;;
    --esik)    [ $# -ge 2 ] || { echo "HATA: --esik değer ister" >&2; exit 2; };    ESIK="$2";    shift 2 ;;
    *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done

case "$KOMUT" in
  cipa-yolu) _cipa_yolu || { echo "HATA: çıpa aracı bulunamadı: $CIPA_ARAC" >&2; exit 2; }; echo; exit 0 ;;

  hazir-mi|oneri)
    DURUM="$(_cipa_durumu)"
    case "$DURUM" in
      yok)   echo "🔴 ÇIPA YOK — compact önerilmez. Önce planı diske yaz (çıpa aracı 'yaz')."; exit 3 ;;
      bayat:*) echo "🔴 ÇIPA BAYAT (${DURUM#bayat:}) — bugünün planı değil. Dünün çıpasıyla compact'e girmek"
               echo "   kaybolmayacağını sandığın bir planın BAYATINI korur. Önce tazele."; exit 3 ;;
      bos)   echo "🔴 ÇIPA BOŞ — dosya var ama madde yok; hiçbir şey korumuyor. Önce planı yaz."; exit 3 ;;
    esac
    if [ -z "$DOLULUK" ]; then
      echo "◻ ÖLÇEMEDİM: bağlam doluluğunu bu araç ölçemez, ajanın kendi göstergesinden gelir (--doluluk)."
      echo "  Çıpa TAZE ve $(_acik_madde_sayisi) açık madde taşıyor — sıra tamam, eksik olan yalnız sayı."
      exit 4
    fi
    case "$DOLULUK" in (*[!0-9]*|"") echo "HATA: --doluluk tam sayı olmalı (yüzde): '$DOLULUK'" >&2; exit 2 ;; esac
    if [ "$DOLULUK" -lt "$ESIK" ]; then
      echo "🟢 Eşik altı: doluluk %$DOLULUK < %$ESIK — compact önerilmez, çalışmaya devam."
      exit 1
    fi
    [ "$KOMUT" = hazir-mi ] && { echo "🟡 HAZIR: doluluk %$DOLULUK ≥ %$ESIK · çıpa TAZE · $(_acik_madde_sayisi) açık madde"; exit 0; }
    cat <<M
🟡 SOLUKLANMA ZAMANI · doluluk %$DOLULUK (eşik %$ESIK)

Planı diske yazdım, kaybolmaz — $(_acik_madde_sayisi) açık madde çıpada duruyor.
Compact'ten sonra kaldığım yerden, aynı maddelerle devam ederim.

Compact yapalım mı?
M
    exit 0 ;;

  sonrasi)
    DURUM="$(_cipa_durumu)"
    case "$DURUM" in
      yok|bos) echo "🔴 ÇIPA YOK/BOŞ — compact sonrası geri okunacak plan bulunamadı. Bu, sıranın"
               echo "   bozulduğunu gösterir (çıpa compact'ten ÖNCE yazılmalıydı). Uydurma plan yazma;"
               echo "   Sultan'a 'planı kaybettim' de ve yeniden ölç."; exit 3 ;;
    esac
    y="$(_cipa_yolu)"
    echo "⚓ ÇIPADAN GERİ OKUNAN PLAN${DURUM#taze}"
    [ "${DURUM%%:*}" = bayat ] && echo "⚠ DİKKAT: çıpa bugünün değil (${DURUM#bayat:}) — maddeler bayat olabilir, ölçmeden sürdürme."
    echo "────────────────────────────────────────"
    cat "$y"
    echo "────────────────────────────────────────"
    cat <<'M'
SONRAKİ ÜÇ ADIM (atlanmaz):
  1. ORTAM DAMGASI — neredeyim, hangi dal, ağaç temiz mi? Compact harness durumunu sıfırlar.
  2. ÇIPAYI DOĞRULA — maddeler hâlâ geçerli mi? Bir madde bu arada başkası tarafından
     kapanmış olabilir; "açık" damgası bir İDDİADIR, ölçüm değil.
  3. YENİDEN PLANLA — kapanabilir olanı öne al, kilidi açanı ikinci sıraya; Sultan'ın
     ekranında değişen iş ile görünmez altyapı arasında seçim gerekiyorsa birincisini sun.
M
    exit 0 ;;

  *) kullanim ;;
esac
