#!/usr/bin/env python3
"""retro.py — haftalık retro: araç ÖLÇER, ajan YORUMLAR, merkez TOPLAR, süzüm KANITLANIR.

Niçin var (Sultan 17 Eki 2026, beyan SERDAR): haftanın dersleri yalnız merkezin yorumuyla değil,
HER ajanın kendi gözüyle de merkeze aksın; akış sistemli olsun ki süzülsün. Ölçüm (17 Eki): ajanların
kendi "ders/zaman kaybı" satırı BÂNİ 11/100 · MUAVİN 1/21 · MİRAHUR 0 · MUHAKKİK 0 — kanal yoktu.

Beş alt komut:
  kutu   <AJAN>   ajanın haftasını ölçer, retro dosyasının iskeletini yazar (5 başlık boş; ajan doldurur)
  doldur <AJAN> --metin <dosya|->   ajanın yazdığı 5 başlığı iskelete ARAÇ yerleştirir (ana dal kapısı Edit/Write'ı
                  reddeder; ölçüm/imza satırları dosyada kalır, metinden alınmaz; lint'ten geçmeyen sonuç YAZILMAZ)
  lint   <dosya>  retro dosyası şemaya uyuyor mu (başlık · imza · ölçüm bloğu · 5 başlık dolu · ölçülü zaman kaybı)
  merkez          kutu retrolarını toplar: OK / GEÇERSİZ / EKSİK / ÇALIŞMADI; MERKEZ.md iskeleti (Süzüm listesi)
  suzum           her "merkeze öneri" maddesi MERKEZ.md'de → gorev_… ya da → RED: … damgası aldı mı

Dürüst sınırlar (K01: ölçemediğin kuralı sert ilan edemezsin):
  • NOTES satırlarının tarihi çoğunlukla satırda yok; satır üstündeki son açık tarihi devralır
    (çıpa başlığı ya da tarihli satır). Tarih çözülemeyen satır SAYILMAZ, "tarihsiz" olarak ayrıca basılır.
  • Kaçış defteri ajan alanı taşımaz → sayı KUTU GENELİdir, böyle etiketlenir.
  • "Sultan-eli adımı" için tanımlı kaynak yok → ÖLÇÜLEMEDİ basılır, 0 değil.
  • Dosyayı kimin yazdığı ölçülemez (hepimiz aynı git kimliğiyiz); _koltuk satırı BEYANdır, kanıt değil.
Çıkış kodları (fabrika rengiyle aynı): 0 yeşil · 1 KIRMIZI (lint/süzüm/merkez EKSİK-GEÇERSİZ: ölçtü, tutmuyor) ·
  2 kullanım hatası · 3 SARI (ölçemedi: ajan listesi ya da MERKEZ.md yok) · 4 dosya zaten var
"""
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
from datetime import date, datetime, timedelta

SURUM = "1.2.0"
AJAN_DIZIN_DISI = {"handoff", "fabrika", "spec", "orchestration", "codex", "decisions", "runbooks", "ekip-os-base"}
DERS_RE = re.compile(r"ders|zaman kayb|zorluk|tıkand|tikand|boşa|bosa", re.I)
TARIH_RE = re.compile(r"(20\d\d-\d\d-\d\d)")
GOREV_RE = re.compile(r"gorev_[0-9A-Z]{26}")
ETIKETLER = {"1": "B", "2": "Z", "3": "A", "4": "D", "5": "Ö"}
BASLIKLAR = [
    ("1", "Ne bitti"),
    ("2", "Nerede zaman kaybettim (ölçüyle)"),
    ("3", "Hangi araç/kural beni yavaşlattı"),
    ("4", "Ne öğrendim"),
    ("5", "Merkeze önerim"),
]
MADDE_RE = re.compile(r"^- ([BZADÖ])(\d+)\) (.+)$")
YER_TUTUCU_RE = re.compile(r"<[^>]{1,60}>|…")
YORUM_NOTU = "<!-- Yorum satırları ajanındır; merkez bunları DEĞİŞTİRMEZ. Z maddesi ölçüsüz geçmez. Ö maddesi en çok 5. -->"


# ───────────────────────── yardımcılar ─────────────────────────
def norm(s):
    s = (s or "").replace("İ", "i").replace("I", "ı")
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]", "", s.lower().replace("ı", "i"))


def bugun():
    v = os.environ.get("RETRO_BUGUN")
    return date.fromisoformat(v) if v else date.today()


def bu_hafta(g=None):
    g = g or bugun()
    y, w, _ = g.isocalendar()
    return f"{y}-W{w:02d}"


def hafta_araligi(hafta):
    m = re.fullmatch(r"(\d{4})-W(\d{2})", hafta or "")
    if not m:
        raise ValueError(f"hafta biçimi YYYY-Www olmalı: {hafta!r}")
    pzt = date.fromisocalendar(int(m.group(1)), int(m.group(2)), 1)
    return pzt, pzt + timedelta(days=6)


