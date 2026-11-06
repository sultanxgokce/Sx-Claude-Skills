#!/usr/bin/env python3
"""sultan-eli iki-adim.py — iki adımlı insan-izi doğrulaması (görev …YC9DS, SERDAR ölçümü 6 Kas 2026).

NİÇİN: harness insan `!` komutunun kullanıcı kaydını komut BİTTİKTEN SONRA yazıyor (zaman damgası gönderim anı,
  satır sırası bitişten sonra). Komutun İÇİNDE koşan kapı kendi kaydını hiçbir zaman göremez; `sleep` ne olursa olsun düşer.
ÇARE: iki ayrı süreç.
  iz      (komutun İÇİNDE)   süreç zincirinde imzayı taşıyan kök komutu bulur; komut metnini, kökün başlangıç saatini
                              ve tek kullanımlık bir kimlik (nonce) bir iz dosyasına yazar. HİÇBİR ŞEYİ onaylamaz.
  onayla  (komuttan SONRA)   iz dosyasını açar, oturum kaydında şunu arar: <bash-input> metni (kırpılmış) iz'deki komutla
                              BİREBİR aynı ∧ kaydın zaman damgası kökün başlangıcından -2..+5 sn içinde. Bulursa VAR, izi HARCAR.
GÜVENLİK ÖZELLİKLERİ (hepsi sınavda mutantla ölçülür):
  · kayıt yoksa VAR yok: ajan `iz`'i kendi aracıyla koşsa da insan kaydı oluşmaz.
  · eski bir insan kaydı, başka zamanda bırakılmış izle eşleşmez (zaman bağı).
  · bir kayıt BİR kez harcanır: aynı kayıtla ikinci onay yok.
  · komut metni kayıttakiyle birebir olmalı (alt dize, önek/sonek geçmez).
  · iz yaşı sınırlı (varsayılan 900 sn; ortam yalnız düşürebilir).
Çıkış (onayla): 0 VAR · 1 YOK · 3 ÖLÇÜLEMEDİ (oturum kaydı görünmüyor). (iz): 0 bırakıldı · 1 zincirde imza yok · 2 kullanım.
"""
import datetime, fcntl, hashlib, json, os, re, secrets, sys, time, collections

IZ_TAVAN = 900          # saniye: iz'in en çok yaşı (MUTLAK; ortam yalnız düşürebilir)
BAS_ALT, BAS_UST = -2.0, 5.0   # kaydın zaman damgası - kökün başlangıcı (sn)


def ata(p, btime, tick):
    try:
        s = open("/proc/%d/stat" % p).read()
        r = s.rsplit(")", 1)[1].split()
        return int(r[1]), btime + int(r[19]) / tick
    except Exception:
        return 0, 0.0


def cmd(p):
    try:
        return open("/proc/%d/cmdline" % p, "rb").read().decode("utf-8", "replace").split("\0")
    except Exception:
        return []


def zincir_al(pid):
    tick = os.sysconf("SC_CLK_TCK")
    btime = [float(l.split()[1]) for l in open("/proc/stat") if l.startswith("btime")][0]
    z, p = [], pid
    for _ in range(16):
        pp, bas = ata(p, btime, tick)
        if not bas:
            break
        z.append((p, bas, cmd(p)))
        if pp <= 1:
            break
        p = pp
    return z


