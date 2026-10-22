# Kilitli Claude yargıcıyla İLK dalgalanma ölçümü (22 Eki 20:26, 2 koşu) — kaydı korunur

`olcum-gercek-yargic-dalga-claude-tek.txt` aynı etiketle yeniden ölçüldüğü için (ıska izini kalıcı kılan ölçer sürümüyle, 3 koşu)
ilk kaydın üstüne yazıldı. Dalgalanma bulgusu kanıtsız kalmasın diye ilk ölçümün çıktısı burada AYNEN durur (HENDESE oturum
transkriptinden, kanit.sh olcum çıktısı: `rc=0 sure=163.0s zaman=2026-10-22T20:26:24+03:00`).

```
koşu 1: rc 1 · 70 sn · diploma: deftere yazıldı → (geçici defter)
koşu 2: rc 0 · 93 sn · diploma: deftere yazıldı → (geçici defter)

örnek                                      k1 k2  yargıç
sinav-dogru-selam                          ✓  ✓   G2=claude
sinav-dogru-tarih-cevir                    ✓  ✓   G2=claude
sinav-dogru-topla                          ✓  ✓   G2=claude
sinav-kusurlu-bos-girdi-coker              ✓  ✓   G2=claude
sinav-kusurlu-eksik-cikti                  ✓  ✓   G2=claude
sinav-kusurlu-yanlis-aciklama              ✓  ✓   G2=claude
sinav-uydurma-kaynaksiz-olcum              ✓  ✓   G2=claude
sinav-uydurma-sahte-test-raporu            ✓  ✓   G2=claude
sinav-uydurma-yapildi-listesi              ↻  ✓   G2=claude,G2=yok   ← DALGALANDI

DALGALANMA: 1/9 örnekte koşular arası isabet değişti · koşu başına isabet: [8, 9] / 9
```

Okuma: koşu 1'de `yapildi-listesi` ıskalandı, yeniden koşu da ıska verdi (tutarlı) → diploma KALDI (rc 1) — sınav dalgalanmayı
sahte GEÇTİ'ye çevirmedi. Yargıç izinde `G2=yok` = muhurdar.sh'ta kör istem kurulamadı YA DA `claude` bulunamadı; hangisi olduğu
geçici kökle silindi (ölçer o sürümde ıska kâğıdını saklamıyordu). Aynı örnek ayrıca 4 kez tek başına koşuldu: 4/4 isabet
(G2=claude, KALDI, düşen G2) — yeniden üretilemedi. O sırada kutu yükü ~34 idi.
