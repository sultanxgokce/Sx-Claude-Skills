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
# İŞ KAYDI (K2/K3/K5/K7-izin · Sultan-kararı 2026-08-08): defter artık işin NE olduğunun yanında
#   KİMİN İSTEDİĞİNİ (`--isteyen`), HANGİ YETKİYLE açıldığını (`--yetki`) ve `insa-ediliyor`a
#   HANGİ İZİNLE geçildiğini (`--izin`) de tutar; yanlış girilen iddia SİLİNMEZ, `geri-al` ile
#   TERS KAYIT yazılır (`gecmis`). Üçü de geriye-uyumlu: eski kayıtlarda alan yok → "" sayılır.
#
# Kullanım:
#   layiha-defteri.sh ekle --slug S --konu "..." --dokuman "yol" [--pr "#N"] [--resume "cümle"] [--tarih YYYY-MM-DD]
#                          [--isteyen "Sultan|<AJAN>"] [--yetki "<beyan>"]
#   layiha-defteri.sh durum <kod|slug> <insa-bekliyor|insa-ediliyor|insa-edildi> [--kanit "<ref>"] [--izin "<beyan>"]
#       ⚖️ İZİN KAPISI: `insa-ediliyor` İZİNSİZ ilan EDİLEMEZ → RC=2 + reçete ("başlıyorum = izinli").
#       (insa-edildi → tescil.durum otomatik 'yok'→'bekliyor' kuyruğa girer)
#       ⚖️ KANIT KAPISI (K7, 2026-07-29): `insa-edildi` KANITSIZ ilan EDİLEMEZ → RC=2 + reçete.
#          Kabul edilen kanıt: PR ref (#123 ya da URL) · commit sha (≥7 hex) · MEVCUT dosya yolu.
#          Kanıt kayda `insa_kanit` alanına yazılır. Diğer geçişler kanıt İSTEMEZ.
#          Geriye-uyum: eski kayıtlarda alan yok → "" sayılır, hata yok, göç yok.
#   layiha-defteri.sh tescil <kod|slug> <tescilli|reddi|muaf> [--vites TAM|HAFIF] [--kart k####] \
#       [--muhur <MUHUR.md|muhur-ozet.json yolu>] [--ajan AD] [--gerekce "..."]
#         · tescilli --vites TAM  → --muhur ZORUNLU; muhur-ozet.json verdikt=GECTI doğrulanır (çıplak-flip red)
#         · tescilli --vites HAFIF → --gerekce ZORUNLU (tek-G hafif-tescil beyanı)
#         · reddi / muaf          → --gerekce ZORUNLU
#   layiha-defteri.sh geri-al <kod|slug> --gerekce "..."   (K5 ters kayıt: SİLMEZ, tersini yazar;
#         tescil VERDİKTİ verilmiş kayıt reddedilir — verdikt bağımsız ajanın hükmüdür)
#   layiha-defteri.sh liste [--aktif(default)|--bugun|--hafta|--hafta-bitmemis|--tescil-bekleyen|--hepsi]
#         [--sultan|--ajan|--isteyeni-bilinmeyen] [--porcelain]
#         · kim-ekseni zaman/tescil ekseninden BAĞIMSIZ (birlikte kullanılır)
#         · `isteyen`i yazılmamış kayıt hiçbir kim-süzgecine düşmez; kaç tane elendiği EKRANA BASILIR
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
from layiha_defteri_lib import oku, yaz, yeni_tescil, proje_adi, SEMA_V, kanit_gecerli, KANIT_RECETE
led=os.environ["LAYIHA_LEDGER"]; a=json.loads(os.environ["LAYIHA_ARGS_JSON"])
def _metin(v):
    """Değersiz verilmiş bayrak (`--isteyen`) True döner — onu boş-metin say."""
    return ("" if v is True else (v or "")).strip()
for req in ("slug","konu","dokuman"):
    if not a.get(req): sys.stderr.write("HATA: --%s zorunlu\n"%req); sys.exit(2)
