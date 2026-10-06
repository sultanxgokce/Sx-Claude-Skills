#!/usr/bin/env python3
"""koken.py — DOSYANIN KENDİ BEYANINI okur ve kanıt konumuna girip giremeyeceğine karar verir.

🔴 NİÇİN VAR (ölçüldü 2026-10-05/06): gorsel-yon'un üç kapısı ÜRETİM tarafını koruyor —
   ne isteyeceğimizi süzüyor. Ama HAZIR GELEN dosya bu kapılardan hiç geçmiyordu.
   Canlı vaka: 62 kare başka bir araçla üretilip köprüye düştü ve vitrine gidiyordu;
   üçü de (iki ajan + ben) "bu dosyalarda meta yok, kökü belirsiz" diye ölçmüştü.
   Gerçek: hepsinde üreticinin köken kaydı vardı ve "üretildi" diyordu.
   Yanlış yerde arıyorduk: köken kaydı Exif/tEXt/XMP'de DEĞİL, JUMBF kutusunda
   (PNG'de `caBX`, JPEG'de APP11, WebP'de `C2PA`).

🔴 ASİMETRİ (ölçüldü: tek yeniden-kayıt kutuyu yok ediyor):
   kayıt VAR + trainedAlgorithmicMedia → GÜÇLÜ POZİTİF, kapı keser.
   kayıt YOK → HİÇBİR ŞEY KANITLAMAZ. Gerçek makine karesi de olabilir, bir kez
   düzenleyiciden geçmiş üretilmiş kare de. Bu yüzden değer ASLA 'temiz' ya da
   'gercek' olmaz — 'hic-yok' olur ve anlamı 'bilinmiyor'dur.

🔴 ÖLÇMEDİĞİM ŞEY — İMZA (bağımsız göz tur-1, 2026-10-06):
   Bu okuyucu köken kutusunun VARLIĞINI ve içindeki beyanı okur; C2PA manifestinin
   kriptografik İMZASINI ve sertifika zincirini DOĞRULAMAZ (kutuda `c2patool` ya da
   `c2pa` modülü yok — ölçüldü). Bu yüzden alan adı 'imzali-koken-var' DEĞİL
   'koken-kutusu-var'dır ve her kayıt `imza_dogrulandi: hayir` taşır.
   Sonucu dürüstçe söyle: beyanı kutuya ELLE koymak mümkündür. Hata yönü iki türlüdür —
   (a) "üretilmiş → iddia taşıyan yüzeye giremez" kuralında yanlış-KIRMIZI üretir (temkinli
   taraf, zararsız); (b) ÇELİŞKİ kuralında bir insanı haksız yere yanlış-beyanla suçlayabilir
   (zararlı taraf). Bu yüzden çelişki çıktısı "çözülmeli" der, "yanlış beyan" DEMEZ.

🔴 PARÇA-DIŞI İZ: beyan metni köken kutusunun DIŞINDA bir yerde geçiyorsa bu HÜKÜM DEĞİL,
   kayıttır (`parca_disi_iz`). Eski sürüm bütün dosyada arayıp hüküm veriyordu; gövdeyi
   ayrıştırmadan arama sahte-pozitif üretir (bağımsız göz tur-1).

Çıkış: 0 kapı geçti · 1 RED · 2 kullanım · 3 ÖLÇEMEDİ (okuyucu kör — temiz SAYILMAZ)
"""
import argparse, collections, hashlib, json, os, struct, sys, tempfile

JUMBF_IMI = (b"jumb", b"c2pa")
URETIM = b"trainedAlgorithmicMedia"
KARMA   = b"compositeWithTrainedAlgorithmicMedia"
META_PARCA = {"tEXt", "zTXt", "iTXt", "eXIf", "XMP "}
KOKEN_PARCA = {"caBX"}                      # PNG'de JUMBF taşıyıcısı
KANIT_ALANLARI = {"kanit", "vitrin", "portfolyo", "referans"}   # iddia taşıyan yüzeyler
PNG_BILINEN = {"IHDR","IDAT","IEND","PLTE","tRNS","gAMA","cHRM","sRGB","iCCP","bKGD",
               "pHYs","sBIT","sPLT","hIST","tIME","acTL","fcTL","fdAT"}

