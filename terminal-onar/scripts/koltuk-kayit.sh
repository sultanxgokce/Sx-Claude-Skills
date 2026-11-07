#!/usr/bin/env bash
# koltuk-kayit.sh — kutu yeniden doğunca personel koltuklarının kendiliğinden geri gelmesi (2.46.0 · kart koltuk-geri-donus-auto ·
#   görev …W38BCZ madde 1-2 · tasarım Nexus _agents/spec/ortak-ayar-dizini-ve-koltuk-geri-donusu-DESIGN.md §4).
#
#   koltuk-kayit.sh yaz <ad> <rol> <session_id> <cwd>   koltuğu açan betik çağırır: kaydı yazar/günceller (anahtar = ad)
#   koltuk-kayit.sh sil <ad>                            kaydı siler (koltuk kendiliğinden dönmemeli: özel izin dosyası vb.)
#   koltuk-kayit.sh don                                 dakikalık bekçi çağırır: yeniden doğuştan sonra koltukları geri açar
#
# KAYIT: $DURUM_DIZ/koltuklar.tsv (vars. /config/.terminal-onar/koltuklar.tsv — kutunun kalıcı dizini, yeniden doğuşta kalır).
#   Sütunlar: ad · rol · session_id · cwd. 🔴 İZİN MODU YAZILMAZ ve OKUNMAZ: dönüş HER ZAMAN `--permission-mode auto`dur
#   (ana koltukla aynı yol, onar.sh). Fazladan sütun (ör. biri izin modu yazdıysa) yok sayılır. Bypass'a yükseltme bu betiğin
#   işi DEĞİLDİR (tasarım §4 madde 3, Sultan kararı); komut satırında bypass görülürse açılmaz (savunma kapısı).
#   Tek yazıcı: koltuğu açan betik (bugün iskan/templates/baslat-claude.sh). Elle satır yazılmaz.
#
# DÖNÜŞ KURALI (don): koltuk YALNIZ şu üçü birlikteyse açılır —
#   1) kayıtlı ve tmux'ta yok,
#   2) kutu YENİDEN DOĞMUŞ ve koltuk ÖNCEKİ doğuşta bekçinin son gördüğü hâliyle canlıydı (ya da bekçi onu açmıştı),
#   3) bu doğuşta henüz ne canlı görüldü ne de açılmaya çalışıldı.
#   🔴 Niçin 2 ve 3: kutuda koltuğu BİLEREK kapatan yollar var (Kadro dondur/emekli, boşta oturum taraması, usta uyut, dava
#      dondur). Yalnız "kayıtlı ve tmux'ta yok" ölçütü bunları her dakika geri açardı. Bu doğuşta canlı görülüp kapanan koltuk
#      bilerek kapatılmış sayılır, geri açılmaz; doğuştan önce kapalı olan koltuk da dönmez (dondurulmuş koltuk dondurulmuş kalır).
#   Doğuş damgası = kutunun 1 numaralı sürecinin başlama anı (/proc/stat btime + /proc/1/stat başlama tıkı): kutu yeniden
#   yaratılınca ya da yeniden başlatılınca değişir, bekçinin her turunda aynıdır.
#   Tur başına en çok KOLTUK_DONUS_TAVAN (vars. 2) koltuk açılır (bellek: 2-4 GB tavanlı kutuda hepsini birden açmak taşırır);
#   kalanlar sonraki dakikalara kalır. Bir koltuk bir doğuşta EN ÇOK BİR KEZ açılır: açılıp yaşamazsa yeniden denenmez (döngü yok).
#   Açılmayan her koltuğun sebebi kutu günlüğüne yazılır (yalnız durum DEĞİŞTİĞİNDE — her dakika aynı satır yazılmaz).
# Durum: $DURUM_DIZ/koltuk-donus.durum (ad · doğuş · hal). Hal: canli · acildi · bekliyor · yasamadi · kapandi · gorulmedi · bozuk · baska-yerde
# rc: 0 tamam · 2 kullanım/geçersiz girdi · 3 ölçülemedi (doğuş damgası okunamadı)
set -uo pipefail
_D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DURUM_DIZ="${TO_DURUM_DIZ:-/config/.terminal-onar}"
KAYIT="${TO_KOLTUK_KAYIT:-$DURUM_DIZ/koltuklar.tsv}"
. "$_D/koltuk-adi.sh"
SID_DESEN='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
temiz_alan() { [ -n "$1" ] && [ "${#1}" -le 400 ] && ! [[ "$1" =~ [[:cntrl:]] ]]; }

