# canli-sayfa-beceri-kaydi — kapsam, karar, bilinen sınırlar (2026-09-30 · SERDAR)

## İstek (D1)
2026-09-29 Sultan: canlı sayfa kuralı beceri ve komut olarak bütün kutulara dağıtılsın
(sohbet · session_013fuJSNg65VkgQE4sJsQURS · "bunu bir ai skill ve slash komutuna çevir ve tüm kutulara global dağıt" · beyan:SERDAR)
2026-09-30 Sultan: ikiye böl (sohbet · session_013fuJSNg65VkgQE4sJsQURS · "İkiye böl, yeniden gönder" · beyan:SERDAR)
2026-09-29 Sultan: ortak kayıt dosyalarında PR #33 ile çakışmada devam edilsin
(sohbet · session_013fuJSNg65VkgQE4sJsQURS · "Devam et, satırımı ekle" · beyan:SERDAR) — aynı PR, aynı iki dosya; karar bu kartta da uygulandı.

## Bu kart ne
PR #253 (`canli-sayfa-kayit-araci`) ikiye bölündü. Aracın kendisi **PR #255** (`canli-sayfa-araci`). Bu kart yalnız:

| Parça | Ne |
|---|---|
| `canli-sayfa/SKILL.md` | filo kuralı: canlıya çıkan her sayfa kayda girer; dört adım; komut ve kayıt kuralları; `/canli-sayfa` komutu beceri adından gelir |
| `catalog.json` | beceri kaydı (`canli-sayfa`, 1.0.0, hedef `_global`) |
| `sync-targets.json` | dağıtım hedefi satırı (`_global`) — kurulumun NEREYE yapılacağının kaydıdır, kurulumun kendisi değildir |

## Sıra bağı
Beceri metni aracın yolunu (`scripts/canli-sayfa.sh`) anlatır; araç PR #255'te. **Önce #255, sonra bu PR birleşir.**
Bu PR tek başına birleşirse beceri kayıtta görünür ama komutu henüz olmaz; o yüzden sıra şart.

## Bu işte OLMAYAN (ayrı kartlar)
1. Kurulum (`sync-skills.mjs` ile yalnız bu beceri; toplu kurulum yapılmaz), kurulu = kaynak ölçümü.
2. İlk kayıtlar (bugün canlı olan sayfalar kurulu araçla yazılır).
3. Kokpit menüsü (cloudtop `kokpit-canli-sayfalar-veri` #549 + Nexus ekran kartı); menü çıkınca durum notu kalkar (1.1.0).
4. Kuralın kutulara duyurusu; ortak talimat dosyasına kısa satır.

## Kanıt
| Ölçüm | Ne gösterir |
|---|---|
| kayıt korunumu | ana daldaki her beceri kaydı ve dağıtım hedefi aynen duruyor; eklenen tek kayıt `canli-sayfa` (tur 1 dersi: eski kopyadan taşımada `terminal-onar` silinmişti) |
| depo denetimi | kayıt ↔ dağıtım haritası eşleşiyor; sürüm satırı geçerli |
| kapsam | bu belge |

## Bilinen sınırlar
- Kural belge; uygulatan kilit yok. Kayıt yazmayan ajanı yakalama yolu ayrı iş.
- Beceri metnindeki komut örnekleri araç birleşmeden çalışmaz (sıra bağı yukarıda).
