#!/usr/bin/env python3
"""compose_parse.py — İSKÂN SALT-OKUR docker-compose YAML çözümleyici (FAZ-1, B1/B2 girdisi).

Diske hiçbir şey yazmaz, hiçbir ağ/host çağrısı yapmaz — yalnız verilen dosyayı (veya "-" ile
stdin'i) okur ve servis/volume/port haritasını JSON olarak stdout'a basar. `iskan-host.sh` bu
JSON'u B1 (volume-path kesişim-guard) ve compose-diff için kullanır.

Kullanım: compose_parse.py [--haric <servis-key>] <compose.yml|->
  --haric: verilen servisi (compose `services:` anahtarı; İSKÂN-tenant'ında servis-key = cname,
  bkz iskan.sh yeni-proje üreteci) rapordan DÜŞÜRÜP raporu — kesişimler DAHİL — yeniden hesaplar.
  COMPOSE-SENKRON beklenen-delta kapısı bunu İKİ tarafa uygulayıp "fark yalnız-aday mı" sorusunu
  yanıtlar. Bayraksız çağrı çıktısı BAYT-aynıdır (mevcut tüketiciler etkilenmez, golden-kanıtlı).
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


def build_report(doc, haric=None):
    services = (doc or {}).get("services") or {}
    out = {}
    volume_owner = {}
    intersections = []
    for name in sorted(services.keys()):
        if haric is not None and name == haric:
            continue  # --haric: servis rapora hiç girmez → kesişimler de onsuz yeniden hesaplanır
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
    args = list(argv[1:])
    haric = None
    if args and args[0] == "--haric":
        if len(args) != 3:
            print("kullanım: compose_parse.py [--haric <servis-key>] <compose.yml|->", file=sys.stderr)
            return 2
        haric = args[1]
        args = args[2:]
    if len(args) != 1:
        print("kullanım: compose_parse.py [--haric <servis-key>] <compose.yml|->", file=sys.stderr)
        return 2
    src = args[0]
    try:
        if src == "-":
            doc = yaml.safe_load(sys.stdin.read()) or {}
        else:
            with open(src, "r", encoding="utf-8") as fh:
                doc = yaml.safe_load(fh) or {}
    except Exception as exc:  # noqa: BLE001 — okunamayan/bozuk yaml için dürüst-fail, sızdırmadan
        print(f"parse-hatasi: {exc}", file=sys.stderr)
        return 1
    report = build_report(doc, haric=haric)
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