# ───────────────────────── biçim ayrıştırıcıları (hepsi gövde döndürür) ─────────────────────────
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

def jpeg_parcalari(ham):
    """JPEG işaretçi zincirini yürür → [(ad, gövde)]. APP11 = JUMBF taşıyıcısı."""
    if ham[:2] != b"\xff\xd8": return None
    i, out = 2, []
    while i + 4 <= len(ham):
        if ham[i] != 0xFF: return out          # zincir bozuk — okunanı döndür
        m = ham[i+1]
        if m == 0xD9: out.append(("EOI", b"")); break
        if m == 0xDA:                           # görüntü verisi başladı
            out.append(("SOS", b"")); break
        n = struct.unpack(">H", ham[i+2:i+4])[0]
        ad = f"APP{m-0xE0}" if 0xE0 <= m <= 0xEF else f"M{m:02X}"
        out.append((ad, ham[i+4:i+2+n]))
        i += 2 + n
    return out

def webp_parcalari(ham):
    """RIFF kutu zinciri → [(fourcc, gövde)]. Köken taşıyıcısı: C2PA."""
    if ham[:4] != b"RIFF" or ham[8:12] != b"WEBP": return None
    i, out = 12, []
    while i + 8 <= len(ham):
        t = ham[i:i+4].decode("latin1", "replace")
        n = struct.unpack("<I", ham[i+4:i+8])[0]
        out.append((t, ham[i+8:i+8+n]))
        i += 8 + n + (n & 1)                    # tek uzunluk dolgu baytı alır
    return out

def oku(yol):
    """→ sözlük. Hüküm YALNIZ köken kutusunun gövdesinden çıkar."""
    with open(yol, "rb") as f: ham = f.read()
    bicim, parcalar, koken_govde, meta_var = None, None, b"", False
    p = png_parcalari(ham)
    if p is not None:
        bicim, parcalar = "png", p
        for t, d in p:
            if t in KOKEN_PARCA: koken_govde += d
            if t in META_PARCA:  meta_var = True
        tanimadik = sorted({t for t, _ in p if t not in (PNG_BILINEN | META_PARCA | KOKEN_PARCA)})
    else:
        j = jpeg_parcalari(ham)
        if j is not None:
            bicim, parcalar = "jpeg", j
            for t, d in j:
                if t == "APP11" and any(im in d for im in JUMBF_IMI): koken_govde += d
                if t in ("APP1", "APP13"):  meta_var = True
            tanimadik = sorted({t for t, _ in j if t.startswith("APP") and t not in
                                ("APP0","APP1","APP2","APP11","APP13","APP14")})
        else:
            w = webp_parcalari(ham)
            if w is not None:
                bicim, parcalar = "webp", w
                for t, d in w:
                    if t == "C2PA": koken_govde += d
                    if t in ("EXIF", "XMP "): meta_var = True
                tanimadik = sorted({t for t, _ in w if t not in
                                    ("VP8 ","VP8L","VP8X","ALPH","ANIM","ANMF","ICCP","EXIF","XMP ")})
            else:
                # 🔴 BİÇİMİ AYRIŞTIRAMADIM — "temiz" demem, "okunamadi" derim (b0110 dersi)
                tanimadik = []
    kaynak_turu = None
    if URETIM in koken_govde:  kaynak_turu = "uretilmis"
    elif KARMA in koken_govde: kaynak_turu = "gercek+iyilestirme"
    # kutu DIŞINDAKİ iz: kayda geçer, hüküm vermez
    disi = (URETIM in ham or KARMA in ham) and (URETIM not in koken_govde and KARMA not in koken_govde)
    if bicim is None:            durum = "okunamadi"
    elif koken_govde:            durum = "koken-kutusu-var"
    elif meta_var:               durum = "meta-var"
    else:                        durum = "hic-yok"
    uretici = None
    if koken_govde:
        for ad in (b"gpt-image", b"firefly", b"midjourney", b"stable-diffusion", b"dall-e", b"imagen"):
            if ad in koken_govde: uretici = ad.decode(); break
    return {"bicim": bicim, "koken_durumu": durum, "kaynak_turu": kaynak_turu,
            "uretici": uretici, "filigran": b"c2pa.watermarked" in koken_govde,
            "imza_dogrulandi": "hayir",          # 🔴 araç yok — iddia edilmez
            "parca_disi_iz": bool(disi), "tanimadik_parca": tanimadik,
            "md5": hashlib.md5(ham).hexdigest()}

