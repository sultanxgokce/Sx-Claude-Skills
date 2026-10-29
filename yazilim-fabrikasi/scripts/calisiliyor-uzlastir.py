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
PR BİRLEŞTİ (--pr-komut; TP00WX, X666 2. parçanın kapsam dışı kalan yarısı): kalan 'çalışılıyor' görevin AÇIK kartının PR'ı birleşmişse
(kartta pr yazılıysa o PR; yoksa dal adı = kart adı, kart.sh supur ile aynı DAR eşleme: 'ekip/ad' öneki ya da 'ad-N' soneki, altdize yok,
başka kartın adı olan dal sayılmaz) sahibine TEK zil: "PR #N birleşti ama görev çalışılıyor: kart.sh bitti → onay bekliyor ya da bekliyor".
Kendiliğinden ÇEKMEZ, yalnız önerir; tekrar anahtarı görev+PR. Liste her kart kökünün deposundan gh ile alınır; okunamazsa 'ölçülemedi' der,
zil çalmaz (uydurma 'birleşmedi' yok). KURU kipte yalnız yazar. --pr-komut "" kapatır.
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

def acik_kartlar(kokler, ajan):
    """→ {gorev: {"ad", "pr", "kok", "adlar"}} ajanın AÇIK kartları (kok = kart dosyasının dizini, glob kök değil) (adlar: o kökteki BÜTÜN kart adları, dal eşlemesinde 'başkasının adı' süzgeci)."""
    acik = {}
    for kok in kokler:
        adlar = {os.path.basename(f)[:-5] for f in glob.glob(os.path.join(kok, "*.json"))}
        for f in glob.glob(os.path.join(kok, "*.json")):
            try: k = json.load(open(f, encoding="utf-8"))
            except Exception: continue
            if k.get("durum") == "acik" and k.get("gorev") and norm(k.get("aldi")) == ajan:
                # kok: kart DOSYASININ gerçek dizini — --kart-kok tırnaklı glob gelebilir (süpürme cron'u: "/config/projects/*/_agents/fabrika/kartlar");
                # glob dizgisinden depo türetilemez (QY2D-sonrası KALDI, 29 Eki): canlıda 'PR listesi okunamadı' basıyordu
                acik[k["gorev"]] = {"ad": k.get("is") or os.path.basename(f)[:-5], "pr": k.get("pr"), "kok": os.path.dirname(os.path.abspath(f)), "adlar": adlar}
    return acik

def acik_gorevler(kokler, ajan):
    return set(acik_kartlar(kokler, ajan))

_PR_ONBELLEK = {}
def birlesmis_prler(kok, komut):
    """Kart kökünün deposunda birleşmiş PR listesi → ({dal: pr}, {no: pr}) ya da None (okunamadı = ÖLÇÜLEMEDİ, boş değil).
    Depo = <kök>/../../.. (kartlar _agents/fabrika/kartlar altında); o yol yoksa kökün kendisi. Depo başına bir kez çalışır."""
    if not komut: return None
    depo = os.path.abspath(os.path.join(kok, "..", "..", ".."))
    if not os.path.isdir(os.path.join(depo, ".git")): depo = kok
    if depo in _PR_ONBELLEK: return _PR_ONBELLEK[depo]
    try:
        c = subprocess.run(komut, cwd=depo, capture_output=True, text=True, timeout=60)
        liste = json.loads(c.stdout) if c.returncode == 0 else None
    except Exception:
        liste = None
    if not isinstance(liste, list): _PR_ONBELLEK[depo] = None; return None
    dal, no = {}, {}
    for p in liste:
        if p.get("mergedAt") and p.get("headRefName"):
            dal.setdefault(p["headRefName"], p); no[int(p["number"])] = p
    _PR_ONBELLEK[depo] = (dal, no); return _PR_ONBELLEK[depo]

import re as _re
def birlesmis_pr_bul(kart, prler):
    """Kartın birleşmiş PR'ı → pr dict ya da None. kart.sh supur ile AYNI kural: kartta pr varsa o numara; yoksa dal adı = kart adı,
    DAR varyant ('ekip/ad' öneki · 'ad-<sayı>' soneki); dal başka bir kartın kendi adıysa o kartındır; altdize eşlemesi YOK."""
    dal, no = prler; ad = kart["ad"]
    if kart.get("pr"):
        try: return no.get(int(str(kart["pr"]).lstrip("#")))
        except ValueError: return None
    if ad in dal: return dal[ad]
    for h, p in dal.items():
        ad_h = h.split("/", 1)[-1]
        if ({h, ad_h} - {ad}) & kart["adlar"]: continue
        if ad_h == ad or _re.fullmatch(_re.escape(ad) + r"-\d+", ad_h): return p
    return None

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

ZIL_ACILIYET = "genis"   # rahat: bilgi mektubu; postane 0.1.4 rahat mektup ölünce SERDAR'a zil çalmaz (…1SSZVC — 24 ölü uzlaştırma mektubu zil çalıyordu)

