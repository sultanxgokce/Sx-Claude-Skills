# 0 · KABUL — iş kartı ve sınıf

İş, kartı yazılmadan başlamaz. Kart dört satırdır ve işin yanında yaşar (PR gövdesinin başı; F3'te araç yazacak):

```
İŞ: <tek cümle, Sultan-dilinde>
KİM İSTEDİ: <Sultan | reis | mektup ref>     KİM ALDI: <ajan>     NE ZAMAN: <YYYY-MM-DD HH:MM>
SINIF: <yok | geri-alınamaz | para | dış-yüzey | yetki>     → BAŞLAMA İZNİ: <gerekmiyor | Sultan (veto)>
KANIT NEREDE OLACAK: <_agents/fabrika/kanit/<iş>/ | ölçüm çifti | kare>
```

## Sınıf — dört soru, biri "evet" ya da "emin değilim" ise BAŞLAMA İZNİ Sultan'a gider (veto penceresi)
1. **Geri alınamaz mı?** (silme · göç · prod veritabanı · yayın geri alınamıyorsa)
2. **Para mı?** (abonelik · ödeme · faturalama · kota satın alma)
3. **Dış yüzey mi?** (müşterinin/dışarının gördüğü sayfa, mesaj, e-posta, marka)
4. **Yetki genişletiyor mu?** (yeni erişim · anahtar · kanca · filo-ortak ayar)

**Şüphede sınıf yukarı.** Yanlış tarafta hata yapılacaksa fazla sormak tarafında yapılır. Canlı vaka (21 Eyl):
görünüm değişikliği "kusur düzeltmesi" sanılıp peşin onayla yayınlandı; Sultan "bozulmuş" dedi.
"Bu dış yüzey mi, iç mi" tereddüdü = dış.

## Sınıflı iş — başlama izni Sultan'ın, kararlar reisin (0.21.0 · Sultan D1 22 Eki 2026)
Kural metni BURADA yaşar. Sultan (session_01Ge4BawKcUrcm1pdV8WANyF): *"sadece ara kararlar değil birleştirme kararları da reise
geçsin"* (işler kapısında ayda 1.138 saat bekledi).
- **Başlama izni Sultan'a gider, iş bekletilmez:** sınıflı kartta `baslama_izni: bekliyor`; izin isteği `--oda` odasına gider,
  satır komut taşımaz ("durdurmak için 'dur' demen yeter").
- **Veto:** Sultan'ın "dur"unu ajan `kart.sh sultan-dedi <iş> --karar dur` ile işler → `reis-dedi` · `daralt` · `bitti` rc 1;
  `--karar basla` vetoyu kaldırır (son kazanır). Sınıfsız kartta basla/dur rc 1 (veto penceresi yok).
- **Ara kararlar (devam · daralt · geri-al) ve birleştirme kararı reisin:** gerekçeli `kart.sh reis-dedi`; `bitti` kararı
  `birlestirme_karari{karar_veren: reis}` olarak yazar. Dağıtım Sultan eli. A06: reis kaydı ayrı alanda, Sultan sözü değildir.
- **Geriye uyum:** eski kart "bekliyor · veto yok" sayılır; eski Sultan kararları geçerli, şart değil.
- **İkinci kartta** (`fabrika-merge-reise-parca2`): kapı/denetçi/gün sonunun vetoyu okuması, ulaşım yolu yokken kartın
  açılmaması, sınıflı işte canlı borcun reise geçmesi.

## Sınıfsız iş
Ekipte biter: kanıt + bağımsız göz puanı + damga ile deftere girer; gün sonu özetinde "içeride bitirdiklerimiz"
bölümünde görünür. Sultan sonradan "bunu bana sormalıydınız" derse sınıf kuralı o vakayla düzeltilir.

## Tetikli mesaj
**Görev bağı (0.11.0):** iş defterde bir göreve karşılık geliyorsa kartı ona bağla: `kart.sh ac … --gorev gorev_<kimlik> --tahmin <dk>`. Açılışta görev "çalışılıyor" olur, bitince "onay bekliyor", tıkanınca "bekliyor" — Sultan'ın "çalışılıyor" ekranı bunu okur. Bağsız kart o ekrana düşmez.

**Kapsam = teslim birimi** (retro W42 ders M2): kart tek depoda, tek PR'da, bir günde teslim edilecek kadar olsun. `kart.sh ac` cümlede iki depo adı ya da haftalık kapsam görürse UYARIR (red değil) ve depo başına / gün başına kart önerir; uyarı karta da yazılır.

Kart açılınca ilgili odaya `oda-tetik` ile tek satır (var olan hat, L42): "<iş> alındı · sahip <ajan> · sınıf <x>".
Kart kapanınca aynı hattan "bitti · kanıt <yol> · puan <n>/5 <E/H>".

## Sahiplik ve tıkanma
- Bir işin tek sahibi olur; sahibi değişirse kart güncellenir (eski sahip yazar, yeni sahip onaylar).
- Tıkanma = 3 mektup cevapsız **ya da** 24 saat ilerlemeyen iş → reis → SERDAR (yalnız kutular-arası) → Sultan.
