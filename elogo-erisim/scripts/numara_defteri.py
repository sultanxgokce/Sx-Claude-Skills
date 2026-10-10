#!/usr/bin/env python3
"""Fatura numarası sayacı — SERVİS yolunda sırayı BİZ tutarız.

🔴 KARAR (Sultan + MUAVİN, 2026-08-22): portalın serisi (ör. `<PORTAL-SERİSİ>`) servis yolunda
   **KULLANILMAZ**. Servis yoluna ÖZEL ikinci bir ön ek tanımlanır ve o seriden
   portal üzerinden **ASLA** numara alınmaz.
   Gerekçe 1 — ÇAKIŞMA: aynı seriyi iki dağıtıcı kullanırsa mükerrer numara doğar;
     bu mali bir sorundur. Ayrı seri = çakışma **yapısal olarak imkânsız**
     (disipline değil, imkânsızlığa dayanır).
   Gerekçe 2 — TARİH SIRASI: faturalarımız 20.08 tarihli. Mevcut seride daha geç
     tarihli numara varsa, geriye dönük numara vermek numara-tarih sırasını bozar.
     Yeni seride ilk fatura olduğu için bu sorun doğmaz.

🔴 ÖLÇÜLDÜ 2026-08-22 (demo, tek belge, servis serisi canlıdakiyle aynı tanımlı):
   `cbc:ID` **BOŞ** gönderilince e-Logo belgeyi **REDDEDİYOR** —
   `resultCode=-1` · *"Numara (cbc:ID) formatı … 16 karakter (Örneğin; ABC2018000000001)
   olmalıdır."*
   → **Numarayı BİZ veriyoruz.** Web-Servis serisinde e-Logo numara ATAMIYOR;
   bu sayaç defteri ZORUNLUDUR ve kaybolursa mükerrer numara riski gerçektir
   (bkz. "boş defter kapısı").

Biçim: <ÖNEK><YIL><9 hane> = 16 karakter  →  ilk numara `<ÖNEK>2026000000001`.
e-Logo'nun beyan ettiği kural: 3 serbest harf + 4 hane yıl + 9 hane rakam.
Defter append-only; verilen numara SİLİNMEZ (iz kaybolmasın).
"""
import contextlib, fcntl, json, os, re, datetime

DEFTER = os.path.expanduser("~/.config/elogo-numara-defteri.jsonl")
BICIM = re.compile(r"^[A-Z]{3}\d{4}\d{9}$")


def _satirlar():
    """Defter satırları, DOSYADAKİ SIRAYLA. Her satıra `_ix` (0'dan artan konum) eklenir.

    🔴 NİÇİN `_ix` (ölçüldü 2026-08-23): iptalin hangi tahsisi kapattığı ZAMAN DAMGASIYLA
    belirleniyordu (`i.tarih >= k.tarih`) ve damga SANİYE çözünürlüklüydü. Aynı saniyede iki
    olay bu sistemde ölçülmüş bir gerçektir — defterin ilk iki satırı aynı saniyeyi taşıyor.
    Bir iptal ile YENİ bir tahsis aynı saniyeye düşse, iptal yeni tahsisi de yutardı ve
    C8 (mükerrer numara) aynen geri gelirdi.
    Doğru ölçü zaman değil SIRA'dır: defter append-only olduğu için dosyadaki konum,
    olayların gerçek sırasının kendisidir ve çözünürlük sorunu yoktur.
    ⚠️ Bu, eski satırlar için de çalışır — `seq` alanı eklemeye gerek yok, konum zaten var.
    """
    if not os.path.exists(DEFTER):
        return []
    with open(DEFTER, encoding="utf-8") as f:
        out = []
        for i, satir in enumerate(f):
            if not satir.strip():
                continue
            k = json.loads(satir)
            k["_ix"] = len(out)
            out.append(k)
    return out


