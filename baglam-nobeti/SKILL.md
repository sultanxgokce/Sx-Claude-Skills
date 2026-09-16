---
name: baglam-nobeti
version: 0.2.0
description: Oturum bağlamı (context) dolarken Sultan'ı ASLA sessizce geçmez — %70'te uyarır, %80'de ŞİDDETLİ uyarıp compact önerir; compact'tan önce çıpaları tazeler ki hiçbir iş kaybolmasın. Ölçü mekaniktir (kanca her araç çağrısında transkriptten ölçer), söz değil. Sultan kuralı 2026-09-16; AKAR/MÜTEVELLİ doğurdu, MUAVİN filo geneline paketledi.
allowed-tools: Bash, Read
---

# /baglam-nobeti — bağlam doluluk nöbeti (Sultan kuralı, 2026-09-16)

**Sultan:** "Context'in dolmuş ve hiç uyarmadın. Context dolduğunda direkt, şiddetli şekilde 'context doldu,
compact öneriyorum' de; bunu bir AI skill'e dönüştür, asla kaçmasın."

**Kim çağırır:** kimse çağırmak zorunda değil — kanca her araç çağrısından sonra kendiliğinden ölçer ve eşik
aşıldıysa uyarı satırını ajanın önüne koyar. Ajan isterse `baglam-olc.py` ile elle de ölçer.
**Nerede çalışır:** her kutuda (global). Pencere bilgisi filo kanonundan okunur; ikinci kopya yoktur.

## Kural (ZORUNLU, her kutuda)
1. **Ölçüm:** ajan `/context` komutunu kendisi çalıştıramaz (o bir CLI komutudur). Ölçüyü **kanca** verir:
   `scripts/nobet-kancasi.sh` (PostToolUse) her araç çağrısından sonra transkriptin son kullanım kaydından
   doluluğu hesaplar. Elle ölçmek için: `python3 ~/.claude/skills/baglam-nobeti/scripts/baglam-olc.py`
   (çıkış 0 = %70 altı · 1 = %70+ · 2 = %80+ · 3 = ÖLÇÜLEMEDİ). Sistemin "autocompact will trigger soon"
   uyarısı ve Sultan'ın yapıştırdığı `/context` çıktısı da ölçüm sayılır.
2. **Eşikler ve söz** (kanca bu satırları birebir verir; ajan cevabının başına koyar):
   - **%70 ve üstü** → cevabın İLK satırı: `⚠️ BAĞLAM %NN DOLU — yakında compact gerekecek; çıpalar tazeleniyor.`
     Soru AÇMA, menü açma; çıpanı yaz, işine devam et.
   - **%80 ve üstü** → cevabın İLK satırı, kalın, başka hiçbir şeyden önce:
     `🔴 BAĞLAM %NN DOLU — COMPACT ÖNERİYORUM. Çıpalar tazelendi (<dosyalar>); "/compact" deyin, kaldığım yerden aynen sürerim.`
     Bu satır **her cevapta** tekrarlanır, Sultan compact deyene ya da doluluk düşene kadar.
   - **%90 ve üstü** → aynı satır + "yeni büyük iş almıyorum; önce compact" — ve gerçekten yeni büyük iş başlatılmaz.
3. **Compact'tan ÖNCE çıpa (kayıpsızlık sözü):** `bash scripts/cipa-bul.sh` bu kutuda VAR OLAN çıpa dosyalarını
   listeler (AKAR'da: `DURUM.md` · `tanitim/ANA-AKS.md` · `_agents/durum/<AD>.json` · `Notlarim/notlarim.md`;
   başka kutuda başka adlar; hiçbiri yoksa `Notlarim/notlarim.md` önerir). Her birine **nerede kaldık · kapıda
   ne var · kimden ne bekleniyor** yazılır. Çıpa yazılmadan "çıpalar tazelendi" DENMEZ; kanca da bunu hatırlatır.
