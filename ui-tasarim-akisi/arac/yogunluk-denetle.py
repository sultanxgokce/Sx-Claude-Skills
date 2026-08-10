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

SÖZLÜK = ÇEKİRDEK ∪ PROFİL (L57/F1): kabul edilen bileşen adları filo çekirdeğinin Ç3
listesi ile projenin marka profilindeki `sozluk` listesinin BİRLEŞİMİDİR. Niçin: çekirdek
prompta kendiliğinden giriyor (prompt-yap.sh) ama kapı yalnız profile bakıyordu → kurala
harfi harfine uyan ekran "sessiz icat" suçlaması yiyordu (yanlış-KIRMIZI). Çekirdek adları
ikinci bir ayrıştırıcıyla değil, bekçinin KENDİ `cekirdek_adlari()` fonksiyonuyla okunur —
iki ayrıştırıcı iki gerçek demektir.
  🔴 Karşılaştırma TAM eşleşmedir; casefold YOK. Ölçüldü (2026-08-07): casefold üç iddiayı
  birden kırar — yüzey ayrımı `== "Yan panel"` tam eşlemesine dayanır, kasa gevşerse
  `Yan Panel` de panel sayılır, bütçeler ayrışır, `panel-kirmizi` fikstürü yeşile döner.

ÇIKIŞ: 0 temiz · 1 en az bir ihlal · 2 çalıştırılamadı (profil/çekirdek/dosya yok)

ÖLÇÜM-DÜRÜSTLÜĞÜ (kalibrasyonda üç yanlış-pozitif sınıfı yakalanıp kapatıldı):
  • "Örnek durumlar" vitrini bütçe sayımlarının DIŞINDA — sözleşme o bölümü zaten
    "gerçek sanılmasın" diye işaretletir; gerçek saymak ölçüm hatasıdır. Küme-kuralları
    (renk/punto kümesi, sözlük, yasak dil) vitrin DAHİL koşar: drift orada da drift.
  • Yüzey modeli: arka-sayfa ⟂ her yan-panel örneği ayrı yüzey; bütçe yüzey başına.
  • Koşul-farkındalığı: birbirini dışlayan şablon dallarındaki (sc-if) öğeler bütçeye
    sert sayılmaz; AYNI daldaki çift yine serttir, farklı dallar İNSAN-GÖZÜ notu olur.
