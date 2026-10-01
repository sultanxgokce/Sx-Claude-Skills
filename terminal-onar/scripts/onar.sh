#!/usr/bin/env bash
# onar.sh — KADEME 0: deterministik onarım. Her adım idempotent: sağlam parçaya DOKUNMAZ,
# yalnız eksik olanı kurar. Sıfırdan inşa da budur (hiçbir şey yokken koşunca hepsini kurar).
#   --web-yenile   web terminalini sağlam olsa bile yeniden başlat (ör. yeni parola kasaya konduktan sonra)
# RC: 0 = sonunda durum sağlam · 1 = hâlâ bozuk (sonraki kademeye geç) · 2 = parola kasada yok
set -u
. "$(dirname "$0")/ortak.sh"
WEB_YENILE=0; [ "${1:-}" = "--web-yenile" ] && WEB_YENILE=1
gunluk "K0 onar başladı"
SIFRE_YOK=0

# ── ÖN KOŞUL: tmux'un varsayılan kabuğu GERÇEK bir kabuk mu ────────────────────
# 🔴 Niçin (SEDİR/RAHVAN uyarısı + REVAK'ta ölçülen vaka, 2026-09-29): LSIO imajında
#    `abc` kullanıcısının kabuğu `/bin/false`. Kutuda `.tmux.conf`'ta `default-shell`
#    satırı yoksa her oturum DOĞAR DOĞMAZ ölür. Belirtisi yanıltıcıdır: tmux rc=0 döner,
#    soket bile oluşur; yalnız ayrıntılı günlükte "%0 error" görünür. Sonuç: telefonda
#    terminal açılıp kapanır, bekçi her dakika yeniden kurar, merdiven K1/K2'ye tırmanır
#    ve her tırmanış yeni bir Claude süreci (yani bellek) demektir.
# 🔴 KENDİLİĞİNDEN DÜZELTMİYORUZ, DURUYORUZ: `.tmux.conf` kutu genelinde ORTAK bir dosyadır;
#    başkasının dosyasına sessizce yazmak onarımın işi değil (öneri: RAHVAN).
# 🔴 İKİ DÜZELTME (bağımsız göz, tur 1 — ikisi de haklıydı):
#  1) ESKİ HÂLİ ASIL VAKAYI KORUMUYORDU. tmux sunucusu YOKKEN `$SHELL`e düşüyordu; ama
#     $SHELL ÇAĞIRANIN ortamıdır, hesabın kabuğu değil. Yeni doğmuş bir kutuda hesabın
#     kabuğu /bin/false iken, onarımı geçerli bir kabuktan çalıştırmak kapıyı AÇIYORDU —
#     yani kapı tam da yazıldığı vakada sessiz kalıyordu. Artık sunucu yoksa HESABIN
#     kabuğu okunur (parola dosyası), ortam değişkeni DEĞİL.
#  2) "ÇALIŞTIRILABİLİR" KABUK DEMEK DEĞİL. Eski ölçüt yalnız adı false/nologin ile biten
#     yolları eliyor ve çalıştırılabilirlik bitine bakıyordu; /bin/true gibi hemen çıkan
#     bir dosya GEÇERLİ sayılıyordu ve aynı "oturum doğar doğmaz ölür" hâlini üretirdi.
#     Artık kabuğun kabuk gibi DAVRANDIĞI ölçülür: bir komut verilip çıktısı okunur.
_hesap_kabugu() {
  local u; u="$(id -un 2>/dev/null)" || return 1
  getent passwd "$u" 2>/dev/null | awk -F: '{print $7}' | head -1
}
kabuk_gecerli_mi() {
  local k; k=$(tmux show -gv default-shell 2>/dev/null)
  [ -n "$k" ] || k="$(_hesap_kabugu)"
  case "$k" in ""|*/false|*/nologin) return 1 ;; esac
  [ -x "$k" ] || return 1
  # Davranış ölçümü: çıkış kodu YETMEZ (/bin/true da 0 döner), ÇIKTI okunur.
  [ "$("$k" -c 'printf kabuk' 2>/dev/null)" = "kabuk" ]
}
if ! kabuk_gecerli_mi; then
  gunluk "K0 DUR: tmux varsayılan kabuğu çalıştırılabilir DEĞİL ($(tmux show -gv default-shell 2>/dev/null || echo tanımsız)) — oturumlar doğar doğmaz ölür"
  gunluk "K0 ÇARE: kutunun .tmux.conf dosyasına tek satır: set -g default-shell /bin/bash"
  exit 3
fi

