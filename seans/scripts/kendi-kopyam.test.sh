#!/usr/bin/env bash
# kendi-kopyam.test.sh — "kendi kopyam" kapısı. Gerçek git depolarıyla koşar, ağ YOK.
#
# NİÇİN BU KADAR SIKI: bu araç DOSYA SİSTEMİNE yazar ve --kapat ile SİLER. Sınanmayan bir
# silici, bir gün birinin işini götürür. Buradaki her testin karşılığı ya ölçülmüş bir
# tuzak ya da bilinçli bir sözleşme maddesidir.
set -u
BURASI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
KK="$BURASI/kendi-kopyam"
GECTI=0; DUSTU=0

ok(){ GECTI=$((GECTI+1)); printf '  ✓ %s\n' "$1"; }
no(){ DUSTU=$((DUSTU+1)); printf '  ✗ %s\n     %s\n' "$1" "${2:-}"; }
esit(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "beklenen='$3' gelen='$2'"; }
icerir(){ case "$2" in *"$3"*) ok "$1" ;; *) no "$1" "çıktıda '$3' yok" ;; esac; }
iceremez(){ case "$2" in *"$3"*) no "$1" "çıktıda '$3' VAR (olmamalı)" ;; *) ok "$1" ;; esac; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
git config -f "$TMP/gitconfig" user.email t@t.t
git config -f "$TMP/gitconfig" user.name  T
git config -f "$TMP/gitconfig" init.defaultBranch main
git config -f "$TMP/gitconfig" advice.detachedHead false

# Ortam-bağımsızlık: testte tmux'a HİÇ sorulmasın (masa adı kancadan gelir).
export KENDI_KOPYAM_TEST_MASA="motor1"
unset TMUX 2>/dev/null || true

depo_kur(){ # depo_kur <yol> [--uzak]
  local d="$1"; mkdir -p "$d"; git -C "$d" init -q
  printf 'ilk\n' > "$d/dosya.txt"; git -C "$d" add -A; git -C "$d" commit -qm ilk
  if [ "${2:-}" = "--uzak" ]; then
    git -C "$d" init -q --bare "$d.git" 2>/dev/null || git init -q --bare "$d.git"
    git -C "$d" remote add origin "$d.git"; git -C "$d" push -q origin main 2>/dev/null
  fi
}

echo "── 1 · söz dizimi"
bash -n "$KK" && ok "kendi-kopyam söz dizimi" || no "kendi-kopyam söz dizimi"
[ -x "$KK" ] && ok "çalıştırılabilir (mod)" || no "çalıştırılabilir (mod)" "chmod +x gerek"

echo "── 2 · burada yapılamaz halleri (fail-closed, exit 3)"
mkdir -p "$TMP/bos"; out=$(cd "$TMP/bos" && bash "$KK" 2>&1); rc=$?
esit "repo olmayan dizinde exit 3" "$rc" 3
icerir "repo yok mesajı Sultan-dili" "$out" "proje deposu değil"

mkdir -p "$TMP/kayitsiz"; git -C "$TMP/kayitsiz" init -q
out=$(cd "$TMP/kayitsiz" && bash "$KK" 2>&1); rc=$?
esit "kayıtsız depoda exit 3" "$rc" 3
icerir "kayıtsız depo gerekçesi" "$out" "hiç kayıt yok"

echo "── 3 · ölçüm modu HİÇBİR ŞEY yazmaz"
D="$TMP/p1"; depo_kur "$D"
onceki="$(ls "$TMP" | sort | tr '\n' ' ')"
out=$(cd "$D" && bash "$KK" --nerede 2>&1); rc=$?
esit "--nerede exit 0" "$rc" 0
esit "--nerede dizin oluşturmadı" "$(ls "$TMP" | sort | tr '\n' ' ')" "$onceki"
icerir "--nerede kuru-koşu dediğini söylüyor" "$out" "hiçbir şey yazılmadı"
icerir "--nerede dalı gösteriyor" "$out" "main"

