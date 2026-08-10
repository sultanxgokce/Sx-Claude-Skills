#!/usr/bin/env python3
"""LIFTING — ham çizim katmanlarından semantik oda grafına.

Girdi: duvar + açıklık segmentleri (JSON) ve oda etiket noktaları.
Çıktı: oda başına dikdörtgensel poligon + alan (plan-motor modeline hazır).

YÖNTEM — ızgara boyama (planar yüz dolaşımı DEĞİL):
Mimari çizimlerde duvarlar kapı/pencere yerlerinde KESİLİR; bu yüzden yalnız
duvar katmanıyla oda sınırı kapanmaz (bu dosyada 38 açık uç ölçüldü). Buna
karşılık açıklık katmanı (kapı kanadı/pervaz çizgileri) tam o boşlukları
doldurur. İkisi birlikte taranınca sınır kapanır; her etiket noktasından
boyama yapılır ve boyanan bölge o odadır. Sınır kaçağı olursa bölge dev
çıkar — fail-closed kapısı bunu yakalar.

FAIL-CLOSED:
  · bir etiketin bölgesi çizimin tamamına sızarsa (kaçak) → RC=1
  · iki etiket aynı bölgeye düşerse (duvar ayırmıyor) → RC=1
  · bir bölge kapanmazsa → RC=1
"Muhtemelen doğrudur" diye model üretilmez.
"""
import json
import math
import sys
from collections import deque

HUCRE = 2.0   # cm — ızgara çözünürlüğü
KALIN = 1     # sınır çizgisi kalınlığı (hücre) — piksel düzeyi delikleri kapatır


def _yon(a, b):
    if abs(a[0] - b[0]) < 0.6:
        return "D"
    if abs(a[1] - b[1]) < 0.6:
        return "Y"
    return "?"


def _engel_var(p, q, segmentler, haric):
    """p–q (eksen hizalı) aralığını başka bir duvar kesiyor mu."""
    dikey = abs(p[0] - q[0]) < 0.6
    for k, (a, b) in enumerate(segmentler):
        if k in haric:
            continue
        if dikey and abs(a[1] - b[1]) < 0.6:
            y = a[1]
            x0, x1 = sorted((a[0], b[0]))
            t0, t1 = sorted((p[1], q[1]))
            if x0 - 0.6 <= p[0] <= x1 + 0.6 and t0 + 1 < y < t1 - 1:
                return True
        if not dikey and abs(a[0] - b[0]) < 0.6:
            x = a[0]
            y0, y1 = sorted((a[1], b[1]))
            t0, t1 = sorted((p[0], q[0]))
            if y0 - 0.6 <= p[1] <= y1 + 0.6 and t0 + 1 < x < t1 - 1:
                return True
    return False


def kapilari_muhurle(segmentler, asgari=55.0, azami=180.0, kalinlik_toleransi=1.5):
    """Duvarlar kapalı gövde olarak çizilir; kapı/pencere yerinde iki gövde arasında
    AĞIZ kalır ve oda sınırı kapanmaz. Karşılıklı duran iki duvar-ucunu (aynı
    kalınlıkta, tam karşı karşıya, aralarında başka duvar YOK) mühürler.
    Mühür çizgileri sınır sayılır; oda ayrımı bunlarla kurulur."""
    uclar = [(i, a, b) for i, (a, b) in enumerate(segmentler) if math.dist(a, b) <= 35]
    muhurler = []
    for ii in range(len(uclar)):
        i, a1, b1 = uclar[ii]
        y1 = _yon(a1, b1)
        if y1 == "?":
            continue
        for jj in range(ii + 1, len(uclar)):
            j, a2, b2 = uclar[jj]
            if _yon(a2, b2) != y1:
                continue
            if abs(math.dist(a1, b1) - math.dist(a2, b2)) > kalinlik_toleransi:
                continue
            m1 = ((a1[0] + b1[0]) / 2, (a1[1] + b1[1]) / 2)
            m2 = ((a2[0] + b2[0]) / 2, (a2[1] + b2[1]) / 2)
            d = math.dist(m1, m2)
            if not (asgari <= d <= azami):
                continue
            if y1 == "D" and abs(m1[1] - m2[1]) > 2.5:
                continue
            if y1 == "Y" and abs(m1[0] - m2[0]) > 2.5:
                continue
            if _engel_var(m1, m2, segmentler, {i, j}):
                continue
            muhurler.append((m1, m2))
    return muhurler


