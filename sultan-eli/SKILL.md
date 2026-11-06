---
name: sultan-eli
type: agent
version: 0.1.3
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
Kalfa (S2 · paketli, proje-bağımsız). Doğrula: `bash scripts/sultan-eli.test.sh` (saniye-içi dahil).

## Geliştirme (KULLANDIKÇA GELİŞTİR — AHÎ §12)
Bu beceriyi kullanırken eksik/hata/daha-iyi-yol görürsen **düzeltmek senin işindir**:
1. Kendi kutunun canlı rafındaki kopyada düzelt.
2. **Sürümü yükselt** (yukarıdaki `version:`; davranış-düzeltmesi=patch · yeni yetenek=minor).
3. **Kanona döndür** — `Sx-Claude-Skills`'e PR; kutun kanonu görmüyorsa klasörü kuryenin
   giden kutusuna bırak + tek sayfalık devir notu.
4. Dağıtımı doğrula + deftere bir satır düş.

⚠️ Bu becerinin özel borcu: **fixture-yeşil yetmez.** İlk sürüm 14/14 fixture testini geçtiği
hâlde gerçek oturum kaydında yanlış cevap verdi. Her değişiklikten sonra **canlı kayıtta** koştur.

## Zincir kimliği (0.1.2 · SERDAR kararı 6 Kas 2026)
Kayıt komutun BAŞINDA düşer, kapı zincirin SONUNDA koşabilir; 45 sn pencere kayıt anından sayıldığı için
geç kalan kapı meşru Sultan'ı reddediyordu (fixture: 5 sn → VAR, 60 sn → YOK). Pencere büyütülmedi (gevşetir).
Kimlik bağı eklendi: kapının süreç zincirinde komut satırı kayıttaki insan komutunu BİREBİR taşıyan bir kök
varsa ve o kök kayıt anında başlamışsa (−2..+5 sn) kayıt kabul edilir, mutlak üst sınır 10 dk
(`SULTAN_ELI_ZINCIR_UST`). Yoksa eski 45 sn kuralı aynen. Aynı komutun sonradan yeniden koşusu, başka komut
ve yeniden kullanılmış PID geçmez. **Dürüst sınır:** kaydı Claude Code yazar, satıra PID giremez; bağ komut
metni + başlangıç saatidir. Sınav sarmalayıcıyı `eval '<komut>'` kökü olarak taklit eder (bu oturumun kendi
zincirinde ölçüldü); gerçek `!` koşusu fixture ile üretilemez → canlı doğrulama Sultan'ın tek `!` komutuyla.

### 0.1.3 · sarmalayıcıyı ayrıştır (6 Kas 20:2x, canlı `!` koşusu "insan-izi YOK" dedi)
0.1.2 yalnız `eval '<komut>'` biçimini tanıyordu; sınav da kökü öyle kuruyordu (fixtürde yeşil, canlıda kırmızı).
Artık kök kabuk satırı shlex ile ayrıştırılır, `eval` argümanı çözülüp komutla BİREBİR karşılaştırılır (tek/çift
tırnak ya da ters bölü fark etmez); `< /dev/null && pwd -P >| …` kuyruğu ve `source … && shopt …` başı sınavda
ps'ten ölçülen gerçek biçimle kurulur. Alt dize hâlâ geçmez (önek/sonek, başka argümanın içinde geçen metin).
Eşleşmeyen zincirde kapı SEBEBİ sayılarla basar (`tanı: pid=… başlangıç-kayıt=… eval-argümanı=…`; komut metni
basılmaz). **Dürüst sınır:** canlı koşunun neden düştüğü KANITLANMADI (iki aday: sarmalayıcı biçimi, kök başlangıç
saati); bu sürüm birincisini kapatır, ikincisini tanı satırı gösterecek.