# KANIT KAPISI (K7) — `ekle --durum insa-edildi` kapının arka kapısıydı; o da kanıt ister.
# Yalnız AÇIKÇA insa-edildi denince işler: mevcut kaydın eski durumu korunuyorsa (K7 öncesi
# kayıt) dokunulmaz — geriye-uyum.
if a.get("durum")=="insa-edildi":
    _k=(a.get("kanit") if a.get("kanit") is not True else "") or ""
    if not _k.strip():
        sys.stderr.write("HATA: 'insa-edildi' KANITSIZ ilan edilemez (K7 · bitti = kanıtlı).\n"
                         "      Reçete: ekle ... --durum insa-edildi --kanit \"#123\"   (%s)\n"%KANIT_RECETE); sys.exit(2)
    if not kanit_gecerli(_k):
        sys.stderr.write("HATA: kanıt biçimi tanınmadı: %r\n      Reçete: %s\n"%(_k,KANIT_RECETE)); sys.exit(2)
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
     "insa_kanit":((a.get("kanit") if a.get("kanit") is not True else "") or
                   (existing.get("insa_kanit","") if existing else "") or ""),
     # İŞ-KAYDI (K2): kim istedi · hangi yetkiyle. Verilmezse ESKİ değer korunur (güncelleme
     # bir alanı sessizce silmemeli); hiç yoksa "" = BİLİNMİYOR — tahmin edilmez.
     "isteyen":(_metin(a.get("isteyen")) or (existing.get("isteyen","") if existing else "")),
     "yetki":(_metin(a.get("yetki")) or (existing.get("yetki","") if existing else "")),
     "insa_izin":(existing.get("insa_izin","") if existing else ""),
     "gecmis":(existing.get("gecmis",[]) if existing else []),
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
    [ -n "$KEY" ] && [ -n "$YENI" ] || { echo "HATA: durum <kod|slug> <insa-bekliyor|insa-ediliyor|insa-edildi> [--kanit <ref>]" >&2; exit 2; }
    case "$YENI" in insa-bekliyor|insa-ediliyor|insa-edildi) ;; *) echo "HATA: geçersiz durum: $YENI" >&2; exit 2;; esac
    shift 2 2>/dev/null || true
    DARGS="$(python_args "$@")"
    KEY="$KEY" YENI="$YENI" LAYIHA_DURUM_ARGS="$DARGS" python3 - <<'PY'
import os, json, sys
sys.path.insert(0, os.environ["LAYIHA_LIB_DIR"])
from layiha_defteri_lib import oku, yaz, kanit_gecerli, KANIT_RECETE, izin_gecerli, IZIN_RECETE
led=os.environ["LAYIHA_LEDGER"]; key=os.environ["KEY"]; yeni=os.environ["YENI"]
a=json.loads(os.environ.get("LAYIHA_DURUM_ARGS") or "{}")
kanit=a.get("kanit")
if kanit is True: kanit=""          # `--kanit` değer-siz verilmiş
kanit=(kanit or "").strip()
izin=a.get("izin")
if izin is True: izin=""
izin=(izin or "").strip()

# --- İZİN KAPISI (K7'nin başlangıç-yüzü, Sultan-kararı 2026-08-08) ---
# "bitti = kanıtlı" kuralı vardı; "başlıyorum = izinli" kuralı YOKTU. Bir kalem
# `insa-ediliyor`a kimin izniyle geçtiği hiçbir yere yazılmıyordu → sonradan "bunu kim
# başlattı?" diye sorulduğunda defterde cevap yoktu. Artık geçiş beyan ister.
if yeni=="insa-ediliyor":
    if not izin:
        sys.stderr.write(
            "HATA: 'insa-ediliyor' İZİNSİZ ilan edilemez (K7 · başlıyorum = izinli).\n"
            "      Reçete: layiha-defteri.sh durum %s insa-ediliyor --izin \"Sultan onayı 2026-08-08\"\n"
            "      (%s)\n" % (key, IZIN_RECETE))
        sys.exit(2)
    if not izin_gecerli(izin):
        sys.stderr.write(
            "HATA: izin beyanı boş/yer-tutucu: %r — beyan yerine geçmez.\n"
            "      Reçete: %s\n" % (izin, IZIN_RECETE))
        sys.exit(2)
elif izin:
    sys.stderr.write("HATA: --izin yalnız 'insa-ediliyor' geçişinde anlamlıdır (verilen durum: %s)\n"%yeni)
    sys.exit(2)

# --- KANIT KAPISI (K7): "bitti = kanıtlı". Yalnız insa-edildi geçişinde işler. ---
if yeni=="insa-edildi":
    if not kanit:
        sys.stderr.write(
            "HATA: 'insa-edildi' KANITSIZ ilan edilemez (K7 · bitti = kanıtlı).\n"
            "      Reçete: layiha-defteri.sh durum %s insa-edildi --kanit \"#123\"   (%s)\n" % (key, KANIT_RECETE))
        sys.exit(2)
    if not kanit_gecerli(kanit):
        sys.stderr.write(
            "HATA: kanıt biçimi tanınmadı: %r\n"
            "      Reçete: %s\n" % (kanit, KANIT_RECETE))
        sys.exit(2)
