---
name: kosu-kaydi
type: agent
version: 0.2.0
description: >
  Koşu kaydı sarmalayıcısı: her cron/zamanlı iş kendi komutunu `kosu-sar.sh <is> -- <komut>` ile sarar; her koşu
  TAM BİR satır yazar (/config/.claude/kosu-kaydi/<kutu>.<YYYY-MM>.jsonl, 15 alan — Nexus kokpit-ux/05 şeması K1-K6).
  Sessiz başarı yalnız işin beyanıyla ("dokunmadim") ayrı sonuç olur; sonraki koşu canlı crontab'dan GÖZLEM, kanon
  dosyasından TAHMİN olarak iki ayrı alan taşır, çelişki kokpitte sarı. Sonraki-koşu hesabı bağımsız (paket yok).
  Global beceri: cloudtop deposu izole kutularda görünmez (A290), /config/.claude/skills her kutuda görünür.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [kosu-kaydi, cron, sarmalayici, kokpit, headless, agentic-os, jsonl]
---
# kosu-kaydi — koşu kaydı sarmalayıcısı (Agentic OS zemin B0-b)

## Niçin var
Kokpit, kutularda koşan zamanlı işleri (cron) **göremez**: her iş kendi kütüğüne yazar ya da hiç yazmaz; "koştu mu,
ne zaman, ne oldu, bir sonraki ne zaman" sorusunun tek cevabı yok. Şema Nexus `_agents/handoff/kokpit-ux/05-kosu-kaydi.md`
(sürüm 1) — bu beceri onun **yazıcısı**dır. Okuyucu (kokpit) ayrı iştir.

**Niçin global beceri (A290, 9 Eki 2026):** ilk sürüm cloudtop deposunda yaşıyordu. Ölçüldü: nazir kutusu `/config/projects`
altında yalnız `cortex · nazir · Nexus · _wt-nazir` görüyor, cloudtop YOK; `/config/.claude/skills` ise 90 beceriyle görünür.
Ayrıca `croniter` paketi orada yoktu → sonraki-koşu hesabı pakete bırakılmadı, saf python yazıldı.

## Kullanım
Kanon cron satırında eski komutun önüne sarmalayıcı gelir; iş adı `[a-z0-9-]+`:
```
# sahip: NAZIR
# damga: /config/.claude/supur.log
35 * * * * bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh supur -- flock -n /x bash .../supur.sh
```
- `# sahip:` satırın hemen üstünde → `sahip` alanı (K3); yoksa `bilinmiyor` (uydurma yok). `# damga:` → `kutuk`.
- Kutunun adı: crontab başına `KOSU_KUTU=<kutu>` satırı koy. Yoksa `DEFAULT_WORKSPACE`'ten türer; o da yoksa `bilinmiyor`
  (konteyner hostname'i onaltılık bir kimliktir, kutu adı değil — basılmaz).
- Kanon dosyasının yolu biliniyorsa `KOSU_KANON=<yol>` (crontab başına). **Verilmezse kanon = canlı crontab**: sahip okunur
  ama `ifadeden_tahmin` gözlemle aynı olur, yani **drift ölçülemez** — bu dürüstçe böyledir, "drift yok" demek değildir.

### Sonuç kümesi (K4)
| `sonuc` | Ne zaman |
|---|---|
| `tamam` | rc 0 |
| `ayakta-dokunmadim` | rc 0 **ve** iş `$KOSU_BEYAN` dosyasına `dokunmadim` yazdı — çıkarım yok, yalnız beyan |
| `hata` | rc ≠ 0 (beyan olsa da) |
| `olculemedi` | komut bulunamadı (127) ya da çalıştırılamadı (126); rc olduğu gibi geçer, yalnız sonuç sınıfı değişir |
Sarmalayıcı işin çıkış kodunu olduğu gibi geçirir; kayıt yazılamasa bile iş engellenmez.

### Sonraki koşu (K5)
`sonraki_planli` = **canlı** `crontab -l`'deki kendi satırının ifadesinden · `ifadeden_tahmin` = **kanon** dosyasındaki satırdan,
`tahmin:true` damgalı. `@reboot` ve 5 alanlı olmayan ifade → `null` + `turetilemedi:true`. Hesap `scripts/cron-sonraki.py`
(vixie kuralları: `*` · sayı · `a-b` · liste · `/adım` · ay/gün adı · hafta günü 0=7=Pazar · gün-ay ve hafta-günü ikisi
kısıtlıysa OR). Tarama 366 gün; bulunamazsa rc 3.

## Dikişler (sınav için)
`KOSU_KAYIT_DIZ` · `KOSU_KANON` · `KOSU_CRONTAB_KOMUT` (varsayılan `crontab -l`) · `KOSU_KUTU` · `KOSU_SIMDI`.

## Sınav
`bash scripts/kosu-sar.test.sh` — hermetik (sahte kanon, sahte crontab, geçici dizin). Ölçtüğü: 15 alan geçerli JSON ·
beyan protokolü · kanon/canlı çelişkisi · @reboot · kanonsuz kip · kutu adı türetimi · cron-sonraki 10 ifade + 4 ret.

## Sınırlar (dürüst)
- Bu beceri **yazar**; okuyan (kokpit paneli, `kokpit_veri.py`) ayrı iştir. Satır yoksa kokpit "koşmadı" der — sarılmamış iş
  bu defterde görünmez (K6 listesi okuyucunun işi).
- Kanon yolu verilmeyen kutuda drift (A267) ölçülemez.
- Saat dilimi: kayıt `date -Iseconds` yerel dilimle; `KOSU_SIMDI` verilirse dilimi onunla gider. DST geçişleri özel ele alınmaz.
- `defter_ref` alanı şimdilik hep `null` (headless defter B0-d ayrı kart).
