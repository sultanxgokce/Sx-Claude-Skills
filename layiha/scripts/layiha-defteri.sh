#!/usr/bin/env bash
# layiha-defteri.sh — layiha kayıt-defteri (ekle · durum · tescil · liste + zaman/tescil-filtresi)
#
# NE: Her layiha (araştır→sabitle→sonraya-bırak) bu deftere BİR satır düşer. Her kaydın
#     KODU (L01, L02…) + oluşturulma-tarihi + inşa-durumu + TESCİL-durumu vardır.
#
# ⚖️ TESCİL DİSİPLİNİ (Sultan-kararı 2026-07-22): "insa-edildi ≠ tescilli". İnşa-durumu üretici-beyanı;
#    TERMİNAL-başarı = bağımsız-ajanın (MÜHÜRDAR) TESCİL'idir. insa-edildi olan kayıt otomatik
#    tescil-kuyruğuna (tescil.durum=bekliyor) girer; ancak `tescilli` (kör-tescil MUHUR'lu) VEYA `muaf`
#    (Sultan-gerekçeli kaçış) terminal sayılır. Sahte-tescil YASAK: `tescilli --vites TAM` yalnız
#    muhur-ozet.json verdikt=GECTI ile flip'ler (çıplak-flip reddedilir).
#
# DEFTER KONUMU (per-container — İ1 yalnız-yerel; container'lar birbirinin layihasını GÖRMEZ):
#   1) $LAYIHA_DEFTER (env override)  2) <hat-kökü>/_agents/handoff/layiha-defteri.jsonl
#   ⛔ 3. kademe KALDIRILDI (L24 F4, Sultan-kararı K1): eski sürüm git-kökü bulamayınca
#      `$HOME/.claude/layiha-defteri.jsonl`'e düşüyordu. `$HOME=/config` ve `/config/.claude` 10
#      container'ın ORTAK fiziksel dizinidir → ilk yanlış-dizin çağrısı o dosyayı YARATIR ve o andan
#      sonra her oda ötekilerin layihalarını görür (geri-alınamaz İ1 ihlali). Ölçüldü: bu container'da
#      bile 7/10 çalışma dizini oraya düşüyordu. Artık git-siz yerde RC=2 + reçete.
#      Kök `--git-common-dir`'den çözülür → 17 ayrı worktree kopyası sorunu da kapanır (B6).
#
# ŞEMA (L24 F4): her kayıt `v` (şema-sürümü) + `proje` (hangi oda) taşır. Bilinmeyen/daha-yeni `v`
#   görülürse araç DURUR ve HİÇBİR ŞEY YAZMAZ (eski araç yeni defteri ezemez). Eski sürümsüz kayıtlar
#   okuma-anında v=1 sayılır — göç yok.
#
# `liste` SALT-OKURDUR (L24 F4): eskiden eksik alanları doldurup dosyayı baştan yazıyordu; ortak bir
#   dosyada "sadece listeledim" demek yazma-yarışıydı. Artık normalize BELLEKTE kalır, diske yalnız
#   yazma-komutları (ekle/durum/tescil) dokunur — onlar da flock + atomik-replace ile.
#
# Kullanım:
#   layiha-defteri.sh ekle --slug S --konu "..." --dokuman "yol" [--pr "#N"] [--resume "cümle"] [--tarih YYYY-MM-DD]
#   layiha-defteri.sh durum <kod|slug> <insa-bekliyor|insa-ediliyor|insa-edildi>
#       (insa-edildi → tescil.durum otomatik 'yok'→'bekliyor' kuyruğa girer)
#   layiha-defteri.sh tescil <kod|slug> <tescilli|reddi|muaf> [--vites TAM|HAFIF] [--kart k####] \
#       [--muhur <MUHUR.md|muhur-ozet.json yolu>] [--ajan AD] [--gerekce "..."]
#         · tescilli --vites TAM  → --muhur ZORUNLU; muhur-ozet.json verdikt=GECTI doğrulanır (çıplak-flip red)
#         · tescilli --vites HAFIF → --gerekce ZORUNLU (tek-G hafif-tescil beyanı)
#         · reddi / muaf          → --gerekce ZORUNLU
#   layiha-defteri.sh liste [--aktif(default)|--bugun|--hafta|--hafta-bitmemis|--tescil-bekleyen|--hepsi] [--porcelain]
# Çıkış: 0 OK · 2 girdi/ortam hatası
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then echo "HATA: python3 yok." >&2; exit 2; fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/hat-yolu.lib.sh"

