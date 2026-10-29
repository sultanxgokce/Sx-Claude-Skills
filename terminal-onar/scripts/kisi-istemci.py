#!/usr/bin/env python3
"""kisi-istemci.py — kısıtlı kişinin (ayse) terminali: koltuk-köprüsü istemcisi (A5-1). ttyd-kisi'nin SABİT komutu; kabuk YOK.

Kullanım: kisi-istemci.py [<koltuk>]    (köprü soketi: KOPRU_SOKET, vars. /run/kisi/koprusu.sock)
Koltuk ADI VERİLMEZSE (ttyd-kisi komutu böyle başlatır; merkez kişi için ?arg='yı bilerek reddeder) köprüden izinli koltuklar listelenir:
  tek koltuk → doğrudan ona bağlanır · birden çok → 1-9 ile seçilir (r yeniler, q çıkar) · hiç yoksa nedeni yazar ve r/q bekler.
  Koltuk adı URL'den ALINMAZ: seçim yalnız köprünün kendi (izinli ∩ görünür) listesinden gelir — saldırı yüzeyi açılmaz.
Ekran koltuğu SALT OKUR gösterir (alt satır hariç). Tuşlar yalnız burada yorumlanır, köprüye ham tuş GİTMEZ:
  m  → mesaj yaz (Enter gönderir · Esc vazgeçer)      1-9 → koltuk menü sorusu bekliyorsa o şıkkı seç      q → çık
Başka her tuş atılır. (Güvenlik köprüdedir; bu istemci yalnız kullanım kolaylığı: köprü zaten başka eylem tanımaz.)
"""
import base64, fcntl, json, os, select, signal, socket, struct, sys, termios, tty

YOL = os.environ.get("KOPRU_SOKET", "/run/kisi/koprusu.sock")
NEDEN = {"kimlik": "Bu hesap bu ekrana giremez.", "koltuk-izinli-degil": "Bu koltuğa erişimin yok.", "koltuk-adi-gecersiz": "Koltuk adı geçersiz.",
         "koltuklar-olculemedi": "Koltuk listesi şu an okunamadı; biraz sonra dene.", "cok-sik": "Çok sık mesaj; birkaç saniye bekle.",
         "metin-bos-ya-da-uzun": "Mesaj boş ya da 2000 karakterden uzun.", "menu-sorusu-yok": "Seçilecek soru yok. Yazmak için [m] tuşuna bas.",
         "sik-sunulmadi": "Bu şık sunulmuyor.", "mesaj-yolu-yok": "Mesaj yolu bu kutuda kurulu değil.", "once-izle": "Önce bir koltuk aç."}


def boyut():
    try:
        s, c, _, _ = struct.unpack("HHHH", fcntl.ioctl(1, termios.TIOCGWINSZ, b"\0" * 8))
        return max(s, 3), max(c, 20)
    except OSError:
        return 24, 80


HAL = {"calisiyor": "çalışıyor", "soru": "soru bekliyor", "bos": "boşta"}


