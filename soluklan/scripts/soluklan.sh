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
AZAMI_YAS_DK="${SOLUKLAN_AZAMI_YAS_DK:-240}"   # çıpa bu kadar dakikadan eskiyse BAYAT (aynı gün olsa bile)
CIPA_ARAC="${SOLUKLAN_CIPA_ARAC:-/config/.claude/skills/gunluk-plan/scripts/cipa.sh}"
BUGUN="${SOLUKLAN_BUGUN:-$(date +%F)}"

# Sayı olmayan eşik/yaş sessizce 0 sayılmaz — karşılaştırma hatası fail-OPEN üretirdi
# (bağımsız göz tur 1): `[ "$D" -lt "$E" ]` hatalı E ile çöker, betikte `set -e` yok,
# akış hazır/öneri yoluna düşebilirdi. Sayı kapısı giriş noktasında.
_sayi_mi() { case "${1:-}" in (""|*[!0-9]*) return 1 ;; (*) return 0 ;; esac; }
_sayi_mi "$ESIK"        || { echo "HATA: eşik tam sayı olmalı (yüzde): '$ESIK'" >&2; exit 2; }
_sayi_mi "$AZAMI_YAS_DK" || { echo "HATA: azami yaş tam sayı olmalı (dakika): '$AZAMI_YAS_DK'" >&2; exit 2; }

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
  # 🔴 TARİH BAŞLIKTAN OKUNUR, gövdeden ARANMAZ (bağımsız göz tur 2): `grep -q "$BUGUN"`
  #    gövdenin herhangi bir yerinde bugünün tarihini görünce "taze" diyordu — dünün planı
  #    içinde bugünü anan tek bir satır (ör. "yarın 8 Ekim'de teslim") kapıyı geçiriyordu.
  #    Yakınlık bağ değildir: tarih, çıpanın KENDİ başlık alanından ayrıştırılır.
  local baslik_tarih
  baslik_tarih="$(printf '%s' "$govde" | sed -n 's/^#[[:space:]]*⚓[^0-9]*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*$/\1/p' | head -1)"
  if [ -z "$baslik_tarih" ]; then printf 'bayat:basliksiz'; return; fi
  if [ "$baslik_tarih" != "$BUGUN" ]; then printf 'bayat:%s' "$baslik_tarih"; return; fi
  printf '%s' "$govde" | grep -qE '^- \[' || { printf 'bos'; return; }
  # 🔴 AYNI GÜN DE BAYATLAR (bağımsız göz tur 1): takvim günü tek başına tazelik DEĞİLDİR.
  #   Sabah 09:30'da yazılmış bir çıpa akşam 23:00'te hâlâ "bugünün" ama planı anlatmıyor.
  #   İlk yazımda bunu "bilinen sınır" diye BELGELEDİM — oysa belgelemek onarmak değildir;
  #   ölçülebilir bir şeyi ölçmeyip dipnota yazmak, kapıyı süse çevirir.
  #   İki yüzeyden yaş: çıpanın kendi damgası (_yazıldı:) ve dosyanın değişme zamanı;
  #   hangisi TAZE ise o kazanır (tazele dosyayı günceller ama damgayı değiştirmeyebilir).
  # 🔴 YAŞ: EN ESKİ yüzey kazanır (fail-closed). İlk yazımda "taze olan kazanır" demiştim;
  #    bu FAIL-OPEN'dı — bağımsız göz haklı olarak gösterdi: eski içerikli bir dosyaya boş
  #    bir dokunuş yapmak yaşı sıfırlıyordu. İki yüzey farklı soruları yanıtlar:
  #      `_dokunuldu:` → çıpa SON NE ZAMAN güncellendi (tazele artık bunu yazıyor; otorite budur)
  #      `_yazıldı:`   → plan ne zaman KURULDU (tazelemede değişmez, tek başına hep eskidir)
  #      dosya zamanı  → herhangi bir yazma (boş dokunuşla kandırılabilir)
  #    Kural: dokunma damgası varsa O esastır; yoksa yazım damgası. Dosya zamanı tek başına
  #    tazelik KANITI sayılmaz — yalnız damgayı DOĞRULAR: damga diyor ki taze ama dosya
  #    ondan da eskiyse, eski olan kazanır.
  local dokunma yazim yas_dk mtime_yas sn
  dokunma="$(printf '%s' "$govde" | sed -n 's/^_dokunuldu:[[:space:]]*\([0-9T:+-]\{19,25\}\).*$/\1/p' | tail -1)"
  yazim="$(printf '%s' "$govde" | sed -n 's/^_yazıldı:[[:space:]]*\([0-9T:+-]\{19,25\}\).*$/\1/p' | tail -1)"
  damga="${dokunma:-$yazim}"
  yas_dk=""
  if [ -n "$damga" ]; then
    sn="$(date -d "$damga" +%s 2>/dev/null)" && yas_dk=$(( ( $(date +%s) - sn ) / 60 ))
  fi
  mtime_yas="$(( ( $(date +%s) - $(stat -c %Y "$y" 2>/dev/null || echo 0) ) / 60 ))"
  if [ -z "$yas_dk" ]; then
    # Hiçbir damga yok: yalnız dosya zamanı kaldı. Bu bir ÖLÇÜM DEĞİL, bir tahmindir →
    # taze diyemeyiz. Damgasız çıpa "ölçemedim" sınıfıdır.
    printf 'damgasiz:%s' "$mtime_yas"; return
  fi
  # 🔴 GELECEK ZAMANLI DAMGA FAIL-CLOSED (bağımsız göz tur 4): ileri tarihli bir damga
  #    NEGATİF yaş üretir ve "yaşlı mı" kapısı yalnız üst sınıra baktığı için negatif değer
  #    oradan sorunsuz geçip "taze" basardı. Bozuk damga ya da saat kayması tazelik KANITI
  #    değildir — ölçemediğimiz hâldir. (Aynı sınıf hata filoda bir kez üç saatlik kaymayla
  #    ödendi; orada da hiçbir kapı kırmızı olmamıştı.) EN ESKİ-kazanır kuralından ÖNCE
  #    bakılır, çünkü en-eski kuralı negatifi yutar.
  if [ "$yas_dk" -lt 0 ] || [ "$mtime_yas" -lt 0 ]; then
    printf 'gelecek:%s' "$yas_dk"; return
  fi
  [ "$mtime_yas" -gt "$yas_dk" ] && yas_dk="$mtime_yas"   # EN ESKİ kazanır
  if [ "$yas_dk" -gt "$AZAMI_YAS_DK" ]; then printf 'yasli:%s' "$yas_dk"; return; fi
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

