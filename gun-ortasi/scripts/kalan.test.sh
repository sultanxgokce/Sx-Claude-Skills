#!/usr/bin/env bash
# kalan.test.sh — /gun-ortasi kalan.sh + cipa-ekle.sh sınavı. HERMETİK: sahte kutu ve sahte beceri dizini
# $TMP'de; gerçek kutuya, gerçek defterlere dokunulmaz. Çıpa kapıları GERÇEK gunluk-plan/cipa.sh'ın KOPYASIYLA
# koşar (kör-1: uydurma biçimle yeşil olan kapı gerçek biçimi göremiyordu).
# KOŞUM: bash kalan.test.sh → 0 = hepsi yeşil
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ARAC="$D/kalan.sh"; EKLE="$D/cipa-ekle.sh"
# 🔴 ÇIPA ARACI İKİ YERDE ARANIR (2026-10-05): kurulu kutuda `/config/.claude/skills/...`,
#    ama CI TEMİZ bir makinede koşar ve orada o yol YOKTUR → on kapı birden "ölçemedim"e
#    düşüyordu ve sınav buna rağmen çıkış 0 veriyordu, yani CI'da yeşil görünen koşum
#    çıpa kapılarını HİÇ ölçmemiş oluyordu. İki beceri aynı kaynakta yaşadığı için depo-göreli
#    yol gerçek bir yüzeydir: kurulu yol yoksa ona düşülür.
_cipa_bul() {
  [ -n "${GUN_ORTASI_GERCEK_CIPA:-}" ] && { printf '%s' "$GUN_ORTASI_GERCEK_CIPA"; return; }
  local a="/config/.claude/skills/gunluk-plan/scripts/cipa.sh"
  local b="$D/../../gunluk-plan/scripts/cipa.sh"
  # 🔴 DEPO KARDEŞİ ÖNCE (1.1.0, bağımsız göz tur 1 bağlamı): kurulu kopya önce gelince sınav DEĞİŞEN
  #    kodu değil kutudaki ESKİ kurulumu ölçüyordu — yeni tablo/kapanış sınavda hiç koşmuyordu.
  [ -f "$b" ] && { printf '%s' "$b"; return; }
  [ -f "$a" ] && { printf '%s' "$a"; return; }
  printf '%s' "$a"
}
GERCEK_CIPA="$(_cipa_bul)"
TMP="$(mktemp -d)"; trap 'find "$TMP" -delete 2>/dev/null' EXIT
G=0; K=0; O3=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  🟢 %s\n' "$1"; else K=$((K+1)); printf '  🔴 %s — beklenen [%s] görülen [%s]\n' "$1" "$3" "$2"; fi; }
oz(){ grep '^#OZET' <<<"$1" | tr '\t' '\n' | awk -F= -v a="$2" '$1==a{print $2; exit}'; }
BUGUN="$(date +%F)"

# ── sahte kutu ───────────────────────────────────────────────────────────
B="$TMP/kutu"; SK="$TMP/sk"; KK="$B/_agents/fabrika/kanit"
mkdir -p "$B/_agents/fabrika/kartlar" "$B/_agents/handoff" "$KK/is-a" "$KK/is-b" "$KK/is-c" "$KK/is-d" "$B/0-teslimat/gelen" "$SK"
git -C "$B" init -q
printf '{"durum":"acik"}\n'    > "$B/_agents/fabrika/kartlar/k1.json"
printf '{"durum":"bitti"}\n'   > "$B/_agents/fabrika/kartlar/k2.json"
printf '{"durum":"tikandi"}\n' > "$B/_agents/fabrika/kartlar/k3.json"
printf '{bozuk\n'              > "$B/_agents/fabrika/kartlar/k4.json"
printf '## KONUM\n- iş X bitti\n- Açık: bekçi iki kapısız nokta\n- SARI: yarın sabah kanıtı\n' > "$B/_agents/handoff/ali-durum.md"
# is-a: md, gerçek başlık biçimi; kapandı (küçük harf, Türkçe ı) düşer · KISMEN KAPANDI açık · ### başlık yakalanır · ENGEL yok düşer
printf 'KOD İYİ Mİ: 4\nDOĞRU ŞEY Mİ: E\n\n- N1 DÜŞÜK: sınır kapısız\n- **N2 (eski): kapandı.**\n- N3 KISMEN KAPANDI: yarısı açık\n### N4 · NOT başlık biçimli bulgu\n## NOT-1 (kapsam) — görüşüm\n## B1 doğrulaması\n- ENGEL: yok\n' > "$KK/is-a/BAGIMSIZ-GOZ-kor-2.md"
printf 'KOD İYİ Mİ: 3\nDOĞRU ŞEY Mİ: E\n- N9 eski turun bulgusu\n' > "$KK/is-a/BAGIMSIZ-GOZ-kor-1.md"; touch -d '1 hour ago' "$KK/is-a/BAGIMSIZ-GOZ-kor-1.md"
# is-b: 5·E, yalnız BİLGİ → açık değil
printf 'KOD İYİ Mİ: 5\nDOĞRU ŞEY Mİ: E\n- N1 BİLGİ: zararsız\n' > "$KK/is-b/BAGIMSIZ-GOZ-kor-1.md"
# is-c: fabrika denetçisi biçimi (DENETIM json) 3·H → açık 1
printf '{"tur":1,"sonuc":{"kod_puani":3,"dogru_sey":"H","ozet":"doğru şey değil"}}\n' > "$KK/is-c/DENETIM-1.json"
# is-d: md eski 4·E, json daha YENİ 5·E → json kazanır, açık değil
printf 'KOD İYİ Mİ: 4\nDOĞRU ŞEY Mİ: E\n- N1 açık\n' > "$KK/is-d/BAGIMSIZ-GOZ-kor-1.md"; touch -d '2 hours ago' "$KK/is-d/BAGIMSIZ-GOZ-kor-1.md"
printf '{"tur":2,"sonuc":{"kod_puani":5,"dogru_sey":"E","ozet":"tamam"}}\n' > "$KK/is-d/DENETIM-2.json"
# gelen: tam ad eşleşmesi + pencere yok
printf 'x\n' > "$B/0-teslimat/gelen/BA.md"; printf 'y\n' > "$B/0-teslimat/gelen/A.md"; printf 'z\n' > "$B/0-teslimat/gelen/ESKI.md"
touch -d '40 days ago' "$B/0-teslimat/gelen/ESKI.md"
printf '2026-10-02T00:00:00Z | okundu | BA.md | abc | ali\n' > "$B/0-teslimat/okundu.log"
printf '# ANA-HEDEF\n1. Gece turu bulgu getirsin\n' > "$B/_agents/ANA-HEDEF.md"
printf '# x\n\n## Amaç\nKaynak koddan kanıtlı bulgu.\n\n## Ekip\n' > "$B/CLAUDE.md"
kos(){ (cd "$B" && GUN_ORTASI_SK="$SK" GUN_ORTASI_KOK="$B" "$@" bash "$ARAC" 2>&1); }

