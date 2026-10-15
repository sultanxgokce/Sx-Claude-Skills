#!/usr/bin/env python3
"""imar-defter.py — ⛩️ İMAR tek defter, HÂL ZİNCİRİ (M11):  gelen → seçildi → yapılıyor → canlı → onaylandı

NİÇİN BÖYLE: Sultan tek defter ve beş hâl istedi. Bulgu Defteri (MUAVİN paketi, /config/.ic-sayfa) dört
hâl tanır: acik · uygulandi · canli · onaylandi — ve bu küme ekranla ORTAK TEK SÖZLÜKtür (defter_ortak.py:24).
O sözlüğe "seçildi/yapılıyor" eklemek paketi çatallar (DEVRİYE aynı kalıbı kullanır). Bu yüzden:
  • defter ikinci kez KURULMAZ; kayıt, numara, kilit, ekran hep Bulgu Defteri'nindir
  • Sultan'ın beş hâli Bulgu Defteri'nin dört hâli + damgalı not ile ifade edilir:
        gelen     = hal acik, damga yok
        seçildi   = hal acik + not "[İMAR hâl] seçildi · <kim> · <niçin>"
        yapılıyor = hal acik + not "[İMAR hâl] yapılıyor · …"
        canlı     = hal canli  (defterin kendi kapısı: notta sürüm + ölçüm zorunlu)
        onaylandı = hal onaylandi  — YALNIZ Sultan'ın kendi satırıyla (A06); ajan uyduramaz
  • "seçildi" damgasının iki meşru kaynağı var: puan ≥ 75 (otomatik, fikir kapısı yazar) ya da Sultan'ın
    tek tuşu (--sultan "<onun satırı>"). İkisi de yoksa damga BASILMAZ.
Bu dosya SALT-OKUR görüşü doğrudan bulgular.json'dan alır; her YAZMA defter-yaz.py üzerinden (kilitli, doğrulamalı).

Kullanım:
  imar-defter.py zincir                       beş hâlin sayımı + kayıt başına konum
  imar-defter.py gelen                        Sultan'ın önünde bekleyenler (seçilmemiş açık kayıtlar)
  imar-defter.py secildi  <kayıt> (--otomatik --puan N | --sultan "<satır>") [--kim AD]
  imar-defter.py yapiliyor <kayıt> --not "ne yapılıyor" [--kim AD]
  imar-defter.py canli    <kayıt> --surum "<sürüm/sha>" --olcum "<ölçüm>" [--kim AD]
  imar-defter.py onaylandi <kayıt> --sultan "<Sultan'ın kendi satırı>" [--kim AD]
  imar-defter.py oldur    <kayıt> --sultan "<Sultan'ın satırı>" [--not "sebep"]   → mezarlık (M10 ret yolu)
rc: 0 tamam · 1 defter hatası · 2 kullanım/kapı reddi · 3 ölçülemedi
"""
import sys, os, json, re, subprocess, argparse

DEFTER_YAZ = os.environ.get("DEFTER_YAZ", "/config/.ic-sayfa/defter-yaz.py")
BULGULAR = os.environ.get("BULGULAR_JSON", "/config/.ic-sayfa/bulgu-defteri/bulgular.json")
DAMGA = "[İMAR hâl]"
SIRA = ["gelen", "seçildi", "yapılıyor", "canlı", "onaylandı"]


def kayitlar():
    try:
        d = json.load(open(BULGULAR, encoding="utf-8"))
    except Exception as e:
        print("ÖLÇÜLEMEDİ: defter okunamadı (%s)" % e, file=sys.stderr); sys.exit(3)
    return d if isinstance(d, list) else d.get("bulgular") or d.get("kayitlar") or []


def konum(k):
    """Kaydın zincirdeki yeri: defter hâli önce, sonra son damga."""
    hal = k.get("hal")
    if hal == "onaylandi": return "onaylandı"
    if hal == "canli": return "canlı"
    son = None
    for n in k.get("notlar", []):
        m = re.match(r"\s*\[İMAR hâl\]\s*(seçildi|yapılıyor|öldü)", str(n.get("metin", "")))
        if m: son = m.group(1)
    if son == "öldü": return "öldü"   # mezarlık: zincirin dışında, 'gelen'de bekletilmez
    if hal == "uygulandi": return son or "yapılıyor"   # uygulandı = yapıldı, henüz canlı değil
    return son or "gelen"


def norm(kayit):
    m = re.search(r"(\d+)", kayit); return "S-%d" % int(m.group(1)) if m else kayit


def bul(kayit):
    no = norm(kayit)
    for k in kayitlar():
        if k.get("no") == no: return k
    print("kayıt yok: %s" % no, file=sys.stderr); sys.exit(2)


def yaz(args):
    r = subprocess.run([sys.executable, DEFTER_YAZ] + args, capture_output=True, text=True)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
    return r.returncode


