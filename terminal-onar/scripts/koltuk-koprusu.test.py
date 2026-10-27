#!/usr/bin/env python3
"""koltuk-koprusu sınavı — gerçek tmux (geçici TMUX_TMPDIR), gerçek UNIX soketi, gerçek SO_PEERCRED. KOPRU= köprü dosyası (mutant sınavı için)."""
import base64, json, os, shutil, socket, subprocess, sys, tempfile, time

KOPRU = os.environ.get("KOPRU") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "koltuk-koprusu.py")
T = tempfile.mkdtemp(prefix="kopru-")
os.makedirs(T + "/tmux", exist_ok=True)
ENV = dict({k: v for k, v in os.environ.items() if k != "TMUX"}, TMUX_TMPDIR=T + "/tmux", KOPRU_SOKET=T + "/k.sock", KOPRU_KUTU="demo", KOPRU_KISI="aysenur",
           KOPRU_IZIN_DOSYA=T + "/izin.json", KOPRU_IZ=T + "/iz.jsonl", KOPRU_MESAJ_ARALIK="0.3",
           KOPRU_LISTE_KOMUT=T + "/liste.sh", KOPRU_MESAJ_KOMUT=T + "/mesaj.sh", KOPRU_IZIN_UID=str(os.getuid()))
sonuc = {"gecti": 0, "kaldi": 0}


def ok(ad, kosul, ayrinti=""):
    sonuc["gecti" if kosul else "kaldi"] += 1
    print(("  ✓ " if kosul else "  ✗ ") + ad + ("" if kosul else "  → " + str(ayrinti)), flush=True)


def tmux(*a):
    if a and a[0] == "kill-server":   # 🔴 yalnız ÖZEL sunucuyu öldür: gerçek sunucuya (TMUX değişkeni!) dokunma
        yol = subprocess.run(["tmux", "display-message", "-p", "#{socket_path}"], env=ENV, capture_output=True, text=True).stdout.strip()
        if not yol.startswith(T):
            print("GÜVENLİK: tmux sunucusu özel değil, kill-server YAPILMADI:", yol); return None
    return subprocess.run(["tmux", *a], env=ENV, capture_output=True, text=True)


def yaz(yol, icerik, kip=None):
    open(yol, "w").write(icerik)
    if kip:
        os.chmod(yol, kip)


yaz(T + "/liste.sh", '#!/bin/sh\nif [ -e "' + T + '/degis" ]; then n=$(cat "' + T + '/sayac" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "' + T + '/sayac"; if [ $n -ge 2 ]; then cat "' + T + '/liste2.tsv"; exit 0; fi; fi\ncat "' + T + '/liste.tsv"\n', 0o755)
yaz(T + "/mesaj.sh", '#!/bin/sh\ncat > "' + T + '/mesaj.gelen"\necho "$1 $2" > "' + T + '/mesaj.arg"\necho ulak_TEST-1\n', 0o755)
yaz(T + "/izin.json", json.dumps({"kisiler": [{"id": "aysenur", "kutular": {"demo": ["demo-ana", "menu-ana", "gorunmez"], "baska": ["baska-ana"]}}]}))
tmux("new-session", "-d", "-s", "demo-ana", "-x", "80", "-y", "24", "echo MERHABA-KOLTUK; sleep 600")
tmux("new-session", "-d", "-s", "menu-ana", "-x", "80", "-y", "24", "echo Devam?; echo '1. Evet'; echo '2. Hayır'; cat")
tmux("new-session", "-d", "-s", "yasak-ana", "-x", "80", "-y", "24", "sleep 600")
SORU = json.dumps({"tur": "menu", "metin": "Devam?", "siklar": [{"no": 1, "metin": "Evet"}, {"no": 2, "metin": "Hayır"}], "beri": 1})


def liste(menu_hali="soru"):
    satirlar = ["demo-ana\t1\t1\tajan\tcalisiyor\t\t\t", "menu-ana\t1\t1\tajan\t%s\t\t\t%s" % (menu_hali, SORU),
                "yasak-ana\t1\t1\tajan\tbos\t\t\t"]   # yasak-ana görünür ama izinde YOK; gorunmez izinde ama görünmez
    yaz(T + "/liste.tsv", "\n".join(satirlar) + "\n")


