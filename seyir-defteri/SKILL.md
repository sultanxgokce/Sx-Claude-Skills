---
name: seyir-defteri
type: agent
version: 1.0.0
description: >
  Keşif-günlüğü + döngü-refleksiyonu. Yan-keşifler (aslında-şöyleymiş / bug / risk / fırsat) rapora
  gömülüp KAYBOLMASIN diye append-only defter: her-ajan gözlemini yazar, koordinatör döngü-sonu okur+
  dispozisyonlar. ÇEKİRDEK (yaz·oku·isaretle·durum) her-ekipte; RİTÜEL (refleksiyon = döngü-sonu 4-soru+
  özet+hafıza-köprü) opsiyonel. jsonl append-only + flock-güvenli + kimlik uydurma-YOK + sır-hijyenik.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [seyir-defteri, kesif-gunlugu, gozlem, dongu-refleksiyon, append-log, orkestra, jsonl]
---
# seyir-defteri — Keşif-Günlüğü + Döngü-Refleksiyonu

`bash scripts/seyir-defteri.sh <komut>`. **Amaç:** işi yaparken fark edilen yan-keşifler
("aslında-şöyleymiş", gizli-bug, risk, daha-iyi-yol, fırsat) rapora gömülüp kaybolmasın — deftere düşsün,
döngü-sonu okunsun. **NE-YAPILACAK değil, NE-FARK-ETTİM defteri** (ayrışma: §E).

## Katmanlar
- **ÇEKİRDEK** (her-ekip): `yaz · oku · isaretle · durum` — append-only keşif-log + koordinatör-dispozisyon.
- **RİTÜEL** (opsiyonel, orkestra-döngülü ekipler): `refleksiyon` — döngü-sonu 4-soru + özet + hafıza-köprü.
- **MİGRASYON:** `migrate` — geçici `[KEŞİF]`-md → jsonl (idempotent).

## Komutlar (§B)
| Komut | İş |
|---|---|
| `seyir-defteri "<metin>" [--sev=] [--tur=] [--baglam=] [--dongu=]` | not-event append (YAZ) |
| `seyir-defteri oku [--sev=][--tur=][--durum=acik][--kim=][--dongu=]` | filtreli render (disp-fold) |
| `seyir-defteri isaretle <id> <acik\|okundu\|sonraki-donguye\|kapatildi>` | dispozisyon-event |
| `seyir-defteri durum` | özet-sayaç (açık · kritik-açık · güncel-döngü) |
| `seyir-defteri refleksiyon [<n>]` | döngü-ritüeli (oku+4-soru+işaretleme-rehberi+özet-iste) |
| `seyir-defteri refleksiyon <n> --ne="…" --siradaki="…"` | döngü-özet YAZ (sayaç ilerler + hafıza-köprü öneri) |
| `seyir-defteri migrate <eski-md>` | `[KEŞİF]`-md → jsonl (idempotent, eski arşivlenir) |

## İki-eksen taksonomi (§D-taksonomi — ikisi ortogonal, ikisi-de tutulur)
- **`sev`** (ne-kadar-acil, 3-düzey): `kritik🔴 · onemli🟡 · bilgi🟢` — default **bilgi**.
- **`tur`** (ne-cinsi): `bug · iyilestirme · varsayim-curudu · risk · soru · firsat⭐ · oneri · gozlem` — default **gozlem**.
- **ALIAS (MMEx kas-hafızası):** `--sev=firsat` yazarsan → **`--tur=firsat`'a düşer** (sev=bilgi kalır). Böylece
  hem MMEx'in `--sev=firsat` refleksi hem medigate tür-enum'u kırılmaz.

## Render (deterministik · emoji yalnız-burada · store düz-token · değer-basmaz)
```
[🔴 s0012 · bug · SİNAN · 2s] null-deref login akışında → auth.ts:12 ⟨açık⟩
[🟢 s0001 · ⭐firsat · SİNAN · 5dk] upload chunked-API 3× → ui/lib/pcloud.ts:88 ⟨→sonraki⟩
```
`[<sev-emoji> <id> · <tur> · <kim> · <göreli-zaman>] <metin> → <baglam> ⟨<durum>⟩`. Dispozisyon **ayrı event**
(not-satırı değişmez; reader son-disp-per-id **katlar**) → dosya tam append-only, flock-güvenli.

