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
    return v is None or (isinstance(v, (str, list, dict)) and len(v) == 0)


def dogrula(d):
    h = []                                  # hatalar
    if not isinstance(d, dict):
        return ["profil bir nesne değil"]
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

    kp = d.get("kapilar")
    if not isinstance(kp, list) or not kp:
        h.append("kapilar: en az bir kapı şart")
    else:
        for i, k in enumerate(kp):
            _kume("kapilar", k, KAPI_ZORUNLU, KAPI_ISTEGE, sira=i)

    ds = d.get("defter_semasi")
    if isinstance(ds, dict):
        al = ds.get("alanlar")
        if not isinstance(al, list) or not al:
            h.append("defter_semasi.alanlar: en az bir alan şart")
        else:
            for i, a in enumerate(al):
                _kume("defter_semasi.alanlar", a, {"ad", "tur"}, {"zorunlu", "aciklama", "not"}, sira=i)
    elif "defter_semasi" in d:
        h.append("defter_semasi bir nesne değil")

    ks = d.get("kurulum_sinavi")
    if isinstance(ks, list):
        for i, a in enumerate(ks):
            _kume("kurulum_sinavi", a, {"adim", "beklenen"}, {"aciklama"}, sira=i)
    return h


def main():
    if len(sys.argv) != 2:
        print("kullanım: profil-dogrula.py <profil.json>", file=sys.stderr); sys.exit(2)
    try:
        d = json.load(open(sys.argv[1], encoding="utf-8"))
    except Exception as e:
        print(f"✗ profil OKUNAMADI: {e}", file=sys.stderr); sys.exit(2)
    h = dogrula(d)
    if h:
        print(f"✗ profil ŞEMA-1'e UYMUYOR — {len(h)} bulgu (kurulum ÜRETİLMEZ):")
        for x in h:
            print(f"  · {x}")
        sys.exit(1)
    nb = d.get("nobetler", [])
    print(f"✓ profil şema-1 geçerli: {d.get('kutu')}/{d.get('profil')} · "
          f"{len(nb)} nöbet · {len(d.get('kapilar', []))} kapı · kapısız nöbet 0")
    sys.exit(0)


if __name__ == "__main__":
    main()
