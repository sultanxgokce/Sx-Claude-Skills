"""soru.py — CEVAP BEKLE (gorev_…CMWNK · SERDAR 22 Eki atama; ders 17 Eki L89 Railway temizliği).

Niçin: MİRAHUR geri alınamaz bir eylemi (iki Postgres servisini silmek) SERDAR'a soru olarak yazdı ve cevap gelmeden arka planda
koştu. Kural yazılıydı ("sor → cevabı bekle"), araçta yoktu: soru da cevap da yalnız sohbette yaşıyordu, hiçbir komut "cevap geldi mi"
diye soramıyordu. Bu modül soruyu KARTA bağlar ve tek bir yüzeyden okutur:

  kart.sh sor <iş> --kime <AD> --eylem "<ne yapılacak>" --soru "<soru>"   → açık soru (no 1, 2, …)
  kart.sh cevap <iş> --no N --kim <AD> --karar evet|hayir --oturum <ref> --soz "<sorulanın sözü, birebir>"
  kart.sh cevap-bekle <iş>   → İLK satır "yok|evet|acik|hayir<TAB>açıklama"; rc 0 yok/evet · 3 açık · 4 hayır
                               (kullanım: kart.sh cevap-bekle X && <geri alınamaz eylem>)
  kart.sh acik-soru <AJAN>   → ajanın kartlarındaki cevapsız sorular; rc 0 yok · 3 var (kanca dilimi bunu okur)
  kart.sh bitti              → cevapsız soru varken kart KAPANMAZ (rc 1)

Sınırlar (bilerek):
  · Soran kendi sorusunu cevaplayamaz: cevabı veren sorulan kişidir (--kim = sorunun kime'si) ve kim ≠ kartın sahibi.
  · SINIFLI kartta soru yalnız Sultan'a sorulur (sınıf işinin karar mercii Sultan'dır — reis-dedi ile aynı kural).
  · Araç kimlik doğrulayamaz: cevabı ajan kayda geçirir (D1 deseni — oturum ref + birebir söz). Uydurmayı imkânsız kılmaz,
    KAYITLI ve denetlenebilir kılar (sultan-dedi ile aynı dürüst sınır).
  · "hayır" kesindir: aynı soru yeniden cevaplanmaz; eylem yine isteniyorsa YENİ soru açılır (gerekçesiyle).
"""
import datetime

KARARLAR = ("evet", "hayir")


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
    if kime == k.get("aldi"):
        raise ValueError(f"--kime '{kime}' kartın sahibi — soran kendine soramaz (cevabı başkası verir)")
    if (k.get("sultan") or k.get("siniflar")) and kime != "Sultan":
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
    if kim != s["kime"]:
        raise ValueError(f"--kim '{kim}' bu sorunun sorulanı değil (sorulan: {s['kime']}) — cevabı yalnız sorulan verir")
    if kim == k.get("aldi"):
        raise ValueError("soran kendi sorusunu cevaplayamaz")
    s["cevap"] = {"karar": karar, "kim": kim, "oturum": oturum, "soz": soz, "zaman": simdi()}
    return s
