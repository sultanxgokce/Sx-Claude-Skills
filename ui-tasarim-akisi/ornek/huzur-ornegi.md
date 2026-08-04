# Örnek — metodun ilk kullanıldığı iş

*Bu dosya şablon DEĞİL, örnektir. Şablonlarda ürün adı geçmez; burada geçer, çünkü örneğin
somut olması gerekir. Kaynak: huzur (randevuyla çalışan uzmanlar için randevu/danışan yönetimi),
4 Ağustos 2026.*

---

## Durak 1 — envanter

Yedi kalemlik bir faz, **16 ekrana** açıldı. Ama 16 ekran ≠ 16 sayfa: gezinme üç kalem
(Ajanda · Danışanlar · Ayarlar), gerisi sekme, panel, akış ve görünüm oldu.

**En değerli karar burada verildi:** açılış ekranı için ayrı bir gösterge paneli **icat edilmedi.**
Önce açılışta sıfır tıkla cevaplanması gereken üç soru yazıldı; sonra bakıldı ki üçü de zaten
ajanda ekranından okunuyor. Araya özet sayfası koymak her açılışa bir tık ekleyecekti.

## Durak 2 — senaryolar

16 ekranın 16 kartı yazıldı; her kartta `Tık bütçesi:` satırı zorunluydu. Mekanik denetim:
`grep -c "Tık bütçesi:"` → 16.

Dokuz kanonik görev tanımlandı, hedefleriyle. En kritik ikisi:
- "Bugün kim geliyor" — **0 tık** (açılışta görünmeli)
- Mevcut kişiye yarına randevu — **≤4 tık + 1 alan**

Web araştırması bu aşamada yapıldı ve **kararları değiştirdi**: sektörde randevu paneli slota
tıklanınca açılıyor, süre hizmet türünden geliyor, dolu saatler hiç listelenmiyor. Üçü de
senaryolara girdi. Bir bulgu da tersini yaptırdı: taranan dört üründe "işaretlenmemiş randevu
kuyruğu" yoktu — biz yine de tuttuk, ama **bilinçli sapma** olarak, gerekçesi ve çıkış yolu yazılı.

## Durak 3 — sözleşme + estetik yön + ilk prompt

Sözleşme 15 bileşenlik sözlükle kuruldu. Palet iki seçenekle sahibine soruldu, seçim yapıldı ve
**kontrastlar ölçüldü** — altı çiftin hepsi erişilebilirlik eşiğinin üstünde çıktı.

Estetik yön dosyasının en değerli maddesi **hazır kalıp uyarısı** oldu. Seçilen palet (kırık beyaz
+ koyu kahve), yapay zekâ tasarımının en yaygın varsayılanının tam ortasındaydı. Palet sahibinin
bilinçli seçimiydi ve tartışılmadı; ama onunla gelen refleks açıkça reddedildi: *serif başlık yok,
dergi düzeni yok, sıcaklık zeminde kalır jestte değil.* Tek cümlelik özeti şuydu:

> **Sıcak bir palet, soğukkanlı bir araç.**

Bu satır yazılmasaydı model paleti görüp editöryel bir açılış sayfası çizerdi; oysa ürün günde
onlarca kez açılan bir çalışma aracıydı.

İlk prompt 362 satır oldu: senaryo + sözleşme + estetik yön, hepsi yuvadan.

## Durak 4 — devam promptu

İkinci sayfanın promptu **797 satır** oldu, çünkü içine ilk sayfanın tüm kaynağı gömüldü.

**Sonuç ölçüldü:** ikinci ekran, birincinin **on bileşenini aynen devraldı**. Beş bileşen sözlükten
ilk kez doğdu. Bir tane yeni ad gerekti — ve model onu **sessizce icat etmedi, bildirdi**:

> *"Sözlük dışı yeni ad bildiriyorum: `Anahtar` (aç/kapa anahtarı)... sözleşmeye eklenmesi gerekir."*

