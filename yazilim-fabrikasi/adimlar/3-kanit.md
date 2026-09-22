# 3 · KANITLA — "ajan söz veremez"

Yeterince bastırırsan ajan "evet yaptım" der. Bu yüzden sorular sabittir: **yaptıysan nasıl yaptın? kanıtı nerede?
karesi nerede? ölçümü nerede?** Kanıt yalnız insanı güvenceye almaz; kareyi üretebilmek için ajan o işi gerçekten
yapmak zorunda kalır — çalışma biçimini değiştirir.

## Ne kanıt sayılır
| Değişiklik | Kanıt | Kural |
|---|---|---|
| **Görünüm** | önce/sonra kare — "sayfa yoktu, şimdi var" | **gerçekçi veriyle** çekilir; boş/örnek veriyle kare kanıt değil. Yeni görünüm karesi insana gitmeden yayınlanmaz |
| **Akış** (tıkla, gir, gönder) | ajanın uygulamayı **kendisi kullanarak** aldığı kare dizisi; grafik ortamı olan kutuda kısa video | kutuda grafik ortam yoksa "video alınamadı" **SARI** yazılır, yeşile boyanmaz |
| **Görünmez** (performans, veri, arka plan) | ölçüm çifti: önceki değer · sonraki değer · komut · rc — yan yana | komut kırpılmadan saklanır, boru arkasına konmaz |

**Kanıt sayılmayan:** "yaptım / bitti / çalışıyor / muhtemelen geçer" beyanı · kod satırının kendisi (kimse her
satırı okumuyor) · pipe arkasındaki yeşil · KOŞULMADI'nın yeşil sayılması.

## Kanıt nerede yaşar
`_agents/fabrika/kanit/<iş>/` — kutunun içinde. **Dış yükleme servisi yok** (Sultan direktifi: görsel onay kendi
sunucumuzda). `KANIT.json` manifestini **araç yazar** (`kanit.sh`, F1); elle yazılmış manifesti bağımsız göz reddeder.
Manifest satırı: tür · dosya · sha · komut · rc · zaman · aracın sürümü. Kokpit buradan gösterir.

## Rubrik — altı kanun + bir (hepsi AKAR'da vakalı, 15-21 Eyl 2026)
1. **Yazılmış ≠ kurulmuş.** Sınav depoda durur ama hiçbir kapıda çağrılmaz (265 sınavın 48'i zincir dışıydı,
   30'u gerekçesiz). Soru: "bunu kim çağırıyor?"
2. **Kurulmuş ≠ koşuyor.** Tarayıcı açılamayınca "KOŞULMADI" basıp rc=0 dönen sınav: 6 güvenlik iddiası ölçülmeden
   yeşil geçti. Kural: KOŞULMADI → rc=3.
3. **Koşuyor ≠ iddia ediyor.** Öğeyi seçici olarak kullanıp varlığını iddia etmeyen sınav; öğe silinse yeşil kalır.
4. **Koşuyor ≠ her kabukta koşuyor.** Yazı tipi ortamını kendi kurmayan sınav: 113 koşunun 107'si yanlış yeşil, 6 gün.
   Sınav ortam satırlarını kendi içinde taşır.
5. **Yeşil ≠ ölçmüş.** Var olmayan tabloya çapa atıp "ölçülemedi" deyip rc=0 dönen sınav; ürün bozulunca da yeşil.
   Kural: `exit(kaldı ? 1 : 3)`.
6. **Ölçememiş ≠ kusur bulmamış.** Ölçer canlı adrese bakıp 401'e düştü, açtığı şey ürün değil giriş sayfasıydı;
   tersinde "hizasız" ölçtüğü satırlar kareye bakınca hizalıydı. Ölçer açtığı sayfanın ürün olduğunu ilan eder;
   ulaşılamayan ekran sayılır.
7. **Yeşil sınav, hedefin doğru olduğunu söylemez.** Talepte yön yoktu, ajan varsaydı, sınav varsayımı ölçtü.
   Bu satır adım 4'teki "doğru şey mi" sütununun kaynağıdır.

**Üç renk:** koruyor (yeşil) · korumuyor (kırmızı) · **bakamadı (SARI, rc=3)**. Sarı yeşil değildir.
**Mutasyon:** kapı gerçekten kapı mı — kaynağı boz, sınav kırmızıya dönüyor mu; bozulan şey **kaynak mı düzenek mi**
ayrı yazılır (`kapi-sinavi mutasyon`).
**Bulgu da kanıt ister:** "kusur" dediğin şey bilinçli karar çıkabilir (S-94); bulguya kare/ölçüm eklenir.
**Ürünün çizdiği ile yazdığı aynı mı:** CSS kuralı sessizce düşünce altı düğme sistem yazısıyla çizildi, hiçbir sınav
"çizilen yazı ürünün yazısı mı" diye sormuyordu. Görünüm işinde bu soru en az bir kapıda sorulur.
**Vakayı aktaran da ölçer sayılır:** "X şöyle dedi" diye yazdığın rakamı kendin ölçmediysen öyle yaz.

## Kapı
Kanıt yoksa **adım 4 açılmaz**. PR gövdesinde "Kanıt" başlığı boşsa `pr-onay` özet üretmez. Kanıt bulunan
komutlar `olcum-disiplini boru` süzgecinden geçer (boru maskesi yakalanır).
