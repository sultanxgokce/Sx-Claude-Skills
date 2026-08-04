# Durak 2 — Senaryo kartı

*Envanterdeki her ekran için bir kart. Bu kartlar Durak 3/4'te prompta **birebir** gömülür,
o yüzden prompta yazılacak dille yazılır.*

---

## Tık sayım kuralı — TEK yerde tanımlı

Bu kural tüm kartlar için geçerlidir ve başka yerde tekrar edilmez:

- **1 tık** = fare tıklaması / dokunma. Menü açmak da tıktır.
- **1 alan** = klavye girişi gereken bir alan. Kaç karakter olursa olsun 1 sayılır.
- **Sayılmaz:** sayfa yüklenmesi, otomatik odak, ön-dolu değerler.
- **Yazım:** `"3 tık + 2 alan"`.
- **Sayım açılış ekranından başlar.**

Bu kural yazılmazsa herkes farklı sayar ve "kaç tık" ölçüsü ölçü olmaktan çıkar.

---

## Kanonik görevler — tık bütçesi bunlar üzerinden ölçülür

Ürünün **en sık tekrarlanan** işleri. Beş-on tane; hepsi değil.

| # | Görev | Hedef | Gerçekleşen |
|---|---|---|---|
| G1 | {{GOREV_1}} | | *(tasarım gelince dolar)* |
| G2 | {{GOREV_2}} | | |

Hedefler bir **iddiadır**; tasarım gelince HTML üstünde izlenir ve gerçekleşen sütunu dolar.
Aşım sessiz geçilmez.

---

## Kart şablonu — her ekran için doldurulur

```markdown
### E# · <ekran adı>

**Amaç:** <bu ekranda biten iş, tek cümle>
**Giriş:** <nereden gelinir; açılış ekranından kaç tık>
**İlk bakışta:** <ekran açılınca görünenler, ÖNCELİK SIRASIYLA — üstten alta değil,
  gözün gitmesi gereken sırayla>
**Ana akış:** <numaralı etkileşim dizisi; en sık yapılan yol>
**Tık bütçesi:** <yukarıdaki kurala göre; bu satır BOŞ BIRAKILAMAZ>
**Kenar durumlar:** <boş hâl · hata · çakışma · onay gereken yer — her biri ne yapar>
**Kısıt kancaları:** <bu ekranda hangi ürün kısıtları geçerli, ne ÇİZİLMEZ>
```

---

## Kart yazarken üç sık hata

**1 · "Güzel görünsün" yazmak.** Kart tasarımcıya değil, prompta yazılır. "Modern ve temiz" bir
talimat değildir. Ölçülebilir olan yazılır: kaç alan, kaç tık, ne görünür, ne görünmez.

**2 · Boş hâli atlamak.** Her liste bir gün boştur ve ilk kullanıcı onu **her zaman** görür.
Boş ekran üç şey söyler: ne olduğu · burada ne görüneceği · doğrudan bir eylem. Boş beyaz alan
bırakmak tasarım değil, eksikliktir.

**3 · Çizilmeyecekleri yazmamak.** Modele "şunu yap" demek yetmez; **"şunu yapma"** da yazılmalı.
Yoksa alışıldık deseni ekler: olmayan bir alan, gereksiz bir onay ekranı, sihirbaz adımı.
Her kartta "Kısıt kancaları" bu iş içindir.

---

## Bitti sayılma kanıtı

Envanterdeki her ekranın kartı var ve her kartta `Tık bütçesi:` satırı **dolu**.
Mekanik denetim: kart sayısı = envanter satır sayısı, `grep -c "Tık bütçesi:"` = kart sayısı.
