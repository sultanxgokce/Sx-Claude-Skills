#!/usr/bin/env python3
"""izin — BAŞLAMA İZNİ / VETO penceresi (0.21.0 · Sultan D1 22 Eki 2026). Tek gerçek: kart.sh izin-durum, canli_borc.py,
denetci.sh ve birlestirme-kapisi.sh (kart.sh izin-durum üstünden) ve gun-sonu.sh buradan okur; kural metni adimlar/0-kabul.md'de yaşar.

NİÇİN (Sultan, 22 Eki 2026, session_01Ge4BawKcUrcm1pdV8WANyF): "sadece ara kararlar değil birleştirme kararları da reise geçsin
  çünkü ciddi sorun yaşıyoruz çok iş takılıyor". Ölçüm: bağımsız gözden geçen işler ayda 1.138 saat bekledi; 22 Eki'de sorulan
  12 kararın 12'sinde Sultan ajan önerisini seçti. Sınıflı işte Sultan artık YALNIZ başlama iznini verir; izin bir VETO
  PENCERESİDİR: iş bekletilmez, Sultan "dur" derse kapı kapanır ve reis durur. Dağıtım / canlıya alma Sultan eli olarak KALIR.

DURUMLAR (izin_durumu(k) → (ad, açıklama)):
  gerekmiyor  sınıfsız iş — başlama izni gerekmez
  bekliyor    sınıflı iş, Sultan henüz bir şey demedi — veto YOK, iş reis kararlarıyla yürür (eski kart da buraya düşer)
  basla       Sultan "başla" dedi (kart.sh sultan-dedi --karar basla) — karta işli
  dur         Sultan "dur" dedi (VETO) — reis kararı / daralt / canlı borç / denetim / birleştirme kapalı; kaldırmak Sultan'ın (basla)
  olculemedi  kartta baslama_izni alanı var ama bozuk — çağıran fail-closed davranır (kart.sh izin-durum rc 3, borç geçersiz)
Son basla/dur KAZANIR: dur = veto, sonraki basla vetoyu kaldırır. Eski kart (alan yok): sultan_kararlari'ndaki son basla/dur
kaydından türetilir; o da yoksa "bekliyor · eski kart (kural 0.17) · veto yok". Serbest-metin eski kararlar YOK SAYILIR, bozuk sayılmaz.
SINIFSIZ kartta baslama_izni alanı OLMAZ: kart.sh sultan-dedi basla|dur'u sınıfsız kartta rc 1 ile reddeder (göz 23 Eki — eski araç
yazıyor, "kapı kapalı" diyordu, hiçbir kapı okumuyordu). Elle yazılmış alan YOK SAYILIR ve açıklamada söylenir; her yüzey "gerekmiyor" okur.
"""

KURAL_SURUMU = "0.21.0"
DURUMLAR = ("gerekmiyor", "bekliyor", "basla", "dur")


def siniflimi(k):
    return bool(k.get("sultan") or k.get("siniflar"))


def _ref(x):
    """Sultan kaydının izlenebilir künyesi (oturum · söz) — A06: söz üretilmez, aktarılır."""
    o = str(x.get("oturum") or "?"); s = str(x.get("soz") or "?")
    return "oturum %s · söz \"%s\"" % (o, s[:60])


def izin_durumu(k):
    """→ (durum, açıklama). Kartı okuyan her yüzey (kapı · denetçi · gün sonu · borç) BU fonksiyondan geçer."""
    if not siniflimi(k):
        ek = " · ⚠ kartta baslama_izni alanı var ama kart SINIFSIZ — araç yazmaz (sultan-dedi reddeder), alan YOK SAYILDI" if k.get("baslama_izni") is not None else ""
        return ("gerekmiyor", "sınıfsız iş — başlama izni gerekmez, ekipte biter" + ek)
    bi = k.get("baslama_izni")
    if bi is not None:
        if not isinstance(bi, dict) or bi.get("durum") not in ("bekliyor", "basla", "dur"):
            return ("olculemedi", "kartın baslama_izni alanı bozuk (%r) — fail-closed, elle düzeltme yasak" % (bi,))
        d = bi["durum"]
        if d == "dur":
            return ("dur", "Sultan DUR dedi (%s) — veto" % _ref(bi))
        if d == "basla":
            return ("basla", "Sultan başla dedi (%s) — iş reis kararlarıyla yürür" % _ref(bi))
        return ("bekliyor", "başlama izni Sultan'a gitti (%s) · veto yok — iş reis kararlarıyla yürür" % str(bi.get("istendi") or "?")[:16])
    son = None
    for sk in k.get("sultan_kararlari") or []:
        if sk.get("karar") in ("basla", "dur"):
            son = sk
    if son is not None:
        if son["karar"] == "dur":
            return ("dur", "Sultan DUR dedi (%s) — veto" % _ref(son))
        return ("basla", "Sultan başla dedi (%s) — iş reis kararlarıyla yürür" % _ref(son))
    return ("bekliyor", "eski kart (kural 0.17) · veto yok — iş reis kararlarıyla yürür")


def vetolu(k):
    return izin_durumu(k)[0] == "dur"
