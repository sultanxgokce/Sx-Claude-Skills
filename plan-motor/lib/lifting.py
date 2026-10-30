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


def etiket_sadelestir(ad):
    """CAD metnini karşılaştırılabilir hâle getir: biçim kodları (\\C0; \\A1; \\W1.2;), süslü
    parantez ve \\U+XXXX kaçışları temizlenir; boşluk sadeleşir; büyük/küçük ayrımı kalkar.
    Niçin: aynı oda adı çizimde '\\C0;ASANS\\U+00D6R BO\\U+015ELU\\U+011EU' yazılıdır; insan
    'ASANSÖR BOŞLUĞU' beyan eder. Eşleşme insanın yazdığıyla kurulmalı."""
    import re
    t = ad or ""
    t = re.sub(r"\\U\+([0-9A-Fa-f]{4})", lambda m: chr(int(m.group(1), 16)), t)
    t = re.sub(r"\\[A-Za-z][^;]*;", " ", t)
    t = t.replace("{", " ").replace("}", " ")
    t = re.sub(r"\s+", " ", t).strip()
    return t.casefold().replace("i̇", "i")


def oda_tohumlarini_suz(etiketler, beyan, akis):
    """Yalnız BEYAN edilen etiketler oda tohumu sayılır (ek_muhur/ek_cevre deseni).

    Gerçek çizimde oda adı ile raf adı AYNI katmanlarda durur (ölçüldü 2026-09-18: Siirt'te
    oda adları 'not'/'duvar', raf adları 'kolon'/'yok-say' rolündeydi) — katman rolü bu sınıfta
    ayırt edici değildir. Ayrımı insan yapar, motor beyanı uygular ve izini çıktıya yazar.
    """
    istenen = [str(x) for x in beyan]
    anahtar = {}
    for ad in istenen: anahtar.setdefault(etiket_sadelestir(ad), ad)
    secilen, elenen, eslesen = [], 0, set()
    for e in etiketler:
        k = etiket_sadelestir(e.get("ad"))
        if k in anahtar:
            secilen.append(e); eslesen.add(anahtar[k])
        else:
            elenen += 1
    eslesmeyen = [a for a in istenen if a not in eslesen]
    print(f"  · oda BEYANI: {len(istenen)} ad istendi → {len(secilen)} tohum seçildi, {elenen} etiket elendi", file=akis)
    for a in eslesmeyen:
        print(f"    ⚠ beyan edilen '{a}' çizimde BULUNAMADI (yazım farkı olabilir) — sessizce yutulmuyor", file=akis)
    return secilen, {"kaynak": "oda_etiketleri", "istenen": len(istenen), "tohum": len(secilen),
                     "elenen_etiket": elenen, "eslesmeyen": eslesmeyen}


def duvar_kutusu(segmentler, minX, minY, en, boy):
    """Sınır segmentlerinin ızgara koordinatındaki kutusu (bina kutusu)."""
    xs = [p[0] for s in segmentler for p in s]; ys = [p[1] for s in segmentler for p in s]
    gx0 = max(0, int((min(xs) - minX) / HUCRE)); gx1 = min(en - 1, int((max(xs) - minX) / HUCRE))
    gy0 = max(0, int((min(ys) - minY) / HUCRE)); gy1 = min(boy - 1, int((max(ys) - minY) / HUCRE))
    return gx0, gy0, gx1, gy1


def _kosular(indisler):
    """Ardışık indis koşularını (bas, son) olarak grupla."""
    out = []
    for i in sorted(indisler):
        if out and i == out[-1][1] + 1: out[-1][1] = i
        else: out.append([i, i])
    return [(a, b) for a, b in out]


