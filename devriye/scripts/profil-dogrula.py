#!/usr/bin/env python3
"""profil-dogrula.py — DEVRİYE şema-1 profil doğrulayıcısı (iskeletin ilk parçası).

NİÇİN VAR: profili yazan taraf "şemaya uydum, boş alan 0, kapısız nöbet 0" diyor.
  Bu bir İDDİADIR; iskelet onu ölçmeden kurulum yapmaz. Üç kural (MUAVİN→MÜTEVELLİ şeması):
    1. Bilinmeyen alan = RED. Sessizce atlanan alan, ölçülmediği hâlde "temiz" görünen alandır.
    2. Zorunlu alan boşsa kurulum ÜRETİLMEZ. Boş yol / boş komut = kurulduğu anda yeşil
       görünüp hiçbir şey yapmayan nöbet — bu filoda ölçülmüş en pahalı hata sınıfı.
    3. Her nöbetin bir KAPISI olmak zorunda. Sonucu kimsenin ölçmediği nöbet, nöbet değil
       gürültüdür; "kırmızı yanarsa ne demek" sorusunun cevabı profilde yazılı olacak.

Çıkış: 0 geçerli · 1 profil kuralı ihlali · 2 kullanım/okuma hatası
Hiçbir şey YAZMAZ, hiçbir komut KOŞMAZ — salt okur.
"""
import json
import sys

UST_ZORUNLU = {"sema", "profil", "kutu", "etiket", "bayrak", "yollar", "hat",
               "nobetler", "kapilar", "defter_semasi", "karne_alanlari",
               "kurulum_sinavi", "damga_olcutu"}
UST_ISTEGE = {"surum", "aciklama"}
YOL_ZORUNLU = {"repo_kok", "kosu_kok", "kanit_kok", "defter_kok", "hub"}
HAT_ZORUNLU = {"canli", "defter_port"}
NOBET_ZORUNLU = {"ad", "ne_zaman", "komut", "kapi", "kirmizi_ne_demek"}
NOBET_ISTEGE = {"zorunlu", "aciklama"}
KAPI_ZORUNLU = {"ad", "komut", "kirmizi_ne_demek"}
KAPI_ISTEGE = {"aciklama"}


def _bos(v):
    """🔴 YALNIZCA-BOŞLUK DA BOŞTUR (bağımsız göz tur 1). İlk yazımda `len(v)==0` bakıyordum;
    `" "` dolu sayılıyordu. Daha kötüsü: bunu sınavımın yorumunda *"boş DEĞİL ama anlamsız,
    _bos görmez, bu kasıtlı"* diye YAZMIŞTIM — açığı onarmak yerine BELGELEMİŞİM. Belgelemek
    onarmak değildir; aynı dersi bugün bir kez daha almak zorunda kaldım."""
    if v is None:
        return True
    if isinstance(v, str):
        return v.strip() == ""
    return isinstance(v, (list, dict)) and len(v) == 0


