---
name: kapi-yolu
type: agent
version: 1.0.0
description: >
  Kapı-yolu (L25) — çok-model şeridini tek yerden kur/aç/kapat/denetle ve filoya yay.
  Kapı servisinin host-kurucusunu, istemci-kurucusunu, `kapi` başlatıcısını, anahtar-teminini
  (vault-cek) ve geri-alma düğmesini (model-modu.sh) BESTELER — kendi ssh/docker/curl kodunu YAZMAZ.
  Değişmez: varsayılan `claude` şeridi DOKUNULMAZ; kapı kapalıyken davranış byte-identical.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [kapi-yolu, bilesik, serit, cok-model, l25, evergreen]
status: v1.0-usta
---

# kapi-yolu — Çok-Model Kapısı Yolu (Usta · bileşik iş-sistemi)

**NE-DİR:** Sultan'ın aboneliğini yakmadan Claude Code içinde açık-kaynak modellerle çalışmayı
sağlayan **kapı şeridinin** tek giriş-noktası. Parçalar zaten var (`cloudtop/infra/kapi/`); bu paket
onları bir iş-sistemi olarak besteler: **kur → aç → denetle → geri-al → yay**.

**İKİ ŞERİT (değişmez):** `claude` = varsayılan, dokunulmaz (abonelik + telefon-kumandası + dikte).
`kapi` = ayrı şerit (abonelik tüketilmez, kumanda yok). Aynı CLAUDE.md/skill/hook.

## Kullanım-yüzeyi

| Ne istiyorsun | Komut |
|---|---|
| **Şerit aç** (yeni pencerede) | `kapi` · `kapi glm` · `kapi kimi` · `kapi minimax` |
| **Aynı sohbete kapıda devam** | `kapi devam` |
| **Durum** (hangi şerit · sağlık · anahtar · model sayısı) | `kapi durum` — ajan yüzeyi: `/kapi` |
| **Bu makineye kur** (istemci: komut + PATH + anahtar) | `bash <cloudtop>/infra/kapi/setup-kapi.sh` |
| **Geçidin kendisini kur** (host, bir kez) | `ssh hostsrv 'bash -s' < <cloudtop>/infra/kapi/kapi-kur.sh` |
| **Anahtar rotasyonu** | `bash <cloudtop>/infra/kapi/istemci-anahtar.sh --yenile` |
| **Geri-al** (diskteki izleri sök, cerrahi) | `bash /config/projects/ocak/scripts/model-modu.sh geri` |
| **Filoya yayılım planı** (KURU-KOŞU varsayılan) | `bash scripts/kapi-yay.sh` → uygulamak: `--uygula` |
| **Varsayılana dön** | yeni pencerede `claude` |

`<cloudtop>` = `/config/projects/cloudtop` (repoyu GÖREN kutularda). Görünmüyorsa → §Yayılım sınırı.

## 🔴 Dürüstlük değişmezleri (ihlal edilemez)

1. **Çalışan oturumun şeridi değiştirilemez.** Şerit süreç-ortamına açılışta yazılır; kabuk başka
   sürecin ortamını değiştiremez → "şeridi değiştirdim/açtım" demek YASAK. Yapılabilecek tek şey:
   durumu bildirmek + yeni pencere talimatı.
2. **Sessiz düşme YOK.** Kapı ölü ya da anahtar yoksa başlatıcı ortamı SET ETMEZ, görünür uyarı basar
   ve varsayılan şeritte açar.
3. **Sır-değer hiçbir yere basılmaz** — anahtar `export` ile verilir, argv'ye ASLA (`ps auxww`).
   Doğrulamalar değer-okumaz (`stat`, `wc -c`, rc).
4. **`/config/.claude/settings.json`'a `env` bloğu ASLA** — o dosya 10 kutuda ORTAK bind-mount'tur;
   oraya şerit-değişkeni yazmak her kutuda uzaktan-kumandayı öldürür.
5. **Şerit-otoritesi tek elde:** ortamı kuran TEK yer `infra/kapi/bin/kapi`'dir. `cs.sh`/`ekip-ac.sh`
   değişken ADI YAZMAZ (`kapi cevre --yaz` ile devralır). Bu bloğu ikinci bir yere KOPYALAMA.

## Harness-uyum probu (`requires_harness: >=2.1.129`)

Kapı modellerinin `/model` menüsünde görünmesi harness'ın **geçit-model-keşfi** desteğine bağlıdır.
Kurulumdan önce prob et — desteklenmiyorsa **sessiz bozulma yerine açık uyarı** ver:

```bash
claude --version                     # ör. 2.1.220 (Claude Code)
bash scripts/kapi-yay.sh --kuru      # harness satırı da bu raporda basılır
```

Destek yoksa: şerit yine açılır (istekler kapıya gider) ama `/model` menüsü kapı modellerini
listelemez → kullanıcıya "menü boş görünecek, model seçimi `kapi <model>` ile yapılır" denir.

## Besteleme

`requires: [vault-cek, bulut-yapilandir]` (manifest). Bestelenen fiilî parçalar:

