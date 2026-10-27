#!/usr/bin/env python3
"""bosta-oturum-tarama.py — uzun süredir boş duran claude oturumlarını bulur; kapatmadan bir gün önce zil atar.

NİÇİN (gorev …T6YWE6, SERDAR kararı 26 Eki, Sultan onaylı): vekatip'te 11 claude ≈4,6 GiB, 9-11 gündür açık, takas dolu.
KURAL: eşik = 7 gün ve üstü boş + soru penceresi yok + Sultan-eşli koltuk listesi hariç; kapatmadan 1 gün önce zil.
NASIL: tmux window_activity = son çıktı/girdi anı. Hâl (soru bekliyor mu) filo.hal ile ekrandan okunur.
  taze      boş süre < ZIL_GUN (6)                          → dokunulmaz
  muaf      Sultan-eşli listede                              → dokunulmaz
  soru      ekranda soru penceresi var                       → dokunulmaz (cevap bekliyor, boşta değil)
  zil       boş ≥ ZIL_GUN, bu etkinlik için zil yok          → zil atılır (kapanışa ≥1 gün var), deftere yazılır
  bekle     zil atıldı ama 24 saat dolmadı                   → bekler
  kapat     boş ≥ ESIK_GUN + zil ≥ 24 saat önce + etkinlik değişmedi → kapatılabilir
KURU KOŞU varsayılan. --zil: zilleri gönderir. --kapat: 'kapat' sınıfını kapatır (zil ayrıca gerekmez, ama zilsiz kapatma YOK).
Zilden sonra oturumda herhangi bir etkinlik olursa (window_activity değişir) sayaç sıfırlanır: zil geçersiz.
rc: 0 tur tamam · 3 ölçülemedi (tmux yok/okunamadı; --kapat için muaf listesi yok/boş; --zil için zil kanalı yok) · 4 zil ya da kapatma eylemi başarısız.
KUTU BAĞIMSIZ (terminal-onar'a taşındı, T6YWE6): araç Nexus'a bağlı değildir. Muaf liste sırası: OT_MUAF → ~/.filo/sultan-esli-koltuklar.txt → Nexus kopyası (varsa).
Zil kanalı sırası: OT_NOTIFY → yanındaki aile-notify.sh → Nexus aile-notify.sh (varsa) → PATH'teki `ulak gonder <OTURUM-BÜYÜK>`. Hiçbiri yoksa --zil ölçülemedi der.
FAIL-CLOSED: muaf listesi bulunamaz ya da boşsa --kapat HİÇBİR ŞEY kapatmaz (Sultan-eşli oturumu yanlışlıkla kapatma riski).
Ortam (sınav dikişleri): OT_TMUX · OT_SIMDI · OT_ESIK_GUN · OT_ZIL_GUN · OT_ZIL_SAAT · OT_DEFTER · OT_MUAF · OT_NOTIFY · OT_FILO
"""
import argparse, fcntl, importlib.util, json, os, re, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
TMUX = os.environ.get("OT_TMUX") or "tmux"
ESIK_GUN = float(os.environ.get("OT_ESIK_GUN", "7"))
ZIL_GUN = float(os.environ.get("OT_ZIL_GUN", "6"))
ZIL_SAAT = float(os.environ.get("OT_ZIL_SAAT", "24"))
DEFTER = os.environ.get("OT_DEFTER") or os.path.expanduser("~/.filo/bosta-oturum-tarama.json")
NEXUS = os.environ.get("OT_NEXUS") or "/config/projects/Nexus"


def _ilk_var(*adaylar):
    """Var olan ilk dosya yolu; hiçbiri yoksa None."""
    for a in adaylar:
        if a and os.path.isfile(a):
            return a
    return None


MUAF = os.environ.get("OT_MUAF") or _ilk_var(os.path.expanduser("~/.filo/sultan-esli-koltuklar.txt"),
                                              os.path.join(NEXUS, "_agents", "handoff", "sultan-esli-koltuklar.txt"))
NOTIFY = os.environ.get("OT_NOTIFY") or _ilk_var(os.path.join(HERE, "aile-notify.sh"), os.path.join(NEXUS, "scripts", "aile-notify.sh"))
FILO = os.environ.get("OT_FILO") or _ilk_var(os.path.join(HERE, "filo.py"), os.path.join(NEXUS, "scripts", "filo.py")) or "/yok"
SORU_DESEN = re.compile(r"❯\s*1\.|\(y/n\)|Do you want|proceed\?|\[Y/n\]|Esc to cancel")


def simdi():
    return float(os.environ.get("OT_SIMDI") or time.time())


def muaf_oku():
    if not MUAF:
        return set()
    try:
        with open(MUAF, encoding="utf-8") as f:
            return {s.split("#")[0].strip().lower() for s in f if s.split("#")[0].strip()}
    except OSError:
        return set()


