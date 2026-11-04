#!/usr/bin/env bash
# usta.sh — USTA = UYUYAN OTURUM (Sultan onaylı usta düzeni, 2 Kas 2026 · kart usta-uyku-uyandir)
#
#   usta.sh liste   [--kayit F] [--proje D]               → her usta: ad · durum (uyanik|uyuyor|kayit-eksik) · klasor · oda (kayıtta yoksa boş)
#   usta.sh uyandir <AD> [--kuru] [--kayit F] [--proje D] → ustanın KENDİ klasöründe `claude --resume <sohbet>`; kilit + tavan
#   usta.sh uyut    <AD> [--kuru] [--kayit F]             → kapanış kancası (DURUM.md) sonra oturumu kapatır
#
# KAYIT (ekip-registry.yaml, usta başına): ad · klasor (proje köküne göre, örn. ustalar/PERGEL) · sohbet (claude oturum kimliği) · koltuk: yok
#
# 🔴 YANLIŞ KLASÖR KİLİDİ: claude --resume kimliği BAŞKA klasörde de açar, HATA VERMEZ ve hafızayı karıştırır (prova).
#    Konuşma dosyası yalnız ustanın kendi klasörünün proje dizininde olmalı: <config>/projects/<klasör-kodu>/<sohbet>.jsonl.
#    Yoksa AÇILMAZ (rc 4). Klasör kodu = mutlak yolun / . _ karakterlerinin '-' yapılmış hâli.
# 🔴 TAVAN: aynı anda en çok UST_TAVAN (vars. 6) uyanık usta; dolunca EN BOŞTA olan (tmux son etkinliği en eski) uyutulur.
# 🔴 KAPANIŞ KANCASI: uyutmadan önce Claude'a "DURUM.md'yi güncelle" yazılır, ekran sakinleşene dek beklenir; araç ayrıca
#    DURUM.md'ye bir uyutma damgası ekler (dosya her koşulda dokunulmuş olur).
# rc: 0 tamam · 2 kullanım · 3 ölçülemedi · 4 kilit (yanlış klasör/sohbet yok) · 5 kayıt eksik/usta yok
set -uo pipefail
TM="${USTA_TMUX:-tmux}"
TAVAN="${UST_TAVAN:-6}"
CL="${USTA_CLAUDE:-claude}"
CFG="${USTA_CONFIG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
BEKLE="${UYUT_BEKLE_SN:-90}"; SAKIN="${UYUT_SAKIN_SN:-8}"
KOMUT="${1:-}"; [ $# -gt 0 ] && shift
AD=""; KURU=0; KAYIT="${USTA_KAYIT:-}"; PROJE="${USTA_PROJE:-${TO_PROJE:-$PWD}}"
case "$KOMUT" in uyandir|uyut) AD="${1:-}"; [ $# -gt 0 ] && shift;; esac
while [ $# -gt 0 ]; do case "$1" in
  --kuru) KURU=1;; --kayit) KAYIT="$2"; shift;; --proje) PROJE="$2"; shift;;
  *) echo "usta.sh: bilinmeyen argüman '$1'" >&2; exit 2;; esac; shift; done
case "$KOMUT" in liste|uyandir|uyut) ;; *) sed -n 2,14p "$0" | sed 's/^# \{0,1\}//'; exit 2;; esac
[ -n "$KAYIT" ] || KAYIT="$PROJE/_agents/handoff/ekip-registry.yaml"
[ -f "$KAYIT" ] || { echo "usta.sh: kayıt yok: $KAYIT" >&2; exit 5; }

# kayıttan ustaları oku: ad<TAB>klasor<TAB>sohbet<TAB>oda  (yalnız klasor alanı olan üyeler usta sayılır)
ustalar() { python3 -I - "$KAYIT" <<'PY'
# PyYAML'a BAĞLI DEĞİL (ortam-yukle PATH'i değişince yaml görünmeyebiliyor): düz satır ayrıştırma. İki biçim: akış `- {ad: X, klasor: Y}`
# ve blok (`- id:`/`- ad:` + girintili alanlar). Yorum (#) ve tırnak atılır.
import re, sys
def temiz(v): return re.sub(r'\s+#.*$', '', v).strip().strip('"\'')
uyeler, cur = [], None
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.rstrip('\n')
    if re.match(r'^\s*#', line) or not line.strip(): continue
    m = re.match(r'^\s*-\s*\{(.*)\}\s*(#.*)?$', line)
    if m:
        cur = {}
        for kv in re.split(r',\s*(?=\w+\s*:)', m.group(1)):
            k, _, v = kv.partition(':'); cur[k.strip()] = temiz(v)
        uyeler.append(cur); cur = None; continue
    m = re.match(r'^\s*-\s*(\w+):\s*(.*)$', line)
    if m:
        cur = {m.group(1): temiz(m.group(2))}; uyeler.append(cur); continue
    m = re.match(r'^\s+(\w+):\s*(.*)$', line)
    if m and cur is not None: cur.setdefault(m.group(1), temiz(m.group(2)))
for u in uyeler:
    ad = u.get('ad') or u.get('id') or ''
    if ad and u.get('klasor') and u.get('koltuk', '').lower() == 'yok': print('\t'.join([ad, u['klasor'], u.get('sohbet') or u.get('session_id', ''), u.get('oda', '')]))
PY
}
usta_satir() { ustalar | awk -F'\t' -v a="$1" '$1==a{print; exit}'; }
kod() { printf '%s' "$1" | sed 's#[/._]#-#g'; }     # mutlak yol → claude proje dizini adı
uyanik_mi() { "$TM" has-session -t "=$1" 2>/dev/null; }
son_etkinlik() { local v; v="$("$TM" list-sessions -F '#{session_name} #{session_activity}' 2>/dev/null | awk -v a="$1" '$1==a{print $2; exit}')"; case "$v" in ''|*[!0-9]*) echo 0;; *) echo "$v";; esac; }

