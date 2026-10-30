#!/usr/bin/env bash
# birlestirme-kapisi.sh — fabrika 4. adımın SON kapısı: kanıtsız ya da puansız iş BİRLEŞTİRİLEMEZ.
#
# NİÇİN VAR (Sultan sorusu 23 Eyl 2026: "kullandığından nasıl emin olurum"): fabrikanın adımları
# bugüne dek TALİMATTI — kanıt toplamayan, bağımsız göze göstermeyen bir iş yine de birleşebiliyordu.
# Sistem "kullanmadın" diyemiyor, yalnız "kullandığın görünmüyor" diyebiliyordu. Bu kapı onu kapatır:
# birleştirme anında ÜÇ şey ölçülür ve biri eksikse rc≠0.
#
# ÜÇ ÖLÇÜM
#   1) KART     — işin kartı var mı (0. adım atlanmamış mı)
#   2) KANIT    — `kanit.py dogrula` rc=0: manifest ARAÇ imzalı, dosya sha'ları tutuyor
#   2b) CANLI   — cron/servis/sunucu kartı: yeşil `canli` kaydı (gerçek ateşleme) şart; sarı canlı her kartta engel (17 Eki 2026)
#   3) PUAN     — son DENETIM-<tur>.json: kod_puani=5 VE dogru_sey=E VE denetçi ≠ yazan
#
# 🔴 NE ÖLÇMEZ (dürüstlük): kanıtın DOĞRU şeyi ölçtüğünü ölçmez — onu bağımsız göz yapar.
#    Sınıf işinde Sultan onayını da ölçmez (A06: onay üretilemez, yalnız insan verir) — yalnız
#    kartın sınıf taşıdığını SÖYLER, kararı insana bırakır.
#
# Kullanım:
#   birlestirme-kapisi.sh <iş> [--depo KÖK] [--sessiz]
#   birlestirme-kapisi.sh --pr <N> [--depo KÖK]     (iş adını PR'IN KENDİSİNDEN çözer — sıra: gövdedeki 'kart: <ad>' satırı · kanıt kaydında
#                                                    pr=N olan dizin · PR'ın tek kanıt dizini · dal adı; aday birden çoksa rc 2 "hangi kart?")
# rc: 0 GEÇTİ · 1 eksik (kanıt yok/puan yetersiz/kart yok) · 2 kullanım / hangi kart? · 3 ÖLÇÜLEMEDİ (yeşil değil)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS=""; PR=""; DEPO="${KANIT_DEPO:-}"; SESSIZ=0
while [ $# -gt 0 ]; do case "$1" in
  --pr) PR="$2"; shift 2 ;; --depo) DEPO="$2"; shift 2 ;; --sessiz) SESSIZ=1; shift ;;
  -h|--help) sed -n '1,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  *) [ -z "$IS" ] && IS="$1" || { echo "✗ tanınmayan argüman: $1" >&2; exit 2; }; shift ;;
esac; done

_y() { [ "$SESSIZ" -eq 1 ] || printf '%s\n' "$*"; }
_h() { printf '✗ %s\n' "$*" >&2; }

# Depo kökü: BİRİNCİL ağaç (worktree'den çağrılsa da kart oradadır); kanıt ise ÇALIŞILAN ağaçta.
if [ -z "$DEPO" ]; then
  c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && DEPO="$(dirname "$c")"
fi
[ -n "$DEPO" ] || { _h "depo kökü bulunamadı — ÖLÇÜLEMEDİ"; exit 3; }
WT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEPO")"

