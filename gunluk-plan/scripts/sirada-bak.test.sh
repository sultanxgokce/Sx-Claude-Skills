#!/usr/bin/env bash
# sirada-bak.sh + kutu-bul.sh sınavı — Sırada eşiği, başlama, ölçülemeyen durum, kutu türetme (menzil hatası).
# Hermetik: gerçek deftere GİTMEZ; sahte gorev.sh (liste + ustlen kaydı).
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SB="${SIRADA_BAK:-$KOK/sirada-bak.sh}"; KB="${KUTU_BUL:-$KOK/kutu-bul.sh}"; DY="${DEFTERE_YAZ:-$KOK/deftere-yaz.sh}"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
iceriyor(){ case "$3" in *"$2"*) gecen=$((gecen+1)); echo "  ✓ $1" ;; *) kalan=$((kalan+1)); echo "  ✗ $1 — '$2' yok: $3" ;; esac; }
icermiyor(){ case "$3" in *"$2"*) kalan=$((kalan+1)); echo "  ✗ $1 — '$2' OLMAMALI: $3" ;; *) gecen=$((gecen+1)); echo "  ✓ $1" ;; esac; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
export GUNLUK_PLAN_AJAN="MENZILCI" GUNLUK_PLAN_TARIH="2026-01-02" GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_CIPA_SH="$KOK/cipa.sh"
export GUNLUK_PLAN_ESLEME="$T/esleme.tsv"; printf "# yorum\nMOBILYACI\tNECCAR\n" > "$T/esleme.tsv"; KC="${KIMLIK_COZ:-$KOK/kimlik-coz.sh}"
export DEFTER_JETON_YOL="$T/jeton-yok" DEFTER_UC="http://127.0.0.1:9"
unset GUNLUK_PLAN_KUTU
cat > "$T/gorev.sh" <<'EOS'
#!/usr/bin/env bash
T="$(dirname "${BASH_SOURCE[0]}")"
case "$1" in
  liste) [ "${LISTE_RC:-0}" -eq 0 ] || exit "$LISTE_RC"; cat "$T/liste.txt" ;;
  ustlen) printf '%s\n' "$*" >> "$T/ustlen.log"; [ "${USTLEN_RC:-0}" -eq 0 ] || exit "$USTLEN_RC" ;;
  *) printf '%s\n' "$*" >> "$T/baska.log" ;;
esac
EOS
chmod +x "$T/gorev.sh"; export GUNLUK_PLAN_GOREV_SH="$T/gorev.sh"
# satır biçimi: id kutu durum aciliyet etiket atanan BAŞLIK  (son: …)
satir(){ printf 'gorev_%s  %-10s %-14s %-9s %-8s %-10s %s  (son: 2026-01-01)\n' "$@"; }
liste_menzil(){ : > "$T/liste.txt"
  for i in 1 2 3 4 5 6; do satir "C$i" code acik esnek ozellik MUAVİN "code işi $i" >> "$T/liste.txt"; done      # kalabalık kutu: en sık kutu = code
  satir M1 menzil acik esnek ozellik MENZILCI "menzil işi A" >> "$T/liste.txt"
  satir M2 menzil acik acil ozellik MENZILCI "menzil işi B (acil)" >> "$T/liste.txt"
  satir M3 menzil sira-bende esnek ozellik - "menzil işi C" >> "$T/liste.txt"
  satir M4 menzil havuz esnek ozellik - "havuz sayılmaz" >> "$T/liste.txt"
  satir M5 menzil calisiliyor esnek ozellik MENZILCI "çalışılan sayılmaz" >> "$T/liste.txt"
  satir M6 menzil bitti esnek ozellik MENZILCI "biten sayılmaz" >> "$T/liste.txt"; }
