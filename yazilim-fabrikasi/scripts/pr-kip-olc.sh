#!/usr/bin/env bash
# pr-kip-olc.sh — bir açık PR'ın BİR dosyaya dokunuşu GERÇEK mi, yoksa yalnız dosya KİPİ mi?
#
# NİÇİN VAR (ölçülmüş vaka, 15 Ekim 2026): `is-alani.sh ac --dosyalar …` kapsam kapısı
#   `gh pr diff --name-only` ile YOL listesi karşılaştırıyordu. PR #326 yedi betiğe yalnız
#   çalıştırma biti veriyordu (`old mode 100644` → `new mode 100755`, içerik farkı SIFIR
#   satır); kapı bunu "KAPSAM ÇAKIŞMASI" sayıp iş alanı AÇMADI. Yani zararsız bir izin PR'ı,
#   o dosyalara dokunacak bütün işleri blokluyordu. Kapı ADLARI karşılaştırıyordu, SATIRLARI
#   değil — ve iki ad eşleşmesi iki işin aynı satırlara dokunduğunu KANITLAMAZ.
#
# NE ÖLÇER: verilen yolun, verilen PR'ın diff'indeki bölümünde içerik parçası (`@@` hunk)
#   var mı. Çıkış koduyla söyler; karar çağıranındır.
#
# 🔴 YALNIZ KİP ucuza indirilir, ÖTEKİ HER ŞEY ÇAKIŞMA SAYILIR (fail-closed). Niçin:
#   "hunk yok" ≠ "zararsız". Bir dosya yeniden ADLANDIRILMIŞ ya da SİLİNMİŞ olabilir — ikisinde
#   de hunk yoktur ama ikisi de gerçek çatışmadır (benim düzenlediğim dosya ayağımın altından
#   kayar). İkili (binary) dosyada da hunk yoktur, değişiklik gerçektir. Bu yüzden indirim
#   YALNIZ şu durumda verilir: kip satırı VAR · hunk YOK · rename/copy YOK · binary YOK.
#   Ayrıştıramadığımız her hâl ÇAKIŞMA'dır — ölçemediğimizde bloklamak güvenli taraftır,
#   çünkü yanlış blok bir işi geciktirir, yanlış geçiş iki ajanı aynı satıra sokar.
#
# KULLANIM
#   pr-kip-olc.sh <pr-no> <dosya-yolu> [--depo <kök>]
#   pr-kip-olc.sh --fark <dosya> <dosya-yolu>      # hazır diff metninden (sınav/çevrimdışı)
#
# ÇIKIŞ: 0 = yalnız KİP (çakışma sayılmaz, uyarı yeter) · 1 = GERÇEK dokunuş (çakışma)
#        3 = ÖLÇÜLEMEDİ (gh yok · diff alınamadı · bölüm bulunamadı) — "temiz" DEĞİL
set -uo pipefail

_kullanim() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

PR=""; YOL=""; DEPO="${PWD}"; FARK_DOSYA=""
while [ $# -gt 0 ]; do
  case "$1" in
    # 🔴 Değer isteyen bayrak, değeri eksikse SESSİZCE yutulmaz (bağımsız göz bulgusu):
    #    `set -u` altında $2'ye dokunmak kabuk hatası verir ve aracın tanımlı çıkış kodları
    #    yerine beklenmedik bir kodla düşer. Ölçüm aracının kendi çıkışı belirsizse ölçüm de
    #    belirsizdir. (Aynı sınıf, yoğunluk kapısında 0.3.0'a kadar ölü bayrak olarak yaşadı.)
    --depo) [ $# -ge 2 ] || { echo "--depo bayrağının değeri eksik" >&2; exit 2; }
            DEPO="$2"; shift 2 ;;
    --fark) [ $# -ge 2 ] || { echo "--fark bayrağının değeri eksik" >&2; exit 2; }
            FARK_DOSYA="$2"; shift 2 ;;
    -h|--help) _kullanim ;;
    *) if [ -z "$PR" ] && [ -z "$FARK_DOSYA" ]; then PR="$1"; elif [ -z "$YOL" ]; then YOL="$1";
       else echo "fazla argüman: $1" >&2; exit 2; fi; shift ;;
  esac
done
[ -n "$YOL" ] || _kullanim
[ -n "$PR" ] || [ -n "$FARK_DOSYA" ] || _kullanim

# ── diff metnini al ────────────────────────────────────────────────────────────────────
if [ -n "$FARK_DOSYA" ]; then
  [ -f "$FARK_DOSYA" ] || { echo "ÖLÇÜLEMEDİ: fark dosyası yok: $FARK_DOSYA" >&2; exit 3; }
  FARK="$(cat "$FARK_DOSYA")"
