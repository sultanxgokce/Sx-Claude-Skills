#!/usr/bin/env python3
"""İ1 taramasının SAHTE-FİKSTÜR süzgeci — hiçbir gerçek değeri BİLMEZ.

🔴 Kural (Sultan, 2026-08-23): *sınav DEĞER değil BİÇİM aramalı.* Bir değer listesi
tutmak, denetçiyi yeniden sızıntı yapar — listeye bir gün gerçek bir değer eklenirse
sızıntı arayan sınav onu ELİYLE beyaz-listeler. Bu süzgeç bunun yerine sayının
YAPISINA bakar: bir fikstür değeri "açıkça sahte" görünmek ZORUNDADIR.

Sahte sayılan biçimler (hepsi yapısal, hiçbiri ezberlenmiş değer değil):
  · tek hanenin tekrarı        1111111111 · 2222222222
  · artan/azalan ardışık dizi  1234567890 · 9876543210 · 0987654321
  · ≤2 farklı hane             1212121212
Bunun dışındaki her 10-11 haneli sayı GERÇEK VARSAYILIR (fail-closed).
"""
import re
import sys

SAYI = re.compile(r"\b\d{10,11}\b")


def sahte_mi(n: str) -> bool:
    if len(set(n)) <= 2:                       # tek hane tekrarı / iki hane dönüşümü
        return True
    farklar = {(int(b) - int(a)) % 10 for a, b in zip(n, n[1:])}
    return farklar in ({1}, {9})               # artan ya da azalan ardışık dizi


def main() -> int:
    for satir in sys.stdin:
        sayilar = SAYI.findall(satir)
        # Satırda GERÇEK görünen en az bir sayı varsa satır BULGUDUR; hepsi sahteyse elenir.
        if sayilar and all(sahte_mi(n) for n in sayilar):
            continue
        sys.stdout.write(satir)
    return 0


# 🔴 `__main__` KAPISI ŞART: ilk hâlinde stdin okuması modül düzeyindeydi ve dosyayı
#    `import` eden her şey (sınav dahil) stdin'de ASILI KALIYORDU. Bugünün "yazılmış ≠
#    bağlanmış" ailesinin kardeşi: kod doğruydu, ÇAĞRILMA BİÇİMİ yanlıştı.
if __name__ == "__main__":
    raise SystemExit(main())
