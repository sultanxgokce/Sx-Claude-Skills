---
name: defter-kapisi
type: agent
version: 0.1.0
description: >
  Sultan'la doğal-dil sohbetinde iki tekrarlayan-anı standartlaştırır ki AI'ın izleyeceği yol NET olsun
  (refleks-hızında, tutarlı). (A) GÖREV-YAKALAMA KAPISI — Sultan bir işten/görevden bahsedince: önce
  YENİ-görev mi yoksa MEVCUT-konuya-ekleme mi olduğunu ayırt et; YENİ ise deftere yazmadan ÖNCE
  çoktan-seçmeli onay sor ("Yeni görev algılandı: [başlık] / [açıklama] — deftere kaydedeyim mi?
  [Evet / Düzenle / Hayır]"), EKLEME ise mevcut kaydı güncelle → böylece defter gürültüsüz + dublikasyonsuz.
  (B) MAILBOX-YANIT PROSEDÜRÜ — bir defter/mailbox mesajı gelince net-hızlı sıra: kartı-oku → anla →
  SADE-dille-yanıtla → gereken-aksiyonu-al → thread'i-kapat. Amaç: temiz defter + hızlı-tutarlı yanıt.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [defter, gorev-yakalama, mailbox, sultan-dili, kapi, onay-gate, capture, ilerleme-akisi]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Defter-Kapısı — görev-yakalama + mailbox-yanıt prosedürü

## Ne işe yarar
Sultan'la terminalde doğal-dil konuşurken **iki an** tekrar tekrar geliyor ve ikisi de standart-yol olmadan
ya gürültü ya yavaşlık üretiyor:

1. **Sultan bir işten bahsediyor** — ama her bahis "yeni görev" değil; bazısı zaten-var-olan bir işe
   eklemedir. AI ayırt etmeden deftere yeni-kart açarsa → **gürültülü/dublike defter**.
2. **Deftere yazdığı bir kart üzerinden AI'a mesaj atıyor** (mailbox) — AI'ın izleyeceği prosedür belli
   değilse → dağınık, yavaş, tutarsız yanıt.

Bu skill her iki anı da **çizili bir yola** oturtur. Sultan'ın sözüyle: *"yolun belli çizili olsa böylelikle
ne yapacağın net olur ve mesaj geldiğinde şak şak şak hızlı yaparsın."*

## Ne zaman devreye girer (tetikler)
- **PROTOKOL A:** Sultan doğal sohbette bir **iş / görev / yapılacak / "şunu da yapalım" / "şuna bakalım"**
  niyeti ifade ettiğinde. (Soru sorması, durum-istemesi, sohbet ≠ görev — A1 filtresi.)
- **PROTOKOL B:** Bir **defter/mailbox mesajı** geldiğinde (Nexus: `defter-mailbox.sh check` bekleyen döndürür;
  ya da harness "📬 Sultan mailbox'a yazdı" ile haber verir).

> **Güvenilir-tetik (hook backstop):** PROTOKOL A refleks-hızı model'e-bağlı olduğu için atlanabiliyordu.
> Nexus'ta `scripts/hooks/gorev-niyeti-nudge.sh` UserPromptSubmit hook'u, Sultan'ın mesajında görev-niyeti
> kalıbı görünce `🎯 görev-niyeti → defter-kapisi protokolü` bağlamını **model-bağımsız** düşürür. Bu bağlamı
> gördüğünde bu skill'in PROTOKOL A'sını ÇAĞIR (A1→A2→A3). Hook = güvenilir zil; skill = izlenecek yol.
> Hook sustuysa da (throttle/kill-switch) doğal-dil sinyali görülünce elle çağrılır — hook backstop'tur,
> zorunlu-koşul değil. (Kaynak-proje bu hook'u sunmuyorsa PROTOKOL A yalnız doğal-dil sinyaliyle tetiklenir.)

---

## PROTOKOL A — Görev-Yakalama Kapısı

### A1 · Algıla: bu bir görev-bahsi mi?
Her cümle görev değil. **Görev-sinyali:** yeni-yapılacak-iş, hedef, "şunu kuralım/yapalım/ekleyelim/düzeltelim",
gelecek-kip + eylem. **Görev-DEĞİL:** soru ("X nedir?"), durum-isteği ("nerede kaldık?"), onay/ret, salt-sohbet,
zaten-yürüyen-işe-anlık-yönlendirme. Şüpheliyse görev-değil say (yanlış-kart açmaktansa açmamak yeğ).

### A2 · Ayır: YENİ görev mi, MEVCUT'a ekleme mi? (gürültü-önleyici çekirdek)
**Yazmadan ÖNCE mevcut açık-kartları tara** — konu-örtüşmesi var mı?
- Nexus: `bash scripts/defter-mailbox.sh` çevresindeki defter ya da `katip-defter.jsonl` / `/api/defter/*`
  açık-kartları; kart başlıkları + `ham_istek`/`sultan_ozeti` alanlarında konu-eşleşmesi ara.
- **Örtüşme VAR** → bu bir **EKLEME** (A4). Yeni-kart AÇMA.
- **Örtüşme YOK** → bu **YENİ görev** (A3).

> Sultan'ın nüansı (birebir): *"eğer bahsettiğim şey daha önce var olan konuya bir eklemeyse bunu da algılamalı
> ki gürültülü kayıtlar oluşmasın."* — A2 tam olarak bu.

### A3 · YENİ görev → çoktan-seçmeli onay (yazmadan önce SOR)
`AskUserQuestion` ile **tek soru** sor — başlık + kısa-açıklama taslağını sen üret, Sultan onaylasın:

```
Soru:  "Yeni görev algılandı — deftere kaydedeyim mi?"
        Başlık:   <senin-önerdiğin kısa başlık>
        Açıklama: <senin-önerdiğin 1-2 cümle sade açıklama>
Seçenekler:
  • Evet    → taslağı olduğu gibi kaydet
  • Düzenle → Sultan başlık/açıklamayı değiştirsin, sonra kaydet
  • Hayır   → kaydetme (salt-sohbetti / gerek yok)
```
(header ≤12 char: "Defter". "Evet" ilk-sırada = önerilen.) **Onay gelmeden deftere YAZMA.**

### A4 · EKLEME → mevcut kaydı güncelle (yeni-kart AÇMA)
Örtüşen kartı bul, Sultan'ın yeni-detayını o kaydın açıklamasına/notuna işle. Belirsizse hafif-doğrula:
"Bunu [mevcut-kart-başlığı]'na ekliyorum, doğru mu?" — ama yeni-kart açma refleksine düşme.

### A5 · Yaz (yalnız onaydan sonra)
Onaylanan başlık+açıklamayı projenin defter-yazma-yoluyla kaydet (Nexus: defter/katip kaydı). Kaydettikten
sonra tek-satır teyit: "📒 kaydedildi: <başlık>". Sultan'a değer-döndür, sessizce yazıp geçme.

---

## PROTOKOL B — Mailbox-Yanıt Prosedürü

Bir defter/mailbox mesajı geldiğinde şu **5 adımı sırayla** uygula — dağılma, hızlı ol:

### B1 · Al
`bash scripts/defter-mailbox.sh check` (bekleyeni gör) → `... raw <id>` (tam içerik + hangi kart). Hangi
karta/konuya ait olduğunu netleştir.

### B2 · Anla
Kartın **kanonik içeriğini** oku (Nexus: `katip-defter.jsonl` ilgili kayıt + varsa overlay). Sultan ne
soruyor/ne istiyor: açıklama mı, değişiklik mi, kaldırma mı, karar mı? Tek-cümlede kendine özetle.

### B3 · Sade-dille yanıtla
Sultan'a **jargonsuz** cevap ver (bkz. `/sultanca` skill'i varsa uygula). Kart-içeriği belirsizse önce
netleştir; teknik-terim yerine "ne işe yarıyor / ne değişecek" dilini kullan.

### B4 · Aksiyon al
Mesaj bir **değişiklik/karar** istiyorsa uygula:
- İçerik-güncelleme (özet/detay) → **deploysuz** override-yolu (Nexus: `/api/defter/ozet` SERDAR-token ile
  POST; anında canlı, redeploy YOK). Bkz. defter overlay-mimarisi.
- Kaldırma → durum-override (`iptal`) ya da projenin gizleme-yolu.
- Yeni-iş → PROTOKOL A'ya devret (A3 onay-gate).

### B5 · Thread'i kapat
`bash scripts/defter-mailbox.sh reply <id> "<sade-yanıt>"` ile Sultan'a dönüş yaz (mailbox → onun terminaline
düşer). Aksiyon aldıysan "yaptım: <ne>" de. Thread'i asılı bırakma.