def kok_bul(arg):
    k = arg or os.environ.get("RETRO_KOK")
    if k:
        return os.path.abspath(k)
    try:
        return subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return os.getcwd()


def retro_dizin(kok, hafta):
    return os.path.join(kok, "_agents", "handoff", "retro", hafta)


def ajan_dizini(kok, ajan):
    for d in sorted(glob.glob(os.path.join(kok, "_agents", "*"))):
        ad = os.path.basename(d)
        if ad in AJAN_DIZIN_DISI or not os.path.isdir(d):
            continue
        if norm(ad) == norm(ajan):
            return d
    return None


def tarih_cek(s):
    m = TARIH_RE.search(s)
    if not m:
        return None
    try:
        return date.fromisoformat(m.group(1))
    except ValueError:
        return None


def aralikta(d, pzt, paz):
    return d is not None and pzt <= d <= paz


# ───────────────────────── ölçüm kaynakları ─────────────────────────
def notes_olc(kok, ajan, pzt, paz):
    d = ajan_dizini(kok, ajan)
    if not d or not os.path.exists(os.path.join(d, "NOTES.md")):
        return None
    yol = os.path.join(d, "NOTES.md")
    son = None
    toplam = ders = tarihsiz = 0
    for satir in open(yol, encoding="utf-8", errors="replace"):
        s = satir.rstrip("\n")
        if not s.strip():
            continue
        t = tarih_cek(s)
        if t:
            son = t
        if not s.startswith("["):
            continue  # yalnız mesaj satırları sayılır
        if son is None:
            tarihsiz += 1
            continue
        if aralikta(son, pzt, paz):
            toplam += 1
            if DERS_RE.search(s):
                ders += 1
    return {"yol": os.path.relpath(yol, kok), "satir": toplam, "ders": ders, "tarihsiz": tarihsiz}


def depolar(kok):
    """Kart/göz ölçüsünün tarandığı depolar (CQ46Y + NFS16): ajan iş kartını hangi depoda açtıysa orada durur (kart.sh birincil
    depoya yazar) → yalnız KOK'a bakan retro W42'de Sx işini hiç görmedi. RETRO_DEPOLAR (':' ayraçlı) verilirse o liste; yoksa
    RETRO_DEPO_KOKU (varsayılan /config/projects) altında kartlar dizini olan BİRİNCİL depolar — izole kutuda bu, kutunun kendi
    depo listesidir; _wt/… çalışma kopyaları iki seviye derinde olduğu için sayılmaz. KOK hep ilk sıradadır; aynı depo bir kez."""
    aday = [kok]
    if os.environ.get("RETRO_DEPOLAR"):
        aday += [d for d in os.environ["RETRO_DEPOLAR"].split(":") if d]
    else:
        kok_d = os.environ.get("RETRO_DEPO_KOKU", "/config/projects")
        aday += [os.path.dirname(os.path.dirname(os.path.dirname(k)))
                 for k in sorted(glob.glob(os.path.join(kok_d, "*", "_agents", "fabrika", "kartlar")))]
    gorulen, out = set(), []
    for d in aday:
        r = os.path.realpath(d)
        if r not in gorulen and os.path.isdir(os.path.join(d, "_agents", "fabrika", "kartlar")):
            gorulen.add(r); out.append(d)
    return out


def denetim_adlari(depo, is_):
    """Bir işin göz turu kayıtları: diskteki kopya ∪ origin/main ağacı. Birincil kopya bayat ya da başka dalda olabilir
    (20 Eki: Sx birincili layiha dalında, birleşmiş işlerin kanıt dizini diskte yok) → yalnız disk sayımı turları eksik gösterirdi."""
    ad = {os.path.basename(p) for p in glob.glob(os.path.join(depo, "_agents", "fabrika", "kanit", is_, "DENETIM-*.json"))}
    try:
        r = subprocess.run(["git", "-C", depo, "ls-tree", "--name-only", "origin/main", f"_agents/fabrika/kanit/{is_}/"],
                           capture_output=True, text=True, timeout=10)
        if r.returncode == 0:
            ad |= {os.path.basename(s) for s in r.stdout.split("\n") if re.fullmatch(r"DENETIM-\d+\.json", os.path.basename(s))}
    except Exception:
        pass
    return ad


