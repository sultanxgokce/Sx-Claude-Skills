#!/usr/bin/env python3
"""hafta-kapanis.py — haftanın kapanış KAPISI: yazmaz, ÖLÇER. Protokol eksiksiz koşmadıysa hafta kapanmaz.

Niçin var (Sultan 17 Eki 2026, beyan SERDAR): "haftayı kapatma şartı olsun; sistem protokol eksiksiz
koşmadıysa haftayı kapatmasın." Kapı dört ölçüm + bir onay okur; hiçbirini kendisi üretmez:

  K1 katılım   — aktif ajanların kutu retrosu var ve geçerli (retro.py'nin saf yardımcılarıyla; `retro.py merkez`
                 MERKEZ.md yazabildiği için kapı onu ÇAĞIRMAZ)
  K2 dersler   — MERKEZ.md var; en az bir ders (M<n>) yazılı; HER ders görev defterine D1 damgasıyla girmiş
                 (`- gorev_<26> · ders M<n> · D1: YYYY-MM-DD Sultan: … (sohbet · <ref> · "<kırpık>" · beyan:<AJAN>)`).
                 RED yolu YOK: görev olmayacak şey Dersler'e yazılmaz (nota taşınır). D1 TAM satırdır (baş/son çapalı)
                 ve kırpık ≤15 kelimedir (karakter sayısı kelime sayısının yerine geçmez).
  K3 süzüm     — kutu önerilerinin her biri damgalı (retro.py suzum rc)
  K4 kaçış     — haftanın kaçış (kaçış defteri) ve tıkanma (kart durum=tikandi) kayıtlarının her biri MERKEZ.md
                 "## Kaçış ve tıkanma" bölümünde YAZILI bir derse bağlı: `- <anahtar> → M<n>` (RED yolu yok)
  K5 onay      — KAPANIS.md'de `_sultan_onay:` satırı geçerli D1 biçiminde. 🔴 A06: bu satırı ARAÇ YAZMAZ;
                 insan (Sultan sözünü aktaran beyan) yazar, araç yalnız var mı/biçimli mi diye ölçer ve korur.

Çıktı: `_agents/handoff/retro/<hafta>/KAPANIS.md` (aracın TEK yazdığı dosya; retro/MERKEZ dosyalarına dokunmaz).
Çıkış: 0 KAPANDI · 5 ONAY BEKLİYOR (K1-K4 yeşil, K5 yok) · 1 AÇIK (kırmızı var) · 3 ÖLÇÜLEMEDİ (sarı var, kırmızı yok;
        retro becerisi hiç yoksa dosya yazılmadan 3 — aracın kendisi ölçülür) · 2 kullanım.
`acik` alt komutu: KAPANDI olmayan hafta dizinlerini listeler (açık hafta kaydı dizinden türetilir, ayrı defter yok).
"""
import glob
import importlib.util
import json
import os
import re
import subprocess
import sys
from datetime import datetime

SURUM = "1.0.0"
D1_RE = re.compile(r"\d{4}-\d{2}-\d{2} Sultan: .+\(sohbet · [^·()]+ · \"([^\"]{1,120})\" · beyan:\S+\)")
D1_KIRPIK_KELIME = 15   # L73 K1-K4: verbatim kırpık ≤15 kelime — karakter sayısı kelime sayısının yerine geçmez (göz #360 tur 3)


def d1_gecerli(v):
    """D1 damgası TAM satır eşleşir ve kırpık ≤15 kelimedir. → (True, "") ya da (False, sebep)."""
    m = D1_RE.fullmatch(v.strip())
    if not m:
        return False, "D1 biçimi değil (tarih · 'Sultan:' · sohbet · ref · kırpık · beyan:)"
    n = len(m.group(1).split())
    if n > D1_KIRPIK_KELIME:
        return False, f"kırpık {n} kelime (>{D1_KIRPIK_KELIME}); verbatim kırpık kısa tutulur, Sultan sözü özetlenmez-üretilmez"
    return True, ""
