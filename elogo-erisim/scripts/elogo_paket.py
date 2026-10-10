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
import xml.etree.ElementTree as ET
import zipfile
from datetime import date

CBC = "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"

# 🔴 AD TAVANI — ÖLÇÜLEN DEĞER, SÖZLEŞMEDEN OKUNAN DEĞİL.
#    Uygulama Arabirim Dokümanı dosya adı için bir sınır YAZMIYOR; sınırın
#    varlığı canlı bir retten öğrenildi (MUHASİP, mmex, 08.10.2026):
#       56 hane  16 haneli belge numarası + DÖRT irsaliye numarası + ".zip"
#                → resultCode=-1 · "Dosya adı çok uzun" · belge hatta GİRMEDİ
#       47 hane  16 haneli belge numarası + ÜÇ irsaliye numarası + ".zip"
#                → geçmiş (emsal)
#    (Numaraların kendisi buraya YAZILMAZ: bu raf 16 kutunun ortak gördüğü
#     yerdir, müşteri/belge verisi burada yaşamaz — İ1. Şekli yeter.)
#    🔴 GERÇEK SINIR ÖLÇÜLMEDİ: 47 ile 56 arasında bir yerde. Buraya ölçülmüş
#    GEÇEN değeri yazıyoruz; aradaki 8 haneyi tahminle doldurmak, ölçmediğimiz
#    bir şeye sert kural demek olurdu (K01). Tavan ancak yeni bir ÖLÇÜMLE
#    yükseltilir — "muhtemelen 50 de geçer" bu dosyada gerekçe değildir.
#    Sayım `.zip` uzantısı DAHİL yapılır; iki ölçüm de öyle yapıldı.
AD_TAVANI = 47


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


