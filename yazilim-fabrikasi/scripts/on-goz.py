#!/usr/bin/env python3
"""on-goz.py — bağımsız göze göndermeden önce yazanın MEKANİK ön göz kapıları (görev W42-E1 …W7H1EBA · tasarım Nexus
_agents/spec/on-goz-adimi-DESIGN.md, dilim 2). Model çağrısı yok; saniyeler. Denetime bağlanmaz (bağlama ve fail-closed dilim 3).

Kullanım (iş alanından): on-goz.py <iş> [--pr N] [--depo DİZİN] [--json]
Kapılar (ölçülen tasarım sınıfları: kanıt başı %32 · kanıt eksik %13 · kapsam %26 · bugünkü rc 3 vakaları):
  A1 kanıt başı — KANIT.json'daki GEÇERLİ (geçersiz ilan edilmemiş) kayıtlardan 'once' olmayanların olculen_commit'i HEAD'e eşit ya da
                  arada yalnız _agents/**/kanit/** dosyası değişmiş. 'once' kayıtları muaftır (tanımı gereği düzeltmeden önceki kodu ölçer).
                  --pr verilirse PR başı (gh) = HEAD; verilmezse dal origin'e itilmişse origin/<dal> = HEAD ('önce it').
  A2 kanıt eksik — kanıt dizini ve KANIT.json var · `kanit.sh dogrula` yeşil (imza + sha) · en az bir geçerli gerçek (mutant olmayan) ölçüm ·
                  her mutant kaydı hedef kapı (hedef_kapi) taşır ve o kapı düşmüştür (hedef_dustu).
  A3 taban     — dal tabanın (ON_GOZ_TABAN, varsayılan origin/main) gerisindeyse birleştirme ÇAKIŞIYOR mu (git merge-tree).
                  Yalnız geride olmak bilgidir (ana dal hızlı ilerler; her işi sürekli birleştirmeye zorlamak tasarımın amacı değil).
  A4 ağaç      — commit'lenmemiş İZLENEN dosya; aracın kendi defterleri (kanıt dizini · kartlar · karne · tavan defteri) hariç — denetci.sh'in
                  kirli-ağaç kontrolüyle aynı küme.
  A5 kapsam    — kart cümlesinde 'dışında / dışı / ayrı kart / dokunulmaz / dokunmaz / değişmez' geçen bölümdeki yol ya da dosya adı
                  dalın farkında (taban...HEAD) BİLEŞEN olarak geçiyorsa (tam yol · yol sonu · dizin altı · yalın ad = dosya adı; alt dize değil).
Hüküm: beşinden biri uyumsuz → rc 1 (ne düzeltileceği satır satır) · biri ölçülemedi, hiçbiri uyumsuz değil → rc 3 · beşi uyumlu → rc 0 ·
kullanım hatası rc 2. Ölçülemedi uyumlu sayılmaz.
"""
import argparse, json, os, re, subprocess, sys

HDIR = os.path.dirname(os.path.abspath(__file__))
KANIT_DESEN = re.compile(r"^_agents/fabrika/kanit/")
DEFTER_HARIC = ("_agents/fabrika/kanit", "_agents/fabrika/kartlar", "_agents/fabrika/karne.jsonl", "_agents/fabrika/tavan-defteri.log")   # A4: aracın kendi defterleri   # A4 ve kanit.py ile AYNI tanım (göz tur 2 ön-gözü: A1 daha genişti)
KAPSAM_SOZ = re.compile(r"dışında|dışı\b|ayrı kart|dokunulmaz|dokunmaz|değişmez", re.I)
YOL_DESEN = re.compile(r"[\w.\-]+(?:/[\w.\-]+)+|[\w\-]+\.(?:py|sh|md|json|jsonl|mjs|js|ts|tsx|yml|yaml|log|tsv|txt|html|css)\b")


def git(depo, *a, ok=False):
    r = subprocess.run(["git", "-C", depo, *a], capture_output=True, text=True)
    if ok:
        return r
    return r.stdout.strip() if r.returncode == 0 else None


def kapi(ad, durum, satirlar):
    return {"ad": ad, "durum": durum, "satirlar": satirlar}


