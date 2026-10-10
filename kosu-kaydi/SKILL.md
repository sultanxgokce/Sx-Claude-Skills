---
name: kosu-kaydi
type: agent
version: 0.5.0
description: >
  Koşu kaydı sarmalayıcısı: her cron/zamanlı iş kendi komutunu `kosu-sar.sh <is> [--nobetci [--gozlem <komut>]] [--kilit <dosya>] -- <komut>` ile sarar; her koşu
  TAM BİR satır yazar (/config/.kosu-kaydi/<kutu>.<YYYY-MM>.jsonl, kutu-yerel, 17 alan — Nexus kokpit-ux/05 şeması sürüm 1.4; gözlemli kipte gozlem_once/gozlem_sonra ilk 120 bayt).
  Sessiz başarı yalnız beyanla ($KOSU_BEYAN dosyası ya da kanon satırında --nobetci; --gozlem ile ölçü stdout değil önce/sonra gözlemdir) ayrı sonuç olur; kilitte atlanan koşu
  (flock -n -E 75) `atlandi-kilit`; sahip etiketi satır üstü ya da satır sonu. Sonraki koşu canlı crontab'dan GÖZLEM, kanon
  dosyasından TAHMİN olarak iki alan, çelişki kokpitte sarı; hesap paketsiz saf python. Global beceri: cloudtop deposu izole
  kutularda görünmez (A290), /config/.claude/skills her kutuda aynı dizin.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [kosu-kaydi, cron, sarmalayici, kokpit, headless, agentic-os, jsonl]
---
# kosu-kaydi — koşu kaydı sarmalayıcısı (Agentic OS zemin B0-b)

## Niçin var
Kokpit, kutularda koşan zamanlı işleri (cron) **göremez**: her iş kendi kütüğüne yazar ya da hiç yazmaz; "koştu mu,
ne zaman, ne oldu, bir sonraki ne zaman" sorusunun tek cevabı yok. Şema Nexus `_agents/handoff/kokpit-ux/05-kosu-kaydi.md`
(sürüm 1.4) — bu beceri onun **yazıcısı**dır. Okuyucu (kokpit) ayrı iştir.

**Niçin global beceri (A290, 9 Eki 2026):** ilk sürüm cloudtop deposunda yaşıyordu. Ölçüldü: nazir kutusu `/config/projects`
altında yalnız `cortex · nazir · Nexus · _wt-nazir` görüyor, cloudtop YOK; `/config/.claude/skills` ise merkezle **aynı dizin**
(aygıt:inode eşit). Ayrıca `croniter` paketi orada yoktu → sonraki-koşu hesabı pakete bırakılmadı, saf python yazıldı.

**Niçin kutu-yerel kayıt (A291):** `/config/.claude` 13 kutunun ortak bağıdır (`findmnt` → `/opt/cloudtop/config/.claude`); nazir
oda kuralında oraya yazmak Sultan kapısı. `/config`'in kendisi kutuya özeldir → kayıt `/config/.kosu-kaydi/` (merkez `docker exec` ile okur).

## Kullanım
Kanon cron satırında eski komutun önüne sarmalayıcı gelir; iş adı `[a-z0-9-]+`. İki etiket biçimi de tanınır:
```
KOSU_KUTU=nazir
KOSU_KANON=/config/projects/nazir/.oda/cron            # verilmezse drift ölçülemez (aşağıda)
# sahip: NAZIR                                          # (a) satır ÜSTÜ not — cloudtop kanonunun deseni
# damga: /config/.claude/supur.log
35 * * * * bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh supur --kilit /x.lock -- bash .../supur.sh   # eski: flock -n /x.lock bash …
*/5 * * * * bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh bulgu-defteri --nobetci --gozlem "awk '\$2 ~ /:2256\$/ && \$4==\"0A\" {print \$10}' /proc/net/tcp" -- bash /config/.ic-sayfa/sunucu.sh # bulgu-defteri sahip:NAZIR
# gözlem = 8790'ı (2256 onaltılık) dinleyen soketin inode'u. `ss` nazir'de YOK (0.4.0 örneği `ss -ltnpH` oradaki her koşuyu olculemedi yapardı); `pgrep -f` kendi dışındakileri de sayar (A306)
```
- `sahip` (K3): satır üstü `# sahip:` **ya da** satır sonu `# <ad> sahip:<ROL> [damga:<yol>]`; ikisi varsa satır sonu kazanır
  (A292: bazı kanon üreticileri yorum satırlarını canlıya taşımaz, satır sonu etiketi taşınır); yoksa `bilinmiyor` (uydurma yok).
