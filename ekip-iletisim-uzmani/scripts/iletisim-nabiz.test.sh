#!/usr/bin/env bash
# iletisim-nabiz sınavı — AĞSIZ, fixture'lı. Beş sınıf + üç durum + "emir vermez" (salt-oku) sözleşmesi.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  ✓ %s\n' "$1";
        else K=$((K+1)); printf '  ✗ %s\n     beklenen: %s\n     görülen : %s\n' "$1" "$2" "$3"; fi; }
TMP="$(mktemp -d)"; trap 'find "$TMP" -type f -delete 2>/dev/null; find "$TMP" -depth -type d -empty -delete 2>/dev/null' EXIT
R="$TMP/kutu"; mkdir -p "$R/_agents/handoff" "$R/_agents/durum"
SIMDI=1789560000   # sabit "şimdi" (epoch); fixture zamanları buna göre
ts(){ date -d "@$1" -Is; }   # epoch → ISO (yerel)

cat > "$R/_agents/handoff/ekip-registry.yaml" <<'Y'
uyeler:
  - id: REIS
  - id: KATIP
  - id: SESSIZ
  - id: BESIR
Y
{
  # kayıp tetik: REIS→KATIP engellendi (2 sa önce)
  echo "a1|$(ts $((SIMDI-7200)))|ping|REIS|KATIP|engellendi|is ver"
  echo "a2|$(ts $((SIMDI-7000)))|ping|REIS|KATIP|dogrulanamadi|is ver"
  # ACK'siz: REIS→BESIR iletildi 3 sa önce, ack yok
  echo "b1|$(ts $((SIMDI-10800)))|ping|REIS|BESIR|iletildi|is ver"
  # ACK'lı: REIS→REIS-e yok; KATIP'e iletildi + KATIP ack'ledi
  echo "c1|$(ts $((SIMDI-5000)))|ping|REIS|KATIP|iletildi|is ver"
  echo "c2|$(ts $((SIMDI-4900)))|ack|KATIP|REIS|tuketildi|aldim"
  # taze ping (5 dk önce) — süre dolmadı, ACK'siz SAYILMAZ
  echo "d1|$(ts $((SIMDI-300)))|ping|REIS|BESIR|iletildi|is ver"
  # eski (3 gün) engellendi — pencere dışı
  echo "e1|$(ts $((SIMDI-259200)))|ping|REIS|SESSIZ|engellendi|eski"
} > "$R/_agents/handoff/ekip-sinyal.log"
# durum dosyaları: BESIR 3 gündür aynı iş (bayat); KATIP taze; SESSIZ'in dosyası YOK
python3 - "$R" "$SIMDI" <<'PY'
import json, sys, os, datetime
R, S = sys.argv[1], int(sys.argv[2])
def iso(e): return datetime.datetime.fromtimestamp(e).isoformat()
d=os.path.join(R,"_agents","durum")
json.dump({"simdi":{"is":"rapor v1","baslangic":iso(S-3*86400)}, "bekliyor":[{"kimden":"REIS","ne":"onay"}]}, open(f"{d}/BESIR.json","w"))
json.dump({"simdi":{"is":"form","baslangic":iso(S-3600)}, "bekliyor":[{"kimden":"REIS","ne":"onay"}]}, open(f"{d}/KATIP.json","w"))
json.dump({"simdi":{"is":"yon","baslangic":iso(S-600)}, "bekliyor":[{"kimden":"REIS","ne":"karar"}]}, open(f"{d}/REIS.json","w"))
os.utime(f"{d}/BESIR.json",(S-3*86400,S-3*86400)); os.utime(f"{d}/KATIP.json",(S-3600,S-3600)); os.utime(f"{d}/REIS.json",(S-600,S-600))
PY

kos(){ ( cd "$R" && NABIZ_SIMDI="$SIMDI" bash "$KOK/iletisim-nabiz.sh" --porcelain "$@" ); }
J="$(kos)"; RC=$?
sinif(){ printf '%s' "$J" | python3 -c "import json,sys;d=json.load(sys.stdin);print(sorted(b['kim'] for b in d['bulgular'] if b['sinif']=='$1'))"; }