def kart_olc(kok, ajan, pzt, paz):
    dl = depolar(kok)
    if not dl:
        return None
    acilan = bitti = tikandi = 0
    turlar, dokum = [], []
    for depo in dl:
        da = db = dt = 0
        for yol in sorted(glob.glob(os.path.join(depo, "_agents", "fabrika", "kartlar", "*.json"))):
            try:
                k = json.load(open(yol, encoding="utf-8"))
            except Exception:
                continue
            if norm(k.get("aldi", "")) != norm(ajan):
                continue
            z = tarih_cek(str(k.get("zaman", "")))
            b = tarih_cek(str(k.get("bitis", "")))
            if aralikta(z, pzt, paz):
                da += 1
            if aralikta(b, pzt, paz):
                if k.get("durum") == "bitti":
                    db += 1
                elif k.get("durum") == "tikandi":
                    dt += 1
            if aralikta(z, pzt, paz) or aralikta(b, pzt, paz):
                turlar.append(len(denetim_adlari(depo, k.get("is", "?"))))
        acilan += da; bitti += db; tikandi += dt
        dokum.append(f"{os.path.basename(os.path.realpath(depo))} {da}/{db}/{dt}")
    return {
        "yol": "_agents/fabrika/kartlar", "depolar": dokum, "acilan": acilan, "bitti": bitti, "tikandi": tikandi,
        "goz_turu": sum(turlar), "kart": len(turlar),
        "ort_tur": (round(sum(turlar) / len(turlar), 1) if turlar else None),
    }


def kacis_olc(kok, pzt, paz):
    yol = os.path.join(kok, "_agents", "fabrika", "kacis-defteri.log")
    if not os.path.exists(yol):
        return None
    n = sum(1 for s in open(yol, encoding="utf-8", errors="replace") if aralikta(tarih_cek(s[:25]), pzt, paz))
    return {"yol": os.path.relpath(yol, kok), "sayi": n}


def bekci_olc(ajan, pzt, paz):
    yol = os.environ.get("RETRO_BEKCI_LOG", "/config/.filo/bosta-bekcisi.log")
    if not os.path.exists(yol):
        return None
    n = 0
    for s in open(yol, encoding="utf-8", errors="replace"):
        p = s.split()
        if len(p) < 3 or p[2] == "TUR" or norm(p[2]) != norm(ajan):
            continue
        if aralikta(tarih_cek(p[0]), pzt, paz):
            n += 1
    return {"yol": yol, "sayi": n}


def olc(kok, ajan, hafta):
    pzt, paz = hafta_araligi(hafta)
    return {
        "ajan": ajan, "hafta": hafta, "pzt": pzt.isoformat(), "paz": paz.isoformat(),
        "notes": notes_olc(kok, ajan, pzt, paz),
        "kart": kart_olc(kok, ajan, pzt, paz),
        "kacis": kacis_olc(kok, pzt, paz),
        "bekci": bekci_olc(ajan, pzt, paz),
    }


def iz_var(o):
    n, k = o.get("notes"), o.get("kart")
    return bool((n and n["satir"] > 0) or (k and (k["acilan"] + k["bitti"] + k["tikandi"]) > 0))


def olcum_tablosu(o):
    def sat(kaynak, deger, kanit):
        return f"| {kaynak} | {deger} | {kanit} |"
    r = ["## Ölçüm (araç yazdı · elle değiştirilmez · `retro.py kutu --yenile` yeniler)",
         f"_aralık: {o['pzt']} → {o['paz']}_", "", "| Kaynak | Değer | Kanıt |", "|---|---|---|"]
    n = o["notes"]
    if n:
        r.append(sat("NOTES mesaj satırı", f"{n['satir']} (tarihsiz {n['tarihsiz']} sayılmadı)", f"`{n['yol']}`"))
        r.append(sat("ders / zaman kaybı / tıkanma satırı", str(n["ders"]), "aynı dosya, anahtar kelime"))
    else:
        r.append(sat("NOTES mesaj satırı", "ÖLÇÜLEMEDİ: _agents/<ajan>/NOTES.md yok", "—"))
        r.append(sat("ders / zaman kaybı / tıkanma satırı", "ÖLÇÜLEMEDİ: kaynak yok", "—"))
    k = o["kart"]
    if k:
        r.append(sat("kart açılan / bitti / tıkandı", f"{k['acilan']} / {k['bitti']} / {k['tikandi']}",
                     f"`{k['yol']}` (aldı = ajan) · {len(k['depolar'])} depo: " + " · ".join(k["depolar"])))
        ort = "—" if k["ort_tur"] is None else str(k["ort_tur"])
        r.append(sat("bağımsız göz turu · ortalama tur/kart", f"{k['goz_turu']} · {ort}", "`_agents/fabrika/kanit/*/DENETIM-*.json` (disk ∪ origin/main)"))
    else:
        r.append(sat("kart açılan / bitti / tıkandı", "ÖLÇÜLEMEDİ: fabrika kartları yok", "—"))
        r.append(sat("bağımsız göz turu · ortalama tur/kart", "ÖLÇÜLEMEDİ: kaynak yok", "—"))
    c = o["kacis"]
    r.append(sat("kaçış (KUTU GENELİ, ajan ayrımı yok)", str(c["sayi"]) if c else "ÖLÇÜLEMEDİ: kaçış defteri yok", f"`{c['yol']}`" if c else "—"))
    b = o["bekci"]
    r.append(sat("boşta bekçisi zili", str(b["sayi"]) if b else "ÖLÇÜLEMEDİ: bekçi günlüğü yok", f"`{b['yol']}`" if b else "—"))
    r.append(sat("Sultan-eli adımı", "ÖLÇÜLEMEDİ: tanımlı kaynak yok", "—"))
    return "\n".join(r)


