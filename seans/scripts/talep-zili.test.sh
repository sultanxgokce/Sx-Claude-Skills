#!/usr/bin/env bash
# talep-zili.test.sh — karşılama ekranının "oda-talebi SAHİPSİZ" zilini hermetik sınar.
#
# Kritik kapı G2: bekleyen talep VARKEN zil ÇALIYOR mu. Bu zilin var olma sebebi ölçülmüş
# bir vaka: 7 oda-talebi 8 gün 20 saat sahipsiz bekledi ve hiçbir ekran bunu söylemedi.
# G4 ise ters yönü korur: ölçüm BAYATSA sayı gerçek gibi sunulmaz ("doğrulanmadı").
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/basla"
gecti=0; dustu=0
ok()   { echo "PASS  $1"; gecti=$((gecti+1)); }
kotu() { echo "FAIL  $1"; dustu=$((dustu+1)); }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

ayikla(){ sed -n '/^_talep_zili() {/,/^}/p' "$SUT"; }
kos(){ FEDERE_DURUM="$1" bash -c "
  C_SAR=''; C_SIF=''; C_SOL=''
  $(ayikla)
  _talep_zili
"; }

yaz(){ # yaz <dosya> <adet> <en_eski> <kontrol-dk-once>
  local k; k="$(date -u -d "-$4 minutes" +%Y-%m-%dT%H:%MZ)"
  printf 'adet=%s\nen_eski=%s\nkontrol=%s\n' "$2" "$3" "$k" > "$1"
}

# ── G1: ölçüm dosyası YOK → sessiz (yokluk ≠ arıza)
cikti="$(kos "$T/hic-yok.txt" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "G1a dosya yok → exit 0" || kotu "G1a exit=$rc"
[ -z "$cikti" ] && ok "G1b dosya yokken SESSİZ" || kotu "G1b boşuna konuştu: $cikti"

# ── G2: bekleyen VAR → zil çalıyor (zilin VAR OLMA sebebi)
yaz "$T/dolu.txt" 3 "$(date -u -d '-5 hours' +%Y-%m-%dT%H:%MZ)" 5
cikti="$(kos "$T/dolu.txt" 2>&1)"
grep -q "3 oda-talebi SAHİPSİZ" <<<"$cikti" && ok "G2a sayı + sahipsizlik basıldı" || kotu "G2a zil çalmadı: $cikti"
grep -q "5 saattir bekliyor" <<<"$cikti" && ok "G2b en eskisinin yaşı saat olarak basıldı" || kotu "G2b yaş yok: $cikti"
grep -q "federe.sh alindi" <<<"$cikti" && ok "G2c üstlenme yolu gösterildi (eyleme dönük)" || kotu "G2c eylem yok"

# ── G3: kuyruk boş → tek kelime etme (gürültü yok)
yaz "$T/bos.txt" 0 "-" 5
cikti="$(kos "$T/bos.txt" 2>&1)"
[ -z "$cikti" ] && ok "G3 kuyruk boşken SESSİZ" || kotu "G3 boşuna konuştu: $cikti"

# ── G4: ÖLÇÜM BAYAT → sayıyı gerçek gibi sunma (sahte-yeşil/sahte-kırmızı panzehiri)
yaz "$T/bayat.txt" 4 "$(date -u -d '-3 days' +%Y-%m-%dT%H:%MZ)" 300
cikti="$(kos "$T/bayat.txt" 2>&1)"
grep -q "doğrulanmadı" <<<"$cikti" && ok "G4a bayat ölçüm 'doğrulanmadı' diyor" || kotu "G4a bayatlık gizlendi: $cikti"
grep -q "4 oda-talebi SAHİPSİZ" <<<"$cikti" && kotu "G4b bayat sayı GERÇEK gibi sunuldu" || ok "G4b bayat sayı gerçek gibi sunulmuyor"
grep -q "dinleyici durmuş olabilir" <<<"$cikti" && ok "G4c olası sebep söylendi" || kotu "G4c sebep yok"

# ── G5: çok eski bekleyen GÜN olarak okunur (8 gün "192 saat" diye basılmamalı)
yaz "$T/gun.txt" 7 "$(date -u -d '-9 days' +%Y-%m-%dT%H:%MZ)" 3
cikti="$(kos "$T/gun.txt" 2>&1)"
grep -q "9 gündür bekliyor" <<<"$cikti" && ok "G5 çok eski bekleme GÜN olarak basıldı" || kotu "G5 gün-biçimi yok: $cikti"

# ── G6: bozuk/eksik alan → çökmez, sessiz geçer
printf 'adet=abc\n' > "$T/bozuk.txt"
cikti="$(kos "$T/bozuk.txt" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$cikti" ] && ok "G6 bozuk dosyada çökmedi ve sustu" || kotu "G6 bozuk dosyada davranış yanlış (rc=$rc): $cikti"


# ═══ L50 · KAPSAM DAMGASI ════════════════════════════════════════════════════
# NİÇİN: bu sayıyı merkez ölçüp kutuya dağıtıyor ve merkez token'ı cell-izolasyonlu →
# tablo yalnız MERKEZ-KAYNAKLI bekleyenleri görür. Damga basılmazsa okuyan sayıyı
# "kuyruğun tamamı" sanar; oda-odaya gelen bir mesaj görünmediğinde ekran farkında
# olmadan yalan söylemiş olur. (Kök vaka: ekran 13 kutuya MERKEZİN sayısını basıyordu.)

# G7: kapsam damgası varsa sınır SÖYLENİR
yaz "$T/kapsamli.txt" 9 "$(date -u -d '-30 hours' +%Y-%m-%dT%H:%MZ)" 5
printf 'kapsam=s01-kaynakli\n' >> "$T/kapsamli.txt"
cikti="$(kos "$T/kapsamli.txt" 2>&1)"
grep -q "BU KUTUNUN gelen kutusu" <<<"$cikti" && ok "G7a satır BU kutunun kuyruğu olduğunu söylüyor" || kotu "G7a kime ait belirsiz: $cikti"
grep -q "9 oda-talebi SAHİPSİZ" <<<"$cikti" && ok "G7b kutunun KENDİ sayısı basıldı" || kotu "G7b sayı yok: $cikti"
grep -q "merkez-kaynaklı" <<<"$cikti" && ok "G7c kapsam sınırı söylendi" || kotu "G7c kapsam gizlendi: $cikti"

# G8: kapsam damgası YOKSA uydurma sınır cümlesi basılmaz (eski biçimle geriye-uyum)
cikti="$(kos "$T/dolu.txt" 2>&1)"
grep -q "merkez-kaynaklı" <<<"$cikti" && kotu "G8 damgasız dosyada uydurma kapsam cümlesi" || ok "G8 damga yoksa kapsam cümlesi YOK (geriye-uyum)"

# G9: kapsamlı ama adet=0 → yine SESSİZ ("kuyruk temiz" İDDİASI edilmez)
yaz "$T/sifir.txt" 0 "-" 5
printf 'kapsam=s01-kaynakli\n' >> "$T/sifir.txt"
cikti="$(kos "$T/sifir.txt" 2>&1)"
[ -z "$cikti" ] && ok "G9 adet=0 iken sessiz (temiz iddiası yok)" || kotu "G9 0'da konuştu: $cikti"

echo; echo "── SONUÇ: $gecti geçti · $dustu kaldı ──"
[ "$dustu" -eq 0 ]
