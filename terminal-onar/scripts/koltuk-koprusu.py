#!/usr/bin/env python3
"""koltuk-koprusu.py — kısıtlı kişi (Ayşenur) için KOLTUK KÖPRÜSÜ (A5-1 · görev …A5Y3P · Sultan 26 Eki: "ham tuş yok, iki güvenli düğme").

NİÇİN: ayrı Linux kullanıcısı, ham tuş yazma yolu açıkken hiçbir şeyi korumaz (yazılabilir tmux istemcisi = `abc` kabuğu). Köprü `abc` olarak
  çalışır, kişi yalnız bu UNIX soketini görür. Kişi SALT-OKUR izler ve yalnız İKİ eylem yapabilir: (1) mesaj gönder (posta, izli),
  (2) koltuk bir menü sorusu bekliyorsa sunulan şıklardan birini seç. "Ham tuş" diye bir eylem protokolde YOKTUR.

PROTOKOL — satır başına bir JSON (UTF-8, satır en çok 16 KiB). İstemci → köprü:
  {"op":"liste"}                                  → {"t":"liste","koltuklar":[{"ad","hal","soru"}]}   (izinli ∩ görünür)
  {"op":"izle","koltuk":AD,"satir":N,"sutun":N}   → salt okur akış başlar: {"t":"cikti","b":<base64>} … · {"t":"bitti"}
  {"op":"boyut","satir":N,"sutun":N}              → izleme penceresini yeniden boyutlar
  {"op":"mesaj","metin":"…"}                      → {"t":"tamam","eylem":"mesaj","kimlik":…}
  {"op":"sik","no":N}                             → {"t":"tamam","eylem":"sik","no":N}
  başka her şey                                    → {"t":"ret","neden":"bilinmeyen-eylem"} (bağlantı DÜŞMEZ ama hiçbir şey yapılmaz)
KAPILAR (hepsi fail-closed, hepsi izlenir): (1) SO_PEERCRED uid ∈ KOPRU_IZIN_UID · (2) koltuk adı süzgeci (koltuk-adi.sh kuralının eşi) ·
  (3) koltuk izin listesinde (merkez-kisiler.json biçimi: kisiler[].kutular[KUTU]) · (4) koltuk şu an GÖRÜNÜR (koltuk-bagla.sh --liste).
Ortam: KOPRU_SOKET · KOPRU_IZIN_UID (virgüllü; boşsa KOPRU_KULLANICI='ayse' adının uid'i) · KOPRU_GRUP · KOPRU_KUTU · KOPRU_KISI ·
  KOPRU_IZIN_DOSYA · KOPRU_LISTE_KOMUT · KOPRU_MESAJ_KOMUT · KOPRU_IZ (jsonl) · KOPRU_TMUX · KOPRU_SIK_TUS ('{no}').
"""
import base64, fcntl, grp, json, os, pwd, pty, re, select, shlex, signal, socket, struct, subprocess, sys, termios, threading, time

SATIR_TAVAN = 16384
METIN_TAVAN = 2000
MESAJ_ARALIK = float(os.environ.get("KOPRU_MESAJ_ARALIK", "2"))
KOLTUK_DESEN = re.compile(r"^[^\x00-\x1f\x7f:.]{1,200}$")


def ortam(ad, varsayilan=""):
    return os.environ.get(ad, varsayilan)


def koltuk_adi_gecerli(ad):
    """koltuk-adi.sh kuralının eşi: 1-200 karakter · '.' ':' ve kontrol YOK · başta '$@%=' ve boşluk YOK · sonda boşluk YOK."""
    if not isinstance(ad, str) or not KOLTUK_DESEN.match(ad):
        return False
    if ad[0] in "$@%=" or ad[0].isspace() or ad[-1].isspace():
        return False
    return True


def izinli_uidler():
    ham = ortam("KOPRU_IZIN_UID").strip()
    if ham:
        try:
            return {int(x) for x in ham.split(",") if x.strip()}
        except ValueError:
            return set()
    try:
        return {pwd.getpwnam(ortam("KOPRU_KULLANICI", "ayse")).pw_uid}
    except KeyError:
        return set()   # kullanıcı yok → kimse giremez (fail-closed)