# ───────────────────────── kutu ─────────────────────────
def kutu(a):
    kok = kok_bul(a.get("--kok"))
    ajan = a["ajan"]
    hafta = a.get("--hafta") or bu_hafta()
    o = olc(kok, ajan, hafta)
    diz = retro_dizin(kok, hafta)
    yol = os.path.join(diz, f"{ajan}.md")
    yenile = "--yenile" in a
    if os.path.exists(yol) and not yenile:
        print(f"✗ dosya zaten var: {os.path.relpath(yol, kok)} — ölçümü yenilemek için --yenile (yorumlara dokunmaz)")
        return 4
    koltuk = a.get("--koltuk") or os.environ.get("TMUX_PANE_HEDEF") or ""
    simdi = datetime.now().astimezone().replace(microsecond=0).isoformat()
    tablo = olcum_tablosu(o)
    if os.path.exists(yol) and yenile:
        eski = open(yol, encoding="utf-8").read()
        yeni, n = re.subn(r"## Ölçüm \(araç yazdı.*?(?=\n## 1 · )", tablo + "\n", eski, count=1, flags=re.S)
        if n != 1:
            print("✗ ölçüm bloğu bulunamadı, yenilenemedi (dosya elle bozulmuş olabilir)")
            return 2
        yeni = re.sub(r"^_olcum_yenilendi: .*$", f"_olcum_yenilendi: {simdi}", yeni, flags=re.M)
        if "_olcum_yenilendi:" not in yeni:
            yeni = yeni.replace("\n\n## Ölçüm", f"\n_olcum_yenilendi: {simdi}\n\n## Ölçüm", 1)
        open(yol, "w", encoding="utf-8").write(yeni)
        print(f"✓ ölçüm yenilendi: {os.path.relpath(yol, kok)}")
    else:
        os.makedirs(diz, exist_ok=True)
        bolumler = []
        for no, ad in BASLIKLAR:
            et = ETIKETLER[no]
            ipucu = {"B": "<bitirdiğin iş · PR/kart>", "Z": "<nerede> · ölçü: <sayı birim>",
                     "A": "<araç ya da kural> · <nasıl yavaşlattı>", "D": "<ders tek cümle>",
                     "Ö": "<merkeze öneri tek cümle>"}[et]
            bolumler.append(f"## {no} · {ad}\n- {et}1) {ipucu}\n")
        govde = (
            f"# 🔁 HAFTALIK RETRO · {hafta} · {ajan}\n"
            f"_koltuk: {koltuk}\n_kutu: {os.uname().nodename}\n_yazildi: {simdi}\n_arac: retro.py {SURUM}\n\n"
            f"{tablo}\n\n" + "\n".join(bolumler) +
            "\n" + YORUM_NOTU + "\n"
        )
        open(yol, "w", encoding="utf-8").write(govde)
        print(f"✓ iskelet yazıldı: {os.path.relpath(yol, kok)} — 5 başlığı doldur, sonra `retro.py lint` koş")
    print(f"  iz: {'VAR' if iz_var(o) else 'YOK'} · notes {o['notes']['satir'] if o['notes'] else '—'} · "
          f"kart {o['kart']['acilan'] if o['kart'] else '—'}/{o['kart']['bitti'] if o['kart'] else '—'}/{o['kart']['tikandi'] if o['kart'] else '—'}")
    if "--json" in a:
        print(json.dumps(o, ensure_ascii=False))
    return 0


