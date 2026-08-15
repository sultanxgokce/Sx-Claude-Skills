---
name: whatsapp-gonder
type: agent
version: 1.1.0
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
bash $S --dosya /config/projects/tez/rapor.pdf --not "ilk taslak"   # BELGE (ek) olarak
bash $S --dosya /config/projects/tez/ekran.png --gorsel             # satır-içi FOTOĞRAF olarak
```

`--gorsel` yalnız `--dosya` ile kullanılır ve **yalnız görünümü** değiştirir: aynı içerik
belge yerine satır-içi fotoğraf olarak düşer. Bayrak verilmezse davranış eskisi gibidir.

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
- **Ekin TÜRÜ de bildirilir.** Gövdeye dosyanın uzantısından türetilen `mimetype` konur.
  Bildirilmezse geçidin altındaki kütüphane kendi varsayılanını ("application/pdf") koyuyor;
  adı `.png` olan dosya karşıya **PDF olarak düşüyor ve açılmıyordu** (2026-08-15, 13+ kutu).
  Uzantı tahmin edilemezse alan hiç konmaz — geçit onu "bilinmeyen" sayar, pdf'e DÜŞMEZ.

## Ne zaman KULLANMA

- Toplu/otomatik bildirim akıtmak için — Baileys gayrıresmîdir, düşük hacim ilkesi geçerlidir.
  Rutin makine-alarmları için **ntfy** kanalı vardır.
- Sır/kimlik bilgisi göndermek için — mesajlar üçüncü bir platformdan geçer.

## Ortam

Geçit adresi varsayılan `http://cloudtop-wa:8790`; gerekirse `WA_GECIT` ile değiştirilir.
Kutunun iç ağda (`cloudtop_default`) olması gerekir.

**Kutu jetonu (2026-07-29'dan beri ZORUNLU):** geçit kimlik ister; jetonsuz istek
`401 {"hata":"jeton_yok"}` döner. Betik jetonu şu sırayla arar: `WA_JETON` ortam değişkeni →
`/config/.wa-jeton` (ilk satır). **Jeton bir SIRDIR** — ekrana, loga, hata mesajına ASLA
basılmaz; bu dosyada da yalnız KONUMU yazılır. Kayıt defteri: `Nexus/_agents/credentials.yaml`
→ `wa-gecit-kutu-jetonu`. Jeton yoksa istek 401 döner ve betik bunu açıkça söyler.

## Kademe (AHÎ)

**Çırak.** Tek betik, tek sorumluluk, taşınabilir (yalnız `curl` + `python3` ister).
Kalfa'ya terfi için: gönderim kaydı/telemetri + kuyruk-yedeği (geçit kapalıyken dosyaya yaz,
sonra akıt) + `ahi promote whatsapp-gonder`.