def zil(komut, kimden, kime, metin, tekrar):
    """Sahibine posta. En iyi gayret: başarısızlık söylenir, rc'yi bozmaz (uzlaştırma yazımı zaten oldu).
    Her deneme TEK satır günlük basar (görev …FAEKS1Y, 29 Eki): kime · aciliyet · tekrar anahtarı · posta rc — süpürme cron günlüğü bu satırla
    'rahat aciliyetle gitti' iddiasını ölçer; eskiden aciliyet hiçbir günlükte yoktu. Mektup metni ve jeton günlüğe YAZILMAZ."""
    try:
        c = subprocess.run([komut, "gonder", kime, metin, "--kimden", kimden, "--aciliyet", ZIL_ACILIYET,
                            "--konu", "çalışılıyor uzlaştırması", "--tekrar", tekrar], capture_output=True, text=True, timeout=30)
        # Postane (kimden, tekrar) tekil: aynı anahtarla ikinci gönderim YENİ mektup açmaz, '= aynı mesaj zaten vardı' döner (posta.mjs).
        #   Eskiden bu da 'zil →' diye yazılıyordu: 29 Eki süpürme günlüğünde 17 zil satırının 5'i yeni mektup değildi ve günlük canlı
        #   kanıt olarak okunuyor (görev …XGGM6). Ayrı satır: 'zil yinelendi →' — 'zil →' artık yalnız gerçekten açılan mektup.
        if c.returncode == 0 and (c.stdout or "").lstrip().startswith("= aynı mesaj zaten vardı"):
            print("  · zil yinelendi → %s · aciliyet %s · tekrar %s · postane: zaten vardı (yeni mektup yok)" % (kime, ZIL_ACILIYET, tekrar))
        else:
            print("  · zil → %s · aciliyet %s · tekrar %s · posta rc %d" % (kime, ZIL_ACILIYET, tekrar, c.returncode))
        return c.returncode == 0
    except Exception as e:
        print("  · zil → %s · aciliyet %s · tekrar %s · posta ÇALIŞMADI (%s)" % (kime, ZIL_ACILIYET, tekrar, type(e).__name__))
        return False

def ad_sade(g):
    return ((g.get("adlar") or [{}])[0].get("deger", "") or "")[:70]

def tek_ajan(s, ajan, jeton, gorevler, acik, koltuklar, simdi, kartlar=None):
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
    kalan = [g for g in gorevler if (g.get("canli") or {}).get("gorev_durumu") == "calisiliyor"
             and norm((g.get("canli") or {}).get("atanan")) == ajan and g["id"] not in cekilen]
    # PR birleşti (TP00WX): kalan görevin açık kartının PR'ı birleşmişse sahibine TEK öneri zili; kendiliğinden çekmez
    if s.pr_komut and kartlar is not None:
        olculemedi = set()
        for g in kalan:
            k = kartlar.get(g["id"])
            if not k: continue
            prler = birlesmis_prler(k["kok"], s.pr_komut.split())
            if prler is None:
                if k["kok"] not in olculemedi:
                    olculemedi.add(k["kok"]); print("  · PR listesi okunamadı (%s): PR-birleşti zili atlandı — ÖLÇÜLEMEDİ, 'birleşmedi' sayılmaz" % k["kok"])
                continue
            pr = birlesmis_pr_bul(k, prler)
            if not pr: continue
            metin = ("[uzlaştırma] %s (%s): kart '%s' PR #%s birleşti (%s) ama görev hâlâ çalışılıyor. kart.sh bitti %s --pr %s → onay bekliyor; "
                     "iş sürüyorsa bekliyor'a çek." % (g["id"], ad_sade(g), k["ad"], pr["number"], str(pr.get("mergedAt", ""))[:10], k["ad"], pr["number"]))
            if s.uygula is not True:
                print("  · KURU: %s (%s) kart '%s' PR #%s birleşti ama çalışılıyor → sahibine öneri zili çalardı" % (g["id"], ad_sade(g), k["ad"], pr["number"])); continue
            print("  · %s: kart '%s' PR #%s birleşti ama çalışılıyor → sahibine öneri zili" % (g["id"], k["ad"], pr["number"]))
            if s.zil_komut and not zil(s.zil_komut, kimden, sahip_ad, metin, "uzlastir-pr-%s-%s" % (g["id"], pr["number"])):
                print("  ⚠ %s: PR-birleşti zili gidemedi (posta)" % g["id"]); rc = 4
    # koltuk boş: kalan (çekilmeyen) çalışılıyor görevler için TEK zil; kendiliğinden çekmez
    if s.koltuk_bos_dk > 0 and koltuklar is not None:
        bos = koltuk_bos_dk(koltuklar, ajan, simdi)
        if bos and bos[0] > s.koltuk_bos_dk and kalan:
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
    a.add_argument("--pr-komut", default=os.environ.get("UZLASTIR_PR_KOMUT", "gh pr list --state merged --base main --limit 200 --json number,headRefName,mergedAt"),
                   help="kart kökünün deposunda koşar; birleşmiş PR listesi (JSON). Boş verilirse PR-birleşti zili kapalı")
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
        kartlar = acik_kartlar(s.kart_kok, ajan)
        if tek_ajan(s, ajan, jeton, gorevler, set(kartlar), koltuklar, simdi, kartlar): rc = 4
    return rc

if __name__ == "__main__":
    sys.exit(main())