@contextlib.contextmanager
def _kilit():
    """🔴 NUMARA ÜRETİMİ TEK KRİTİK BÖLGEDİR — oku · üret · yaz · doğrula.

    Ölçüldü 2026-08-23 (derin kazı A1): bu dosyada HİÇ kilit yoktu (`flock` araması 0
    eşleşme). İki süreç aynı anda `son_numara()` okursa **ikisi de aynı sırayı** üretir.
    `dogrula()` yazımdan SONRA koştuğu için ikinci süreç patlar — ama BİRİNCİ süreç
    numarayı çoktan almış, XML'i yazmış, hatta GÖNDERMİŞ olabilir. Yani değişmez
    kusuru bildirir ama zararı önlemez.

    Kilit AYRI bir dosyada (`<defter>.kilit`): defterin kendisini kilitlemek, salt-okur
    denetim çağrılarını da bekletirdi. Kilit dosyası defter silinse bile kalır.
    """
    yol = DEFTER + ".kilit"
    os.makedirs(os.path.dirname(yol) or ".", exist_ok=True)
    f = open(yol, "a+")
    try:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        os.chmod(yol, 0o600)
        yield
    finally:
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        f.close()


def _gecersizler() -> set:
    """`duzelt()` ile GEÇERSİZ işaretlenmiş satırların konumları.

    🔴 Satır SİLİNMEZ, işaretlenir — C9'un kendi kuralı ("iptal gizlemez, işaretler")
    düzeltmeye de uygulanır. 2026-08-23'te mükerrer bir satırı diskten SİLDİM; kendi
    koyduğum kurala aykırıydı ve o gün kodda `duzelt()` diye bir fonksiyon yoktu.
    """
    return {k["hedef_ix"] for k in _satirlar()
            if k.get("tur") == "gecersiz" and isinstance(k.get("hedef_ix"), int)}


#: Kesim defteri — bir numaranın GERÇEKTEN gönderilip gönderilmediğinin ikinci tanığı.
#: İptal kapısı buna bakar; defterin kendi sözüne güvenmek tek-tanıklıktır.
KESIM_DEFTERI = os.path.expanduser("~/.config/arcelik-kesim-defteri.jsonl")


def _kesilmis_numaralar() -> set:
    """Kesim defterinde 'kesildi' damgası taşıyan fatura numaraları."""
    out = set()
    try:
        with open(KESIM_DEFTERI, encoding="utf-8") as f:
            for s in f:
                if not s.strip():
                    continue
                k = json.loads(s)
                if k.get("durum") == "kesildi" and k.get("fatura_no"):
                    out.add(k["fatura_no"])
    except OSError:
        pass
    return out


def _iptal_kayitlari() -> list:
    """Ham iptal kayıtları."""
    return [k for k in _satirlar() if k.get("tur") == "iptal"]


def iptalli_mi(kayit: dict) -> bool:
    """Bu TAHSİS iptal edilmiş mi?

    🔴 İKİ KUSUR BURADA KAPANDI (ölçüldü 2026-08-23, ikisi de canlıda üretildi):
    1. İptali yalnız NUMARA ile tutmak → o numaranın SONRAKİ tahsisini de iptalli sanıp
       sayaçtan düşürüyordu; aynı numara ikinci kez verildi.
    2. Yalnız (numara, sap) çiftine bakmak → iptal edilmiş bir tahsisin AYNISI yeniden
       yazılırsa, hatalı yeni kayıt eski iptalin ARKASINA SAKLANIYORDU. Mükerrer numara
       denetimden görünmez hâle geliyordu — sessiz maskeleme, en tehlikeli sınıf.
    Doğru kural: iptal, KENDİSİNDEN ÖNCEKİ tahsisi öldürür. Sonrasını ilgilendirmez.
    """
    if kayit.get("_ix") in _gecersizler():
        return True                       # geçersiz işaretli satır tahsis saymaz
    n, sap, ix = kayit.get("numara"), kayit.get("sap"), kayit.get("_ix", -1)
    for i in _iptal_kayitlari():
        # 🔴 SIRA, ZAMAN DEĞİL: iptal yalnız KENDİNDEN ÖNCE yazılmış tahsisi kapatır.
        #    Eskiden `i.tarih >= k.tarih` idi; saniye çözünürlüğü yüzünden aynı saniyeye
        #    düşen YENİ bir tahsis de yutuluyordu (C8'in geri dönüş yolu).
        if i.get("numara") == n and i.get("sap") == sap and i.get("_ix", -1) > ix:
            return True
    return False


