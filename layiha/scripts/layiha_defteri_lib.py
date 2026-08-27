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
  · İŞ-KAYDI ALANLARI (K2/K3/K5/K7-izin, Sultan-kararı 2026-08-08): defter bugüne kadar
    işin NE olduğunu kaydediyordu, ama KİMİN İSTEDİĞİNİ ve HANGİ İZİNLE yapıldığını
    kaydetmiyordu. Sonuç: "bu işi kim istedi?" sorusunun defterde cevabı yoktu — Sultan'ın
    istediği iş ile ajanın kendi kendine açtığı iş aynı görünüyordu, ve bir kalem "yapılıyor"
    durumuna kimin izniyle geçtiği hiç yazılmıyordu.
      `isteyen`    — işi kim istedi (Sultan / ajan adı). Boş = BİLİNMİYOR; tahmin edilmez.
      `yetki`      — hangi yetkiyle açıldı (serbest beyan).
      `insa_izin`  — `insa-ediliyor`a geçerken beyan edilen izin (K7'nin başlangıç-yüzü:
                     "bitti = kanıtlı" ise "başlıyorum = izinli").
      `gecmis`     — ters-kayıt defteri (K5). Kayıt SİLİNMEZ, geri alınır: eski değerler
                     buraya düşer. Muhasebedeki ters-kayıt mantığı — silmek izi yok eder,
                     ters kayıt izi çoğaltır.
    Üçü de geriye-uyumludur: eski kayıtlarda alanlar YOKTUR → okuma-anında "" / [] sayılır.
  · BİLİNMEYEN GİZLENMEZ: `isteyen` boş olan kayıt ne `--sultan` ne `--ajan` süzgecine düşer;
    süzgeç bunu SAYIP EKRANA YAZAR. Bugünün dersi: kayıp meşru olabilir, GÖRÜNMEZ olamaz.
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

# ── NİZAM HÜCRESİ (L66-F2, Sultan onaylı 2026-08-08) ────────────────────────────────
# Sultan'ın şartı: "AI ajan bana 'hangi tip ilişki' diye sormalı — free/kenarsız
# çalışmıyoruz." Ölçüm gösterdi ki onun iki örneği aynı eksende DEĞİL, DİK:
#   SUBSTRAT = taraflar birbirine nasıl ULAŞIR (kanal)
#   AKIŞ     = iş hangi rollerden GEÇER (zincir)
# Bu yüzden katalog düz liste değil MATRİS: 4 substrat × 3 akış = 12 hücre.
#
# Çağıranın burası olmasının sebebi ölçülen yasadır: "bir protokolün adımı, işin ÜRÜNÜNÜ
# üretme yolunun ÜSTÜNDE değilse ölür." Kanıt: ÖLÇÜM akışı canlı (2 günde 41 hüküm,
# kapıdan geçmeden çıktı yok) ⟂ DİVAN akışı 18 Temmuz'dan beri ölü (gönüllü olduğu için).
# Layiha defteri filonun kanıtlı tek canlı yolu (66 kayıt) → kapı buraya takılır.
SUBSTRATLAR = ("OTAG", "MIZAN", "MENZIL", "KAPI")
AKISLAR = ("DIVAN", "LAYIHA", "OLCUM")
# 🔴 `belirsiz` MEŞRUDUR — kapalı küme DAYATMAK işi yanlış kutuya sokar (ölçüldü).
# Hiçbir hücreye oturmayan iş `belirsiz` yazar; bu bir hata değil, YENİ-TİP ARZININ
# ham maddesidir (ÇAVUŞ'un "şüphe = üstlenmeme" emsali). Sayaca girer, gizlenmez.
HUCRE_BELIRSIZ = "belirsiz"
HUCRELER = tuple("%s x %s" % (s, a) for s in SUBSTRATLAR for a in AKISLAR)

HUCRE_RECETE = (
    "hücre biçimi: '<SUBSTRAT> x <AKIŞ>' — substrat: %s · akış: %s "
    "(hiçbirine oturmuyorsa: %s)" % ("/".join(SUBSTRATLAR), "/".join(AKISLAR), HUCRE_BELIRSIZ)
)


