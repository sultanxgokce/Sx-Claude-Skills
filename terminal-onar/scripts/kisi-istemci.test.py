#!/usr/bin/env python3
"""kisi-istemci sınavı — gerçek köprü + gerçek tmux + istemci GERÇEK bir pty içinde (tuşlar pty'ye yazılır)."""
import json, os, pty, select, shutil, struct, subprocess, sys, tempfile, termios, time, fcntl

ISTEMCI = os.environ.get("ISTEMCI") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "kisi-istemci.py")
KOPRU = os.path.join(os.path.dirname(os.path.abspath(__file__)), "koltuk-koprusu.py")
T = tempfile.mkdtemp(prefix="istemci-"); os.makedirs(T + "/tmux")
ENV = dict({k: v for k, v in os.environ.items() if k != "TMUX"}, TMUX_TMPDIR=T + "/tmux", KOPRU_SOKET=T + "/k.sock", KOPRU_KUTU="demo", KOPRU_KISI="aysenur", KOPRU_IZIN_DOSYA=T + "/izin.json",
           KOPRU_IZ=T + "/iz.jsonl", KOPRU_MESAJ_ARALIK="0.2", KOPRU_LISTE_KOMUT="cat " + T + "/liste.tsv", KOPRU_MESAJ_KOMUT=T + "/mesaj.sh", KOPRU_IZIN_UID=str(os.getuid()))
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


def yaz(y, i, k=None):
    open(y, "w").write(i); k and os.chmod(y, k)