"""
import glob, importlib.util, json, os, re, sys

BURASI = os.path.dirname(os.path.abspath(__file__))
BEKCI_YOLU = os.path.join(BURASI, "cekirdek-sozluk-denetle.py")
VARSAYILAN_CEKIRDEK = os.path.join(BURASI, "..", "cekirdek", "sozlesme.md")

# ROL ADLARI (L57/F4 · G4): araç üç bileşen adını KODA GÖMÜLÜ ve harf-duyarlı tanıyordu
# ("Yan panel" yüzey açar · "Gezinme" iskelet imzası · "Örnek durumlar" vitrin muafiyeti).
# Hiçbir profilden gelmiyor, hiçbir bekçi ölçmüyordu → adlandırması farklı bir kutu (ölçülen
# vaka: HUZUR'un `NavCubugu`/`SayfaBasligi` yazımı) kendi profilini yazsa bile X1 ve
# yüzey-ayrıştırma kırık kalıyordu. Artık profil `rol_adlari` ile bunları yeniden bağlayabilir.
# İSTEĞE BAĞLI alandır — vermeyen eski profiller aynen çalışır (varsayılan = çekirdek yazımı).
ROL_VARSAYILAN = {"panel": "Yan panel", "gezinme": "Gezinme", "vitrin": "Örnek durumlar"}
ISTEGE_BAGLI = {"rol_adlari"}

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
    # İSTEĞE BAĞLI (bkz ROL_VARSAYILAN): kutunun kendi yazımı farklıysa buradan bağlanır.
    "rol_adlari": dict(ROL_VARSAYILAN),
}

MARKER = re.compile(r"<!--\s*bilesen:\s*([^->]+?)\s*(?:—\s*([^->]*?)\s*)?-->")
FONT_PX = re.compile(r"font-size:\s*([0-9.]+)px")
RADIUS_PX = re.compile(r"border-radius:\s*([0-9]+)px")


def punto_norm(x):
    """`14.0` ile `14`ü aynı sayar — AMA tam sayıya DOKUNMAZ.

    NİÇİN (L57-EK · NAKKAŞ ölçtü 2026-08-07): eski hâli `x.rstrip("0").rstrip(".")` idi;
    kesirli sıfırı kırpmak için konmuştu ama tam sayının sonundaki sıfırı da yiyordu →
    `20→2` · `10→1` · `100→1`. Sonu sıfırla biten HER punto küme-dışı sanılıp SAHTE-KIRMIZI
    veriyordu. 172 sınav görmedi çünkü fikstür profillerinin hepsi 12.5/14.5/16.5/21/25 —
    hiçbiri sıfırla bitmiyor. HUZUR'un ölçeği (12/14/16/20) ilk tetikleyen: 5 ekranda 5 sahte
    ihlal, göçürme bloke. Kırpma artık YALNIZ kesirli değerde çalışır ve karşılaştırmanın
    İKİ YANINA da uygulanır (tek yana uygulamak asimetriyi sürdürürdü).
    """
    return x.rstrip("0").rstrip(".") if "." in x else x


def cekirdek_adlari_yukle(yol=None):
    """Çekirdek Ç3 adları — BEKÇİNİN kendi ayrıştırıcısıyla (ikinci ayrıştırıcı YAZILMAZ).

    Hata yutulmaz: sözleşme okunamıyorsa çağıran RC=2 döndürür. Sessizce "profil-yalnız"a
    düşmek, kapıyı fark ettirmeden eski yanlış-KIRMIZI davranışına geri sokardı."""
    spec = importlib.util.spec_from_file_location("_cekirdek_sozluk_denetle", BEKCI_YOLU)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return set(mod.cekirdek_adlari(yol or VARSAYILAN_CEKIRDEK))


def sozluk_kumesi(P):
    """Kabul edilen bileşen adları = çekirdek ∪ profil (TAM eşleşme, casefold YOK)."""
    return set(P["sozluk"]) | set(P.get("_cekirdek", ()))


def rol(P, anahtar):
    """Koda gömülü bileşen adı yerine profilden türetilmiş rol adı (F4/G4)."""
    return dict(ROL_VARSAYILAN, **(P.get("rol_adlari") or {}))[anahtar]


def govde(icerik):
    """<style>/<script> ölçüm dışı (medya-kuralları + veri); ölçülen inline stildir."""
    icerik = re.sub(r"<style\b.*?</style>", "", icerik, flags=re.S)
    return re.sub(r"<script\b.*?</script>", "", icerik, flags=re.S)


def ornek_disi(metin, vitrin_ad=ROL_VARSAYILAN["vitrin"]):
    while True:
        m = next((x for x in MARKER.finditer(metin) if x.group(1).strip() == vitrin_ad), None)
        if m is None:
            return metin
        son = metin.find("</section>", m.end())
        metin = metin[:m.start()] + (metin[son + len("</section>"):] if son != -1 else "")


def yuzeyler(metin, panel_ad=ROL_VARSAYILAN["panel"]):
    """[(ad, parça)] — arka-sayfa + her ana/varyant yan-panel ayrı yüzey.
    'sahne'/'örtü' ekli işaretler sarmalayıcıdır, yüzey açmaz."""
    baslar = [(m.start(), "panel:" + ((m.group(2) or "").lower()[:28] or "adsız"))
              for m in MARKER.finditer(metin)
              if m.group(1).strip() == panel_ad
              and not any(k in (m.group(2) or "").lower() for k in ("sahne", "örtü"))]
    if not baslar:
        return [("sayfa", metin)]
    parcalar = [("arka-sayfa", metin[:baslar[0][0]])]
    for i, (poz, ad) in enumerate(baslar):
        son = baslar[i + 1][0] if i + 1 < len(baslar) else len(metin)
        parcalar.append((ad, metin[poz:son]))
    return parcalar


def araliklar(metin, etiket):
    """Etiket aralıkları — İÇ-İÇE geçmiş etiketleri yığınla doğru eşler.

    ESKİ DAVRANIŞ (hatalıydı): her açılış için `find("</etiket>")` ile İLK kapanış
    alınıyordu. İç-içe `<sc-if>`te DIŞ aralık, İÇ etiketin kapanışında bitmiş sayılıyor —
    iç bloğun bittiği yerle dış bloğun bittiği yer arasındaki öğeler "koşulsuz" görünüp
    bütçeye yazılıyordu. Sonuç: sahte-kırmızı, ve kanonik prompt-yap.sh --onceki yolunda
    devam promptu hiç üretilemiyordu (huzur, 2026-08-10: üretim hattı durdu).

    Kapanmamış etiket eski davranışı korur: bitiş -1 (= dosya sonuna kadar).
    """
    olaylar = sorted(
        [(m.start(), 1) for m in re.finditer(r"<%s\b" % etiket, metin)]
        + [(m.start(), -1) for m in re.finditer(r"</%s>" % etiket, metin)])
    yigin, cift = [], []
    for poz, tip in olaylar:
        if tip == 1:
            yigin.append(poz)
        elif yigin:
            cift.append((yigin.pop(), poz))
    cift += [(poz, -1) for poz in yigin]          # kapanmamış → açık uçlu
    return sorted(cift)


def kapsayan(poz, arlar):
    ic = [i for i, (a, b) in enumerate(arlar) if a <= poz <= (b if b != -1 else 10 ** 9)]
    return ic[-1] if ic else None


def gezinme_imzasi(metin, gezinme_ad=ROL_VARSAYILAN["gezinme"]):
    for m in MARKER.finditer(metin):
        if m.group(1).strip() == gezinme_ad:
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
    temiz = ornek_disi(metin, rol(P, "vitrin"))
    ihlaller, notlar = [], []
    blok_eslesme = 0          # F4/G5: S2 hattı bu ekranda hiç ateşlendi mi (sahte-yeşil izi)
    renk = re.escape(P["birincil_renk"].lstrip("#"))
    birincil_desen = re.compile(r"background(-color)?:\s*#%s" % renk, re.I)

    for yuzey_ad, parca in yuzeyler(temiz, rol(P, "panel")):
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
                blok_eslesme += 1
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
    kademeler = {punto_norm(k) for k in P["font_kademeleri"]}
    f_disi = sorted({v for v in FONT_PX.findall(metin)
                     if punto_norm(v) not in kademeler})
    if f_disi:
        ihlaller.append("S5 font-kademe küme-dışı: %spx (izinli: %s)" %
                        (",".join(f_disi), "/".join(P["font_kademeleri"])))

    adlar = [m.group(1).strip() for m in MARKER.finditer(metin)]
    # Kabul kümesi = ÇEKİRDEK ∪ PROFİL (F1) + aracın KENDİ vitrin protokol adı (o ad
    # projenin sözlüğünde olmasa da sessiz-icat sayılmaz — vitrin muafiyeti onunla çalışır).
    disi = sorted({a for a in adlar if a not in sozluk_kumesi(P) | {rol(P, "vitrin")}
                   and "bildirilen" not in a.lower()})
    if disi:
        ihlaller.append("X2 sözlük-dışı bileşen adı (sessiz icat): %s" % ", ".join(disi))
    for desen in P["yasak_dil"]:
        es = re.findall(desen, metin, re.I)
        if es:
            ihlaller.append("X3 yasak dil: %r ×%d" % (es[0], len(es)))

    return {"ihlaller": ihlaller, "notlar": notlar, "blok_eslesme": blok_eslesme,
            "isaret": len(adlar),
            "gezinme": gezinme_imzasi(metin, rol(P, "gezinme")),
            "rozetler": rozet_metinleri(ham)}


def profil_yukle(yol):
    P = json.load(open(yol, encoding="utf-8"))
    eksik = [k for k in ORNEK_PROFIL
             if not k.startswith("_") and k not in ISTEGE_BAGLI and k not in P]
    if eksik:
        raise KeyError("profilde eksik alan: %s" % ", ".join(eksik))
    bilinmeyen = [k for k in (P.get("rol_adlari") or {}) if k not in ROL_VARSAYILAN]
    if bilinmeyen:
        raise KeyError("rol_adlari'nda bilinmeyen rol: %s (izinli: %s)"
                       % (", ".join(sorted(bilinmeyen)), ", ".join(sorted(ROL_VARSAYILAN))))
    return P


def profil_tutarlilik(P):
    """F4/G5 — SAHTE-YEŞİL PANZEHİRİ (profil düzeyi).

    `blok_turu` haritasının anahtarı sözlükte yoksa o anahtar HİÇBİR işareti tutamaz;
    S2 (blok-türü bütçesi) hattı sessizce hiç ateşlenmez ve kapı 'temiz' der. Eski kod
    `if tur:` ile sessizce atlıyordu → ölçülmemiş bütçe 'geçti' gibi görünüyordu.
    Bu bir yapılandırma hatasıdır, ihlal değil: kapı RC=2 ile ÖLÇEMEDİĞİNİ söyler."""
    kume = sozluk_kumesi(P)
    oksuz = sorted(k for k in P["blok_turu"] if k not in kume)
    if oksuz:
        raise KeyError("blok_turu anahtarı sözlükte (çekirdek ∪ profil) YOK: %s — "
                       "bu anahtar hiçbir işareti tutamaz, S2 bütçesi sessizce ölçülmez "
                       "(sahte-yeşil)" % ", ".join(oksuz))


DEGERLI_BAYRAKLAR = ("--profil", "--cekirdek")


def bayrak_ayikla(argv):
    """(konumsal-argümanlar, {bayrak: değer}) — F3/G6 onarımı.

    Eski kod `[a for a in argv if not a.startswith('--')]` diyordu: bayrağı eliyor ama
    DEĞERİNİ elemiyordu → `--profil <yol>` verilince yol da konumsal sayılıyor, sayı 2
    oluyor, ilan edilmiş bayrak RC=2 ile ölü yol hâline geliyordu. Hem `--bayrak deger`
    hem `--bayrak=deger` biçimi kabul edilir; değeri eksik bayrak sessizce yutulmaz."""
    konum, deger, i = [], {}, 0
    while i < len(argv):
        a = argv[i]
        if a in DEGERLI_BAYRAKLAR:
            if i + 1 >= len(argv):
                raise ValueError("%s bayrağının değeri eksik" % a)
            deger[a] = argv[i + 1]
            i += 2
            continue
        eslesen = next((b for b in DEGERLI_BAYRAKLAR if a.startswith(b + "=")), None)
        if eslesen:
            deger[eslesen] = a.split("=", 1)[1]
            i += 1
            continue
        if not a.startswith("--"):
            konum.append(a)
        i += 1
    return konum, deger


def main(argv):
    if "--profil-ornek" in argv:
        json.dump(ORNEK_PROFIL, sys.stdout, ensure_ascii=False, indent=1)
        print()
        return 0
    try:
        args, bayrak = bayrak_ayikla(argv)
    except ValueError as e:
        print("RC=2 ÇALIŞTIRILAMADI — %s" % e, file=sys.stderr)
        return 2
    if len(args) != 1:
        print(__doc__.split("KULLANIM")[1].split("PROFİL")[0].strip(), file=sys.stderr)
        return 2
    kok = args[0].rstrip("/")
    pyol = bayrak.get("--profil") or \
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

    cyol = bayrak.get("--cekirdek") or os.environ.get("UI_AKIS_CEKIRDEK") or VARSAYILAN_CEKIRDEK
    try:
        P["_cekirdek"] = cekirdek_adlari_yukle(cyol)
    except Exception as e:
        print("RC=2 ÇALIŞTIRILAMADI — çekirdek sözleşme okunamadı: %s: %s"
              % (type(e).__name__, e), file=sys.stderr)
        print("   kapı sözlüğü ÇEKİRDEK ∪ PROFİL'dir; çekirdek okunamazsa ölçüm yapılmaz "
              "(profil-yalnız'a sessizce düşmek eski yanlış-KIRMIZI'yı geri getirirdi).",
              file=sys.stderr)
        return 2
    try:
        profil_tutarlilik(P)
    except Exception as e:
        print("RC=2 ÇALIŞTIRILAMADI — profil kendiyle tutarsız: %s" % e, file=sys.stderr)
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
                s["ihlaller"].append("X1 gezinme: %s bileşeni YOK" % rol(P, "gezinme"))
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
    # F4/G5 — küme düzeyi sahte-yeşil izi: profilde blok_turu haritası VAR, ekranlarda
    # işaret VAR, ama tek bir eşleşme bile olmadı → S2 bütçesi bu kümede hiç ölçülmedi.
    # (Anahtarlar sözlükteyse profil_tutarlilik susar; asıl kayma ekran adlandırmasındadır.)
    if P["blok_turu"] and sum(s["isaret"] for s in sonuc.values()) \
            and not sum(s["blok_eslesme"] for s in sonuc.values()):
        print("⚠️  UYARI: blok_turu haritası bu kümede HİÇ tutmadı (%s) — S2 blok-türü "
              "bütçesi ölçülmedi; 'temiz' bu boyutu KAPSAMIYOR (sahte-yeşil riski)."
              % ", ".join(sorted(P["blok_turu"])), file=sys.stderr)
    print("KÜME: %d ekran · %d kırmızı · profil: %s" % (len(sonuc), kirmizi, pyol))
    print("NOT: bu kapı tek-ekran ANLAMINI ölçmez (manşet, bilgi değeri) — ona hiç bakmadı.")
    return 1 if kirmizi else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