# ───────────────────────── doldur ─────────────────────────
# Niçin (retro W42 MİRAHUR Ö1 · gorev_01M57ZV2C26H9VZ9VX2XSKHX56): `kutu` iskeleti paylaşılan ana ağaca yazar, ama ana dal
# kapısı o ağaçta Edit/Write'ı reddeder — ajan iskeleti dolduramıyordu. Kapı GEVŞETİLMEZ; dolumu araç yapar (Bash'ten,
# append-note.sh gibi). Ajan metni ağaç dışında (taslak dosya ya da stdin) yazar; araç yalnız 5 yorum başlığını alır.
def doldur(a):
    kok = kok_bul(a.get("--kok"))
    ajan = a["ajan"]
    hafta = a.get("--hafta") or bu_hafta()
    yol = os.path.join(retro_dizin(kok, hafta), f"{ajan}.md")
    if not os.path.exists(yol):
        print(f"✗ iskelet yok: {os.path.relpath(yol, kok)} — önce `retro.py kutu {ajan}` (ölçüm bloğunu araç yazar)")
        return 2
    kaynak = a.get("--metin")
    if not kaynak:
        raise ValueError("--metin <dosya|-> gerekli (doldurulmuş 5 başlık)")
    try:
        metin = sys.stdin.read() if kaynak == "-" else open(kaynak, encoding="utf-8").read()
    except OSError as e:
        print(f"✗ metin okunamadı: {kaynak} ({e.strerror})")
        return 2
    # Ölçüm ve imza ARACINDIR: metinde görünürse ajan onları sahteleyebilirdi → reddedilir, sessizce atılmaz.
    if re.search(r"^## Ölçüm", metin, re.M) or re.search(r"^_(koltuk|kutu|yazildi|arac|olcum_yenilendi):", metin, re.M):
        print("✗ yazılmadı — metinde ölçüm bloğu ya da imza satırı var; onları araç yazar. Yalnız '## 1 · …' … '## 5 · …' ver")
        return 2
    m = re.search(r"^## 1 · ", metin, re.M)
    if not m:
        print("✗ yazılmadı — metinde '## 1 · ' başlığı yok (5 başlık iskeletteki adlarıyla verilir)")
        return 2
    if metin[:m.start()].strip():
        print("✗ yazılmadı — '## 1 · ' öncesinde metin var; araç onu yutardı. Yalnız 5 başlığı ver")
        return 2
    govde = re.sub(r"\n*<!-- Yorum satırları ajanındır;.*?-->\s*$", "", metin[m.start():], flags=re.S).rstrip("\n") + "\n"
    eski = open(yol, encoding="utf-8").read()
    i = eski.find("\n## 1 · ")
    if i < 0:
        print("✗ yazılmadı — iskelette '## 1 · ' bulunamadı (dosya elle bozulmuş olabilir)")
        return 2
    yeni = eski[: i + 1] + govde + "\n" + YORUM_NOTU + "\n"
    h, b = lint_metin(yeni, hafta, ajan)
    if h:
        print(f"✗ yazılmadı — doldurulmuş retro GEÇERSİZ ({len(h)} hata), dosya olduğu gibi:")
        for x in h:
            print(f"  • {x}")
        return 1
    # Benzersiz geçici dosya AYNI dizinde (os.replace atomik kalsın); sabit ad eşzamanlı iki dolumu çarpıştırırdı (göz tur 1).
    fd, gecici = tempfile.mkstemp(prefix=f".{ajan}.", suffix=".yeni", dir=os.path.dirname(yol))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(yeni)
        os.chmod(gecici, 0o644)
        os.replace(gecici, yol)
    except BaseException:
        if os.path.exists(gecici):
            os.unlink(gecici)
        raise
    print(f"✓ dolduruldu: {os.path.relpath(yol, kok)} · öneri {len(b['oneri'])} · ders {len(b['ders'])} — lint geçti")
    return 0


# ───────────────────────── lint ─────────────────────────
def lint_metin(metin, beklenen_hafta=None, beklenen_ajan=None):
    """→ (hatalar[], bilgi{}). Hata yoksa geçerli."""
    h = []
    sat = metin.split("\n")
    m = re.match(r"^# 🔁 HAFTALIK RETRO · (\d{4}-W\d{2}) · (\S.*)$", sat[0] if sat else "")
    if not m:
        h.append("L1 başlık: '# 🔁 HAFTALIK RETRO · YYYY-Www · AJAN' bekleniyor")
        hafta = ajan = None
    else:
        hafta, ajan = m.group(1), m.group(2).strip()
        if beklenen_hafta and hafta != beklenen_hafta:
            h.append(f"L1 başlıktaki hafta {hafta} ≠ dizin {beklenen_hafta}")
        if beklenen_ajan and norm(ajan) != norm(beklenen_ajan):
            h.append(f"L1 başlıktaki ajan {ajan} ≠ dosya adı {beklenen_ajan}")
    for alan in ("_koltuk", "_yazildi", "_arac"):
        if not re.search(rf"^{alan}: \S", metin, re.M):
            h.append(f"L2 imza satırı eksik/boş: {alan}")
    if "## Ölçüm (araç yazdı" not in metin:
        h.append("L3 ölçüm bloğu yok (araç yazmalı; elle retro geçersiz)")
    else:
        tablo = [s for s in sat if s.startswith("| ") and not s.startswith("| Kaynak") ]
        if len(tablo) < 7:
            h.append(f"L3 ölçüm tablosu {len(tablo)} satır (<7): kaynak eksik")
        for s in tablo:
            p = [x.strip() for x in s.strip("|").split("|")]
            if len(p) >= 2 and not (re.search(r"\d", p[1]) or p[1].startswith("ÖLÇÜLEMEDİ:")):
                h.append(f"L3 ölçüm değeri ne sayı ne ÖLÇÜLEMEDİ: '{p[0]}' = '{p[1]}'")
    maddeler = {}
    bolum = None
    for s in sat:
        mb = re.match(r"^## (\d) · ", s)
        if mb:
            bolum = mb.group(1)
            maddeler.setdefault(bolum, [])
            continue
        mm = MADDE_RE.match(s)
        if mm and bolum in ETIKETLER:
            if mm.group(1) != ETIKETLER[bolum]:
                h.append(f"L4 bölüm {bolum} maddesi {mm.group(1)}{mm.group(2)}) yanlış etiket (beklenen {ETIKETLER[bolum]})")
            maddeler[bolum].append((mm.group(1), int(mm.group(2)), mm.group(3).strip()))
    for no, ad in BASLIKLAR:
        if no not in maddeler:
            h.append(f"L4 başlık yok: '## {no} · {ad}'")
            continue
        if not maddeler[no]:
            h.append(f"L4 başlık boş: {no} · {ad} (yorum satırı boşsa dosya geçersiz)")
        for et, n, metin_m in maddeler[no]:
            if YER_TUTUCU_RE.search(metin_m):
                h.append(f"L7 yer tutucu kalmış: {et}{n}) {metin_m[:40]}")
            if len(metin_m) < 8:
                h.append(f"L4 madde çok kısa: {et}{n})")
        nolar = [n for _, n, _ in maddeler[no]]
        if nolar != list(range(1, len(nolar) + 1)):
            h.append(f"L4 bölüm {no} numaraları 1..n sıralı değil: {nolar}")
    for et, n, metin_m in maddeler.get("2", []):
        if not re.search(r"· ölçü: .*\d", metin_m):
            h.append(f"L5 zaman kaybı ölçüsüz: Z{n}) — '· ölçü: <sayı birim>' zorunlu")
    if len(maddeler.get("5", [])) > 5:
        h.append(f"L6 merkeze öneri {len(maddeler['5'])} madde (>5): kapasite dürüstlüğü, süz")
    bilgi = {"hafta": hafta, "ajan": ajan, "oneri": [(n, t) for _, n, t in maddeler.get("5", [])],
             "ders": [(n, t) for _, n, t in maddeler.get("4", [])]}
    return h, bilgi


