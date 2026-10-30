---
name: whatsapp-gonder
type: agent
version: 1.2.0
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

## 🔴 `alici_bu_kutuya_kapali` (403) — ölçüldü 2026-09-09

Geçit, **kutu → alıcı** iznini kendi tutar. Bir kutudan Sultan'a gönderim çalışırken
başka bir alıcıya `403 {"hata":"alici_bu_kutuya_kapali","kutu":"<kutu>"}` dönebilir.

**Bu bir istemci arızası DEĞİLDİR** ve kutuda çözülemez: ayar `cloudtop-wa` içindedir,
izole kutu oraya erişemez. Doğru yol merkeze (s01) **tetikli** talep bırakmaktır
(`federe-os-cekirdek`), kutuda ayar aramak değil.

**Teşhis sırası — hangi katman reddediyor:**
| gözlem | katman |
|---|---|
| `--durum` → 🔴 ulaşılamıyor | ağ / geçit ayakta değil |
| `--durum` → 🟡 oturum kapalı | WhatsApp oturumu (QR gerekir → `whatsapp-baileys`) |
| `--durum` → 🟢 ama gönderim 403 | **izin listesi** — merkez açar |
| 🟢 ve başka alıcıya gidiyor | alıcı adı sözlükte yok |

> ⚠️ **Çıkış kodunu boru hattından okuma.** `bash $S … | tail -3; echo $?` **tail'in**
> kodunu basar; reddedilen bir gönderim ekranda `0` görünür. Ölçüldü 2026-09-09, aynı
> gün ikinci kez. Doğrusu: `out=$(bash $S …); rc=$?; echo "$out"`.

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

## İ1 sınırı — etiket sır DEĞİLDİR (ölçülmüş, 2026-09-09)

Geçitte bir alıcıya gönderim kapalıysa açılması için merkeze **adı** yazmak gerekir.
MUHASİP bunu yapmadı: *"alıcı adını buraya koymuyorum"* dedi ve **açılması gereken kapıyı,
açacak kişiden gizledi.** Talep bir tur boşa gitti.

🔴 **Ayrım:** sır olan **numaradır**. Sözlükteki ad yalnız bir etikettir (`Arçelik-Yönetim`,
`TamamlayiciSatis` cinsinden) ve zaten merkezde açık durur. İ1 *içerik ve sır* der, *etiket*
demez. Kanalda yazılır:

| Yazılır | Yazılmaz |
|---|---|
| etiket (`Resul`) | telefon numarası |
| hangi kutunun kime kapalı olduğu | mesajın gövdesi |
| ret kodu | kişisel veri, adres |

**Numarayı Sultan verir, kanaldan değil.** Sen yalnız etiketi bildirirsin.

### Ret kaydının kör noktası
Geçidin ret kaydı **kimin** reddedildiğini yazmıyor:
`{"m":"gonderim-RED","kutu":"mmex","hata":"alici_bu_kutuya_kapali"}` — alıcı alanı yok.
Yani merkez hangi adı eklemesi gerektiğini göremez, sen de hangi adın kapalı olduğunu.
Teşhisi **kıyaslayarak** kurarsın (birine gidiyor, ötekine gitmiyor → fark alıcıda) —
bu bir çıkarımdır, okuma değil; raporunda öyle yaz.

### İzin modeli — grup YOK, liste var (merkez ölçtü)
Her kutu bir **alıcı adları listesi** taşır; rol/grup kavramı yok. Yeni ad eklemek
merkezde **elle** yapılır, kod yazmaz. "Topluca açma"nın tek yolu tam yetkidir ve o
bilerek kapalıdır. Bir ad eklemek yeni yetenek değil, satır eklemektir — **iki addan
fazlasını ölçülmüş gerekçe olmadan isteme.**