def panolar():
    """[(oturum, hedef, etkinlik_epoch)] — komut claude olanlar. None: tmux okunamadı."""
    try:
        r = subprocess.run([TMUX, "list-panes", "-a", "-F", "#{session_name}\t#{session_name}:#{window_index}.#{pane_index}\t#{window_activity}\t#{pane_current_command}"],
                           capture_output=True, text=True)
    except OSError:
        return None
    if r.returncode != 0:
        return None
    out = []
    for s in r.stdout.splitlines():
        p = s.split("\t")
        if len(p) == 4 and p[3] == "claude" and p[2].isdigit():
            out.append((p[0], p[1], int(p[2])))
    return out


def soru_var(hedef):
    try:
        r = subprocess.run([TMUX, "capture-pane", "-p", "-t", hedef], capture_output=True, text=True, errors="replace")
    except OSError:
        return None
    if r.returncode != 0:
        return None
    son = "\n".join([s for s in r.stdout.splitlines() if s.strip()][-14:])
    try:
        sp = importlib.util.spec_from_file_location("filo_ot", FILO)
        m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
        return m.hal(son.splitlines())[0] == "soru-bekliyor"
    except Exception:
        return bool(SORU_DESEN.search(son))


def defter_oku():
    try:
        with open(DEFTER, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def defter_yaz(d):
    os.makedirs(os.path.dirname(DEFTER), exist_ok=True)
    tmp = DEFTER + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
    os.replace(tmp, DEFTER)


def zil_kanali():
    """Zil komutu (liste) ya da None. Sıra: NOTIFY → PATH'teki ulak."""
    if NOTIFY:
        return [NOTIFY]
    u = shutil.which("ulak")
    return [u, "gonder"] if u else None


def zil_gonder(oturum, metin):
    k = zil_kanali()
    if not k:
        return False
    hedef = oturum if k == [NOTIFY] else oturum.upper()
    ek = [] if k == [NOTIFY] else ["--kimden", "TARAMA", "--onem", "normal"]
    return subprocess.run(k + [hedef, metin] + ek, stdin=subprocess.DEVNULL, capture_output=True).returncode == 0


def sinifla(oturum, hedef, etk, t, muaf, defter):
    gun = (t - etk) / 86400
    if oturum.lower() in muaf:
        return "muaf", gun
    if gun < ZIL_GUN:
        return "taze", gun
    q = soru_var(hedef)
    if q is None:
        return "olculemedi", gun
    if q:
        return "soru", gun
    z = defter.get(oturum)
    if not z or z.get("etkinlik") != etk:
        return "zil", gun
    if gun >= ESIK_GUN and (t - z["zil_ts"]) >= ZIL_SAAT * 3600:
        return "kapat", gun
    return "bekle", gun


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--zil", action="store_true", help="zil sınıfına gerçekten zil gönder")
    ap.add_argument("--kapat", action="store_true", help="kapat sınıfını gerçekten kapat")
    a = ap.parse_args()
    t = simdi()
    ps = panolar()
    if ps is None:
        print("ÖLÇÜLEMEDİ: tmux okunamadı", file=sys.stderr)
        return 3
    muaf = muaf_oku()
    if a.kapat and not muaf:
        print("ÖLÇÜLEMEDİ: muaf (Sultan-eşli) listesi yok ya da boş — --kapat hiçbir şey kapatmaz (OT_MUAF ya da ~/.filo/sultan-esli-koltuklar.txt)", file=sys.stderr)
        return 3
    if a.zil and not zil_kanali():
        print("ÖLÇÜLEMEDİ: zil kanalı yok (OT_NOTIFY / aile-notify.sh / PATH'te ulak) — --zil hiçbir şey göndermez", file=sys.stderr)
        return 3
    os.makedirs(os.path.dirname(DEFTER), exist_ok=True)
    with open(DEFTER + ".kilit", "w") as kf:
        fcntl.flock(kf, fcntl.LOCK_EX)
        defter = defter_oku()
        rc = 0
        for oturum, hedef, etk in sorted(ps, key=lambda x: x[2]):
            sinif, gun = sinifla(oturum, hedef, etk, t, muaf, defter)
            eylem = ""
            if sinif == "olculemedi":
                rc = 3
            if sinif == "zil":
                if a.zil:
                    ok = zil_gonder(oturum, f"[tarama] {oturum} oturumu {gun:.0f} gündür boş; yarın bu saatten sonra kapatılabilir. Kalacaksa bir şey yaz ya da Sultan-eşli listeye ekletin.")
                    if ok:
                        defter[oturum] = {"zil_ts": t, "etkinlik": etk}
                    eylem = "zil=gonderildi" if ok else "zil=BASARISIZ"
                    if not ok:
                        rc = rc or 4
                else:
                    eylem = "zil=gonderirdim"
            elif sinif == "kapat":
                if a.kapat:
                    ok = subprocess.run([TMUX, "kill-session", "-t", "=" + oturum], capture_output=True).returncode == 0
                    eylem = "kapatildi" if ok else "kapatma=BASARISIZ"
                    if not ok:
                        rc = rc or 4
                    if ok:
                        defter.pop(oturum, None)
                else:
                    eylem = "kapatirdim"
            print(f"{oturum:<16} bos={gun:.1f}g  {sinif:<10} {eylem}".rstrip())
        defter_yaz(defter)
    return rc


if __name__ == "__main__":
    sys.exit(main())
