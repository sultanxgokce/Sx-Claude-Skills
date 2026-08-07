#!/usr/bin/env python3
"""yogunluk-denetle.py — üretilen ekran kümesinde yoğunluk + çapraz-ekran denetimi.

NİÇİN VAR: sözleşme uyumlu ekranlar yine de "karışık" çıkabiliyor (ölçüldü: bir turun 5
ekranı da mekanik kapıdan geçti, insan oturumu 11 madde çıkardı). Eksik olan boyut renk
ya da tipografi değil YOĞUNLUK ve ekranlar-arası TUTARLILIK'tı. Bu araç o iki boyutu
LLM'siz, tarayıcısız, deterministik ölçer — model yorumuna hiç sormaz.

NE ÖLÇMEZ (dürüstlük): tek-ekran anlamı (manşetin öznesi doğru mu, görsel bilgi taşıyor mu).
O boyut insan ya da kör yargıç işidir; bu araç ona "temiz" demez, hiç bakmaz.

KULLANIM
  yogunluk-denetle.py <ekran-dizini> [--profil <dosya>]
  yogunluk-denetle.py --profil-ornek > tasarim/kapi-profili.json   # şablon üret

PROFİL: kapının ölçtüğü SAYILAR projenin kendi sözleşmesinden gelir (çekirdek = kural,
marka = değer). Profil yoksa kapı RC=2 döner — varsayılan uydurup yanlış-yeşil vermez.

ÇIKIŞ: 0 temiz · 1 en az bir ihlal · 2 çalıştırılamadı (profil/dosya yok)

ÖLÇÜM-DÜRÜSTLÜĞÜ (kalibrasyonda üç yanlış-pozitif sınıfı yakalanıp kapatıldı):
  • "Örnek durumlar" vitrini bütçe sayımlarının DIŞINDA — sözleşme o bölümü zaten
    "gerçek sanılmasın" diye işaretletir; gerçek saymak ölçüm hatasıdır. Küme-kuralları
    (renk/punto kümesi, sözlük, yasak dil) vitrin DAHİL koşar: drift orada da drift.
  • Yüzey modeli: arka-sayfa ⟂ her yan-panel örneği ayrı yüzey; bütçe yüzey başına.
  • Koşul-farkındalığı: birbirini dışlayan şablon dallarındaki (sc-if) öğeler bütçeye
    sert sayılmaz; AYNI daldaki çift yine serttir, farklı dallar İNSAN-GÖZÜ notu olur.
"""
import glob, json, os, re, sys

ORNEK_PROFIL = {
    "_aciklama": "Kapının ölçtüğü sayılar. Kaynak: projenin tasarım dili sözleşmesi. "
                 "Buradaki her değer sözleşmede yazılı olanla AYNI olmalı; sapma driftir.",
    "buyuk_punto_taban": 25.0,
    "buyuk_sayi_butce": 3,
    "blok_tur_butce": 2,
    "font_kademeleri": ["12.5", "14.5", "16.5", "21", "25"],
    "radius_kumesi": ["0", "8", "10", "999"],
    "birincil_renk": "#8a5a2b",
    # Çekirdeğin on adı (cekirdek/sozlesme.md Ç3) + bu örnek ürünün kendi adları.
    # ÇEKİRDEK ADLARI ÇIKARILAMAZ: cekirdek-sozluk-denetle.py bekçisi kapsamayı ölçer;
    # buradan bir çekirdek adı düşerse ya da yazımı sapar ise sınav KIRMIZI yanar.
    "sozluk": ["Gezinme", "Sayfa başlığı", "Liste satırı", "Form alanı", "Düğme",
               "Onay diyaloğu", "Yan panel", "Bilgi şeridi", "Boş durum", "Durum rozeti",
               "Başlık şeridi", "Veri tablosu", "Ölçü kartı", "Dipnot"],
    "blok_turu": {"Veri tablosu": "liste", "Ölçü kartı": "kart", "Bilgi şeridi": "şerit"},
    "yasak_dil": ["tasarruf", "kazan[cç]"],
}

