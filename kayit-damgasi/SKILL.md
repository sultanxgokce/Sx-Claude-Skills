---
name: kayit-damgasi
type: agent
version: 0.1.0
description: >
  Bir iş/PR merge olurken kapattığı kayda (defter-kartı, gap/bulgu-defteri, SULTAN-KAPISI gate'i,
  plan-satırı) kapanış-damgasını işleyen paketli yardımcı. CLAUDE.md §9 "Kayıt-Damgası" refleksini
  tek-komuta indirir; mevcut `defter-mailbox.sh durum` primitifini orkestra eder. Tetik: bir PR
  merge edildikten sonra, ya da "bu iş şu kaydı kapatıyor mu?" refleksi.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [kayit-damgasi, defter, merge, damga]
status: v0.1
---

# kayit-damgasi — (Kalfa · paketli skill)

**NE-DİR:** Bir iş/PR bir kaydı fiilen kapatıyorsa (ya da ilerletiyorsa), **merge anında** o kayda
kapanış-damgasını işaretlemeyi refleks-hıza indiren yardımcı. 30 günde **8×** "kayıt bayatken fix landed"
ölçüldü — damga atlanınca bir-sonraki ajan aynı işi yeniden keşfediyor. Bu skill CLAUDE.md
**§9 (Kayıt-Damgası)** adımını mekanikleştirir: verilen bir git-ref/PR'ın kapattığı kayıtları bulur,
önerilen damga-komutlarını basar ve (onayla) uygular.

Kapsadığı kayıt-türleri: **defter-kartı** (`defter-mailbox.sh durum <k####> bitti --kanit …`) ·
**gap/bulgu-defteri** (FIX + kanıt satırı) · **SULTAN-KAPISI** gate'i (durum + damga) · **plan-satırı**.

## Kullanım

```bash
# 1) SALT-OKU tarama — ref hangi kayıtları kapatıyor, hangi damgalar önerilir?
kayit-damgasi tara <git-ref|range>        # ör: kayit-damgasi tara HEAD   ·   kayit-damgasi tara main..HEAD

# 2) Tek kart-damgası uygula (defter-mailbox.sh durum sarmalayıcı)
kayit-damgasi isle k0107 bitti --kanit "#493"

# 3) Merge-sonrası tek-hareket: tara + (--apply ise) ref'teki k#### kartlarını 'bitti' damgala
kayit-damgasi merge HEAD            # DRY — ne yapılacağını basar
kayit-damgasi merge HEAD --apply    # commit-mesajlarındaki k#### kartlarını damgalar
```

**Tipik refleks (PR merge ettikten hemen sonra):**
`kayit-damgasi merge <merge-commit>` → çıktı: kapatılan kartlar otomatik damgalanır, gap/kapı/plan
kayıtları "elle-damga adayı" olarak listelenir (bunlar serbest-metin düzenleme ister).

## Değişmezler (güvenlik)
- **DRY-varsayılan:** `tara` ve `merge` (`--apply`'sız) hiçbir yazma yapmaz — INERT.
- **İnsan-onay-alanına yazmaz:** yalnız ajan-yetkili kart-durumu (`bitti|teslim|yeniden`) flip'lenir;
  `sultan_response`/onay gibi alanlara dokunmaz (ek-guard: geçersiz durum = red). Yetki-Sınırı Protokolü.
- **Yeniden-icat yok:** kart-flip'i `scripts/defter-mailbox.sh durum`'a devreder; o yoksa (Nexus-dışı proje)
  net-mesajla durur, sessiz-geçmez.

## Kademe
Kalfa (S2 · paketli). generic-goal: "planlı + paketli + her-projede güvenilir tekrarlanabilir".
Manifest: `ahi.manifest.yaml` · Doğrula: `ahi check kayit-damgasi` · Kanon: `ahi doctrine`.
Kaynak: Vizyon-denetimi FAZ-2 İLK-DALGA (Z6, YK-007); defter-kartı k0107.
