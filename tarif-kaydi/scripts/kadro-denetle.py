#!/usr/bin/env python3
"""kadro-denetle.py — tarif-kaydi veri bekçisi (veri-semasi.md §7 ve §10).

Kullanım:
  kadro-denetle.py [--veri DİZİN] [--katalog catalog.json] [--kok SX_KÖK] [--siki]

Çıktı: KIRMIZI <kural>: <ne> · SARI <kural>: <ne> · son satır `kirmizi=A sari=B`.
Çıkış: 0 temiz (sarı olabilir) · 1 kırmızı var (--siki: sarı da sayılır) · 3 ÖLÇÜLEMEDİ (dosya yok/bozuk/boş katalog).
Ölçemediğine temiz demez: kök dizini okunamayan kaynak yolu SARI "ölçülemedi" olur, yeşil sayılmaz.

Kurallar (numara = veri-semasi §10): 1 kapalı kümeler · 2 cakisir/karistirilan iki yönlü · 3 beceri_id katalogda (yoksa sarı) ·
4 kapi_yolu dosyası (null = sarı, yol var dosya yok = kırmızı) · 5 kadro adının terim kaydı (yoksa sarı) · 6 terim kaynak yolları ·
7 sema_surumu ve sultan_eli tarifi · 8 acil=evet → yedek dolu · 9 kalibrasyon kimliği yok. Ek: sira ardışık, kimlik benzersiz, geri bağlar.
"""
import json
import os
import sys

UZMANLIK_DURUM = ("aktif", "planli", "emekli")
TERIM_DURUM = ("onayli", "aday", "emekli")
ADIM_TUR = ("beceri", "kapi", "sultan_eli")
ACIL = ("evet", "hayir")
MODELLER = ("codex-yoksa-claude", None)
SINAV_TURLER = ["dogru", "kusurlu", "uydurma"]
YASAK_VAZIFE_ID = ("kalibrasyon",)
KOKLER = {"nexus": ("NEXUS_KOK", "/config/projects/Nexus"), "cloudtop": ("CLOUDTOP_KOK", "/config/projects/cloudtop")}


class Rapor:
    def __init__(self):
        self.k, self.s = [], []

    def kirmizi(self, kural, ne):
        self.k.append(f"KIRMIZI {kural}: {ne}")

    def sari(self, kural, ne):
        self.s.append(f"SARI {kural}: {ne}")