---

## Değişmezler / Yasaklar
- **A3 onay-gate atlanmaz:** Sultan onaylamadan yeni-kart YAZMA. Şüphe → sor ya da yazma.
- **Dublikasyon-önleme A2 zorunlu:** yazmadan önce mevcut-kartları tara; ekleme'yi yeni-kart yapma.
- **İçerik-güncelleme deploysuz olmalı** (varsa): redeploy bekletme; override-yolu kullan (Sultan bunu açıkça
  istedi — "yazışarak içeriği hemen güncelleyebilmeni (deploysuz) isterim, bu önemli").
- **İnsan-onay-alanına yazma:** onay/karar Sultan'ındır; sen taslak-öner + uygula, onay-değeri üretme.
- **Sade-dil:** Sultan'a dönüşte jargon yok (`/sultanca`).

## Global-bağlantı notu
Bu skill **global** kurulur (`_global` → HOME=/config, her projede yüklenir). Nexus'a özgü uçlar
(`defter-mailbox.sh`, `katip-defter.jsonl`, `/api/defter/ozet`) **defansif** referanslanır: o mekanizma yoksa
**PRENSİP** yine geçerli — (A) yeni-görev-öncesi-onay-gate + ekleme-birleştirme, (B) gelen-mesajda
oku→anla→sade-yanıtla→aksiyon→kapat. Projenin kendi defter/inbox mekanizmasına eşle. Sultan-kuralı:
*"yaptığımız güncellemeler bağlantılı olarak globalde güncellenmeli"* → bu skill'e saha-iyileştirmesi gelirse
kaynak `Sx-Claude-Skills/defter-kapisi`'nde düzenle + `node sync-skills.mjs --apply` ile propagate et.
