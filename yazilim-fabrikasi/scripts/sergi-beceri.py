#!/usr/bin/env python3
"""sergi-beceri.py — filodaki bütün becerilerin kataloğunu üretir (var olan `sergi` becerisiyle basılır).

NİÇİN: Sultan 21 Eyl 2026: "tüm ai skillerimizi görebileceğimiz bir katalog /sergi, canlıya alalım".
Yeni katalog motoru YAZILMAZ — `sergi` becerisi (Sultan'ın beğendiği düzen) basar; bu betik yalnız
onun veri sözleşmesine uygun manifesti üretir ve SKILL.md dosyalarını yanına koyar.

Kaynaklar (üçü de ölçülür, tahmin yok):
  1. Sx-Claude-Skills/catalog.json  → kanonik kayıt (sürüm, tür, aile, durum, kaynak)
  2. /config/.claude/skills/*/SKILL.md → filoda GERÇEKTEN kurulu olanlar (ön-blok: name/version/description)
  3. <depo>/.claude/skills/*/SKILL.md → depo-yerel beceriler (yalnız görülebilen depolar)
Katalogda olup kurulu olmayan = "kurulmamış"; kurulu olup katalogda olmayan = "ÖKSÜZ" (L46 dersi:
kayıt var çağıran yok / çağıran var kayıt yok — ikisi de görünür olsun).

Kullanım:
  sergi-beceri.py --sx <Sx-Claude-Skills-kökü> --out <çıktı-dizini> [--depo <ad>=<yol> ...] [--kuru]
Çıktı: <out>/manifest.json + <out>/dosyalar/<id>/SKILL.md ; sonra:
  python3 /config/.claude/skills/sergi/scripts/build_catalog.py <out>/manifest.json --out <out>/katalog
rc: 0 üretildi · 2 kullanım · 3 kaynak okunamadı
"""
import argparse, datetime, json, os, re, shutil, subprocess, sys

GLOBAL = "/config/.claude/skills"


def onblok(yol):
    """SKILL.md YAML ön-bloğundan name/version/description/type/tags — bağımlılıksız, kaba ama yeterli."""
    try:
        s = open(yol, encoding="utf-8").read()
    except Exception:
        return {}
    m = re.match(r"^---\n(.*?)\n---", s, re.S)
    if not m:
        return {}
    d = {}
    blok = m.group(1)
    for k in ("name", "version", "type", "author"):
        mm = re.search(rf"^{k}:\s*(.+?)\s*$", blok, re.M)
        if mm: d[k] = mm.group(1).strip().strip('"\'')
    md = re.search(r"^description:\s*>?-?\s*\n((?:[ \t]+.*\n?)+)", blok, re.M)
    if md:
        d["description"] = " ".join(l.strip() for l in md.group(1).splitlines())
    else:
        md = re.search(r"^description:\s*(.+)$", blok, re.M)
        if md: d["description"] = md.group(1).strip().strip('"\'')
    mt = re.search(r"^tags:\s*\[(.*?)\]", blok, re.M)
    if mt: d["tags"] = [t.strip().strip('"\'') for t in mt.group(1).split(",") if t.strip()]
    return d


def git_tarih(kok, alt):
    try:
        return subprocess.check_output(["git", "-C", kok, "log", "-1", "--format=%cs", "--", alt], text=True, stderr=subprocess.DEVNULL).strip() or ""
    except Exception:
        return ""