echo "── 4 · paylaşım ölçümü: uydurmuyor, ölçemediğini söylüyor"
out=$(cd "$D" && KENDI_KOPYAM_TEST_PAYLASAN=3 bash "$KK" --nerede 2>&1)
icerir "3 masa paylaşıyor uyarısı" "$out" "3 masa paylaşıyor"
icerir "sonucu Sultan-dilinde anlatıyor" "$out" "çakışır"
out=$(cd "$D" && KENDI_KOPYAM_TEST_PAYLASAN='?' bash "$KK" --nerede 2>&1)
icerir "ölçemedim dürüstlüğü" "$out" "ölçemedim"
iceremez "ölçemezken yeşil iddia YOK" "$out" "yalnız senin"

echo "── 5 · kopya açma"
out=$(cd "$D" && bash "$KK" 2>&1); rc=$?
esit "açma exit 0" "$rc" 0
[ -d "$TMP/p1-motor1" ] && ok "kopya dizini açıldı (p1-motor1)" || no "kopya dizini açıldı" "yok: $TMP/p1-motor1"
esit "kopyanın dalı masa adı"     "$(git -C "$TMP/p1-motor1" rev-parse --abbrev-ref HEAD)" "motor1"
esit "ANA kopyanın dalı DEĞİŞMEDİ" "$(git -C "$D" rev-parse --abbrev-ref HEAD)" "main"
esit "ANA kopya temiz kaldı"       "$(git -C "$D" status --porcelain | wc -l | tr -d ' ')" "0"
esit "ana kopya dosyası bozulmadı" "$(cat "$D/dosya.txt")" "ilk"

echo "── 6 · idempotentlik + konu adı + ad temizliği"
out=$(cd "$D" && bash "$KK" 2>&1); rc=$?
esit "ikinci çağrı exit 0" "$rc" 0
icerir "ikinci çağrı 'zaten var' der" "$out" "zaten var"
out=$(cd "$D" && KENDI_KOPYAM_TEST_MASA="Ayşe Nur" bash "$KK" randevu-akisi 2>&1); rc=$?
esit "türkçe/boşluklu masa adı exit 0" "$rc" 0
[ -d "$TMP/p1-ayse-nur" ] && ok "ad temizlendi (p1-ayse-nur)" || no "ad temizlendi" "yok: $TMP/p1-ayse-nur"
esit "konu dala eklendi" "$(git -C "$TMP/p1-ayse-nur" rev-parse --abbrev-ref HEAD)" "ayse-nur-randevu-akisi"

echo "── 7 · var olan dala bağlanır (yeniden oluşturmaya çalışmaz)"
D2="$TMP/p2"; depo_kur "$D2"; git -C "$D2" branch motor1
out=$(cd "$D2" && bash "$KK" 2>&1); rc=$?
esit "var olan dalla exit 0" "$rc" 0
esit "var olan dala bağlandı" "$(git -C "$TMP/p2-motor1" rev-parse --abbrev-ref HEAD)" "motor1"

echo "── 8 · kopyanın içinden bakış"
out=$(cd "$TMP/p1-motor1" && bash "$KK" 2>&1); rc=$?
esit "kendi kopyasında exit 0" "$rc" 0
icerir "kendi kopyan olduğunu söyler" "$out" "kendi kopyan"
iceremez "ikinci kopya AÇMAZ" "$out" "açıldı"
esit "--yol kopyanın içinden kendi yolunu basar" "$(cd "$TMP/p1-motor1" && bash "$KK" --yol)" "$TMP/p1-motor1"
esit "--yol ana kopyada hedef yolu basar"        "$(cd "$D" && bash "$KK" --yol)" "$TMP/p1-motor1"

echo "── 9 · --kapat: koruma önce, silme sonra"
out=$(cd "$D" && bash "$KK" --kapat 2>&1); rc=$?
esit "ana kopyada --kapat reddedilir (exit 2)" "$rc" 2
icerir "ana kopya asla silinmez mesajı" "$out" "ANA kopya"

