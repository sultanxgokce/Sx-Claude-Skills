---
name: terminal-onar
description: Sultan'ın canlı çalışma düzenini (tmux sedir-ana'daki Claude konuşması + sedir-terminal.mmepanel.com web terminali + kurtarıcı ajan + dakikalık bekçi) ÖLÇER, ONARIR ve gerekirse SIFIRDAN kurar. "/terminal-onar · terminal bozuldu · web terminali açılmıyor · oturum kapandı · düzeni yeniden kur" tetiğinde; ayrıca onarım merdiveni (bekçi / Onar düğmesi) kademe 1-2'de bu beceriyi çağırır.
---

# /terminal-onar — canlı düzenin onarıcısı

## Düzen (neyi koruyoruz)
| Parça | Ne | Sağlam sayılma ölçüsü |
|---|---|---|
| konuşma odası | tmux `sedir-ana` | oturum var |
| konuşma | `sedir-ana` içinde Claude (Sultan'ın ana konuşması) | Claude'un oturum kaydında `tmux=sedir-ana:` + süreç canlı |
| web kapısı | `kapi/sunucu.mjs` `:7681` → `sedir-terminal.mmepanel.com` — telefon ekranı (PWA), giriş (parola, imzalı çerez), mesaj/foto/tuş/Onar API'si. tmux `kapi-sedir` | `/giris` 200 · `/` girişsiz 302 |
| terminal | ttyd yalnız UNIX soketinde (`/config/.terminal-onar/ttyd.sock`, TCP portu yok), kapı `/tty/` altında sunar. tmux `ttyd-sedir` | soket `/tty/` 200 |
| kurtarıcı ajan | tmux `sedir-kurtarici` içinde ayrı Claude | aynı ölçü |
| bekçi | crontab `* * * * * … bekci.sh # terminal-onar-bekci` (+ kalıcı kopya `.oda/cron`) | satır var |

code-server terminali ve web terminali **aynı tmux oturumuna** bağlanır → birebir, canlı senkron.
Web terminali `tmux new-session -A` ile açılır: oturum yoksa kendisi kurar, boş ekrana bakmaz.

## Komutlar (hepsi `scripts/komut.sh` üzerinden)
```
bash .claude/skills/terminal-onar/scripts/komut.sh durum [--json]
bash .claude/skills/terminal-onar/scripts/komut.sh onar [--web-yenile]     # kademe 0 = sıfırdan inşa
bash .claude/skills/terminal-onar/scripts/komut.sh merdiven [--arka]       # K0 → K1 → K2 → K3
bash .claude/skills/terminal-onar/scripts/komut.sh duraklat "<sebep>" | devam
bash .claude/skills/terminal-onar/scripts/komut.sh gunluk [N]
```
Argüman `onar` ile çağrıldıysan: önce `durum`, sonra `onar`, sonra yine `durum`. Sağlam değilse
günlüğe bak, sebebi bul, `onar --web-yenile` dahil tekrar dene. Sağlam olmadan "bitti" deme.

## Onarım merdiveni (yarıda kalmaz)
1. **K0** `onar.sh` — betik; eksik parçayı kurar, sağlam parçaya dokunmaz. Konuşmayı hep **aynı
   kimlikle** geri açar (`/config/.terminal-onar/ana-oturum`), asla "son oturum"la (aynı klasörde
   başka ajanlar da çalışır; `--continue` yanlış konuşmayı açabilir).
2. **K1** başsız Claude (`claude -p`, 10 dk) — yalnız bu betiklere + okumaya izinli.
3. **K2** kurtarıcı ajan — `/terminal-onar onar` komutu gönderilir, 20 dk izlenir.
4. **K3** Sultan'a WhatsApp: "elle bakılmalı" + durum + son günlük.

Tek kilit (flock) → iki merdiven aynı anda koşmaz. Merdiven ölürse bekçi bir dakika içinde yeniden
başlatır. Bekçi tetiklediğinde K1/K2 15 dakikada bir defadan sık denenmez.

## Değişmezler
- **Parolasız kapı ASLA açılmaz** (fail-closed; hem onar.sh hem sunucu.mjs reddeder). Parola kasada: `SEDIR__TERMINAL_SIFRE`
  (vault-cek). Değer hiçbir dosyaya, günlüğe, sohbete yazılmaz.
- Ana konuşma başka bir yerde canlıysa **ikinci kopya açılmaz** (günlüğe uyarı düşer).
- Bilerek kapatırken önce `duraklat` — yoksa bekçi bir dakika içinde geri açar.
- Sınır: kutunun kendisi çökerse bu düzen de onunla gider; o durumda kurtarma kutu dışından
  (MUAVİN / host) gelir.

## Durum dosyaları
`/config/.terminal-onar/` — `gunluk.log` · `ana-oturum` · `kurtarici-oturum` · `kademe.durum` · `duraklat`.
Sultan-onayı: 2026-09-25 (gözetimsiz ajan kademeleri dahil).