def lint(a):
    yol = a["dosya"]
    if not os.path.exists(yol):
        print(f"✗ dosya yok: {yol}")
        return 2
    diz = os.path.basename(os.path.dirname(os.path.abspath(yol)))
    ajan = os.path.splitext(os.path.basename(yol))[0]
    h, b = lint_metin(open(yol, encoding="utf-8").read(), diz if re.fullmatch(r"\d{4}-W\d{2}", diz) else None, ajan)
    if h:
        print(f"✗ GEÇERSİZ retro ({len(h)} hata): {yol}")
        for x in h:
            print(f"  • {x}")
        return 1
    print(f"✓ geçerli retro: {yol} · öneri {len(b['oneri'])} · ders {len(b['ders'])}")
    return 0


# ───────────────────────── merkez ─────────────────────────
def merkez_satir_coz(s):
    """'- <AJAN> Ö<n>) <metin> → <damga>' → (norm(ajan), n, metin, damga) ya da None. Damga SON oktan sonrasıdır
    (öneri metni ok taşıyabilir); damga ok taşıyamaz. Metin damgayla birlikte saklanır: metin değişirse damga bayattır."""
    s = s.strip()
    m = re.match(r"^- (\S+) Ö(\d+)\) (.*)$", s)
    if not m or "→" not in m.group(3):
        return None
    metin, damga = m.group(3).rsplit("→", 1)
    return norm(m.group(1)), int(m.group(2)), metin.strip(), damga.strip()


def registry_ajanlar(yol):
    if not yol or not os.path.exists(yol):
        return None
    ids = []
    for s in open(yol, encoding="utf-8", errors="replace"):
        m = re.match(r"^\s*-\s*id:\s*([^\s#]+)", s)
        if m:
            ids.append(m.group(1))
    return ids


MERKEZ_KATILIM = "## Katılım (araç yazdı)"
MERKEZ_SUZUM = "## Süzüm — her öneri bir damga alır: `→ gorev_<id>` (görev defterine girdi) ya da `→ RED: <gerekçe ≥10 karakter>`"
# ARAÇ bölümleri BİREBİR bu başlıklardır (önek değil: elle yazılmış "## Süzüm notları" araç bölümü sayılıp silinmesin, göz tur 1)


def merkez_elle_ham(metin):
    """MERKEZ.md'deki araç dışı ## bölümlerini HAM metin olarak, yazıldıkları sırayla döndürür (satır sonları, boş satırlar,
    girinti bayt bayt korunur — göz tur 1). Araç dışı bölüm yoksa boş dize."""
    ham, icinde = [], False
    for s in metin.splitlines(keepends=True):
        if s.startswith("## "):
            icinde = s.rstrip("\r\n") not in (MERKEZ_KATILIM, MERKEZ_SUZUM)
        if icinde:
            ham.append(s)
    return "".join(ham)