## Döngü-ritüeli (§C · opsiyonel-katman)
**Standart tetik-cümle** (orkestra döngü-sonu): **"döngü bitti, plan moduna geçelim"** → `seyir-defteri refleksiyon <n>`:
1. OKU: açık + o-döngü keşifleri kritik-önce.
2. 4-SORU (medigate-kanonu): • ne-yaptık? • önümüzde-ne-var? • doğru-yolda-mıyız? • planı-nasıl-güçlendiririz?
3. Her açık-not → `isaretle <id> <okundu|sonraki-donguye|kapatildi>`.
4. Döngü-özet: `refleksiyon <n> --ne="…" --siradaki="…"` → `ozet`-event (sayaç ilerler, durable).
- **Döngü-sayaç:** güncel-döngü = son `ozet`-event'in `dongu`+1 (disk-kalıcı, transkript-bağımsız).
- **Hafıza-köprüsü:** refleksiyon özeti **öneri-metni** olarak basar — ajan kendi `memory/`'sine yazabilir;
  **skill kendisi YAZMAZ** (ajan-aksiyonu, zorlama-yok). Plan-modu/model-geçişi (Fable-5) = **ekip-tercihi**, skill dayatmaz.

## Kültür-kuralı (§D — KANON, skill-talimatına gömülü)
> **Ajan, orkestranın her dediğini kabule mecbur DEĞİL — itiraz/uyarı/daha-iyi-yol bildirmek SERBEST ve
> TEŞVİKLİdir. İtiraz da deftere düşer:** `--tur=oneri` (daha-iyi-yol) / `--tur=risk` (uyarı).
Görüş sessizce-yutulmaz, yapıya-akar. Her-ajan gözlemini yazmakla yükümlü; orkestra döngü-sonu okur.

## Ayrışma (§E — karışıklık-önleme)
- **katip-defter = NE-YAPILACAK** (Sultan-istek ops-backlog) · **seyir-defteri = NE-FARK-ETTİM** (mühendislik-içgörü)
  · **DONGU-LEDGER = döngü-execution-audit**. Seyir-notu bir GÖREV değil.
- Göreve dönüşürse koordinatör **opsiyonel** katip-promote eder + notu `kapatildi`-işaretler (köprü izlenebilir,
  zorla-birleştirme YOK). Kalıcı-değerli keşif **opsiyonel** cortex-promote (yine zorlama-yok).

## Mekanik & sınırlar (§H)
- **Store:** `<git-kök>/seyir-defteri.jsonl` (env-override `SEYIR_DEFTERI`; git-tracked → koordinatör/başka-oturum görür).
  Proje-agnostik (`git rev-parse --show-toplevel`; hard-code-yok). `id = s<seq4>` (flock-içinde üretilir → eşzamanlı-yazımda çift-id yok).
- **Kimlik:** `$EKIP_UYE` → `$AGENT_NAME` → `hostname:cwd` (**uydurma-YOK**).
- **Append-only + flock:** 3 event-türü (`not`·`disp`·`ozet`), satır-edit YOK; self-contained flock (Nexus-scripts bağımlılığı yok).
- **Sır-hijyen:** serbest-metne sır-DEĞERİ YAZILMAZ. `sk-…/token=/password=/secret=/api_key=` deseni → **uyar + onay-iste**
  (non-TTY & onaysız → yazMAZ; teyit için `--sir-onay`). Konum/ad yaz, değer değil.
- Basit-tut (analitik-sistem değil) · render deterministik/LLM-yok.

## Migrasyon (§F)
Geçici `[KEŞİF] <ne> | tür: … | nerede: … | öneri: … | kim | döngü:<n>` md'leri:
`seyir-defteri migrate <yol>` → `not`-event map (tur←tür · baglam←nerede · metin←ne+öneri · dongu←döngü) ·
içerik-hash **dedupe** (idempotent, çift-koşu=0-yeni) · eski-md `→ MİGRE-EDİLDİ` başlığıyla **arşivlenir** (silme-YOK).

## Doktrin bağları
Kanon-SPEC: `Nexus/_agents/handoff/mimserdar-kesif-gunlugu-SPEC.md`. Emsal: `append-note.sh` (append-only/flock) ·
`sert-dongu` DONGU-LEDGER · `erisim.sh` kimlik. İlk-dogfood: SİNAN (MMEx çekirdek) + HEKİMBAŞI (medigate çekirdek+ritüel).