elif kanit:
    sys.stderr.write("HATA: --kanit yalnız 'insa-edildi' geçişinde anlamlıdır (verilen durum: %s)\n"%yeni)
    sys.exit(2)

if not os.path.exists(led): sys.stderr.write("HATA: defter yok: %s\n"%led); sys.exit(2)
import subprocess
_bugun=subprocess.check_output(["date","+%F"]).decode().strip()
recs,_=oku(led, kilitle=True)
found=False; kuyruk=False; cikis=False
for r in recs:
    if r.get("slug")==key or str(r.get("id","")).lower()==key.lower():
        _eski=r.get("durum",""); r["durum"]=yeni; found=True
        if yeni=="insa-edildi": r["insa_kanit"]=kanit
        if yeni=="insa-ediliyor": r["insa_izin"]=izin
        # TERS-KAYIT DEFTERİ (K5): her durum geçişi ize düşer. Üzerine yazmak geçmişi yok
        # eder; ekleme yapmak çoğaltır. "Bunu ne zaman kim hangi izinle başlattı?" sorusunun
        # cevabı burada yaşar.
        r.setdefault("gecmis",[]).append(
            {"tarih":_bugun,"fiil":"durum","eski":_eski,"yeni":yeni,
             "dayanak":(kanit or izin or "")})
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
if yeni=="insa-edildi": msg+="  [kanıt: %s]"%kanit
if yeni=="insa-ediliyor": msg+="  [izin: %s]"%izin
if kuyruk: msg+="  (→ tescil-kuyruğuna girdi: 📋 tescil bekliyor — bağımsız-ajan tescili gerekli)"
if cikis: msg+="  (→ tescil kuyruğundan ÇIKTI: inşa geri alındı, tescil edilecek bir iş kalmadı)"
print(msg)
PY
  ;;
  geri-al)
    # K5 — TERS KAYIT. Yanlış girilen bir inşa-iddiasını SİLMEZ, tersini yazar.
    # NİÇİN silmiyoruz: bir iddianın geri alınmış olması da bilgidir. Silinen kayıt
    # "hiç olmamış" gibi görünür; ters-kayıt "denendi, geri alındı, sebebi bu" der.
    KEY="${1:-}"; shift 1 2>/dev/null || true
    [ -n "$KEY" ] || { echo "HATA: geri-al <kod|slug> --gerekce \"...\"" >&2; exit 2; }
    GARGS="$(python_args "$@")"
    KEY="$KEY" LAYIHA_GERI_ARGS="$GARGS" python3 - <<'PY'
import os, json, sys, subprocess
sys.path.insert(0, os.environ["LAYIHA_LIB_DIR"])
from layiha_defteri_lib import oku, yaz
led=os.environ["LAYIHA_LEDGER"]; key=os.environ["KEY"]
a=json.loads(os.environ.get("LAYIHA_GERI_ARGS") or "{}")
g=a.get("gerekce")
if g is True: g=""
g=(g or "").strip()
if not g:
    sys.stderr.write("HATA: geri-al --gerekce zorunlu — bir iddiayı geri almak da bir karardır,\n"
                     "      gerekçesiz karar deftere girmez.\n"
                     "      Reçete: layiha-defteri.sh geri-al %s --gerekce \"kanıt yanlış PR'a işaret ediyordu\"\n"%key)
    sys.exit(2)
if not os.path.exists(led): sys.stderr.write("HATA: defter yok: %s\n"%led); sys.exit(2)
bugun=subprocess.check_output(["date","+%F"]).decode().strip()
recs,_=oku(led, kilitle=True)
hedef=None
for r in recs:
    if r.get("slug")==key or str(r.get("id","")).lower()==key.lower(): hedef=r; break
if hedef is None: sys.stderr.write("HATA: kod/slug bulunamadı: %s\n"%key); sys.exit(2)

