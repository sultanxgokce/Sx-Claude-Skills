#!/usr/bin/env python3
"""compose_block.py — İSKÂN compose METİN-düzeyi blok-filtresi (YALNIZ kontrol amaçlı; yazım İÇİN DEĞİL).

Tek mod: `sil <cname>` — verilen servis-bloğunu (önündeki İSKÂN-yorum satırları + bir
ayraç-boşluk dahil) METİN-düzeyinde çıkarır, KALANI stdout'a basar. Seçim-mantığı
iskan.sh `_sokum_compose_cikar`ın birebir aynasıdır (satır-desenli; YAML-parser değil).

NEDEN (LB-fix, komşu-BAYT kapısı): compose_parse yapısal raporu mem_limit/env/image/
healthcheck GÖRMEZ → yapısal karşılaştırma komşu-drift'e (MAHREM tenant'lar dahil) kördü.
COMPOSE-SENKRON tam-dosya yazımından ÖNCE her iki taraftan aday bu filtreyle çıkarılır ve
kalan komşu-metinler BAYT (md5) karşılaştırılır: eş DEĞİLSE yazım fail-closed reddedilir
(komşu-ezme imkânsızlaşır), eş İSE tam-dosya yazımı komşulara bayt-etkisizdir.

Sözleşme:
- aday bulunursa: blok çıkarılmış metin stdout'a (tek-kuyruk-\n normalize).
- aday YOKSA: metin AYNEN (aynı normalize ile) stdout'a — "host'ta aday-yok" durumunda
  komşu-küme = tüm-dosya (rc=0; ayrım gate için gereksiz).
- boş/salt-boşluk girdi: stdout boş + rc=1 (çağıran fail-closed'a bağlar; sahte-yeşil yok).
- Diske yazmaz, ağ/host çağrısı yapmaz.
"""
import re
import sys


def sil(text, cname):
    lines = text.splitlines()
    key = next(
        (i for i, l in enumerate(lines) if re.match(r"^  " + re.escape(cname) + r":\s*$", l)),
        None,
    )
    if key is None:
        # aday yok → passthrough (bulunan-yolla AYNI normalize: tek-kuyruk-\n; simetri şart,
        # yoksa gate'in md5 karşılaştırması yapay kuyruk-farkı üretirdi)
        return "\n".join(lines) + "\n"
    start = key
    j = key - 1
    while j >= 0 and re.match(r"^  #", lines[j]):
        start = j
        j -= 1
    if start > 0 and lines[start - 1].strip() == "":
        start -= 1
    end = key + 1
    while end < len(lines) and (lines[end].strip() == "" or lines[end].startswith("    ")):
        end += 1
    while end - 1 > key and lines[end - 1].strip() == "":
        end -= 1  # ayraç-boşluğu komşuya bırak (_sokum_compose_cikar aynası)
    del lines[start:end]
    return "\n".join(lines) + "\n"


def main(argv):
    if len(argv) != 4 or argv[1] != "sil":
        print("kullanım: compose_block.py sil <cname> <compose.yml|->", file=sys.stderr)
        return 2
    cname, src = argv[2], argv[3]
    try:
        if src == "-":
            text = sys.stdin.read()
        else:
            with open(src, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
    except Exception as exc:  # noqa: BLE001 — okunamayan girdi için dürüst-fail
        print(f"okuma-hatasi: {exc}", file=sys.stderr)
        return 1
    if not text.strip():
        print("bos-girdi: compose metni boş — komşu-küme çıkarılamaz (fail-closed)", file=sys.stderr)
        return 1
    sys.stdout.write(sil(text, cname))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
