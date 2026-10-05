#!/usr/bin/env bash
# kalan.sh — /gun-ortasi ADIM-1: "plan bitti, elde kalan iş var mı?" sorusunu ÖLÇER.
# SALT-OKUR: hiçbir dosyaya yazmaz. Ölçemediğini "ölçemedim" diye basar; #OZET'te o alan "?" olur.
# "ölçemedim" ASLA "iş yok" sayılmaz (unknown ≠ boş).
#
# Kaynaklar (kutudan bağımsız; olmayan kaynak ölçemedim olur, hata değil):
#   1 bugünün plan çıpası (gunluk-plan/cipa.sh oku) — "- [ ]" ve "- [~]" maddeler; başka günün çıpası SAYILMAZ
#   2 fabrika kartları (_agents/fabrika/kartlar/*.json) — açık; tıkandı ayrı; bozuk JSON ölçemedim
#   3 konum çapaları (_agents/handoff/*-durum.md, son N gün, son 120 satır) — açık/kalan/ayrı kart/SARI/SIRADA
#   4 bağımsız göz — her işin SON raporu: BAGIMSIZ-GOZ-kor-<n>.md YA DA fabrika denetçisinin DENETIM-<n>.json
#     (5·E değilse açık; md'de kapanmamış N/B/Y/NOT/SARI/ENGEL satırları)
#   5 gelen kutusu (0-teslimat/gelen) — okundu.log'da TAM adıyla olmayan HER mektup (pencere yok)
#   6 aktif layiha sayısı · 7 Sultan'ın kapısı · 8 hedef dosyaları · 9 ortam (dal, commit'siz, açık PR)
#
# ÇIKIŞ: 0 ölçüm bitti · 2 kullanım hatası. Son satır makine-okur:
#   #OZET cipa_acik= cipa_kapali= kart= tikandi= capa_acik= goz_acik= gelen= layiha= kapimda= commitsiz= pr= olcemedim=
#   göz sayımı: md raporunda BULGU başına, DENETIM json'da RAPOR başına (json bulgu listesi taşımıyor).
set -uo pipefail
SK="${GUN_ORTASI_SK:-/config/.claude/skills}"
KOK="${GUN_ORTASI_KOK:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
GUN="${GUN_ORTASI_GUN:-3}"
BUGUN="${GUN_ORTASI_TARIH:-$(date +%F)}"
TAVAN="${GUN_ORTASI_TAVAN:-10}"   # her bölümde EKRANA basılan satır tavanı — SAYIM tavandan önce yapılır
case "$GUN" in ''|*[!0-9]*) echo "GUN_ORTASI_GUN sayı olmalı" >&2; exit 2 ;; esac
case "$TAVAN" in ''|*[!0-9]*) echo "GUN_ORTASI_TAVAN sayı olmalı" >&2; exit 2 ;; esac
OLC=0
bolum(){ printf '\n━━━ %s ━━━\n' "$1"; }
olcemedim(){ printf '  ⚠️ ölçemedim: %s\n' "$1"; OLC=$((OLC+1)); }
# bas <metin> — tavana kadar bas, kırpılanı SÖYLE
bas(){ local n; n="$(printf '%s\n' "$1" | grep -c .)"; printf '%s\n' "$1" | grep . | head -"$TAVAN"
       [ "$n" -gt "$TAVAN" ] && printf '    … (+%s satır daha; sayım tamamını içerir)\n' "$((n-TAVAN))"; return 0; }

printf '🕛 GÜN ORTASI ÖLÇÜMÜ · %s · oda: %s · pencere: son %s gün\n' "$(date '+%F %H:%M')" "$(basename "$KOK")" "$GUN"

bolum "1/9 · Bugünün plan çıpası — kapanmamış madde"
CIPA_ACIK="?"; CIPA_KAPALI="?"
if [ -f "$SK/gunluk-plan/scripts/cipa.sh" ]; then
  c="$( (cd "$KOK" && bash "$SK/gunluk-plan/scripts/cipa.sh" oku) 2>/dev/null)"; r=$?
  if [ "$r" -ne 0 ] || [ -z "$c" ]; then olcemedim "çıpa yok (bugün /gunluk-plan çıpa yazmadı)"
  elif ! printf '%s\n' "$c" | grep -q "GÜNÜN PLANI ÇIPASI · $BUGUN"; then
    olcemedim "çıpa bugüne ait değil ($(printf '%s\n' "$c" | grep -o 'ÇIPASI · [0-9-]*' | head -1)) — eski plan 'sabahki plan' sayılmaz"
  else
    CIPA_ACIK="$(printf '%s\n' "$c" | grep -cE '^- \[( |~)\] ')"   # [-] = geri alındı: açık da kapalı da değil
    CIPA_KAPALI="$(printf '%s\n' "$c" | grep -cE '^- \[x\] ')"
    bas "$(printf '%s\n' "$c" | grep -E '^- \[.\] ' | cut -c1-170 | sed 's/^/  /')"
  fi
