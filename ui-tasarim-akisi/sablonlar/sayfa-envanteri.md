# Durak 1 — Sayfa envanteri

*Şablon. `{{...}}` yuvalarını doldur, örneği sil.*

## Kural

Envanterin işi **hangi ekranlar var** sorusunu kapatmaktır — nasıl görünecekleri Durak 2'nin işi.

**Ekran sayısı ≠ sayfa sayısı.** Bir kalem şunlardan biri olabilir ve bu ayrım baştan yapılır,
yoksa sonradan her şey ayrı sayfa olur ve ürün şişer:

| Nerede yaşar | Ne zaman |
|---|---|
| **Sayfa** (gezinmede kendi kalemi var) | Kullanıcı ona doğrudan gitmek ister |
| **Panel** (bir sayfanın üstüne açılır) | Bir işi bitirir, sonra kapanır; arkadaki bağlam korunmalı |
| **Sekme** (bir sayfanın bölümü) | Aynı ailenin ayarları/görünümleri |
| **Akış** (birkaç adım, kendi sayfası yok) | Diyalog + kayıt; ayrı ekran gerektirmez |
| **Görünüm** (başka ekranın içinde) | Zaten görünen bilginin başka türlü sunumu |

## Ürün

- **Ad:** {{URUN_ADI}}
- **Ne:** {{URUN_TARIFI}}
- **Kullanıcı:** {{HEDEF_KULLANICI}}

## Gezinme

Üst düzey gezinme **kaç kalem**? (Üçten fazlaysa gerekçesi yazılır — her kalem kullanıcının
kafasında bir yer tutar.)

```
{{GEZINME}}
```

## Envanter

| # | Ad | Bitirdiği iş (tek cümle) | Nerede yaşar | Tur | Bağlı kısıt |
|---|---|---|---|---|---|
| E1 | | | sayfa/panel/sekme/akış/görünüm | ilk/sonra | |
| E2 | | | | | |

**Tur sütunu:** ilk turda tasarlanacaklar işaretlenir. İlk tur **dörtten fazla olmasın** — dili
kuran sayfa + onu tüketen üç sayfa yeterli kanıttır; gerisi aynı zincirle gelir.

## Açılış ekranı — ayrı bir "gösterge paneli" icat etme

Açılış ekranı, kullanıcının **sıfır tıkla** cevap alması gereken soruların ekranıdır. Önce o
soruları yaz:

1. {{ACILIS_SORUSU_1}}
2. {{ACILIS_SORUSU_2}}
3. {{ACILIS_SORUSU_3}}

Sonra bak: bu soruların hepsi **zaten var olan bir ekrandan** okunabiliyor mu? Okunabiliyorsa
açılış o ekrandır. Araya bir özet sayfası koymak her açılışa bir tık ekler.

## Bitti sayılma kanıtı

- Her satırda "bitirdiği iş" tek cümleyle yazılı.
- Her satırın "nerede yaşar" sütunu dolu.
- İlk tur ≤4 ekran.