GOREV_RE = re.compile(r"gorev_[0-9A-Z]{26}")
DERS_RE = re.compile(r"^- M(\d+)\) (.+)$")
GOREV_SATIR_RE = re.compile(r"^- (gorev_[0-9A-Z]{26}) · ders ((?:M\d+(?:, )?)+) · D1: (.+)$")
KACIS_SATIR_RE = re.compile(r"^- (\S+) → M(\d+)$")   # kaçış/tıkanma yalnız bir DERSE bağlanır; RED yolu yok
YER_TUTUCU_RE = re.compile(r"<[^>]{1,60}>")


def retro_py_bul(arg):
    adaylar = [arg, os.environ.get("HAFTA_KAPANIS_RETRO_PY"),
               os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "retro", "scripts", "retro.py"),
               os.path.expanduser("~/.claude/skills/retro/scripts/retro.py")]
    for a in adaylar:
        if a and os.path.exists(a):
            return os.path.abspath(a)
    return None


def retro_yukle(yol):
    spec = importlib.util.spec_from_file_location("retro", yol)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def bolum(metin, baslik):
    """'## <baslik>' bölümünün satırları (sonraki '## ' kadar)."""
    sat = metin.split("\n")
    out, ic = [], False
    for s in sat:
        if s.startswith("## "):
            ic = s[3:].strip().startswith(baslik)
            continue
        if ic:
            out.append(s)
    return out


# ───────────────────────── kapılar ─────────────────────────
def k_retro(retro_py, alt, kok, hafta, ekstra):
    """retro.py <alt> koşar → (renk, not). Sarı = rc 3 ya da araç yok."""
    if not retro_py:
        return "SARI", "retro becerisi yok (retro.py bulunamadı) — katılım/süzüm ölçülemez"
    p = subprocess.run([sys.executable, retro_py, alt, "--kok", kok, "--hafta", hafta] + ekstra, capture_output=True, text=True)
    cikti = (p.stdout + p.stderr).strip()
    ilk = next((s for s in cikti.split("\n") if s.strip()), "")
    ozet = next((s.strip() for s in cikti.split("\n") if s.strip().startswith(("✗", "✓", "◻"))), ilk)
    if p.returncode == 0:
        return "YEŞİL", ozet[:160]
    if p.returncode == 3:
        return "SARI", ozet[:160]
    return "KIRMIZI", ozet[:160]


def k1_katilim(retro, kok, hafta, a):
    """Katılım: retro.py'nin SAF yardımcılarıyla (olc · iz_var · lint_metin · registry_ajanlar). `retro.py merkez`
    MERKEZ.md yazabildiği için kapı onu ÇAĞIRMAZ; sınıflandırma kuralı merkezle aynıdır (OK/GEÇERSİZ/EKSİK/ÇALIŞMADI).
    Not: bu kural iki çağıranda yaşıyor → retro.py'ye `katilim()` çıkarılması ayrı küçük iş (#359 birleşince)."""
    diz = os.path.join(kok, "_agents", "handoff", "retro", hafta)
    if a.get("--ajanlar"):
        ajanlar = [x for x in a["--ajanlar"].split(",") if x]
    else:
        ajanlar = retro.registry_ajanlar(a.get("--registry") or os.environ.get("RETRO_REGISTRY") or os.path.join(kok, "_agents", "handoff", "aile-registry.yaml"))
        if ajanlar is None:
            return "SARI", "ajan listesi yok (--ajanlar ya da aile-registry.yaml) — katılım ölçülemez"
    haric = {retro.norm(x) for x in (a.get("--haric") or "SERDAR").split(",")}
    eksik, gecersiz, ok = [], [], 0
    for ajan in ajanlar:
        if retro.norm(ajan) in haric:
            continue
        yol = next((pp for pp in glob.glob(os.path.join(diz, "*.md")) if retro.norm(os.path.splitext(os.path.basename(pp))[0]) == retro.norm(ajan)), None)
        if yol:
            h, _ = retro.lint_metin(open(yol, encoding="utf-8").read(), hafta, ajan)
            (gecersiz if h else []).append(ajan)
            ok += 0 if h else 1
        elif retro.iz_var(retro.olc(kok, ajan, hafta)):
            eksik.append(ajan)
    if eksik or gecersiz:
        return "KIRMIZI", f"OK {ok} · EKSİK {len(eksik)} ({', '.join(eksik) or '—'}) · GEÇERSİZ {len(gecersiz)} ({', '.join(gecersiz) or '—'}) — kutu retrosunu ajan yazar"
    return "YEŞİL", f"OK {ok} · eksik/geçersiz yok (iz bırakmamış ajan serbest)"


