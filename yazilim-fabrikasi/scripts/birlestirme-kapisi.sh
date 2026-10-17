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
#   birlestirme-kapisi.sh --pr <N> [--depo KÖK]     (PR'ın dal adından iş adını çözer)
# rc: 0 GEÇTİ · 1 eksik (kanıt yok/puan yetersiz/kart yok) · 2 kullanım · 3 ÖLÇÜLEMEDİ (yeşil değil)
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
fi
[ -n "$IS" ] || { _h "iş adı gerekiyor (ya da --pr N)"; exit 2; }

KART="$DEPO/_agents/fabrika/kartlar/$IS.json"
DZ="$WT/_agents/fabrika/kanit/$IS"; [ -d "$DZ" ] || DZ="$DEPO/_agents/fabrika/kanit/$IS"

eksik=0; olcemedi=0
_y "── BİRLEŞTİRME KAPISI · iş: $IS"

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
    0) _y "  ✓ kanıt: $(printf '%s' "$cik" | head -1 | sed 's/^✓ //')" ;;
    1) _h "kanıt manifesti BOZUK (elle yazılmış ya da dosya değişmiş)"; eksik=$((eksik+1)) ;;
    *) _h "kanıt YOK — 'kanıtsız iş gönderilemez'"; eksik=$((eksik+1)) ;;
  esac
else
  _h "kanit.py bulunamadı — ÖLÇÜLEMEDİ"; olcemedi=$((olcemedi+1))
fi

# 2b · CANLI — "git'te düzeltildi ≠ canlıda çalışıyor" (retro 17 Eki 2026 · ders 1): cron/servis/sunucu kartı yeşil ölçüm
#    + 5/E ile GEÇMEZ; gerçek ateşleme kaydı (kanit.sh canli, yeşil) ister. Sarı canlı = ölçülmüş ama ateşleme yok → kart ne
#    derse desin geçmez (sarı yeşil değildir). Kartın canlı şartını kart.sh söyler (eski kartta cümleden türetir).
cg="H"; csebep=""
if [ -f "$KART" ] && [ -f "$HERE/kart.sh" ]; then
  IFS=$'\t' read -r cg csebep <<<"$(KANIT_DEPO="$DEPO" bash "$HERE/kart.sh" canli-gerekir "$IS" 2>/dev/null)"; cg="${cg:-H}"; csebep="${csebep:-}"
fi
# 🔴 GÖZ TUR 1 (PR #352): "herhangi bir yeşil canlı kaydı yetiyor; eski ya da ilgisiz kayıt yeni cron değişikliğini geçirir" — doğru.
#    Kayıt bu İŞE BAĞLANIR: ölçüm zamanı DA son ateşleme saati DE kartın açılış zamanından SONRA olmalı. Bağlanamayan yeşil kayıt
#    sayılmaz, sebebi basılır. Kapı sayılan kaydın komutunu ve kaynağını da basar — göz "neyi okudu" diye bakabilsin.
cy=0; cs=0; cilk=""; ckopuk=""
if [ -f "$DZ/KANIT.json" ]; then
  eval "$(python3 - "$DZ/KANIT.json" "$KART" <<'PY'
import json,sys,shlex,datetime
def P(s):
    try: return datetime.datetime.fromisoformat(s)
    except Exception: return None
try: m=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: m={}
kz=None
try: kz=P(json.load(open(sys.argv[2],encoding="utf-8")).get("zaman",""))
except Exception: pass
c=[k for k in m.get("kayitlar",[]) if k.get("tur")=="canli"]
y=[k for k in c if k.get("renk")=="yesil"]; s=[k for k in c if k.get("renk")=="sari"]
bagli_l=[]; kopuk=[]
def bagli_mi(neden): return neden is None
for k in y:
    oz=P(k.get("zaman") or ""); son=P(((k.get("son_atesleme") or k.get("ilk_atesleme") or {}).get("saat_iso")) or "")
    kzs=kz.isoformat(timespec="seconds") if kz else "?"
    if kz is None: neden="kart açılışı zamanı okunamadı"
    elif oz is None or oz<kz: neden=f"ölçüm kart açılışı ({kzs}) ÖNCESİNDE"
    elif son is None: neden="ateşleme saati çözülemedi (saat_iso yok; eski araçla alınmış olabilir)"
    elif son<kz: neden=f"son ateşleme {son.isoformat(timespec='seconds')} kart açılışı {kzs} ÖNCESİNDE — bu işin ateşlemesi değil"
    elif son>oz+datetime.timedelta(minutes=5): neden=f"son ateşleme {son.isoformat(timespec='seconds')} ÖLÇÜMDEN SONRA ({oz.isoformat(timespec='seconds')}) — geleceğe tarihli, şüpheli"
    else: neden=None
    (bagli_l if bagli_mi(neden) else kopuk).append((k,neden))
print("cy="+str(len(bagli_l))); print("cs="+str(len(s)))
if bagli_l:
    k=bagli_l[0][0]; ilk=k.get("ilk_atesleme") or {}
    print("cilk="+shlex.quote(f"{ilk.get('saat','')} · {str(ilk.get('satir',''))[:120]} · kaynak: {k.get('kaynak','')} · komut: {' '.join(k.get('komut') or [])[:160]}"))
else: print("cilk=''")
print("ckopuk="+shlex.quote("; ".join(f"{k.get('etiket')}: {n}" for k,n in kopuk)))
PY
)"
fi
cs_engel=0
[ -n "$ckopuk" ] && _y "  ⚠ canlı kaydı işe bağlanamadı (sayılmaz): $ckopuk"
[ "$cs" -gt 0 ] && { _h "canlı kanıt SARI ($cs kayıt) — ölçülmüş ama ateşleme kaydı yok; sarı yeşil değildir"; eksik=$((eksik+1)); cs_engel=1; }
[ "$cg" = "E" ] && [ "$cy" -eq 0 ] && [ "$cs_engel" -eq 0 ] && { _h "canlı kanıt YOK ya da bu işe bağlı değil — cron/servis/sunucu işi ($csebep) kart açılışından SONRAKİ gerçek ateşleme kaydını ister: kanit.sh canli <iş> <etiket> --kaynak … -- <log okuyan komut>"; eksik=$((eksik+1)); }
[ "$cy" -gt 0 ] && _y "  ✓ canlı: $cy ateşleme kaydı (işe bağlı) · ilk: $cilk"
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

if [ "$olcemedi" -gt 0 ]; then _y ""; _h "ÖLÇÜLEMEDİ — kapı yeşil demiyor (rc=3)"; exit 3; fi
if [ "$eksik" -gt 0 ]; then
  _y ""
  _h "BİRLEŞTİRME ENGELLENDİ — $eksik eksik."
  _y "  Yapılacak: kanıtı topla (kanit.sh), bağımsız göze gönder (denetci.sh), 5+E alınca tekrar dene."
  _y '  Acil durumda: FABRIKA_KAPISIZ="<en az 20 karakterlik gerekçe>" — kaçış deftere yazılır (sessiz atlama yasak).'
  exit 1
fi
_y ""; _y "✓ GEÇTİ — kanıt imzalı, bağımsız göz 5/5 + doğru şey E, kart yerinde."
exit 0
