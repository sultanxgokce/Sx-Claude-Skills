---
name: durum
description: Sultan'a ekibin ne durumda olduğunu SADE-TÜRKÇE söyle — kim çalışıyor, kim boşta, kim gizlice yön bekliyor. Ajan-jargonu YOK. USER-ONLY (Sultan/yönetici-eli).
disable-model-invocation: true
allowed-tools: Bash, Read
---

# /durum — ekip durumu, Sultan dilinde

**Kim çağırır:** Sultan (ya da yönetici). USER-ONLY — model kendiliğinden çağırmaz.
**Ne yapar:** Ekibin canlı durumunu toplar ve JARGONSUZ sade-Türkçe özetler: "kim ne yapıyor · kim dinleniyor · kim gizlice yön bekliyor". Ham ajan-jargonunu (busy/preflight/needs_serdar/🟡/SID/hash/dosya-adı) Sultan ASLA görmez — sen çevirirsin.

## Adımlar
1. **Veriyi topla (tek komut):**
   `bash scripts/ekip-durum.sh --porcelain`
   Her satır TAB-ayraçlı: `ID⇥oturum(1/0)⇥sınıf⇥sinyal⇥neden⇥son-KONUM`; son satır `#OZET⇥calisan=N⇥serbest=N⇥bekliyor=N⇥bekleyenler=…`.
   Komut yoksa/hata verirse fallback: `bash scripts/ekip-durum.sh` (insan-tablosu) — onu da okuyup çevirebilirsin.
2. **Gerekirse derinleş (YALNIZ 🟡bekleyen için):** bir üye "bekliyor" ve nedeni belirsizse, o üyenin son-KONUM'una / kanalına Read ile bak — Sultan'a "tam neyi beklediğini" söyleyebilmek için. Serbest/çalışan üye için DERİNLEŞME (gereksiz token).
3. **Sultan diline ÇEVİR ve bas** (aşağıdaki sözlük + şablon). Dosya-adı, commit-hash, SID, jargon KULLANMA. Kısa cümle. "son-KONUM" ham-satırındaki teknik-işi (PR#, dosya, faz-kodu) sade-eyleme çevir (örn. `PR#317 F2.6 koşu-drawer teslim` → "arayüz panelini bitirdi").

### Jargon → Sultan-dili sözlüğü (ZORUNLU)
| Ham sınıf | Sultan-dili |
|-----------|-------------|
| calisir | "şu an çalışıyor: <ne-yaptığı sade, son-KONUM'dan>" |
| serbest | "işini bitirmiş, boşta — yeni iş bekliyor (dinleniyor)" |
| bekliyor | ⚠️ "SENDEN/yöneticiden yön bekliyor — kendiliğinden ilerlemez" |
| menu | "bir onay/menü ekranında duruyor (bir tuş bekliyor)" |
| compact | "hafızasını topluyor, birazdan devam eder" |
| draft | "yarım bir mesaj asılı kalmış (takılmış olabilir)" |
| yok | "şu an açık değil / uykuda" |

### Çıktı şablonu (Sultan görür)
```
🧑‍🚀 EKİP ŞU AN · <saat>

▶️ ÇALIŞANLAR (n)
  • <ÜYE> — <sade ne yaptığı>

😴 BOŞTA / DİNLENİYOR (n)
  • <ÜYE> — işini bitirdi, yeni iş bekliyor

⚠️ SENİ/YÖNETİCİYİ BEKLİYORLAR (n)   ← gizli-bekleyen; boşsa: "yok — herkes ya çalışıyor ya boşta 👍"
  • <ÜYE> — <neyi bekliyor, sade> → yön verilmezse boşta kalır

📋 Tek cümle: <n çalışıyor · n boşta · n seni bekliyor>.
```

## Sınırlar
- SALT-OKUR: hiçbir dosyaya/pane'e YAZMA, ping ATMA, tetikleme YAPMA. Yalnız oku + özetle.
- Sır-değer, dosya-yolu, commit-hash, SID Sultan'a gösterme.
- "Bekliyor" bölümü akış-fix'in Sultan-yüzü: gizli-bekleyeni ÖNE çıkar (Sultan'ın asıl derdi bu — sıradan-boştan ayır).
- Oturumu kapalı üye = normaldir, "uykuda" de, alarm yapma.
- son-KONUM ham-satırı bayat olabilir (üye brief güncellememişse): "çalışıyor" de, uydurma detay ekleme.
