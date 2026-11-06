#!/usr/bin/env bash
# kanit-kirli-say.test.sh — kapanış ölçümü dört kayıt türünü AYRI sayar, kapı damgasını süzgeç yapmaz (görev …PYWKB).
set -u
D="$(cd "$(dirname "$0")" && pwd)"
A="$D/kanit-kirli-say.py"
T="$(mktemp -d)"; trap 'find "$T" -delete 2>/dev/null' EXIT
G=0; K=0
ok() { G=$((G+1)); echo "  ✓ $1"; }
no() { K=$((K+1)); echo "  ✗ $1"; }
kos() { OUT="$(python3 "$A" "$@" 2>&1)"; RC=$?; }
satir() { printf '%s\n' "$OUT" | awk -v t="$1" '$1==t {print $2, $3, $4, $5, $6}'; }

mk() { mkdir -p "$T/$1/_agents/fabrika/kanit/$2"; printf '%s' "$3" > "$T/$1/_agents/fabrika/kanit/$2/KANIT.json"; }

# depo a: her türden birer izinsiz kirli kayıt; dosya ve canli kaydında kirli_kurali YOK (0.8.0 aracı: kapı koşmamıştı)
mk a is1 '{"kayitlar":[
 {"tur":"olcum","etiket":"o1","olcum_id":"o1","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":true,"kirli_kurali":1},
 {"tur":"ekran","etiket":"e1","olcum_id":"e1","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":true,"kirli_kurali":1},
 {"tur":"dosya","etiket":"d1","olcum_id":"d1","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":true},
 {"tur":"canli","etiket":"c1","olcum_id":"c1","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":true},
 {"tur":"dosya","etiket":"d2","olcum_id":"d2","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":true,"kirli_izin":"bilerek kirli: taslak kayıt"},
 {"tur":"canli","etiket":"c2","olcum_id":"c2","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":false},
 {"tur":"olcum","etiket":"o2","olcum_id":"o2","zaman":"2026-11-06T10:00:00+03:00"},
 {"tur":"gecersiz","olcum_id":"g1","zaman":"2026-11-06T10:00:00+03:00"}]}'

echo "── K1 dört tür ayrı satır, kapı damgası süzgeç değil"
kos "$T/a"
[ "$RC" = 1 ] && ok "izinsiz varken rc 1" || no "rc=$RC (1 beklendi)"
[ "$(satir olcum)" = "2 1 0 1 1" ] && ok "olcum: 2 toplam · 1 izinsiz · 1 ölçülemedi" || no "olcum satırı: $(satir olcum)"
[ "$(satir ekran)" = "1 1 0 1 0" ] && ok "ekran: 1 izinsiz" || no "ekran satırı: $(satir ekran)"
[ "$(satir dosya)" = "2 2 1 1 0" ] && ok "dosya: damgasız izinsiz kayıt sayıldı, izinli ayrı" || no "dosya satırı: $(satir dosya)"
[ "$(satir canli)" = "2 1 0 1 0" ] && ok "canli: damgasız izinsiz sayıldı, temiz kayıt kirli değil" || no "canli satırı: $(satir canli)"
printf '%s\n' "$OUT" | grep -q "İZİNSİZ KİRLİ TOPLAM=4 · olcum=1 · ekran=1 · dosya=1 · canli=1" && ok "toplam satırı dört türü adıyla basar" || no "toplam satırı yok"
printf '%s\n' "$OUT" | grep -q "dört tür dışı (sayıma girmedi): gecersiz=1" && ok "tür dışı kayıt söylenir" || no "tür dışı satırı yok"

echo "── K2 görülmeyen tür de 0 satırıyla basılır"
mk b is2 '{"kayitlar":[{"tur":"olcum","olcum_id":"x1","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":false}]}'
kos "$T/b"
[ "$RC" = 0 ] && ok "izinsiz yok → rc 0" || no "rc=$RC"
for t in ekran dosya canli; do [ "$(satir $t)" = "0 0 0 0 0" ] && ok "$t satırı 0 ile basıldı" || no "$t satırı: $(satir $t)"; done

echo "── K3 pencere (--sonra) ve tekilleştirme"
mk c is1 '{"kayitlar":[
 {"tur":"dosya","olcum_id":"d1","zaman":"2026-11-06T10:00:00+03:00","olculen_kirli":true},
 {"tur":"canli","olcum_id":"c9","zaman":"2026-11-06T15:00:00+03:00","olculen_kirli":true}]}'
kos "$T/a" "$T/c"
[ "$(satir dosya)" = "2 2 1 1 0" ] && ok "aynı olcum_id iki kökte tek sayıldı" || no "dosya satırı: $(satir dosya)"
kos --sonra 2026-11-06T14:00:00+03:00 "$T/a" "$T/c"
[ "$RC" = 1 ] && [ "$(satir canli)" = "1 1 0 1 0" ] && [ "$(satir dosya)" = "0 0 0 0 0" ] && ok "pencere yalnız sonraki kaydı sayar" || no "rc=$RC canli=$(satir canli) dosya=$(satir dosya)"
kos --sonra 2026-11-06T16:00:00+03:00 "$T/a" "$T/c"
[ "$RC" = 0 ] && ok "pencere boş → rc 0" || no "rc=$RC"

echo "── K4 ölçülemedi ve kullanım hataları"
kos "$T/yok"
[ "$RC" = 3 ] && printf '%s\n' "$OUT" | grep -q "ÖLÇÜLEMEDİ" && ok "manifest yok → rc 3 ÖLÇÜLEMEDİ" || no "rc=$RC"
mk d bozuk '{bozuk'
kos "$T/d"
[ "$RC" = 3 ] && ok "yalnız bozuk manifest → rc 3" || no "rc=$RC"
kos --sonra dun "$T/a"
[ "$RC" = 2 ] && ok "okunamayan --sonra → rc 2" || no "rc=$RC"
kos "$T/a/_agents/fabrika/kanit/is1/KANIT.json"
[ "$RC" = 1 ] && [ "$(satir dosya)" = "2 2 1 1 0" ] && ok "doğrudan KANIT.json yolu da okunur" || no "rc=$RC"

echo "── SONUÇ: $G geçti · $K kaldı ──"
[ "$K" = 0 ]