MARKER = re.compile(r"<!--\s*bilesen:\s*([^->]+?)\s*(?:—\s*([^->]*?)\s*)?-->")
FONT_PX = re.compile(r"font-size:\s*([0-9.]+)px")
RADIUS_PX = re.compile(r"border-radius:\s*([0-9]+)px")


def govde(icerik):
    """<style>/<script> ölçüm dışı (medya-kuralları + veri); ölçülen inline stildir."""
    icerik = re.sub(r"<style\b.*?</style>", "", icerik, flags=re.S)
    return re.sub(r"<script\b.*?</script>", "", icerik, flags=re.S)


def ornek_disi(metin):
    while True:
        m = next((x for x in MARKER.finditer(metin) if x.group(1).strip() == "Örnek durumlar"), None)
        if m is None:
            return metin
        son = metin.find("</section>", m.end())
        metin = metin[:m.start()] + (metin[son + len("</section>"):] if son != -1 else "")


def yuzeyler(metin):
    """[(ad, parça)] — arka-sayfa + her ana/varyant yan-panel ayrı yüzey.
    'sahne'/'örtü' ekli işaretler sarmalayıcıdır, yüzey açmaz."""
    baslar = [(m.start(), "panel:" + ((m.group(2) or "").lower()[:28] or "adsız"))
              for m in MARKER.finditer(metin)
              if m.group(1).strip() == "Yan panel"
              and not any(k in (m.group(2) or "").lower() for k in ("sahne", "örtü"))]
    if not baslar:
        return [("sayfa", metin)]
    parcalar = [("arka-sayfa", metin[:baslar[0][0]])]
    for i, (poz, ad) in enumerate(baslar):
        son = baslar[i + 1][0] if i + 1 < len(baslar) else len(metin)
        parcalar.append((ad, metin[poz:son]))
    return parcalar


def araliklar(metin, etiket):
    return [(m.start(), metin.find("</%s>" % etiket, m.start()))
            for m in re.finditer(r"<%s\b" % etiket, metin)]


def kapsayan(poz, arlar):
    ic = [i for i, (a, b) in enumerate(arlar) if a <= poz <= (b if b != -1 else 10 ** 9)]
    return ic[-1] if ic else None


def gezinme_imzasi(metin):
    for m in MARKER.finditer(metin):
        if m.group(1).strip() == "Gezinme":
            son = MARKER.search(metin, m.end())
            blok = metin[m.end(): son.start() if son else m.end() + 4000]
            kok = re.search(r"<([a-z]+)", blok)
            return (kok.group(1) if kok else "?",
                    tuple(t.strip() for t in re.findall(r"<a\b[^>]*>([^<{}]{2,40})</a>", blok)))
    return None


def rozet_metinleri(ham):
    rozetler = re.findall(r'rozet:\s*"([^"]+)"', ham)
    rozetler += [m.group(1).strip() for m in
                 re.finditer(r'<span[^>]*border-radius:\s*999px[^>]*>([^<{}]{2,40})</span>', ham)]
    return [r for r in rozetler if r]