def iptal_et(numara: str, gerekce: str) -> dict:
    """VERİLMİŞ ama GÖNDERİLMEMİŞ bir numarayı serbest bırakır (append-only iptal kaydı).

    🔴 NİÇİN VAR (2026-08-23): numara, belge gönderilmeden ÖNCE veriliyor. Gönderim
    sırası değişirse (araya bir belge girerse) verilmiş-ama-gönderilmemiş numara
    seride BOŞLUK bırakır — boşluk mali olarak kapatılamaz. İptal, boşluğu doğmadan
    kapatır.

    🔴 İKİ KAPI — ikisi de geçilmeden iptal YOK:
      (a) numara defterde VERİLMİŞ olmalı (var olmayan numara iptal edilemez)
      (b) numara KESİM DEFTERİNDE 'kesildi' damgası TAŞIMAMALI — yani gönderilmemiş
          olmalı. Gönderilmiş numaranın iptali muhasebe kaydını yalanlar; o iş
          e-fatura iptali/iade faturasıdır, defter kaydı değildir.
    ⚠️ İkinci kapı DEFTERİN KENDİ SÖZÜNE değil, AYRI bir tanığa (kesim defteri) dayanır.
    """
    kayitlar = _satirlar()
    verilen = [k for k in kayitlar if k.get("numara") == numara and k.get("tur") != "iptal"]
    if not verilen:
        raise RuntimeError(f"iptal edilemez: {numara} defterde VERİLMİŞ değil — DURULDU")
    if iptalli_mi(verilen[-1]):
        raise RuntimeError(f"{numara} (SAP {verilen[-1].get('sap')}) zaten iptal edilmiş — DURULDU")
    if numara in _kesilmis_numaralar():
        raise RuntimeError(
            f"🔴 {numara} KESİM DEFTERİNDE 'kesildi' — gönderilmiş bir numara iptal EDİLEMEZ. "
            "Gerekiyorsa yol e-fatura iptali/iade faturasıdır, defter kaydı değil. DURULDU")
    if not gerekce or len(gerekce) < 10:
        raise RuntimeError("iptal gerekçesi ZORUNLU (en az 10 karakter) — DURULDU")
    kayit = {"tur": "iptal", "numara": numara, "onek": verilen[-1].get("onek"),
             "yil": verilen[-1].get("yil"), "sira": verilen[-1].get("sira"),
             "sap": verilen[-1].get("sap"), "gerekce": gerekce,
             "tarih": datetime.datetime.now().isoformat(timespec="seconds"),
             "veren": "MUHASIP/servis"}
    with open(DEFTER, "a", encoding="utf-8") as f:
        f.write(json.dumps(kayit, ensure_ascii=False) + "\n")
    os.chmod(DEFTER, 0o600)
    return kayit


def son_numara(onek: str, yil: int) -> int:
    """Bu ön ek+yıl için verilmiş EN BÜYÜK sıra; hiç yoksa 0."""
    en = 0
    for k in _satirlar():
        if k.get("tur") == "iptal" or iptalli_mi(k):   # iptalli tahsis sırayı TUTMAZ
            continue
        if k.get("onek") == onek and k.get("yil") == yil:
            en = max(en, int(k.get("sira", 0)))
    # 🔴 Taban iki defterin BÜYÜĞÜ: numara defteri bayatlarsa kesim defteri onu yukarı çeker.
    on = f"{onek}{yil}"
    for n in _kesilmis_numaralar():
        if n.startswith(on) and n[len(on):].isdigit():
            en = max(en, int(n[len(on):]))
    return en


