#!/usr/bin/env bash
# koltuk-bagla.sh — kutunun KOLTUKLARI (tmux oturumları) için tek kaynak.
#
#   koltuk-bagla.sh <ana-oturum> <proje-dizini> [koltuk]   ttyd'nin çalıştırdığı komut (ttyd -a: adresteki
#                                                          ?arg=<koltuk> buraya SON argüman olarak eklenir)
#                                                          TELEFON KİPİ (2.25.0): ?arg=tel. (ana oturum) · ?arg=tel.<koltuk|kimlik> →
#                                                          tmux'a '-f ignore-size' ile bağlanır: telefon pencere boyunu ETKİLEMEZ, masaüstü daralmaz
#   koltuk-bagla.sh --tel-buyut <istemci>                  (2.36.5) telefon kancasının çağrısı: ignore-size istemcinin boyuna pencereyi YALNIZ BÜYÜTÜR
#   koltuk-bagla.sh --gizli                                listede OLMAYAN oturumlar, gerekçesiyle: ad · neden (G-BANI-0007:
#                                                          sessiz düşürme yok — gizlenen her oturum adıyla ve nedeniyle sayılır)
#   koltuk-bagla.sh --bos                                  BOŞ KABUK oturumlar (2.5.0): hiçbir bölmesinde Claude yok VE her bölmede
#                                                          yalnız kabuk istemi var (altında hiçbir süreç yok). Sunucu/izleme koşan
#                                                          Claude'suz oturum boş DEĞİLDİR (ör. nova/kesif-ui web sunucusu).
#   koltuk-bagla.sh --liste                                görünür koltuklar, sekmeyle: ad · son-etkinlik(epoch) · claude(1|0) · tür(ajan|diger) · hâl · ne · hesap · soru
#                                                          soru (2.23.0 · K1 Engel kurgusu): hâl 'soru' iken tek satır JSON {tur menu|serbest, metin, siklar, beri}
#                                                          (kapi/soru.mjs; sır süzgecinden geçmiş); başka hâlde ya da okunamazsa boş — uydurulmaz.
#                                                          hesap (2.14.0 · G-BANI-0008 E1 zemini): koltuktaki Claude'un HESAP ADI — kapi · varsayilan · <ad> ·
#                                                          bilinmiyor:<neden>; Claude'suz koltukta boş. Sürecin ortamından AD türetilir, kimlik DEĞERİ okunmaz.
#
# 🔴 NİÇİN TEK KAYNAK: "hangi oturum görünür" sorusunu hem ekran (ttyd) hem liste ucu (/api/koltuklar)
#    soruyor. İki ayrı liste yazılsaydı ilk değişiklikte ayrışırdı: listede görünmeyen bir oturuma adresle
#    girilebilir ya da listede görünen bir koltuk açılmazdı. Kapı bu betiğe SORAR, kendisi türetmez.
#
# 🔴 ADRES GÜVENİLMEZ GİRDİDİR. Bağlanılacak ad yalnız şu üç kapıdan geçerse kabul edilir:
#    (1) karakter kümesi dar (harf · rakam · _ -, en çok 64) — tmux hedef sözdizimi (: . = ^) giremez
#    (2) kutuda ŞU AN VAR olan bir oturum (beyaz liste = tmux'un kendi listesi; ad uydurulamaz)
#    (3) gizli değil (altyapı oturumları: ttyd · kapı · kurtarıcı · görsel dinleyici)
#    Kapıdan geçmeyen ad İÇİN YENİ OTURUM AÇILMAZ ve ana oturuma da sessizce düşülmez: kullanıcı yanlış
#    koltukta olduğunu sanmasın diye açık bir red basılır.
set -uo pipefail

gizli() { case "$1" in ttyd-*|kapi-*|*-kurtarici|imglistener*) return 0 ;; esac; return 1; }
gizli_neden() { case "$1" in ttyd-*) echo "altyapı: web terminali (ttyd)" ;; kapi-*) echo "altyapı: kutu kapısı" ;;
  *-kurtarici) echo "altyapı: kurtarıcı ajan" ;; imglistener*) echo "altyapı: görsel dinleyici" ;; esac; }
# 🔴 AD SÜZGECİ: tek kaynak koltuk-adi.sh (kural ve gerekçesi orada; kapı aynı kuralı KOLTUK_AD_DESEN'de taşır, eşdeğerlik sınavlı).
KB_DIZIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$KB_DIZIN/koltuk-adi.sh"
gecerli_ad() { koltuk_adi_gecerli "$1"; }
# ttyd ?arg=2026%2F85 değerini kabuğa ÇÖZÜLMÜŞ ('2026/85') iletir — gerçek ttyd+Chromium ile ölçüldü (13 Eki); burada çözme YOK.

# 🔴 ÖLÇEMEDİĞİNE "boş" DEMEZ (bağımsız göz, tur 3): tmux listesi ALINAMAZSA bu "0 koltuk" değil
#    "ölçülemedi"dir → rc=3. Tek istisna tmux sunucusunun hiç çalışmaması ("no server running"):
#    o kutuda gerçekten koltuk yoktur, boş liste doğrudur.
koltuklar() {  # görünür oturum adları, satır satır · rc 3 = ölçülemedi
  local ham hata
  if ! ham="$(tmux list-sessions -F '#{session_name}' 2>&1)"; then
    case "$ham" in *"no server running"*|*"No such file or directory"*) return 0 ;; esac
    printf 'koltuklar ölçülemedi: %s\n' "$ham" >&2; return 3
  fi
  printf '%s\n' "$ham" | while IFS= read -r s; do
    if [ -n "$s" ] && ! gizli "$s"; then printf '%s\n' "$s"; fi
  done
  return 0   # son satır gizliyse döngü 1 döner; o bir ölçüm hatası değil
}