def kisalt(s, n=220):
    s = re.sub(r"\s+", " ", s or "").strip()
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--sx", required=True); p.add_argument("--out", required=True)
    p.add_argument("--depo", action="append", default=[], help="ad=yol (depo-yerel .claude/skills taraması)")
    p.add_argument("--kuru", action="store_true")
    a = p.parse_args()

    kat_yol = os.path.join(a.sx, "catalog.json"); st_yol = os.path.join(a.sx, "sync-targets.json")
    if not os.path.isfile(kat_yol):
        print(f"✗ catalog.json yok: {kat_yol}", file=sys.stderr); return 3
    katalog = {s["id"]: s for s in json.load(open(kat_yol, encoding="utf-8"))["skills"]}
    kurulum = json.load(open(st_yol, encoding="utf-8")).get("install", {}) if os.path.isfile(st_yol) else {}
    kurulu = {d: os.path.join(GLOBAL, d, "SKILL.md") for d in sorted(os.listdir(GLOBAL))
              if os.path.isfile(os.path.join(GLOBAL, d, "SKILL.md"))} if os.path.isdir(GLOBAL) else {}

    items = []; dosyalar = {}
    say = {"katalog+kurulu": 0, "katalog-kurulmamis": 0, "oksuz": 0, "depo-yerel": 0}

    def ekle(id_, baslik, kategori, tur, notu, skill_md, tags, tarih, surum, kaynak):
        items.append({"id": id_, "title": baslik, "category": kategori, "kind": tur, "note": kisalt(notu) or "Açıklama yok.",
                      "file": f"dosyalar/{id_}/SKILL.md", "tags": [t for t in tags if t][:12], "date": tarih or "",
                      "license": "Filo içi (Sx-Claude-Skills)" if kaynak == "sx" else "Bilinmiyor"})
        dosyalar[id_] = skill_md

    # 1+2 · katalog ∪ kurulu (küresel)
    for sid in sorted(set(katalog) | set(kurulu)):
        k = katalog.get(sid); kur = kurulu.get(sid)
        kyol = os.path.join(a.sx, (k or {}).get("path") or f"{sid}/SKILL.md") if k else None   # bazı kayıtlarda path YOK
        fm = onblok(kur) if kur else (onblok(kyol) if kyol and os.path.isfile(kyol) else {})
        skill_md = kur or kyol
        if not skill_md or not os.path.isfile(skill_md):
            continue
        surum = fm.get("version") or (k or {}).get("version") or "?"
        hedefler = kurulum.get(sid, [])
        if k and kur:
            kat = "Küresel beceri"; say["katalog+kurulu"] += 1
            durum_tag = "kurulu:" + ",".join(hedefler or ["_global"])
        elif k:
            kat = "Katalogda var, kurulu değil"; say["katalog-kurulmamis"] += 1; durum_tag = "kurulmamış"
        else:
            kat = "Öksüz (kurulu, katalog dışı)"; say["oksuz"] += 1; durum_tag = "öksüz"
        tur = (k or {}).get("type") or fm.get("type") or "beceri"
        baslik = (k or {}).get("name") or fm.get("name") or sid
        notu = fm.get("description") or (k or {}).get("description") or ""
        tags = [f"v{surum}", durum_tag, tur] + list((k or {}).get("tags", []) or fm.get("tags", []))
        if k and k.get("status"): tags.append(k["status"])
        tarih = git_tarih(a.sx, os.path.dirname(os.path.relpath(kyol, a.sx))) if k else ""
        ekle(sid, baslik, kat, tur, notu, skill_md, tags, tarih, surum, "sx" if k else "yerel")

    # 3 · depo-yerel
    for spec in a.depo:
        ad, _, yol = spec.partition("=")
        kok = os.path.join(yol, ".claude", "skills")
        if not os.path.isdir(kok):
            print(f"· {ad}: .claude/skills yok, atlandı", file=sys.stderr); continue
        for d in sorted(os.listdir(kok)):
            md = os.path.join(kok, d, "SKILL.md")
            if not os.path.isfile(md): continue
            fm = onblok(md); sid = f"{ad}-{d}"
            if sid in dosyalar: continue
            say["depo-yerel"] += 1
            ekle(sid, f"{fm.get('name') or d} ({ad})", f"Depo-yerel · {ad}", fm.get("type") or "beceri", fm.get("description", ""),
                 md, [f"v{fm.get('version','?')}", f"depo:{ad}", "depo-yerel"] + fm.get("tags", []), git_tarih(yol, os.path.join(".claude", "skills", d)), fm.get("version", "?"), "yerel")

    manifest = {"title": "Beceri Sergisi", "subtitle": f"Filodaki AI becerileri — küresel {say['katalog+kurulu']} · öksüz {say['oksuz']} · kurulmamış {say['katalog-kurulmamis']} · depo-yerel {say['depo-yerel']}",
                "language": "tr", "collected_at": datetime.date.today().isoformat(), "items": items}
    print(f"sayım: {say} · toplam {len(items)}")
    if a.kuru:
        print("KURU: manifest yazılmadı"); return 0
    os.makedirs(a.out, exist_ok=True)
    for sid, src in dosyalar.items():
        h = os.path.join(a.out, "dosyalar", sid); os.makedirs(h, exist_ok=True); shutil.copyfile(src, os.path.join(h, "SKILL.md"))
    with open(os.path.join(a.out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"✓ manifest: {os.path.join(a.out, 'manifest.json')} · {len(items)} kayıt · dosyalar/ kopyalandı")
    return 0


if __name__ == "__main__":
    sys.exit(main())
