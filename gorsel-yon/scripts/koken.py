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

🔴 İMZA KAPISI — İKİ KİP, HANGİSİNDE OLDUĞUNU HER ZAMAN SÖYLER (bağımsız göz tur-1/tur-2):
   AÇIK  : `c2pa` kütüphanesi varsa manifest YAPISAL okunur — imza + sertifika zinciri
           doğrulanır (`validation_state`), `digitalSourceType` eylem iddiasının İÇİNDEN
           alınır. Bayt arama DEĞİL.
   KAPALI: kütüphane yoksa (ya da `KOKEN_IMZA=kapali`) kutu-gövdesi okuyucusuna düşer ve
           bunu ÇIKTIDA söyler; `imza_dogrulandi: olculemedi`.
   🔴 Sessiz düşüş YASAK: kip her koşuda basılır (K20/K21 kapıları bunu ölçer).
   Kipin hükme etkisi ASİMETRİKTİR — niçini zarar yönünden:
   - "üretilmiş → iddia taşıyan yüzeye giremez": imza doğrulanmasa da KESER (temkinli taraf).
   - ÇELİŞKİ ("dosya şunu diyor, insan bunu dedi"): YALNIZ imza doğrulanmışsa keser. Doğrulanmamış
     bir beyanla bir insanı yanlış-beyanla suçlamak zararın ağır tarafıdır; o hâlde uyarı basılır.

🔴 PARÇA-DIŞI İZ: beyan metni köken kutusunun DIŞINDA bir yerde geçiyorsa bu HÜKÜM DEĞİL,
   kayıttır (`parca_disi_iz`). Eski sürüm bütün dosyada arayıp hüküm veriyordu; gövdeyi
   ayrıştırmadan arama sahte-pozitif üretir (bağımsız göz tur-1).