O="$(kos env)"; R=$?
kapi "T1 rc=0 ve #OZET satırı var" "$R/$(grep -c '^#OZET' <<<"$O")" "0/1"
kapi "T2 açık kart 1 · tıkandı ayrı 1 · bozuk JSON sayılmaz, ölçemedim der" "$(oz "$O" kart)/$(oz "$O" tikandi)/$(grep -c '1 kartın durumu okunamadı' <<<"$O")" "1/1/1"
kapi "T3 konum çapasından 'Açık' ve 'SARI' (2), 'bitti' değil" "$(oz "$O" capa_acik)" "2"
kapi "T4 göz md: son rapor; kapandı düşer; KISMEN + ### başlık açık → 3 (N1,N3,N4); eski tur N9 yok" \
  "$(grep -c 'N1 DÜŞÜK' <<<"$O")/$(grep -c 'N2 (eski)' <<<"$O")/$(grep -c 'N3 KISMEN' <<<"$O")/$(grep -c 'N4 · NOT' <<<"$O")/$(grep -c 'N9 eski' <<<"$O")" "1/0/1/1/0"
kapi "T4c bölüm başlıkları ('## NOT-1 (…) — görüşüm', '## B1 doğrulaması') bulgu sayılmaz" "$(grep -c 'görüşüm' <<<"$O")/$(grep -c 'B1 doğrulaması' <<<"$O")" "0/0"
kapi "T4b göz json: 3·H açık (1) · daha yeni 5·E json eski md'yi ezer · 5·E+BİLGİ açık değil → toplam 4" \
  "$(oz "$O" goz_acik)/$(grep -c 'is-c (DENETIM-1.json · 3·H)' <<<"$O")/$(grep -c '▸ is-d' <<<"$O")/$(grep -c '▸ is-b' <<<"$O")" "4/1/0/0"
kapi "T5 gelen: TAM ad eşleşmesi (BA okundu, A okunmadı) + 40 günlük mektup da sayılır → 2" \
  "$(oz "$O" gelen)/$(grep -c '• A.md' <<<"$O")/$(grep -c '• ESKI.md' <<<"$O")" "2/1/1"
# T15 #OZET olcemedim = basılan "ölçemedim:" satır sayısı (kör-2 N2: sabit-0 mutantı yaşıyordu) · hiçbir alan boş değil
kapi "T15 #OZET olcemedim basılan satır sayısına eşit · alanların hiçbiri boş değil" \
  "$(oz "$O" olcemedim)/$(grep -c 'ölçemedim:' <<<"$O")/$(grep '^#OZET' <<<"$O" | tr '\t' '\n' | grep -c '=$')" "$(grep -c 'ölçemedim:' <<<"$O")/$(grep -c 'ölçemedim:' <<<"$O")/0"
kapi "T6 hedef: ANA-HEDEF ve CLAUDE.md Amaç basılır" "$(grep -c 'Gece turu bulgu getirsin' <<<"$O")/$(grep -c 'Kaynak koddan kanıtlı' <<<"$O")" "1/1"
kapi "T7 ölçülemeyen alan ? basar, 0 değil (çıpa, layiha, kapımda)" "$(oz "$O" cipa_acik)/$(oz "$O" layiha)/$(oz "$O" kapimda)" "?/?/?"
P1="$(cd "$B" && find . -path ./.git -prune -o -type f -printf '%p %s %T@\n' | sort | md5sum)"; kos env >/dev/null
P2="$(cd "$B" && find . -path ./.git -prune -o -type f -printf '%p %s %T@\n' | sort | md5sum)"
kapi "T8 salt-okur: kutu dokunulmadı" "$([ "$P1" = "$P2" ] && echo ayni)" "ayni"
touch -d '10 days ago' "$B/_agents/handoff/ali-durum.md"; O9="$(kos env)"
kapi "T9 pencere dışındaki çapa sayılmaz; '?' basar (ölçemedim)" "$(oz "$O9" capa_acik)" "?"
O9b="$(kos env GUN_ORTASI_GUN=30)"; kapi "T9b pencere genişletilince sayılır" "$(oz "$O9b" capa_acik)" "2"
kos env GUN_ORTASI_GUN=abc >/dev/null; kapi "T10 sayı olmayan pencere → rc=2" "$?" "2"

