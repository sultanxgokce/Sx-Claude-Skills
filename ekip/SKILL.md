---
name: ekip
version: 1.0.0
description: Bu kutudaki ekibin masalarını önce SÜZ (eksik/boş/fazla var mı), gerekirse ONAR (kapanmış masaları aç, Claude'u başlat), sonra Sultan-dilinde LİSTELE — ajan adları · tmux adları · geri dönmek/başlatmak için komutlar. "ekibim ayakta mı · masalar kapanmış · kim var · tmux adları neydi · ekibi geri getir" sorusunun kanonik cevabı. USER-ONLY.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# /ekip — bu kutudaki ekip önizlemesi (süz → onar → listele)

**Kim çağırır:** Sultan (ya da kutunun MÜDÜR'ü). USER-ONLY — model kendiliğinden çağırmaz.
**Nerede çalışır:** çağrıldığı **kutunun içinde**. Başka container'a bakmaz, ssh kullanmaz (İ1).
**Filo geneli** ("hangi kutular var, adresleri ne") ayrı sorudur → **`/filo`** (Nexus'ta).

> **Neden var (nazir doğumu, 2026-07-28):** `baslat-claude.sh` Claude'u bulunduğu terminalde
> `exec` eder — tmux oturumu AÇMAZ. Bu yüzden `for … do baslat-claude.sh …; done` **çalışmaz**
> (ilk üyede exec eder, döngü biter) ve ekibi ayağa kaldırmak sekme-sekme elle işe dönüşür
> (6 masa = 6 sekme). Bu skill o boşluğu kapatır: oturumu kendi açar, başlatıcıyı içinde koşturur.

## Adımlar

1. **Tek komut** (süzer, onarır, tabloyu basar):
   `bash /config/.claude/skills/ekip/scripts/ekip-onizleme.sh`
   - Sultan "sadece bak, dokunma" derse: `--kontrol` ekle (SALT-OKUR).
   - Makine-okunur gerekirse: `--porcelain` → `ajan⇥tmux⇥durum⇥komut` + `#OZET` + `#ONARIM` satırları.
   - Çıkış: **0** hepsi ayakta · **1** eksik kaldı · **2** ortam/kayıt hatası.

2. **Çıkış-kodu 2 ise** hata satırını sade çevir ("ekip kaydını bulamadım: …"). **Uydurma liste BASMA.**
   Çıkış-kodu 1 ise tabloyu yine bas — hangi masanın neden ayağa kalkmadığı ONARIM satırlarında yazar.

3. **Sultan diline çevir ve bas** (şablon aşağıda). Script'in çıktısı zaten sade; teknik kalanları
   (`respawn-pane`, `pane_current_command`) Sultan'a gösterme, "masa boştu, başlattım" de.

### Çıktı şablonu (Sultan görür)
```
👥 <KUTU> EKİBİ · <N>/<M> masa ayakta

  ✅ <ajan> — geri dönmek için:  tmux attach -t <tmux>
  ⚠️ <ajan> — masası boştu, başlattım
  ❌ <ajan> — açılamadı: <sebep>

🔧 Yapılanlar: <onarım satırları, varsa>
ℹ️ Kayıtta olmayan oturum(lar): <liste> — silmedim, sistem oturumu olabilir

Çıkış: tmux içinde Ctrl+b ardından d
```

## Onarım sınırları (bunlara ASLA taşma)
- **Oturum SİLİNMEZ.** Kayıtta olmayan fazla oturum yalnız raporlanır — silme veri-kaybı riskidir, insan kararıdır.
- **Meşgul masaya DOKUNULMAZ.** Pane'de Claude dışında bir iş koşuyorsa kesilmez, raporlanır.
- **Çalışan Claude yeniden başlatılmaz** (idempotent — ikinci koşu hiçbir şey yapmaz).
- Skill başka kutuya geçmez, ssh çağırmaz, sır okumaz.

## Sınırlar / dürüstlük
- **Ölçemediğini "yok" sayma.** tmux ya da ekip-kaydı yoksa exit=2 + sebep; sahte-yeşil basılmaz.
- Boş roster (0 üye) **hata**dır (exit=2) — "hepsi ayakta" DENMEZ.
- Bu skill kimlik/rol anlatmaz; kim-ne-yapar için kutunun `_agents/` belgelerine bak.

## Doğrula (bakım)
`bash /config/.claude/skills/ekip/scripts/ekip-onizleme.test.sh ; echo exit=$?` → 13/13 PASS.
Test **izole tmux sunucusunda** (`-L`) koşar — çalışan ekiplerin oturumlarına dokunmaz.

## Kademe
Kalfa (S2 · taşınabilir: yalnız tmux + python3 + ekip-kaydı ister; kutuya özel yol gömülü değil).
