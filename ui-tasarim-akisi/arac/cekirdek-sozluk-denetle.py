#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""cekirdek-sozluk-denetle.py — çekirdek sözleşme ⟂ araç sözlüğü hizası bekçisi.

NİÇİN VAR (canlı vaka, 2026-08-07 · AKAR/MÜTEVELLİ + NAKKAŞ)
    Çekirdek sözleşme Ç3'te bileşen adları Başlık Düzeni'nde yazılıydı (`Yan Panel`),
    araç ise cümle düzeni bekliyordu (`Yan panel`). Aynı ad, iki yazım, iki gerçek.
    Sonuç: çekirdeği harfi harfine uygulayan kutu (a) X2 "sözlük-dışı ad / sessiz icat"
    suçlaması yedi, (b) paneli ayrı yüzey saymadığı için gövde+panel bütçeleri birleşti
    → YANLIŞ KIRMIZI. Bütçesi bol bir sayfada aynı kaymanın tersi (yanlış YEŞİL) de
    mümkündü — yani hata sınıfı iki yönlüydü.

    Bu bekçi tek vakayı değil SINIFI kapatır: çekirdekte yazılı her bileşen adı, aracın
    varsayılan profilindeki `sozluk` listesinde HARFİ HARFİNE bulunmalıdır. İki dosya
    ayrı gerçekler taşıyamaz.

NİÇİN harf-duyarsız karşılaştırma DEĞİL
    `casefold` ile eşlemek harf farkını meşrulaştırır; o zaman `Yan Panel` ile `Yan panel`
    ikisi de "doğru" olur ve X4'ün ("aynı şeyin iki yazımı = çatal") felsefesi çöker.
    Kural tek yazım olmalı. Bu yüzden karşılaştırma TAM eşleşmedir.

KAPSAM (dürüstlük)
    Yalnız aracın VARSAYILAN profili (ORNEK_PROFIL) ölçülür — proje profilleri değil.
    Bir ürün çekirdeğin on adının hepsini kullanmak zorunda değildir (Ç3: "işi bu adlardan
    birine uyuyorsa o ad kullanılır"); ama aracın kendi varsayılanı çekirdeği KAPSAMALIDIR,
    yoksa çekirdeğe uyan kutu araç tarafından reddedilir.

KULLANIM
    cekirdek-sozluk-denetle.py [--sozlesme <yol>] [--arac <yol>]

ÇIKIŞ: 0 hizalı · 1 sapma var (eksik/yazımı farklı ad) · 2 çalıştırılamadı (dosya/parse)
"""
import importlib.util, os, re, sys

BURASI = os.path.dirname(os.path.abspath(__file__))
VARSAYILAN_SOZLESME = os.path.join(BURASI, "..", "cekirdek", "sozlesme.md")
VARSAYILAN_ARAC = os.path.join(BURASI, "yogunluk-denetle.py")

# Ç3 gövdesindeki adlar backtick içinde, `·` ile ayrılmış satır(lar)da yaşar.
BASLIK = re.compile(r"^##\s*Ç3\b", re.M)
SONRAKI_BASLIK = re.compile(r"^##\s", re.M)
AD = re.compile(r"`([^`\n]+)`")


def cekirdek_adlari(yol):
    """cekirdek/sozlesme.md Ç3 bölümündeki bileşen adlarını makine-okunur çıkarır."""
    with open(yol, encoding="utf-8") as f:
        metin = f.read()
    b = BASLIK.search(metin)
    if not b:
        raise ValueError("Ç3 bölümü bulunamadı: %s" % yol)
    kalan = metin[b.end():]
    s = SONRAKI_BASLIK.search(kalan)
    bolum = kalan[: s.start()] if s else kalan
    # Adlar yalnız `·` ile ayrılmış listelerde; açıklama paragrafındaki tek-tek
    # backtick'ler (örnek/karşı-örnek) sözleşme LİSTESİ değildir → yalnız `·` taşıyan
    # satır kümesi okunur.
    adlar, blok = [], []
    for satir in bolum.splitlines():
        if satir.lstrip().startswith(">"):      # alıntı bloğu = açıklama, liste değil
            continue
        if "·" in satir and AD.search(satir):
            blok.append(satir)
    for satir in blok:
        adlar += [a.strip() for a in AD.findall(satir)]
    if not adlar:
        raise ValueError("Ç3 bölümünde bileşen adı listesi yok: %s" % yol)
    return adlar


def arac_sozlugu(yol):
    """yogunluk-denetle.py'nin VARSAYILAN profilindeki sozluk listesi."""
    spec = importlib.util.spec_from_file_location("_yogunluk_denetle", yol)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return list(mod.ORNEK_PROFIL["sozluk"])


def main(argv):
    def al(ad, vars_):
        return argv[argv.index("--" + ad) + 1] if "--" + ad in argv else vars_

    syol = al("sozlesme", VARSAYILAN_SOZLESME)
    ayol = al("arac", VARSAYILAN_ARAC)
    try:
        adlar = cekirdek_adlari(syol)
        sozluk = arac_sozlugu(ayol)
    except Exception as e:
        sys.stderr.write("RC=2 ÇALIŞTIRILAMADI — %s: %s\n" % (type(e).__name__, e))
        return 2

    kume = set(sozluk)
    eksik = [a for a in adlar if a not in kume]
    print("çekirdek Ç3: %d ad · araç varsayılan sözlüğü: %d ad" % (len(adlar), len(sozluk)))
    if not eksik:
        print("✅ hizalı — çekirdeğin her adı aracın sözlüğünde (tam eşleşme)")
        return 0

    print("❌ KIRMIZI — çekirdekteki ad aracın sözlüğünde YOK (iki ayrı gerçek):")
    kasa = {a.casefold(): a for a in sozluk}
    for a in eksik:
        yakin = kasa.get(a.casefold())
        if yakin:
            print("   · %r ⟂ araçta %r — YALNIZ HARF KASASI farklı; bu yanlış-kırmızı üretir"
                  % (a, yakin))
        else:
            print("   · %r — araç sözlüğünde karşılığı hiç yok" % a)
    print("Düzeltme: tek yazım seçilir; çekirdek metni ile ORNEK_PROFIL['sozluk'] eşitlenir.")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
