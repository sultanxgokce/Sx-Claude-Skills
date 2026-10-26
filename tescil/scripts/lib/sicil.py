#!/usr/bin/env python3
"""sicil.py — Mühürdarlık · sicil (isabet bölümü) + ders çıkarma + askı (G11 · S9 · S10; kadro şeması §6-§7).

Alt-komutlar (sicil.sh çağırır):
  isabet <mühürdar> --gorev G --gereklilik Gi --muhur ✓|✗ --sultan katiliyorum|saglanmadi --kaynak <ref>
         [--neden "<Sultan'ın tek cümlesi>"] [--g-tur <tur>] [--bassiz] [--el-kitabi-surum v]
  durum  <mühürdar> [--json]
  ders   <mühürdar> [--json]
  ders-bagla <mühürdar> --isabet-ts <ts> --ders D-NNN
  muhur  <mühürdar> --gorev G --verdikt V [--bassiz] [--el-kitabi-surum v]   (muhurdar.sh her mühürde KENDİSİ yazar)
  teslim-isle <mühürdar> --kaynak <ref> --muhur-dir <deneme-dir>             (geçit: Sultan'ın tek teslim kararı → bütün satırlar)
  supur  [--kutu <çıkış-kutusu.jsonl>] [--muhur-kok <dizin>]                (geçidin çıkış kutusunu süpürür → her görev için teslim-isle)
  muhur-kopya --gorev G --out <mühür-dizini> [--muhur-kok <dizin>]          (muhurdar.sh kendisi çağırır: mühür dosyalarını süpürmenin bulacağı yere kilitli ve atomik kopyalar)

Kayıt yeri: personelin özlük dosyası `<SICIL_DIZIN>/<personel_no>.yaml` → `isabet:` bölümü (append-only; silinmez, ters
kayıtla düzeltilir). Yeni defter KURULMAZ (S9). Satır §6 biçimidir + üç ek alan: `g_tur` (gereklilik türü — ders çıkarma
gruplar), `neden` (Sultan'ın tek cümlesi), `kaynak` (Sultan'ın kaydı — A06). Satırlar JSON nesnesidir (YAML alt kümesi).

🔴 A06: `sultan:` alanı Sultan'ın hükmüdür; ajan üretemez. Biçim yetmez (göz #411 tur 1: `teslim:abc123` uydurulabilirdi):
   kaynak `SICIL_KAYNAK_DOGRULA <kaynak>` ile DOĞRULANIR — geçidin sağladığı bu komut Sultan'ın KAYITLI kararını JSON basar
   (`{"gorev": …, "satirlar": {"G1": {"sultan": "katiliyorum|saglanmadi", "neden": …}}}`) ve hüküm YALNIZ bu çıktıdan alınır.
   Doğrulayıcı yoksa → rc 3 (yazılmaz); kayıt bulunamaz ya da içerik uyuşmazsa → rc 2.
   Pencere (S10) Sultan'ın satırlarından değil MÜHÜR kayıtlarından sayılır: muhurdar.sh her mühürde `tur: muhur` satırı yazar.
RC: 0 tamam · 2 kullanım/biçim/kaynak · 3 ölçülemedi (özlük dosyası yok, YAML okunamadı) — yazılmaz.
"""
import datetime
import fcntl
import json
import os
import re
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

HERE = os.path.dirname(os.path.abspath(__file__))
SICIL_DIZIN = os.environ.get("SICIL_DIZIN", "/config/projects/Nexus/_agents/federe/sicil")
TARIF_KAYDI = os.environ.get("TARIF_KAYDI", "/config/.claude/skills/tarif-kaydi/veri/kadro-tarifleri.json")
EL_KITABI = os.environ.get("EL_KITABI", os.path.join(HERE, "..", "..", "SKILL.md"))
VARSAYILAN_ESIK = {"kacirma": 2, "pencere": 10}   # Sultan S10 (21 Eki): son 10 mühürde 2 kaçırma
D1 = re.compile(r'^\d{4}-\d{2}-\d{2} Sultan: .+ \(sohbet · \S+ · ".+" · beyan:\S+\)$')
TESLIM = re.compile(r"^teslim:[A-Za-z0-9_.-]{6,}$")
DERS_ID = re.compile(r"^D-\d{3}$")


def ad_kat(ad):
    """Türkçe harf katlama: 'MUHAKKİK'.casefold() 'muhakki̇k' (birleşik nokta) verir, 'MUHAKKIK' ile eşleşmez (ölçüldü 22 Eki).
    İ/ı/I/i aynı sayılır — kayıtlarda iki yazım da yaşıyor (MUHAKKIK/MUHAKKİK çatalı, kadro şeması §1c)."""
    return (ad or "").strip().replace("İ", "I").replace("ı", "i").casefold()