# 🔴 HEDEF ADLA DEĞİL BÖLME KİMLİĞİYLE (yedek göz tur 2 ölçtü): '-t "$1:"' ve '-t "=$1:"' adı değil oturum KİMLİĞİNİ ($1) çözer →
#    '$1' adlı koltuğun hâli/etkinliği BAŞKA oturumdan okunurdu. Tüm bölmeler bir kez listelenir, ada tam eşleşmeyle süzülür.
bolmeler() { if [ -n "${BOLMELER_ONBELLEK+x}" ]; then printf '%s\n' "$BOLMELER_ONBELLEK"; return 0; fi
  tmux list-panes -a -F '#{session_name}	#{window_active}	#{pane_active}	#{pane_id}	#{pane_pid}	#{pane_current_command}' 2>/dev/null; }
bolme_bul() { bolmeler | awk -F'\t' -v s="$1" '$1==s && $2==1 && $3==1 {print $4; exit}'; }   # oturumun etkin bölmesi (%N)
# 🔴 2.5.0 (SERDAR 14 Eki ölçümü): Claude yalnız ÇOCUK süreçte aranıyordu. Kutuların çoğu ajanı bir başlatma betiğiyle açar
#    (bölme: bash → baslat-claude.sh → claude): Claude TORUN süreçtir, eski arama onu görmez → koltuk "Claude yok" sayılırdı
#    (tellal/HAYALI, nova-kesif). Artık bölmenin bütün alt ağacı (derinlik sınırı yok) taranır; komut satırı claude ile başlayan
#    ya da …/claude olan süreç bulunursa koltukta Claude VAR.
altta_claude() {  # $1 = kök pid → 0 ise alt ağacın HERHANGİ bir katında Claude süreci var (derinlik sınırı YOK — bağımsız göz tur 1)
  # Tek anlık süreç tablosu (ps) üzerinde kökten aşağı yürünür; tablo alınamazsa rc 2 (ÖLÇÜLEMEDİ — "yok" sayılmaz).
  local tablo; tablo="$(ps -e -o pid=,ppid=,args= 2>/dev/null)" || return 2
  [ -n "$tablo" ] || return 2
  printf '%s\n' "$tablo" | awk -v kok="$1" '
    { pid=$1; pp=$2; $1=""; $2=""; sub(/^  /,""); a[pid]=$0; c[pp]=c[pp] " " pid }
    END { n=split(c[kok], q, " "); i=1
      while (i<=n) { p=q[i++]; if (p=="" || gor[p]++) continue
        # YALNIZ çalıştırılan program (argv[0]) sayılır — argümanında "…/claude" geçen başlatıcı kabuk Claude DEĞİL (bağımsız göz tur 2)
        x=a[p]; sub(/ .*/, "", x); sub(/.*\//, "", x); if (x == "claude" || x == "claude.exe") { bulundu=1; exit }
        m=split(c[p], r, " "); for (k=1;k<=m;k++) q[++n]=r[k] }
      exit (bulundu ? 0 : 1) }'
}
claude_var_mi() {  # $1 = oturum → 0 Claude var · 1 yok · 2 ölçülemedi (süreç tablosu alınamadı)
  local pid kom r
  while read -r pid kom; do
    case "$kom" in claude|claude-*|claude.exe) return 0 ;; esac   # claude.exe: yerel kurucunun ikilisi (medigate/SAYMAN, 14 Eki)
    altta_claude "$pid"; r=$?; [ $r = 0 ] && return 0; [ $r = 2 ] && return 2
  done < <(bolmeler | awk -F'\t' -v s="$1" '$1==s {print $5" "$6}')
  return 1
}
# ── HESAP (2.14.0 · G-BANI-0008, senaryo kartı E1 zemini): koltuktaki Claude'un hesabı, SÜRECİN ORTAMINDAN okunur.
#    Kural Nexus scripts/hesap_kutu.py hesap_adi() ile BİREBİR (iki dilin eşdeğerliği koltuk-bagla.test.sh H bloğunda sınanır):
#    ANTHROPIC_BASE_URL varsa → kapi (kapı şeridi hesabı EZER) · CLAUDE_CONFIG_DIR yok ya da taban dizinse → varsayilan ·
#    <KOK>/<ad> ise → <ad> · başka yer → bilinmiyor:dizin · ortam okunamazsa → bilinmiyor:okunamadi.
#    🔴 Yalnız AD üretilir: hesabın kimlik dosyası hiçbir yolda açılmaz (sınav H9 betikte adının bile geçmediğini ölçer);
#       sürecin ortamından da yalnız iki değişkenin değeri okunur (dizin yolu ve kapı adresi var/yok).
HESAP_KOK="${HESAP_KOK:-/config/.claude/hesaplar}"; HESAP_TABAN="${HESAP_TABAN:-/config/.claude}"; PROC_KOK="${HESAP_PROC_KOK:-/proc}"
altta_claude_pid() {  # $1 = kök pid → alt ağaçtaki İLK Claude sürecinin pid'i (altta_claude ile aynı yürüyüş); yoksa boş, tablo alınamazsa rc 2
  local tablo; tablo="$(ps -e -o pid=,ppid=,args= 2>/dev/null)" || return 2
  [ -n "$tablo" ] || return 2
  printf '%s\n' "$tablo" | awk -v kok="$1" '
    { pid=$1; pp=$2; $1=""; $2=""; sub(/^  /,""); a[pid]=$0; c[pp]=c[pp] " " pid }
    END { n=split(c[kok], q, " "); i=1
      while (i<=n) { p=q[i++]; if (p=="" || gor[p]++) continue
        x=a[p]; sub(/ .*/, "", x); sub(/.*\//, "", x); if (x == "claude" || x == "claude.exe") { print p; exit }
        m=split(c[p], r, " "); for (k=1;k<=m;k++) q[++n]=r[k] } }'
}
claude_pid() {  # $1 = oturum → koltuktaki Claude sürecinin pid'i; yoksa boş
  # 🔴 ÖNCE alt ağaç (bağımsız göz tur 2): tmux'un pane_pid'i bölmenin KABUĞUDUR, pane_current_command ise ön plandaki program.
  #    Kabuk 'CLAUDE_CONFIG_DIR=… claude' diye açtıysa hesap değişkeni yalnız ÇOCUKTA vardır; kabuğun ortamını okumak hesabı kaçırır.
  #    Alt ağaçta Claude yoksa ve bölme komutu claude ise süreç exec'lenmiştir → bölme pid'i Claude'un kendisidir.
  local pid kom p
  while read -r pid kom; do
    p="$(altta_claude_pid "$pid")"; [ -n "$p" ] && { echo "$p"; return 0; }
    case "$kom" in claude|claude-*|claude.exe) echo "$pid"; return 0 ;; esac
  done < <(bolmeler | awk -F'\t' -v s="$1" '$1==s {print $5" "$6}')
  return 1
}
hesap_adi() {  # $1 = CLAUDE_CONFIG_DIR değeri · $2 = ANTHROPIC_BASE_URL dolu mu (1|0) → ad (hesap_kutu.py hesap_adi eşdeğeri)
  local ccd="$1" n taban kok
  [ "$2" = 1 ] && { echo kapi; return; }
  taban="$(normal_yol "$HESAP_TABAN")"; kok="$(normal_yol "$HESAP_KOK")"
  [ -z "$ccd" ] && { echo varsayilan; return; }
  n="$(normal_yol "$ccd")"
  [ "$n" = "$taban" ] && { echo varsayilan; return; }
  [ "$(dirname "$n")" = "$kok" ] && { basename "$n"; return; }
  echo bilinmiyor:dizin
}
normal_yol() {  # python os.path.normpath eşdeğeri (sözcüksel): çift eğik · '.' · '..' (kökte '..' düşer; göreli yolda başta '..' kalır) · sondaki eğik
  printf '%s' "$1" | awk -F'/' '{ mutlak=(substr($0,1,1)=="/"); n=0
    for (i=1;i<=NF;i++) { p=$i; if (p=="" || p==".") continue
      if (p=="..") { if (n>0 && y[n]!="..") { n-- } else if (!mutlak) { y[++n]=p }; continue }
      y[++n]=p }
    s=""; for (i=1;i<=n;i++) s=s (i>1?"/":"") y[i]
    if (mutlak) s="/" s; if (s=="") s=(mutlak?"/":"."); printf "%s", s }'
}
koltuk_hesabi() {  # $1 = oturum → hesap adı; Claude yoksa boş (uydurulmaz)
  local pid ort ccd burl
  pid="$(claude_pid "$1")" || { echo ""; return; }
  [ -n "$pid" ] || { echo ""; return; }
  ort="$(tr '\0' '\n' < "$PROC_KOK/$pid/environ" 2>/dev/null)" || { echo "bilinmiyor:okunamadi"; return; }
  ccd="$(printf '%s\n' "$ort" | awk -F= '$1=="CLAUDE_CONFIG_DIR"{sub(/^[^=]*=/,""); print; exit}')"
  burl="$(printf '%s\n' "$ort" | awk -F= '$1=="ANTHROPIC_BASE_URL"{sub(/^[^=]*=/,""); print; exit}')"
  hesap_adi "$ccd" "$([ -n "$burl" ] && echo 1 || echo 0)"
}

