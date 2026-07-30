---
name: seans
version: 1.12.0
description: >
  Claude sohbetlerini yönetme ve ekip kısayolları — her kutuda çalışır.
  Motor (cs) burada tek kopya yaşar; cloudtop tarafındaki eski çağrı yolu ince köprüyle korunur.
  Türkçe kapılar: basla · sessiongetir · yenisession · gruba · yardim · kendi-kopyam — altısı PATH'e `seans-kur.sh` ile bağlanır (v1.3.0: önce hiçbiri PATH'te DEĞİLDİ).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [seans, tmux, claude, whatsapp, ekip]
status: v1.0-kalfa
---

# /seans — Sohbet yönetimi ve ekip kısayolları

**NE-DİR:** Claude sohbetlerini listeleme/geri getirme/yeni açma motoru (`cs`) **artı** günlük
kullanım için Türkçe kapılar — terminal açılışındaki karşılama ekranı (`basla`) dâhil. Kod yazmayan ekip üyesi de tek kelimeyle işini görsün diye.

**NİÇİN ORTAK BECERİ:** motor eskiden yalnız cloudtop deposunda yaşıyordu; o depoyu göremeyen
kutularda (tenant'lar) komut **yoktu**. Aynı sınıf hata daha önce de yaşandı ("araç bir odada,
el kitabı on odada"). Motor artık ortak mount'ta tek kopya; cloudtop'taki eski yol ince bir
köprüdür — **iki kopya yoktur, drift doğmaz**.

## Günlük kapılar

| Komut | Ne yapar |
|---|---|
| `sessiongetir` | Kapanan sohbeti geri getirir. Argümansız → seçim menüsü. `sessiongetir 3` / `sessiongetir randevu` de olur. |
| `yenisession` | Yeni sohbet açar; adını sorar. `yenisession --yan` ekranı bölüp **yanda** açar. |
| `gruba "mesaj"` | Projenin WhatsApp grubuna yazar. Grup adı bir kez `.wa-grup` dosyasına yazılır. |
| `yardim` | Komut listesini terminalde gösterir + projenin kılavuz adresine işaret eder (`.yardim-linki`). |
| `kendi-kopyam` | Masaya **ayrı çalışma kopyası** açar (git worktree) — paylaşılan kopyada dal değiştirmenin kimsenin işini bozmaması için. `--nerede` yalnız ölçer · `--kapat` kaldırır (temiz olmalı). |

## Neden `kendi-kopyam` var (ölçülmüş sorun)

Bir kutuda birden çok masa (ekip üyesi) **aynı çalışma kopyasına** bakabilir. 2026-07-30'da
huzur kutusunda ölçüldü: üç masa + insanların sekmeleri tek kopyayı paylaşıyordu —

    git worktree list  →  /config/projects/huzur  d2bb6a8 [faz-0-tasarim]   ← tek satır

Bunun anlamı: biri dal değiştirdiğinde ötekilerin **kaydedilmemiş işi** o dala taşınır ya da
çakışır. Git bunu engellemez, kimse haber vermez. Ölçüm anında ağaç temizdi (yani iş kaybı
olmamıştı) — pencere hâlâ açıktı, bu araç onu kapatır.

İki parça birlikte çalışır:
- **`basla` ekranı** paylaşımı GÖRÜNÜR kılar ("⚠ ana kopyayı 3 masa paylaşıyor"). Ölçemezse
  sayı uydurmaz, "ölçemedim" der. Ekran hiçbir şeyi kendiliğinden değiştirmez.
- **`kendi-kopyam`** çözer: masaya kendi kopyasını + kendi dalını verir. Ana kopyanın dalına
  ve dosyalarına dokunmaz; çağrılmadıkça hiçbir şey olmaz.

Sınırlar bilinçli: `--kapat` yalnız **temiz** kopyayı kaldırır ve **dalı silmez** (kaydedilmiş
iş git geçmişinde kalır — kaldırma onu kaybetmez). Ana kopya asla silinmez.

Motorun tamamı hâlâ elinizin altında: `cs ls` · `cs rename` · `cs note` · `cs sil` · `cs gc`
(bkz. `cs --help`).

## Mahremiyet — çok-insanlı kutu kuralı

Seans kayıtları **tüm kutuların gördüğü ortak alanda** durur. Tek insanlı kutuda bu zararsızdı;
birden çok insanın çalıştığı kutuda değil. Bu yüzden liste iki sınıfa ayrılır:

- **Kokpit kutusu** (filo kaydı görünür): filtre yok — Sultan kendi filosunu görür.
- **Tenant kutusu**: yalnız o kutunun kendi projesi listelenir. Bilinmeyen → **gizlenir**
  (fail-closed; bilinmeyen ≠ güvenli).

Bu, 2026-07-29'da huzur kutusunda firsthand ölçülen gerçek bir sızıntının panzehiridir
(o kutuda `cs ls` tüm filoyu, mahrem projeler dahil, listeliyordu).

## Sınırlar (dürüst)

- **Sohbetin hafızası ayrı mesele.** Ekran (tmux) yerinde kalır ama uzun süre dokunulmayan
  Claude sohbeti kendini toparlayabilir. `sessiongetir` ekranı ve kimliği geri getirir; kaldığı
  yerden aynen devam edeceğini **garanti etmez**.
- `yenisession --yan` yalnız tmux içinde ekran bölebilir; dışarıdaysan uyarır ve aynı pencerede
  açar — "yanda açtım" diye sahte-yeşil basmaz.
- `gruba` yalnız **gönderir**. Gruptan mesaj okuma/onay yakalama bu becerinin işi değildir.
- Grup adını adrese çeviren tek yer merkezî WhatsApp geçididir; numara hiçbir kutuda tutulmaz.

## Kurulum notu

Bu beceri `_global` hedefine kurulur (`/config/.claude/skills`) → **HOME=/config olduğu için her
kutuda, her projede** otomatik görünür. Kısayolların PATH'te olması için kutu kurulumunda
`scripts/` dizini `~/.local/bin`'e bağlanır.
