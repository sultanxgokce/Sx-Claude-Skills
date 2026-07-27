#!/usr/bin/env bash
# kasif-hafiza.test.sh — KAŞİF hafızasının OKUMA ucu (L24 F7): brifing + karne.
#
# Yazma ucunun testleri kasif-havuz-ekle.test.sh'te (H1-H8). Bu dosya iki soruyu sınar:
#   (a) brifing ölçekleniyor mu — defter büyüdükçe context'i şişiriyor mu?
#   (b) karne dürüst mü — az veriyle hüküm veriyor mu, adet ölçüp şişmeyi teşvik ediyor mu?
# HERMETİK: yalnız $TMP altında sahte defterler; gerçek deftere dokunmaz (B5/B9 kanıtlar).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIEF="$DIR/kasif-brief.sh"
KARNE="$DIR/kasif-karne.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
no(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

HD="$T/kasif"; mkdir -p "$HD"
HAVUZ="$T/havuz.jsonl"; : > "$HAVUZ"
brief(){ KASIF_HAFIZA_DIR="$HD" KASIF_HAVUZ="$HAVUZ" bash "$BRIEF" "$@" 2>/dev/null; }
karne(){ KASIF_HAFIZA_DIR="$HD" KASIF_HAVUZ="$HAVUZ" bash "$KARNE" "$@" 2>/dev/null; }

echo "== B1: sözdizimi =="
bash -n "$BRIEF" 2>/dev/null && ok "kasif-brief.sh temiz" || no "brief sözdizimi"
bash -n "$KARNE" 2>/dev/null && ok "kasif-karne.sh temiz" || no "karne sözdizimi"

echo "== B2: defter YOKKEN brifing SESSİZ (yeni oda gürültü görmez) =="
out="$(brief)"; rc=$?
[ -z "$out" ] && ok "çıktı boş" || no "boş defterde konuştu: [$out]"
[ "$rc" -eq 0 ] && ok "rc=0 (brifing bir kapı değil)" || no "rc=$rc"

echo "== B3: veri varken brifing konuşur =="
cat > "$HD/seyir.jsonl" <<'JSONL'
{"v":1,"tur":"t20260726-1","tarih":"2026-07-26","kaynak":"kasif","aday":3,"eklenen":2,"atlanan":{"dup":1,"anahtar":0,"sema":0}}
{"v":1,"tur":"t20260727-1","tarih":"2026-07-27","kaynak":"kasif","aday":1,"eklenen":0,"atlanan":{"dup":1,"anahtar":0,"sema":0}}
JSONL
cat > "$HD/kaynaklar.jsonl" <<'JSONL'
{"url_key":"iyi.dev/x","host":"iyi.dev","ilk":"2026-07-26","son":"2026-07-27","ziyaret":2,"verim":3,"turlar":["t20260726-1"],"bulgu_idler":["b1","b2","b3"],"durum":"aktif"}
{"url_key":"kisir.io/y","host":"kisir.io","ilk":"2026-07-26","son":"2026-07-27","ziyaret":4,"verim":0,"turlar":["t20260726-1"],"bulgu_idler":[],"durum":"aktif"}
JSONL
cat > "$HD/tekrar.jsonl" <<'JSONL'
{"dedup_key":"a","baslik":"Uc ayri yerden duyulan fikir","kez":3,"ilk":"2026-07-26","son":"2026-07-27","hostlar":["a.io","b.io","c.io"],"turlar":[]}
JSONL
out="$(brief --gun 30)"
grep -q 'KAŞİF brifingi' <<<"$out" && ok "başlık basıldı" || no "başlık yok"
grep -q 'iyi.dev' <<<"$out" && ok "verimli kaynak listelendi" || no "verimli kaynak yok"
grep -q 'kisir.io' <<<"$out" && ok "KISIR kaynak uyarısı var (bir daha gitme)" || no "kısır uyarısı yok"
grep -q 'Uc ayri yerden' <<<"$out" && ok "tekrar sinyali gösterildi" || no "tekrar sinyali yok"

echo "== B4: ÖLÇEK — defter 3000 kayda çıksa da brifing ≤40 satır =="
# En kritik test: brifing HER turun başında context'e giriyor. Kayıtla birlikte büyürse
# asıl işi (tarama) sıkıştırır ve zamanla kullanılamaz hâle gelir.
python3 - "$HD" <<'PY' 2>/dev/null
import json, io, sys, random
HD=sys.argv[1]; random.seed(7)
with io.open(f"{HD}/kaynaklar.jsonl","w",encoding="utf-8") as f:
    for i in range(1500):
        f.write(json.dumps({"url_key":f"h{i}.dev/p","host":f"h{i}.dev","ilk":"2026-07-01","son":"2026-07-27",
                            "ziyaret":random.randint(1,9),"verim":random.randint(0,7),"turlar":["t1"],
                            "bulgu_idler":[],"durum":"aktif"},ensure_ascii=False)+"\n")
with io.open(f"{HD}/tekrar.jsonl","w",encoding="utf-8") as f:
    for i in range(900):
        f.write(json.dumps({"dedup_key":f"k{i}","baslik":f"Tekrar eden fikir {i} " + "uzun "*20,
                            "kez":random.randint(1,9),"ilk":"2026-07-01","son":"2026-07-27",
                            "hostlar":[f"x{j}.io" for j in range(3)],"turlar":[]},ensure_ascii=False)+"\n")
with io.open(f"{HD}/seyir.jsonl","w",encoding="utf-8") as f:
    for i in range(600):
        f.write(json.dumps({"v":1,"tur":f"t2026072{i%7}-{i}","tarih":"2026-07-2%d"%(i%7+1),"kaynak":"kasif",
                            "aday":5,"eklenen":i%4,"atlanan":{"dup":1,"anahtar":0,"sema":0}},ensure_ascii=False)+"\n")
PY
buyuk="$(brief --gun 30)"
n="$(printf '%s\n' "$buyuk" | wc -l)"
[ "$n" -le 40 ] && ok "3000 kayıtla brifing $n satır (tavan 40)" || no "TAVAN AŞILDI: $n satır"
printf '%s' "$buyuk" | grep -qE '^\{|"url_key"|"dedup_key"' && no "HAM KAYIT sızdı (context kirliliği)" \
  || ok "ham JSONL basılmadı — yalnız damıtılmış satır"

echo "== B5: brifing SALT-OKUR =="
onceki="$(cd "$HD" && md5sum ./*.jsonl 2>/dev/null | md5sum)"
brief --gun 30 >/dev/null
[ "$onceki" = "$(cd "$HD" && md5sum ./*.jsonl 2>/dev/null | md5sum)" ] \
  && ok "hiçbir defter değişmedi" || no "brifing yazdı"

echo "== B6: karne AZ VERİYLE hüküm vermez (dürüstlük kapısı) =="
printf '{"v":1,"tur":"t20260727-1","tarih":"2026-07-27","kaynak":"kasif","aday":1,"eklenen":1,"atlanan":{"dup":0,"anahtar":0,"sema":0}}\n' > "$HD/seyir.jsonl"
out="$(karne)"
grep -q 'Henüz karne verilemez' <<<"$out" && ok "3 turdan az → karne reddedildi" || no "az veriyle hüküm verdi"
grep -qE 'dönüşüm|boşa geçen' <<<"$out" && no "yine de oran bastı" || ok "hiçbir oran basılmadı"

echo "== B7: karne YETERLİ veriyle dört oranı basar =="
python3 - "$HD" "$HAVUZ" <<'PY' 2>/dev/null
import json, io, sys, datetime
HD, HAVUZ = sys.argv[1], sys.argv[2]
b=datetime.date(2026,7,27)
with io.open(f"{HD}/seyir.jsonl","w",encoding="utf-8") as f:
    for i,ek in enumerate([3,2,0,1,2,0,4,2]):
        d=(b-datetime.timedelta(days=7-i)).isoformat()
        f.write(json.dumps({"v":1,"tur":f"t{d.replace('-','')}-1","tarih":d,"kaynak":"kasif",
                            "aday":ek+1,"eklenen":ek,"atlanan":{"dup":1,"anahtar":0,"sema":0}},ensure_ascii=False)+"\n")
with io.open(HAVUZ,"w",encoding="utf-8") as f:
    for i in range(14):
        f.write(json.dumps({"id":f"b{i:04d}","kaynak":"kasif","baslik":f"b{i}",
                            "durum":"islendi" if i<5 else "ham","kanit":"x","tarih":"2026-07-25"},ensure_ascii=False)+"\n")
PY
out="$(karne)"
grep -q 'dönüşüm' <<<"$out"        && ok "dönüşüm oranı basıldı"      || no "dönüşüm yok"
grep -q 'boşa geçen tur' <<<"$out" && ok "boşa-tur oranı basıldı"     || no "boşa-tur yok"
grep -q 'kaynak isabeti' <<<"$out" && ok "kaynak isabeti basıldı"     || no "isabet yok"
grep -q 'tekrar yükü' <<<"$out"    && ok "tekrar yükü basıldı"        || no "tekrar yükü yok"

echo "== B8: karne ADET ölçmez (ölçtüğünü üretirsin — havuz çöple dolmasın) =="
grep -qE '^\s+(getirilen|toplam) (bulgu|malzeme)\s*:' <<<"$out" \
  && no "adet-bazlı ölçüt karneye girmiş" || ok "adet-bazlı ölçüt YOK (yalnız oranlar)"
grep -q 'ölçtüğün şeyi üretirsin' <<<"$out" && ok "gerekçe ekranda yazılı" || no "gerekçe basılmadı"

echo "== B9: karne SALT-OKUR =="
onceki2="$(cd "$HD" && md5sum ./*.jsonl 2>/dev/null | md5sum)"
karne >/dev/null
[ "$onceki2" = "$(cd "$HD" && md5sum ./*.jsonl 2>/dev/null | md5sum)" ] \
  && ok "hiçbir defter değişmedi" || no "karne yazdı"

echo ""
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
