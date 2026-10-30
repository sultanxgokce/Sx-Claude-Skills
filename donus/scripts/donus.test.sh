#!/usr/bin/env bash
# donus.test.sh — hermetik: geçici kutu/merkez dizinleri, sahte aile-notify (çağrıyı kaydeder), geçici görev defteri.
# Ölçülür: kutuda dosya ADINDA numara + ilk-5-satır sözleşmesi (zil ve hızlı yol bunu okur) · merkezde açan G#### → defter,
# G-AJAN-#### → görev mektubu · ASCII açan Türkçe kimliğe eşlenir · zil düşerse rc 4 ama dönüş YAZILI · açan yoksa rc 3 ·
# biçim/çok satır/uzunluk kapıları · kuru koşum hiçbir şey yazmaz/çağırmaz.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$D/donus.sh"; T="$(mktemp -d)"; trap 'rm -r "$T"' EXIT
gecen=0; kalan=0; kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }
# kutu
mkdir -p "$T/kutu/proj/0-teslimat/giden" && git -C "$T/kutu/proj" init -q
# merkez (sahte Nexus)
N="$T/nexus"; mkdir -p "$N/scripts" "$N/_agents/handoff" "$N/0-teslimat/giden" "$T/filo"
printf '#!/bin/bash\necho "$1|$2" >> "%s/zil"; exit "${ZIL_RC:-0}"\n' "$T" > "$N/scripts/aile-notify.sh"; : > "$N/scripts/filo.py"
printf 'uyeler:\n  - id: SERDAR\n  - id: MUAVİN\n  - id: BÂNİ\n' > "$N/_agents/handoff/aile-registry.yaml"
printf 'HEDEF: merkez\nAJAN: BANI\nGOREV: G-BANI-0006\n\n# SERDAR → BÂNİ\n' > "$N/_agents/handoff/SERDAR-BANI-gorev-donus-zili-20261013.md"
printf '%s\n' '{"no":"G0034","kim":"SERDAR"}' '{"no":"G0040","kim":"MUAVIN"}' > "$T/filo/gorev.jsonl"
export FILO_DIZ="$T/filo" DONUS_NEXUS="$N"
K() { ( cd "$T/kutu/proj" && DONUS_KIP=kutu bash "$S" "$@" ) 2>&1; }
M() { : > "$T/zil"; ( cd "$N" && DONUS_KIP=merkez bash "$S" "$@" ) 2>&1; }
echo "── K · kutu"
out="$(K G0034 bitti "ölçüler perdeciye gitti" --ben PEYK)"; rc=$?
f="$(ls "$T/kutu/proj/0-teslimat/giden/" | head -1)"
kapi "K1 kutuda giden kutusuna yazıldı, rc 0" "0|1" "$rc|$(ls "$T/kutu/proj/0-teslimat/giden/" | wc -l)"
kapi "K2 dosya ADINDA numara, gönderen önde" "1" "$([[ "$f" =~ ^PEYK-G0034-[0-9]{8}-[0-9]{6}\.md$ ]] && echo 1 || echo 0)"
GNO_RE='(^|[^A-Za-z0-9])[Gg][0-9]{4}([^0-9]|$)'   # donus-hizli.sh / oda-cevap-zili.sh ile AYNI desen
kapi "K3 merkezin hızlı yolu bu adı tanır (çapraz desen)" "1" "$([[ "$f" =~ $GNO_RE ]] && echo 1 || echo 0)"
h="$(head -5 "$T/kutu/proj/0-teslimat/giden/$f")"
kapi "K4 ilk 5 satır: 'G0034 · bitti · …' · '→ AÇAN' başlığı · HEDEF · GOREV · DURUM" "1|1|1|1|1" \
  "$(sed -n 1p <<<"$h" | grep -c '^G0034 · bitti · ölçüler')|$(sed -n 2p <<<"$h" | grep -c '→ ')|$(grep -c '^HEDEF: merkez' <<<"$h")|$(grep -c '^GOREV: G0034' <<<"$h")|$(grep -c '^DURUM: bitti' <<<"$h")"
kapi "K5 kutuda zil ÇAĞRILMAZ (ssh yok; merkez yoklar)" "yok" "$([ -s "$T/zil" ] && echo var || echo yok)"
# 1.0.2 (nazir, 30 Eki): izole kutuda Nexus SALT OKUR kopyadır → kip kendiliğinden kutu olmalı; salt okur Nexus'a yazılmaz
RO="$T/nexus-ro"; mkdir -p "$RO/scripts" "$RO/0-teslimat/giden"; : > "$RO/scripts/aile-notify.sh"; : > "$RO/scripts/filo.py"; chmod a-w "$RO/0-teslimat/giden" "$RO/0-teslimat"
out="$( cd "$T/kutu/proj" && DONUS_KIP= DONUS_NEXUS="$RO" bash "$S" G0034 bitti "salt okur sınavı" --ben PEYK 2>&1 )"; rc=$?
kapi "K6 Nexus dosyaları var ama giden kutusu salt okur → kip KUTU, dönüş kutunun giden kutusuna yazılır, Nexus'a yazılmaz, rc 0" "0|1|0|kutu" \
  "$rc|$(grep -l 'salt okur sınavı' "$T/kutu/proj/0-teslimat/giden/"*.md 2>/dev/null | wc -l)|$(ls "$RO/0-teslimat/giden/" | wc -l)|$( cd "$T/kutu/proj" && DONUS_KIP= DONUS_NEXUS="$RO" bash "$S" G0034 bitti "kuru" --ben PEYK --kuru 2>&1 | grep -o 'kip: [a-z]*' | head -1 | sed 's/kip: //')"
