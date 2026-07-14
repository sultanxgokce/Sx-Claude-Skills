#!/usr/bin/env python3
"""gereklilik.py — GEREKLILIK.md parser + politika-denetimi (tescil lib; DİVAN K5, k0054).

Kullanım: gereklilik.py parse <GEREKLILIK.md>
Stdout: normalize JSON (kart/goal/tip/vites/g[]/oznel_sayisi/gereklilik_sha256 + red|null).
RC: 0 = parse başarılı (politika-ihlali varsa JSON `red` alanında — karar tescil-run.sh'ta),
    2 = dosya-okunamadı/harness.

Politika (SKILL.md §1-2-4):
- G yok / KART-TIP eksik ................................. red: gereklilik-eksik
- ≥1 DAVRANIŞ-G yok (davranis:evet ∨ tur∈{api,e2e}) ...... red: gereklilik-jenerik
- TIP=ui → ≥1 e2e-check G şart (mock-only yeşil yasak) ... red: gereklilik-jenerik
- TIP=kod → ≥1 api-check|e2e-check G şart (tsc yetmez) ... red: gereklilik-jenerik
- VITES=HAFIF → tek-G + tek-kanıt meşru (G-sayısı şartı yok; davranış-G şartı geçerli)
- tur=llm-yargi → rubrik zorunlu (Katman-2)
"""
import hashlib
import json
import re
import sys

TIPLER = ("ui", "kod", "docs")
VITESLER = ("TAM", "HAFIF")
TURLER = ("cmd", "api-check", "e2e-check", "llm-yargi")
DAVRANIS_TURLERI = ("api-check", "e2e-check")

G_BASLIK = re.compile(r"^G(\d+):\s*(.*)$")
ALAN = re.compile(r"^\s+([a-z_]+):\s*(.*)$")
BASLIK_ALAN = re.compile(r"^(KART|GOAL|TIP|VITES):\s*(.*)$")


def parse(metin):
    kart = goal = None
    tip = vites = None
    gler = []
    aktif = None
    for satir in metin.splitlines():
        if satir.strip().startswith("#"):
            continue
        m = G_BASLIK.match(satir)
        if m:
            aktif = {
                "id": f"G{m.group(1)}",
                "aciklama": m.group(2).strip(),
                "tur": "cmd",
                "komut": None,
                "beklenen_rc": 0,
                "beklenen_desen": None,
                "davranis": False,
                "cwd": None,
                "rubrik": None,
            }
            gler.append(aktif)
            continue
        m = BASLIK_ALAN.match(satir)
        if m:
            anahtar, deger = m.group(1), m.group(2).strip()
            if anahtar == "KART":
                kart = deger
            elif anahtar == "GOAL":
                goal = deger
            elif anahtar == "TIP":
                tip = deger.lower()
            elif anahtar == "VITES":
                vites = deger.upper()
            aktif = None
            continue
        if aktif is not None:
            m = ALAN.match(satir)
            if m:
                anahtar, deger = m.group(1), m.group(2).strip()
                if anahtar == "beklenen_rc":
                    try:
                        aktif["beklenen_rc"] = int(deger)
                    except ValueError:
                        aktif["beklenen_rc"] = None  # politika-denetimi yakalar
                elif anahtar == "davranis":
                    aktif["davranis"] = deger.lower() in ("evet", "true", "1")
                elif anahtar in ("tur", "komut", "beklenen_desen", "cwd", "rubrik"):
                    aktif[anahtar] = deger
    return kart, goal, tip, vites, gler


def politika(kart, goal, tip, vites, gler):
    """(red_adi|None, sebepler[]) döner."""
    eksik = []
    if not kart:
        eksik.append("KART: satırı yok")
    if not goal:
        eksik.append("GOAL: satırı yok")
    if tip not in TIPLER:
        eksik.append(f"TIP geçersiz/eksik: {tip!r} (ui|kod|docs)")
    if vites not in VITESLER:
        eksik.append(f"VITES geçersiz/eksik: {vites!r} (TAM|HAFIF)")
    if not gler:
        eksik.append("hiç G-satırı yok")
    for g in gler:
        if g["tur"] not in TURLER:
            eksik.append(f"{g['id']}: geçersiz tur {g['tur']!r}")
        if g["tur"] == "llm-yargi":
            if not g["rubrik"]:
                eksik.append(f"{g['id']}: llm-yargi için rubrik zorunlu (izole-rubrik)")
        elif not g["komut"]:
            eksik.append(f"{g['id']}: komut eksik")
        if g["beklenen_rc"] is None:
            eksik.append(f"{g['id']}: beklenen_rc sayı değil")
    if eksik:
        return "gereklilik-eksik", eksik

    jenerik = []
    davranis_var = any(g["davranis"] or g["tur"] in DAVRANIS_TURLERI for g in gler)
    if not davranis_var:
        jenerik.append(
            "≥1 DAVRANIŞ-G yok — yalnız tsc/vitest/dosya-var sınıfı jenerik-G "
            "(davranis: evet ya da tur: api-check|e2e-check gerekli)"
        )
    if tip == "ui" and not any(g["tur"] == "e2e-check" for g in gler):
        jenerik.append("TIP=ui: ≥1 e2e-check G şart (kesif DOM↔API; mock-only yeşil YASAK)")
    if tip == "kod" and not any(g["tur"] in DAVRANIS_TURLERI for g in gler):
        jenerik.append("TIP=kod: ≥1 api-check|e2e-check G şart (tsc/build/lint YETMEZ)")
    if jenerik:
        return "gereklilik-jenerik", jenerik
    return None, []


def main():
    if len(sys.argv) != 3 or sys.argv[1] != "parse":
        sys.stderr.write("kullanım: gereklilik.py parse <GEREKLILIK.md>\n")
        return 2
    try:
        with open(sys.argv[2], "r", encoding="utf-8") as f:
            metin = f.read()
    except OSError as e:
        sys.stderr.write(f"gereklilik.py: dosya okunamadı: {e}\n")
        return 2
    kart, goal, tip, vites, gler = parse(metin)
    red_adi, sebepler = politika(kart, goal, tip, vites, gler)
    cikti = {
        "kart": kart,
        "goal": goal,
        "tip": tip,
        "vites": vites,
        "gereklilik_sha256": hashlib.sha256(metin.encode("utf-8")).hexdigest(),
        "g": gler,
        "oznel_sayisi": sum(1 for g in gler if g["tur"] == "llm-yargi"),
        "red": {"ad": red_adi, "sebepler": sebepler} if red_adi else None,
    }
    json.dump(cikti, sys.stdout, ensure_ascii=False, indent=1)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
