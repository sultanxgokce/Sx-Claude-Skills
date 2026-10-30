#!/usr/bin/env bash
# oda-etiketleri.test.sh — ODA BEYANI kapısı, PAKETİN İÇİNDE.
#
# 🔴 NEDEN VAR (ölçüldü 2026-09-18, gerçek market planı): çizimde oda adı ile raf adı AYNI
# katmanlarda durur — oda adları 'not'/'duvar', raf adları 'kolon'/'yok-say' rolündeydi.
# Katman rolüyle ayrım yapmak oda adlarını eler, raf adlarını bırakır. Ayrımı insan yapar:
# `oda_etiketleri` BEYANI (ek_muhur/ek_cevre deseni). Beyan iz bırakır, sessizce yutmaz.
# DEĞİŞMEZ: fixture sentetik; müşteri dosyası kullanılmaz.
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }
bek_rc() { local b="$1" ad="$2"; shift 2; "$@" >"$T/o" 2>"$T/e"; local r=$?; [ "$r" -eq "$b" ] && ok || kir "$ad (beklenen RC=$b, gelen $r)"; }
bek_metin() { local m="$1" ad="$2" d="$3"; grep -qF -- "$m" "$d" && ok || kir "$ad — '$m' yok: $(tail -2 "$d" | tr '\n' ' ')"; }

# Fixture: iki oda (alt SALON, üst MUTFAK). SALON'un içinde bir RAF etiketi var —
# gerçek market planındaki kusurun sentetik hâli: iki etiket aynı bölgeye düşer.
kur() {  # $1 = ek alanlar
  cat <<JSON > "$T/f.json"
{ "sinir": [ [[0,0],[1000,0]], [[1000,0],[1000,1000]], [[1000,1000],[0,1000]], [[0,1000],[0,0]], [[0,500],[1000,500]] ],
  "etiketler": [ {"ad":"SALON","m2":null,"x":500,"y":250},
                 {"ad":"\\\\C0;S\\\\U+00DCTL\\\\U+00DCK","m2":null,"x":700,"y":200},
                 {"ad":"MUTFAK","m2":null,"x":500,"y":750} ]$1 }
JSON
}

# 1) Beyansız: iki etiket aynı bölgede → bugünkü davranış (RC 1) KORUNUR
kur ""
bek_rc 1 "beyansız dosyada davranış değişmedi (aynı bölgede iki etiket → RC 1)" python3 lib/lifting.py "$T/f.json" "$T/o1.json"

# 2) Beyanla: yalnız SALON + MUTFAK tohum → iki oda çıkar
kur ', "oda_etiketleri": ["SALON","MUTFAK"], "oda_etiketleri_gerekce": "kullanici isaretledi"'
bek_rc 0 "oda beyanı ile raf etiketi elenir, RC=0" python3 lib/lifting.py "$T/f.json" "$T/o2.json"
bek_metin '"kaynak": "oda_etiketleri"' "çıktıda beyan İZİ var" "$T/o2.json"
bek_metin '"tohum": 2' "tohum sayısı kayda geçer" "$T/o2.json"
bek_metin '"elenen_etiket": 1' "elenen etiket SAYISI kayda geçer" "$T/o2.json"
bek_metin "kullanici isaretledi" "beyanın gerekçesi kayda geçer" "$T/o2.json"
bek_metin '"ad": "MUTFAK"' "beyan edilen iki oda da çıkar" "$T/o2.json"

# 3) MUTASYON: yanlış beyan — aynı bölgedeki iki adı oda ilan et → RC 1 (kapı kandırılamaz)
kur ', "oda_etiketleri": ["SALON","SÜTLÜK"]'
bek_rc 1 "aynı bölgeye düşen iki beyan REDDEDİLİR" python3 lib/lifting.py "$T/f.json" "$T/o3.json"

# 4) Bulunamayan beyan sessizce yutulmaz
kur ', "oda_etiketleri": ["SALON","MUTFAK","OLMAYAN ODA"]'
python3 lib/lifting.py "$T/f.json" "$T/o4.json" >/dev/null 2>"$T/e4"
bek_metin "BULUNAMADI" "eşleşmeyen beyan UYARI olarak basılır" "$T/e4"
bek_metin '"eslesmeyen": [' "eşleşmeyen beyan çıktıya da yazılır" "$T/o4.json"

# 5) Hiçbiri eşleşmezse oda üretilmez (fail-closed)
kur ', "oda_etiketleri": ["YOK1","YOK2"]'
bek_rc 1 "hiçbir beyan eşleşmezse RC=1" python3 lib/lifting.py "$T/f.json" "$T/o5.json"

# 6) CAD kaçışlı ad insan yazımıyla eşleşir (ASANSÖR örneği)
kur ', "oda_etiketleri": ["SALON","MUTFAK","SÜTLÜK"]'
python3 lib/lifting.py "$T/f.json" "$T/o6.json" >/dev/null 2>"$T/e6"
bek_metin '3 ad istendi → 3 tohum' "CAD kaçışlı '\\U+00DCTL\\U+00DCK' insan yazımıyla eşleşti" "$T/e6"

printf 'oda-etiketleri: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
