#!/usr/bin/env python3
"""imar-fikir-kapisi — İMAR'ın fikir merceği + ucuz deney + öldür/sürdür kapısı (M6·M7·M8).

NİÇİN VAR: İMAR'ın hatası "bozdum" değil "ÇÖP BİRİKTİRDİM"dir. Fikir üreten bir çarka eleme
kapısı konmazsa, birkaç haftada Sultan'ın önüne bakılamayacak bir yığın çıkar. Bu kapı,
fikrin deftere girip giremeyeceğine karar verir.

🔴 YENİ DEFTER AÇMAZ: kabul edilen fikir, kutuda zaten kurulu olan Bulgu Defteri'ne yazılır
(hâlleri: acik → uygulandi → canli → onaylandi). Reddedilenler MEZARLIĞA gider — o ayrı bir
yerdir çünkü defterde "reddedildi" hâli yok ve ölü fikir canlı listeyi kirletmemeli.

Mercek (M6) — 100 puan:
  kullanıcı değeri 0-40 · pazar 0-30 · teknik imkân 0-30
Eşik (Sultan, 30 Eylül): ≥75 otomatik inşaya · <75 Sultan'ın onayına.
🔴 Dört sınıf iş (geri alınamaz · para · dış yüzey · yetki) puanı ne olursa olsun Sultan'a sorulur.

Fail-closed alanlar — biri eksikse fikir DEFTERE GİRMEZ:
  --deney  : nasıl UCUZA sınanır (M7)
  --oldur  : ne olursa bu fikir ölür (M8)
  --kanit  : olcum | kaynak | zanaat   (zanaat tek başına 75'i geçiremez)

Kullanım:
  imar-fikir-kapisi.py --baslik "…" --deger N --pazar N --teknik N \
      --deney "…" --oldur "…" --kanit olcum|kaynak|zanaat [--sinif geri-alinamaz,para,dis-yuzey,yetki] [--kuru]
  imar-fikir-kapisi.py --mezarlik          # ölü fikirleri listele
Çıkış: 0 deftere girdi · 1 ÖLDÜ (mezarlığa yazıldı) · 2 kullanım/eksik alan · 3 ölçülemedi
"""
import argparse, json, os, re, subprocess, sys, datetime

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEZARLIK = os.path.join(KOK, "hafiza", "fikir-mezarligi.jsonl")
# 🔴 PROFİLE BAĞLANDI (bağımsız gözün tur-1 bulgusu): profil `defter_yaz` alanını ZORUNLU ilan
#    ediyordu ama kod onu hiç okumuyor, küresel yolu varsayıyordu — yani kayıt vardı, ÇAĞIRAN yoktu.
#    İlan edilen ama bağlanmayan alan, kutu bağımsızlığını kanıtlamaz; yalnız iddia eder.
DEFTER_YAZ = (os.environ.get("IMAR_DEFTER_YAZ") or os.environ.get("DEFTER_YAZ")
              or "/config/.ic-sayfa/defter-yaz.py")
ESIK = 75
SINIFLAR = {"geri-alinamaz", "para", "dis-yuzey", "yetki"}

def sadelestir(s):
    s = s.lower()
    for a, b in (("ı","i"),("ş","s"),("ğ","g"),("ü","u"),("ö","o"),("ç","c")):
        s = s.replace(a, b)
    return re.sub(r"[^a-z0-9 ]", " ", s).split()

def benzer(a, b):
    ka, kb = set(sadelestir(a)), set(sadelestir(b))
    if not ka or not kb: return 0.0
    return len(ka & kb) / len(ka | kb)

def mezarlik_oku():
    if not os.path.isfile(MEZARLIK): return []
    with open(MEZARLIK, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]

def mezara_yaz(kayit):
    os.makedirs(os.path.dirname(MEZARLIK), exist_ok=True)
    with open(MEZARLIK, "a", encoding="utf-8") as f:
        f.write(json.dumps(kayit, ensure_ascii=False) + "\n")

