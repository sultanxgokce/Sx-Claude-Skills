#!/config/.local-py/python/bin/python
"""enabiz-erisim — e-Nabız'a e-Devlet ile headless giriş, PDF + WADO görüntü indirme.

Komutlar: doctor · login [--otp KOD] · liste --out F · indir --liste F --out D ·
          goruntu --out D [--acc ACC] [--dicom] · dedupe --indir D --mevcut D --out F
Sır: EDEVLET_TC / EDEVLET_SIFRE ortamdan (vault-cek get … → ~/.config/cortex-access.env). Değer basılmaz.
"""
import argparse, base64, json, os, re, sys, time, threading, queue

HOME = os.environ.get("HOME", "/config")
ENV_FILE = os.path.join(HOME, ".config", "cortex-access.env")
FONTCONF = "/config/.config/fontconfig/fonts.conf"
STATE = os.environ.get("ENABIZ_STATE", os.path.join(os.getcwd(), "enabiz-state.json"))
B = "https://enabiz.gov.tr"
TELE = "https://teleradyoloji.saglik.gov.tr/viewerbackend/viewerapi"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36"


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def env_yukle():
    if os.path.exists(ENV_FILE):
        for ln in open(ENV_FILE):
            ln = ln.strip()
            ln = ln[7:] if ln.startswith("export ") else ln
            if ln and not ln.startswith("#") and "=" in ln:
                k, v = ln.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"'))
    os.environ.setdefault("FONTCONFIG_FILE", FONTCONF)


def kimlik():
    tc, sf = os.environ.get("EDEVLET_TC"), os.environ.get("EDEVLET_SIFRE")
    if not tc or not sf:
        log("✗ kimlik yok — kasaya koy (değer gizli):")
        log("  read -rsp 'TC: ' v; echo; printf '%s' \"$v\" | bash /config/.claude/skills/vault-cek/scripts/vault-cek.sh put EDEVLET_TC --tenant nexus --stdin; unset v")
        log("  (aynısı EDEVLET_SIFRE için) → sonra: vault-cek get EDEVLET_TC / EDEVLET_SIFRE")
        sys.exit(2)
    log(f"✓ kimlik ortamda (TC {len(tc)} krk, şifre {len(sf)} krk)")
    return tc, sf


def iso(t):
    d, m, y = t.strip().split(".")
    return f"{y}-{m}-{d}"


def fontconfig_kur():
    if os.path.exists(FONTCONF):
        return True
    os.makedirs(os.path.dirname(FONTCONF) + "/cache", exist_ok=True)
    fd = "/config/.local/share/fonts"
    os.makedirs(fd, exist_ok=True)
    if not any(f.endswith(".ttf") for f in os.listdir(fd)):
        log("⚠ font yok: /config/.local/share/fonts içine bir DejaVu*.ttf koy (Chromium web-font çökmesini önler)")
    open(FONTCONF, "w").write(
        '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>'
        f'<dir>{fd}</dir><cachedir>{os.path.dirname(FONTCONF)}/cache</cachedir>'
        '<alias><family>sans-serif</family><prefer><family>DejaVu Sans</family></prefer></alias>'
        '<alias><family>serif</family><prefer><family>DejaVu Serif</family></prefer></alias></fontconfig>')
    return True


def tarayici(p, state=None):
    b = p.chromium.launch(headless=True, args=["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"])
    kw = dict(locale="tr-TR", user_agent=UA, viewport={"width": 1400, "height": 1000})
    if state and os.path.exists(state):
        kw["storage_state"] = state
    ctx = b.new_context(**kw)
    ctx.set_default_timeout(30000)
    return b, ctx


def oturum_acik(page):
    page.goto(B + "/Home/Index", wait_until="domcontentloaded")
    time.sleep(1.5)
    return "/Account/Login" not in page.url