# 🔴 BAYRAK, ORTAMDAN SONRA GELİR: yukarıdaki sayı kapısı yalnız ORTAM değerini gördü;
#   `--esik seksen` argüman ayrıştırmasında atandığı için o kapıdan SONRA geliyordu ve
#   denetlenmiyordu. Kapıyı bir kez koymak yetmez — değerin DEĞİŞTİĞİ her yerde durur.
_sayi_mi "$ESIK"         || { echo "HATA: eşik tam sayı olmalı (yüzde): '$ESIK'" >&2; exit 2; }
_sayi_mi "$AZAMI_YAS_DK" || { echo "HATA: azami yaş tam sayı olmalı (dakika): '$AZAMI_YAS_DK'" >&2; exit 2; }

case "$KOMUT" in
  cipa-yolu) _cipa_yolu || { echo "HATA: çıpa aracı bulunamadı: $CIPA_ARAC" >&2; exit 2; }; echo; exit 0 ;;

  hazir-mi|oneri)
    DURUM="$(_cipa_durumu)"
    case "$DURUM" in
      yok)   echo "🔴 ÇIPA YOK — compact önerilmez. Önce planı diske yaz (çıpa aracı 'yaz')."; exit 3 ;;
      bayat:*) echo "🔴 ÇIPA BAYAT (${DURUM#bayat:}) — bugünün planı değil. Dünün çıpasıyla compact'e girmek"
               echo "   kaybolmayacağını sandığın bir planın BAYATINI korur. Önce tazele."; exit 3 ;;
      bos)   echo "🔴 ÇIPA BOŞ — dosya var ama madde yok; hiçbir şey korumuyor. Önce planı yaz."; exit 3 ;;
      damgasiz:*) echo "◻ ÇIPA DAMGASIZ — içinde ne zaman yazıldığı/dokunulduğu yazmıyor."
               echo "   Dosya ${DURUM#damgasiz:} dakikadır değişmemiş ama bu bir TAHMİN, ölçüm değil:"
               echo "   boş bir dokunuş da dosya zamanını yeniler. Tazeliği ölçemediğim bir çıpayla"
               echo "   compact önermem. Çıpayı aracıyla tazele (damga kendiliğinden düşer)."; exit 3 ;;
      gelecek:*) echo "🔴 ÇIPA DAMGASI GELECEĞİ GÖSTERİYOR (${DURUM#gelecek:} dakika) — ölçemedim."
               echo "   Bir plan henüz yazılmamış olamaz: ya damga bozuk ya makinenin saati kaymış."
               echo "   Bu bir tazelik kanıtı değil, ölçüm arızasıdır; compact önermem."
               echo "   Saati kontrol et ya da çıpayı aracıyla yeniden tazele."; exit 3 ;;
      yasli:*) echo "🔴 ÇIPA YAŞLI (${DURUM#yasli:} dakika) — bugünün ama son ${AZAMI_YAS_DK} dakikada dokunulmamış."
               echo "   Takvim günü tazelik değildir: sabah yazılan plan akşam olan biteni anlatmaz."
               echo "   Önce çıpayı tazele (ne bitti, ne yarım kaldı), sonra tekrar çağır."; exit 3 ;;
    esac
    if [ -z "$DOLULUK" ]; then
      echo "◻ ÖLÇEMEDİM: bağlam doluluğunu bu araç ölçemez, ajanın kendi göstergesinden gelir (--doluluk)."
      echo "  Çıpa TAZE ve $(_acik_madde_sayisi) açık madde taşıyor — sıra tamam, eksik olan yalnız sayı."
      exit 4
    fi
    case "$DOLULUK" in (*[!0-9]*|"") echo "HATA: --doluluk tam sayı olmalı (yüzde): '$DOLULUK'" >&2; exit 2 ;; esac
    # 🔴 SULTAN'IN SÖZÜ "60'IN ÜSTÜ" — tam eşikte TETİKLEMEZ (bağımsız göz tur 1).
    #   İlk yazımda sınırı dahil etmiş ve sınava "sınır dahil" diye yazmıştım; bu, Sultan'ın
    #   sormadığı bir kararı benim vermemdi. Kural onun cümlesiyle hizalandı.
    if [ "$DOLULUK" -le "$ESIK" ]; then
      echo "🟢 Eşik aşılmadı: doluluk %$DOLULUK ≤ %$ESIK — compact önerilmez, çalışmaya devam."
      exit 1
    fi
    [ "$KOMUT" = hazir-mi ] && { echo "🟡 HAZIR: doluluk %$DOLULUK > %$ESIK · çıpa TAZE · $(_acik_madde_sayisi) açık madde"; exit 0; }
    cat <<M
🟡 SOLUKLANMA ZAMANI · doluluk %$DOLULUK (eşik %$ESIK aşıldı)

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
    [ "${DURUM%%:*}" = damgasiz ] && echo "⚠ DİKKAT: çıpa damgasız — tazeliği ölçülemedi."
    [ "${DURUM%%:*}" = yasli ] && echo "⚠ DİKKAT: çıpaya ${DURUM#yasli:} dakikadır dokunulmamış — maddeler bayat olabilir."
    [ "${DURUM%%:*}" = gelecek ] && echo "⚠ DİKKAT: çıpa damgası geleceği gösteriyor — tazeliği ölçülemedi."
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
