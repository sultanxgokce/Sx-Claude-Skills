#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""yargi-istek-yap.py — kör yargıç çağrısının İSTEK GÖVDESİNİ kurar (ağ YOK).

NİÇİN AYRI DOSYA (L57/F5): gövde kurulumu `yargi-panel.sh` içinde gömülü bir heredoc'tu.
Ağ ve kapı-anahtarı olmadan çağrılamadığı için hiçbir sınav ona dokunamıyordu; prompta
neyin girip neyin girmediği ÖLÇÜLMÜYORDU. Ölçülmeyen yer sessizce bozulur — nitekim
bozulmuştu (aşağı bak).

NE DÜZELTİR (ölçülen kusur): panel prompta yalnız MARKA sözleşmesini koyuyordu; çekirdek
(`cekirdek/sozlesme.md`) hiç enjekte edilmiyordu (`grep -c cekirdek` = 0). Rubrik M1
"sözlük-dışı sessiz icat var mı" diye sorduğu için yargıç, çekirdeğin on adını —
`Liste satırı`, `Form alanı`, `Onay diyaloğu`… — TANIMSIZ görüp icat sayabiliyordu.
Bu, mekanik kapıdaki X2 hatasının (L57/F1) birebir LLM ikizidir: aynı çatal, iki tüketici.

FAIL-CLOSED: çekirdek okunamazsa gövde YAZILMAZ, rc=2 döner. Yarım sözleşmeyle verilmiş
hüküm "kırmızı" değil ÖLÇÜLEMEDİ'dir; onu hükme çevirmek yargıcın hatası sanılır.

KULLANIM
  yargi-istek-yap.py --rubrik <f> --ekran <f.html> --model <raf> --out <govde.json>
                     [--cekirdek <f>] [--sozlesme <marka.md>] [--maxtok 16000]

ÇIKIŞ: 0 gövde yazıldı · 2 çalıştırılamadı (eksik girdi / çekirdek okunamadı)
"""
import json, os, sys

BURASI = os.path.dirname(os.path.abspath(__file__))
VARSAYILAN_CEKIRDEK = os.path.join(BURASI, "..", "cekirdek", "sozlesme.md")

YONERGE = (
    "GÖREV: Kör tasarım yargıçlığı. Aşağıda bir puanlama rubriği ve TEK bir ekranın HTML "
    "dosyası var. Ekranı YALNIZ rubrikteki maddelere göre puanla.\n\n"
    "KURALLAR:\n"
    "- Tek atış: soru soramazsın, araç kullanamazsın.\n"
    "- Her madde için puan 0, 1 ya da 2 (rubrikteki çapalar).\n"
    "- KANIT ZORUNLU: her maddenin \"kanit\" alanına EKRAN DOSYASINDAN harfi harfine kopyalanmış "
    "TEK PARÇA alıntı yaz (en çok 160 karakter). Alıntıyı DEĞİŞTİRME: üç nokta ekleme, boşluk "
    "düzeltme, birleştirme yok — dosyada birebir aranacak, bulunamazsa o maddedeki hüküm geçersiz sayılır.\n"
    "- \"gerekce\" tek cümle.\n"
    "- Emin değilsen 2 ver — yalnız kanıtla gösterebildiğini düşür.\n"
    "- SÖZLEŞME İKİ PARÇADIR: ÇEKİRDEK (filo geneli kural, her üründe geçerli) + MARKA "
    "(bu ürünün değerleri). Bir bileşen adı ÇEKİRDEKTE geçiyorsa tanımlıdır; marka "
    "bölümünde tekrar yazılmamış olması onu \"sessiz icat\" yapmaz.\n"
    "- ÇIKTIN YALNIZ rubrikteki kapalı-şema JSON olacak; başka tek kelime yazma.\n\n")


def oku(yol):
    return open(yol, encoding="utf-8").read()


def prompt_yap(rubrik_yol, ekran_yol, cekirdek_yol, sozlesme_yol=None):
    parcalar = [YONERGE]
    parcalar.append("════════ ÇEKİRDEK SÖZLEŞME (filo kuralı — her ürün için geçerli) ════════\n"
                    + oku(cekirdek_yol) + "\n\n")
    if sozlesme_yol and os.path.exists(sozlesme_yol):
        parcalar.append("════════ MARKA SÖZLEŞMESİ (bu ürünün değerleri) ════════\n"
                        + oku(sozlesme_yol) + "\n\n")
    parcalar.append("════════ RUBRİK ════════\n" + oku(rubrik_yol))
    parcalar.append("\n\n════════ EKRAN DOSYASI: " + os.path.basename(ekran_yol)
                    + " ════════\n" + oku(ekran_yol))
    return "".join(parcalar)


def main(argv):
    def al(ad, vars_=None):
        return argv[argv.index("--" + ad) + 1] if "--" + ad in argv else vars_

    try:
        rubrik, ekran, model, out = al("rubrik"), al("ekran"), al("model"), al("out")
    except IndexError:
        sys.stderr.write("RC=2 bayrak değeri eksik\n")
        return 2
    if not (rubrik and ekran and model and out):
        sys.stderr.write("RC=2 --rubrik --ekran --model --out zorunlu\n")
        return 2
    cekirdek = al("cekirdek") or os.environ.get("UI_AKIS_CEKIRDEK") or VARSAYILAN_CEKIRDEK
    try:
        prompt = prompt_yap(rubrik, ekran, cekirdek, al("sozlesme"))
    except Exception as e:
        sys.stderr.write("RC=2 ÇALIŞTIRILAMADI — %s: %s\n" % (type(e).__name__, e))
        sys.stderr.write("   çekirdek sözleşme prompta girmeden yargı istenmez: rubrik M1 "
                         "çekirdek adlarını 'sessiz icat' sanır (ölçülen kusur, L57/F5).\n")
        return 2
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"model": model, "temperature": 0,
                   "max_tokens": int(al("maxtok") or os.environ.get("MAXTOK", "16000")),
                   "messages": [{"role": "user", "content": prompt}]}, f)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
