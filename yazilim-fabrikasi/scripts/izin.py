#!/usr/bin/env python3
"""izin — BAŞLAMA İZNİ / VETO penceresi (0.21.0). Tek gerçek; kural metni adimlar/0-kabul.md "Sınıflı iş".

DURUMLAR (izin_durumu(k) → (ad, açıklama)):
  gerekmiyor  sınıfsız iş — başlama izni yok (elle yazılmış baslama_izni alanı YOK SAYILIR ve söylenir)
  bekliyor    sınıflı iş, Sultan henüz bir şey demedi — veto yok, iş reis kararlarıyla yürür (eski kart da buraya düşer)
  basla       Sultan "başla" dedi (kart.sh sultan-dedi --karar basla)
  dur         Sultan "dur" dedi (VETO) — reis-dedi · daralt · bitti kapalı; kaldırmak Sultan'ın (basla)
  olculemedi  baslama_izni alanı bozuk — çağıran fail-closed davranır (izin-durum rc 3)
Son basla/dur kazanır. Eski kart (alan yok): sultan_kararlari'ndaki son basla/dur, yoksa "bekliyor · eski kart · veto yok".
"""

KURAL_SURUMU = "0.21.0"
DURUMLAR = ("gerekmiyor", "bekliyor", "basla", "dur")


def siniflimi(k):
    return bool(k.get("sultan") or k.get("siniflar"))


def _ref(x):
    """Sultan kaydının izlenebilir künyesi (oturum · söz · sözün saati) — A06: söz üretilmez, aktarılır.
    Saat kayıttaki "zaman"dır: --soz-zamani ile sözün saati, yoksa yazım saati (görev …F6EWHF)."""
    o = str(x.get("oturum") or "?"); s = str(x.get("soz") or "?"); z = str(x.get("zaman") or "")[:16]
    return "oturum %s · söz \"%s\"%s" % (o, s[:60], (" · söz saati %s" % z) if z else "")


def soz_zamani_coz(ham, an):
    """--soz-zamani çözümü → (zaman ISO, kaynak 'soz'|'yazim', hata|None). Boş → yazım saati. Bozuk ya da gelecekteki saat → hata (kayıt üretilmez)."""
    import datetime
    ham = (ham or "").strip()
    if not ham:
        return an.isoformat(timespec="seconds"), "yazim", None
    try:
        z = datetime.datetime.fromisoformat(ham.replace("Z", "+00:00"))
    except ValueError:
        return None, None, "bozuk biçim (%r) — ISO-8601 ister, ör. 2026-10-28T20:25:00+03:00" % ham
    if z.tzinfo is None:
        z = z.replace(tzinfo=an.tzinfo)   # saat dilimi yoksa bu kutunun dilimi (oturum kaydı yerel saattedir)
    if z > an + datetime.timedelta(seconds=60):
        return None, None, "gelecekte (%s > şimdi %s) — söz henüz söylenmemiş olamaz" % (z.isoformat(timespec="seconds"), an.isoformat(timespec="seconds"))
    return z.isoformat(timespec="seconds"), "soz", None


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
