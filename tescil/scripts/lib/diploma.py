#!/usr/bin/env python3
"""diploma.py — Mühürdarlık diploma sınavı (G13 · Sultan D1 22 Eki "Üç alana böl"; kadro şeması §1b · §6 · §7).

Bir mühürdar, el kitabının yanındaki SINAV KÜMESİYLE sınanır: bilinen doğru, kusurlu ve uydurma teslimler. Her örnekte
mühürdarın usulü (muhurdar.sh) GERÇEKTEN koşulur ve hüküm örneğin beklenen hükmüyle karşılaştırılır. Sonuç merkezdeki
append-only diploma defterine şema §6 satırıyla yazılır; diploma SAKLANMAZ, defterden türetilir (durum).

Komutlar:
  sina  <personel> [--uzmanlik muhurdarlik] [--kume DIR] [--kanit DIR]
  durum <personel> [--uzmanlik muhurdarlik]

Örnek dizini (kume/<tür>/<ad>/): GEREKLILIK.md + rubrik dosyaları + is/ (teslim edilen iş ağacı) + beklenen.json
  beklenen.json = {"verdikt": "GECTI"|"KALDI", "kaldi": [G…], "neden": "…"}
  Doğru örnekte hüküm GECTI olmalı. Kusurlu/uydurma örnekte hüküm KALDI olmalı VE beklenen G'lerin hepsi düşmüş olmalı
  (başka bir G'nin kazara düşmesi kusuru yakalamak sayılmaz). EMIN-DEGILIM (eskalasyon) hiçbir türde isabet sayılmaz.
Geçme: her örnekte isabet (tam puan). Kümedeki bir tür boşsa sınav KOŞULMAZ (rc 3) — şema §1b: her tür ≥1 örnek.

Ayrım (gerçek kayda dokunmaz): sınav koşusu geçici bir kökte yapılır; mühürdarın sicili (SICIL_DIZIN) yok bir dizine,
tescil telemetrisi geçici köke yönlenir. Sınav teslimi gerçek bir mühür DEĞİLDİR, sicil penceresini ilerletmez.

Durum türetimi (§6 · §7): son GEÇEN koşu yok → yok · koşunun el kitabı sürümü ≠ güncel sürüm → bayat (yeniden sınav) ·
sicil askıda → askida · aksi → gecerli. Güncel sürüm katalogdan (§1: `catalog.json` → tescil version); katalog okunamazsa
el kitabının SKILL.md sürümü, bu da söylenir. Sicil okunamazsa diploma geçerli görünse de "sicil ölçülemedi" yazılır.

RC: 0 = geçti / geçerli · 1 = kaldı / yok · bayat · askida · 2 = kullanım · 3 = ölçülemedi (defter yok, küme eksik, koşu bozuk)
Ortam: DIPLOMA_DEFTERI (varsayılan Nexus _agents/orchestration/diploma-defteri.jsonl) · TESCIL_KATALOG · SICIL_DIZIN (durum için)
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
EL_KITABI_KOK = os.path.dirname(SCRIPTS)
DEFTER = os.environ.get("DIPLOMA_DEFTERI", "/config/projects/Nexus/_agents/orchestration/diploma-defteri.jsonl")
KATALOG = os.environ.get("TESCIL_KATALOG", os.path.join(os.path.dirname(EL_KITABI_KOK), "catalog.json"))
TURLER = ("dogru", "kusurlu", "uydurma")
SINAV_YAZAN = "DIPLOMA-SINAVI"


def hata(m, rc):
    print(f"diploma: {m}", file=sys.stderr)
    sys.exit(rc)


def ad_kat(s):
    """Türkçe harf katlama: 'MUHAKKİK' ile 'MUHAKKIK' aynı kişidir (sicil.py ile aynı kural)."""
    return s.strip().replace("İ", "I").replace("ı", "i").casefold()


def skill_surum():
    try:
        with open(os.path.join(EL_KITABI_KOK, "SKILL.md"), encoding="utf-8") as f:
            for satir in f:
                m = re.match(r"^version:\s*(\S+)", satir)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return None


def guncel_surum():
    """(sürüm, kaynak) — katalog önce (şema §1), yoksa SKILL.md."""
    try:
        with open(KATALOG, encoding="utf-8") as f:
            for s in json.load(f).get("skills", []):
                if s.get("id") == "tescil" and s.get("version"):
                    return s["version"], "katalog"
    except (OSError, ValueError):
        pass
    v = skill_surum()
    return (v, "SKILL.md (katalog okunamadı)") if v else (None, "yok")


def kume_ozeti(kume):
    """{tür: [örnek dizini…]} ve kümenin içerik özeti (dosya yolu + bayt, sıralı)."""
    ornekler, h = {}, hashlib.sha256()
    for tur in TURLER:
        d = os.path.join(kume, tur)
        ornekler[tur] = sorted(os.path.join(d, x) for x in os.listdir(d) if os.path.isdir(os.path.join(d, x))) if os.path.isdir(d) else []
    for kok, dizinler, dosyalar in os.walk(kume):
        dizinler.sort()
        for ad in sorted(dosyalar):
            yol = os.path.join(kok, ad)
            h.update(os.path.relpath(yol, kume).encode() + b"\0")
            with open(yol, "rb") as f:
                h.update(f.read() + b"\0")
    return ornekler, h.hexdigest()


def ornek_kos(personel, ornek, kok, kart):
    """Bir örneği geçici kökte mühürdar usulüyle koşar → (isabet bool, ayrıntı dict)."""
    with open(os.path.join(ornek, "beklenen.json"), encoding="utf-8") as f:
        bek = json.load(f)
    if bek.get("verdikt") not in ("GECTI", "KALDI"):
        raise ValueError(f"{ornek}: beklenen.json verdikt GECTI|KALDI değil")
    w = os.path.join(kok, "is", kart)
    shutil.copytree(os.path.join(ornek, "is"), w)
    g = ["git", "-C", w]
    subprocess.run(g + ["init", "-q", "-b", "main"], check=True)
    subprocess.run(g + ["add", "-A"], check=True)
    subprocess.run(g + ["-c", "user.email=sinav@yerel", "-c", "user.name=sinav", "commit", "-qm", "sinav ornegi"], check=True)
    k = os.path.join(kok, "_agents", "tescil", kart)   # GEREKLILIK + rubrikler iş ağacının DIŞINDA; telemetri = kok/_agents/tescil
    os.makedirs(k)
    for ad in os.listdir(ornek):
        if os.path.isfile(os.path.join(ornek, ad)) and ad != "beklenen.json":
            shutil.copy(os.path.join(ornek, ad), k)
    out = os.path.join(k, "out")
    env = dict(os.environ, AGENT_NAME=personel, SICIL_DIZIN=os.path.join(kok, "sicil-yok"))
    p = subprocess.run(["bash", os.path.join(SCRIPTS, "muhurdar.sh"), kart, "--gereklilik", os.path.join(k, "GEREKLILIK.md"),
                        "--worktree", w, "--out", out, "--yazan", SINAV_YAZAN], env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    try:
        with open(os.path.join(out, "muhur-ozet.json"), encoding="utf-8") as f:
            oz = json.load(f)
    except (OSError, ValueError):
        oz = {}
    verdikt, dusen = oz.get("verdikt"), list(oz.get("g_dusen") or [])
    yargic, notlar = "", []   # hangi yargıç karar verdi + öznel G notları (MUHUR.md) — ıska/eskalasyonun sebebi kanıtta kalsın
    try:
        with open(os.path.join(out, "MUHUR.md"), encoding="utf-8") as f:
            for satir in f:
                if satir.startswith("yargic: "):
                    yargic = satir[8:].strip()
                elif re.match(r"^- G\d+: (GECTI|KALDI|EMIN-DEGILIM)", satir):
                    notlar.append(satir[2:].strip()[:300])
    except OSError:
        pass
    if bek["verdikt"] == "GECTI":
        isabet = verdikt == "GECTI"
    else:
        isabet = verdikt == "KALDI" and set(bek.get("kaldi") or []) <= set(dusen)
    return isabet, {"rc": p.returncode, "verdikt": verdikt, "g_dusen": dusen, "beklenen": bek["verdikt"],
                    "beklenen_kaldi": bek.get("kaldi") or [], "isabet": isabet, "yargic": yargic, "oznel_notlar": notlar,
                    "son_satir": (p.stdout.strip().splitlines() or [""])[-1][:300]}, out


def defter_oku():
    if not os.path.isfile(DEFTER):
        return None
    satirlar = []
    with open(DEFTER, encoding="utf-8") as f:
        for s in f:
            s = s.strip()
            if s:
                try:
                    satirlar.append(json.loads(s))
                except ValueError:
                    pass
    return satirlar


def sina(a):
    if ad_kat(a.personel) == ad_kat(SINAV_YAZAN):
        hata("sınavın yazan adı personel adı olamaz", 2)
    if not os.path.isdir(os.path.dirname(DEFTER) or "."):
        hata(f"diploma defterinin dizini yok: {os.path.dirname(DEFTER)} — ölçülemedi, sınav koşulmadı", 3)
    kume = os.path.abspath(a.kume or os.path.join(EL_KITABI_KOK, "sinav"))
    ornekler, kume_sha = kume_ozeti(kume) if os.path.isdir(kume) else ({t: [] for t in TURLER}, "")
    bos = [t for t in TURLER if not ornekler[t]]
    if bos:
        hata(f"sınav kümesi eksik ({kume}): {', '.join(bos)} türünde örnek yok — şema §1b her tür ≥1 ister; sınav koşulmadı", 3)
    surum, surum_kaynak = guncel_surum()
    if not surum:
        hata("el kitabı sürümü okunamadı (katalog da SKILL.md de yok) — ölçülemedi", 3)
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    kanit = os.path.abspath(a.kanit or tempfile.mkdtemp(prefix="diploma-kanit-"))
    os.makedirs(kanit, exist_ok=True)
    sonuc, ayrinti = {}, {}
    kok = tempfile.mkdtemp(prefix="diploma-kok-")
    try:
        for tur in TURLER:
            n = 0
            for o in ornekler[tur]:
                kart = f"sinav-{tur}-{os.path.basename(o)}"
                try:
                    isabet, ay, out = ornek_kos(a.personel, o, kok, kart)
                except (OSError, ValueError, subprocess.CalledProcessError) as e:
                    hata(f"örnek koşulamadı ({o}): {e} — sınav ölçülemedi, deftere yazılmadı", 3)
                if ay["rc"] == 2 or ay["verdikt"] is None:
                    hata(f"örnek koşusu bozuk ({kart}: rc {ay['rc']}, mühür özeti yok) — {ay['son_satir']}; deftere yazılmadı", 3)
                n += isabet
                ayrinti[kart] = ay
                if os.path.isfile(os.path.join(out, "MUHUR.md")):
                    shutil.copy(os.path.join(out, "MUHUR.md"), os.path.join(kanit, f"{kart}.MUHUR.md"))
                print(f"  {'✓' if isabet else '✗'} {tur}/{os.path.basename(o)} · beklenen {ay['beklenen']}"
                      f"{' ' + ','.join(ay['beklenen_kaldi']) if ay['beklenen_kaldi'] else ''} · hüküm {ay['verdikt']}"
                      f"{' (düşen ' + ','.join(ay['g_dusen']) + ')' if ay['g_dusen'] else ''}"
                      f"{' · yargıç ' + ay['yargic'] if ay['yargic'] else ''}")
                if not isabet:
                    for n_ in ay["oznel_notlar"]:
                        print(f"      {n_}")
            sonuc[tur] = f"{n}/{len(ornekler[tur])}"
    finally:
        shutil.rmtree(kok, ignore_errors=True)
    gecti = all(s.split("/")[0] == s.split("/")[1] for s in sonuc.values())
    with open(os.path.join(kanit, "sonuc.json"), "w", encoding="utf-8") as f:
        json.dump({"personel": a.personel, "uzmanlik": a.uzmanlik, "ts": ts, "sonuc": sonuc, "ornekler": ayrinti,
                   "el_kitabi_surum": surum, "surum_kaynagi": surum_kaynak, "kume_sha": kume_sha}, f, ensure_ascii=False, indent=1)
    satir = {"ts": ts, "personel": a.personel, "uzmanlik": a.uzmanlik, "el_kitabi": "tescil", "el_kitabi_surum": surum,
             "kume_sha": kume_sha, "sonuc": sonuc, "gecti": "e" if gecti else "h", "kanit": kanit}
    metin = json.dumps(satir, ensure_ascii=False)
    with open(DEFTER, "a", encoding="utf-8") as f:
        f.write(metin + "\n")
    son = (defter_oku() or [None])[-1]   # yazdığını geri oku (EKSİK VERİYİ ÖNCE SINA)
    if son != satir:
        hata(f"deftere yazılan satır geri okunamadı ({DEFTER})", 3)
    print(f"diploma: {a.personel} · {a.uzmanlik} · el kitabı tescil {surum} ({surum_kaynak}) · "
          f"doğru {sonuc['dogru']} · kusurlu {sonuc['kusurlu']} · uydurma {sonuc['uydurma']} → {'GEÇTİ' if gecti else 'KALDI'}")
    print(f"diploma: deftere yazıldı → {DEFTER} · kanıt {kanit}")
    return 0 if gecti else 1


def sicil_durumu(personel):
    """'askida' | 'ders-cikarma' | 'temiz' | None (ölçülemedi) — sicil.py durum çıktısından."""
    sicil = os.path.join(HERE, "sicil.py")
    if not os.path.isfile(sicil):
        return None
    p = subprocess.run([sys.executable, sicil, "durum", personel, "--json"], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    try:
        d = json.loads(p.stdout) if p.returncode == 0 else {}
    except ValueError:
        d = {}
    return d.get("durum") if d.get("durum") in ("askida", "ders-cikarma", "temiz") else None


def durum(a):
    satirlar = defter_oku()
    if satirlar is None:
        hata(f"diploma defteri yok: {DEFTER} — ölçülemedi (yok DEĞİL)", 3)
    benim = [s for s in satirlar if ad_kat(str(s.get("personel", ""))) == ad_kat(a.personel) and s.get("uzmanlik") == a.uzmanlik]
    gecen = [s for s in benim if s.get("gecti") == "e"]
    surum, surum_kaynak = guncel_surum()
    sic = sicil_durumu(a.personel)
    sicil_notu = f"sicil {sic}" if sic else "sicil ölçülemedi"
    if not gecen:
        son = benim[-1] if benim else None
        ek = f" · son koşu {son['ts'][:10]} kaldı ({', '.join(f'{k} {v}' for k, v in son.get('sonuc', {}).items())})" if son else ""
        print(f"diploma: {a.personel} · {a.uzmanlik} · durum: yok{ek} · {sicil_notu}")
        return 1
    d = gecen[-1]
    if sic == "askida":
        hal, gereken = "askida", "el kitabı güncellemesi + yeniden sınav (S10)"
    elif not surum:
        print(f"diploma: {a.personel} · güncel el kitabı sürümü okunamadı — ölçülemedi", file=sys.stderr)
        return 3
    elif d.get("el_kitabi_surum") != surum:
        hal, gereken = "bayat", f"el kitabı {d.get('el_kitabi_surum')} → {surum}: yeniden sınav"
    else:
        hal, gereken = "gecerli", ""
    print(f"diploma: {a.personel} · {a.uzmanlik} · durum: {hal} · sınav {d['ts'][:10]} · el kitabı {d.get('el_kitabi_surum')} "
          f"(güncel {surum}, {surum_kaynak}) · {sicil_notu}{' · gereken: ' + gereken if gereken else ''}")
    return 0 if hal == "gecerli" else 1


def main():
    ap = argparse.ArgumentParser(prog="diploma")
    alt = ap.add_subparsers(dest="komut", required=True)
    s = alt.add_parser("sina")
    s.add_argument("personel")
    s.add_argument("--uzmanlik", default="muhurdarlik")
    s.add_argument("--kume")
    s.add_argument("--kanit")
    d = alt.add_parser("durum")
    d.add_argument("personel")
    d.add_argument("--uzmanlik", default="muhurdarlik")
    a = ap.parse_args()
    if a.uzmanlik != "muhurdarlik":
        hata(f"bilinmeyen uzmanlık: {a.uzmanlik} (bugün yalnız muhurdarlik'in sınav kümesi var)", 2)
    sys.exit(sina(a) if a.komut == "sina" else durum(a))


if __name__ == "__main__":
    main()