def k2_dersler(merkez_yol):
    if not os.path.exists(merkez_yol):
        return "KIRMIZI", "MERKEZ.md yok — merkez retrosu yazılmadı (retro.py merkez)", []
    m = open(merkez_yol, encoding="utf-8").read()
    dersler = {}
    for s in bolum(m, "Dersler"):
        d = DERS_RE.match(s.strip())
        if d and not YER_TUTUCU_RE.search(d.group(2)):
            dersler[d.group(1)] = d.group(2)
    if not dersler:
        return "KIRMIZI", "MERKEZ.md'de yazılı ders yok (## Dersler · `- M1) …`)", []
    kapsanan, bozuk = {}, []
    for s in bolum(m, "Görevler"):
        s = s.strip()
        g = GOREV_SATIR_RE.match(s)
        if g:
            gecerli, sebep = d1_gecerli(g.group(3))
            if gecerli:
                for mn in re.findall(r"M(\d+)", g.group(2)):
                    kapsanan[mn] = g.group(1)
            else:
                bozuk.append(f"{g.group(1)} D1 damgası biçimsiz: {sebep} — üretme, Sultan sözünü aktar")
            continue
    eksik = [f"M{n}" for n in dersler if n not in kapsanan]
    if eksik or bozuk:
        return "KIRMIZI", f"ders→görev D1 eksik: {', '.join(eksik) or '—'}" + (f" · {' · '.join(bozuk)}" if bozuk else ""), sorted(dersler)
    return "YEŞİL", f"{len(dersler)} ders, hepsi görev defterine D1 damgasıyla girdi", sorted(dersler)


def k4_kacis(retro, kok, hafta, merkez_yol):
    pzt, paz = retro.hafta_araligi(hafta)
    anahtarlar = {}
    kyol = os.path.join(kok, "_agents", "fabrika", "kacis-defteri.log")
    kdiz = os.path.join(kok, "_agents", "fabrika", "kartlar")
    if not os.path.exists(kyol) and not os.path.isdir(kdiz):
        return "SARI", "kaçış defteri ve fabrika kartları yok — kaçış/tıkanma ölçülemez"
    if os.path.exists(kyol):
        for s in open(kyol, encoding="utf-8", errors="replace"):
            t = retro.tarih_cek(s[:25])
            if retro.aralikta(t, pzt, paz):
                anahtarlar[s.split("|")[0].strip()] = "kaçış"
    bozuk = []
    if os.path.isdir(kdiz):
        for yol in sorted(glob.glob(os.path.join(kdiz, "*.json"))):
            try:
                k = json.load(open(yol, encoding="utf-8"))
                if not isinstance(k, dict):
                    raise ValueError("nesne değil")
            except Exception as e:
                bozuk.append(f"{os.path.basename(yol)} ({type(e).__name__})")
                continue
            if k.get("durum") == "tikandi" and retro.aralikta(retro.tarih_cek(str(k.get("bitis", ""))), pzt, paz):
                anahtarlar[f"kart:{k.get('is')}"] = "tıkanma"
    if bozuk:
        # okunamayan kart tıkanmış olabilir; görmediğimizi yeşil sayamayız
        return "SARI", f"{len(bozuk)} kart okunamadı, tıkanma kümesi eksik olabilir: {', '.join(bozuk)[:160]}"
    if not anahtarlar:
        return "YEŞİL", "bu hafta kaçış/tıkanma kaydı yok"
    if not os.path.exists(merkez_yol):
        return "KIRMIZI", f"{len(anahtarlar)} kaçış/tıkanma var, MERKEZ.md yok"
    m = open(merkez_yol, encoding="utf-8").read()
    dersler = {d.group(1) for d in (DERS_RE.match(x.strip()) for x in bolum(m, "Dersler")) if d and not YER_TUTUCU_RE.search(d.group(2))}
    damga = {}
    for s in bolum(m, "Kaçış ve tıkanma"):
        mm = KACIS_SATIR_RE.match(s.strip())
        if mm:
            damga[mm.group(1)] = mm.group(2)
    eksik = [f"{a} ({t})" for a, t in anahtarlar.items() if a not in damga]
    yok = [f"{a} → M{n} (ders yazılı değil)" for a, n in damga.items() if a in anahtarlar and n not in dersler]
    if eksik or yok:
        return "KIRMIZI", f"{len(eksik) + len(yok)}/{len(anahtarlar)} kaçış/tıkanma ders damgası almadı: {', '.join(eksik + yok)[:200]}"
    return "YEŞİL", f"{len(anahtarlar)} kaçış/tıkanma kaydının hepsi yazılı bir derse bağlı"