def eş_uid(baglanti):
    pid, uid, gid = struct.unpack("3i", baglanti.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i")))
    return uid


def iz_yaz(**alanlar):
    yol = ortam("KOPRU_IZ")
    if not yol:
        return
    alanlar["zaman"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    try:
        with open(yol, "a", encoding="utf-8") as f:
            f.write(json.dumps(alanlar, ensure_ascii=False) + "\n")
    except OSError:
        print("koprusu: iz yazılamadı", file=sys.stderr)   # eylem düşmez ama sessiz de geçmez


def izin_listesi():
    """izin dosyası (merkez-kisiler.json biçimi) → bu kişinin bu kutudaki koltuk kümesi. Okunamaz/bozuk/kişi yok → boş küme."""
    try:
        j = json.load(open(ortam("KOPRU_IZIN_DOSYA"), encoding="utf-8"))
    except Exception:
        return set()
    for k in j.get("kisiler", []) if isinstance(j, dict) else []:
        if isinstance(k, dict) and k.get("id") == ortam("KOPRU_KISI", "aysenur"):
            k_ = k.get("kutular", {})
            lst = k_.get(ortam("KOPRU_KUTU"), []) if isinstance(k_, dict) else []
            return {a for a in lst if isinstance(a, str) and koltuk_adi_gecerli(a)} if isinstance(lst, list) else set()
    return set()


def gorunur_koltuklar():
    """koltuk-bagla.sh --liste → {ad: {hal, soru}} · ölçülemezse None (boş liste DEĞİL)."""
    komut = ortam("KOPRU_LISTE_KOMUT")
    if not komut:
        return None
    try:
        p = subprocess.run(shlex.split(komut), capture_output=True, text=True, timeout=20)
    except Exception:
        return None
    if p.returncode != 0:
        return None
    cikti = {}
    for s in p.stdout.splitlines():
        c = s.split("\t")
        if len(c) >= 5 and c[0]:
            soru = None
            if len(c) >= 8 and c[7].strip():
                try:
                    soru = json.loads(c[7])
                except Exception:
                    soru = None
            cikti[c[0]] = {"hal": c[4], "soru": soru}
    return cikti


def izinli_gorunur():
    izin, gor = izin_listesi(), gorunur_koltuklar()
    if gor is None:
        return None
    return {a: v for a, v in gor.items() if a in izin}


def temizle_metin(m):
    if not isinstance(m, str):
        return ""
    m = m.replace("\r\n", "\n").replace("\r", "\n").replace("\t", " ")
    m = "".join(ch for ch in m if ch == "\n" or (ch >= " " and ch != "\x7f" and not (0x80 <= ord(ch) < 0xa0)))
    return m.strip()


class Oturum(threading.Thread):
    def __init__(self, baglanti, uid):
        super().__init__(daemon=True)
        self.b, self.uid, self.koltuk = baglanti, uid, None
        self.fd, self.cocuk, self.son_mesaj = None, None, 0.0
        self.kilit = threading.Lock()
        self.kisi = ortam("KOPRU_KISI", "aysenur")

    def gonder(self, nesne):
        veri = (json.dumps(nesne, ensure_ascii=False) + "\n").encode()
        with self.kilit:
            try:
                self.b.sendall(veri)
            except OSError:
                pass

    def ret(self, neden, op=""):
        iz_yaz(kisi=self.kisi, uid=self.uid, op=op, koltuk=self.koltuk, sonuc="ret", neden=neden)
        self.gonder({"t": "ret", "neden": neden})

    def pencere(self, satir, sutun):
        if self.fd is not None:
            fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", satir, sutun, 0, 0))
            if self.cocuk:
                try:
                    os.kill(self.cocuk, signal.SIGWINCH)
                except OSError:
                    pass

    def izle(self, o):
        if self.cocuk:
            return self.ret("zaten-izleniyor", "izle")
        ad = o.get("koltuk")
        if not koltuk_adi_gecerli(ad):
            return self.ret("koltuk-adi-gecersiz", "izle")
        iz = izinli_gorunur()
        if iz is None:
            return self.ret("koltuklar-olculemedi", "izle")
        if ad not in iz:
            return self.ret("koltuk-izinli-degil", "izle")
        satir, sutun = int(o.get("satir") or 24), int(o.get("sutun") or 80)
        satir, sutun = max(2, min(satir, 500)), max(10, min(sutun, 1000))
        self.koltuk = ad
        pid, fd = pty.fork()
        if pid == 0:   # çocuk: SALT OKUR tmux istemcisi (-r) · girdi asla ona yazılmaz
            try:
                fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", satir, sutun, 0, 0))
                os.environ["TERM"] = "xterm-256color"
                os.environ.pop("TMUX", None)   # başka bir tmux içinden başlatılsa da hedef sunucu TMUX_TMPDIR/varsayılan olsun
                os.execvp(ortam("KOPRU_TMUX", "tmux"), [ortam("KOPRU_TMUX", "tmux"), "attach-session", "-r", "-t", "=" + ad])
            finally:
                os._exit(127)
        self.cocuk, self.fd = pid, fd
        self.pencere(satir, sutun)
        iz_yaz(kisi=self.kisi, uid=self.uid, op="izle", koltuk=ad, sonuc="tamam")
        threading.Thread(target=self.akit, daemon=True).start()

    def akit(self):
        while True:
            try:
                r, _, _ = select.select([self.fd], [], [], 1.0)
                if r:
                    v = os.read(self.fd, 65536)
                    if not v:
                        break
                    self.gonder({"t": "cikti", "b": base64.b64encode(v).decode()})
            except OSError:
                break
        self.gonder({"t": "bitti"})

    def mesaj(self, o):
        if not self.koltuk:
            return self.ret("once-izle", "mesaj")
        simdi = time.monotonic()
        if simdi - self.son_mesaj < MESAJ_ARALIK:
            return self.ret("cok-sik", "mesaj")
        metin = temizle_metin(o.get("metin"))
        if not metin or len(metin) > METIN_TAVAN:
            return self.ret("metin-bos-ya-da-uzun", "mesaj")
        komut = ortam("KOPRU_MESAJ_KOMUT")
        if not komut:
            return self.ret("mesaj-yolu-yok", "mesaj")
        if self.koltuk not in (izinli_gorunur() or {}):   # izin her eylemde yeniden bakılır (liste izleme sırasında daralmış olabilir)
            return self.ret("koltuk-izinli-degil", "mesaj")
        self.son_mesaj = simdi
        try:
            p = subprocess.run(shlex.split(komut) + [self.koltuk, self.kisi], input=metin, capture_output=True, text=True, timeout=20)
        except Exception:
            return self.ret("mesaj-komutu-calismadi", "mesaj")
        if p.returncode != 0:
            return self.ret("mesaj-komutu-rc%d" % p.returncode, "mesaj")
        kimlik = p.stdout.strip().splitlines()[-1] if p.stdout.strip() else ""
        iz_yaz(kisi=self.kisi, uid=self.uid, op="mesaj", koltuk=self.koltuk, sonuc="tamam", uzunluk=len(metin), kimlik=kimlik)
        self.gonder({"t": "tamam", "eylem": "mesaj", "kimlik": kimlik})

    def sik(self, o):
        if not self.koltuk:
            return self.ret("once-izle", "sik")
        no = o.get("no")
        if not isinstance(no, int) or isinstance(no, bool):
            return self.ret("sik-gecersiz", "sik")
        iz = izinli_gorunur()
        k = (iz or {}).get(self.koltuk)
        soru = k and k.get("soru")
        if not k or k.get("hal") != "soru" or not isinstance(soru, dict) or soru.get("tur") != "menu":
            return self.ret("menu-sorusu-yok", "sik")
        sunulan = {s.get("no") for s in soru.get("siklar", []) if isinstance(s, dict)}
        if no not in sunulan:
            return self.ret("sik-sunulmadi", "sik")   # sunulmayan şık YOK
        tus = ortam("KOPRU_SIK_TUS", "{no}").replace("{no}", str(no))
        p = subprocess.run([ortam("KOPRU_TMUX", "tmux"), "send-keys", "-t", "=" + self.koltuk + ":", tus], capture_output=True, text=True, timeout=10, env={k: v for k, v in os.environ.items() if k != "TMUX"})
        if p.returncode != 0:
            return self.ret("tus-gonderilemedi", "sik")
        iz_yaz(kisi=self.kisi, uid=self.uid, op="sik", koltuk=self.koltuk, sonuc="tamam", no=no)
        self.gonder({"t": "tamam", "eylem": "sik", "no": no})

    def liste(self):
        iz = izinli_gorunur()
        if iz is None:
            return self.ret("koltuklar-olculemedi", "liste")
        self.gonder({"t": "liste", "koltuklar": [{"ad": a, "hal": v["hal"], "soru": v["soru"]} for a, v in sorted(iz.items())]})

    def run(self):
        tampon = b""
        try:
            while True:
                v = self.b.recv(4096)
                if not v:
                    break
                tampon += v
                while b"\n" in tampon:
                    satir, tampon = tampon.split(b"\n", 1)
                    self.isle(satir)
                if len(tampon) > SATIR_TAVAN:
                    self.ret("satir-cok-uzun")
                    break
        except OSError:
            pass
        finally:
            self.kapat()

    def isle(self, satir):
        if len(satir) > SATIR_TAVAN:
            return self.ret("satir-cok-uzun")
        try:
            o = json.loads(satir.decode("utf-8"))
        except Exception:
            return self.ret("json-degil")
        if not isinstance(o, dict):
            return self.ret("json-degil")
        op = o.get("op")
        if op == "liste":
            self.liste()
        elif op == "izle":
            self.izle(o)
        elif op == "boyut" and self.cocuk:
            try:
                self.pencere(max(2, min(int(o.get("satir")), 500)), max(10, min(int(o.get("sutun")), 1000)))
            except (TypeError, ValueError):
                self.ret("boyut-gecersiz", "boyut")
        elif op == "mesaj":
            self.mesaj(o)
        elif op == "sik":
            self.sik(o)
        else:
            self.ret("bilinmeyen-eylem", str(op)[:20])

    def kapat(self):
        if self.cocuk:
            try:
                os.kill(self.cocuk, signal.SIGHUP)
                os.waitpid(self.cocuk, 0)
            except OSError:
                pass
            self.cocuk = None
        if self.fd is not None:
            try:
                os.close(self.fd)
            except OSError:
                pass
            self.fd = None
        try:
            self.b.close()
        except OSError:
            pass


def dinle(yol):
    if os.path.exists(yol):
        t = socket.socket(socket.AF_UNIX)
        try:
            t.connect(yol)
            raise SystemExit("koprusu: soketi başka bir köprü dinliyor: " + yol)
        except OSError:
            os.unlink(yol)   # bayat soket
        finally:
            t.close()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    eski = os.umask(0o117)   # 0660
    try:
        s.bind(yol)
    finally:
        os.umask(eski)
    grup = ortam("KOPRU_GRUP")
    if grup:
        os.chown(yol, -1, grp.getgrnam(grup).gr_gid)
    s.listen(8)
    return s


def ana():
    yol = ortam("KOPRU_SOKET")
    if not yol:
        raise SystemExit("koprusu: KOPRU_SOKET verilmedi")
    s = dinle(yol)
    print("koprusu: dinliyor " + yol, flush=True)
    while True:
        b, _ = s.accept()
        try:
            uid = eş_uid(b)
        except OSError:
            b.close()
            continue
        if uid not in izinli_uidler():
            iz_yaz(kisi="?", uid=uid, op="baglan", sonuc="ret", neden="uid-izinli-degil")
            try:
                b.sendall(b'{"t":"ret","neden":"kimlik"}\n')
            except OSError:
                pass
            b.close()
            continue
        Oturum(b, uid).start()


if __name__ == "__main__":
    ana()
