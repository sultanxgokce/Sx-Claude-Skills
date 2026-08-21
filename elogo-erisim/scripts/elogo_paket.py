#!/usr/bin/env python3
"""
elogo_paket.py — UBL XML'i e-Logo'nun `SendDocument` beklediği kaba koyar.

NİÇİN AYRI DOSYA
────────────────
Gönderim iki bağımsız işten oluşuyor ve ikisinin risk profili taban tabana zıt:

  1. PAKETLEME  — saf hesap. Ağ yok, kimlik yok, geri-alınamaz sonuç yok.
                  Sonuna kadar test edilebilir. BU DOSYA.
  2. GÖNDERİM   — geri alınamaz. Bir kez GİB'e giden fatura geri gelmez.
                  `elogo_gonder.py`'de yaşar ve ayrı bir kapıdan geçer.

İkisini tek dosyaya koymak, test edilebilir olanı test edilemez olanın
riskine ortak ederdi.

ÖLÇÜLEN SÖZLEŞME (Uygulama Arabirim Dokümanı, 21.08.2026 · s.5, s.24, s.36)
──────────────────────────────────────────────────────────────────────────
> "Belge verisi **zip formatında sıkıştırılmış** olmalıdır.
>  Bir zip dosya içinde birden fazla belge olabilir."

`DocumentDataType` dört alan ister:
  binaryData.Value  → ZIP'in base64'ü        (contentType = "base64")
  fileName          → zip dosya adı
  hash              → 🔴 "Binary data verisinin **MD5** özet değeri"
  currentDate       → güncel tarih

🔴 İKİ TUZAK, ikisi de belgeden okundu, ikisi de sınavda kilitli:
  (a) MD5 **ZIP'in ham baytları** üstünde alınır — base64 metni üstünde DEĞİL.
      Yanlış tarafı özetlemek sunucuda "hash uyuşmadı" verir ve sebebi
      fatura içeriğinde aranır; oysa hata burada olur.
  (b) Özet **MD5**'tir. Belge iki ayrı yerde MD5 diyor (s.24 ve s.5 örnek kodu).
      SHA-256 alışkanlığı buraya taşınmaz.

🔴 ŞİRKETSİZ: bu dosyada firma adı, VKN, etiket, müşteri yok — 16 kutunun
   ortak gördüğü rafta yaşıyor (İ1). Her değer çağırandan gelir.
"""
from __future__ import annotations

import base64
import hashlib
import io
import zipfile
from datetime import date


class PaketHatasi(ValueError):
    """Paketleme ön-koşulu tutmadı. Fail-closed: eksikse paket ÜRETİLMEZ."""


def zip_kur(belgeler: dict[str, bytes]) -> bytes:
    """{dosya-adı: içerik} → zip baytları.

    Deterministik: sabit zaman damgası kullanılır, böylece aynı girdi aynı
    zip'i (ve aynı MD5'i) verir. Damga değişkense özet de değişir ve
    "aynı faturayı iki kez paketledim, iki farklı hash çıktı" sınıfı bir
    teşhis kâbusu doğar.
    """
    if not belgeler:
        raise PaketHatasi("zip boş olamaz — en az bir belge gerekli")
    for ad, icerik in belgeler.items():
        if not ad.strip():
            raise PaketHatasi("belge adı boş")
        if not icerik:
            raise PaketHatasi(f"belge içeriği boş: {ad}")

    tampon = io.BytesIO()
    with zipfile.ZipFile(tampon, "w", zipfile.ZIP_DEFLATED) as z:
        for ad in sorted(belgeler):                      # sıra da deterministik
            bilgi = zipfile.ZipInfo(ad, date_time=(1980, 1, 1, 0, 0, 0))
            bilgi.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(bilgi, belgeler[ad])
    return tampon.getvalue()


def paketle(xml: bytes, belge_adi: str, tarih: date | None = None) -> dict[str, str]:
    """Tek UBL XML → `SendDocument`'ın `document` alanına hazır sözlük.

    `belge_adi` uzantısız verilir (genelde belgenin UUID'i); zip adı ondan türer.
    """
    if not isinstance(xml, bytes):
        raise PaketHatasi("xml baytlar olmalı (str değil) — kodlama belirsizliği yaratır")
    if not xml.strip():
        raise PaketHatasi("xml boş")
    ad = belge_adi.strip()
    if not ad:
        raise PaketHatasi("belge adı boş")
    if "/" in ad or "\\" in ad:
        raise PaketHatasi(f"belge adında yol ayracı olamaz: {ad}")

    ham_zip = zip_kur({f"{ad}.xml": xml})
    return {
        "fileName": f"{ad}.zip",
        "binaryData": base64.b64encode(ham_zip).decode("ascii"),
        "contentType": "base64",
        # 🔴 ZIP'in HAM baytları üstünde MD5 — base64 metni üstünde değil (tuzak a+b)
        "hash": hashlib.md5(ham_zip).hexdigest().upper(),
        "currentDate": (tarih or date.today()).isoformat(),
    }


def _main(argv: list[str]) -> int:
    """Kuru koşum: bir XML dosyasını paketler, ÖZETİNİ basar — içeriği basmaz."""
    import sys
    from pathlib import Path

    if len(argv) < 2:
        print("kullanım: elogo_paket.py <xml-yolu> [belge-adı]", file=sys.stderr)
        return 2
    yol = Path(argv[0])
    ad = argv[1] if len(argv) > 1 else yol.stem
    try:
        p = paketle(yol.read_bytes(), ad)
    except (PaketHatasi, OSError) as e:
        print(f"⛔ paketlenemedi: {e}", file=sys.stderr)
        return 1
    print(f"dosya : {p['fileName']}")
    print(f"özet  : {p['hash']}  (MD5, zip baytları üstünde)")
    print(f"tarih : {p['currentDate']}")
    print(f"boyut : {len(p['binaryData'])} karakter base64")
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(_main(sys.argv[1:]))