def cmd_login(args):
    env_yukle()
    tc, sf = kimlik()
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b, ctx = tarayici(p)
        page = ctx.new_page()
        page.goto(B + "/Account/Login?_st=1", wait_until="domcontentloaded")
        time.sleep(2)
        page.locator("button.edevletGirisBtn").first.click()
        page.wait_for_url(re.compile(r"giris\.turkiye\.gov\.tr"), timeout=30000)
        page.fill("#tridField", tc)
        page.fill("#egpField", sf)
        page.locator("form input[type=submit], form button[type=submit]").first.click()
        time.sleep(3)
        body = page.inner_text("body")
        if "Onayla" not in body and re.search(r"(SMS|doğrulama kodu|Kod)", body, re.I):
            if not args.otp:
                log("✗ e-Devlet SMS kodu istiyor — telefondaki kodu al ve tekrar çalıştır: login --otp KOD")
                sys.exit(3)
            page.locator("input[type=number], input[type=text], input[type=tel]").first.fill(args.otp)
            page.locator("form input[type=submit], form button[type=submit]").first.click()
            time.sleep(3)
        if "Onayla" in page.inner_text("body"):
            page.get_by_role("button", name="Onayla").or_(page.locator("input[value=Onayla]")).first.click()
        page.wait_for_url(re.compile(r"enabiz\.gov\.tr/Home"), timeout=30000)
        ctx.storage_state(path=STATE)
        os.chmod(STATE, 0o600)
        log(f"✓ giriş tamam → {STATE} (oturum ~30 dk)")
        b.close()


def _sayfa_ve_ctx(p):
    b, ctx = tarayici(p, STATE)
    page = ctx.new_page()
    if not oturum_acik(page):
        log("⚠ oturum düşmüş — login yapılıyor")
        b.close()
        cmd_login(argparse.Namespace(otp=None))
        b, ctx = tarayici(p, STATE)
        page = ctx.new_page()
        oturum_acik(page)
    return b, ctx, page


def tam_aralik(page, fn):
    opts = [o.get_attribute("value") for o in page.locator("#baslangicyilSelect option").all() if o.get_attribute("value")]
    page.select_option("#baslangicyilSelect", opts[-1])
    page.evaluate(fn + "()")
    time.sleep(4)
    page.evaluate("()=>{try{$.fn.dataTable.tables({api:true}).page.len(-1).draw()}catch(e){}}")


def cmd_liste(args):
    env_yukle()
    from playwright.sync_api import sync_playwright
    out = {}
    with sync_playwright() as p:
        b, ctx, page = _sayfa_ve_ctx(p)
        page.goto(B + "/Home/Tahlillerim", wait_until="domcontentloaded"); time.sleep(2)
        tam_aralik(page, "GetTahlilByDateList") if page.evaluate("()=>typeof GetTahlilByDateList==='function'") else None
        kart = []
        for a in page.locator("a[onclick*=TahlillerPdfIndir]").all():
            m = re.search(r"TahlillerPdfIndir\('tr-TR',\s*'(.*?)',\s*'(.*?)'", a.get_attribute("onclick") or "")
            if m:
                box = a.locator("xpath=ancestor::*[contains(@class,'accordion-item') or contains(@class,'card')][1]")
                hosp = box.locator(".hastaneAdi").first.inner_text() if box.locator(".hastaneAdi").count() else ""
                kart.append({"tarih": m.group(1), "kurumKodu": m.group(2), "hastane": hosp.strip()})
        out["tahlil"] = kart
        page.goto(B + "/Home/Raporlarim", wait_until="domcontentloaded"); time.sleep(2)
        tam_aralik(page, "GetRaporByDateList")
        rows = []
        for tr in page.locator("#raporlarTbody tr").all():
            tds = [t.inner_text().strip() for t in tr.locator("td").all()]
            oc = tr.locator("a[onclick*=RaporPdf]")
            pid = re.search(r"RaporPdf\('(.*?)'", oc.first.get_attribute("onclick")).group(1) if oc.count() else None
            if len(tds) >= 7:
                rows.append({"tarih": tds[0], "raporNo": tds[1], "takipNo": tds[2], "tur": tds[3], "tani": tds[6], "pdfId": pid})
        out["rapor"] = rows
        for ad, path, fn in [("patoloji", "/Home/Patolojilerim", "GetPatolojiByDateList"), ("epikriz", "/Home/Epikrizlerim", "GetEpikrizByDateList")]:
            page.goto(B + path, wait_until="domcontentloaded"); time.sleep(2)
            tam_aralik(page, fn)
            rows = []
            for tr in page.locator("table tbody tr").all():
                tds = [t.inner_text().strip() for t in tr.locator("td").all()]
                bt = tr.locator("button[onclick*=PDFGetir]")
                if bt.count() and len(tds) >= 5:
                    m = re.search(r"PDFGetir\('(.*?)',\s*'(.*?)'", bt.first.get_attribute("onclick"))
                    rows.append({"tarih": tds[0], "ref": tds[1], "hastane": tds[2], "klinik": tds[3], "hekim": tds[4], "sysNo": m.group(1), "referansNo": m.group(2)})
            out[ad] = rows
        page.goto(B + "/Home/RadyolojikGoruntulerim", wait_until="domcontentloaded"); time.sleep(3)
        page.locator("a:has-text('Liste Görünümü'), button:has-text('Liste Görünümü')").first.click(); time.sleep(1)
        opts = [o.get_attribute("value") for o in page.locator("#baslangicyilSelect option").all() if o.get_attribute("value")]
        page.select_option("#baslangicyilSelect", opts[-1]); page.evaluate("RadyolojiApp.getListByDate()"); time.sleep(5)
        cards = []
        for c in page.locator(".card-flex").all():
            def tx(sel):
                l = c.locator(sel); return l.first.inner_text().strip() if l.count() else ""
            rap = c.locator("button[onclick*=showHtmlReport]"); img = c.locator("button[onclick*=openImageLink]")
            cards.append({"tarih": tx(".Rtarih span"), "hastane": tx(".RhastaneAdi"), "aciklama": tx(".Raciklama").replace("Açıklama :", "").strip(),
                          "orderId": re.search(r"\('(.*?)'", rap.first.get_attribute("onclick")).group(1) if rap.count() else None,
                          "accession": re.search(r"\('(.*?)'", img.first.get_attribute("onclick")).group(1) if img.count() else None})
        out["radyoloji"] = cards
        out["_verifToken"] = page.locator("input[name=__RequestVerificationToken]").first.input_value()
        ctx.storage_state(path=STATE)
        b.close()
    json.dump(out, open(args.out, "w"), ensure_ascii=False, indent=1)
    log("✓ liste:", {k: len(v) for k, v in out.items() if isinstance(v, list)}, "→", args.out)


