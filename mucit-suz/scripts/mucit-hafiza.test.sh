#!/usr/bin/env bash
# mucit-hafiza.test.sh — MUCİT'in masası (ADR-025 K6): brifing + karne kapıları.
# KAŞİF'in `kasif-hafiza.test.sh`'inin ikizi; aynı dört soruyu MUCİT için sorar.
# HERMETİK: yalnız $T altında sahte defterler; gerçek deftere dokunmaz (M5/M9 kanıtlar).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIEF="$DIR/mucit-brief.sh"
KARNE="$DIR/mucit-karne.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

D="$T/mucit-defteri.jsonl"; H="$T/havuz.jsonl"; : > "$D"; : > "$H"
brief(){ MUCIT_DEFTER="$D" MUCIT_HAVUZ="$H" bash "$BRIEF" "$@" 2>/dev/null; }
karne(){ MUCIT_DEFTER="$D" MUCIT_HAVUZ="$H" bash "$KARNE" "$@" 2>/dev/null; }

echo "== M1: sözdizimi =="
bash -n "$BRIEF" 2>/dev/null && ok "mucit-brief.sh temiz" || no "brief sözdizimi"
bash -n "$KARNE" 2>/dev/null && ok "mucit-karne.sh temiz" || no "karne sözdizimi"

echo "== M2: defter BOŞKEN brifing SESSİZ =="
out="$(brief)"; rc=$?
[ -z "$out" ] && ok "çıktı boş" || no "boş defterde konuştu"
[ "$rc" -eq 0 ] && ok "rc=0" || no "rc=$rc"

echo "== M3: ELEDİKLERİM görünür (asıl birikim — aynı analizi tekrar yaptırmaz) =="
cat > "$D" <<'JSONL'
{"turu":"t1","tarih":"2026-07-20","bulgu_id":"b1","baslik":"Elenen birinci fikir","verdikt":"elendi","kart":null,"not":"zaten-var: scripts/x.sh"}
{"turu":"t1","tarih":"2026-07-21","bulgu_id":"b2","baslik":"Elenen ikinci fikir","verdikt":"elendi","kart":null,"not":"kanit yetersiz"}
{"turu":"t2","tarih":"2026-07-22","bulgu_id":"b3","baslik":"Aday olan fikir","verdikt":"aday-arzi","kart":"k0099","not":"guclu"}
JSONL
printf '{"id":"b1","kaynak":"kasif","durum":"ham","tarih":"2026-07-19","baslik":"x","kanit":"k"}\n{"id":"b2","kaynak":"kasif","durum":"islendi","tarih":"2026-07-19","baslik":"y","kanit":"k"}\n' > "$H"
o="$(brief --gun 3650)"
grep -q 'elediklerim' <<<"$o" && ok "eleme başlığı var" || no "eleme bölümü yok"
grep -q 'zaten-var' <<<"$o" && ok "GEREKÇE gösteriliyor (tekrar analiz panzehiri)" || no "gerekçe basılmadı"
grep -q 'aday yaptıklarım' <<<"$o" && ok "aday bölümü var (eşik kalibrasyonu)" || no "aday bölümü yok"
grep -q 'ham malzeme bekliyor' <<<"$o" && ok "önündeki iş gösteriliyor" || no "havuz durumu yok"

echo "== M4: ÖLÇEK — defter 2000 kayda çıksa da brifing ≤40 satır =="
python3 - "$D" <<'PY' 2>/dev/null
import json, io, sys, random
random.seed(11); p=sys.argv[1]
with io.open(p,"w",encoding="utf-8") as f:
    for i in range(2000):
        v = random.choice(["elendi","aday-arzi","preview"])
        f.write(json.dumps({"turu":f"t{i%9}","tarih":"2026-07-%02d"%(i%28+1),"bulgu_id":f"b{i}",
                            "baslik":f"Fikir {i} "+"uzun "*18,"verdikt":v,"kart":None,
                            "not":"gerekce "+"detay "*12},ensure_ascii=False)+"\n")