# ───────────────────────── pozitif kontrol (okuyucu kör mü) ─────────────────────────
def _png(parcalar):
    out = bytearray(b"\x89PNG\r\n\x1a\n")
    for t, d in parcalar:
        out += struct.pack(">I", len(d)) + t.encode() + d + b"\0\0\0\0"
    return bytes(out)

def _jpeg(segmentler):
    out = bytearray(b"\xff\xd8")
    for m, d in segmentler:
        out += bytes([0xFF, m]) + struct.pack(">H", len(d) + 2) + d
    return bytes(out + b"\xff\xd9")

def _webp(parcalar):
    gov = bytearray(b"WEBP")
    for t, d in parcalar:
        gov += t.encode() + struct.pack("<I", len(d)) + d + (b"\0" if len(d) & 1 else b"")
    return bytes(b"RIFF" + struct.pack("<I", len(gov)) + gov)

def pozitif_kontrol():
    """Okuyucunun KÖR OLMADIĞINI üç biçimde kanıtla + kutu-dışı izi hüküm saymadığını göster.
    Düşerse hüküm YOK (rc=3)."""
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    ornekler = [
        ("png-koken",  _png([("IHDR", ihdr), ("caBX", b"jumbc2pa" + URETIM), ("IDAT", b"x"), ("IEND", b"")])),
        ("png-meta",   _png([("IHDR", ihdr), ("tEXt", b"Deneme\0meta"), ("IDAT", b"x"), ("IEND", b"")])),
        ("png-bos",    _png([("IHDR", ihdr), ("IDAT", b"x"), ("IEND", b"")])),
        ("png-disi",   _png([("IHDR", ihdr), ("tEXt", b"Not\0" + URETIM), ("IDAT", b"x"), ("IEND", b"")])),
        ("jpeg-koken", _jpeg([(0xEB, b"JP\0\0jumbc2pa" + URETIM), (0xE0, b"JFIF\0")])),
        ("webp-koken", _webp([("VP8X", b"\0" * 10), ("C2PA", b"jumbc2pa" + URETIM)])),
    ]
    beklenen = [("koken-kutusu-var", "uretilmis", False), ("meta-var", None, False),
                ("hic-yok", None, False),           ("meta-var", None, True),
                ("koken-kutusu-var", "uretilmis", False), ("koken-kutusu-var", "uretilmis", False)]
    gorulen = []
    for ad, ham in ornekler:
        with tempfile.NamedTemporaryFile(suffix="." + ad.split("-")[0], delete=False) as f:
            f.write(ham); y = f.name
        r = oku(y); os.remove(y)
        gorulen.append((r["koken_durumu"], r["kaynak_turu"], r["parca_disi_iz"]))
    return gorulen == beklenen, list(zip([a for a, _ in ornekler], gorulen))

