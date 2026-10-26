#!/usr/bin/env python3
"""calisiliyor-uzlastir.py — defterdeki 'çalışılıyor' görevleri, ajanın AÇIK kartlarıyla uzlaştırır (DKYSHH + X666).

Kural (Sultan kararı + SERDAR 26 Eki): bir ajanın 'çalışılıyor' görevi YALNIZ şu ikisi birden doğruysa çalışılıyor kalır:
  (1) o görev için ajanın AÇIK (durum=acik) bir kartı var  → kartı olmayan görev 'çalışılıyor' sayılmaz (X666: 0MHE6C 25 Eki'den beri sahipsiz çalışılıyordu)
  (2) ajanın çalışılıyor sayısı AZAMI'yı (varsayılan 2) aşmıyor → fazlası, en eski hareketten başlayarak 'bekliyor + başka işe geçti' (DKYSHH)
KURU varsayılan: ne yapacağını söyler, deftere yazmaz. --uygula: fazlayı 'bekliyor'a çeker (gerekçe + not; defter notsuz bekliyor'u reddeder).
Kartlar tek depodan değil, --kart-kok glob'larından okunur (ajan birden çok depoda iş taşır). Jeton değeri hiçbir çıktıya girmez.
SAHİBİNE ZİL (X666 2. parça, SERDAR 26 Eki): bekliyor'a çekilen her görev için sahibine posta gider (aynı görev aynı son adımla ikinci kez zil çalmaz: --tekrar anahtarı).
KOLTUK BOŞ (--koltuk-bos-dk N, varsayılan 60; 0 kapatır): kalan 'çalışılıyor' görevin sahibinin koltuğu (koltuk-bagla --liste, hâl=bos) N dakikadan uzun boşsa
sahibine TEK zil: "bekliyor ya da onay bekliyor'a çek". Kendiliğinden çekmez (koltuk iki tur arası boş görünebilir); yalnız önerir.
SÜPÜRME (--koltuklardan): bu kutunun koltuklarındaki bütün ajanlar için koşar (kart.sh çalıştırılmasa da takılı kalan iş yakalanır).
rc 0 temiz/uygulandı · 4 en az bir yazım ya da okuma başarısız · 2 kullanım.
"""
import argparse, glob, json, os, subprocess, sys, time, unicodedata, urllib.request, urllib.error

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

