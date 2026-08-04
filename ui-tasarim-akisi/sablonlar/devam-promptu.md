# Durak 4 — Devam promptu (ikinci ve sonraki sayfalar)

> **Metodun püf noktası budur.** Bu şablon yazılmazsa ikinci sayfa birinciye benzemez ve elde
> tasarım dili değil, birbirinden habersiz ekranlar kalır.
>
> Yuvalar: `{{ONCEKI_HTML}}` · `{{SAYFA_SENARYOSU}}` · `{{TASARIM_DILI}}` · `{{ESTETIK_YON}}`
> Yapıştırılacak hâli: `arac/prompt-yap.sh <bu dosya> --onceki <önceki-sayfa>`
>
> **Zincir kilitlidir:** önceki sayfa gelmeden bu prompt üretilemez; araç hata verip durur,
> sessizce eksik prompt üretmez.
>
> Her yeni sayfa için bu şablondan bir kopya çıkarılır ve yalnız `{{SAYFA_SENARYOSU}}` doldurulur.

---

Aynı ürünün **bir sonraki sayfasını** tasarla. Aşağıda bu ürünün hâlihazırda tasarlanmış bir
sayfasının tam kaynağı var. Yeni sayfa **onun dilini sürdürmeli** — yeni bir tasarım denemesi
değil, aynı uygulamanın başka bir ekranı.

## Mevcut sayfa (dilin kaynağı)

```
{{ONCEKI_HTML}}
```

## Yeniden kullanım emri

- Yukarıdaki kaynakta geçen bileşenleri **aynen kullan**: aynı işaretleme yapısı, aynı sınıf
  adları, aynı değişkenler, aynı ölçüler. **Kopyala, yeniden yorumlama.**
- Gezinme ve başlık şeridi **birebir aynıdır**; yalnız aktif gezinme öğesi ve başlık metni değişir.
- Yeni bir bileşen gerçekten gerekiyorsa: önce sözlükteki adlardan biriyle karşılanıp
  karşılanmadığına bak. Karşılanmıyorsa yeni adı **açıkça bildir** ve işaretle.
  **Sözlük dışı ad sessizce icat edilmez.**
- Renk, tipografi kademesi, boşluk ölçeği, köşe yuvarlaklığı ve gölge **kımıldamaz**.

## Fark tarifi

{{FARK_TARIFI}}

Varsayılan: değişen **yalnız içerik bölgesidir**. Gezinme, üst şerit, tipografi ve renk aynı kalır.
İki ekran yan yana konduğunda aynı uygulamanın iki hâli olduğu **bir bakışta** anlaşılmalı.

*Bu sayfa bir panel/katmansa bunu açıkça yaz* — yazılmazsa model ayrı bir sayfa çizer ve iskelet
ikiye ayrılır.

## Yeni sayfanın senaryosu

{{SAYFA_SENARYOSU}}

---

{{TASARIM_DILI}}

---

{{ESTETIK_YON}}

---

## Çıktı

Yukarıdaki "Çıktı sözleşmesi" bölümüne birebir uy. Dosya bağımsız olmalı: mevcut sayfanın stilleri
yeni sayfaya da kopyalanır, ortak bir stil dosyası varsayılmaz.
