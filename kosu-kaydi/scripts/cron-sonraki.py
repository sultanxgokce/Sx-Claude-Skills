#!/usr/bin/env python3
"""cron-sonraki.py — 5 alanlı cron ifadesinden bir SONRAKİ ateşleme anını basar (ISO-8601, yerel saat dilimli).
Şema: Nexus kokpit-ux/05 K5. @reboot/@daily… sınıfı ve 5 alanlı olmayan ifade → stdout boş, rc 3 (türetilemedi; uydurma yok).
Kullanım: cron-sonraki.py "<dk> <saat> <gün> <ay> <hafta-günü>" [<an ISO>]   (an verilmezse şimdi)
Bağımsız: hiçbir paket istemez (croniter nazir kutusunda YOKTU, A290). Vixie-cron kuralları:
  alan = * | sayı | a-b | liste(,) | adım(/) | ay/gün adı (jan…dec · sun…sat); hafta günü 0 ve 7 = Pazar;
  gün-ay ve hafta-günü İKİSİ de kısıtlıysa biri tutunca ateşler (cron'un OR kuralı). Tarama 1500 gün (29 Şubat sığar); bulunamazsa rc 3.
"""
import sys, datetime

SINIR = {0: (0, 59), 1: (0, 23), 2: (1, 31), 3: (1, 12), 4: (0, 7)}
AD = {3: {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12},
      4: {"sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6}}


def _sayi(s, i):
    s = s.lower()
    if i in AD and s in AD[i]:
        return AD[i][s]
    return int(s)


def alan_coz(metin, i):
    """bir alan → tutan değerler kümesi; '*' ise None (kısıtsız)."""
    lo, hi = SINIR[i]
    if metin == "*":
        return None
    kume = set()
    for parca in metin.split(","):
        adim = 1
        if "/" in parca:
            parca, a = parca.split("/", 1)
            adim = int(a)
            if adim < 1:
                raise ValueError("adım<1")
        if parca == "*":
            bas, son = lo, hi
        elif "-" in parca:
            a, b = parca.split("-", 1)
            bas, son = _sayi(a, i), _sayi(b, i)
        else:
            bas = _sayi(parca, i)
            son = hi if adim != 1 else bas  # "5/15": 5'ten başla, adımla sona kadar
        if bas < lo or son > hi or bas > son:
            raise ValueError(f"alan {i} aralık dışı: {metin}")
        kume.update(range(bas, son + 1, adim))
    if i == 4 and 7 in kume:
        kume.discard(7)
        kume.add(0)
    return kume


def sonraki(ifade, an):
    alanlar = ifade.split()
    if len(alanlar) != 5:
        raise ValueError("5 alan değil")
    dk, sa, gun, ay, hg = (alan_coz(a, i) for i, a in enumerate(alanlar))
    t = (an + datetime.timedelta(minutes=1)).replace(second=0, microsecond=0)
    son = an + datetime.timedelta(days=1500)   # 4 yıl+: 29 Şubat gibi seyrek ama geçerli ifadeler türetilsin (366 gün yetmiyordu)
    while t <= son:
        if ay is not None and t.month not in ay:
            y, m = (t.year + t.month // 12, t.month % 12 + 1)
            t = t.replace(year=y, month=m, day=1, hour=0, minute=0)
            continue
        gun_tutar = gun is None or t.day in gun
        hg_tutar = hg is None or ((t.weekday() + 1) % 7) in hg  # python Pzt=0 → cron Paz=0
        if gun is not None and hg is not None:
            gun_ok = gun_tutar or hg_tutar
        else:
            gun_ok = gun_tutar and hg_tutar
        if not gun_ok:
            t = (t + datetime.timedelta(days=1)).replace(hour=0, minute=0)
            continue
        if sa is not None and t.hour not in sa:
            t = (t + datetime.timedelta(hours=1)).replace(minute=0)
            continue
        if dk is not None and t.minute not in dk:
            t += datetime.timedelta(minutes=1)
            continue
        return t
    return None


def main():
    if len(sys.argv) < 2:
        print("kullanım: cron-sonraki.py '<5 alan>' [<an>]", file=sys.stderr)
        return 2
    ifade = sys.argv[1].strip()
    if ifade.startswith("@") or len(ifade.split()) != 5:
        return 3  # türetilemedi: @reboot sınıfı ya da 5 alanlı değil
    an = datetime.datetime.fromisoformat(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else datetime.datetime.now().astimezone()
    if an.tzinfo is None:
        an = an.astimezone()
    try:
        s = sonraki(ifade, an)
    except (ValueError, KeyError) as e:
        print(f"ifade çözülemedi: {e}", file=sys.stderr)
        return 3
    if s is None:
        return 3
    print(s.isoformat(timespec="seconds"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
