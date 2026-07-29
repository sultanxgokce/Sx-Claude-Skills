---
name: whatsapp-gonder
type: agent
version: 1.0.2
description: >
  Herhangi bir kutudan Sultan'a WhatsApp mesajı/dosyası göndermenin TEK yolu. Kutu tarafında
  yapılandırma yoktur: geçit (cloudtop-wa) iç ağda durur, kutu yalnız ona seslenir. Numara
  bilinmez — alıcı ADI gönderilir, çözümü geçit yapar.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [whatsapp, bildirim, teslimat, filo, gecit]
---

# WhatsApp Gönder — filo geçidi istemcisi

Bu skill **eşleştirme/kurulum yapmaz**. Oturumu tutan, tek sıcak bağlantıyı sahiplenen ve
gönderimi yapan servis ayrıdır (`cloudtop-wa`). Buradaki iş yalnız ona seslenmektir.

> Kurulum/eşleştirme (QR, throttle, sürüm bug'ları) → **`whatsapp-baileys`** skill'i.
> Bu ikisi karıştırılmaz: biri **playbook**, bu **istemci**.

## Kullanım

```bash
S=/config/.claude/skills/whatsapp-gonder/scripts/wa-gonder.sh

bash $S --durum                                   # geçit ayakta mı, oturum açık mı
bash $S "işi bitirdim, rapor hazır"               # Sultan'a metin
bash $S --kime Sultan "..."                       # adlandırılmış alıcı
bash $S --dosya /config/projects/tez/rapor.pdf --not "ilk taslak"
```

Çıkış kodları: `0` gönderildi · `2` kullanım/ortam · `3` geçide ulaşılamadı (**mesaj gitmedi**) ·
`4` geçit reddetti (gövdede neden).

## Değişmezler

- **Numara ASLA burada durmaz.** Kutu alıcı ADI gönderir; ad→numara çözümü geçitte, sözlük
  dosyası da orada (0600). Kutuya sır dağıtılmaz.
- **Tek sıcak bağlantı geçittedir.** Hiçbir kutu kendi Baileys oturumunu açmaz — iki bağlantı
  ikisini birden düşürür ve yeniden QR gerektirir.
- **Kanıtsız yeşil yok.** `--durum`, servis ayakta ama oturum kapalıysa 🟡 der; ulaşılamıyorsa
  🔴 ve "mesaj GİTMEDİ" yazar. `0` yalnız geçit 200 dönerse basılır.
- **Teslim ≠ gönderim.** `0` "geçit kabul etti" demektir. Kritik bir bildirimde teslimi insan teyit eder.

## Ne zaman KULLANMA

- Toplu/otomatik bildirim akıtmak için — Baileys gayrıresmîdir, düşük hacim ilkesi geçerlidir.
  Rutin makine-alarmları için **ntfy** kanalı vardır.
- Sır/kimlik bilgisi göndermek için — mesajlar üçüncü bir platformdan geçer.

## Ortam

Geçit adresi varsayılan `http://cloudtop-wa:8790`; gerekirse `WA_GECIT` ile değiştirilir.
Kutunun iç ağda (`cloudtop_default`) olması yeterlidir — ek mount ya da ayar yoktur.

## Kademe (AHÎ)

**Çırak.** Tek betik, tek sorumluluk, taşınabilir (yalnız `curl` + `python3` ister).
Kalfa'ya terfi için: gönderim kaydı/telemetri + kuyruk-yedeği (geçit kapalıyken dosyaya yaz,
sonra akıt) + `ahi promote whatsapp-gonder`.