kayit_yaz() {  # $1 ad $2 rol $3 sid $4 cwd
  local ad="$1" rol="$2" sid="$3" cwd="$4"
  koltuk_adi_gecerli "$ad" || { echo "koltuk-kayit: geçersiz koltuk adı" >&2; return 2; }
  temiz_alan "$rol" || { echo "koltuk-kayit: geçersiz rol ($ad)" >&2; return 2; }
  [[ "$sid" =~ $SID_DESEN ]] || { echo "koltuk-kayit: session_id biçimi bozuk ($ad) — yazılmadı" >&2; return 2; }
  temiz_alan "$cwd" && [ "${cwd:0:1}" = / ] && [ -d "$cwd" ] || { echo "koltuk-kayit: çalışma dizini yok ya da göreli ($ad)" >&2; return 2; }
  mkdir -p "$(dirname "$KAYIT")" 2>/dev/null
  (
    flock -w 5 9 || { echo "koltuk-kayit: kilit alınamadı" >&2; exit 1; }
    local g KAYIT_VAR=""; g="$(mktemp "$KAYIT.XXXXXX")" || exit 1; [ -f "$KAYIT" ] && KAYIT_VAR="$KAYIT"
    { printf '# ad\trol\tsession_id\tcwd   (yazan: koltuğu açan betik · izin modu YOK, dönüş her zaman auto · terminal-onar koltuk-kayit.sh)\n'
      # yerinde güncelle (kayıt sırası = dönüş sırası korunur), yoksa sona ekle
      # değerler ENVIRON'dan (awk -v ters bölüyü kaçış sayar, dizin adını bozardı)
      KK_AD="$ad" KK_Y="$(printf '%s\t%s\t%s\t%s' "$ad" "$rol" "$sid" "$cwd")" awk -F'\t' \
        'BEGIN {a=ENVIRON["KK_AD"]; y=ENVIRON["KK_Y"]} /^#/ {next} $1 == a {if (!b) print y; b=1; next} {print} END {if (!b) print y}' \
        "${KAYIT_VAR:-/dev/null}"; } > "$g" && mv -f "$g" "$KAYIT"
  ) 9>"$KAYIT.lock"
}
kayit_sil() {  # $1 ad
  koltuk_adi_gecerli "$1" || { echo "koltuk-kayit: geçersiz koltuk adı" >&2; return 2; }
  [ -f "$KAYIT" ] || return 0
  (
    flock -w 5 9 || exit 1
    local g; g="$(mktemp "$KAYIT.XXXXXX")" || exit 1
    KK_AD="$1" awk -F'\t' '/^#/ || $1 != ENVIRON["KK_AD"]' "$KAYIT" > "$g" && mv -f "$g" "$KAYIT"
  ) 9>"$KAYIT.lock"
}

dogus_damgasi() {  # kutunun 1 numaralı sürecinin başlama anı — opak, yeniden doğuşta değişir
  [ -n "${TO_DOGUS:-}" ] && { printf '%s' "$TO_DOGUS"; return 0; }
  local bt st s
  bt="$(awk '$1=="btime"{print $2}' /proc/stat 2>/dev/null)"
  s="$(cat /proc/1/stat 2>/dev/null)" || return 1
  s="${s##*) }"; set -- $s; st="${20:-}"
  [ -n "$bt" ] && [ -n "$st" ] || return 1
  printf '%s.%s' "$bt" "$st"
}