# Bir tmux oturumunda Claude başlat (kabuk boştaysa aynı pencerede, değilse yeni pencerede).
# 🔴 26 Eyl dersi: eski sürüm "yeni pencere" açamayınca komutu CANLI Claude'un içine yazdı.
#    Artık hedef pane kimliğiyle (%N) seçilir ve yazmadan hemen önce yeniden ölçülür:
#    panede kabuk dışında bir şey çalışıyorsa YAZILMAZ.
claude_baslat() {
  local tm="$1" komut="$2" hedef cmd
  if claude_pid "$tm" >/dev/null; then gunluk "K0 DUR: $tm içinde Claude zaten çalışıyor — yazılmadı"; return 0; fi
  hedef=$(tmux list-panes -t "=$tm:" -F '#{pane_id}' 2>/dev/null | head -1)
  cmd=$(tmux display -p -t "$hedef" '#{pane_current_command}' 2>/dev/null)
  case "$cmd" in
    bash|sh|zsh|dash) ;;
    *) hedef=$(tmux new-window -P -F '#{pane_id}' -t "=$tm:" -c "$PROJE" 2>/dev/null) \
         || { gunluk "K0 HATA: $tm içinde yeni pencere açılamadı — yazılmadı"; return 1; }
       sleep 1 ;;
  esac
  cmd=$(tmux display -p -t "$hedef" '#{pane_current_command}' 2>/dev/null)
  case "$cmd" in bash|sh|zsh|dash) ;; *) gunluk "K0 DUR: hedef panede '$cmd' çalışıyor — yazılmadı"; return 1 ;; esac
  tmux send-keys -t "$hedef" -l "cd $PROJE && $BELLEK_ENV $komut"
  tmux send-keys -t "$hedef" Enter
  local i; for i in $(seq 1 45); do sleep 2; claude_pid "$tm" >/dev/null && return 0; done
  return 1
}

# 1 · konuşma odası
if ! tmux_var "$ANA_TMUX"; then
  tmux new-session -d -s "$ANA_TMUX" -c "$PROJE" && gunluk "K0 tmux $ANA_TMUX kuruldu"
fi