# ── TÜR ve HÂL (2.2.0 · dilim 4, Sultan: "düzenli net sade"): ekran yalnız AJAN koltuklarını önde gösterir,
#    gerisi "diğer" altında katlanır; hâl noktası koltuk başına. İkisi de BURADA ölçülür (kapı sormakla yetinir).
#    tür  : ajan  = Claude çalışan oturum · diğer = geçici/arka plan (cc-* · dash* · imglistener* · *-kurtarici) ya da
#           Claude'suz oturum (ana dahil; ana'nın önde durması `ana` bayrağının işi)
#    hâl  : son ekran satırlarından, filo yoklamasıyla AYNI desenler (Nexus scripts/filo.py hal()): sıra meşgul > soru >
#           sınır > girdi > boş; hiçbiri tutmazsa "bilinmiyor" (uydurulmaz). Claude'suz oturumun hâli ölçülmez → "bilinmiyor".
diger_mi() { case "$1" in cc-*|dash*|imglistener*|*-kurtarici) return 0 ;; esac; return 1; }
koltuk_turu() {  # $1 = oturum · $2 = claude(1|0) → ajan yalnız Claude çalışan, adı geçici olmayan oturum; gerisi diğer
  # 🔴 ANA oturum için istisna YOK (bağımsız göz #298 tur 2): Claude'suz ana da "diğer"dir. Ana'nın ekranda hep önde
  #    durması türün değil `ana` bayrağının işidir (kapı onu ayrıca verir; merkez ana'yı türünden bağımsız önde çizer).
  if diger_mi "$1"; then echo diger; elif [ "$2" = 1 ]; then echo ajan; else echo diger; fi
}
# yazi_kutusu_var <ekran> → 0: ekranda Claude Code yazı kutusu var — '❯' ile başlayan (ama '❯ N.' menü şıkkı OLMAYAN) bir satırın hemen
#   üstünde '─' çizgisi ve ALTINDA herhangi bir yerde yine '─' çizgisi (çok satırlı insan taslağı kutuyu istediği kadar uzatır; satır sınırı
#   YOK — göz #440 tur 1: 8 satırlık sınır uzun taslakta kutuyu kaçırıyordu). U+00A0 boşluk sayılır
#   (koltuk-gonder 15 Eki dersi). Boş satırlar çağıranda silinmiştir. Çizgi düz üç '─' ile aranır: mawk baytla çalışır, '─{3,}'
#   tekrarı yalnız '─'nin SON baytına uygular ve gerçek çizgide HİÇ tutmaz (ölçüldü 23 Eki, mawk 1.3.4). awk programına tek tırnaklı yorum KONMAZ.
yazi_kutusu_var() {
  printf '%s\n' "$1" | sed 's/\xc2\xa0/ /g' | awk '
    { c[NR] = ($0 ~ /^[[:space:]]*───/); p[NR] = ($0 ~ /^[[:space:]]*❯/ && $0 !~ /^[[:space:]]*❯[[:space:]]*[0-9]+\./) }
    END { for (i = 2; i <= NR; i++) if (p[i] && c[i-1]) for (j = i + 1; j <= NR; j++) if (c[j]) exit 0; exit 1 }'
}
# soru_durum_yolu → kapi/soru.mjs ile AYNI kural (TO_SORU_DURUM · XDG_STATE_HOME · ~/.local/state)
soru_durum_yolu() { if [ -n "${TO_SORU_DURUM:-}" ]; then printf '%s' "$TO_SORU_DURUM"; else printf '%s' "${XDG_STATE_HOME:-${HOME:-/config}/.local/state}/terminal-onar/soru-beri.json"; fi; }
# soru_oku <oturum> → tek satır JSON ya da boş. Ekranın son 40 dolu satırı (soru kutusu uzun olabilir); node yoksa / okunamazsa boş (uydurulmaz).
soru_oku() {
  local hedef; hedef="$(bolme_bul "$1")"; [ -n "$hedef" ] || return 0
  command -v node >/dev/null 2>&1 || return 0
  tmux capture-pane -p -t "$hedef" -S -40 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 40 | node "$KB_DIZIN/../kapi/soru.mjs" --oturum "$1" 2>/dev/null | head -1
}
koltuk_hali() {  # $1 = oturum → calisiyor|soru|sinirda|girdi|dis-olay|bos|bilinmiyor  (SON 15 dolu satır; eskisi sayılmaz)
  local ekran genis
  # 🔴 tmux -S -15 görünür panenin ÜSTÜNE 15 geçmiş satır ekler, sonunu sınırlamaz (bağımsız göz #298 tur 1): sınır tail ile.
  # 🔴 capture-pane BÖLME hedefi ister: "=ad" oturum biçimi GEÇERSİZDİR ("can't find pane" — canlıda ölçüldü, 13 Eki); "ad:" ise
  #    '$1' gibi adı kimlik sanır (yedek göz tur 2). Hedef = ada tam eşleşen oturumun etkin bölme kimliği (%N).
  local hedef; hedef="$(bolme_bul "$1")"; [ -n "$hedef" ] || { echo bilinmiyor; return; }
  # TEK yakalama, iki görünüm (2.23.0 · göz #440 tur 1): hâl desenleri SON 15 dolu satırda aranır (eskisi sayılmaz); yazı kutusu ise 60 satırda
  #   — çok satırlı uzun bir taslak kutunun üst çizgisini 15 satırın dışına iter, kutu görülmez ve taslaktaki "Do you want to" yanlış soru olurdu.
  genis="$(tmux capture-pane -p -t "$hedef" -S -60 2>/dev/null | sed '/^[[:space:]]*$/d' | tail -n 60)" || { echo bilinmiyor; return; }
  ekran="$(printf '%s\n' "$genis" | tail -n 15)"
  [ -n "$ekran" ] || { echo bilinmiyor; return; }
  # Sıra: soru > meşgul > sınır > girdi > boş — soru en üstte: bekleyen bir soru, ekranda "esc to cancel" gibi meşgul izi taşısa
  # da sorudur; Sultan'ın görmesi gereken odur (filo yoklaması aynı deseni "Enter to select" istisnasıyla kuruyordu).
  # 🔴 YAZI KUTUSU VARKEN SORU YOK (2.23.0 · BÂNİ koltuğu 23 Eki 14:5x ölçümü): desen ajanın KENDİ yazdığı metinde de geçer
  #    ("Do you want to", "❯ 1." içeren bir açıklama, araç çıktısı) — eski kural hâli yanlış 'soru' yapıyordu. Gerçek soru menüsü
  #    açıkken Claude Code yazı kutusunu (çizgi · '❯' satırı · çizgi) ekrandan KALDIRIR; kutu duruyorsa soru yoktur.
  if ! yazi_kutusu_var "$genis" && printf '%s' "$ekran" | grep -qE 'Enter to select|Do you want to|❯ [0-9]+\. '; then echo soru; return; fi
  if printf '%s' "$ekran" | grep -qiE 'esc to interrupt|esc to cancel\)|\([0-9]+s ·|Running…|Waiting…'; then echo calisiyor; return; fi
  if printf '%s' "$ekran" | grep -qiE 'usage limit|limit reached|5-hour limit'; then echo sinirda; return; fi
  local satir
  # U+00A0 (yeni TUI boş kutuyu '❯'+kırılmaz boşluk çizer) boşluk sayılır — koltuk-gonder 15 Eki dersi
  satir="$(printf '%s\n' "$ekran" | sed 's/\xc2\xa0/ /g' | grep -E '^[[:space:]]*❯' | tail -1 | sed 's/^[[:space:]]*❯[[:space:]]*//')"
  if printf '%s\n' "$ekran" | grep -qE '^[[:space:]]*❯'; then
    if [ -n "$satir" ]; then echo girdi; return; fi
    # 5. HÂL — DIŞ OLAY BEKLİYOR (Sultan 15 Eki 20:40): yazı kutusu BOŞ ama ajan bir dış olayı bekliyor (CI, arka plan izleyici,
    #   zamanlayıcı). "çalışıyor" DEĞİL (esc to interrupt yok), "boşta" da değil — Sultan onu takılı sanmasın. Kaynak: Claude Code
    #   alt çubuğundaki "N shells running" ya da son mesajdaki bekleme kalıbı. Ne beklediği KH_NE'ye düşer (rozet üstüne gelince).
    # 🔴 YALNIZ GÜNCEL iz (bağımsız göz tur 1): eski bir açıklama "bekleniyor" diyebilir; ölçü son 5 dolu satırdır (alt çubuk +
    #    son mesajın kuyruğu). Alt çubuk iki yazımda gelir: "N shells still running" (eski) ve "· N shells ·" (yeni, 'running' YOK; 27 Eki canlıda ölçüldü:
    #    kalıp yalnız eskiyi tanıyınca arka plan işi süren koltuk "boş" göründü, AZWHMF). "N shells running" alt çubuk sinyalidir ve en güçlüsü; metin kalıpları da aynı pencerede aranır.
    # 🔴 METİN KALIBI YALNIZ SON MESAJDA (bağımsız göz tur 3): son 5 satırda "CI bekleniyor" sonra "⏺ Bitti" + boş istem gelmişse
    #    bekleme BİTMİŞTİR; kalıp son ⏺ satırından itibaren aranır. Alt çubuk sinyali ("N shells running") mesaj değil durum
    #    çubuğudur, istemin altındadır — her yerde sayılır.
    # 🔴 NE BEKLEDİĞİ = NEDEN (bağımsız göz tur 4): ikisi birlikteyse açıklayıcı son mesaj ("CI bekleniyor; bildirim gelince devam")
    #    önce gelir, "N shells running" yalnız sayıdır — ad "ne bekliyor" diyorsa alanı da nedeni taşımalı. Hâl kararı (dis-olay)
    #    ikisinden biri varsa; alt çubuk sinyali hâl için en güçlü, metin için en zayıf.
    local kuyruk ne son kabuk; kuyruk="$(printf '%s\n' "$ekran" | tail -n 5)"
    kabuk="$(printf '%s\n' "$kuyruk" | grep -iE '[0-9]+ (background )?shells? (still )?running|·[[:space:]]*[0-9]+ shells?[[:space:]]*(·|$)' | tail -1 | sed 's/^[[:space:]]*//' | cut -c1-80)"
    son="$(printf '%s\n' "$kuyruk" | awk '/⏺/{n=NR} END{print n+0}')"; [ "$son" -gt 0 ] || son=1
    ne="$(printf '%s\n' "$kuyruk" | tail -n +"$son" | grep -iE 'bekleniyor|bildirim gelince|CI [^ ]*bekl|bekleyici|arka plan(da)? (bekl|izl)|izleniyor' | tail -1 | sed 's/^[[:space:]]*//; s/^⏺[[:space:]]*//' | cut -c1-80)"
    [ -n "$ne" ] || ne="$kabuk"
    if [ -n "$ne" ]; then KH_NE="$ne"; echo dis-olay; return; fi
    echo bos; return
  fi
  echo bilinmiyor
}
KH_NE=""   # koltuk_hali 'dis-olay' dediğinde ne beklediği (tek satır, ≤80); başka hâlde boş

