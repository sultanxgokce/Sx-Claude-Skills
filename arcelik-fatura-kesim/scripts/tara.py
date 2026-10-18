#!/usr/bin/env python3
"""'Arçelik'ten kesilecek fatura var mı?' — tek komutluk cevap.

🔴 Kural 1: IADE PAKETI DOKUMU  -> KESİLMEZ (zarar). Sayıya girmez, ayrı satırda gösterilir.
🔴 Kural 2: 'Malzeme İade'      -> isim yanıltır, DÜZ FATURA olarak KESİLİR.
🔴 Kural 3: kesim defteri sorgulanır; kesilmişse listeye GİRMEZ.
Fail-closed: tanınmayan tip -> 'SOR' listesine düşer, asla 'kes' sayılmaz.
📝 Fatura talebi (Bizpuan · iskonto · klima montaj prim) -> ayrı başlık: kanonda KES, kalemi insan okur.
"""
import os, re, json, subprocess, unicodedata, urllib.request, urllib.parse, sys

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/140.0 Safari/537.36")
BASE = "https://outlook.office365.com/api/v2.0"
DEFTER_SH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "defter.sh")

#: 🔴 TÜRKÇE SADELEŞTİRME — desenden ÖNCE (2026-08-23'te eklendi, sınav yakaladı).
#: Eski desenler Türkçe harf VARYANTLARINI elle sayıyordu (`[İI]`, `F[İI]S?`) ve eksik
#: kalmıştı: `İADE PAKETİ DÖKÜMÜ` (Ö,Ü) ve `FİŞ PAKETİ DÖKÜMÜ` (Ş,Ö,Ü) desene UYMUYOR,
#: `SOR`a düşüyordu. 🔴 İade paketinin `SOR`a düşmesi görece iyi huyludur (kesilmez),
#: ama fiş paketinin `SOR`a düşmesi FATURA KAÇIRIR — ikisi de sessizdi.
#: Ders (muhafızda da aynısı çıktı): varyantı desende saymak yerine METNİ SADELEŞTİR.
#: 'ı' (U+0131) NFKD ile çözülmez; elle eşlenir.
_TR = (("ı", "i"), ("İ", "i"), ("ş", "s"), ("ğ", "g"), ("ç", "c"),
       ("ö", "o"), ("ü", "u"), ("â", "a"), ("î", "i"), ("û", "u"))


def sadelestir(metin: str) -> str:
    """Konu satırını aksansız-küçük ASCII'ye indirger. Desenler bu biçime yazılır."""
    s = (metin or "").lower()
    for a, b in _TR:
        s = s.replace(a, b)
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))