# 2 · konuşma (Claude) — hep AYNI konuşmaya dön (kimlik diskte), asla rastgele "son oturum"a değil
if ! claude_oturumu "$ANA_TMUX" >/dev/null; then
  id=$(cat "$DURUM_DIZ/ana-oturum" 2>/dev/null)
  if [ -n "$id" ] && oturum_canli_mi "$id"; then
    gunluk "K0 UYARI: ana konuşma ($id) başka bir yerde açık — ikinci kopya AÇILMADI"
  elif [ -n "$id" ] && ls "$HOME"/.claude/projects/*/"$id".jsonl >/dev/null 2>&1; then
    claude_baslat "$ANA_TMUX" "claude --resume $id --permission-mode auto" \
      && gunluk "K0 ana konuşma geri açıldı ($id)" || gunluk "K0 HATA: ana konuşma açılamadı"
  else
    claude_baslat "$ANA_TMUX" "claude -n $ANA_AD --permission-mode auto" \
      && gunluk "K0 kayıtlı konuşma yok → yeni konuşma açıldı" || gunluk "K0 HATA: yeni konuşma açılamadı"
  fi
fi

# 3 · web terminali (ttyd, yalnız soket) + kapı (:7681, telefon ekranı + giriş)
#     Parolasız kapı ASLA açılmaz (fail-closed). ttyd'nin kendi parolası yok: dışarıya portu yok,
#     tek yolu girişi yapan kapıdır.
# telefon bağlanınca masaüstü kalıcı daralmasın. Pencere kimliğiyle hedeflenir — "=oturum" PENCERE adı sanılır,
# ayar sessizce düşer ve genel "smallest" kalır (25 Eyl ölçüldü: Mac daralmasının kökü buydu).
for w in $(tmux list-windows -t "=$ANA_TMUX" -F '#{window_id}' 2>/dev/null); do
  tmux set-option -w -t "$w" window-size latest 2>/dev/null || gunluk "K0 UYARI: $ANA_TMUX window-size ayarlanamadı"
done
if [ $WEB_YENILE = 1 ] || ! ttyd_saglam; then
  tmux kill-session -t "=$TTYD_TMUX" 2>/dev/null
  pkill -u "$(id -u)" -f "ttyd .*-p $KAPI_PORT " 2>/dev/null   # eski düzen (parolalı ttyd :7681) kalıntısı
  pkill -u "$(id -u)" -f "ttyd .*$TTYD_SOKET" 2>/dev/null; sleep 1
  rm -f "$TTYD_SOKET"; chmod 700 "$DURUM_DIZ" 2>/dev/null
  tmux new-session -d -s "$TTYD_TMUX" "exec $TTYD_BIN -W -i $TTYD_SOKET -b $TABAN/tty \
    -t fontSize=12 -t disableLeaveAlert=true -t disableResizeOverlay=true -t titleFixed=Sedir \
    -t 'theme={\"background\":\"#15120e\",\"foreground\":\"#ede5d7\",\"cursor\":\"#c9914f\"}' \
    tmux new-session -A -s $ANA_TMUX -c $PROJE"
  bekle_saglam ttyd_saglam "$TTYD_BEKLE" || true
  ttyd_saglam && gunluk "K0 terminal (ttyd) başlatıldı" || gunluk "K0 HATA: terminal ayağa kalkmadı ($(ttyd_kod))"
fi
if [ $WEB_YENILE = 1 ] || ! kapi_saglam; then
  if ! sifre_yukle; then
    SIFRE_YOK=1; gunluk "K0 HATA: $SIFRE_ANAHTAR kasada yok — kapı parolasız AÇILMADI"
  else
    tmux kill-session -t "=$KAPI_TMUX" 2>/dev/null
    pkill -u "$(id -u)" -f "ttyd .*-p $KAPI_PORT " 2>/dev/null
    pkill -u "$(id -u)" -f "node $KAPI_DIZ/sunucu.mjs" 2>/dev/null; sleep 1
    # Parola tmux komutuna YAZILMAZ: kapıyı başlatan kabuk onu env dosyasından kendisi okur.
    tmux new-session -d -s "$KAPI_TMUX" \
      "set -a; . $ENV_DOSYA; set +a; KAPI_PORT=$KAPI_PORT KAPI_TTYD_SOKET=$TTYD_SOKET TO_ANA_TMUX=$ANA_TMUX TO_DURUM_DIZ=$DURUM_DIZ KAPI_TABAN=$TABAN TO_KUTU=$KUTU exec node $KAPI_DIZ/sunucu.mjs >> $DURUM_DIZ/kapi.log 2>&1"
    bekle_saglam kapi_saglam "$KAPI_BEKLE" || true
    kapi_saglam && gunluk "K0 kapı başlatıldı" || gunluk "K0 HATA: kapı ayağa kalkmadı ($(kapi_kod))"
  fi
fi

# 4 · kurtarıcı ajan — kendi Claude'u, yalnız onarım betiklerine sorusuz izinli
if ! claude_oturumu "$KURT_TMUX" >/dev/null; then
  tmux_var "$KURT_TMUX" || tmux new-session -d -s "$KURT_TMUX" -c "$PROJE"
  kid=$(cat "$DURUM_DIZ/kurtarici-oturum" 2>/dev/null)
  izin="--permission-mode auto --allowedTools 'Bash(bash $BETIK_DIZ/*)'"
  if [ -n "$kid" ] && ls "$HOME"/.claude/projects/*/"$kid".jsonl >/dev/null 2>&1 && ! oturum_canli_mi "$kid"; then
    k="claude --resume $kid $izin"
  else
    k="claude -n $KURT_AD $izin"
  fi
  claude_baslat "$KURT_TMUX" "$k" && gunluk "K0 kurtarıcı ajan açıldı" || gunluk "K0 HATA: kurtarıcı açılamadı"
fi

[ -n "${TO_BEKCI_YOK:-}" ] || {
# 5 · bekçi — kalıcı kopya (.oda/cron, kutu yeniden kurulunca yüklenir) + canlı crontab
BEKCI_SATIR="* * * * * bash $BETIK_DIZ/bekci.sh # terminal-onar-bekci"
ODA_CRON="$PROJE/.oda/cron"
grep -q '# terminal-onar-bekci' "$ODA_CRON" 2>/dev/null || { printf '%s\n' "$BEKCI_SATIR" >> "$ODA_CRON"; gunluk "K0 bekçi .oda/cron'a yazıldı"; }
if ! bekci_kurulu; then
  { crontab -l 2>/dev/null; printf '%s\n' "$BEKCI_SATIR"; } | crontab - && gunluk "K0 bekçi crontab'a kuruldu"
fi
}

if bash "$BETIK_DIZ/durum.sh" >/dev/null; then gunluk "K0 bitti: sağlam"; exit 0; fi
gunluk "K0 bitti: hâlâ bozuk"
[ $SIFRE_YOK = 1 ] && exit 2
exit 1
