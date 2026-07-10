---
platform: elogo
confidence: high
verified: true
---

# elogo — erişim/auth reçetesi

> erisim-skill-fabrikasi bilgi tabanı · saha-doğrulanmış (canlı Login+salt-okur ops, 8 Tem 2026).
> Reçete adı (araştırmacı): elogo (Logo e-Fatura/e-Arşiv entegratörü, PostBox SOAP WS)

## Özet

e-Logo erişimi = doğrudan **SOAP Web Servisi** (WSDL `https://pb.elogo.com.tr/PostBoxService.svc?wsdl`).
Kimlik = **kullanıcı-adı + şifre** → `Login(userName,passWord)` çağrısı **sessionID** döndürür; her iş
çağrısı bu sessionID ile yapılır, sonra `Logout`. Ayrı "API token" kavramı YOK. İstemci `zeep` ile kurulur
(root-suz `uv run --with zeep --with lxml`). e-Logo eski SSL renegotiation kullanır → transport'ta
`OP_LEGACY_SERVER_CONNECT (ctx.options |= 0x4)` + `verify=False` ŞART, yoksa TLS el-sıkışması patlar.

## ⚠️ Dürüstlük kısıtı (baştan söyle)

Kullanıcı-adı+şifre → token API'si YOK; WS zaten şifreyle doğrudan Login yapar. Dar-yetki (least-privilege)
programatik token'la DEĞİL, portalda **özel bir "Bağlantı (Web Servis) Kullanıcısı" (alt-kullanıcı)** açarak
sağlanır. Login'in **hesap-kilidi vardır**: yanlış şifre denemeleri "Kalan deneme hakkı: (N)" ile azalır ve
hesabı kilitler → körlemesine şifre deneme YAPMA (prod entegratör hesabı kilitlenirse eski sistem senkronu çöker).
Ayrıca **kontör sınırlıdır** (her WS çağrısı kontör yakar; negatife düşebilir) → gereksiz çağrı yapma.

## Credential intake (kullanıcı BİR KEZ)

Kullanıcı BİR KEZ WS kullanıcı-kodu + şifresini verir (skill `read -rs` ile gizli okur, argv'ye/log'a düşmez).
ÖNERİ: portalda (efatura.elogo.com.tr → Ayarlar → **Bağlantı (Web Servis) Kullanıcısı** → **Yeni Ekle**)
işe özel bir alt-kullanıcı aç (kod = `<VKN>` + son-ek, ör. `3840044863mmexclaude`); ana insan-portal şifresini
(e-posta girişi) WS'e KOYMA — o yalnız portal login'idir, WS'i numaralı alt-kullanıcı kullanır.

## Token üretimi / alımı (token_mint)

Yok (N/A). Session her çağrıda Login ile alınır. "mint" yerine → portalda alt-kullanıcı oluştur (dashboard).
Prod'da merkezi kullanımda oturum bir broker-vault'ta tutulup paylaşılabilir (MMEpanel Plan B-Lite deseni), ama
tekil ajan erişimi için doğrudan Login yeterli.

## Scope (least-privilege)

Alt-kullanıcı bazında izole. Aynı firmanın tüm belgelerini görür ama her alt-kullanıcının kendi şifresi +
kendi deneme-kilidi sayacı vardır → prod'un kullandığı alt-kullanıcıya (ör. `…mmebroker`) DOKUNMA; ayrı bir
`…claude`/`…readonly` alt-kullanıcı aç. Bu skill yalnız **salt-okur, kuyruk-tüketmeyen** ops sunar:
`getInvoiceStatus`, `getEArchiveInvoicePdfData`, `GetDocumentData`, `GetDocumentStatus`, `GetDocumentList`.

## 🚫 YASAK / sızıntı riskleri (forbidden)

1) **KUYRUK-TÜKETEN ops YASAK bu skill'de:** `GetDocument` + `receiveInvoiceDone`/`receiveDone`/`GetDocumentDone`
   gelen-fatura kuyruğundan belge çeker ve "alındı" işaretler → eski prod cron'unun (b2b_elogo_sync) çekeceği
   belgeyi tüketir → kalıcı veri kaybı. Sadece salt-okur çağrı yap. 2) Yanlış şifreyle **tekrar tekrar Login
   deneme** → hesap-kilidi (deneme sayacı azalır) → prod hesabıysa YASAK. Şifre bilinmiyorsa DUR, kullanıcıdan iste.
   3) Şifreyi argv/curl komut-satırı/log/chat'e yazma → yalnız env (cortex-access.env 0600) + `read -rs`.
   4) Prod'un `…mmebroker` alt-kullanıcısının şifresini SIFIRLAMA (broker vault eskir → prod senkron kırılır).
   5) Railway'deki eski `ELOGO_WS_*` env'ine yazma (CLAUDE.md §3 eski-prod-config YASAK).

## Doğrulama (doctor / verify)

`Login` → `LoginResult=True` + dolu `sessionID` → yeşil; `Logout`. Hata "Kullanıcı adı veya şifre hatalı.
Kalan deneme hakkı: (N)" → kırmızı (ama tekrar deneme). Salt-okur iş doğrulaması: bilinen KESİLMİŞ bir e-Arşiv
ETTN'i ile `getEArchiveInvoicePdfData` → `result=True` + pdfData bytes. TASLAK (kesilmemiş, Fatura No boş)
faturalar WS'te YOKTUR → `result=False`/`NOTFOUND` (bu bir hata değil, belge henüz issued değil).

## CLI aracı

Resmi CLI yok → `zeep` (Python SOAP) ile saf WS. Root-suz koşum: `uv run --with zeep --with lxml`.
Referans istemci deseni: MMEpanel `backend/scripts/etl/elogo_client.py` (salt-okur).

## env_var

`ELOGO_WS_USER`, `ELOGO_WS_PASSWORD`, `ELOGO_WS_WSDL` → `~/.config/cortex-access.env` (0600).