def merkez(a):
    kok = kok_bul(a.get("--kok"))
    hafta = a.get("--hafta") or bu_hafta()
    diz = retro_dizin(kok, hafta)
    if a.get("--ajanlar"):
        ajanlar = [x for x in a["--ajanlar"].split(",") if x]
    else:
        ajanlar = registry_ajanlar(a.get("--registry") or os.environ.get("RETRO_REGISTRY") or os.path.join(kok, "_agents", "handoff", "aile-registry.yaml"))
        if ajanlar is None:
            print("◻ ÖLÇÜLEMEDİ: ajan listesi yok — --ajanlar A,B ya da aile-registry.yaml gerekli (ölçülemeyen katılım kapanış sayılmaz)")
            return 3
    haric = {norm(x) for x in (a.get("--haric") or "SERDAR").split(",")}
    durum = {}
    oneriler = []
    for ajan in ajanlar:
        if norm(ajan) in haric:
            continue
        yol = os.path.join(diz, f"{ajan}.md")
        eslesen = yol if os.path.exists(yol) else next((p for p in glob.glob(os.path.join(diz, "*.md")) if norm(os.path.splitext(os.path.basename(p))[0]) == norm(ajan)), None)
        if eslesen:
            h, b = lint_metin(open(eslesen, encoding="utf-8").read(), hafta, ajan)
            if h:
                durum[ajan] = ("GEÇERSİZ", f"{len(h)} lint hatası: {h[0]}")
            else:
                durum[ajan] = ("OK", f"öneri {len(b['oneri'])} · ders {len(b['ders'])}")
                oneriler += [(ajan, n, t) for n, t in b["oneri"]]
        else:
            o = olc(kok, ajan, hafta)
            if iz_var(o):
                durum[ajan] = ("EKSİK", f"iz var (notes {o['notes']['satir'] if o['notes'] else 0} · kart {o['kart']['acilan'] if o['kart'] else 0}) ama retro yok → zil")
            else:
                durum[ajan] = ("ÇALIŞMADI", "bu hafta iz yok (NOTES/kart) — retro zorunlu değil")
    sira = {"EKSİK": 0, "GEÇERSİZ": 1, "OK": 2, "ÇALIŞMADI": 3}
    print(f"MERKEZ · {hafta} · {len(durum)} ajan")
    for ajan, (d, n) in sorted(durum.items(), key=lambda x: (sira[x[1][0]], x[0])):
        print(f"  {d:<9} {ajan:<10} {n}")
    eksik = [x for x, (d, _) in durum.items() if d in ("EKSİK", "GEÇERSİZ")]
    myol = os.path.join(diz, "MERKEZ.md")
    if os.path.exists(myol) and "--yenile" not in a:
        print(f"  MERKEZ.md zaten var ({os.path.relpath(myol, kok)}); araç bölümlerini yenilemek için --yenile (Süzüm damgaları ve elle yazılan bölümler KORUNUR)")
    else:
        eski_damga = {}  # (ajan, n) → (metin, damga)
        elle = ""        # araç dışı ## bölümleri (Dersler · Görevler · Kaçış …) — --yenile bunları OLDUĞU GİBİ taşır
        if os.path.exists(myol):
            eski = open(myol, encoding="utf-8").read()
            for s in eski.splitlines():
                c = merkez_satir_coz(s)
                if c and c[3]:
                    eski_damga[(c[0], c[1])] = (c[2], c[3])
            elle = merkez_elle_ham(eski)
        os.makedirs(diz, exist_ok=True)
        simdi = datetime.now().astimezone().replace(microsecond=0).isoformat()
        r = [f"# 🔁 MERKEZ RETROSU · {hafta}", f"_yazildi: {simdi}", f"_arac: retro.py {SURUM}", "",
             MERKEZ_KATILIM, "| Ajan | Durum | Not |", "|---|---|---|"]
        for ajan, (d, n) in sorted(durum.items(), key=lambda x: (sira[x[1][0]], x[0])):
            r.append(f"| {ajan} | {d} | {n} |")
        r += ["", MERKEZ_SUZUM]
        if not oneriler:
            r.append("_(geçerli kutu retrosunda öneri yok)_")
        dusen = []
        for ajan, n, t in oneriler:
            e = eski_damga.get((norm(ajan), n))
            d = ""
            if e:
                if e[0] == t.strip():
                    d = e[1]
                else:
                    dusen.append(f"{ajan} Ö{n}")
            r.append(f"- {ajan} Ö{n}) {t} → {d}".rstrip())
        if dusen:
            print(f"  ⚠ damga DÜŞTÜ (öneri metni değişti, yeniden süzülmeli): {', '.join(dusen)}")
        if elle:   # gorev_01M58987YSBASEXV1MF7T2GJHP: eskiden burada iskelet yeniden basılıyor, elle yazılan bölümler SİLİNİYORDU
            metin = "\n".join(r) + "\n\n" + elle   # araç bölümleri + bir boş satır + elle bölümler HAM (bayt bayt)
        else:
            r += ["", "## Dersler (merkez yorumu; kutu dersine D<n> ile atıf: `BÂNİ D2`)", "- M1) <ders> · kaynak: <AJAN D<n> | ölçüm>", "",
                  "## Görevler (Sultan ders ders onaylar · D1 damgası · görev defteri)", "- <gorev_… · ders M<n>>", ""]
            metin = "\n".join(r)
        open(myol, "w", encoding="utf-8").write(metin)
        bekleyen = sum(1 for a_, n, t in oneriler if not (eski_damga.get((norm(a_), n)) and eski_damga[(norm(a_), n)][0] == t.strip()))
        print(f"  ✓ MERKEZ.md iskeleti: {os.path.relpath(myol, kok)} · öneri {len(oneriler)} (damga bekliyor: {bekleyen})")
    if eksik:
        print(f"✗ EKSİK/GEÇERSİZ: {', '.join(eksik)} → kutu retrosunu ajan yazar (merkez yazamaz); zil düşür")
        return 1
    return 0


