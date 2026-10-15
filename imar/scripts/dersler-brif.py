#!/usr/bin/env python3
"""dersler-brif.py — ders defterini insansız turun brifi için AYIRARAK verir.

🔴 NİÇİN VAR (ölçüldü 14 Ekim 2026): brif dersleri `tail -n 60` ile veriyordu. İki ayrı zarar:
  1) Kesit KEYFİ: ders sayısı arttıkça eskiler düşüyor ve kesme bir ders bloğunun ORTASINDAN
     geçebiliyor — üretici yarım ders okuyor.
  2) Çürütülmüş dersler ayrılmıyordu: ikinci gözün "🔴 ÇÜRÜDÜ" damgasını vurduğu iddia,
     ayakta kalanlarla aynı listede, aynı tonda görünüyordu. Üretici onun ÜSTÜNE inşa edebilir.
     Ölçüm: 12 dersten 4'ü çürük, brifin gördüğü kesitte yalnız 2'si vardı.

Çıktı üç başlık: AYAKTA (çürütülemedi — doğru demek değil) · ÇÜRÜTÜLDÜ (üstüne inşa etme) ·
ÖLÇÜLEMEDİ. Bloklar bütün verilir, ortadan kesilmez.

Kullanım: dersler-brif.py <DERSLER.md> [--son N]   (N: en yeni kaç ders, varsayılan 8)
rc: 0 yazıldı · 3 dosya yok/okunamadı (brif onu "HENÜZ YOK" diye yazar)
"""
import sys, re, os

a = sys.argv[1:]
if not a or a[0].startswith("-"):
    print(__doc__); sys.exit(3)
yol = a[0]
son = int(a[a.index("--son") + 1]) if "--son" in a else 8
if not os.path.isfile(yol):
    print("ÖLÇÜLEMEDİ: ders defteri yok: %s" % yol, file=sys.stderr); sys.exit(3)
metin = open(yol, encoding="utf-8").read()

# ders blokları: "### D-xxx ·" başlığından bir sonrakine kadar (blok BÜTÜN kalır)
bloklar = []
for m in re.finditer(r"^### D-(\d+) ·.*?(?=^### D-\d+ ·|\Z)", metin, re.S | re.M):
    bloklar.append((int(m.group(1)), m.group(0).rstrip()))
if not bloklar:
    print("ÖLÇÜLEMEDİ: defterde ders bloğu bulunamadı (biçim kaymış olabilir)", file=sys.stderr); sys.exit(3)

def hal(b):
    if re.search(r"İkinci göz:\*\* 🔴 ÇÜRÜDÜ", b): return "curuk"
    if re.search(r"İkinci göz:\*\* ölçülemedi", b): return "olculemedi"
    return "ayakta"

bloklar.sort(key=lambda x: x[0])
secilen = bloklar[-son:] if son > 0 else bloklar
kova = {"ayakta": [], "curuk": [], "olculemedi": []}
for no, b in secilen: kova[hal(b)].append(b)

print("## Kendi derslerin — ÖNCE BUNLARI OKU (son %d ders, toplam %d)" % (len(secilen), len(bloklar)))
print()
print("### AYAKTA (ikinci göz çürütemedi — *doğru* demek DEĞİL, yalnız çürütülemedi)")
print("\n\n".join(kova["ayakta"]) if kova["ayakta"] else "_(bu kesitte ayakta ders yok)_")
print()
if kova["curuk"]:
    print("### 🔴 ÇÜRÜTÜLDÜ — bu iddiaların ÜSTÜNE İNŞA ETME")
    print("Bağımsız göz bunları çürüttü; gerekçe her dersin altında. Aynı kalıbı tekrarlama.")
    print()
    print("\n\n".join(kova["curuk"]))
    print()
if kova["olculemedi"]:
    print("### ÖLÇÜLEMEDİ — göz karar veremedi, kanıtı tamamlanmadan dayanak sayma")
    print("\n\n".join(kova["olculemedi"]))
    print()