liste()
kopru = subprocess.Popen([sys.executable, KOPRU], env=ENV, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
for _ in range(50):
    if os.path.exists(T + "/k.sock"):
        break
    time.sleep(0.1)


class Ist:
    def __init__(self):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.settimeout(8)
        self.s.connect(T + "/k.sock")
        self.tam = b""

    def yolla(self, **o):
        self.s.sendall((json.dumps(o) + "\n").encode())

    def satir(self, ilk_cikti_degil=True, sure=6):
        son = time.time() + sure
        while time.time() < son:
            if b"\n" in self.tam:
                l, self.tam = self.tam.split(b"\n", 1)
                return json.loads(l)
            try:
                v = self.s.recv(65536)
            except socket.timeout:
                return None
            if not v:
                return None
            self.tam += v
        return None

    def sonraki(self, tip, sure=6):
        son = time.time() + sure
        while time.time() < son:
            m = self.satir(sure=max(0.1, son - time.time()))
            if m is None:
                return None
            if m.get("t") == tip:
                return m
        return None

    def cikti_topla(self, sure=2.5):
        son, v = time.time() + sure, ""
        while time.time() < son:
            m = self.satir(sure=0.5)
            if m and m.get("t") == "cikti":
                v += base64.b64decode(m["b"]).decode(errors="replace")
        return v


def yeni_izle(koltuk="demo-ana"):
    c = Ist()
    c.yolla(op="izle", koltuk=koltuk, satir=24, sutun=80)
    return c


try:
    print("K1 liste: izinli ∩ görünür")
    c = Ist(); c.yolla(op="liste"); m = c.sonraki("liste")
    adlar = sorted(k["ad"] for k in (m or {}).get("koltuklar", []))
    ok("K1 yalnız demo-ana ve menu-ana (yasak-ana izinde yok, gorunmez görünmez)", adlar == ["demo-ana", "menu-ana"], adlar)

    print("K2 izle: salt okur akış")
    c = yeni_izle(); v = c.cikti_topla()
    ok("K2 izinli koltuğun ekranı akıyor", "MERHABA-KOLTUK" in v, v[-200:])
    ro = tmux("list-clients", "-F", "#{client_readonly}").stdout.split()
    ok("K3 tmux istemcisi SALT OKUR (-r)", ro.count("1") >= 1 and "0" not in ro, ro)

    print("K4 ham tuş yolu yok")
    for op in ({"op": "tus", "tus": "x"}, {"op": "girdi", "veri": "echo HAM > /tmp/ham-" + str(os.getpid()) + "\n"}, {"op": "yaz", "b": "aGk="}):
        c.yolla(**op); r = c.sonraki("ret")
        ok("K4 '%s' reddedildi" % op["op"], bool(r) and r["neden"] == "bilinmeyen-eylem", r)
    time.sleep(0.6)
    ok("K5 ham komut çalışmadı", not os.path.exists("/tmp/ham-" + str(os.getpid())))
    cap = tmux("capture-pane", "-p", "-t", "=demo-ana:").stdout
    ok("K6 koltuk ekranına ham girdi düşmedi", "HAM" not in cap, cap[-120:])

    print("K7 kapılar")
    c = yeni_izle("yasak-ana"); r = c.sonraki("ret")
    ok("K7 izinde olmayan koltuk reddi", bool(r) and r["neden"] == "koltuk-izinli-degil", r)
    c = yeni_izle("gorunmez"); r = c.sonraki("ret")
    ok("K8 izinde ama görünmeyen koltuk reddi", bool(r) and r["neden"] == "koltuk-izinli-degil", r)
    for kotu in ("$1", "a:b", "a.b", " a", "=demo-ana", "demo-ana\n", ""):
        c = yeni_izle(kotu); r = c.sonraki("ret")
        ok("K9 geçersiz ad %r reddi" % kotu, bool(r) and r["neden"] == "koltuk-adi-gecersiz", r)
    yaz(T + "/liste.tsv", ""); c = yeni_izle(); r = c.sonraki("ret")
    ok("K10 görünür liste boşken izle reddi (boş liste ≠ izin)", bool(r) and r["neden"] == "koltuk-izinli-degil", r)
    os.remove(T + "/liste.tsv"); c = yeni_izle(); r = c.sonraki("ret")
    ok("K10b liste komutu düşünce 'ölçülemedi' (boş sanılmaz)", bool(r) and r["neden"] == "koltuklar-olculemedi", r)
    liste()
    ENV_ESKI = ENV["KOPRU_LISTE_KOMUT"]
    yaz(T + "/izin.json", "{bozuk")
    c = Ist(); c.yolla(op="liste"); m = c.sonraki("liste")
    ok("K11 bozuk izin dosyası → boş liste (fail-closed)", m is not None and m["koltuklar"] == [], m)
    yaz(T + "/izin.json", json.dumps({"kisiler": [{"id": "aysenur", "kutular": {"demo": ["demo-ana", "menu-ana", "gorunmez"]}}]}))

    print("K12 mesaj")
    c = yeni_izle(); c.cikti_topla(0.8)
    c.yolla(op="mesaj", metin="Merhaba\x1b[31m\x07 ajan\x00!"); r = c.sonraki("tamam")
    gelen = open(T + "/mesaj.gelen").read() if os.path.exists(T + "/mesaj.gelen") else None
    ok("K12 mesaj posta komutuna ulaştı, kimlik döndü", bool(r) and r["kimlik"] == "ulak_TEST-1" and gelen is not None, (r, gelen))
    ok("K13 denetim karakterleri atıldı", gelen is not None and "\x1b" not in gelen and "\x07" not in gelen and "\x00" not in gelen, repr(gelen))
    ok("K14 koltuk ve kişi komuta argüman gitti", open(T + "/mesaj.arg").read().strip() == "demo-ana aysenur")
    c.yolla(op="mesaj", metin="hemen ikinci"); r = c.sonraki("ret")
    ok("K15 sık mesaj sınırı", bool(r) and r["neden"] == "cok-sik", r)
    time.sleep(0.5)
    c.yolla(op="mesaj", metin="x" * 2001); r = c.sonraki("ret")
    ok("K16 2000 karakter üstü reddi", bool(r) and r["neden"] == "metin-bos-ya-da-uzun", r)
    time.sleep(0.5)
    c.yolla(op="mesaj", metin="  \n\t "); r = c.sonraki("ret")
    ok("K17 boş mesaj reddi", bool(r) and r["neden"] == "metin-bos-ya-da-uzun", r)
    c2 = Ist(); c2.yolla(op="mesaj", metin="izlemeden"); r = c2.sonraki("ret")
    ok("K18 izlemeden mesaj reddi", bool(r) and r["neden"] == "once-izle", r)

    print("K19 menü şıkkı")
    cm = yeni_izle("menu-ana"); cm.cikti_topla(0.8)
    cm.yolla(op="sik", no=2); r = cm.sonraki("tamam")
    time.sleep(0.4)
    cap = tmux("capture-pane", "-p", "-t", "=menu-ana:").stdout
    ok("K19 sunulan şık tuşu koltuğa gitti", bool(r) and r["no"] == 2 and any(l.strip() == "2" for l in cap.splitlines()), (r, cap[-80:]))
    cm.yolla(op="sik", no=7); r = cm.sonraki("ret")
    ok("K20 sunulmayan şık reddi", bool(r) and r["neden"] == "sik-sunulmadi", r)
    cm.yolla(op="sik", no="2; rm"); r = cm.sonraki("ret")
    ok("K21 sayı olmayan şık reddi", bool(r) and r["neden"] == "sik-gecersiz", r)
    liste("calisiyor")
    cm.yolla(op="sik", no=1); r = cm.sonraki("ret")
    ok("K22 soru yokken şık reddi", bool(r) and r["neden"] == "menu-sorusu-yok", r)
    liste()

    print("K27 iz yazılamıyorsa yan etkili eylem YAPILMAZ (göz tur 1)")
    time.sleep(0.4)
    os.rename(T + "/iz.jsonl", T + "/iz.eski"); os.mkdir(T + "/iz.jsonl")   # iz yolu bir dizin → open() OSError
    if os.path.exists(T + "/mesaj.gelen"): os.remove(T + "/mesaj.gelen")
    c.yolla(op="mesaj", metin="izsiz mesaj olmamalı"); r = c.sonraki("ret")
    ok("K27 iz yazılamıyor → mesaj reddi (iz-yazilamadi)", bool(r) and r["neden"] == "iz-yazilamadi", r)
    ok("K27b mesaj komutu ÇALIŞMADI", not os.path.exists(T + "/mesaj.gelen"))
    cm.yolla(op="sik", no=1); r = cm.sonraki("ret")
    ok("K27c iz yazılamıyor → şık reddi (iz-yazilamadi)", bool(r) and r["neden"] == "iz-yazilamadi", r)
    os.rmdir(T + "/iz.jsonl"); os.rename(T + "/iz.eski", T + "/iz.jsonl")

    print("K28 liste bayatken (soru ekrandan gitti) tuş GİTMEZ: doğrulama + gönderim tek tmux komutunda (göz tur 1+2)")
    tmux("respawn-pane", "-k", "-t", "=menu-ana:", "cat")   # ekran temiz; ama liste komutu hâlâ 'soru' diyor (bayat okuma = yarışın ta kendisi)
    time.sleep(0.6)
    once = tmux("capture-pane", "-p", "-t", "=menu-ana:").stdout
    cm.yolla(op="sik", no=1); r = cm.sonraki("ret"); time.sleep(0.4)
    sonra = tmux("capture-pane", "-p", "-t", "=menu-ana:").stdout
    ok("K28 soru ekranda yok → şık reddi (soru-degisti)", bool(r) and r["neden"] == "soru-degisti", r)
    ok("K28b tuş koltuğa gitmedi", once == sonra, (once[-60:], sonra[-60:]))
    tmux("respawn-pane", "-k", "-t", "=menu-ana:", "echo \"Başka soru\"; echo \"1. Evet\"; cat")
    time.sleep(0.6); cm.yolla(op="sik", no=1); r = cm.sonraki("ret")
    ok("K28c aynı şık metni ama BAŞKA soru → reddi (iki koşul birlikte)", bool(r) and r["neden"] == "soru-degisti", r)
    SORU_KOTU = json.dumps({"tur": "menu", "metin": "Sil #{x}?", "siklar": [{"no": 1, "metin": "Evet"}, {"no": 2, "metin": "Hayır"}], "beri": 3})
    yaz(T + "/liste.tsv", "demo-ana\t1\t1\tajan\tcalisiyor\t\t\t\nmenu-ana\t1\t1\tajan\tsoru\t\t\t" + SORU_KOTU + "\n")
    cm.yolla(op="sik", no=1); r = cm.sonraki("ret")
    ok("K28d tmux biçim karakterli soru metni → koşul kurulamaz, tuş gitmez (kosul-kurulamadi)", bool(r) and r["neden"] == "kosul-kurulamadi", r)
    liste()

    print("K23 uid kapısı")
    kopru.terminate(); kopru.wait()
    ENV2 = dict(ENV, KOPRU_IZIN_UID="1", KOPRU_SOKET=T + "/k2.sock")
    k2 = subprocess.Popen([sys.executable, KOPRU], env=ENV2, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    for _ in range(50):
        if os.path.exists(T + "/k2.sock"):
            break
        time.sleep(0.1)
    s = socket.socket(socket.AF_UNIX); s.settimeout(5); s.connect(T + "/k2.sock")
    s.sendall(b'{"op":"liste"}\n'); d = s.recv(4096)
    ok("K23 izinli olmayan uid reddi", b'"kimlik"' in d, d)
    ok("K24 sokete 0660 kip", oct(os.stat(T + "/k2.sock").st_mode & 0o777) == "0o660", oct(os.stat(T + "/k2.sock").st_mode & 0o777))
    k2.terminate()
    iz = open(T + "/iz.jsonl").read()
    ok("K25 eylemler izli (mesaj/sik/ret)", '"op": "mesaj"' in iz and '"op": "sik"' in iz and '"sonuc": "ret"' in iz and "uid-izinli-degil" in iz)
    ok("K26 iz günlüğü mesaj METNİNİ taşımaz", "Merhaba" not in iz)
    # K27: abc `ayse` grubuna üye değilse chown EPERM verir; köprü ölmemeli (medigate 27 Eki: köprü sessizce düşüp soket yetim kaldı)
    import importlib.util
    sp = importlib.util.spec_from_file_location("kopru_mod", KOPRU); mod = importlib.util.module_from_spec(sp); sp.loader.exec_module(mod)
    eski_chown, eski_ortam = mod.os.chown, os.environ.get("KOPRU_GRUP")
    def reddet(*a, **k): raise PermissionError(1, "Operation not permitted")
    mod.os.chown = reddet; os.environ["KOPRU_GRUP"] = "root"
    try:
        s3 = mod.dinle(T + "/k3.sock"); dinledi = True; s3.close()
    except PermissionError:
        dinledi = False
    finally:
        mod.os.chown = eski_chown
        os.environ.pop("KOPRU_GRUP", None) if eski_ortam is None else os.environ.__setitem__("KOPRU_GRUP", eski_ortam)
    ok("K27d grup atama izni reddedilse de köprü dinlemeye başlar", dinledi)
finally:
    kopru.poll() is None and kopru.terminate()
    tmux("kill-server")
    shutil.rmtree(T, ignore_errors=True)

print("\n%d geçti, %d kaldı" % (sonuc["gecti"], sonuc["kaldi"]))
sys.exit(1 if sonuc["kaldi"] else 0)