else olcemedim "gunluk-plan/cipa.sh bulunamadı"; fi

bolum "2/9 · Fabrika kartları — açık"
KART="?"; TIK="?"
KD="$KOK/_agents/fabrika/kartlar"
if [ -d "$KD" ] && command -v jq >/dev/null 2>&1; then
  KART=0; TIK=0; liste=""; bozuk=0
  for f in "$KD"/*.json; do
    [ -f "$f" ] || continue
    d="$(jq -r '.durum // empty' "$f" 2>/dev/null)" || d=""
    case "$d" in
      '') bozuk=$((bozuk+1)) ;;
      bitti) ;;
      tikandi) TIK=$((TIK+1)) ;;   # tavanda karar verilmiş iş — açık SAYILMAZ; kalanı 3-4. bölümde
      *) KART=$((KART+1)); liste+="  • $(basename "$f" .json) · $d"$'\n' ;;
    esac
  done
  if [ -n "$liste" ]; then bas "$liste"; else printf '  (açık kart yok)\n'; fi
  printf '  tıkandı (tavanda karar verilmiş, açık sayılmadı): %s\n' "$TIK"
  [ "$bozuk" -gt 0 ] && olcemedim "$bozuk kartın durumu okunamadı (bozuk/eksik JSON) — açık da kapalı da sayılmadı"
else olcemedim "kart dizini ya da jq yok: $KD"; fi

bolum "3/9 · Konum çapaları — açık satırlar (son $GUN gün)"
CAPA="?"
mapfile -t DURUMLAR < <(find "$KOK/_agents/handoff" -maxdepth 1 -name '*-durum.md' -mtime "-$GUN" 2>/dev/null)
if [ "${#DURUMLAR[@]}" -gt 0 ]; then
  CAPA=0
  for f in "${DURUMLAR[@]}"; do
    # yalnız son 120 satır: eski çapalar bugünün kalanı değildir
    s="$(tail -120 "$f" | grep -niE 'açık( liste)?[:)]|acik[:)]|kalan[:)]|ayrı kart|ayri kart|SARI|bekliyor|SIRADA')"
    [ -n "$s" ] || continue
    CAPA=$((CAPA+$(printf '%s\n' "$s" | grep -c .)))
    printf '  ▸ %s\n' "$(basename "$f")"; bas "$(printf '%s\n' "$s" | cut -c1-200 | sed 's/^/    /')"
  done
  [ "$CAPA" -eq 0 ] && printf '  (son çapalarda açık satır yok)\n'
else olcemedim "son $GUN günde değişmiş *-durum.md yok (bu kutuda çapa düzeni farklı olabilir)"; fi

bolum "4/9 · Bağımsız göz — her işin SON raporu (son $GUN gün)"
GOZ="?"
KK="$KOK/_agents/fabrika/kanit"
# liste satırı: "- N1 …" · başlık satırı YALNIZ "### N12 · …" / "### N12: …" biçiminde (kör-2 N3: "## NOT-1 (…) — görüşüm",
#   "B1 doğrulaması" gibi bölüm başlıkları bulgu sayılıyordu)
BULGU_RE='^\s*([-*]\s*\**(N[0-9]+|B[0-9]+|Y[0-9]+|NOT-?[0-9]*|SARI|ENGEL)|#{2,4}\s*\**(N[0-9]+|B[0-9]+|Y[0-9]+|NOT-?[0-9]+)\s*[·:])'
if [ -d "$KK" ]; then
  GOZ=0; rapor=0; okunamadi=0
  for is in "$KK"/*/; do
    md="$(find "$is" -maxdepth 1 -name 'BAGIMSIZ-GOZ-kor-*.md' -mtime "-$GUN" 2>/dev/null | sort -V | tail -1)"
    js="$(find "$is" -maxdepth 1 -name 'DENETIM-*.json' -mtime "-$GUN" 2>/dev/null | sort -V | tail -1)"
    # iki biçim de varsa daha YENİ olan işin son sözüdür
    son="$md"
    if [ -n "$js" ] && { [ -z "$md" ] || [ "$js" -nt "$md" ]; }; then son="$js"; fi
    [ -n "$son" ] || continue
    rapor=$((rapor+1)); ad="$(basename "$is")"
    case "$son" in
      *.json)
        p=""; command -v jq >/dev/null 2>&1 && p="$(jq -r '[(.sonuc.kod_puani // "?"|tostring), (.sonuc.dogru_sey // "?")] | join("·")' "$son" 2>/dev/null)"
        case "$p" in ''|*'?'*) okunamadi=$((okunamadi+1)); continue ;; esac
        if [ "$p" != "5·E" ]; then
          GOZ=$((GOZ+1)); printf '  ▸ %s (%s · %s) — %s\n' "$ad" "$(basename "$son")" "$p" "$(jq -r '.sonuc.ozet // ""' "$son" 2>/dev/null | cut -c1-150)"
        fi ;;
      *)
        p="$(sed -n '1,4p' "$son" | grep -oE '(KOD İYİ Mİ|DOĞRU ŞEY Mİ): *[0-9EH]' | grep -oE '[0-9EH]$' | awk 'NR>1{printf "·"} {printf "%s",$0}')"   # tr bayt işler, "·" çok baytlı — awk ile birleştir
        case "$p" in [0-5]·[EH]) ;; *) okunamadi=$((okunamadi+1)); continue ;; esac
        # kapanmamış bulgu: liste ya da başlık satırı. Yalın "KAPANDI" / "ENGEL yok" / BİLGİ düşer;
        # "KISMEN KAPANDI" AÇIK kalır (kör-1: düşürülüyordu).
        # (harf çevirmeden: awk/toupper Türkçe "ı"yı çevirmez — "kapandı" KAPANDI'ya dönmüyordu)
        hepsi="$(grep -E "$BULGU_RE" "$son" 2>/dev/null | grep -viE 'ENGEL\W*(yok|bulunmad)|BİLGİ|BILGI|bilgi notu|zararsız')"
        b="$( { printf '%s\n' "$hepsi" | grep -iE 'kısmen|kismen|KISMEN'; printf '%s\n' "$hepsi" | grep -viE 'kısmen|kismen|KISMEN' | grep -viE 'kapand|KAPAND'; } | grep .)"
        n=0; [ -n "$b" ] && n="$(printf '%s\n' "$b" | grep -c .)"
        if [ "$p" != "5·E" ] || [ "$n" -gt 0 ]; then
          if [ "$n" -gt 0 ]; then GOZ=$((GOZ+n)); else GOZ=$((GOZ+1)); fi
          printf '  ▸ %s (%s · %s)\n' "$ad" "$(basename "$son")" "$p"
          [ "$n" -gt 0 ] && bas "$(printf '%s\n' "$b" | cut -c1-180 | sed 's/^/    /')"
        fi ;;
    esac
  done
  [ "$rapor" -eq 0 ] && printf '  (son %s günde bağımsız göz raporu yok)\n' "$GUN"
  [ "$okunamadi" -gt 0 ] && olcemedim "$okunamadi raporun puanı okunamadı (biçim tanınmadı) — açık sayılmadı"
  okunan=$((rapor-okunamadi))
  [ "$okunan" -gt 0 ] && [ "$GOZ" -eq 0 ] && printf '  (okunan %s işin son raporu 5·E ve açık bulgu yok)\n' "$okunan"
  printf '  not: bu liste ADAY listesidir — "hâlâ açık mı" ADIM 2 ile kodda/commit'"'"'te doğrulanır\n'