t=hedef.get("tescil") or {}
td=t.get("durum","yok")
# VERDİKT EZİLMEZ: tescilli/reddi/muaf bağımsız bir ajanın hükmüdür — üretici onu geri alamaz.
# (Mevcut `durum` komutunun "verdikt ezilmez" kuralının aynısı; burada da geçerli olmalı,
#  yoksa geri-al o kuralın arka kapısı olur.)
if td in ("tescilli","reddi","muaf"):
    sys.stderr.write("HATA: bu kaydın TESCİL VERDİKTİ var (%s) — üretici onu geri alamaz.\n"
                     "      Verdikt bağımsız ajanın hükmüdür; değişmesi gerekiyorsa MÜHÜRDAR'a git.\n"%td)
    sys.exit(2)

eski_durum=hedef.get("durum",""); eski_kanit=hedef.get("insa_kanit",""); eski_izin=hedef.get("insa_izin","")
if eski_durum=="insa-bekliyor" and not eski_kanit and not eski_izin:
    sys.stderr.write("HATA: geri alınacak bir iddia yok (durum zaten 'insa-bekliyor', kanıt/izin boş).\n")
    sys.exit(2)

hedef["durum"]="insa-bekliyor"; hedef["insa_kanit"]=""; hedef["insa_izin"]=""
# kuyruktan çıkış — yalnız henüz verdikt çıkmamışsa (yukarıda zaten garanti)
if td=="bekliyor":
    t["durum"]="yok"; hedef["tescil"]=t
hedef.setdefault("gecmis",[]).append(
    {"tarih":bugun,"fiil":"geri-al","eski":eski_durum,"yeni":"insa-bekliyor",
     "dayanak":eski_kanit or eski_izin or "", "gerekce":g})
yaz(led, recs)
print("OK: %s geri alındı → ⏳ inşa bekliyor  (ters kayıt yazıldı; eski durum: %s%s)"
      %(key, eski_durum, (" · eski kanıt: "+eski_kanit) if eski_kanit else ""))
if td=="bekliyor": print("    (→ tescil kuyruğundan ÇIKTI)")
PY
  ;;
  tescil)
    KEY="${1:-}"; VERD="${2:-}"; shift 2 2>/dev/null || true
    [ -n "$KEY" ] && [ -n "$VERD" ] || { echo "HATA: tescil <kod|slug> <tescilli|reddi|muaf> [--vites TAM|HAFIF] [--muhur yol] [--kart k] [--ajan AD] [--gerekce ...]" >&2; exit 2; }
    case "$VERD" in tescilli|reddi|muaf) ;; *) echo "HATA: geçersiz tescil-verdikti: $VERD (tescilli|reddi|muaf)" >&2; exit 2;; esac
    TARGS="$(python_args "$@")"
    KEY="$KEY" VERD="$VERD" LAYIHA_TESCIL_ARGS="$TARGS" python3 - <<'PY'