# ───────────────────────── ana akış ─────────────────────────
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
        print(f"◻ ÖLÇEMEDİM: okuyucu pozitif kontrolü geçemedi (görülen {detay})\n"
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
        r = oku(y); kt, durum = r["kaynak_turu"], r["koken_durumu"]
        kume[r["md5"]].append(y)
        tur = kt or "bilinmiyor"
        tur_kaynagi = "dosyadan" if kt else ("beyandan" if a.beyan else "yok")
        if not kt and a.beyan: tur = a.beyan
        kanit_olabilir = ("HAYIR" if kt == "uretilmis"
                          else "bilinmiyor" if durum in ("hic-yok", "okunamadi") else "evet")
        celisen = a.beyan_sahibi if (kt and a.beyan and a.beyan != kt) else None
        iddia = bool(a.kullanim and a.kullanim in KANIT_ALANLARI)
        if kt == "uretilmis" and iddia:
            red.append((y, f"üretilmiş kare iddia taşıyan yüzeye ({a.kullanim}) giremez"))
        if celisen:
            red.append((y, f"dosya '{kt}' diyor, {celisen} beyanı '{a.beyan}' diyor — çelişki çözülmeden yayın YOK"))
        satirlar.append({"dosya": os.path.basename(y), "tur": tur, "tur_kaynagi": tur_kaynagi,
                         "kanit_olabilir": kanit_olabilir, "celisen_taraf": celisen, **r})
    ikiz_ici = sum(len(v) - 1 for v in kume.values() if len(v) > 1)
    ikiz_arasi = sum(1 for v in kume.values() if len({os.path.dirname(x) for x in v}) > 1)

    if a.json:
        print(json.dumps({"dosya": len(dosyalar), "ayri": len(kume), "ikiz_ici": ikiz_ici,
                          "ikiz_arasi": ikiz_arasi, "red": len(red),
                          "imza_dogrulandi": "hayir", "kayitlar": satirlar},
                         ensure_ascii=False, indent=2))
    else:
        print(f"🔎 KÖKEN ÖLÇÜMÜ · {len(dosyalar)} dosya · {len(kume)} ayrı görüntü"
              f" · ikiz (küme içi {ikiz_ici} · kümeler arası {ikiz_arasi})")
        say = collections.Counter(s["koken_durumu"] for s in satirlar)
        for k, v in say.most_common(): print(f"   {k}: {v}")
        uret = [s for s in satirlar if s["tur"] == "uretilmis"]
        if uret:
            print(f"   🔴 ÜRETİLMİŞ (dosyanın köken kutusundaki beyanı): {len(uret)}"
                  f" · üretici: {uret[0]['uretici'] or 'adsız'} · filigran: {'var' if uret[0]['filigran'] else 'yok'}"
                  "\n      ⚠️ imza DOĞRULANMADI (kutuda c2pa aracı yok) — beyan kutuya elle de konabilir.")
        if say.get("hic-yok"):
            print(f"   ⚠️ {say['hic-yok']} dosyada köken kaydı YOK → bu 'temiz' DEĞİL, 'bilinmiyor'."
                  "\n      Gerçek fotoğraf olarak SUNULAMAZ (kayıt tek yeniden-kayıtta yok olur).")
        if say.get("okunamadi"):
            print(f"   ◻ {say['okunamadi']} dosyanın biçimini ayrıştıramadım → ÖLÇEMEDİM (temiz değil).")
        disi = sum(1 for s in satirlar if s["parca_disi_iz"])
        if disi:
            print(f"   ℹ️ {disi} dosyada beyan metni köken kutusunun DIŞINDA görüldü"
                  " — kayda geçti, HÜKÜM DEĞİL (sahte-pozitif kapısı).")
        tn = sorted({t for s in satirlar for t in s["tanimadik_parca"]})
        if tn: print(f"   ℹ️ tanımadığım parça türü (yok SAYILMADI, kayda geçti): {', '.join(tn)}")
    for y, sebep in red:
        print(f"✗ RED · {os.path.basename(y)} — {sebep}", file=sys.stderr)
    sys.exit(1 if red else 0)

if __name__ == "__main__":
    main()