else olcemedim "kanıt dizini yok: $KK"; fi

bolum "5/9 · Gelen kutusu — okunmamış (pencere yok)"
GELEN="?"
GD="$KOK/0-teslimat/gelen"; OK="$KOK/0-teslimat/okundu.log"
if [ -d "$GD" ]; then
  GELEN=0; liste=""; okunan=""
  [ -f "$OK" ] && okunan="$(awk -F' [|] ' '{print $3}' "$OK" 2>/dev/null)"
  while IFS= read -r f; do
    a="$(basename "$f")"
    printf '%s\n' "$okunan" | grep -qxF -- "$a" && continue   # TAM ad eşleşmesi (ad parçası değil)
    GELEN=$((GELEN+1)); liste+="  • $a ($(date -r "$f" +%F))"$'\n'
  done < <(find "$GD" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
  if [ -n "$liste" ]; then bas "$liste"; else printf '  (okunmamış mektup yok)\n'; fi
  [ -f "$OK" ] || printf '  not: okundu.log yok — listelenenlerin hepsi okunmamış sayıldı\n'
else olcemedim "gelen kutusu yok: $GD (bu kutuda mektup düzeni farklı olabilir)"; fi

bolum "6/9 · Aktif layiha (inşa bekleyen)"
LAY="?"
if [ -f "$SK/layiha/scripts/layiha-defteri.sh" ]; then
  l="$( (cd "$KOK" && bash "$SK/layiha/scripts/layiha-defteri.sh" liste --aktif) 2>/dev/null)"
  if [ -n "$l" ]; then LAY="$(printf '%s\n' "$l" | grep -cE '^  \[[^]]+\]')"; printf '  toplam aktif: %s\n' "$LAY"
  else olcemedim "layiha defteri okunamadı (sıfır SAYILMADI)"; fi
else olcemedim "layiha-defteri.sh yok"; fi

bolum "7/9 · Sultan'ın kapısı"
KAP="?"
if [ -f "$SK/kapimda/scripts/kapimda.sh" ]; then
  k="$(bash "$SK/kapimda/scripts/kapimda.sh" liste --hepsi 2>/dev/null)"; r=$?
  if [ "$r" -eq 0 ] && [ -n "$k" ]; then KAP="$(printf '%s\n' "$k" | grep -cE '^\s*•')"; bas "$k"
  else olcemedim "kapımda listelenemedi (rc=$r)"; fi
else olcemedim "kapimda.sh yok"; fi

bolum "8/9 · Hedefler (iş kalmadıysa fikirler BUNLARA bağlanır)"
H=0
for f in "$KOK/_agents/ANA-HEDEF.md" "$KOK/ANA-HEDEF.md"; do
  if [ -f "$f" ]; then
    printf '  ▸ %s (değişim: %s)\n' "${f#"$KOK"/}" "$(date -r "$f" +%F)"
    bas "$(grep -E '^#|^\s*[-*0-9]' "$f" | cut -c1-170 | sed 's/^/    /')"; H=1; break
  fi
done
if [ -f "$KOK/CLAUDE.md" ]; then
  a="$(awk '/^## Amaç/{f=1;next} /^## /{f=0} f' "$KOK/CLAUDE.md" | grep .)"
  [ -n "$a" ] && { printf '  ▸ CLAUDE.md · Amaç\n'; bas "$(printf '%s\n' "$a" | cut -c1-170 | sed 's/^/    /')"; H=1; }
fi
[ "$H" -eq 0 ] && olcemedim "hedef dosyası yok (ANA-HEDEF.md / CLAUDE.md Amaç) — fikir önerilirse hedefsiz olur, Sultan'a sor"

bolum "9/9 · Ortam (dal · commit'siz · açık PR)"
COMMITSIZ="?"; PR="?"
if git -C "$KOK" rev-parse >/dev/null 2>&1; then
  COMMITSIZ="$(git -C "$KOK" status --porcelain 2>/dev/null | grep -c .)"
  printf '  %s · commit'"'"'siz dosya: %s\n' "$(git -C "$KOK" status -sb 2>/dev/null | head -1)" "$COMMITSIZ"
else olcemedim "git deposu değil: $KOK"; fi
if command -v gh >/dev/null 2>&1; then
  if pr="$( (cd "$KOK" && gh pr list --state open --limit 20 --json number,title,createdAt -q '.[]|"  #\(.number)  \(.createdAt[0:10])  \(.title[0:70])"') 2>/dev/null)"; then
    PR="$(printf '%s\n' "$pr" | grep -c .)"; if [ -n "$pr" ]; then bas "$pr"; else printf '  (açık PR yok)\n'; fi
  else olcemedim "açık PR listelenemedi (gh)"; fi
else olcemedim "gh yok — açık PR ölçülmedi"; fi

printf '\n#OZET\tcipa_acik=%s\tcipa_kapali=%s\tkart=%s\ttikandi=%s\tcapa_acik=%s\tgoz_acik=%s\tgelen=%s\tlayiha=%s\tkapimda=%s\tcommitsiz=%s\tpr=%s\tolcemedim=%s\n' \
  "$CIPA_ACIK" "$CIPA_KAPALI" "$KART" "$TIK" "$CAPA" "$GOZ" "$GELEN" "$LAY" "$KAP" "$COMMITSIZ" "$PR" "$OLC"