# --pr verilmişse iş adını PR'ın dalından çöz (is-alani dalı iş adıyla açar)
if [ -z "$IS" ] && [ -n "$PR" ]; then
  command -v gh >/dev/null 2>&1 || { _h "gh yok, PR'dan iş adı çözülemedi — ÖLÇÜLEMEDİ"; exit 3; }
  IS="$(cd "$DEPO" && gh pr view "$PR" --json headRefName --jq .headRefName 2>/dev/null)"
  [ -n "$IS" ] || { _h "PR #$PR dalı okunamadı — ÖLÇÜLEMEDİ"; exit 3; }
  IS="${IS##*/}"   # muavin/<iş> gibi önekleri at
  # 🔴 İŞ ADI DAL ADINDAN DEĞİL, PR'IN DEĞİŞTİRDİĞİ KANIT DİZİNİNDEN gelir (gorev …THYFXG0): kanıt PR'ı ayrı dalla açılınca
  #    (dal 'merkez-dogrulat-kanit' ≠ iş 'merkez-dogrulat-kendiliginden') dal adı yanlış işi gösterir, kapı "kart/kanıt/denetim YOK" der ve
  #    birleştirme kancası kapı iş adıyla GEÇMİŞ PR'ı keserdi (#884, #817, #960).
  # 🔴 KART KİMLİĞİ PR'IN KENDİSİNDEN (30 Eki 2026 · görev …CE1RT · kart fabrika-kapi-kart-kimligi-prden · BENNÂ): cloudtop #1185'te PR tabanı
  #    bayattı, GitHub dosya listesi main'den gelen 4 YABANCI kanıt dizinini saydı; kapı dal adıyla eşleşeni seçip ESKİ kartı (2/H) okudu, doğru
  #    kartı (5/E) görmedi, 2× engelledi. Şimdi aday listesi merge-base farkıyla süzülür (origin/main...PR başı — yabancı dizin düşer; taban
  #    gerideyse söylenir) ve kart kimliği PR'ın kendisinden alınır, öncelik sırası:
  #      1) PR gövdesinde 'kart: <ad>' satırı (PR kendini ilan eder; kanıt kaydı başka karta bağlıysa ÇELİŞKİ → rc 2)
  #      2) PR'ın dokunduğu kanıt dizinlerinden, PR başındaki DENETIM-*.json / KART.json kaydında pr=N olan (tek → o; birden çok → rc 2)
  #      3) tek kanıt dizini → o (dal adı ayrışıyorsa söylenir)
  #      4) birden çok dizin → dal adıyla eşleşen; yoksa DUR rc 2 "hangi kart?" (adaylar basılır; eskiden rc 3)
  #      5) sıfır dizin ya da liste okunamadı → dal adı (kapı yine de kanıt yoksa kapalı kalır).
  DAL_ADI="$IS"; IS_NOT=""; PR_UYARI=""; ANA_DAL="${KANIT_ANA:-main}"
  GOVDE_KART="$(cd "$DEPO" && gh pr view "$PR" --json body --jq .body 2>/dev/null | sed -n 's/^[[:space:]]*kart:[[:space:]]*\([^[:space:]]\{1,\}\).*/\1/p' | head -1)"
  PRBAS_C=""; GERCEK=""
  if git -C "$DEPO" fetch -q origin "pull/$PR/head" 2>/dev/null; then
    PRBAS_C="$(git -C "$DEPO" rev-parse FETCH_HEAD 2>/dev/null)"
    if [ -n "$PRBAS_C" ] && git -C "$DEPO" fetch -q origin "$ANA_DAL" 2>/dev/null; then
      GERCEK="$(git -C "$DEPO" diff --name-only "origin/$ANA_DAL...$PRBAS_C" 2>/dev/null)" || GERCEK=""
      geri="$(git -C "$DEPO" rev-list --count "$PRBAS_C..origin/$ANA_DAL" 2>/dev/null || echo "")"
      [ -n "$geri" ] && [ "$geri" -gt 0 ] && PR_UYARI="PR #$PR tabanı origin/$ANA_DAL'in $geri commit gerisinde — GitHub dosya listesi main'den gelen (yabancı) kanıt dizinlerini sayabilir; adaylar merge-base farkıyla süzüldü"
    fi
  fi
  PRDOSYA=""
  if PRDOSYA="$(cd "$DEPO" && gh pr diff "$PR" --name-only 2>/dev/null)" && [ -n "$PRDOSYA" ]; then
    [ -z "$GERCEK" ] || PRDOSYA="$(printf '%s\n' "$PRDOSYA" | grep -Fx -f <(printf '%s\n' "$GERCEK") || true)"
  else
    PRDOSYA="$GERCEK"   # GitHub listesi okunamadı → merge-base farkı (ikinci yüzey); o da yoksa dal adı
  fi
  ADAY=""; NADAY=0; ESLESEN=""
  if [ -n "$PRDOSYA" ]; then
    ADAY="$(printf '%s\n' "$PRDOSYA" | awk -F/ '$1=="_agents" && $2=="fabrika" && $3=="kanit" && NF>=5 {print $4}' | sort -u)"
    NADAY="$(printf '%s' "$ADAY" | grep -c . || true)"
    if [ -n "$PRBAS_C" ] && [ "$NADAY" -gt 0 ]; then
      ESLESEN="$(for x in $ADAY; do
        for f in $(git -C "$DEPO" ls-tree --name-only "$PRBAS_C" "_agents/fabrika/kanit/$x/" 2>/dev/null | grep -E '/(DENETIM-[0-9]+|KART)\.json$'); do
          git -C "$DEPO" show "$PRBAS_C:$f" 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin);print(str(d.get("pr","")).lstrip("#"))' 2>/dev/null | grep -qx -- "$PR" && { echo "$x"; break; }
        done
      done | sort -u)"
    fi
  fi
  NESLESEN="$(printf '%s' "$ESLESEN" | grep -c . || true)"
  if [ -n "$GOVDE_KART" ]; then
    if [ "$NESLESEN" -gt 0 ] && ! printf '%s\n' "$ESLESEN" | grep -qxF -- "$GOVDE_KART"; then
      _h "PR #$PR hangi kart? gövde 'kart: $GOVDE_KART' diyor, kanıt kaydı pr=$PR ile başka karta bağlı: $(printf '%s' "$ESLESEN" | tr '\n' ' ')— çelişki; iş adını elle ver"; exit 2
    fi
    IS="$GOVDE_KART"; IS_NOT="iş adı PR gövdesinden: 'kart: $IS'$( [ "$IS" = "$DAL_ADI" ] || printf " (PR dalı '%s')" "$DAL_ADI")"
  elif [ "$NESLESEN" -eq 1 ]; then
    IS="$ESLESEN"; IS_NOT="iş adı PR numarası eşleşmesinden: '$IS' (kanıt kaydında pr=$PR$( [ "$IS" = "$DAL_ADI" ] || printf "; PR dalı '%s'" "$DAL_ADI"))"
  elif [ "$NESLESEN" -gt 1 ]; then
    _h "PR #$PR hangi kart? birden çok kanıt dizininin kaydı pr=$PR diyor: $(printf '%s' "$ESLESEN" | tr '\n' ' ')— iş adını elle ver"; exit 2
  elif [ "$NADAY" -eq 1 ]; then
    IS="$ADAY"
    [ "$IS" = "$DAL_ADI" ] || IS_NOT="iş adı PR'ın tek kanıt dizininden türetildi: '$IS' (PR dalı '$DAL_ADI' ayrışıyor)"
  elif [ "$NADAY" -gt 1 ]; then
    if printf '%s\n' "$ADAY" | grep -qxF -- "$DAL_ADI"; then IS="$DAL_ADI"; IS_NOT="PR birden çok kanıt dizinine dokunuyor; dal adıyla eşleşen seçildi: '$IS'"
    else _h "PR #$PR hangi kart? $NADAY kanıt dizinine dokunuyor, hiçbiri dal adı ('$DAL_ADI') değil, hiçbirinin kaydı pr=$PR demiyor, gövdede 'kart: <ad>' yok: $(printf '%s' "$ADAY" | tr '\n' ' ')— PR gövdesine 'kart: <ad>' yaz ya da iş adını elle ver"; exit 2
    fi
  fi