printf 'kirli\n' > "$TMP/p1-motor1/yeni.txt"
out=$(cd "$TMP/p1-motor1" && KENDI_KOPYAM_TEST_ONAY=e bash "$KK" --kapat 2>&1); rc=$?
esit "kirli kopya kapatılmaz (exit 1)" "$rc" 1
[ -d "$TMP/p1-motor1" ] && ok "kirliyken dizin DURUYOR" || no "kirliyken dizin duruyor" "silindi!"
# ⚠️ Bu satır olmadan test YANLIŞ SEBEPLE geçiyordu: koruma kaldırılsa bile `git worktree
# remove` kirli dizini kendisi reddediyor ve exit 1 yine geliyordu (mutasyon sınaması
# yakaladı, 2026-07-30). Bizim kapımızın kanıtı, gerekçeyi Sultan-dilinde SÖYLEMESİDİR.
icerir "kirli gerekçesi Sultan-dilinde açıklanıyor" "$out" "kaydedilmemiş değişiklik var"
iceremez "ham git hatası kullanıcıya dökülmüyor" "$out" "contains modified"
rm -f "$TMP/p1-motor1/yeni.txt"

# Gönderilmemiş kayıt: RED değil UYARI (worktree remove dalı silmez → iş kaybolmaz)
git -C "$TMP/p1-motor1" commit -q --allow-empty -m "yalnız burada"
out=$(cd "$TMP/p1-motor1" && KENDI_KOPYAM_TEST_ONAY=e bash "$KK" --kapat 2>&1); rc=$?
esit "gönderilmemiş kayıtla kapatılır (exit 0)" "$rc" 0
icerir "uyarı verilir" "$out" "yalnız burada duran"
icerir "dal silinmediği SÖYLENİR (dürüst gerekçe)" "$out" "dal SİLİNMEZ"
esit "dal ve kaydı git'te DURUYOR" \
     "$(git -C "$D" log --oneline motor1 2>/dev/null | head -1 | grep -c 'yalnız burada')" "1"

# temiz kopya → kapanabilir
out=$(cd "$D" && bash "$KK" 2>&1)   # yeniden aç (dal motor1'de zaten var)
out=$(cd "$TMP/p1-motor1" && KENDI_KOPYAM_TEST_ONAY=e bash "$KK" --kapat 2>&1); rc=$?
esit "temiz kopya kapatılır (exit 0)" "$rc" 0
[ ! -d "$TMP/p1-motor1" ] && ok "kopya kaldırıldı" || no "kopya kaldırıldı" "hâlâ duruyor"
esit "ANA kopya kapatmadan sonra da sağlam" "$(cat "$D/dosya.txt")" "ilk"

# onay verilmezse silmez
out=$(cd "$D" && bash "$KK" 2>&1) # yeniden aç
out=$(cd "$TMP/p1-motor1" && KENDI_KOPYAM_TEST_ONAY=h bash "$KK" --kapat 2>&1); rc=$?
esit "onaysız kapatma exit 0 (vazgeçti)" "$rc" 0
[ -d "$TMP/p1-motor1" ] && ok "onay yokken dizin DURUYOR" || no "onay yokken dizin duruyor" "silindi!"

echo "── 10 · uzak sunuculu depoda 'gönderilmiş' ölçümü"
D3="$TMP/p3"; depo_kur "$D3" --uzak
out=$(cd "$D3" && bash "$KK" 2>&1)
git -C "$TMP/p3-motor1" commit -q --allow-empty -m "gönderilmedi"
out=$(cd "$TMP/p3-motor1" && KENDI_KOPYAM_TEST_ONAY=e bash "$KK" --kapat 2>&1); rc=$?
esit "uzak var + gönderilmemiş kayıt → uyarıp kapatır (exit 0)" "$rc" 0
icerir "doğru yönlendirme (git push)" "$out" "git push"
icerir "uzak varken 'yalnız burada' uyarısı" "$out" "yalnız burada duran 1 kayıt"
esit "kayıt uzakta değil ama DALDA duruyor" \
     "$(git -C "$D3" log --oneline motor1 | head -1 | grep -c 'gönderilmedi')" "1"
