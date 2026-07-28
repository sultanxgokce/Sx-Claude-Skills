---
name: kesif-hatti
version: 1.0.1
description: Bu kutudaki keşif hattını tek ekranda göster — kaç HAM bulgu var, kaçı süzüldü, hangi etiketi aldı, kaçı ADAY oldu, son tur ne zaman koştu. "NÂZIR/KAŞİF ne buldu · neler süzüldü · hangi fikirler çıktı · ham ile sentez farkı ne" sorusunun kanonik cevabı. SALT-OKUR, süzme YAPMAZ. USER-ONLY.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# /kesif-hatti — ham keşiften onaya giden hattın penceresi

**Kim çağırır:** Sultan (ya da kutunun MÜDÜR'ü). USER-ONLY.
**Nerede çalışır:** çağrıldığı **kutunun içinde**, kendi defterlerini okur (İ1 — ssh/ağ yok).
**Yazma YOK.** Bu bir görüntüleyici.

## Hat nasıl işler (skill bunu gösterir, İŞLETMEZ)

```
KAŞİF tarar → bulgu-havuzu.jsonl   HAM keşif      durum: ham
                    ↓
MUCİT süzer → mucit-defteri.jsonl  KARAR defteri  verdikt: elendi | aday-arzi | preview | …
                    ↓
              aday-havuzu.jsonl    ADAY kartlar   Sultan-dili sentez, puanlı
                    ↓
              sen                  tek-tuş onay
```

**Etiket/tekrar kuralı** (kod-kanonu `mucit-suz/scripts/mucit-t1.sh:218`):
süzmeye YALNIZ `durum ∈ {ham, kart-red}` girer. `bitti · cozuluyor · aday-onerildi · kart · elendi`
**girmez**.

> ⚠️ **DÜZELTME (2026-07-28):** bu bölüm önceden *"karar defterinde kaydı olan bulgu bir daha
> süzülmez — bir kez elenen geri gelmez"* diyordu. **Bu ÇÜRÜK.** Firsthand ölçüldü: `mucit-t1.sh:218`
> uygunluk kapısı karar defterine **hiç bakmaz**; defter yalnız hafta-kotası sayılırken okunur
> (`:136-142`). Bugün havuzda kararı olan bulgular `durum:"ham"` kaldığı için **yeniden süzmeye
> giriyor**. Bu görüntüleyicinin "SÜZMEYE HAZIR" sayısı defterdekileri düşer — yani **burada
> gördüğün sayı motorun fiilen işleyeceğinden AZ olabilir.** Delik `_agents/spec/uc-elek-suzme-DESIGN.md`
> (Nexus) F1+F2 fazında kapatılıyor; kapandığında bu uyarı kalkar.

## Adımlar

1. **Tek komut:**
   `bash /config/.claude/skills/kesif-hatti/scripts/kesif-onizleme.sh`
   - Makine-okunur: `--porcelain` (TAB-ayraçlı satırlar).
   - Çıkış: **0** okundu · **2** ortam hatası (python3 yok / hiçbir defter yok).

2. **Çıkış-kodu 2 ise** sebebi sade söyle ("bu kutuda keşif defteri yok"). **Sayı uydurma.**

3. **Sultan'a çevir.** Script'in çıktısı zaten sade — olduğu gibi basabilir, ya da şu üç soruyu
   öne çıkarabilirsin: *ne birikti · ne süzüldü · sırada ne var.*

## Sınırlar / dürüstlük (bunlara ASLA taşma)
- **SÜZME YAPMAZ.** "En iyi bulgular" DEME. Süzmek MUCİT'in işidir → `/mucit-suz`.
  Çıktıdaki "ham havuzdan örnek" listesi **yargı değil**, yalnız "henüz süzülmemişlerden en yenileri".
  Bunu Sultan'a aktarırken de belirt — aksi hâlde sahte-sentez sunmuş olursun.
- **YOK ≠ BOŞ.** Defter dosyası yoksa "kayıt yok" yazar, **sıfır yazmaz**. Sen de öyle aktar:
  "MUCİT bu kutuda hiç süzmemiş" ile "süzdü, hiçbir şey geçmedi" AYRI şeylerdir.
- **Kart açmaz, aday üretmez, deftere yazmaz.** Aday→kuyruk her koşulda Sultan tek-tuşundan geçer.

## Kardeş komutlar
`/mucit-suz kalibrasyon` süzme turu başlatır · `/filo` filo geneli · `/ekip` bu kutunun masaları

## Doğrula (bakım)
`bash /config/.claude/skills/kesif-hatti/scripts/kesif-onizleme.test.sh ; echo exit=$?` → 16/16 PASS.

## Kademe
Kalfa (S2 · taşınabilir: yalnız python3 + defter-yolları; kutuya özel yol gömülü değil).
