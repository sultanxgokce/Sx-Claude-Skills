#!/usr/bin/env python3
"""imar-karne.py — ⛩️ İMAR karnesi (M12). Sayılar DEFTERDEN üretilir, elle yazılmaz.

Kaynaklar (hepsi disk; biri okunamazsa o satır "ölçülemedi" basılır, uydurulmaz):
  hafiza/cark-kosu.log        → günlük tur: koştu / düştü / atlandı · kaynak (cron mu, el mi)
  arastirma-serisi/goz/*.json → ikinci gözün hükümleri (ayakta · çürüdü · ölçülemedi)
  arastirma-serisi/DERSLER.md → ders sayısı, güven dağılımı
  hafiza/imar-kutuk.log       → şalter geçişleri
  hafiza/fikir-mezarligi.jsonl, Bulgu Defteri → fikir sayıları
Damga sayacı: bugünden geriye, ARDIŞIK gün sayısı; gün sayılır ⇔ (zamanlayıcıdan ≥1 tur bitti) ∧ (0 düşen tur) ∧ (göz koştu).

Kaynak tespiti (cron mu, el mi): cark-tur.sh 8 Ekim'den itibaren satıra `kaynak=cron|el` yazar;
daha eski satırlarda saat dilimi ipucu kullanılır (cron UTC +00:00 yazıyor, el +03:00) — bu bir
TAHMİNDİR ve karnede öyle işaretlenir.

Kullanım: python3 scripts/imar-karne.py [--gun 7] [--yaz]   (--yaz: hafiza/karne/<tarih>.md)
"""
import sys, os, re, json, glob, datetime, collections, subprocess

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
KUTUK = os.path.join(REPO, "hafiza", "imar-kutuk.log")
MEZAR = os.path.join(REPO, "hafiza", "fikir-mezarligi.jsonl")
DURUM = os.path.join(REPO, "_agents", "spec", "imar", "DURUM.json")

args = sys.argv[1:]
GUN = int(args[args.index("--gun") + 1]) if "--gun" in args else 7
YAZ = "--yaz" in args
bugun = datetime.date.today()
gunler = [bugun - datetime.timedelta(days=i) for i in range(GUN - 1, -1, -1)]
olculemedi = []

# ── 1. ÇARK kütüğü ───────────────────────────────────────────────────────────
SATIR = re.compile(r"^\[(\d{4}-\d{2}-\d{2})T(\d{2}):\d{2}:\d{2}([+-]\d{2}:\d{2})\] (.*)$")
gun_tur = collections.defaultdict(lambda: {"bitti_cron": 0, "bitti_el": 0, "dustu": 0, "atlandi_kota": 0,
                                           "atlandi_kapali": 0, "goz": None, "tahmin": False})
if os.path.exists(LOG):
    for ln in open(LOG, encoding="utf-8", errors="replace"):
        m = SATIR.match(ln.rstrip("\n"))
        if not m: continue
        tarih, saat, tz, govde = m.groups()
        # UTC yazılmış satırı yerel güne çevir (cron +00:00 yazıyor; 21:00 UTC sonrası ertesi gün)
        try:
            t = datetime.datetime.fromisoformat(f"{tarih}T{saat}:00:00{tz}").astimezone()
            g = t.date()
        except Exception:
            g = datetime.date.fromisoformat(tarih)
        d = gun_tur[g]
        km = re.search(r"kaynak=(cron|el)", govde)
        if km: kaynak = km.group(1)
        else:
            kaynak = "cron" if tz == "+00:00" else "el"
            if "tur bitti" in govde: d["tahmin"] = True
        if govde.startswith("tur bitti"):
            d["bitti_cron" if kaynak == "cron" else "bitti_el"] += 1
        elif govde.startswith("TUR DÜŞTÜ"):
            d["dustu"] += 1
        elif govde.startswith("yuva atlandı: ⛩️"):
            d["atlandi_kapali"] += 1
        elif govde.startswith("yuva atlandı (konu kapalı"):
            d["konu_kapali"] = d.get("konu_kapali", 0) + 1
        elif govde.startswith("yuva atlandı"):
            d["atlandi_kota"] += 1
        elif govde.startswith("ikinci göz:"):
            d["goz"] = ("çürüyen" if "ÇÜRÜYEN" in govde else "ölçülemedi" if "ÖLÇÜLEMEDİ" in govde else "ayakta")
