#!/usr/bin/env bash
# koltuk-ac.sh — bir KOLTUĞU (tmux oturumu) tek komutla ölç ve aç/yeniden aç (dilim 5/5 · 13 Ekim 2026).
#
#   koltuk-ac.sh durum <ad>              → JSON: {"ad","durum","tmux","claude","hal","son","rol","resume","yol","ana"}
#   koltuk-ac.sh ac <ad> [--eski] [--zorla] → açar; --eski = eski sohbete dön (ekip-ac.sh --resume-if-known); --zorla = takılı görünen
#                                          oturumu KAPATIP yeniden doğur (zorlasız: rc 5, dokunmaz — çalışıyor olabilir)
#
# DURUM (üçü ayrı gösterilir, Sultan: "oturum kapandı/bozuldu/silindi — tekrar açmak çok basit olmalı"):
#   yok          = tmux oturumu yok · olculemedi = oturum var ama liste ölçümü düştü (Claude yok SANILMAZ; zorlasız dokunulmaz)
#   claude-yok   = oturum var, içinde Claude yok (kabuk/ölü)
#   takili       = Claude var ama TAKILI_SN (vars. 900 s) süredir ekran değişmedi ve soru/girdi beklemiyor
#   canli        = Claude var, hâl normal
# YOL (kim açar) — kutunun KENDİ açıcısı, kayıt da onun okuduğu dosya (2.4.2):
#   baslat  = İSKÂN kutusu (`scripts/baslat-claude.sh` + `iskan-registry.yaml`): koltuk kayıtlı bir rolün tmux'uysa yeni tmux
#             oturumunda baslat-claude.sh <rol> — ayrılmış kimlik, konuşma varsa ona döner
#   ekip-ac = merkez (`scripts/ekip-ac.sh` DOĞURAN sürüm + `aile-registry.yaml`): TEK-KANONİK KAPI, ikinci kopya açmaz;
#             --eski → --resume-if-known
#   onar    = koltuk ANA ise → onar.sh (K0), düşerse merdiven (kademe.sh)
#   yok     = kayıtsız koltuk: AÇILMAZ, sebebi söylenir (kimliksiz Claude başka kimliğe düşer — ölçülmüş vaka)
#   Sır değeri yok; bu betik kayda YAZMAZ (yazan açıcının kendisi).
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ortak.sh"
TAKILI_SN="${TO_TAKILI_SN:-900}"
EKIP_AC="${TO_EKIP_AC:-$PROJE/scripts/ekip-ac.sh}"
BASLAT="${TO_BASLAT:-$PROJE/scripts/baslat-claude.sh}"
BASLAT_BEKLE="${TO_BASLAT_BEKLE:-3}"   # açılıştan sonra oturumun yaşadığını ölçmeden "açıldı" denmez
# AÇICI ve KAYIT BİRLİKTE seçilir — kayıt, koltuğu FİİLEN açacak betiğin okuduğu dosyadır (tek kaynak, iki kopya yok).
#   🔴 13 Eki 2026 canlı ölçüm (G-BANI-0002/4): 2.4.0 yalnız aile-registry.yaml okuyordu. Merkez dışındaki 12 kutu İSKÂN
#   doğumlu: koltuğu `scripts/baslat-claude.sh <rol>` açar, rolü `iskan-registry.yaml`'dan çözer (ayrılmış oturum kimliği →
#   kendi sohbetine kendiliğinden döner). Oralarda kayıtlı koltuk "kayıtsız" görünüyor, Aç çalışmıyordu (enis ENIS/MURSIT).
#   Aynı adlı `ekip-ac.sh` İSKÂN kutularında BAŞKA bir betiktir: var olan oturumları tek pencerede toplar, oturum DOĞURMAZ
#   ve rol argümanı almaz — açıcı sayılsaydı Aç, Claude'suz oturumu kapatıp geri getirmezdi (koltuk kaybolurdu).
#   Bu yüzden ekip-ac.sh yalnız DOĞURAN sürümse (merkez: --resume-if-known bilir) açıcıdır.
ISKAN="${ISKAN_REGISTRY:-$PROJE/iskan-registry.yaml}"
if [ -f "$BASLAT" ] && [ -f "$ISKAN" ]; then
  ACICI=baslat; KAYIT="$ISKAN"