if [ -n "${LAYIHA_DEFTER:-}" ]; then LEDGER="$LAYIHA_DEFTER"
else LEDGER="$(hat_yolu layiha-defteri)" || exit 2; fi
# Kayda "hangi oda" damgası için kök gerekir; env-override'lı kullanımda kök çözülemeyebilir → boş geçilir.
HAT_KOK="$(hat_root 2>/dev/null)" || HAT_KOK=""

CMD="${1:-liste}"; shift || true
export LAYIHA_LEDGER="$LEDGER" LAYIHA_LIB_DIR="$HERE" HAT_KOK

python_args() {
  python3 - "$@" <<'PY'
import sys, json
d={}; a=sys.argv[1:]; i=0
while i < len(a):
    k=a[i]
    if k.startswith("--"):
        key=k[2:]
        if i+1 < len(a) and not a[i+1].startswith("--"): d[key]=a[i+1]; i+=2
        else: d[key]=True; i+=1
    else: i+=1
print(json.dumps(d))
PY
}

# ortak: id-atama yardımcısı python-içinde tanımlı (max numeric part + 1 → L%02d)
# ortak: tescil default nesnesi = {"durum":"yok","kart":"","ajan":"","tarih":"","muhur_ref":"","muhur_sha256":"","deneme":0,"vites":"","gerekce":""}

case "$CMD" in
  ekle)
    ARGS="$(python_args "$@")"
    LAYIHA_ARGS_JSON="$ARGS" python3 - <<'PY'
import os, json, sys, subprocess
sys.path.insert(0, os.environ["LAYIHA_LIB_DIR"])
from layiha_defteri_lib import oku, yaz, yeni_tescil, proje_adi, SEMA_V
led=os.environ["LAYIHA_LEDGER"]; a=json.loads(os.environ["LAYIHA_ARGS_JSON"])
for req in ("slug","konu","dokuman"):
    if not a.get(req): sys.stderr.write("HATA: --%s zorunlu\n"%req); sys.exit(2)
tarih=a.get("tarih") or subprocess.check_output(["date","+%F"]).decode().strip()
recs,_=oku(led, kilitle=True)
def id_num(x):
    try: return int(str(x).lstrip("Ll"))
    except: return 0
def next_id():
    mx=max([id_num(r.get("id","")) for r in recs] + [0])
    return "L%02d"%(mx+1)
# mevcut slug'ın id'sini koru; yoksa yeni id
existing=None
for r in recs:
    if r.get("slug")==a["slug"]: existing=r; break
kod = (existing.get("id") if existing and existing.get("id") else next_id())
rec={"v":SEMA_V,"id":kod,"slug":a["slug"],"konu":a["konu"],
     "proje":(a.get("proje") or (existing.get("proje") if existing and existing.get("proje") else proje_adi())),
     "tarih":(existing.get("tarih") if existing and not a.get("tarih") else tarih),
     "durum":a.get("durum", existing.get("durum") if existing else "insa-bekliyor"),
     "dokuman":a["dokuman"],"pr":a.get("pr", existing.get("pr","") if existing else ""),
     "resume":a.get("resume", existing.get("resume","") if existing else ""),"not":a.get("not",""),
     "tescil": (existing.get("tescil") if existing and existing.get("tescil") else yeni_tescil())}
out=[]; found=False
for r in recs:
    if r.get("slug")==rec["slug"]: out.append(rec); found=True
    else: out.append(r)
if not found: out.append(rec)
yaz(led, out)
print("OK: layiha %s %s (%s · %s · oda: %s)"%(rec["id"], "güncellendi" if found else "eklendi",
                                               rec["slug"], rec["tarih"], rec.get("proje") or "?"))
PY
  ;;
  durum)
    KEY="${1:-}"; YENI="${2:-}"
    [ -n "$KEY" ] && [ -n "$YENI" ] || { echo "HATA: durum <kod|slug> <insa-bekliyor|insa-ediliyor|insa-edildi>" >&2; exit 2; }
    case "$YENI" in insa-bekliyor|insa-ediliyor|insa-edildi) ;; *) echo "HATA: geçersiz durum: $YENI" >&2; exit 2;; esac
    KEY="$KEY" YENI="$YENI" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["LAYIHA_LIB_DIR"])
