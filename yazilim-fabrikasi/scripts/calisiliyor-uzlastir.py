#!/usr/bin/env python3
"""calisiliyor-uzlastir.py — defterdeki 'çalışılıyor' görevleri, ajanın AÇIK kartlarıyla uzlaştırır (DKYSHH + X666).

Kural (Sultan kararı + SERDAR 26 Eki): bir ajanın 'çalışılıyor' görevi YALNIZ şu ikisi birden doğruysa çalışılıyor kalır:
  (1) o görev için ajanın AÇIK (durum=acik) bir kartı var  → kartı olmayan görev 'çalışılıyor' sayılmaz (X666: 0MHE6C 25 Eki'den beri sahipsiz çalışılıyordu)
  (2) ajanın çalışılıyor sayısı AZAMI'yı (varsayılan 2) aşmıyor → fazlası, en eski hareketten başlayarak 'bekliyor + başka işe geçti' (DKYSHH)
KURU varsayılan: ne yapacağını söyler, deftere yazmaz. --uygula: fazlayı 'bekliyor'a çeker (gerekçe + not; defter notsuz bekliyor'u reddeder).
Kartlar tek depodan değil, --kart-kok glob'larından okunur (ajan birden çok depoda iş taşır). Jeton değeri hiçbir çıktıya girmez.
rc 0 temiz/uygulandı · 4 en az bir yazım ya da okuma başarısız · 2 kullanım.
"""
import argparse, glob, json, os, sys, unicodedata, urllib.request, urllib.error

def norm(ad):
    s = unicodedata.normalize("NFKD", str(ad or "")).replace("ı", "I")
    return "".join(c for c in s if not unicodedata.combining(c)).upper().strip()

def cagir(uc, jeton, yontem, yol, govde=None):
    veri = json.dumps(govde, ensure_ascii=False).encode() if govde is not None else None
    r = urllib.request.Request(uc.rstrip("/") + yol, data=veri, method=yontem,
                               headers={"x-defter-jeton": jeton, "content-type": "application/json"})
    try:
        with urllib.request.urlopen(r, timeout=15) as y:
            return y.status, json.loads(y.read() or b"{}")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"{}")
        except Exception: return e.code, {}
    except Exception:
        return 0, {}

def acik_gorevler(kokler, ajan):
    acik = set()
    for kok in kokler:
        for f in glob.glob(os.path.join(kok, "*.json")):
            try: k = json.load(open(f, encoding="utf-8"))
            except Exception: continue
            if k.get("durum") == "acik" and k.get("gorev") and norm(k.get("aldi")) == ajan:
                acik.add(k["gorev"])
    return acik

def planla(gorevler, acik, ajan, azami):
    """→ [(gorev, neden)] bekliyor'a çekilecekler. Saf fonksiyon (sınavın ana hedefi)."""
    benim = [g for g in gorevler if (g.get("canli") or {}).get("gorev_durumu") == "calisiliyor"
             and norm((g.get("canli") or {}).get("atanan")) == ajan]
    kart_yok = [g for g in benim if g["id"] not in acik]
    kartli = sorted([g for g in benim if g["id"] in acik], key=lambda g: g.get("son_adim", ""), reverse=True)
    plan = [(g, "açık kartı yok") for g in kart_yok]
    plan += [(g, "ajan başına en çok %d çalışılıyor" % azami) for g in kartli[azami:]]
    return plan

def main():
    a = argparse.ArgumentParser()
    a.add_argument("--ajan", required=True); a.add_argument("--azami", type=int, default=2)
    a.add_argument("--uygula", action="store_true"); a.add_argument("--kart-kok", action="append", default=[])
    a.add_argument("--defter-uc", default=os.environ.get("DEFTER_UC", "http://cloudtop-defter:8791"))
    a.add_argument("--jeton-yol", default=os.environ.get("DEFTER_JETON_YOL", "/config/defter-jeton"))
    s = a.parse_args()
    if s.azami < 1: print("--azami en az 1", file=sys.stderr); return 2
    try: jeton = open(s.jeton_yol, encoding="utf-8").read().strip()
    except OSError: print("  ⚠ uzlaştırma atlandı: defter jetonu okunamadı"); return 4
    ajan = norm(s.ajan)
    kod, j = cagir(s.defter_uc, jeton, "GET", "/gorevler")
    if kod != 200 or not isinstance(j.get("gorevler", j.get("kayitlar")), list):
        print("  ⚠ uzlaştırma atlandı: görev listesi okunamadı (http %s)" % kod); return 4
    gorevler = j.get("gorevler", j.get("kayitlar"))
    plan = planla(gorevler, acik_gorevler(s.kart_kok, ajan), ajan, s.azami)
    if not plan: print("  ✓ çalışılıyor uzlaştırması: %s için fazla/sahipsiz çalışılıyor görev yok" % s.ajan); return 0
    rc = 0
    for g, neden in plan:
        ad = (g.get("adlar") or [{}])[0].get("deger", "")[:70]
        if not s.uygula:
            print("  · KURU: %s (%s) çalışılıyor → bekliyor olurdu: %s" % (g["id"], ad, neden)); continue
        not_ = "başka işe geçti: %s (otomatik uzlaştırma)" % neden
        kod, _ = cagir(s.defter_uc, jeton, "PATCH", "/kayit/" + g["id"],
                       {"yerine": {"gorev_durumu": "bekliyor", "not": not_}, "gerekce": not_, "adimlar": ["[⏳ bekliyor] " + not_]})
        if kod == 200: print("  ✓ %s (%s) → bekliyor: %s" % (g["id"], ad, neden))
        else: print("  ⚠ %s bekliyor'a çekilemedi (http %s)" % (g["id"], kod)); rc = 4
    return rc

if __name__ == "__main__":
    sys.exit(main())