echo "— kutu-bul"
liste_menzil
kapi "K1 menzil koltuğu kutuyu 'menzil' bulur (en sık sütun 'code' olsa da)" "menzil" "$(bash "$KB" 2>/dev/null)"
kapi "K2 başka koltuk kendi kutusunu bulur (MUAVIN→code, İ/I farkı yok sayılır)" "code" "$(bash "$KB" --kim MUAVIN 2>/dev/null)"
bash "$KB" --kim YOKBOYLEBIRI >/dev/null 2>&1; kapi "K3 atanmış işi olmayan koltuk: rc 3, kutu UYDURULMAZ" "3" "$?"
: > "$T/l2.txt"; satir X1 a acik esnek o MENZILCI x >> "$T/l2.txt"; satir X2 b acik esnek o MENZILCI y >> "$T/l2.txt"
bash "$KB" --liste "$T/l2.txt" >/dev/null 2>&1; kapi "K4 iki kutu eşit sayıda: tahmin yok, rc 3" "3" "$?"
kapi "K5 GUNLUK_PLAN_KUTU açık ayarı kazanır" "huma" "$(GUNLUK_PLAN_KUTU=huma bash "$KB" 2>/dev/null)"
LISTE_RC=7 bash "$KB" >/dev/null 2>&1; kapi "K6 liste okunamazsa rc 3" "3" "$?"
echo "— sirada-bak"
liste_menzil; rm -f "$T/ustlen.log"
c="$(bash "$SB" 2>&1)"; rc=$?
kapi "S1 menzil: Sırada=3 (acik+sira-bende; havuz/çalışılan/biten ve code işleri SAYILMAZ) rc 0" "0:SIRADA=3" "$rc:$(printf '%s\n' "$c" | grep '^SIRADA=')"
iceriyor "S2 eşik 3 ve 3 iş → KARAR=BAS" "KARAR=BAS" "$c"
kapi "S3 acil iş listede ilk sırada" "ISI=gorev_M2" "$(printf '%s\n' "$c" | grep '^ISI=' | head -1 | cut -d' ' -f1)"
kapi "S4 VARSAYILAN koşuda en üstteki iş ustlen edilir (talep: başlasın)" "ustlen gorev_M2 --kim MENZILCI --tahmin 30" "$(cat "$T/ustlen.log" 2>/dev/null)"
rm -f "$T/ustlen.log"; c0="$(bash "$SB" --bak 2>&1)"
kapi "S4b --bak: ustlen ÇAĞRILMAZ ve çıktı 'başladım' DEMEZ (gerçeğe aykırı beyan yok)" "yok:0" "$([ -e "$T/ustlen.log" ] && echo var || echo yok):$(printf '%s' "$c0" | grep -c 'ile başladım')"
iceriyor "S5 öneri bugüne almanın SULTAN'ın olduğunu söyler" "tıkı Sultan'ın" "$c"
iceriyor "S5b varsayılan koşuda BASLADI satırı var" "BASLADI=gorev_M2" "$c"
iceriyor "S5c --bak önerisi üstlenmenin ajanın işi olduğunu söyler (izin beklemez)" "izin beklemez" "$c0"
iceriyor "S5d --bak önerisi üstlen komutunu gösterir" "gorev.sh ustlen gorev_M2" "$c0"
kapi "S5e --bak önerisi izin soran 'alayım mı' kalıbını İÇERMEZ" "0" "$(printf '%s' "$c0" | grep -c 'alayım mı')"
rm -f "$T/ustlen.log"; bash "$SB" --basla >/dev/null 2>&1; kapi "S6 eski --basla bayrağı artık TANINMAZ (rc 2, ustlen yok)" "2:yok" "$?:$([ -e "$T/ustlen.log" ] && echo var || echo yok)"
icermiyor "S7 betik bugun_plani'na ASLA yazmaz (ustlen dışında çağrı yok)" "bugun" "$(cat "$T/baska.log" "$T/ustlen.log" 2>/dev/null)"
grep -v "gorev_M4" "$T/liste.txt" > "$T/liste.tmp"; mv "$T/liste.tmp" "$T/liste.txt"   # S8–S10: havuzsuz kutu (havuz artık iştir: H bölümü)
c="$(bash "$SB" --esik 4 2>&1)"; iceriyor "S8 eşik 4 ve 3 iş → KARAR=SOR" "KARAR=SOR" "$c"
iceriyor "S9 SOR iki şık verir" "SIKLAR=Sultan'la sohbet ederek|Reis kendi başına" "$c"
iceriyor "S9b SOR: ADIM 0-d tarama ZORUNLU satırı var, Sultan'ı beklemez (HC75A)" "ZORUNLU=ADIM 0-d tarama: Sultan'ın cevabını BEKLEMEDEN" "$c"
iceriyor "S9c ZORUNLU satırı tarama-ekle.sh'ı gösterir ve ölçüt bayraklarını taşır (kaynak + kanıt zorunlu kalır)" "tarama-ekle.sh --baslik" "$c"
iceriyor "S9d günlük tavan söylenir (günde en çok 3, tavan değişmedi)" "günde en çok 3" "$c"
icermiyor "S9e BAS kararında ZORUNLU satırı YOK (sıra doluyken taranmaz)" "ZORUNLU=" "$(bash "$SB" --bak 2>&1)"
rm -f "$T/ustlen.log"; bash "$SB" --esik 4 >/dev/null 2>&1; kapi "S10 SOR iken varsayılanda bile ustlen ÇAĞIRMAZ" "yok" "$([ -e "$T/ustlen.log" ] && echo var || echo yok)"
: > "$T/liste.txt"; satir M1 menzil acik esnek o MENZILCI "tek iş" >> "$T/liste.txt"
c="$(bash "$SB" 2>&1)"; iceriyor "S11 Sırada 1 → SOR" "KARAR=SOR" "$c"
icermiyor "S11b Sırada 1 iken 'planlanmış görev yok' DENMEZ (kendi sayımıyla çelişmez)" "planlanmış görev yok" "$c"
iceriyor "S11c Sırada 1 iken gerçek sayı ve eşik söylenir" "sırada yalnız 1 iş var (başlamak için en az 3 gerek)" "$c"
satir Z1 code bitti esnek o MUAVİN "tek" > "$T/liste.txt"; c="$(bash "$SB" --kutu menzil 2>&1)"; iceriyor "S12 --kutu verilince boş kutu: SIRADA=0 → SOR" "SIRADA=0" "$c"
iceriyor "S12b Sırada 0 iken 'planlanmış görev yok' denir" "planlanmış görev yok" "$c"
liste_menzil; LISTE_RC=5 bash "$SB" >/dev/null 2>&1; kapi "S13 liste okunamazsa rc 3 ('Sırada 0' DENMEZ)" "3" "$?"
out="$(LISTE_RC=5 bash "$SB" 2>&1)"; icermiyor "S14 ölçülemeyende KARAR satırı basılmaz" "KARAR=" "$out"
bash "$SB" --esik abc >/dev/null 2>&1; kapi "S15 bozuk eşik rc 2" "2" "$?"
bash "$SB" --esik 0 >/dev/null 2>&1; kapi "S16 eşik 0 rc 2" "2" "$?"
USTLEN_RC=1 bash "$SB" >/dev/null 2>&1; kapi "S17 ustlen reddedilirse rc 1 (sessiz başarı yok)" "1" "$?"
GUNLUK_PLAN_AJAN="" AGENT_NAME="" bash "$SB" --kutu menzil >/dev/null 2>&1; kapi "S18 kim yokken başlatma rc 3" "3" "$?"
echo "— başkasının işi üstlenilmez (kutu-düzeyi sayım ≠ koltuk-düzeyi başlatma)"
liste_menzil; satir M0 menzil acik cok-acil ozellik SERDAR "serdarın işi (en acil, en üstte)" >> "$T/liste.txt"; rm -f "$T/ustlen.log"
c="$(bash "$SB" 2>&1)"; rc=$?
kapi "S19 en üstteki iş BAŞKASINA atanmış: onu ÜSTLENMEZ, bana atanmış ilk işi üstlenir" "ustlen gorev_M2 --kim MENZILCI --tahmin 30" "$(cat "$T/ustlen.log" 2>/dev/null)"
iceriyor "S19b sayım yine kutu-düzeyinde (4 iş) ve karar BAS" "SIRADA=4" "$c"
: > "$T/liste.txt"; for i in 1 2 3; do satir "Y$i" menzil acik esnek ozellik SERDAR "serdarın işi $i" >> "$T/liste.txt"; done; rm -f "$T/ustlen.log"
c="$(bash "$SB" --kutu menzil 2>&1)"; rc=$?
kapi "S20 3 iş de başkasına atanmış: ustlen ÇAĞRILMAZ, rc 0" "yok:0" "$([ -e "$T/ustlen.log" ] && echo var || echo yok):$rc"
iceriyor "S20b 'başkasının işi üstlenilmez' açıkça söylenir" "BASLAMADI=yok" "$c"
satir Y4 menzil acik esnek ozellik - "sahipsiz iş" >> "$T/liste.txt"; rm -f "$T/ustlen.log"; bash "$SB" --kutu menzil >/dev/null 2>&1
kapi "S21 sahipsiz ('-') iş başlatma adayıdır" "ustlen gorev_Y4 --kim MENZILCI --tahmin 30" "$(cat "$T/ustlen.log" 2>/dev/null)"
echo "— deftere-yaz kutu türetme (menzil hatası)"
liste_menzil; rm -r -- "$T/cipa" 2>/dev/null; bash "$KOK/cipa.sh" yaz --plan "1) ilk madde | 2) ikinci madde" >/dev/null 2>&1
d="$(bash "$DY" 2>&1)"; iceriyor "D1 --kutu verilmeden menzil koltuğu 'kutu=menzil' çıkar (code DEĞİL)" "kutu=menzil" "$d"
icermiyor "D2 'kutu=code' çıkmaz" "kutu=code" "$d"
d="$(GUNLUK_PLAN_AJAN=YOKBOYLE bash "$DY" 2>&1)"; rc=$?; kapi "D3 atanmışı olmayan koltuk --kutu'suz rc 3" "3" "$rc"
echo "— koltuk eşleme (kimlik-coz)"
kapi "Q1 tablodaki koltuk defter adına çevrilir" "NECCAR" "$(bash "$KC" MOBILYACI 2>&1)"
kapi "Q2 İ/I/ı katlı eşleşir (MOBİLYACI)" "NECCAR" "$(bash "$KC" MOBİLYACI 2>&1)"
kapi "Q3 tabloda olmayan ad AYNEN döner" "MUAVİN" "$(bash "$KC" MUAVİN 2>&1)"
kapi "Q4 tablo yoksa ad AYNEN döner" "MOBILYACI" "$(GUNLUK_PLAN_ESLEME="$T/yok.tsv" bash "$KC" MOBILYACI 2>&1)"
printf 'X\tA\nX\tB\n' > "$T/celis.tsv"; GUNLUK_PLAN_ESLEME="$T/celis.tsv" bash "$KC" X >/dev/null 2>&1; kapi "Q5 aynı koltuk iki ada giderse rc 3 (tahmin yok)" "3" "$?"
printf 'bozuk satir sekmesiz\nY\tZ\n' > "$T/bozuk.tsv"; q="$(GUNLUK_PLAN_ESLEME="$T/bozuk.tsv" bash "$KC" Y 2>&1)"
iceriyor "Q6 bozuk satır atlanır ve söylenir" "satır 1 bozuk" "$q"; iceriyor "Q6b sağlam satır yine çalışır" "Z" "$q"
: > "$T/l3.txt"; for i in 1 2 3; do satir N$i mihenk acik esnek o NECCAR "mihenk işi $i" >> "$T/l3.txt"; done
kapi "Q7 kutu-bul: koltuk adıyla (MOBILYACI) NECCAR'ın kutusunu bulur" "mihenk" "$(bash "$KB" --kim MOBILYACI --liste "$T/l3.txt" 2>/dev/null)"
kapi "Q7b tablo yokken aynı çağrı ÖLÇEMEZ (rc 3) — kapı çeviriden geliyor" "3" "$(GUNLUK_PLAN_ESLEME="$T/yok.tsv" bash "$KB" --kim MOBILYACI --liste "$T/l3.txt" >/dev/null 2>&1; echo $?)"
cp "$T/l3.txt" "$T/liste.txt"; rm -f "$T/ustlen.log"; GUNLUK_PLAN_AJAN=MOBILYACI bash "$SB" >/dev/null 2>&1
kapi "Q8 sirada-bak: ustlen DEFTER adıyla çağrılır (--kim NECCAR)" "ustlen gorev_N1 --kim NECCAR --tahmin 30" "$(cat "$T/ustlen.log" 2>/dev/null)"
liste_menzil
cp "$T/l3.txt" "$T/liste.txt"; rm -r -- "$T/cipa" 2>/dev/null; GUNLUK_PLAN_AJAN=MOBILYACI bash "$KOK/cipa.sh" yaz --plan "1) ilk madde | 2) ikinci madde" >/dev/null 2>&1
d="$(GUNLUK_PLAN_AJAN=MOBILYACI bash "$DY" 2>&1)"; iceriyor "Q9 deftere-yaz: koltuk adı çevrilir, kutu=mihenk" "kutu=mihenk" "$d"
iceriyor "Q9b deftere-yaz: defter kaydı DEFTER adıyla yazılır (kim=NECCAR)" "kim=NECCAR" "$d"
printf 'ZA\tZB\nZB\tZC\n' > "$T/zincir.tsv"; : > "$T/liste.txt"; for i in 1 2 3; do satir X$i kutux acik esnek o ZB "ZB işi $i" >> "$T/liste.txt"; satir Y$i kutuy acik esnek o ZC "ZC işi $i" >> "$T/liste.txt"; done
rm -f "$T/ustlen.log"; zc="$(GUNLUK_PLAN_ESLEME="$T/zincir.tsv" GUNLUK_PLAN_AJAN=ZA bash "$SB" 2>&1)"
iceriyor "Q10 zincirli tabloda TEK geçiş: ZA→ZB (ZC'ye varmaz), kutu=kutux" "KUTU=kutux" "$zc"
kapi "Q10b ustlen ZB adıyla çağrılır (ZC DEĞİL)" "ustlen gorev_X1 --kim ZB --tahmin 30" "$(cat "$T/ustlen.log" 2>/dev/null)"
rm -r -- "$T/cipa" 2>/dev/null; GUNLUK_PLAN_AJAN=ZA bash "$KOK/cipa.sh" yaz --plan "1) ilk madde | 2) ikinci madde" >/dev/null 2>&1; kapi "Q10c deftere-yaz da tek geçiş: kutu=kutux kim=ZB" "1" "$(GUNLUK_PLAN_ESLEME="$T/zincir.tsv" GUNLUK_PLAN_AJAN=ZA bash "$DY" 2>&1 | grep -c 'kutu=kutux kim=ZB')"
# Q11-Q13: ü ö ç ş ğ katı — koltuk MUTEVELLI, defterde MÜTEVELLİ (akar kutusu, MÜTEVELLİ 28 Eki 2026 ölçümü)
: > "$T/liste.txt"; for i in 1 2 3; do satir A$i akar acik esnek o MÜTEVELLİ "akar işi $i" >> "$T/liste.txt"; done
kapi "Q11 kutu-bul: ASCII koltuk (MUTEVELLI) aksanlı defter adını (MÜTEVELLİ) bulur" "akar" "$(bash "$KB" --kim MUTEVELLI --liste "$T/liste.txt" 2>/dev/null)"
rm -f "$T/ustlen.log"; q12="$(GUNLUK_PLAN_ESLEME="$T/yok.tsv" GUNLUK_PLAN_AJAN=MUTEVELLI bash "$SB" 2>&1)"
iceriyor "Q12 sirada-bak: tablosuz bile MÜTEVELLİ işleri koltuğa atanmış sayılır (BASLAMADI=yok DEĞİL)" "KUTU=akar" "$q12"
icermiyor "Q12b 'bana atanmış ya da sahipsiz iş yok' çıkmaz" "bana atanmış ya da sahipsiz iş yok" "$q12"
kapi "Q13 kimlik-coz: ü ö ç ş ğ katlı eşleşir (tablo satırı MUTEVELLİ koltuğu → MÜTEVELLİ)" "MÜTEVELLİ" "$(printf 'MÜTEVELLİ\tMÜTEVELLİ\n' > "$T/e2.tsv"; GUNLUK_PLAN_ESLEME="$T/e2.tsv" bash "$KC" MUTEVELLI 2>&1)"
echo
echo "— havuz da iştir (1.14.0 · SERDAR 29 Eki)"
liste_menzil; rm -f "$T/ustlen.log"
c="$(bash "$SB" --esik 4 2>&1)"
iceriyor "H1 Sırada 3 < eşik 4 ama sahipsiz HAVUZ işi var → KARAR=BAS (Sultan'a 'iş çıkaralım mı' SORULMAZ)" "KARAR=BAS" "$c"
iceriyor "H1b NEDEN satırı 'havuz da iştir' der" "havuz da iştir" "$c"
iceriyor "H1c HAVUZDA=1 ayrı sayılır, SIRADA=3 değişmez (ekranın tanımı)" "HAVUZDA=1" "$c"
iceriyor "H1d SIRADA hâlâ 3" "SIRADA=3" "$c"
icermiyor "H1e BAS kararında SOR/ZORUNLU yok" "ZORUNLU=" "$c"
kapi "H1f ilk aday sıradaki acil iş (sıra önce, havuz sonra)" "ustlen gorev_M2 --kim MENZILCI --tahmin 30" "$(cat "$T/ustlen.log" 2>/dev/null)"
: > "$T/liste.txt"; satir H1 menzil havuz esnek ozellik MENZILCI "havuz işim" >> "$T/liste.txt"; rm -f "$T/ustlen.log"
c="$(bash "$SB" 2>&1)"
iceriyor "H2 Sırada 0, koltuğa atanmış havuz işi var → KARAR=BAS" "KARAR=BAS" "$c"
kapi "H2b havuz işi üstlenilir" "ustlen gorev_H1 --kim MENZILCI --tahmin 30" "$(cat "$T/ustlen.log" 2>/dev/null)"
iceriyor "H2c ISI satırında havuz işi listelenir" "ISI=gorev_H1" "$c"
: > "$T/liste.txt"; satir H2 menzil havuz esnek ozellik HENDESE "başkasının havuzu" >> "$T/liste.txt"; rm -f "$T/ustlen.log"
c="$(bash "$SB" --kutu menzil 2>&1)"
iceriyor "H3 havuz işi BAŞKASINA atanmışsa sayılmaz → KARAR=SOR" "KARAR=SOR" "$c"
iceriyor "H3b HAVUZDA=0" "HAVUZDA=0" "$c"
kapi "H3c başkasının havuz işi üstlenilmez" "yok" "$([ -e "$T/ustlen.log" ] && echo var || echo yok)"
: > "$T/liste.txt"; satir H3 menzil havuz esnek ozellik MENZILCI "havuz işim" >> "$T/liste.txt"; rm -f "$T/ustlen.log"
c="$(bash "$SB" --bak 2>&1)"
kapi "H4 --bak havuz işini üstlenmez" "yok" "$([ -e "$T/ustlen.log" ] && echo var || echo yok)"
iceriyor "H4b --bak havuzdan BAS der ve üstlenme komutunu gösterir" "gorev.sh ustlen gorev_H3" "$c"

