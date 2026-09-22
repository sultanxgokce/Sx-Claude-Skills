#!/usr/bin/env python3
"""kanit.py — fabrika 3. adım (KANITLA): kanıtı toplar, manifesti ARAÇ yazar.

Neden araç yazar: "yaptım" beyanı kanıt değildir; elle yazılmış manifest de değildir. Bu araç her kaydı
kendisi üretir (komutu kendi koşar, kareyi kendi çeker, sha'yı kendi hesaplar) ve manifesti imzalar.
`dogrula` imzayı ve dosya sha'larını yeniden hesaplar: elle değişmiş manifest kırmızı (rc=1).

Renkler: yesil (ölçtü, korudu) · kirmizi (ölçtü, korumuyor) · sari (ÖLÇEMEDİ — rc=3; yeşil değildir).

Kullanım:
  kanit.py olcum  <iş> <etiket> --asama once|sonra -- <komut...>     komutu koşar, kırpılmamış çıktı+rc kaydeder
  kanit.py ekran  <iş> <etiket> --asama once|sonra --url U [--urun-imi CSS] [--bekle CSS] [--genislik N]
  kanit.py dosya  <iş> <etiket> <yol> [--asama ...]                    var olan dosyayı (video, rapor) sha ile ekler
  kanit.py dogrula <iş>                                                imza + dosya sha'ları (0 sağlam · 1 bozuk · 3 yok)
  kanit.py ozet   <iş>                                                 PR gövdesi için tablo (markdown)
  kanit.py liste  <iş>
Ortam: KANIT_DEPO (depo kökü; vars. git toplevel) · KANIT_PLAYWRIGHT_DIR (node_modules'lı dizin)
"""
import argparse, datetime, hashlib, json, os, shutil, subprocess, sys

SURUM = "kanit.py/0.1.0"
TUZ = "yazilim-fabrikasi-kanit-2026"  # imza tuzu: elle yazımı yakalar; kriptografik gizlilik iddiası YOK
HERE = os.path.dirname(os.path.abspath(__file__))


def hata(m, rc=1):
    print(f"✗ {m}", file=sys.stderr); sys.exit(rc)


def depo_kok(arg):
    d = arg or os.environ.get("KANIT_DEPO")
    if not d:
        try:
            d = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True, stderr=subprocess.DEVNULL).strip()
        except Exception:
            hata("depo kökü bulunamadı (--depo ver ya da KANIT_DEPO)", 3)
    return d


def kanit_dizin(depo, is_adi):
    return os.path.join(depo, "_agents", "fabrika", "kanit", is_adi)


def sha_dosya(yol):
    h = hashlib.sha256()
    with open(yol, "rb") as f:
        for p in iter(lambda: f.read(1 << 20), b""):
            h.update(p)
    return h.hexdigest()


def imza(kayitlar):
    govde = json.dumps(kayitlar, ensure_ascii=False, sort_keys=True) + SURUM + TUZ
    return hashlib.sha256(govde.encode()).hexdigest()


def manifest_oku(dz):
    yol = os.path.join(dz, "KANIT.json")
    if not os.path.exists(yol):
        return None
    with open(yol, encoding="utf-8") as f:
        return json.load(f)


