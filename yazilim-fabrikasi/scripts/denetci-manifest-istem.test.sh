#!/usr/bin/env bash
# denetci-manifest-istem.test.sh — GÖZE GİDEN TAM İSTEMİN baytı: geçersiz ilanlar şişirmesin (gorev_01M6AX7Y31S4R4GK6NMDKT29NK).
# Mihenk PYBNNV (1 Kas): 51 kaydın 28'i geçersizlik ilanı, manifest 67 KB, istem 114 KB > tavan. Burada AYNI sınıf küçük ölçekte kurulur:
# gerçek kanit.sh ile N ölçüm + N geçersiz ilan, sahte göz gelen istemi saklar, ESKİ (ham cat) ve YENİ denetci.sh'ın istemi KARŞILAŞTIRILIR.
# ESKİ taban = yeni denetci.sh'ın manifest çağrısı ham cat'e çevrilmiş kopyası. Sınav "önce/sonra istem baytı" satırını basar.
# kabuk-testleri: sure=120
set -uo pipefail
export DALGIC_KAPALI=1 KANIT_SIRA=0 DENETCI_SIRA=0 FABRIKA_AILE_NOTIFY=-
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; ESKI="$HERE/.denetci-eski-$$.sh"; trap 'find "$T" -delete 2>/dev/null; rm -f "$ESKI"' EXIT
# ESKİ taban = YENİ denetci.sh'ın manifest çağrısı eski haline (ham cat) çevrilmiş kopyası: origin/main'e bağlı değil, birleşince de geçerli.
python3 - "$D" "$ESKI" <<'PY2'
import sys; s,d=sys.argv[1:]; t=open(s,encoding='utf-8').read()
e='python3 "$HERE/manifest-ozet.py" "$DZ/KANIT.json" 2>/dev/null || cat "$DZ/KANIT.json"'
assert t.count(e)==1, "manifest çağrısı bulunamadı"
open(d,'w',encoding='utf-8').write(t.replace(e,'cat "$DZ/KANIT.json"',1))
PY2
grep -q 'cat "\$DZ/KANIT.json"' "$ESKI"; g $? "ESKİ denetci.sh ham 'cat KANIT.json' yapıyor (karşılaştırma tabanı)"
( cd "$T" && git init -q -b main ) >/dev/null 2>&1
ZB="$T/.zil-kilidi"; mkdir -p "$ZB"; printf '#!/usr/bin/env bash\nexit 0\n' > "$ZB/aile-notify.sh"; chmod +x "$ZB/aile-notify.sh"
export PATH="$ZB:$PATH" AILE_SINYAL_LOG="$ZB/sinyal.log" KANIT_DEPO="$T"
printf 'diff --git a/x b/x\n+satir\n' > "$T/d.patch"
# sahte göz: gelen istem dosyasını saklar, geçerli bir hüküm döner
SAHTE="$T/sahte.sh"
cat > "$SAHTE" <<'EOF'
#!/usr/bin/env bash
cp "$1" "$ISTEM_KAYIT" 2>/dev/null
printf '{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
EOF
chmod +x "$SAHTE"; export DENETCI_KOMUT="$SAHTE"
unset DENETCI_TAVAN DENETCI_MUTLAK DENETCI_ISTEM_TAVAN

# iş: 3 geçerli ölçüm + 16 geçersiz ilan (uzun nedenli) → mihenk'in küçük kopyası
NEDEN="kart daraltıldı: bu ölçüm artık dalda olmayan hat dosyalarını ölçüyordu; ölçüm sahibi yeniden ölçmedi, ilan geri alınmaz. $(printf 'ayrıntı %.0s' $(seq 1 30))"
is_kur() {  # $1 = iş adı
  local i; for i in 1 2 3; do bash "$K" olcum "$1" "gecerli$i" --asama tek -- echo "gecerli $i" >/dev/null 2>&1; done
  for i in $(seq 1 16); do
    bash "$K" olcum "$1" "bozuk$i" --asama tek -- echo "bozuk $i" >/dev/null 2>&1
    bash "$K" gecersiz "$1" "bozuk$i" --neden "$NEDEN" --kim SERDAR >/dev/null 2>&1
  done
}
is_kur is-m
KJ="$T/_agents/fabrika/kanit/is-m/KANIT.json"
[ -f "$KJ" ] && [ "$(python3 -c "import json;print(sum(1 for k in json.load(open('$KJ'))['kayitlar'] if k.get('tur')=='gecersiz'))")" -eq 16 ]; g $? "fikstür: 16 geçersiz ilan KANIT.json'da (gerçek kanit.sh ile)"
echo "     manifest (diskte, imzalı): $(wc -c < "$KJ") bayt"

kos() {  # $1 = denetci.sh yolu · $2 = kayıt dosyası · $3 = ek ortam
  rm -f "$T/_agents/fabrika/kanit/is-m/DENETIM-"*.json
  env ISTEM_KAYIT="$2" ${3:-} bash "$1" is-m --diff "$T/d.patch" >"$T/cikti.$$" 2>&1; echo $?
}
RC_E=$(kos "$ESKI" "$T/istem-eski.md"); RC_Y=$(kos "$D" "$T/istem-yeni.md")
[ "$RC_E" -eq 0 ] && [ "$RC_Y" -eq 0 ]; g $? "iki sürüm de koştu (rc eski=$RC_E yeni=$RC_Y)"
B_E=$(wc -c < "$T/istem-eski.md"); B_Y=$(wc -c < "$T/istem-yeni.md")
echo "     TAM İSTEM önce=$B_E sonra=$B_Y bayt (fark $((B_E - B_Y)))"
[ "$B_Y" -lt "$B_E" ]; g $? "yeni istem ESKİden küçük"
[ "$B_Y" -lt $((B_E * 7 / 10)) ]; g $? "yeni istem eskinin %70'inden küçük (geçersizlik şişkinliği gitti)"
[ "$(grep -c '^⛔ GEÇERSİZ' "$T/istem-yeni.md")" -eq 16 ]; g $? "yeni istemde 16 ilan = 16 tek satır (göz neyin ilan edildiğini hâlâ görüyor)"
for i in 1 2 3; do grep -q "gecerli$i" "$T/istem-yeni.md" || { g 1 "geçerli kayıt gecerli$i istemden DÜŞTÜ"; break; }; done; [ "$kalan" -eq 0 ] && g 0 "3 geçerli ölçüm yeni istemde tam"

# mihenk'in asıl vakası: tavan ESKİ istemin altında, YENİ istemin üstünde → eski İŞİ BÖL der, yeni geçer
TAVAN=$(( (B_E + B_Y) / 2 ))
RC_E2=$(kos "$ESKI" "$T/i2e.md" "DENETCI_ISTEM_TAVAN=$TAVAN"); RC_Y2=$(kos "$D" "$T/i2y.md" "DENETCI_ISTEM_TAVAN=$TAVAN")
echo "     tavan=$TAVAN: eski rc=$RC_E2 yeni rc=$RC_Y2"
[ "$RC_E2" -eq 1 ]; g $? "🔴 ESKİ sürüm bu tavanda İŞİ BÖL (rc=1): mihenk vakası yeniden üretildi"
[ "$RC_Y2" -eq 0 ]; g $? "🔴 YENİ sürüm aynı tavanda GEÇER (rc=0): geçersizlik ilanları artık tavanı doldurmuyor"
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
