#!/usr/bin/env bash
# koltuk-bagla.test.sh — koltuk seçicinin kapıları. HERMETİK: sahte tmux ile koşar, gerçek oturuma dokunmaz.
# Ağırlık merkezi RED yüzü: adresten gelen ad uydurulamaz, altyapı oturumu açılamaz, yeni oturum doğmaz.
set -uo pipefail
cd "$(dirname "$0")"
B="$PWD/koltuk-bagla.sh"
GECEN=0; DUSEN=0
ok()  { GECEN=$((GECEN+1)); echo "  ✓ $1"; }
bad() { DUSEN=$((DUSEN+1)); echo "  ✗ $1 — $2"; }
S="$(mktemp -d)"; trap 'rm -r -f -- "$S" 2>/dev/null' EXIT
mkdir -p "$S/bin"
# Sahte tmux: oturum listesi $S/oturumlar'dan; "çalıştırılan" komutlar $S/iz'e yazılır.
cat > "$S/bin/tmux" <<'T'
#!/usr/bin/env bash
case "$1" in
  list-sessions) [ -n "${SAHTE_BOZUK:-}" ] && { echo "error connecting to /tmp/tmux-1000/default (Permission denied)" >&2; exit 1; }
                 [ -n "${SAHTE_SUNUCU_YOK:-}" ] && { echo "no server running on /tmp/tmux-1000/default" >&2; exit 1; }
                 case "$3" in *session_activity*) sed 's/$/\t1760000000/' "$SAHTE/oturumlar" ;; *) cat "$SAHTE/oturumlar" ;; esac ;;
  list-panes)    if [ "$2" = -a ]; then   # tüm bölmeler: ad·pencere-etkin·bölme-etkin·kimlik·pid·komut (kimlik = %ad, sahte)
                   while IFS= read -r n; do case "$n" in BASIRET|cc-1|ZAKIR|KALFA|NEDIM|MUHASIP) k=claude; p=100 ;; *) k=bash; p=200 ;; esac
                     printf '%s\t1\t1\t%%%s\t%s\t%s\n' "$n" "$n" "$p" "$k"; done < "$SAHTE/oturumlar"
                 else t="${4#=}"; case "$t" in BASIRET|cc-1|ZAKIR|KALFA|NEDIM|MUHASIP) echo "100 claude" ;; *) echo "200 bash" ;; esac; fi ;;
  display-message) echo 1760000000 ;;
  capture-pane)  case "$4" in =*) echo "can't find pane: $4" >&2; exit 1 ;; esac   # gerçek tmux gibi: bölme hedefinde '=ad' geçersiz
                 case "$4" in %*) t="${4#%}" ;; *) t="${4%:}" ;; esac; [ -f "$SAHTE/ekran-$t" ] && cat "$SAHTE/ekran-$t" || exit 1 ;;
  list-windows)  echo "@1" ;;
  set-option)    : ;;
  new-session|attach-session) echo "$*" >> "$SAHTE/iz"; exit 0 ;;
  *) exit 1 ;;
