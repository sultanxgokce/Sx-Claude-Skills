"""layiha_defteri_lib — defter okuma/yazmanın TEK kapısı (L24 F4).

NİÇİN AYRI DOSYA: `layiha-defteri.sh` içinde dört ayrı python heredoc'u var ve dördü de aynı üç şeyi
kendi başına yapıyordu (oku · normalize · dosyayı baştan yaz). Aynı işin dört kopyası, üç ayrı hatanın
kaynağıydı: (1) şema-sürümü kontrolü hiçbirinde yoktu, (2) yazma atomik değildi (kısmi-yazım riski),
(3) `liste` bile dosyayı baştan yazıyordu — "sadece listeledim" demek ortak bir dosyada yazma-yarışıydı.

DEĞİŞMEZLER
  · SEMA_V — bu kodun anladığı en yüksek şema-sürümü. Daha YENİ sürümlü bir defter görülürse
    `oku()` RC=2 ile durur ve HİÇBİR yazma yapılmaz: eski bir script yeni şemalı defteri
    ezerek alan kaybettiremez (ileri-uyum kapısı).
  · Sürümsüz eski kayıtlar okuma-anında v=1 sayılır — GÖÇ YOK (kasif-havuz-ekle.sh:20 konvansiyonu).
  · KİLİT OKU→DEĞİŞTİR→YAZ döngüsünün TAMAMINI sarar, yalnız yazmayı değil. İlk sürümde kilit
    sadece `yaz()`'daydı ve testi düşürdü: iki paralel `ekle` boş defteri ikisi de okuyor, ikisi de
    kendi tam-anlık-görüntüsünü yazıyor, ikincisi birincisini siliyordu (kayıp-güncelleme). Artık
    yazacak komutlar `oku(led, kilitle=True)` der; kilit `yaz()` bitince bırakılır.
  · `yaz()` her zaman `os.replace` — yarım dosya diye bir hâl yok.
"""

import io
import json
import os
import sys

SEMA_V = 1


def _hata(msg):
    sys.stderr.write("HATA: %s\n" % msg)
    sys.exit(2)


def proje_adi(kok=None):
    """Kaydın hangi ODAYA ait olduğu. LAYIHA_PROJE ezebilir; yoksa hat-kökünün adı."""
    p = os.environ.get("LAYIHA_PROJE")
    if p:
        return p
    kok = kok or os.environ.get("HAT_KOK") or ""
    return os.path.basename(kok.rstrip("/")) if kok else ""


_KILIT_FH = None


def kilit_al(led):
    """Döngü-kilidi: oku→değiştir→yaz boyunca tutulur. Kilit AYRI dosyada (`.lock`) çünkü defterin
    kendisi `os.replace` ile değişiyor → inode değişir, defterde tutulan kilit yarışı kapatmaz."""
    global _KILIT_FH
    if _KILIT_FH is not None:
        return
    d = os.path.dirname(led) or "."
    try:
        os.makedirs(d, exist_ok=True)
        fh = open(led + ".lock", "a+")
        import fcntl

        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        _KILIT_FH = fh
    except Exception:
        _KILIT_FH = None  # kilit kurulamadıysa da devam — atomiklik `os.replace` ile korunur


def kilit_birak():
    global _KILIT_FH
    if _KILIT_FH is not None:
        try:
            _KILIT_FH.close()
        except Exception:
            pass
        _KILIT_FH = None


def oku(led, norm=True, kilitle=False):
    """Defteri oku → (kayitlar, degisti). Bozuk satır atlanır; ileri-sürüm KAPIDA durdurur.

    norm=True: eksik id/tescil/v/proje alanları BELLEKTE tamamlanır ve degisti=True döner.
    Çağıran bunu diske yazıp yazmamaya kendi karar verir — `liste` YAZMAZ (salt-okur).
    kilitle=True: yazacak komutlar için — kilit burada alınır, `yaz()` bitince bırakılır.
    """
    if kilitle:
        kilit_al(led)
    recs = []
    if os.path.exists(led):
        with io.open(led, encoding="utf-8") as f:
            for l in f:
                if not l.strip():
                    continue
                try:
                    recs.append(json.loads(l))
                except Exception:
                    pass

    for r in recs:
        rv = r.get("v", 1)
        try:
            rv = int(rv)
        except Exception:
            _hata("kayıt %s bozuk şema-sürümü taşıyor (v=%r) — yazma yapılmadı" % (r.get("id", "?"), r.get("v")))
        if rv > SEMA_V:
            _hata(
                "defter şema-sürümü %d, bu araç en fazla %d anlıyor (%s).\n"
                "      Aracı güncelle: Sx-Claude-Skills → sync-skills.mjs --apply.\n"
                "      Hiçbir şey yazılmadı (eski araç yeni defteri ezemez)." % (rv, SEMA_V, led)
            )

    if not norm:
        return recs, False

    def id_num(x):
        try:
            return int(str(x).lstrip("Ll"))
        except Exception:
            return 0

    mx = max([id_num(r.get("id", "")) for r in recs] + [0])
    degisti = False
    proje = proje_adi()
    for r in recs:
        if not r.get("id"):
            mx += 1
            r["id"] = "L%02d" % mx
            degisti = True
        if not r.get("tescil"):
            r["tescil"] = yeni_tescil()
            degisti = True
        if "v" not in r:
            r["v"] = 1
            degisti = True
        if "proje" not in r:
            # Eski kayıtlar hangi odada yazıldıysa orada duruyor → o odanın adı doğru cevaptır.
            r["proje"] = proje
            degisti = True
    return recs, degisti


def yaz(led, recs):
    """Atomik yazma + döngü-kilidini bırakma. Kilit `oku(kilitle=True)`'de alınmış olmalı."""
    d = os.path.dirname(led) or "."
    try:
        os.makedirs(d, exist_ok=True)
        kilit_al(led)  # çağıran kilitlemeden geldiyse en azından yazmayı sarar (no-op if held)
        tmp = led + ".tmp.%d" % os.getpid()
        with io.open(tmp, "w", encoding="utf-8") as f:
            for r in recs:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        os.replace(tmp, led)
    finally:
        kilit_birak()


def yeni_tescil():
    return {
        "durum": "yok", "kart": "", "ajan": "", "tarih": "",
        "muhur_ref": "", "muhur_sha256": "", "deneme": 0, "vites": "", "gerekce": "",
    }