else
  command -v gh >/dev/null 2>&1 || { echo "ÖLÇÜLEMEDİ: gh yok — PR diff'i alınamadı" >&2; exit 3; }
  FARK="$(cd "$DEPO" && gh pr diff "$PR" 2>/dev/null)" \
    || { echo "ÖLÇÜLEMEDİ: gh pr diff $PR düştü (yetki/ağ)" >&2; exit 3; }
  [ -n "$FARK" ] || { echo "ÖLÇÜLEMEDİ: PR #$PR diff'i BOŞ döndü" >&2; exit 3; }
fi

# ── o dosyanın bölümünü kes ────────────────────────────────────────────────────────────
# `diff --git a/<yol> b/<yol>` satırından bir SONRAKİ `diff --git ` satırına kadar.
# Yol birebir eşleşir (grep -F mantığı): kısmi ad eşleşmesi yanlış bölüm keser.
# 🔴 Yol ALAN BÖLMEKLE çıkarılmaz (bağımsız göz bulgusu): git, boşluk ya da özel karakter
#    içeren yolları diff başlığında TIRNAKLAR (`diff --git "a/iki kelime.sh" "b/iki kelime.sh"`).
#    `$3`/`$4` ile bölmek o satırı parçalar ve geçerli bir yalnız-kip dosyası rc=3'e düşer.
#    Bunun yerine dört olası jeton (a/P · "a/P" · b/P · "b/P") jeton SINIRIYLA aranır:
#    eşleşmenin solu satır başı ya da boşluk, sağı satır sonu ya da boşluk olmalı — kısmi ad
#    eşleşmesi (denetle.test.sh ⟂ yogunluk-denetle.test.sh) hâlâ TUTMAZ.
BOLUM="$(printf '%s\n' "$FARK" | awk -v yol="$YOL" '
  function jeton(s, t,   i, sol, sag) {
    i = index(s, t)
    while (i > 0) {
      sol = (i == 1) ? " " : substr(s, i - 1, 1)
      sag = substr(s, i + length(t), 1)
      if ((sol == " " || i == 1) && (sag == "" || sag == " ")) return 1
      s = substr(s, i + 1); i = index(s, t)
    }
    return 0
  }
  $0 ~ /^diff --git / {
    kalan = substr($0, 12)
    bas = (jeton(kalan, "a/" yol) || jeton(kalan, "b/" yol) \
           || jeton(kalan, "\"a/" yol "\"") || jeton(kalan, "\"b/" yol "\""))
  }
  bas { print }
')"

if [ -z "$BOLUM" ]; then
  echo "ÖLÇÜLEMEDİ: '$YOL' bu diff'te bir bölüm olarak bulunamadı" >&2
  exit 3
fi

hunk=$(printf '%s\n' "$BOLUM" | grep -c '^@@' || true)
kip=$(printf '%s\n' "$BOLUM" | grep -cE '^(old|new) mode [0-7]{6}$' || true)
adlandirma=$(printf '%s\n' "$BOLUM" | grep -cE '^(rename|copy) (from|to) ' || true)
ikili=$(printf '%s\n' "$BOLUM" | grep -cE '^(Binary files|GIT binary patch)' || true)
silme=$(printf '%s\n' "$BOLUM" | grep -cE '^deleted file mode ' || true)

if [ "$hunk" -gt 0 ]; then
  echo "GERÇEK: '$YOL' içerik değişiyor ($hunk parça)"; exit 1
fi
if [ "$adlandirma" -gt 0 ]; then
  echo "GERÇEK: '$YOL' yeniden ADLANDIRILIYOR/kopyalanıyor — hunk yok ama dosya yer değiştirir"; exit 1
fi
if [ "$silme" -gt 0 ]; then
  echo "GERÇEK: '$YOL' SİLİNİYOR — hunk yok ama dosya kalmıyor"; exit 1
fi
if [ "$ikili" -gt 0 ]; then
  echo "GERÇEK: '$YOL' ikili dosya olarak değişiyor — hunk görünmez, değişiklik gerçek"; exit 1
fi
if [ "$kip" -gt 0 ]; then
  echo "YALNIZ KİP: '$YOL' — dosya izni değişiyor, içerik farkı YOK (satır: 0)"; exit 0
fi

# Buraya düşmek: hunk yok, kip yok, rename yok, binary yok, silme yok. Tanımadığımız bir hâl.
echo "ÖLÇÜLEMEDİ: '$YOL' bölümü tanınmadı (hunk 0 · kip 0) — 'zararsız' SAYILMAZ" >&2
exit 3