def dogrula(d):
    """(hatalar, uyarılar) döndürür. Uyarı rc'yi değiştirmez ama SUSULMAZ."""
    h = []                                  # hatalar
    if not isinstance(d, dict):
        return ["profil bir nesne değil"], []
    if d.get("sema") != 1:
        h.append(f"sema 1 olmalı, gelen: {d.get('sema')!r}")

    fazla = set(d) - UST_ZORUNLU - UST_ISTEGE
    if fazla:
        h.append(f"BİLİNMEYEN üst alan(lar): {sorted(fazla)} — şemada yok, sessizce atlanmaz")
    for a in sorted(UST_ZORUNLU - set(d)):
        h.append(f"zorunlu üst alan EKSİK: {a}")
    for a in sorted(UST_ZORUNLU & set(d)):
        if _bos(d[a]):
            h.append(f"zorunlu alan BOŞ: {a}")

    def _kume(ad, gelen, zorunlu, istege=frozenset(), sira=None):
        yer = f"{ad}[{sira}]" if sira is not None else ad
        if not isinstance(gelen, dict):
            h.append(f"{yer} bir nesne değil"); return
        fz = set(gelen) - zorunlu - istege
        if fz:
            h.append(f"{yer}: BİLİNMEYEN alan(lar) {sorted(fz)}")
        for a in sorted(zorunlu - set(gelen)):
            h.append(f"{yer}: zorunlu alan EKSİK: {a}")
        for a in sorted(zorunlu & set(gelen)):
            if _bos(gelen[a]):
                h.append(f"{yer}: zorunlu alan BOŞ: {a}")

    if "yollar" in d:
        _kume("yollar", d["yollar"], YOL_ZORUNLU)
    if "hat" in d:
        _kume("hat", d["hat"], HAT_ZORUNLU)

    bagli, serbest = [], []
    nb = d.get("nobetler")
    if not isinstance(nb, list) or not nb:
        h.append("nobetler: en az bir nöbet şart (boş liste = kurulacak hiçbir şey yok)")
    else:
        adlar = []
        for i, n in enumerate(nb):
            _kume("nobetler", n, NOBET_ZORUNLU, NOBET_ISTEGE, sira=i)
            if isinstance(n, dict):
                adlar.append(n.get("ad"))
                # 3. kural ayrıca ve AÇIKÇA: kapısız nöbet, nöbet değildir.
                if _bos(n.get("kapi")):
                    h.append(f"nobetler[{i}] ({n.get('ad')!r}): KAPISIZ — sonucu ölçülmeyen "
                             f"nöbet gürültüdür")
                if "zorunlu" in n and not isinstance(n["zorunlu"], bool):
                    h.append(f"nobetler[{i}]: 'zorunlu' evet/hayır olmalı")
        tekrar = {a for a in adlar if adlar.count(a) > 1 and a is not None}
        if tekrar:
            h.append(f"nobetler: AYNI AD birden çok nöbette: {sorted(tekrar)} — "
                     f"hangisinin düştüğü ayırt edilemez")
        # 🔴 DOLU OLMAK YETMEZ, KARŞILIĞI OLMALI (bağımsız göz tur 1): `kapi` alanı yalnız
        #    boş mu diye bakılıyordu; uydurma ama dolu bir kapı adı geçiyordu. Var olmayan
        #    bir kapıya bağlı nöbet, kapısız nöbetin kılık değiştirmiş hâlidir.
        # 🔴 TÜR DENETİMİ KULLANIMDAN ÖNCE (bağımsız göz tur 2): `kapilar` liste değilse
        #    (ör. 5) bu küme kurulurken TypeError atıyordu — yani şema ihlali, DENETİMSİZ
        #    BİR ÇÖKMEYE dönüşüyordu. Bir doğrulayıcının çökmesi, "hayır" demesinden kötüdür:
        #    çağıran taraf bunu "araç bozuk" sanır, "profil bozuk" değil.
        _kp = d.get("kapilar")
        kapi_adlari = {k.get("ad") for k in _kp if isinstance(k, dict)} if isinstance(_kp, list) else set()
        for i, n in enumerate(nb):
            if not isinstance(n, dict):
                continue
            ka = n.get("kapi")
            if _bos(ka) or not isinstance(ka, str):
                continue                      # zaten yukarıda KAPISIZ diye yakalandı
            if ka in kapi_adlari:
                bagli.append(n.get("ad"))
            else:
                serbest.append(n.get("ad"))   # RED DEĞİL — gerekçesi aşağıda

    kp = d.get("kapilar")
    if "kapilar" in d and not isinstance(kp, list):
        h.append("kapilar bir liste değil")
    elif not isinstance(kp, list) or not kp:
        h.append("kapilar: en az bir kapı şart")
    else:
        for i, k in enumerate(kp):
            _kume("kapilar", k, KAPI_ZORUNLU, KAPI_ISTEGE, sira=i)

    # 🔴 "Bilinmeyen alan RED" kuralı ŞEMANIN HER KATINDA geçerli (bağımsız göz tur 1):
    #    ilk yazımda yalnız üst düzeyde ve nöbet/kapı içinde uyguluyordum; defter şemasının
    #    KENDİ anahtarları denetlenmiyordu, oraya eklenen uydurma bir alan sessizce geçiyordu.
    #    Bir kuralı bazı katlarda uygulamak, o kuralı olmayan katlarda YOK saymaktır.
    ds = d.get("defter_semasi")
    if "defter_semasi" in d:
        if isinstance(ds, dict):
            _kume("defter_semasi", ds, {"alanlar"}, {"aciklama"})
            al = ds.get("alanlar")
            if not isinstance(al, list) or not al:
                h.append("defter_semasi.alanlar: en az bir alan şart")
            else:
                for i, a in enumerate(al):
                    _kume("defter_semasi.alanlar", a, {"ad", "tur"}, {"zorunlu", "aciklama", "not"}, sira=i)
        else:
            h.append("defter_semasi bir nesne değil")

    # 🔴 YANLIŞ TÜR SESSİZCE GEÇMEZ: `isinstance(...)` doğruysa incele, DEĞİLSE söyle.
    #    Eksik `else` dalı, "denetlenmedi"yi "temiz" diye göstermenin en sessiz biçimidir.
    ks = d.get("kurulum_sinavi")
    if "kurulum_sinavi" in d:
        if isinstance(ks, list):
            for i, a in enumerate(ks):
                _kume("kurulum_sinavi", a, {"adim", "beklenen"}, {"aciklama"}, sira=i)
        else:
            h.append("kurulum_sinavi bir liste değil")
    if "karne_alanlari" in d and not isinstance(d["karne_alanlari"], list):
        h.append("karne_alanlari bir liste değil")
    for a in ("profil", "kutu", "etiket", "bayrak", "damga_olcutu"):
        if a in d and not isinstance(d[a], str):
            h.append(f"{a} metin olmalı")

    # 🔴 KAPI BAĞI: adlı mı, serbest tarif mi — RED DEĞİL, çünkü ŞEMAYI BEN EKSİK YAZDIM.
    #    Bağımsız göz haklı olarak "dolu olmak yetmez, karşılığı olmalı" dedi; doğru.
    #    AMA şemada `kapi` alanının `kapilar` listesinden bir AD olması gerektiğini HİÇ
    #    yazmamıştım — profili yazan taraf yazdığım şemaya uydu. Teslimden SONRA sözleşmeyi
    #    sıkılaştırıp onun işini reddetmek, kuralı sonradan koyup geçmişi suçlamak olurdu;
    #    bugün tam bunun bedelini imza-sürüm işinde ölçtük.
    #    Bu yüzden: iki biçim de geçerli, ama hangisinin hangisi olduğu SÖYLENİR.
    #    Adlı bağ güçlüdür (kapının komutu ve "kırmızı ne demek"i profilde ayrıca yazılı);
    #    serbest tarif zayıftır (kapı bir metindir, koşulabilir bir şey değildir).
    uy = []
    if serbest:
        uy.append(f"{len(serbest)} nöbetin kapısı SERBEST TARİF (adlı kapıya bağlı değil): "
                  f"{serbest} — geçerli ama zayıf bağ; 'kapilar' listesindeki bir ADA bağlamak "
                  f"kapıyı koşulabilir kılar")
    return h, uy


