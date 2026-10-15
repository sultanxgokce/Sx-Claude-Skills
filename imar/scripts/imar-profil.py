#!/usr/bin/env python3
"""imar-profil.py — ⛩️ İMAR profil doğrulayıcısı ve çözücüsü.

NİÇİN VAR: reçete MİHENK kutusunda doğdu ve 12 yerde o kutuya ÇİVİLİYDİ. Çivili bir düzen
başka kutuda ya çöker ya da SESSİZCE yanlış yere yazar; ikincisi daha pahalıdır, çünkü yeşil
görünür. Profil "bu kutuda ne nerede" sorusunu kurulumdan ÖNCE sorar.

Üç kural (DEVRİYE profil doğrulayıcısının şemasıyla aynı aile — filoda tek desen):
  1. Bilinmeyen alan = RED. Sessizce atlanan alan, ölçülmediği hâlde "temiz" görünen alandır.
  2. Zorunlu alan boşsa kurulum ÜRETİLMEZ. Boş yol, kurulduğu anda yeşil görünüp hiçbir şey
     yapmayan düzen demektir.
  3. Alarm "cihaz teyidi" olmadan yeşil sayılmaz. Ölçülmüş vaka: abone olunmayan konuya 200
     almak yeşil görünen arızadır; "200 geldi" alarmın çalıştığını KANITLAMAZ.

Kullanım:
  imar-profil.py dogrula <profil.json>      → 0 geçerli · 1 kural ihlali · 2 kullanım/okuma
  imar-profil.py cozumle <profil.json>      → kabuğa `export IMAR_*=...` satırları basar (0/1/2)
  imar-profil.py ornek                      → doldurulacak iskelet profil basar

Hiçbir şey YAZMAZ, hiçbir komut KOŞMAZ — salt okur.
"""
import json
import os
import sys

UST_ZORUNLU = {"kutu", "ajan", "repo_kok", "muneccim_ev", "defter_yaz", "alarm"}
UST_ISTEGE = {"sema", "surum", "aciklama", "seri", "mezarlik", "durum", "kutuk"}
ALARM_ZORUNLU = {"taban", "konu", "cihaz_teyidi"}
ALARM_ISTEGE = {"aciklama"}


def hata(m, rc=1):
    print(f"✗ {m}", file=sys.stderr)
    sys.exit(rc)


def oku(yol):
    if not os.path.isfile(yol):
        hata(f"profil dosyası yok: {yol} — ÖLÇEMEDİM (kurulum üretilmez)", 2)
    try:
        with open(yol, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        hata(f"profil okunamadı ({yol}): {e} — bozuk profil, kurulum üretilmez", 2)


def dogrula(p):
    """Kural ihlallerinin listesini döner (boş liste = geçerli)."""
    kusur = []
    if not isinstance(p, dict):
        return ["profil bir JSON nesnesi değil"]

    # Kural 1 · bilinmeyen alan = RED
    for k in p:
        if k not in UST_ZORUNLU and k not in UST_ISTEGE and not k.startswith("_"):
            kusur.append(f"bilinmeyen alan: {k} — sessizce atlanan alan ölçülmemiş alandır")

    # Kural 2 · zorunlu alan boş olamaz
    for k in sorted(UST_ZORUNLU):
        if k == "alarm":
            continue
        d = p.get(k)
        if not isinstance(d, str) or not d.strip():
            kusur.append(f"zorunlu alan boş ya da metin değil: {k}")

    a = p.get("alarm")
    if not isinstance(a, dict):
        kusur.append("zorunlu alan boş ya da nesne değil: alarm")
    else:
        for k in a:
            if k not in ALARM_ZORUNLU and k not in ALARM_ISTEGE and not k.startswith("_"):
                kusur.append(f"bilinmeyen alarm alanı: {k}")
        for k in sorted(ALARM_ZORUNLU):
            d = a.get(k)
            if not isinstance(d, str) or not d.strip():
                # Kural 3 · cihaz teyidi ayrı gerekçeyle anlatılır
                if k == "cihaz_teyidi":
                    kusur.append("alarm.cihaz_teyidi BOŞ — 'geçit 200 döndü' alarmın çalıştığını "
                                 "KANITLAMAZ; Sultan 'cihaza düştü' demeden alarm yeşil sayılmaz")
                else:
                    kusur.append(f"zorunlu alarm alanı boş: alarm.{k}")

    # Yollar MUTLAK olmalı: göreli yol, koşulduğu dizine göre kayar ve sessizce yanlış yere yazar.
    for k in ("repo_kok", "muneccim_ev", "defter_yaz", "seri", "mezarlik", "durum", "kutuk"):
        d = p.get(k)
        if isinstance(d, str) and d.strip() and not d.startswith("/"):
            kusur.append(f"{k} mutlak yol değil ({d}) — göreli yol koşulduğu dizine göre kayar")
    return kusur


def cozumle(p):
    """Profilden türetilmiş tam yol kümesi. Varsayılanlar profilden TÜRETİLİR, kutu adı GEÇMEZ."""
    repo = p["repo_kok"].rstrip("/")
    ev = p["muneccim_ev"].rstrip("/")
    a = p["alarm"]
    return {
        "IMAR_KUTU": p["kutu"],
        "IMAR_AJAN": p["ajan"],
        "IMAR_REPO": repo,
        "MUNECCIM_EV": ev,
        "IMAR_SERI": p.get("seri") or f"{ev}/arastirma-serisi",
        "IMAR_MEZARLIK": p.get("mezarlik") or f"{repo}/hafiza/fikir-mezarligi.jsonl",
        "IMAR_DURUM": p.get("durum") or f"{repo}/_agents/spec/imar/DURUM.json",
        "IMAR_KUTUK": p.get("kutuk") or f"{repo}/hafiza/imar-kutuk.log",
        "IMAR_DEFTER_YAZ": p["defter_yaz"],
        "NTFY_TABAN": a["taban"],
        "IMAR_ALARM_KONU": a["konu"],
        "IMAR_ALARM_TEYIT": a["cihaz_teyidi"],
    }


ORNEK = {
    "_aciklama": "⛩️ İMAR profili — bu kutuda ne nerede. scripts/imar-profil.py dogrula ile sınanır.",
    "sema": 1,
    "kutu": "<kutu-adi>",
    "ajan": "<TURU-KOSAN-AJAN>",
    "repo_kok": "/config/projects/<depo>",
    "muneccim_ev": "/config/projects/<depo>-muneccim",
    "defter_yaz": "/config/.ic-sayfa/defter-yaz.py",
    "alarm": {
        "taban": "http://cloudtop-ntfy:80",
        "konu": "<abone-olunan-konu>",
        "cihaz_teyidi": ""
    }
}


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip()); sys.exit(2)
    komut = sys.argv[1]
    if komut == "ornek":
        print(json.dumps(ORNEK, ensure_ascii=False, indent=2)); return
    if komut not in ("dogrula", "cozumle") or len(sys.argv) < 3:
        print(__doc__.strip()); sys.exit(2)
    p = oku(sys.argv[2])
    kusur = dogrula(p)
    if kusur:
        for k in kusur:
            print(f"✗ {k}", file=sys.stderr)
        print(f"✗ profil GEÇERSİZ ({len(kusur)} kural ihlali) — kurulum ÜRETİLMEZ", file=sys.stderr)
        sys.exit(1)
    if komut == "dogrula":
        print(f"✓ profil geçerli · kutu={p['kutu']} ajan={p['ajan']}")
        return
    for k, v in cozumle(p).items():
        print(f"export {k}={json.dumps(v, ensure_ascii=False)}")


if __name__ == "__main__":
    main()
