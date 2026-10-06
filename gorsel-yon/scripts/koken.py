#!/usr/bin/env python3
"""koken.py — DOSYANIN KENDİ BEYANINI okur ve kanıt konumuna girip giremeyeceğine karar verir.

🔴 NİÇİN VAR (ölçüldü 2026-10-05/06): gorsel-yon'un üç kapısı ÜRETİM tarafını koruyor —
   ne isteyeceğimizi süzüyor. Ama HAZIR GELEN dosya bu kapılardan hiç geçmiyordu.
   Canlı vaka: 62 kare başka bir araçla üretilip köprüye düştü ve vitrine gidiyordu;
   üçü de (iki ajan + ben) "bu dosyalarda meta yok, kökü belirsiz" diye ölçmüştü.
   Gerçek: hepsinde OpenAI'nin imzalı köken kaydı vardı ve "üretildi" diyordu.
   Yanlış yerde arıyorduk: köken kaydı Exif/tEXt/XMP'de DEĞİL, JUMBF kutusunda
   (PNG'de `caBX`, JPEG'de APP11, WebP'de `C2PA`).

🔴 ASİMETRİ (ölçüldü: tek yeniden-kayıt kutuyu yok ediyor):
   kayıt VAR + trainedAlgorithmicMedia → GÜÇLÜ POZİTİF, kapı keser.
   kayıt YOK → HİÇBİR ŞEY KANITLAMAZ. Gerçek makine karesi de olabilir, bir kez
   düzenleyiciden geçmiş üretilmiş kare de. Bu yüzden değer ASLA 'temiz' ya da
   'gercek' olmaz — 'hic-yok' olur ve anlamı 'bilinmiyor'dur.

Çıkış: 0 kapı geçti · 1 RED · 2 kullanım · 3 ÖLÇEMEDİ (okuyucu kör — temiz SAYILMAZ)
"""
import argparse, hashlib, io, json, os, struct, sys, collections

JUMBF_IMI = (b"jumb", b"c2pa")
URETIM = b"trainedAlgorithmicMedia"
KARMA   = b"compositeWithTrainedAlgorithmicMedia"
META_PARCA = {"tEXt", "zTXt", "iTXt", "eXIf", "XMP "}
KOKEN_PARCA = {"caBX"}                      # PNG'de JUMBF taşıyıcısı
KANIT_ALANLARI = {"kanit", "vitrin", "portfolyo", "referans"}   # iddia taşıyan yüzeyler

def png_parcalari(ham):
    if ham[:8] != b"\x89PNG\r\n\x1a\n": return None
    i, out = 8, []
    while i + 8 <= len(ham):
        n, tip = struct.unpack(">I4s", ham[i:i+8])
        t = tip.decode("latin1", "replace")
        out.append((t, ham[i+8:i+8+n]))
        i += 12 + n
        if t == "IEND": break
    return out

def oku(yol):
    """→ (koken_durumu, uretici_beyani, parca_turleri, tanimadik)"""
    with open(yol, "rb") as f: ham = f.read()
    p = png_parcalari(ham)
    turler, koken_govde = [], b""
    if p is not None:
        for t, d in p:
            turler.append(t)
            if t in KOKEN_PARCA: koken_govde += d
    else:
        # JPEG/WebP: biçim ayrıştırmadan JUMBF imi aranır (tek biçime bakan okuyucu "temiz" der)
        if any(im in ham for im in JUMBF_IMI): koken_govde = ham
    kaynak_turu = None
    if URETIM in koken_govde or URETIM in ham: kaynak_turu = "uretilmis"
    elif KARMA in koken_govde or KARMA in ham: kaynak_turu = "gercek+iyilestirme"
    filigran = b"c2pa.watermarked" in ham
    uretici = None
    for ad in (b"gpt-image", b"firefly", b"midjourney", b"stable-diffusion", b"dall-e", b"imagen"):
        if ad in ham: uretici = ad.decode(); break
    if koken_govde or (p is not None and KOKEN_PARCA & set(turler)):
        durum = "imzali-koken-var"
    elif p is not None and META_PARCA & set(turler):
        durum = "meta-var"
    elif p is None and any(im in ham for im in (b"Exif", b"http://ns.adobe.com/xap")):
        durum = "meta-var"
    else:
        durum = "hic-yok"
    # 🔴 TANIMADIĞIN PARÇAYI "YOK" SAYMA — kayda geç (sözlük tuzağı, b0110)
    bilinen = {"IHDR","IDAT","IEND","PLTE","tRNS","gAMA","cHRM","sRGB","iCCP","bKGD",
               "pHYs","sBIT","sPLT","hIST","tIME","acTL","fcTL","fdAT"} | META_PARCA | KOKEN_PARCA
    tanimadik = sorted({t for t in turler if t not in bilinen})
    return durum, kaynak_turu, uretici, filigran, tanimadik, hashlib.md5(ham).hexdigest()

