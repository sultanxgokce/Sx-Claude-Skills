#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""havuz.py — tasarım havuzu: ölçüm sonuçlarının merkezde biriktiği yer.

NİÇİN VAR
    Bir tasarım turunda öğrenilen şey bugüne kadar hiçbir yere düşmüyordu: kapı kırmızı
    yanıyor, düzeltiliyor, sonraki tur aynı hatayı yeniden keşfediyordu. Havuz o kaybı
    kapatır — hangi kutu, hangi ekran, hangi kapı, ne düştü.

ŞEMA KAPALIDIR — SERBEST METİN ALANI YOKTUR (bu bir güvenlik kararıdır)
    Havuz dosyası 13 kutunun ORTAK gördüğü bir dizindedir; izole bir kutu başkasının
    satırlarını okuyabilir. Bu yüzden şemada içerik taşıyacak hiçbir alan YOKTUR:
    alıntı yok, HTML yok, gerekçe metni yok, kişi/müşteri adı yok. Yalnız KOD ve SAYI.
    Bilinmeyen anahtar, uzun değer ya da desene uymayan değer → satır REDDEDİLİR
    (fail-closed). "Şuraya bir not düşeyim" diye alan eklenmez; eklenirse mahremiyet
    sınırı sessizce delinir.

SALT-EKLEME + İPTAL (satır silinmez, yanlış satır düzeltilebilir)
    Havuz append-only'dir; bir satır YAZILDIKTAN sonra değiştirilemez/silinemez. Ama
    ölçmeden tahminle yazılmış bir satır özeti sonsuza dek kirletiyordu (canlı vaka:
    MÜTEVELLİ 4 satırı tahminle yazdı, 2'si yanlış çıktı; özet "S1 4 · S2 4" derken
    gerçek dağılım başkaydı). Çözüm silmek değil, ÜSTÜNE YAZMAK: `iptal` komutu yeni
    bir MEZAR-TAŞI satırı ekler; eski satır dosyada aynen kalır (geçmiş korunur), ama
    `ozet` ve `oku` varsayılan görünümde ikisini de dışarıda bırakır.
    Sebep KAPALI KÜMEDİR (serbest metin YOK — mahremiyet sınırı).

KULLANIM
    havuz.py yaz   --kutu akar --urun akar --ekran e4-bugun --kapi yogunluk \
                   --hukum kirmizi --dusen S2,X1 [--tur 3] [--arac 0.1.5] \
                   [--profil-sha 9f2a1c0b7d34]
    havuz.py oku   [--kutu akar] [--son 20] [--iptaller-dahil]
    havuz.py ozet  [--kutu akar]        # NAKKAŞ'ın okuduğu görünüm
    havuz.py iptal <kayit-id> --sebep olcmeden-yazildi
                   # kayıt-id'leri `oku` çıktısının ilk sütununda

    Havuz yolu: --havuz, yoksa $UI_AKIS_HAVUZ, yoksa ~/.claude/tasarim-havuz.jsonl

ÇIKIŞ: 0 tamam · 1 geçersiz kayıt (yazılmadı) · 2 çalıştırılamadı
       3 ÖLÇÜLEMEDİ — havuzda hiç kayıt yok ("temiz" DEĞİL, "hiç bakılmamış")
