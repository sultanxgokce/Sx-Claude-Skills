#!/usr/bin/env bash
# baglam-karti.canli.sh — UÇTAN UCA: baglam-karti.sh GERÇEK Görev Defteri geçit motoruna (cloudtop infra/defter-gecit/gecit.mjs) karşı.
# Birim sınavı (baglam-karti.test.sh) SAHTE sunucuyla koşar: sahtenin yanıt biçimi aracın BEKLEDİĞİ biçimdir, defterin gerçek biçimi değil.
# Bu sınav o varsayımı ölçer: gerçek PATCH /kayit/<id> yanıtında degisti (bool) + kayit.adimlar (liste, adım metni birebir) var mı?
# Kapsam: motor GEÇİCİ dizinde (kendi defter dosyası, rastgele port, loopback) kalkar — canlı Sultan defterine DOKUNMAZ (gerçek kayıt görevine test adımı yazmak
#   Sultan'ın ekranını kirletir). "Canlı" = gerçek motor kodu + gerçek HTTP + gerçek jeton/rol/yetki yolu; sahte sunucu değil.
# CI'da KOŞMAZ (bu dosya *.test.sh değil): motor cloudtop deposundadır, Sx CI'ında yoktur. Elle: bash baglam-karti.canli.sh
# Ortam: DEFTER_GECIT (vars. /config/projects/cloudtop/infra/defter-gecit/gecit.mjs) · node gerekir
# Çıkış: 0 hepsi geçti · 1 kapı düştü · 3 ÖLÇÜLEMEDİ (motor ya da node yok — "temiz" DEĞİL)
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$D/baglam-karti.sh"
G="${DEFTER_GECIT:-/config/projects/cloudtop/infra/defter-gecit/gecit.mjs}"
[ -f "$G" ] || { echo "ÖLÇÜLEMEDİ: geçit motoru yok ($G) — canlı sınav koşmadı, 'temiz' DEĞİL (DEFTER_GECIT ver)" >&2; exit 3; }
command -v node >/dev/null || { echo "ÖLÇÜLEMEDİ: node yok" >&2; exit 3; }
T="$(mktemp -d)"; PID=""
temizle() { [ -n "$PID" ] && kill "$PID" 2>/dev/null; wait 2>/dev/null; find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null; }; trap temizle EXIT
gecen=0; kalan=0; kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }

printf '{"jeton-serdar":{"kutu":"serdar"},"jeton-baska":{"kutu":"akar"}}' > "$T/izin.json"
PORT=$((20000 + RANDOM % 20000))
DEFTER_PORT=$PORT DEFTER_DOSYA="$T/defter.json" DEFTER_IZIN="$T/izin.json" DEFTER_KUTUK="$T/kutuk.jsonl" node "$G" > "$T/gecit.log" 2>&1 & PID=$!
for _ in $(seq 20); do curl -fsS -m 1 "http://127.0.0.1:$PORT/saglik" >/dev/null 2>&1 && break; sleep 0.5; done
curl -fsS -m 2 "http://127.0.0.1:$PORT/saglik" >/dev/null || { echo "ÖLÇÜLEMEDİ: geçit kalkmadı"; sed 's/^/    /' "$T/gecit.log" | head -5; exit 3; }
printf 'jeton-serdar\n' > "$T/j-serdar"; printf 'jeton-baska\n' > "$T/j-baska"
export DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/j-serdar"
cagir() { curl -sS -m 5 -H "x-defter-jeton: ${JETON:-jeton-serdar}" -H 'content-type: application/json' "$@"; }

# kayıt görevi: gerçek defterde AÇILIR (gorev.sh ac ile aynı gövde), kimliği motor verir
GOREV="$(cagir -X POST "$DEFTER_UC/kayit" -d '{"tur":"gorev","adlar":["ENİS bağlam kartı kayıtları (canlı sınav)"],"kapi":"karar","sahip":"serdar","gorev_durumu":"acik"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["kayit"]["id"])' 2>/dev/null)"
[ -n "$GOREV" ] || { echo "ÖLÇÜLEMEDİ: test görevi açılamadı"; exit 3; }
export BAGLAM_KARTI_GOREV="$GOREV"