def ekran_denetle(yol, P):
    ham = open(yol, encoding="utf-8").read()
    metin = govde(ham)
    temiz = ornek_disi(metin)
    ihlaller, notlar = [], []
    renk = re.escape(P["birincil_renk"].lstrip("#"))
    birincil_desen = re.compile(r"background(-color)?:\s*#%s" % renk, re.I)

    for yuzey_ad, parca in yuzeyler(temiz):
        scfor, scif = araliklar(parca, "sc-for"), araliklar(parca, "sc-if")

        buyuk = [(m.start(), m.group(1)) for m in FONT_PX.finditer(parca)
                 if float(m.group(1)) >= P["buyuk_punto_taban"]]
        if len(buyuk) > P["buyuk_sayi_butce"]:
            sablon = sum(1 for poz, _ in buyuk if kapsayan(poz, scfor) is not None)
            ihlaller.append("S1[%s] büyük-sayı: %d adet %gpx+ (bütçe %d)%s" %
                            (yuzey_ad, len(buyuk), P["buyuk_punto_taban"], P["buyuk_sayi_butce"],
                             " · %d'i şablon-içi" % sablon if sablon else ""))

        turler, kosullu = set(), set()
        for m in MARKER.finditer(parca):
            tur = P["blok_turu"].get(m.group(1).strip())
            if tur:
                (turler if kapsayan(m.start(), scif) is None else kosullu).add(tur)
        if len(turler) > P["blok_tur_butce"]:
            ihlaller.append("S2[%s] blok-türü: %d tür (%s) — bütçe %d" %
                            (yuzey_ad, len(turler), "+".join(sorted(turler)), P["blok_tur_butce"]))
        elif len(turler | kosullu) > P["blok_tur_butce"]:
            notlar.append("S2[%s]: koşullu dallarla %d tür (%s) — dışlayıcılık şablon "
                          "değişkenine bağlı, statik kanıtlanamaz (İNSAN-GÖZÜ)" %
                          (yuzey_ad, len(turler | kosullu), "+".join(sorted(turler | kosullu))))

        gruplar = {}
        for m in re.finditer(r"<(a|button)\b[^>]*>", parca):
            if birincil_desen.search(m.group(0)) and "disabled" not in m.group(0):
                gruplar.setdefault(kapsayan(m.start(), scif), []).append(m.start())
        if len(gruplar.get(None, [])) > 1:
            ihlaller.append("S3[%s] birincil eylem: %d KOŞULSUZ adet (tek olmalı)" %
                            (yuzey_ad, len(gruplar[None])))
        for kim, uyeler in gruplar.items():
            if kim is not None and len(uyeler) > 1:
                ihlaller.append("S3[%s] AYNI koşul-dalında %d birincil (aynı anda görünürler)" %
                                (yuzey_ad, len(uyeler)))
        if len(gruplar) > 1:
            notlar.append("S3[%s]: birincil düğmeler %d ayrı görünürlük-bağlamında — "
                          "dışlayıcılık şablonda, statik kanıtlanamaz (İNSAN-GÖZÜ)" %
                          (yuzey_ad, len(gruplar)))

    r_disi = sorted({v for v in RADIUS_PX.findall(metin) if v not in set(P["radius_kumesi"])})
    if r_disi:
        ihlaller.append("S4 köşe-yarıçapı küme-dışı: %spx (izinli: %s)" %
                        (",".join(r_disi), "/".join(P["radius_kumesi"])))
    kademeler = set(P["font_kademeleri"])
    f_disi = sorted({v for v in FONT_PX.findall(metin)
                     if v.rstrip("0").rstrip(".") not in kademeler})
    if f_disi:
        ihlaller.append("S5 font-kademe küme-dışı: %spx (izinli: %s)" %
                        (",".join(f_disi), "/".join(P["font_kademeleri"])))

    adlar = [m.group(1).strip() for m in MARKER.finditer(metin)]
    # "Örnek durumlar" aracın KENDİ protokol adıdır (vitrin muafiyeti onunla çalışır) →
    # projenin sözlüğünde olmasa da sessiz-icat sayılmaz.
    disi = sorted({a for a in adlar if a not in set(P["sozluk"]) | {"Örnek durumlar"}
                   and "bildirilen" not in a.lower()})
    if disi:
        ihlaller.append("X2 sözlük-dışı bileşen adı (sessiz icat): %s" % ", ".join(disi))
    for desen in P["yasak_dil"]:
        es = re.findall(desen, metin, re.I)
        if es:
            ihlaller.append("X3 yasak dil: %r ×%d" % (es[0], len(es)))

    return {"ihlaller": ihlaller, "notlar": notlar,
            "gezinme": gezinme_imzasi(metin), "rozetler": rozet_metinleri(ham)}


