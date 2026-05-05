#!/usr/bin/env python3
"""
Hafıza Audit Otomatik Snapshot — KPI sayım, no AI

Bu script haftalık cron ile çalışır. Cortex (Nexus) + Veri Genom (MMEpanel)
için KPI'ları hesaplar, _audit_history.md'ye trend olarak ekler.

LLM yargısı YOK — sadece deterministic metrics (frontmatter var/yok,
dosya boyutu, link sayısı, açık soru pattern eşleşmesi).

Tamirat (frontmatter normalize, dedup) için /memory-audit fix slash komutu
manuel çalıştırılmalı.

Kullanım:
    python3 audit_snapshot.py                    # her iki repo
    python3 audit_snapshot.py --cortex           # sadece Nexus
    python3 audit_snapshot.py --veri-genom       # sadece MMEpanel
    python3 audit_snapshot.py --dry-run          # yazma, sadece raporla

Cron örneği (macOS launchd / crontab):
    0 7 * * 1  /usr/bin/python3 /Users/sultan/Desktop/y/001/Nexus/scripts/audit_snapshot.py
"""
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from collections import defaultdict

CORTEX_PATH = Path("/Users/sultan/Desktop/y/001/Nexus/cortex/wiki")
GENOM_PATH = Path("/Users/sultan/Desktop/y/001/MMEpanel/_agents/docs/veri-genom/wiki/kavramlar")

OPEN_QUESTION_PATTERNS = [
    r"^S\d+:",
    r"^\*\*Açık soru\*\*",
    r"^\?:",
    r"❓",
    r"\[ \]\s+(beklemede|todo|yapılacak)",
]


def parse_frontmatter(text: str) -> dict | None:
    """Markdown başındaki YAML frontmatter'ı dict olarak döner.
    Multi-line list field'ları (- item) destekler."""
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None
    block = text[4:end]
    fm = {}
    current_key = None
    current_list = []
    for line in block.split("\n"):
        if not line.strip():
            continue
        # Sub-list item: "  - foo" veya "- foo"
        if line.lstrip().startswith("- ") and current_key:
            current_list.append(line.lstrip()[2:].strip())
            continue
        # Yeni key:value
        if ":" in line and not line.startswith(" "):
            # Önceki listeyi flush et
            if current_key and current_list:
                fm[current_key] = current_list
                current_list = []
            k, _, v = line.partition(":")
            k = k.strip()
            v = v.strip()
            if v:  # tek satır value
                fm[k] = v
                current_key = None
            else:  # multi-line list başlangıcı
                current_key = k
                current_list = []
    # Son listeyi flush et
    if current_key and current_list:
        fm[current_key] = current_list
    return fm


def count_links(text: str, all_files: set[str]) -> tuple[int, set[str]]:
    """Markdown link sayısı + hangi dosyalara referans var."""
    # [text](path.md) ve [[wikilink]] her ikisi
    md_links = re.findall(r"\[(?:[^\]]+)\]\(([^)]+\.md)\)", text)
    wiki_links = re.findall(r"\[\[([^\]]+)\]\]", text)
    refs = set()
    for link in md_links + [w + ".md" for w in wiki_links]:
        # Sadece dosya adı
        name = Path(link).name
        if name in all_files:
            refs.add(name)
    return len(md_links) + len(wiki_links), refs