PY
buyuk="$(brief --gun 3650)"; n="$(printf '%s\n' "$buyuk" | wc -l)"
[ "$n" -le 40 ] && ok "2000 kayıtla brifing $n satır (tavan 40)" || no "TAVAN AŞILDI: $n"
printf '%s' "$buyuk" | grep -qE '^\{|"bulgu_id"|"verdikt"' && no "HAM KAYIT sızdı" || ok "ham JSONL basılmadı"

echo "== M5: brifing SALT-OKUR =="
imza="$(md5sum "$D" "$H" | md5sum)"
brief --gun 3650 >/dev/null
[ "$imza" = "$(md5sum "$D" "$H" | md5sum)" ] && ok "defter+havuz değişmedi" || no "brifing yazdı"

echo "== M6: karne AZ VERİYLE hüküm vermez =="
printf '{"turu":"t","tarih":"2026-07-27","bulgu_id":"b","baslik":"tek","verdikt":"elendi","kart":null,"not":"n"}\n' > "$D"
o="$(karne --gun 3650)"
grep -q 'Henüz karne verilemez' <<<"$o" && ok "1 karar → reddedildi" || no "az veriyle hüküm verdi"
grep -qE 'geçirme oranı|gerekçe oranı' <<<"$o" && no "yine de oran bastı" || ok "hiçbir oran basılmadı"

echo "== M7: karne YETERLİ veriyle oranları basar =="
python3 - "$D" <<'PY' 2>/dev/null
import json, io, sys
p=sys.argv[1]
kayit=[]
for i in range(6):
    v = "aday-arzi" if i < 2 else "elendi"
    kayit.append({"turu":"t","tarih":"2026-07-2%d"%(i+1),"bulgu_id":f"b{i}","baslik":f"f{i}",
                  "verdikt":v,"kart":None,"not":("gerekce" if i != 5 else "")})
io.open(p,"w",encoding="utf-8").write("\n".join(json.dumps(r,ensure_ascii=False) for r in kayit)+"\n")
PY
o="$(karne --gun 3650)"
grep -q 'geçirme oranı' <<<"$o"   && ok "geçirme oranı basıldı"   || no "geçirme yok"
grep -q 'gerekçe oranı' <<<"$o"   && ok "gerekçe oranı basıldı"   || no "gerekçe yok"
grep -q 'havuz sindirimi' <<<"$o" && ok "havuz sindirimi basıldı" || no "sindirim yok"
# 4 eleme, 3'ünde gerekçe var → %75
grep -q 'gerekçe oranı : %75' <<<"$o" && ok "gerekçe oranı doğru hesaplandı (%75)" || no "gerekçe hesabı"

echo "== M8: karne ADET ölçmez (eşik gevşemesin) =="
grep -qE '^\s+(üretilen|toplam) (aday|karar)\s*:' <<<"$o" && no "adet ölçütü girmiş" || ok "adet ölçütü YOK"
grep -q 'ölçtüğün şeyi üretirsin' <<<"$o" && ok "gerekçe ekranda" || no "gerekçe basılmadı"

echo "== M9: karne SALT-OKUR =="
imza2="$(md5sum "$D" "$H" | md5sum)"
karne --gun 3650 >/dev/null
[ "$imza2" = "$(md5sum "$D" "$H" | md5sum)" ] && ok "defter değişmedi" || no "karne yazdı"

echo "== M10: 'doğum' kaydı karar sayılmaz (sayaç kirlenmesin) =="
printf '{"turu":"dogum","tarih":"2026-07-14","bulgu_id":null,"baslik":"MUCİT doğdu","verdikt":"dogum","kart":null,"not":"x"}\n' > "$D"
o="$(karne --gun 3650)"
grep -q 'Henüz karne verilemez' <<<"$o" && ok "yalnız doğum kaydı → karar sayılmadı" || no "doğum karar sayıldı"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