def hata(m, rc=2):
    print(f"✗ {m}", file=sys.stderr)
    sys.exit(rc)


def simdi():
    # mikrosaniye: ts satırın anahtarıdır (ders-bagla ts ile bağlar); saniyede birden çok satır düşebilir (sınavda ölçüldü)
    return datetime.datetime.now().astimezone().isoformat(timespec="microseconds")


def ozluk_var(ad):
    """özlük dosyası ya da sicil dizini YOKSA False (bilinen durum: sicili olmayan mühürdarın penceresi de yok)."""
    if not os.path.isdir(SICIL_DIZIN):
        return False
    for f in os.listdir(SICIL_DIZIN):
        if f.endswith(".yaml"):
            with open(os.path.join(SICIL_DIZIN, f), encoding="utf-8") as h:
                for satir in h:
                    m = re.match(r"^persona:\s*(\S+)", satir)
                    if m and ad_kat(m.group(1).strip("\"'")) == ad_kat(ad):
                        return True
    return False


def ozluk_bul(ad):
    """mühürdarın özlük dosyası: `persona:` alanı ada eşit (casefold) olan TEK dosya."""
    if not os.path.isdir(SICIL_DIZIN):
        hata(f"sicil dizini yok: {SICIL_DIZIN} — ölçülemedi", 3)
    bulunan = []
    for f in sorted(os.listdir(SICIL_DIZIN)):
        if not f.endswith(".yaml"):
            continue
        with open(os.path.join(SICIL_DIZIN, f), encoding="utf-8") as h:
            for satir in h:
                m = re.match(r"^persona:\s*(\S+)", satir)
                if m and ad_kat(m.group(1).strip("\"'")) == ad_kat(ad):
                    bulunan.append(os.path.join(SICIL_DIZIN, f)); break
    if not bulunan:
        hata(f"{ad} için özlük dosyası YOK ({SICIL_DIZIN}) — isabet yazılmadı; özlük açmak KÂHYA'nın işi (/ise-alim)", 3)
    if len(bulunan) > 1:
        hata(f"{ad} için birden çok özlük dosyası: {', '.join(os.path.basename(b) for b in bulunan)} — hangisi bilinmeden yazılmaz", 3)
    return bulunan[0]


def oku(yol):
    if yaml is None:
        hata("PyYAML yok — sicil okunamadı (ölçülemedi)", 3)
    try:
        with open(yol, encoding="utf-8") as h:
            return yaml.safe_load(h) or {}
    except yaml.YAMLError as e:
        hata(f"özlük dosyası YAML değil ({os.path.basename(yol)}): {e}", 3)


def isabetler(d):
    """(isabet satırları, ders bağları) — bağ satırı `tur: ders-bagi` taşır, isabet sayılmaz."""
    tum = d.get("isabet") or []
    return [x for x in tum if isinstance(x, dict) and not x.get("tur")], \
           [x for x in tum if isinstance(x, dict) and x.get("tur") == "ders-bagi"]


def ekle(yol, kayit):
    ekle_toplu(yol, [kayit])


def ekle_toplu(yol, kayitlar, onkosul=None):
    """append-only: `isabet:` dosyanın SON üst düzey anahtarı olmalı (yoksa açılır); yazdıktan sonra geri okunur.
    Bütün satırlar TEK yazımla gider (göz #411 tur 3): yeni içerik geçici dosyaya, sonra os.replace — ya hepsi ya hiçbiri;
    yarıda kalan teslim sicili kısmi bırakıp yeniden denemeyi 'zaten işlendi' diye kilitlemez.
    Okuma → yerine koyma süreçler arası KİLİTLE (göz #411 tur 4): eşzamanlı iki yazım aynı eski içeriği okuyup birbirini silmez.
    onkosul(d) kilidin içinde, okunan güncel içerikle koşar (ör. 'bu karar zaten işlendi mi') — yarışta iki kez yazılmaz."""
    kilit = open(os.path.join(os.path.dirname(yol), "." + os.path.basename(yol) + ".kilit"), "a")
    fcntl.flock(kilit, fcntl.LOCK_EX)   # süreç bitince (hata dahil) çekirdek bırakır
    with open(yol, encoding="utf-8") as h:
        metin = h.read()
    if onkosul:
        onkosul(oku(yol))
    ust = [m.group(1) for m in re.finditer(r"^([a-z_]+):", metin, re.M)]
    if "isabet" in ust and ust[-1] != "isabet":
        hata(f"{os.path.basename(yol)}: isabet bölümü dosyanın sonunda değil ({ust[-1]} ondan sonra) — sona eklenemez, elle bakılmalı")
    ek = ("" if metin.endswith("\n") else "\n") + ("" if "isabet" in ust else "isabet:\n")
    ek += "".join("  - " + json.dumps(k, ensure_ascii=False) + "\n" for k in kayitlar)
    gecici = f"{yol}.yaziliyor-{os.getpid()}"
    try:
        with open(gecici, "w", encoding="utf-8") as h:
            h.write(metin + ek); h.flush(); os.fsync(h.fileno())
        os.chmod(gecici, os.stat(yol).st_mode & 0o7777)
        os.replace(gecici, yol)
    except OSError as e:
        try:
            os.unlink(gecici)
        except OSError:
            pass
        hata(f"{os.path.basename(yol)}: yazılamadı ({e}) — dosya değişmedi, yeniden denenebilir", 3)
    son = (oku(yol).get("isabet") or [])[-len(kayitlar):]   # yazdığını DOĞRULA (CLAUDE.md: "yazdım" yetmez, geri oku)
    if son != kayitlar:
        hata(f"{os.path.basename(yol)}: yazılan satır geri okunamadı — dosyaya bak", 3)