echo "── MADDE satırı (GJRBF1T8): sıradaki iş doğrudan plan maddesi biçiminde"
: > "$T/liste.txt"; for i in 1 2 3; do satir "MMMMM$i" menzil acik esnek ozellik MENZILCI "sıra işi $i" >> "$T/liste.txt"; done; satir "ZZZZZ9" menzil acik acil ozellik HENDESE "başkasının işi" >> "$T/liste.txt"
c="$(GUNLUK_PLAN_AJAN=MENZILCI bash "$SB" --bak --kutu menzil 2>/dev/null)"
kapi "S30 her ISI satırına bir MADDE satırı eşlik eder (4)" "4" "$(grep -c '^MADDE=' <<<"$c")"
kapi "S30b biçim: 'görev …<son6> tamamlanacak: <başlık> (sahip: <kim>)' — acil iş önce, başkasının işi 'başkası'" "1:1" "$(grep -c '^MADDE=görev …ZZZZZ9 tamamlanacak: başkasının işi (sahip: başkası)$' <<<"$c"):$(grep -c '^MADDE=görev …MMMMM1 tamamlanacak: sıra işi 1 (sahip: MENZILCI)$' <<<"$c")"
echo "sonuç: $gecen geçti · $kalan kaldı"; [ "$kalan" -eq 0 ]
