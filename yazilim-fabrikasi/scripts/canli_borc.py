#!/usr/bin/env python3
"""canli_borc — CANLI BORÇ değerlendirmesi (5WYQMW · SERDAR 22 Eki 00:43). Tek gerçek: kart.sh ve birlestirme-kapisi.sh buradan okur.

NİÇİN: canlı kanıt kapısı ("git'te düzeltildi ≠ canlıda çalışıyor") doğru, ama dağıtım birleşmeden SONRA (ya da başkasında) olunca kayıt ancak
  birleşmeden sonra oluşabilir ve kapı birleştirmeyi kilitler (cloudtop #769, #767). Çözüm kapıyı gevşetmek değil BORCU görünür kılmak:
  borç kayıtlıdır, kart 'bitti' olmaz, ödenmezse 24 saatte kırmızı olur.

DURUMLAR (durum(k, canli) → (ad, açıklama)):
  yok       kartta borç kaydı yok
  kaldirildi borçtan sonra sahibi canlı şartı kaldırdı (canli-ayarla --canli h): borç konusuz, kart bitebilir
  gecerli   borç kayıtlı, GEÇERLİ ve ÖDENMEMİŞ (kapı geçirir; kart 'canli-borclu')
  gecersiz  borç kayıtlı ama koşul tutmuyor (kapı geçirmez; sebep açıklamada)
  odendi    borçtan SONRA alınmış yeşil canlı kaydı var (kart 'bitti' olabilir)
GEÇERLİLİK: yazan = kartın sahibi (aldi) · gerekçe ≥ 20 karakter · SINIFLI kartta (sultan ya da siniflar) borç KENDİ BAŞINA yetmez:
  borçtan ÖNCE kart.sh sultan-dedi --karar canli-borc ile işlenmiş Sultan kararı (D1 deseni, A06: ajan Sultan adına borç yazamaz).
ÖDEME: etkin rengi yeşil canlı kayıt VE ölçüm zamanı borç zamanından SONRA (eski kayıt borcu ödemez).
"""
import datetime

SURE_SAAT = 24


def zaman(s):
    try:
        d = datetime.datetime.fromisoformat(str(s))
        return d.astimezone() if d.tzinfo is None else d
    except Exception:
        return None


def siniflimi(k):
    return bool(k.get("sultan") or k.get("siniflar"))


def durum(k, canli=()):
    b = k.get("canli_borc")
    if not b:
        return ("yok", "")
    bz = zaman(b.get("zaman"))
    if bz is None:
        return ("gecersiz", "borç zamanı okunamadı")
    # SERDAR 7 Kas (…NFC10Q): borçtan SONRA sahibi canlı şartı kaldırdıysa (kart.sh canli-ayarla --canli h) borç konusuz kalır; eskiden durum()
    #   bunu bilmediği için kart 'bitti' denince yine 'canli-borclu' kalıyor, borclar listesinde sonsuza dek kırmızı duruyordu. SON canli-ayarla
    #   olayı karar verir (sonradan şart yeniden konduysa 'e' → borç yürür).
    for g in reversed(k.get("gecmis") or []):
        if g.get("olay") == "canli-ayarla":
            gz = zaman(g.get("zaman"))
            if g.get("canli") == "h" and k.get("canli_gerekir") is False and gz is not None and gz >= bz:
                return ("kaldirildi", "canlı şartı borçtan sonra sahibince kaldırıldı (%s): %s" % (str(g.get("zaman", ""))[:16], str(g.get("gerekce", ""))[:120]))
            break
    if b.get("yazan") != k.get("aldi"):
        return ("gecersiz", "borcu yazan '%s' kartın sahibi değil (aldi: %s)" % (b.get("yazan"), k.get("aldi")))
    if len(str(b.get("gerekce") or "").strip()) < 20:
        return ("gecersiz", "borç gerekçesi 20 karakterden kısa")
    if siniflimi(k):
        # FAIL-CLOSED (göz tur 1): kararın zamanı okunamıyorsa ya da eksikse karar SAYILMAZ ("sıra" ölçülemez). Eski hâl `or bz` ile
        #   okunamayan zamanı borç anına eşitleyip kabul ediyordu.
        ok = any(
            sk.get("karar") == "canli-borc" and zaman(sk.get("zaman")) is not None and zaman(sk.get("zaman")) <= bz
            for sk in (k.get("sultan_kararlari") or [])
        )
        if not ok:
            return ("gecersiz", "kart SINIFLI: borçtan önce Sultan'ın kararı işlenmemiş (kart.sh sultan-dedi <iş> --karar canli-borc …); ajan Sultan adına borç yazamaz")
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