def main():
    if len(sys.argv) != 2:
        print("kullanım: profil-dogrula.py <profil.json>", file=sys.stderr); sys.exit(2)
    try:
        d = json.load(open(sys.argv[1], encoding="utf-8"))
    except Exception as e:
        print(f"✗ profil OKUNAMADI: {e}", file=sys.stderr); sys.exit(2)
    # 🔴 GENEL KALKAN: tek tek tür denetimi eklemek bu sınıfı bitirmez — bir sonraki
    #    beklenmedik girdi yine çökertebilir. Doğrulayıcı HİÇBİR girdide çökmemeli:
    #    çökme, "profil bozuk" hükmünü "araç bozuk" gibi gösterir. Beklenmedik hata
    #    ayrı bir sınıftır (rc=2 · ölçemedim), ihlal (rc=1) DEĞİL.
    try:
        h, uy = dogrula(d)
    except Exception as e:
        print(f"✗ doğrulayıcı BEKLENMEDİK hata verdi: {type(e).__name__}: {e}", file=sys.stderr)
        print("  Bu bir profil hükmü DEĞİL — ölçemedim. Araçta açık var, bildir.", file=sys.stderr)
        sys.exit(2)
    for x in uy:
        print(f"⚠ {x}")
    if h:
        print(f"✗ profil ŞEMA-1'e UYMUYOR — {len(h)} bulgu (kurulum ÜRETİLMEZ):")
        for x in h:
            print(f"  · {x}")
        sys.exit(1)
    nb = d.get("nobetler", [])
    print(f"✓ profil şema-1 geçerli: {d.get('kutu')}/{d.get('profil')} · "
          f"{len(nb)} nöbet · {len(d.get('kapilar', []))} kapı · kapısız nöbet 0"
          + (f" · ⚠ {len(uy)} uyarı" if uy else ""))
    sys.exit(0)


if __name__ == "__main__":
    main()
