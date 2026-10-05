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
  [ -f "$a" ] && { printf '%s' "$a"; return; }
  [ -f "$b" ] && { printf '%s' "$b"; return; }
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

echo "── SONUÇ: geçti=$G kaldı=$K ölçemedim=$O3 ──"
[ "$K" -eq 0 ]