bos_kabuk_mu() {  # $1 = oturum → 0 ise BOŞ KABUK: Claude yok ve her bölme yalnız kabuk istemi (altında süreç yok)
  local pid kom n=0 r
  claude_var_mi "$1"; r=$?; [ $r = 0 ] && return 1; [ $r = 2 ] && return 2
  while read -r pid kom; do
    n=$((n+1))
    case "$kom" in bash|sh|zsh|fish|dash|-bash|-sh) ;; *) return 1 ;; esac
    pgrep -P "$pid" >/dev/null 2>&1 && return 1
  done < <(bolmeler | awk -F'\t' -v s="$1" '$1==s {print $5" "$6}')
  [ $n -gt 0 ]
}

# ── TELEFON BOYU (2.36.5 · telefon-terminal-zoom-boy): ignore-size'ın ters yüzü. Telefon pencere boyuna HİÇ girmediği için pencere
#    telefondan DARSA (son bağlanan dar bir masaüstünün boyunda kalmış: canlıda code-ana 30x50 ölçüldü) telefonun sağı/altı noktalı çıkar.
#    Kural: telefon masaüstünü daraltmaz AMA pencere telefondan darsa (ya da kısaysa) pencere telefon boyuna BÜYÜTÜLÜR. Yalnız büyütür,
#    hiçbir boyutu küçültmez; oturumda boyu sayılan (ignore-size'sız) bir istemci varsa DOKUNMAZ — boy onundur.
#    Ölçülerek seçildi (gerçek tmux 3.4 + gerçek ttyd + Chromium 390 px):
#    · bayrağı kaldırmak (refresh-client -f '!ignore-size') REDDEDİLDİ: telefon tuşa bastığı an 'latest' olur, 120 sütunluk masaüstünü 50'ye indirir.
#    · bağlanırken tek seferlik büyütme (stty size) YETMEDİ: ttyd süreci ilk boyla doğar (30x55), xterm sonra 31x59'a oturur → 3 sütun yine noktalı.
#    · SEÇİLEN: oturuma iki kanca (client-attached + client-resized, dizin 86). tmux ölçtüğü İSTEMCİ boyuyla çağırır; telefon dönünce de çalışır.
#      Kanca yalnız ignore-size istemcide koşar (if-shell -F süzgeci): masaüstü istemcisi hiç süreç doğurmaz. Kanca oturum kapsamlıdır, başka
#      oturuma ve sunucu geneline yazmaz; telefon gidince kalır ama telefonsuz hiçbir şey yapmaz.
#    resize-window pencereyi 'manual'e çeker → hemen ardından pencerenin YEREL ayarı eski hâline döner (yoksa silinir): boy kalır, sonra bağlanan
#    masaüstü 'latest' kuralıyla boyu yine alır.
TEL_KANCA_NO=86
tel_kanca() {  # $1 = oturum adı → telefon boyu kancalarını kurar (yol tmux komutuna güvenle yazılamıyorsa kurmaz)
  local yol="$KB_DIZIN/koltuk-bagla.sh" k
  case "$yol" in *[!A-Za-z0-9_./-]*) return 0 ;; esac
  k="if-shell -F '#{m:*ignore-size*,#{client_flags}}' { run-shell -b \"bash $yol --tel-buyut '#{client_name}'\" }"
  tmux set-hook -t "=$1:" "client-attached[$TEL_KANCA_NO]" "$k" 2>/dev/null
  tmux set-hook -t "=$1:" "client-resized[$TEL_KANCA_NO]" "$k" 2>/dev/null
  return 0
}
tel_buyut() {  # $1 = istemci adı (kancadan) → istemci ignore-size ise ve oturumda boyu sayılan istemci yoksa pencereleri istemci boyuna büyütür
  local bilgi tc ts st bay ses ist w ww wh nx ny yerel
  [[ "$1" =~ ^[A-Za-z0-9_./-]{1,64}$ ]] || return 0
  bilgi="$(tmux display-message -p -c "$1" '#{client_width}	#{client_height}	#{status}	#{client_flags}	#{session_name}' 2>/dev/null)" || return 0
  IFS=$'\t' read -r tc ts st bay ses <<< "$bilgi"
  [[ "$bay" == *ignore-size* ]] || return 0
  [[ "$tc" =~ ^[0-9]+$ && "$ts" =~ ^[0-9]+$ ]] && [ "$tc" -gt 0 ] && [ -n "$ses" ] || return 0
  case "$st" in off) ;; on) ts=$((ts-1)) ;; [2-5]) ts=$((ts-st)) ;; esac   # durum çubuğu satırları pencereye girmez
  [ "$ts" -gt 0 ] || return 0
  ist="$(tmux list-clients -t "=$ses" -F '#{client_flags}' 2>/dev/null)" || return 0   # ölçülemedi → dokunma
  printf '%s\n' "$ist" | grep -v 'ignore-size' | grep -q '^.' && return 0
  # İKİ KANCA (client-attached + client-resized) AYNI ANDA koşabilir: ikincisi, birincinin resize-window'undan SONRA ama yerel ayarı silmesinden ÖNCE
  # 'yerel'i okursa 'manual'i eski değer sanıp geri yazar → pencere sonsuza dek 'manual' kalır, sonra bağlanan masaüstü boyu alamaz
  # (CI'da R2/R3/R4; ölçüm: yerel-ayar=[manual], pencere 70x50, 120x40 istemci bağlı). Çözüm: oturum başına kilit — gövde sıralı koşar.
  # Kilit dosyası AÇILAMAZSA (salt-okur TMPDIR) ya da flock YOKSA kilitsiz sürer (özellik çalışsın); kilit AÇILDI ama süre içinde ALINAMADIYSA başka bir kanca
  # aynı işi yapıyor demektir → dokunma (kilitsiz sürmek yarışı geri getirirdi). Süre: KB_KILIT_SN (varsayılan 10).
  KILITLI=0
  if [ -z "${KB_KILIT_YOK:-}" ] && command -v flock >/dev/null 2>&1 && exec 9>"${TMPDIR:-/tmp}/koltuk-bagla-tel-buyut.$(id -u).${ses//[^A-Za-z0-9_.-]/_}.lock" 2>/dev/null; then
    flock -w "${KB_KILIT_SN:-10}" 9 || return 0
    KILITLI=1
  fi
  tmux list-windows -t "=$ses" -F '#{window_id} #{window_width} #{window_height}' 2>/dev/null | while read -r w ww wh; do
    [[ "$ww" =~ ^[0-9]+$ && "$wh" =~ ^[0-9]+$ ]] || continue
    nx=$ww; [ "$tc" -gt "$ww" ] && nx=$tc
    ny=$wh; [ "$ts" -gt "$wh" ] && ny=$ts
    [ "$nx" = "$ww" ] && [ "$ny" = "$wh" ] && continue
    yerel="$(tmux show-options -wqv -t "$w" window-size 2>/dev/null)"
    # KİLİTSİZ kolda 'manual' ya kullanıcının bilerek koyduğudur ya da eşzamanlı kancanın resize-window'undan kalandır; ikisi ayırt edilemez →
    # pencereye dokunma (ne büyüt, ne sil, ne geri yaz): ayar korunur, yarış 'manual' bırakamaz.
    [ "$KILITLI" = 0 ] && [ "$yerel" = manual ] && continue
    tmux resize-window -t "$w" -x "$nx" -y "$ny" 2>/dev/null || continue
    if [ -n "$yerel" ]; then tmux set-option -w -t "$w" window-size "$yerel" 2>/dev/null; else tmux set-option -w -u -t "$w" window-size 2>/dev/null; fi
  done
  return 0
}
if [ "${1:-}" = "--tel-buyut" ]; then tel_buyut "${2:-}"; exit 0; fi

