#!/usr/bin/env bash
# defter.sh — TELLAL üretim-defteri (G2). Append-only jsonl + doğrulama + özet + acı-sayacı.
#
# NEDEN: pilotun çıktısı video değil KANIT. Kaydedilmeyen üretim geri gelmez.
#   Şema/kanon: uretim/SEMA.md
#
# Kullanım:
#   defter.sh ekle  k=v k=v ...        # zorunlu: is_id arac model sure_dk deneme_no tarif_ref
#   defter.sh ozet                     # araç-başı kredi/süre/maliyet + lip-sync ortalaması
#   defter.sh sayac <tarif_ref>        # AYRI is_id sayısı (G5 acı-sayacı) → tek tamsayı
# Exit: 0=tamam · 1=doğrulama/veri hatası · 2=kullanım
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"

# ── ENV-BYPASS KAPISI (denetim 2026-07-25, bulgu K9) ──────────────────────────
# TELLAL_DEFTER serbest bir yol kabul ediyordu: `TELLAL_DEFTER=/dev/null defter.sh sayac X` → 0.
# kuyruk.sh terfi'yi ALT-SÜREÇ olarak çağırdığı ve ortamı miras verdiği için, sahte bir defter
# göstererek G5 acı-sayacı kapısı açılabiliyordu — üstelik terfi olayı GERÇEK kuyruğa yazılıyordu.
# Artık: yalnız TELLAL_TEST=1 iken VE hedef /tmp altındayken kabul edilir.
DEFTER="$REPO_ROOT/uretim/defter.jsonl"
if [ -n "${TELLAL_DEFTER:-}" ]; then
  if [ "${TELLAL_TEST:-}" = "1" ] && case "$TELLAL_DEFTER" in /tmp/*) true ;; *) false ;; esac; then
    DEFTER="$TELLAL_DEFTER"
  else
    echo "[kirmizi] TELLAL_DEFTER yok sayildi: yalniz TELLAL_TEST=1 ve /tmp altinda gecerlidir" >&2
    echo "[kirmizi] (kapi-atlatma korumasi — denetim 2026-07-25/K9). Gercek defter kullanilacak." >&2
    exit 1
  fi
fi

usage() {
  cat >&2 <<'EOF'
kullanim:
  defter.sh ekle  is_id=.. arac=.. model=.. sure_dk=.. deneme_no=.. tarif_ref=.. [kredi=..] [maliyet_usd=..]
                  [lipsync_notu=1-5] [hook_metni=..] [uyum_ok=evet|hayir] [yayin_kanali=..] [ctr=..] [not=..]
  defter.sh ozet
  defter.sh sayac <tarif_ref>
  defter.sh kart  <tarif_ref>        # o tarifin TURETILEN sure/maliyet istatistigi (G3/G11)
  defter.sh duzelt duzeltir=<is_id> sebep=".." [ayni_is=<is_id>] [alan=<ad> dogru_deger=<v>]
                                     # append-only DUZELTME kaydi (satir silinmez/degistirilmez)
sema: uretim/SEMA.md
EOF
  exit 2
}

KOMUT="${1:-}"; shift 2>/dev/null || true
[ -n "$KOMUT" ] || usage
command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 yok" >&2; exit 1; }

case "$KOMUT" in

  ekle)
    [ "$#" -gt 0 ] || usage
    # ── D9: uyum_ok=evet MAKBUZ ISTER (SEMA.md K8'in kalici cozumu) ───────────
    # NEDEN: `uyum_ok` serbest bir alandi; lint hic kosmadan `uyum_ok=evet` yazilabiliyordu.
    # Bu soyut bir risk degil — kalici kanit defterine BES kez dogru-olmayan uyum beyani
    # dustu (SEMA.md K8) ve sonradan duzeltme kaydiyla kapatildi.
    # Makbuzu YALNIZ uyum-lint (RC=0 yolunda) yazar. Makbuz bir SIR degildir, bu yuzden
    # tek basina yeterli sayilmaz: defter lint'i YENIDEN kosar. Bayat ya da elle yazilmis
    # makbuz gecemez — cunku hakem makbuz degil, LINT'IN KENDISIDIR.
    ARGS_TEMIZ=(); UYUM_DEGER=""; MAKBUZ_YOLU=""
    for a in "$@"; do
      case "$a" in
        uyum_ok=*)     UYUM_DEGER="${a#uyum_ok=}";     ARGS_TEMIZ+=("$a") ;;
        uyum_makbuz=*) MAKBUZ_YOLU="${a#uyum_makbuz=}" ;;   # kanit, veri degil → satira yazilmaz
        *) ARGS_TEMIZ+=("$a") ;;
      esac
    done
    if [ "$UYUM_DEGER" = "evet" ]; then
      if [ -z "$MAKBUZ_YOLU" ]; then
        echo "[kirmizi] uyum_ok=evet MAKBUZSUZ yazilamaz (D9)." >&2
        echo "          Makbuzu uyum-lint uretir: uyum-lint.sh <dizin> --makbuz <yol>" >&2
        echo "          Dogrudan yol: scripts/teslimat.sh (uctan uca, makbuzu kendi gecirir)" >&2
        exit 1
      fi
      MAK_DIZIN="$(python3 - "$MAKBUZ_YOLU" <<'PYMAK'
import json, os, sys, hashlib
yol = sys.argv[1]
try:
    m = json.load(open(yol, encoding="utf-8"))
except (OSError, ValueError) as e:
    print(f"HATA: makbuz okunamadi ({e})", file=sys.stderr); sys.exit(1)
if m.get("sonuc") != "GECTI":
    print("HATA: makbuz GECTI demiyor", file=sys.stderr); sys.exit(1)
d = m.get("dizin", "")
tm = os.path.join(d, "TESLIMAT.md")
if not os.path.isfile(tm):
    print(f"HATA: makbuzun gosterdigi teslimat yok: {tm}", file=sys.stderr); sys.exit(1)
if hashlib.sha256(open(tm, "rb").read()).hexdigest() != m.get("teslimat_md_sha256"):
    print("HATA: makbuz BAYAT — TESLIMAT.md makbuzdan sonra degismis", file=sys.stderr); sys.exit(1)
art = m.get("artefakt", "")
if art:
    ay = os.path.join(d, art)
    if not os.path.isfile(ay):
        print(f"HATA: makbuzun gosterdigi artefakt yok: {ay}", file=sys.stderr); sys.exit(1)
    if hashlib.sha256(open(ay, "rb").read()).hexdigest() != m.get("artefakt_sha256"):
        print("HATA: artefakt makbuzdan sonra DEGISMIS", file=sys.stderr); sys.exit(1)
print(d)
PYMAK
)" || { echo "[kirmizi] uyum_ok=evet reddedildi: makbuz gecersiz (D9). Satir YAZILMADI." >&2; exit 1; }
      # Hakem makbuz degil, LINT'in kendisi: taze kosu yesil degilse satir yazilmaz.
      if ! bash "$SCRIPT_DIR/uyum-lint.sh" "$MAK_DIZIN" >/dev/null 2>&1; then
        echo "[kirmizi] uyum_ok=evet reddedildi: uyum-lint SU AN kirmizi ($MAK_DIZIN)." >&2
        echo "          Makbuz vardi ama teslimat artik kapidan gecmiyor. Satir YAZILMADI." >&2
        exit 1
      fi
    fi
    set -- "${ARGS_TEMIZ[@]}"
    mkdir -p "$(dirname "$DEFTER")"
    python3 - "$DEFTER" "$@" <<'PYEOF'
import json, sys, datetime

defter, args = sys.argv[1], sys.argv[2:]
ZORUNLU = ["is_id", "arac", "model", "sure_dk", "deneme_no", "tarif_ref"]
SAYISAL = ["sure_dk", "kredi", "maliyet_usd", "ctr"]
BILINEN = set(ZORUNLU + SAYISAL + ["lipsync_notu", "hook_metni", "uyum_ok", "yayin_kanali", "not"])

kayit, hata = {}, []
for a in args:
    if "=" not in a:
        hata.append(f"bicim disi arguman (k=v bekleniyor): {a!r}"); continue
    k, v = a.split("=", 1)
    k = k.strip()
    if k not in BILINEN:
        hata.append(f"bilinmeyen alan: {k!r} (sema: uretim/SEMA.md)"); continue
    kayit[k] = v.strip()

# ── MALIYET BEYANI ZORUNLU (F0.4, anayasa §6) ────────────────────────────────
# Anayasa §6: "Video-basina kredi+sure kaydi tut." Sure (sure_dk) zaten zorunluydu;
# maliyet DEGILDI. Olculdu (2026-08-15): 12 uretim satirinin 12'sinde `maliyet_usd`
# VAR ama `kredi` alani BOS — yani para tutuluyordu, kredi birimi tutulmuyordu.
# Kural bu yuzden "kredi zorunlu" DEGIL: her satir EN AZ BIR maliyet sinyali tasir.
# Bedavaysa ACIKCA `maliyet_usd=0` yazilir — sessiz yokluk ile beyan edilmis sifir
# ayni sey degildir (ayni gerekce: katman rolleri "acik beyan" kapisi).
# NOT: duzeltme/olay satirlari bu kuraldan muaftir (uretim degillerdir).
if not kayit.get("olay"):
    if not any(kayit.get(a) not in (None, "") for a in ("kredi", "maliyet_usd")):
        hata.append("maliyet beyani yok: 'kredi' ya da 'maliyet_usd' alanlarindan "
                    "en az biri zorunlu (anayasa §6). Bedavaysa ACIKCA maliyet_usd=0 yaz.")

# ANLAMSIZ-DEGER REDDI (denetim 2026-07-25): zorunlu alan '-', 'null', '0', '?' gibi
# yer-doldurucularla "dolu" sayilabiliyordu; gorunmez karakterler (U+200B) de strip()'ten kaciyordu.
# Bir alan doldurulmadiysa satir YAZILMAZ — yarim kanit, kanit degildir.
import unicodedata
# NOT: tek harfli 'x' bilincli olarak LISTEDE DEGIL — mesru kisa bir kimlik olabilir
# (denylist'e eklendiginde `is_id=x` yanlis-pozitif verdi; kapinin guveni yanlis-pozitifle yipranir).
ANLAMSIZ = {"-", "--", ".", "_", "?", "null", "none", "nil", "n/a", "na", "yok", "bos", "tbd"}
def bos_mu(v):
    t = "".join(c for c in (v or "") if unicodedata.category(c) != "Cf").strip()
    return (not t) or t.lower() in ANLAMSIZ

for k in ZORUNLU:
    if k not in kayit or bos_mu(kayit[k]):
        hata.append(f"zorunlu alan eksik/anlamsiz: {k}={kayit.get(k, '')!r} "
                    "(bos, gorunmez-karakter ya da '-'/'null'/'yok' gibi yer-doldurucu kabul edilmez)")

for k in SAYISAL:
    if k in kayit and kayit[k] != "":
        try: kayit[k] = float(kayit[k])
        except ValueError: hata.append(f"{k} sayisal olmali: {kayit[k]!r}")

# sure_dk=0 "sifir insan-emegi" demektir; aci-sayacinin birimi olamaz (denetim 2026-07-25).
if isinstance(kayit.get("sure_dk"), float) and kayit["sure_dk"] <= 0:
    hata.append(f"sure_dk > 0 olmali: {kayit['sure_dk']!r} (sifir-emek bir 'is' degildir)")

if "deneme_no" in kayit:
    try:
        n = int(kayit["deneme_no"])
        if n < 1: raise ValueError
        kayit["deneme_no"] = n
    except (ValueError, TypeError):
        hata.append(f"deneme_no tamsayi >=1 olmali: {kayit.get('deneme_no')!r}")

if "lipsync_notu" in kayit and kayit["lipsync_notu"] != "":
    try:
        n = int(kayit["lipsync_notu"])
        if not 1 <= n <= 5: raise ValueError
        kayit["lipsync_notu"] = n
    except (ValueError, TypeError):
        hata.append(f"lipsync_notu 1-5 arasi tamsayi olmali: {kayit.get('lipsync_notu')!r}")

if kayit.get("uyum_ok") not in (None, "", "evet", "hayir"):
    hata.append(f"uyum_ok evet|hayir olmali: {kayit['uyum_ok']!r}")

if hata:
    for h in hata: print(f"[kirmizi] {h}", file=sys.stderr)
    print("[kirmizi] SATIR YAZILMADI (fail-closed)", file=sys.stderr)
    sys.exit(1)

kayit = {"tarih": datetime.datetime.now().isoformat(timespec="seconds"), **kayit}
# APPEND KILIDI (denetim 2026-07-25): dort ajan ayni deftere yaziyor; kilitsiz append'te
# satirlar ic-ice gecebilir. flock bu konteynerde mevcut.
import fcntl
with open(defter, "a", encoding="utf-8") as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    try:
        f.write(json.dumps(kayit, ensure_ascii=False) + "\n")
        f.flush()
    finally:
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)
print(f"[yesil] satir eklendi: is_id={kayit['is_id']} deneme={kayit['deneme_no']} tarif={kayit['tarif_ref']}")
PYEOF
    ;;

  ozet)
    [ -s "$DEFTER" ] || { echo "defter bos: $DEFTER"; exit 0; }
    python3 - "$DEFTER" <<'PYEOF'
import json, sys, collections

satirlar = []
for i, ln in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    ln = ln.strip()
    if not ln: continue
    try: satirlar.append(json.loads(ln))
    except json.JSONDecodeError:
        print(f"[kirmizi] satir {i} bozuk JSON — atlandi", file=sys.stderr)

if not satirlar:
    print("defter bos"); sys.exit(0)

# ALAN-DUZELTMELERINI UYGULA (bulgu 2026-08-04: `duzelt alan=.. dogru_deger=..` deftere
# yaziliyordu ama ozet onu HIC OKUMUYORDU — yalnizca `ayni_is` birlestirmesi `sayac`ta
# uygulaniyordu. Sonuc: Sultan'in kor-puanlamasi kaydedildi, ozet yine "lipsync YOK" dedi.
# Duzeltme kozmetik kalirsa defter yalan soyler; append-only ilkesi bozulmadan uygulanir:
# ham satirlar degismez, YALNIZ okuma-aninda son duzeltme kazanir.)
duzeltme = {}   # (is_id, alan) -> dogru_deger  ·  dosya sirasi: sonraki kazanir
for s in satirlar:
    if s.get("olay") == "duzeltme" and s.get("duzeltir") and s.get("alan"):
        duzeltme[(s["duzeltir"], s["alan"])] = s.get("dogru_deger")
if duzeltme:
    for s in satirlar:
        iid = s.get("is_id")
        if not iid: continue
        for (hedef, alan), deger in duzeltme.items():
            if hedef == iid:
                s[alan] = deger

satirlar = [s for s in satirlar if s.get("olay") != "duzeltme"]   # duzeltme satiri "deneme" degil

g = collections.defaultdict(lambda: {"n":0, "kredi":0.0, "sure":0.0, "usd":0.0, "ls":[]})
for s in satirlar:
    d = g[s.get("arac", "?")]
    d["n"] += 1
    d["kredi"] += float(s.get("kredi") or 0)
    d["sure"]  += float(s.get("sure_dk") or 0)
    d["usd"]   += float(s.get("maliyet_usd") or 0)
    if s.get("lipsync_notu"): d["ls"].append(int(s["lipsync_notu"]))

print(f"{'arac':<14}{'deneme':>7}{'kredi':>10}{'sure_dk':>9}{'usd':>9}{'lipsync~':>10}")
print("-" * 59)
for arac in sorted(g):
    d = g[arac]
    ls = f"{sum(d['ls'])/len(d['ls']):.1f}" if d["ls"] else "-"
    print(f"{arac:<14}{d['n']:>7}{d['kredi']:>10.1f}{d['sure']:>9.1f}{d['usd']:>9.2f}{ls:>10}")
print("-" * 59)
T = {k: sum(d[k] for d in g.values()) for k in ("n","kredi","sure","usd")}
tum_ls = [x for d in g.values() for x in d["ls"]]
ls = f"{sum(tum_ls)/len(tum_ls):.1f}" if tum_ls else "-"
print(f"{'TOPLAM':<14}{T['n']:>7}{T['kredi']:>10.1f}{T['sure']:>9.1f}{T['usd']:>9.2f}{ls:>10}")

isler = len({s.get("is_id") for s in satirlar})
print(f"\nayri is: {isler} · deneme/is: {len(satirlar)/isler:.1f}")
eksik = sum(1 for s in satirlar if not s.get("lipsync_notu"))
if eksik:
    print(f"[uyari] {eksik} satirda lipsync_notu YOK — kill-kriteri (a) kaniti eksik kaliyor")
PYEOF
    ;;

  duzelt)
    # NEDEN: defter append-only — yanlis satir SILINMEZ. Ama yanlis kayit da OLDUGU GIBI durmaz;
    # ustune DUZELTME kaydi dusulur ve okuyucular (sayac) bunu hesaba katar.
    # Denetim 2026-07-25: iki gercek yanlis bulundu (uyum_ok=evet iddiasi kanitsizdi;
    # tek TEST-A isinin 5 ses varyanti 5 AYRI is_id yazilip G5 kapisini sisirdi).
    [ "$#" -gt 0 ] || usage
    python3 - "$DEFTER" "$@" <<'PYEOF'
import json, sys, datetime, fcntl
defter, args = sys.argv[1], sys.argv[2:]
BILINEN = {"duzeltir", "sebep", "ayni_is", "alan", "dogru_deger"}
kayit, hata = {}, []
for a in args:
    if "=" not in a: hata.append(f"bicim disi arguman: {a!r}"); continue
    k, v = a.split("=", 1); k = k.strip()
    if k not in BILINEN: hata.append(f"bilinmeyen alan: {k!r} (izinli: {', '.join(sorted(BILINEN))})"); continue
    kayit[k] = v.strip()
for k in ("duzeltir", "sebep"):
    if not kayit.get(k): hata.append(f"zorunlu alan eksik: {k}")
if not (kayit.get("ayni_is") or kayit.get("alan")):
    hata.append("ayni_is VEYA alan+dogru_deger verilmeli — neyin duzeltildigi belirsiz")
if kayit.get("alan") and not kayit.get("dogru_deger"):
    hata.append("alan verildiyse dogru_deger de zorunlu")
if kayit.get("ayni_is") and kayit["ayni_is"] == kayit.get("duzeltir"):
    hata.append("ayni_is, duzeltir ile ayni olamaz")
# duzeltilen is_id defterde GERCEKTEN var mi? (uydurma duzeltme yazilmasin)
try:
    mevcut = set()
    for ln in open(defter, encoding="utf-8"):
        ln = ln.strip()
        if not ln: continue
        try: o = json.loads(ln)
        except json.JSONDecodeError: continue
        if isinstance(o, dict) and o.get("is_id"): mevcut.add(o["is_id"])
    if kayit.get("duzeltir") and kayit["duzeltir"] not in mevcut:
        hata.append(f"duzeltilecek is_id defterde YOK: {kayit['duzeltir']!r}")
    if kayit.get("ayni_is") and kayit["ayni_is"] not in mevcut:
        hata.append(f"ayni_is defterde YOK: {kayit['ayni_is']!r}")
except OSError as e:
    hata.append(f"defter okunamadi: {e}")
if hata:
    for h in hata: print(f"[kirmizi] {h}", file=sys.stderr)
    print("[kirmizi] DUZELTME YAZILMADI (fail-closed)", file=sys.stderr)
    sys.exit(1)
kayit = {"tarih": datetime.datetime.now().isoformat(timespec="seconds"), "olay": "duzeltme", **kayit}
with open(defter, "a", encoding="utf-8") as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    try: f.write(json.dumps(kayit, ensure_ascii=False) + "\n"); f.flush()
    finally: fcntl.flock(f.fileno(), fcntl.LOCK_UN)
print(f"[yesil] duzeltme kaydedildi: {kayit['duzeltir']}"
      + (f" → ayni is: {kayit['ayni_is']}" if kayit.get("ayni_is") else f" · {kayit.get('alan')}={kayit.get('dogru_deger')}"))
PYEOF
    ;;

  kart)
    TARIF="${1:-}"
    [ -n "$TARIF" ] || usage
    [ -s "$DEFTER" ] || { echo "defter bos — '$TARIF' icin turetilecek kanit YOK"; exit 1; }
    python3 - "$DEFTER" "$TARIF" <<'PYEOF'
import json, sys, collections, statistics
defter, tarif = sys.argv[1], sys.argv[2]
satirlar = []
for ln in open(defter, encoding="utf-8"):
    ln = ln.strip()
    if not ln: continue
    try: s = json.loads(ln)
    except json.JSONDecodeError: continue
    if s.get("tarif_ref") == tarif: satirlar.append(s)

if not satirlar:
    print(f"[kirmizi] '{tarif}' icin defterde kayit YOK — kanitli sure/maliyet TURETILEMEZ")
    print("         karta elle sayi yazma; once isi yap, deftere kaydet.")
    sys.exit(1)

isler = collections.defaultdict(lambda: {"sure":0.0, "usd":0.0, "kredi":0.0, "deneme":0})
ls = []
for s in satirlar:
    d = isler[s["is_id"]]
    d["sure"]   += float(s.get("sure_dk") or 0)
    d["usd"]    += float(s.get("maliyet_usd") or 0)
    d["kredi"]  += float(s.get("kredi") or 0)
    d["deneme"] += 1
    if s.get("lipsync_notu"): ls.append(int(s["lipsync_notu"]))

sureler = [d["sure"] for d in isler.values()]
usdler  = [d["usd"]  for d in isler.values()]
n = len(isler)
print(f"tarif           : {tarif}")
print(f"ayri is (sayac) : {n}   · toplam deneme: {len(satirlar)}")
print(f"kanitli_sure_dk : {statistics.median(sureler):.1f}  (medyan · min {min(sureler):.1f} / max {max(sureler):.1f})")
print(f"kanitli_maliyet : ${statistics.median(usdler):.2f}  (medyan · toplam kredi {sum(d['kredi'] for d in isler.values()):.0f})")
print(f"lipsync ort.    : {sum(ls)/len(ls):.1f}" if ls else "lipsync ort.    : - (veri yok)")
if n < 3:
    print(f"[uyari] yalnizca {n} is — G11 katalogu icin zayif kanit, G5 aci-sayaci kapisi 3 istiyor")
PYEOF
    ;;

  sayac)
    TARIF="${1:-}"
    [ -n "$TARIF" ] || usage
    # E5 (denetim 2026-07-25): eskiden `[ -s ] && python3 … || echo 0` idi — python CRASH ederse
    # stdout'a '0' basip RC=0 donuyordu. "hic is yok" ile "defter OKUNAMIYOR" ayirt edilemiyordu;
    # G5 kapisinin TEK veri kaynagi sessizce yalan soyluyordu. Artik okunamayan defter RC=1.
    if [ ! -s "$DEFTER" ]; then echo 0; exit 0; fi
    python3 - "$DEFTER" "$TARIF" <<'PYEOF'
import json, sys
defter, tarif = sys.argv[1], sys.argv[2]
isler, bozuk, birlestir = set(), 0, {}
try:
    with open(defter, encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if not ln: continue
            try: s = json.loads(ln)
            except json.JSONDecodeError:
                bozuk += 1; continue
            if not isinstance(s, dict):
                bozuk += 1; continue
            # DUZELTME kaydi: "bu is_id aslinda su isin varyantiydi" (denetim 2026-07-25/K7).
            # Kayit kozmetik kalmasin diye SAYAC bunu HESABA KATAR, yoksa sisik sayac
            # G5 terfi kapisini acik tutmaya devam ederdi.
            if s.get("olay") == "duzeltme":
                if s.get("duzeltir") and s.get("ayni_is"):
                    birlestir[s["duzeltir"]] = s["ayni_is"]
                continue
            if s.get("tarif_ref") == tarif and s.get("is_id"):
                isler.add(s["is_id"])
    def kok(x, _derinlik=0):
        # zincirli birlestirmeyi coz (a→b→c); dongude durur
        while x in birlestir and _derinlik < 50:
            x = birlestir[x]; _derinlik += 1
        return x
    isler = {kok(i) for i in isler}
except OSError as e:
    print(f"[kirmizi] defter okunamadi: {e}", file=sys.stderr); sys.exit(1)
except UnicodeDecodeError as e:
    print(f"[kirmizi] defter metin degil / bozuk kodlama: {e}", file=sys.stderr); sys.exit(1)
if bozuk:
    print(f"[kirmizi] defterde {bozuk} bozuk satir — sayac GUVENILMEZ, kapi acilamaz", file=sys.stderr)
    sys.exit(1)
print(len(isler))
PYEOF
    ;;

  *) usage ;;
esac
