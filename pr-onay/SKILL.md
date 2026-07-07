---
name: pr-onay
type: agent
version: 1.0.0
description: >
  İş bittiğinde SULTAN-DİLİNDE (jargonsuz) kısa özet üretir, "PR açıp merge edeyim mi?"
  onay-kapısından geçirir, onaylanırsa kalite-gate'leri GERÇEKTEN koşup PR açar,
  CI-yeşilini bekler ve merge eder. Gate'ler atlanmaz: agent-dashboard-plugin'li projede
  YOL-A (marker meşru-taşınır — gate'ler koşulduğu İÇİN), plugin'siz projede doğrudan
  gh pr create. Herhangi bir adım kırmızı → DUR + çıplak-çıktı + exit-kod.
  Kaynak-tasarım: Nexus mimserdar-mimari.md "PR-ONAY-AKIŞI TASARIM" (YOL-A, Sultan-onaylı).
disable-model-invocation: true
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [pr, merge, onay, kalite-gate, sultan-dili, workflow, ci]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# PR-Onay — Sultan-dili özet → onay → gate'li PR+merge

## Ne işe yarar
Her iş bitiminde aynı sürtünme yaşanıyordu: teknik-jargonlu rapor → "PR aç" → "merge et".
Bu skill onu kalıcı tek-akışa bağlar: **sade özet → tek-soru onay → kalite-gate → PR → CI → merge.**
`disable-model-invocation: true` → yalnız Sultan `/pr-onay` yazınca başlar (onay-kapısının kendisi
insan-tetikli; ajan bu skill'i kendi kendine çağıramaz).

> Bu skill `/agent-dashboard:pr`'ı DEĞİŞTİRMEZ, sarmalar: onun kalite-gate fikrini kendi içinde
> gerçekten koşar, üstüne Sultan-dili-özet + onay + merge ekler.

## AKIŞ (sabit-sıra — atlama yok, yer değiştirme yok)

### 0 · Adapte-ön-uçuş (kurulu projeyi tanı; varsayma, PROB'LA)
1. **Makefile/`make test` var mı?** `test -f Makefile && grep -qE '^test:' Makefile`
   - VARSA: kalite-gate = `make test` (projenin kendi tam-kapısı; Nexus'ta bu zaten
     hook-testleri + `cd ui && npx tsc --noEmit && npx vitest run` içerir).
   - YOKSA: Sultan'a sor — *"Bu projede make-test hedefi yok; tsc+test hedefi ekleyeyim mi,
     yoksa bu seferlik `npx tsc --noEmit && npx vitest run`'ı doğrudan mı koşayım?"* (soru-cevabına göre davran; sessiz-varsayım yok).
2. **agent-dashboard plugin var mı?** (PreToolUse `pr-skill-gate` hook'u `gh pr create`'i bloklar mı?)
   Tespit: `.claude/settings.json` / kurulu-plugin listesinde `agent-dashboard` ara.
   - VARSA → **YOL-A**: PR-açma komutu `AGENT_DASHBOARD_PR_SKILL=1 gh pr create …` ile verilir —
     **AMA yalnız aşağıdaki gate'lerin HEPSİ gerçekten koşulup yeşil geçtiyse.** Marker'ın anlamı
     "kalite-gate'ler koştu"dur; koşmadan koymak = sanctioned-marker-sahtelenmesi = İHLAL.
   - YOKSA → doğrudan `gh pr create`.
3. ⛔ **`SKIP_PR_SKILL_GATE` env'ine HİÇBİR KOŞULDA dokunma** (okuma-önerme-yazma yok; YOL-A politikası bu env'siz yaşar).

### 1 · Kalite-gate (özet-ÖNCESİ zorunlu; pipe-maskeleme YASAK)
Sırayla, her komut ÇIPLAK (grep/tail arkasına gizleme) + sonuna `; echo exit=$?`:
1. tip-kontrol: `npx tsc --noEmit` (ya da `make test`'in tsc-adımı)
2. testler: `npx vitest run` (ya da `make test`)
3. temizlik: untracked build-artifact'ları PR'a sızdırma (git status kontrolü); `make fmt` varsa koş.
4. ⚠️ `next build` KOŞMA — build-gerçeği CI'dır (2GB-container OOM; Container-vs-CI kuralı).

**Herhangi biri kırmızı → DUR:** özet üretme, PR açma; Sultan'a çıplak-çıktı + exit-kod raporla.

### 2 · Sultan-dili özet üret (jargon-yasak)
Kaynak: `git diff --stat` + branch-commit-mesajları + değişen-dosya-listesi → aşağıdaki sabit-iskelete damıt.
**Jargon-YASAK listesi (özet-gövdesinde geçemez):** dosya-yolu · tsc/vitest/prisma · enum/tip/interface/fonksiyon adı ·
PR-numarası · "refactor/seam/dispatcher" gibi mimari-terim. (Bunlar PR-body'nin teknik-katmanında kalabilir.)

```
📋 <günlük-dilde tek-satır başlık: ne yaptım>

• Ne değişti:   <1 cümle — teknik-ad YOK, ne davranış değişti>
• Neden:        <1 cümle — hangi sorun/ihtiyaç>
• Sana ne katıyor: <1 cümle — Sultan'ın göreceği/hissedeceği somut fark>

✅ Kontroller: tip-kontrol ✓ · testler ✓ · CI: <yeşil|bekliyor>
👉 PR açıp merge edeyim mi?  (evet / hayır / önce-diff-göster)
```

### 3 · Onay-kapısı (tek-soru, üç-cevap; sonlu-durum)
```
özet-göster → "PR açıp merge edeyim mi?" → YANIT-BEKLE
   ├─ evet             → adım-4'e geç
   ├─ hayır            → DUR; hiçbir şey açma; nedeni sor (revizyon-döngüsü)
   └─ önce-diff-göster → git diff --stat + kilit-dosyaların kısa-özeti → AYNI tek-soruyu tekrar sor
```
**İnvariantlar:** "evet"i YALNIZ Sultan yazar — ajan onay-cevabını üretemez/varsayamaz (Yetki-Sınırı).
Sessizlik ≠ onay. Onay tek-seferlik ve bu-PR-scope'lu (bir "evet" sonraki PR'a taşınmaz).

### 4 · PR-aç → CI-bekle → merge
1. PR-aç: YOL-A ise `AGENT_DASHBOARD_PR_SKILL=1 gh pr create --title … --body …`; değilse markersız.
   PR-body = teknik-katman (dosya/kanıt/exit-kodlar burada serbest).
2. CI-bekle: `scripts/wait-ci.sh` varsa ONU kullan (`run_in_background:true` ile); yoksa `gh pr checks`
   sonucunu bekle. Foreground `for…sleep…` döngüsü YASAK (harness-timeout).
3. CI yeşil → `gh pr merge --squash`; **CI kırmızı → merge YOK**, Sultan'a çıplak-rapor.
4. Bitiş-bildirimi: PR-URL + "yayınlandı" (yine Sultan-dilinde tek-satır).

### 5 · Kanıt-defteri (gate'leri atlamadığını KANITLA)
Projenin LEDGER/CONTEXT append-kanalına (Nexus'ta `scripts/append-note.sh` ile) tek-satır yaz:
hangi gate'ler koşuldu + her birinin `exit=` değeri + PR-URL. Marker kullanıldıysa bu satır onun
meşruiyet-kanıtıdır. (Append-kanal yoksa PR-body'ye aynı kanıt-bloğunu koy.)

## Sınırlar / dürüstlük
- Skill'in kendisi kod içermez — bu bir talimat-akışıdır; gate'ler projenin kendi araçlarıyla koşulur.
- "Olmalı/muhtemelen geçer" dili YASAK: her ✓ ancak kırpılmamış-çıktı + exit-0 kanıtıyla yazılır.
- Bu skill merge-YETKİSİ vermez; onay her koşuda Sultan'dan alınır. Kırmızı her durumda DUR demektir.