def kanit_kayitlari(dz):
    p = os.path.join(dz, "KANIT.json")
    if not os.path.exists(p):
        return None
    sys.path.insert(0, HDIR)
    from kanit import etkin_kayitlar
    # etkin_kayitlar süzmez, İŞARETLER: geçersiz ilan edilen kayıt etkin_renk='gecersiz', ilanın kendisi 'ilan' — ikisi de kanıt sayılmaz
    return [k for k in etkin_kayitlar(json.load(open(p, encoding="utf-8"))) if k.get("etkin_renk") not in ("gecersiz", "ilan")]


def a1(depo, kayitlar, pr):
    head = git(depo, "rev-parse", "HEAD")
    if not head:
        return kapi("A1 kanıt başı", "olculemedi", ["HEAD okunamadı"])
    out, olc = [], []
    for k in kayitlar or []:
        oc = k.get("olculen_commit")
        if not oc or k.get("asama") == "once":
            continue
        if oc == head:
            continue
        fark = git(depo, "diff", "--name-only", oc, head)
        if fark is None:
            out.append(f"'{k.get('etiket')}' kaydı {oc[:8]}'de ölçülmüş, bu commit depoda yok — kanıtı HEAD'de yeniden al"); continue
        kod = [f for f in fark.splitlines() if f and not KANIT_DESEN.match(f)]
        if kod:
            out.append(f"'{k.get('etiket')}' ({k.get('asama') or ('mutant' if k.get('mutasyon') else '-')}) {oc[:8]}'de ölçülmüş, HEAD {head[:8]}; "
                       f"arada kanıt dışı {len(kod)} dosya ({', '.join(kod[:3])}{' …' if len(kod) > 3 else ''}) — kanıtı HEAD'de yeniden al")
    if pr:
        r = subprocess.run(["gh", "pr", "view", str(pr), "--json", "headRefOid", "-q", ".headRefOid"], cwd=depo, capture_output=True, text=True)
        prbas = r.stdout.strip() if r.returncode == 0 else ""
        if not prbas:
            olc.append(f"PR #{pr} başı okunamadı (gh rc {r.returncode})")
        elif prbas != head:
            out.append(f"PR #{pr} başı {prbas[:8]} ≠ HEAD {head[:8]} — önce it (PR başı GitHub'da birkaç dakika geç güncellenebilir)")
    else:
        # Kart: "dal itilmişse ORIGIN dalı = HEAD" — izlenen uzak (@{u}) başka bir uzak olabilir (göz tur 1); origin'deki aynı adlı dal kıyaslanır.
        dal = git(depo, "symbolic-ref", "--short", "-q", "HEAD")
        up = git(depo, "rev-parse", "--verify", "-q", f"refs/remotes/origin/{dal}") if dal else None
        if up and up != head:
            out.append(f"origin/{dal} {up[:8]} ≠ HEAD {head[:8]} — önce it")
    if out:
        return kapi("A1 kanıt başı", "uyumsuz", out)
    if olc:
        return kapi("A1 kanıt başı", "olculemedi", olc)
    return kapi("A1 kanıt başı", "uyumlu", [f"geçerli kayıtlar HEAD {head[:8]} ile aynı (ya da arada yalnız kanıt)"])


