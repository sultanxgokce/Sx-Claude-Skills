#!/usr/bin/env python3
"""imar-olgunluk.py — ⛩️ İMAR olgunluk göstergesi (M15): proje ne zaman DEVRİYE'ye devredilir?

NİÇİN: İMAR yoktan kurar, DEVRİYE koruyarak iyileştirir. Devir anı "hissetme"yle değil ÖLÇÜLEN eşikle
belirlenir; eşikler defterden okunur, elle yazılmaz. Bu araç KARAR VERMEZ — ölçer ve "hazır/değil" der;
devir kararı Sultan'ındır (A06). Hiçbir eşik "ölçülemedi"yken hazır sayılmaz (fail-closed).

Dört eşik (hepsi diskten):
  E1 · Sultan onaylı canlı iş  : hâl zincirinde ≥1 kayıt 'onaylandı' (Sultan satırıyla)            ← imar-defter.py
  E2 · Ölçümle kanıtlanmış iş  : 'canlı' ya da 'onaylandı' kayıtların en az birinde KANIT SINIFI: olcum ← Bulgu Defteri notları
  E3 · İnsansız kararlılık     : son 14 günde düşen tur 0 ∧ zamanlayıcıdan ≥7 tur bitti               ← cark-kosu.log (karne mantığı)
  E4 · İkinci göz çürütme oranı: son 14 günde çürüyen / (ayakta+çürüyen) ≤ %25 ∧ ≥4 ders tartıldı      ← goz/*.json
Hepsi ✓ → "DEVRİYE'ye devre HAZIR (Sultan kararı)". Biri ✗ ya da ölçülemedi → "İMAR'da kalır" + hangi eşik.

Kullanım: python3 scripts/imar-olgunluk.py [--gun 14]
rc: 0 hazır · 1 hazır değil · 3 ölçülemedi (bir eşik okunamadı → hazır sayılmaz)
"""
import sys, os, re, json, glob, datetime, collections

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def _gerek(ad):
    """Profilden gelmesi gereken ortam değişkeni yoksa ÖLÇEMEDİM der, varsayılan UYDURMAZ.

    🔴 Eski sürüm burada kutu adını (mihenk-muneccim) varsayılan yapıyordu: başka kutuda
    araç sessizce VAR OLMAYAN bir diziniN altını ölçüyor ve "0" basıyordu — yeşil görünen arıza.
    """
    print(f"✗ {ad} yok — İMAR profili çözülmedi (imar-profil.py cozumle); ÖLÇEMEDİM", file=sys.stderr)
    sys.exit(3)


SERI = os.environ["IMAR_SERI"] if os.environ.get("IMAR_SERI") else _gerek("IMAR_SERI")
LOG = os.path.join(REPO, "hafiza", "cark-kosu.log")
BULGULAR = os.environ.get("BULGULAR_JSON", "/config/.ic-sayfa/bulgu-defteri/bulgular.json")
sys.path.insert(0, os.path.join(REPO, "scripts"))

args = sys.argv[1:]
GUN = int(args[args.index("--gun") + 1]) if "--gun" in args else 14
bugun = datetime.date.today(); baslangic = bugun - datetime.timedelta(days=GUN - 1)
sonuc = []  # (ad, durum: True/False/None, açıklama)

# E1 + E2 — hâl zinciri ve kanıt sınıfı
try:
    import importlib.util
    spec = importlib.util.spec_from_file_location("imar_defter", os.path.join(REPO, "scripts", "imar-defter.py"))
    idf = importlib.util.module_from_spec(spec); spec.loader.exec_module(idf)
    ks = idf.kayitlar()
    onayli = [k for k in ks if idf.konum(k) == "onaylandı"]
    canli_ust = [k for k in ks if idf.konum(k) in ("canlı", "onaylandı")]
    sonuc.append(("E1 Sultan onaylı canlı iş", len(onayli) >= 1, f"{len(onayli)} onaylı kayıt"))
    olcumlu = [k for k in canli_ust if any("KANIT SINIFI: olcum" in str(n.get("metin", "")) for n in k.get("notlar", []))]
    sonuc.append(("E2 Ölçümle kanıtlanmış iş", len(olcumlu) >= 1, f"{len(olcumlu)} ölçüm-kanıtlı canlı kayıt ({len(canli_ust)} canlı/onaylı)"))
except SystemExit:
    sonuc.append(("E1 Sultan onaylı canlı iş", None, "defter okunamadı")); sonuc.append(("E2 Ölçümle kanıtlanmış iş", None, "defter okunamadı"))
except Exception as e:
    sonuc.append(("E1 Sultan onaylı canlı iş", None, f"okunamadı: {e}")); sonuc.append(("E2 Ölçümle kanıtlanmış iş", None, f"okunamadı: {e}"))

