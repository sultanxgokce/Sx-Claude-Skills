#!/usr/bin/env python3
"""compose_parse.py — İSKÂN SALT-OKUR docker-compose YAML çözümleyici (FAZ-1, B1/B2 girdisi).

Diske hiçbir şey yazmaz, hiçbir ağ/host çağrısı yapmaz — yalnız verilen dosyayı (veya "-" ile
stdin'i) okur ve servis/volume/port haritasını JSON olarak stdout'a basar. `iskan-host.sh` bu
JSON'u B1 (volume-path kesişim-guard) ve compose-diff için kullanır.

Kullanım: compose_parse.py <compose.yml|->
"""
import json
import sys

import yaml


def parse_port(entry):
    parts = str(entry).split(":")
    if len(parts) >= 2:
        return parts[-2]
    return parts[0]


def parse_volume_host_path(entry):
    text = str(entry)
    if ":" not in text:
        return None
    return text.split(":", 1)[0]


def build_report(doc):
    services = (doc or {}).get("services") or {}
    out = {}
    volume_owner = {}
    intersections = []
    for name in sorted(services.keys()):
        cfg = services[name] or {}
        container_name = cfg.get("container_name", name)
        volumes = [parse_volume_host_path(v) for v in (cfg.get("volumes") or [])]
        volumes = sorted(v for v in volumes if v)
        ports = sorted(parse_port(p) for p in (cfg.get("ports") or []))
        out[name] = {
            "container_name": container_name,
            "volumes": volumes,
            "ports": ports,
        }
        for v in volumes:
            owner = volume_owner.get(v)
            if owner and owner != name:
                intersections.append({"path": v, "services": sorted({owner, name})})
            else:
                volume_owner.setdefault(v, name)
    return {"services": out, "intersections": intersections}


def main(argv):
    if len(argv) != 2:
        print("kullanım: compose_parse.py <compose.yml|->", file=sys.stderr)
        return 2
    src = argv[1]
    try:
        if src == "-":
            doc = yaml.safe_load(sys.stdin.read()) or {}
        else:
            with open(src, "r", encoding="utf-8") as fh:
                doc = yaml.safe_load(fh) or {}
    except Exception as exc:  # noqa: BLE001 — okunamayan/bozuk yaml için dürüst-fail, sızdırmadan
        print(f"parse-hatasi: {exc}", file=sys.stderr)
        return 1
    report = build_report(doc)
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