def esik():
    try:
        with open(TARIF_KAYDI, encoding="utf-8") as h:
            t = json.load(h)
        for u in t.get("uzmanliklar", []):
            if u.get("id") == "muhurdarlik" and isinstance(u.get("sicil_esigi"), dict):
                e = u["sicil_esigi"]
                if isinstance(e.get("kacirma"), int) and isinstance(e.get("pencere"), int) and e["kacirma"] > 0 and e["pencere"] > 0:
                    return e, "tarif kaydı"
    except (OSError, ValueError):
        pass
    return VARSAYILAN_ESIK, "varsayılan (Sultan S10)"


def argv_al(argv, bayraklar, tekli=()):
    a = {}; i = 0; konum = []
    while i < len(argv):
        if argv[i] in tekli:
            a[argv[i][2:]] = True; i += 1
        elif argv[i] in bayraklar:
            if i + 1 >= len(argv):
                hata(f"{argv[i]} değer ister")
            a[argv[i][2:].replace("-", "_")] = argv[i + 1]; i += 2
        elif argv[i].startswith("--"):
            hata(f"bilinmeyen bayrak: {argv[i]}")
        else:
            konum.append(argv[i]); i += 1
    return a, konum


def sultan_karari(kaynak):
    """A06: Sultan'ın kayıtlı kararı — yalnız geçidin doğrulayıcısından. Biçim denetimi tek başına kanıt değildir."""
    import shlex, subprocess
    if not (D1.match(kaynak) or TESLIM.match(kaynak)):
        hata("--kaynak Sultan'ın KAYDINA işaret etmeli: 'teslim:<kimlik>' ya da D1 damgası — Sultan'ın hükmü üretilmez (A06); yazılmadı")
    komut = os.environ.get("SICIL_KAYNAK_DOGRULA", "").strip()
    if not komut:
        hata("Sultan kaydı DOĞRULANAMADI: doğrulayıcı yok (SICIL_KAYNAK_DOGRULA — teslim geçidi sağlar). A06: doğrulanmamış hüküm yazılmaz", 3)
    try:
        p = subprocess.run(shlex.split(komut) + [kaynak], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as e:
        hata(f"Sultan kaydı doğrulanamadı (doğrulayıcı koşmadı: {e})", 3)
    if p.returncode != 0:
        hata(f"Sultan kaydı BULUNAMADI: {kaynak} (doğrulayıcı rc {p.returncode}) — uydurma kaynakla yazılmaz (A06)")
    try:
        k = json.loads(p.stdout)
        assert isinstance(k.get("satirlar"), dict) and k.get("gorev")
    except (ValueError, AssertionError):
        hata(f"doğrulayıcı geçerli karar dönmedi ({kaynak}) — yazılmadı", 3)
    return k


def cmd_isabet(argv):
    a, k = argv_al(argv, ("--gorev", "--gereklilik", "--muhur", "--sultan", "--kaynak", "--neden", "--g-tur", "--el-kitabi-surum"), ("--bassiz",))
    if len(k) != 1:
        hata("kullanım: isabet <mühürdar> --gorev G --gereklilik Gi --muhur ✓|✗ --sultan katiliyorum|saglanmadi --kaynak <ref> …")
    ad = k[0]
    for z in ("gorev", "gereklilik", "muhur", "sultan"):
        if not a.get(z):
            hata(f"--{z} zorunlu")
    if a["muhur"] not in ("✓", "✗"):
        hata("--muhur ✓ ya da ✗")
    if a["sultan"] not in ("katiliyorum", "saglanmadi"):
        hata("--sultan katiliyorum ya da saglanmadi")
    kaynak = (a.get("kaynak") or "").strip()
    karar = sultan_karari(kaynak)
    ks = karar["satirlar"].get(a["gereklilik"]) or {}
    if karar.get("gorev") != a["gorev"] or ks.get("sultan") != a["sultan"]:
        hata(f"Sultan'ın kaydı bu satırı DOĞRULAMIYOR ({kaynak}: {karar.get('gorev')} {a['gereklilik']} = {ks.get('sultan')}) — yazılmadı (A06)")
    # Sultan'ın cümlesi YALNIZ kayıttan (göz #411 tur 2): --neden verilirse kayıttakiyle aynı olmalı, değiştirilemez
    if a.get("neden") and (a["neden"].strip() != (ks.get("neden") or "").strip()):
        hata(f"--neden Sultan'ın kayıtlı cümlesiyle aynı değil ({kaynak}) — Sultan'ın söylemediği cümle yazılmaz (A06)")
    a["neden"] = ks.get("neden")
    if a["sultan"] == "saglanmadi" and not (a.get("neden") or "").strip():
        hata("Sultan'ın kaydında cümle yok: 'sağlanmadı' Sultan'ın tek cümlesiyle gelir (ders çıkarma bundan beslenir) — yazılmadı")
    yol = ozluk_bul(ad)
    kayit = {"ts": simdi(), "gorev": a["gorev"], "gereklilik": a["gereklilik"], "muhur": a["muhur"], "sultan": a["sultan"],
             "kacirma": "e" if (a["muhur"] == "✓" and a["sultan"] == "saglanmadi") else "h",
             "bassiz": "e" if a.get("bassiz") else "h", "el_kitabi_surum": a.get("el_kitabi_surum"), "ders": None,
             "g_tur": a.get("g_tur"), "neden": (a.get("neden") or "").strip() or None, "kaynak": kaynak}

    def yazilmadi(d):   # kilidin içinde: aynı Sultan kaydının aynı satırı iki kez yazılmaz (iki kaçırma sayılırdı)
        if any(x.get("kaynak") == kaynak and x.get("gorev") == a["gorev"] and x.get("gereklilik") == a["gereklilik"]
               for x in isabetler(d)[0]):
            hata(f"{kaynak} · {a['gorev']} {a['gereklilik']} zaten yazılı — iki kez yazılmaz")
    ekle_toplu(yol, [kayit], yazilmadi)
    print(f"✓ isabet yazıldı: {ad} ({os.path.basename(yol)}) · {a['gorev']} {a['gereklilik']} · mühür {a['muhur']} · Sultan {a['sultan']}"
          + (" · KAÇIRMA" if kayit["kacirma"] == "e" else ""))
    return 0


def hesap(ad):
    yol = ozluk_bul(ad); d = oku(yol); isb, baglar = isabetler(d); e, ek = esik()
    # mühür = görev teslimi; pencere MÜHÜR kayıtlarından (tur: muhur) sayılır — Sultan satırı gelmeyen temiz mühür de pencereyi
    #   ilerletir (göz #411 tur 1). Mühür kaydı olmayan eski isabet satırının görevi kendi yerinde sayılır.
    # Pencere mühür OLAYLARINI sayar (göz #411 tur 2): aynı görevin yeniden mühürü yeni olaydır. İsabet satırı o görevin kendinden
    #   önceki SON mühür olayına bağlanır; mühür kaydı olmayan eski satır kendi yerinde bir olay açar.
    olaylar = []   # [{gorev, kacirma}]
    son = {}       # gorev → olay indeksi
    for x in d.get("isabet") or []:
        if not isinstance(x, dict) or x.get("tur") not in (None, "muhur"):
            continue
        if x.get("tur") == "muhur" or x.get("gorev") not in son:
            olaylar.append({"gorev": x.get("gorev"), "kacirma": False}); son[x.get("gorev")] = len(olaylar) - 1
        if x.get("tur") is None and x.get("kacirma") == "e":
            olaylar[son[x.get("gorev")]]["kacirma"] = True
    gorevler = [o["gorev"] for o in olaylar]
    pencere = olaylar[-e["pencere"]:]
    kacirmali = [o["gorev"] for o in pencere if o["kacirma"]]
    n = len(kacirmali)
    durum = "askida" if n >= e["kacirma"] else ("ders-cikarma" if n >= 1 else "temiz")
    return {"muhurdar": ad, "personel": os.path.basename(yol)[:-5], "muhur_sayisi": len(gorevler), "pencere": len(pencere),
            "kacirmali_muhur": n, "kacirmali_gorevler": kacirmali, "esik": e, "esik_kaynagi": ek, "durum": durum,
            "bagli_ders": {b.get("hedef_ts"): b.get("ders") for b in baglar}}, isb, baglar


def cmd_durum(argv):
    a, k = argv_al(argv, (), ("--json",))
    if len(k) != 1:
        hata("kullanım: durum <mühürdar> [--json]")
    h, _, _ = hesap(k[0])
    gereken = {"temiz": [], "ders-cikarma": [f"ders çıkarma vazifesi: sicil.sh ders {k[0]}"],
               "askida": ["atama ASKIDA (uzmanlık durumu askida)", f"el kitabı güncelleme: sicil.sh ders {k[0]} → ders günlüğü",
                          "yeniden yeterlilik sınavı (diploma)"]}[h["durum"]]
    h["gereken"] = gereken
    if a.get("json"):
        print(json.dumps(h, ensure_ascii=False)); return 0
    print(f"mühürdar {h['muhurdar']} · personel {h['personel']} · {h['muhur_sayisi']} mühür (son {h['pencere']}'u sayıldı) · "
          f"kaçırmalı mühür {h['kacirmali_muhur']} · eşik {h['esik']['kacirma']}/{h['esik']['pencere']} ({h['esik_kaynagi']})")
    print(f"durum: {h['durum']}")
    for g in gereken:
        print(f"  gereken: {g}")
    return 0


def gunluk_dersleri():
    try:
        with open(EL_KITABI, encoding="utf-8") as h:
            metin = h.read()
    except OSError:
        hata(f"el kitabı okunamadı: {EL_KITABI}", 3)
    if "## 12 · Ders günlüğü" not in metin:
        hata("el kitabında '## 12 · Ders günlüğü' bölümü yok — ders bağlanamaz", 3)
    return set(re.findall(r"^- \*\*(D-\d{3})\*\*", metin.split("## 12 · Ders günlüğü", 1)[1], re.M))


def cmd_ders(argv):
    a, k = argv_al(argv, (), ("--json",))
    if len(k) != 1:
        hata("kullanım: ders <mühürdar> [--json]")
    h, isb, baglar = hesap(k[0])
    bagli = {b.get("hedef_ts") for b in baglar}
    acik = [x for x in isb if x.get("kacirma") == "e" and x.get("ts") not in bagli]
    gruplar = {}
    for x in acik:
        gruplar.setdefault(x.get("g_tur") or "(türsüz)", []).append(x)
    tekrar = {t: xs for t, xs in gruplar.items() if len({x.get("gorev") for x in xs}) >= 2}   # ≥2 AYRI görevde aynı tür
    mevcut = gunluk_dersleri()
    taban = max([int(d[2:]) for d in mevcut] or [0]) + 1
    sonraki = f"D-{taban:03d}"
    kimlik = {t: f"D-{taban + i:03d}" for i, t in enumerate(tekrar)}   # göz #411 tur 5: her tekrar eden türe AYRI ders kimliği
    if a.get("json"):
        print(json.dumps({"muhurdar": k[0], "acik_kacirma": len(acik), "tekrar_eden": {t: [x["ts"] for x in xs] for t, xs in tekrar.items()},
                          "sonraki_ders": sonraki, "ders_kimlikleri": kimlik}, ensure_ascii=False)); return 0
    print(f"── ders çıkarma · {k[0]} · bağlanmamış kaçırma {len(acik)} · tekrar eden tür {len(tekrar)}")
    for t, xs in gruplar.items():
        print(f"  {t}: {len(xs)} kaçırma · {len({x.get('gorev') for x in xs})} görev{' — TEKRAR EDEN' if t in tekrar else ''}")
    for t, xs in tekrar.items():
        print(f"\n### Ders taslağı ({kimlik[t]}) — tekrar eden kaçırma türü: {t}")
        for x in xs:
            print(f"- Sultan: \"{x.get('neden')}\" ({x.get('gorev')} {x.get('gereklilik')} · {x.get('ts')})")
        print(f"Kural (el kitabı §12'ye '- **{kimlik[t]}** …' satırı olarak, PR ile): '{t}' türündeki gereklilikte mühürdar şunu da sınar: <yukarıdaki cümlelerden türeyen ölçüt>")
        print(f"Bağla: sicil.sh ders-bagla {k[0]} --isabet-ts <ts> --ders {kimlik[t]}  (her satır için)")
    if not tekrar:
        print("  tekrar eden tür yok — tek kaçırma ders çıkarmada konuşulur, kural yazılmaz (S10: 1 kaçırma = ders çıkarma)")
    return 0


def cmd_ders_bagla(argv):
    a, k = argv_al(argv, ("--isabet-ts", "--ders"))
    if len(k) != 1 or not a.get("isabet_ts") or not a.get("ders"):
        hata("kullanım: ders-bagla <mühürdar> --isabet-ts <ts> --ders D-NNN")
    if not DERS_ID.match(a["ders"]):
        hata("--ders D-NNN biçiminde olmalı")
    if a["ders"] not in gunluk_dersleri():
        hata(f"{a['ders']} el kitabının ders günlüğünde YOK — önce kuralı el kitabına yaz (PR), sonra bağla")
    yol = ozluk_bul(k[0]); isb, baglar = isabetler(oku(yol))
    hedef = [x for x in isb if x.get("ts") == a["isabet_ts"] and x.get("kacirma") == "e"]
    if not hedef:
        hata(f"{a['isabet_ts']} zamanlı KAÇIRMA satırı yok — yalnız kaçırma bir derse bağlanır")

    def baglanmadi(d):   # kilidin içinde: eşzamanlı iki bağlama aynı kaçırmayı iki derse bağlamaz
        if any(b.get("hedef_ts") == a["isabet_ts"] for b in isabetler(d)[1]):
            hata(f"{a['isabet_ts']} zaten bir derse bağlı")
    ekle_toplu(yol, [{"ts": simdi(), "tur": "ders-bagi", "hedef_ts": a["isabet_ts"], "ders": a["ders"]}], baglanmadi)
    print(f"✓ {k[0]} · {a['isabet_ts']} kaçırması {a['ders']} dersine bağlandı (ters kayıt; özgün satır değişmedi)")
    return 0


def cmd_muhur(argv):
    a, k = argv_al(argv, ("--gorev", "--verdikt", "--el-kitabi-surum"), ("--bassiz", "--yoksa-gec"))
    if len(k) != 1 or not a.get("gorev") or not a.get("verdikt"):
        hata("kullanım: muhur <mühürdar> --gorev G --verdikt V [--bassiz] [--el-kitabi-surum v] [--yoksa-gec]")
    if a.get("yoksa-gec") and not ozluk_var(k[0]):   # muhurdar.sh: özlüğü olmayanın sicili yok — atlanır; öbür her hata rc ≠ 0
        print(f"· {k[0]} için özlük yok — mühür kaydı atlandı (özlük KÂHYA'nın işi)", file=sys.stderr); return 0
    yol = ozluk_bul(k[0])
    ekle(yol, {"ts": simdi(), "tur": "muhur", "gorev": a["gorev"], "verdikt": a["verdikt"],
               "bassiz": "e" if a.get("bassiz") else "h", "el_kitabi_surum": a.get("el_kitabi_surum")})
    print(f"✓ mühür kaydı: {k[0]} · {a['gorev']} · {a['verdikt']}")
    return 0


def cmd_teslim_isle(argv):
    """Sultan'ın TEK teslim kararı → mühürün her (mühürdarca sınanan) satırı için bir isabet satırı. Geçit bunu bir kez çağırır."""
    a, k = argv_al(argv, ("--kaynak", "--muhur-dir"))
    if len(k) != 1 or not a.get("kaynak") or not a.get("muhur_dir"):
        hata("kullanım: teslim-isle <mühürdar> --kaynak <ref> --muhur-dir <deneme-dir>")
    karar = sultan_karari(a["kaynak"].strip())
    try:
        oz = json.load(open(os.path.join(a["muhur_dir"], "muhur-ozet.json"), encoding="utf-8"))
        ger = json.load(open(os.path.join(a["muhur_dir"], "gereklilik.json"), encoding="utf-8"))
    except (OSError, ValueError) as e:
        hata(f"mühür dizini okunamadı: {e}", 3)
    if oz.get("kart") != karar["gorev"]:   # göz #411 tur 2: başka görevin mühür sonucu bu karara uygulanmasın
        hata(f"karar {karar['gorev']} görevine ait, mühür dizini {oz.get('kart')} görevinin — eşleşmeyen mühür yazılmaz")
    if oz.get("muhurdar") and ad_kat(oz["muhurdar"]) != ad_kat(k[0]):
        hata(f"bu mühürü {oz['muhurdar']} bastı, {k[0]} değil — başkasının siciline yazılmaz")
    sinanan = [g for g in ger["g"] if g["tur"] != "sultan-denemesi"]   # 👤 satırını mühürdar sınamadı → isabeti olmaz
    eksik = [g["id"] for g in sinanan if not (karar["satirlar"].get(g["id"]) or {}).get("sultan")]
    cumlesiz = [g["id"] for g in sinanan if (karar["satirlar"].get(g["id"]) or {}).get("sultan") == "saglanmadi"
                and not ((karar["satirlar"][g["id"]].get("neden")) or "").strip()]
    gecersiz = [g["id"] for g in sinanan if g["id"] not in eksik
                and karar["satirlar"][g["id"]]["sultan"] not in ("katiliyorum", "saglanmadi")]   # göz #411 tur 3: isabet yolunun kapısı burada da
    if gecersiz:
        hata(f"Sultan'ın kaydında geçersiz hüküm: {', '.join(gecersiz)} (katiliyorum|saglanmadi değil) — yazılmadı")
    if cumlesiz:
        hata(f"Sultan'ın kaydında cümlesiz 'sağlanmadı': {', '.join(cumlesiz)} — yazılmadı")
    if eksik:
        hata(f"Sultan'ın kararında şu satırlar yok: {', '.join(eksik)} — kısmi teslim yazılmaz")
    yol = ozluk_bul(k[0])

    def islenmedi(d):   # kilidin İÇİNDE (göz #411 tur 4): aynı kararı işleyen iki eşzamanlı çağrıdan biri reddedilir
        if any(x.get("kaynak") == a["kaynak"].strip() for x in isabetler(d)[0]):
            hata(f"{a['kaynak']} kararı zaten işlendi — iki kez yazılmaz")
    dusen = set(oz.get("g_dusen") or [])
    satirlar = []
    for g in sinanan:
        ks = karar["satirlar"][g["id"]]
        muhur = "✗" if g["id"] in dusen else "✓"
        satirlar.append({"ts": simdi(), "gorev": karar["gorev"], "gereklilik": g["id"], "muhur": muhur, "sultan": ks["sultan"],
                         "kacirma": "e" if (muhur == "✓" and ks["sultan"] == "saglanmadi") else "h",
                         "bassiz": "h", "el_kitabi_surum": oz.get("tescil_skill_version"), "ders": None,
                         "g_tur": g["tur"], "neden": ks.get("neden"), "kaynak": a["kaynak"].strip()})
    ekle_toplu(yol, satirlar, islenmedi)   # tek yazım: kısmi teslim olmaz
    print(f"✓ teslim işlendi: {k[0]} · {karar['gorev']} · {len(sinanan)} satır (👤 {len(ger['g']) - len(sinanan)} atlandı)")
    return 0


def varsayilan_muhur_kok():
    return os.environ.get("SICIL_MUHUR_KOK") or os.path.join(os.path.expanduser("~"), ".claude", "tescil", "muhur")


def cmd_supur(argv):
    """Geçit Sultan'ın hükmünü çıkış kutusuna (JSONL) tek satır yazar: {"gorev":…, "kaynak":"teslim:<görev>"}. Burada her görev için,
    mühür dizini (muhurdar.sh'in bıraktığı kopya) varsa ve Sultan'ın kararı tamamsa teslim-isle koşar. Sultan'ın hükmü YİNE yalnız
    geçidin doğrulayıcısından gelir (SICIL_KAYNAK_DOGRULA, A06): kutudaki satır bir İŞARETTİR, hüküm kaynağı değildir.
    İşlenen kaynaklar `<kutu>.islendi`ye yazılır; eksik karar / mühür yok / ölçülemedi satırı kutuda KALIR ve sonraki süpürmede yeniden denenir."""
    import subprocess, fcntl
    a, k = argv_al(argv, ("--kutu", "--muhur-kok"))
    if k:
        hata("kullanım: supur [--kutu <jsonl>] [--muhur-kok <dizin>]")
    kutu = a.get("kutu") or os.environ.get("SICIL_CIKIS_KUTUSU")
    if not kutu:
        hata("çıkış kutusu verilmedi (--kutu ya da SICIL_CIKIS_KUTUSU)")
    kok = a.get("muhur_kok") or varsayilan_muhur_kok()
    if not os.path.exists(kutu):
        print(f"✓ süpürme: çıkış kutusu yok ({kutu}) — yapılacak şey yok")
        return 0
    islendi_yol = kutu + ".islendi"
    try:
        islendi = set(x.strip() for x in open(islendi_yol, encoding="utf-8")) if os.path.exists(islendi_yol) else set()
    except OSError as e:
        hata(f"işlenenler listesi okunamadı: {e}", 3)
    kaynaklar = {}   # kaynak → görev (ilk satır kazanır; aynı görevin tekrar satırları tek iş)
    bozuk = 0
    with open(kutu, encoding="utf-8") as h:
        for ham in h:
            if not ham.strip():
                continue
            try:
                x = json.loads(ham); g, kay = x["gorev"], x["kaynak"]
                assert isinstance(g, str) and isinstance(kay, str) and TESLIM.match(kay) and kay == "teslim:" + g   # kaynak ile görev AYNI kayda işaret eder
            except (ValueError, KeyError, AssertionError, TypeError):
                bozuk += 1; continue
            kaynaklar.setdefault(kay, g)
    sayi = {"islendi": 0, "zaten": 0, "bekliyor": 0, "reddedildi": 0}
    ayrinti = []
    for kay, g in kaynaklar.items():
        if kay in islendi:
            sayi["zaten"] += 1; continue
        md = os.path.join(kok, g)
        # mühür kopyası yazılırken (muhur-kopya, özel kilit) HİÇBİR şey okunmaz: mühürdar adı, gereklilik ve özet aynı koşuya ait kalır —
        #   kilit, özeti okumadan ÖNCE alınır ve teslim-isle bitene dek tutulur
        try:
            kilit = open(os.path.join(md, ".kilit"), "a")
        except OSError:
            sayi["bekliyor"] += 1; ayrinti.append(f"{g}: bekliyor (mühür dizini yok: {md})"); continue
        try:
            fcntl.flock(kilit, fcntl.LOCK_SH)
            try:
                oz = json.load(open(os.path.join(md, "muhur-ozet.json"), encoding="utf-8"))
                assert os.path.exists(os.path.join(md, "gereklilik.json")) and oz.get("muhurdar")
            except (OSError, ValueError, AssertionError):
                sayi["bekliyor"] += 1; ayrinti.append(f"{g}: bekliyor (mühür özeti yok ya da mühürdarsız: {md})"); continue
            try:
                p = subprocess.run([sys.executable, os.path.abspath(__file__), "teslim-isle", oz["muhurdar"], "--kaynak", kay, "--muhur-dir", md],
                                   capture_output=True, text=True, timeout=int(os.environ.get("SICIL_SUPUR_ZAMAN", "120")))
            except subprocess.TimeoutExpired:
                sayi["bekliyor"] += 1; ayrinti.append(f"{g}: bekliyor (zaman aşımı — doğrulayıcı ya da teslim-isle yanıt vermedi)"); continue
        finally:
            kilit.close()
        hata_metni = (p.stderr or "").strip().splitlines()[-1:] or [""]
        if p.returncode == 0 or "zaten işlendi" in p.stderr:
            with open(islendi_yol, "a", encoding="utf-8") as w:
                fcntl.flock(w, fcntl.LOCK_EX); w.write(kay + "\n")
            sayi["islendi" if p.returncode == 0 else "zaten"] += 1
        elif "satırlar yok" in p.stderr or p.returncode == 3:
            sayi["bekliyor"] += 1; ayrinti.append(f"{g}: bekliyor ({hata_metni[0].lstrip('✗ ')})")
        else:
            sayi["reddedildi"] += 1; ayrinti.append(f"{g}: REDDEDİLDİ ({hata_metni[0].lstrip('✗ ')})")
    for s_ in ayrinti:
        print("  · " + s_)
    print(f"✓ süpürme: {sayi['islendi']} işlendi · {sayi['zaten']} zaten işli · {sayi['bekliyor']} bekliyor · {sayi['reddedildi']} reddedildi"
          + (f" · {bozuk} bozuk satır atlandı" if bozuk else ""))
    return 4 if sayi["reddedildi"] or bozuk else 0


def cmd_muhur_kopya(argv):
    """muhurdar.sh her gerçek mühürde çağırır: muhur-ozet.json + gereklilik.json'u <kök>/<görev>/ altına, süpürmeyle ORTAK kilitle
    (özel kilit) ve dosya dosya atomik yer değiştirerek kopyalar — süpürme iki ayrı koşunun dosyalarını birlikte okuyamaz."""
    import fcntl, shutil
    a, k = argv_al(argv, ("--gorev", "--out", "--muhur-kok"))
    if k or not a.get("gorev") or not a.get("out"):
        hata("kullanım: muhur-kopya --gorev G --out <mühür-dizini> [--muhur-kok <dizin>]")
    kok = a.get("muhur_kok") or varsayilan_muhur_kok()
    if "/" in a["gorev"] or a["gorev"] in (".", ".."):
        hata(f"görev adı dizin adı olamaz: {a['gorev']}")
    hedef = os.path.join(kok, a["gorev"])
    kaynaklar = [os.path.join(a["out"], f) for f in ("muhur-ozet.json", "gereklilik.json")]
    for f in kaynaklar:
        if not os.path.isfile(f):
            hata(f"mühür dosyası yok: {f}", 3)
    try:
        os.makedirs(hedef, exist_ok=True)
        kilit = open(os.path.join(hedef, ".kilit"), "a")
        fcntl.flock(kilit, fcntl.LOCK_EX)
        for f in kaynaklar:
            gecici = os.path.join(hedef, "." + os.path.basename(f) + f".yeni-{os.getpid()}")
            shutil.copyfile(f, gecici)
            os.replace(gecici, os.path.join(hedef, os.path.basename(f)))
    except OSError as e:
        hata(f"mühür kopyası yazılamadı ({hedef}): {e}", 3)
    print(f"✓ mühür kopyası: {hedef}")
    return 0


def main():
    if len(sys.argv) < 2:
        hata("kullanım: sicil.py isabet|durum|ders|ders-bagla|muhur|teslim-isle|supur|muhur-kopya …")
    k = {"isabet": cmd_isabet, "durum": cmd_durum, "ders": cmd_ders, "ders-bagla": cmd_ders_bagla,
         "muhur": cmd_muhur, "teslim-isle": cmd_teslim_isle, "supur": cmd_supur, "muhur-kopya": cmd_muhur_kopya}.get(sys.argv[1])
    if not k:
        hata(f"bilinmeyen alt komut: {sys.argv[1]}")
    return k(sys.argv[2:])


if __name__ == "__main__":
    sys.exit(main())
