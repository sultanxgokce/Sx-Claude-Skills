#!/usr/bin/env python3
"""manifest-ozet.py — denetçiye giden kanıt manifesti GÖRÜNÜMÜ (istem tavanı için).

Sorun (gorev_01M6AX7Y31S4R4GK6NMDKT29NK, mihenk PYBNNV 1 Kas): KANIT.json isteme ham basılıyordu; 51 kaydın 28'i
geçersizlik ilanıydı ve bu kayıtlar (ilan + hedef ölçüm, sha/kimlik alanlarıyla) ~67 KB tutup istemi 100 KB tavanın üstüne itti.
Dürüstlük mekanizması (geçersiz ilanı) denetim mekanizmasını kilitliyordu.

Bu görünüm: geçersiz ilan edilen her ölçüm VE onu ilan eden kayıt TEK SATIRA iner; geçerli kayıtlar, imza ve üst alanlar
AYNEN kalır. İmzalı KANIT.json diskte DEĞİŞMEZ — bu yalnız göze giden görünümdür ve başlığı bunu söyler.

Kullanım: manifest-ozet.py <KANIT.json>      rc 0 görünüm stdout'a · rc 2 dosya okunamadı/bozuk (çağıran ham cat'e düşer)
Dürüstlük: bir ilan hedefini bulamazsa (hedef_olcum_id eşleşmiyor) ilan yine tek satır olur, hedef kaydı da SİLİNMEZ.
"""
import json
import sys

NEDEN_GEN = 160   # neden metni bu kadar karakterde kesilir (tam metin diskteki KANIT.json'da)


def kis(s, n):
    s = " ".join(str(s or "").split())
    return s if len(s) <= n else s[: n - 1] + "…"


def tek_satir(ilan, hedef):
    ad = ilan.get("etiket") or ilan.get("hedef_dosya") or "?"
    asama = ilan.get("asama")
    kim = ilan.get("kim") or "?"
    zaman = (ilan.get("zaman") or "")[:16]
    karsi = ilan.get("karsi")
    ek = f" · karşı: {kis(karsi, 40)}" if karsi else ""
    komut = ""
    if hedef and hedef.get("komut"):
        komut = " · komut: " + kis(" ".join(hedef["komut"]) if isinstance(hedef["komut"], list) else hedef["komut"], 60)
    return ("⛔ GEÇERSİZ · %s%s · hedef: %s · ilan eden: %s %s%s%s · neden: %s"
            % (ad, f"/{asama}" if asama else "", ilan.get("hedef_dosya") or "?", kim, zaman, komut, ek, kis(ilan.get("neden"), NEDEN_GEN)))


def main(yol):
    try:
        d = json.load(open(yol, encoding="utf-8"))
        kayitlar = d["kayitlar"]
        assert isinstance(kayitlar, list)
    except Exception as e:  # noqa: BLE001
        print("manifest-ozet: okunamadı (%s)" % e, file=sys.stderr)
        return 2
    ilanlar = [k for k in kayitlar if isinstance(k, dict) and k.get("tur") == "gecersiz"]
    hedef_id = {k.get("hedef_olcum_id") for k in ilanlar if k.get("hedef_olcum_id")}
    # hedef = ilan edilen ölçüm kaydı: olcum_id eşleşirse tek satıra iner (ayrı kayıt olarak basılmaz)
    hedefler = {k["olcum_id"]: k for k in kayitlar if isinstance(k, dict) and k.get("olcum_id") in hedef_id and k.get("tur") != "gecersiz"}
    kalan = [k for k in kayitlar if not (isinstance(k, dict) and (k.get("tur") == "gecersiz" or k.get("olcum_id") in hedefler))]
    cik = {kk: vv for kk, vv in d.items() if kk != "kayitlar"}
    cik["kayitlar"] = kalan
    print("[GÖRÜNÜM — özet: imzalı KANIT.json diskte AYNEN durur; burada %d geçersiz ilan + %d hedef ölçüm TEK SATIRA indirildi, "
          "geçerli kayıtlar tam. Geçersiz kayıt kanıt sayılmaz.]" % (len(ilanlar), len(hedefler)))
    print(json.dumps(cik, ensure_ascii=False, indent=1))
    if ilanlar:
        print("\n--- GEÇERSİZ İLAN EDİLENLER (%d · her biri tek satır; kanıt sayılmaz) ---" % len(ilanlar))
        for i in ilanlar:
            print(tek_satir(i, hedefler.get(i.get("hedef_olcum_id"))))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("kullanım: manifest-ozet.py <KANIT.json>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
