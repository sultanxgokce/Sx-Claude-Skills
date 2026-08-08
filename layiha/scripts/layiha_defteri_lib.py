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
  · KUYRUK-DEĞİŞMEZİ: `durum=insa-edildi` olan bir kayıt `tescil.durum="yok"` ile duramaz.
    `durum` komutu bunu zaten kuruyordu, ama kayıt başka bir yoldan (elle düzenleme, kural
    konmadan önce yazılmış eski kayıt, dışarıdan üretilmiş satır) o hâle gelebiliyordu ve
    sonuç SESSİZ KAYIPtı: iş bitmiş sayılıyor, `--tescil-bekleyen` listesinde görünmüyor,
    `--aktif`te de "terminal değil" diye kalıyor ama kimse tescile sevk etmiyor.
    Firsthand: L22 (youtube-ai-not-akisi) tam bu hâlde 5 gün görünmez kaldı (2026-07-29).
    Artık okuma-anında norm'lanır → kayıt hangi yoldan gelirse gelsin kuyruğa düşer.
  · KANIT-KAPISI (K7, Sultan-kararı 2026-07-29): `durum=insa-edildi` KANITSIZ ilan edilemez.
    Defterin (defter-mailbox.sh) en iyi özelliği buydu ve layihaya taşınmamıştı: "bitti"
    demek serbestti, kimse ne PR ne commit ne de rapor göstermek zorundaydı. Artık
    insa-edildi'ye geçiş `--kanit <ref>` ister ve ref BİÇİM-DOĞRULANIR (`kanit_gecerli`).
    Geriye-uyum: eski kayıtlarda `insa_kanit` alanı YOKTUR — okuma-anında "" sayılır,
    hata verilmez, göç yapılmaz (v/proje/tescil alanlarıyla aynı konvansiyon).
"""

import io
import json
import os
import re
import sys

SEMA_V = 1

# Bilinen inşa-durumları. `layiha-defteri.sh durum` bu kümeyi YAZMA anında zorluyordu
# (:134) — ama okuma tarafında hiçbir kapı yoktu. Sonuç: başka yoldan giren (elle
# düzenleme · dışarıdan üretilmiş satır · kural konmadan önceki kayıt) bilinmeyen bir
# değer SESSİZCE kabul ediliyordu.
# Firsthand vaka (L44, 2026-08-08): durum="insa-tamam" — sözlükte YOK. Etkisi
# görünmezlik DEĞİL, KALICI-AKTİFLİK: terminal sayılmadığı için `--aktif`te sonsuza
# dek "yapılacak iş" gibi duruyor, ama `insa-edildi` de olmadığı için kuyruk-değişmezi
# onu tescile de sokmuyor → iki yönlü sıkışma, kimse fark etmiyor.
# Karar: DÜZELTMİYORUZ, GÖRÜNÜR KILIYORUZ. Değeri tahmin edip yeniden yazmak niyet
# uydurmaktır (K7 kanıt-kapısının ihlali); doğru davranış onu işaretleyip insana/ajana
# göstermek. "Kayıp meşru olabilir, GÖRÜNMEZ olamaz."
DURUMLAR = ("insa-bekliyor", "insa-ediliyor", "insa-edildi")

# Kabul edilen kanıt biçimleri (K7). Üçünden biri tutmalı:
_KANIT_PR_NO = re.compile(r"^#\d+$")                    # PR referansı: #123
_KANIT_URL = re.compile(r"^https?://\S+$")              # PR/commit URL'i
_KANIT_SHA = re.compile(r"^[0-9a-fA-F]{7,40}$")         # commit sha (≥7 hex)

KANIT_RECETE = (
    'kanıt biçimi: PR ref ("#123" ya da URL) · commit sha (≥7 hex) · '
    "ya da MEVCUT bir dosya yolu (mühür/rapor)"
)


def kanit_gecerli(ref):
    """Kanıt referansı kabul edilebilir mi? (biçim-doğrulama, içerik-doğrulama DEĞİL)"""
    ref = (ref or "").strip()
    if not ref:
        return False
    if _KANIT_PR_NO.match(ref) or _KANIT_URL.match(ref) or _KANIT_SHA.match(ref):
        return True
    # dosya yolu: yalnız GERÇEKTEN VAR ise geçerli — var-olmayan yol "kanıt" değildir
    return os.path.exists(os.path.expanduser(ref))


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
        if "insa_kanit" not in r:
            # GERİYE-UYUM: K7 öncesi kayıtlarda bu alan yok. Eksikliği HATA DEĞİLDİR ve
            # göç gerektirmez — bellekte "" sayılır; kapı yalnız YENİ geçişlerde işler.
            r["insa_kanit"] = ""
            degisti = True
        if "proje" not in r:
            # Eski kayıtlar hangi odada yazıldıysa orada duruyor → o odanın adı doğru cevaptır.
            r["proje"] = proje
            degisti = True
        # KUYRUK-DEĞİŞMEZİ (bkz başlık): inşa bitmiş ama tescil hiç başlamamış kayıt olamaz.
        # Yalnız "yok" → "bekliyor"; tescilli/reddi/muaf/bekliyor'a DOKUNULMAZ (verdikt ezilmez).
        if r.get("durum") == "insa-edildi" and (r["tescil"].get("durum") or "yok") == "yok":
            r["tescil"]["durum"] = "bekliyor"
            degisti = True
        # ŞEMA-DIŞI DURUM KAPISI (2026-08-08): tanımadığımız değeri sessizce geçirmiyoruz.
        # Kayıt DEĞİŞTİRİLMEZ (degisti=True yapılmaz) — yalnız bellekte işaretlenir ve
        # stderr'de bir kez duyurulur. Böylece `liste` onu ⚠️ ile gösterir, `durum` komutu
        # ise düzeltmeyi normal kanıt-kapısından geçerek yapar.
        if r.get("durum") not in DURUMLAR:
            r["_sema_disi_durum"] = True
            sys.stderr.write(
                "⚠️  şema-dışı durum: %s → %r (bilinen: %s)\n"
                "    Bu kayıt ne aktif-kuyruğa ne tescil-kuyruğuna doğru düşer. Düzeltme:\n"
                "    layiha-defteri.sh durum %s <insa-bekliyor|insa-ediliyor|insa-edildi> [--kanit <ref>]\n"
                % (r.get("id", "?"), r.get("durum"), "|".join(DURUMLAR), r.get("id", "?"))
            )
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