# ── T11 · GERÇEK cipa.sh ile ─────────────────────────────────────────────
if [ -f "$GERCEK_CIPA" ]; then
  mkdir -p "$SK/gunluk-plan/scripts"; cp "$GERCEK_CIPA" "$SK/gunluk-plan/scripts/cipa.sh"
  # 1.1.0: tablo ve sayım çıpa aracının ayrıştırıcısından gelir (tek şablon) — gerçek kurulumdaki gibi yanına konur
  cp "$(dirname "$GERCEK_CIPA")/tablo.py" "$SK/gunluk-plan/scripts/tablo.py"
  # 🔴 ÇIPA YOLU ARAÇTAN SORULUR, SINAVA GÖMÜLMEZ (2026-10-05). Eskiden burada sabit
  #    "$CF" yazılıydı; cipa.sh ajan-başına dosyaya
  #    geçtiğinde sınav var olmayan dosyayı grep'ledi ve 8 kapı birden kırmızıya döndü.
  #    Sınav yolu kendi türetirse, ölçtüğü şey ARACIN davranışı değil kendi varsayımı olur.
  CF="$( (cd "$B" && GUN_ORTASI_SK="$SK" bash "$SK/gunluk-plan/scripts/cipa.sh" yol) )"
  [ -n "$CF" ] || { echo "  🔴 cipa.sh 'yol' desteklemiyor — çıpa kapıları koşulamaz"; exit 1; }
  (cd "$B" && bash "$SK/gunluk-plan/scripts/cipa.sh" yaz --plan "1) A | 2) B | 3) C" --not "Sultan onayı: deneme" >/dev/null)
  (cd "$B" && bash "$SK/gunluk-plan/scripts/cipa.sh" tazele --madde 1 --durum kapandi --not "bitti, bekliyor değil" >/dev/null)
  (cd "$B" && bash "$SK/gunluk-plan/scripts/cipa.sh" tazele --madde 2 --durum yarim >/dev/null)
  O11="$(kos env)"
  kapi "T11 gerçek çıpa: [x] kapalı (notunda 'bekliyor' geçse de) · [~] ve [ ] açık → 2/1" "$(oz "$O11" cipa_acik)/$(oz "$O11" cipa_kapali)" "2/1"
  # T16 · TEK ŞABLON fiilen basılır (bağımsız göz tur 1: yalnız talimatta yazılıydı, çıktıda ölçülmüyordu)
  kapi "T16 1. bölüm /gunluk-plan'ın KUTULU tablosunu basar (madde · sahip · durum işareti · kanıt)" \
       "$(printf '%s\n' "$O11" | grep -c '│ # │ Madde')/$(printf '%s\n' "$O11" | grep -cE '│ 2 +│ B +│ — +│ +🟡 +│ — +│')" "1/1"
  # T17 · ayrıştırıcı yoksa (eski kurulum) sessiz grep'e DÜŞMEZ — ölçemedim der
  mv "$SK/gunluk-plan/scripts/tablo.py" "$SK/gunluk-plan/scripts/tablo.py.yok"
  O17="$(kos env)"; mv "$SK/gunluk-plan/scripts/tablo.py.yok" "$SK/gunluk-plan/scripts/tablo.py"
  kapi "T17 ayrıştırıcı yoksa çıpa sayımı ? + ölçemedim (sessiz yedek sayım yok)" "$(oz "$O17" cipa_acik)/$(printf '%s\n' "$O17" | grep -c 'tabloya çevrilemedi')" "?/1"
  # T11c başka klasörden çağrılınca da KUTUNUN çıpası okunur (kör-1: `cd $KOK` silen mutant yaşıyordu)
  mkdir -p "$TMP/baska"; git -C "$TMP/baska" init -q
  O11c="$(cd "$TMP/baska" && GUN_ORTASI_SK="$SK" GUN_ORTASI_KOK="$B" bash "$ARAC" 2>&1)"
  kapi "T11c başka klasörden çağrıda kutunun çıpası okunur → 2/1" "$(oz "$O11c" cipa_acik)/$(oz "$O11c" cipa_kapali)" "2/1"
  O11b="$(kos env GUN_ORTASI_TARIH=2000-01-01)"
  kapi "T11b başka günün çıpası sayılmaz → ? ve ölçemedim" "$(oz "$O11b" cipa_acik)/$(grep -c 'çıpa bugüne ait değil' <<<"$O11b")" "?/1"
  # T14 cipa-ekle: sabahki maddelere dokunmadan arkaya ekler; tazele yeni maddeyi numarasıyla bulur
  E="$(cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G1) gün ortası X | G2) Y" 2>&1)"; ER=$?
  M="$(grep -E '^- \[.\] ' "$CF")"
  T4ok="$( (cd "$B" && bash "$SK/gunluk-plan/scripts/cipa.sh" tazele --madde 4 --durum kapandi) >/dev/null 2>&1; echo $?)"
  kapi "T14 cipa-ekle: rc=0 · 5 madde · sabah [x] korundu · 4. madde G1 · tazele 4 çalışır" \
    "$ER/$(grep -c . <<<"$M")/$(sed -n 1p <<<"$M" | cut -c1-5)/$(sed -n 4p <<<"$M" | grep -c 'G1) gün ortası X')/$T4ok" "0/5/- [x]/1/0"
  (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G1) gün ortası X | G2) Y" >/dev/null 2>&1); n2="$(grep -cE '^- \[.\] ' "$CF")"
  (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --geri-al "G2)" >/dev/null 2>&1); rg=$?
  O14="$(kos env)"
  kapi "T14c tekrar ekleme çoğaltmaz (5) · geri-al rc=0 · geri alınan açık sayılmaz (açık 2: [~]B,[ ]C; G1 kapandı, G2 geri)" \
    "$n2/$rg/$(grep -c '^- \[-\] G2) Y → GERİ ALINDI' "$CF")/$(oz "$O14" cipa_acik)" "5/0/1/2"
  (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --geri-al "G7)" >/dev/null 2>&1); rg2=$?
  timeout 5 env GUN_ORTASI_SK="$SK" bash "$EKLE" --plan >/dev/null 2>&1; rd=$?; (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --plan " | " >/dev/null 2>&1); rb=$?
  kapi "T14d eşleşmeyen geri-al rc=1 · değersiz bayrak rc=2 (döngü yok) · boş liste rc=2" "$rg2/$rd/$rb" "1/2/2"
  kapi "T14e çıpanın '## Not' bölümü ve yazıldı satırı korunur, maddeler Not'tan önce" \
    "$(grep -c '^## Not' "$CF")/$(grep -c '^_yazıldı:' "$CF")/$(awk '/^- \[/{m=NR} /^## Not/{n=NR} END{print (m<n)?"once":"sonra"}' "$CF")" "1/1/once"
  # T14f geri alınan yeniden eklenince AÇILIR (kör-3 Y1) · geri-al yalnız tam etiket: "2)" ve "G" reddedilir, sabah maddesi dokunulmaz (Y2)
  (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G2) Y" >/dev/null 2>&1); ry=$?
  (cd "$B" && timeout 5 env GUN_ORTASI_SK="$SK" bash "$EKLE" --geri-al "2)" >/dev/null 2>&1); ra=$?; (cd "$B" && timeout 5 env GUN_ORTASI_SK="$SK" bash "$EKLE" --geri-al "G" >/dev/null 2>&1); rb2=$?
  (cd "$B" && timeout 5 env GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "serbest metin" >/dev/null 2>&1); rp=$?
  kapi "T14f geri alınan yeniden açılır · '2)' ve 'G' ret (rc=2) · etiketsiz plan ret · sabah 2. madde [~] kaldı" \
    "$ry/$(grep -c '^- \[ \] G2) Y$' "$CF")/$ra/$rb2/$rp/$(grep -c '^- \[~\] 2) B' "$CF")" "0/1/2/2/2/1"
  # T14g kilit depoda dosya bırakmaz (kör-3 Y3) · "→" geçen madde metni tekrar-yazma engelini bozmaz
  (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G5) a → b arası" >/dev/null 2>&1; GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G5) a → b arası" >/dev/null 2>&1)
  # T14h ikinci gün ortası turu aynı etiketi başka metinle kullanamaz (kör-4 Y4); seçilmiş G1 yerinde kalır
  (cd "$B" && timeout 5 env GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G1) başka iş" >/dev/null 2>&1); r14h=$?
  kapi "T14h aynı etiket farklı metin → rc=2, sabahki G1 dokunulmadı" "$r14h/$(grep -c 'G1) gün ortası X' "$CF")/$(grep -c 'G1) başka iş' "$CF")" "2/1/0"
  # T14g cipa-ekle cipa.sh ile AYNI kilidi bekler (2026-10-03: ayrı kilitler karşılıklı dışlamıyordu) · "→" metni bir kez
  ( exec 8>>"$CF.kilit"; flock 8; sleep 2 ) & kp=$!; sleep 0.3
  t0=$(date +%s%N); (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G6) kilit sınavı" >/dev/null 2>&1); bek=$(( ($(date +%s%N)-t0)/1000000 )); wait "$kp"
  kapi "T14g ortak kilit tutulurken ekle BEKLER (≥1500 ms) · '→' içeren madde bir kez" "$([ "$bek" -ge 1500 ] && echo bekledi || echo "beklemedi(${bek}ms)")/$(grep -c 'G5) a → b arası' "$CF")" "bekledi/1"
  # T14j · 🔴 TOCTOU (bağımsız göz tur 3): kilidi beklerken çıpa BAŞKA güne dönerse ekleme
  #   REDDEDİLİR. Eskiden tarih kilitten ÖNCE sorulduğu için bekleyen ekleme yanlış günün
  #   çıpasına yazıyordu. Senaryo: kilidi tutan süreç dosyayı dünün çıpasıyla değiştirir.
  #   🔴 SIRA KRİTİK (ilk yazımda kapı ISIRMIYORDU — mutasyonda yeşil kaldı): tarihi kilidi
  #   alır almaz değiştirirsem, ESKİ sıra da kilitten önceki kontrolde yeni tarihi görüp
  #   reddeder; iki sıra aynı sonucu verir ve kapı hiçbir şey ölçmez. Tarih, ekleyici
  #   kilitten ÖNCEKİ kontrolünü GEÇTİKTEN sonra değişmeli. Onun için: kilidi al → bekle
  #   (ekleyici ön kontrolünü geçsin ve kilide takılsın) → tarihi değiştir → bırak.
  CFK="$CF.kilit"
  ( exec 9>>"$CFK"; flock 9; sleep 1.5; sed -i "s/ÇIPASI · $BUGUN/ÇIPASI · 2000-01-01/" "$CF" ) & kt=$!
  sleep 0.3
  rt="$( (cd "$B" && GUN_ORTASI_SK="$SK" timeout 20 bash "$EKLE" --plan "G4) toctou" 2>&1) )"; rtc=$?
  wait "$kt" 2>/dev/null
  kapi "T14j kilit beklenirken çıpa başka güne dönerse YAZMAZ (rc=1)" \
       "$rtc/$(grep -c 'bugüne ait değil' <<<"$rt")/$(grep -c 'G4) toctou' "$CF")" "1/1/0"
  sed -i "s/ÇIPASI · 2000-01-01/ÇIPASI · $BUGUN/" "$CF"

  # T14i · 🔴 ARAÇ BULUNAMAZSA FAIL-CLOSED (2026-10-05, CI'da ölçüldü): cipa-ekle çıpa yolunu
  #   `cipa.sh yol`dan sorar. Araç görünmüyorsa TAHMİN ETMEZ, rc=1 verir ve sebebini söyler.
  #   Bu kapı niçin var: sınav bu yolu KAZARA tetikliyordu — çağrılara arama dikişi verilmediği
  #   için kurulu yola düşüyor, geliştirici makinesinde o yol VAR olduğu için yeşil kalıyor,
  #   CI'da YOK olduğu için altı kapı birden kırmızıya dönüyordu. Artık yol bilerek ölçülüyor.
  ry_yok="$( (cd "$B" && GUN_ORTASI_SK="$TMP/yok-boyle-bir-dizin" bash "$EKLE" --plan "G8) q" 2>&1) )"; r_yok=$?
  kapi "T14i araç yoksa rc=1 + sebep söylenir (tahminle yazmaz)" \
       "$r_yok/$(grep -c 'cipa.sh bulunamadı' <<<"$ry_yok")" "1/1"
  (cd "$B" && GUNLUK_PLAN_TARIH=2000-01-01 GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G9) z" >/dev/null 2>&1); r1=$?
  mv "$CF" "$TMP/cipa.yedek"; (cd "$B" && GUN_ORTASI_SK="$SK" bash "$EKLE" --plan "G9) z" >/dev/null 2>&1); r2=$?
  kapi "T14b cipa-ekle eski çıpaya ve çıpasız kutuya YAZMAZ (rc=1/1)" "$r1/$r2" "1/1"