def hucre_normalize(deger):
    """Serbest yazımı kanonik biçime çeker: boşluk/büyük-küçük/ayraç toleransı.

    'mizan x olcum' · 'MIZAN×OLCUM' · 'MIZAN  X  OLCUM' → 'MIZAN x OLCUM'
    Tolerans BİÇİMDE olur, KÜMEDE değil: tanınmayan ad yine reddedilir.
    """
    m = (deger or "").strip()
    if not m:
        return ""
    if m.casefold() == HUCRE_BELIRSIZ.casefold():
        return HUCRE_BELIRSIZ
    parcalar = [p for p in re.split(r"\s*[x×X]\s*|\s+", m) if p]
    if len(parcalar) != 2:
        return m                      # bozuk → olduğu gibi dön, kapı reddetsin
    return "%s x %s" % (parcalar[0].upper(), parcalar[1].upper())


def hucre_gecerli(deger):
    """Kapalı küme + `belirsiz`. Boş değer BURADA geçerli sayılmaz —
    'zorunlu mu' kararı çağıranın (ekle kapısı) işidir, doğrulayıcının değil."""
    n = hucre_normalize(deger)
    return n == HUCRE_BELIRSIZ or n in HUCRELER

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


IZIN_RECETE = (
    'izin beyanı: kim/ne yetkilendirdi — D1-damga biçimi önerilir: '
    '"2026-08-27 Sultan: GO (sohbet · <oturum-ref> · \\"<≤15-kelime kırpık>\\" · beyan:<AJAN>)" · '
    'ör. "Sultan onayı 2026-08-08" · "L63 izin paketi md-4". '
    'A06: araç Sultan\'ın sözünü ÜRETMEZ — bu alan ajanın GÖRDÜĞÜ onayın referans-beyanıdır'
)


def izin_gecerli(ref):
    """İzin beyanı kabul edilebilir mi? (biçim, içerik DEĞİL — beyan insanın sözüdür)

    Tek kapı: boş ya da içi-boş yer-tutucu olmasın. "-" / "yok" / "?" gibi kaçamaklar
    beyanın kendisini anlamsız kılar; onları reddetmek gate'in var olma sebebidir.
    """
    ref = (ref or "").strip()
    if len(ref) < 3:
        return False
    return ref.lower() not in ("yok", "n/a", "na", "---", "???", "bos", "boş")


# ── DOĞRULAMA KOMUTU (L35-F1, "bayat kayıt" panzehiri · 2026-08-12) ──────────────
# NİÇİN: kayıtlar İDDİA biçiminde yazılıyordu, ÖLÇÜM biçiminde değil. "🔴 ekip henüz
# giremiyor" bir cümledir — doğruluğu ancak bir insan gidip bakarsa anlaşılır. Ölçüldü
# (bayat-kayit-DESIGN §2): 28 kırmızı-bayraklı kaydın 12'si 5-6 haftadır hiç sınanmamıştı,
# ikisi Sultan'ın gözünde ÇOKTAN BİTMİŞTİ. Kayıt yanına "yanlışsa şu komut gösterir"
# yazsaydı tazelik SANİYEDE sınanırdı.
#
# Bu yüzden YENİ açık-iş kayıtları tek satırlık bir doğrulama komutu taşır. Kapı yalnız
# YENİ kayıtlara işler; ESKİ kayıtlarda alan YOKTUR → okuma-anında "" sayılır, hata yok,
# GÖÇ YOK (insa_kanit/isteyen/hucre alanlarıyla birebir aynı konvansiyon).
#
# 🔴 DEĞER-OKUMAZ ŞART (DESIGN §8 risk-3): komut bir sırrı/token'ı EKRANA BASAMAZ. Defterin
# kendisi paylaşılan bir dosyadır ve içeriği transkripte düşer — "doğrulama" diye bir
# `cat .env` yazmak, sır-değer kuralını kaydın içinden delmek olurdu. Kabul edilen biçim
# filonun zaten uyguladığı biçimdir: varlık-grep (`-c`/`-q`), çıkış-kodu, sayı.
DOGRULA_RECETE = (
    'doğrulama komutu: TEK satır, DEĞER-OKUMAZ — sayı/varlık/çıkış-kodu döndürsün. '
    'Ör: `grep -c "^cell_id: s02" filo-registry.yaml` · `systemctl is-active nexus` · '
    '`test -f /opt/nexus/deploy/preflight.sh; echo $?`'
)