if [ "${1:-}" = "--bos" ]; then
  if ! TUM="$(tmux list-sessions -F '#{session_name}' 2>&1)"; then
    case "$TUM" in *"no server running"*|*"No such file or directory"*) exit 0 ;; esac
    printf 'oturumlar ölçülemedi: %s\n' "$TUM" >&2; exit 3
  fi
  # 🔴 Bölme listesi ve süreç tablosu alınamazsa ölçüm YOK (bağımsız göz tur 1): boş liste "hiç boş koltuk yok" sayılmaz → rc 3.
  BOLMELER_ONBELLEK="$(tmux list-panes -a -F '#{session_name}	#{window_active}	#{pane_active}	#{pane_id}	#{pane_pid}	#{pane_current_command}' 2>&1)" \
    || { printf 'bölmeler ölçülemedi: %s\n' "$BOLMELER_ONBELLEK" >&2; exit 3; }
  ps -e -o pid= >/dev/null 2>&1 || { echo 'süreç tablosu ölçülemedi (ps)' >&2; exit 3; }
  printf '%s\n' "$TUM" | while IFS= read -r s; do
    [ -n "$s" ] || continue
    bos_kabuk_mu "$s"; r=$?
    [ $r = 0 ] && printf '%s\n' "$s"
    if [ $r = 2 ]; then printf 'ölçülemedi: %s\n' "$s" >&2; exit 3; fi
  done || exit 3
  exit 0
