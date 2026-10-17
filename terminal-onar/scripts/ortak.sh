# terminal-onar — ortak ayarlar ve ölçüm fonksiyonları (source edilir, tek başına koşmaz)
#
# Düzen: tmux `sedir-ana` (Sultan'ın konuşması, Claude) ← hem code-server terminali hem web
# terminali (ttyd, :7681 → sedir-terminal.mmepanel.com) AYNI oturuma bağlanır → birebir senkron.
# `sedir-kurtarici` ayrı bir Claude oturumudur; onarımın son kademesi.
#
# 🔴 Sır değeri hiçbir dosyaya, günlüğe, argv'ye YAZILMAZ. Parola kasadan (SEDIR__TERMINAL_SIFRE)
#    ortam değişkenine çekilir; ttyd onu kendi sürecinde okur.

# ── KUTU KİMLİĞİ — her şey buradan türer ─────────────────────────────────────
# 🔴 NİÇİN BÖYLE: bu beceri SEDİR kutusunda doğdu ve adlar oraya çivilenmişti
#    (`sedir-ana`, `kapi-sedir`, `SEDIR__TERMINAL_SIFRE`). Genelleştirirken her adı
#    ayrı ayrı ezilebilir yapmak da mümkündü — ama o zaman bir kutuyu kurmak ON ayrı
#    değişken doğru yazmayı gerektirirdi ve biri unutulduğunda kurulum SESSİZCE başka
#    kutunun adına bakardı. Tek kaynak: KUTU. Gerisi türetilir; yine de tek tek
#    ezilebilir kalır (deneme kopyası için).
KUTU="${TO_KUTU:-$(
  # 1) açık beyan · 2) çalışma alanının adı · 3) makine adı → hiçbiri yoksa BOŞ
  d="${TO_PROJE:-}"; [ -n "$d" ] && basename "$d" && exit 0
  # 2) BECERİNİN KENDİ KURULU OLDUĞU YER: <...>/projects/<kutu>/.claude/skills/terminal-onar/scripts
  #    Bu en güvenilir kaynak: kurulu kopya zaten kutunun içinde yaşıyor.
  #    🔴 Eskiden burada `for c in /config/projects/*/; do :; done` vardı — döngü değişkeni
  #    HİÇ KULLANILMIYORDU (ölü kod) ve akış doğrudan makine adına düşüyordu. Kabın makine adı
  #    rastgele bir kimlik olduğunda (ölçüldü: SEDİR kutusunda `f517818d622f`) beceri kutuyu
  #    o kimlik sanıyor: tmux adları, kasa anahtarı ve TABAN yolu hep yanlış türüyordu.
  k="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../../.." 2>/dev/null && pwd)"
  case "$k" in */projects/*) basename "$k" && exit 0 ;; esac
  hostname 2>/dev/null | sed 's/^cloudtop-//'
)}"
# Kutu adı ÇÖZÜLEMEZSE kurulum yapılmaz: yanlış kutunun adına yazmaktansa durmak yeğdir.
[ -n "${KUTU:-}" ] || { echo "terminal-onar: KUTU adı çözülemedi — TO_KUTU ver" >&2; return 1 2>/dev/null || exit 1; }
# 🔴 MAKİNE KİMLİĞİ KUTU ADI DEĞİLDİR (12 Eki 2026 canlı: 15 kutuda ölçüldü). Beceri ORTAK dizinden (/config/.claude/skills)
#    çağrılınca yol kutuyu söylemez, makine adı da kabın rastgele kimliğidir (12 hex) → tmux adları, kasa anahtarı, TABAN
#    yanlış türer; ttyd yanlış yolda açılır, "bozuk" sanılıp başsız kurtarıcı doğar. Böyle bir ad FAIL-CLOSED reddedilir:
#    ya TO_KUTU verilir ya beceri /config/projects/<kutu>/.claude/skills/terminal-onar yolundan çağrılır.
#    Açık beyan (TO_KUTU) bu kapıdan MUAFTIR: hata iletisi "TO_KUTU ver" diyor, o çıkış yolu çalışmalı (bağımsız göz, tur 2);
#    kapı yalnız TÜRETİLMİŞ ada bakar.
if [ -z "${TO_KUTU:-}" ]; then case "$KUTU" in
  *[!0-9a-f]*) ;;   # harf/tire içeren gerçek ad
  ????????????) echo "terminal-onar: KUTU='$KUTU' bir makine kimliğine benziyor, kutu adı değil — TO_KUTU ver ya da beceriyi /config/projects/<kutu>/.claude/skills/terminal-onar yolundan çağır" >&2; return 1 2>/dev/null || exit 1 ;;
esac; fi
KUTU_BUYUK="$(printf '%s' "$KUTU" | tr '[:lower:]-' '[:upper:]_')"

PROJE="${TO_PROJE:-/config/projects/$KUTU}"
# 🔴 KADRO KAYIT KÖKÜ (2.17.0 · gorev_01M554PCYA0HWM6TM4KXY4E72V, ölçüldü 17 Eki): kapı kaydı $PROJE altında arar. Merkez kutusunda
#    (code) $PROJE=/config/projects/code bir iskelettir, ekibin kaydı başka depodadır → kapı 0 üye okudu, sekiz canlı ajanı
#    "kayıtsız oturum" saydı ve Sultan'a tek eylem olarak "Oturumu kapat" sundu. Kutu adı koda GÖMÜLMEZ: kutu kendi yerinde
#    $PROJE/.oda/ortam dosyasına kayıt yolunu yazar. Dosya SOURCE EDİLMEZ; yalnız İZİN LİSTESİ (AILE_REGISTRY · ISKAN_REGISTRY),
#    yalnız mutlak yol, yalnız var olan dosya kabul edilir. Açık ortam (ör. sınavın verdiği) her zaman kazanır.
ODA_ORTAM="${TO_ODA_ORTAM:-$PROJE/.oda/ortam}"
ODA_ORTAM_RED=0
oda_ortam_yukle() {  # → izinli ve geçerli satırları export eder; reddedilenleri ODA_ORTAM_RED'de sayar (içerik basmaz)
  local satir ad deger
  [ -f "$ODA_ORTAM" ] || return 0
  ODA_ORTAM_RED=0
  while IFS= read -r satir || [ -n "$satir" ]; do
    satir="${satir%$'\r'}"
    case "$satir" in ''|'#'*) continue ;; esac
    ad="${satir%%=*}"; deger="${satir#*=}"
    case "$ad" in AILE_REGISTRY|ISKAN_REGISTRY) ;; *) ODA_ORTAM_RED=$((ODA_ORTAM_RED+1)); continue ;; esac
    case "$deger" in /*) ;; *) ODA_ORTAM_RED=$((ODA_ORTAM_RED+1)); continue ;; esac
    [ -f "$deger" ] || { ODA_ORTAM_RED=$((ODA_ORTAM_RED+1)); continue; }
    [ -n "${!ad:-}" ] && continue    # açık ortam kazanır (dolaylı okuma; eval yok)
    export "$ad=$deger"
  done < "$ODA_ORTAM"
}
oda_ortam_yukle
# Kapıya giden kayıt ortamı — TEK yerde üretilir (onar.sh kapıyı bununla başlatır; sınav bunu çağırıp ölçer).
# TO_PROJE de geçer: kapı kökü kendisi türetmesin, kabukla aynı kökü görsün.
kapi_kayit_ortami() {
  printf 'TO_PROJE=%q' "$PROJE"
  [ -n "${AILE_REGISTRY:-}" ] && printf ' AILE_REGISTRY=%q' "$AILE_REGISTRY"
  [ -n "${ISKAN_REGISTRY:-}" ] && printf ' ISKAN_REGISTRY=%q' "$ISKAN_REGISTRY"
  return 0
}
DURUM_DIZ="${TO_DURUM_DIZ:-/config/.terminal-onar}"
GUNLUK="$DURUM_DIZ/gunluk.log"
ANA_TMUX="${TO_ANA_TMUX:-$KUTU-ana}"
KURT_TMUX="${TO_KURT_TMUX:-$KUTU-kurtarici}"
TTYD_TMUX="${TO_TTYD_TMUX:-ttyd-$KUTU}"
KAPI_TMUX="${TO_KAPI_TMUX:-kapi-$KUTU}"
KAPI_PORT="${TO_KAPI_PORT:-7681}"
TTYD_SOKET="${TO_TTYD_SOKET:-${TO_DURUM_DIZ:-/config/.terminal-onar}/ttyd.sock}"
# Rapor dizini — kapıya KAPI_RAPOR_DIZ olarak GİDER. 🔴 2.3.0 / REVAK gerilemesi (12-13 Eki): kutu yayın sayfalarını kendi
#    dizininde ($PROJE/veri/rapor — defter-sayfasi oraya yazar) tutuyordu; ortak koda bağlanınca onar.sh bu değişkeni kapıya
#    vermiyordu, kapı ortak varsayılana baktı, sayfa 404 oldu. Sıra: açık beyan > kutunun veri/rapor dizini (varsa) > ortak varsayılan.
RAPOR_DIZ="${TO_RAPOR_DIZ:-}"
[ -n "$RAPOR_DIZ" ] || { [ -d "$PROJE/veri/rapor" ] && RAPOR_DIZ="$PROJE/veri/rapor" || RAPOR_DIZ="$DURUM_DIZ/rapor"; }
# Beceri GLOBAL dizinde yaşar (tek kopya, 14 kutuda ortak); kutu-yerel kopya varsa o kazanır.
BECERI_KOK="${TO_BECERI_KOK:-$(
  for d in "$PROJE/.claude/skills/terminal-onar" "/config/.claude/skills/terminal-onar"; do
    [ -d "$d" ] && { echo "$d"; break; }
  done
)}"
KAPI_DIZ="$BECERI_KOK/kapi"
TTYD_BIN="${TO_TTYD_BIN:-/config/.local/bin/ttyd}"
ENV_DOSYA="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
SIFRE_ANAHTAR="${TO_SIFRE_ANAHTAR:-${KUTU_BUYUK}__TERMINAL_SIFRE}"
BETIK_DIZ="$BECERI_KOK/scripts"
# 🔴 CRON/ÇAĞRI YOLU = PROJE YOLU: cron satırları ve yeniden çağrılar beceriyi KUTUNUN yolundan çağırmalı ki KUTU yoldan
#    türesin (ortak dizinden çağrı yukarıdaki tuzağa düşer). kur.sh bu bağı kurar; satırlar bu yolu kullanır.
PROJE_BECERI="${TO_PROJE_BECERI:-$PROJE/.claude/skills/terminal-onar}"
PROJE_BETIK="$PROJE_BECERI/scripts"
ANA_AD="${TO_ANA_AD:-$KUTU-yon}"
KURT_AD="${TO_KURT_AD:-$KUTU-kurtarici}"
# ── KURTARICI KAPALI işareti (Sultan kararı 16 Eki 2026: filo genelinde kurtarıcı ajanlar KAPANIR, yalnız code kutusununki
#    kalır — her kutuda ayrı bir Claude bellek yiyordu). İşaret KUTU BAŞINADIR: durum dizini kutuya özeldir (/config/.terminal-onar
#    kutunun kendi /config'inde; paylaşılan tek şey /config/.claude). İşareti kutunun reisi koyar; code kutusuna KONMAZ.
#    Alternatif açık beyan: TO_KURTARICI=0 (ortamdan; cron/sınav için). İşaret varken onar.sh K0 adım 4 kurtarıcıyı AÇMAZ,
#    açıksa KAPATIR (durum işarete yakınsar; yoksa bekçi bir dakika içinde geri açardı); durum.sh "kapalı" basar, "yok" demez;
#    kademe.sh K2'yi atlar ve K3 iletisine "kurtarıcı kapalı → MUAVİN/SERDAR'a bildir" ekler. Geri açmak = işareti silmek.
KURT_KAPALI_DOSYA="${TO_KURTARICI_KAPALI_DOSYA:-$DURUM_DIZ/kurtarici-kapali}"
kurtarici_kapali() { [ "${TO_KURTARICI:-}" = 0 ] || [ -f "$KURT_KAPALI_DOSYA" ]; }
KURT_KAPALI_SEBEP="kapalı (Sultan 16 Eki)"

# ── TABAN YOLU — merkez sayfanın ön şartı ────────────────────────────────────
# Merkez (terminal.mmepanel.com) kutuları YOL ile ayırır: /sedir/ · /akar/ …
# Kapı ve ttyd bu tabanı bilmek zorunda, yoksa döndürdükleri mutlak yollar merkeze
# gider ve kutuya hiç ulaşmaz. Boş bırakılırsa bugünkü kök-yol davranışı aynen sürer.
TABAN="${TO_TABAN:-/$KUTU}"
case "$TABAN" in /) TABAN="" ;; */) TABAN="${TABAN%/}" ;; esac
BELLEK_ENV="NODE_OPTIONS=--max-old-space-size=3072 MALLOC_ARENA_MAX=2"