# ───────────────────────── süzüm ─────────────────────────
def suzum(a):
    kok = kok_bul(a.get("--kok"))
    hafta = a.get("--hafta") or bu_hafta()
    diz = retro_dizin(kok, hafta)
    myol = os.path.join(diz, "MERKEZ.md")
    if not os.path.exists(myol):
        print(f"◻ ÖLÇÜLEMEDİ: MERKEZ.md yok ({os.path.relpath(myol, kok)}) — süzüm ölçülemez (merkez retrosu önce)")
        return 3
    damga = {}  # (ajan, n) → (metin, damga)
    for s in open(myol, encoding="utf-8"):
        c = merkez_satir_coz(s)
        if c:
            damga[(c[0], c[1])] = (c[2], c[3])
    eksik, toplam = [], 0
    for p in sorted(glob.glob(os.path.join(diz, "*.md"))):
        ajan = os.path.splitext(os.path.basename(p))[0]
        if ajan in ("MERKEZ", "KAPANIS"):
            continue
        h, b = lint_metin(open(p, encoding="utf-8").read(), hafta, ajan)
        if h:
            eksik.append(f"{ajan}: retro GEÇERSİZ ({len(h)} hata) — önerileri sayılamaz")
            continue
        for n, t in b["oneri"]:
            toplam += 1
            e = damga.get((norm(ajan), n))
            d = e[1] if e else ""
            if e and e[0] != t.strip():
                eksik.append(f"{ajan} Ö{n}) damga BAYAT: kutu metni değişti ('{t[:40]}…' ≠ MERKEZ '{e[0][:40]}…') — merkez --yenile ile yeniden süz")
                continue
            if GOREV_RE.fullmatch(d) or (d.startswith("RED:") and len(d[4:].strip()) >= 10):
                continue
            eksik.append(f"{ajan} Ö{n}) damgasız ya da biçimsiz: '{d or '(boş)'}' — '→ gorev_<26>' ya da '→ RED: <gerekçe>'")
    if eksik:
        print(f"✗ SÜZÜM KIRMIZI · {hafta} · {toplam} öneri, {len(eksik)} sorun")
        for x in eksik:
            print(f"  • {x}")
        return 1
    print(f"✓ süzüm tamam · {hafta} · {toplam} önerinin {toplam}'i damgalı")
    return 0


# ───────────────────────── giriş ─────────────────────────
def argv_coz(argv, konumlu):
    a = {}
    k = list(konumlu)
    i = 0
    while i < len(argv):
        x = argv[i]
        if x.startswith("--"):
            if x in ("--yenile", "--json"):
                a[x] = True
            else:
                if i + 1 >= len(argv):
                    raise ValueError(f"{x} değer ister")
                a[x] = argv[i + 1]
                i += 1
        elif k:
            a[k.pop(0)] = x
        else:
            raise ValueError(f"fazla argüman: {x}")
        i += 1
    if k:
        raise ValueError(f"eksik argüman: {k[0]}")
    return a


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    cmd, rest = argv[0], argv[1:]
    try:
        if cmd == "kutu":
            return kutu(argv_coz(rest, ["ajan"]))
        if cmd == "doldur":
            return doldur(argv_coz(rest, ["ajan"]))
        if cmd == "lint":
            return lint(argv_coz(rest, ["dosya"]))
        if cmd == "merkez":
            return merkez(argv_coz(rest, []))
        if cmd == "suzum":
            return suzum(argv_coz(rest, []))
        if cmd == "hafta":
            print(bu_hafta())
            return 0
    except ValueError as e:
        print(f"✗ {e}")
        return 2
    print(f"✗ bilinmeyen komut: {cmd} (kutu · doldur · lint · merkez · suzum · hafta)")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