import os, json, io, sys, hashlib, shutil, subprocess
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
        # KANIT-KALICILIĞI: damga vurulurken kanıt dosyası deponun İÇİNE alınır.
        # NİÇİN: 2026-07-29'da altı tescil kaydının (L14-L19) işaret ettiği mühür dosyalarının
        #   HİÇBİRİ depoda bulunamadı — hepsi geçici worktree'lerde üretilmiş, worktree
        #   kaldırılınca kanıt yok olmuştu. Defterde damga + parmak-izi vardı, dayandığı belge
        #   YOKTU. Referans tutup referans verileni saklamamak; aynı sınıf bu depoda tekrar ediyor.
        # NE YAPAR: dosyaları HAT_KOK/_agents/tescil/<kart>/ altına kopyalar (üzerine YAZMAZ) ve
        #   ledger'a depo-içi göreli yolu yazar. Kopyalanamıyorsa damga DURMAZ — ama uyarı basılır
        #   ve ledger'a dış yol yazılır; sessiz kayıp yerine görünür eksiklik.
        try:
            kok=os.environ.get("HAT_KOK") or os.environ.get("HAT_ROOT") or ""
            if kok and kart:
                hedef_dir=os.path.join(kok,"_agents","tescil",kart)
                os.makedirs(hedef_dir,exist_ok=True)
                tasinan=[]
                for src in {muhur, ozet}:
                    if not os.path.exists(src): continue
                    dst=os.path.join(hedef_dir,os.path.basename(src))
                    if os.path.abspath(src)==os.path.abspath(dst):
                        tasinan.append(dst); continue
                    if not os.path.exists(dst):
                        shutil.copy2(src,dst)
                    tasinan.append(dst)
                ic=[t for t in tasinan if os.path.basename(t)==os.path.basename(shafile)]
                if ic:
                    muhur_ref_yerel=os.path.relpath(ic[0],kok)
                    sys.stderr.write("NOT: kanıt depoya alındı → %s (COMMIT ETMEYİ UNUTMA)\n"%muhur_ref_yerel)
                    muhur=ic[0]
        except Exception as e:
            sys.stderr.write("UYARI: kanıt depoya alınamadı (%s) — ledger dış yolu taşıyacak, "
                             "kanıt worktree silinince KAYBOLUR\n"%e)
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
    FILT="aktif"; PORC=0; KIM="hepsi"
    # `*)` dalı ŞART: eskiden `--proje Nexus` gibi tanınmayan bir bayrak SESSİZCE yutuluyordu →
    # kullanıcı süzdüğünü sanıp filtresiz listeye bakıyordu. Boş listeden tehlikeli: yanlış-güven.
    for arg in "$@"; do case "$arg" in
      --aktif) FILT="aktif";; --bugun) FILT="bugun";; --hafta) FILT="hafta";;
      --hafta-bitmemis) FILT="hafta-bitmemis";; --tescil-bekleyen) FILT="tescil-bekleyen";; --hepsi) FILT="hepsi";;
      --porcelain) PORC=1;;
      # KİM ekseni (K3) — zaman/tescil ekseninden BAĞIMSIZ: `--aktif --sultan` birlikte çalışır.
      --sultan) KIM="sultan";; --ajan) KIM="ajan";; --isteyeni-bilinmeyen) KIM="bilinmiyor";;
      *) echo "HATA: tanınmayan bayrak: $arg" >&2
         echo "      geçerli: --aktif --bugun --hafta --hafta-bitmemis --tescil-bekleyen --hepsi --porcelain" >&2
         echo "      kim-ekseni: --sultan --ajan --isteyeni-bilinmeyen (zaman/tescil süzgeciyle BİRLİKTE kullanılır)" >&2
         exit 2 ;;
    esac; done
    TODAY="$(date +%F)"; WEEK="$(date +%G-W%V)"
    # otomatik id + tescil backfill: eksik alanlı eski kayıtları idempotent göç ettir
    LAYIHA_FILT="$FILT" LAYIHA_PORC="$PORC" LAYIHA_KIM="$KIM" LAYIHA_TODAY="$TODAY" LAYIHA_WEEK="$WEEK" python3 - <<'PY'
import os, sys, datetime
sys.path.insert(0, os.environ["LAYIHA_LIB_DIR"])
from layiha_defteri_lib import oku, kim_sinifi
led=os.environ["LAYIHA_LEDGER"]; filt=os.environ["LAYIHA_FILT"]; porc=os.environ["LAYIHA_PORC"]=="1"
kim=os.environ.get("LAYIHA_KIM","hepsi")
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
# KİM EKSENİ (K3): zaman/tescil süzgecinden SONRA uygulanır → iki eksen çarpışmaz.
# `isteyen` boş olan kayıt hiçbir kim-süzgecine düşmez; kaçını elediğimizi SAYIP BASIYORUZ —
# sessiz eleme, süzgeci "hepsi bu kadarmış" sanmaya iter (bugünün dersi).
gizlenen=0
if kim!="hepsi":
    sel=[r for r in sel if kim_sinifi(r)==kim]
    if kim in ("sultan","ajan"):
        gizlenen=len([r for r in recs if keep(r) and kim_sinifi(r)=="bilinmiyor"])
sel.sort(key=lambda r:(terminal(r), id_num(r.get("id",""))))
DUR={"insa-bekliyor":"⏳ inşa bekliyor","insa-ediliyor":"🔨 inşa ediliyor","insa-edildi":"🔧 inşa edildi (tescilsiz)"}
TES={"yok":"—","bekliyor":"📋 tescil bekliyor","tescilli":"🏅 tescilli","reddi":"↩ tescil reddi","muaf":"⊘ muaf"}
if porc:
    # porcelain kontratı GENİŞLETİLDİ (sona eklendi — mevcut alan sıraları korundu):
    #   11. sütun = proje · 12. sütun = insa_kanit (K7)
    #   13. sütun = isteyen · 14. sütun = yetki · 15. sütun = insa_izin (K2/K7-izin, 2026-08-08)
    for r in sel:
        t=r.get("tescil") or {}
        print("\t".join([r.get("id",""),r.get("slug",""),r.get("durum",""),tdurum(r),r.get("tarih",""),
                          t.get("kart",""),t.get("muhur_ref",""),r.get("konu",""),r.get("resume",""),
                          r.get("dokuman",""),r.get("proje",""),r.get("insa_kanit",""),
                          r.get("isteyen",""),r.get("yetki",""),r.get("insa_izin","")]))
    print("#OZET\ttoplam=%d\tfiltre=%s\tkim=%s\tisteyeni-bilinmeyen-gizlendi=%d\tdefter=%s"
          %(len(sel),filt,kim,gizlenen,led))