def pozitif_kontrol():
    """Okuyucunun KÖR OLMADIĞINI kanıtla. Düşerse hüküm YOK (rc=3)."""
    def png(parcalar):
        out = bytearray(b"\x89PNG\r\n\x1a\n")
        for t, d in parcalar:
            out += struct.pack(">I", len(d)) + t.encode() + d + b"\0\0\0\0"
        return bytes(out)
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    a = png([("IHDR", ihdr), ("caBX", b"jumbc2pa" + URETIM), ("IDAT", b"x"), ("IEND", b"")])
    b = png([("IHDR", ihdr), ("tEXt", b"Deneme\0meta"), ("IDAT", b"x"), ("IEND", b"")])
    c = png([("IHDR", ihdr), ("IDAT", b"x"), ("IEND", b"")])
    import tempfile
    sonuc = []
    for ham in (a, b, c):
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f: f.write(ham); y = f.name
        sonuc.append(oku(y)[0]); os.remove(y)
    return sonuc == ["imzali-koken-var", "meta-var", "hic-yok"], sonuc

def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("yollar", nargs="+")
    ap.add_argument("--kullanim", help="yayın yüzeyi; kanit|vitrin|portfolyo|referans = iddia taşır")
    ap.add_argument("--beyan", choices=["gercek", "gercek+iyilestirme", "uretilmis"],
                    help="insanın/ajanın beyanı — dosyayla çelişirse kapı keser")
    ap.add_argument("--beyan-sahibi", choices=["insan", "ajan"], default="insan")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    ok, detay = pozitif_kontrol()
    if not ok:
        print(f"◻ ÖLÇEMEDİM: okuyucu pozitif kontrolü geçemedi (beklenen üç hâl, görülen {detay})\n"
              "  Bu TEMİZ DEĞİLDİR — hüküm üretilmedi.", file=sys.stderr)
        sys.exit(3)

    dosyalar = []
    for y in a.yollar:
        if os.path.isdir(y):
            for kok, _, adlar in os.walk(y):
                for ad in sorted(adlar):
                    if ad.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                        dosyalar.append(os.path.join(kok, ad))
        elif os.path.isfile(y): dosyalar.append(y)
    if not dosyalar:
        print("HATA: okunacak görsel bulunamadı", file=sys.stderr); sys.exit(2)

    kume = collections.defaultdict(list)
    satirlar, red = [], []
    for y in dosyalar:
        durum, kt, uretici, filigran, tanimadik, md5 = oku(y)
        kume[md5].append(y)
        tur = kt or "bilinmiyor"
        tur_kaynagi = "dosyadan" if kt else ("beyandan" if a.beyan else "yok")
        if not kt and a.beyan: tur = a.beyan
        kanit_olabilir = "HAYIR" if kt == "uretilmis" else ("bilinmiyor" if durum == "hic-yok" else "evet")
        celisen = None
        if kt and a.beyan and a.beyan != kt:
            celisen = a.beyan_sahibi      # insan beyanı SORULUR, ajan beyanı DÜZELTİLİR (KALFA, b0110)
        iddia = bool(a.kullanim and a.kullanim in KANIT_ALANLARI)
        if kt == "uretilmis" and iddia:
            red.append((y, f"üretilmiş kare iddia taşıyan yüzeye ({a.kullanim}) giremez"))
        if celisen:
            red.append((y, f"dosya '{kt}' diyor, {celisen} beyanı '{a.beyan}' diyor — çelişki çözülmeden yayın YOK"))
        satirlar.append({"dosya": os.path.basename(y), "tur": tur, "tur_kaynagi": tur_kaynagi,
                         "koken_durumu": durum, "kanit_olabilir": kanit_olabilir,
                         "uretici": uretici, "filigran": filigran,
                         "celisen_taraf": celisen, "tanimadik_parca": tanimadik, "md5": md5})
    ikiz_ici = sum(len(v) - 1 for v in kume.values() if len(v) > 1)
    ikiz_arasi = sum(1 for v in kume.values() if len({os.path.dirname(x) for x in v}) > 1)

    if a.json:
        print(json.dumps({"dosya": len(dosyalar), "ayri": len(kume), "ikiz_ici": ikiz_ici,
                          "ikiz_arasi": ikiz_arasi, "red": len(red), "kayitlar": satirlar},
                         ensure_ascii=False, indent=2))
    else:
        print(f"🔎 KÖKEN ÖLÇÜMÜ · {len(dosyalar)} dosya · {len(kume)} ayrı görüntü"
              f" · ikiz (küme içi {ikiz_ici} · kümeler arası {ikiz_arasi})")
        say = collections.Counter(s["koken_durumu"] for s in satirlar)
        for k, v in say.most_common(): print(f"   {k}: {v}")
        uret = [s for s in satirlar if s["tur"] == "uretilmis"]
        if uret:
            print(f"   🔴 ÜRETİLMİŞ (dosyanın kendi imzalı beyanı): {len(uret)}"
                  f" · üretici: {uret[0]['uretici'] or 'adsız'} · filigran: {'var' if uret[0]['filigran'] else 'yok'}")
        if say.get("hic-yok"):
            print(f"   ⚠️ {say['hic-yok']} dosyada köken kaydı YOK → bu 'temiz' DEĞİL, 'bilinmiyor'."
                  "\n      Gerçek fotoğraf olarak SUNULAMAZ (kayıt tek yeniden-kayıtta yok olur).")
        tn = sorted({t for s in satirlar for t in s["tanimadik_parca"]})
        if tn: print(f"   ℹ️ tanımadığım parça türü (yok SAYILMADI, kayda geçti): {', '.join(tn)}")
    for y, sebep in red:
        print(f"✗ RED · {os.path.basename(y)} — {sebep}", file=sys.stderr)
    sys.exit(1 if red else 0)

if __name__ == "__main__":
    main()
