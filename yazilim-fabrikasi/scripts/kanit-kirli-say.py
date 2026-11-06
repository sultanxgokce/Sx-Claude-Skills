#!/usr/bin/env python3
"""kanit-kirli-say.py — "kirli ağaçta kanıt alınmasın" kuralının KAPANIŞ ÖLÇÜMÜ (görev …PYWKB, 6 Kas 2026).

Kural bir KÜMEYİ kapsar: her kanıt kaydı. Bu araç kümenin DÖRT türünü (olcum · ekran · dosya · canli) AYRI AYRI sayar;
bir tür hiç görülmese de satırı basılır (0 yazar, sessiz düşmez). İlk kapanışta yalnız `olcum` sayılmış, 9 izinsiz kirli
kayıt (4 dosya, 5 canli) görülmemişti — ölçüt kendi alt kümesini sayıyordu.

Sayım KAPIDAN BAĞIMSIZ alanla yapılır: `olculen_kirli` (0.6.0'dan beri her kayıt yolunda yazılır; kapı koşsun koşmasın).
`kirli_kurali` (yalnız kapı koşunca yazılan damga) süzgeç OLARAK KULLANILMAZ.
  izinsiz kirli = olculen_kirli true ve kirli_izin boş
  ölçülemedi    = olculen_kirli alanı yok (eski araç ya da ağaç okunamadı) — temiz SAYILMAZ, ayrı sütunda

Kullanım:
  python3 kanit-kirli-say.py [--sonra 2026-11-06T14:00:00+03:00] KÖK [KÖK ...]
  KÖK: bir depo/iş alanı kökü (altındaki _agents/fabrika/kanit/*/KANIT.json okunur) ya da doğrudan bir KANIT.json.
  Aynı kayıt birden çok kökte görünürse (ana checkout + iş alanı) `olcum_id` ile tek sayılır.

Çıkış: 0 izinsiz kirli kayıt yok · 1 en az bir izinsiz kirli kayıt · 2 kullanım hatası · 3 hiç KANIT.json okunamadı (ÖLÇÜLEMEDİ).
"""
import argparse
import datetime
import glob
import json
import os
import sys

TURLER = ("olcum", "ekran", "dosya", "canli")


def zaman_oku(s):
    try:
        z = datetime.datetime.fromisoformat(str(s))
    except (TypeError, ValueError):
        return None
    if z.tzinfo is None:
        z = z.astimezone()
    return z


def manifestler(kokler):
    for kok in kokler:
        if os.path.isfile(kok):
            yield os.path.abspath(kok)
            continue
        for y in sorted(glob.glob(os.path.join(kok, "_agents", "fabrika", "kanit", "*", "KANIT.json"))):
            yield os.path.abspath(y)


def main():
    p = argparse.ArgumentParser(description="kirli ağaç kuralının kapanış ölçümü: dört kayıt türü ayrı ayrı")
    p.add_argument("kokler", nargs="+", metavar="KÖK")
    p.add_argument("--sonra", default=None, help="yalnız bu andan (ISO 8601) sonra yazılan kayıtlar")
    p.add_argument("--liste", type=int, default=20, help="basılacak izinsiz kayıt sayısı tavanı (toplam her zaman basılır)")
    a = p.parse_args()

    esik = None
    if a.sonra:
        esik = zaman_oku(a.sonra)
        if esik is None:
            print(f"--sonra okunamadı: {a.sonra!r} (ISO 8601 bekleniyor)", file=sys.stderr)
            return 2

    say = {t: {"toplam": 0, "kirli": 0, "izinli": 0, "izinsiz": 0, "olculemedi": 0} for t in TURLER}
    diger = {}
    izinsizler = []
    goruldu = set()
    okunan = bozuk = zamansiz = 0

    for yol in manifestler(a.kokler):
        try:
            with open(yol, encoding="utf-8") as f:
                m = json.load(f)
        except (OSError, ValueError):
            bozuk += 1
            continue
        kayitlar = m.get("kayitlar") if isinstance(m, dict) else m
        if not isinstance(kayitlar, list):
            bozuk += 1
            continue
        okunan += 1
        is_adi = os.path.basename(os.path.dirname(yol))
        for k in kayitlar:
            if not isinstance(k, dict):
                continue
            kimlik = k.get("olcum_id") or (is_adi, k.get("dosya"), k.get("sha256"), k.get("zaman"))
            if kimlik in goruldu:
                continue
            goruldu.add(kimlik)
            if esik is not None:
                z = zaman_oku(k.get("zaman"))
                if z is None:
                    zamansiz += 1
                    continue
                if z < esik:
                    continue
            tur = k.get("tur")
            if tur not in say:
                diger[tur] = diger.get(tur, 0) + 1
                continue
            s = say[tur]
            s["toplam"] += 1
            if "olculen_kirli" not in k:
                s["olculemedi"] += 1
                continue
            if k.get("olculen_kirli") is True:
                s["kirli"] += 1
                if (k.get("kirli_izin") or "").strip():
                    s["izinli"] += 1
                else:
                    s["izinsiz"] += 1
                    izinsizler.append((k.get("zaman") or "?", tur, is_adi, k.get("etiket") or k.get("dosya") or "?", yol))

    if okunan == 0:
        print(f"ÖLÇÜLEMEDİ: hiç KANIT.json okunamadı ({len(a.kokler)} kök, {bozuk} bozuk) — 'izinsiz 0' denmez", file=sys.stderr)
        return 3

    print(f"kirli ağaç kapanış ölçümü · {okunan} manifest · pencere: {a.sonra or 'hepsi'} · alan: olculen_kirli (kapıdan bağımsız)")
    print(f"{'tür':<6} {'toplam':>7} {'kirli':>6} {'izinli':>7} {'izinsiz':>8} {'ölçülemedi':>11}")
    for t in TURLER:
        s = say[t]
        print(f"{t:<6} {s['toplam']:>7} {s['kirli']:>6} {s['izinli']:>7} {s['izinsiz']:>8} {s['olculemedi']:>11}")
    top = sum(say[t]["izinsiz"] for t in TURLER)
    print(f"İZİNSİZ KİRLİ TOPLAM={top} · " + " · ".join(f"{t}={say[t]['izinsiz']}" for t in TURLER))
    if diger:
        print("dört tür dışı (sayıma girmedi): " + ", ".join(f"{k}={v}" for k, v in sorted(diger.items(), key=lambda x: str(x[0]))))
    if zamansiz:
        print(f"zamanı okunamayan kayıt: {zamansiz} (pencereye girip girmediği bilinmiyor — sayıma girmedi)")
    if bozuk:
        print(f"okunamayan manifest: {bozuk}")
    for z, t, i, e, y in sorted(izinsizler)[: max(a.liste, 0)]:
        print(f"  izinsiz · {z} · {t} · {i} · {e}")
    if len(izinsizler) > max(a.liste, 0):
        print(f"  … {len(izinsizler) - max(a.liste, 0)} kayıt daha (--liste ile artır)")
    return 1 if top else 0


if __name__ == "__main__":
    sys.exit(main())