def kabuk_ayristir(m):
    out, i, n = [], 0, len(m)
    while i < n:
        c = m[i]
        if c in " \t":
            i += 1
            continue
        if c in "&|;<>\n":
            j = i + 1
            while j < n and m[j] in "&|;<>" and c != "\n" and m[i] in "&|;<>":
                j += 1
            out.append(("o", m[i:j]))
            i = j
            continue
        w, tirnakli = "", False
        while i < n and m[i] not in " \t&|;<>\n":
            c = m[i]
            if c == "'":
                k = m.find("'", i + 1)
                if k < 0:
                    return None
                w += m[i + 1:k]
                i = k + 1
                tirnakli = True
            elif c == '"':
                i += 1
                tirnakli = True
                while i < n and m[i] != '"':
                    if m[i] == "\\" and i + 1 < n and m[i + 1] in ('"', "\\", "$", "`"):
                        w += m[i + 1]
                        i += 2
                    else:
                        w += m[i]
                        i += 1
                if i >= n:
                    return None
                i += 1
            elif c == "\\":
                if i + 1 >= n:
                    return None
                w += m[i + 1]
                i += 2
                tirnakli = True
            else:
                w += c
                i += 1
        if w.isdigit() and not tirnakli and i < n and m[i] in "<>":
            continue
        out.append(("s", w))
    return out


def eval_argumanlari(a):
    """Komut konumundaki tırnaksız `eval`in argümanları (sultan-eli.sh ile AYNI kural)."""
    t = kabuk_ayristir(a)
    if not t:
        return []
    out = []
    for i, (tur, x) in enumerate(t):
        if tur != "s" or x != "eval":
            continue
        if i > 0 and not ((t[i - 1][0] == "o" and not any(ch in t[i - 1][1] for ch in "<>")) or (t[i - 1][0] == "s" and t[i - 1][1] in ("{", "(", "!"))):
            continue
        j, parca = i + 1, []
        while j < len(t) and t[j][0] == "s":
            parca.append(t[j][1])
            j += 1
        if parca:
            out.append(" ".join(parca))
    return out


def kok_komut(z, imza):
    """Zincirde, komutu imzayı taşıyan EN DIŞ (kök tarafı) süreç: (komut metni, başlangıç). Önce eval argümanı, yoksa argv öğesi."""
    for pid, bas, argv in reversed(z):   # kökten uca
        for a in argv:
            for c in eval_argumanlari(a):
                if imza in c:
                    return c.strip(), bas
        for a in argv:   # eval yoksa: komut tek bir argv öğesi olarak (bash -c "<komut>") verilmiş olabilir
            if imza in a and len(a) > len(imza) and not a.startswith("/"):
                return a.strip(), bas
    return None


def kayit_yazi(dosya):
    return os.path.join(dosya, "harcanan.txt")


def izler(izdir):
    out = []
    try:
        for ad in os.listdir(izdir):
            if ad.endswith(".json"):
                try:
                    out.append(json.load(open(os.path.join(izdir, ad), encoding="utf-8")))
                except Exception:
                    pass
    except Exception:
        pass
    return out


def anahtar(komut, ts):
    return hashlib.sha256((("%.3f" % ts) + "|" + komut).encode("utf-8")).hexdigest()[:24]


def harcananlar(izdir):
    try:
        return set(l.strip() for l in open(kayit_yazi(izdir), encoding="utf-8"))
    except Exception:
        return set()


def komut_iz(imza, pid, izdir):
    z = zincir_al(pid)
    k = kok_komut(z, imza)
    if not k:
        print("iz bırakılamadı: süreç zincirinde '%s' taşıyan bir kök komut yok (bu komut bir insan `!` komutu gibi görünmüyor)" % imza, file=sys.stderr)
        return 1
    komut, bas = k
    os.makedirs(izdir, mode=0o700, exist_ok=True)
    nonce = secrets.token_hex(8)
    iz = {"nonce": nonce, "imza": imza, "komut": komut, "kok_bas": bas, "an": time.time()}
    yol = os.path.join(izdir, nonce + ".json")
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(iz, f, ensure_ascii=False)
    os.chmod(yol, 0o600)
    print("iz bırakıldı: %s (komut kırpılmış %d karakter, kök başlangıcı %.1f sn önce) — komut bitince `onayla --imza %s` koşulur" % (nonce, len(komut), time.time() - bas, imza))
    return 0