# 🔴 SIRA SÖZLEŞMESİ: iade paketi, fiş paketinden ÖNCE denenir — ikisi de "paketi dokumu"
#    taşır. Sıra bozulursa İADE PAKETİ FİŞ PAKETİ SAYILIR ve kesilir = zarar. Sınavda kapılı.
TIPLER = [
    ("iade_paketi",   re.compile(r"iade\s*paketi\s*doku?mu?"),         "KESME"),
    ("fis_paketi",    re.compile(r"fi[sz]?\s*paketi\s*doku?mu?"),      "KES"),
    ("malzeme_iade",  re.compile(r"malzeme\s*iade"),                   "KES"),
    # 🔴 FATURA TALEBİ — kanonda KES (Sultan 05.09 Bizpuan/iskonto · 14.10 klima montaj prim).
    #    Ayrı karar "TALEP": KESİLECEK sayısına GİRMEZ, SOR gürültüsüne de DÜŞMEZ. Neden ayrı:
    #    tutar ekte değil mail GÖVDESİNDE, tarih mailde SABİT → kalemi insan okur. 03.10'dan
    #    14.10'a kadar bu üç tip SOR'a düşüp elle yakalandı (görev gorev_01M4ZKQ1QTBG76GM4537QF7CE3).
    #    SIRA: `odul_puan` ("Bizpuan ÖDÜL") ve `uyari` ("Hatırlatma: … Fatura Talebi") ÖNCESİ.
    #    "Düzenlenmemiş Görünen … Faturalarınız" hatırlatmasında "fatura talebi" geçmez → buraya DÜŞMEZ.
    ("fatura_talebi_kes", re.compile(r"(bizpuan|iskonto|klima\s*montaj).*fatura\s*taleb"), "TALEP"),
    # 🔴 KAPSAM DIŞI (Sultan kararı 2026-08-24): mutabakat Sultan'ın işidir, bu tarayıcının
    #    değil. Gerekçe ölçülmüş: mutabakat, karşı tarafın kaydıyla BİZİM kaydımızı
    #    karşılaştırma işidir ve bizde o cari hesap kaydı YOKTUR. Ajan ancak PDF'i okur,
    #    DOĞRULAYAMAZ — doğrulanmamış bir "mutabıkız" beyanı mali risktir.
    #    ⚠️ ATLA burada "önemsiz" demek DEĞİL: 2026-08-24'te "(Hatırlatma-1-)" ile ikinci
    #    kez geldi ve cevapsızdı. Kapsam dışı olan şey unutulabilir; kayıt burada dursun.
    ("mutabakat",     re.compile(r"cari\s*hesap\s*mutabakat"),          "ATLA"),
    ("uyari",         re.compile(r"duzenlenmeyen|hatirlatma"),          "ATLA"),
    # ⚠️ SIRA: `mutabakat` `uyari`dan ÖNCEDİR. "(Hatırlatma-1-) Cari Hesap Mutabakatı"
    #    ikisine birden uyuyor; sıra bozulursa karar değişmez (ikisi de ATLA) ama ETİKET
    #    yanlış olur ve rapor "uyarı" der. Daha önemlisi: PAKET desenleri (iade/fiş/malzeme)
    #    `uyari`dan ÖNCEDİR ve öyle KALMALIDIR — "Hatırlatma: FİŞ PAKETİ DÖKÜMÜ" gibi bir
    #    konu `uyari`ya düşerse GERÇEK BİR FATURA ATLANIR. Sınavda kilitli.
    # ── ADLANDIRILMIŞ ATLA'lar (Sultan kararı 2026-08-24) ────────────────────────────
    # 🔴 NİÇİN "tanınmayan/SOR" değil de ADLANDIRILMIŞ ATLA: bu üç tip her taramada
    #    SOR listesine düşüyordu ve orası "para kokusu var, kural yok" bölümü. Her hafta
    #    aynı üç mail önümüze geliyordu ve hiçbiri fatura kesilecek belge değildi.
    #    Adlandırılmış ATLA, "sessizce yut" DEĞİLDİR: sayıda görünür, adı vardır, ve
    #    niçin atlandığı burada yazılıdır. Tanınmayan olarak bırakmak, gerçek bir SOR
    #    çıktığında onu gürültünün içinde kaybetmek olurdu.
    #
    # ⚠️ MUTABAKAT bir AKSİYON ister — fatura değil ama cevap bekliyor (bakiye teyidi).
    #    Bu tarayıcının işi "kesilecek fatura var mı"dır; mutabakatı cevaplamak Sultan'ın
    #    işidir ve bu satır onu ATLAMAZ, KAPSAM DIŞI bırakır. Fark önemli: kapsam dışı
    #    olan bir şey unutulabilir. 2026-08-24'te "(Hatırlatma-1-)" ile ikinci kez geldi.
    # Ödeme/denkleştirme dökümü. Fatura değil — ama İÇİNDE bizim fatura numaralarımız ve
    # ödeme durumları var (FGF serisi + tutar + durum). "Hangi faturam ödendi" sorusunun
    # cevabı burada; şimdilik kapsam dışı, ileride mutabakat yeteneği için kaynak.
    ("odeme_bildirimi", re.compile(r"odeme\s*/?\s*mahsuplastirma|mahsuplastirma\s*bildirim"), "ATLA"),
    # Hurda parça kargolama talebi — lojistik, belge değil.
    ("lojistik",      re.compile(r"fi[sz]\s*hurdas|hurda"),              "ATLA"),
    # Sultan 18.10: ödeme dökümü ve yıllık "harcanmayan puan" duyurusu fatura değil → adlandırılmış ATLA.
    #    Ödeme Listesi = net ödeme dökümü (mahsup sonrası); harcanmayan puan = çalışanlara harcama hatırlatması.
    #    SIRA: `fatura_talebi_kes`ten SONRA, `odul_puan`dan ÖNCE (yoksa "puan" SOR'a düşer).
    ("odeme_listesi", re.compile(r"odeme\s*listesi"),                   "ATLA"),
    ("puan_duyurusu", re.compile(r"harcanmayan\s*puan"),                "ATLA"),
    ("odul_puan",     re.compile(r"odul|puan"),                         "SOR"),
    ("fatura_talebi", re.compile(r"fatura\s*taleb"),                    "SOR"),
]