# gönderilmiş hâl: uyarı YOK
out=$(cd "$D3" && bash "$KK" 2>&1)
git -C "$TMP/p3-motor1" push -q origin motor1
out=$(cd "$TMP/p3-motor1" && KENDI_KOPYAM_TEST_ONAY=e bash "$KK" --kapat 2>&1); rc=$?
esit "gönderilmişken kapanır (exit 0)" "$rc" 0
iceremez "gönderilmişken gereksiz uyarı YOK" "$out" "yalnız burada duran"
[ ! -d "$TMP/p3-motor1" ] && ok "gönderilmiş kopya kaldırıldı" || no "gönderilmiş kopya kaldırıldı" "duruyor"

echo "── 11 · --satir (karşılama ekranının çağırdığı mod)"
out=$(cd "$TMP/bos" && bash "$KK" --satir 2>&1); rc=$?
esit "depo olmayan yerde --satir exit 0" "$rc" 0
esit "depo olmayan yerde --satir SESSİZ" "$(printf '%s' "$out" | tr -d ' \n')" ""
out=$(cd "$D" && KENDI_KOPYAM_TEST_PAYLASAN=3 bash "$KK" --satir 2>&1)
icerir "--satir paylaşımı uyarır" "$out" "3 masa paylaşıyor"
icerir "--satir çözümü gösterir" "$out" "kendi-kopyam"
esit  "--satir kısa kalır (≤3 satır)" "$(printf '%s\n' "$out" | grep -c .)" "2"
out=$(cd "$TMP/p1-motor1" && bash "$KK" --satir 2>&1)
icerir "--satir kendi kopyada 'yalnız senin' der" "$out" "yalnız senin"

echo "── 12 · KABLO: karşılama ekranı bu satırı gerçekten basıyor mu"
# NİÇİN: aracı yazmak onu ekrana getirmez. Bugünün dersi — "birim yeşil ≠ yol çalışıyor".
BASLA="$BURASI/basla"
if [ -f "$BASLA" ]; then
  out=$(cd "$D" && PATH="$BURASI:$PATH" KENDI_KOPYAM_TEST_PAYLASAN=4 \
        BASLA_TEST_SECIM=q bash "$BASLA" 2>&1)
  icerir "basla ekranında paylaşım uyarısı görünüyor" "$out" "4 masa paylaşıyor"
  # Menü numaraları KORUNDU: ekibe yazılı bildirilen sıra (1 kontrol · 2 masaya geç ·
  # 3 yeni sohbet · 4 kurallar · 5 ara) sessizce kaymasın. Bu bir bilgi satırı ekledi,
  # SEÇENEK eklemedi. (Menü çizimi etkileşimli seçicide olduğu için sözleşme metinde ölçülür.)
  menu="$(cat "$BASLA")"
  icerir "menü 1 = ekibi kontrol et"   "$menu" "1  Ekibi kontrol et"
  icerir "menü 2 = bir masaya geç"     "$menu" "2  Bir masaya geç"
  icerir "menü 3 = yeni sohbet"        "$menu" "3  Yeni sohbet başlat"
  icerir "menü 4 = kurallar"           "$menu" "4  Kuralları ve komutları göster"
  icerir "menü 5 = eski sohbetlerde ara" "$menu" "5  Eski sohbetlerde ara"
  # Araç yoksa ekran KIRILMAZ (eski davranış birebir korunur) — basla'yı YALNIZ kopyalayıp
  # yanında kendi-kopyam olmayan bir dizinden koşuyoruz (gerçek "kurulmamış kutu" hâli).
  mkdir -p "$TMP/solo"; cp "$BASLA" "$TMP/solo/basla"
  out=$(cd "$D" && BASLA_TEST_SECIM=q bash "$TMP/solo/basla" 2>&1); rc=$?
  esit "kendi-kopyam yokken basla yine çalışır" "$rc" 0
  iceremez "araç yokken kopya satırı basılmaz" "$out" "ana kopya · dal"
else
  no "basla bulunamadı" "$BASLA"
fi

echo "── 13 · kullanım hatası"
out=$(cd "$D" && bash "$KK" --olmayan-secenek 2>&1); rc=$?
esit "bilinmeyen seçenek exit 2" "$rc" 2

echo
printf 'kendi-kopyam: GEÇTI=%s DUSTU=%s\n' "$GECTI" "$DUSTU"
[ "$DUSTU" -eq 0 ] || exit 1
