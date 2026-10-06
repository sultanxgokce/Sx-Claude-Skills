#!/usr/bin/env python3
"""koken-imzali-fikstur.py — sınav için GERÇEK imzalı bir C2PA karesi üretir.

🔴 NİÇİN AYRI DOSYA: "imza doğrulanmışsa çelişki keser" kuralının RED yüzü imzasız
   fikstürle ölçülemez; sentetik bayt dizisiyle de ölçülemez (artık şema yürünüyor).
   Bu betik sınavın kendi sertifikasıyla, AĞA ÇIKMADAN imzalı bir kare üretir.
   Çağıran: koken.test.sh (openssl + c2pa varsa). Yoksa kapılar ATLANDI basar.

Kullanım: koken-imzali-fikstur.py <tmp-dizin>   (cert.pem + key.pem orada bekler)
"""
import os, struct, sys, zlib

import c2pa

T = sys.argv[1]
URL = "http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia"


def _parca(tip, veri):
    return (struct.pack(">I", len(veri)) + tip + veri
            + struct.pack(">I", zlib.crc32(tip + veri) & 0xFFFFFFFF))


ihdr = struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0)
satirlar = b"".join(b"\x00" + b"\xff\x00\x00" * 2 for _ in range(2))
ham = (b"\x89PNG\r\n\x1a\n" + _parca(b"IHDR", ihdr)
       + _parca(b"IDAT", zlib.compress(satirlar)) + _parca(b"IEND", b""))
open(f"{T}/ham.png", "wb").write(ham)

manifest = {
    "claim_generator_info": [{"name": "koken-sinav", "version": "1.0"}],
    "assertions": [{"label": "c2pa.actions.v2", "data": {"actions": [
        {"action": "c2pa.created", "digitalSourceType": URL,
         "softwareAgent": {"name": "sinav-motoru", "version": "1.0"}}]}}],
}
bilgi = c2pa.C2paSignerInfo(alg=b"es256",
                            sign_cert=open(f"{T}/cert.pem", "rb").read(),
                            private_key=open(f"{T}/key.pem", "rb").read(),
                            ta_url=None)
os.makedirs(f"{T}/imzali", exist_ok=True)
hedef = f"{T}/imzali/j.png"
if os.path.exists(hedef):
    os.remove(hedef)
c2pa.Builder(manifest).sign_file(f"{T}/ham.png", hedef, c2pa.Signer.from_info(bilgi))
print(hedef)