from layiha_defteri_lib import oku, yaz
led=os.environ["LAYIHA_LEDGER"]; key=os.environ["KEY"]; yeni=os.environ["YENI"]
if not os.path.exists(led): sys.stderr.write("HATA: defter yok: %s\n"%led); sys.exit(2)
recs,_=oku(led, kilitle=True)
found=False; kuyruk=False; cikis=False
for r in recs:
    if r.get("slug")==key or str(r.get("id","")).lower()==key.lower():
        r["durum"]=yeni; found=True
        # insa-edildi → tescil kuyruğuna otomatik giriş (K3: zorunlu-tescil). Yalnız 'yok' iken.
        t=r.get("tescil") or {"durum":"yok"}
        if yeni=="insa-edildi" and t.get("durum","yok")=="yok":
            t["durum"]="bekliyor"; r["tescil"]=t; kuyruk=True
        # SİMETRİK KAPI: inşa geri alınırsa kayıt kuyrukta ASILI kalamaz. Yalnız HENÜZ VERDİKT
        # ÇIKMAMIŞ ("bekliyor") kayıt çıkarılır — tescilli/reddi/muaf bir karardır, geri alınmaz.
        # Firsthand: L23 (whatsapp-filo-erisimi) yarım çıkınca 'insa-bekliyor'a alındı ama
        # kuyrukta kaldı → "inşa bekliyor" ile "tescil bekliyor" aynı satırda göründü (2026-07-29).
        elif yeni!="insa-edildi" and t.get("durum","yok")=="bekliyor":
            t["durum"]="yok"; r["tescil"]=t; cikis=True
if not found: sys.stderr.write("HATA: kod/slug bulunamadı: %s\n"%key); sys.exit(2)
yaz(led, recs)
msg="OK: %s → %s"%(key,yeni)
if kuyruk: msg+="  (→ tescil-kuyruğuna girdi: 📋 tescil bekliyor — bağımsız-ajan tescili gerekli)"
if cikis: msg+="  (→ tescil kuyruğundan ÇIKTI: inşa geri alındı, tescil edilecek bir iş kalmadı)"
print(msg)
PY
  ;;
  tescil)
    KEY="${1:-}"; VERD="${2:-}"; shift 2 2>/dev/null || true
    [ -n "$KEY" ] && [ -n "$VERD" ] || { echo "HATA: tescil <kod|slug> <tescilli|reddi|muaf> [--vites TAM|HAFIF] [--muhur yol] [--kart k] [--ajan AD] [--gerekce ...]" >&2; exit 2; }
    case "$VERD" in tescilli|reddi|muaf) ;; *) echo "HATA: geçersiz tescil-verdikti: $VERD (tescilli|reddi|muaf)" >&2; exit 2;; esac
    TARGS="$(python_args "$@")"
    KEY="$KEY" VERD="$VERD" LAYIHA_TESCIL_ARGS="$TARGS" python3 - <<'PY'
import os, json, io, sys, hashlib, subprocess
sys.path.insert(0, os.environ["LAYIHA_LIB_DIR"])
from layiha_defteri_lib import oku, yaz
led=os.environ["LAYIHA_LEDGER"]; key=os.environ["KEY"]; verd=os.environ["VERD"]
a=json.loads(os.environ["LAYIHA_TESCIL_ARGS"])
if not os.path.exists(led): sys.stderr.write("HATA: defter yok: %s\n"%led); sys.exit(2)
vites=(a.get("vites") or "").upper()
muhur=a.get("muhur") or ""
gerekce=a.get("gerekce") or ""
ajan=a.get("ajan") or "MÜHÜRDAR"
kart=a.get("kart") or ""

def hata(m): sys.stderr.write("HATA: %s\n"%m); sys.exit(2)

