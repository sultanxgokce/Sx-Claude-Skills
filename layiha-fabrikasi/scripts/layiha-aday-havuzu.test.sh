#!/usr/bin/env bash
# layiha-aday-havuzu.test.sh — layiha-aday-goc.sh + layiha-aday-havuzu.sh golden-testleri
# (dongu-sayac.test.sh deseni). Ağ'sız, izole: tüm yollar temp-dizine env-override — GERÇEK
# havuzu / GERÇEK defteri KİRLETMEZ. python3 tek-bağımlılık.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GOC="$HERE/layiha-aday-goc.sh"
AH="$HERE/layiha-aday-havuzu.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

pass=0; fail=0
check() { local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then pass=$((pass+1)); echo "PASS  $name"
  else fail=$((fail+1)); echo "FAIL  $name → want='$want' got='$got'"; fi
}
check_ne0() { local name="$1" got="$2"
  if [ "$got" != "0" ]; then pass=$((pass+1)); echo "PASS  $name (rc=$got)"
  else fail=$((fail+1)); echo "FAIL  $name → rc=0 beklenmiyordu"; fi
}
rc_of() { "$@" >/dev/null 2>&1; echo $?; }

# ── İzole test-ortamı: sahte kaynak (5 kayıt), sahte havuz, sahte layiha-defteri.sh ──
export LAYIHA_ADAY_HAVUZ="$T/havuz.jsonl"
export LAYIHA_ADAY_KAYNAK="$T/skorlar.json"
export LAYIHA_DEFTER="$T/defter.jsonl"
export LAYIHA_DEFTERI_BIN="$T/layiha-defteri.sh"