def kayitlar(dosyalar, ust_satir=4000):
    for dosya in dosyalar:
        try:
            son = collections.deque(open(dosya, encoding="utf-8", errors="replace"), maxlen=ust_satir)
        except Exception:
            continue
        for satir in son:
            try:
                o = json.loads(satir)
            except Exception:
                continue
            ic = o.get("message", {}).get("content")
            if not isinstance(ic, str):
                continue
            m = re.search(r"<bash-input>(.*?)</bash-input>", ic, re.S)
            ts = o.get("timestamp")
            if not m or not ts:
                continue
            try:
                an = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
            except Exception:
                continue
            yield an, m.group(1).strip()


def onayla(imza, izdir, dosyalar, nonce, tavan):
    if not dosyalar:
        print("ÖLÇÜLEMEDİ: oturum kaydı görünmüyor — bu 'insan yok' DEMEK DEĞİLDİR", file=sys.stderr)
        return 3
    simdi = time.time()
    if not os.path.isdir(izdir):
        print("insan-izi YOK: iz dizini yok (iz komutun İÇİNDE `iz --imza ...` ile bırakılır)", file=sys.stderr)
        return 1
    kilit = open(os.path.join(izdir, ".kilit"), "a")
    fcntl.flock(kilit, fcntl.LOCK_EX)   # kontrol + harcama ATOMİK: eşzamanlı iki onay aynı kaydı/izi geçemez
    harcanan = harcananlar(izdir)
    aday = [i for i in izler(izdir) if i.get("imza") == imza and (not nonce or i.get("nonce") == nonce) and 0 <= simdi - i.get("an", 0) <= tavan and ("iz:" + str(i.get("nonce"))) not in harcanan]
    if not aday:
        print("insan-izi YOK: '%s' için taze iz yok (iz komutun İÇİNDE `iz --imza ...` ile bırakılır, en çok %d sn önce)" % (imza, tavan), file=sys.stderr)
        return 1
    kay = list(kayitlar(dosyalar))
    sebepler = []
    for iz in sorted(aday, key=lambda i: -i["an"]):
        for an, komut in kay:
            if komut != iz["komut"]:
                continue
            fark = an - iz["kok_bas"]
            if not (BAS_ALT <= fark <= BAS_UST):
                sebepler.append("kayıt var ama başlangıçla farkı %+.1f sn (izin %+.0f..%+.0f)" % (fark, BAS_ALT, BAS_UST))
                continue
            a = anahtar(komut, an)
            if a in harcanan:
                sebepler.append("bu kayıt daha önce harcandı")
                continue
            with open(kayit_yazi(izdir), "a", encoding="utf-8") as f:
                f.write(a + "\n")
                f.write("iz:" + str(iz["nonce"]) + "\n")   # iz de BİR kez: ikinci uygun kayıt aynı izle VAR üretemez
            print("insan-izi VAR (iki adım): '%s' geçen '!' komutunun kaydı, iz %s ile birebir ve başlangıçla %+.1f sn farklı; kayıt harcandı" % (imza, iz["nonce"], fark))
            return 0
    print("insan-izi YOK: %d iz var, eşleşen insan kaydı yok%s" % (len(aday), (" · " + "; ".join(sorted(set(sebepler)))) if sebepler else " · komut kaydı henüz yazılmamış olabilir (komut bitince tekrar dene)"), file=sys.stderr)
    return 1


def main(a):
    if len(a) < 2:
        return 2
    mod = a[1]
    try:
        if mod == "iz":
            imza, pid, izdir = a[2], int(a[3]), a[4]
            return komut_iz(imza, pid, izdir)
        if mod == "onayla":
            imza, izdir, nonce, tavan = a[2], a[3], a[4], float(a[5])
            return onayla(imza, izdir, a[6:], nonce, min(tavan, IZ_TAVAN))
    except Exception as e:
        print("ÖLÇÜLEMEDİ: %s" % e, file=sys.stderr)
        return 3
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