4. **Compact'tan SONRA ilk cevap:** çıpa dosyasını okuyup tek cümleyle "kaldığım yer: …" der; Sultan'a özet sormaz.
5. **Sessiz geçmek yasak:** %70 üstünde uyarı satırı olmayan bir cevap kural ihlalidir. Uyarı Sultan diliyle
   yazılır (jargon yok).
6. **Ölçülemeyen "temiz" değildir:** model kanonda yoksa (ör. Codex şeridi gpt-*) kanca "ÖLÇÜLEMEDİ" der, yüzde
   uydurmaz. O zaman ajan Sultan'dan `/context` ister ya da `BAGLAM_PENCERE=<pencere>` ile pencereyi verir.

## Mekanik gövde (ne nerede)
| Dosya | İş |
|---|---|
| `scripts/baglam-olc.py` | transkript → `pct=… kullanilan=… pencere=… kaynak=… model=…`; pencere `/config/.claude/ORTAK-MIMARI.md` "Model sozlugu" tablosundan (tek kaynak) + `[1m]` ezici; tam model kimliği transkriptteki son `attachment.type=model` kaydından ([1m] eki orada korunur, usage kaydında silinir) |
| `scripts/nobet-kancasi.sh` | PostToolUse kancası; oran sınırlı (koşum 60 sn · %70 satırı 300 sn · %80+ 90 sn · ölçülemedi 900 sn); bloklamaz |
| `scripts/cipa-bul.sh` | bu kutudaki çıpa dosyalarını listeler; yoksa rc=1 + öneri |
| `scripts/*.test.sh` | 13 + 14 + 4 kapı, ağsız |

**Kablo:** `/config/.claude/settings.json` → `hooks.PostToolUse` (matcher `*`), tek satır:
`f=/config/.claude/skills/baglam-nobeti/scripts/nobet-kancasi.sh; [ -x "$f" ] || exit 0; exec "$f"`.
Bu dosya bütün kutularda ortaktır → tek satır her kutuda geçerli. Kanca yoksa/kurulu değilse sessizce yutulur;
bunu `hook-gorunurluk.sh` (Nexus) kırmızı gösterir — "sessiz yeşil" sınıfının bilinen tuzağı.

**Ayarlar:** `BAGLAM_NOBETI_KAPALI=1` susturur · `BAGLAM_PENCERE=<n>` pencereyi ezer · `BAGLAM_ESIK_UYARI`/`BAGLAM_ESIK_COMPACT`/`BAGLAM_ESIK_DUR` (70/80/90).

## Tuzaklar (ölçüldü, paketlerken)
- **Kural AKAR'ın dosya adlarıyla doğdu** (`DURUM.md`, `tanitim/ANA-AKS.md`): başka kutuda o dosyalar yok → `cipa-bul.sh` var olanı ölçer, uydurmaz.
- **`[1m]` eki transkriptin usage kaydında silinir** (`claude-opus-5[1m]` → `claude-opus-5`): pencere 1M yerine 500k sanılır, doluluk 2× yüksek çıkar (Nexus ctx-nudge L25-W5 vakası). Çözüm: `attachment.type=model` kaydındaki tam kimlik geriye doğru taranır (64 MB'a kadar, ~30 ms).
- **Uzun araç dizisinde kimlik kaydı son 256 KB'ta olmayabilir** → geriye parça parça tarama (T10 sınavı).
- **Nexus'un `ctx-nudge.sh` kancası** yalnız Nexus'u gören kutularda çalışır (izole kutularda yol yok → sessiz). Bu beceri onun filo genelindeki karşılığıdır; ikisi aynı kutuda birlikte koşarsa iki satır görülür — zararsız, ama uzun vadede ctx-nudge'ın mesaj kısmı emekli edilebilir (aile-ctx yayını kalır).

## Filo
Global beceri (MUAVİN kurar/senkronlar; kaynak Sx-Claude-Skills, kurulum `node sync-skills.mjs --skill baglam-nobeti --apply`).
Her kutunun reisi CLAUDE.md'sine tek satır bağlar: "Bağlam %70 → uyar, %80 → compact öner (baglam-nobeti)".