def _requests_session():
    import requests
    st = json.load(open(STATE))
    s = requests.Session()
    s.headers["User-Agent"] = UA
    for c in st["cookies"]:
        s.cookies.set(c["name"], c["value"], domain=c["domain"], path=c["path"])
    return s


def _pdf_yaz(path, body):
    if body[:4] != b"%PDF":
        log("  ✗ PDF değil:", os.path.basename(path)); return False
    open(path, "wb").write(body); return True


def cmd_indir(args):
    env_yukle()
    L = json.load(open(args.liste)); s = _requests_session(); meta = []
    hdr = {"RequestVerificationToken": L.get("_verifToken", ""), "X-Requested-With": "XMLHttpRequest"}
    for k in ("tahlil", "rapor", "patoloji", "epikriz", "radyoloji"):
        os.makedirs(os.path.join(args.out, k), exist_ok=True)
    def kaydet(kat, ad, body, m):
        p = os.path.join(args.out, kat, ad)
        if os.path.exists(p) or _pdf_yaz(p, body):
            meta.append(m | {"kategori": kat, "dosya": ad})
    for c in L["tahlil"]:
        r = s.get(B + "/Tahlil/TahlillerPdf", params={"baslangicYil": "2014", "bitisYil": "2030", "cardTarih": c["tarih"], "kurumKodu": c["kurumKodu"], "dil": "tr-TR", "sonucTuru": "null"}, timeout=90)
        kaydet("tahlil", f"{iso(c['tarih'])}_tahlil_{c['kurumKodu']}.pdf", r.content, {"tarih": iso(c["tarih"]), "hastane": c["hastane"]})
    for c in L["rapor"]:
        if c["pdfId"]:
            r = s.get(B + "/Rapor/RaporPdf", params={"raporTakipNo": c["pdfId"]}, timeout=90)
            kaydet("rapor", f"{iso(c['tarih'])}_ilacraporu_{c['pdfId']}.pdf", r.content, {"tarih": iso(c["tarih"]), "tur": c["tur"], "tani": c["tani"]})
    for kat, yol in (("patoloji", "/Patoloji/GetPatolojiPdf"), ("epikriz", "/Epikriz/GetEpikrizPdf")):
        for c in L[kat]:
            r = s.get(B + yol, params={"referansNo": c["referansNo"], "sysNo": c["sysNo"]}, timeout=90)
            kaydet(kat, f"{iso(c['tarih'])}_{kat}_{re.sub(r'[^0-9A-Za-z]', '', c['referansNo'])}.pdf", r.content, {k: c[k] for k in ("hastane", "klinik", "hekim")} | {"tarih": iso(c["tarih"])})
    for i, c in enumerate(L["radyoloji"]):
        if not c["orderId"]:
            continue
        r = s.get(B + "/RadyolojikGoruntu/GetRaporPdfByOrder", params={"orderId": c["orderId"]}, headers=hdr, timeout=90)
        try:
            b64 = r.json().get("rapor") or ""
        except Exception:
            log("  ✗ radyoloji JSON değil", c["tarih"]); continue
        if len(b64) < 100:
            continue
        slug = re.sub(r"[^0-9A-Za-z]+", "-", c["aciklama"])[:40].strip("-")
        kaydet("radyoloji", f"{iso(c['tarih'])}_radyoloji_{i:02d}_{slug}.pdf", base64.b64decode(b64), {"tarih": iso(c["tarih"]), "hastane": c["hastane"], "aciklama": c["aciklama"], "accession": c["accession"]})
    json.dump(meta, open(os.path.join(args.out, "meta.json"), "w"), ensure_ascii=False, indent=1)
    log(f"✓ {len(meta)} PDF → {args.out}")


