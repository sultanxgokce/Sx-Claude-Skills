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
# ÇIKIŞ: 0 = yalnız KİP, TAM çift 100644 → 100755 (çakışma sayılmaz, uyarı yeter) · 1 = GERÇEK dokunuş (çakışma)
#        3 = ÖLÇÜLEMEDİ (gh yok · diff alınamadı · bölüm bulunamadı) — "temiz" DEĞİL
set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GECICI_FARK="$(mktemp)"; trap 'rm -f "$GECICI_FARK"' EXIT

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
# 🔴 Yol ALAN BÖLMEKLE ÇIKARILMAZ ve HAM yolla da aranmaz (bağımsız göz, tur 1 ve tur 3):
#    git, boşluklu yolları TIRNAKLAR; `core.quotePath` açıkken (varsayılan) ASCII dışı yolları
#    ayrıca C biçiminde KAÇIŞLAR. Gerçek git çıktısıyla ölçüldü:
#        diff --git "a/\303\266l\303\247\303\274m dosyas\304\261.sh" "b/..."
#    ( = `ölçüm dosyası.sh` ). Bu filoda dosya adları Türkçedir; ham yolu arayan bir eşleştirici
#    geçerli bir yalnız-kip dosyasını bulamaz ve rc=3'e düşerdi — fail-closed tarafta, ama yanlış.
#    Ayrıştırma bu yüzden ayrı ve sınanabilir bir araçta: bolum-ayikla.py (tırnağı ve kaçışı çözer,
#    kısmi ad eşleşmesini hâlâ tutmaz).
BOLUM="$(printf '%s\n' "$FARK" > "$GECICI_FARK" && python3 "$BURASI/bolum-ayikla.py" "$GECICI_FARK" "$YOL")"

if [ -z "$BOLUM" ]; then
  echo "ÖLÇÜLEMEDİ: '$YOL' bu diff'te bir bölüm olarak bulunamadı" >&2
  exit 3
fi

hunk=$(printf '%s\n' "$BOLUM" | grep -c '^@@' || true)
# Kip İNDİRİMİ yalnız TAM bir çifte verilir (göz #337 tur 1, kart pr-kip-olcer): tek bir `old mode`/`new mode` satırı
#   ya da 100644→100755 dışındaki bir çift (ters yön · sembolik bağ 120000 · alt modül 160000) "yalnız kip" SAYILMAZ.
eski_kip=$(printf '%s\n' "$BOLUM" | sed -n 's/^old mode \([0-7]\{6\}\)$/\1/p')
yeni_kip=$(printf '%s\n' "$BOLUM" | sed -n 's/^new mode \([0-7]\{6\}\)$/\1/p')
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
  if [ "$kip" -ne 2 ] || [ "$(printf '%s\n' "$eski_kip" | grep -c .)" -ne 1 ] || [ "$(printf '%s\n' "$yeni_kip" | grep -c .)" -ne 1 ]; then
    echo "ÖLÇÜLEMEDİ: '$YOL' kip bölümü EKSİK/bozuk (old='${eski_kip//$'\n'/,}' new='${yeni_kip//$'\n'/,}') — 'zararsız' SAYILMAZ" >&2; exit 3
  fi
  if [ "$eski_kip" = 100644 ] && [ "$yeni_kip" = 100755 ]; then
    echo "YALNIZ KİP: '$YOL' — 100644 → 100755 (çalıştırma biti), içerik farkı YOK (satır: 0)"; exit 0
  fi
  echo "GERÇEK: '$YOL' kip $eski_kip → $yeni_kip — indirim yalnız 100644 → 100755 içindir (fail-closed)"; exit 1
fi

# Buraya düşmek: hunk yok, kip yok, rename yok, binary yok, silme yok. Tanımadığımız bir hâl.
echo "ÖLÇÜLEMEDİ: '$YOL' bölümü tanınmadı (hunk 0 · kip 0) — 'zararsız' SAYILMAZ" >&2
exit 3
