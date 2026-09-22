# 2 · İNŞA — yapı kuralı (üç kat, tek gerekçe)

**Neden gerekli:** modeller işi bitirmeye odaklıdır; dağınık bitirebiliyorlarsa dağınık bitirirler. "Bitti"
demek için çabalar, temizlikle ilgilenmez. Altı ay sonra o kodda debelenen sen olursun; yeni bir ajan da şaşırır.
Yapı kuralı bunun için var. **Tek gerekçe: hata olduğunda nerede olduğunu bil.**

## Üç kat
| Kat | Sahibi olduğu şey | Sahibi OLMADIĞI şey |
|---|---|---|
| **Yüzey** (sayfa · komut · uç nokta · eylem) | *niçin / ne zaman*: iş kuralı, yetki ve sahiplik kontrolü, durum geçişi, hata sınıfı, kullanıcıya dönen mesaj, yeniden deneme kararı | nasıl yapıldığı; sağlayıcı ayrıntısı; veriye doğrudan dokunma |
| **Servis** (yeniden kullanılan mekanik) | *nasıl*: sağlayıcı/SDK çağrısı, komut koşumu, sağlık kontrolü, dönüştürme; **açık girdi, yapılı çıktı** | iş kuralı; durum değiştirmek; veritabanına uzanmak; hatayı yutmak |
| **Depo** (veriye dokunan tek yer) | sorgu, yazma, göç; tek şema kaynağı | mantık; sağlayıcı çağrısı |

Bir cümle: **yüzey karar verir, servis yapar, depo saklar.** Hata "niçin" hatasıysa yüzeyde, "nasıl" hatasıysa
serviste, "veri" hatasıysa depoda aranır — üç dosyaya dağılmış mantık aranmaz.

## Ne zaman servise çıkarılır
- Aynı mekanik **ikinci** çağıranda ortaya çıkınca — birinci çağıranda değil (erken soyutlama pahalıdır).
- Bir kusur bir yolda düzeltilip diğer yolda kalıyorsa → o mantık zaten iki yerde, birleştir.
- Çıkarma sırası: bir bloğu çıkar → bir çağıranı değiştir → **doğrula** → kalanları değiştir. Hepsini birden değil.

## Servis fonksiyonu nasıl olur
- Bütün girdisini **açık parametre** olarak alır; global duruma, ortama, veritabanına uzanmaz.
- **Yapılı sonuç** döner (`{hazir, adres, hata}` gibi); hata yutulmaz, açık döner. Çağıran sıkı ya da gevşek
  davranmayı kendi seçer.
- Küçük yetenek blokları: `paketiHazirla`, `bagimlilikKur`, `derle`, `sunucuyuBaslat` — "her şeyi yapan" tek dev
  fonksiyon değil.

## Karşı-desenler
| Desen | Zarar |
|---|---|
| Tanrı servis | bütün akış tek fonksiyonda saklı, teşhis imkânsız |
| Sızdıran servis | servis tabloya doğrudan yazıyor; kural iki yerde |
| Tutarsız arayüz | her fonksiyon başka argüman düzeni, başka hata anlamı |
| Aşırı soyutlama | tek çağıranı olan mantık servise taşınmış |

## Filoya özel ekler (videoda yok, bizde kural)
- **Sultan'a görünen her metin Sultan-dilinde** (jargon, dosya yolu, kod terimi yok). Yüzey katının işi.
- **Üretilmiş dosyaya elle yazılmaz** — "bunu kim üretiyor?" sorusu önce sorulur (roster, kanon, katalog).
- **Yeni havuz/defter kurulmaz**; var olana bağlanılır.
- **Sır değeri** hiçbir katta çıktıya, dosyaya, sohbete düşmez; yalnız ad ve yol konuşulur.
- Kapsamı dar tut: iş kartındaki cümlenin dışına çıkan değişiklik bu PR'a girmez, yeni kart olur.

## Zihinsel model
```
Yeni iş → yüzeyde yaz → tekrar eden mekanik gördün mü? → evet: servise çıkar (2. çağıranda)
                                                     → hayır: yüzeyde kalsın
```