else
  echo "  🟡 [OLCEMEDIM] T11/T11b/T11c/T14/T14b/T14c/T14d/T14e/T14f/T14g — gerçek cipa.sh yok: $GERCEK_CIPA (yeşil DEĞİL)"; O3=$((O3+10))
fi

# T12 sayım tavandan ÖNCE: 15 açık satır, tavan 10 → sayı 15 ve "+5" iletisi
touch "$B/_agents/handoff/ali-durum.md"; for i in $(seq 1 13); do printf -- '- Açık: kalem %s\n' "$i" >> "$B/_agents/handoff/ali-durum.md"; done
O12="$(kos env GUN_ORTASI_TAVAN=10)"
kapi "T12 sayım kırpmadan önce (15) ve kırpılan söylenir (+5)" "$(oz "$O12" capa_acik)/$(grep -c '+5 satır daha' <<<"$O12")" "15/1"
# T13 kapımda hata verirse ölçemedim + '?'
mkdir -p "$SK/kapimda/scripts"; printf '#!/usr/bin/env bash\nexit 7\n' > "$SK/kapimda/scripts/kapimda.sh"
O13="$(kos env)"
kapi "T13 kapımda hata → ? ve ölçemedim (rc=7)" "$(oz "$O13" kapimda)/$(grep -c 'kapımda listelenemedi (rc=7)' <<<"$O13")" "?/1"