def k5_onay(kapanis_yol):
    """Mevcut KAPANIS.md'deki _sultan_onay satırını okur. ARAÇ ÜRETMEZ."""
    if not os.path.exists(kapanis_yol):
        return "BEKLİYOR", "", "onay satırı yok"
    for s in open(kapanis_yol, encoding="utf-8"):
        if s.startswith("_sultan_onay:"):
            v = s[len("_sultan_onay:"):].strip()
            if not v or v.startswith("("):
                return "BEKLİYOR", "", "onay satırı boş"
            gecerli, sebep = d1_gecerli(v)
            if gecerli:
                return "VAR", v, "D1 biçimli onay var (kırpık ≤15 kelime)"
            return "BİÇİMSİZ", v, f"onay satırı var ama {sebep}"
    return "BEKLİYOR", "", "onay satırı yok"


# ───────────────────────── olc ─────────────────────────
def olc(a):
    kok = os.path.abspath(a.get("--kok") or os.environ.get("RETRO_KOK") or subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip() or os.getcwd())
    retro_py = retro_py_bul(a.get("--retro-py"))
    if not retro_py:
        # aracın kendisi ölçülür: ölçüm aracı yoksa kapı "AÇIK" da "KAPANDI" da diyemez — ÖLÇÜLEMEDİ, dosya yazılmaz
        print("◻ ÖLÇÜLEMEDİ: retro becerisi yok (retro.py bulunamadı: --retro-py · HAFTA_KAPANIS_RETRO_PY · kardeş dizin · ~/.claude/skills/retro) — K1/K3/K4 ölçülemez, hafta kapanmış sayılmaz")
        return 3
    retro = retro_yukle(retro_py)
    hafta = a.get("--hafta") or retro.bu_hafta()
    diz = os.path.join(kok, "_agents", "handoff", "retro", hafta)
    merkez_yol = os.path.join(diz, "MERKEZ.md")
    kapanis_yol = os.path.join(diz, "KAPANIS.md")
    K = []
    K.append(("K1", "katılım", *k1_katilim(retro, kok, hafta, a)))
    renk2, not2, _ = k2_dersler(merkez_yol)
    K.append(("K2", "dersler → görev (D1)", renk2, not2))
    K.append(("K3", "süzüm", *k_retro(retro_py, "suzum", kok, hafta, [])))
    K.append(("K4", "kaçış/tıkanma → ders", *(k4_kacis(retro, kok, hafta, merkez_yol) if retro else ("SARI", "retro becerisi yok"))))
    onay_durum, onay_deger, onay_not = k5_onay(kapanis_yol)
    renkler = [k[2] for k in K]
    if "KIRMIZI" in renkler or onay_durum == "BİÇİMSİZ":
        durum, rc = "AÇIK", 1
    elif "SARI" in renkler:
        durum, rc = "ÖLÇÜLEMEDİ", 3
    elif onay_durum == "VAR":
        durum, rc = "KAPANDI", 0
    else:
        durum, rc = "ONAY BEKLİYOR", 5
    simdi = datetime.now().astimezone().replace(microsecond=0).isoformat()
    im = {"YEŞİL": "✓", "KIRMIZI": "✗", "SARI": "◻"}
    r = [f"# 🔒 HAFTA KAPANIŞI · {hafta}", f"_durum: {durum}", f"_olculdu: {simdi}", f"_arac: hafta-kapanis.py {SURUM}",
         f"_sultan_onay: {onay_deger or '(bekliyor — Sultan sözünü D1 biçimiyle insan aktarır; araç yazmaz)'}", "",
         "| Kapı | Ne | Renk | Not |", "|---|---|---|---|"]
    for kod, ad, renk, nt in K:
        r.append(f"| {kod} | {ad} | {im[renk]} {renk} | {nt.replace('|', '¦')} |")
    r.append(f"| K5 | Sultan onayı | {'✓ VAR' if onay_durum == 'VAR' else ('✗ BİÇİMSİZ' if onay_durum == 'BİÇİMSİZ' else '… BEKLİYOR')} | {onay_not} |")
    r += ["", {"KAPANDI": "Hafta kapandı: dört kapı yeşil, Sultan onayı D1 biçimli.",
               "ONAY BEKLİYOR": "Dört kapı yeşil. Kapanış için `_sultan_onay:` satırına Sultan'ın sözü D1 biçimiyle aktarılır (A06: araç yazmaz).",
               "AÇIK": "Hafta AÇIK: kırmızı kapı var. Eksikler ilgili ajana görev olur; ertesi gün yeniden ölçülür.",
               "ÖLÇÜLEMEDİ": "Sarı kapı var: ölçülemeyen şey kapanmış sayılmaz. Kaynağı kur, yeniden ölç."}[durum], ""]
    os.makedirs(diz, exist_ok=True)
    open(kapanis_yol, "w", encoding="utf-8").write("\n".join(r))
    print(f"{ {'KAPANDI': '✓', 'ONAY BEKLİYOR': '…', 'AÇIK': '✗', 'ÖLÇÜLEMEDİ': '◻'}[durum] } HAFTA {hafta}: {durum}")
    for kod, ad, renk, nt in K:
        print(f"  {im[renk]} {kod} {ad}: {nt}")
    print(f"  {'✓' if onay_durum == 'VAR' else '…'} K5 Sultan onayı: {onay_not}")
    print(f"  → {os.path.relpath(kapanis_yol, kok)}")
    return rc