kayit_don() {
  . "$_D/ortak.sh" || exit 3   # kutu adı reddi: ortak.sh sebebi tek satır yazdı → DUR, rc 3 (FSZ30 sözleşmesi, kutu-red.test.sh R8c)
  [ -s "$KAYIT" ] || return 0                                          # kayıt yoksa no-op
  local DURUM="$DURUM_DIZ/koltuk-donus.durum" TAVAN="${KOLTUK_DONUS_TAVAN:-2}" D
  D="$(dogus_damgasi)" || D=""
  if [ -z "$D" ]; then
    [ -f "$DURUM_DIZ/koltuk-donus.olculemedi" ] || { gunluk "bekçi: koltuk dönüşü ÖLÇÜLEMEDİ — kutunun doğuş anı okunamadı (/proc), hiçbir koltuk açılmadı"; : > "$DURUM_DIZ/koltuk-donus.olculemedi"; }
    return 3
  fi
  rm -f "$DURUM_DIZ/koltuk-donus.olculemedi"
  exec 8>"$DURUM_DIZ/koltuk-donus.lock"; flock -n 8 || return 0   # önceki tur sürüyorsa bu tur atlanır
  local -A ESKI_D ESKI_H
  local ad rol sid cwd _f h
  if [ -f "$DURUM" ]; then
    while IFS=$'\t' read -r ad _f h; do [ -n "$ad" ] && { ESKI_D[$ad]="$_f"; ESKI_H[$ad]="$h"; }; done < "$DURUM"
  fi
  local yeni; yeni="$(mktemp "$DURUM.XXXXXX")" || return 1
  local acilan=0 CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" CL="" kod komut
  # hal yaz + yalnız DEĞİŞTİYSE günlüğe → durum dosyasına satır
  _hal() {  # $1 ad $2 hal $3 günlük metni (boşsa yazılmaz)
    if [ -n "$3" ] && { [ "${ESKI_D[$1]:-}" != "$D" ] || [ "${ESKI_H[$1]:-}" != "$2" ]; }; then gunluk "bekçi: koltuk $1: $3"; fi
    printf '%s\t%s\t%s\n' "$1" "$D" "$2" >> "$yeni"
  }
  while IFS=$'\t' read -r ad rol sid cwd _f; do
    case "$ad" in ''|'#'*) continue ;; esac
    koltuk_adi_gecerli "$ad" || continue
    [ "$ad" = "$ANA_TMUX" ] && continue                              # ana koltuk onar.sh'ın (aynı yol, ayrı sahip)
    if tmux_var "$ad"; then _hal "$ad" canli ""; continue; fi          # canlı koltuğa DOKUNULMAZ
    local od="${ESKI_D[$ad]:-}" oh="${ESKI_H[$ad]:-}"
    if [ "$od" = "$D" ]; then                                          # bu doğuşta bu koltuk için zaten bir hal var
      case "$oh" in
        canli)    _hal "$ad" kapandi "bu doğuşta canlıydı, kapanmış — bilerek kapatılmış sayılır, geri AÇILMAZ"; continue ;;
        acildi)   _hal "$ad" yasamadi "geri açılmıştı ama yaşamadı — bu doğuşta yeniden DENENMEZ (kutu günlüğüne bak)"; continue ;;
        bekliyor) ;;                                                   # tavana takılmıştı: sırası geldi, aşağıda açılır
        *)        _hal "$ad" "$oh" ""; continue ;;                     # kapandi · yasamadi · gorulmedi · bozuk · baska-yerde: kalır
      esac
    else                                                               # yeni doğuş (ya da hiç hal yok): önceki doğuşun son hali
      case "$oh" in
        canli|acildi|bekliyor) ;;                                      # kutu ölürken canlıydı → döner
        *) _hal "$ad" gorulmedi "kayıtlı ama kutu ölürken canlı görülmedi — kendiliğinden AÇILMAZ (açmak için: koltuk-ac.sh ac $ad)"; continue ;;
      esac
    fi
    [[ "$sid" =~ $SID_DESEN ]] || { _hal "$ad" bozuk "kayıttaki session_id boş ya da bozuk — AÇILMADI (kimliksiz Claude açılmaz)"; continue; }
    [ "${cwd:0:1}" = / ] && [ -d "$cwd" ] || { _hal "$ad" bozuk "kayıttaki çalışma dizini yok — AÇILMADI"; continue; }
    kod="$(printf '%s' "$cwd" | sed 's/[^A-Za-z0-9]/-/g')"
    [ -f "$CFG/projects/$kod/$sid.jsonl" ] || { _hal "$ad" bozuk "konuşma dosyası bu kutuda bu dizinde yok ($sid) — AÇILMADI (yanlış dizinde resume hafızayı karıştırır)"; continue; }
    if oturum_canli_mi "$sid"; then _hal "$ad" baska-yerde "konuşma ($sid) başka bir yerde açık — ikinci kopya AÇILMADI"; continue; fi
    if [ "$acilan" -ge "$TAVAN" ]; then _hal "$ad" bekliyor "sırada (tur başına en çok $TAVAN koltuk açılır) — sonraki dakika"; continue; fi
    [ -n "$CL" ] || CL="${TO_CLAUDE:-$(claude_yolu 2>/dev/null)}"
    [ -x "${CL:-}" ] || { _hal "$ad" bekliyor "çalışan claude bulunamadı — bu tur açılmadı, sonraki dakika yeniden denenir"; continue; }
    komut="exec env $BELLEK_ENV $SIKISTIRMA_ENV $(printf '%q' "$CL") --resume $(printf '%q' "$sid") --permission-mode auto"
    # savunma kapısı: dönüş yetki yükseltmez — komutta izin atlatma görülürse açılmaz
    case "$komut" in *dangerously*|*bypassPermissions*|*--allow-dangerously*) _hal "$ad" bozuk "komut satırında izin atlatma göründü — AÇILMADI"; continue ;; esac
    if tmux new-session -d -s "$ad" -c "$cwd" "$komut" 2>/dev/null; then
      acilan=$((acilan + 1)); _hal "$ad" acildi "yeniden doğuştan sonra geri açıldı (claude --resume $sid --permission-mode auto)"
    else
      _hal "$ad" yasamadi "tmux oturumu kurulamadı — bu doğuşta yeniden DENENMEZ"
    fi
  done < "$KAYIT"
  mv -f "$yeni" "$DURUM"
  return 0
}

case "${1:-}" in
  yaz) [ $# -eq 5 ] || { echo "kullanım: koltuk-kayit.sh yaz <ad> <rol> <session_id> <cwd>" >&2; exit 2; }; kayit_yaz "$2" "$3" "$4" "$5" ;;
  sil) [ $# -eq 2 ] || { echo "kullanım: koltuk-kayit.sh sil <ad>" >&2; exit 2; }; kayit_sil "$2" ;;
  don) [ $# -eq 1 ] || { echo "kullanım: koltuk-kayit.sh don" >&2; exit 2; }; kayit_don ;;
  *) sed -n 2,8p "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