def belge_adini_turet(xml: bytes) -> str:
    """Belgenin KENDİ kimliğinden paket adı türetir. Türetemezse DURUR.

    NİÇİN BU FONKSİYON VAR
    ──────────────────────
    Eskiden paket adının varsayılanı **dosya adıydı** (`yol.stem`). Dosya adı
    belgenin bir özelliği değil, onu diske yazan tarafın keyfidir; SAP'tan gelen
    bir fatura dört irsaliye numarasını adına ekleyince ad 56 haneye çıktı ve
    e-Logo belgeyi REDDETTİ. Asıl zarar retten büyük: **numara zaten verilmiş**
    oluyor. Sıralı gönderimde birinci belge geçip ikincisi ad yüzünden düşerse
    numara dizisinde boşluk kalır — ve o boşluğun sebebi faturanın içeriğinde
    aranır, oysa hata adda olmuştur.

    ZİNCİR — iki basamak, sonra DUR
    ───────────────────────────────
      1. `cbc:ID`   → belgenin kendi numarası (bu hesapta her zaman 16 hane)
      2. `cbc:UUID` → belgenin tekil kimliği; e-Logo'nun numara ATADIĞI
                      hesap/seri için geçerli yol (bizim kutuda canlı vakası
                      yok, sınavı hermetiktir — ölçüm: MUHASİP, 09.10.2026)
      3. **DUR**    → ne numara ne kimlik varsa ad ÜRETİLMEZ

    🔴 3. BASAMAK ÖLÜ KOD DEĞİL, TAŞIYICI. `elogo_gonder.py` komut satırından
    **herhangi** bir XML kabul eder; kendi üreticimizin hiç üretmediği bir belge
    de oraya verilebilir. O belgede numara yoksa eski kod dosya adına düşerdi —
    yani düzelttiğimiz kusurun tam kendisine. Burada durmak, kusurun geri
    gelebileceği tek deliği kapatır.

    🔴 BOŞ ALAN = YOK OLAN ALAN. `<cbc:ID/>` elemanı VAR ama değeri boşsa bu
    "numara yok" demektir, "boş numara" demek değildir. İkisini ayırmamak şu
    hatayı üretirdi: paket adı `.zip` olurdu. Üstelik bu hesap boş numarayı
    zaten reddediyor (ölçüldü: `resultCode=-1` · "Numara (cbc:ID) formatı …
    16 karakter olmalıdır").

    🔴 YALNIZ KÖK ALTINDAKİ alanlar okunur. `cbc:ID` fatura içinde onlarca
    yerde geçer (satıcı, alıcı, her kalem, her vergi). Ağaçta arama yapmak
    belge numarası yerine ilk kalemin sıra numarasını getirirdi; bu, yanlış
    adla geçen bir gönderim demekti — yani sessiz, en kötü cinsten bir hata.

    🔴 HESAP POLİTİKASINA KARAR VERMEZ. Burada "bu hesap numarayı kendi mi
    atıyor" sorusu sorulmaz; yalnız belgede yazılı olan okunur. Politika
    çağıranın ve hesabın işidir, paketleyicinin değil.
    """
    try:
        kok = ET.fromstring(xml)
    except ET.ParseError as e:
        raise PaketHatasi(
            f"belge XML olarak okunamadı, paket adı türetilemez: {e}"
        ) from e

    def kok_alani(ad: str) -> str:
        # Yalnız DOĞRUDAN çocuklar — ağaçta arama bilerek yapılmıyor.
        for c in kok:
            if c.tag == f"{{{CBC}}}{ad}":
                return (c.text or "").strip()
        return ""

    for alan in ("ID", "UUID"):
        d = kok_alani(alan)
        if d:
            return d

    raise PaketHatasi(
        "paket adı türetilemedi: belgenin kökünde ne numara (cbc:ID) ne tekil "
        "kimlik (cbc:UUID) var.\n"
        "   Ad UYDURULMADI ve dosya adına DÜŞÜLMEDİ — düzeltilen kusur tam o idi.\n"
        "   Ya belgeye numarasını yaz, ya adı açıkça ver (--belge-adi)."
    )


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
    # 🔴 Ad artık DIŞARIDAN gelen bir belgenin içinden de türeyebiliyor
    #    (`belge_adini_turet`). Bu alan `elogo_gonder.zarf_kur` içinde SOAP
    #    zarfına kaçışsız gömülüyor; etiket için zaten var olan kontrolün
    #    aynısı buraya da gerekli oldu. Değişiklik yeni bir titizlik değil,
    #    yeni açılan yüzeyin kapatılmasıdır.
    if any(c in ad for c in "<>&\"'"):
        raise PaketHatasi(f"belge adında zarfı bozacak karakter var: {ad}")
    if any(ord(c) < 32 for c in ad):
        raise PaketHatasi("belge adında yazdırılamaz karakter var")

    dosya_adi = f"{ad}.zip"
    # 🔴 UZUNLUK KAPISI — ret AĞA ÇIKTIKTAN SONRA düşüyor, numara ise o ana
    #    kadar verilmiş oluyor. Bu yüzden kapı burada: hiçbir bayt gitmeden,
    #    saf hesapla. Tavanın niçin 47 olduğu AD_TAVANI'nın başında yazılı.
    if len(dosya_adi) > AD_TAVANI:
        raise PaketHatasi(
            f"paket adı ölçülmüş güvenli tavanı aşıyor: {len(dosya_adi)} hane "
            f"> {AD_TAVANI} (.zip dahil) — gönderim YAPILMADI.\n"
            f"   Ölçülen: {AD_TAVANI} hane GEÇTİ, 56 hane e-Logo tarafından "
            f"REDDEDİLDİ. Aradaki değerler ÖLÇÜLMEDİ — bu adın reddedileceğini "
            f"BİLMİYORUZ, geçeceğini de.\n"
            f"   Kapı burada duruyor çünkü ret ancak ağa çıktıktan sonra düşer ve "
            f"belge numarası o ana kadar harcanmış olur; bilinmezlikte durmak, "
            f"numara dizisinde boşluk bırakmaktan ucuzdur.\n"
            f"   ad: {dosya_adi}\n"
            f"   Çare: adı belgenin kendi numarasına indir (--belge-adi), "
            f"irsaliye/sipariş numaralarını adın içine yığma. Tavanı yükseltmek "
            f"ayrı iştir ve yeni bir ÖLÇÜM ister."
        )

    ham_zip = zip_kur({f"{ad}.xml": xml})
    return {
        "fileName": dosya_adi,
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

    if len(argv) < 1:
        print("kullanım: elogo_paket.py <xml-yolu> [belge-adı]", file=sys.stderr)
        print("   ad verilmezse belgenin kendi numarasından (cbc:ID, yoksa cbc:UUID) türer.",
              file=sys.stderr)
        return 2
    yol = Path(argv[0])
    try:
        ham = yol.read_bytes()
        # 🔴 Varsayılan ad artık DOSYA ADI DEĞİL, belgenin kendi numarası.
        #    Eski `yol.stem` varsayılanı düzeltilen kusurun kaynağıydı.
        ad = argv[1] if len(argv) > 1 else belge_adini_turet(ham)
        p = paketle(ham, ad)
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