def main():
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--baslik"); p.add_argument("--deger", type=int)
    p.add_argument("--pazar", type=int); p.add_argument("--teknik", type=int)
    p.add_argument("--deney"); p.add_argument("--oldur"); p.add_argument("--kanit")
    p.add_argument("--sinif", default=""); p.add_argument("--kim", default="İMAR")
    p.add_argument("--kuru", action="store_true"); p.add_argument("--mezarlik", action="store_true")
    p.add_argument("-h", "--help", action="store_true")
    a = p.parse_args()

    if a.help: print(__doc__); return 2
    if a.mezarlik:
        olu = mezarlik_oku()
        if not olu: print("mezarlık boş"); return 0
        for k in olu: print("☠ %s · %s · sebep: %s" % (k["tarih"], k["baslik"][:60], k["sebep"]))
        return 0

    eksik = [ad for ad, d in (("baslik", a.baslik), ("deney", a.deney), ("oldur", a.oldur),
                              ("kanit", a.kanit)) if not d]
    if None in (a.deger, a.pazar, a.teknik): eksik.append("puanlar")
    if eksik:
        print("DURDU (rc=2): şu alanlar olmadan fikir deftere giremez: %s" % ", ".join(eksik), file=sys.stderr)
        print("  'nasıl ucuza sınanır' ve 'ne olursa ölür' yazılmayan fikir, bir fikir değil bir dilektir.", file=sys.stderr)
        return 2
    if a.kanit not in ("olcum", "kaynak", "zanaat"):
        print("DURDU (rc=2): kanıt sınıfı olcum|kaynak|zanaat olmalı", file=sys.stderr); return 2
    for n, ust in (("deger", 40), ("pazar", 30), ("teknik", 30)):
        v = getattr(a, n)
        if not (0 <= v <= ust):
            print("DURDU (rc=2): %s 0-%d arası olmalı (verilen: %d)" % (n, ust, v), file=sys.stderr); return 2
    sinif = [s for s in a.sinif.split(",") if s]
    if set(sinif) - SINIFLAR:
        print("DURDU (rc=2): bilinmeyen sınıf: %s" % ",".join(set(sinif)-SINIFLAR), file=sys.stderr); return 2

    puan = a.deger + a.pazar + a.teknik
    bugun = datetime.date.today().isoformat()

    # ——— M8/a: aynı fikir daha önce öldü mü (mezarlıkta eşleşme) ———
    for olu in mezarlik_oku():
        o = benzer(a.baslik, olu["baslik"])
        if o >= 0.6:
            print("ÖLÜ FİKİR GERİ GELDİ (benzerlik %.0f%%): %s" % (o*100, olu["baslik"][:70]))
            print("  önceki sebep: %s (%s)" % (olu["sebep"], olu["tarih"]))
            print("  → yeniden denemek için önce o sebebi çürüten KANIT gerekir.")
            return 1

    # ——— M8/b: zanaat tek başına eşiği geçemez ———
    if a.kanit == "zanaat" and puan >= ESIK:
        puan_eski = puan; puan = ESIK - 1
        print("NOT: kanıt 'zanaat' (ajan deneyimi) — tek başına eşiği geçemez: %d → %d" % (puan_eski, puan))

    dort_sinif = bool(sinif)
    if puan >= ESIK and not dort_sinif:
        karar, hal = "OTOMATİK İNŞA", "acik"
    elif puan >= ESIK and dort_sinif:
        karar, hal = "SULTAN ONAYI (dört sınıf: %s)" % ",".join(sinif), "acik"
    elif puan >= 40:
        karar, hal = "SULTAN ONAYI (eşik altı)", "acik"
    else:
        mezara_yaz({"tarih": bugun, "baslik": a.baslik, "puan": puan,
                    "sebep": "puan %d < 40 (zayıf fikir)" % puan, "deney": a.deney, "oldur": a.oldur})
        print("☠ ÖLDÜ: puan %d · mezarlığa yazıldı (sebep kayıtlı, tekrar doğarsa eşlenecek)" % puan)
        return 1

    satir = ("%s\n\nPUAN %d/100 (değer %d · pazar %d · teknik %d) → %s\n"
             "UCUZ DENEY: %s\nÖLÜM ŞARTI: %s\nKANIT SINIFI: %s"
             % (a.baslik, puan, a.deger, a.pazar, a.teknik, karar, a.deney, a.oldur, a.kanit))
    if a.kuru:
        print("KURU — deftere YAZILMADI:\n" + satir); return 0
    if not os.path.isfile(DEFTER_YAZ):
        print("ÖLÇÜLEMEDİ: defter aracı yok (%s)" % DEFTER_YAZ, file=sys.stderr); return 3
    r = subprocess.run([sys.executable, DEFTER_YAZ, "yeni", "--baslik", a.baslik[:120],
                        "--hal", hal, "--not", satir, "--kim", a.kim],
                       capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        print("ÖLÇÜLEMEDİ: deftere yazılamadı — %s" % (r.stderr or r.stdout).strip()[:200], file=sys.stderr)
        return 3
    print("✓ deftere girdi · puan %d/100 · karar: %s" % (puan, karar))
    print("  " + (r.stdout or "").strip()[:160])
    # M11 hâl zinciri: ≥75 ve sınıfsız = seçildi (otomatik). Eşik altı ya da sınıflı kayıt 'gelen'de
    # kalır — onu yalnız Sultan'ın satırı 'seçildi' yapar (imar-defter.py secildi --sultan "…").
    if karar == "OTOMATİK İNŞA":
        m = re.search(r"S-\d+", r.stdout or "")
        zd = os.path.join(os.path.dirname(os.path.abspath(__file__)), "imar-defter.py")
        if m and os.path.isfile(zd):
            z = subprocess.run([sys.executable, zd, "secildi", m.group(0), "--otomatik", "--puan", str(puan), "--kim", a.kim],
                               capture_output=True, text=True, timeout=30)
            print("  zincir: " + ("seçildi (otomatik)" if z.returncode == 0 else "⚠ seçildi damgası basılamadı: %s" % (z.stdout + z.stderr).strip()[:120]))
        else:
            print("  zincir: ⚠ kayıt numarası okunamadı ya da imar-defter.py yok — damga basılmadı, 'gelen'de duruyor")
    return 0

sys.exit(main())