# T16a · cipa.sh VAR ama çıpa YOK → "?" + ölçemedim (kör-4 N1 A13: bugün nazir'de yaşanan durum)
if [ -f "$SK/gunluk-plan/scripts/cipa.sh" ]; then
  [ -f "$CF" ] && mv "$CF" "$TMP/cipa.t16"
  o16="$(kos env)"
  kapi "T16a araç var, çıpa yok → cipa_acik ? ve ölçemedim satırı" "$(oz "$o16" cipa_acik)/$(grep -c 'çıpa yok (bugün' <<<"$o16")" "?/1"
fi
# T16 · "ölçemedim ≠ iş yok" HER KAYNAK İÇİN (kör-3 N1): kaynak tek tek kaldırılır → o alan "?" olur ve
#   olcemedim TAM BİR artar. Bir dal satırı silinip alan 0'a çevrilse bu döngü yakalar.
rm -f "$B/_agents/fabrika/kartlar/k4.json"   # bozuk kart kendi ölçemedim'ini üretir; kaynak kaldırma sayımını karıştırmasın
taban="$(oz "$(kos env)" olcemedim)"; s16=""
for ikili in "_agents/fabrika/kartlar:kart" "_agents/handoff:capa_acik" "_agents/fabrika/kanit:goz_acik" "0-teslimat/gelen:gelen" ".git:commitsiz"; do
  yol="${ikili%%:*}"; alan="${ikili#*:}"; mv "$B/$yol" "$TMP/kaldirilan"
  o="$(kos env)"; v="$(oz "$o" "$alan")"; n="$(oz "$o" olcemedim)"
  mv "$TMP/kaldirilan" "$B/$yol"
  [ "$v" = "?" ] && [ "$n" = "$((taban+1))" ] || s16+="$alan($v,$n) "