else:
    olculemedi.append("ÇARK kütüğü yok")

# ── 2. İkinci göz dosyaları ──────────────────────────────────────────────────
goz_toplam = collections.Counter(); goz_gun = {}
for f in sorted(glob.glob(os.path.join(SERI, "goz", "*.goz.json"))):
    try:
        d = json.load(open(f, encoding="utf-8"))
        c = collections.Counter(x.get("hukum", "?") for x in d.get("dersler", []))
        goz_toplam.update(c)
        gm = re.search(r"(\d{4}-\d{2}-\d{2})", os.path.basename(f))
        if gm: goz_gun[datetime.date.fromisoformat(gm.group(1))] = c
    except Exception as e:
        olculemedi.append(f"göz dosyası okunamadı: {os.path.basename(f)}")
if not goz_gun and not os.path.isdir(os.path.join(SERI, "goz")):
    olculemedi.append("göz dizini yok")
# ——— 2b. Göz tutarsızlığı: aynı tura birden çok hüküm dosyası (.goz.2.json …) varsa hüküm kaç derste değişti?
# (ölçüldü 11 Ekim: iki koşu üç dersin üçünde farklı hüküm verdi; ilk dosya ezildiği için O fark diskte YOK —
#  karne yalnız diskte duranı sayar, ezilen koşu sayılamaz; bu yüzden göz artık ezmez.)
def _hukumler(f):
    try: return {x.get("no"): x.get("hukum") for x in json.load(open(f, encoding="utf-8")).get("dersler", [])}
    except Exception: return None
coklu = 0; degisen_tur = 0; degisen_ders = 0; tartilan_ders = 0
for f in sorted(glob.glob(os.path.join(SERI, "goz", "*.goz.[0-9]*.json"))):
    ilk = re.sub(r"\.goz\.\d+\.json$", ".goz.json", f)
    a, b = _hukumler(ilk), _hukumler(f)
    if a is None or b is None: continue
    coklu += 1; ortak = [k for k in b if k in a]; tartilan_ders += len(ortak)
    fark = sum(1 for k in ortak if a[k] != b[k]); degisen_ders += fark
    if fark: degisen_tur += 1

# ── 3. Dersler ───────────────────────────────────────────────────────────────
ders_say = None; guven = collections.Counter(); tur_say = len(glob.glob(os.path.join(SERI, "gunluk", "*-tur.md")))
dp = os.path.join(SERI, "DERSLER.md")
if os.path.exists(dp):
    txt = open(dp, encoding="utf-8").read()
    ders_say = len(re.findall(r"^(?:###? |\*\*|\d+\. \*\*)?D-\d{3}", txt, flags=re.M))
    for g in re.findall(r"\*\*(Yüksek|Orta|Düşük|Zayıf) güven", txt): guven[g] += 1
else:
    olculemedi.append("DERSLER.md yok")

# ── 4. Şalter + fikirler ─────────────────────────────────────────────────────
salter = "ölçülemedi"
try:
    sd = json.load(open(DURUM, encoding="utf-8")); salter = ("AÇIK" if sd.get("acik") is True else "KAPALI") + f" (son değişim {sd.get('degisti','?')[:10]})"
except Exception: olculemedi.append("şalter dosyası okunamadı")
gecis = 0
if os.path.exists(KUTUK):
    for ln in open(KUTUK, encoding="utf-8"):
        m = SATIR.match(ln.rstrip("\n"))
        if m and datetime.date.fromisoformat(m.group(1)) >= gunler[0] and re.match(r"(AÇ|KAPAT)", m.group(4)): gecis += 1
mezar = sum(1 for ln in open(MEZAR, encoding="utf-8") if ln.strip()) if os.path.exists(MEZAR) else None
defter = None
try:
    out = subprocess.run(["python3", "/config/.ic-sayfa/defter-yaz.py", "listele"], capture_output=True, text=True, timeout=10).stdout
    defter = collections.Counter(l.split()[1] for l in out.splitlines() if re.match(r"^S-\d+\s", l))
except Exception: olculemedi.append("Bulgu Defteri okunamadı")