def sirada_ne_var(onek: str, yil: int | None = None) -> str:
    """Bir sonraki numarayı ÜRETİR ama DEFTERE YAZMAZ (önizleme içindir)."""
    yil = yil or datetime.date.today().year
    return f"{onek}{yil}{son_numara(onek, yil) + 1:09d}"


def canli_tahsisler() -> list:
    """İptal edilmemiş, yürürlükteki numara tahsisleri."""
    # 🔴 POZİTİF SÜZGEÇ (ölçüldü 2026-08-23): "tur != iptal" NEGATİF süzgeçti ve
    #    sonradan eklenen 'duzeltme' kaydını TAHSİS sandı (dogrula() None-numara ile
    #    çalıştı, sayım 3 yerine 4 gösterdi). Yeni bir kayıt türü eklenince negatif
    #    süzgeç sessizce yanılır; pozitif süzgeç yanılmaz.
    return [k for k in _satirlar()
            if k.get("tur") is None and k.get("numara") and not iptalli_mi(k)]


def tahsisler_ham(numara: str | None = None) -> list:
    """DENETİM okuması — iptalli olsun olmasın BÜTÜN tahsis satırları.

    🔴 KURAL (Sultan, 2026-08-23): **İPTAL BİR SATIRI GİZLEMEZ, İŞARETLER.**
    Append-only defterin bütün değeri "hiçbir şey kaybolmaz"dır; ama okuma tarafı
    iptalli satırları süzüp atıyorsa hatalı kayıt görünmez olur — defter yine yalan
    söyler, sadece daha kibarca. Kaydı silmemek yetmez, OKUMAYI da süzmemek gerekir.

    Bu yüzden iki AYRI okuma vardır ve karıştırılmaz:
      · `canli_tahsisler()` → "sıradaki numara ne?"  (iptalliyi SAYMAZ)
      · `tahsisler_ham()`   → "bu defterde ne oldu?" (iptalliyi GÖSTERİR)
    """
    return [k for k in _satirlar()
            if k.get("tur") is None and k.get("numara")
            and (numara is None or k.get("numara") == numara)]


def denetim() -> list:
    """Defterin TAM geçmişini sınar. İptalin arkasına saklanan kusuru arar.

    Döndürdüğü her satır bir ANOMALİ'dir — boş liste "temiz" demektir.
    `dogrula()` "bugün gönderim güvenli mi" sorusunu yanıtlar; bu ise
    "bu defterde açıklanamayan bir şey oldu mu" sorusunu.
    """
    anomali = []
    gecmis = {}
    for k in tahsisler_ham():
        gecmis.setdefault(k["numara"], []).append(k)
    for numara, satirlar in sorted(gecmis.items()):
        if len(satirlar) < 2:
            continue
        # Aynı numara birden çok kez verilmişse: her ÖNCEKİ tahsis, sonraki verilmeden
        # ÖNCE iptal edilmiş olmalı. Değilse mükerrer numara vardır ve iptal onu ÖRTER.
        for onceki, sonraki in zip(satirlar, satirlar[1:]):
            iptaller = [i for i in _iptal_kayitlari()
                        if i.get("numara") == numara and i.get("sap") == onceki.get("sap")
                        and onceki.get("_ix", -1) < i.get("_ix", -1) < sonraki.get("_ix", 10**9)]
            if not iptaller:
                anomali.append(
                    f"🔴 {numara}: SAP {onceki.get('sap')} → SAP {sonraki.get('sap')} yeniden "
                    "verilmiş ama ARADA İPTAL YOK — mükerrer numara, iptalin arkasında değil.")
    for i in _iptal_kayitlari():
        if not tahsisler_ham(i.get("numara")):
            anomali.append(f"🔴 iptal kaydı var ama tahsisi YOK: {i.get('numara')}")
    return anomali