Çıkış: 0 kapı geçti · 1 RED · 2 kullanım · 3 ÖLÇEMEDİ (okuyucu kör — temiz SAYILMAZ)
"""
import argparse, collections, hashlib, json, os, struct, sys, tempfile, zlib

try:
    if os.environ.get("KOKEN_IMZA") == "kapali": raise ImportError("elle kapatıldı")
    import c2pa as _c2pa
    IMZA_KIPI = "acik"
except Exception:
    _c2pa, IMZA_KIPI = None, "kapali"

IPTC_SON = {"trainedAlgorithmicMedia": "uretilmis",
            "compositeWithTrainedAlgorithmicMedia": "gercek+iyilestirme",
            "digitalCapture": "gercek"}
BICIM_TURU = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"}

JUMBF_IMI = (b"jumb", b"c2pa")
URETIM = b"trainedAlgorithmicMedia"
KARMA   = b"compositeWithTrainedAlgorithmicMedia"
META_PARCA = {"tEXt", "zTXt", "iTXt", "eXIf", "XMP "}
KOKEN_PARCA = {"caBX"}                      # PNG'de JUMBF taşıyıcısı
KANIT_ALANLARI = {"kanit", "vitrin", "portfolyo", "referans"}   # iddia taşıyan yüzeyler
PNG_BILINEN = {"IHDR","IDAT","IEND","PLTE","tRNS","gAMA","cHRM","sRGB","iCCP","bKGD",
               "pHYs","sBIT","sPLT","hIST","tIME","acTL","fcTL","fdAT"}

# ───────────────────────── biçim ayrıştırıcıları (hepsi gövde döndürür) ─────────────────────────
# 🔴 BOZUK YAPIYI "OKUNABİLİR" SAYMA (bağımsız göz · dar kapı tur-1): zararın yönü yanlış
#    SUÇLAMA olduğu için, kısmi ayrıştırmadan iddia çıkarmak kabul edilemez. Üç ayrıştırıcı da
#    sınır + bütünlük denetler; ihlalde None döner ve dosya `okunamadi` olur ("temiz" değil).
def png_parcalari(ham):
    if ham[:8] != b"\x89PNG\r\n\x1a\n": return None
    i, out, bitti = 8, [], False
    while i + 8 <= len(ham):
        n, tip = struct.unpack(">I4s", ham[i:i+8])
        if i + 12 + n > len(ham): return None            # bildirilen uzunluk dosyayı aşıyor
        govde = ham[i+8:i+8+n]
        beklenen = struct.unpack(">I", ham[i+8+n:i+12+n])[0]
        if zlib.crc32(tip + govde) & 0xFFFFFFFF != beklenen: return None   # CRC tutmuyor
        t = tip.decode("latin1", "replace")
        out.append((t, govde))
        i += 12 + n
        if t == "IEND": bitti = True; break
    if not bitti or i != len(ham): return None           # kesik ya da artık bayt var
    return out

def jpeg_parcalari(ham):
    """JPEG işaretçi zincirini yürür → [(ad, gövde)]. APP11 = JUMBF taşıyıcısı."""
    if ham[:2] != b"\xff\xd8": return None
    i, out, bitti = 2, [], False
    while i + 2 <= len(ham):
        if ham[i] != 0xFF: return None          # zincir bozuk → kısmi okuma İDDİA ÜRETMEZ
        m = ham[i+1]
        if m == 0xD9: out.append(("EOI", b"")); bitti = True; break
        if m == 0xDA:
            # 🔴 SOS'ta "tamamlandı" DEME (bağımsız göz · dar kapı tur-2): entropi akışı
            #    işaretçi zinciri gibi yürünmez, ama dosyanın EOI ile bittiği ÖLÇÜLEBİLİR.
            #    Kesik bir JPEG'den suçlayıcı hüküm çıkmasın.
            if ham[-2:] != b"\xff\xd9": return None
            out.append(("SOS", b"")); bitti = True; break
        if m in (0x01,) or 0xD0 <= m <= 0xD8:   # uzunluk alanı OLMAYAN işaretçiler
            i += 2; continue
        if i + 4 > len(ham): return None         # uzunluk alanı dosyada yok
        n = struct.unpack(">H", ham[i+2:i+4])[0]
        if n < 2 or i + 2 + n > len(ham): return None     # uzunluk alanı tutmuyor
        ad = f"APP{m-0xE0}" if 0xE0 <= m <= 0xEF else f"M{m:02X}"
        out.append((ad, ham[i+4:i+2+n]))
        i += 2 + n
    return out if bitti else None

def webp_parcalari(ham):
    """RIFF kutu zinciri → [(fourcc, gövde)]. Köken taşıyıcısı: C2PA."""
    if ham[:4] != b"RIFF" or ham[8:12] != b"WEBP": return None
    riff = struct.unpack("<I", ham[4:8])[0]
    if riff + 8 != len(ham): return None        # bildirilen RIFF boyu dosya boyuyla tutmuyor
    i, out = 12, []
    while i + 8 <= len(ham):
        t = ham[i:i+4].decode("latin1", "replace")
        n = struct.unpack("<I", ham[i+4:i+8])[0]
        if i + 8 + n > len(ham): return None    # kutu uzunluğu dosyayı aşıyor
        out.append((t, ham[i+8:i+8+n]))
        i += 8 + n + (n & 1)                    # tek uzunluk dolgu baytı alır
    return out if i == len(ham) else None       # artık bayt = bozuk zincir

def imzali_oku(yol):
    """c2pa ile YAPISAL okuma: imza + sertifika zinciri doğrulanır, iddia şemadan alınır.
    → sözlük | None (manifest yok / okunamadı → çağıran kutu-okuyucusuna düşer)."""
    if _c2pa is None: return None
    tur = BICIM_TURU.get(yol.rsplit(".", 1)[-1].lower())
    if not tur: return None
    try:
        with open(yol, "rb") as fh:
            d = json.loads(_c2pa.Reader(tur, fh).json())
    except Exception:
        return None
    am = d.get("active_manifest"); m = (d.get("manifests") or {}).get(am) or {}
    hal = str(d.get("validation_state") or "bilinmiyor")
    kaynak_turu, eylemler = None, []
    for a in m.get("assertions", []) or []:
        et = a.get("label", "")
        veri = a.get("data") or {}
        if et.startswith("c2pa.actions"):
            for ey in veri.get("actions", []) or []:
                eylemler.append(ey.get("action"))
                dst = (ey.get("digitalSourceType") or "").rsplit("/", 1)[-1]
                if dst in IPTC_SON and kaynak_turu is None: kaynak_turu = IPTC_SON[dst]
        elif et.startswith("stds.schema-org.CreativeWork"):
            dst = str(veri.get("digitalSourceType") or "").rsplit("/", 1)[-1]
            if dst in IPTC_SON and kaynak_turu is None: kaynak_turu = IPTC_SON[dst]
    imza = (m.get("signature_info") or {})
    return {"kaynak_turu": kaynak_turu,
            # 🔴 İKİ AYRI ŞEY (bağımsız göz · dar kapı tur-3): imzanın MATEMATİKSEL olarak
            #    tutması (Valid) ile mührün GÜVENİLEN bir kökten gelmesi (Trusted) aynı şey
            #    değildir. Kendi sertifikasını üreten herkes Valid alır. İkisini tek 'evet'e
            #    indirmek, ölçülenden fazlasını beyan etmekti.
            "imza_dogrulandi": ("evet-guven-zinciri" if hal.lower() == "trusted"
                                else "evet-imza-tutuyor" if hal.lower() == "valid"
                                else f"gecersiz:{hal}"),
            "imza_sahibi": imza.get("issuer"), "imza_zamani": imza.get("time"),
            "eylemler": eylemler, "dogrulama_hali": hal}

ANAHTAR = b"digitalSourceType"

AYIRAC = b"\"':= \t\r\n\x00"          # anahtar ile değer arasına girebilen baytlar
TANIMLI = (b"abcdefghijklmnopqrstuvwxyz"
           b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.:/")

def _kutuda_iddia(govde):
    """Köken kutusunda `digitalSourceType` anahtarının DEĞERİNİ ayrıştırır.

    🔴 Niçin pencere-araması değil (bağımsız göz · dar kapı tur-3): "anahtardan sonraki 96
       baytta tanınan bir sözcük geçsin" şartı, anahtarla İLGİSİZ bir alanda geçen diziyi de
       iddia sayıyordu → yanlış suçlama. Artık anahtar-değer bağı fiilen kuruluyor: anahtardan
       sonra YALNIZ ayıraçlar atlanır, sonra gelen TEK belirteç okunur; araya başka bir alan
       girerse (yani belirteç tanınan değerlerden biri değilse) iddia YOK sayılır.
    """
    i = 0
    while True:
        i = govde.find(ANAHTAR, i)
        if i < 0: return None
        j = i + len(ANAHTAR)
        while j < len(govde) and govde[j:j+1] in (AYIRAC[k:k+1] for k in range(len(AYIRAC))):
            j += 1
        k = j
        while k < len(govde) and govde[k:k+1] in (TANIMLI[t:t+1] for t in range(len(TANIMLI))):
            k += 1
        belirtec = govde[j:k].rsplit(b"/", 1)[-1]          # IPTC URL'si de olabilir
        if belirtec == KARMA: return "gercek+iyilestirme"
        if belirtec == URETIM: return "uretilmis"
        if belirtec == b"digitalCapture": return "gercek"
        i = j

# 🔴 BU KAPI YALNIZ SUÇLAR, ASLA BERAAT ETTİRMEZ (kapsam daraltıldı · Sultan kararı 2026-10-06).
#    Niçin: "ben üretilmişim" beyanı dosyayı KISITLAR → temkinli taraf, imzasız da işler.
#    "ben gerçek fotoğrafım" beyanı dosyayı SERBEST BIRAKIR → bunu kabul etmek bir GÜVEN KÖKÜ
#    ister: imzanın matematiksel olarak tutması, mührün KİMDEN geldiğini söylemez. Kendi
#    sertifikasını üreten herkes "gerçeğim" diye imzalayabilir (bağımsız göz tur-4, haklı).
#    Güvenilir-mühür listesi AYRI iştir; o kurulana kadar bu kapı olumlu hüküm VERMEZ:
#    çıktı ya "üretilmiş, iddia yüzeyine giremez" ya "bilinmiyor"dur. ÜÇÜNCÜ hâl yoktur.
OLUMLU_IDDIA = {"gercek"}        # yalnız KAYDA geçer — hüküm üretmez (aşağıda kanit_olabilir)

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
    # 🔴 SIKILAŞTIRMA (bağımsız göz tur-2): kutu gövdesinde serbest geçen bir anahtar sözcük
    #    iddia sayılmaz. Değer, `digitalSourceType` ANAHTARININ hemen ardında (≤96 bayt)
    #    geçmek zorunda — açıklama metnine ya da başka bir iddiaya düşen dizi hüküm vermez.
    kaynak_turu = _kutuda_iddia(koken_govde)
    # kutu DIŞINDAKİ iz: kayda geçer, hüküm vermez
    disi = (URETIM in ham or KARMA in ham) and (URETIM not in koken_govde and KARMA not in koken_govde)
    if bicim is None:            durum = "okunamadi"
    elif koken_govde:            durum = "koken-kutusu-var"
    elif meta_var:               durum = "meta-var"
    elif tanimadik:              durum = "belirsiz-tasiyici"   # 🔴 tanımadığım parça 'yok' SAYILMAZ (tur-2)
    else:                        durum = "hic-yok"
    uretici = None
    if koken_govde:
        for ad in (b"gpt-image", b"firefly", b"midjourney", b"stable-diffusion", b"dall-e", b"imagen"):
            if ad in koken_govde: uretici = ad.decode(); break
    sonuc = {"bicim": bicim, "koken_durumu": durum, "kaynak_turu": kaynak_turu,
             "uretici": uretici, "filigran": b"c2pa.watermarked" in koken_govde,
             "imza_kipi": IMZA_KIPI, "imza_dogrulandi": "olculemedi",
             "imza_sahibi": None, "okuma_yolu": "kutu-govdesi",
             "parca_disi_iz": bool(disi), "tanimadik_parca": tanimadik,
             "md5": hashlib.md5(ham).hexdigest()}
    im = imzali_oku(yol)
    if im is not None:                      # YAPISAL okuma kutu-aramasını EZER
        sonuc.update({"kaynak_turu": im["kaynak_turu"] or kaynak_turu,
                      "imza_dogrulandi": im["imza_dogrulandi"], "imza_sahibi": im["imza_sahibi"],
                      "dogrulama_hali": im["dogrulama_hali"], "eylemler": im["eylemler"],
                      "okuma_yolu": "c2pa-yapisal",
                      "koken_durumu": "koken-kutusu-var" if durum in ("hic-yok", "belirsiz-tasiyici", "meta-var") else durum})
    kt, imza = sonuc["kaynak_turu"], sonuc["imza_dogrulandi"]
    sonuc["dosya_iddiasi"] = kt          # 🔴 ÇELİŞKİ için korunur (tur-2): hükme girmemek,
    if kt in OLUMLU_IDDIA:               #    "görünmez olmak" demek DEĞİL
        # olumlu iddia HÜKME girmez; imzası doğrulanmış olsa bile yalnız kayda geçer
        sonuc["kaynak_turu"] = None
        sonuc["dusurulen_iddia"] = kt
    sonuc["iddia_guveni"] = ("guven-zinciri-dogrulandi" if imza == "evet-guven-zinciri"
                             else "imza-tutuyor-veren-dogrulanmadi" if imza == "evet-imza-tutuyor"
                             else "dogrulanmamis" if sonuc["kaynak_turu"] else "yok")
    return sonuc

# ───────────────────────── pozitif kontrol (okuyucu kör mü) ─────────────────────────
def _png(parcalar):
    out = bytearray(b"\x89PNG\r\n\x1a\n")
    for t, d in parcalar:
        tip = t.encode()
        out += (struct.pack(">I", len(d)) + tip + d
                + struct.pack(">I", zlib.crc32(tip + d) & 0xFFFFFFFF))
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
    iddia = b"jumbc2pa" + ANAHTAR + b'":"http://cv.iptc.org/newscodes/digitalsourcetype/' + URETIM + b'"'
    bagsiz = b"jumbc2pa" + b'"description":"' + URETIM + b'"'   # anahtara BAĞLI DEĞİL → iddia sayılmaz
    ornekler = [
        ("png-koken",  _png([("IHDR", ihdr), ("caBX", iddia), ("IDAT", b"x"), ("IEND", b"")])),
        ("png-meta",   _png([("IHDR", ihdr), ("tEXt", b"Deneme\0meta"), ("IDAT", b"x"), ("IEND", b"")])),
        ("png-bos",    _png([("IHDR", ihdr), ("IDAT", b"x"), ("IEND", b"")])),
        ("png-disi",   _png([("IHDR", ihdr), ("tEXt", b"Not\0" + URETIM), ("IDAT", b"x"), ("IEND", b"")])),
        ("jpeg-koken", _jpeg([(0xEB, b"JP\0\0" + iddia), (0xE0, b"JFIF\0")])),
        ("webp-koken", _webp([("VP8X", b"\0" * 10), ("C2PA", iddia)])),
        ("png-bagsiz", _png([("IHDR", ihdr), ("caBX", bagsiz), ("IDAT", b"x"), ("IEND", b"")])),
        ("png-belirsiz", _png([("IHDR", ihdr), ("zzZZ", b"bilinmeyen"), ("IDAT", b"x"), ("IEND", b"")])),
    ]
    beklenen = [("koken-kutusu-var", "uretilmis", False), ("meta-var", None, False),
                ("hic-yok", None, False),           ("meta-var", None, True),
                ("koken-kutusu-var", "uretilmis", False), ("koken-kutusu-var", "uretilmis", False),
                ("koken-kutusu-var", None, False),  ("belirsiz-tasiyici", None, False)]
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
    satirlar, red, uyari = [], [], []
    for y in dosyalar:
        r = oku(y); kt, durum = r["kaynak_turu"], r["koken_durumu"]
        kume[r["md5"]].append(y)
        tur = kt or "bilinmiyor"
        tur_kaynagi = "dosyadan" if kt else ("beyandan" if a.beyan else "yok")
        if not kt and a.beyan: tur = a.beyan
        # 🔴 'evet' DAMGASI YALNIZ DOĞRULANMIŞ OLUMLU İDDİAYLA (bağımsız göz tur-3):
        #    eski kod "köken kutusu var ama iddia okunamadı" hâline de 'evet' diyordu →
        #    boş/şema-dışı/güvenilmez kutu gerçeklik kanıtına dönüşüyordu (sahte-yeşil).
        # 🔴 KAPALI KÜME: {HAYIR, bilinmiyor}. 'evet' hiçbir yoldan ÜRETİLEMEZ —
        #    beraat için güven kökü gerekir, o da bu kapının işi değil (bkz. başlık).
        kanit_olabilir = "HAYIR" if kt == "uretilmis" else "bilinmiyor"
        # çelişki HÜKÜM-türünden değil DOSYANIN İDDİASINDAN hesaplanır: düşürülmüş olumlu
        # iddia da beyanla çelişebilir ("dosya gerçeğim diyor, insan üretilmiş dedi")
        di = r.get("dosya_iddiasi")
        celisen = a.beyan_sahibi if (di and a.beyan and a.beyan != di) else None
        imza_ok = str(r.get("imza_dogrulandi")).startswith("evet")   # kısıtlayıcı taraf
        iddia = bool(a.kullanim and a.kullanim in KANIT_ALANLARI)
        if kt == "uretilmis" and iddia:
            red.append((y, f"üretilmiş kare iddia taşıyan yüzeye ({a.kullanim}) giremez"
                           f" · iddianın güveni: {r.get('iddia_guveni')}"
                           + ("" if imza_ok else " (imza doğrulanmadı — TEMKİNLİ red)")))
        if celisen and imza_ok:
            red.append((y, f"dosya '{di}' diyor, {celisen} beyanı '{a.beyan}' diyor — çelişki çözülmeden yayın YOK"))
        elif celisen:
            # 🔴 İMZA DOĞRULANMADI → kapı KESMEZ, uyarır. Doğrulanmamış beyanla insanı
            #    yanlış-beyanla suçlamak zararın ağır tarafıdır (tur-1/tur-2 dersi).
            uyari.append((y, f"dosya '{di}' diyor, {celisen} beyanı '{a.beyan}' diyor — AMA imza"
                             f" doğrulanmadı ({r.get('imza_dogrulandi')}); kapı kesmiyor, SORULMALI"))
        satirlar.append({"dosya": os.path.basename(y), "tur": tur, "tur_kaynagi": tur_kaynagi,
                         "kanit_olabilir": kanit_olabilir, "celisen_taraf": celisen, **r})
    ikiz_ici = sum(len(v) - 1 for v in kume.values() if len(v) > 1)
    ikiz_arasi = sum(1 for v in kume.values() if len({os.path.dirname(x) for x in v}) > 1)

    if a.json:
        print(json.dumps({"dosya": len(dosyalar), "ayri": len(kume), "ikiz_ici": ikiz_ici,
                          "ikiz_arasi": ikiz_arasi, "red": len(red),
                          "imza_kipi": IMZA_KIPI, "uyari": len(uyari), "kayitlar": satirlar},
                         ensure_ascii=False, indent=2))
    else:
        print(f"   imza kapısı: {'AÇIK (c2pa yapısal doğrulama)' if IMZA_KIPI == 'acik' else 'KAPALI (kütüphane yok → kutu-gövdesi okuyucusu; imza ÖLÇÜLMEDİ)'}")
        print(f"🔎 KÖKEN ÖLÇÜMÜ · {len(dosyalar)} dosya · {len(kume)} ayrı görüntü"
              f" · ikiz (küme içi {ikiz_ici} · kümeler arası {ikiz_arasi})")
        say = collections.Counter(s["koken_durumu"] for s in satirlar)
        for k, v in say.most_common(): print(f"   {k}: {v}")
        uret = [s for s in satirlar if s["tur"] == "uretilmis"]
        if uret:
            print(f"   🔴 ÜRETİLMİŞ (dosyanın köken kutusundaki beyanı): {len(uret)}"
                  f" · üretici: {uret[0]['uretici'] or 'adsız'} · filigran: {'var' if uret[0]['filigran'] else 'yok'}"
                  + ("\n      ✅ imza + GÜVEN ZİNCİRİ doğrulandı · veren: "
                     + str(uret[0].get("imza_sahibi") or "adsız")
                     if uret[0].get("imza_dogrulandi") == "evet-guven-zinciri" else
                     "\n      ✅ imza matematiksel olarak TUTUYOR · beyan edilen veren: "
                     + str(uret[0].get("imza_sahibi") or "adsız")
                     + "\n      ⚠️ ama GÜVEN ZİNCİRİ doğrulanmadı — veren kimliği beyandır"
                     if uret[0].get("imza_dogrulandi") == "evet-imza-tutuyor" else
                     "\n      ⚠️ imza DOĞRULANMADI (" + str(uret[0].get("imza_dogrulandi"))
                     + ") — beyan kutuya elle de konabilir."))
        if say.get("hic-yok"):
            print(f"   ⚠️ {say['hic-yok']} dosyada köken kaydı YOK → bu 'temiz' DEĞİL, 'bilinmiyor'."
                  "\n      Gerçek fotoğraf olarak SUNULAMAZ (kayıt tek yeniden-kayıtta yok olur).")
        if say.get("okunamadi"):
            print(f"   ◻ {say['okunamadi']} dosyanın biçimini ayrıştıramadım → ÖLÇEMEDİM (temiz değil).")
        dus = [s for s in satirlar if s.get("dusurulen_iddia")]
        if dus:
            print(f"   ℹ️ {len(dus)} dosya 'gerçek fotoğraf' iddiası taşıyor → KAYDA geçti, HÜKÜM OLMADI."
                  "\n      Bu kapı yalnız suçlar, beraat ettirmez: beraat için mührün KİMDEN geldiğini"
                  "\n      ölçen bir güven kökü gerekir ve o ayrı iştir.")
        disi = sum(1 for s in satirlar if s["parca_disi_iz"])
        if disi:
            print(f"   ℹ️ {disi} dosyada beyan metni köken kutusunun DIŞINDA görüldü"
                  " — kayda geçti, HÜKÜM DEĞİL (sahte-pozitif kapısı).")
        tn = sorted({t for s in satirlar for t in s["tanimadik_parca"]})
        if tn: print(f"   ℹ️ tanımadığım parça türü (yok SAYILMADI, kayda geçti): {', '.join(tn)}")
    for y, sebep in uyari:
        print(f"⚠️ UYARI · {os.path.basename(y)} — {sebep}", file=sys.stderr)
    for y, sebep in red:
        print(f"✗ RED · {os.path.basename(y)} — {sebep}", file=sys.stderr)
    sys.exit(1 if red else 0)

if __name__ == "__main__":
    main()