# ── 5. Damga sayacı ──────────────────────────────────────────────────────────
# "konu kapalı" günü (9 Ekim) sayacı NE artırır NE sıfırlar: sistem bekliyordu, düşmedi. Sayaç yalnız
# "düştü" ya da "koşması gerekirken koşmadı" günde sıfırlanır. Bekleme günleri ayrıca raporlanır.
damga = 0; bekleme = 0
for g in reversed(gunler):
    d = gun_tur.get(g)
    # 🔴 "göz koştu" ≠ "göz ölçemedi" (ölçüldü 12 Ekim): tur DEVİR yazmadı, göz ÖLÇÜLEMEDİ dedi, sayaç günü
    # saydı. Kusursuz gün = göz fiilen hüküm verdi (ayakta ya da çürüyen); ölçülemedi gün sayacı SIFIRLAR.
    if d and d["bitti_cron"] >= 1 and d["dustu"] == 0 and d["goz"] in ("ayakta", "çürüyen"): damga += 1
    elif d and d["bitti_cron"] == 0 and d["dustu"] == 0 and d.get("konu_kapali", 0) > 0: bekleme += 1; continue
    else: break
tahminli = any(gun_tur[g]["tahmin"] for g in gunler if g in gun_tur)

# ── Çıktı ────────────────────────────────────────────────────────────────────
L = []
L.append(f"# ⛩️ İMAR KARNESİ · {bugun} · son {GUN} gün")
L.append("")
L.append(f"**Şalter:** {salter} · bu dönemde {gecis} geçiş")
L.append(f"**Damga sayacı:** {damga} ardışık gün insansız (ölçüt: zamanlayıcıdan tur bitti ∧ düşen yok ∧ göz koştu). Hedef 3." + (f" Bekleme (konu kapalı) {bekleme} gün: sayılmaz, sıfırlamaz." if bekleme else "") + ("  _(kaynak tespiti eski satırlarda saat-dilimi TAHMİNİ)_" if tahminli else ""))
L.append("")
L.append("| Gün | Tur bitti (zamanlayıcı / el) | Düştü | Atlandı (kota / kapalı) | İkinci göz |")
L.append("|---|---|---|---|---|")
for g in gunler:
    d = gun_tur.get(g)
    if not d: L.append(f"| {g} | — | — | — | — |"); continue
    gz = goz_gun.get(g)
    gzs = " · ".join(f"{k} {v}" for k, v in gz.items()) if gz else (d["goz"] or "—")
    L.append(f"| {g} | {d['bitti_cron']} / {d['bitti_el']} | {d['dustu']} | {d['atlandi_kota']} / {d['atlandi_kapali']} | {gzs} |")
L.append("")
L.append("## Üretim")
L.append(f"- Tur dosyası: {tur_say} · Ders: {ders_say if ders_say is not None else 'ölçülemedi'}" + (f" (güven: {', '.join(f'{k} {v}' for k,v in guven.items())})" if guven else ""))
if goz_toplam:
    top = sum(goz_toplam.values())
    L.append(f"- İkinci gözden geçen ders: {top} → ayakta {goz_toplam.get('ayakta',0)} · çürüdü {goz_toplam.get('curudu',0)} · ölçülemedi {goz_toplam.get('olculemedi',0)}  _(ayakta = çürütülemedi, doğru demek değil)_")
    L.append(f"- Göz tutarlılığı: {coklu} tur birden çok kez koşuldu" + (f" → {degisen_tur} turda hüküm değişti ({degisen_ders}/{tartilan_ders} ders)" if coklu else "") + "  _(ezilen koşular sayılamaz; 11 Ekim'den önce göz ezebiliyordu)_")
else:
    L.append("- İkinci göz: ölçülemedi")
L.append(f"- Fikir defteri: " + (" · ".join(f"{k} {v}" for k, v in defter.items()) if defter else "ölçülemedi") + f" · mezarlık: {mezar if mezar is not None else 'ölçülemedi'}")
L.append("")
if olculemedi:
    L.append("## Ölçülemeyen"); L += [f"- {x}" for x in olculemedi]; L.append("")
L.append("_Bu karne defterden üretildi: `python3 scripts/imar-karne.py`. Elle düzenlenmez._")
metin = "\n".join(L)
print(metin)
if YAZ:
    kd = os.path.join(REPO, "hafiza", "karne"); os.makedirs(kd, exist_ok=True)
    yol = os.path.join(kd, f"{bugun}.md"); open(yol, "w", encoding="utf-8").write(metin + "\n")
    print(f"\n→ yazıldı: {yol}", file=sys.stderr)