def cevre_taramasi(hucreler, en, boy, minX, minY, kutu):
    """Taşkın bölge bina kutusunu NEREDE geçiyor: kenar → [(baş_cm, son_cm, uzunluk_cm)].

    Niçin: 'sınır kapalı değil' tek başına kullanıcıya hedefli soru ürettirmez. Açık yerin
    hangi kenarda ve hangi aralıkta olduğu söylenirse soru 'şu 140 cm'lik ağzı kapatır mısın'
    olur. Ölçüm ızgara hücresi üzerindendir; çözünürlük HUCRE (2 cm) kadardır.
    """
    gx0, gy0, gx1, gy1 = kutu
    hatlar = {
        "BATI":  [((gx0, y), y) for y in range(gy0, gy1 + 1)],
        "DOGU":  [((gx1, y), y) for y in range(gy0, gy1 + 1)],
        "GUNEY": [((x, gy0), x) for x in range(gx0, gx1 + 1)],
        "KUZEY": [((x, gy1), x) for x in range(gx0, gx1 + 1)],
    }
    rapor = {}
    for ad, hat in hatlar.items():
        acik = [i for (h, i) in hat if h in hucreler]
        if not acik: continue
        dikey = ad in ("BATI", "DOGU")
        taban = minY if dikey else minX
        araliklar = []
        for a, b in _kosular(acik):
            bas = taban + a * HUCRE; son = taban + (b + 1) * HUCRE
            araliklar.append((round(bas, 1), round(son, 1), round(son - bas, 1)))
        rapor[ad] = {"araliklar": araliklar, "acik_hucre": len(acik), "kenar_hucre": len(hat)}
    return rapor