M="$T/m"; mkdir -p "$M"
KARAR="Bu hafta yeni bir satış görüşmesi alınsın mı?"
KART="Bu hafta tempo düşük tutulursa iyi olur. Yeni görüşme yerine mevcutları kapatmak şu yönde."
printf 'HEDEF: enis\nKOPYA: muavin\n\n# SERDAR → ENİS · bağlam kartı isteği 1\n\nKarar:   %s\nUfuk:    bu hafta\nSon an:  2026-10-20 18:00\n' "$KARAR" > "$M/SERDAR-ENIS-baglam-karti-20261018-1.md"
printf 'HEDEF: merkez\nKOPYA: muavin\n\n# ENİS → isteyen · bağlam kartı 1\n\nDurum:  verildi\nKart:   %s\nKapı:   geçti (dis-raf-kapi.sh rc=0)\n' "$KART" > "$M/ENIS-SERDAR-baglam-karti-20261018-1.md"
adimlar() { cagir "$DEFTER_UC/kayit/$GOREV" | python3 -c 'import sys,json; print(json.dumps([x["deger"] for x in json.load(sys.stdin)["kayit"].get("adimlar")],ensure_ascii=False))'; }
sayi() { adimlar | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'; }
K() { bash "$S" kaydet "$@" 2>&1; }

echo "── S · yanıt sözleşmesi (gerçek PATCH, araçtan bağımsız)"
ham="$(cagir -X PATCH "$DEFTER_UC/kayit/$GOREV" -d '{"adimlar":["sözleşme denemesi"]}' -w '\n%{http_code}')"
kod="$(tail -1 <<<"$ham")"; govde="$(sed '$d' <<<"$ham")"
tur() { python3 -c 'import sys,json; j=json.loads(sys.argv[1]); print(eval(sys.argv[2]))' "$govde" "$1" 2>&1; }
kapi "S1 yeni adım: http 200" "200" "$kod"
kapi "S2 degisti bool ve true" "bool:True" "$(tur '"%s:%s" % (type(j["degisti"]).__name__, j["degisti"])')"
kapi "S3 kayit.adimlar LİSTE, öğeler NESNE {deger, anahtar, kutu, ts} (düz metin DEĞİL — araç buna göre eşleşir)" "list|dict|deger,anahtar,kutu,ts" "$(tur '"%s|%s|%s" % (type(j["kayit"]["adimlar"]).__name__, type(j["kayit"]["adimlar"][0]).__name__, ",".join(sorted(j["kayit"]["adimlar"][0], key=["deger","anahtar","kutu","ts"].index)))')"
kapi "S4 adım metni nesnenin deger alanında BİREBİR" "True" "$(tur '"sözleşme denemesi" in [x["deger"] for x in j["kayit"]["adimlar"]]')"
ham="$(cagir -X PATCH "$DEFTER_UC/kayit/$GOREV" -d '{"adimlar":["sözleşme denemesi"]}' -w '\n%{http_code}')"; govde="$(sed '$d' <<<"$ham")"
kapi "S5 aynı adım ikinci kez: degisti=false, adım iki kez yazılmaz" "False|1" "$(tur '"%s|%d" % (j["degisti"], [x["deger"] for x in j["kayit"]["adimlar"]].count("sözleşme denemesi"))')"

echo "── İ · istek"
out="$(K "$M/SERDAR-ENIS-baglam-karti-20261018-1.md")"; rc=$?
kapi "İ1 geçerli istek: rc 0, 'adım yazıldı'" "0|1" "$rc|$(grep -c 'adım yazıldı' <<<"$out")"
kapi "İ2 adım gerçek kayıtta, şablon §3 biçiminde" "True" "$(adimlar | python3 -c 'import sys,json; print("istek 20261018-1 · SERDAR · ufuk bu hafta · son an 2026-10-20 18:00" in json.load(sys.stdin))')"
kapi "İ3 aynı istek ikinci kez: rc 0, 'zaten yazılıydı', adım sayısı değişmez" "0|1|2" "$(K "$M/SERDAR-ENIS-baglam-karti-20261018-1.md" >"$T/o"; echo "$?|$(grep -c 'zaten yazılıydı' "$T/o")|$(sayi)")"

echo "── C · cevap"
out="$(K "$M/ENIS-SERDAR-baglam-karti-20261018-1.md")"; rc=$?
kapi "C1 geçerli cevap: rc 0" "0" "$rc"
kapi "C2 cevap adımı gerçek kayıtta" "True" "$(adimlar | python3 -c 'import sys,json; print("cevap 20261018-1 · SERDAR · durum verildi · kapı geçti" in json.load(sys.stdin))')"
kapi "C3 karar cümlesi ve kart metni defterde YOK (mahremiyet)" "0" "$(cagir "$DEFTER_UC/kayit/$GOREV" | grep -c -e 'satış görüşmesi' -e 'tempo düşük')"
kapi "C4 defter kütüğünde de yok" "0" "$(grep -c -e 'satış görüşmesi' -e 'tempo düşük' "$T/kutuk.jsonl" "$T/defter.json" | awk -F: '{s+=$NF} END{print s+0}')"

echo "── F · fail-closed (gerçek reddetme yolları)"
n0="$(sayi)"
printf 'HEDEF: enis\nKOPYA: muavin\n\n# SERDAR → ENİS · bağlam kartı isteği 2\n\nKarar:   %s\nUfuk:    bugün\nSon an:  2026-10-21 09:00\n' "$KARAR" > "$M/SERDAR-ENIS-baglam-karti-20261018-2.md"
out="$(DEFTER_JETON_YOL="$T/j-baska" K "$M/SERDAR-ENIS-baglam-karti-20261018-2.md")"; rc=$?
kapi "F1 görmeye yetkisiz jeton (başka kutu): rc 1, adım YAZILMADI" "1|$n0" "$rc|$(sayi)"
out="$(BAGLAM_KARTI_GOREV=gorev_YOKTUR K "$M/SERDAR-ENIS-baglam-karti-20261018-2.md")"; rc=$?
kapi "F2 olmayan görev: rc 1 (defter reddetti), kart dönmez" "1" "$rc"
printf 'bilinmeyen-jeton\n' > "$T/j-yanlis"
out="$(DEFTER_JETON_YOL="$T/j-yanlis" K "$M/SERDAR-ENIS-baglam-karti-20261018-2.md")"; rc=$?
kapi "F3 tanınmayan jeton: rc 1" "1" "$rc"
out="$(DEFTER_UC="http://127.0.0.1:9" K "$M/SERDAR-ENIS-baglam-karti-20261018-2.md")"; rc=$?
kapi "F4 defter ulaşılamaz: rc 1" "1" "$rc"
kapi "F5 fail-closed yolları kayıt sayısını DEĞİŞTİRMEDİ" "$n0" "$(sayi)"
kapi "F6 jeton değeri hiçbir çıktıda yok" "0" "$(cat "$T/o" <<<"$out" | grep -c -e jeton-serdar -e jeton-baska)"

echo "── Y · geçerli ikinci istek hâlâ yazılır (reddetme yolları kaydı bozmadı)"
out="$(K "$M/SERDAR-ENIS-baglam-karti-20261018-2.md")"; rc=$?
kapi "Y1 rc 0 ve sayı +1" "0|$((n0+1))" "$rc|$(sayi)"

echo "── $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ] || exit 1
exit 0