kapi "N1 kayıp tetik: KATIP'e engellendi+doğrulanamadı yakalanır; 3 günlük eski pencere dışı" "['KATIP']" "$(sinif kayip-tetik)"
kapi "N2 ACK'siz tetik: BESIR (3 sa cevapsız) yakalanır; KATIP ack'ledi" "['BESIR']" "$(sinif acksiz-tetik)"
kapi "N2b taze ping (5 dk) ACK'siz SAYILMAZ — BESIR için yalnız 1 tetik" "1" \
  "$(printf '%s' "$J" | python3 -c "import json,sys,re;d=json.load(sys.stdin);k=[b['kanit'] for b in d['bulgular'] if b['sinif']=='acksiz-tetik' and b['kim']=='BESIR'][0];print(re.match(r'(\\d+) tetik',k).group(1))")"
# BESIR de sessizdir: 3 gündür ne sinyal göndermiş ne durum yazmış (bayat iş ⊂ sessizlik) — iki sınıf birden meşru.
kapi "N3 sessiz üye: SESSIZ (hiç iz yok) ve BESIR (3 gündür iz yok) yakalanır; KATIP/REIS taze" "['BESIR', 'SESSIZ']" "$(sinif sessiz-uye)"
kapi "N4 bayat iş: BESIR (3 gündür aynı iş, dosya değişmemiş)" "['BESIR']" "$(sinif bayat-is)"
kapi "N5 yönetim darboğazı: 3 üye REIS'ten bekliyor → REIS" "['REIS']" "$(sinif yonetim-darbogazi)"
kapi "N6 kırmızı bulgu varken çıkış 1" "1" "$RC"
kapi "N7 ölçülen beş eksen listelenir" "5" "$(printf '%s' "$J" | python3 -c "import json,sys;print(len(json.load(sys.stdin)['olculen']))")"

# üç durum: sinyal defteri YOKSA kayıp/acksiz ÖLÇÜLEMEDİ, temiz DEĞİL
mv "$R/_agents/handoff/ekip-sinyal.log" "$TMP/yedek.log"
J2="$(kos)"
kapi "N8 sinyal defteri yokken kayıp/acksiz eksenleri ÖLÇÜLEMEDİ diye yazılır" "2" \
  "$(printf '%s' "$J2" | python3 -c "import json,sys;d=json.load(sys.stdin);print(sum(1 for x in d['olculemeyen'] if 'tetik' in x))")"
mv "$TMP/yedek.log" "$R/_agents/handoff/ekip-sinyal.log"

# hiçbir kaynak yoksa çıkış 3 (kapı yeşil DEĞİL)
B="$TMP/bos"; mkdir -p "$B"; ( cd "$B" && NABIZ_SIMDI="$SIMDI" bash "$KOK/iletisim-nabiz.sh" --repo "$B" --porcelain >/dev/null 2>&1 ); kapi "N9 kaynak yoksa çıkış 3 (ölçülemedi ≠ temiz)" "3" "$?"

# salt-oku: koşum kutu dosyalarını DEĞİŞTİRMEZ
ONCE="$(find "$R" -type f -exec md5sum {} + | sort | md5sum)"; kos >/dev/null; SONRA="$(find "$R" -type f -exec md5sum {} + | sort | md5sum)"
kapi "N10 araç salt-oku: hiçbir kutu dosyası değişmez" "$ONCE" "$SONRA"

# damga: çekirdek değişince damga değişir
D1="$(bash "$KOK/miras-damga.sh")"; kapi "N11 damga sürüm+sha basar" "1" "$(printf '%s' "$D1" | grep -cE '^ekip-iletisim-uzmani@[0-9.]+ sha=[0-9a-f]{12}$')"

printf '\ngeçti=%s · kaldı=%s\n' "$G" "$K"
[ "$K" -eq 0 ]