def acik(a):
    kok = os.path.abspath(a.get("--kok") or os.environ.get("RETRO_KOK") or subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip() or os.getcwd())
    kokd = os.path.join(kok, "_agents", "handoff", "retro")
    if not os.path.isdir(kokd):
        print("◻ retro dizini yok — açık hafta ölçülemez (hiç retro yazılmamış)")
        return 3
    acik_h = []
    for d in sorted(glob.glob(os.path.join(kokd, "*-W??"))):
        h = os.path.basename(d)
        ky = os.path.join(d, "KAPANIS.md")
        durum = "KAPANIS.md yok"
        if os.path.exists(ky):
            durum = next((s.split(":", 1)[1].strip() for s in open(ky, encoding="utf-8") if s.startswith("_durum:")), "durum satırı yok")
        if durum != "KAPANDI":
            acik_h.append((h, durum))
    if acik_h:
        print(f"✗ AÇIK HAFTA: {len(acik_h)}")
        for h, d in acik_h:
            print(f"  • {h} — {d}")
        return 1
    print("✓ açık hafta yok")
    return 0


def argv_coz(argv):
    a = {}
    i = 0
    while i < len(argv):
        x = argv[i]
        if x.startswith("--"):
            if i + 1 >= len(argv):
                raise ValueError(f"{x} değer ister")
            a[x] = argv[i + 1]
            i += 1
        else:
            raise ValueError(f"fazla argüman: {x}")
        i += 1
    return a


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    try:
        if argv[0] == "olc":
            return olc(argv_coz(argv[1:]))
        if argv[0] == "acik":
            return acik(argv_coz(argv[1:]))
    except ValueError as e:
        print(f"✗ {e}")
        return 2
    print(f"✗ bilinmeyen komut: {argv[0]} (olc · acik)")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