yaz(T + "/mesaj.sh", '#!/bin/sh\ncat > "' + T + '/mesaj.gelen"\necho ulak_T\n', 0o755)
yaz(T + "/izin.json", json.dumps({"kisiler": [{"id": "aysenur", "kutular": {"demo": ["demo-ana", "menu-ana"]}}]}))
SORU = json.dumps({"tur": "menu", "metin": "Devam?", "siklar": [{"no": 1, "metin": "a"}, {"no": 2, "metin": "b"}]})
yaz(T + "/liste.tsv", "demo-ana\t1\t1\tajan\tcalisiyor\t\t\t\nmenu-ana\t1\t1\tajan\tsoru\t\t\t" + SORU + "\n")
tmux("new-session", "-d", "-s", "demo-ana", "-x", "80", "-y", "24", "echo ISTEMCI-GORUR; sleep 600")
tmux("new-session", "-d", "-s", "menu-ana", "-x", "80", "-y", "24", "echo 'Devam?'; echo '1. a'; echo '2. b'; cat")
kopru = subprocess.Popen([sys.executable, KOPRU], env=ENV, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
for _ in range(50):
    if os.path.exists(T + "/k.sock"):
        break
    time.sleep(0.1)


def baslat(koltuk=None):   # None = ARGÜMANSIZ: ttyd-kisi komutu istemciyi böyle başlatır (ttyd her bağlantıda pty içinde bu komutu çalıştırır)
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.update(ENV); os.environ["TERM"] = "xterm"
        os.execv(sys.executable, [sys.executable, ISTEMCI] + ([koltuk] if koltuk else []))
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    return pid, fd


def oku(fd, sure=2.0):
    son, v = time.time() + sure, b""
    while time.time() < son:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                d = os.read(fd, 65536)
            except OSError:
                break
            if not d:
                break
            v += d
    return v.decode(errors="replace")


try:
    pid, fd = baslat("demo-ana")
    ekran = oku(fd, 3)
    ok("I1 koltuk ekranı + yardım satırı görünüyor", "ISTEMCI-GORUR" in ekran and "mesaj gönder" in ekran, repr(ekran)[:900])
    os.write(fd, b"zzz yy\r"); oku(fd, 0.6)
    ok("I2 tanımsız tuşlar atıldı (mesaj yolu çalışmadı)", not os.path.exists(T + "/mesaj.gelen"))
    ok("I3 tanımsız tuşlar koltuğa gitmedi", "zzz" not in tmux("capture-pane", "-p", "-t", "=demo-ana:").stdout)
    os.write(fd, b"1"); son1 = oku(fd, 1.5)
    ok("I3b soru yokken rakam → red + 'yazmak için m' ipucu; tekrar basınca ipucu yine görünür", "Yazmak için [m]" in son1 and "[q] çık" not in son1.split("Yazmak için [m]")[-1], repr(son1[-200:]))
    os.write(fd, b"1"); son1 = oku(fd, 1.5)
    ok("I3c ikinci red de aynı ipucunu basar", "Yazmak için [m]" in son1, repr(son1[-200:]))
    # I3d: kişi ekranı küçük bir başka istemci yüzünden daralmasın (window-size smallest + 60x20 rakip istemci → pencere 105 sütuna uymalı)
    tmux("set-option", "-g", "window-size", "smallest")
    rpid, rfd = pty.fork()
    if rpid == 0:
        os.environ.update(ENV); os.environ["TERM"] = "xterm"
        os.execvp("tmux", ["tmux", "attach-session", "-t", "=demo-ana"])
    fcntl.ioctl(rfd, termios.TIOCSWINSZ, struct.pack("HHHH", 20, 60, 0, 0)); oku(rfd, 0.8)
    q = tmux("display-message", "-p", "-t", "=demo-ana:", "#{window_width}").stdout.strip()
    bpid, bfd = pty.fork()
    if bpid == 0:
        os.environ.update(ENV); os.environ["TERM"] = "xterm"
        os.execv(sys.executable, [sys.executable, ISTEMCI, "demo-ana"])
    fcntl.ioctl(bfd, termios.TIOCSWINSZ, struct.pack("HHHH", 45, 105, 0, 0)); oku(bfd, 2.5)
    w = tmux("display-message", "-p", "-t", "=demo-ana:", "#{window_width}").stdout.strip()
    ok("I3d geniş kişi ekranı küçük rakip istemciyle daralmaz (pencere 105 sütun)", w == "105", "rakip tek başına=%s · kişi bağlanınca=%s" % (q, w))
    for _p, _f in ((bpid, bfd), (rpid, rfd)):
        os.write(_f, b"q") if _p == bpid else None
        try:
            os.kill(_p, 15); os.waitpid(_p, 0)
        except OSError:
            pass
    tmux("set-option", "-g", "window-size", "latest")
    os.write(fd, b"m"); oku(fd, 0.4); os.write(fd, "Selam ajan ş\r".encode()); son = oku(fd, 2.0)
    g = open(T + "/mesaj.gelen").read() if os.path.exists(T + "/mesaj.gelen") else None
    ok("I4 m + yazı + Enter → mesaj köprüden geçti", g is not None and g.strip() == "Selam ajan ş", g)
    ok("I5 durum satırı 'mesaj gönderildi'", "mesaj gönderildi" in son, son[-160:])
    os.write(fd, b"mvazgec\x1b"); oku(fd, 0.5); os.remove(T + "/mesaj.gelen")
    os.write(fd, b"\r"); oku(fd, 0.5)
    ok("I6 Esc ile vazgeçilen mesaj gitmedi", not os.path.exists(T + "/mesaj.gelen"))
    os.write(fd, b"q"); bitis = False
    for _ in range(30):
        r = os.waitpid(pid, os.WNOHANG)
        if r[0]:
            bitis = os.WEXITSTATUS(r[1]) == 0; break
        time.sleep(0.2)
    ok("I7 q ile temiz çıkış (rc 0)", bitis)
    pid, fd = baslat("menu-ana"); oku(fd, 1.5)
    os.write(fd, b"2"); oku(fd, 1.0); time.sleep(0.3)
    ok("I8 rakam → sunulan şık koltuğa gitti", any(l.strip() == "2" for l in tmux("capture-pane", "-p", "-t", "=menu-ana:").stdout.splitlines()))
    os.write(fd, b"q"); oku(fd, 0.5)
    pid, fd = baslat("yasak-ana"); ekran = oku(fd, 2.0)
    ok("I9 izinsiz koltukta kullanıcı dilinde ret", "erişimin yok" in ekran, ekran[-200:])
    os.write(fd, b"q"); oku(fd, 0.3)
    # ── ARGÜMANSIZ AÇILIŞ (HADH10 · 28 Eki canlı: ttyd-kisi komutu koltuk taşımıyor, merkez ?arg='yı kişi için 403 yapıyor →
    #    istemci 'kullanım' yazıp çıkıyor, ekran 'Press Enter to Reconnect' döngüsüne giriyordu; eski sınavlar hep argümanla başlattığı için görmedi)
    def bitti_mi(pid, sn=6):
        for _ in range(int(sn / 0.2)):
            r = os.waitpid(pid, os.WNOHANG)
            if r[0]:
                return os.WEXITSTATUS(r[1])
            time.sleep(0.2)
        return None
    pid, fd = baslat(); ekran = oku(fd, 2.5)
    ok("I10 argümansız + iki izinli koltuk → menü (kullanım yazıp ÇIKMAZ): iki koltuk adı + seçim satırı", "demo-ana" in ekran and "menu-ana" in ekran and "[1-2] seç" in ekran and "kullanım" not in ekran and os.waitpid(pid, os.WNOHANG)[0] == 0, repr(ekran)[:500])
    os.write(fd, b"z9"); ekran = oku(fd, 0.6)
    ok("I11 menüde geçersiz tuş (z · listede olmayan 9) atılır, menü yerinde kalır", os.waitpid(pid, os.WNOHANG)[0] == 0 and "ISTEMCI-GORUR" not in ekran, repr(ekran)[:200])
    os.write(fd, b"1"); ekran = oku(fd, 3)
    ok("I12 menüde 1 → ilk koltuğa (demo-ana) bağlandı, ekranı görünür", "ISTEMCI-GORUR" in ekran and "mesaj gönder" in ekran, repr(ekran)[:400])
    os.write(fd, b"q"); ok("I13 bağlandıktan sonra q temiz çıkış (rc 0)", bitti_mi(pid) == 0)
    pid, fd = baslat(); oku(fd, 1.5); os.write(fd, b"2"); ekran = oku(fd, 2.5)
    ok("I14 menüde 2 → ikinci koltuğa (menu-ana) bağlandı", "Devam?" in ekran, repr(ekran)[:300]); os.write(fd, b"q"); oku(fd, 0.4)
    pid, fd = baslat(); oku(fd, 1.5); os.write(fd, b"q")
    ok("I15 menüde q → çıkış rc 0 (koltuğa bağlanmadan)", bitti_mi(pid) == 0)
    LISTE_ESKI = open(T + "/liste.tsv").read()
    yaz(T + "/liste.tsv", "demo-ana\t1\t1\tajan\tcalisiyor\t\t\t\n")
    pid, fd = baslat(); ekran = oku(fd, 3)
    ok("I16 argümansız + TEK izinli koltuk → menüsüz, doğrudan o koltuğa bağlanır", "ISTEMCI-GORUR" in ekran and "Hangi koltuğa" not in ekran, repr(ekran)[:300]); os.write(fd, b"q"); oku(fd, 0.4)
    yaz(T + "/liste.tsv", "")
    pid, fd = baslat(); ekran = oku(fd, 2)
    ok("I17 argümansız + hiç koltuk yok → nedeni yazar, ÇIKMAZ (r/q bekler)", "açık koltuk görünmüyor" in ekran and os.waitpid(pid, os.WNOHANG)[0] == 0, repr(ekran)[:300])
    yaz(T + "/liste.tsv", "demo-ana\t1\t1\tajan\tcalisiyor\t\t\t\n"); os.write(fd, b"r"); ekran = oku(fd, 3)
    ok("I18 koltuk görününce r → yeniler ve doğrudan bağlanır", "ISTEMCI-GORUR" in ekran, repr(ekran)[:300]); os.write(fd, b"q"); oku(fd, 0.4)
    yaz(T + "/liste.tsv", LISTE_ESKI)
    pid, fd = baslat("demo-ana"); ekran = oku(fd, 2.5)
    ok("I19 koltuk adı VERİLİRSE eski yol aynen (menü yok)", "ISTEMCI-GORUR" in ekran and "Hangi koltuğa" not in ekran, repr(ekran)[:200]); os.write(fd, b"q"); oku(fd, 0.4)
finally:
    kopru.terminate(); tmux("kill-server"); shutil.rmtree(T, ignore_errors=True)
print("\n%d geçti, %d kaldı" % (sonuc["gecti"], sonuc["kaldi"])); sys.exit(1 if sonuc["kaldi"] else 0)