fi

if [ "${1:-}" = "--gizli" ]; then
  if ! TUM="$(tmux list-sessions -F '#{session_name}' 2>&1)"; then
    case "$TUM" in *"no server running"*|*"No such file or directory"*) exit 0 ;; esac
    printf 'oturumlar ölçülemedi: %s\n' "$TUM" >&2; exit 3
  fi
  printf '%s\n' "$TUM" | while IFS= read -r s; do
    [ -n "$s" ] && gizli "$s" && printf '%s\t%s\n' "$s" "$(gizli_neden "$s")"
  done
  exit 0
fi

if [ "${1:-}" = "--liste" ]; then
  LISTE="$(koltuklar)" || exit 3
  SORU_OTURUM="$(mktemp)" || exit 3
  AKT="$(tmux list-sessions -F '#{session_name}	#{session_activity}' 2>/dev/null)"   # son etkinlik: ada tam eşleşme, -t yok
  printf '%s\n' "$LISTE" | while IFS= read -r s; do
    [ -n "$s" ] || continue
    son=$(printf '%s\n' "$AKT" | awk -F'\t' -v n="$s" '$1==n {print $2; exit}'); son="${son:-0}"
    if claude_var_mi "$s"; then c=1; else c=0; fi
    tur="$(koltuk_turu "$s" "$c")"
    KH_NE=""
    if [ "$c" = 1 ]; then hal="$(koltuk_hali "$s"; printf '\x1f%s' "$KH_NE")"; else hal=bilinmiyor; fi   # Claude'suz oturumda hâl ölçülmez → bilinmiyor
    ne="${hal#*$'\x1f'}"; hal="${hal%%$'\x1f'*}"; hal="${hal%$'\n'}"; [ "$ne" = "$hal" ] && ne=""   # echo'nun satır sonu ayraçtan önce kalır
    # 6. sütun: ne beklediği (yalnız dis-olay'da dolu); sekme/satır sonu taşımaz · 7. sütun: hesap adı (2.14.0; Claude'suz koltukta boş)
    if [ "$c" = 1 ]; then hesap="$(koltuk_hesabi "$s")"; else hesap=""; fi
    soru=""
    if [ "$hal" = soru ]; then soru="$(soru_oku "$s")"; printf '%s\n' "$s" >> "$SORU_OTURUM"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$s" "${son:-0}" "$c" "$tur" "$hal" "$(printf '%s' "$ne" | tr '\t\n' '  ')" "$(printf '%s' "$hesap" | tr '\t\n' '  ')" "$(printf '%s' "$soru" | tr '\t\n' '  ')"
  done
  # soru hâlinden çıkan koltuğun 'beri' kaydı silinir (aynı soru sonra yeniden gelirse eski an taşınmasın); durum dosyası yoksa node koşmaz
  if [ -s "$(soru_durum_yolu)" ] && command -v node >/dev/null 2>&1; then mapfile -t SO < "$SORU_OTURUM"; node "$KB_DIZIN/../kapi/soru.mjs" --tut "${SO[@]}" >/dev/null 2>&1; fi
  rm -f "$SORU_OTURUM"
  exit 0
