# Poll-cron paketi (A1 · "uzak-MÜDÜR dinle-döngüsü")

> **KURULUM-KAPISI:** bu birimin token'ı (kutu-kutu vault-provizyonu, **Sultan-eli** — GO-1 s02
> emsaliyle kapı AÇIK, kalan birimler FAZ-3+ sırayla) inmeden cron KURULMAZ — kimlik-ucu olmayan
> poll = anlamsız + sahte-canlılık riski. İlk gerçek kurulum = FAZ-3 MİHENK re-doğumu (Sultan-eşli).
> Bu dosya reçetedir, kendiliğinden hiçbir şey kurmaz.

## Ön-koşullar (birim-içi)
1. Araçlar: `command -v curl jq flock` → üçü de VAR olmalı (istemci curl+jq'yu başta kendisi de
   doğrular; İSKÂN-doğumlu kutuda jq eksikse önce kur). `flock` yoksa cron-satırını flock'suz kur
   ve deftere not düş (üst-üste binen iki `dinle` 409-ACK sınıfı üretebilir — istemci artık bunu
   batch-öldürmeden atlatıyor, yine de kilit tercih edilir).
2. Token: `~/.federe/token` (0600; vault'tan Sultan indirir — değer hiçbir transkripte yazılmaz):
   ```bash
   mkdir -p ~/.federe && chmod 700 ~/.federe
   # (token'ı vault'tan ELLE yapıştır; echo/komut-geçmişine düşürme)
   chmod 600 ~/.federe/token
   ```
   Üretim-tarafı kural: token yalnız `[A-Za-z0-9_-]` (özel-karakter curl-config parse-uyarısı
   üretebilir → stderr/log'a satır-parçası sızma sınıfı kapanır).
3. Doğrulama (değer-okumaz): `bash ~/.claude/skills/federe-os-cekirdek/scripts/federe.sh durum`
   → "API: YEŞİL" görmeden cron kurma.

## Seçenek A — container-içi cron (varsa)
```cron
# federe poll — 15dk'da bir bekleyen tetikleri çek + alindi-ACK (token: ~/.federe/token; kilit: flock)
*/15 * * * * flock -n $HOME/.federe/dinle.lock bash $HOME/.claude/skills/federe-os-cekirdek/scripts/federe.sh dinle >> $HOME/.federe/dinle.log 2>&1
```
- Token cron-satırına YAZILMAZ (istemci dosyadan okur). Log'da token yoktur (istemci değer basmaz).
- **İnbox = TEK sabit yol (zorunlu-karar, kurulumda verilir):** default `~/.federe/tetik-inbox.md`
  (cwd'den bağımsız, deterministik). Repo-içi inbox istiyorsan cron-satırına
  `FEDERE_TETIK_INBOX=<repo>/_agents/handoff/federe-tetik-inbox.md` ekle ve MÜDÜR'e AYNI yolu
  bildir — koşudan-koşuya değişen inbox = kayıp-mesaj sınıfı, yasak.
- **Rebuild-kalıcılığı:** container recreate'te elle-kurulan crontab KAYBOLUR. Kurulan satır birimin
  evergreen-kaydına (`.iskan-answers.yaml` / ilgili manifest) işlenmeden "bitti" sayılmaz; recreate
  sonrası `federe.sh durum` ile canlılık yeniden doğrulanır (sessiz-ölü panzehiri).

## Seçenek B — cron yoksa: oturum-başı poll (bugünkü asgari)
MÜDÜR her oturum-başında (ORYANTASYON/durum-defteri okuma adımının yanına) bir kez:
```bash
bash ~/.claude/skills/federe-os-cekirdek/scripts/federe.sh dinle
```
→ inbox dosyasına düşenleri işle (alindi-ACK otomatik basılmıştır; iş bitince `tamam <id>`).

## İşleme-disiplini (her iki seçenekte)
- İnbox append-only'dir; işlenen satırı SİLME — yanına `→ tamam <id> (tarih)` notu düş.
- ACK'i düşmeyen tetik sonraki poll'da TEKRAR gelir (at-least-once) → inbox'ta mükerrer satır
  görmek normaldir; id aynıysa tek iştir, iki kez işleme.
- `durdur`-tipli tetik = acil-durdur (SKILL §1): işi güvenli noktada durdur, merkez kararını bekle.
- Poll boş dönerse sorun değil; poll HİÇ koşamıyorsa (token/ağ) `federe.sh durum` çıktısıyla
  kırmızıyı deftere yaz — sessiz-ölü kalma.