done
kapi "T16 beş kaynağın her biri kaldırılınca alanı '?' ve olcemedim +1" "${s16:-tamam}" "tamam"

# T5b · BÜYÜK okundu kaydı (gorev_01M55X6PGK9C9K8MRSY0E01W3Q, TELLAL 18 Eki: 204 satırla 140/140/131 yanlış sayım):
#   'printf | grep -q' pipefail altında — grep ilk eşleşmede çıkar, printf SIGPIPE (141) alır, boru rc≠0 olur ve
#   OKUNMUŞ mektup okunmamış sayılır. Eşleşme kaydın BAŞINDA, kayıt boru tamponundan (64K) büyük → eski kod kesin düşer.
{ printf '2026-10-18T00:00:00Z | okundu | A.md | abc | ali\n'
  for i in $(seq 1 3000); do printf '2026-10-18T00:00:00Z | okundu | DOLGU-%05d-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.md | abc | ali\n' "$i"; done
  printf '2026-10-18T00:00:00Z | okundu | BA.md | abc | ali\n'; } > "$B/0-teslimat/okundu.log"
O5="$(kos env)"
kapi "T5b büyük okundu kaydı (>64K, eşleşme başta ve sonda): A ve BA okundu sayılır → gelen 1 (yalnız ESKI)" \
  "$(oz "$O5" gelen)/$(grep -c '• A.md' <<<"$O5")/$(grep -c '• BA.md' <<<"$O5")" "1/0/0"
printf '2026-10-02T00:00:00Z | okundu | BA.md | abc | ali\n' > "$B/0-teslimat/okundu.log"

# T5c · BÜYÜK çıpa (aynı SIGPIPE tuzağı, kalan.sh 1. bölüm): başlık en üstte, gövde >64K → eski 'printf | grep -q'
#   bugünün çıpasını "bugüne ait değil" sayardı. Sahte çıpa aracı yalnız 'oku' basar.
SK2="$TMP/sk-buyuk"; mkdir -p "$SK2/gunluk-plan/scripts"
cat > "$SK2/gunluk-plan/scripts/cipa.sh" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = oku ] || exit 2
printf '# ⚓ GÜNÜN PLANI ÇIPASI · %s\n\n## Maddeler\n' "$(date +%F)"
for i in $(seq 1 3000); do printf -- '- [x] %d) dolgu maddesi xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx → KAPANDI\n' "$i"; done
EOF
O6="$(cd "$B" && GUN_ORTASI_SK="$SK2" GUN_ORTASI_KOK="$B" bash "$ARAC" 2>&1)"
#   Sahte araç 'tablo' bilmez → tarih kapısını GEÇEN çıpa bir sonraki adımda "tabloya çevrilemedi" der; kapıda düşen bunu diyemez.
kapi "T5c büyük çıpa (>64K, başlık başta) tarih kapısını geçer — 'bugüne ait değil' DENMEZ, sonraki adıma (tablo) ulaşır" \
  "$(grep -c 'çıpa bugüne ait değil' <<<"$O6")/$(grep -c 'çıpa tabloya çevrilemedi' <<<"$O6")" "0/1"