def profil_yukle(yol):
    P = json.load(open(yol, encoding="utf-8"))
    eksik = [k for k in ORNEK_PROFIL if not k.startswith("_") and k not in P]
    if eksik:
        raise KeyError("profilde eksik alan: %s" % ", ".join(eksik))
    return P


def main(argv):
    if "--profil-ornek" in argv:
        json.dump(ORNEK_PROFIL, sys.stdout, ensure_ascii=False, indent=1)
        print()
        return 0
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 1:
        print(__doc__.split("KULLANIM")[1].split("PROFİL")[0].strip(), file=sys.stderr)
        return 2
    kok = args[0].rstrip("/")
    pyol = argv[argv.index("--profil") + 1] if "--profil" in argv else \
        os.path.join(os.path.dirname(kok) or ".", "kapi-profili.json")
    if not os.path.isfile(pyol):
        print("RC=2 ÇALIŞTIRILAMADI — kapı profili yok: %s" % pyol, file=sys.stderr)
        print("   üret:  %s --profil-ornek > %s" % (sys.argv[0], pyol), file=sys.stderr)
        print("   sonra profildeki sayıları projenin sözleşmesiyle EŞİTLE.", file=sys.stderr)
        return 2
    try:
        P = profil_yukle(pyol)
    except Exception as e:
        print("RC=2 ÇALIŞTIRILAMADI — profil okunamadı: %s" % e, file=sys.stderr)
        return 2

    dosyalar = sorted(glob.glob(kok + "/*.html"))
    if not dosyalar:
        print("RC=2 ÇALIŞTIRILAMADI — ekran yok: %s/*.html" % kok, file=sys.stderr)
        return 2

    sonuc = {d.rsplit("/", 1)[-1][:-5]: ekran_denetle(d, P) for d in dosyalar}

    if len(dosyalar) > 1:
        sayim = {}
        for s in sonuc.values():
            sayim[s["gezinme"]] = sayim.get(s["gezinme"], 0) + 1
        taban = max(sayim, key=sayim.get)
        for ad, s in sonuc.items():
            if s["gezinme"] is None:
                s["ihlaller"].append("X1 gezinme: Gezinme bileşeni YOK")
            elif sayim[taban] == 1:
                s["notlar"].append("X1: her ekranın gezinmesi FARKLI — küme tutarsız")
            elif s["gezinme"] != taban:
                s["ihlaller"].append("X1 gezinme iskeleti çoğunluktan sapıyor: %s ≠ taban %s"
                                     % (s["gezinme"], taban))

    tum = {}
    for s in sonuc.values():
        for r in s["rozetler"]:
            tum.setdefault(r.casefold(), set()).add(r)
    for anahtar, yazimlar in sorted(tum.items()):
        if len(yazimlar) > 1:
            for s in sonuc.values():
                if any(r.casefold() == anahtar for r in s["rozetler"]):
                    s["ihlaller"].append("X4 durum-yazımı çatallı: %s" % " ⟂ ".join(sorted(yazimlar)))

    print("=" * 72)
    for ad in sorted(sonuc):
        s = sonuc[ad]
        print("%s  %s" % ("❌ KIRMIZI" if s["ihlaller"] else "✅ temiz", ad))
        for i in s["ihlaller"]:
            print("      · %s" % i)
        for n in s["notlar"]:
            print("      ~ %s" % n)
    kirmizi = sum(1 for s in sonuc.values() if s["ihlaller"])
    print("=" * 72)
    print("KÜME: %d ekran · %d kırmızı · profil: %s" % (len(sonuc), kirmizi, pyol))
    print("NOT: bu kapı tek-ekran ANLAMINI ölçmez (manşet, bilgi değeri) — ona hiç bakmadı.")
    return 1 if kirmizi else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