# sahte layiha-defteri.sh: gerçek script'in `ekle` alt-komutunu taklit eder (id-artışlı L-kod)
cat > "$LAYIHA_DEFTERI_BIN" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
CMD="${1:-}"; shift || true
[ "$CMD" = "ekle" ] || { echo "HATA: yalnız ekle destekleniyor (test-stub)" >&2; exit 2; }
SLUG=""; while [ $# -gt 0 ]; do case "$1" in --slug) SLUG="$2"; shift 2;; *) shift;; esac; done
[ -n "$SLUG" ] || { echo "HATA: --slug zorunlu" >&2; exit 2; }
N=1
if [ -f "$LAYIHA_DEFTER" ]; then N=$(( $(grep -c . "$LAYIHA_DEFTER" 2>/dev/null || echo 0) + 1 )); fi
KOD=$(printf "L%02d" "$N")
echo "{\"id\":\"$KOD\",\"slug\":\"$SLUG\"}" >> "$LAYIHA_DEFTER"
echo "OK: layiha $KOD eklendi ($SLUG)"
STUB
chmod +x "$LAYIHA_DEFTERI_BIN"

# sahte 00-SKORLAR.json (5 kayıt, farklı pct/sinif)
cat > "$LAYIHA_ADAY_KAYNAK" <<'JSON'
{
  "uretim": "test", "formul": "test", "toplam": 5,
  "kayitlar": [
    {"no":1,"slug":"aday-bir","baslik":"Aday Bir","sinif":"muhendislik","spekulatif":false,"pct":70,
     "skor":{"deger":7,"yapilabilirlik":7,"kanit_gucu":7,"uyum":7,"juri":1,"gerekce":"g1"},
     "goal":"goal1","kanit":"kanit1"},
    {"no":2,"slug":"aday-iki","baslik":"Aday İki","sinif":"sultan","spekulatif":false,"pct":90,
     "skor":{"deger":9,"yapilabilirlik":9,"kanit_gucu":9,"uyum":9,"juri":2,"gerekce":"g2"},
     "goal":"goal2","kanit":"kanit2"},
    {"no":3,"slug":"aday-uc","baslik":"Aday Üç","sinif":"urun","spekulatif":true,"pct":60,
     "skor":{"deger":6,"yapilabilirlik":6,"kanit_gucu":6,"uyum":6,"juri":0,"gerekce":"g3"},
     "goal":"goal3","kanit":"kanit3"},
    {"no":4,"slug":"aday-dort","baslik":"Aday Dört","sinif":"muhendislik","spekulatif":false,"pct":80,
     "skor":{"deger":8,"yapilabilirlik":8,"kanit_gucu":8,"uyum":8,"juri":1,"gerekce":"g4"},
     "goal":"goal4","kanit":"kanit4"},
    {"no":5,"slug":"aday-bes","baslik":"Aday Beş","sinif":"sultan","spekulatif":false,"pct":50,
     "skor":{"deger":5,"yapilabilirlik":5,"kanit_gucu":5,"uyum":5,"juri":0,"gerekce":"g5"},
     "goal":"goal5","kanit":"kanit5"}
  ]
}
JSON

# sahte taslak-layiha DESIGN dokümanları (5 adet, gerçek DESIGN dosya-yapısı)
mkdir -p "$T/repo/_agents/spec/taslak-layiha" "$T/repo/_agents/handoff"
for slug in aday-bir aday-iki aday-uc aday-dort aday-bes; do
  printf '> Statü: TASLAK-ADAY — SALT-ARAŞTIRMA, İNŞA-YOK, ONAY-BEKLİYOR\n\n# %s\n\nİçerik.\n' "$slug" \
    > "$T/repo/_agents/spec/taslak-layiha/${slug}-DESIGN.md"
done
# git-kökü test-ortamının kendisi olsun (root=$T/repo) — havuz/goc script'leri git rev-parse kullanıyor
git -C "$T/repo" init -q
git -C "$T/repo" add -A
git -C "$T/repo" -c user.email=t@t -c user.name=t commit -q -m init

run_in_repo() { ( cd "$T/repo" && "$@" ); }

# ── T1: göç idempotent (2x koşu → aynı sayı, 100→5 test-boyutunda) ──
check "T1 dry-run: 5 eklenecek" "0" "$(rc_of run_in_repo bash "$GOC")"
o1="$(run_in_repo bash "$GOC")"
check "T1 dry-run mesajı 5 eklenecek gösterir" "1" "$(echo "$o1" | grep -c 'eklenecek=5')"
run_in_repo bash "$GOC" --apply >/dev/null
n1="$(wc -l < "$LAYIHA_ADAY_HAVUZ" | tr -d ' ')"
check "T1 --apply sonrası havuzda 5 satır" "5" "$n1"
run_in_repo bash "$GOC" --apply >/dev/null
n2="$(wc -l < "$LAYIHA_ADAY_HAVUZ" | tr -d ' ')"
check "T1 2. --apply sonrası hâlâ 5 satır (idempotent)" "5" "$n2"

# ── T2: liste --top 3, pct azalan ──
o2="$(run_in_repo bash "$AH" liste --top 3 --porcelain)"
check "T2 top-3 tam 3 satır" "3" "$(echo "$o2" | grep -v '^#' | grep -c .)"
pct_sirali="$(echo "$o2" | grep -v '^#' | awk -F'\t' '{print $2}' | paste -sd, -)"
check "T2 pct azalan sırada" "90,80,70" "$pct_sirali"

# ── T3: terfi sonrası aday varsayılan liste'de yok, --hepsi'de var ──
id_iki="$(run_in_repo bash "$AH" liste --hepsi --porcelain | awk -F'\t' '$7=="aday-iki"{print $1}')"
check "T3 aday-iki id bulundu (A00x)" "1" "$([ -n "$id_iki" ] && echo 1 || echo 0)"
check "T3 terfi rc=0" "0" "$(rc_of run_in_repo bash "$AH" terfi "$id_iki" --sultan-onay --gerekce test-terfi)"
kalan_liste="$(run_in_repo bash "$AH" liste --porcelain)"
check "T3 terfi-edilen varsayılan listede yok" "0" "$(echo "$kalan_liste" | grep -c "aday-iki" || true)"
hepsi_liste="$(run_in_repo bash "$AH" liste --hepsi --porcelain)"
check "T3 terfi-edilen --hepsi'de var" "1" "$(echo "$hepsi_liste" | grep -c "aday-iki")"
check "T3 defterde yeni satır düştü" "1" "$(grep -c 'aday-iki' "$LAYIHA_DEFTER")"
check "T3 stub-doküman taşındı" "1" "$([ -f "$T/repo/_agents/spec/aday-iki-DESIGN.md" ] && echo 1 || echo 0)"
check "T3 taşınan dokümanda terfi-notu var" "1" "$(grep -c '> Terfi: aday' "$T/repo/_agents/spec/aday-iki-DESIGN.md")"
check "T3 taşınan dokümanın ilk-satırı SALT-ARAŞTIRMA statüsü" "1" \
  "$(head -1 "$T/repo/_agents/spec/aday-iki-DESIGN.md" | grep -c '> Statü: SALT-ARAŞTIRMA — İNŞA YOK')"

# ── T4: terfi-edilmişi tekrar terfi → exit 2 ──
check_ne0 "T4 zaten terfi-edilmişi tekrar terfi reddi" "$(rc_of run_in_repo bash "$AH" terfi "$id_iki" --sultan-onay)"

# ── T5: olmayan id → exit 2 ──
check_ne0 "T5 olmayan id terfi reddi" "$(rc_of run_in_repo bash "$AH" terfi A999 --sultan-onay)"

# ── T6: atomiklik — 2 adaydan biri geçersizken hiçbiri terfi etmemeli ──
id_bir="$(run_in_repo bash "$AH" liste --hepsi --porcelain | awk -F'\t' '$7=="aday-bir"{print $1}')"
defter_once="$(wc -l < "$LAYIHA_DEFTER" | tr -d ' ')"
check_ne0 "T6 geçerli+geçersiz karışık terfi tümden reddedilir" "$(rc_of run_in_repo bash "$AH" terfi "$id_bir" A999)"
defter_sonra="$(wc -l < "$LAYIHA_DEFTER" | tr -d ' ')"
check "T6 defter satır-sayısı değişmedi (hiçbiri uygulanmadı)" "$defter_once" "$defter_sonra"
durum_bir="$(run_in_repo bash "$AH" liste --hepsi --porcelain | awk -F'\t' -v id="$id_bir" '$1==id{print $4}')"
check "T6 aday-bir hâlâ durum=aday" "aday" "$durum_bir"
check "T6 aday-bir dokümanı hâlâ eski konumda (taşınmadı)" "1" \
  "$([ -f "$T/repo/_agents/spec/taslak-layiha/aday-bir-DESIGN.md" ] && echo 1 || echo 0)"

# ── T7: durum özeti sayaçları tutarlı ──
o7="$(run_in_repo bash "$AH" durum)"
check "T7 durum'da terfi-edildi=1" "1" "$(echo "$o7" | grep 'terfi-edildi' | awk '{print $2}')"
check "T7 durum'da aday=4" "4" "$(echo "$o7" | grep -E '^\s*aday\s' | awk '{print $2}')"

# ── T8: --min-pct + --sinif filtresi ──
o8="$(run_in_repo bash "$AH" liste --sinif muhendislik --porcelain | grep -v '^#')"
check "T8 sinif=muhendislik yalnız 2 kayıt (aday-bir,aday-dort)" "2" "$(echo "$o8" | grep -c .)"
o9="$(run_in_repo bash "$AH" liste --min-pct 75 --porcelain | grep -v '^#')"
check "T8 min-pct=75 yalnız aday-dort (pct=80, aday-iki zaten terfi-edildi)" "1" "$(echo "$o9" | grep -c .)"

# ── T9: goster ──
o10="$(run_in_repo bash "$AH" goster aday-uc)"
check "T9 goster başlık içerir" "1" "$(echo "$o10" | grep -c 'Aday Üç')"
check_ne0 "T9 olmayan slug goster reddi" "$(rc_of run_in_repo bash "$AH" goster yok-boyle-bir-slug)"

# ── T10: SULTAN KİLİDİ — onaysız terfi reddedilir, aday DEĞİŞMEZ ──
id_uc="$(run_in_repo bash "$AH" liste --hepsi --porcelain | awk -F'\t' '$7=="aday-uc"{print $1}')"
onceki="$(run_in_repo bash "$AH" liste --hepsi 2>/dev/null | grep -c "aday-uc" || true)"
check_ne0 "T10 --sultan-onay olmadan terfi reddi" "$(rc_of run_in_repo bash "$AH" terfi "$id_uc")"
err="$(run_in_repo bash "$AH" terfi "$id_uc" 2>&1 >/dev/null || true)"
check "T10b ret gerekçesi Sultan-onayına atıf yapar" "1" "$(echo "$err" | grep -ci "sultan-onay" || true)"
check "T10c reddedilen terfi adayı DEĞİŞTİRMEDİ" "$onceki" "$(run_in_repo bash "$AH" liste --hepsi 2>/dev/null | grep -c "aday-uc" || true)"

# ── T11: ekle — tek-kayıt ekleme (K3) ────────────────────────────────────────────────────────
once_ekle="$(wc -l < "$LAYIHA_ADAY_HAVUZ" | tr -d ' ')"
yeni_id="$(run_in_repo bash "$AH" ekle "Gunluk yedek raporu otomatik gelsin" --kaynak oto-yakalama 2>/dev/null)"
check "T11 ekle yeni A-id basar" "1" "$(echo "$yeni_id" | grep -c '^A[0-9][0-9][0-9]$')"
sonra_ekle="$(wc -l < "$LAYIHA_ADAY_HAVUZ" | tr -d ' ')"
check "T11 havuz bir satır büyüdü" "$((once_ekle + 1))" "$sonra_ekle"
check "T11 kayıt durum=aday" "aday" \
  "$(run_in_repo bash "$AH" liste --hepsi --porcelain | awk -F'\t' -v id="$yeni_id" '$1==id{print $4}')"
check "T11 kaynak alanı oto-yakalama" "oto-yakalama" \
  "$(python3 -c "import json,sys;print([json.loads(l)['kaynak'] for l in open(sys.argv[1]) if l.strip() and json.loads(l)['id']==sys.argv[2]][0])" "$LAYIHA_ADAY_HAVUZ" "$yeni_id")"
check "T11 havuzun her satırı geçerli JSON (atomik yazma bozmadı)" "0" \
  "$(python3 -c "import json,sys;[json.loads(l) for l in open(sys.argv[1]) if l.strip()];print(0)" "$LAYIHA_ADAY_HAVUZ" 2>/dev/null || echo 1)"
check "T11 önceki kayıtlar korundu (aday-bir hâlâ havuzda)" "1" \
  "$(run_in_repo bash "$AH" liste --hepsi --porcelain | grep -c 'aday-bir')"

# ── T12: ekle dedup — aynı/çok-benzer metin ikinci kez YAZILMAZ, RC=0 ──
check "T12 dedup rc=0 (sessiz atlama)" "0" \
  "$(rc_of run_in_repo bash "$AH" ekle "Bugun sunu dedim: Gunluk yedek raporu otomatik gelsin" --kaynak oto-yakalama)"
check "T12 dedup sonrası havuz büyümedi" "$sonra_ekle" "$(wc -l < "$LAYIHA_ADAY_HAVUZ" | tr -d ' ')"
check "T12 dedup stdout'a id BASMAZ" "0" \
  "$(run_in_repo bash "$AH" ekle "Gunluk yedek raporu otomatik gelsin" 2>/dev/null | grep -c '^A[0-9]')"

# ── T13: boş metin reddi + geçersiz sınıf reddi ──
check_ne0 "T13 metinsiz ekle reddi" "$(rc_of run_in_repo bash "$AH" ekle --kaynak oto-yakalama)"
check_ne0 "T13 geçersiz --sinif reddi" "$(rc_of run_in_repo bash "$AH" ekle "sinif testi metni" --sinif saka)"

# ── T14: NEGATİF — git-siz dizinde RC=2 ve ORTAK dizine ($HOME/.claude) dosya OLUŞMAZ ──
# (İ1: /config/.claude 10 container'ın ortak fiziksel dizini; oraya düşen havuz geri-alınamaz sızıntıdır.)
GITSIZ="$T/gitsiz"; FAKEHOME="$T/fakehome"
mkdir -p "$GITSIZ" "$FAKEHOME/.claude"
rc14="$( cd "$GITSIZ" && env -u LAYIHA_ADAY_HAVUZ -u HAT_ROOT HOME="$FAKEHOME" \
         bash "$AH" ekle "gitsiz dizin sizma testi" --kaynak oto-yakalama >/dev/null 2>&1; echo $? )"
check "T14 git-siz dizinde rc=2" "2" "$rc14"
check "T14 ortak dizine ($HOME/.claude) HİÇBİR dosya yazılmadı" "0" \
  "$(find "$FAKEHOME/.claude" -type f 2>/dev/null | wc -l | tr -d ' ')"
check "T14 git-siz dizinde de dosya oluşmadı" "0" "$(find "$GITSIZ" -type f 2>/dev/null | wc -l | tr -d ' ')"

# ── T15: ekle'den sonra terfi zinciri hâlâ çalışıyor (mevcut komutlar bozulmadı) ──
id_bes="$(run_in_repo bash "$AH" liste --hepsi --porcelain | awk -F'\t' '$7=="aday-bes"{print $1}')"
check "T15 ekle sonrası mevcut adayın terfisi rc=0" "0" \
  "$(rc_of run_in_repo bash "$AH" terfi "$id_bes" --sultan-onay --gerekce t15)"

echo
total=$((pass + fail))
echo "TOPLAM: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
