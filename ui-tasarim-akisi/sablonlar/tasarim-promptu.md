# Durak 3 — İlk sayfanın tasarım promptu

> Bu bir **şablondur**; yuvalar dolmadan platforma verilmez.
> Yapıştırılacak hâli: `arac/prompt-yap.sh <bu dosya>`
> Sözleşme ve estetik yön buraya **elle kopyalanmaz** — kopya bayatlar, yuva bayatlamaz.

---

{{URUN_TARIFI}} için **ilk ekranını** tasarla. Bu, tasarım dilini kuran sayfa — sonraki sayfalar
bunun dilini sürdürecek.

## Kullanıcı

{{HEDEF_KULLANICI}}

Ekran açıldığı anda, **hiç tıklamadan** şu soruların cevabını görmeli:

1. {{ACILIS_SORUSU_1}}
2. {{ACILIS_SORUSU_2}}
3. {{ACILIS_SORUSU_3}}

Ayrı bir "gösterge paneli" sayfası **istemiyoruz**; bu sayfa hem içerik hem giriş ekranıdır.

## Sayfanın senaryosu

{{SAYFA_SENARYOSU}}

## Örnek veri

{{ORNEK_VERI_TARIFI}}

Ürünün durum kümesi varsa **hepsi** örnekte görünsün. Veriler gerçekçi ama uydurma olsun.

---

{{TASARIM_DILI}}

---

{{ESTETIK_YON}}

---

## Çıktı

Yukarıdaki "Çıktı sözleşmesi" bölümüne birebir uy. Özellikle: dış kaynak yok, her bileşende
`<!-- bilesen: Ad -->` yorumu, örnek veriler uydurma ve işaretli.