def dogrula() -> None:
    """🔴 DEĞİŞMEZ: yürürlükteki tahsislerde AYNI NUMARA İKİ KEZ GEÇEMEZ.

    Bu kontrol, sayaç mantığındaki bir hatanın deftere mükerrer numara yazmasını
    yakalar. Sayacın kendi sözüne güvenmek yetmez — defter kendi kendini sınar.
    Kaynak: 2026-08-23'te tam bu hata üretildi ve buradan yakalanmadığı için ancak
    çıktıya bakılarak fark edildi.
    """
    gorulen = {}
    for k in canli_tahsisler():
        n = k.get("numara")
        if n in gorulen:
            raise RuntimeError(
                f"🔴 DEFTER BOZUK — MÜKERRER NUMARA {n}: SAP {gorulen[n]} ve SAP {k.get('sap')}. "
                "Numara sırası güvenilmez; gönderim YAPILMAZ. DURULDU")
        gorulen[n] = k.get("sap")
    # 🔴 İkinci arm: iptalin ARKASINA saklanmış kusur (Sultan kuralı 2026-08-23).
    a = denetim()
    if a:
        raise RuntimeError("🔴 DENETİM KIRMIZI — " + " | ".join(a) + " DURULDU")


def numara_ver(onek: str, sap: str, tutar: str, yil: int | None = None,
               ilk_kullanim_onayi: bool = False, tarih: str | None = None,
               yil_devri_onayi: bool = False) -> str:
    """Numarayı üretir ve deftere İŞLER. Aynı SAP belge için iki kez numara VERMEZ.

    🔴 BOŞ DEFTER KAPISI (MUAVİN sorusu, 2026-08-22): defter boşsa iki ihtimal vardır —
    (a) gerçekten ilk kullanım · (b) **defter KAYBOLDU**. İkisi dışarıdan aynı görünür.
    Ayırt edemediğimiz için sessizce 1'den başlamak MÜKERRER NUMARA üretebilir.
    Bu yüzden boş defterde numara verilmez; `ilk_kullanim_onayi=True` açıkça verilmelidir.
    """
    # 🔴 YIL, BELGENİN YILIDIR — bugünün yılı DEĞİL (ölçülmemiş boşluk, kapatıldı 2026-08-23).
    # e-Logo'nun biçim kuralı yılı açıkça "faturanın AİT OLDUĞU yıl" diye tanımlıyor; oysa
    # varsayılan `date.today().year` idi ve fatura tarihi ayrı bir parametreydi. 31.12'de
    # düzenlenip 02.01'de numaralanan bir belge → numarada 2027, belgede 2026 → biçim kuralı
    # ihlali VE numara-tarih sırası bozulur. Kimse bu çelişkiyi kontrol etmiyordu.
    if tarih:
        belge_yili = int(str(tarih)[:4])
        if yil is None:
            yil = belge_yili
        elif yil != belge_yili:
            raise RuntimeError(
                f"🔴 YIL ÇELİŞKİSİ: numara yılı {yil}, belge tarihi {tarih} ({belge_yili}). "
                "Numaranın yılı BELGENİN yılı olmalıdır. DURULDU")
    if yil is None:
        yil = datetime.date.today().year
    with _kilit():
        return _numara_ver_kilitli(onek, sap, tutar, yil, ilk_kullanim_onayi, yil_devri_onayi)


