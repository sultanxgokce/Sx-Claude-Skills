#!/usr/bin/env python3
"""compose_block.py — İSKÂN compose METİN-düzeyi blok-filtresi (YALNIZ kontrol amaçlı; yazım İÇİN DEĞİL).

İki mod:
- `sil <cname>`     — aday servis-bloğunu (önündeki bitişik İSKÂN-yorum satırları + bir ayraç-
  boşluk dahil) METİN-düzeyinde çıkarır, KALANI (komşu-küme) stdout'a basar.
- `yutulan <cname>` — aday servis-header'ından ÖNCE yutulan satırları (bitişik yorumlar +
  ayraç-boşluk) basar. `sil`in aday'a dahil edip attığı bağlam budur.

Seçim-mantığı iskan.sh `_sokum_compose_cikar`ın birebir aynasıdır (satır-desenli; YAML-parser
değil — hafif+bağımlılıksız).

NEDEN — komşu-BAYT kapısı (LB-fix): compose_parse yapısal raporu mem_limit/env/image/healthcheck
GÖRMEZ → yapısal karşılaştırma komşu-drift'e (MAHREM tenant'lar dahil) kördü. COMPOSE-SENKRON
tam-dosya yazımından ÖNCE her iki taraftan aday `sil`inir, kalan komşu-metinler md5-eş İSE yazım
komşulara bayt-etkisizdir.

NEDEN — `yutulan` (asimetrik-yorum-yutma reddi, 3.tur MAJOR-1): `sil` aday-header'a BİTİŞİK
(araya blank-ayraç yok) bir yorumu adaya yutar. Host'ta origin/main'de-OLMAYAN bir bakım-yorumu
aday-header'a bitişikse, o yorum host_komsu'dan da çıkar → komşu-md5 sahte-EŞ görünür, ama
tam-dosya yazımı o host-only yorumu SİLER (sahte-attestasyon). `yutulan` iki taraftan yutulan
bağlamı görünür kılar → _compose_senkron "host'un yuttuğu ⊆ repo'nun yuttuğu" değilse fail-closed.

Bilinen-sınır (MINOR): YAML-anchor'lı header (`  cloudtop-x: &sk`) key-regex'i eşlemez →
`sil` passthrough / `yutulan` boş döner. İSKÂN yeni-proje üreteci anchor kullanmaz; anchor'lı
elle-host bloğu doğumda no-op/false-RED'e düşer (sessiz-config-ezme DEĞİL — passthrough güvenli
taraf; bkz golden 'compose_block anchor passthrough davranış-dok').

Sözleşme:
- `sil`, aday bulunursa blok-çıkarılmış metni; aday YOKSA metni AYNEN (tek-kuyruk-\n normalize)
  stdout'a — "host'ta aday-yok" simetrisi (rc=0).
- `yutulan`, aday bulunursa header-öncesi yutulan satırları; aday YOKSA boş stdout (rc=0).
- boş/salt-boşluk girdi: boş stdout + rc=1 (çağıran fail-closed'a bağlar; sahte-yeşil yok).
- Diske yazmaz, ağ/host çağrısı yapmaz.
"""
import re
import sys


def _bul(lines, cname):
    """(start, key, end) — aday-bloğun sınırları; aday yoksa None. _sokum_compose_cikar aynası."""
    key = next(
        (i for i, l in enumerate(lines) if re.match(r"^  " + re.escape(cname) + r":\s*$", l)),
        None,
    )
    if key is None:
        return None
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
        end -= 1  # ayraç-boşluğu komşuya bırak (tek-blank separatör korunur)
    return start, key, end


def sil(text, cname):
    lines = text.splitlines()
    r = _bul(lines, cname)
    if r is None:
        # aday yok → passthrough (bulunan-yolla AYNI normalize; simetri şart, yoksa gate'in
        # md5 karşılaştırması yapay kuyruk-farkı üretirdi)
        return "\n".join(lines) + "\n"
    start, _key, end = r
    del lines[start:end]
    return "\n".join(lines) + "\n"


def yutulan(text, cname):
    """aday-header ÖNCESİ yutulan satırlar (bitişik yorumlar + ayraç-blank). aday yoksa boş."""
    lines = text.splitlines()
    r = _bul(lines, cname)
    if r is None:
        return ""
    start, key, _end = r
    if key <= start:
        return ""
    return "\n".join(lines[start:key]) + "\n"


def main(argv):
    if len(argv) != 4 or argv[1] not in ("sil", "yutulan"):
        print("kullanım: compose_block.py <sil|yutulan> <cname> <compose.yml|->", file=sys.stderr)
        return 2
    mode, cname, src = argv[1], argv[2], argv[3]
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
    out = sil(text, cname) if mode == "sil" else yutulan(text, cname)
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