def tip_bul(konu):
    d = sadelestir(konu)
    for ad, desen, karar in TIPLER:
        if desen.search(d):
            return ad, karar
    return "taninmayan", "SOR"      # fail-closed

def sap_cikar(konu, ekler):
    for e in ekler:
        m = re.search(r"(\d{15,20})_", e or "")
        if m: return m.group(1)
    return ""


#: 🔴 MALZEME İADE'nin SAP'ı DOSYA ADINDA DEĞİL, PDF'İN İÇİNDE (ölçüldü 2026-09-20).
#:    Ek adı sabittir ("… MALZEME IADE DOKUMU.PDF") → `sap_cikar` boş döner → belge
#:    HER TARAMADA "SAP okunamadı" ile SOR'a düşerdi. SOR gürültü bölümüdür; orada
#:    iki tanınmış iadenin yanına YENİ ve KESİLMEMİŞ bir iade düşse kaybolurdu.
#:    (Aynı sınıf: "fiş paketi SOR'a düşerse fatura kaçar" — Türkçe-desen dersi.)
#: 🔴 ANAHTAR TEK KURALDAN: sıralı, "+" ile birleşik — kesim defteri de böyle yazıyor.
#:    İki taraf anahtarı farklı kurarsa kapı uydurma kırmızı üretir (18.09 dersi).
def sap_pdften(msg_id, tok):
    """Malzeme iade PDF'inin İÇİNDEN SAP Teslimat Belge No'ları. Okunamazsa "" döner.

    Dürüst sınır: pypdf yoksa ya da biçim tanınmazsa "" döner ve belge "ölçülemedi"
    olarak SOR'da kalır — SESSİZCE "kesilmiş" SAYILMAZ.
    """
    try:
        import base64, io
        from pypdf import PdfReader
    except Exception:
        return ""
    try:
        ekler = g(f"{BASE}/me/messages/{urllib.parse.quote(msg_id)}/attachments", tok).get("value", [])
        for e in ekler:
            if not str(e.get("Name", "")).lower().endswith(".pdf"):
                continue
            ham = base64.b64decode(e.get("ContentBytes") or "")
            if not ham:
                continue
            t = "\n".join((sf.extract_text() or "") for sf in PdfReader(io.BytesIO(ham)).pages)
            saplar = sorted(set(re.findall(r"\b(\d{8})\b\s+İlk", t)))
            if not saplar:
                saplar = sorted(set(re.findall(r"\b(8403\d{4})\b", t)))
            if saplar:
                return "+".join(saplar)
    except Exception:
        return ""
    return ""

# Sultan beyanı 2026-08-22: bu tarihten ÖNCEKİ tüm paketler kesilmiştir.
# Bu bir BEYANDIR, ölçüm değil — o yüzden sessizce yutulmaz, ayrı satırda gösterilir.
CIZGI = os.environ.get("ARCELIK_KESIM_CIZGISI", "2026-08-20")


#: Ölçülemeyen SAP'lar — her biri (sap, neden). BOŞ DEĞİLSE tarama güvenilmez sayılır.
OLCULEMEDI = []