uyut_et() { # <AD> <klasor-mutlak> → rc 0 yalnız kanca + damga + kapanış DOĞRULANDIYSA; aksi hâlde oturuma DOKUNULMAZ/açık kalır, rc 3
  local ad="$1" kl="$2" t0 sk=0 h="" n
  if uyanik_mi "$ad"; then
    "$TM" send-keys -t "=$ad:" "DURUM.md dosyasını şimdi güncelle: yaptığın, bıraktığın ve sıradaki adımı yaz; sonra bekle." Enter 2>/dev/null \
      || { echo "uyutulamadı: $ad — kapanış kancası Claude'a iletilemedi" >&2; return 3; }
    t0=$(date +%s)
    while [ $(( $(date +%s) - t0 )) -lt "$BEKLE" ]; do
      sleep 1; n="$("$TM" capture-pane -p -t "=$ad:" 2>/dev/null | md5sum)"
      if [ "$n" = "$h" ]; then sk=$((sk+1)); else sk=0; h="$n"; fi
      [ "$sk" -ge "$SAKIN" ] && break
    done
  fi
  printf '\n- uyutuldu %s (usta.sh)\n' "$(date '+%Y-%m-%d %H:%M')" >> "$kl/DURUM.md" 2>/dev/null \
    || { echo "uyutulamadı: $ad — $kl/DURUM.md yazılamadı (oturum açık bırakıldı)" >&2; return 3; }
  "$TM" kill-session -t "=$ad" 2>/dev/null
  if uyanik_mi "$ad"; then echo "uyutulamadı: $ad — oturum kapanmadı" >&2; return 3; fi
  return 0
}
mutlak() { case "$1" in /*) printf '%s' "$1";; *) printf '%s/%s' "$PROJE" "$1";; esac; }

case "$KOMUT" in
  liste)
    ustalar | tr '\t' '\037' | while IFS=$'\037' read -r a k s o; do   # sekme boşluk sayılır, ardışık sekme tek olur: boş sohbet alanı odayı sohbete kaydırırdı
      d=uyuyor; uyanik_mi "$a" && d=uyanik; { [ -n "$s" ] && [ -n "$k" ]; } || d=kayit-eksik
      printf '%s\t%s\t%s\t%s\n' "$a" "$d" "$k" "$o"; done ;;
  uyandir)
    [ -n "$AD" ] || { echo "kullanım: usta.sh uyandir <AD> [--kuru]" >&2; exit 2; }
    sat="$(usta_satir "$AD")"; [ -n "$sat" ] || { echo "usta yok: '$AD' (kayıtta klasor alanlı üye değil)" >&2; exit 5; }
    IFS=$'\037' read -r _ K S _ <<<"$(printf '%s' "$sat" | tr '\t' '\037')"
    [ -n "$S" ] || { echo "kayıt eksik: '$AD' için sohbet kimliği yok — kimliksiz Claude açılmaz" >&2; exit 5; }
    MK="$(mutlak "$K")"; [ -d "$MK" ] || { echo "klasör yok: $MK" >&2; exit 5; }
    MK="$(cd "$MK" && pwd -P)"
    DOSYA="$CFG/projects/$(kod "$MK")/$S.jsonl"
    [ -f "$DOSYA" ] || { echo "KİLİT: '$AD' sohbeti $S bu klasörün ($MK) proje dizininde YOK — başka klasörde resume hafızayı karıştırır, açılmadı" >&2; exit 4; }
    if uyanik_mi "$AD"; then echo "zaten uyanık: $AD"; exit 0; fi
    uyanikler=(); while IFS=$'\t' read -r a _ _; do uyanik_mi "$a" && uyanikler+=("$a"); done < <(ustalar)
    if [ "${#uyanikler[@]}" -ge "$TAVAN" ]; then
      en=""; ens=9999999999
      for a in "${uyanikler[@]}"; do e="$(son_etkinlik "$a")"; [ "$e" -lt "$ens" ] && { ens="$e"; en="$a"; }; done
      if [ "$KURU" = 1 ]; then echo "KURU: tavan $TAVAN dolu → en boştaki uyutulur: $en"
      else uyut_et "$en" "$(mutlak "$(usta_satir "$en" | cut -f2)")" || { echo "tavan dolu ($TAVAN) ve en boştaki ($en) uyutulamadı — yeni usta AÇILMADI" >&2; exit 3; }
        echo "uyutuldu (tavan): $en"; fi
    fi
    if [ "$KURU" = 1 ]; then echo "KURU: $AD ← cd $MK && $CL --resume $S (kilit geçti)"; exit 0; fi
    "$TM" new-session -d -s "$AD" -c "$MK" "$(printf '%q' "$CL") --resume $(printf '%q' "$S")" 2>/dev/null
    if uyanik_mi "$AD"; then echo "uyandı: $AD"; else echo "açılamadı: $AD" >&2; exit 3; fi ;;
  uyut)
    [ -n "$AD" ] || { echo "kullanım: usta.sh uyut <AD>" >&2; exit 2; }
    sat="$(usta_satir "$AD")"; [ -n "$sat" ] || { echo "usta yok: '$AD'" >&2; exit 5; }
    K="$(mutlak "$(printf '%s' "$sat" | cut -f2)")"
    if [ "$KURU" = 1 ]; then echo "KURU: $AD uyutulur (kanca + $K/DURUM.md damgası)"; exit 0; fi
    uyut_et "$AD" "$K" || exit 3; echo "uyutuldu: $AD" ;;
esac