def koltuklari_oku(komut):
    """koltuk-bagla --liste çıktısı → [{ad, son(epoch), tur, hal}]. Okunamazsa None (ölçülemedi ≠ boş)."""
    try:
        c = subprocess.run(komut, capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    if c.returncode != 0:
        return None
    out = []
    for satir in c.stdout.splitlines():
        a = satir.split("\t")
        if len(a) < 5: continue
        try: son = int(a[1])
        except ValueError: continue
        out.append({"ad": a[0], "son": son, "tur": a[3], "hal": a[4]})
    return out

def koltuk_bos_dk(koltuklar, ajan, simdi):
    """→ (dakika, son) ajanın koltuğu hâl=bos ise boş kaldığı süre; değilse/koltuk yoksa None. Saf fonksiyon."""
    for k in koltuklar or []:
        if k["tur"] == "ajan" and norm(k["ad"]) == ajan and k["hal"] == "bos":
            return max(0, (simdi - k["son"]) // 60), k["son"]
    return None

def zil(komut, kimden, kime, metin, tekrar):
    """Sahibine posta. En iyi gayret: başarısızlık söylenir, rc'yi bozmaz (uzlaştırma yazımı zaten oldu)."""
    try:
        c = subprocess.run([komut, "gonder", kime, metin, "--kimden", kimden, "--aciliyet", "orta",
                            "--konu", "çalışılıyor uzlaştırması", "--tekrar", tekrar], capture_output=True, text=True, timeout=30)
        return c.returncode == 0
    except Exception:
        return False

def ad_sade(g):
    return ((g.get("adlar") or [{}])[0].get("deger", "") or "")[:70]

def tek_ajan(s, ajan, jeton, gorevler, acik, koltuklar, simdi):
    """Bir ajan için planı uygular; rc döner (0 / 4)."""
    rc = 0
    kimden = s.zil_kimden or ajan
    sahip_ad = next((((g.get("canli") or {}).get("atanan") or ajan) for g in gorevler if norm((g.get("canli") or {}).get("atanan")) == ajan), ajan)
    plan = planla(gorevler, acik, ajan, s.azami)
    if not plan: print("  ✓ çalışılıyor uzlaştırması: %s için fazla/sahipsiz çalışılıyor görev yok" % ajan)
    cekilen = set()
    for g, neden in plan:
        ad = ad_sade(g)
        if not s.uygula:
            print("  · KURU: %s (%s) çalışılıyor → bekliyor olurdu: %s" % (g["id"], ad, neden)); continue
        not_ = "başka işe geçti: %s (otomatik uzlaştırma)" % neden
        kod, _ = cagir(s.defter_uc, jeton, "PATCH", "/kayit/" + g["id"],
                       {"yerine": {"gorev_durumu": "bekliyor", "not": not_}, "gerekce": not_, "adimlar": ["[⏳ bekliyor] " + not_]})
        if kod == 200:
            print("  ✓ %s (%s) → bekliyor: %s" % (g["id"], ad, neden)); cekilen.add(g["id"])
            sahip = (g.get("canli") or {}).get("atanan") or ajan
            if s.zil_komut and not zil(s.zil_komut, kimden, sahip,
                    "[uzlaştırma] %s (%s) çalışılıyor'dan bekliyor'a çekildi: %s. Sürüyorsa kartını aç, yeniden çalışılıyor yap." % (g["id"], ad, neden),
                    "uzlastir-cek-%s-%s" % (g["id"], g.get("son_adim", ""))):
                print("  ⚠ %s: sahibine zil gidemedi (posta)" % g["id"]); rc = 4
        else: print("  ⚠ %s bekliyor'a çekilemedi (http %s)" % (g["id"], kod)); rc = 4
    # koltuk boş: kalan (çekilmeyen) çalışılıyor görevler için TEK zil; kendiliğinden çekmez
    if s.koltuk_bos_dk > 0 and koltuklar is not None:
        bos = koltuk_bos_dk(koltuklar, ajan, simdi)
        kalan = [g for g in gorevler if (g.get("canli") or {}).get("gorev_durumu") == "calisiliyor"
                 and norm((g.get("canli") or {}).get("atanan")) == ajan and g["id"] not in cekilen]
        if bos and bos[0] >= s.koltuk_bos_dk and kalan:
            liste = ", ".join("%s (%s)" % (g["id"], ad_sade(g)) for g in kalan[:5])
            print("  · koltuk %d dk'dır boş, çalışılıyor: %s" % (bos[0], liste))
            if s.uygula and s.zil_komut:
                if not zil(s.zil_komut, kimden, sahip_ad,
                           "[uzlaştırma] koltuğun %d dk'dır boş ama çalışılıyor görevin var: %s. Sürmüyorsa 'bekliyor' ya da 'onay bekliyor'a çek." % (bos[0], liste),
                           "uzlastir-koltuk-%s-%d" % (ajan, bos[1])):
                    print("  ⚠ koltuk-boş zili gidemedi (posta)"); rc = 4
    return rc

def main():
    a = argparse.ArgumentParser()
    a.add_argument("--ajan", action="append", default=[]); a.add_argument("--azami", type=int, default=2)
    a.add_argument("--uygula", action="store_true"); a.add_argument("--kart-kok", action="append", default=[])
    a.add_argument("--koltuklardan", action="store_true", help="bu kutunun koltuklarındaki bütün ajanlar için koş (süpürme)")
    a.add_argument("--koltuk-bos-dk", type=int, default=60)
    a.add_argument("--koltuk-komut", default=os.environ.get("UZLASTIR_KOLTUK_KOMUT", "/config/.claude/skills/terminal-onar/scripts/koltuk-bagla.sh --liste"))
    a.add_argument("--zil-komut", default=os.environ.get("UZLASTIR_ZIL_KOMUT", "/config/projects/cloudtop/infra/postane/posta.sh"))
    a.add_argument("--zil-kimden", default="")
    a.add_argument("--simdi", type=int, default=0, help="sınav için epoch")
    a.add_argument("--defter-uc", default=os.environ.get("DEFTER_UC", "http://cloudtop-defter:8791"))
    a.add_argument("--jeton-yol", default=os.environ.get("DEFTER_JETON_YOL", "/config/defter-jeton"))
    s = a.parse_args()
    if s.azami < 1: print("--azami en az 1", file=sys.stderr); return 2
    if not s.ajan and not s.koltuklardan: print("--ajan ya da --koltuklardan gerekli", file=sys.stderr); return 2
    if s.koltuk_bos_dk < 0: print("--koltuk-bos-dk 0 ya da pozitif", file=sys.stderr); return 2
    try: jeton = open(s.jeton_yol, encoding="utf-8").read().strip()
    except OSError: print("  ⚠ uzlaştırma atlandı: defter jetonu okunamadı"); return 4
    simdi = s.simdi or int(time.time())
    kokomut = s.koltuk_komut.split()
    koltuklar = koltuklari_oku(kokomut) if (s.koltuklardan or s.koltuk_bos_dk > 0) else None
    ajanlar = [norm(x) for x in s.ajan]
    if s.koltuklardan:
        if koltuklar is None: print("  ⚠ süpürme atlandı: koltuk listesi okunamadı"); return 4
        for k in koltuklar:
            if k["tur"] == "ajan" and norm(k["ad"]) not in ajanlar: ajanlar.append(norm(k["ad"]))
    kod, j = cagir(s.defter_uc, jeton, "GET", "/gorevler")
    if kod != 200 or not isinstance(j.get("gorevler", j.get("kayitlar")), list):
        print("  ⚠ uzlaştırma atlandı: görev listesi okunamadı (http %s)" % kod); return 4
    gorevler = j.get("gorevler", j.get("kayitlar"))
    rc = 0
    for ajan in ajanlar:
        if tek_ajan(s, ajan, jeton, gorevler, acik_gorevler(s.kart_kok, ajan), koltuklar, simdi): rc = 4
    return rc

if __name__ == "__main__":
    sys.exit(main())