export TZ=Europe/Istanbul  # cron UTC koşar; günlük yerel saatle yazılsın
# cron'un çıplak PATH'i claude'u bulamaz
# 🔴 NODE YOLU DİNAMİK BULUNUR — sürüm elle yazılıydı ve SEDİR bunu kendi dersinde
#    "beceride dinamik bulunmalı" diye işaretlemişti. Elle yazılan sürüm, node
#    yükseltildiği gün cron'u SESSİZCE öldürür: bekçi koşar, claude bulunamaz, iş yapmaz.
_node_yolu() {
  local d; d="$(command -v node 2>/dev/null)" && { dirname "$d"; return 0; }
  for d in /config/.nvm/versions/node/*/bin; do [ -x "$d/node" ] && { echo "$d"; return 0; }; done
  return 1
}
export PATH="$(_node_yolu 2>/dev/null):/config/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
mkdir -p "$DURUM_DIZ" 2>/dev/null

gunluk() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$GUNLUK"; }

tmux_var() { tmux has-session -t "=$1" 2>/dev/null; }

# Bir tmux oturumunda CANLI Claude var mı → sessionId basar (yoksa RC=1).
# 🔴 Birincil kanıt SÜREÇ AĞACIDIR: oturumun bir panesinin altında `claude` süreci var mı.
#    Oturum kaydı (~/.claude/sessions/<pid>.json) yalnız KİMLİK için okunur — 26 Eylül'de canlı
#    konuşmanın kaydı diskte YOKTU; kayda güvenen eski sürüm konuşmayı "kapalı" sanıp yeniden-açma
#    komutunu canlı konuşmanın İÇİNE yazdı.
claude_pid() {  # $1 = tmux oturumu → ilk canlı claude sürecinin pid'i
  local pp c
  for pp in $(tmux list-panes -s -t "=$1" -F '#{pane_pid}' 2>/dev/null); do
    for c in $(pgrep -P "$pp" 2>/dev/null); do
      tr '\0' ' ' < "/proc/$c/cmdline" 2>/dev/null | grep -qE '(^|/)claude( |$)' && { echo "$c"; return 0; }
    done
    # pane doğrudan claude ise (tmux new-session "claude …")
    tr '\0' ' ' < "/proc/$pp/cmdline" 2>/dev/null | grep -qE '(^|/)claude( |$)' && { echo "$pp"; return 0; }
  done
  return 1
}
claude_oturumu() {  # canlıysa sessionId basar ("?" = canlı ama kimlik bilinmiyor), değilse RC=1
  local tm="$1" pid f id=""
  pid=$(claude_pid "$tm") || return 1
  f="$HOME/.claude/sessions/$pid.json"
  [ -f "$f" ] && id=$(jq -r '.sessionId // empty' "$f" 2>/dev/null)
  [ -z "$id" ] && id=$(tr '\0' ' ' < "/proc/$pid/cmdline" | grep -oE -- '--resume [0-9a-f-]{36}' | awk '{print $2}')
  echo "${id:-?}"; return 0
}

# sessionId başka bir yerde (başka tmux/pencere) canlı mı?
oturum_canli_mi() {
  local id="$1" f pid
  for f in "$HOME"/.claude/sessions/*.json; do
    [ -f "$f" ] || continue
    [ "$(jq -r '.sessionId' "$f" 2>/dev/null)" = "$id" ] || continue
    pid=$(jq -r '.pid' "$f"); kill -0 "$pid" 2>/dev/null && return 0
  done
  # kayıt yoksa süreç satırına bak: `claude --resume <id>` çalışıyor mu
  pgrep -u "$(id -u)" -f -- "claude .*--resume $id" >/dev/null && return 0
  return 1
}

# ttyd yalnız UNIX soketinde (TCP portu yok); kapı :7681'de, girişi o yapar.
ttyd_kod() { curl -s -o /dev/null -m 4 -w '%{http_code}' --unix-socket "$TTYD_SOKET" "http://localhost$TABAN/tty/" 2>/dev/null; }
kapi_kod() { curl -s -o /dev/null -m 4 -w '%{http_code}' "http://127.0.0.1:$KAPI_PORT$TABAN/giris" 2>/dev/null; }
kapi_saglam() { [ "$(kapi_kod)" = "200" ] && [ "$(curl -s -o /dev/null -m 4 -w '%{http_code}' "http://127.0.0.1:$KAPI_PORT$TABAN/")" = "302" ]; }

ttyd_saglam() { [ "$(ttyd_kod)" = "200" ]; }

# Sağlık bekleme — bütçe SANİYE cinsinden, sağlıklı olur olmaz döner.
# SEDİR ölçümü (2026-09-27): bellek sıkışıkken (oom_kill 40) kapı 28 sn'de açıldı;
# 6 sn'lik bütçe "bozuk" deyip merdiveni boşuna tırmandırıyordu — K1 yeni bir Claude
# açar, belleği daha da sıkıştırır. Bütçe uzun, dönüş erken: yavaş açılışta bedel yok.
TTYD_BEKLE=${TTYD_BEKLE:-20}
KAPI_BEKLE=${KAPI_BEKLE:-40}
TO_BEKLE_ADIM=${TO_BEKLE_ADIM:-1}     # sınav hızlandırması; canlıda 1 sn
bekle_saglam() {
  local f=$1 n=$2 i
  for i in $(seq 1 "$n"); do sleep "$TO_BEKLE_ADIM"; "$f" && return 0; done
  return 1
}

# 🔴 İŞARET YALNIZ CRON SATIRININ SONUNDA (2.17.1 · kart terminal-onar-bekci-yorum-korur, 17 Eki ölçüldü): desen eskiden işareti
#    satırın HERHANGİ bir yerinde arıyordu → kanon crontab-abc'nin AÇIKLAMA yorumu ("…işaret yorumu '# terminal-onar-bekci' dahil…")
#    bekçi satırı sanıldı: düzeltici o yorumu bekçi satırına çevirdi, asıl satırı "çift kopya" sayıp sildi (canlıda 20:26'da oldu);
#    bekci_kurulu da asıl satır yokken yorum yüzünden "kurulu" diyebilirdi. Artık: '#' ile başlayan satır YORUMDUR, olduğu gibi
#    korunur; işaret yalnız yorum olmayan satırın SONUNDA sayılır. Beş kullanım yeri (düzeltici · kurulu · iki varlık denetimi ·
#    canlı varlık denetimi) bu iki desenden okur — tek tanım.
BEKCI_DESEN='^[[:space:]]*[^#[:space:]].*# terminal-onar-bekci[[:space:]]*$'
ACILIS_DESEN='^[[:space:]]*[^#[:space:]].*# terminal-onar-acilis[[:space:]]*$'
bekci_kurulu() { ${TO_CRONTAB:-crontab} -l 2>/dev/null | grep -Eq "$BEKCI_DESEN"; }
# ── BEKÇİ SATIRLARI — tek kaynak, PROJE yoluyla; eski (ortak-dizin yollu) satırlar GÖÇÜRÜLÜR ──────────────────────
# 🔴 Bağımsız göz (tur 2): işaretleyici varsa satır "doğru" sayılıyordu; 15 kutudaki eski ortak-yollu satırlar yerinde
#    kalıyordu. Artık işaretleyicili her satır KANONİK biçime yeniden yazılır (yol proje yolu); eksikse eklenir.
# 🔴 YEDEK DAL (2.6.0 · S-9, 13 Eki ölçümü): proje-yolu bağı (<proje>/.claude/skills/terminal-onar) git'te DEĞİL, kur.sh'ın
#    kutuya bıraktığı kayıtsız bir bağdır — depoya yazma yasağı olan kutuda (maiset) hiç kurulamadı, sıfırdan kurulan her
#    kutuda da kaybolur; satır her dakika rc 127 ile düşüyor ve bekçi "kurulu" görünüyordu. Satır artık bağ yoksa ORTAK
#    yola düşer ve kutuyu AÇIK BEYANLA (TO_KUTU=<kutu>) söyler — makine-kimliği tuzağına (2.1.1) düşmez. Bağ varsa eski
#    davranış birebir (proje yolu kazanır). Değişmez: satır işaretleyiciyle bitmeli (bekci_kurulu + kanon bayt-bayt eşleşir).
ODA_CRON="${TO_ODA_CRON:-$PROJE/.oda/cron}"
ORTAK_BECERI="${TO_ORTAK_BECERI:-/config/.claude/skills/terminal-onar}"
_cron_komut() {  # $1 = betik adı · $2 = ek argüman → proje yolu varsa oradan, yoksa ortak yoldan TO_KUTU ile
  printf 'if [ -x %s/%s ]; then bash %s/%s%s; else TO_KUTU=%s bash %s/scripts/%s%s; fi' \
    "$PROJE_BETIK" "$1" "$PROJE_BETIK" "$1" "${2:+ $2}" "$KUTU" "$ORTAK_BECERI" "$1" "${2:+ $2}"
}
BEKCI_SATIR="* * * * * $(_cron_komut bekci.sh)  # terminal-onar-bekci"
ACILIS_SATIR="@reboot sleep 15; $(_cron_komut komut.sh onar)  # terminal-onar-acilis"
bekci_satirlari_duzelt() {  # stdin → stdout: işaretleyicili satırlar kanonik ve TEK (çift kopya tekilleşir), gerisi olduğu gibi
  awk -v b="$BEKCI_SATIR" -v a="$ACILIS_SATIR" -v bd="$BEKCI_DESEN" -v ad="$ACILIS_DESEN" '
    $0 ~ bd { if (!bg) { print b; bg=1 }; next }
    $0 ~ ad { if (!ag) { print a; ag=1 }; next }
    { print }'
}
# 🔴 CANLI CRONTAB KİLİDİ (2.6.0 · S-10, 13 Eki): bir sınav onar.sh'ı TO_PROJE=<geçici dizin> ile ve TO_CRONTAB vermeden
#    koşturdu; bekci_kur canlı crontab'daki bekçi satırını /tmp/... yoluna çevirdi, bekçi o kutuda sessizce öldü (iki kez).
#    Kural: PROJE gerçek kutu yolu (/config/projects/<kutu>) değilse canlı crontab'a YALNIZ açıkça verilen TO_CRONTAB ile
#    dokunulur; verilmemişse dokunulmaz ve söylenir. Deneme kopyası gerçek crontab'ı bozamaz.
canli_crontab_izinli() { [ -n "${TO_CRONTAB:-}" ] || [ "$PROJE" = "/config/projects/$KUTU" ]; }
bekci_kur() {  # $1 = kalıcı cron dosyası (.oda/cron) · $2 = "canli" ise canlı crontab da düzeltilir → stdout: ne yapıldı
  local oda="$1" tmp sonuc="zaten var" ct="${TO_CRONTAB:-crontab}" eski yeni
  mkdir -p "$(dirname "$oda")" 2>/dev/null
  tmp="$(mktemp)"
  if [ -f "$oda" ]; then bekci_satirlari_duzelt < "$oda" > "$tmp"; else printf 'TZ=Europe/Istanbul\n' > "$tmp"; fi
  grep -Eq "$BEKCI_DESEN"  "$tmp" || printf '%s\n' "$BEKCI_SATIR"  >> "$tmp"
  grep -Eq "$ACILIS_DESEN" "$tmp" || printf '%s\n' "$ACILIS_SATIR" >> "$tmp"
  if [ ! -f "$oda" ]; then sonuc="yazıldı"; cat "$tmp" > "$oda"
  elif ! cmp -s "$oda" "$tmp"; then sonuc="eski yol proje yoluna çevrildi"; cat "$tmp" > "$oda"; fi
  rm -f "$tmp"
  if [ "${2:-}" = canli ]; then
    if ! canli_crontab_izinli; then
      sonuc="$sonuc · canlı crontab'a DOKUNULMADI (deneme yolu: $PROJE — gerçek crontab için TO_CRONTAB ver)"
    else
      eski="$($ct -l 2>/dev/null)"; yeni="$(printf '%s\n' "$eski" | bekci_satirlari_duzelt)"
      printf '%s\n' "$yeni" | grep -Eq "$BEKCI_DESEN" || yeni="${yeni:+$yeni
}$BEKCI_SATIR"
      if [ "$eski" != "$yeni" ]; then printf '%s\n' "$yeni" | $ct - && sonuc="$sonuc · canlı crontab düzeltildi"; fi
    fi
  fi
  printf '%s\n' "$sonuc"
}
# Kapı ve ttyd TABAN'ı ortamdan okur; tek yerden verilir ki ikisi ayrışmasın.
export KAPI_TABAN="$TABAN"

# Parola kutu-bağımsız okunur: anahtar adı KUTU'dan türer (SEDIR__… · AKAR__…).
# 🔴 Değer hiçbir zaman argv'ye, günlüğe ya da tmux komutuna girmez — kasadan ortam
#    değişkenine çekilir, kapıyı başlatan kabuk onu dosyadan kendisi okur.
sifre_var_mi() { [ -n "$(eval "printf '%s' \"\${$SIFRE_ANAHTAR:-}\"")" ]; }
# 🔴 Ortam dosyası SOURCE EDİLMEZ (2.2.2 · 13 Eki ölçümü): üç kutuda dosyada AD=değer olmayan satırlar vardı; `. dosya`
#    bash'e o satırları KOMUT diye koşturdu, "command not found" ile değer parçaları stderr'e düştü (sır sızıntısı) ve
#    kabuk bir komut çalıştırmış da olabilirdi. Yalnız `AD=değer` biçimli satırlar okunur, çevreleyen tırnak soyulur,
#    gerisi SAYILIR ama ne koşturulur ne basılır (fail-closed: bozuk satır sayısı ölçülebilir, içerik görünmez).
ORTAM_BOZUK_SATIR=0
ortam_yukle() {  # $1 = dosya → yalnız AD=değer satırlarını ortama alır; bozuk satırları sayar (içerik basmaz)
  local d="$1" satir ad deger
  [ -f "$d" ] || return 1
  ORTAM_BOZUK_SATIR=0
  while IFS= read -r satir || [ -n "$satir" ]; do
    satir="${satir%$'\r'}"
    case "$satir" in ''|'#'*) continue ;; esac
    satir="${satir#export }"
    case "$satir" in
      [A-Za-z_]*=*) ad="${satir%%=*}"; deger="${satir#*=}"
        case "$ad" in *[!A-Za-z0-9_]*) ORTAM_BOZUK_SATIR=$((ORTAM_BOZUK_SATIR+1)); continue ;; esac
        case "$deger" in \"*\") deger="${deger#\"}"; deger="${deger%\"}" ;; \'*\') deger="${deger#\'}"; deger="${deger%\'}" ;; esac
        export "$ad=$deger" ;;
      *) ORTAM_BOZUK_SATIR=$((ORTAM_BOZUK_SATIR+1)) ;;
    esac
  done < "$d"
  return 0
}
sifre_yukle() {
  sifre_var_mi && return 0
  ortam_yukle "$ENV_DOSYA"
  sifre_var_mi && return 0
  bash /config/.claude/skills/vault-cek/scripts/vault-cek.sh get "$SIFRE_ANAHTAR" >/dev/null 2>&1 || return 1
  ortam_yukle "$ENV_DOSYA"
  sifre_var_mi
}

haber() {  # Sultan'a WhatsApp — başarısızlık onarımı durdurmaz
  bash /config/.claude/skills/whatsapp-gonder/scripts/wa-gonder.sh --kime Sultan "$*" >/dev/null 2>&1 \
    || gunluk "uyari: whatsapp haberi gitmedi"
}
