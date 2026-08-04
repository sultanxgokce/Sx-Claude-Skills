---
name: sultan-eli
type: agent
version: 0.1.0
description: >
  Geri alınamaz kapılar için "bu komutu gerçekten insan mı başlattı?" ölçümü. Sultan'ın `!`
  ile koştuğu komut oturum kaydına `<bash-input>` olarak düşer, ajanın komutu düşmez —
  kapı bu izi imzaya ve zamana bağlayarak arar. Kilit değil korkuluk: kazayı durdurur, kastı durdurmaz.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [onay, kapi, guvenlik, a06, sultan-gate, kalfa]
status: v0.1
---

# sultan-eli — "bunu insan mı başlattı?" (Kalfa · paketli)

**NE-DİR:** Geri alınamaz bir işi yapmadan önce, çağrının bir **insan `!` komutundan** geldiğini
ölçen tek-amaçlı kapı. Ölçer, karar vermez: verdikti çağıran kapı yorumlar.

## Niçin var
Filoda **18 beceri** bir "Sultan onayladı" bayrağı taşıyor. 2026-08-03'te NÂZIR ölçtü:
bayrağın **varlığı** fail-closed zorlanıyor, **kaynağı** hiç sorulmuyor. Uçtan uca sınandı —
ajan ortamında, insan hiç devrede değilken bir terfi geçti, `RC=0`. Ajanı durduran tek şey,
bayrağı yazmamayı **seçmesiydi**. Yani sanılan "kapı var"; gerçek olan "bayrak var, ölçüm yok".

## 🔴 Ne olmadığı — önce bu
**Kilit değil, korkuluktur.** Oda anahtarsız doğdu: betiği koşturabilen ajan, betiğin
okuyabildiği her şeyi de yazabilir. **Kazayı ve sessiz sürüklenmeyi** durdurur, **kastı**
durdurmaz. "Artık güvenli" cümlesi bu paketin verdiği güvencenin ötesindedir.

## Nerede kullanılır — ve nerede KULLANILMAZ
Sultan kararı (2026-08-04): **yalnız geri alınamaz kapılarda.**

| kullanılır | kullanılmaz |
|---|---|
| söküm · üretim-veritabanı · sunucu kurma · CF rota silme | terfi · layiha · kart açma · rapor |

Gerekçe: tam kilit imkânsız olduğuna göre ölçüm ancak kazayı durdurur → bedeli, kazanın
**felaket** olduğu yere harcanır. Geri alınabilir kapılarda bayrak **beyan** olarak kalır,
çünkü yanlış-red gerçek bir maliyettir (31 Tem'de meşru bir Sultan işi tam bu yüzden engellendi).

## Kullanım
```bash
sultan-eli.sh dogrula --imza "sokum tez"   # kapının kendi komut parçası
sultan-eli.sh durum                        # ölçüm yüzeyi bu kutuda görünüyor mu
```
Çıkış: `0` insan-izi var · `1` yok · `2` kullanım · **`3` ÖLÇÜLEMEDİ**.

⚠️ **3 ≠ 1.** Ölçemediğini "insan yok" saymak, kapıyı yer-gerçeği yerine bilgisizliğe bağlar.
Çağıran taraf 3'ü kendi politikasına göre yorumlar (öneri: dur ve Sultan'a sor).

**İmza zorunlu.** İmzasız bir kontrol, kapıyı yalnız bir zaman-penceresine indirger: insan
başka bir iş için `!` yazdıktan hemen sonra ajan kapıdan geçebilirdi. İmza, izi **komuta** bağlar.

## Ölçülen yüzey (firsthand, 2026-08-04)
İnsanın `!` komutu kayda `<bash-input>` sarmalayıcısıyla düşer; ajanın komutu `tool_use` olur.
Aynı oturumda: `<bash-input>` = **59** · ajan Bash çağrısı = **12515**.
⚠️ `userType=external` **ayırt etmez** (168047 satır — her kullanıcı-rolü satırında var).
**Zamanlama** (yaklaşımın yaşam-şartı): kayıt komuttan **önce** düşüyor —
`<bash-input>` .492 → komut .863 → `<bash-stdout>` .866. Sonra düşseydi bu yaklaşım ölüydü.

## Kademe
Kalfa (S2 · paketli, proje-bağımsız). Doğrula: `bash scripts/sultan-eli.test.sh` (15 kontrol).

## Geliştirme (KULLANDIKÇA GELİŞTİR — AHÎ §12)
Bu beceriyi kullanırken eksik/hata/daha-iyi-yol görürsen **düzeltmek senin işindir**:
1. Kendi kutunun canlı rafındaki kopyada düzelt.
2. **Sürümü yükselt** (yukarıdaki `version:`; davranış-düzeltmesi=patch · yeni yetenek=minor).
3. **Kanona döndür** — `Sx-Claude-Skills`'e PR; kutun kanonu görmüyorsa klasörü kuryenin
   giden kutusuna bırak + tek sayfalık devir notu.
4. Dağıtımı doğrula + deftere bir satır düş.

⚠️ Bu becerinin özel borcu: **fixture-yeşil yetmez.** İlk sürüm 14/14 fixture testini geçtiği
hâlde gerçek oturum kaydında yanlış cevap verdi. Her değişiklikten sonra **canlı kayıtta** koştur.