def a2(depo, is_adi, dz, kayitlar, okunamadi=None):
    if okunamadi:
        return kapi("A2 kanıt eksik", "olculemedi", [f"KANIT.json okunamadı ({okunamadi}) — kanıt yok DENMEZ"])
    if kayitlar is None:
        return kapi("A2 kanıt eksik", "uyumsuz", [f"kanıt yok: {os.path.relpath(dz, depo)}/KANIT.json — önce kanit.sh olcum"])
    out = []
    r = subprocess.run(["bash", os.path.join(HDIR, "kanit.sh"), "dogrula", is_adi], cwd=depo, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    if r.returncode != 0:
        son = [x for x in (r.stdout + r.stderr).splitlines() if x.strip()][-1:] or ["?"]
        out.append(f"kanit.sh dogrula rc {r.returncode}: {son[0][:160]}")
    if not [k for k in kayitlar if k.get("tur") == "olcum" and not k.get("mutasyon")]:
        out.append("geçerli gerçek ölçüm kaydı yok (mutantlar ve geçersiz ilanlar sayılmaz) — önce kanit.sh olcum")
    for k in kayitlar:
        if not k.get("mutasyon"):
            continue
        if not (k.get("hedef_kapi") or k.get("kapi")):
            out.append(f"mutant kaydı '{k.get('etiket')}' hedef kapı taşımıyor — --kapi <düşmesi gereken kapı> ile yeniden al")
        elif k.get("hedef_dustu") is False:
            out.append(f"mutant kaydı '{k.get('etiket')}' hedef kapısı ({k.get('hedef_kapi') or k.get('kapi')}) DÜŞMEDİ — sınav o kapıyı ölçmüyor")
    return kapi("A2 kanıt eksik", "uyumsuz" if out else "uyumlu", out or [f"{len(kayitlar)} geçerli kayıt, manifest doğrulandı"])


def taban_ref(depo):
    t = os.environ.get("ON_GOZ_TABAN", "origin/main")
    return t if git(depo, "rev-parse", "--verify", "-q", t) else None


def a3(depo):
    t = taban_ref(depo)
    if not t:
        return kapi("A3 taban", "olculemedi", [f"taban {os.environ.get('ON_GOZ_TABAN', 'origin/main')} okunamadı"])
    r = git(depo, "merge-base", "--is-ancestor", t, "HEAD", ok=True)
    if r.returncode == 0:
        return kapi("A3 taban", "uyumlu", [f"dal {t} üstünde"])
    geri = git(depo, "rev-list", "--count", f"HEAD..{t}") or "?"
    m = git(depo, "merge-tree", "--write-tree", "--name-only", "HEAD", t, ok=True)
    if m.returncode == 1:
        dosya = [x for x in m.stdout.splitlines()[1:] if x and not x.startswith(("Auto-merging", "CONFLICT"))]
        return kapi("A3 taban", "uyumsuz", [f"{t} {geri} commit ileride ve birleştirme ÇAKIŞIYOR ({', '.join(dosya[:4]) or '?'}) — önce merge (rebase değil, dal itilmiş)"])
    if m.returncode != 0:
        return kapi("A3 taban", "olculemedi", [f"git merge-tree rc {m.returncode}"])
    return kapi("A3 taban", "uyumlu", [f"bilgi: {t} {geri} commit ileride, çakışma yok"])


def a4(depo):
    # Hariç küme denetci.sh'in kendi kirli-ağaç kontrolüyle AYNI (kanit/ · kartlar/ · karne.jsonl · tavan-defteri.log): bunlar aracın kendi
    # defterleridir — denetçi --reis-devam turunda tavan satırını kendisi yazar; A4 onu kirli sayınca zorunlu kipte devam turu kendi
    # yazımıyla kapanırdı (ölçüm: Sx #739 DENETIM-4 on_goz.agac=uyumsuz, kart on-goz-a4-defter).
    r = git(depo, "status", "--porcelain", "--untracked-files=no", "--", ":/", *(f":(top,exclude){y}" for y in DEFTER_HARIC), ok=True)
    if r.returncode != 0:
        return kapi("A4 ağaç", "olculemedi", [f"git status rc {r.returncode}"])
    kirli = [x[3:] for x in r.stdout.splitlines() if x.strip()]
    if kirli:
        return kapi("A4 ağaç", "uyumsuz", [f"commit'lenmemiş izlenen dosya: {', '.join(kirli[:5])}{' …' if len(kirli) > 5 else ''} — commit'le ya da geri al"])
    return kapi("A4 ağaç", "uyumlu", ["kanıt dışı commit'lenmemiş izlenen dosya yok"])


def kart_bul(depo, is_adi):
    ortak = git(depo, "rev-parse", "--path-format=absolute", "--git-common-dir")
    adaylar = [os.path.join(depo, "_agents", "fabrika", "kartlar", f"{is_adi}.json")]
    if ortak:
        adaylar.append(os.path.join(os.path.dirname(ortak), "_agents", "fabrika", "kartlar", f"{is_adi}.json"))
    for p in adaylar:
        if os.path.exists(p):
            return p
    return None


def yol_eslesir(f, y):
    """Kapsam dışı yol y farktaki dosya f'ye BİLEŞEN olarak denk mi (alt dize değil — göz tur 1: 'od.txt' 'kod.txt'i vurmamalı):
    tam yol · yolun sonu ('/'+y) · y bir dizinse altı · y yalın dosya adıysa f'nin adı."""
    y = y.strip("/")
    return f == y or f.endswith("/" + y) or f.startswith(y + "/") or ("/" not in y and os.path.basename(f) == y)


def a5(depo, is_adi):
    kp = kart_bul(depo, is_adi)
    if not kp:
        return kapi("A5 kapsam", "olculemedi", ["kart bulunamadı (iş alanı ya da birincil depo)"])
    try:
        cumle = json.load(open(kp, encoding="utf-8")).get("cumle") or ""
    except (OSError, ValueError):
        return kapi("A5 kapsam", "olculemedi", ["kart okunamadı"])
    yasak = set()
    for parca in re.split(r"[;·()\[\]]|, ", cumle):
        if KAPSAM_SOZ.search(parca):
            yasak.update(m.group(0).strip(".-") for m in YOL_DESEN.finditer(parca))
    yasak.discard("")
    if not yasak:
        return kapi("A5 kapsam", "uyumlu", ["kart cümlesi kapsam dışı yol anmıyor"])
    t = taban_ref(depo)
    fark = git(depo, "diff", "--name-only", f"{t}...HEAD") if t else None
    if fark is None:
        return kapi("A5 kapsam", "olculemedi", ["dalın farkı okunamadı (taban yok)"])
    vur = sorted({f"{f} ← '{y}'" for f in fark.splitlines() for y in yasak if yol_eslesir(f, y)})
    if vur:
        return kapi("A5 kapsam", "uyumsuz", [f"kart cümlesinde kapsam dışı denen yol farkta: {', '.join(vur[:4])} — dosyayı çıkar ya da kartı daralt"])
    return kapi("A5 kapsam", "uyumlu", [f"kapsam dışı yollar ({', '.join(sorted(yasak)[:4])}) farkta yok"])


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("is_adi"); ap.add_argument("--pr"); ap.add_argument("--depo"); ap.add_argument("--json", action="store_true")
    try:
        a = ap.parse_args()
    except SystemExit as e:
        return 0 if e.code == 0 else 2
    depo = git(a.depo or os.getcwd(), "rev-parse", "--show-toplevel")
    if not depo:
        print("ÖLÇÜLEMEDİ: git ağacı değil", file=sys.stderr); return 3
    dz = os.path.join(depo, "_agents", "fabrika", "kanit", a.is_adi)
    okunamadi = None
    try:
        kayitlar = kanit_kayitlari(dz)
    except Exception as e:   # bozuk KANIT.json ya da kanit modülü yüklenemedi: ÖLÇÜLEMEDİ (rc 3), "kanıt yok" (rc 1) değil — göz tur 2 ön-gözü
        kayitlar = None; okunamadi = type(e).__name__
    a1k = kapi("A1 kanıt başı", "olculemedi", [f"KANIT.json okunamadı ({okunamadi})"]) if okunamadi else a1(depo, kayitlar, a.pr)
    kapilar = [a1k, a2(depo, a.is_adi, dz, kayitlar, okunamadi), a3(depo), a4(depo), a5(depo, a.is_adi)]
    durumlar = [k["durum"] for k in kapilar]
    hukum = "uyumsuz" if "uyumsuz" in durumlar else "olculemedi" if "olculemedi" in durumlar else "uyumlu"
    if a.json:
        print(json.dumps({"is": a.is_adi, "durum": hukum, "kapilar": kapilar}, ensure_ascii=False))
    else:
        isaret = {"uyumlu": "✓", "uyumsuz": "✗", "olculemedi": "○"}
        for k in kapilar:
            print(f"  {isaret[k['durum']]} {k['ad']}: {k['satirlar'][0] if k['satirlar'] else ''}")
            for s in k["satirlar"][1:]:
                print(f"      {s}")
        print(f"ÖN GÖZ (mekanik): {dict(uyumlu='UYUMLU', uyumsuz='UYUMSUZ', olculemedi='ÖLÇÜLEMEDİ')[hukum]}" + ("" if hukum == "uyumlu" else " — ölçülemeyen uyumlu sayılmaz" if hukum == "olculemedi" else " — göze göndermeden önce düzelt"))
    return {"uyumlu": 0, "uyumsuz": 1, "olculemedi": 3}[hukum]


if __name__ == "__main__":
    sys.exit(main())