# Bariz sır-okuma kalıpları. Tam bir güvenlik-çözümleyicisi DEĞİL (öyle olduğunu iddia
# etmek K01 ihlali olurdu) — kasıt-dışı sızıntının en sık üç kalıbını kapatan bir kapı:
# env-dosyası dökme · sır-değişkeni ekrana basma · kasadan değer çekme.
_SIR_DESENLERI = (
    (re.compile(r"\b(cat|less|more|head|tail|bat|nl|xxd|od)\b[^|;&]*\.env\b", re.I),
     "env dosyasını ekrana döküyor"),
    (re.compile(r"\b(grep|sed|awk|rg)\b(?![^|;&]*\s-[a-zA-Z]*[cql])[^|;&]*\.env\b", re.I),
     "env dosyasından DEĞER okuyor (varlık-grep için -c/-q kullan)"),
    # `env` yalnız KOMUT olarak yasak; `ui/.env` gibi bir DOSYA ADININ sonu değil
    # (ilk yazımda `\benv` ".env"i de yakalayıp meşru `grep -c TOKEN ui/.env`i reddetti).
    (re.compile(r"\bprintenv\b|(?<![\w./\\-])env\s*(\||$)", re.I),
     "tüm ortam değişkenlerini basıyor"),
    (re.compile(r"\$\{?[A-Za-z_]*(TOKEN|SECRET|PASSWORD|PASSWD|APIKEY|API_KEY|_KEY)\b", re.I),
     "sır taşıyan değişkeni genişletiyor"),
    (re.compile(r"\b(vault-cek|infisical|bao|vault)\b[^|;&]*\b(get|read|oku|export|secrets)\b", re.I),
     "kasadan sır DEĞERİ çekiyor"),
    (re.compile(r"\bcred\.sh\b[^|;&]*\b(get|oku|show|print)\b", re.I),
     "credential aracından değer okuyor"),
)


def dogrula_sir_riski(komut):
    """Komut bariz bir sır-okuma kalıbı taşıyor mu? → sebep metni ya da ""."""
    k = (komut or "").strip()
    for desen, sebep in _SIR_DESENLERI:
        if desen.search(k):
            return sebep
    return ""


def dogrula_gecerli(komut):
    """Biçim kapısı: TEK satır, anlamlı uzunlukta, yer-tutucu değil.

    (İçerik-doğrulama DEĞİL — komutun gerçekten doğru şeyi ölçtüğünü hiçbir regex bilemez;
    `izin_gecerli` emsali: kapı yer-tutucuyu eler, hükmü yazana bırakır.)
    """
    k = (komut or "").strip()
    if len(k) < 4:
        return False
    if "\n" in k or "\r" in k:
        return False
    return k.lower() not in ("yok", "n/a", "na", "---", "???", "bos", "boş", "true", "echo ok")


# ── K2 KAPALI-BİÇİM (Sultan-onaylı K#1 çatı, 2026-08-27 · NÂZIR-mutabık K2) ─────────────
# `isteyen`/`yetki` bugüne dek serbest metindi ("SERDAR", "sözlü direktif") — makine
# ayrıştıramıyordu (S5: Sultan'ın işi ile ajanınki ayırt EDİLEMİYORDU). Artık kapalı biçim:
#   isteyen: `sultan` ya da `<oda>/<rol>` (ör. s13/mim) — regex aşağıda.
#   yetki  : sultan-emri | oda-ici | odalar-arasi (kapalı küme).
# Tolerans BİÇİMDE olur, KÜMEDE değil (hucre_normalize emsali): "Sultan"/"S13/MIM" küçük
# harfe çekilir, tanınmayan değer RC=2. ESKİ serbest-metin kayıtlar okuma-anında AYNEN
# yaşar — kapı yalnız YENİ yazımda işler, göç yok.
ISTEYEN_RE = re.compile(r"^(sultan|[a-z0-9-]+/[a-z0-9-]+)$")
ISTEYEN_RECETE = (
    "isteyen biçimi: `sultan` ya da `<oda>/<rol>` (küçük harf, ör. s13/mim · s01/serdar)"
)
YETKILER = ("sultan-emri", "oda-ici", "odalar-arasi")
YETKI_RECETE = "yetki kapalı kümedir: %s" % " | ".join(YETKILER)


def isteyen_normalize(v):
    return (v or "").strip().lower()


def isteyen_gecerli(v):
    return bool(ISTEYEN_RE.match(isteyen_normalize(v)))


def yetki_normalize(v):
    return (v or "").strip().lower()


def yetki_gecerli(v):
    return yetki_normalize(v) in YETKILER