esac
T
printf '#!/usr/bin/env bash\nexit 1\n' > "$S/bin/pgrep"
chmod +x "$S/bin/tmux" "$S/bin/pgrep"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"
kos() { : > "$S/iz"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" "$@" > "$S/cikti" 2>&1; echo $? > "$S/rc"; }
iz()  { cat "$S/iz"; }
rc()  { cat "$S/rc"; }

echo "A · bağlanma (kabul yüzü)"
kos maiset-ana /p
[ "$(iz)" = "new-session -A -s maiset-ana -c /p" ] && ok "A1 argümansız → ana oturum (bugünkü davranış aynı)" || bad A1 "$(iz)"
kos maiset-ana /p BASIRET
[ "$(iz)" = "attach-session -t =BASIRET" ] && ok "A2 var olan koltuk → TAM eşleşmeli hedefle (=ad) bağlanır" || bad A2 "$(iz)"
kos maiset-ana /p maiset-ana
[ "$(iz)" = "attach-session -t =maiset-ana" ] && ok "A3 ana oturumun adı açıkça verilirse de beyaz listeden geçer (VAR → bağlanır, yaratmaz)" || bad A3 "$(iz)"
printf '%s\n' BASIRET CARSI imglistener > "$S/oturumlar"
kos maiset-ana /p maiset-ana
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "A4 🔴 ana oturum YOKKEN adı açıkça verilirse YARATILMAZ (beyaz liste delinmez)" || bad A4 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p
[ "$(iz)" = "new-session -A -s maiset-ana -c /p" ] && ok "A5 ... ama argümansız yol ana oturumu yine açar (A4 tautoloji değil)" || bad A5 "$(iz)"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"

echo "B · red yüzü (adres güvenilmez girdi)"
kos maiset-ana /p YOKKOLTUK
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "B1 kutuda olmayan ad → rc=3, YENİ OTURUM AÇILMAZ" || bad B1 "rc=$(rc) iz=$(iz)"
grep -q "koltuk yok" "$S/cikti" && ok "B2 red sessiz değil: sebebi ekrana basılır" || bad B2 "$(cat "$S/cikti")"
for g in ttyd-maiset kapi-maiset maiset-kurtarici imglistener; do
  kos maiset-ana /p "$g"
  [ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "B3 altyapı oturumu açılamaz: $g" || bad "B3 $g" "rc=$(rc) iz=$(iz)"
done
for k in 'BASIRET:0' 'BASIRET.1' '=BASIRET' '^' 'a b' '../x' "$(printf 'x%.0s' {1..70})" ; do
  kos maiset-ana /p "$k"
  [ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "B4 tmux hedef sözdizimi/kaçış reddedilir: '${k:0:12}'" || bad "B4 $k" "rc=$(rc) iz=$(iz)"
done
kos maiset-ana /p BASIRET CARSI
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && grep -q "birden çok" "$S/cikti" && ok "B7 🔴 birden çok arg (?arg=X&arg=Y) → red, ilki seçilmez" || bad B7 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p BASIRET BASIRET
[ "$(rc)" = 3 ] && ok "B8 aynı ad iki kez de belirsizdir, red" || bad B8 "rc=$(rc)"
kos maiset-ana /p basiret
[ "$(rc)" = 3 ] && ok "B5 harf büyüklüğü tam eşleşir (basiret ≠ BASIRET)" || bad B5 "rc=$(rc)"
kos maiset-ana /p 'BASIRE'
[ "$(rc)" = 3 ] && ok "B6 önek eşleşmez (BASIRE ≠ BASIRET)" || bad B6 "rc=$(rc)"

echo "D · tür ve hâl (2.2.0: ajan ⟂ diğer · hâl son ekrandan, filo desenleri)"
# ── E · adında '/' olan oturum (dilim 5/7 · SERDAR ölçtü: vekatip '2026/85' listeden düşmüştü) ──
printf '%s\n' maiset-ana BASIRET '2026/85' 'a b' imglistener > "$S/oturumlar"
: > "$S/iz"; : > "$S/rc"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" maiset-ana /proje '2026/85' >/dev/null 2>&1
[ "$(iz)" = "attach-session -t =2026/85" ] && ok "E1 '/' içeren koltuk TAM eşleşmeli hedefle (=2026/85) bağlanır (eski desen reddediyordu)" || bad E1 "$(iz)"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste-e"
grep -qP '^2026/85\t' "$S/liste-e" && ok "E2 '/' içeren koltuk LİSTEDE (düşmez)" || bad E2 "$(cat "$S/liste-e")"
: > "$S/iz"; : > "$S/rc"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" maiset-ana /proje 'a b' >/dev/null 2>&1
[ "$(iz)" = "attach-session -t =a b" ] && ok "E3 arada boşluklu ad TAM eşleşmeli hedefle bağlanır (tmux izin verir — bağımsız göz tur 1)" || bad E3 "$(iz)"
: > "$S/iz"; : > "$S/rc"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" maiset-ana /proje ' a' >/dev/null 2>&1
[ -z "$(iz)" ] && ok "E3b başta boşluklu ad reddedilir (kesilip başka ada dönüşür)" || bad E3b "$(iz)"
printf '%s\n' maiset-ana BASIRET CARSI cc-1 dash ZAKIR KALFA NEDIM MUHASIP imglistener > "$S/oturumlar"
printf '%s\n' "⏺ Düşünüyor…" "esc to interrupt" > "$S/ekran-BASIRET"
printf '%s\n' "Do you want to proceed?" "❯ 1. Yes" "  2. No" "Esc to cancel)" > "$S/ekran-ZAKIR"   # meşgul izi (esc to cancel) + soru → SORU kazanır
printf '%s\n' "You've hit your usage limit · limit reached" "❯ " > "$S/ekran-KALFA"
printf '%s\n' "önceki çıktı" "❯ yarım kalmış bir cümle" > "$S/ekran-NEDIM"
printf '%s\n' "bitti." "" "❯ " > "$S/ekran-MUHASIP"
printf '%s\n' "sadece metin, istem yok" > "$S/ekran-cc-1"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
al() { grep -P "^$1\t" "$S/liste" | cut -f"$2"; }
[ "$lrc" = 0 ] && [ "$(head -1 "$S/liste" | awk -F'\t' '{print NF}')" = 7 ] && ok "D1 liste 7 alan: ad · son · claude · tür · hâl · ne · hesap (2.14.0)" || bad D1 "rc=$lrc $(head -1 "$S/liste")"
[ "$(al BASIRET 4)" = ajan ] && ok "D2 Claude çalışan oturum 'ajan'" || bad D2 "$(al BASIRET 4)"
[ "$(al maiset-ana 4)" = diger ] && ok "D2b Claude'suz ANA oturum da 'diğer' (istisna yok; önde durması 'ana' bayrağının işi)" || bad D2b "$(al maiset-ana 4)"
[ "$(al CARSI 4)" = diger ] && [ "$(al dash 4)" = diger ] && ok "D3 Claude'suz oturum ve dash* 'diğer'" || bad D3 "$(al CARSI 4)/$(al dash 4)"
[ "$(al cc-1 4)" = diger ] && ok "D4 cc-* Claude çalışsa da 'diğer' (geçici oturum)" || bad D4 "$(al cc-1 4)"
[ "$(al BASIRET 5)" = calisiyor ] && ok "D5 'esc to interrupt' → çalışıyor" || bad D5 "$(al BASIRET 5)"
[ "$(al ZAKIR 5)" = soru ] && ok "D6 'Do you want to' + 'Esc to cancel' birlikte → SORU kazanır (meşgul izi soruyu gizlemez)" || bad D6 "$(al ZAKIR 5)"
[ "$(al KALFA 5)" = sinirda ] && ok "D7 'usage limit' → sınırda" || bad D7 "$(al KALFA 5)"
[ "$(al NEDIM 5)" = girdi ] && [ "$(al MUHASIP 5)" = bos ] && ok "D8 istemde yazı → girdi bekliyor · boş istem → boş" || bad D8 "$(al NEDIM 5)/$(al MUHASIP 5)"
[ "$(al cc-1 5)" = bilinmiyor ] && ok "D9 hiçbir desen tutmazsa 'bilinmiyor' (uydurma yok)" || bad D9 "$(al cc-1 5)"
[ "$(al CARSI 5)" = bilinmiyor ] && ok "D10 Claude'suz oturumun hâli ölçülmez: 'bilinmiyor' (altı değer dışına çıkılmaz)" || bad D10 "$(al CARSI 5)"
# D12: yalnız SON 15 dolu satır sayılır — 20 satır yukarıdaki eski 'esc to interrupt' güncel boş istemi 'çalışıyor' yapamaz
{ echo "esc to interrupt"; for i in $(seq 1 20); do echo "çıktı satırı $i"; done; echo "❯ "; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste3"
[ "$(grep -P '^BASIRET\t' "$S/liste3" | cut -f5)" = bos ] && ok "D12 eski satırdaki meşgul izi sayılmaz: son 15 satırda boş istem → boş" || bad D12 "$(grep -P '^BASIRET\t' "$S/liste3" | cut -f5)"
{ for i in $(seq 1 20); do echo "çıktı satırı $i"; done; echo "⏺ Düşünüyor…"; echo "esc to interrupt"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste4"
[ "$(grep -P '^BASIRET\t' "$S/liste4" | cut -f5)" = calisiyor ] && ok "D12b güncel meşgul izi (son satırlarda) → çalışıyor (D12 tautoloji değil)" || bad D12b "$(grep -P '^BASIRET\t' "$S/liste4" | cut -f5)"
# D13 · 5. HÂL ⏳ dış olay bekliyor (Sultan 15 Eki): yazı kutusu boş + "2 shells running" → dis-olay, 6. sütun ne beklediği
{ echo "⏺ CI bekleniyor; bildirim gelince devam."; echo "❯ "; echo "──────"; echo "  2 shells still running · ⏵⏵ auto mode"; } > "$S/ekran-BASIRET"
printf '%s\n' "Bitti." "❯ " > "$S/ekran-KALFA"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste5"
[ "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f5)" = dis-olay ] && ok "D13 boş kutu + 'shells running' → ⏳ dış olay bekliyor (çalışıyor DEĞİL, boş DEĞİL)" || bad D13 "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f5)"
[ "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f6)" = "CI bekleniyor; bildirim gelince devam." ] && ok "D13b ne beklediği --liste 6. sütununda NEDEN olarak (açıklayıcı son mesaj kabuk sayısından önce; göz tur 4); çizim cloudtop #621'in" || bad D13b "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f6)"
{ echo "⏺ Bitti."; echo "❯ "; echo "──────"; echo "  2 shells still running · ⏵⏵ auto mode"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste5b"
[ "$(grep -P '^BASIRET\t' "$S/liste5b" | cut -f5)" = dis-olay ] && [[ "$(grep -P '^BASIRET\t' "$S/liste5b" | cut -f6)" == *"2 shells still running"* ]] && ok "D13b2 açıklayıcı mesaj yoksa 'ne' kabuk sayısını taşır (hâl yine dış olay)" || bad D13b2 "$(grep -P '^BASIRET\t' "$S/liste5b" | cut -f5-6)"
[ "$(grep -P '^KALFA\t' "$S/liste5" | cut -f5)" = bos ] && [ -z "$(grep -P '^KALFA\t' "$S/liste5" | cut -f6)" ] && ok "D13c boş kutu, bekleme izi yok → boş; ne sütunu BOŞ (uydurulmaz)" || bad D13c "$(grep -P '^KALFA\t' "$S/liste5" | cut -f5-6)"
{ echo "❯ "; echo "  2 shells still running"; echo "⏺ Düşünüyor…"; echo "esc to interrupt"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste6"
[ "$(grep -P '^BASIRET\t' "$S/liste6" | cut -f5)" = calisiyor ] && ok "D13d meşgul izi varken 'shells running' çalışıyor'u GİZLEMEZ (öncelik: çalışıyor > dış olay)" || bad D13d "$(grep -P '^BASIRET\t' "$S/liste6" | cut -f5)"
# D13e: ESKİ bir "bekleniyor" (10 satır yukarıda) güncel boş istemi dış olay YAPMAZ — yalnız son 5 satır sayılır (bağımsız göz tur 1)
{ echo "⏺ CI bekleniyor; bildirim gelince devam."; for i in $(seq 1 10); do echo "çıktı satırı $i"; done; echo "⏺ Bitti, kapattım."; echo "❯ "; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste7"
[ "$(grep -P '^BASIRET\t' "$S/liste7" | cut -f5)" = bos ] && ok "D13e eski 'bekleniyor' satırı (son 5 dışı) dış olay sayılmaz → boş" || bad D13e "$(grep -P '^BASIRET\t' "$S/liste7" | cut -f5)"
# D13f: son 5 satır İÇİNDE "bekleniyor" ama ardından "⏺ Bitti" + boş istem → bekleme bitmiş, dış olay DEĞİL → boş (bağımsız göz tur 3)
{ for i in $(seq 1 10); do echo "çıktı satırı $i"; done; echo "⏺ CI bekleniyor; bildirim gelince devam."; echo "⏺ Bitti, kapattım."; echo "❯ "; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste8"
[ "$(grep -P '^BASIRET\t' "$S/liste8" | cut -f5)" = bos ] && [ -z "$(grep -P '^BASIRET\t' "$S/liste8" | cut -f6)" ] && ok "D13f son 5 satırda 'bekleniyor' + sonra '⏺ Bitti' + boş istem → boş (bitmiş bekleme dış olay sayılmaz)" || bad D13f "$(grep -P '^BASIRET\t' "$S/liste8" | cut -f5-6)"
# D13g: alt çubuk sinyali mesajdan bağımsız — "⏺ Bitti" sonrası bile "2 shells still running" çubuğu varsa dış olay (çubuk istemin ALTINDADIR)
{ echo "⏺ Bitti, kapattım."; echo "❯ "; echo "──────"; echo "  2 shells still running"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste9"
[ "$(grep -P '^BASIRET\t' "$S/liste9" | cut -f5)" = dis-olay ] && ok "D13g 'shells running' çubuğu son mesaja bakmaz → dış olay" || bad D13g "$(grep -P '^BASIRET\t' "$S/liste9" | cut -f5)"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"; rm -f "$S"/ekran-*

echo "C · liste (tek kaynak)"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
[ "$lrc" = 0 ] && ok "C1 --liste rc=0" || bad C1 "rc=$lrc"
[ "$(cut -f1 "$S/liste" | tr '\n' ' ')" = "maiset-ana BASIRET CARSI " ] && ok "C2 gizliler listede YOK, görünürler sırasıyla var" || bad C2 "$(cut -f1 "$S/liste" | tr '\n' ' ')"
[ "$(grep -P '^BASIRET\t' "$S/liste" | cut -f3)" = 1 ] && [ "$(grep -P '^CARSI\t' "$S/liste" | cut -f3)" = 0 ] && ok "C3 Claude çalışan koltuk işaretli, çalışmayan değil" || bad C3 "$(cat "$S/liste")"
[ "$(grep -P '^CARSI\t' "$S/liste" | cut -f2)" = 1760000000 ] && ok "C4 son etkinlik tmux'tan okunur" || bad C4 "$(cat "$S/liste")"
: > "$S/oturumlar"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
[ "$lrc" = 0 ] && [ ! -s "$S/liste" ] && ok "C5 hiç oturum yoksa boş liste (uydurma yok)" || bad C5 "rc=$lrc"
SAHTE_BOZUK=1 SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste" 2>"$S/hata"; lrc=$?
[ "$lrc" = 3 ] && [ ! -s "$S/liste" ] && grep -q "ölçülemedi" "$S/hata" && ok "C6 🔴 tmux listesi ALINAMAZSA boş liste DEĞİL rc=3 'ölçülemedi' (C5 tautoloji değil)" || bad C6 "rc=$lrc"
SAHTE_SUNUCU_YOK=1 SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
[ "$lrc" = 0 ] && [ ! -s "$S/liste" ] && ok "C7 tmux sunucusu hiç yoksa gerçekten boş: rc=0" || bad C7 "rc=$lrc"
printf '%s\n' maiset-ana BASIRET > "$S/oturumlar"
SAHTE_BOZUK=1 kos maiset-ana /p BASIRET
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "C8 liste alınamazken koltuğa da BAĞLANILMAZ (yanlış 'yok' demez, red basar)" || bad C8 "rc=$(rc) iz=$(iz)"


# ── H · hesap sütunu (2.14.0 · G-BANI-0008 E1 zemini): koltuktaki Claude'un hesap ADI sürecin ortamından; kural hesap_kutu.py hesap_adi ile aynı ──
# Sahte /proc: HESAP_PROC_KOK=$S/proc; sahte tmux claude bölmelerine pid 100 verir → $S/proc/100/environ. Kök/taban da sahte (gerçek /config okunmaz).
echo "H · hesap (sürecin ortamından AD; değer değil)"
mkdir -p "$S/proc/100" "$S/hes/sgk1"
hk() { HESAP_PROC_KOK="$S/proc" HESAP_KOK="$S/hes" HESAP_TABAN="$S/taban" SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/listeH" 2>/dev/null; grep -P "^$1\t" "$S/listeH" | cut -f7; }
printf '%s\n' maiset-ana BASIRET CARSI > "$S/oturumlar"
printf 'HOME=/config\0CLAUDE_CONFIG_DIR=%s\0PATH=/usr/bin\0' "$S/hes/sgk1" > "$S/proc/100/environ"
[ "$(hk BASIRET)" = sgk1 ] && ok "H1 CLAUDE_CONFIG_DIR=<kök>/sgk1 → hesap sgk1 (adlı hesap)" || bad H1 "$(hk BASIRET)"
[ -z "$(hk CARSI)" ] && ok "H2 Claude'suz koltukta hesap sütunu BOŞ (uydurulmaz)" || bad H2 "'$(hk CARSI)'"
printf 'HOME=/config\0PATH=/usr/bin\0' > "$S/proc/100/environ"
[ "$(hk BASIRET)" = varsayilan ] && ok "H3 CLAUDE_CONFIG_DIR yok → varsayilan" || bad H3 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=%s/\0' "$S/taban" > "$S/proc/100/environ"
[ "$(hk BASIRET)" = varsayilan ] && ok "H4 CLAUDE_CONFIG_DIR taban dizinin kendisi (sondaki / ile) → varsayilan (normpath eşdeğeri)" || bad H4 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=%s\0ANTHROPIC_BASE_URL=http://cloudtop-kapi:4000\0' "$S/hes/sgk1" > "$S/proc/100/environ"
[ "$(hk BASIRET)" = kapi ] && ok "H5 ANTHROPIC_BASE_URL varsa → kapi (kapı şeridi hesabı EZER; adlı hesap yazsa da)" || bad H5 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=/opt/baska/yer\0' > "$S/proc/100/environ"
[ "$(hk BASIRET)" = bilinmiyor:dizin ] && ok "H6 kök dışı dizin → bilinmiyor:dizin (ad uydurulmaz)" || bad H6 "$(hk BASIRET)"
rm -f "$S/proc/100/environ"
[ "$(hk BASIRET)" = bilinmiyor:okunamadi ] && ok "H7 🔴 ortam okunamazsa 'bilinmiyor:okunamadi' — varsayilan DENMEZ (ölçülemedi ≠ varsayılan)" || bad H7 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=%s\0' "$S/hes/sgk1" > "$S/proc/100/environ"
printf '❯ \n' > "$S/ekran-BASIRET"
[ "$(hk BASIRET)" = sgk1 ] && [ "$(grep -P '^BASIRET\t' "$S/listeH" | cut -f5)" = bos ] && [ "$(grep -P '^BASIRET\t' "$S/listeH" | cut -f3)" = 1 ] && ok "H8 hesap sütunu öteki sütunları bozmaz (3. claude=1, 5. hâl=boş, 7. hesap)" || bad H8 "$(grep -P '^BASIRET\t' "$S/listeH")"
rm -f "$S/ekran-BASIRET"
# kimlik DEĞERİ hiçbir yolda okunmaz: betikte .credentials.json adı geçmez (okuma yolu yok)
grep -q "credentials" "$B" && bad H9 "betikte kimlik dosyası adı geçiyor" || ok "H9 betik kimlik dosyasına (.credentials.json) hiç dokunmaz"
# Nexus kuralıyla eşdeğerlik (hesap_kutu.py bu kutuda varsa): aynı girdiler iki dilde aynı adı vermeli
HK=/config/projects/Nexus/scripts/hesap_kutu.py
if [ -f "$HK" ]; then
  py() { HESAP_KOK="$S/hes" HESAP_TABAN="$S/taban" python3 -c "import sys; sys.argv=['x']; exec(open('$HK').read().split('\ndef _ad_gecerli')[0]);
import os
def hesap_adi(ccd, kapi):
    if kapi: return 'kapi'
    if not ccd or os.path.normpath(ccd) == os.path.normpath(TABAN): return 'varsayilan'
    if os.path.dirname(os.path.normpath(ccd)) == os.path.normpath(KOK): return os.path.basename(os.path.normpath(ccd))
    return 'bilinmiyor:dizin'
print(hesap_adi('$1', $2))"; }
  sh_adi() { HESAP_KOK="$S/hes" HESAP_TABAN="$S/taban" bash -c "source <(sed -n '/^HESAP_KOK=/,/^koltuk_hesabi()/p' '$B' | sed '\$d'); hesap_adi \"\$1\" \"\$2\"" _ "$1" "$2"; }
  esit=1
  for g in "$S/hes/sgk1|0" "|0" "$S/taban/|0" "$S/hes/sgk1|1" "/opt/baska/yer|0" "$S/hes//sgk1/|0" "$S/hes/x/../sgk1|0" "$S/hes/./sgk1/.|0" "$S/hes/sgk1/..|0" "/../$S/hes/sgk1|0" "$S/taban/../taban|0"; do
    ccd="${g%|*}"; kp="${g#*|}"; a="$(py "$ccd" "$([ "$kp" = 1 ] && echo True || echo False)")"; b="$(sh_adi "$ccd" "$kp")"
    [ "$a" = "$b" ] || { esit=0; echo "    fark: '$ccd' kapi=$kp → py=$a sh=$b"; }
  done
  [ "$esit" = 1 ] && ok "H10 kabuk hesap_adi == Nexus hesap_kutu.py hesap_adi (11 girdi: çift eğik · sondaki / · . · .. · kökte ..)" || bad H10 "iki dil ayrıştı"
else
  echo "  · H10 atlandı: hesap_kutu.py bu kutuda yok (eşdeğerlik Nexus kutusunda ölçülür)"
fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[ "$DUSEN" -eq 0 ]