def rasterle(segmentler, minX, minY, en, boy):
    """Segmentleri ızgaraya SINIR olarak bas (Bresenham + kalınlaştırma)."""
    duvar = bytearray(en * boy)

    def isaretle(cx, cy):
        for dx in range(-KALIN, KALIN + 1):
            for dy in range(-KALIN, KALIN + 1):
                x, y = cx + dx, cy + dy
                if 0 <= x < en and 0 <= y < boy:
                    duvar[y * en + x] = 1

    for a, b in segmentler:
        x0 = int(round((a[0] - minX) / HUCRE))
        y0 = int(round((a[1] - minY) / HUCRE))
        x1 = int(round((b[0] - minX) / HUCRE))
        y1 = int(round((b[1] - minY) / HUCRE))
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        hata = dx - dy
        while True:
            isaretle(x0, y0)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * hata
            if e2 > -dy:
                hata -= dy
                x0 += sx
            if e2 < dx:
                hata += dx
                y0 += sy
    return duvar


def boya(duvar, en, boy, bas):
    """4-komşu boyama. Döner: (hücre kümesi, kenara_dokundu_mu)."""
    bx, by = bas
    if duvar[by * en + bx]:
        # etiket tam sınıra düşmüş — en yakın boş hücreye kay
        for r in range(1, 12):
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    x, y = bx + dx, by + dy
                    if 0 <= x < en and 0 <= y < boy and not duvar[y * en + x]:
                        bx, by = x, y
                        r = -1
                        break
                if r == -1:
                    break
            if r == -1:
                break
    gorulen = bytearray(en * boy)
    kuyruk = deque([(bx, by)])
    gorulen[by * en + bx] = 1
    hucreler = []
    kenara_dokundu = False
    while kuyruk:
        x, y = kuyruk.popleft()
        hucreler.append((x, y))
        if x == 0 or y == 0 or x == en - 1 or y == boy - 1:
            kenara_dokundu = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < en and 0 <= ny < boy:
                i = ny * en + nx
                if not gorulen[i] and not duvar[i]:
                    gorulen[i] = 1
                    kuyruk.append((nx, ny))
    return set(hucreler), kenara_dokundu


def konturu_izle(hucreler, en, boy):
    """Hücre kümesinin dış sınırını dikdörtgensel poligon olarak çıkar.
    Kenar-yürüyüşü: bölgenin dışına bakan birim kenarları toplayıp zincirler."""
    kenarlar = {}
    for x, y in hucreler:
        # her hücre kenarı: bölge dışına bakıyorsa sınırdır (saat yönü tersine yönlü)
        if (x, y - 1) not in hucreler:
            kenarlar.setdefault((x, y), []).append((x + 1, y))
        if (x + 1, y) not in hucreler:
            kenarlar.setdefault((x + 1, y), []).append((x + 1, y + 1))
        if (x, y + 1) not in hucreler:
            kenarlar.setdefault((x + 1, y + 1), []).append((x, y + 1))
        if (x - 1, y) not in hucreler:
            kenarlar.setdefault((x, y + 1), []).append((x, y))

    if not kenarlar:
        return None
    # en büyük halkayı izle (delikler atılır)
    bas = min(kenarlar)
    halka = [bas]
    simdi = bas
    while True:
        sonraki_liste = kenarlar.get(simdi)
        if not sonraki_liste:
            return None
        sonraki = sonraki_liste.pop()
        if not sonraki_liste:
            del kenarlar[simdi]
        if sonraki == bas:
            break
        halka.append(sonraki)
        simdi = sonraki
        if len(halka) > 200000:
            return None
    return halka


def sadelestir(halka):
    """Eş-doğrusal ardışık noktaları at."""
    if len(halka) < 3:
        return halka
    cikti = []
    n = len(halka)
    for i in range(n):
        o, b, s = halka[i - 1], halka[i], halka[(i + 1) % n]
        capraz = (b[0] - o[0]) * (s[1] - b[1]) - (b[1] - o[1]) * (s[0] - b[0])
        if capraz != 0:
            cikti.append(b)
    return cikti