def cevre_raporla(rapor, akis):
    """Çeper taramasını insan diline çevir: her kenar için AÇIK YÜZDE + eksenli aralıklar.
    Etiket uydurmaz ("çeper yok" diye ikili karar vermez): %92 açık kenar ile 140 cm'lik tek ağız
    aynı satır biçiminde okunur, yorum insanındır. Çözünürlük ızgara payı kadardır (±2·HUCRE cm)."""
    acik_kenar = 0
    for ad in ("BATI", "DOGU", "GUNEY", "KUZEY"):
        r = rapor.get(ad)
        if not r: continue
        acik_kenar += 1
        oran = 100.0 * r["acik_hucre"] / max(1, r["kenar_hucre"])
        eksen = "y" if ad in ("BATI", "DOGU") else "x"
        gosterilen = r["araliklar"][:6]
        metin = " · ".join(f"{eksen}={a:.0f}…{b:.0f} ({u:.0f} cm)" for a, b, u in gosterilen)
        fazla = "" if len(r["araliklar"]) <= 6 else f" · +{len(r['araliklar'])-6} aralık daha"
        print(f"   {ad:6s}: kenarın %{oran:.0f}'i açık · {len(r['araliklar'])} aralık — {metin}{fazla}", file=akis)
    print(f"   özet: 4 kenarın {acik_kenar}'inde açıklık var (ızgara payı ±{2*HUCRE:.0f} cm)", file=akis)


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

    # ÇEPER BEYANI: gerçek müşteri çizimlerinde dış çeper çoğu kez kapalı çizili DEĞİLDİR
    # (ölçüldü 2026-09-16, Bankalar Merkez Siirt: 23 katmanın hiçbiri kapatmıyor). İki meşru
    # yol var: (a) çizime CEVRE katmanı çizip rolünü 'duvar' beyan etmek — kod gerektirmez,
    # segmentler sinir'e katmandan gelir; (b) burada 'ek_cevre' ile poligon beyan etmek.
    # Her ikisi de BEYANDIR, ölçüm değildir: kaynağı çıktıya yazılır ki model bunu gizlemesin.
    # ODA BEYANI: hangi etiketler oda tohumudur (MEDDAH kararı 2026-09-18)
    oda_beyani = None
    ham_oda = girdi.get("oda_etiketleri")
    if ham_oda:
        etiketler, oda_beyani = oda_tohumlarini_suz(etiketler, ham_oda, sys.stderr)
        oda_beyani["gerekce"] = girdi.get("oda_etiketleri_gerekce", "gerekçe yazılmamış")
        if not etiketler:
            print("✗ beyan edilen adların HİÇBİRİ çizimde bulunamadı — oda üretilmez", file=sys.stderr)
            return 1

    # İÇ BÖLME BEYANI (çeperin kardeşi, MEDDAH kararı 2026-09-23): gerçek çizimde bölme duvarları
    # ya rolü yanlış beyan edilmiş katmanda ya da duvar+mobilya KARIŞIK bir katmandadır (Siirt: `0`
    # katmanı 712 segmentle hem WC duvarını hem raf ayak izini taşıyor; tek rol her iki yönde yanlış).
    # Karışık katmanda rol düzeltmesi çare değildir; gereken bölme çizgileri burada BEYAN edilir.
    bolme_beyani = None
    ham_bolme = girdi.get("ek_bolme")
    if ham_bolme:
        eklenen = []
        for b in ham_bolme:
            a_, b_ = tuple(b["a"]), tuple(b["b"])
            if math.dist(a_, b_) > 0.1: eklenen.append((a_, b_))
        if not eklenen:
            print("✗ ek_bolme boş ya da sıfır uzunluklu", file=sys.stderr)
            return 1
        sinir = sinir + eklenen
        bolme_beyani = {"kaynak": "ek_bolme", "segment": len(eklenen),
                        "gerekce": girdi.get("ek_bolme_gerekce", "gerekçe yazılmamış")}
        print(f"  · iç bölme BEYANI: {len(eklenen)} segment — {bolme_beyani['gerekce']}", file=sys.stderr)

    cevre_beyani = None
    ham_cevre = girdi.get("ek_cevre")
    if ham_cevre:
        noktalar = [tuple(p) for p in ham_cevre]
        if len(noktalar) < 3:
            print("✗ ek_cevre en az 3 köşe ister (kapalı halka)", file=sys.stderr)
            return 1
        halka = [(noktalar[i], noktalar[(i + 1) % len(noktalar)]) for i in range(len(noktalar))]
        eklenen = [(a, b) for a, b in halka if math.dist(a, b) > 0.1]
        sinir = sinir + eklenen
        cevre_beyani = {"kaynak": "ek_cevre", "kose": len(noktalar), "segment": len(eklenen),
                        "gerekce": girdi.get("ek_cevre_gerekce", "gerekçe yazılmamış")}
        print(f"  · çeper BEYANI: {len(noktalar)} köşe / {len(eklenen)} segment — {cevre_beyani['gerekce']}", file=sys.stderr)

    xs = [p[0] for s in sinir for p in s]
    ys = [p[1] for s in sinir for p in s]
    pay = 20
    minX, minY = min(xs) - pay, min(ys) - pay
    en = int((max(xs) + pay - minX) / HUCRE) + 2
    boy = int((max(ys) + pay - minY) / HUCRE) + 2
    print(f"ızgara {en}×{boy} hücre ({HUCRE} cm) · sınır segmenti {len(sinir)}", file=sys.stderr)

    # OTOMATİK MÜHÜR ANAHTARI (2026-09-23, gerçek market çiziminde ölçüldü): otomatik kural
    # karışık katmanlı çizimde SAHTE ağız üretiyor (44 mühürün yalnız %14'i duvara bağlandı,
    # köprü haklı olarak durdu). Kapılar çizimde ölçü yazısıyla belli olduğunda otomatik kural
    # kapatılır ve ağızlar BEYAN edilir. Varsayılan AÇIK: eski davranış değişmez.
    otomatik = girdi.get("otomatik_muhur", True)
    muhurler = kapilari_muhurle(sinir) if otomatik else []
    if not otomatik:
        print("  · otomatik mühür KAPALI (beyan: otomatik_muhur=false) — ağızlar yalnız ek_muhur'dan", file=sys.stderr)
    # Otomatik kural her ağzı yakalayamaz (çizimdeki düzensiz boşluklar). v1 YARI-OTOMATİKTİR:
    # kalan ağızlar girdide açıkça beyan edilir; her biri gerekçesiyle kayda geçer.
    elle = girdi.get("ek_muhur", [])
    for m in elle:
        muhurler.append((tuple(m["a"]), tuple(m["b"]), m.get("genislik")))
        print(f"  · elle mühür: {m['a']} ↔ {m['b']} — {m.get('gerekce', 'gerekçe yazılmamış')}", file=sys.stderr)
    print(f"kapı/pencere ağzı mührü: {len(muhurler) - len(elle)} otomatik + {len(elle)} elle", file=sys.stderr)
    duvar = rasterle([(m[0], m[1]) for m in muhurler], minX, minY, en, boy) if False else rasterle(sinir + [(m[0], m[1]) for m in muhurler], minX, minY, en, boy)
    toplam_bos = en * boy - sum(duvar)

    sonuc = []
    imzalar = {}
    disarida = 0
    for e in etiketler:
        bx = int(round((e["x"] - minX) / HUCRE))
        by = int(round((e["y"] - minY) / HUCRE))
        if not (0 <= bx < en and 0 <= by < boy):
            # Çizim kutusunun DIŞINDAKİ etiket (başlık bloğu notu, lejant): oda değildir.
            # Eskiden IndexError ile çöküyordu (2026-09-16, gerçek market çiziminde ölçüldü).
            disarida += 1
            print(f"  ⚠ '{e['ad']}': etiket çizim kutusunun dışında — oda sayılmadı", file=sys.stderr)
            continue
        hucreler, kenar = boya(duvar, en, boy, (bx, by))
        alan = len(hucreler) * HUCRE * HUCRE / 10000
        if kenar:
            print(f"✗ '{e['ad']}': bölge çizim kenarına sızdı ({alan:.1f} m²) — sınır kapalı değil", file=sys.stderr)
            kutu = duvar_kutusu(sinir, minX, minY, en, boy)
            en_cm = (kutu[2] - kutu[0]) * HUCRE; boy_cm = (kutu[3] - kutu[1]) * HUCRE
            print(f"  çeper taraması (bina kutusu {en_cm:.0f}×{boy_cm:.0f} cm):", file=sys.stderr)
            tarama = cevre_taramasi(hucreler, en, boy, minX, minY, kutu)
            if tarama: cevre_raporla(tarama, sys.stderr)
            else: print("   (taşkın kutu kenarlarına değmiyor — kaçak iç bölgede)", file=sys.stderr)
            print("  → çeperi kapat: çizime CEVRE katmanı çiz (rol=duvar) ya da girdiye"
                  " ek_cevre: [[x,y], ...] beyanı koy", file=sys.stderr)
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
            # Beyan edilen genişlik (kapı ölçü yazısı) mühürle BİRLİKTE taşınır: köprü onu
            # duvar parçasının boyundan türetmek zorunda kalmasın (ölçüldü 2026-09-23: 90 cm kapı,
            # bölme beyanıyla parçalanmış 68 cm'lik duvara düşünce sessizce 66 cm oluyordu).
            "muhurler": [dict({"a": [round(m[0][0], 1), round(m[0][1], 1)],
                               "b": [round(m[1][0], 1), round(m[1][1], 1)]},
                              **({"genislik": m[2]} if len(m) > 2 and m[2] else {})) for m in muhurler],
            # Çeper beyanla kapatıldıysa model bunu BİLMELİ: ölçü raporunda "dış hat beyandır" der.
            "cevre_beyani": cevre_beyani,
            "oda_beyani": oda_beyani,
            "bolme_beyani": bolme_beyani,
        },
        open(sys.argv[2], "w"),
        ensure_ascii=False,
        indent=1,
    )
    print(f"✓ {len(sonuc)} oda çıkarıldı" + (f" · {disarida} etiket kutu dışında atlandı" if disarida else ""), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