- Kutunun adı: crontab başına `KOSU_KUTU=<kutu>`. Yoksa `DEFAULT_WORKSPACE`'ten türer; o da yoksa `bilinmiyor`
  (konteyner hostname'i onaltılık bir kimliktir, kutu adı değil — basılmaz).
- Kanon dosyasının yolu biliniyorsa `KOSU_KANON=<yol>`. **Verilmezse kanon = canlı crontab**: sahip okunur ama
  `ifadeden_tahmin` gözlemle aynı olur, yani **drift ölçülemez** — bu dürüstçe böyledir, "drift yok" demek değildir.
- Kilit: satırdaki `flock -n <dosya>` **sarmalayıcıya taşınır** (`--kilit <dosya>`); kilidi sarmalayıcı alır, alamazsa komut koşmaz ve
  `atlandi-kilit` yazılır. `flock` sarmalayıcının içinde kalsa alt komutun rc'sini olduğu gibi geçirdiği için "75 = kilit" çıkarımı
  kesin olmazdı (bağımsız göz); dışında kalsa kilitli koşu hiç satır yazmaz, kokpit "koşmadı" derdi.

### Sonuç kümesi (K4 · K4b)
| `sonuc` | Ne zaman |
|---|---|
| `tamam` | rc 0 (nöbetçi kipinde: rc 0 **ve** çıktı var — iş yaptı) |
| `ayakta-dokunmadim` | rc 0 **ve** beyan: iş `$KOSU_BEYAN` dosyasına `dokunmadim` yazdı **ya da** satır `--nobetci` taşıyor ve çıktı boş. "Çıktı" = yalnız **stdout**; yalnız boşluk/yeni satır **boş** sayılır; **stderr sınıflamaya girmez** (kütüğe gider). Bayraksız satırda çıkarım yok |
| `atlandi-kilit` | satır `--kilit <dosya>` taşıyor ve sarmalayıcı kilidi (`flock -n`) **alamadı**: komut hiç koşmadı, rc **75** (EX_TEMPFAIL, sabit) yazılır — hata değil (A293). Çıkış kodundan çıkarım yok: işin kendi 75'i (kilit boşken de) `hata`dır. `flock` yoksa ya da bozuksa kilit durumu bilinmez → `olculemedi`, komut koşmaz (atlandı denmez) |
| `hata` | diğer rc ≠ 0 (beyan olsa da) |
| `olculemedi` | komut bulunamadı (127) ya da çalıştırılamadı (126) |
Sarmalayıcı işin çıkış kodunu **olduğu gibi** geçirir (126/127/75 dahil); kayıt yazılamasa bile iş engellenmez — ama izsiz de kalmaz:
kayıt dizini açılamaz/yazılamazsa satır **yedek dizine** düşer (`KOSU_YEDEK_DIZ`, varsayılan `$TMPDIR/kosu-kaydi`) ve stderr'e uyarı basılır
(cron bunu kütüğe/postaya taşır); satır hiç yazılamazsa stderr'de `KAYIT YAZILAMADI`.
`--nobetci --gozlem <komut>` (0.4, şema 1.2): nöbetçi **yeniden başlatırken de sessizse** (nazir `sunucu.sh` iki kolda da rc 0 + boş stdout, A300)
"boş çıktı = iş yok" çıkarıma döner. Gözlemli kipte ölçü stdout değildir: gözlem komutu koşudan **önce** ve **sonra** koşar; çıktı aynıysa
`ayakta-dokunmadim`, değiştiyse `tamam` (ör. dinleyen pid değişti = yeniden başlattı). Karşılaştırma: gözlem stdout'u, bütünün baş/son boşluğu kırpılıp bayt bayt; içteki boşluk anlamlı. Önce ya da sonra gözlemden biri rc≠0 → `olculemedi` — iş rc'si ne olursa olsun (koşulsuz; `hata` bile denmez, çünkü sınıf ölçülememiştir); iş rc'si olduğu gibi geçer.
**Altı hâl (0.4.1, şema 1.3 K4-d — NÂZIR ölçtü):** kırpılmış gözlem **boşsa gözlenen şey yoktur**. boş→boş = `hata` (yoktu, hâlâ yok — "ayakta" değil) ·
dolu→boş = `hata` (nöbetçi düşürdü — "iş yaptı" değil) · boş→dolu = `tamam` (düştü, kaldırıldı) · dolu→aynı = `ayakta-dokunmadim` · dolu→farklı = `tamam` ·
gözlem rc≠0 = `olculemedi`. 0.4.0 ilk ikisini yeşil basıyordu. İş rc'si 126/127 ise gözlem ne olursa olsun `olculemedi` (komut yok/çalışmaz).
**Gözlem değerleri satırda (0.5, şema 1.4 — A310, NÂZIR):** `gozlem_once` / `gozlem_sonra` = kırpılmış gözlem çıktısının **ilk 120 baytı** (geçersiz UTF-8/NUL
yer tutucuyla, JSON bozulmaz); gözlemsiz kipte **`null`**, gözlem koşup boş döndüyse **boş dizge** (null değil — "ölçüldü, yoktu"). Niçin: 0.4 satırı hükmü
(`sonuc`) taşıyor, dayanağını taşımıyordu; `tamam` yazınca neyin değiştiği satırdan okunamıyordu. Gözlem komutu kanon sahibinin seçimidir — sır basan bir komut seçilmez.
`--nobetci`: beyan betikte değil **kanon satırında** yaşar — sürümsüz bir nöbetçi betiğine (A291: nazir'inki hiçbir depoda değil)
dokunmadan K4 ölçülür. Bedeli: nöbetçinin çıktısı sarmalayıcıdan geçer (`tee`), kütüğe yine düşer.

### Sonraki koşu (K5)
`sonraki_planli` = **canlı** `crontab -l`'deki kendi satırının ifadesinden · `ifadeden_tahmin` = **kanon** dosyasındaki satırdan,
`tahmin:true` damgalı. `@reboot` ve 5 alanlı olmayan ifade → `null` + `turetilemedi:true`. Hesap `scripts/cron-sonraki.py`
(vixie kuralları: `*` · sayı · `a-b` · liste · `/adım` · ay/gün adı · hafta günü 0=7=Pazar · gün-ay ve hafta-günü ikisi
kısıtlıysa OR). Tarama 1500 gün (29 Şubat gibi seyrek ama geçerli ifadeler sığar); bulunamazsa (31 Şubat) rc 3.

## Dikişler (sınav için)
`KOSU_KAYIT_DIZ` · `KOSU_KANON` · `KOSU_CRONTAB_KOMUT` (varsayılan `crontab -l`) · `KOSU_KUTU` · `KOSU_SIMDI` · `KOSU_YEDEK_DIZ` · `KOSU_FLOCK_KOMUT` (varsayılan `flock`; 'flock yok' sınavı için).

Ön koşul: `bash` · `python3` · `crontab` (yoksa gözlem null) · `flock` (util-linux; yalnız `--kilit` için).

## Sınav
- `bash scripts/kosu-sar.test.sh` — hermetik (sahte kanon, sahte crontab, geçici dizin). Ölçtüğü: 17 alan geçerli JSON · gözlem değerleri (120 bayt, NUL, null/boş ayrımı) · beyan
  protokolü (dosya + `--nobetci`) · satır sonu etiketi · `atlandi-kilit` · kanon/canlı çelişkisi · @reboot · kanonsuz kip · kutu adı
  türetimi · rc 126/127 geçişi · gözlem altı hâl (boş→boş/dolu→boş hata) · UTC damga · cron-sonraki 10 ifade + 4 ret · croniter zehirli-modül kapısı (pakete bağımlılık yok).
- `bash scripts/hedef-kutu-sinav.sh <konteyner> [<ssh-host>|-]` — aynı sınavı **hedef kutuda** koşturur (tar → `/tmp`, orada koş, sil;
  kaynak/hedef md5'leri basılır). Kurulumdan önce "bu kutuda çalışır" iddiasının ölçümü.

## Sınırlar (dürüst)
- Bu beceri **yazar**; okuyan (kokpit paneli, `kokpit_veri.py`) ayrı iştir. Satır yoksa kokpit "koşmadı" der — sarılmamış iş
  bu defterde görünmez (K6 listesi okuyucunun işi).
- Kurulum bu paketin işi değil: merge sonrası `sync-skills.mjs --skill kosu-kaydi --apply` (yalnız bu beceri; toplu `--force` yasak) ve
  kutularda görünürlük ölçümü ayrı karttır (`kosu-kaydi-kurulum`).
- Kanon yolu verilmeyen kutuda drift (A267) ölçülemez. `--kilit`'e taşınmamış (içeride `flock -n` kalan) satırda kilit/hata ayrımı yoktur.
- Saat dilimi (0.4.1, A303): `baslangic`/`bitis` **hep UTC** (`+00:00`) — nazir'de cron satırları UTC, elle koşu +03:00 yazıyordu, aynı dosyada iki dilim. Sonraki-koşu alanları cron ifadesinin dilimindedir (`KOSU_SIMDI` verilirse onunla). DST geçişleri özel ele alınmaz.
- `defter_ref` alanı şimdilik hep `null` (headless defter B0-d ayrı kart).