# E3 — kararlılık (karneyle aynı satır mantığı)
SATIR = re.compile(r"^\[(\d{4}-\d{2}-\d{2})T(\d{2}):\d{2}:\d{2}([+-]\d{2}:\d{2})\] (.*)$")
if os.path.exists(LOG):
    bitti = dustu = 0
    for ln in open(LOG, encoding="utf-8", errors="replace"):
        m = SATIR.match(ln.rstrip("\n"))
        if not m: continue
        tarih, saat, tz, govde = m.groups()
        try: g = datetime.datetime.fromisoformat(f"{tarih}T{saat}:00:00{tz}").astimezone().date()
        except Exception: g = datetime.date.fromisoformat(tarih)
        if g < baslangic: continue
        km = re.search(r"kaynak=(cron|el)", govde); kaynak = km.group(1) if km else ("cron" if tz == "+00:00" else "el")
        if govde.startswith("tur bitti") and kaynak == "cron": bitti += 1
        elif govde.startswith("TUR DÜŞTÜ"): dustu += 1
    sonuc.append((f"E3 İnsansız kararlılık ({GUN} gün)", dustu == 0 and bitti >= 7, f"zamanlayıcıdan {bitti} tur bitti · düşen {dustu} (eşik: ≥7 ∧ 0)"))
else:
    sonuc.append((f"E3 İnsansız kararlılık ({GUN} gün)", None, "ÇARK kütüğü yok"))

# E4 — ikinci göz
c = collections.Counter(); okunan = 0
for f in glob.glob(os.path.join(SERI, "goz", "*.goz.json")) + glob.glob(os.path.join(SERI, "arsiv", "*", "goz", "*.goz.json")):
    gm = re.search(r"(\d{4}-\d{2}-\d{2})", os.path.basename(f))
    if not gm or datetime.date.fromisoformat(gm.group(1)) < baslangic: continue
    try:
        d = json.load(open(f, encoding="utf-8")); okunan += 1
        c.update(x.get("hukum", "?") for x in d.get("dersler", []))
    except Exception: pass
tartilan = c.get("ayakta", 0) + c.get("curudu", 0)
# göz kendiyle tutarsızsa çürütme oranı güvenilmez: aynı tura çoklu koşuda değişen ders oranı >%25 → E4 geçmez
tut_degisen = tut_ortak = 0
for f in glob.glob(os.path.join(SERI, "goz", "*.goz.[0-9]*.json")):
    gm = re.search(r"(\d{4}-\d{2}-\d{2})", os.path.basename(f))
    if not gm or datetime.date.fromisoformat(gm.group(1)) < baslangic: continue
    try:
        a = {x.get("no"): x.get("hukum") for x in json.load(open(re.sub(r"\.goz\.\d+\.json$", ".goz.json", f), encoding="utf-8")).get("dersler", [])}
        b = {x.get("no"): x.get("hukum") for x in json.load(open(f, encoding="utf-8")).get("dersler", [])}
        ortak = [k for k in b if k in a]; tut_ortak += len(ortak); tut_degisen += sum(1 for k in ortak if a[k] != b[k])
    except Exception: pass
tutarsiz = (tut_ortak > 0 and tut_degisen / tut_ortak > 0.25)
if okunan == 0:
    sonuc.append((f"E4 İkinci göz çürütme oranı ({GUN} gün)", None, "göz dosyası yok"))
else:
    oran = (c.get("curudu", 0) / tartilan) if tartilan else None
    ok = oran is not None and tartilan >= 4 and oran <= 0.25 and not tutarsiz
    sonuc.append((f"E4 İkinci göz çürütme oranı ({GUN} gün)", ok,
                  (f"çürüyen {c.get('curudu',0)} / tartılan {tartilan} = %{round(oran*100)}" if oran is not None else "tartılan 0") + f" · ölçülemedi {c.get('olculemedi',0)} (eşik: ≤%25 ∧ ≥4)"
                  + (f" · göz tutarlılığı: çoklu koşuda {tut_degisen}/{tut_ortak} ders değişti" + (" → GÜVENİLMEZ" if tutarsiz else "") if tut_ortak else " · göz tutarlılığı: çoklu koşu yok")))

# Hüküm
print(f"⛩️ İMAR OLGUNLUK · {bugun} · son {GUN} gün")
for ad, dur, acik in sonuc:
    isaret = "✓" if dur is True else ("✗" if dur is False else "?")
    print(f"  {isaret} {ad}: {acik}" + ("" if dur is not None else "  [ÖLÇÜLEMEDİ → hazır sayılmaz]"))
if any(d is None for _, d, _ in sonuc):
    print("HÜKÜM: ÖLÇÜLEMEDİ — en az bir eşik okunamadı; İMAR'da kalır."); sys.exit(3)
if all(d for _, d, _ in sonuc):
    print("HÜKÜM: dört eşik de geçti → DEVRİYE'ye devre HAZIR. Devir kararı Sultan'ındır; bu satır karar değildir."); sys.exit(0)
eksik = [ad for ad, d, _ in sonuc if not d]
print("HÜKÜM: İMAR'da kalır — geçmeyen: " + " · ".join(eksik)); sys.exit(1)
