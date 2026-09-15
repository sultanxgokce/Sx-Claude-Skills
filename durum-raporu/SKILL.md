---
name: durum-raporu
version: 0.2.0
description: Sultan "durum raporu / son durum / neler yapılıyor" deyince bu kutunun personelini STANDART biçimde raporlar — kişi başına bitirdi · geçti · önündeki işler · bekliyor · canlı bağlantı; veri tüm kutularda aynı şemadan (SEMA.md).
allowed-tools: Bash, Read
---

# /durum-raporu — personel durum raporu (Sultan standardı, 2026-09-15)

**Kim çağırır:** Sultan (ya da kutunun reisi). Reis, Sultan durum sorduğunda BU biçimi kullanır; serbest anlatım yapmaz.
**Nerede çalışır:** çağrıldığı kutunun içinde; başka kutuya bakmaz.

## Adımlar
1. `bash /config/.claude/skills/durum-raporu/scripts/durum-raporu.sh` → raporu olduğu gibi Sultan'a bas (Türkçe, sıra registry sırası).
2. Satırlarda "(türetildi — durum dosyası yok)" görüyorsan o üyenin durum dosyası eksiktir: üyeye `durum-yaz.sh` ile kendi dosyasını
   yazmasını söyle; türetilmiş satırı uydurma bilgiyle TAMAMLAMA.
3. Bağlantılar `mmepanel://…` hâlinde çıkıyorsa `link-taban.yaml` doldurulmamıştır — Sultan'a tek satırla söyle, ham linki bas.

## Üye tarafı (her ajanın görevi — iş bitince / işe geçince / kuyruk değişince)
`bash /config/.claude/skills/durum-raporu/scripts/durum-yaz.sh --ad <AD> --bitti "<iş>" --kayit <sha> --simdi "<sıradaki iş>" --link mmepanel://<kutu>/dosya/<yol> --kuyruk "iş|hedef-tarih|link" --bekliyor "kimden|ne|link"`
Kural: yalnız KENDİ dosyanı yaz; saat betikten gelir (elle yazma); bilinmeyen alan boş kalır.

## Dosyalar
- `SEMA.md` — veri sözleşmesi + link şeması + rapor biçimi (tek kaynak).
- `scripts/durum-raporu.sh` (okuyucu) · `scripts/durum-yaz.sh` (yazıcı) · `scripts/link-coz.sh` + `link-taban.yaml` (bağlantı çözümü, filo geneli).

## Sürüm notu — 0.2.0 (MUAVİN, 2026-09-15)
Beceri AKAR'da (MÜTEVELLİ) doğdu; bu sürümle **filo geneline paketlendi**:
- `link-taban.yaml` dolduruldu: kod sunucusu şablonu ölçülmüş biçimle yazıldı
  (`https://{kutu}.mmepanel.com/?folder=/config/projects/{kutu}`, federe-registry `hostname` ile birebir).
- `link-coz.sh` artık **kutuya özel** şablonu (`<tur>_<kutu>:`) filo-genelinden ÖNCE okur —
  akar'ın canlı adresi (`yayin_akar`) böyle çözülür, öteki kutular ham link basar.
- 🔴 Ölçülmeyenler boş bırakıldı (uydurma URL yok): mobil panelde pencere derin-bağlantısı ·
  commit görünümü · sinyal defteri satırı · code-server'ın TEK DOSYA açan parametresi.
- 🔴 **Taşınma tuzağı kapatıldı:** betikler proje kökünü `pwd`den alıyordu; beceri global dizine
  kurulunca kök kayıyor ve ekip kaydı bulunamıyordu (filo'nun bilinen "taşıyınca sessizce kırılır"
  sınıfı). Artık `scripts/repo-bul.sh`: açık ayar → cwd → üst dizinler; hiçbiri değilse rc=1 ve
  sahte kök uydurulmaz.
- Kapılar eklendi: `scripts/link-coz.test.sh` (8) · `scripts/repo-bul.test.sh` (5), ikisi de ağsız.