"""
import hashlib, json, os, re, sys, datetime

ANAHTARLAR = {
    "ts":     r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$",
    "kutu":   r"^[a-z0-9][a-z0-9-]{0,23}$",
    "urun":   r"^[a-z0-9][a-z0-9-]{0,23}$",
    "ekran":  r"^[a-z0-9][a-z0-9._-]{0,39}$",
    "kapi":   r"^(yogunluk|yargi|tik)$",
    "hukum":  r"^(temiz|kirmizi|olcemedi|emin-degilim)$",
    "arac":   r"^[0-9]+\.[0-9]+\.[0-9]+$",
}
ZORUNLU = set(ANAHTARLAR) | {"dusen", "tur"}
DUSEN_DESENI = r"^[A-ZÇĞİÖŞÜ]{1,2}[0-9]{1,2}$"

# ── İSTEĞE BAĞLI ALANLAR — hepsi SKALAR ve KAPALI KÜME/desen. Serbest metin YOK.
#    profil_sha: hangi kapı-profiline karşı ölçüldüğü (12 hane sha256 ön-eki).
#      NİÇİN: aynı ekran iki farklı profille iki farklı hüküm alır; havuza bakan
#      hangisinin geçerli olduğunu bilemiyordu ("ölçüm doğru, referans yanlış" vakası).
#      Desen `rubrik_sha` (yargi-birlestir.py) ile aynı: içerik değil PARMAK İZİ.
#    iptal + sebep: mezar-taşı satırı; ikisi BİRLİKTE gelir (fail-closed).
SECIMLI = {
    "profil_sha": r"^[0-9a-f]{12}$",
    "iptal":      r"^[0-9a-f]{12}$",
    "sebep":      r"^(olcmeden-yazildi|yanlis-profil|tekrar|test-artigi)$",
}
SEBEPLER = ("olcmeden-yazildi", "yanlis-profil", "tekrar", "test-artigi")


def havuz_yolu(argv):
    if "--havuz" in argv:
        return argv[argv.index("--havuz") + 1]
    if os.environ.get("UI_AKIS_HAVUZ"):
        return os.environ["UI_AKIS_HAVUZ"]
    return os.path.join(os.path.expanduser("~"), ".claude", "tasarim-havuz.jsonl")


def kayit_id(kayit):
    """Satırın 12-hane kimliği — TÜRETİLİR, saklanmaz.

    Niçin türetilmiş: mevcut havuz satırlarında `id` alanı yok; şemaya zorunlu alan
    eklemek bugün diskte duran kayıtları geçersiz kılar ve sessizce düşürürdü.
    Kimlik, satırın kanonik JSON'unun sha256 ön-ekidir → aynı satır her yerde aynı id.
    Mezar-taşı alanları kimliğe girmez (bir iptal kaydının kimliği hedefini gölgelemez).
    """
    cekirdek = {a: kayit[a] for a in sorted(kayit) if a not in SECIMLI}
    ham = json.dumps(cekirdek, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(ham.encode("utf-8")).hexdigest()[:12]


def dogrula(kayit):
    """Kapalı şema denetimi. Dönen liste boşsa kayıt geçerlidir."""
    hata = []
    fazla = set(kayit) - ZORUNLU - set(SECIMLI)
    if fazla:
        hata.append("şemada olmayan anahtar: %s (serbest metin alanı YOK)"
                    % ", ".join(sorted(fazla)))
    for a in sorted(ZORUNLU - set(kayit)):
        hata.append("eksik anahtar: %s" % a)
    if ("iptal" in kayit) != ("sebep" in kayit):
        hata.append("iptal ve sebep BİRLİKTE gelir (mezar-taşı yarım olamaz)")
    for a, desen in SECIMLI.items():
        if a in kayit and (not isinstance(kayit[a], str) or not re.match(desen, kayit[a])):
            hata.append("%s desene uymuyor: %r (beklenen: %s)" % (a, str(kayit[a])[:40], desen))
    for a, desen in ANAHTARLAR.items():
        if a not in kayit:
            continue
        d = kayit[a]
        if not isinstance(d, str):
            hata.append("%s metin olmalı" % a); continue
        if not re.match(desen, d):
            hata.append("%s desene uymuyor: %r (beklenen: %s)" % (a, d[:40], desen))
    if "tur" in kayit:
        if not isinstance(kayit["tur"], int) or not (0 <= kayit["tur"] <= 999):
            hata.append("tur 0-999 arası tam sayı olmalı")
    if "dusen" in kayit:
        d = kayit["dusen"]
        if not isinstance(d, list) or len(d) > 40:
            hata.append("dusen en çok 40 elemanlı liste olmalı")
        else:
            for k in d:
                if not isinstance(k, str) or not re.match(DUSEN_DESENI, k):
                    hata.append("dusen yalnız KOD alır (ör. S2, M4, X1) — gelen: %r" % (k,))
    return hata


def yaz(argv, yol):
    def al(ad, varsayilan=None):
        return argv[argv.index("--" + ad) + 1] if "--" + ad in argv else varsayilan

    dusen = [p.strip() for p in (al("dusen") or "").split(",") if p.strip()]
    kayit = {
        "ts":    al("ts") or datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "kutu":  al("kutu") or "",
        "urun":  al("urun") or "",
        "ekran": al("ekran") or "",
        "kapi":  al("kapi") or "",
        "hukum": al("hukum") or "",
        "arac":  al("arac") or "0.0.0",
        "tur":   int(al("tur") or 0),
        "dusen": dusen,
    }
    if al("profil-sha"):
        kayit["profil_sha"] = al("profil-sha")
    hata = dogrula(kayit)
    if hata:
        sys.stderr.write("HAVUZ REDDETTİ — kayıt yazılmadı:\n")
        for h in hata:
            sys.stderr.write("  · %s\n" % h)
        return 1
    try:
        os.makedirs(os.path.dirname(yol) or ".", exist_ok=True)
        with open(yol, "a", encoding="utf-8") as f:
            f.write(json.dumps(kayit, ensure_ascii=False, sort_keys=True) + "\n")
    except OSError as e:
        sys.stderr.write("HAVUZA YAZILAMADI: %s\n" % e)
        return 2
    print("havuz +1 · %s · %s/%s %s=%s%s" % (kayit_id(kayit), kayit["kutu"], kayit["ekran"],
          kayit["kapi"], kayit["hukum"], (" düşen:" + ",".join(dusen)) if dusen else ""))
    return 0


def iptal(argv, yol):
    """Salt-ekleme korunur: eski satıra DOKUNULMAZ, üstüne mezar-taşı satırı yazılır."""
    # Konumsal argümanı ayıkla: değer alan bayrakların DEĞERİ konumsal sanılmamalı
    # (yoksa `--havuz <yol>` yolu kayıt-id zannedilir).
    degerli = {"--havuz", "--sebep"}
    hedefler, atla = [], False
    for a in argv[2:]:
        if atla:
            atla = False
            continue
        if a.startswith("--"):
            atla = a in degerli
            continue
        hedefler.append(a)
    sebep = argv[argv.index("--sebep") + 1] if "--sebep" in argv else ""
    if len(hedefler) != 1:
        sys.stderr.write("kullanım: havuz.py iptal <kayit-id> --sebep %s\n"
                         % "|".join(SEBEPLER))
        return 2
    if sebep not in SEBEPLER:
        sys.stderr.write("geçersiz --sebep: %r\n  kapalı küme (serbest metin YOK): %s\n"
                         % (sebep, ", ".join(SEBEPLER)))
        return 1
    hedef_id = hedefler[0]
    kayitlar = satirlar(yol)
    hedef = next((k for k in kayitlar if kayit_id(k) == hedef_id and "iptal" not in k), None)
    if hedef is None:
        sys.stderr.write("kayıt bulunamadı: %s (havuz: %s)\n" % (hedef_id, yol))
        sys.stderr.write("  kimlikleri gör: havuz.py oku --havuz %s\n" % yol)
        return 1
    if any(k.get("iptal") == hedef_id for k in kayitlar):
        print("zaten iptal edilmiş: %s (yeni mezar-taşı yazılmadı)" % hedef_id)
        return 0
    tas = {a: hedef[a] for a in ZORUNLU}
    tas["ts"] = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    tas["dusen"] = []                       # mezar-taşı kural DÜŞÜRMEZ, sayaca girmez
    tas["iptal"] = hedef_id
    tas["sebep"] = sebep
    hata = dogrula(tas)
    if hata:
        sys.stderr.write("İPTAL YAZILAMADI — mezar-taşı şemaya uymadı:\n")
        for h in hata:
            sys.stderr.write("  · %s\n" % h)
        return 1
    try:
        with open(yol, "a", encoding="utf-8") as f:
            f.write(json.dumps(tas, ensure_ascii=False, sort_keys=True) + "\n")
    except OSError as e:
        sys.stderr.write("HAVUZA YAZILAMADI: %s\n" % e)
        return 2
    print("iptal edildi · %s (%s/%s %s) · sebep=%s" %
          (hedef_id, hedef["kutu"], hedef["ekran"], hedef["kapi"], sebep))
    print("Eski satır dosyada DURUYOR (salt-ekleme); özet ve okuma görünümünden düştü.")
    return 0


def satirlar(yol):
    if not os.path.isfile(yol):
        return []
    cikan = []
    with open(yol, encoding="utf-8") as f:
        for ham in f:
            ham = ham.strip()
            if not ham:
                continue
            try:
                k = json.loads(ham)
            except ValueError:
                continue
            if not dogrula(k):          # bozuk/şema-dışı satır okumada da sayılmaz
                cikan.append(k)
    return cikan


def gecerli(kayitlar):
    """Yürürlükteki kayıtlar: mezar-taşları ve iptal ettikleri satırlar DIŞARIDA.

    Dosyadan hiçbir şey silinmez — bu yalnız GÖRÜNÜM. Geçmiş `oku --iptaller-dahil`
    ile görünür.
    """
    olen = {k["iptal"] for k in kayitlar if "iptal" in k}
    return [k for k in kayitlar if "iptal" not in k and kayit_id(k) not in olen]


def oku(argv, yol):
    ham = satirlar(yol)
    dahil = "--iptaller-dahil" in argv
    kayitlar = ham if dahil else gecerli(ham)
    kutu = argv[argv.index("--kutu") + 1] if "--kutu" in argv else None
    if kutu:
        kayitlar = [k for k in kayitlar if k["kutu"] == kutu]
    son = int(argv[argv.index("--son") + 1]) if "--son" in argv else 20
    olen = {k["iptal"] for k in ham if "iptal" in k}
    for k in kayitlar[-son:]:
        if "iptal" in k:
            im = "⌫ iptal→%s (%s)" % (k["iptal"], k["sebep"])
        elif kayit_id(k) in olen:
            im = "✗ İPTAL EDİLDİ"
        else:
            im = ",".join(k["dusen"])
        print("%s  %s  %-6s %-16s %-8s %-12s %s" % (kayit_id(k), k["ts"], k["kutu"],
              k["ekran"], k["kapi"], k["hukum"], im))
    kapali = len(ham) - len(gecerli(ham))
    print("— %d kayıt (havuz: %s)%s" % (len(kayitlar), yol,
          "" if dahil else (" · %d satır iptal görünümü dışında "
                            "(--iptaller-dahil ile görünür)" % kapali if kapali else "")))
    return 0


def ozet(argv, yol):
    """NAKKAŞ'ın görünümü: hangi kural en çok düşüyor, hangi kutu ne durumda."""
    ham = satirlar(yol)
    kayitlar = gecerli(ham)
    kutu = argv[argv.index("--kutu") + 1] if "--kutu" in argv else None
    if kutu:
        kayitlar = [k for k in kayitlar if k["kutu"] == kutu]
    if not kayitlar:
        # RC=3 ÖLÇÜLEMEDİ. Metin zaten dürüsttü ("hiç bakılmamış") ama çıkış kodu 0
        # diyordu — bir çağıran için 0 "temiz" demektir. Kod da metinle aynı şeyi
        # söylemeli, yoksa makine yalan duyar. (Bulan: NAKKAŞ, 2026-08-07.)
        print("Havuz boş — ölçüm yapılmamış ya da havuz yolu yanlış: %s" % yol)
        print("Bu 'her şey temiz' DEĞİL, 'hiç bakılmamış' demektir.")
        if ham:
            print("(dosyada %d satır var ama hepsi iptal edilmiş / süzgeç dışında)" % len(ham))
        return 3
    sayac, kutular, hukumler = {}, {}, {}
    for k in kayitlar:
        for d in k["dusen"]:
            sayac[d] = sayac.get(d, 0) + 1
        kutular[k["kutu"]] = kutular.get(k["kutu"], 0) + 1
        hukumler[k["hukum"]] = hukumler.get(k["hukum"], 0) + 1
    kapali = len(ham) - len(gecerli(ham))
    print("TASARIM HAVUZU · %d ölçüm · %d kutu%s" % (len(kayitlar), len(kutular),
          (" · %d satır iptal edilmiş (sayıma girmedi)" % kapali) if kapali else ""))
    sha_yok = sum(1 for k in kayitlar if "profil_sha" not in k)
    if sha_yok:
        print("profil: %d/%d ölçümde profil parmak-izi YOK — hangi referansa göre "
              "ölçüldüğü bilinmiyor" % (sha_yok, len(kayitlar)))
    print("hüküm: " + " · ".join("%s=%d" % (h, n) for h, n in sorted(hukumler.items())))
    print("kutu:  " + " · ".join("%s=%d" % (h, n) for h, n in sorted(kutular.items())))
    if sayac:
        print("\nEN ÇOK DÜŞEN KURALLAR (kural mı zor, tasarım mı zayıf — NAKKAŞ'ın sorusu):")
        for kod, n in sorted(sayac.items(), key=lambda x: (-x[1], x[0]))[:10]:
            print("  %-4s %d" % (kod, n))
    else:
        print("\nHiçbir kural düşmemiş.")
    return 0


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        sys.stderr.write(__doc__); return 2
    yol = havuz_yolu(argv)
    komut = argv[1]
    if komut == "yaz":
        return yaz(argv, yol)
    if komut == "oku":
        return oku(argv, yol)
    if komut == "ozet":
        return ozet(argv, yol)
    if komut == "iptal":
        return iptal(argv, yol)
    sys.stderr.write("bilinmeyen komut: %s (yaz|oku|ozet|iptal)\n" % komut)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