fi
[ -n "$IS" ] || { _h "iş adı gerekiyor (ya da --pr N)"; exit 2; }

KART="$DEPO/_agents/fabrika/kartlar/$IS.json"
# 🔴 KANIT TEK KURALLA ARANIR (retro W42 ders M3 · gorev_01M57ZWR5MAMW513WYBX5MB3J8): kapı eskiden kanıtı "çağrıldığı ağaç,
#    yoksa birincil" diye arıyordu. Birleştirme çoğu zaman BİRİNCİL checkout'tan `--pr` ile yapılır; kanıt ise iş alanında ya da
#    PR'ın dalında durur → kapı "kanıt YOK" dedi ve iş kaçışla (FABRIKA_KAPISIZ) birleşti (kaçış defteri: 15 Eki compact-kurali).
#    Artık her çağrı AYNI sırayla bakar, hangisini kullandığını söyler:
#      1) dalı iş adıyla aynı olan ağaç — önce çağrılan ağaç, sonra birincilin iş alanları (dal adı = kart adı; önek atılır)
#      2) --pr verildiyse PR'ın BAŞI (origin pull/<N>/head; yalnız kanıt dizini geçici yere çıkarılır, ağaca dokunulmaz)
#      3) birincil depo (birleşmiş iş, ya da tek ağaç kurulum)
#    Dalı iş adıyla tutmayan bir ağaçtaki kopya ARANMAZ: bayat kopyadır, o işin kanıtı değil.
KANIT_GECICI=""; trap '[ -n "$KANIT_GECICI" ] && rm -r -f "$KANIT_GECICI"' EXIT
dal_tutar() { local b; b="$(git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null)" || return 1; [ "${b##*/}" = "$IS" ]; }
kanit_bul() {
  local t yol agaclar=()
  mapfile -t agaclar < <(printf '%s\n' "$WT"; git -C "$DEPO" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')   # boşluklu yol bölünmez
  for t in "${agaclar[@]}"; do
    yol="$t/_agents/fabrika/kanit/$IS"
    if [ -f "$yol/KANIT.json" ] && dal_tutar "$t"; then
      DZ="$yol"; DZ_AGAC="$t"; [ "$t" = "$WT" ] && DZ_YER="çağrılan ağaç ($t, dal iş adıyla aynı)" || DZ_YER="iş alanı ($t, dal iş adıyla aynı)"; return 0
    fi
  done
  if [ -n "$PR" ] && git -C "$DEPO" remote get-url origin >/dev/null 2>&1 && git -C "$DEPO" fetch -q origin "pull/$PR/head" 2>/dev/null; then
    KANIT_GECICI="$(mktemp -d)"
    if git -C "$DEPO" archive FETCH_HEAD "_agents/fabrika/kanit/$IS" 2>/dev/null | tar -x -C "$KANIT_GECICI" 2>/dev/null && [ -f "$KANIT_GECICI/_agents/fabrika/kanit/$IS/KANIT.json" ]; then
      DZ="$KANIT_GECICI/_agents/fabrika/kanit/$IS"; DZ_YER="PR #$PR başı ($(git -C "$DEPO" rev-parse --short FETCH_HEAD 2>/dev/null))"; return 0
    fi
  fi
  if [ -f "$DEPO/_agents/fabrika/kanit/$IS/KANIT.json" ]; then DZ="$DEPO/_agents/fabrika/kanit/$IS"; DZ_AGAC="$DEPO"; DZ_YER="birincil depo ($DEPO)"; return 0; fi
  DZ="/kanit-bulunamadi/_agents/fabrika/kanit/$IS"   # bulunamadı: hiçbir yeri GÖSTERMEZ (aşağıdaki her okuma "yok" görür; mutant birincil-aranmaz)
  DZ_YER="hiçbir yerde (arandı: dalı '$IS' olan ağaçlar${PR:+ · PR #$PR başı} · birincil depo)"; return 1
}
DZ=""; DZ_YER=""; DZ_AGAC=""; kanit_bul || true

eksik=0; olcemedi=0
_y "── BİRLEŞTİRME KAPISI · iş: $IS"
[ -n "${IS_NOT:-}" ] && _y "  · $IS_NOT"
[ -n "${PR_UYARI:-}" ] && _y "  ⚠ $PR_UYARI"
_y "  · kanıt yeri: $DZ_YER"

# 🔴 PR BAŞI DOĞRULAMASI (…898AX · SERDAR 26 Eki 2026): kanıt YEREL ağaçtan okunduysa kapı, orada duran ama PR'a İTİLMEMİŞ bir denetim
#    kaydını da "var" sayıyordu → #907 ve #908 iki kez DENETIM-1.json'suz birleşti (PR başı 80987568, yerel 77e7bf21, kapı rc0).
#    Kapı artık --pr verilmişse okuduğu kanıt dizinini PR'ın BAŞIYLA bayt bayt karşılaştırır: (a) yerel baş ≠ PR başı → "itilmemiş commit var",
#    (b) kanıt dizinindeki her dosyanın PR başındaki karşılığı yoksa ya da farklıysa ad ad söylenir (commit'lenmemiş dosya da burada yakalanır).
#    PR başı çekilemezse ÖLÇÜLEMEDİ (rc=3): "ölçemedim"i "temiz" saymak bu açığın kendisiydi. Kanıt zaten PR başından okunduysa (DZ_AGAC boş) bakılacak şey yok.
if [ -n "$PR" ] && [ -n "$DZ_AGAC" ]; then
  if git -C "$DEPO" fetch -q origin "pull/$PR/head" 2>/dev/null; then
    prbas="$(git -C "$DEPO" rev-parse FETCH_HEAD 2>/dev/null)"
    if [ -z "$prbas" ]; then
      _h "PR #$PR başı çözülemedi — itilmemiş kayıt ÖLÇÜLEMEDİ"; olcemedi=$((olcemedi+1))
    else
      yerel_bas="$(git -C "$DZ_AGAC" rev-parse HEAD 2>/dev/null)"; farklar=""
      for f in "$DZ"/*; do
        [ -f "$f" ] || continue
        yb="$(git -C "$DZ_AGAC" hash-object -- "$f" 2>/dev/null)"
        ub="$(git -C "$DEPO" rev-parse -q --verify "$prbas:_agents/fabrika/kanit/$IS/$(basename "$f")" 2>/dev/null)" || ub=""
        [ -n "$yb" ] && [ "$yb" = "$ub" ] || farklar="$farklar $(basename "$f")"
      done
      if [ "$DZ_AGAC" != "$DEPO" ] && [ -n "$yerel_bas" ] && [ "$yerel_bas" != "$prbas" ]; then
        _h "itilmemiş commit var — PR #$PR başı ${prbas:0:8} ≠ yerel baş ${yerel_bas:0:8} (önce push; PR başı GitHub'da birkaç dakika geç güncellenebilir)"; eksik=$((eksik+1))
      fi
      if [ -n "$farklar" ]; then
        _h "kanıt dizini PR #$PR başıyla AYNI değil (PR'da yok ya da farklı:$farklar) — itilmemiş ya da commit'lenmemiş kayıt kapıyı geçirmez"; eksik=$((eksik+1))
      fi
      [ -z "$farklar" ] && { [ "$DZ_AGAC" = "$DEPO" ] || [ "$yerel_bas" = "$prbas" ]; } && _y "  ✓ PR başı: kanıt dizini PR #$PR başıyla aynı (${prbas:0:8})"
    fi
  else
    _h "PR #$PR başı çekilemedi (origin pull/$PR/head) — kanıt dizininin PR'a itilip itilmediği ÖLÇÜLEMEDİ"; olcemedi=$((olcemedi+1))
  fi
fi

# 1 · KART
if [ -f "$KART" ]; then
  sinif="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(','.join(d.get('siniflar') or []) or 'yok')" "$KART" 2>/dev/null)"
  sultan="$(python3 -c "import json,sys;print('E' if json.load(open(sys.argv[1])).get('sultan') else 'H')" "$KART" 2>/dev/null)"
  _y "  ✓ kart var · sınıf: $sinif"
  [ "$sultan" = "E" ] && _y "  ⚠ SINIF İŞİ — birleştirme kararı SULTAN'ın; bu kapı onay ÜRETMEZ (A06)"
else
  _h "kart YOK: $KART — 0. adım atlanmış"; eksik=$((eksik+1))
fi

# 2 · KANIT
if [ -f "$HERE/kanit.py" ]; then
  KANIT_KOK="${DZ%/_agents/fabrika/kanit/$IS}"     # kanıt dizininden deponun kökünü türet
  cik="$(python3 "$HERE/kanit.py" --depo "$KANIT_KOK" dogrula "$IS" 2>&1)"; krc=$?
  case "$krc" in
    0) _y "  ✓ kanıt: $(printf '%s\n' "$cik" | grep '^✓ manifest' | sed 's/^✓ //')"
       # 4K938: geçersiz ilan edilen kayıt sessiz kalmaz — kapı satırında görünür (olcum renkleri kapının hükmü değil, gözün)
       printf '%s\n' "$cik" | grep '^⛔ GEÇERSİZ' | while IFS= read -r l; do _y "  $l"; done ;;
    1) _h "kanıt manifesti BOZUK (elle yazılmış ya da dosya değişmiş)"; eksik=$((eksik+1)) ;;
    *) _h "kanıt YOK — 'kanıtsız iş gönderilemez'"; eksik=$((eksik+1)) ;;
  esac
else
  _h "kanit.py bulunamadı — ÖLÇÜLEMEDİ"; olcemedi=$((olcemedi+1))
fi

# 2b · CANLI — "git'te düzeltildi ≠ canlıda çalışıyor" (retro 17 Eki 2026 · ders 1): cron/servis/sunucu kartı yeşil ölçüm
#    + 5/E ile GEÇMEZ; gerçek ateşleme kaydı (kanit.sh canli, yeşil) ister. Sarı canlı = ölçülmüş ama ateşleme yok → kart ne
#    derse desin geçmez (sarı yeşil değildir). Kartın canlı şartını kart.sh söyler (eski kartta cümleden türetir).
# 🔴 GÖZ (daraltılmış tur): kart.sh canli-gerekir düşünce cg boş kalıyor ve H varsayılıyordu → canlı şartı FAIL-OPEN atlanıyordu.
#    Kapı ölçemediğini yeşil saymaz: yardımcı rc≠0 ya da cevap E/H değilse ÖLÇÜLEMEDİ (rc=3).
cg="H"; csebep=""
if [ -f "$KART" ]; then
  if [ -f "$HERE/kart.sh" ]; then
    cg_cikti="$(KANIT_DEPO="$DEPO" bash "$HERE/kart.sh" canli-gerekir "$IS" 2>&1)"; cg_rc=$?
    IFS=$'\t' read -r cg csebep <<<"$cg_cikti"; csebep="${csebep:-}"
    if [ "$cg_rc" -ne 0 ] || { [ "$cg" != "E" ] && [ "$cg" != "H" ]; }; then
      _h "kartın canlı şartı OKUNAMADI (kart.sh canli-gerekir rc=$cg_rc: ${cg_cikti:-boş}) — ÖLÇÜLEMEDİ, canlı kontrolü atlanmaz"; olcemedi=$((olcemedi+1)); cg="?"
    fi
  else
    _h "kart.sh bulunamadı — kartın canlı şartı ÖLÇÜLEMEDİ"; olcemedi=$((olcemedi+1)); cg="?"
  fi
fi
# 🔴 GÖZ TUR 1 (PR #352): "herhangi bir yeşil canlı kaydı yetiyor; eski ya da ilgisiz kayıt yeni cron değişikliğini geçirir" — doğru.
#    Kayıt bu İŞE BAĞLANIR: ölçüm zamanı DA son ateşleme saati DE kartın açılış zamanından SONRA olmalı. Bağlanamayan yeşil kayıt
#    sayılmaz, sebebi basılır. Kapı sayılan kaydın komutunu ve kaynağını da basar — göz "neyi okudu" diye bakabilsin.
cy=0; cs=0; cilk=""; ckopuk=""; ckz=1; cpy_rc=0
if [ -f "$DZ/KANIT.json" ]; then
  # 🔴 GÖZ #353 tur 2: python bloğu düşerse eval boş kalıyor ve kapı "canlı yok" (rc=1) diyordu → alt sürecin rc'si ölçülür, düşerse ÖLÇÜLEMEDİ
  cpy_out="$(python3 - "$DZ/KANIT.json" "$KART" "$HERE" <<'PY'
import json,sys,shlex,datetime
# 4K938: etkin renk kanit.py'den okunur (kopya yok); içe aktarım düşerse alt süreç rc≠0 → ÖLÇÜLEMEDİ (fail-closed)
sys.path.insert(0,sys.argv[3]); from kanit import etkin_kayitlar
def P(s):
    # 🔴 GÖZ #353 tur 2: dilimsiz (naive) ISO ile dilimli karşılaştırma TypeError veriyordu → dilimsiz değer kutunun yerel dilimine alınır
    try:
        d=datetime.datetime.fromisoformat(s)
        return d.astimezone() if d.tzinfo is None else d
    except Exception: return None
try: m=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: m={}
kz=None
try: kz=P(json.load(open(sys.argv[2],encoding="utf-8")).get("zaman",""))
except Exception: pass
c=[k for k in etkin_kayitlar(m) if k.get("tur")=="canli"]
# geçersiz ilan edilen canlı kayıt yeşil SAYILMAZ, sarı gibi ENGELDİR — ilan kapıyı hiçbir zaman gevşetmez
y=[k for k in c if k["etkin_renk"]=="yesil"]; s=[k for k in c if k["etkin_renk"] in ("sari","gecersiz")]
# 🔴 #817 (RH8A3): bayat SARI sonraki YEŞİL kayıtla yerine geçtiyse ya da SARI iken geçersiz ilan edildiyse (ilan yeşili aklamaz, sarıyı emekli eder)
#    sayımdan düşer. Yeşili geçersiz ilan edilmiş kayıt ENGEL kalır; aynı etiketin SONRAKİ yeşili yalnız işe bağlıysa (aşağıda) sarıyı yerine geçirir.
s=[k for k in s if not (k["etkin_renk"]=="gecersiz" and k.get("renk")!="yesil")]
bagli_l=[]; kopuk=[]
for k in y:
    oz=P(k.get("zaman") or ""); son=P(((k.get("son_atesleme") or k.get("ilk_atesleme") or {}).get("saat_iso")) or "")
    kzs=kz.isoformat(timespec="seconds") if kz else "?"
    if kz is None: neden="kart açılışı zamanı okunamadı"
    elif oz is None or oz<kz: neden=f"ölçüm kart açılışı ({kzs}) ÖNCESİNDE"
    elif son is None: neden="ateşleme saati çözülemedi (saat_iso yok; eski araçla alınmış olabilir)"
    elif son<kz: neden=f"son ateşleme {son.isoformat(timespec='seconds')} kart açılışı {kzs} ÖNCESİNDE — bu işin ateşlemesi değil"
    elif son>oz+datetime.timedelta(minutes=5): neden=f"son ateşleme {son.isoformat(timespec='seconds')} ÖLÇÜMDEN SONRA ({oz.isoformat(timespec='seconds')}) — geleceğe tarihli, şüpheli"
    else: neden=None
    (bagli_l if neden is None else kopuk).append((k,neden))
# yerine geçme: kendinden SONRA ölçülmüş, işe BAĞLI bir yeşil kayıt varsa bayat sarı sayılmaz (etiketi farklı olsa da: kapı "bağlı yeşil ateşleme var mı"yı sorar;
#   geçersiz ilanlı yeşil bağlı yeşil olamaz → bagli_l'de yok). Sarıdan ÖNCE alınmış yeşil sarıyı düşürmez.
def _z(k): return P(k.get("zaman") or "")
yerine=[x for x in s if x["etkin_renk"]=="sari" and any(_z(kk) and _z(x) and _z(kk)>_z(x) for kk,_ in bagli_l)]
s=[x for x in s if x not in yerine]
print("cy="+str(len(bagli_l))); print("cs="+str(len(s))); print("ckz="+("1" if kz else "0"))
if bagli_l:
    k=bagli_l[0][0]; ilk=k.get("ilk_atesleme") or {}
    print("cilk="+shlex.quote(f"{ilk.get('saat','')} · {str(ilk.get('satir',''))[:120]} · kaynak: {k.get('kaynak','')} · komut: {' '.join(k.get('komut') or [])[:160]}"))
else: print("cilk=''")
print("ckopuk="+shlex.quote("; ".join(f"{k.get('etiket')}: {n}" for k,n in kopuk)))
PY
)"; cpy_rc=$?
  [ "$cpy_rc" -eq 0 ] && eval "$cpy_out"
fi
cs_engel=0
# 🧾 CANLI BORÇ (5WYQMW · SERDAR 22 Eki 00:43): canlı kayıt henüz ÜRETİLEMİYORSA (dağıtım birleşmeden sonra/başkasında) kapı, kartta KAYITLI ve GEÇERLİ
#    bir borçla geçer — borç kapıyı gevşetmez, görünür kılar: kart 'bitti' olmaz (canli-borclu), 24 saatte kırmızı olur. Koşullar canli_borc.py'de
#    (sınıflı kartta Sultan kararı şart). Borç yalnız bağlı yeşil kayıt YOKKEN anlamlıdır; geçersiz ilan edilmiş kaydı AKLAMAZ.
bd=""; bac=""; borc_gecer=0
if [ "$cg" = "E" ] && [ "$cy" -eq 0 ] && [ -f "$HERE/kart.sh" ]; then
  IFS=$'\t' read -r bd bac <<<"$(KANIT_DEPO="$DEPO" bash "$HERE/kart.sh" canli-borc-durum "$IS" 2>&1)"; bac="${bac:-}"
  case "$bd" in
    gecerli) borc_gecer=1 ;;
    gecersiz) _h "canlı borç GEÇERSİZ: $bac"; eksik=$((eksik+1)) ;;
    yok|odendi) ;;
    *) _h "canlı borç durumu OKUNAMADI (kart.sh canli-borc-durum: ${bd:-boş} ${bac}) — ÖLÇÜLEMEDİ, borç sayılmaz"; olcemedi=$((olcemedi+1)) ;;
  esac
fi
[ "$cpy_rc" -eq 0 ] || { _h "canlı kayıt değerlendirmesi DÜŞTÜ (python rc=$cpy_rc) — ÖLÇÜLEMEDİ, 'canlı yok' sayılmaz"; olcemedi=$((olcemedi+1)); }
# 🔴 GÖZ #353 tur 1: kartın açılış zamanı okunamazsa işe bağlama ÖLÇÜLEMEZ — bu "bağlı kayıt yok" (rc=1) değil, ÖLÇÜLEMEDİ (rc=3).
[ ! -f "$KART" ] || [ "$ckz" = "1" ] || { _h "kartın açılış zamanı ('zaman') okunamadı — canlı kaydın işe bağlanması ÖLÇÜLEMEDİ"; olcemedi=$((olcemedi+1)); }
[ -n "$ckopuk" ] && _y "  ⚠ canlı kaydı işe bağlanamadı (sayılmaz): $ckopuk"
[ "$cs" -gt 0 ] && [ "$borc_gecer" -eq 0 ] && { _h "canlı kanıt SARI ya da GEÇERSİZ ($cs kayıt) — ateşleme kaydı yok ya da kayıt geçersiz ilan edilmiş; yeniden ölç (kanit.sh canli)"; eksik=$((eksik+1)); cs_engel=1; }
[ "$cg" = "E" ] && [ "$cy" -eq 0 ] && [ "$cs_engel" -eq 0 ] && [ "$borc_gecer" -eq 0 ] && [ "$bd" != "gecersiz" ] && { _h "canlı kanıt YOK ya da bu işe bağlı değil — cron/servis/sunucu işi ($csebep) kart açılışından SONRAKİ gerçek ateşleme kaydını ister: kanit.sh canli <iş> <etiket> --kaynak … -- <log okuyan komut>"; eksik=$((eksik+1)); }
[ "$cy" -gt 0 ] && _y "  ✓ canlı: $cy ateşleme kaydı (işe bağlı) · ilk: $cilk"
[ "$borc_gecer" -eq 1 ] && _y "  🧾 CANLI BORÇ (kapı geçer, kart BİTMEZ): $bac
     → birleştir → kur → kanit.sh canli $IS <etiket> --kaynak … --desen … → kart.sh bitti $IS. 24 sa ödenmezse kart.sh borclar kırmızı."
[ "$cg" = "H" ] && [ -n "$csebep" ] && _y "  · canlı kanıt istenmedi — $csebep"

# 3 · PUAN
SON="$(ls "$DZ"/DENETIM-[0-9]*.json 2>/dev/null | sort -V | tail -1)"
if [ -n "$SON" ]; then
  # 🔴 SATIR-TEMELLİ AKTARIM DA KIRILGANDI (bağımsız göz #339 tur 1 pipe'ı çözdü, tur 2 yeni
  #    satırı buldu): serbest-metin `yedek` alanı "\n" içerirse sabit satır-numarasıyla okuma
  #    (sed -n Np) da kayar. Çözüm metinsel ayraç DEĞİL: python her değeri shlex.quote ile
  #    KABUĞA GÜVENLİ tek-tırnaklı bir ifadeye çevirir, kabuk onu `eval` ile DEĞİŞKENE atar —
  #    içinde "|" ya da "\n" olsa da shlex.quote kapatıp-yeniden-açarak kaçışlar, hiçbir
  #    ayraç/satır-sayısı varsayımına dayanmaz.
  okuma="$(python3 - "$SON" <<'PY'
import json,sys,shlex
d=json.load(open(sys.argv[1],encoding="utf-8")); s=d["sonuc"]
vals={"puan":s["kod_puani"],"dogru":s["dogru_sey"],"yazan":d.get("yazan","?"),"denetci":d.get("denetci","?"),
      "tur":d.get("tur","?"),"nb":len(s["bulgular"]),"yedek":d.get("yedek") or "",
      "yazan_model":d.get("yazan_model") or "","yedek_model":d.get("yedek_model") or ""}
for k,v in vals.items():
    print(f"{k}={shlex.quote(str(v))}")
PY
)"
  eval "$okuma"
  _y "  · denetim tur $tur · $puan/5 · doğru şey: $dogru · bulgu: $nb · yazan: $yazan → denetçi: $denetci"
  # ── DARALTMA KAYDI (PCP7J, 18 Eki 2026): kapı eskiden kartın reis/Sultan kararlarını hiç okumuyor, koşulsuz son
  #    DENETIM 5/E istiyordu. Kart daraltıldıysa (kart.sh daralt → daraltmalar[-1].tur_sifir) son denetim daraltmadan
  #    SONRA koşmuş olmalı: eski cümleye verilmiş 5/E yeni cümleyi doğrulamaz. Kart okunamazsa ÖLÇÜLEMEDİ (rc=3), geçti değil.
  if [ -n "${KART:-}" ] && [ -r "$KART" ]; then
    dar="$(python3 - "$KART" "$tur" <<'PYD'
import json,sys
try:
    try: k=json.load(open(sys.argv[1],encoding="utf-8"))
    except Exception: print("yok"); raise SystemExit   # kart okunamıyorsa onu canli-gerekir kapısı zaten ÖLÇÜLEMEDİ sayar (çift sayım yok)
    d=k.get("daraltmalar") or []
    rk=[x for x in (k.get("reis_kararlari") or []) if x.get("karar")=="daralt"]; sk=[x for x in (k.get("sultan_kararlari") or []) if x.get("karar")=="daralt"]
    if not d: print("yok"); raise SystemExit
    ts=int(d[-1].get("tur_sifir",0)); tur=int(sys.argv[2]) if str(sys.argv[2]).isdigit() else -1
    kim="Sultan" if sk else ("reis" if rk else "kayitsiz")
    print(f"{'tamam' if tur>ts else 'eski'} {ts} {d[-1].get('kalan_kart','?')} {kim}")
except SystemExit: pass
except Exception as e: print("hata")
PYD
)"
    # ── SULTAN TURU (kart.sh sultan-turu · beğeni döngüsü): son kayıtlı Sultan turundan sonra en az bir göz turu koşmuş olmalı — Sultan
    #    "değiştir" dedikten sonra yapılan iş yeniden denetlenmeden birleşmez (tavan esnetilir, denetim esnetilmez).
    st="$(python3 - "$KART" "$tur" <<'PYS'
import json,sys
try:
    try: k=json.load(open(sys.argv[1],encoding="utf-8"))
    except Exception: print("yok"); raise SystemExit   # kart okunamıyorsa onu canli-gerekir kapısı zaten ÖLÇÜLEMEDİ sayar (çift sayım yok)
    st=k.get("sultan_turlari") or []
    if not st: print("yok"); raise SystemExit
    ts=int(st[-1].get("tur_sifir",0)); tur=int(sys.argv[2]) if str(sys.argv[2]).isdigit() else -1
    print(f"{'tamam' if tur>ts else 'eski'} {ts} {st[-1].get('tur','?')}")
except SystemExit: pass
except Exception: print("hata")
PYS
)"
    case "$st" in
      yok) ;;
      hata) _h "kartın Sultan turu kaydı OKUNAMADI — kapı ölçemedi"; olcemedi=$((olcemedi+1)) ;;
      tamam\ *) set -- $st; _y "  · Sultan turu $3 kayıtlı (tur sıfırı $2) · son denetim bu turdan SONRA ✓" ;;
      eski\ *) set -- $st; _h "Sultan turu $3 kayıtlı (tur sıfırı $2) ama son denetim (tur $tur) ondan ÖNCE — Sultan'ın istediği değişiklik denetlenmedi, birleştirme YOK"; eksik=$((eksik+1)) ;;
    esac
    case "$dar" in
      yok) ;;
      hata) _h "kartın daraltma kaydı OKUNAMADI — kapı ölçemedi"; olcemedi=$((olcemedi+1)) ;;
      tamam\ *) set -- $dar; _y "  · kart daraltılmış (tur sıfırı $2, kalan → $3, karar: $4) · son denetim daraltma SONRASI ✓" ;;
      eski\ *) set -- $dar; _h "kart daraltılmış (tur sıfırı $2, kalan → $3) ama son denetim (tur $tur) daraltmadan ÖNCE — yeni cümle denetlenmedi, birleştirme YOK"; eksik=$((eksik+1)) ;;
    esac
  fi
  [ "$puan" = "5" ] || { _h "kod puanı 5 DEĞİL ($puan) — adım 2'ye dönülmeliydi"; eksik=$((eksik+1)); }
  [ "$dogru" = "E" ] || { _h "'doğru şey mi' EVET değil ($dogru) — kod doğru olsa da yanlış iş olabilir"; eksik=$((eksik+1)); }
  # Sultan Y0006: yedek göz (yazandan farklı YENİ oturum) de bağımsız sayılır — ama ancak
  # yedek_model VE yazan_model İKİSİ DE ölçülmüş VE birbirinden FARKLIYSA (fail-closed: alan
  # boşsa ya da modeller aynıysa eski string-match reddi geçerliliğini sürdürür). "$denetci"
  # alanı yedek kipinde "claude (…) (YEDEK GÖZ: …)" olduğundan $yazan ("claude") onun İÇİNDE
  # geçer — bu artık K1 ihlali DEĞİL, çünkü farklı model + farklı oturum ölçülmüştür.
  # 🔴 KARAR "$denetci" METNİNİN BİÇİMİNE BAĞLI KALMASIN (bağımsız göz #339 tur 3): eski
  # hâlde fail-closed red yalnız `case "$denetci" in *"$yazan"*)` dalında uygulanıyordu —
  # yedek kaydı AYNI modelle gelse bile denetci metni yazanın adını İÇERMİYORSA (biçim
  # farkı, gelecekteki bir format değişimi) kontrol hiç ÇALIŞMAZDI. Karar artık `yedek`
  # ALANININ VARLIĞI üzerinden verilir — metin-eşleşmesinden bağımsız, dolayısıyla
  # denetci'nin tam biçimine duyarlı değil.
  if [ -n "$yedek" ]; then
    if [ -n "$yedek_model" ] && [ -n "$yazan_model" ] && [ "$yedek_model" != "$yazan_model" ]; then
      _y "  · yedek göz: $yedek · yazan modeli $yazan_model ≠ yedek modeli $yedek_model — K1 bağımsız SAYILDI (Sultan Y0006)"
    else
      _h "yedek göz AYNI modelle alınmış (yazan: ${yazan_model:-?} · yedek: ${yedek_model:-?}) — bağımsız göz değil (K1)"; eksik=$((eksik+1))
    fi
  else
    case "$denetci" in
      *"$yazan"*) _h "denetçi yazanla AYNI ($yazan) — bağımsız göz değil (K1)"; eksik=$((eksik+1)) ;;
    esac
  fi
else
  _h "DENETİM kaydı YOK — bağımsız göz hiç koşmamış"; eksik=$((eksik+1))
fi

# ── CANLI-YAZILAN DOSYA UYARISI (yalnız bilgi — rc DEĞİŞMEZ): PR, başka süreçlerin sürekli yazdığı dosyaya dokunuyorsa söyle.
#    Birincil checkout'ta bu dosyalar kirlenir; PR bunlara dokunursa birleşme sonrası `git pull` kilitlenir. Liste canli-dosyalar.txt'te.
#    Değişen dosya listesi okunamazsa "ölçülemedi" denir (yok demez); uyarı kapıyı kırmızıya ÇEVİRMEZ.
canli_uyari() {
  local liste="$HERE/../canli-dosyalar.txt" dosyalar kalip f hit="" okundu=0
  [ -r "$liste" ] || { _y "  ℹ canlı-dosya listesi okunamadı — uyarı ölçülemedi"; return 0; }
  if [ -n "${CANLI_DOSYA_DEGISEN:-}" ] && [ -r "$CANLI_DOSYA_DEGISEN" ]; then dosyalar="$(cat "$CANLI_DOSYA_DEGISEN")"; okundu=1
  elif [ -n "$PR" ] && command -v gh >/dev/null 2>&1 && dosyalar="$(cd "$DEPO" && gh pr diff "$PR" --name-only 2>/dev/null)" && [ -n "$dosyalar" ]; then okundu=1
  elif dosyalar="$(git -C "$WT" diff --name-only origin/main...HEAD 2>/dev/null)" && [ -n "$dosyalar" ]; then okundu=1; fi
  [ "$okundu" -eq 1 ] || { _y "  ℹ değişen dosya listesi okunamadı — canlı-dosya uyarısı ölçülemedi"; return 0; }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    while IFS= read -r kalip; do
      case "$kalip" in ''|\#*) continue ;; esac
      # shellcheck disable=SC2254
      case "$f" in $kalip) hit="$hit $f"; break ;; esac
    done < "$liste"
  done <<< "$dosyalar"
  if [ -n "$hit" ]; then
    _y "  ⚠ PR canlı-yazılan dosyaya dokunuyor (birleşme sonrası birincil checkout'ta pull kilitlenebilir):"
    for f in $hit; do _y "      · $f"; done
  fi
  return 0
}
canli_uyari

if [ "$olcemedi" -gt 0 ]; then _y ""; _h "ÖLÇÜLEMEDİ — kapı yeşil demiyor (rc=3)"; exit 3; fi
if [ "$eksik" -gt 0 ]; then
  _y ""
  _h "BİRLEŞTİRME ENGELLENDİ — $eksik eksik."
  _y "  Yapılacak: kanıtı topla (kanit.sh), bağımsız göze gönder (denetci.sh), 5+E alınca tekrar dene."
  # FABRIKA_KAPISIZ'ı YALNIZ birleştirme kancası okur (scripts/hooks/birlestirme-kapisi.sh); kancası olmayan depoda (izole kutu) değişken
  # hiçbir şey yapmaz — kapıya kaçış öğütlemek ajanı boşa yönlendirir. Orada gerçek yol: eksiği tamamlamak, karar gerekiyorsa kayıtlı karar.
  if [ -x "$DEPO/scripts/hooks/birlestirme-kapisi.sh" ]; then
    _y '  Acil durumda: FABRIKA_KAPISIZ="<en az 20 karakterlik gerekçe>" — kaçış deftere yazılır (sessiz atlama yasak).'
  else
    _y '  Bu depoda birleştirme kancası kurulu değil: FABRIKA_KAPISIZ burada bir şey yapmaz. Eksik kalemi tamamla;'
    _y '  karar gerekiyorsa kayıtlı yol: kart.sh sultan-dedi (Sultan sözü) ya da kart.sh reis-dedi (sınıfsız iş, reis kararı).'
  fi
  exit 1
fi
_y ""; _y "✓ GEÇTİ — kanıt imzalı, bağımsız göz 5/5 + doğru şey E, kart yerinde."
# TCBXPP (Sultan 26 Eki): sınıfsız işte GEÇTİ = "birleştirirdim" kaydı (1 hafta yalnız bildirim; birleştirme yine sahibinde). Kayıt kapıyı bozmaz.
if [ "$sultan" != "E" ] && [ "$sinif" = "yok" ] && [ -x "$HERE/golge-birlestirme.sh" ]; then
  bash "$HERE/golge-birlestirme.sh" "$IS" --depo "$DEPO" ${PR:+--pr "$PR"} ${prbas:+--sha "$prbas"} </dev/null 2>&1 | sed 's/^/  /' || true
fi
exit 0
