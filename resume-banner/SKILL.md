---
name: resume-banner
type: agent
version: 0.1.0
description: >
  Oturum-açılış ve post-compact/resume anında "neredeyiz" toparlamasını tek-komuta indiren paketli
  yardımcı: env-fingerprint (pwd/hostname/git) + son CONTEXT ⚓-çıpası + son defter-çıpası (+ cortex STATE)
  + post-compact hatırlatmaları. CLAUDE.md "post-compact 4-zorunlu"yu tek harekete indirir; doctor.sh'ı
  tamamlar. SALT-OKU + token-güvenli (büyük dosyaları tam-dökmez). Tetik: oturum başı, compact/resume sonrası,
  makine-değişimi (Mac→container) şüphesi.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [resume, compact, konum, env-fingerprint, oturum]
status: v0.1
---

# resume-banner — (Kalfa · paketli skill)

**NE-DİR:** Oturum-açılış / post-compact refleksini tek-komuta indiren yardımcı. Ölçülen sürtünme:
compact/resume sonrası bayat-bağlamla yanlış-teşhis (canlı-vaka: Mac→container churn'ü "edit'lerim silindi"
sanıldı → 4 edit boşa yeniden-uygulandı) + İngilizce-flip + "neredeyiz/bitti mi" tekrar-sorusu. Bu skill
CLAUDE.md **post-compact 4-zorunlu**yu (env-fingerprint · harness-varsayma · dil-koru · 3-satır KONUM-banner)
tek harekete toplar: ham-maddeyi (env + son çıpalar) çeker, hatırlatmaları basar; **3-satır banner'ı ajan yazar**.

## Kullanım

```bash
resume-banner            # tam refleks: env-fingerprint + KONUM ham-maddesi + post-compact hatırlatmaları
resume-banner env        # yalnız env-fingerprint (pwd/hostname/git status -sb)
```

**Tipik refleks (compact/resume sonrası İLK tur):**
`resume-banner` → çıktı: (1) nerede çalışıyorum (host/dizin/dal/kirli/HEAD), (2) son CONTEXT ⚓ + son defter
çıpası, (3) 4-zorunlu hatırlatma. Ajan bu ham-maddeden 3-satır KONUM-banner'ı yazar (neredeyiz · ne bitti · sıradaki).

## Değişmezler
- **SALT-OKU:** hiçbir dosya yazılmaz — yalnız okur ve basar.
- **Token-güvenli:** büyük dosyaları (CONTEXT.md ~85k token) ASLA tam-dökmez; yalnız son ⚓-çıpa satırları.
- **Taşınabilir:** Nexus-uçları (CONTEXT/defter/cortex-STATE yolları) yoksa sessiz-atlar; env-fingerprint + genel
  hatırlatmalar her projede çalışır.
- **Doğuran-değil-toparlayan:** 3-satır semantik banner ajanın yargısıdır; skill ham-maddeyi ve checklist'i verir.

## Kademe
Kalfa (S2 · paketli). generic-goal: "planlı + paketli + her-projede güvenilir tekrarlanabilir".
Manifest: `ahi.manifest.yaml` · Doğrula: `ahi check resume-banner` · Kanon: `ahi doctrine`.
Kaynak: Vizyon-denetimi FAZ-2 İLK-DALGA (Z5, YK-007); defter-kartı k0110.