| Parça | Nerede | Rolü |
|---|---|---|
| `bin/kapi` | `cloudtop/infra/kapi/` | başlatıcı + **tek** şerit-otoritesi (makine yüzeyi: `adres · saglik · cevre --yaz`) |
| `setup-kapi.sh` | aynı | istemci kurulumu (symlink + PATH + `.bashrc` marker-bloğu + anahtar) |
| `istemci-anahtar.sh` | aynı | anahtarı `$HOME/.claude/kapi.env`'e (0600) koyar — kaynak sırası **vault-cek** → hostsrv → gizli-giriş |
| `kapi-kur.sh` + `docker-compose.kapi.yml` | aynı | geçidin kendisi (HOST; karıştırma) |
| `model-modu.sh` | `ocak/scripts/` | deneme + **cerrahi geri-alma** düğmesi (disk izleri) |
| `/kapi` komutu | `~/.claude/commands/kapi.md` | salt-okur durum raporu (ajan yüzeyi) |

Bu paket bunların hiçbirini **yeniden yazmaz**; kendi `ssh`/`docker`/`curl` kodunu **yazmaz** —
yalnız sırayı, kapıları ve sınırı tutar (owner-domain-dokunma).

⚠ **`.bashrc` çift-blok tuzağı:** `model-modu.sh dene` kendi marker-bloğunu (`model-modu-kapi`) bir
`kapi()` fonksiyonu olarak yazar; `setup-kapi.sh` markersız/yabancı `kapi()` görürse **saygı gösterip
atlar** (duplike yok). İkisi birlikte kullanıldıysa geri-alma da `model-modu.sh geri` ile yapılır.

## Yayılım + SINIR (ölçülmüş, varsayılmamış)

`/config/.claude` 10/10 kutuda ORTAK bind-mount → bu skill ve `/kapi` komutu **tek yazımla** her
kutuda görünür. **Ama `kapi` BAŞLATICISI öyle değil.** Firsthand ölçüm (2026-07-25, host `docker exec`):

| Kutu | `cloudtop` reposu görünür mü | başlatıcı diskte |
|---|---|---|
| cloudtop · cloudtop-code | ✅ (2/10) | ❌ (checkout dalı eski — dosya yok) |
| vekatip · mmex · medigate · huma · mihenk · tellal · akar · s02 | ❌ (8/10 · yalnız kendi projesi mount) | ❌ |

Sonuç: **başlatıcıyı repo-yolundan çağırmak 8/10 kutuda ÇALIŞMAZ**; çalışan 2 kutuda bile dosyanın
varlığı checkout-dalına bağlıdır (kırılgan). Ağ tarafı sorun değil — tüm kutular aynı iç ağdadır.

**Çözüm (kuru-koşuyla hazır, uygulaması Sultan-onaylı):** `scripts/kapi-yay.sh` istemci yüzeyinin
üç dosyasını (`bin/kapi` · `setup-kapi.sh` · `istemci-anahtar.sh`) ortak mount'a
(`/config/.claude/kapi/`) **dağıtım-kopyası** olarak basar. Kanonik dosyalar repoda kalır; kopya
hash-karşılaştırmalıdır ve drift bekçisi (`cloudtop/scripts/evergreen-parity.sh` **P10-KAPI**)
kopya ≠ kanon olduğunda uyarır. Böylece kutu başına düşen komut 10/10'da **AYNI** olur — kurucu
kendi konumundan çözülür, repo görünürlüğü gerekmez:

```bash
bash scripts/kapi-yay.sh            # KURU-KOŞU (varsayılan): plan + kutu-kutu komutlar; hiçbir yazma yok
bash scripts/kapi-yay.sh --uygula   # yalnız ortak dağıtım-kopyasını yazar; kutulara DOKUNMAZ
# sonra (host'ta, Sultan onayıyla) her kutu için tek satır:
#   docker exec -u abc <kutu> bash /config/.claude/kapi/setup-kapi.sh
```

**Kapatma** kutu bazındadır: `.bashrc`'deki `# >>> kapi >>>` bloğunu sök ya da `model-modu.sh geri`.
Kapı kapalıyken `claude` davranışı **byte-identical**'dır — kapatmak hiçbir şeyi bozmaz.

## Evergreen (sıfırdan-rebuild geri getirir mi?)

| Kalem | Nerede kayıtlı |
|---|---|
| `/kapi` komutu | `cloudtop/infra/bootstrap/claude-user/commands/kapi.md` + `inventory.yaml → user_claude.commands` |
| bu skill | `Sx-Claude-Skills/kapi-yolu/` + `catalog.json` + `sync-targets.json` (`_global`) |
| geçit servisi + config | `cloudtop/infra/kapi/` (kurucu: `kapi-kur.sh`; sır `kapi.env` repoya GİRMEZ) |
| üst-akış aboneliği | `cloudtop/infra/provider-inventory.yaml → opencode_zen` |
| drift bekçisi | `cloudtop/scripts/evergreen-parity.sh` → P1 (skill) · P3 (komut+CLAUDE.md) · **P10-KAPI** (geçit zinciri) |

## Kademe

Usta (S3 · bileşik). generic-goal: "kapıyı tek yerden kur/aç/kapat/denetle ve filoya yay — mevcut
parçaları besteler, yeniden yazmaz". Doğrula: `ahi check kapi-yolu` · Kanon: `ahi doctrine`.

## İ1 izolasyon-notu

Kod/doküman `_global`'e gider (filo-geneli görünür). **Anahtar** container-yereldir
(`$HOME/.claude/kapi.env`, 0600) ve hiçbir ortak yüzeye yazılmaz; ortak mount'a giden tek şey
başlatıcı **kodudur**, sır değil.