class Istemci:
    def __init__(self, koltuk):
        self.koltuk, self.durum, self.yaziyor, self.tampon, self.gelen = koltuk, "", None, "", b""
        self.ret = False   # son durum bir RED ise alt satır genel kısayol şeridi yerine yalnız red + ipucunu gösterir
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(YOL)

    def yolla(self, **o):
        self.s.sendall((json.dumps(o) + "\n").encode())

    def alt_satir(self):
        satir, sutun = boyut()
        if self.yaziyor is not None:
            metin = "Mesaj: " + self.yaziyor + "▌   (Enter gönder · Esc vazgeç)"
        else:
            metin = self.durum if self.ret else (self.durum + " · " if self.durum else "") + "[m] mesaj gönder · [1-9] şık seç · [q] çık"
        sys.stdout.write("\x1b7\x1b[%d;1H\x1b[2K\x1b[7m%s\x1b[0m\x1b8" % (satir, metin[: sutun - 1]))
        sys.stdout.flush()

    def tus(self, ch):
        self.ret = False
        if self.yaziyor is not None:
            if ch in ("\r", "\n"):
                metin, self.yaziyor = self.yaziyor, None
                if metin.strip():
                    self.yolla(op="mesaj", metin=metin)
                    self.durum = "gönderiliyor…"
            elif ch == "\x1b":
                self.yaziyor = None
            elif ch in ("\x7f", "\b"):
                self.yaziyor = self.yaziyor[:-1]
            elif ch >= " " and len(self.yaziyor) < 2000:
                self.yaziyor += ch
        elif ch == "m":
            self.yaziyor, self.durum = "", ""
        elif ch in "123456789":
            self.yolla(op="sik", no=int(ch)); self.durum = "şık gönderiliyor…"
        elif ch in ("q", "\x03"):
            return False
        self.alt_satir()
        return True

    def mesaj(self, m):
        t = m.get("t")
        if t == "cikti":
            sys.stdout.buffer.write(base64.b64decode(m["b"])); sys.stdout.flush(); self.alt_satir()
        elif t == "tamam":
            self.durum = "mesaj gönderildi" if m.get("eylem") == "mesaj" else "şık %s seçildi" % m.get("no"); self.alt_satir()
        elif t == "ret":
            self.durum, self.ret = NEDEN.get(m.get("neden"), "reddedildi: %s" % m.get("neden")), True; self.alt_satir()
        elif t == "bitti":
            return False
        return True

    def liste_al(self):
        """Köprüden izinli koltuk listesi: (koltuklar, None) ya da (None, kullanıcı dilinde neden)."""
        self.yolla(op="liste")
        while b"\n" not in self.gelen:
            v = self.s.recv(65536)
            if not v:
                return None, "Köprü bağlantıyı kapattı."
            self.gelen += v
        l, self.gelen = self.gelen.split(b"\n", 1)
        m = json.loads(l)
        if m.get("t") == "liste":
            return list(m.get("koltuklar") or []), None
        return None, NEDEN.get(m.get("neden"), "Koltuk listesi alınamadı (%s)." % m.get("neden"))

    def tek_tus(self):
        v = os.read(0, 16)
        return v.decode("utf-8", "ignore")[:1] if v else None

    def menu(self):
        """Argümansız açılış: izinli koltuğu seç. Seçilen koltuk adını ya da None (çıkış) döner."""
        eski = termios.tcgetattr(0) if os.isatty(0) else None
        try:
            if eski:
                tty.setraw(0)
            while True:
                kl, neden = self.liste_al()
                sys.stdout.write("\x1b[2J\x1b[H")
                if kl is None:
                    sys.stdout.write("%s\r\n\r\n[r] yeniden dene · [q] çık\r\n" % neden)
                elif not kl:
                    sys.stdout.write("Bu hesaba şu an açık koltuk görünmüyor.\r\n\r\n[r] yenile · [q] çık\r\n")
                elif len(kl) == 1:
                    return kl[0]["ad"]
                else:
                    sys.stdout.write("Hangi koltuğa bağlanalım?\r\n\r\n")
                    for i, k in enumerate(kl[:9], 1):
                        sys.stdout.write("  %d  %s  (%s)\r\n" % (i, k["ad"], HAL.get(k.get("hal"), k.get("hal") or "?")))
                    sys.stdout.write("\r\n[1-%d] seç · [r] yenile · [q] çık\r\n" % min(len(kl), 9))
                sys.stdout.flush()
                while True:
                    ch = self.tek_tus()
                    if ch is None or ch in ("q", "\x03"):
                        return None
                    if ch == "r":
                        break
                    if kl and ch in "123456789" and int(ch) <= min(len(kl), 9):
                        return kl[int(ch) - 1]["ad"]
        finally:
            if eski:
                termios.tcsetattr(0, termios.TCSADRAIN, eski)

    def calis(self):
        satir, sutun = boyut()
        self.yolla(op="izle", koltuk=self.koltuk, satir=satir - 1, sutun=sutun)
        signal.signal(signal.SIGWINCH, lambda *_: (lambda b: self.yolla(op="boyut", satir=b[0] - 1, sutun=b[1]))(boyut()))
        eski = termios.tcgetattr(0) if os.isatty(0) else None
        try:
            if eski:
                tty.setraw(0)
            sys.stdout.write("\x1b[2J\x1b[H"); self.alt_satir()
            dev = True
            while dev:
                try:
                    r, _, _ = select.select([0, self.s], [], [], 5)
                except InterruptedError:
                    continue
                if self.s in r:
                    v = self.s.recv(65536)
                    if not v:
                        break
                    self.gelen += v
                    while b"\n" in self.gelen and dev:
                        l, self.gelen = self.gelen.split(b"\n", 1)
                        dev = self.mesaj(json.loads(l))
                if 0 in r and dev:
                    v = os.read(0, 4096)
                    if not v:
                        break
                    for ch in v.decode("utf-8", "ignore"):
                        if not self.tus(ch):
                            dev = False
                            break
        finally:
            if eski:
                termios.tcsetattr(0, termios.TCSADRAIN, eski)
            sys.stdout.write("\x1b[0m\r\n"); sys.stdout.flush()


if __name__ == "__main__":
    if len(sys.argv) > 2:
        sys.exit("kullanım: kisi-istemci.py [<koltuk>]")
    try:
        ist = Istemci(sys.argv[1] if len(sys.argv) == 2 else None)
        if ist.koltuk is None:
            ist.koltuk = ist.menu()
        if ist.koltuk is not None:
            ist.calis()
    except OSError as e:
        sys.exit("Köprüye bağlanılamadı (%s). Biraz sonra yeniden dene." % e.strerror)