def _teletip_token(s, verif, acc):
    import requests
    r = s.get(B + "/RadyolojikGoruntu/GetGoruntuLinkByOrder", params={"AccessionNumber": acc}, headers={"RequestVerificationToken": verif, "X-Requested-With": "XMLHttpRequest"}, timeout=60)
    m = re.search(r"otac=([^&\s\"]+)", r.text)
    if not m:
        raise SystemExit("✗ otac alınamadı (oturum düşmüş olabilir)")
    otac = m.group(1)
    tok = requests.post(TELE + "/CheckOTAC", params={"otac": otac}, timeout=60).json()["ResponseValue"]["AccessToken"]
    # WADO yetkisi ancak iş-öğesi yüklendikten sonra tanınır (aksi hâlde 401 "Yetkisiz Erişim")
    requests.get(TELE + "/LoadWorkItemForENabiz", params={"otac": otac}, headers={"Authorization": tok}, timeout=120)
    return tok, otac


def cmd_goruntu(args):
    import requests
    env_yukle()
    L = json.load(open(args.liste)); s = _requests_session()
    acc0 = args.acc or next(c["accession"] for c in L["radyoloji"] if c["accession"])
    TOK = {"v": None, "t": 0}
    def yenile():
        s.get(B + "/Home/Index", timeout=60)  # e-Nabız oturumunu canlı tut (30 dk idle → SessionTimeout)
        TOK["v"], otac = _teletip_token(s, L["_verifToken"], acc0); TOK["t"] = time.time(); return otac
    otac = yenile()
    wi = requests.get(TELE + "/LoadWorkItemForENabiz", params={"otac": otac}, headers={"Authorization": TOK["v"]}, timeout=120).json()
    studies = [x for x in wi["WorkItem"]["Patient"]["Studies"] if x.get("Series") and (not args.acc or x["AccessionNumber"] == args.acc)]
    os.makedirs(args.out, exist_ok=True)
    json.dump(wi, open(os.path.join(args.out, "_workitem.json"), "w"), ensure_ascii=False)
    slug = lambda t: re.sub(r"[^0-9A-Za-z]+", "-", t or "").strip("-")[:40]
    jobs = queue.Queue(); ext = "dcm" if args.dicom else "jpg"
    for x in studies:
        d, m, y = x["StudyDate"][:10].split(".")
        sdir = os.path.join(args.out, f"{y}-{m}-{d}_{slug(x['ModalitiesInStudy'])}_{slug(x['HospitalName'])[:25]}_{x['AccessionNumber']}")
        os.makedirs(sdir, exist_ok=True)
        json.dump({k: v for k, v in x.items() if k != "Series"} | {"Series": [{k: v for k, v in se.items() if k not in ("Instances", "ThumbnailImage")} | {"InstanceCount": len(se.get("Instances") or [])} for se in x["Series"]]}, open(sdir + ".json", "w"), ensure_ascii=False, indent=1)
        for se in x["Series"]:
            if (se.get("Modality") or "") in ("SR", "OT", "PR", "KO"):
                continue
            sedir = os.path.join(sdir, f"S{int(se.get('SeriesNumber') or 0):02d}_{slug(se.get('Modality'))}_{slug(se.get('Description'))}")
            os.makedirs(sedir, exist_ok=True)
            for ins in se.get("Instances") or []:
                p = os.path.join(sedir, f"{int(ins.get('InstanceNumber') or 0):04d}.{ext}")
                if not (os.path.exists(p) and os.path.getsize(p) > 0):
                    jobs.put((x["WadoAddress"], x["StudyInstanceUID"], se["SeriesInstanceUID"], ins["SopInstanceUID"], p))
    top = jobs.qsize(); log(f"çalışma {len(studies)} · indirilecek kare {top}")
    lock = threading.Lock(); say = {"ok": 0, "fail": 0}
    def worker():
        ss = requests.Session()
        while True:
            try: base, stu, ser, obj, p = jobs.get_nowait()
            except queue.Empty: return
            for _ in range(4):
                try:
                    u = f"{base}requestType=WADO&studyUID={stu}&seriesUID={ser}&objectUID={obj}" + ("" if args.dicom else "&contentType=image/jpeg")
                    r = ss.get(u, headers={"Authorization": TOK["v"]}, timeout=90)
                    if r.status_code == 401:
                        with lock:
                            if time.time() - TOK["t"] > 30: yenile()
                        continue
                    if r.status_code == 200 and (args.dicom or r.content[:2] == b"\xff\xd8"):
                        open(p, "wb").write(r.content); say["ok"] += 1; break
                    if r.status_code == 400: break
                    time.sleep(2)
                except Exception:
                    time.sleep(3)
            else:
                say["fail"] += 1
            if (say["ok"] + say["fail"]) % 500 == 0: log(f"  {say['ok'] + say['fail']}/{top}")
    th = [threading.Thread(target=worker, daemon=True) for _ in range(6)]
    [t.start() for t in th]; [t.join() for t in th]
    log(f"✓ kare {say['ok']} indirildi · {say['fail']} başarısız → {args.out}")