def yukle(yol):
    try:
        with open(yol, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        print(f"ÖLÇÜLEMEDİ: {yol} okunamadı/bozuk ({e})")
        sys.exit(3)


def sozluk_oge(r, kayit, ne):
    if not isinstance(kayit, dict):
        r.kirmizi("1 yapı", f"{ne}: nesne olmalı, {type(kayit).__name__} geldi")
        return False
    return True


def sozluk(r, veri, anahtar, ad):
    """Listeyi kimlik sözlüğüne çevirir; kimliksiz/nesne olmayan kayıt kırmızı, yinelenen kimlik kırmızı (sessizce ezilmez)."""
    liste = veri.get(anahtar, [])
    if not isinstance(liste, list):
        r.kirmizi("1 yapı", f"{anahtar} liste olmalı, {type(liste).__name__} geldi")
        return {}
    sonuc = {}
    for k in liste:
        if not sozluk_oge(r, k, ad):
            continue
        kid = k.get("id")
        if not isinstance(kid, str) or not kid:
            r.kirmizi("1 yapı", f"{ad}: id (metin) eksik: {str(k)[:60]}")
            continue
        if kid in sonuc:
            r.kirmizi("2 benzersiz", f"{ad} kimliği {kid!r} iki kez geçiyor")
            continue
        sonuc[kid] = k
    return sonuc


def tur_kontrol(r, kayit, ad):
    if kayit.get("sema_surumu") != 2:
        r.kirmizi("7 sema_surumu", f"{ad}: sema_surumu 2 olmalı, {kayit.get('sema_surumu')!r}")


def denetle(veri, terimler, katalog_idleri, kok, r):
    uzm = sozluk(r, veri, "uzmanliklar", "uzmanlık")
    vaz = sozluk(r, veri, "vazifeler", "vazife")
    usl = sozluk(r, veri, "usuller", "usul")
    for u in usl.values():   # adımlar nesne listesi olmalı; olmayan kayıt kırmızı sayılır ve atlanır
        u["adimlar"] = [a for a in (u.get("adimlar") or []) if sozluk_oge(r, a, f"usul {u['id']} adım")]
    if veri.get("sema_surumu") != 2:
        r.kirmizi("7 sema_surumu", "kadro-tarifleri.json: sema_surumu 2 olmalı")
    if terimler.get("sema_surumu") != 2:
        r.kirmizi("7 sema_surumu", "terim-kaydi.json: sema_surumu 2 olmalı")

    # ── uzmanlık ──
    for u in uzm.values():
        tur_kontrol(r, u, f"uzmanlık {u['id']}")
        if u.get("durum") not in UZMANLIK_DURUM:
            r.kirmizi("1 kapalı küme", f"uzmanlık {u['id']}: durum {u.get('durum')!r} ∉ {UZMANLIK_DURUM}")
        s = u.get("sinav") or {}
        if s.get("turler") != SINAV_TURLER:
            r.kirmizi("1 kapalı küme", f"uzmanlık {u['id']}: sinav.turler {s.get('turler')!r} ≠ {SINAV_TURLER}")
        e = u.get("sicil_esigi") or {}
        if not (isinstance(e.get("kacirma"), int) and isinstance(e.get("pencere"), int) and 0 < e["kacirma"] <= e["pencere"]):
            r.kirmizi("1 kapalı küme", f"uzmanlık {u['id']}: sicil_esigi {e!r} geçersiz (0 < kacirma ≤ pencere, tamsayı)")
        for vid in u.get("vazifeler", []):
            if vid in YASAK_VAZIFE_ID:
                r.kirmizi("9 kalibrasyon", f"uzmanlık {u['id']}: vazife kimliği {vid!r} şema dışı (ders-cikarma)")
            if vid not in vaz:
                r.kirmizi("2 bütünlük", f"uzmanlık {u['id']}: vazife {vid!r} tanımlı değil")
            elif vaz[vid].get("uzmanlik") != u["id"]:
                r.kirmizi("2 bütünlük", f"vazife {vid}: uzmanlik geri bağı {vaz[vid].get('uzmanlik')!r} ≠ {u['id']!r}")

    # ── vazife ──
    for v in vaz.values():
        tur_kontrol(r, v, f"vazife {v['id']}")
        if v["id"] in YASAK_VAZIFE_ID:
            r.kirmizi("9 kalibrasyon", f"vazife kimliği {v['id']!r} şema dışı (fabrika puan kalibrasyonuyla karışır; ders-cikarma)")
        if v.get("uzmanlik") not in uzm:
            r.kirmizi("2 bütünlük", f"vazife {v['id']}: uzmanlik {v.get('uzmanlik')!r} tanımlı değil")
        if v.get("acil") not in ACIL:
            r.kirmizi("1 kapalı küme", f"vazife {v['id']}: acil {v.get('acil')!r} ∉ {ACIL}")
        if v.get("model") not in MODELLER:
            r.kirmizi("1 kapalı küme", f"vazife {v['id']}: model {v.get('model')!r} ∉ {MODELLER}")
        y = v.get("yedek")
        if v.get("acil") == "evet":
            if not (isinstance(y, dict) and y.get("tur") == "bassiz-sapka" and isinstance(y.get("bekleme_dk"), int) and y["bekleme_dk"] > 0):
                r.kirmizi("8 yedek", f"vazife {v['id']}: acil=evet ama yedek dolu değil ({y!r})")
        for uid in v.get("usuller", []):
            if uid not in usl:
                r.kirmizi("2 bütünlük", f"vazife {v['id']}: usul {uid!r} tanımlı değil")
            elif usl[uid].get("vazife") != v["id"]:
                r.kirmizi("2 bütünlük", f"usul {uid}: vazife geri bağı {usl[uid].get('vazife')!r} ≠ {v['id']!r}")
        for c in v.get("cakisir", []):
            if c not in vaz:
                r.kirmizi("2 bütünlük", f"vazife {v['id']}: cakisir {c!r} tanımlı değil")
            elif v["id"] not in vaz[c].get("cakisir", []):
                r.kirmizi("2 iki yönlü", f"vazife {v['id']} cakisir {c!r} diyor ama {c!r} {v['id']!r} demiyor — iki yönlü olmalı")

    # ── usul ve adım ──
    for u in usl.values():
        tur_kontrol(r, u, f"usul {u['id']}")
        if u.get("vazife") not in vaz:
            r.kirmizi("2 bütünlük", f"usul {u['id']}: vazife {u.get('vazife')!r} tanımlı değil")
        adimlar = u.get("adimlar") or []
        if not adimlar:
            r.kirmizi("1 kapalı küme", f"usul {u['id']}: adım yok")
        if [a.get("sira") for a in adimlar] != list(range(1, len(adimlar) + 1)):
            r.kirmizi("1 sira", f"usul {u['id']}: sira 1..n ardışık değil: {[a.get('sira') for a in adimlar]}")
        for a in adimlar:
            ad = f"usul {u['id']} adım {a.get('sira')}"
            if a.get("tur") not in ADIM_TUR:
                r.kirmizi("1 adım türü", f"{ad}: tur {a.get('tur')!r} ∉ {ADIM_TUR}")
                continue
            if not a.get("ne_yapar"):
                r.kirmizi("1 ne_yapar", f"{ad}: ne_yapar boş")
            if a["tur"] == "sultan_eli" and not a.get("sultan_eli_tarifi"):
                r.kirmizi("7 sultan_eli", f"{ad}: sultan_eli adımında sultan_eli_tarifi zorunlu")
            if a["tur"] == "beceri":
                b = a.get("beceri_id")
                if not b:
                    r.kirmizi("3 beceri_id", f"{ad}: beceri adımında beceri_id zorunlu")
                elif b not in katalog_idleri:
                    r.sari("3 beceri_id", f"{ad}: {b!r} katalogda yok (uydurulmaz)")
            if a["tur"] == "kapi":
                if "kapi_yolu" not in a:
                    r.kirmizi("4 kapi_yolu", f"{ad}: kapı adımında kapi_yolu alanı şart (henüz yazılmadıysa null)")
                elif a["kapi_yolu"] is None:
                    r.sari("4 kapi_yolu", f"{ad}: kapı henüz yazılmadı (kapi_yolu null) — usul planlı")
                elif not os.path.isfile(os.path.join(kok, a["kapi_yolu"])):
                    r.kirmizi("4 kapi_yolu", f"{ad}: kapi_yolu {a['kapi_yolu']!r} dosya olarak yok")

    # ── terim kaydı ──
    liste = [t for t in (terimler.get("terimler") or []) if sozluk_oge(r, t, "terim")]
    idler, adlar = {}, {}
    for t in liste:
        tur_kontrol(r, t, f"terim {t.get('id')}")
        if t.get("id") in idler:
            r.kirmizi("2 benzersiz", f"terim kimliği {t['id']!r} iki kez geçiyor")
        idler[t.get("id")] = t
        if t.get("ad") in adlar:
            r.kirmizi("2 benzersiz", f"terim adı {t['ad']!r} iki kez geçiyor (tam eşleşme; aynı kelimenin iki anlamı iki kayıttır)")
        adlar[t.get("ad")] = t
    for t in liste:
        tid = t.get("id")
        for alan in ("ad", "anlam", "isleyis", "ornek", "sahip"):
            if not t.get(alan):
                r.kirmizi("2 zorunlu alan", f"terim {tid}: {alan} boş")
        if t.get("durum") not in TERIM_DURUM:
            r.kirmizi("1 kapalı küme", f"terim {tid}: durum {t.get('durum')!r} ∉ {TERIM_DURUM}")
        if not t.get("kaynak"):
            r.kirmizi("6 kaynak", f"terim {tid}: kaynak[] boş")
        if t.get("karistirilan") and not t.get("ayirt_testi"):
            r.kirmizi("2 ayirt_testi", f"terim {tid}: karistirilan dolu ama ayirt_testi yok")
        for k in t.get("karistirilan", []):
            if k not in idler:
                r.kirmizi("2 bütünlük", f"terim {tid}: karistirilan {k!r} tanımlı değil")
            elif tid not in idler[k].get("karistirilan", []):
                r.kirmizi("2 iki yönlü", f"terim {tid} karistirilan {k!r} diyor ama {k!r} {tid!r} demiyor — iki yönlü olmalı")
        for kay in t.get("kaynak", []):
            kaynak_denetle(r, tid, kay, katalog_idleri, kok)

    # ── 5: kadro adı terim kaydında mı (tam eşleşme) ──
    for grup, ad_ in (("uzmanlık", uzm), ("vazife", vaz), ("usul", usl)):
        for k in ad_.values():
            if k.get("ad") not in adlar:
                r.sari("5 terimi yok", f"{grup} {k['id']} adı {k.get('ad')!r} terim kaydında yok")


def kaynak_denetle(r, tid, kay, katalog_idleri, kok):
    onek, _, yol = kay.partition(":")
    if onek == "beceri":
        if yol not in katalog_idleri:
            r.kirmizi("6 kaynak", f"terim {tid}: beceri:{yol} katalogda yok")
    elif onek == "sx":
        if not os.path.exists(os.path.join(kok, yol)):
            r.kirmizi("6 kaynak", f"terim {tid}: sx:{yol} yok")
    elif onek in KOKLER:
        ortam, varsayilan = KOKLER[onek]
        taban = os.environ.get(ortam, varsayilan)
        if not os.path.isdir(taban):
            r.sari("6 kaynak", f"terim {tid}: {kay} — {onek} kökü okunamadı ({taban}); ÖLÇÜLEMEDİ, temiz sayılmaz")
        elif not os.path.exists(os.path.join(taban, yol)):
            r.kirmizi("6 kaynak", f"terim {tid}: {kay} yok ({taban})")
    elif onek == "yerel":
        taban = os.environ.get("CLAUDE_YEREL", os.path.expanduser("~/.claude"))
        if not os.path.isdir(taban):
            r.sari("6 kaynak", f"terim {tid}: {kay} — yerel kök okunamadı ({taban}); ÖLÇÜLEMEDİ")
        elif not os.path.exists(os.path.join(taban, yol)):
            r.sari("6 kaynak", f"terim {tid}: {kay} bu kutuda kurulu değil")
    else:
        r.kirmizi("6 kaynak", f"terim {tid}: kaynak {kay!r} biçimi tanınmıyor (beceri:|sx:|nexus:|cloudtop:|yerel:)")


def main(argv):
    betik_dizini = os.path.dirname(os.path.abspath(__file__))
    veri_dizini = os.path.join(betik_dizini, "..", "veri")
    kok = os.path.abspath(os.path.join(betik_dizini, "..", ".."))
    katalog_yolu, siki = None, False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--veri" and i + 1 < len(argv):
            veri_dizini = argv[i + 1]; i += 2
        elif a == "--katalog" and i + 1 < len(argv):
            katalog_yolu = argv[i + 1]; i += 2
        elif a == "--kok" and i + 1 < len(argv):
            kok = argv[i + 1]; i += 2
        elif a == "--siki":
            siki = True; i += 1
        else:
            print(f"kullanım hatası: {a}", file=sys.stderr); return 2
    katalog_yolu = katalog_yolu or os.path.join(kok, "catalog.json")
    veri = yukle(os.path.join(veri_dizini, "kadro-tarifleri.json"))
    terimler = yukle(os.path.join(veri_dizini, "terim-kaydi.json"))
    katalog = yukle(katalog_yolu)
    idler = {s.get("id") for s in (katalog.get("skills") or []) if isinstance(s, dict)}
    if not idler:
        print(f"ÖLÇÜLEMEDİ: {katalog_yolu} içinde beceri yok (boş katalog) — beceri_id denetimi yapılamaz")
        return 3
    r = Rapor()
    try:
        denetle(veri, terimler, idler, kok, r)
    except Exception as e:   # beklenmeyen biçim: temiz DEĞİL, ölçülemedi
        for satir in r.k + r.s:
            print(satir)
        print(f"ÖLÇÜLEMEDİ: bekçi beklenmeyen biçimde durdu ({type(e).__name__}: {e}) — veri şemaya uymuyor olabilir")
        return 3
    for satir in r.k + r.s:
        print(satir)
    print(f"kirmizi={len(r.k)} sari={len(r.s)}")
    return 1 if (r.k or (siki and r.s)) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
