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


# ───────────────────────────────────────── kill-switch

def anahtar_yolu() -> Path:
    return Path(os.environ.get("BILEYI_ANAHTAR", "")) or Path("/config/.claude/bileyi-kapali")


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


def komut_olc(n) -> int:
    depo = Path(n.depo).resolve()
    kim = kimlik(depo)
    es = esik_oku(esik_dosyasi(n))
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
    s1 = [(k, v) for k, v in o["sinif"].most_common() if v >= sn_esik]
    if s1:
        for k, v in s1[:10]:
            print(f"   {v:3d} × {k[:80]}")
            bulunan.append(("sinif", k, v))
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
                bulunan.append(("ikili", k, v))
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
    if not bulunan:
        print("✓ eşiği aşan TEKRAR YOK — bileyecek bir şey çıkmadı (bu bir ölçümdür, iddia değil)")
        return 1
    print(f"🔪 eşiği aşan {len(bulunan)} tekrar var · tavan {es['tavan']} yetenek/tur")
    print("   🔴 Bu bir GİRDİdir, hüküm değil: hangi cinsten yetenek üretileceği")
    print("      (kural · yapılandırma · beceri) muhakeme ister — ÖNCE 'kural var mı,")
    print("      koşuyor mu' sorulur; var olanı kapıya bağlamak yeni beceri yazmaktan ucuzdur.")
    print("   🔴 ÖLÇMEDİĞİM: bu sürtünmelerin MALİYETİ. Kaç kez olduğunu saydım,")
    print("      kaç dakika yediğini bilmiyorum ve oraya temiz demiyorum.")
    return 0


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


def komut_tur(n) -> int:
    kapali, gerekce = kapali_mi()
    if kapali and not n.kuru:
        print(f"🔴 otonom tur KAPALI — koşmuyorum. gerekçe: {gerekce}")
        print("   Açmak Sultan kararıdır: bileyi.sh ac --gerekce \"…\"")
        return 4
    rc = komut_olc(n)
    if rc != 0:
        return rc
    print()
    print("── SIRADAKİ (fabrika hattı — bu araç kod YAZMAZ, hattı çağırır)")
    print("   0 KABUL  · kart.sh ac <iş> … · sınıf sorularını ÖLÇÜMDEN cevapla, gerekçeyi karta yaz")
    print("   1 İZOLE  · is-alani.sh ac <iş>")
    print("   2 İNŞA   · önce 'kural var mı, koşuyor mu'")
    print("   3 KANIT  · kanit.sh olcum … (önce/sonra · pozitif kontrol · mutasyon)")
    print("   4 GÖNDER · denetci.sh (bağımsız göz) → sınıfsız: kendin birleştir · sınıflı: Sultan")
    print("   5 KAYDET · kapatılan tekrarı bulgu satırlarına damgala")
    if n.kuru:
        print("\n(kuru koşum — hiçbir şey yazılmadı)")
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
    d = alt.add_parser("dur", help="otonom turu kapat")
    d.add_argument("--gerekce", required=True)
    c = alt.add_parser("ac", help="otonom turu aç")
    c.add_argument("--gerekce", required=True)

    n = a.parse_args(argv)
    for alan, vars_ in (("gun", None), ("ikili_esik", None)):
        if not hasattr(n, alan):
            setattr(n, alan, vars_)

    islem = {"olc": komut_olc, "tur": komut_tur, "durum": komut_durum,
             "dur": komut_dur, "ac": komut_ac}[n.komut]
    try:
        return islem(n)
    except Durdu as e:
        print(f"⛔ {e}", file=sys.stderr)
        return e.rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