chmod u+w "$RO/0-teslimat/giden" "$RO/0-teslimat"
# cwd projede değil + aday listesinde ilk proje salt okur → yazılabilir ikinci proje seçilir
PK="$T/projeler"; mkdir -p "$PK/a-ro/0-teslimat/giden" "$PK/b-rw/0-teslimat/giden"; chmod a-w "$PK/a-ro/0-teslimat/giden" "$PK/a-ro/0-teslimat"
out="$( cd "$T" && DONUS_KIP=kutu DONUS_PROJE_KOK="$PK" bash "$S" G0034 bitti "aday sınavı" --ben PEYK 2>&1 )"; rc=$?
kapi "K7 cwd projede değil, ilk aday salt okur → yazılabilir ikinci projenin giden kutusu seçilir, rc 0" "0|0|1" "$rc|$(ls "$PK/a-ro/0-teslimat/giden/" | wc -l)|$(ls "$PK/b-rw/0-teslimat/giden/" | wc -l)"
chmod u+w "$PK/a-ro/0-teslimat/giden" "$PK/a-ro/0-teslimat"
echo "── M · merkez"
out="$(M G0034 tikandi "numara yok, MAİŞET'ten bekleniyor" --ben BANI)"; rc=$?
kapi "M1 G#### → açan defterden (SERDAR), mesajda numara+durum, rc 0" "0|SERDAR|1" "$rc|$(cut -d'|' -f1 "$T/zil")|$(grep -c 'G0034 · tikandi' "$T/zil")"
kapi "M2 durum defteri: G0034 tikandi durtuldu" "G0034 tikandi durtuldu" "$(python3 -c 'import json,sys;d=[json.loads(x) for x in open(sys.argv[1])][-1];print(d["no"],d["durum"],d["zil"])' "$T/filo/gorev-durum.jsonl")"
kapi "M3 merkez dönüşü Nexus giden kutusunda (kalıcı işaret)" "1" "$(ls "$N/0-teslimat/giden/" | grep -c '^BANI-G0034-')"
out="$(M G-BANI-0006 bitti "dönüş zili inşa edildi" --ben BANI --kanit PR)"; rc=$?
kapi "M4 G-AJAN-#### → açan görev mektubundan (SERDAR)" "0|SERDAR" "$rc|$(cut -d'|' -f1 "$T/zil")"
out="$(M G0040 soru "hangi gün?")"; kapi "M5 ASCII açan (MUAVIN) → kayıt kimliği MUAVİN" "MUAVİN" "$(cut -d'|' -f1 "$T/zil")"
out="$(ZIL_RC=1 M G0034 bitti "zil düşecek")"; rc=$?
kapi "M6 zil düşerse rc 4, dönüş YAZILI, durum zil=ulasmadi" "4|ulasmadi" "$rc|$(python3 -c 'import json,sys;print([json.loads(x) for x in open(sys.argv[1])][-1]["zil"])' "$T/filo/gorev-durum.jsonl")"
out="$(M G0099 bitti "defterde yok")"; rc=$?
kapi "M7 açan bulunamazsa rc 3, kimse çalınmaz, dönüş yine yazılır" "3|yok|1" "$rc|$([ -s "$T/zil" ] && echo var || echo yok)|$(ls "$N/0-teslimat/giden/" | grep -c 'G0099')"
out="$(M G0099 bitti "elle açan" --kime SERDAR)"; kapi "M8 --kime açanı verir" "SERDAR" "$(cut -d'|' -f1 "$T/zil")"
echo "── B · biçim kapıları (dosya yazılmaz)"
n0="$(ls "$N/0-teslimat/giden/" | wc -l)"
for a in "G34|bitti|x" "G0034|tamam|x" "G-bani-0006|bitti|x" "G0034|bitti|"; do
  IFS='|' read -r x y z <<<"$a"; M "$x" "$y" "$z" >/dev/null; r=$?; kapi "B '$x' '$y' '$z' → rc 2" "2" "$r"; done
M G0034 bitti "$(printf 'iki\nsatır')" >/dev/null; kapi "B5 çok satırlı özet → rc 2" "2" "$?"
M G0034 bitti "$(printf 'x%.0s' $(seq 1 301))" >/dev/null; kapi "B6 300 karakter üstü → rc 2" "2" "$?"
kapi "B7 hiçbir ret dosya yazmadı" "$n0" "$(ls "$N/0-teslimat/giden/" | wc -l)"
out="$(M G0034 bitti "kuru" --kuru)"; kapi "B8 kuru koşum: yazmaz, çalmaz" "$n0|yok" "$(ls "$N/0-teslimat/giden/" | wc -l)|$([ -s "$T/zil" ] && echo var || echo yok)"
echo; echo "GEÇEN: $gecen · KALAN: $kalan"; [ "$kalan" = 0 ]