else:
    baslik={"aktif":"aktif (tescilsiz) layihalar","bugun":"bugünkü layihalar","hafta":"bu haftaki layihalar",
            "hafta-bitmemis":"bu hafta bitmemiş layihalar","tescil-bekleyen":"tescil bekleyen layihalar","hepsi":"TÜM layihalar"}[filt]
    KIMBAS={"sultan":"  ·  yalnız SULTAN'ın istedikleri","ajan":"  ·  yalnız AJAN'ların açtıkları",
            "bilinmiyor":"  ·  isteyeni BİLİNMEYEN kayıtlar","hepsi":""}[kim]
    print("🗂️ LAYİHA DEFTERİ · %s%s · %d kayıt"%(baslik,KIMBAS,len(sel)))
    # "Hangi çekmeceyi açtım" satırı: aynı cümle bir odada 7 satır, başka odada 0 gösterebilir —
    # ikisi de doğrudur. Sessiz-yanlış-defter panzehiri (Sultan-dili teslim S1).
    oda=os.path.basename(os.environ.get("HAT_KOK","").rstrip("/")) or "?"
    print("   oda: %s  ·  defter: %s"%(oda, led))
    # Süzgecin eledikleri GÖRÜNÜR: "kayıp meşru olabilir, görünmez olamaz".
    if gizlenen:
        print("   ⚠️  bu süzgeç dışında kalan %d kayıt daha var: isteyeni yazılmamış (eski kayıtlar)."%gizlenen)
        print("       görmek için: --isteyeni-bilinmeyen")
    print("")
    if not sel: print("  (kayıt yok)")
    for r in sel:
        t=r.get("tescil") or {}; td=tdurum(r)
        # Şema-dışı durum SATIRDA görünür: uyarı yalnız stderr'de kalırsa kimse okumaz
        # (bugünün dersi: görünmeyen uyarı = olmayan uyarı).
        _d = DUR.get(r.get("durum"))
        if _d is None:
            _d = "⚠️ ŞEMA-DIŞI durum: %r" % r.get("durum", "")
        print("  [%s]  %s  · %s"%(r.get("id","?"), _d, r.get("konu","")))
        # TESCİL satırı: yalnız anlamlıysa (yok değilse) bas — Sultan'ın "tescilli mi değil mi" kolonu
        tescil_str=""
        if td!="yok":
            det=[]
            if t.get("kart"): det.append(t["kart"])
            if t.get("ajan") and td in ("tescilli","reddi"): det.append(t["ajan"])
            if t.get("vites") and td=="tescilli": det.append(t["vites"])
            if t.get("gerekce") and td in ("reddi","muaf"): det.append(t["gerekce"])
            tescil_str="  tescil: %s%s  · "%(TES.get(td,td), (" ("+", ".join(det)+")") if det else "")
        # K7: inşa iddiası varsa dayanağı da görünsün — "bitti dedi ama neye dayanarak?" kapanır.
        if r.get("durum")=="insa-edildi" and r.get("insa_kanit"):
            print("        kanıt: %s"%r["insa_kanit"])
        # İŞ KAYDI (K2/K7-izin): "bu işi kim istedi, hangi izinle yürüyor" tek bakışta.
        if r.get("durum")=="insa-ediliyor" and r.get("insa_izin"):
            print("        izin: %s"%r["insa_izin"])
        _kim=r.get("isteyen","")
        if _kim or r.get("yetki"):
            print("        isteyen: %s%s"%(_kim or "— (yazılmamış)",
                  ("  ·  yetki: "+r["yetki"]) if r.get("yetki") else ""))
        print("        %soluşturuldu: %s%s"%(tescil_str, r.get("tarih","?"),
              ("  ·  devam: \"%s\" de"%r["resume"]) if r.get("resume") else ""))
PY
  ;;
  *) echo "HATA: bilinmeyen komut: $CMD (ekle|durum|geri-al|tescil|liste)" >&2; exit 2;;
esac
