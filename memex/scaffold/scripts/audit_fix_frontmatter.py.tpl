#!/usr/bin/env python3
"""
Otomatik Frontmatter Eksik Doldurma — Deterministic, no AI

Frontmatter'ı eksik kavram dosyalarına template ekler. Sadece NET olarak
çıkarılabilen alanları doldurur:
- gen_id: dosya adından (`ek-garanti-sku-mapping.md` → `kavramlar.ek-garanti-sku-mapping`)
- kategori: dosya path'inden (kavramlar/, kararlar/, vs)
- son_guncelleme: dosyanın git log'undan (son commit tarihi) veya bugün
- guvenilirlik: 'orta' default (manuel review gerek)
- önem: 3 default (manuel review gerek)
- tags: []
- ilgili: []

DİKKAT: Sadece frontmatter EKLER, mevcut içeriği değiştirmez. Idempotent.

Kullanım:
    python3 audit_fix_frontmatter.py                   # gerçek fix
    python3 audit_fix_frontmatter.py --dry-run         # sadece raporla
    python3 audit_fix_frontmatter.py --cortex          # sadece Nexus
    python3 audit_fix_frontmatter.py --veri-genom      # sadece MMEpanel
"""
import os
import sys
import subprocess
from datetime import datetime
from pathlib import Path

CORTEX_PATH = Path("/Users/sultan/Desktop/y/001/Nexus/cortex/wiki")
GENOM_PATH = Path("/Users/sultan/Desktop/y/001/MMEpanel/_agents/docs/veri-genom/wiki/kavramlar")


def has_frontmatter(text: str) -> bool:
    return text.startswith("---\n") and "\n---\n" in text[4:]


def git_last_modified(filepath: Path) -> str:
    """Dosyanın git log'unda son commit tarihi (YYYY-MM-DD)."""
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%cs", str(filepath)],
            cwd=filepath.parent,
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass
    return datetime.now().strftime("%Y-%m-%d")


def gen_id_from_path(filepath: Path, repo_root: Path) -> str:
    """Path'ten gen_id türet — kullanıcı konvansiyonuna uygun.

    Cortex: 'cortex/wiki/sultan/profil.md' → 'sultan.profil'
    Veri Genom: '_agents/docs/veri-genom/wiki/kavramlar/X.md' → 'kavramlar.X'
    """
    rel = filepath.relative_to(repo_root)
    parts = list(rel.parts)
    # 'cortex' / 'wiki' / 'docs' / 'veri-genom' / '_agents' prefiksini at
    PREFIX_NOISE = {"cortex", "wiki", "docs", "veri-genom", "_agents"}
    parts = [p for p in parts if p not in PREFIX_NOISE]
    # Son eleman dosya, .md uzantısını at
    if parts and parts[-1].endswith(".md"):
        parts[-1] = parts[-1][:-3]
    return ".".join(parts)


def make_frontmatter(filepath: Path, repo_root: Path, kategori: str = "kavram") -> str:
    """Eksik frontmatter için minimum template."""
    gen_id = gen_id_from_path(filepath, repo_root)
    son_guncelleme = git_last_modified(filepath)
    return f"""---
gen_id: {gen_id}
kategori: {kategori}
son_guncelleme: {son_guncelleme}
guvenilirlik: orta
önem: 3
tags: []
ilgili: []
---

"""


def fix_file(filepath: Path, repo_root: Path, dry_run: bool) -> bool:
    """Frontmatter eksikse ekle. True = değişiklik yapıldı."""
    text = filepath.read_text(encoding="utf-8")
    if has_frontmatter(text):
        return False

    # Kategori: parent klasör adından (kavramlar, kararlar, konular, vs)
    KNOWN_CATEGORIES = {"kavramlar", "kararlar", "konular", "sultan", "nexus", "mmepanel",
                        "baglantilar", "aksiyonlar", "kaynaklar", "kesifler", "kesif-rehberi",
                        "ic-veri-modeli"}
    parent = filepath.parent.name
    if parent in KNOWN_CATEGORIES:
        kategori = parent
    else:
        kategori = "kavram"

    fm = make_frontmatter(filepath, repo_root, kategori)

    # Eğer dosya '# Başlık' ile başlıyorsa, frontmatter'ı oraya ekle
    new_text = fm + text

    if dry_run:
        print(f"  [DRY] {filepath.name} → frontmatter eklenecek (gen_id={gen_id_from_path(filepath, repo_root)})")
        return True

    filepath.write_text(new_text, encoding="utf-8")
    print(f"  ✓ {filepath.name} → frontmatter eklendi")
    return True


def process_repo(name: str, path: Path, repo_root: Path, dry_run: bool):
    if not path.exists():
        print(f"  ⚠️ {path} bulunamadı")
        return

    files = sorted(path.glob("**/*.md"))
    print(f"\n=== {name} ({len(files)} dosya) ===")

    fixed = 0
    skipped = 0
    for f in files:
        if fix_file(f, repo_root, dry_run):
            fixed += 1
        else:
            skipped += 1
    action = "Eklenecek" if dry_run else "Eklendi"
    print(f"  Özet: {fixed} {action}, {skipped} zaten var")


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    only_cortex = "--cortex" in args
    only_genom = "--veri-genom" in args

    print(f"🔧 Frontmatter Fix — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    if dry_run:
        print("⚠️  DRY-RUN — dosya yazılmayacak")

    if not only_genom:
        process_repo("Cortex", CORTEX_PATH, Path("/Users/sultan/Desktop/y/001/Nexus"), dry_run)
    if not only_cortex:
        process_repo("Veri Genom", GENOM_PATH, Path("/Users/sultan/Desktop/y/001/MMEpanel"), dry_run)

    print()


if __name__ == "__main__":
    main()