def alan_m2(halka):
    s = 0.0
    for i in range(len(halka)):
        x1, y1 = halka[i]
        x2, y2 = halka[(i + 1) % len(halka)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2 * HUCRE * HUCRE / 10000


def main():
    girdi = json.load(open(sys.argv[1]))
    sinir = [(tuple(a), tuple(b)) for a, b in girdi["sinir"]]
    sinir = [(a, b) for a, b in sinir if math.dist(a, b) > 0.1]
    etiketler = girdi["etiketler"]

    xs = [p[0] for s in sinir for p in s]
    ys = [p[1] for s in sinir for p in s]
    pay = 20
    minX, minY = min(xs) - pay, min(ys) - pay
    en = int((max(xs) + pay - minX) / HUCRE) + 2
    boy = int((max(ys) + pay - minY) / HUCRE) + 2
    print(f"ızgara {en}×{boy} hücre ({HUCRE} cm) · sınır segmenti {len(sinir)}", file=sys.stderr)

    muhurler = kapilari_muhurle(sinir)
    # Otomatik kural her ağzı yakalayamaz (çizimdeki düzensiz boşluklar). v1 YARI-OTOMATİKTİR:
    # kalan ağızlar girdide açıkça beyan edilir; her biri gerekçesiyle kayda geçer.
    elle = girdi.get("ek_muhur", [])
    for m in elle:
        muhurler.append((tuple(m["a"]), tuple(m["b"])))
        print(f"  · elle mühür: {m['a']} ↔ {m['b']} — {m.get('gerekce', 'gerekçe yazılmamış')}", file=sys.stderr)
    print(f"kapı/pencere ağzı mührü: {len(muhurler) - len(elle)} otomatik + {len(elle)} elle", file=sys.stderr)
    duvar = rasterle(sinir + muhurler, minX, minY, en, boy)
    toplam_bos = en * boy - sum(duvar)

    sonuc = []
    imzalar = {}
    for e in etiketler:
        bx = int(round((e["x"] - minX) / HUCRE))
        by = int(round((e["y"] - minY) / HUCRE))
        hucreler, kenar = boya(duvar, en, boy, (bx, by))
        alan = len(hucreler) * HUCRE * HUCRE / 10000
        if kenar:
            print(f"✗ '{e['ad']}': bölge çizim kenarına sızdı ({alan:.1f} m²) — sınır kapalı değil", file=sys.stderr)
            return 1
        if len(hucreler) > toplam_bos * 0.75:
            print(f"✗ '{e['ad']}': bölge çizimin %75'inden büyük — kaçak var", file=sys.stderr)
            return 1
        imza = min(hucreler)
        if imza in imzalar:
            print(f"✗ '{e['ad']}' ile '{imzalar[imza]}' AYNI bölgede — çizim bu ikisini duvarla ayırmıyor", file=sys.stderr)
            return 1
        imzalar[imza] = e["ad"]

        halka = konturu_izle(hucreler, en, boy)
        if halka is None:
            print(f"✗ '{e['ad']}': kontur kapanmadı", file=sys.stderr)
            return 1
        halka = sadelestir(halka)
        poligon = [[round(minX + x * HUCRE, 1), round(minY + y * HUCRE, 1)] for x, y in halka]
        sonuc.append({
            "ad": e["ad"],
            "m2_etiket": e.get("m2"),
            "m2_boyama": round(alan, 2),
            "m2_poligon": round(alan_m2(halka), 2),
            "kose": len(poligon),
            "poligon": poligon,
        })
        print(f"  ✓ {e['ad']:10s} {alan:6.2f} m² (etikette {e.get('m2')}) · {len(poligon)} köşe", file=sys.stderr)

    json.dump(
        {
            "odalar": sonuc,
            # mühürler = kapı/pencere ağızları; model üreticisi bunları açıklığa çevirir
            "muhurler": [{"a": [round(m[0][0], 1), round(m[0][1], 1)],
                          "b": [round(m[1][0], 1), round(m[1][1], 1)]} for m in muhurler],
        },
        open(sys.argv[2], "w"),
        ensure_ascii=False,
        indent=1,
    )
    print(f"✓ {len(sonuc)} oda çıkarıldı", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