def manifest_yaz(dz, is_adi, kayitlar):
    m = {"is": is_adi, "arac": SURUM, "guncelleme": simdi(), "kayitlar": kayitlar, "imza": imza(kayitlar)}
    with open(os.path.join(dz, "KANIT.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=2); f.write("\n")
    return m


def simdi():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def kayit_ekle(depo, is_adi, kayit):
    dz = kanit_dizin(depo, is_adi); os.makedirs(dz, exist_ok=True)
    m = manifest_oku(dz)
    kayitlar = m["kayitlar"] if m else []
    if m and m.get("imza") != imza(kayitlar):
        hata("var olan KANIT.json imzası TUTMUYOR — elle değişmiş; yeni kayıt eklenmedi (dogrula ile bak)", 1)
    kayitlar.append(kayit)
    manifest_yaz(dz, is_adi, kayitlar)
    return dz


# ── olcum ────────────────────────────────────────────────────────────────────────
def cmd_olcum(a):
    if not a.komut:
        hata("komut gerekiyor: -- <komut...>")
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); os.makedirs(dz, exist_ok=True)
    ad = f"olcum-{a.etiket}-{a.asama}.txt"
    yol = os.path.join(dz, ad)
    t0 = datetime.datetime.now()
    p = subprocess.run(a.komut, capture_output=True, text=True)   # boru YOK: çıktı kırpılmadan
    sure = (datetime.datetime.now() - t0).total_seconds()
    with open(yol, "w", encoding="utf-8") as f:
        f.write(f"$ {' '.join(a.komut)}\n# rc={p.returncode} sure={sure:.1f}s zaman={simdi()}\n--- stdout ---\n{p.stdout}--- stderr ---\n{p.stderr}")
    renk = "sari" if p.returncode == 3 else ("yesil" if p.returncode == 0 else "kirmizi")
    kayit = {"tur": "olcum", "etiket": a.etiket, "asama": a.asama, "dosya": ad, "sha256": sha_dosya(yol),
             "komut": a.komut, "rc": p.returncode, "renk": renk, "zaman": simdi(), "sure_sn": round(sure, 1)}
    kayit_ekle(depo, a.is_adi, kayit)
    print(f"{'✓' if renk=='yesil' else ('◻' if renk=='sari' else '✗')} ölçüm kaydedildi: {ad} rc={p.returncode} renk={renk}")
    print(p.stdout, end="")
    if p.stderr: print(p.stderr, end="", file=sys.stderr)
    sys.exit(0 if renk != "sari" else 3)


# ── ekran ────────────────────────────────────────────────────────────────────────
def playwright_dizin():
    aday = [os.environ.get("KANIT_PLAYWRIGHT_DIR")] + [
        os.path.join(d, "node_modules") for d in ("/config/projects/Nexus/ui", "/config/projects/akar", os.getcwd())]
    for d in aday:
        if d and os.path.isdir(os.path.join(d, "playwright")):
            return d
    return None


def cmd_ekran(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); os.makedirs(dz, exist_ok=True)
    ad = f"ekran-{a.etiket}-{a.asama}.png"; yol = os.path.join(dz, ad)
    pw = playwright_dizin()
    temel = {"tur": "ekran", "etiket": a.etiket, "asama": a.asama, "dosya": ad, "url": a.url, "zaman": simdi()}
    if not pw or not shutil.which("node"):
        kayit = {**temel, "sha256": None, "rc": 3, "renk": "sari", "not": "playwright/node bulunamadı — kare ALINAMADI"}
        kayit_ekle(depo, a.is_adi, kayit)
        print("◻ SARI: kare alınamadı (playwright/node yok) — bu yeşil DEĞİLDİR; manifeste sarı yazıldı")
        sys.exit(3)
    env = {**os.environ, "NODE_PATH": pw}
    argv = ["node", os.path.join(HERE, "kanit-ekran.mjs"), a.url, yol, a.urun_imi or "", a.bekle or "", str(a.genislik)]
    p = subprocess.run(argv, capture_output=True, text=True, env=env)
    if p.returncode == 2:
        kayit = {**temel, "sha256": None, "rc": 2, "renk": "kirmizi", "not": "ÜRÜN İMİ YOK — açılan sayfa ürün değil (giriş/hata sayfası olabilir)"}
        kayit_ekle(depo, a.is_adi, kayit)
        print(f"✗ ürün imi bulunamadı ({a.urun_imi}) — ölçer ürünü görmedi; kare kanıt sayılmaz\n{p.stderr}", file=sys.stderr)
        sys.exit(2)
    if p.returncode != 0 or not os.path.exists(yol):
        kayit = {**temel, "sha256": None, "rc": 3, "renk": "sari", "not": f"kare alınamadı: {p.stderr.strip()[:300]}"}
        kayit_ekle(depo, a.is_adi, kayit)
        print(f"◻ SARI: kare alınamadı — {p.stderr.strip()[:300]}")
        sys.exit(3)
    kayit = {**temel, "sha256": sha_dosya(yol), "rc": 0, "renk": "yesil", "urun_imi": a.urun_imi, "genislik": a.genislik}
    kayit_ekle(depo, a.is_adi, kayit)
    print(f"✓ kare alındı: {ad} ({a.genislik}px{' · ürün imi doğrulandı' if a.urun_imi else ''})")


# ── dosya ────────────────────────────────────────────────────────────────────────
def cmd_dosya(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); os.makedirs(dz, exist_ok=True)
    if not os.path.isfile(a.yol): hata(f"dosya yok: {a.yol}", 3)
    ad = f"dosya-{a.etiket}-{a.asama}{os.path.splitext(a.yol)[1]}"; hedef = os.path.join(dz, ad)
    shutil.copyfile(a.yol, hedef)
    kayit = {"tur": "dosya", "etiket": a.etiket, "asama": a.asama, "dosya": ad, "sha256": sha_dosya(hedef),
             "kaynak": os.path.abspath(a.yol), "rc": 0, "renk": "yesil", "zaman": simdi()}
    kayit_ekle(depo, a.is_adi, kayit)
    print(f"✓ dosya eklendi: {ad}")


# ── dogrula ──────────────────────────────────────────────────────────────────────
def cmd_dogrula(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi)
    m = manifest_oku(dz)
    if not m:
        print(f"◻ {dz}/KANIT.json YOK — kanıt yok (ölçülemedi)"); sys.exit(3)
    rc = 0
    if m.get("arac") != SURUM:
        print(f"· araç sürümü farklı: {m.get('arac')} (bu: {SURUM})")
    if m.get("imza") != imza(m.get("kayitlar", [])):
        print("✗ İMZA TUTMUYOR — manifest elle değişmiş ya da araç dışında yazılmış"); rc = 1
    sari = 0
    for k in m.get("kayitlar", []):
        if k.get("renk") == "sari": sari += 1
        if k.get("sha256"):
            y = os.path.join(dz, k["dosya"])
            if not os.path.exists(y):
                print(f"✗ dosya yok: {k['dosya']}"); rc = 1
            elif sha_dosya(y) != k["sha256"]:
                print(f"✗ sha TUTMUYOR: {k['dosya']}"); rc = 1
    n = len(m.get("kayitlar", []))
    if rc == 0:
        print(f"✓ manifest sağlam: {n} kayıt, imza ve sha'lar tutuyor" + (f" · ⚠ {sari} SARI kayıt (ölçülemedi)" if sari else ""))
    if n == 0:
        print("◻ kayıt yok — kanıt yok"); sys.exit(3)
    sys.exit(rc)


def cmd_ozet(a):
    depo = depo_kok(a.depo); dz = kanit_dizin(depo, a.is_adi); m = manifest_oku(dz)
    if not m: print("_kanıt yok_"); sys.exit(3)
    print(f"| # | tür | etiket | aşama | renk | rc | dosya |\n|---|---|---|---|---|---|---|")
    for i, k in enumerate(m["kayitlar"], 1):
        print(f"| {i} | {k['tur']} | {k['etiket']} | {k.get('asama','')} | {k['renk']} | {k.get('rc','')} | `{k['dosya']}` |")
    print(f"\nimza `{m['imza'][:16]}` · araç {m['arac']} · dizin `{os.path.relpath(dz, depo)}`")


def cmd_liste(a):
    cmd_ozet(a)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--depo")
    s = p.add_subparsers(dest="cmd", required=True)
    o = s.add_parser("olcum"); o.add_argument("is_adi"); o.add_argument("etiket"); o.add_argument("--asama", default="sonra", choices=["once", "sonra", "tek"]); o.set_defaults(f=cmd_olcum)
    e = s.add_parser("ekran"); e.add_argument("is_adi"); e.add_argument("etiket"); e.add_argument("--asama", default="sonra", choices=["once", "sonra", "tek"]); e.add_argument("--url", required=True); e.add_argument("--urun-imi"); e.add_argument("--bekle"); e.add_argument("--genislik", type=int, default=1280); e.set_defaults(f=cmd_ekran)
    d = s.add_parser("dosya"); d.add_argument("is_adi"); d.add_argument("etiket"); d.add_argument("yol"); d.add_argument("--asama", default="tek"); d.set_defaults(f=cmd_dosya)
    for ad, f in (("dogrula", cmd_dogrula), ("ozet", cmd_ozet), ("liste", cmd_liste)):
        x = s.add_parser(ad); x.add_argument("is_adi"); x.set_defaults(f=f)
    # `--` sonrası KOMUTTUR: argparse'a hiç gösterilmez (REMAINDER, seçenekleri de yutuyordu).
    argv = sys.argv[1:]; komut = []
    if "--" in argv:
        i = argv.index("--"); komut = argv[i + 1:]; argv = argv[:i]
    a = p.parse_args(argv); a.komut = komut
    a.f(a)


if __name__ == "__main__":
    main()