# --- verdikt-özel ön-koşullar (sahte-tescil panzehiri) ---
sha=""; kanit_verdikt=""
if verd=="tescilli":
    if vites not in ("TAM","HAFIF"): hata("tescilli için --vites TAM|HAFIF zorunlu")
    if vites=="TAM":
        if not muhur: hata("tescilli --vites TAM için --muhur <MUHUR.md|muhur-ozet.json> zorunlu (çıplak-flip red)")
        if not os.path.exists(muhur): hata("muhur yolu yok: %s"%muhur)
        # muhur-ozet.json'u bul: verilen yol MUHUR.md ise kardeşini oku
        ozet=muhur
        if os.path.basename(muhur)!="muhur-ozet.json":
            cand=os.path.join(os.path.dirname(muhur),"muhur-ozet.json")
            if os.path.exists(cand): ozet=cand
            else: hata("muhur-ozet.json bulunamadı (kardeş): %s"%cand)
        try:
            oz=json.load(open(ozet,encoding="utf-8"))
        except Exception as e: hata("muhur-ozet.json okunamadı: %s"%e)
        kanit_verdikt=str(oz.get("verdikt",""))
        if kanit_verdikt.upper()!="GECTI":
            hata("muhur verdikti GECTI değil (%r) — tescilli reddedildi (sahte-tescil panzehiri)"%kanit_verdikt)
        # bayat-referans panzehiri: MUHUR.md'nin sha256'sı (MUHUR.md varsa onun, yoksa ozet'in)
        shafile=muhur if os.path.basename(muhur)!="muhur-ozet.json" else ozet
        sha=hashlib.sha256(open(shafile,"rb").read()).hexdigest()
    else:  # HAFIF
        if not gerekce: hata("tescilli --vites HAFIF için --gerekce '<tek-G kanıt beyanı>' zorunlu")
        if muhur and os.path.exists(muhur):
            sha=hashlib.sha256(open(muhur,"rb").read()).hexdigest()
elif verd in ("reddi","muaf"):
    if not gerekce: hata("%s için --gerekce zorunlu"%verd)

tarih=subprocess.check_output(["date","+%F"]).decode().strip()
recs,_=oku(led, kilitle=True)
found=False; eski=None
for r in recs:
    if r.get("slug")==key or str(r.get("id","")).lower()==key.lower():
        found=True; eski=(r.get("tescil") or {}).get("durum","yok")
        deneme=int((r.get("tescil") or {}).get("deneme",0) or 0)+1
        durum_map={"tescilli":"tescilli","reddi":"reddi","muaf":"muaf"}
        r["tescil"]={"durum":durum_map[verd],"kart":kart,"ajan":ajan,"tarih":tarih,
                     "muhur_ref":muhur,"muhur_sha256":sha,"deneme":deneme,"vites":vites,"gerekce":gerekce}
if not found: hata("kod/slug bulunamadı: %s"%key)
yaz(led, recs)
glyph={"tescilli":"🏅 tescilli","reddi":"↩ tescil reddi","muaf":"⊘ muaf"}[verd]
extra=""
if verd=="tescilli" and vites=="TAM": extra="  (MUHUR verdikt=GECTI doğrulandı, sha=%s…)"%sha[:12]
elif verd=="tescilli" and vites=="HAFIF": extra="  (HAFİF tek-G beyanı)"
print("OK: %s tescil → %s%s"%(key,glyph,extra))
PY
  ;;
  liste)
    FILT="aktif"; PORC=0
    # `*)` dalı ŞART: eskiden `--proje Nexus` gibi tanınmayan bir bayrak SESSİZCE yutuluyordu →
    # kullanıcı süzdüğünü sanıp filtresiz listeye bakıyordu. Boş listeden tehlikeli: yanlış-güven.
    for arg in "$@"; do case "$arg" in
      --aktif) FILT="aktif";; --bugun) FILT="bugun";; --hafta) FILT="hafta";;
      --hafta-bitmemis) FILT="hafta-bitmemis";; --tescil-bekleyen) FILT="tescil-bekleyen";; --hepsi) FILT="hepsi";;
      --porcelain) PORC=1;;
      *) echo "HATA: tanınmayan bayrak: $arg" >&2
         echo "      geçerli: --aktif --bugun --hafta --hafta-bitmemis --tescil-bekleyen --hepsi --porcelain" >&2
         exit 2 ;;
    esac; done
    TODAY="$(date +%F)"; WEEK="$(date +%G-W%V)"
    # otomatik id + tescil backfill: eksik alanlı eski kayıtları idempotent göç ettir
    LAYIHA_FILT="$FILT" LAYIHA_PORC="$PORC" LAYIHA_TODAY="$TODAY" LAYIHA_WEEK="$WEEK" python3 - <<'PY'
import os, sys, datetime
sys.path.insert(0, os.environ["LAYIHA_LIB_DIR"])
from layiha_defteri_lib import oku
led=os.environ["LAYIHA_LEDGER"]; filt=os.environ["LAYIHA_FILT"]; porc=os.environ["LAYIHA_PORC"]=="1"
today=os.environ["LAYIHA_TODAY"]; week=os.environ["LAYIHA_WEEK"]
# SALT-OKUR: normalize BELLEKTE kalır, diske dokunulmaz (bkz başlıktaki gerekçe).
recs,_=oku(led)
def id_num(x):
    try: return int(str(x).lstrip("Ll"))
    except: return 0
