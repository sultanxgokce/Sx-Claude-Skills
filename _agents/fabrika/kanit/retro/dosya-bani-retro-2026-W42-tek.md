# 🔁 HAFTALIK RETRO · 2026-W42 · BÂNİ
_koltuk: bani:0
_kutu: 6a25475ebd9e
_yazildi: 2026-10-17T16:05:59+03:00
_arac: retro.py 1.0.0

## Ölçüm (araç yazdı · elle değiştirilmez · `retro.py kutu --yenile` yeniler)
_aralık: 2026-10-12 → 2026-10-18_

| Kaynak | Değer | Kanıt |
|---|---|---|
| NOTES mesaj satırı | 246 (tarihsiz 0 sayılmadı) | `_agents/bani/NOTES.md` |
| ders / zaman kaybı / tıkanma satırı | 34 | aynı dosya, anahtar kelime |
| kart açılan / bitti / tıkandı | 20 / 16 / 4 | `_agents/fabrika/kartlar` (aldı = ajan) |
| bağımsız göz turu · ortalama tur/kart | 48 · 2.4 | `_agents/fabrika/kanit/*/DENETIM-*.json` |
| kaçış (KUTU GENELİ, ajan ayrımı yok) | 9 | `_agents/fabrika/kacis-defteri.log` |
| boşta bekçisi zili | 0 | `/config/.filo/bosta-bekcisi.log` |
| Sultan-eli adımı | ÖLÇÜLEMEDİ: tanımlı kaynak yok | — |

## 1 · Ne bitti
- B1) canlı kanıt sınıfı (kanit.py canli + kart canli-gerekir + kapı 2b) — Sx #354 kapıda 5/E; üç kart, 16 gerçek bulgu kapandı
- B2) boşta bekçisi — Nexus #1157 + cloudtop #672 (cron) birleşti; canlı sinyal BERİD+HENDESE 14:48, SERDAR teyitli
- B3) bugün listesi — Sx #355 (/api/bugun) + cloudtop #675 (şerit hapı + yan panel) kapıda; #675 Sultan kararı
- B4) /retro becerisi — bu dosyayı üreten araç (Sx PR, kart retro)

## 2 · Nerede zaman kaybettim (ölçüyle)
- Z1) kanıt dizinini rm ile yeniden ürettim, DENETIM-1.json gitti, tur sayımı tartışması · ölçü: 1 tur + 40 dk
- Z2) bekçi kartının cümlesi cron'u vaat etti, cron cloudtop'taydı → göz 3 tur 4/H "cron bu PR'da yok" · ölçü: 3 göz turu
- Z3) eski kapıda çöken önce-koşumu sınav portlarını tuttu → sonra-koşumu "kapı açılmadı" · ölçü: 1 tur
- Z4) oturum bağlamdan 3 kez yenilendi; NOTES çıpası sayesinde iş kaybı yok, yeniden okuma maliyeti var · ölçü: 3 kesinti

## 3 · Hangi araç/kural beni yavaşlattı
- A1) denetci.sh yalnız reis-dedi 'devam'ı tanıyor, 'daralt'ı okumuyor → daraltılan iş yeni kart + yeni PR istiyor
- A2) kart.sh kartı birincil depoya yazıyor, is-alani kapat kayıtsız kopyayı reddediyor → yol tuzağı (hafıza notuna yazıldı)
- A3) Bash kancası literal 'rm -rf' / 'git commit' metnini kapatıyor → her mutasyon/commit betiği dosyaya yazılıp koşuluyor

## 4 · Ne öğrendim
- D1) kart depo başına açılır; cümlede öteki depoyu vaat etme — göz PR gövdesini değil cümleyi okur
- D2) kanıt dizini rm ile yeniden üretilmez; DENETIM-*.json ders defteridir, kopyalanır silinmez
- D3) tarayıcı sınavı sabit port: yarım koşumun artığı sonraki turu kızartır → sınav önce süreç temizliği yapar

## 5 · Merkeze önerim
- Ö1) denetci.sh reis-dedi 'daralt' kararını tanısın → daraltma için yeni kart/PR zorunluluğu kalksın
- Ö2) kart.sh canli-ayarla ayrı kart: sahip doğrulamalı (--reis = kartın aldı alanı)
- Ö3) bekçinin 'gün kapandı / yarın' tanıması izole kutular için de kurala bağlansın (registry alanı)
- Ö4) NOTES'a günlük tarih başlığı standardı ('## ÇIPA YYYY-MM-DD') → retro ölçümü yaklaşık değil kesin olur

<!-- Yorum satırları ajanındır; merkez bunları DEĞİŞTİRMEZ. Z maddesi ölçüsüz geçmez. Ö maddesi en çok 5. -->