else
  ACICI=""; KAYIT="${AILE_REGISTRY:-$PROJE/_agents/handoff/aile-registry.yaml}"
  if [ -x "$EKIP_AC" ]; then _ea="$(cat "$EKIP_AC" 2>/dev/null)"; case "$_ea" in *--resume-if-known*) ACICI=ekip-ac ;; esac; fi
fi
# 🔴 Liste betiği BU dosyanın yanındakidir (yedek göz tur 2 canlı bulgusu: BETIK_DIZ ortak kurulu kopyaya çözülüyor, eski
#    koltuk-bagla son=0 basıyordu — iş alanındaki düzeltme hiç çağrılmıyordu). Aynı beceri kopyası, aynı sürüm.
KOLTUK_BETIK="${TO_KOLTUK_BETIK:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/koltuk-bagla.sh}"

json_s() { printf '%s' "$1" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()),end="")'; }
gecerli() { [[ "$1" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; }

# tmux adı → kayıttaki rol (aile-registry: `- id: X` … `tmux: "x:0"`); kayıt yoksa boş
rol_bul() {
  [ -f "$KAYIT" ] || return 0
  python3 - "$KAYIT" "$1" <<'PY'
import re, sys
reg, ad = sys.argv[1], sys.argv[2]
cur=None
for line in open(reg, encoding='utf-8'):
    m = re.match(r'\s*-\s*id:\s*(\S+)', line)
    if m: cur = m.group(1); continue
    m = re.match(r'\s*tmux:\s*["\']?([^"\'#\s]+)', line)
    if m and cur:
        t = m.group(1).split(':')[0]
        if t == ad: print(cur); break
PY
}
# aile kaydında rolün session_id'si dolu ve transcript var mı (eski sohbete dönüş MÜMKÜN mü) — ekip-ac.sh ile aynı ölçüt
resume_var() {
  [ -f "$KAYIT" ] || return 1
  python3 - "$KAYIT" "$1" "${HOME:-/config}/.claude/projects" <<'PY'
import re, sys, os, glob
reg, rol, kok = sys.argv[1], sys.argv[2], sys.argv[3]
cur=None; sid=''
for line in open(reg, encoding='utf-8'):
    m = re.match(r'\s*-\s*id:\s*(\S+)', line)
    if m: cur = m.group(1); continue
    m = re.match(r'\s*session_id:\s*["\']?([0-9a-fA-F-]{36})', line)
    if m and cur == rol: sid = m.group(1); break
ok = bool(sid) and bool(glob.glob(os.path.join(kok, '*', sid + '.jsonl')))
sys.exit(0 if ok else 1)
PY
}
durum_olc() {  # $1 ad → DURUM CLAUDE HAL SON değişkenleri
  DURUM=yok; CLAUDE=0; HAL=""; SON=0; TMUX_VAR=0
  tmux_var "$1" || return 0
  TMUX_VAR=1
  # 🔴 FAIL-CLOSED (yedek göz tur 3): liste ölçümü düşerse (rc≠0 / satır yok) "Claude yok" SANILMAZ — eski hâl kayıtlı bir
  #    koltuğu zorlasız KAPATIRDI. Ölçülemeyen → durum=olculemedi; 'ac' zorlasız dokunmaz.
  local liste satir; liste="$(bash "$KOLTUK_BETIK" --liste 2>/dev/null)" || { DURUM=olculemedi; return 0; }
  satir="$(printf '%s\n' "$liste" | awk -F'\t' -v a="$1" '$1==a')"; [ -n "$satir" ] || { DURUM=olculemedi; return 0; }
  SON="$(printf '%s' "$satir" | cut -f2)"; CLAUDE="$(printf '%s' "$satir" | cut -f3)"; HAL="$(printf '%s' "$satir" | cut -f5)"
  [ "${CLAUDE:-0}" = 1 ] || { DURUM=claude-yok; return 0; }
  local simdi; simdi=$(date +%s)
  if [ "${SON:-0}" -gt 0 ] && [ $((simdi - SON)) -ge "$TAKILI_SN" ] && [ "$HAL" != soru ] && [ "$HAL" != girdi ]; then DURUM=takili; else DURUM=canli; fi
}
# İSKÂN kaydında rolün çalışma dizini (yoksa proje kökü) — baslat-claude.sh orada açılır
cwd_bul() {
  python3 - "$KAYIT" "$1" <<'PY2'
import re, sys
reg, rol = sys.argv[1], sys.argv[2]
cur=None
for line in open(reg, encoding='utf-8'):
    m = re.match(r'\s*-\s*id:\s*(\S+)', line)
    if m: cur = m.group(1); continue
    m = re.match(r'\s*cwd:\s*["\']?([^"\'#\s]+)', line)
    if m and cur == rol: print(m.group(1)); break
PY2
}
yol_bul() {  # $1 ad → YOL ∈ baslat | ekip-ac | onar | yok ; ROL
  ROL="$(rol_bul "$1")"
  if [ -n "$ROL" ] && [ -n "$ACICI" ]; then YOL="$ACICI"
  elif [ "$1" = "$ANA_TMUX" ]; then YOL=onar
  else YOL=yok; fi
}

KOMUT="${1:-}"; AD="${2:-}"; shift $(( $# >= 2 ? 2 : $# ))   # tek argümanda $@ temiz kalır (yedek göz tur 2: "bilinmeyen argüman: durum" basıyordu)
ESKI=0; ZORLA=0; for a in "$@"; do case "$a" in --eski) ESKI=1 ;; --zorla) ZORLA=1 ;; *) echo "bilinmeyen argüman: $a" >&2; exit 2 ;; esac; done
[ -n "$AD" ] && gecerli "$AD" || { echo 'kullanım: koltuk-ac.sh durum|ac <ad> [--eski] [--zorla]' >&2; exit 2; }

case "$KOMUT" in
  durum)
    durum_olc "$AD"; yol_bul "$AD"
    RES=false; { [ "$YOL" = ekip-ac ] || [ "$YOL" = baslat ]; } && resume_var "$ROL" && RES=true
    printf '{"ad":%s,"durum":"%s","tmux":%s,"claude":%s,"hal":%s,"son":%s,"rol":%s,"resume":%s,"yol":"%s","ana":%s}\n' \
      "$(json_s "$AD")" "$DURUM" "$([ $TMUX_VAR = 1 ] && echo true || echo false)" "$([ "${CLAUDE:-0}" = 1 ] && echo true || echo false)" \
      "$(json_s "${HAL:-}")" "${SON:-0}" "$(json_s "${ROL:-}")" "$RES" "$YOL" "$([ "$AD" = "$ANA_TMUX" ] && echo true || echo false)"
    ;;
  ac)
    durum_olc "$AD"; yol_bul "$AD"
    gunluk "koltuk-ac: $AD durum=$DURUM yol=$YOL eski=$ESKI"
    case "$YOL" in yok)
      echo "açılamadı: '$AD' kayıtlı bir koltuk değil (kutunun kaydında rolü yok ya da kutuda koltuk açan betik yok) — kimliksiz Claude açılmaz; önce işe alma (madde 6)" >&2; exit 4 ;;
    esac
    # ORTAK KAPI — ekip-ac yolu ve ana koltuk (onar) yolu AYNI kapıdan geçer (yedek göz tur 4: ana koltukta --zorla hiç okunmuyordu;
    # onar.sh içinde Claude varsa "zaten çalışıyor — yazılmadı" deyip rc 0 dönüyor → telefon "Açıldı" yazıyor, takılı Claude duruyordu).
    # 🔴 TAKILI = görünüş (ekran değişmedi); uzun araç koşan sağlam bir Claude da öyle görünür (canlıda ölçüldü: BÂNİ'nin
    #    kendi koltuğu). Kapatmak işi keser → yalnız açık --zorla ile; telefon penceresi önce sorar.
    if [ "$DURUM" = takili ] && [ $ZORLA = 0 ]; then echo "takılı görünüyor ama çalışıyor olabilir (uzun bir iş): kapatıp yeniden açmak için --zorla (işi keser)"; exit 5; fi
    if [ "$DURUM" = olculemedi ] && [ $ZORLA = 0 ]; then echo "koltuk ÖLÇÜLEMEDİ (liste betiği düştü) — Claude çalışıyor olabilir; dokunmadım. Zorlamak için --zorla"; exit 5; fi
    if [ "$DURUM" = canli ]; then echo "zaten canlı: $AD (ikinci kopya açılmaz)"; exit 0; fi
    # takılı/Claude'suz/ölçülemeyen oturum önce KAPATILIR — ekip-ac.sh ve onar.sh ikisi de "oturum var" görünce Claude'u geri getirmez
    if [ "$DURUM" = claude-yok ] || [ "$DURUM" = takili ] || [ "$DURUM" = olculemedi ]; then tmux kill-session -t "=$AD" 2>/dev/null; gunluk "koltuk-ac: $AD ($DURUM) kapatıldı, yeniden doğacak (zorla=$ZORLA yol=$YOL)"; fi
    case "$YOL" in
      baslat)
        # İSKÂN: ayrılmış kimlikle açılır; konuşma varsa ona döner, yoksa taze başlar (--eski ayrıca bir şey değiştirmez)
        CWD="$(cwd_bul "$ROL")"; [ -d "${CWD:-}" ] || CWD="$PROJE"
        tmux new-session -d -s "$AD" -c "$CWD" "bash $(printf '%q' "$BASLAT") $(printf '%q' "$ROL")" \
          || { echo "açılamadı: tmux oturumu kurulamadı ($AD)" >&2; exit 1; }
        sleep "$BASLAT_BEKLE"
        if tmux_var "$AD"; then echo "açıldı: $AD ← baslat-claude.sh $ROL (kayıtlı sohbetine döner)"; exit 0; fi
        echo "açılamadı: baslat-claude.sh $ROL ${BASLAT_BEKLE} sn içinde düştü (claude yok ya da kayıt eksik olabilir — kutu günlüğüne bak)" >&2; exit 1 ;;
      ekip-ac)
        ARG=(); [ $ESKI = 1 ] && ARG=(--resume-if-known)
        if bash "$EKIP_AC" "$ROL" "${ARG[@]}"; then echo "açıldı: $AD ← ekip-ac.sh $ROL ${ARG[*]:-}"; exit 0
        else echo "açılamadı: ekip-ac.sh $ROL rc=$?" >&2; exit 1; fi ;;
      onar)
        # ana koltuk: onar.sh K0 oturumu yeniden kurar ve kayıtlı ana konuşmaya döner (kapatıldıysa yukarıda kapatıldı)
        if bash "$BETIK_DIZ/onar.sh" >/dev/null 2>&1; then echo "açıldı: $AD (onar.sh K0)"; exit 0; fi
        setsid nohup bash "$BETIK_DIZ/kademe.sh" --kaynak dugme >/dev/null 2>&1 < /dev/null &
        echo "K0 yetmedi; onarım merdiveni başlatıldı (K1→K3)"; exit 3 ;;
    esac ;;
  *) echo 'kullanım: koltuk-ac.sh durum|ac <ad> [--eski] [--zorla]' >&2; exit 2 ;;
esac