def _numara_ver_kilitli(onek, sap, tutar, yil, ilk_kullanim_onayi, yil_devri_onayi=False):
    """`numara_ver`in kilit ALTINDA koşan gövdesi. Doğrudan çağrılmaz."""
    if not _satirlar() and not ilk_kullanim_onayi:
        raise RuntimeError(
            "DEFTER BOŞ — bu ya ilk kullanım ya da defter KAYBOLDU; ikisi aynı görünür. "
            "Sessizce 1'den başlamak mükerrer numara üretebilir. "
            "Gerçekten ilk kullanımsa açık onay gerekir (--ilk-kullanim); "
            "değilse önce defteri yedekten geri getir. DURULDU")
    for k in _satirlar():
        if k.get("tur") == "iptal" or iptalli_mi(k):   # iptalli tahsis SAP'ı bloklamaz
            continue
        if k.get("sap") == sap:
            raise RuntimeError(
                f"bu fiş paketi için zaten numara verilmiş: {k['numara']} (SAP {sap}) — DURULDU")
    sira = son_numara(onek, yil) + 1
    # 🔴 YIL DEVRİ KAPISI: yeni yılın İLK numarası hiçbir insan onayından geçmiyordu.
    # Boş-defter kapısı burada TETİKLENMEZ (defter dolu görünür) — ama sayaç 1'e döner ve
    # bu, "defter kayboldu" hâlinden dışarıdan ayırt edilemez. Ayrı bir onay ister.
    if sira == 1 and any(k.get("onek") == onek and k.get("yil") != yil
                         for k in canli_tahsisler()):
        if not yil_devri_onayi:
            raise RuntimeError(
                f"🔴 YIL DEVRİ: {onek}/{yil} serisinin İLK numarası veriliyor, ama defterde "
                f"{onek} serisinin başka yıllardan kayıtları var. Sayacın 1'e dönmesi doğru "
                "olabilir (yeni yıl) ya da defterin bayat olduğunu gösterebilir; ikisi "
                "dışarıdan aynı görünür. Açık onay gerekir (--yil-devri). DURULDU")
    numara = f"{onek}{yil}{sira:09d}"
    # 🔴 İKİNCİ TANIK — GÖNDERİLMİŞ NUMARA YENİDEN VERİLEMEZ (derin kazı A5, 2026-08-23).
    # Ölçülen risk: defter YEDEKTEN geri yüklenirse sayaç geriye düşer ve canlıda gitmiş bir
    # numarayı "sıradaki" sanar. Bu, boş-defter kapısına YAKALANMAZ (defter dolu görünür).
    # Asimetri kanıtlıydı: `iptal_et` kesim defterine bakıyordu, `numara_ver` BAKMIYORDU —
    # üstelik `_kesilmis_numaralar()` bu dosyada zaten mevcut, yalnız çağrılmıyordu.
    kesilmis = _kesilmis_numaralar()
    if numara in kesilmis:
        raise RuntimeError(
            f"🔴 {numara} KESİM DEFTERİNDE 'kesildi' — bu numara zaten GÖNDERİLMİŞ. "
            "Sayaç geriye düşmüş olabilir (defter yedekten mi dönüldü?). "
            "Mükerrer numara üretmemek için DURULDU; önce defteri gerçek duruma getir.")
    if not BICIM.match(numara):
        raise RuntimeError(f"numara biçimi hatalı: {numara} (beklenen <ÖNEK><YIL><9 hane>)")
    kayit = {"numara": numara, "onek": onek, "yil": yil, "sira": sira, "sap": sap,
             "tutar": tutar, "tarih": datetime.datetime.now().isoformat(timespec="seconds"),
             "veren": "MUHASIP/servis"}
    os.makedirs(os.path.dirname(DEFTER), exist_ok=True)
    with open(DEFTER, "a", encoding="utf-8") as f:
        f.write(json.dumps(kayit, ensure_ascii=False) + "\n")
    os.chmod(DEFTER, 0o600)
    dogrula()                     # yazdıktan HEMEN sonra sına — bozuk defterle devam etme
    return numara


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 2 and sys.argv[1] == "sirada":
        print(sirada_ne_var(sys.argv[2]))
    else:
        for k in _satirlar():
            if k.get("tur") == "iptal":
                print(f"  ⊘ İPTAL {k['numara']}  SAP={k['sap']}  · {k.get('gerekce','')}")
            elif k.get("tur") == "duzeltme":
                kal = k.get("kaldirilan", {})
                print(f"  ✎ DÜZELTME {kal.get('numara','?')}  SAP={kal.get('sap','?')} "
                      f"KALDIRILDI · {k.get('gerekce','')[:90]}")
            else:
                bayrak = " ⊘(iptalli)" if iptalli_mi(k) else ""
                print(f"  {k['numara']}  SAP={k['sap']}  {k['tutar']}  {k['tarih']}{bayrak}")
        print(f"  (toplam {len(_satirlar())} kayıt · {len(canli_tahsisler())} yürürlükte "
              f"· defter: {DEFTER})")
        print(f"  ── denetim okuması (iptalliler GİZLENMEZ, {len(tahsisler_ham())} tahsis satırı) ──")
        for k in tahsisler_ham():
            print(f"     {'⊘' if iptalli_mi(k) else '·'} {k['numara']}  SAP={k['sap']}")
        dogrula()
        print("  ✓ değişmez GEÇTİ: yürürlükteki numaralar benzersiz + denetim temiz")


