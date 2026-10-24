"""soru.py — CEVAP BEKLE (gorev_…CMWNK · SERDAR 22 Eki atama; ders 17 Eki L89 Railway temizliği).

Niçin: MİRAHUR geri alınamaz bir eylemi (iki Postgres servisini silmek) SERDAR'a soru olarak yazdı ve cevap gelmeden arka planda
koştu. Kural yazılıydı ("sor → cevabı bekle"), araçta yoktu: soru da cevap da yalnız sohbette yaşıyordu, hiçbir komut "cevap geldi mi"
diye soramıyordu. Bu modül soruyu KARTA bağlar ve tek bir yüzeyden okutur:

  kart.sh sor <iş> --kime <AD> --eylem "<ne yapılacak>" --soru "<soru>"   → açık soru (no 1, 2, …)
  kart.sh cevap <iş> --no N --kim <AD> --karar evet|hayir --oturum <ref> --soz "<sorulanın sözü, birebir>"
  kart.sh cevap-bekle <iş>   → İLK satır "yok|evet|acik|hayir<TAB>açıklama"; rc 0 yok/evet · 3 açık · 4 hayır
                               (kullanım: kart.sh cevap-bekle X && <geri alınamaz eylem>)
  kart.sh acik-soru <AJAN>   → ajanın kartlarındaki cevapsız sorular; rc 0 yok · 3 var · 2 okunamayan kart (fail-closed; kanca dilimi bunu okur)
  kart.sh bitti              → cevapsız soru varken kart KAPANMAZ (rc 1)

Sınırlar (bilerek):
  · Soran kendi sorusunu cevaplayamaz: cevabı veren sorulan kişidir (--kim = sorunun kime'si) ve kim ≠ kartın sahibi.
  · SINIFLI kartta soru yalnız Sultan'a sorulur (sınıf işinin karar mercii Sultan'dır — reis-dedi ile aynı kural).
  · Araç kimlik doğrulayamaz: cevabı ajan kayda geçirir (D1 deseni — oturum ref + birebir söz). Uydurmayı imkânsız kılmaz,
    KAYITLI ve denetlenebilir kılar (sultan-dedi ile aynı dürüst sınır).
  · Ajan adları yazım farkından bağımsız eşlenir (BERİD = BERID = berid): soran/sorulan/sorgu aynı kişiyi farklı yazımla gösterse de kural dolanılmaz.
  · "hayır" kesindir: aynı soru yeniden cevaplanmaz; eylem yine isteniyorsa YENİ soru açılır (gerekçesiyle).
"""
import datetime

KARARLAR = ("evet", "hayir")

# Ajan adı yazım farkından bağımsız karşılaştırılır (BERİD = BERID = berid; NAKKAŞ = NAKKAS; NECCÂR = NECCAR). Niçin: kartlarda
# aynı ajan iki yazımla duruyor (sohbet deposu: BERID 18 kart, BERİD 8 kart) ve tmux oturum adı ASCII ("berid"). Tam eşleşme
# kanca sorgusunda (acik-soru) kartların bir kısmını görmez, "soran kendi sorusunu cevaplayamaz" kuralında da yazım değiştirerek
# dolanılırdı. Katlama kipi-bağımsız ve tek yerde: önce Türkçe harfler elle (str.lower 'İ'yi 'i'+birleşik nokta yapar), sonra küçük harf.
_KATLA = str.maketrans({"İ": "i", "I": "i", "ı": "i", "Â": "a", "â": "a", "Î": "i", "î": "i", "Û": "u", "û": "u",
                          "Ğ": "g", "ğ": "g", "Ü": "u", "ü": "u", "Ş": "s", "ş": "s", "Ö": "o", "ö": "o", "Ç": "c", "ç": "c"})


def ad_katla(ad):
    return str(ad or "").translate(_KATLA).lower().strip()


def ayni_ad(a, b):
    return ad_katla(a) == ad_katla(b) != ""


def simdi():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def sorular(k):
    return k.get("sorular") or []


def acik(k):
    return [s for s in sorular(k) if not s.get("cevap")]


def durum(k):
    """→ (ad, açıklama). ad: yok | evet | acik | hayir. Açık soru hayırdan önce gelir (bekleyen cevap en sıcak bilgi)."""
    ss = sorular(k)
    if not ss:
        return "yok", "kartta soru yok"
    a = acik(k)
    if a:
        s = a[0]
        return "acik", f"{len(a)} cevapsız soru · ilki no {s['no']} → {s['kime']}: {s['eylem']} ({s['zaman']}'den beri)"
    h = [s for s in ss if s["cevap"]["karar"] == "hayir"]
    if h:
        s = h[-1]
        return "hayir", f"no {s['no']} HAYIR ({s['kime']}, {s['cevap']['zaman']}): {s['eylem']} — eylem koşmaz"
    return "evet", f"{len(ss)} soru, hepsi evet"


def sor(k, kime, eylem, soru):
    if k.get("durum") in ("bitti", "canli-borclu"):
        raise ValueError(f"kart kapanmış (durum {k.get('durum')}) — soru açık işe bağlanır")
    if ayni_ad(kime, k.get("aldi")):
        raise ValueError(f"--kime '{kime}' kartın sahibi — soran kendine soramaz (cevabı başkası verir)")
    if (k.get("sultan") or k.get("siniflar")) and not ayni_ad(kime, "Sultan"):
        raise ValueError(f"kart SINIFLI ({', '.join(k.get('siniflar') or ['?'])}) — sınıf işinde soru Sultan'a sorulur (--kime Sultan)")
    no = max([s["no"] for s in sorular(k)] or [0]) + 1
    k.setdefault("sorular", []).append({"no": no, "kime": kime, "eylem": eylem, "soru": soru, "soran": k.get("aldi"),
                                        "zaman": simdi(), "cevap": None})
    return no


def cevapla(k, no, kim, karar, oturum, soz):
    if karar not in KARARLAR:
        raise ValueError(f"--karar yalnız evet|hayir olabilir ('{karar}' değil)")
    s = next((x for x in sorular(k) if x["no"] == no), None)
    if s is None:
        raise ValueError(f"soru no {no} yok (kartta {len(sorular(k))} soru)")
    if s.get("cevap"):
        raise ValueError(f"soru no {no} zaten cevaplı ({s['cevap']['karar']}, {s['cevap']['zaman']}) — yeniden cevap yok; gerekirse YENİ soru aç")
    if not ayni_ad(kim, s["kime"]):
        raise ValueError(f"--kim '{kim}' bu sorunun sorulanı değil (sorulan: {s['kime']}) — cevabı yalnız sorulan verir")
    if ayni_ad(kim, k.get("aldi")):
        raise ValueError("soran kendi sorusunu cevaplayamaz")
    s["cevap"] = {"karar": karar, "kim": kim, "oturum": oturum, "soz": soz, "zaman": simdi()}
    return s