def kesilmis_mi(sap):
    """ÜÇ DURUM: True=kesilmiş · False=kesilmemiş · None=ÖLÇÜLEMEDİ (asla "kesilmiş" değil).

    🔴 NİÇİN ÜÇ (ölçüldü 2026-08-23, derin kazı): burada `return r.returncode != 0` yazıyordu.
    Defter okunamazsa / izin düşerse / bash patlarsa rc≠0 gelir ve fonksiyon **"kesilmiş"**
    derdi; çağıran da o faturayı `continue` ile **sessizce düşürürdü**. Yani bir ALTYAPI
    HATASI, "bu fatura zaten kesilmiş" İŞ KARARINA dönüşüyordu — parasal, sessiz, tek yönlü.
    Firsthand kanıt: defter yolu okunamaz yapıldığında fonksiyon True döndü.

    Becerinin kendi son satırı bunu zaten yasaklıyordu: *"Ölçemediğine 'yok' deme,
    'ölçemedim' de."* Kod o kuralı ihlal ediyordu; artık etmiyor.
    """
    if not sap:
        return None                              # SAP okunamadı → SOR tarafına
    try:
        r = subprocess.run(["bash", DEFTER_SH, "sor", sap],
                           capture_output=True, text=True, timeout=20)
    except Exception as e:
        OLCULEMEDI.append((sap, f"defter çağrılamadı: {type(e).__name__}"))
        return None
    if r.returncode == 0:
        return False                             # defterde yok → kesilmemiş
    if r.returncode == 1:
        return True                              # defterde 'kesildi' → DUR
    if r.returncode == 3:
        OLCULEMEDI.append((sap, "defterde İPTAL kaydı — insan kararı gerekir"))
        return None
    OLCULEMEDI.append((sap, f"defter rc={r.returncode} · {(r.stderr or r.stdout).strip()[:60]}"))
    return None

#: Talep türü → kesim defterindeki anahtar öneki (defterde ölçüldü 15.10:
#: BIZPUAN-2026-08 · ISKONTO-2026-08 · KLIMA-MONTAJ-PRIM-2026-10-13).
TALEP_ONEK = {"bizpuan": "BIZPUAN-", "iskonto": "ISKONTO-", "klima": "KLIMA-MONTAJ-PRIM-"}


def talep_turu(konu):
    d = sadelestir(konu)
    for tur in TALEP_ONEK:
        if tur in d:
            return tur
    return "?"


AYLAR = {"ocak": 1, "subat": 2, "mart": 3, "nisan": 4, "mayis": 5, "haziran": 6, "temmuz": 7,
         "agustos": 8, "eylul": 9, "ekim": 10, "kasim": 11, "aralik": 12}


def talep_anahtari(tur, konu, mail_tarihi):
    """Talebin defter anahtarı — YALNIZ konudan kesin okunabiliyorsa; yoksa None (tahmin YOK).
    bizpuan/iskonto: dönem konuda ("-Eylül 2026" · "2026/8 Ağustos Ayı") · klima: mail tarihi (15.10 ölçüldü)."""
    onek = TALEP_ONEK.get(tur)
    if not onek:
        return None
    if tur == "klima":
        return onek + mail_tarihi if re.fullmatch(r"\d{4}-\d{2}-\d{2}", mail_tarihi or "") else None
    d = sadelestir(konu)
    yil = re.search(r"\b(20\d\d)\b", d)
    ay = [n for ad, n in AYLAR.items() if re.search(rf"\b{ad}\b", d)]
    if not yil or len(ay) != 1:
        return None
    return f"{onek}{yil.group(1)}-{ay[0]:02d}"


def bu_talep(tur, konu, mail_tarihi):
    """Bu talebin kendi kaydı defterde var mı — insan için tek satır; okunamazsa ÖLÇÜLEMEDİ."""
    k = talep_anahtari(tur, konu, mail_tarihi)
    if not k:
        return "dönem konudan okunamadı — aşağıdaki son kesilene ve e-Logo'ya bak"
    yol = os.environ.get("ARCELIK_KESIM_DEFTERI", os.path.expanduser("~/.config/arcelik-kesim-defteri.jsonl"))
    try:
        satirlar = [json.loads(x) for x in open(yol, encoding="utf-8") if x.strip()]
    except Exception as e:
        return f"ÖLÇÜLEMEDİ (defter okunamadı: {type(e).__name__})"
    l = [r for r in satirlar if r.get("sap") == k and r.get("durum") == "kesildi"]
    if l:
        return f"✓ KESİLMİŞ: {k} → {l[-1].get('fatura_no')} · {l[-1].get('tutar')}"
    return f"🔴 defterde YOK ({k}) — KESİLMEMİŞ olabilir, e-Logo'da da bak"