Şablondaki "sözlük dışı ad sessizce icat edilmez, bildir" kuralı tam olarak bunun için vardı.
Ad sözleşmeye eklendi ve değişiklik günlüğüne gerekçesiyle yazıldı.

## Üç denetim — gerçek çıktılar

**Bileşen tutarlılığı** (ikinci ekran):
```
ajandadan devralınan (10): BilgiSeridi · BosDurumMesaji · BosSlot · Dugme · DurumRozeti
                           NavCubugu · RandevuKarti · SaatIzgarasi · SayfaBasligi · SimdiCizgisi
bu sayfada ilk kez    (6): Anahtar · AramaAlani · DanisanSatiri · FormAlani · OnayDiyalogu · YanPanel
SÖZLÜK DIŞI AD          : Anahtar   (bildirilmiş → sözleşmeye eklendi)
```

**Kısıt denetimi** (18/18 geçti): tür seçici yok · süre alanı yok · ücret alanı yok · panel sağdan
açılıyor ve arkadaki ekran duruyor · sert çakışmada satır içi hata · yumuşak çakışmada onay
diyaloğu · kaçış kapısı var · örnek adlar işaretli · dış kaynak yok · erişilebilirlik tabanı tam.

**Tık sayımı:**
```
gün ileri                     1 tık
boş slota tık → panel         1 tık
kişi ara → öneriden seç       1 tık + 1 alan
Kaydet                        1 tık
────────────────────────────────────
TOPLAM 4 tık + 1 alan · HEDEF ≤4 tık + 1 alan → TUTTU
```
Araya adım ekleyen desen yok: onay ekranı yok, sihirbaz adımı yok, süre seçimi yok.

## Neyin işe yaradığı — dürüst değerlendirme

**İşe yarayan:**
- **Önceki sayfanın kaynağını gömmek.** Tutarlılığı sağlayan asıl şey bu. "Şu dile benzet" tarifi
  değil, gerçek kodu görmek.
- **Bileşen sözlüğü + `<!-- bilesen: -->` işareti.** Tutarlılığı *grep'lenebilir* yapıyor; yoksa
  "benziyor mu" tartışması öznel kalır.
- **"Şunu yapma" listesi.** Modele ne yapacağını söylemek yetmiyor; yasakları yazmazsan alışıldık
  deseni ekliyor.
- **Hazır kalıp uyarısı.** Palet bir varsayılana yakınsa, o varsayılanın refleksini açıkça
  reddetmek gerekiyor.
- **Tık bütçesini karta yazmak.** Ölçülebilir tek kalite göstergesi buydu.

**Zaman kaybı olan:**
- Erişim/kimlik sorunlarını tasarım metoduna karıştırmak. Platforma erişememek ayrı bir sorundur;
  akış ondan bağımsız çalışır ve öyle kurulmalıdır.
- Dolaylı sinyallere bakıp bir yolun kapalı olduğuna karar vermek. Bir kez çalışan bir yolu
  "kullanılamaz" ilan ettim; ölçünce çalıştığı çıktı. **Kanıtsız kırmızı da kanıtsız yeşil kadar
  zararlı.**

**Beklenmedik:** platform ilk çıktıyı verdikten sonra kendini birkaç tur daha rafine ediyor.
İlk çekilen dosya son sürüm olmayabilir. Çıktı **yeniden çekilip karşılaştırılmalı**; "bitti mi"
diye sormak yerine ölçmek daha hızlı.

## Bu örnekte hâlâ ürüne özgü kalan

- Ekran adları, kısıt numaraları (K/A serileri) ve alan listeleri huzur'a aittir.
- "Randevu numarası görünür olmalı" gibi kancalar o ürünün gizlilik kısıtından gelir.
- Örnek veri kuralı (`… Test` soyadı) bu ekibin kararıdır; başka ürün başka işaret seçebilir.

Şablonlarda bunların hiçbiri geçmez; hepsi parametredir.