fi

ANA="${1:?kullanım: koltuk-bagla.sh <ana-oturum> <proje-dizini> [koltuk] | --liste}"
PROJE="${2:?proje dizini eksik}"
ISTEK="${3:-}"
# ── TELEFON KİPİ (2.25.0 · …XQY97Y D4 · Sultan 25 Eki "terminal mobilde de çalışmalı", masaüstü daralmasın): adres 'tel.' önekliyse
#    önek ayrılır, kalan ad (boş = ana oturum) AŞAĞIDAKİ KAPILARIN HEPSİNDEN AYNEN geçer; tek fark bağlanırken '-f ignore-size'.
#    ignore-size: istemci pencere boyu hesabına girmez — infra/tmux.conf 'window-size smallest' iken bile telefon masaüstünü daraltmaz
#    (gerçek tmux 3.4 ile ölçüldü: bayraksız 50 sütunluk istemci 200 sütunluk pencereyi 50'ye indirdi, bayrakla 200 kaldı).
#    Önek belirsiz olamaz: koltuk adında nokta YASAK (koltuk-adi.sh KOLTUK_AD_DESEN), 'tel.' hiçbir koltuğun adı olamaz.
TEL=0; IGN=()
if [[ "$ISTEK" == tel.* ]]; then TEL=1; ISTEK="${ISTEK#tel.}"; IGN=(-f ignore-size); fi
# 🔴 Birden çok arg (?arg=X&arg=Y) ttyd'de birden çok argüman olur (canlı ölçüldü: ARGS=[X Y]).
#    Belirsiz adres SEÇİLMEZ, reddedilir — ilkini alıp gerisini yutmak sessiz bir karar olurdu.
COK_ARG=$(( $# > 3 ))

red() {
  printf '\r\n  \033[1;31m⛔ %s\033[0m\r\n' "$1"
  printf '  Görünür koltuklar: %s\r\n\r\n' "$(koltuklar | tr '\n' ' ')"
  exit 3
}

[ "$COK_ARG" = 1 ] && red "Adreste birden çok koltuk var; tek koltuk ver."
if [ -z "$ISTEK" ]; then
  # Argümansız: bugünkü davranış BAYT BAYT aynı — ana oturuma bağlan, yoksa aç.
  # 🔴 Yalnız ARGÜMANSIZ yol oturum YARATIR. Ana oturumun adı adresle açıkça verilirse o da
  #    öteki koltuklar gibi beyaz listeden geçer (bağımsız göz, tur 1: açık ad listeyi deliyordu).
  # telefon kipinde de aynı yol (ana yoksa açar) — yalnız istemci bayrağı eklenir
  # telefon kipinde ana oturum YOKSA önce ayrık açılır, sonra kanca kurulur (bağımsız göz #600 tur 1): yoksa set-hook düşer, yeni oturum
  #   kancasız kalır ve ttyd'nin sonradan oturan boyu ya da telefonun dönmesi pencereyi büyütemezdi. Ayrık açılış + -A bağlanış = "yoksa aç" ile aynı.
  if [ "$TEL" = 1 ]; then
    tmux has-session -t "=$ANA" 2>/dev/null || tmux new-session -d -s "$ANA" -c "$PROJE"
    tel_kanca "$ANA"
  fi
  exec tmux new-session -A "${IGN[@]}" -s "$ANA" -c "$PROJE"
fi
# ── AD DIŞI KİMLİK (2.24.0 · P4GT2W): adres 'k'+16 onaltılık taşıyorsa ve bu ADDA bir koltuk yoksa kimlik çözülür:
#    görünür koltuklardan kimliği tutan TEK koltuğa bağlanılır. Tutmazsa red — ama koltuk ADLARI BASILMAZ (adres mahrem
#    kutudan geldi; red ekranı da Sultan'ın ekranıdır). Çözülen ad aşağıdaki kapılardan (süzgeç · gizli · beyaz liste) AYNEN geçer.
if [[ "$ISTEK" =~ $KOLTUK_KIMLIK_DESEN ]]; then
  KLISTE="$(koltuklar)" || red "Koltuklar ölçülemedi (tmux listesi alınamadı) — bağlanmıyorum."
  if ! grep -qxF -- "$ISTEK" <<< "$KLISTE"; then
    BUL=""
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      kk="$(koltuk_kimlik "$k")" || { printf '\r\n  \033[1;31m⛔ %s\033[0m\r\n\r\n' "Koltuk kimliği hesaplanamadı (tuz yok) — bağlanmıyorum."; exit 3; }
      [ "$kk" = "$ISTEK" ] && { BUL="$k"; break; }
    done <<< "$KLISTE"
    [ -n "$BUL" ] || { printf '\r\n  \033[1;31m⛔ %s\033[0m\r\n\r\n' "Bu kimlikte bir koltuk yok (kapanmış olabilir) — listeyi yenileyip yeniden dene."; exit 3; }
    ISTEK="$BUL"
  fi
fi
gecerli_ad "$ISTEK" || red "Geçersiz koltuk adı."
gizli "$ISTEK" && red "Bu oturum bir koltuk değil (altyapı)."
# 🔴 Liste ÖNCE alınır: `koltuklar | grep -q` biçiminde grep erken çıkınca üretici SIGPIPE alır ve
#    pipefail altında var olan koltuk da "yok" sayılırdı (sınav A2 yakaladı).
LISTE="$(koltuklar)" || red "Koltuklar ölçülemedi (tmux listesi alınamadı) — bağlanmıyorum."
grep -qxF -- "$ISTEK" <<< "$LISTE" || red "Bu kutuda '$ISTEK' adlı bir koltuk yok."
# Telefon bağlanınca masaüstü kalıcı daralmasın (onar.sh'taki ana oturum ayarının aynısı). Telefon kipinde gereksiz: ignore-size istemcisi
# pencere boyuna hiç girmez, pencere ayarına dokunulmaz.
if [ "$TEL" = 0 ]; then
  for w in $(tmux list-windows -t "=$ISTEK" -F '#{window_id}' 2>/dev/null); do
    tmux set-option -w -t "$w" window-size latest 2>/dev/null || true
  done
fi
[ "$TEL" = 1 ] && tel_kanca "$ISTEK"
exec tmux attach-session "${IGN[@]}" -t "=$ISTEK"