def cmd_dedupe(args):
    import glob, difflib, pymupdf
    def metin(p):
        try:
            d = pymupdf.open(p); t = " ".join(pg.get_text() for pg in d); d.close()
        except Exception:
            return ""
        return re.sub(r"\s+", " ", t).strip()
    mevcut = {p: metin(p) for p in glob.glob(os.path.join(args.mevcut, "**", "*.pdf"), recursive=True)}
    yeni = []
    for p in sorted(glob.glob(os.path.join(args.indir, "**", "*.pdf"), recursive=True)):
        t = metin(p); best = 0.0
        for v in mevcut.values():
            if v and abs(len(v) - len(t)) <= 0.25 * max(len(v), len(t)):
                sm = difflib.SequenceMatcher(None, t[:3000], v[:3000])
                if sm.quick_ratio() > best:
                    best = max(best, sm.ratio())
        if best < args.esik:
            yeni.append({"dosya": p, "en_iyi_eslesme": round(best, 3)})
    json.dump(yeni, open(args.out, "w"), ensure_ascii=False, indent=1)
    log(f"✓ {len(yeni)} yeni / {len(mevcut)} mevcut → {args.out}")


def cmd_doctor(args):
    env_yukle()
    ok = True
    tc, sf = os.environ.get("EDEVLET_TC"), os.environ.get("EDEVLET_SIFRE")
    log(("✓" if tc and sf else "✗") + " kimlik (EDEVLET_TC/EDEVLET_SIFRE ortamda)" + ("" if tc and sf else " — vault-cek get EDEVLET_TC && vault-cek get EDEVLET_SIFRE"))
    ok &= bool(tc and sf)
    fontconfig_kur(); log(("✓" if os.path.exists(FONTCONF) else "✗") + " fontconfig " + FONTCONF)
    try:
        import playwright, requests, pymupdf  # noqa
        log("✓ playwright · requests · pymupdf")
    except Exception as e:
        log("✗ python bağımlılığı:", e); ok = False
    try:
        import requests
        r = requests.get(B + "/Account/Login?_st=1", timeout=20); log(("✓" if r.status_code == 200 else "✗") + f" enabiz.gov.tr http={r.status_code}")
    except Exception as e:
        log("✗ enabiz erişilemiyor:", str(e)[:80]); ok = False
    log("durum:", "yeşil" if ok else "kırmızı")
    sys.exit(0 if ok else 1)


def main():
    ap = argparse.ArgumentParser(); sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("doctor")
    a = sp.add_parser("login"); a.add_argument("--otp")
    a = sp.add_parser("liste"); a.add_argument("--out", required=True)
    a = sp.add_parser("indir"); a.add_argument("--liste", required=True); a.add_argument("--out", required=True)
    a = sp.add_parser("goruntu"); a.add_argument("--liste", required=True); a.add_argument("--out", required=True); a.add_argument("--acc"); a.add_argument("--dicom", action="store_true")
    a = sp.add_parser("dedupe"); a.add_argument("--indir", required=True); a.add_argument("--mevcut", required=True); a.add_argument("--out", required=True); a.add_argument("--esik", type=float, default=0.9)
    args = ap.parse_args()
    {"doctor": cmd_doctor, "login": cmd_login, "liste": cmd_liste, "indir": cmd_indir, "goruntu": cmd_goruntu, "dedupe": cmd_dedupe}[args.cmd](args)


if __name__ == "__main__":
    main()
