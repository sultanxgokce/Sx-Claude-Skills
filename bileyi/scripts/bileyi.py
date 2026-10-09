#!/usr/bin/env python3
"""bileyi.py — kendi izini tara, TEKRAR EDEN sürtünmeyi bul, yeteneğe çevirmeye hazırla.

🔴 BU ARAÇ HÜKÜM VERMEZ, GİRDİ HAZIRLAR.
   "Şu yeteneği üret" demek bir muhakemedir; burada yapılan sayımdır. Araç yalnız
   şunu söyler: bu sürtünme N kez tekrar etti, eşik M, kapsamam şu kadar.

ÜÇ KAPI (hepsi fail-closed)
  K1 · KENDİ İZİ   — kimlik sorulur, çivilenmez. Başkasının defteri okunmaz.
  K2 · EŞİK DAYANAĞI — dayanaksız eşik rc=3 (ÖLÇEMEDİM), yeşil değil.
  K3 · KAPSAMA     — her ölçüm havuzun ne kadarını gördüğünü yazar.

ÇIKIŞ KODLARI
  0 eşiği aşan tekrar VAR      1 yok (temiz)      2 yapılandırma hatası
  3 ÖLÇEMEDİM (yeşil DEĞİL)    4 otonom tur kapalı (kill-switch)
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import re
import subprocess
import sys
import unicodedata
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

BURASI = Path(__file__).resolve().parent
BECERI = BURASI.parent

# Sayıma girmeyen taşıyıcı kelimeler. Liste KISA tutulur: uzun bir durak listesi
# gürültüyü değil SİNYALİ de keser ve bunu kimse fark etmez.
DURAK = {
    "icin", "degil", "ancak", "olan", "oldu", "bile", "daha", "diye", "gibi",
    "hangi", "kadar", "sonra", "once", "vardi", "yoktu", "hala", "ayni", "iken",
    "bunu", "onun", "seyi", "sadece", "zaten", "yani", "hepsi", "bazi", "uzere",
    "kendi", "ama", "ile", "bir", "bu", "da", "de", "ve", "ya", "mi", "mu",
    "hic", "her", "cok", "tek", "iki", "uc", "dort", "bes", "yeni", "eski",
}


class Durdu(RuntimeError):
    """Kapı kapandı. rc taşır."""

    def __init__(self, mesaj: str, rc: int):
        super().__init__(mesaj)
        self.rc = rc


# ───────────────────────────────────────── K1 · kendi izi

def kimlik(depo: Path) -> str:
    """Kimliği SOR, türetme. Tek kaynak çıpa aracıdır.

    🔴 Niçin ortam değişkenine de BAKILMIYOR: kimlik sırasının sahibi çıpa aracıdır;
    ikinci bir türetme "tek kaynak" iddiasını çürütür ve kimlik taklidine kapı açar.
    Ölçülmüş vaka: çivili bir yol, hangi ajan koşarsa koşsun başkasının izini
    "dün nerede bıraktım" diye sunuyordu.
    """
    arac = Path("/config/.claude/skills/gunluk-plan/scripts/cipa.sh")
    if not arac.exists():
        raise Durdu(f"kimlik sorulamadı: çıpa aracı yok ({arac}) — ÖLÇEMEDİM", 3)
    try:
        s = subprocess.run(["bash", str(arac), "ajan"], capture_output=True,
                           text=True, timeout=20, cwd=str(depo))
    except (OSError, subprocess.SubprocessError) as e:
        raise Durdu(f"kimlik sorulamadı: {e} — ÖLÇEMEDİM", 3) from e
    ad = (s.stdout or "").strip().splitlines()[-1].strip() if s.stdout.strip() else ""
    ad = re.sub(r"[^A-Za-zÇĞİÖŞÜçğıöşü0-9_-]", "", ad)
    if not ad:
        raise Durdu("kimlik BOŞ döndü — başkasının defterine düşmemek için duruyorum", 3)
    return ad


# ───────────────────────────────────────── K2 · eşik dayanağı

def esik_oku(yol: Path) -> dict:
    if not yol.exists():
        raise Durdu(f"eşik dosyası yok: {yol} — eşiği UYDURMUYORUM (ÖLÇEMEDİM)", 3)
    try:
        d = json.loads(yol.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise Durdu(f"eşik dosyası okunamadı: {e}", 2)
    dayanak = str(d.get("dayanak", "")).strip()
    if len(dayanak) < 40:
        raise Durdu(
            "eşiğin ÖLÇÜLMÜŞ DAYANAĞI yok (dayanak alanı boş ya da çok kısa) — rc=3.\n"
            "   Sayı değiştirmek bir düzenleme değil, yeni bir ölçümdür.", 3)
    for alan in ("ikili_esik", "sinif_esik", "tavan"):
        v = d.get(alan)
        if not isinstance(v, int) or isinstance(v, bool) or v < 1:
            raise Durdu(f"eşik alanı geçersiz: {alan}={v!r} (pozitif tam sayı bekleniyor)", 2)
    return d


# ───────────────────────────────────────── ölçüm

def _sadelestir(metin: str) -> list[str]:
    t = metin.lower()
    t = "".join(c for c in unicodedata.normalize("NFKD", t) if not unicodedata.combining(c))
    return [w for w in re.findall(r"[a-z]{3,}", t) if w not in DURAK]


def havuz_oku(yol: Path, pencere_gun: int) -> tuple[list[dict], int, str]:
    """Havuzu okur. (kayitlar, atlanan_bozuk, uyari) döner.

    🔴 Bozuk satır SESSİZCE atlanmaz: sayısı basılır. Eksik veri her zaman "daha az"
    görünür, yani rahatlatır; bu yüzden bozuk satır sayısı ölçümün parçasıdır.
    """
    if not yol.exists():
        raise Durdu(f"bulgu havuzu yok: {yol} — ÖLÇEMEDİM", 3)
    kayit, bozuk = [], 0
    for satir in yol.read_text(encoding="utf-8", errors="replace").splitlines():
        if not satir.strip():
            continue
        try:
            kayit.append(json.loads(satir))
        except json.JSONDecodeError:
            bozuk += 1
    if not kayit:
        raise Durdu(f"havuzda okunabilir kayıt YOK ({bozuk} bozuk satır) — ÖLÇEMEDİM", 3)

    uyari = ""
    if pencere_gun > 0:
        sinir = (date.today() - timedelta(days=pencere_gun)).isoformat()
        pencereli = [k for k in kayit if str(k.get("tarih", "")) >= sinir]
        # 🔴 Pencere havuzu BOŞALTIRSA pencere yanlıştır, havuz boş değildir.
        if pencereli:
            uyari = f"pencere {pencere_gun} gün: {len(pencereli)}/{len(kayit)} kayıt"
            kayit = pencereli
        else:
            uyari = (f"🔴 pencere {pencere_gun} gün içinde kayıt YOK — pencere yok sayıldı, "
                     f"tüm havuz ({len(kayit)}) ölçüldü")
    return kayit, bozuk, uyari


def tekrar_say(kayit: list[dict]) -> dict:
    """İki yüzeyden tekrar sayar ve HER İKİSİNİN KAPSAMASINI yazar."""
    sinif_dolu = [k for k in kayit if str(k.get("sinif", "")).strip()]
    sinif = collections.Counter(str(k["sinif"]).strip().lower() for k in sinif_dolu)

    ikili: collections.Counter = collections.Counter()
    ikili_ornek: dict[str, list[str]] = {}
    for k in kayit:
        gov = " ".join(str(k.get(a, "") or "") for a in ("baslik", "sinif"))
        gov += " " + str(k.get("gercek", "") or "")[:200]
        w = _sadelestir(gov)
        for cift in {a + " " + b for a, b in zip(w, w[1:])}:
            ikili[cift] += 1
            ikili_ornek.setdefault(cift, []).append(str(k.get("id", "?")))

    return {
        "toplam": len(kayit),
        "sinif": sinif,
        "sinif_kapsama": len(sinif_dolu),
        "ikili": ikili,
        "ikili_ornek": ikili_ornek,
    }


def tek_parti_mi(idler: list[str]) -> bool:
    """Bu "tekrar" aslında TEK BİR OLAY mı?

    🔴 Ölçülmüş tuzak: aynı oturumda arka arkaya yazılmış üç bulgu, aynı söz öbeğini
    üç kez taşır ve sayım bunu "üç kez tekrar etti" sanar. Oysa üçü BİR olaydır.
    Aynı sınıf b0164'te de çıkmıştı: iki dosyada iki bozuk satır vardı ve ikisi de
    AYNI iki olaya aitti — iki olay değil.

    Ayırt etme: kimlikler sayısal ve KESİNTİSİZ ardışıksa tek parti sayılır.
    Dürüst sınır: ardışık olmayan ama yine aynı oturumdan gelen kayıtları bu ölçü
    GÖREMEZ (havuzda oturum kimliği yok). Yani yanlış-negatif verebilir, yanlış-
    pozitif vermez — şüphede tekrar saymaya devam eder.
    """
    sayi = sorted(int(m.group(1)) for i in idler if (m := re.match(r"\D*(\d+)$", i)))
    if len(sayi) < 2 or len(sayi) != len(idler):
        return False
    return sayi[-1] - sayi[0] == len(sayi) - 1


def surtunme_oku(depo: Path) -> tuple[str, str]:
    """Sürtünme raporu VARSA koşar. YOKSA 'ölçemedim' der — 'sürtünme yok' DEMEZ.

    🔴 unknown != yok. Aracın bulunmaması, sürtünmenin olmadığı anlamına gelmez;
    ölçülmüş vaka: kurulu olmayan bir araç her koşuda 0 döndürdü ve "yok" sanıldı.
    """
    arac = depo / "scripts" / "friction-report.sh"
    if not arac.exists():
        return ("olcemedim", f"sürtünme raporu bu depoda yok ({arac.name}) — ÖLÇEMEDİM, 'yok' demiyorum")
    try:
        s = subprocess.run(["bash", str(arac)], capture_output=True, text=True,
                           timeout=180, cwd=str(depo))
    except (OSError, subprocess.SubprocessError) as e:
        return ("olcemedim", f"sürtünme raporu koşturulamadı: {e} — ÖLÇEMEDİM")
    if s.returncode != 0:
        return ("olcemedim", f"sürtünme raporu rc={s.returncode} — ÖLÇEMEDİM")
    return ("olculdu", s.stdout.strip())


def dedup_kaynaklari(depo: Path) -> tuple[set[str], str]:
    """Zaten önerilmiş / zaten var olan yetenekler. Eksikse SÖYLER."""
    adlar: set[str] = set()
    notlar = []

    aday = depo / "_agents" / "handoff" / "layiha-aday-havuzu.jsonl"
    if aday.exists():
        n = 0
        for satir in aday.read_text(encoding="utf-8", errors="replace").splitlines():
            if not satir.strip():
                continue
            try:
                d = json.loads(satir)
            except json.JSONDecodeError:
                continue
            for a in ("baslik", "ad", "konu"):
                if d.get(a):
                    adlar.add(str(d[a]).strip().lower())
                    n += 1
                    break
        notlar.append(f"aday havuzu: {n} kayıt")
    else:
        notlar.append("🔴 aday havuzu YOK — 'zaten önerilmiş mi' sorusu ÖLÇÜLEMEDİ")

    bec = Path("/config/.claude/skills")
    if bec.is_dir():
        kurulu = sorted(p.name for p in bec.iterdir() if p.is_dir() and not p.name.startswith("_"))
        adlar.update(kurulu)
        notlar.append(f"kurulu beceri: {len(kurulu)}")
    else:
        notlar.append("🔴 kurulu beceri dizini YOK — 'bu yetenek zaten var mı' ÖLÇÜLEMEDİ")

    return adlar, " · ".join(notlar)



# ───────────────────────────────────────── sınıf kâhini (otonom turun emniyeti)

def sinif_kurallari(yol: Path | None = None) -> dict:
    y = yol or (BECERI / "sinif-kurallari.json")
    if not y.exists():
        raise Durdu(f"sınıf kuralları yok: {y} — sınıfı UYDURMUYORUM (ÖLÇEMEDİM)", 3)
    try:
        d = json.loads(y.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise Durdu(f"sınıf kuralları okunamadı: {e}", 2)
    if len(str(d.get("dayanak", "")).strip()) < 40:
        raise Durdu("sınıf kurallarının ÖLÇÜLMÜŞ DAYANAĞI yok — rc=3", 3)
    for a in ("geri_alinamaz", "para", "dis_yuzey", "yetki", "guvenli_onekler"):
        if not isinstance(d.get(a), list) or not d[a]:
            raise Durdu(f"sınıf kuralı eksik ya da boş: {a}", 2)
    return d


def sinifla(yollar: list[str], kurallar: dict) -> dict[str, str]:
    """Dokunulan yollardan dört sınıf sorusunu cevaplar. FAIL-CLOSED.

    🔴 Niçin araç cevaplıyor: otonom tur kart açacaksa sınıf sorusu cevaplanmak
    zorundadır ve onu ajanın serbest muhakemesine bırakmak, ajanın kendi işini
    "sınıfsız" ilan edip kendi kendine birleştirmesine kapı açardı. Cevap bu
    yüzden **denetlenebilir bir listeden** gelir, muhakemeden değil.

    🔴 BİLİNMEYEN YOL = "?" = SULTAN. Güvenli öneklerin hiçbirini tutmayan tek
    bir yol bile varsa sınıf "?" olur; kanonda "?" Sultan'a gider ve şüphede
    sınıf YUKARI çıkar. Yani liste eksikse araç kendine izin vermez, DURUR.
    """
    cevap = {"geri_alinamaz": "h", "para": "h", "dis_yuzey": "h", "yetki": "h"}
    gerekce: list[str] = []
    dusuk = [y.lower() for y in yollar]

    for alan in ("geri_alinamaz", "para", "dis_yuzey", "yetki"):
        for desen in kurallar[alan]:
            d = desen.lower()
            tutan = [y for y in dusuk if d in y]
            if tutan:
                cevap[alan] = "e"
                gerekce.append(f"{alan}=e · '{desen}' → {tutan[0]}")
                break

    yabanci = [y for y in yollar
               if not any(y.startswith(o) for o in kurallar["guvenli_onekler"])]
    if yabanci:
        for alan in cevap:
            if cevap[alan] == "h":
                cevap[alan] = "?"
        gerekce.append("? · güvenli öneklerin dışında yol var: " + ", ".join(yabanci[:4]))

    cevap["_gerekce"] = " | ".join(gerekce) if gerekce else "tüm yollar güvenli önek içinde, desen tutmadı"
    return cevap


def _kos(komut: list[str], cwd: Path, zaman: int = 600) -> tuple[int, str]:
    try:
        s = subprocess.run(komut, capture_output=True, text=True, timeout=zaman, cwd=str(cwd))
    except (OSError, subprocess.SubprocessError) as e:
        return 9, f"çalıştırılamadı: {e}"
    return s.returncode, (s.stdout or "") + (s.stderr or "")


def tur_durumu_yolu(depo: Path) -> Path:
    return depo / "_agents" / "fabrika" / "bileyi-tur.json"


FABRIKA = Path("/config/.claude/skills/yazilim-fabrikasi/scripts")

# ───────────────────────────────────────── kill-switch

ANAHTAR_VARSAYILAN = Path("/config/.claude/bileyi-kapali")


def anahtar_yolu() -> Path:
    """Kill-switch dosyasının yolu.

    🔴 BAĞIMSIZ GÖZÜN TUR-1 BULGUSU (ciddi): eski satır
    `Path(os.environ.get(...,"")) or VARSAYILAN` idi. `Path("")` → `Path(".")`
    ve o **truthy**'dir; yani varsayılan HİÇBİR ZAMAN uygulanmıyordu. Üretimde
    anahtar yolu çalışma dizini oluyordu, dizin de **var** olduğu için araç
    kendini DAİMA "kapalı" sanıyordu ve `dur` bir dizine yazmaya çalışıyordu.
    Sınavların hepsi ortam değişkenini verdiği için **üretim yolu hiç
    ölçülmemişti** — "sınav yeşil, yol çalışmıyor" sınıfının birebir kendisi.
    Artık boşluk açıkça sınanıyor ve bu yolun kendi kapısı var.
    """
    ham = os.environ.get("BILEYI_ANAHTAR", "").strip()
    return Path(ham) if ham else ANAHTAR_VARSAYILAN


def kapali_mi() -> tuple[bool, str]:
    y = anahtar_yolu()
    if y.exists():
        try:
            return True, y.read_text(encoding="utf-8").strip()
        except OSError:
            return True, "(gerekçe okunamadı)"
    return False, ""


# ───────────────────────────────────────── komutlar

def esik_dosyasi(n) -> Path:
    """Eşik dosyasının yolu. Verilmediyse becerinin yanındaki.

    🔴 Ayrı bir fonksiyon, çünkü eşiğin SAYISI ile eşiğin DOSYASI iki ayrı şeydir;
    ilk yazımda ikisi aynı alana yazıyordu ve dosya yolu sayının üstüne biniyordu.
    """
    d = getattr(n, "esik_dosya", None)
    return Path(d) if d else (BECERI / "esik.json")


def olc_veri(n) -> dict:
    depo = Path(n.depo).resolve()
    kim = kimlik(depo)
    es = esik_oku(esik_dosyasi(n))
    # 🔴 BAĞIMSIZ GÖZÜN TUR-1 BULGUSU: komut satırı ezmesi dosyanın pozitif-tam-sayı
    #    kapısını AŞIYORDU — negatif bir eşik doğrudan kabul ediliyordu ve o eşikte
    #    her söz öbeği "tekrar" olurdu. Ezme de aynı kapıdan geçer.
    if n.ikili_esik is not None and n.ikili_esik < 1:
        raise Durdu(f"--ikili-esik pozitif tam sayı olmalı (verilen: {n.ikili_esik})", 2)
    ik_esik = n.ikili_esik if n.ikili_esik else es["ikili_esik"]
    sn_esik = es["sinif_esik"]
    pencere = n.gun if n.gun is not None else es.get("pencere_gun", 30)

    havuz = depo / "_agents" / "handoff" / "bulgu-havuzu.jsonl"
    kayit, bozuk, pen_uyari = havuz_oku(havuz, pencere)
    o = tekrar_say(kayit)
    dedup, dedup_not = dedup_kaynaklari(depo)
    surt_hal, surt = surtunme_oku(depo)

    print(f"🔪 BİLEYİ · iç-tarama · ajan={kim} · {datetime.now(timezone.utc).date().isoformat()}")
    print(f"   havuz: {o['toplam']} kayıt" + (f" · {bozuk} BOZUK satır" if bozuk else ""))
    if pen_uyari:
        print(f"   {pen_uyari}")
    print(f"   dedup kaynakları: {dedup_not}")
    kaps = 100 * o["sinif_kapsama"] // max(1, o["toplam"])
    print(f"   🔴 KAPSAMA · sınıf alanı dolu: {o['sinif_kapsama']}/{o['toplam']} (%{kaps})"
          f" → sınıfa dayanan sayım havuzun %{100 - kaps}'ine KÖR")
    print(f"   eşik: ikili≥{ik_esik} · sınıf≥{sn_esik} · dayanak {es['dayanak_tarihi']}")
    print()

    bulunan = []
    tek_parti_sayisi = [0]

    print(f"── YÜZEY 1 · sınıf alanı (kesin, kısmi kapsama)")
    # 🔴 ÇELİŞKİ KAPISI — bağımsız gözün tur-1 bulgusu: belge "iki yüzey çelişirse
    #    hüküm YOK" diyordu ama hiçbir yerde ölçülmüyordu. Çelişki şudur: sınıf
    #    yüzeyi "bu N kez tekrar etti" derken, AYNI kayıtların kimlikleri tek bir
    #    partiden geliyorsa öbür yüzey "bu bir olay" diyor. İki yüzey aynı aday
    #    hakkında zıt şey söylüyorsa o aday hüküm üretmez.
    s1 = [(k, v) for k, v in o["sinif"].most_common() if v >= sn_esik]
    celiski = []
    if s1:
        for k, v in s1[:10]:
            idler = [str(r.get("id", "?")) for r in kayit
                     if str(r.get("sinif", "")).strip().lower() == k]
            if tek_parti_mi(idler):
                celiski.append((k, v, idler))
                print(f"   {v:3d} × {k[:60]}  ⚡ ÇELİŞKİ: öbür yüzey tek parti diyor [{','.join(idler[:4])}]")
                continue
            print(f"   {v:3d} × {k[:80]}")
            bulunan.append({"yuzey": "sinif", "tekrar": k, "sayi": v, "kaynak_bulgular": idler})
    else:
        print("   eşiği aşan tekrar yok")

    print(f"\n── YÜZEY 2 · ikili söz öbeği (tüm havuz, gürültülü)")
    s2 = [(k, v) for k, v in o["ikili"].most_common() if v >= ik_esik]
    if s2:
        for k, v in s2[:14]:
            zaten = " ⟲ benzeri zaten kayıtlı" if any(k in d for d in dedup) else ""
            idler = o["ikili_ornek"][k]
            parti = tek_parti_mi(idler)
            isaret = " ⚠ TEK PARTİ (bir olay, tekrar değil)" if parti else ""
            print(f"   {v:3d} × {k:<34} [{','.join(idler[:3])}]{zaten}{isaret}")
            if not parti:
                bulunan.append({"yuzey": "ikili", "tekrar": k, "sayi": v,
                                "kaynak_bulgular": idler})
            else:
                tek_parti_sayisi[0] += 1
    else:
        print("   eşiği aşan tekrar yok")

    print(f"\n── YÜZEY 3 · sürtünme raporu")
    if surt_hal == "olcemedim":
        print(f"   🟡 {surt}")
    else:
        for satir in surt.splitlines()[:12]:
            print("   " + satir)

    print()
    if tek_parti_sayisi[0]:
        print(f"   ⚠ {tek_parti_sayisi[0]} söz öbeği TEK PARTİ sayıldı ve tekrar sayılmadı —")
        print(f"     ardışık kimlikler aynı oturumun tek olayıdır. (Yanlış-negatif verebilir:")
        print(f"     ardışık olmayan ama aynı oturumdan gelen kayıtları bu ölçü göremez.)")
    sonuc = {"bulunan": bulunan, "celiski": celiski, "es": es, "toplam": o["toplam"],
             "kim": kim, "depo": depo}
    if celiski and not bulunan:
        sonuc["rc"] = 3
        print(f"⚡ HÜKÜM YOK — eşiği aşan {len(celiski)} adayın hepsinde iki yüzey ÇELİŞİYOR.")
        print("   Çelişki 'temiz' değildir ve 'kirli' de değildir; çözülmesi gerekir.")
        print("   Çare: çelişen kayıtların sınıf alanını gözden geçir ya da pencereyi genişlet.")
        return sonuc
    if not bulunan:
        sonuc["rc"] = 1
        print("✓ eşiği aşan TEKRAR YOK — bileyecek bir şey çıkmadı (bu bir ölçümdür, iddia değil)")
        return sonuc
    sonuc["rc"] = 0
    print(f"🔪 eşiği aşan {len(bulunan)} tekrar var · tavan {es['tavan']} yetenek/tur")
    print("   🔴 Bu bir GİRDİdir, hüküm değil: hangi cinsten yetenek üretileceği")
    print("      (kural · yapılandırma · beceri) muhakeme ister — ÖNCE 'kural var mı,")
    print("      koşuyor mu' sorulur; var olanı kapıya bağlamak yeni beceri yazmaktan ucuzdur.")
    print("   🔴 ÖLÇMEDİĞİM: bu sürtünmelerin MALİYETİ. Kaç kez olduğunu saydım,")
    print("      kaç dakika yediğini bilmiyorum ve oraya temiz demiyorum.")
    return sonuc


def komut_olc(n) -> int:
    """Ölçüm raporu. Veriyi `olc_veri` üretir; bu yalnız çıkış kodunu verir.

    🔴 Niçin ikiye ayrıldı (bağımsız gözün tur-2 bulgusu): eskiden ölçüm yalnız
    bir çıkış kodu döndürüyordu, bulunan tekrarları **kimseye aktarmıyordu**.
    Sonuç: otonom tur ne ölçüldüğünden habersiz, SABİT içerikli tek bir aday
    yazıyordu ve `tavan` fiilî bir kapı değil rapor metniydi. Ölçümün sonucu
    artık veri olarak akıyor.
    """
    return olc_veri(n)["rc"]


def komut_durum(n) -> int:
    kapali, gerekce = kapali_mi()
    print("🔪 BİLEYİ · durum")
    print(f"   otonom tur: {'🔴 KAPALI' if kapali else '🟢 açık'}")
    if kapali:
        print(f"   gerekçe: {gerekce}")
        print(f"   anahtar: {anahtar_yolu()}")
    try:
        es = esik_oku(esik_dosyasi(n))
        print(f"   eşik: ikili≥{es['ikili_esik']} · sınıf≥{es['sinif_esik']} · tavan {es['tavan']}")
        print(f"   dayanak ({es['dayanak_tarihi']}): {es['dayanak'][:160]}…")
    except Durdu as e:
        print(f"   eşik: 🟡 {e}")
    print("   🔴 'olc' ve 'durum' kill-switch'ten ETKİLENMEZ — eldeki ölçüme erişim")
    print("      bir otonomluk ayarına bağlanamaz.")
    return 0


def komut_dur(n) -> int:
    y = anahtar_yolu()
    y.parent.mkdir(parents=True, exist_ok=True)
    y.write_text(f"{datetime.now(timezone.utc).isoformat()} · {n.gerekce}\n", encoding="utf-8")
    print(f"🔴 otonom tur KAPATILDI · {y}")
    print("   'olc' ve 'durum' çalışmaya devam ediyor.")
    return 0


def komut_ac(n) -> int:
    y = anahtar_yolu()
    if y.exists():
        y.unlink()
        print(f"🟢 otonom tur AÇILDI · gerekçe: {n.gerekce}")
    else:
        print("🟢 otonom tur zaten açıktı")
    return 0


def aday_anahtari(aday: dict) -> str:
    """Bir tekrarın kalıcı kimliği. Aynı tekrar iki kez aday OLMAZ."""
    return f"{aday['yuzey']}:{aday['tekrar']}"


def mevcut_anahtarlar(aday_yolu: Path) -> set[str]:
    """Havuzda ZATEN olan bileyi adaylarının anahtarları."""
    var: set[str] = set()
    for satir in aday_yolu.read_text(encoding="utf-8", errors="replace").splitlines():
        if not satir.strip():
            continue
        try:
            d = json.loads(satir)
        except json.JSONDecodeError:
            continue
        if d.get("kaynak") == "bileyi" and d.get("anahtar"):
            var.add(str(d["anahtar"]))
    return var


def komut_tur(n) -> int:
    """Otonom turu BAŞLATIR: ölçer, ÖLÇÜLEN her tekrar için ayrı aday yazar.

    🔴 İKİ TUR BULGU YEDİ, ikisi de haklıydı:
      tur-1: bu komut "sıradaki adımlar" diye ekrana basıyordu, iş yapmıyordu.
      tur-2: iş yapmaya başladı ama ölçümden habersizdi — SABİT içerikli TEK
             bir aday yazıyordu; hangi tekrardan doğduğu, hangi bulgulardan
             geldiği kayıtlı değildi ve `tavan` fiilî bir kapı değil rapor
             metniydi. Şimdi ölçüm veri olarak akıyor: her seçilen tekrar
             kendi adayını alır, kaynak bulgu kimliklerini taşır, tavan
             fiilen keser ve aynı tekrar iki kez aday olmaz.
    """
    depo = Path(n.depo).resolve()
    kapali, gerekce = kapali_mi()
    if kapali and not n.kuru:
        print(f"🔴 otonom tur KAPALI — koşmuyorum. gerekçe: {gerekce}")
        print('   Açmak Sultan kararıdır: bileyi.sh ac --gerekce "…"')
        return 4

    o = olc_veri(n)
    if o["rc"] != 0:
        return o["rc"]

    aday_yolu = depo / "_agents" / "handoff" / "layiha-aday-havuzu.jsonl"
    if not aday_yolu.exists():
        print(f"\n⛔ aday havuzu yok ({aday_yolu}) — YENİ HAVUZ KURMUYORUM.")
        print("   Bu odada aday havuzu kurulu değilse bu tur burada durur.")
        return 3

    tavan = o["es"]["tavan"]
    sirali = sorted(o["bulunan"], key=lambda a: (-a["sayi"], a["tekrar"]))
    zaten = mevcut_anahtarlar(aday_yolu)

    print()
    print(f"── ADAY SEÇİMİ · {len(sirali)} tekrar ölçüldü · tavan {tavan}")
    secilen, atlanan = [], []
    for a in sirali:
        k = aday_anahtari(a)
        if k in zaten:
            atlanan.append((k, "zaten aday"))
            continue
        if len(secilen) >= tavan:
            atlanan.append((k, "tavan doldu"))
            continue
        secilen.append(a)

    for a in secilen:
        print(f"   ✓ {a['sayi']:3d} × {a['tekrar']:<32} "
              f"[{','.join(a['kaynak_bulgular'][:4])}] ({a['yuzey']})")
    for k, sebep in atlanan:
        print(f"   – {k:<40} atlandı: {sebep}")

    if not secilen:
        print("\n✓ yeni aday YOK — ölçülen tekrarların hepsi zaten havuzda ya da tavan dolu.")
        print("   (Bu bir ölçümdür: 'tekrar yok' demek DEĞİL.)")
        return 1

    if n.kuru:
        print("\n(kuru koşum — aday yazılmadı, durum bırakılmadı)")
        return 0

    kim = o["kim"]
    damga = datetime.now(timezone.utc).isoformat()
    with aday_yolu.open("a", encoding="utf-8") as f:
        for a in secilen:
            f.write(json.dumps({
                "kaynak": "bileyi",
                "anahtar": aday_anahtari(a),
                "tarih": date.today().isoformat(),
                "bulan": kim,
                "baslik": f"iç-tarama: '{a['tekrar']}' {a['sayi']} kez tekrar etti",
                "yuzey": a["yuzey"],
                "sayi": a["sayi"],
                "kaynak_bulgular": a["kaynak_bulgular"],
                "not": ("Hangi cinsten yetenek üretileceği (kural · yapılandırma · beceri) "
                        "muhakeme ister; ÖNCE 'kural var mı, koşuyor mu' sorulur."),
                "damga": damga,
            }, ensure_ascii=False) + "\n")
    print(f"\n   ✓ aday havuzuna {len(secilen)} satır yazıldı ({aday_yolu.name})")

    durum = tur_durumu_yolu(depo)
    durum.parent.mkdir(parents=True, exist_ok=True)
    durum.write_text(json.dumps({
        "asama": "yazim-bekliyor",
        "acildi": damga,
        "adaylar": [{"anahtar": aday_anahtari(a), "tekrar": a["tekrar"],
                     "kaynak_bulgular": a["kaynak_bulgular"]} for a in secilen],
        "not": "Kural/yapılandırma/beceri metnini AJAN yazar; betik yazamaz.",
    }, ensure_ascii=False) + "\n", encoding="utf-8")

    print()
    print(f"🔪 TUR AÇIK · aşama: yazım bekliyor · {len(secilen)} aday")
    print("   Yazım bitince:  bileyi.sh kart --is <ad> --hedef <yol> [--hedef <yol>…]")
    print("   Sonra:          bileyi.sh devam --is <ad> --dal <dal>")
    return 0


def komut_kart(n) -> int:
    """Kartı AÇAR ve sınıf sorularını kâhinle cevaplar (muhakemeyle değil)."""
    depo = Path(n.depo).resolve()
    kurallar = sinif_kurallari(Path(n.sinif_dosya) if n.sinif_dosya else None)
    c = sinifla(list(n.hedef), kurallar)
    print(f"🔪 sınıf kâhini · hedef yollar: {', '.join(n.hedef)}")
    for alan in ("geri_alinamaz", "para", "dis_yuzey", "yetki"):
        print(f"   {alan:15s} = {c[alan]}")
    print(f"   gerekçe: {c['_gerekce']}")
    if "?" in c.values():
        print("   🔴 '?' var → kanona göre bu iş SULTAN'A GİDER (şüphede sınıf YUKARI)")
    if n.kuru:
        print("(kuru koşum — kart açılmadı)")
        return 0
    kart = FABRIKA / "kart.sh"
    if not kart.exists():
        raise Durdu(f"fabrika kart aracı yok: {kart} — ÖLÇEMEDİM", 3)
    rc, cik = _kos(["bash", str(kart), "ac", n.is_,
                    "--is", n.cumle or "bileyi: tekrar eden sürtünme yeteneğe çevriliyor",
                    "--istedi", "BILEYI", "--aldi", kimlik(depo),
                    "--geri-alinamaz", c["geri_alinamaz"], "--para", c["para"],
                    "--dis-yuzey", c["dis_yuzey"], "--yetki", c["yetki"],
                    "--kanit", f"_agents/fabrika/kanit/{n.is_}"], depo)
    print(cik.strip())
    return 0 if rc == 0 else 1


def komut_devam(n) -> int:
    """Kanıtı toplar, bağımsız gözü koşar, SINIFSIZSA birleştirir.

    🔴 ÜÇ KİLİT, hepsi dosyadan okunur ve fail-closed:
       (1) kill-switch açık olmalı
       (2) kartın sınıfı BOŞ olmalı — sınıflı iş Sultan'ındır
       (3) 🔴 SINIF YENİDEN ÖLÇÜLÜR: kart açıldığında diff yoktu; şimdi var.
           Gerçek sınıf kartta yazandan YUKARI çıkmışsa birleştirme YOK.
           Aşağı inmişse de kartın sınıfı KORUNUR — sınıf aşağı çekilmez.
    """
    depo = Path(n.depo).resolve()
    kapali, gerekce = kapali_mi()
    if kapali:
        print(f"🔴 otonom tur KAPALI — birleştirmiyorum. gerekçe: {gerekce}")
        return 4

    kart_yolu = depo / "_agents" / "fabrika" / "kartlar" / f"{n.is_}.json"
    if not kart_yolu.exists():
        raise Durdu(f"kart yok: {kart_yolu} — kartsız iş birleştirilmez", 3)
    try:
        kart = json.loads(kart_yolu.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise Durdu(f"kart okunamadı: {e}", 2)

    rc, diff = _kos(["git", "diff", "--name-only", f"origin/main...{n.dal}"], depo)
    if rc != 0:
        raise Durdu(f"diff ölçülemedi ({n.dal}): {diff.strip()[:200]}", 3)
    yollar = [y for y in diff.splitlines() if y.strip()]
    if not yollar:
        raise Durdu(f"dalda değişiklik YOK ({n.dal}) — birleştirecek bir şey yok", 3)

    kurallar = sinif_kurallari(Path(n.sinif_dosya) if n.sinif_dosya else None)
    gercek = sinifla(yollar, kurallar)
    gercek_siniflar = {a for a in ("geri_alinamaz", "para", "dis_yuzey", "yetki")
                       if gercek[a] in ("e", "?")}
    kart_siniflar = set(kart.get("siniflar") or [])

    print(f"🔪 devam · iş={n.is_} · dal={n.dal} · {len(yollar)} dosya")
    print(f"   kart sınıfı   : {sorted(kart_siniflar) or 'sınıfsız'}")
    print(f"   ölçülen sınıf : {sorted(gercek_siniflar) or 'sınıfsız'}  ({gercek['_gerekce']})")

    yeni_sinif = gercek_siniflar - kart_siniflar
    if yeni_sinif:
        print(f"   🔴 SINIF YUKARI ÇIKTI: {sorted(yeni_sinif)} — kart açıldığında diff yoktu.")
        print("      Birleştirme YOK. Bu iş Sultan'a gider; kart güncellenmeli.")
        return 1

    if kart.get("sultan") or kart_siniflar:
        print("   🔴 SINIFLI İŞ — birleştirme Sultan'ın. Kanıt ve bağımsız göz koşulacak,")
        print("      birleştirme YAPILMAYACAK.")

    denetci = FABRIKA / "denetci.sh"
    if not denetci.exists():
        raise Durdu(f"bağımsız göz aracı yok: {denetci} — ÖLÇEMEDİM", 3)
    rc2, diffmetin = _kos(["git", "diff", f"origin/main...{n.dal}"], depo, 300)
    if rc2 != 0:
        raise Durdu("diff gövdesi alınamadı", 3)
    gecici = depo / "_agents" / "fabrika" / f".bileyi-{n.is_}.diff"
    gecici.write_text(diffmetin, encoding="utf-8")
    print("   bağımsız göz koşuyor (farklı model)…")
    rc3, cik = _kos(["bash", str(denetci), n.is_, "--diff", str(gecici),
                     "--yazan", "claude", "--depo", str(depo)], depo, 900)
    print("\n".join("   " + l for l in cik.strip().splitlines()[-8:]))
    gecici.unlink(missing_ok=True)
    if "GEÇTİ" not in cik:
        print("   🔴 bağımsız göz GEÇMEDİ — birleştirme YOK, adım 2'ye dön.")
        return 1

    if kart.get("sultan") or kart_siniflar:
        print("\n🔪 Kanıt tam, bağımsız göz geçti. SINIFLI iş → Sultan'ın kapısında bekliyor.")
        return 0

    if n.kuru:
        print("\n(kuru koşum — sınıfsız iş birleştirilebilirdi, birleştirilmedi)")
        return 0
    rc4, cik4 = _kos(["gh", "pr", "merge", "--squash", "--delete-branch", n.dal], depo, 300)
    print(cik4.strip()[:400])
    if rc4 != 0:
        print("   🔴 birleştirme başarısız — el değmeden bırakıldı.")
        return 1
    print("\n✓ SINIFSIZ iş otonom birleştirildi.")
    return _kapanis_damgasi(depo, n.is_, cik4)


def _kapanis_damgasi(depo: Path, is_: str, kanit: str) -> int:
    """Kapatılan tekrarı bulgu havuzuna EKLEYEREK damgalar.

    🔴 Niçin satır ÜSTÜNE yazılmıyor: bulgu havuzu salt-eklemedir. Var olan
    satırları yeniden yazmak bu araca verilmesi gereken yetkiden büyüktür ve
    geçmişi değiştirir. Onun yerine kapatılan kimlikleri ADIYLA sayan bir
    kapanış satırı eklenir — `havuz.py iptal` deseninin aynısı.

    🔴 Damga atlanırsa bir sonraki tur aynı tekrarı yeniden keşfeder; 30 günde
    8 kez ölçüldü. Bu yüzden durum dosyası yoksa SESSİZ GEÇİLMEZ, söylenir.
    """
    durum = tur_durumu_yolu(depo)
    if not durum.exists():
        print("   🟡 tur durumu yok — hangi tekrarın kapandığı BİLİNMİYOR, damga atılmadı.")
        print("      (Sessizce geçmiyorum: damgasız kapanış, aynı tekrarın yeniden")
        print("       keşfedilmesi demektir.)")
        return 0
    try:
        d = json.loads(durum.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"   🟡 tur durumu okunamadı ({e}) — damga atılmadı.")
        return 0
    idler = sorted({i for a in d.get("adaylar", []) for i in a.get("kaynak_bulgular", [])})
    if not idler:
        print("   🟡 tur durumunda kaynak bulgu yok — damga atılmadı.")
        return 0
    havuz = depo / "_agents" / "handoff" / "bulgu-havuzu.jsonl"
    if not havuz.exists():
        print("   🟡 bulgu havuzu yok — damga atılmadı.")
        return 0
    with havuz.open("a", encoding="utf-8") as f:
        f.write(json.dumps({
            "id": f"bileyi-kapanis-{date.today().isoformat()}-{is_}",
            "tarih": date.today().isoformat(),
            "kaynak": "bileyi",
            "sinif": "kapanis-damgasi",
            "baslik": f"'{is_}' indi; kapatılan tekrar: "
                      + ", ".join(a["tekrar"] for a in d.get("adaylar", [])),
            "kapatilan": idler,
            "kanit": kanit.strip()[:300],
            "durum": "kapandi",
        }, ensure_ascii=False) + "\n")
    print(f"   ✓ kapanış damgası eklendi · {len(idler)} kaynak bulgu adıyla sayıldı")
    d["asama"] = "kapandi"
    durum.write_text(json.dumps(d, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


def main(argv: list[str]) -> int:
    a = argparse.ArgumentParser(prog="bileyi", description=__doc__.splitlines()[0])
    a.add_argument("--depo", default=os.environ.get("BILEYI_DEPO", "."),
                   help="ölçülecek odanın deposu (vars. içinde bulunduğun)")
    a.add_argument("--esik-dosya", default=None, help="eşik dosyası (vars. becerinin yanındaki)")
    alt = a.add_subparsers(dest="komut", required=True)

    def ortak(p):
        p.add_argument("--gun", type=int, default=None, help="pencere (gün); 0 = tüm havuz")
        p.add_argument("--ikili-esik", type=int, default=None,
                       help="ikili eşiğini bu koşum için ez (dosyadaki dayanak DEĞİŞMEZ)")

    ortak(alt.add_parser("olc", help="ölçüm raporu — yazmaz"))
    t = alt.add_parser("tur", help="tam tur")
    ortak(t)
    t.add_argument("--kuru", action="store_true")
    alt.add_parser("durum", help="kill-switch ve eşik hâli")
    kt = alt.add_parser("kart", help="kartı aç — sınıfı KÂHİN cevaplar")
    kt.add_argument("--is", dest="is_", required=True)
    kt.add_argument("--hedef", action="append", required=True,
                    help="dokunulacak yol (birden çok verilebilir)")
    kt.add_argument("--cumle", default=None)
    kt.add_argument("--sinif-dosya", default=None)
    kt.add_argument("--kuru", action="store_true")
    dv = alt.add_parser("devam", help="kanıt + bağımsız göz + SINIFSIZSA birleştir")
    dv.add_argument("--is", dest="is_", required=True)
    dv.add_argument("--dal", required=True)
    dv.add_argument("--sinif-dosya", default=None)
    dv.add_argument("--kuru", action="store_true")
    d = alt.add_parser("dur", help="otonom turu kapat")
    d.add_argument("--gerekce", required=True)
    c = alt.add_parser("ac", help="otonom turu aç")
    c.add_argument("--gerekce", required=True)

    n = a.parse_args(argv)
    for alan, vars_ in (("gun", None), ("ikili_esik", None)):
        if not hasattr(n, alan):
            setattr(n, alan, vars_)

    islem = {"olc": komut_olc, "tur": komut_tur, "durum": komut_durum,
             "dur": komut_dur, "ac": komut_ac, "kart": komut_kart,
             "devam": komut_devam}[n.komut]
    try:
        return islem(n)
    except Durdu as e:
        print(f"⛔ {e}", file=sys.stderr)
        return e.rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