def son_kesilen(tur):
    """Defterde bu türün EN SON kaydı. Okunamazsa ÖLÇÜLEMEDİ der — asla 'yok' demez."""
    onek = TALEP_ONEK.get(tur)
    if not onek:
        return "tür bilinmiyor — insan baksın"
    yol = os.environ.get("ARCELIK_KESIM_DEFTERI", os.path.expanduser("~/.config/arcelik-kesim-defteri.jsonl"))
    try:
        satirlar = [json.loads(x) for x in open(yol, encoding="utf-8") if x.strip()]
    except Exception as e:
        return f"ÖLÇÜLEMEDİ (defter okunamadı: {type(e).__name__})"
    l = [r for r in satirlar if str(r.get("sap", "")).startswith(onek) and r.get("durum") == "kesildi"]
    if not l:
        return "defterde bu türden kayıt YOK"
    r = l[-1]
    return f"{r['sap']} → {r.get('fatura_no')} · {r.get('tutar')} · {r.get('tarih')}"


def g(url, tok):
    r = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}",
                                             "User-Agent": UA, "Accept": "application/json"})
    return json.loads(urllib.request.urlopen(r, timeout=90).read().decode())

def main():
    tok = os.environ.get("EXCHANGE_ACCESS_TOKEN")
    if not tok:
        print("✗ KIRMIZI · token yok — önce: arcelik-mail-erisim/scripts/mail.sh baglan"); return 3
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    q = urllib.parse.urlencode({"$top": str(n), "$orderby": "ReceivedDateTime desc",
                                "$select": "Subject,ReceivedDateTime,Id,HasAttachments"})
    msgs = g(f"{BASE}/me/mailfolders/inbox/messages?{q}", tok).get("value", [])
    kes, kesme, sor, talep, atla, cizgi_alti = [], [], [], [], 0, 0
    for m in msgs:
        konu = m.get("Subject", "") or ""
        tip, karar = tip_bul(konu)
        if karar == "ATLA":
            atla += 1; continue
        if karar == "TALEP":
            talep.append((m.get("ReceivedDateTime", "")[:10], talep_turu(konu), konu[:60])); continue
        ekler = []
        if m.get("HasAttachments"):
            try:
                ekler = [a.get("Name", "") for a in
                         g(f"{BASE}/me/messages/{urllib.parse.quote(m['Id'])}/attachments", tok).get("value", [])]
            except Exception:
                pass
        sap = sap_cikar(konu, ekler)
        # Malzeme iade: SAP dosya adında yok → PDF'in içinden oku (yukarıdaki gerekçe).
        if not sap and tip == "malzeme_iade" and m.get("HasAttachments"):
            sap = sap_pdften(m["Id"], tok)
        kayit = (m.get("ReceivedDateTime", "")[:10], tip, sap or "(SAP okunamadı)", konu[:44])
        if karar == "KESME":
            kesme.append(kayit)
        elif karar == "SOR":
            sor.append(kayit)
        else:
            onceki = len(OLCULEMEDI)
            k = kesilmis_mi(sap)
            altyapi = len(OLCULEMEDI) > onceki      # None'un sebebi SAP yokluğu MU, arıza MI?
            if k is True:
                continue                                     # defterde: kesilmiş
            # 🔴 Çizgi-altı yutması YALNIZ ölçüm sağlamken geçerli. Ölçüm arızalıysa
            #    beyanla susturmak, arızayı ikinci kez görünmez yapardı.
            if kayit[0] < CIZGI and not altyapi:
                cizgi_alti += 1; continue                    # Sultan beyanı: çizgi altı kesilmiş
            if k is None:
                neden = OLCULEMEDI[-1][1] if altyapi else "SAP okunamadı → tekil kontrol edilemedi"
                sor.append(kayit + (neden,))
            else:
                kes.append(kayit)
    print(f"\n{'='*70}\nARÇELİK — KESİLECEK FATURA TARAMASI  ({len(msgs)} mesaj, {atla} uyarı atlandı)\n{'='*70}")
    print(f"\n✅ KESİLECEK: {len(kes)}")
    for t, tip, sap, k in kes: print(f"   {t}  {tip:<13} SAP={sap:<20} {k}")
    if not kes: print("   (yok)")
    print(f"\n📝 FATURA TALEBİ — kanonda KES, kalemi İNSAN okur (tutar gövdede, tarih mailde): {len(talep)}")
    for t, tur, k in talep:
        print(f"   {t}  {tur:<8} {k}")
        print(f"            bu talep   : {bu_talep(tur, k, t)}")
        print(f"            son kesilen: {son_kesilen(tur)}")
    if not talep: print("   (yok)")
    print("   ⚠️ bu tiplerin anahtarı mailden türetilemez — 'son kesilen' bu talebi kapsıyorsa kesilmiştir;")
    print("      emin değilsen e-Logo giden listesine bak (Kural 3). Tek kalem SATIŞ, mailde yazan tarih.")
    print(f"\n🔴 KESİLMEZ (İADE PAKETİ — zarar sebebi, sayıya dahil DEĞİL): {len(kesme)}")
    for t, tip, sap, k in kesme[:6]: print(f"   {t}  {k}")
    if len(kesme) > 6: print(f"   … +{len(kesme)-6} tane daha")
    # Gürültü ayıklama: tanınmayanları "para/fatura kokusu" olana ve olmayana ayır.
    # Fail-closed korunur — ilgisiz olanlar da SAYILIR, sadece tek tek basılmaz.
    KOKU = re.compile(r"fatura|fi[şs]|paket|iade|ödül|odul|puan|mutabakat|ödeme|odeme|mahsup", re.I)
    supheli = [r for r in sor if KOKU.search(r[3])]
    ilgisiz = [r for r in sor if r not in supheli]
    print(f"\n⏸ SOR — fatura/para kokusu olan, kural yok (fail-closed, KESİLMEDİ): {len(supheli)}")
    for r in supheli[:10]: print(f"   {r[0]}  {r[1]:<13} {r[3]}" + (f"  ⚠️ {r[4]}" if len(r) > 4 else ""))
    if not supheli: print("   (yok)")
    print(f"\n·  ilgisiz görünen diğer mailler: {len(ilgisiz)} (fatura deseni taşımıyor; listelenmedi)")
    if cizgi_alti:
        print(f"\n·  çizgi altı ({CIZGI} öncesi) paket: {cizgi_alti} — Sultan beyanıyla KESİLMİŞ sayıldı")
        print("   ⚠️ bu bir BEYANDIR, defter kaydı değil. Defter dolduruldukça bu satır küçülür.")
    # 🔴 ÖLÇÜLEMEYENLER — sessiz kalamaz. Bir tanesi bile varsa tarama GÜVENİLMEZ:
    #    "kesilecek fatura yok" cümlesi ancak defter OKUNABİLDİYSE bir şey söyler.
    if OLCULEMEDI:
        print(f"\n{'='*70}")
        print(f"🔴 ÖLÇÜLEMEDİ — {len(OLCULEMEDI)} SAP için kesim defteri SORULAMADI.")
        print("   Bu 'kesilmemiş' DEĞİLDİR ve 'kesilmiş' de DEĞİLDİR — bilinmiyordur.")
        print("   Yukarıdaki sayılar bu yüzden EKSİK olabilir; karar vermeden önce sebebi gider.")
        for sap, neden in OLCULEMEDI[:10]:
            print(f"   · SAP={sap:<20} {neden}")
        if len(OLCULEMEDI) > 10:
            print(f"   … +{len(OLCULEMEDI)-10} tane daha")
        print(f"{'='*70}")
    print(f"\n{'='*70}\nNot: 'KESİLECEK' listesi kesim defterinden GEÇMİŞTİR. e-Logo giden-fatura")
    print("sorgusu 2. katmandır; kesim öncesi o da yeşil olmalı (Kural 3).")
    return 4 if OLCULEMEDI else 0

if __name__ == "__main__":
    raise SystemExit(main())