def main():
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("komut", nargs="?", default="zincir")
    p.add_argument("kayit", nargs="?")
    p.add_argument("--otomatik", action="store_true"); p.add_argument("--puan", type=int)
    p.add_argument("--sultan"); p.add_argument("--kim", default=os.environ.get("IMAR_AJAN") or os.environ.get("CLAUDE_AGENT") or "")
    p.add_argument("--not", dest="not_"); p.add_argument("--surum"); p.add_argument("--olcum")
    a = p.parse_args()

    if a.komut == "zincir":
        ks = kayitlar(); say = {h: 0 for h in SIRA + ["öldü"]}; satir = []
        for k in ks:
            c = konum(k); say[c] += 1
            satir.append("  %-6s %-10s %s" % (k.get("no"), c, k.get("baslik", "")[:70]))
        print("⛩️ İMAR hâl zinciri · " + " → ".join("%s %d" % (h, say[h]) for h in SIRA) + " · mezarlık %d" % say["öldü"])
        print("\n".join(satir) if satir else "  (kayıt yok)")
        return 0
    if a.komut == "gelen":
        g = [k for k in kayitlar() if konum(k) == "gelen"]
        print("Sultan'ın önünde bekleyen: %d" % len(g))
        for k in g: print("  %-6s %s" % (k.get("no"), k.get("baslik", "")[:80]))
        return 0

    if not a.kayit: print(__doc__); return 2
    k = bul(a.kayit); no = k["no"]; simdi = konum(k)

    if a.komut == "secildi":
        if simdi != "gelen": print("kapı: %s zaten '%s' — seçildi damgası yalnız 'gelen' kayda basılır" % (no, simdi)); return 2
        if a.otomatik and a.puan is not None and a.puan >= 75:
            metin = "%s seçildi · otomatik (puan %d ≥ 75) · %s" % (DAMGA, a.puan, a.kim)
        elif a.sultan and a.sultan.strip():
            metin = "%s seçildi · Sultan'ın satırı: \"%s\" · aktaran %s" % (DAMGA, a.sultan.strip(), a.kim)
        else:
            print("kapı (A06): seçildi damgası iki kaynaktan birini ister — --otomatik --puan ≥75 ya da --sultan \"<onun satırı>\". İkisi de yok, damga basılmadı."); return 2
        return yaz(["not", no, "--metin", metin, "--kim", a.kim])

    if a.komut == "yapiliyor":
        if simdi not in ("seçildi",): print("kapı: %s '%s' — yapılıyor damgası yalnız 'seçildi' kayda basılır (seçilmeden inşa yok)" % (no, simdi)); return 2
        if not a.not_: print("--not zorunlu: ne yapılıyor?"); return 2
        return yaz(["not", no, "--metin", "%s yapılıyor · %s · %s" % (DAMGA, a.not_, a.kim), "--kim", a.kim])

    if a.komut == "canli":
        if simdi not in ("yapılıyor",): print("kapı: %s '%s' — canlı yalnız 'yapılıyor'dan gelir" % (no, simdi)); return 2
        if not (a.surum and a.olcum): print("--surum ve --olcum zorunlu (defterin kendi kapısı da bunu ister)"); return 2
        rc = yaz(["not", no, "--metin", "%s canlı · sürüm: %s · ölçüm: %s · %s" % (DAMGA, a.surum, a.olcum, a.kim), "--kim", a.kim])
        if rc: return rc
        return yaz(["hal", no, "--hal", "canli", "--gerekce", "sürüm %s · ölçüm %s" % (a.surum, a.olcum), "--kim", a.kim])

    if a.komut == "oldur":
        # M10'un öteki yarısı: Sultan "öldür" derse fikir mezarlığa gider (sebebiyle) — yeniden doğarsa
        # fikir kapısı Jaccard eşlemesiyle yakalar. Yalnız 'gelen' ya da 'seçildi' öldürülür; inşası
        # başlamış iş (yapılıyor/canlı) öldürülmez, geri alınır — o ayrı karardır.
        if simdi not in ("gelen", "seçildi"): print("kapı: %s '%s' — öldürme yalnız 'gelen' ya da 'seçildi' kayda uygulanır" % (no, simdi)); return 2
        if not (a.sultan and a.sultan.strip()): print("kapı (A06): öldürme Sultan'ın satırını ister (--sultan \"…\"); ajan fikir öldüremez, yazılmadı."); return 2
        sebep = (a.not_ or a.sultan).strip()
        mezar = os.environ.get("FIKIR_MEZARLIGI") or os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hafiza", "fikir-mezarligi.jsonl")
        import datetime
        kayit = {"tarih": datetime.date.today().isoformat(), "baslik": k.get("baslik", ""), "sebep": sebep,
                 "kayit": no, "kim": a.kim, "sultan": a.sultan.strip()}
        os.makedirs(os.path.dirname(mezar), exist_ok=True)
        with open(mezar, "a", encoding="utf-8") as f: f.write(json.dumps(kayit, ensure_ascii=False) + "\n")
        return yaz(["not", no, "--metin", "%s öldü · Sultan'ın satırı: \"%s\" · sebep: %s · aktaran %s" % (DAMGA, a.sultan.strip(), sebep, a.kim), "--kim", a.kim])

    if a.komut == "onaylandi":
        if simdi != "canlı": print("kapı: %s '%s' — onay yalnız 'canlı' kayda verilir" % (no, simdi)); return 2
        if not (a.sultan and a.sultan.strip()):
            print("kapı (A06): onaylandı YALNIZ Sultan'ın kendi satırıyla yazılır (--sultan \"…\"). Ajan onay uyduramaz; yazılmadı."); return 2
        rc = yaz(["not", no, "--metin", "%s onaylandı · Sultan'ın satırı: \"%s\" · aktaran %s" % (DAMGA, a.sultan.strip(), a.kim), "--kim", a.kim])
        if rc: return rc
        return yaz(["hal", no, "--hal", "onaylandi", "--gerekce", "Sultan: %s" % a.sultan.strip(), "--kim", a.kim])

    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main())