def duzelt(hedef_ix: int, gerekce: str) -> dict:
    """Bir satırı GEÇERSİZ işaretler. 🔴 SATIR SİLMEZ — iz kaybolmaz.

    NİÇİN VAR (ölçüldü 2026-08-23): defterde bir `duzeltme` kaydı vardı ama onu üreten
    HİÇBİR KOD yoktu — o gece mükerrer satır diskten **elle silinmiş**, yerine elle bir
    mezar taşı yazılmıştı. Yani append-only bir SÖZLEŞMEYDİ, mekanizma değildi.
    C9'un kendi kuralı ("iptal bir satırı GİZLEMEZ, İŞARETLER") düzeltmeye de uygulanır:
    silmek, okumayı süzmekten bile beterdir — satırın kendisi kaybolur.

    İPTAL ile farkı: `iptal_et` bir TAHSİSİ geri alır (numara serbest kalır, kayıt doğruydu).
    `duzelt` satırın KENDİSİNİN hatalı yazıldığını söyler (hiç olmamalıydı).
    """
    with _kilit():
        satirlar = _satirlar()
        if not (0 <= hedef_ix < len(satirlar)):
            raise RuntimeError(f"düzeltilecek satır yok: konum {hedef_ix} — DURULDU")
        hedef = satirlar[hedef_ix]
        if hedef.get("tur") is not None:
            raise RuntimeError(
                f"konum {hedef_ix} bir TAHSİS değil (tur={hedef.get('tur')}) — DURULDU")
        if hedef_ix in _gecersizler():
            raise RuntimeError(f"konum {hedef_ix} zaten geçersiz işaretli — DURULDU")
        if not gerekce or len(gerekce) < 10:
            raise RuntimeError("düzeltme gerekçesi ZORUNLU (en az 10 karakter) — DURULDU")
        # 🔴 GÖNDERİLMİŞ SATIR DÜZELTİLEMEZ — ikinci tanık (kesim defteri) sorulur.
        if hedef.get("numara") in _kesilmis_numaralar():
            raise RuntimeError(
                f"🔴 {hedef.get('numara')} KESİM DEFTERİNDE 'kesildi' — gönderilmiş bir "
                "kaydı geçersiz saymak muhasebe kaydını yalanlar. DURULDU")
        kayit = {"tur": "gecersiz", "hedef_ix": hedef_ix,
                 "hedef": {k: v for k, v in hedef.items() if k != "_ix"},
                 "gerekce": gerekce,
                 "tarih": datetime.datetime.now().isoformat(timespec="seconds"),
                 "veren": "MUHASIP/servis"}
        with open(DEFTER, "a", encoding="utf-8") as f:
            f.write(json.dumps(kayit, ensure_ascii=False) + "\n")
        os.chmod(DEFTER, 0o600)
        dogrula()
        return kayit
