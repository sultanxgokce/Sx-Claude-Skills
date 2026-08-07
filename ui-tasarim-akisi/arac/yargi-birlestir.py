#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""yargi-birlestir.py — çapraz-aile yargıç panelinin oylarını hükme çevirir (G1 hattı).

BU DOSYA AĞ KULLANMAZ. Yargıçları çağırmak `yargi-panel.sh`in işidir; burada yalnız
ham yanıtlar → hüküm dönüşümü yapılır. Böylece kural CI'da hermetik test edilebilir.

Zincir (her halkası ölçülmüş bir zaafı kapatır):
  1 parse kapısı   — kapalı şemaya oturmayan cevap düşer          (çıktı bozulması)
  2 alıntı kapısı  — ekranda birebir bulunmayan alıntı → oy düşer (uydurma kusur/övgü)
  3 yeter sayı     — ayakta <N oy → EMİN-DEĞİLİM (asla yeşil)     (unknown ≠ pass)
  4 medyan         — kesirlide AŞAĞI, ortalama DEĞİL              (tek aykırı değer)
  5 kırmızı çizgi  — geçerli-alıntılı tek 0 → madde 0             (sahte-yeşil asimetrisi)

Çıkış kodları:
  0  KIRMIZI-DEĞİL — G1 yeşili iptal etmedi (yeşil ÜRETMEZ; durma koşulu G0'dır)
  1  RED           — en az bir ekran düştü
  2  ÇALIŞTIRILAMADI / EMİN-DEĞİLİM — mühür uyuşmazlığı, rubrik yok, yeter sayı tutmadı

Kullanım:
  yargi-birlestir.py --rubrik <rubrik.md> --yanit <dir> --ekran-dir <dir>
                     [--muhur <sha256>] [--panel kimi,glm,qwen]
                     [--json <cikti.json>] [--tescil-g G3]
                     [--havuz-kutu akar] [--havuz <tasarim-havuz.jsonl>]

Yanıt dosyası adı: `<ekran>__<yargic>.json` (kapının ham yanıtı ya da düz metin).
"""
import glob
import hashlib
import json
import os
import re
import sys

VARSAYILAN = {"yeter_sayi": 2, "red_esigi": 3, "kanit_max": 160}


# ── rubrik: VERİ dosyası; maddeler ve eşikler buradan okunur ────────────────────
def rubrik_oku(yol):
    metin = open(yol, encoding="utf-8").read()
    ayar = dict(VARSAYILAN)
    for anahtar in ayar:
        m = re.search(r"<!--\s*%s:\s*(\d+)\s*-->" % anahtar, metin)
        if m:
            ayar[anahtar] = int(m.group(1))
    maddeler = re.findall(r"^##\s+(M\d+)\s*·\s*(.+?)\s*$", metin, re.M)
    sha = hashlib.sha256(metin.encode("utf-8")).hexdigest()
    return {"ayar": ayar, "maddeler": [m[0] for m in maddeler],
            "basliklar": dict(maddeler), "sha256": sha}


# ── ham yanıt → kapalı şema ────────────────────────────────────────────────────
def metin_cek(ham):
    """Kapı yanıtı (Anthropic biçimi) ya da düz metin → (metin, hata)."""
    try:
        resp = json.loads(ham)
    except Exception:
        return ham, None                      # düz metin de kabul (yerel/test koşusu)
    if not isinstance(resp, dict):
        return ham, None
    if "error" in resp:
        return None, "kapi-hatasi"
    if resp.get("stop_reason") == "max_tokens":
        parcalar = [b.get("text", "") for b in resp.get("content", []) if b.get("type") == "text"]
        return "".join(parcalar), "max_tokens-kirpildi"
    if "content" in resp:
        return "".join(b.get("text", "") for b in resp.get("content", []) if b.get("type") == "text"), None
    if "maddeler" in resp:
        return ham, None
    return ham, None


def sema_bul(metin):
    """Metindeki SON geçerli {"maddeler": [...]} nesnesini çıkar (düşünme bloğu atılır)."""
    if not metin:
        return None
    metin = re.sub(r"<think>.*?</think>", "", metin, flags=re.S)
    coz = json.JSONDecoder()
    bulunan = None
    for m in re.finditer(r"\{", metin):
        try:
            obj, _ = coz.raw_decode(metin, m.start())
        except Exception:
            continue
        if isinstance(obj, dict) and "maddeler" in obj:
            bulunan = obj
    return bulunan


def oylari_yukle(yanit_dir, ekran_dir, rubrik, panel):
    """oylar[ekran][madde][yargic] · ist[yargic] = karne"""
    oylar, ist, ekran_yok = {}, {}, set()
    for yol in sorted(glob.glob(os.path.join(yanit_dir, "*.json"))):
        ad = os.path.basename(yol)[:-5]
        if ad.startswith(".") or "__" not in ad:
            continue
        ekran, yargic = ad.rsplit("__", 1)
        if panel and yargic not in panel:
            continue
        html_yol = os.path.join(ekran_dir, ekran + ".html")
        if not os.path.exists(html_yol):
            ekran_yok.add(ekran)
            continue
        html = open(html_yol, encoding="utf-8").read()
        k = ist.setdefault(yargic, {"parse_ok": 0, "parse_dusen": 0, "alinti_ok": 0,
                                    "alinti_dusen": 0, "gecerli_sifir": 0, "notlar": []})
        oylar.setdefault(ekran, {M: {} for M in rubrik["maddeler"]})
        metin, hata = metin_cek(open(yol, encoding="utf-8").read())
        sema = sema_bul(metin)
        if sema is None:
            k["parse_dusen"] += 1
            k["notlar"].append("%s:%s" % (ekran, hata or "sema-parse-dusen"))
            continue
        k["parse_ok"] += 1
        for mad in sema.get("maddeler", []):
            mid, puan = mad.get("id"), mad.get("puan")
            kanit = str(mad.get("kanit", ""))
            if mid not in rubrik["maddeler"] or puan not in (0, 1, 2):
                continue
            gecerli = bool(kanit) and (kanit in html)     # grep -F anlamı: birebir substring
            k["alinti_ok" if gecerli else "alinti_dusen"] += 1
            if gecerli and puan == 0:
                k["gecerli_sifir"] += 1
            oylar[ekran][mid][yargic] = {
                "puan": puan, "gecerli": gecerli,
                "kanit": kanit[:rubrik["ayar"]["kanit_max"]],
                "gerekce": str(mad.get("gerekce", ""))[:200]}
    return oylar, ist, sorted(ekran_yok)


# ── birleştirme + hüküm ────────────────────────────────────────────────────────
def birlestir(ekran_oylari, rubrik):
    yeter = rubrik["ayar"]["yeter_sayi"]
    final = {}
    for M in rubrik["maddeler"]:
        gecerliler = [v for v in ekran_oylari[M].values() if v["gecerli"]]
        if len(gecerliler) < yeter:
            final[M] = {"puan": None, "oy": len(gecerliler), "gerekce": ""}
            continue
        puanlar = sorted(v["puan"] for v in gecerliler)
        med = puanlar[(len(puanlar) - 1) // 2]             # kesirli medyan AŞAĞI
        sifirlar = [v for v in gecerliler if v["puan"] == 0]
        if sifirlar:                                        # kırmızı çizgi
            med = 0
        final[M] = {"puan": med, "oy": len(gecerliler),
                    "gerekce": (sifirlar[0]["gerekce"] if sifirlar else "")}
    return final


def hukum_ver(final, rubrik):
    belirsiz = [M for M, f in final.items() if f["puan"] is None]
    sifir = sorted(M for M, f in final.items() if f["puan"] == 0)
    if len(belirsiz) >= rubrik["ayar"]["yeter_sayi"]:
        return "EMİN-DEĞİLİM", sifir, sorted(belirsiz)
    if len(sifir) >= rubrik["ayar"]["red_esigi"]:
        return "RED", sifir, sorted(belirsiz)
    return "KIRMIZI-DEĞİL", sifir, sorted(belirsiz)


def cikis(kod, mesaj=None):
    if mesaj:
        print(mesaj)
    sys.exit(kod)


def main(argv):
    a = {"rubrik": None, "yanit": None, "ekran-dir": None, "muhur": None,
         "panel": None, "json": None, "tescil-g": None,
         "havuz-kutu": None, "havuz": None}
    i = 0
    while i < len(argv):
        ad = argv[i][2:] if argv[i].startswith("--") else None
        if ad not in a:
            cikis(2, "RC=2 bilinmeyen argüman: %s" % argv[i])
        a[ad] = argv[i + 1] if i + 1 < len(argv) else None
        i += 2
    if not (a["rubrik"] and a["yanit"] and a["ekran-dir"]):
        cikis(2, "RC=2 kullanım: --rubrik <f> --yanit <dir> --ekran-dir <dir> "
                 "[--muhur <sha>] [--panel a,b,c] [--json <f>] [--tescil-g G3]")
    if not os.path.exists(a["rubrik"]):
        cikis(2, "RC=2 ÇALIŞTIRILAMADI — rubrik yok: %s\n"
                 "  Yargı yapılmadı. (Rubriksiz koşu 'temiz' sayılmaz.)" % a["rubrik"])

    rubrik = rubrik_oku(a["rubrik"])
    if not rubrik["maddeler"]:
        cikis(2, "RC=2 ÇALIŞTIRILAMADI — rubrikte '## M<n> · <başlık>' maddesi bulunamadı")

    # MÜHÜR: kayıtlı sha ≠ canlı sha → koşu REDDEDİLİR ("yine de koş" yok)
    if a["muhur"] and a["muhur"] != rubrik["sha256"]:
        cikis(2, "RC=2 MÜHÜR UYUŞMAZLIĞI — rubrik koşudan sonra değişmiş.\n"
                 "  beklenen: %s\n  canlı   : %s\n"
                 "  Rubriği düzenlemek regresyonu yeniden koşmadan geçerli sayılmaz."
                 % (a["muhur"], rubrik["sha256"]))

    panel = [p.strip() for p in a["panel"].split(",")] if a["panel"] else None
    oylar, ist, ekran_yok = oylari_yukle(a["yanit"], a["ekran-dir"], rubrik, panel)

    if not oylar:
        cikis(2, "RC=2 ÇALIŞTIRILAMADI — değerlendirilebilir yanıt yok (%s)%s"
                 % (a["yanit"],
                    "\n  ekran HTML'i bulunamadı: " + ", ".join(ekran_yok) if ekran_yok else ""))

    ekranlar, imza = {}, []
    for ekran in sorted(oylar):
        final = birlestir(oylar[ekran], rubrik)
        hukum, sifir, belirsiz = hukum_ver(final, rubrik)
        ekranlar[ekran] = {
            "hukum": hukum,
            "puanlar": {M: final[M]["puan"] for M in rubrik["maddeler"]},
            "oy_sayisi": {M: final[M]["oy"] for M in rubrik["maddeler"]},
            "dusuren_maddeler": sifir, "belirsiz_maddeler": belirsiz,
            "gerekceler": {M: final[M]["gerekce"] for M in sifir}}
        imza += ["%s:%s" % (ekran, M) for M in sifir]      # sayısal puan imzaya GİRMEZ

    red = [e for e, v in ekranlar.items() if v["hukum"] == "RED"]
    emin_degil = [e for e, v in ekranlar.items() if v["hukum"] == "EMİN-DEĞİLİM"]
    genel = "RED" if red else ("EMİN-DEĞİLİM" if emin_degil else "KIRMIZI-DEĞİL")
    rc = {"RED": 1, "EMİN-DEĞİLİM": 2, "KIRMIZI-DEĞİL": 0}[genel]

    rapor = {"rubrik": os.path.basename(a["rubrik"]), "rubrik_sha256": rubrik["sha256"],
             "panel": panel or sorted(ist), "genel_hukum": genel, "rc": rc,
             "ekranlar": ekranlar, "imza": sorted(imza), "yargic_karnesi": ist,
             "ekran_html_yok": ekran_yok}
    if a["json"]:
        with open(a["json"], "w", encoding="utf-8") as f:
            json.dump(rapor, f, ensure_ascii=False, indent=1)

    # ── insan çıktısı ──
    print("rubrik: %s  sha=%s" % (rapor["rubrik"], rubrik["sha256"][:12]))
    print("panel : %s" % ", ".join(rapor["panel"]))
    for ekran in sorted(ekranlar):
        v = ekranlar[ekran]
        puan = " ".join("%s=%s" % (M, "?" if v["puanlar"][M] is None else v["puanlar"][M])
                        for M in rubrik["maddeler"])
        print("\n%-28s %s" % (ekran, v["hukum"]))
        print("  %s" % puan)
        for M in v["dusuren_maddeler"]:
            print("  ↓ %s (%s) — %s" % (M, rubrik["basliklar"].get(M, ""), v["gerekceler"][M]))
        for M in v["belirsiz_maddeler"]:
            print("  ? %s — yeter sayı tutmadı (%d geçerli oy)" % (M, v["oy_sayisi"][M]))
    print("\nyargıç karnesi (parse ok/düşen · alıntı ok/düşen · geçerli-0):")
    for j in sorted(ist):
        k = ist[j]
        print("  %-10s %d/%d · %d/%d · %d %s"
              % (j, k["parse_ok"], k["parse_dusen"], k["alinti_ok"], k["alinti_dusen"],
                 k["gecerli_sifir"], ("· " + "; ".join(k["notlar"][:3])) if k["notlar"] else ""))
    if ekran_yok:
        print("\nUYARI ekran HTML'i yok (oy sayılmadı): %s" % ", ".join(ekran_yok))

    # ── HAVUZ: hüküm merkezde birikir (ekran başına bir satır, META-ONLY) ──────
    # Alıntı/gerekçe metni havuza GİRMEZ — şema onu taşımaz (bkz havuz.py).
    if a["havuz-kutu"]:
        import subprocess
        havuz = os.path.join(os.path.dirname(os.path.abspath(__file__)), "havuz.py")
        eslek_h = {"RED": "kirmizi", "KIRMIZI-DEĞİL": "temiz", "EMİN-DEĞİLİM": "emin-degilim"}
        for ekran in sorted(ekranlar):
            v = ekranlar[ekran]
            komut = [sys.executable, havuz, "yaz",
                     "--kutu", a["havuz-kutu"], "--urun", a["havuz-kutu"],
                     "--ekran", ekran.lower(), "--kapi", "yargi",
                     "--hukum", eslek_h[v["hukum"]],
                     "--dusen", ",".join(v["dusuren_maddeler"])]
            if a["havuz"]:
                komut += ["--havuz", a["havuz"]]
            try:
                subprocess.run(komut, check=True, stdout=subprocess.DEVNULL)
            except Exception as e:
                sys.stderr.write("UYARI: havuza yazılamadı (%s) — hüküm geçerli, "
                                 "defter eksik kaldı.\n" % e)
                break

    if a["tescil-g"]:
        eslek = {"RED": "KALDI", "KIRMIZI-DEĞİL": "GECTI", "EMİN-DEĞİLİM": "EMIN-DEGILIM"}
        notu = ("düşen: " + ", ".join(sorted(set(imza)))[:120]) if imza else "rubrik-panel temiz"
        print("\ntescil: --katman2 %s=%s:%s" % (a["tescil-g"], eslek[genel], notu))

    print("\nHÜKÜM: %s (rc=%d)  ·  G1 yeşil ÜRETMEZ, yalnız iptal eder" % (genel, rc))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
