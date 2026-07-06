---
name: ekip-brief-iste
description: Ekipten kısa durum-raporu iste — herkese "durumunu yaz" ping'i at, sonra kanal-başlarını topla+özetle. Yönetici/Sultan-eli.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# /ekip-brief-iste — ekipten son-durum topla

**Kim çağırır:** ekip-yöneticisi ya da Sultan (USER-ONLY).
**Ne yapar:** Her üyeye "son-durumunu kendi kanalına ≤10-satır yaz" ping'i atar, kısa bekler, sonra her üyenin iş-çıktısı-kanalının başını okuyup Sultan'a tek özet çıkarır. Salt-okur toplama — hiçbir kanala YAZMAZ.

## Adımlar

1. **Ping at:**
   ```bash
   bash scripts/ekip-notify.sh all "durum-isteği: son-durumunu kendi kanalına ≤10-satır özetle (ne bitti · sıradaki · engel var mı)"
   ```
   Script `ozet:` satırında kaç üyeye gittiğini basar — kapalı-oturumları dürüstçe not al.
2. **Kısa bekle:** üye-Claude yanıtı ASENKRON. Sultan'a "üyeler kanallarına yazıyor, ~30-60sn sonra toplayacağım" de; hemen-toplama eksik-veri verir (best-effort). Beklemeyi Sultan'ın ritmine bırak — o "topla" deyince Adım-3'e geç.
3. **Kanal-başlarını oku:** her üyenin `kanallar`/`inbox` alanlarından (registry: `_agents/handoff/ekip-registry.yaml`) son girdiyi oku. Registry'yi oku → üye-listesini + kanallarını oradan al (hardcoded liste TUTMA).
4. **Özetle:** her üye için 1-2 satır (durum · sıradaki · engel) → Sultan'a tek tablo/liste. Yazamayan/kapalı üyeyi "yanıt-yok (oturum kapalı?)" olarak dürüstçe işaretle — boşluğu tahminle DOLDURMA.

## Sınırlar
- %100 salt-okur toplama; hiçbir kanala yazmaz.
- Bekleme senkron değil — eksik-toplama olabilir, bunu özet-başında belirt.
