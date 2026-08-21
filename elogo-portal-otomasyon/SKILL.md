---
name: elogo-portal-otomasyon
version: 0.1.0
description: e-Logo Entegratörlük Portalını tarayıcıyla sürer (Playwright) — UBL dosyasını e-Fatura Yükleme'den yükler, sıra numarası aldırır, gönderir. Servis SendDraftDocument kapısını kapattığı için portal tek yoldur. 🔴 KURU KOŞUM VARSAYILAN — "Gönder" geri alınamaz ve tutarlar milyonluk; gönderim ancak açık bayrakla. Her adımda beklenen öğe DOĞRULANIR, bulunamazsa DURULUR (sessiz yanlış tıklama = en pahalı hata). Kimlik kasadan gelir. "portalden fatura yükle · sıra numarası al · e-Fatura Yükleme" tetiğinde.
---

# elogo-portal-otomasyon — portalı süren el

**Kademe:** Kalfa · **Doğum:** 2026-08-22, MUHASİP · **Karar:** Sultan ("kendi taslak oluştursun,
sıra numarası alsın, göndersin") · **Sınırları koyan:** MUAVİN, aynı gün

**Niçin portal:** servis tarafı bu kapıyı kapatmış (ölçüldü: `SendDraftDocument` → BadRequest,
geçersiz docType). Portal açık. Kap ayrı tutuldu: **kes/kesme kararı** `arcelik-fatura-kesim`'de,
**belge kurma** `elogo-erisim`'de, **portalı sürmek** burada.

## 🔴 DÖRT SINIR — tartışmaya açık değil (MUAVİN, Sultan kararı)

1. **ÖNCE DEMO.** Akış demo portalinde kurulur ve kanıtlanır. **Canlı portalde ilk koşuyu
   Sultan izler.** Kanıtsız canlı koşum yok.
2. **KURU KOŞUM VARSAYILAN.** Son adım ("Gönder") **varsayılan olarak DURUR**; gönderim ancak
   açık bayrakla (`--gercekten-gonder`). Gerekçe: geri alınamaz + buradaki tutar 1,7 milyon TL.
3. **KİMLİK KASADAN.** Portal e-postası/şifresi koda, argv'ye, log'a **gömülmez**; kasadan
   ortama çözülür, değeri hiçbir yere basılmaz.
4. **HER ADIMDA DOĞRULA, BULAMAZSAN DUR.** Ekran değişirse sessizce yanlış yere tıklama.
   Beklenen öğe yoksa → ekran görüntüsü al, **DUR**, söyle. *Sessiz başarısızlık burada en pahalı hata.*

## Ortam — root'suz kutuda iki sessiz tuzak (ikisi de ölçüldü, ikisi de çözüldü)

`scripts/ortam.sh` bunları kurar; `ortam-dogrula.py` gerçekten çalıştığını **kanıtlar**.

| Tuzak | Belirti | Çözüm |
|---|---|---|
| **Kütüphane eksiği** | Chromium hiç açılmaz; `libglib-2.0.so.0 not found` (17 kütüphane) | `LD_LIBRARY_PATH=…/micromamba/envs/pw-libs/lib` |
| 🔴 **FONT YOK** | Tarayıcı **ayakta görünür** ama `inner_text` boş, `click` "not visible" der | `pw-libs/fonts` → `~/.local/share/fonts` symlink |

🔴 **Font tuzağı SESSİZDİR** — en tehlikelisi bu. Hiçbir hata mesajı vermez; otomasyon sebepsiz
başarısız olur, insan "portal değişmiş" sanır. **Teşhis parmak izi: `boundingBox()["height"] == 0`.**
Metin render edilmediği için her öğe *hidden* sayılır. Ölçüm: 0px → font bağlandıktan sonra 26px.
`ortam-dogrula.py` bu durumu **adıyla** raporlar (exit=2), "bir şey oldu" demez.

## Ölçülen — portal giriş sayfası (demo, 2026-08-22, salt-gözlem)

```
https://efatura-demo.elogo.com.tr  →  /Account/LoginPage   (http 200)
başlık: "eLogo | Entegratörlük Portalı"
kullanıcı alanı : input[placeholder="e-Posta Adresi Giriniz"]   (type=text)
şifre alanı     : input[name="password"]                        (placeholder="Şifre Giriniz")
```

⚠️ **id'lere GÜVENME:** gözlenen id `input-logo-elements-text-field-7` — **sonundaki sayı üretilmiş**;
render sırası değişince kayar. Bu yüzden seçici olarak `name` ve `placeholder` kullanılır, id değil.
(Bu, "sessizce yanlış yere tıklama" riskinin ta kendisidir — sayı kayarsa id başka bir alanı tutar.)

## 🔴 GATE — portal kimliği KASADA YOK

Portal **e-posta + şifre** ister. Kasadaki `ELOGO_DEMO_WS_*` üçlüsü **SOAP servisi** içindir ve
kullanıcı adı bir **numara**dır, e-posta değil → **portal kimliği ayrı bir kimliktir.**
Kasada aranan adlar: `ELOGO_PORTAL_DEMO_EPOSTA` · `ELOGO_PORTAL_DEMO_SIFRE` → **bulunamadı.**

**Bu yüzden girişten sonraki akış ÖLÇÜLEMEDİ.** Aşağıdaki adımlar **tahmin edilmemiştir** —
ölçülene kadar boş bırakılmıştır. Kimlik gelince menü/öğe adları firsthand keşfedilip yazılacak.

| Adım | Durum |
|---|---|
| 1. Giriş sayfası + alanlar | ✅ ölçüldü |
| 2. Giriş (kimlikle) | ⏸ **kimlik yok** |
| 3. e-Fatura > e-Fatura Yükleme menüsü | ⏸ ölçülmedi |
| 4. Dosya yükleme | ⏸ ölçülmedi |
| 5. "Sıra numarası ver" | ⏸ ölçülmedi |
| 6. Gönder | 🔴 **kuru koşum varsayılan** — kanıtlanana dek kapalı |

## Kullanım
```bash
. scripts/ortam.sh                                  # LD_LIBRARY_PATH + font symlink
uv run --with playwright python scripts/ortam-dogrula.py   # 0=yeşil · 2=FONT YOK · 1=Chromium yok
```

## Negatif kapsam
Fatura **kesme kararı** vermez (o `arcelik-fatura-kesim`) · UBL **kurmaz** (o `elogo-erisim`) ·
canlı portalde Sultan izlemeden koşmaz · kimlik değeri taşımaz/basmaz · kuru koşum dışına
açık bayrak olmadan çıkmaz.