def audit_repo(name: str, path: Path) -> dict:
    """Bir repo'nun audit metriklerini hesaplar."""
    if not path.exists():
        return {"name": name, "error": f"Path not found: {path}"}

    files = sorted(path.glob("**/*.md"))
    file_names = {f.name for f in files}

    metrics = {
        "name": name,
        "path": str(path),
        "total_files": len(files),
        "frontmatter_present": 0,
        "frontmatter_missing": [],
        "ilgili_present": 0,
        "ilgili_missing": [],
        "tarih_present": 0,
        "total_lines": 0,
        "max_lines": 0,
        "max_lines_file": "",
        "files_over_200": [],
        "isolated_files": [],
        "open_questions": 0,
        "duplicate_constants": defaultdict(list),
        "all_referenced": set(),
        "link_count": 0,
    }

    # Olası DRY ihlali — bu sabitler 2+ dosyada açıklanırsa flag
    duplicate_markers = [
        "UCRETSIZ_KAPANIS_KONUMLARI",
        "GARANTI_ICI_KONUMLARI",
        "ARON_ACIK_STATUSLAR",
        "_KAPANMIS_KONUMLAR",
    ]

    for f in files:
        try:
            text = f.read_text(encoding="utf-8")
        except Exception as e:
            print(f"  ⚠️ {f.name} okuma hatası: {e}", file=sys.stderr)
            continue

        lines = text.count("\n")
        metrics["total_lines"] += lines
        if lines > metrics["max_lines"]:
            metrics["max_lines"] = lines
            metrics["max_lines_file"] = f.name
        if lines > 200:
            metrics["files_over_200"].append(f"{f.name} ({lines} satır)")

        # Frontmatter
        fm = parse_frontmatter(text)
        if fm:
            metrics["frontmatter_present"] += 1
            # ilgili / son_guncelleme / tarih
            ilgili_value = fm.get("ilgili")
            # Liste (multi-line) ya da non-empty string
            has_ilgili = (isinstance(ilgili_value, list) and len(ilgili_value) > 0) or \
                         (isinstance(ilgili_value, str) and ilgili_value.strip() and
                          ilgili_value.strip() not in ("[]", "''", '""'))
            if has_ilgili:
                metrics["ilgili_present"] += 1
            else:
                metrics["ilgili_missing"].append(f.name)
            if any(k in fm for k in ("son_guncelleme", "tarih", "Tarih")):
                metrics["tarih_present"] += 1
        else:
            metrics["frontmatter_missing"].append(f.name)
            metrics["ilgili_missing"].append(f.name)

        # Link sayısı + referans dosyalar
        link_cnt, refs = count_links(text, file_names)
        metrics["link_count"] += link_cnt
        metrics["all_referenced"] |= refs

        # Açık soru pattern
        for pattern in OPEN_QUESTION_PATTERNS:
            metrics["open_questions"] += len(re.findall(pattern, text, re.MULTILINE | re.IGNORECASE))

        # Duplicate constants
        for marker in duplicate_markers:
            if marker in text:
                metrics["duplicate_constants"][marker].append(f.name)

    # İzole dosya: hiç referans verilmemiş (kendisi hariç) ve bir _index/_audit/_open dosyası değil
    META_PREFIXES = ("_",)
    for f in files:
        if f.name.startswith(META_PREFIXES):
            continue
        if f.name not in metrics["all_referenced"]:
            metrics["isolated_files"].append(f.name)

    # DRY: 2+ dosyada bahsedilen constant'lar
    metrics["duplicate_constants"] = {
        k: v for k, v in metrics["duplicate_constants"].items() if len(v) >= 2
    }

    # Skor hesapla (basit, deterministic)
    fm_pct = 100 * metrics["frontmatter_present"] / max(metrics["total_files"], 1)
    ilgili_pct = 100 * metrics["ilgili_present"] / max(metrics["total_files"], 1)
    isolated_pct = 100 * len(metrics["isolated_files"]) / max(metrics["total_files"], 1)
    over_200_count = len(metrics["files_over_200"])

    score = 0
    score += int(fm_pct * 0.20)            # frontmatter
    score += int(ilgili_pct * 0.20)        # ilgili field doluluk
    score += max(0, 20 - isolated_pct // 5)  # izole dosya cezası
    score += max(0, 20 - over_200_count * 5)  # 200+ satır cezası
    score += max(0, 20 - len(metrics["duplicate_constants"]) * 5)  # DRY ihlali cezası

    metrics["score"] = min(100, score)
    metrics["fm_pct"] = round(fm_pct, 1)
    metrics["ilgili_pct"] = round(ilgili_pct, 1)
    metrics["isolated_pct"] = round(isolated_pct, 1)

    # all_referenced'ı serialization için at
    del metrics["all_referenced"]

    return metrics


def format_snapshot(metrics: dict) -> str:
    """_audit_history.md'ye eklenecek snapshot."""
    today = datetime.now().strftime("%Y-%m-%d")
    n = metrics["name"]

    if "error" in metrics:
        return f"\n## {today} — {n} HATA\n\n{metrics['error']}\n"

    fm_missing = metrics["frontmatter_missing"]
    isolated = metrics["isolated_files"]
    duplicates = metrics["duplicate_constants"]

    txt = f"""
## {today} — Otomatik Snapshot ({n})

**Tetikleyici:** Cron / `audit_snapshot.py` (otomatik metric)

### KPI

| Metrik | Değer |
|--------|-------|
| Toplam dosya | {metrics['total_files']} |
| Frontmatter ✓ | {metrics['frontmatter_present']}/{metrics['total_files']} ({metrics['fm_pct']}%) |
| `ilgili:` field dolu | {metrics['ilgili_present']}/{metrics['total_files']} ({metrics['ilgili_pct']}%) |
| Tarih bilgisi | {metrics['tarih_present']}/{metrics['total_files']} |
| Toplam link | {metrics['link_count']} |
| İzole dosya (linksiz) | {len(isolated)} ({metrics['isolated_pct']}%) |
| 200+ satır dosya | {len(metrics['files_over_200'])} |
| Açık soru pattern | {metrics['open_questions']} |
| DRY ihlali (2+ yerde sabit) | {len(duplicates)} |
| **Otomatik skor** | **{metrics['score']}/100** |

### En büyük dosya
- {metrics['max_lines_file']}: {metrics['max_lines']} satır

"""
    if metrics["files_over_200"]:
        txt += "### ⚠️ 200+ satır (atomicity ihlali şüphesi)\n"
        for x in metrics["files_over_200"]:
            txt += f"- {x}\n"
        txt += "\n"

    if isolated:
        txt += f"### 🟡 İzole dosyalar ({len(isolated)})\n"
        for x in isolated[:10]:
            txt += f"- {x}\n"
        if len(isolated) > 10:
            txt += f"- … +{len(isolated)-10} daha\n"
        txt += "\n"

    if fm_missing:
        txt += f"### 🟡 Frontmatter eksik ({len(fm_missing)})\n"
        for x in fm_missing[:10]:
            txt += f"- {x}\n"
        if len(fm_missing) > 10:
            txt += f"- … +{len(fm_missing)-10} daha\n"
        txt += "\n"

    if duplicates:
        txt += "### 🔴 DRY İhlali — 2+ dosyada açıklanan sabitler\n"
        for k, v in duplicates.items():
            txt += f"- `{k}` → {', '.join(v)}\n"
        txt += "\n"

    txt += "**Sonraki adım:** Manuel `/memory-audit fix` ile tamirat (Sultan onayı gerek).\n"
    return txt


def append_history(history_path: Path, snapshot: str, dry_run: bool):
    if dry_run:
        print(f"\n[DRY-RUN] Yazılacak ({history_path.name}):\n")
        print(snapshot[:500] + "..." if len(snapshot) > 500 else snapshot)
        return
    if not history_path.exists():
        history_path.write_text("# Audit Geçmişi\n\n" + snapshot, encoding="utf-8")
    else:
        existing = history_path.read_text(encoding="utf-8")
        history_path.write_text(existing + snapshot, encoding="utf-8")
    print(f"✅ {history_path.name} güncellendi")


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    only_cortex = "--cortex" in args
    only_genom = "--veri-genom" in args

    print(f"🔍 Audit Snapshot — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print()

    if not only_genom:
        print(f"=== Cortex ({CORTEX_PATH}) ===")
        m = audit_repo("Cortex", CORTEX_PATH)
        if "error" not in m:
            print(f"  Skor: {m['score']}/100  Dosya: {m['total_files']}  FM: {m['fm_pct']}%  İzole: {len(m['isolated_files'])}")
        snap = format_snapshot(m)
        append_history(CORTEX_PATH / "_audit_history.md", snap, dry_run)
        print()

    if not only_cortex:
        print(f"=== Veri Genom ({GENOM_PATH}) ===")
        m = audit_repo("Veri Genom", GENOM_PATH)
        if "error" not in m:
            print(f"  Skor: {m['score']}/100  Dosya: {m['total_files']}  FM: {m['fm_pct']}%  İzole: {len(m['isolated_files'])}")
        snap = format_snapshot(m)
        append_history(GENOM_PATH / "_audit_history.md", snap, dry_run)
        print()

    print("✅ Snapshot tamam")


if __name__ == "__main__":
    main()
