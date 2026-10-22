#!/usr/bin/env python3
"""canli_borc — CANLI BORÇ değerlendirmesi (5WYQMW · SERDAR 22 Eki 00:43). Tek gerçek: kart.sh ve birlestirme-kapisi.sh buradan okur.

NİÇİN: canlı kanıt kapısı ("git'te düzeltildi ≠ canlıda çalışıyor") doğru, ama dağıtım birleşmeden SONRA (ya da başkasında) olunca kayıt ancak
  birleşmeden sonra oluşabilir ve kapı birleştirmeyi kilitler (cloudtop #769, #767). Çözüm kapıyı gevşetmek değil BORCU görünür kılmak:
  borç kayıtlıdır, kart 'bitti' olmaz, ödenmezse 24 saatte kırmızı olur.

DURUMLAR (durum(k, canli) → (ad, açıklama)):
  yok       kartta borç kaydı yok
  gecerli   borç kayıtlı, GEÇERLİ ve ÖDENMEMİŞ (kapı geçirir; kart 'canli-borclu')
  gecersiz  borç kayıtlı ama koşul tutmuyor (kapı geçirmez; sebep açıklamada)
  odendi    borçtan SONRA alınmış yeşil canlı kaydı var (kart 'bitti' olabilir)
GEÇERLİLİK: yazan = kartın sahibi (aldi) · gerekçe ≥ 20 karakter · SINIFLI kartta (sultan ya da siniflar) üç şart daha
  (0.18.0 · Sultan D1 22 Eki — kural adimlar/4-gonder.md 3b): (1) Sultan VETO koymamış olmalı (izin.py: dur → gecersiz);
  (2) borçtan ÖNCE ya da borçla birlikte kartın sahibinin (reis) 'canli-borc' kararı işlenmiş olmalı (kart.sh canli-borc bunu
  kendisi yazar: reis == aldi, zaman ≤ borç) — VEYA eski kural (0.17) döneminden kalan Sultan 'canli-borc' kararı (geriye uyum);
  (3) kararın zamanı okunamıyorsa karar SAYILMAZ (fail-closed). A06 korunur: reis kaydı ayrı alandadır, Sultan sözü gibi gösterilmez.
ÖDEME: etkin rengi yeşil canlı kayıt VE ölçüm zamanı borç zamanından SONRA (eski kayıt borcu ödemez).
"""
import datetime

from izin import izin_durumu, siniflimi  # noqa: F401  (siniflimi dışarıdan da içe aktarılır — tek gerçek izin.py)

SURE_SAAT = 24


def zaman(s):
    try:
        d = datetime.datetime.fromisoformat(str(s))
        return d.astimezone() if d.tzinfo is None else d
    except Exception:
        return None


def durum(k, canli=()):
    b = k.get("canli_borc")
    if not b:
        return ("yok", "")
    bz = zaman(b.get("zaman"))
    if bz is None:
        return ("gecersiz", "borç zamanı okunamadı")
    if b.get("yazan") != k.get("aldi"):
        return ("gecersiz", "borcu yazan '%s' kartın sahibi değil (aldi: %s)" % (b.get("yazan"), k.get("aldi")))
    if len(str(b.get("gerekce") or "").strip()) < 20:
        return ("gecersiz", "borç gerekçesi 20 karakterden kısa")
    if siniflimi(k):
        # 🔴 VETO (0.18.0): Sultan "dur" dediyse borç yazılamaz / sayılmaz — izin.py tek gerçek; okunamazsa da sayılmaz (fail-closed)
        iz, iza = izin_durumu(k)
        if iz not in ("bekliyor", "basla"):   # dur = VETO · olculemedi = bozuk alan; ikisi de geçersiz (tek çit — sınav mutantı burayı çapalar)
            return ("gecersiz", ("kart SINIFLI ve Sultan DUR dedi — borç yazılmaz/sayılmaz; " if iz == "dur" else "kart SINIFLI ve başlama izni OKUNAMADI — borç sayılmaz; ") + iza)
        # FAIL-CLOSED (göz tur 1): kararın zamanı okunamıyorsa ya da eksikse karar SAYILMAZ ("sıra" ölçülemez). Eski hâl `or bz` ile
        #   okunamayan zamanı borç anına eşitleyip kabul ediyordu.
        reis_ok = any(
            rk.get("karar") == "canli-borc" and rk.get("reis") == k.get("aldi")
            and zaman(rk.get("zaman")) is not None and zaman(rk.get("zaman")) <= bz
            for rk in (k.get("reis_kararlari") or [])
        )
        sultan_ok = any(   # geriye uyum: 0.17 kuralıyla işlenmiş Sultan kararı geçerli kalır
            sk.get("karar") == "canli-borc" and zaman(sk.get("zaman")) is not None and zaman(sk.get("zaman")) <= bz
            for sk in (k.get("sultan_kararlari") or [])
        )
        if not (reis_ok or sultan_ok):
            return ("gecersiz", "kart SINIFLI: borçtan önce kartın sahibinin (reis) 'canli-borc' kararı işlenmemiş (kart.sh canli-borc kararı borçla birlikte yazar; elle yazılmış borç sayılmaz)")
    for x in canli:
        if x.get("tur") == "canli" and x.get("etkin_renk") == "yesil":
            oz = zaman(x.get("zaman") or "")
            if oz is not None and oz > bz:
                return ("odendi", "borç %s tarihli kayıtla ödendi (%s)" % (b.get("zaman", "")[:16], x.get("etiket", "?")))
    yas = (datetime.datetime.now().astimezone() - bz).total_seconds() / 3600
    return ("gecerli", "borç %s · %.1f saat önce · yazan %s · gerekçe: %s" % (b.get("zaman", "")[:16], yas, b.get("yazan"), str(b.get("gerekce"))[:160]))


def yas_saat(k):
    bz = zaman((k.get("canli_borc") or {}).get("zaman"))
    return None if bz is None else (datetime.datetime.now().astimezone() - bz).total_seconds() / 3600
