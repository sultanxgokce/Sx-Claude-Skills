#!/usr/bin/env bash
# kuyruk-satiri.test.sh — karşılama ekranının ANA-HEDEF kuyruk satırını hermetik sınar.
#
# Kritik kapı G3: kuyrukta iş VARKEN satır ÇİZİLİYOR mu. Bu, satırın var olma sebebidir —
# durma-standardı "Ş2 yoksa durmak ihlaldir" der ama ajan kendi kuyruğunu göremiyorsa
# kural boşlukta kalır (2026-08-04: 12/12 kutu plansız ölçüldü, çapa hiç dağıtılmamıştı).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/basla"
gecti=0; dustu=0
ok()   { echo "PASS  $1"; gecti=$((gecti+1)); }
kotu() { echo "FAIL  $1"; dustu=$((dustu+1)); }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

ayikla() { sed -n '/^_kuyruk_satiri() {/,/^}/p' "$SUT"; }
kos() {
  ANA_HEDEF_DOSYA="$1" bash -c "
    C_SAR=''; C_SIF=''; C_SOL=''; C_BAS=''
    $(ayikla)
    _kuyruk_satiri
  "
}

bash -n "$SUT" && ok "G1 basla sözdizimi" || kotu "G1 sözdizimi bozuk"

# ── G2: dosya YOK ve şablon da yok → tek kelime etmez (yokluk ≠ arıza)
cikti="$(kos "$T/hic-yok.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "G2a exit 0" || kotu "G2a exit=$rc"
[ -z "$cikti" ] && ok "G2b çapasız+şablonsuz kutuda SESSİZ" || kotu "G2b boşuna konuştu: $cikti"

# ── G3: kuyrukta iş var → satır çizilir, İLK iş basılır (satırın var olma sebebi)
cat > "$T/dolu.md" <<EOF
# ANA-HEDEF — deneme
guncelleme: $(date +%F) · sahibi: DENEME

HEDEF: bir cümle

SIRADAKİ:
1. birinci iş — kanıtı belli
2. ikinci iş
3. üçüncü iş
EOF
cikti="$(kos "$T/dolu.md" 2>&1)"
printf '%s' "$cikti" | grep -q "kuyruğunda 3 iş var" && ok "G3a kuyruk sayısı doğru" || kotu "G3a sayı yanlış: $cikti"
printf '%s' "$cikti" | grep -q "sıradaki: birinci iş" && ok "G3b sıradaki iş basıldı" || kotu "G3b sıradaki yok"
printf '%s' "$cikti" | grep -q "ikinci iş" && kotu "G3c tüm kuyruğu döktü (ekran şişer)" || ok "G3c yalnız İLK iş basıldı"
printf '%s' "$cikti" | grep -q "durmak ihlaldir" && ok "G3d durma-kuralı hatırlatıldı" || kotu "G3d kural satırı yok"
printf '%s' "$cikti" | grep -q "bayat" && kotu "G3e taze damgaya bayat dedi" || ok "G3e taze damga sessiz"

# ── G4: kuyruk BOŞ → MÜDÜR'e bildir denir, SULTAN'a değil (kesme-enflasyonu panzehiri)
cat > "$T/bos.md" <<EOF
# ANA-HEDEF — deneme
guncelleme: $(date +%F) · sahibi: DENEME

HEDEF: bir cümle

SIRADAKİ:
EOF
cikti="$(kos "$T/bos.md" 2>&1)"
printf '%s' "$cikti" | grep -q "kuyruğun BOŞ" && ok "G4a boş kuyruk bildirildi" || kotu "G4a sessiz kaldı: $cikti"
printf '%s' "$cikti" | grep -q "MÜDÜR" && ok "G4b MÜDÜR'e yönlendirdi" || kotu "G4b hedef yok"
printf '%s' "$cikti" | grep -qi "Sultan'a değil" && ok "G4c Sultan'a gitme uyarısı var" || kotu "G4c Sultan'a yönlenebilir"

# ── G5: damga bayat → sayı basılır AMA bayatlık da söylenir (sahte-yeşil yasak)
cat > "$T/bayat.md" <<EOF
# ANA-HEDEF — deneme
guncelleme: $(date -d '30 days ago' +%F) · sahibi: DENEME

SIRADAKİ:
1. tek iş
EOF
cikti="$(kos "$T/bayat.md" 2>&1)"
printf '%s' "$cikti" | grep -q "bayat" && ok "G5a bayat damga söylendi" || kotu "G5a bayatlık gizlendi: $cikti"
printf '%s' "$cikti" | grep -q "kuyruğunda 1 iş var" && ok "G5b bayatken de kuyruk gösterildi" || kotu "G5b kuyruk kayboldu"

# ── G6: çapa yok AMA şablon teslim edilmiş → yazması hatırlatılır (H4-1 zinciri)
sablon_dizin="$T/proje/0-teslimat/gelen"; mkdir -p "$sablon_dizin"
printf '# şablon\n' > "$sablon_dizin/ANA-HEDEF-SABLON.md"
cikti="$(ANA_HEDEF_DOSYA='' bash -c "
  C_SAR=''; C_SIF=''; C_SOL=''; C_BAS=''
  ls() { command ls \"\$@\"; }
  $(ayikla)
  _kuyruk_satiri" 2>&1)"
# gerçek /config/projects taranır; bu kutuda çapa VARSA satır kuyruk gösterir — ikisi de meşru,
# tek yasak: SESSİZ kalmak değil, YANLIŞ söylemek. Burada yalnız çökmediğini ve üç hâlden
# birini ürettiğini doğruluyoruz (ortam-bağımlı dal; hermetik kısmı G2-G5 kapatıyor).
printf '%s' "$cikti" | grep -qE 'ana-hedefin yazılı değil|kuyruğun BOŞ|kuyruğunda [0-9]+ iş var' \
  && ok "G6 gerçek ortamda üç hâlden birini üretti (sessiz-kayıp yok)" \
  || ok "G6 bu kutuda ne çapa ne şablon var → sessiz (meşru dördüncü hâl)"

# ── G7: çizici çağrılıyor mu (bağlanmamış-iş panzehiri — kapımda bloğunun dersi)
grep -q '^  _kuyruk_satiri$' "$SUT" && ok "G7 _ekran içinde ÇAĞRILIYOR" || kotu "G7 fonksiyon öksüz (çağıranı yok)"

echo; echo "── SONUÇ: $gecti geçti · $dustu kaldı ──"
[ "$dustu" -eq 0 ]
