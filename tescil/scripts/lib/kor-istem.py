#!/usr/bin/env python3
"""kor-istem.py — öznel (llm-yargi) bir G için KÖR yargıç istemi (muhurdar.sh adım 3; G8 · kadro şeması §7).

Kullanım: kor-istem.py <gereklilik.json> <G-id> <worktree> <deneme-dir> [<gereklilik-dizini>]
Stdout: istem metni. RC 2 = istem kurulamadı (sebep stderr; çağıran EMIN-DEGILIM yazar, GEÇTİ değil).

İstemin TAMAMI şu dört parçadır, başka hiçbir şey okunmaz:
  1. gereklilik satırı (GOAL + bu G'nin açıklaması)          — gereklilik.json (tescil-run anlık görüntüsü)
  2. izole rubrik dosyası (`rubrik:`)                         — gereklilik dizini ya da worktree'den, tek dosya
  3. G'nin `hedef:` dosyası (varsa)                            — worktree içinde olmalı, dışarı kaçış reddedilir
  4. mühürdarın KENDİ taze mekanik kanıtlarının sonuç tablosu — deneme-dir/kanit/G*.json (g_id · sonuç · rc)
İnşacının raporu, transkripti, commit mesajı, worktree'nin geri kalanı istem kurulurken AÇILMAZ (kör protokol);
yargıçlar özgüvenli anlatıyla kandırılır (tescil SKILL.md §1).
"""
import glob
import json
import os
import sys

TAVAN = 60_000  # bayt / parça — büyük hedef kırpılır ve SÖYLENİR


def oku(yol):
    with open(yol, "rb") as f:
        b = f.read(TAVAN + 1)
    metin = b[:TAVAN].decode("utf-8", errors="replace")
    return metin + (f"\n[… {TAVAN} baytta KIRPILDI — sonu görülmedi; kararını buna göre ver]" if len(b) > TAVAN else "")


def worktree_ici(worktree, yol):
    gercek = os.path.realpath(os.path.join(worktree, yol))
    kok = os.path.realpath(worktree)
    return gercek if (gercek == kok or gercek.startswith(kok + os.sep)) else None


def main():
    if len(sys.argv) not in (5, 6):
        sys.stderr.write("kullanım: kor-istem.py <gereklilik.json> <G> <worktree> <deneme-dir> [<gereklilik-dizini>]\n")
        return 2
    ger_yol, gid, worktree, out = sys.argv[1:5]
    ger_dizin = sys.argv[5] if len(sys.argv) == 6 else None
    ger = json.load(open(ger_yol, encoding="utf-8"))
    g = next((x for x in ger["g"] if x["id"] == gid), None)
    if not g or g["tur"] != "llm-yargi":
        sys.stderr.write(f"{gid} öznel (llm-yargi) bir G değil\n"); return 2

    rub = g.get("rubrik") or ""
    adaylar = [rub] if os.path.isabs(rub) else [p for p in ((os.path.join(ger_dizin, rub) if ger_dizin else None),
                                                           worktree_ici(worktree, rub)) if p]
    rubrik_yol = next((p for p in adaylar if os.path.isfile(p)), None)
    if not rubrik_yol:
        sys.stderr.write(f"rubrik dosyası bulunamadı: {rub}\n"); return 2

    hedef_metin = "(bu G için hedef dosya verilmedi — yalnız rubrik ve kanıt tablosuna göre karar ver)"
    if g.get("hedef"):
        h = worktree_ici(worktree, g["hedef"])
        if not h:
            sys.stderr.write(f"hedef worktree dışında: {g['hedef']} (kör protokol: yalnız iş ağacı)\n"); return 2
        if not os.path.isfile(h):
            sys.stderr.write(f"hedef dosya yok: {g['hedef']}\n"); return 2
        hedef_metin = oku(h)

    satirlar = []
    for yol in sorted(glob.glob(os.path.join(out, "kanit", "G*.json"))):
        try:
            k = json.load(open(yol, encoding="utf-8"))
            satirlar.append(f"| {k.get('g_id')} | {k.get('sonuc')} | {k.get('exit_code')} |")
        except (OSError, json.JSONDecodeError):
            satirlar.append(f"| {os.path.basename(yol)} | OKUNAMADI | - |")

    print("Sen bir MÜHÜRDARSIN: teslim edilen işi YALNIZ aşağıdaki yazılı gerekliliğe ve rubriğe göre sınarsın.")
    print("İşi yapanın raporunu, sohbetini, commit mesajını GÖRMÜYORSUN ve istemiyorsun; yalnız aşağıdakilere bak.")
    print("Hiçbir komut koşma, dosya okuma. Emin değilsen EMIN-DEGILIM de (GEÇTİ sayılmaz, Sultan'a gider).")
    print('Cevap YALNIZ JSON: {"karar": "GECTI|KALDI|EMIN-DEGILIM", "not": "<tek cümle gerekçe, kanıta atıfla>"}\n')
    print(f"## Hedef (GOAL)\n{ger.get('goal')}\n")
    print(f"## Sınanan gereklilik — {gid}\n{g.get('aciklama')}\n")
    print(f"## Rubrik ({os.path.basename(rubrik_yol)})\n{oku(rubrik_yol)}\n")
    print(f"## Hedef dosya{(' — ' + g['hedef']) if g.get('hedef') else ''}\n{hedef_metin}\n")
    print("## Mühürdarın taze mekanik kanıtları (bu koşuda yeniden ölçüldü)\n| G | sonuç | rc |\n|---|---|---|")
    print("\n".join(satirlar) if satirlar else "| (mekanik G yok) | - | - |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