# ── T5d–T5n · OKUNDU KAYDI KUTUNUN DOSYASINDAN OKUNUR, KURYE KOŞTURULMAZ (gorev_01M4ZMCTDB4B84P42S6R75A8CJ · MİHENK 14 Eki: kutu
#   '0-teslimat/.okundu' yazıyor, araç 'okundu.log' arıyordu → 71 mektup okunmamış basıldı, gerçek 0). Fikstür mihenk'i taklit eder:
#   okundu.log YOK, kayıt .okundu'da (biçim kurye-yokla.sh'ın yazdığıyla aynı: ad<TAB>sha256:|md5:özet · yalın ad).
#   Kutudaki kurye-yokla.sh bir KANARYA: her çağrı .kurye-cagrildi'ye iz bırakır ve eski kuryenin yoklama kipi gibi .okundu'yu
#   "hepsi okunmuş" diye yeniden yazar — kalan.sh onu koşturursa hem iz kalır hem sayım kayar (bağımsız göz tur 4: tanımadığı
#   komutta eski kurye touch + göç yapar; salt-okur ölçüm kutuyu değiştiremez). Eski kod üçünde de "okundu.log yok — hepsi okunmamış" der.
mv "$B/0-teslimat/okundu.log" "$TMP/okundu.log.kenar"
mkdir -p "$B/scripts"
cat > "$TMP/kanarya.sh" <<'EOF'
#!/usr/bin/env bash
# KANARYA kurye-yokla.sh — çağrılırsa iz bırakır ve .okundu'yu "hepsi okunmuş" diye yeniden yazar (eski kuryenin yoklama kipi)
K="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/0-teslimat"
echo "çağrıldı: $*" >> "$K/.kurye-cagrildi"
for f in "$K"/gelen/*.md; do printf '%s\tsha256:%s\n' "$(basename "$f")" "$(sha256sum "$f" | cut -d' ' -f1)"; done > "$K/.okundu"
exit 0
EOF
cp "$TMP/kanarya.sh" "$B/scripts/kurye-yokla.sh"
kanarya() { [ -f "$B/0-teslimat/.kurye-cagrildi" ] && echo 1 || echo 0; }
# BA: özeti tutuyor (okunmuş) · A: okunduktan sonra İÇERİĞİ değişmiş (özet tutmaz → okunmamış) · ESKI: kayıtta yok
printf 'BA.md\tsha256:%s\nA.md\tsha256:0000000000000000000000000000000000000000000000000000000000000000\n' "$(sha256sum "$B/0-teslimat/gelen/BA.md" | cut -d' ' -f1)" > "$B/0-teslimat/.okundu"
OKD_ONCE="$(sha256sum "$B/0-teslimat/.okundu" | cut -d' ' -f1)"
O7="$(kos env)"
kapi "T5d kayıt .okundu'dan OKUNUR (kurye koşturulmaz): BA okunmuş, A (özeti tutmaz) ve ESKI okunmamış → gelen 2; 'okundu.log yok' DENMEZ; not kaynağı ve sayıları söyler; kanarya 0" \
  "$(oz "$O7" gelen)/$(grep -c '• BA.md' <<<"$O7")/$(grep -c '• A.md' <<<"$O7")/$(grep -c 'okundu kaydı yok' <<<"$O7")/$(grep -c '0-teslimat/.okundu dosyasından okundu (2 ad · 1 okunmuş · kurye-yokla.sh koşturulmadı)' <<<"$O7")/$(kanarya)" "2/0/1/0/1/0"
kapi "T5d2 ölçüm .okundu'yu DEĞİŞTİRMEZ (yan etki yok): dosya özeti önce = sonra" \
  "$([ "$OKD_ONCE" = "$(sha256sum "$B/0-teslimat/.okundu" | cut -d' ' -f1)" ] && echo ayni || echo degisti)" "ayni"
# T5e · md5 özetli kayıt (göçte makbuzdan gelen) + yalın ad (eski damga): ikisi de okunmuş → yalnız ESKI
printf 'BA.md\tmd5:%s\nA.md\n' "$(md5sum "$B/0-teslimat/gelen/BA.md" | cut -d' ' -f1)" > "$B/0-teslimat/.okundu"
O8="$(kos env)"
kapi "T5e md5 özetli kayıt + yalın ad kaydı: BA ve A okunmuş → yalnız ESKI → gelen 1; kanarya 0" \
  "$(oz "$O8" gelen)/$(grep -c '• ESKI.md' <<<"$O8")/$(grep -c '• BA.md' <<<"$O8")/$(grep -c '• A.md' <<<"$O8")/$(kanarya)" "1/1/0/0/0"
# T5f · aynı ad için SON özetli kayıt kazanır (kurye-yokla.sh kayit_al kuralı): A önce yanlış sonra doğru → okunmuş; BA önce doğru sonra yanlış → okunmamış
printf 'A.md\tsha256:0000000000000000000000000000000000000000000000000000000000000000\nBA.md\tsha256:%s\nA.md\tsha256:%s\nBA.md\tsha256:1111111111111111111111111111111111111111111111111111111111111111\n' \
  "$(sha256sum "$B/0-teslimat/gelen/BA.md" | cut -d' ' -f1)" "$(sha256sum "$B/0-teslimat/gelen/A.md" | cut -d' ' -f1)" > "$B/0-teslimat/.okundu"
O9="$(kos env)"
kapi "T5f aynı ad için son özetli kayıt kazanır: A okunmuş, BA okunmamış → gelen 2 (BA, ESKI); not '2 ad · 1 okunmuş'" \
  "$(oz "$O9" gelen)/$(grep -c '• A.md' <<<"$O9")/$(grep -c '• BA.md' <<<"$O9")/$(grep -c '(2 ad · 1 okunmuş' <<<"$O9")" "2/0/1/1"
# T5h · özet İDDİA eden ama tanınmayan biçim (blake3:…): okunmuş SAYILMAZ (kurye kuralı: 'biçimi tanınmayan ama özet iddia eden satır okunmuş sayılmaz') ve söylenir
printf 'BA.md\tblake3:abc\nA.md\tsha256:%s\n' "$(sha256sum "$B/0-teslimat/gelen/A.md" | cut -d' ' -f1)" > "$B/0-teslimat/.okundu"
O11="$(kos env)"
kapi "T5h tanınmayan özet biçimi (blake3) okunmuş sayılmaz: BA ve ESKI okunmamış → gelen 2; not '1 kayıt tanınmayan özet biçiminde — okunmuş sayılmadı'" \
  "$(oz "$O11" gelen)/$(grep -c '• BA.md' <<<"$O11")/$(grep -c '1 kayıt tanınmayan özet biçiminde — okunmuş sayılmadı' <<<"$O11")" "2/1/1"
# T5i · .okundu var ama okunabilir bir dosya DEĞİL (dizin): ölçemedim, boş liste ile "hepsi okunmamış" DENMEZ (okunamayan kayıt ≠ boş kayıt)
rm -f "$B/0-teslimat/.okundu"; mkdir -p "$B/0-teslimat/.okundu"
O12="$(kos env)"
kapi "T5i .okundu dizin (okunamaz) → gelen '?' ve ölçemedim +1; hiçbir mektup '•' ile basılmaz; kanarya 0" \
  "$(oz "$O12" gelen)/$(oz "$O12" olcemedim)/$(grep -cE '• (A|BA|ESKI)\.md' <<<"$O12")/$(kanarya)" "?/$(( $(oz "$O7" olcemedim) + 1 ))/0/0"
rmdir "$B/0-teslimat/.okundu"
# T5k · kurye-yokla.sh VAR, .okundu YOK, okundu.log da yok: damga basılmamış = hiç okunmamış (3); kurye koşturulmaz, okundu.log aranmaz, ölçemedim artmaz
O14="$(kos env)"
kapi "T5k kurye var, .okundu yok, okundu.log yok → üçü de okunmamış (3) + not 'okundu damgası yok … koşturulmadı … bakılmadı'; ölçemedim artmaz; kanarya 0" \
  "$(oz "$O14" gelen)/$(grep -c "okundu damgası yok (0-teslimat/.okundu yok; kutuda scripts/kurye-yokla.sh var, koşturulmadı; okundu.log'a bakılmadı)" <<<"$O14")/$(oz "$O14" olcemedim)/$(kanarya)" "3/1/$(oz "$O7" olcemedim)/0"
# T5l · kurye var, .okundu yok, yanında okundu.log VAR (BA okunmuş yazar): kurye kutusunun kaydı .okundu'dur — okundu.log'a BAKILMAZ (eski hata o dosyayı kayıt sanmaktı)
cp "$TMP/okundu.log.kenar" "$B/0-teslimat/okundu.log"
O15="$(kos env)"
kapi "T5l kurye var, .okundu yok, okundu.log var → yine 3 okunmamış (BA dahil); okundu.log'daki BA bilgisi KULLANILMAZ; not bakılmadığını söyler; kanarya 0" \
  "$(oz "$O15" gelen)/$(grep -c '• BA.md' <<<"$O15")/$(grep -c "okundu.log'a bakılmadı" <<<"$O15")/$(kanarya)" "3/1/1/0"
rm -f "$B/0-teslimat/okundu.log"
# T5m · kurye YOK ama .okundu VAR: kayıt dosyadır, kurye şart değil — yine .okundu okunur
rm -f "$B/scripts/kurye-yokla.sh"
printf 'BA.md\tsha256:%s\nA.md\n' "$(sha256sum "$B/0-teslimat/gelen/BA.md" | cut -d' ' -f1)" > "$B/0-teslimat/.okundu"
O16="$(kos env)"
kapi "T5m kurye yok, .okundu var → .okundu okunur: BA ve A okunmuş → gelen 1; not '.okundu dosyasından okundu'" \
  "$(oz "$O16" gelen)/$(grep -c '0-teslimat/.okundu dosyasından okundu' <<<"$O16")" "1/1"
# T5n · POZİTİF KONTROL — kanaryanın kendisi sağlam mı: kurye ELLE çağrılırsa iz bırakır ve .okundu'yu 3 satıra yeniden yazar;
#   kalan.sh onu koşturmuş olsaydı T5d/T5e/T5k/T5l kanarya 1 ve sayımlar kaymış görünürdü (ölçer ölçülmeden olumsuz hüküm yok)
cp "$TMP/kanarya.sh" "$B/scripts/kurye-yokla.sh"
bash "$B/scripts/kurye-yokla.sh" okundu-liste >/dev/null 2>&1
kapi "T5n pozitif kontrol: kanarya kurye elle çağrılınca iz bırakır (1) ve .okundu'yu 3 satıra yeniden yazar — yan etki görünür" \
  "$(kanarya)/$(grep -c . "$B/0-teslimat/.okundu")" "1/3"
rm -f "$B/0-teslimat/.kurye-cagrildi"
# T5g · kurye-yokla.sh de .okundu da okundu.log da yok: eski yol, dürüst not (hepsi okunmamış sayıldı + kutuda kurye-yokla.sh de yok)
rm -rf "$B/scripts" "$B/0-teslimat/.okundu"
O10="$(kos env)"
kapi "T5g kayıt da kurye-yokla.sh de yok: üçü de okunmamış (3) ve not 'okundu kaydı yok … kurye-yokla.sh de yok'" \
  "$(oz "$O10" gelen)/$(grep -c 'okundu kaydı yok .*kurye-yokla.sh de yok' <<<"$O10")" "3/1"
mv "$TMP/okundu.log.kenar" "$B/0-teslimat/okundu.log"

echo "── SONUÇ: geçti=$G kaldı=$K ölçemedim=$O3 ──"
[ "$K" -eq 0 ]
