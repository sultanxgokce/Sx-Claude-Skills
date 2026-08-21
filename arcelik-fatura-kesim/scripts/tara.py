#!/usr/bin/env python3
"""'Arçelik'ten kesilecek fatura var mı?' — tek komutluk cevap.

🔴 Kural 1: IADE PAKETI DOKUMU  -> KESİLMEZ (zarar). Sayıya girmez, ayrı satırda gösterilir.
🔴 Kural 2: 'Malzeme İade'      -> isim yanıltır, DÜZ FATURA olarak KESİLİR.
🔴 Kural 3: kesim defteri sorgulanır; kesilmişse listeye GİRMEZ.
Fail-closed: tanınmayan tip -> 'SOR' listesine düşer, asla 'kes' sayılmaz.
"""
import os, re, json, subprocess, urllib.request, urllib.parse, sys

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/140.0 Safari/537.36")
BASE = "https://outlook.office365.com/api/v2.0"
DEFTER_SH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "defter.sh")

# Sıra ÖNEMLİ: iade paketi, fiş paketinden ÖNCE denenir (ikisi de "PAKETI DOKUMU" taşır).
TIPLER = [
    ("iade_paketi",   re.compile(r"[İI]ADE\s*PAKET[İI]\s*DOKU?MU?", re.I),      "KESME"),
    ("fis_paketi",    re.compile(r"F[İI]S?\s*PAKET[İI]\s*DOKU?MU?", re.I),      "KES"),
    ("malzeme_iade",  re.compile(r"Malzeme\s*[İI]ade", re.I),                   "KES"),
    ("uyari",         re.compile(r"Düzenlenmeyen|Hatırlatma|Hatirlatma", re.I), "ATLA"),
    ("odul_puan",     re.compile(r"ödül|odul|puan", re.I),                      "SOR"),
    ("fatura_talebi", re.compile(r"fatura\s*taleb", re.I),                      "SOR"),
]

def tip_bul(konu):
    for ad, desen, karar in TIPLER:
        if desen.search(konu or ""):
            return ad, karar
    return "taninmayan", "SOR"      # fail-closed

def sap_cikar(konu, ekler):
    for e in ekler:
        m = re.search(r"(\d{15,20})_", e or "")
        if m: return m.group(1)
    return ""

# Sultan beyanı 2026-08-22: bu tarihten ÖNCEKİ tüm paketler kesilmiştir.
# Bu bir BEYANDIR, ölçüm değil — o yüzden sessizce yutulmaz, ayrı satırda gösterilir.
CIZGI = os.environ.get("ARCELIK_KESIM_CIZGISI", "2026-08-20")


def kesilmis_mi(sap):
    if not sap: return None                      # bilinmiyor -> SOR tarafına
    r = subprocess.run(["bash", DEFTER_SH, "sor", sap], capture_output=True, text=True)
    return r.returncode != 0

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
    kes, kesme, sor, atla, cizgi_alti = [], [], [], 0, 0
    for m in msgs:
        konu = m.get("Subject", "") or ""
        tip, karar = tip_bul(konu)
        if karar == "ATLA":
            atla += 1; continue
        ekler = []
        if m.get("HasAttachments"):
            try:
                ekler = [a.get("Name", "") for a in
                         g(f"{BASE}/me/messages/{urllib.parse.quote(m['Id'])}/attachments", tok).get("value", [])]
            except Exception:
                pass
        sap = sap_cikar(konu, ekler)
        kayit = (m.get("ReceivedDateTime", "")[:10], tip, sap or "(SAP okunamadı)", konu[:44])
        if karar == "KESME":
            kesme.append(kayit)
        elif karar == "SOR":
            sor.append(kayit)
        else:
            k = kesilmis_mi(sap)
            if k is True:
                continue                                     # defterde: kesilmiş
            if kayit[0] < CIZGI:
                cizgi_alti += 1; continue                    # Sultan beyanı: çizgi altı kesilmiş
            if k is None:      sor.append(kayit + ("SAP yok → tekil kontrol edilemedi",))
            else:              kes.append(kayit)
    print(f"\n{'='*70}\nARÇELİK — KESİLECEK FATURA TARAMASI  ({len(msgs)} mesaj, {atla} uyarı atlandı)\n{'='*70}")
    print(f"\n✅ KESİLECEK: {len(kes)}")
    for t, tip, sap, k in kes: print(f"   {t}  {tip:<13} SAP={sap:<20} {k}")
    if not kes: print("   (yok)")
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
    print(f"\n{'='*70}\nNot: 'KESİLECEK' listesi kesim defterinden GEÇMİŞTİR. e-Logo giden-fatura")
    print("sorgusu 2. katmandır; kesim öncesi o da yeşil olmalı (Kural 3).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