# ── K6 ODA-ÖNEKLİ KOD ÇÖZÜMÜ (2026-08-27) ────────────────────────────────────────────────
# Girdi `s01-L13` biçiminde gelebilir; defterdeki kod alanı DEĞİŞMEZ (append-only).
# Kendi öneki → soyulur (hem "s01-L13" hem "L13" aday olur; defterde hangisi varsa o bulunur).
# Yabancı-oda öneki → hata metni döner (fail-closed: başka odanın kaydına burada dokunulmaz).
ODA_KOD_RE = re.compile(r"^(s\d{2})-([Ll]\d+)$")


def kod_adaylari(key, onek):
    """→ (aday_listesi, hata_metni). Hata doluysa adaylar boştur."""
    k = (key or "").strip()
    m = ODA_KOD_RE.match(k)
    if not m:
        return [k], ""
    if onek and m.group(1).lower() != onek.lower():
        return [], ("bu defter %s defteri — '%s' öneki başka odanın kaydına işaret ediyor "
                    "(o odanın kendi defterinde işlem yap)" % (onek, m.group(1)))
    return [k, m.group(2)], ""


def kayit_eslesir(rec, adaylar):
    """slug tam-metin · id büyük/küçük-duyarsız — mevcut eşleşme kuralının aday-listeli hâli."""
    rid = str(rec.get("id", "")).lower()
    for a in adaylar:
        if rec.get("slug") == a or rid == a.lower():
            return True
    return False


def kim_suzgec(rec, kim):
    """K3 süzgeç-yüklemi (2026-08-27 genişletme): --sultan artık yetki-eksenini de görür.
    sultan     → isteyen==sultan VEYA yetki==sultan-emri
    ajan       → isteyen dolu VE sultan değil
    bilinmiyor → isteyen boş (eski kayıtlar; tahmin edilmez)"""
    if kim == "sultan":
        return kim_sinifi(rec) == "sultan" or yetki_normalize(rec.get("yetki")) == "sultan-emri"
    if kim == "ajan":
        return kim_sinifi(rec) == "ajan"
    if kim == "bilinmiyor":
        return kim_sinifi(rec) == "bilinmiyor"
    return True


def kim_sinifi(rec):
    """Kaydı isteyen kim? → "sultan" | "ajan" | "bilinmiyor".

    "bilinmiyor" AYRI bir sınıftır, "ajan"ın alt-kümesi DEĞİL: alanı olmayan eski kayıtları
    ajana yazmak, ölçmediğimiz şeyi ölçmüş gibi göstermek olurdu.
    """
    v = (rec.get("isteyen") or "").strip()
    if not v:
        return "bilinmiyor"
    return "sultan" if v.lower() in ("sultan", "sultân") else "ajan"


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

    # K6 (2026-08-10, hücre-öneki): kod artık öneksiz ("L36") ya da <CELL>-önekli ("s04-L36")
    # olabilir — sayaç ikisini de aynı numaralandırmada tutmalı, aksi hâlde backfill eski
    # bir numarayı yeniden kullanır ve iki kayıt aynı sayıyı taşır (görünüşte farklı, aslında
    # çakışan kod). Regex trailing-digit'i alır; önek numaralandırmayı etkilemez.
    def id_num(x):
        m = re.search(r"[Ll](\d+)$", str(x))
        return int(m.group(1)) if m else 0

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
        # İŞ-KAYDI ALANLARI (K2/K7-izin/K5) — aynı geriye-uyum konvansiyonu: yoksa boş,
        # hata yok, göç yok. Boş `isteyen` "ajan" demek DEĞİL, "bilinmiyor" demektir.
        # `hucre` (L66-F2) da aynı konvansiyon: eski 66 kayıtta YOKTUR → "" sayılır,
        # hata verilmez, göç yapılmaz. Boş `hucre` "belirsiz" DEMEK DEĞİLDİR:
        # belirsiz = ajan baktı ve oturmadı (bilgi); boş = hiç sorulmadı (bilgisizlik).
        # İkisini birbirine karıştırmak, ölçmediğini ölçmüş saymaktır.
        # `dogrula` (L35-F1) da aynı geriye-uyum konvansiyonu: ESKİ kayıtlarda YOKTUR →
        # "" sayılır, hata verilmez, göç yapılmaz. Boş `dogrula` = "bu kaydın tazeliği
        # ölçülemez" demektir; kayıt yine de listelenir, süzgeçlerden düşmez.
        for _alan in ("isteyen", "yetki", "insa_izin", "hucre", "dogrula"):
            if _alan not in r:
                r[_alan] = ""
                degisti = True
        if "gecmis" not in r:
            r["gecmis"] = []
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