def isoweek(d):
    try:
        y,m,dd=map(int,d.split("-")); iso=datetime.date(y,m,dd).isocalendar(); return "%d-W%02d"%(iso[0],iso[1])
    except: return ""
def tdurum(r): return (r.get("tescil") or {}).get("durum","yok")
def terminal(r): return tdurum(r) in ("tescilli","muaf")   # gerçek 'tamamlandı' = tescilli VEYA muaf
def keep(r):
    d=r.get("tarih","")
    if filt=="hepsi": return True
    if filt=="aktif": return not terminal(r)              # insa-edildi ama tescilsiz HÂLÂ aktif (Sultan-ilkesi)
    if filt=="bugun": return d==today
    if filt=="hafta": return isoweek(d)==week
    if filt=="hafta-bitmemis": return isoweek(d)==week and not terminal(r)
    if filt=="tescil-bekleyen": return tdurum(r)=="bekliyor"
    return True
sel=[r for r in recs if keep(r)]
sel.sort(key=lambda r:(terminal(r), id_num(r.get("id",""))))
DUR={"insa-bekliyor":"⏳ inşa bekliyor","insa-ediliyor":"🔨 inşa ediliyor","insa-edildi":"🔧 inşa edildi (tescilsiz)"}
TES={"yok":"—","bekliyor":"📋 tescil bekliyor","tescilli":"🏅 tescilli","reddi":"↩ tescil reddi","muaf":"⊘ muaf"}
if porc:
    # porcelain kontratı GENİŞLETİLDİ (sona eklendi — mevcut alan sıraları korundu): 11. sütun = proje.
    for r in sel:
        t=r.get("tescil") or {}
        print("\t".join([r.get("id",""),r.get("slug",""),r.get("durum",""),tdurum(r),r.get("tarih",""),
                          t.get("kart",""),t.get("muhur_ref",""),r.get("konu",""),r.get("resume",""),
                          r.get("dokuman",""),r.get("proje","")]))
    print("#OZET\ttoplam=%d\tfiltre=%s\tdefter=%s"%(len(sel),filt,led))
else:
    baslik={"aktif":"aktif (tescilsiz) layihalar","bugun":"bugünkü layihalar","hafta":"bu haftaki layihalar",
            "hafta-bitmemis":"bu hafta bitmemiş layihalar","tescil-bekleyen":"tescil bekleyen layihalar","hepsi":"TÜM layihalar"}[filt]
    print("🗂️ LAYİHA DEFTERİ · %s · %d kayıt"%(baslik,len(sel)))
    # "Hangi çekmeceyi açtım" satırı: aynı cümle bir odada 7 satır, başka odada 0 gösterebilir —
    # ikisi de doğrudur. Sessiz-yanlış-defter panzehiri (Sultan-dili teslim S1).
    oda=os.path.basename(os.environ.get("HAT_KOK","").rstrip("/")) or "?"
    print("   oda: %s  ·  defter: %s"%(oda, led))
    print("")
    if not sel: print("  (kayıt yok)")
    for r in sel:
        t=r.get("tescil") or {}; td=tdurum(r)
        print("  [%s]  %s  · %s"%(r.get("id","?"), DUR.get(r.get("durum"),r.get("durum","")), r.get("konu","")))
        # TESCİL satırı: yalnız anlamlıysa (yok değilse) bas — Sultan'ın "tescilli mi değil mi" kolonu
        tescil_str=""
        if td!="yok":
            det=[]
            if t.get("kart"): det.append(t["kart"])
            if t.get("ajan") and td in ("tescilli","reddi"): det.append(t["ajan"])
            if t.get("vites") and td=="tescilli": det.append(t["vites"])
            if t.get("gerekce") and td in ("reddi","muaf"): det.append(t["gerekce"])
            tescil_str="  tescil: %s%s  · "%(TES.get(td,td), (" ("+", ".join(det)+")") if det else "")
        print("        %soluşturuldu: %s%s"%(tescil_str, r.get("tarih","?"),
              ("  ·  devam: \"%s\" de"%r["resume"]) if r.get("resume") else ""))
PY
  ;;
  *) echo "HATA: bilinmeyen komut: $CMD (ekle|durum|tescil|liste)" >&2; exit 2;;
esac
