# Matris FORMAT-v0 — gereklilik-matrisi dosya-biçimi (GENERIC)

> Bu biçim proje-bilmezdir (MOTOR-sınıfı). Örnekler soyut "proje-X" üzerinedir; hiçbir gerçek-proje
> adı/değeri normatif-metne giremez. Sürüm: `0.1.0-faz0`.

## 1. Kolon-şeması

Matris dosyası bir markdown tablosudur. Kolonlar SIRALI ve ZORUNLUDUR:

```
| M# | C-ID | kaynak-cümle-verbatim | yuzey | kanıt-türü | doğrulama-komutu(+hash) | etki-alanı | veri-rejimi | durum | kanıt-JSON-ref |
```

| Kolon | Açıklama |
|---|---|
| `M#` | Matris-satır kimliği: `M` + pozitif tamsayı (`M1`, `M2`, …). Tekil. |
| `C-ID` | Kaynak-cümle kimliği: `C-` + sha256(boşluk-normalize(cümle))[0:8] hex. `cumle_bolucu.mjs` üretir. |
| `kaynak-cümle-verbatim` | İş-sahibi/plan cümlesi VERBATIM (yalnız boşluk-normalize). Ham `\|` karakteri `\\|` olarak kaçırılır. |
| `yuzey` | Config'teki `surfaces[].id` değeri (ör. `web-ui-1`, `api-1`). |
| `kanıt-türü` | Enum, bkz. §3. |
| `doğrulama-komutu(+hash)` | Ters-tırnak içinde komut + OPSİYONEL bilgi-amaçlı `sha256:<ilk-12-hex>` eki. Kanonik hash'i `durum_uret.mjs` komut-metninden KENDİSİ hesaplar; ekteki kısa-hash yalnız insan-okur özettir. Biçim: `` `komut metni` sha256:0f3c9d2ab41e `` |
| `etki-alanı` | Kanıtın kapsadığı dosya-glob'u (ör. `src/ui/**`). Tazelik-denetimi bu glob'un son git-commit zamanına bakar. Boş ya da `-` = tazelik-denetimi atlanır. |
| `veri-rejimi` | Kanıtın veri-tabanı: `sentetik` \| `mock` \| `gercek`. Sentetik/mock kanıt teslim-raporunda kalıcı disclaimer düşürür. |
| `durum` | TÜRETİLMİŞ-VERİ — elle yazılamaz, bkz. §2. |
| `kanıt-JSON-ref` | Kanıt dosyası yolu-referansı. Kanonik ad-kuralı: `kanit/<M#>.json` (rejeneratör HER ZAMAN bu ada bakar; hücre insan-okur pointer'dır). |

## 2. `durum` enum'u + tek-yazar kuralı

Enum (kapalı-liste): **`bekliyor` · `kanitli` · `fail` · `engelli` · `OLCULEMEZ`**

- `bekliyor` — kanıt yok / kanıt geçersiz / hash-uyuşmaz / bayat.
- `kanitli` — dörtlü-denetimin DÖRDÜ de geçti (bkz. §4-şeması + `durum_uret.mjs`).
- `fail` — geçerli kanıt var ama `rc != 0` (komut fiilen düştü).
- `engelli` — iş-sahibi-gate'li park durumu (kanıt-türevi DEĞİL).
- `OLCULEMEZ` — cümle test-edilebilir değil; sessizce düşmez, iş-sahibi-gate'e taşınır.

**Tek-yazar (by-construction):** `bekliyor/kanitli/fail` yalnız `durum_uret.mjs` tarafından, `kanit/`
JSON'larından REJENERE edilir; elle yazım güvence taşımaz (bir sonraki rejenerasyon ezer).
`engelli` ve `OLCULEMEZ` iş-sahibi-gate'li istisna-durumlardır: kanıttan türetilemezler, rejeneratör
bunları KORUR (dokunmaz) ve raporunda `korunan` listesinde isimli bildirir.

**Emoji-yasağı:** `durum` hücresinde (ve herhangi bir kanıt-hücresinde) emoji = lint-FAIL.
Gerekçe-mirası: yeşil-satır sayan lint'ler emoji ile DRIFT'e girer (C8+C12 mirası — baked-in kural).

## 3. `kanıt-türü` enum'u

Kapalı-liste: **`komut` · `api-check` · `e2e-check` · `gorsel-onay`**

- `komut` — runner/lint/build komutu (en zayıf sınıf; görünürlük-fiilli cümlede tek başına yetmez).
- `api-check` — çalışan servise gerçek istek + yanıt-assert.
- `e2e-check` — kullanıcı-yüzeyinde uçtan-uca davranış-assert.
- `gorsel-onay` — iş-sahibi görsel onayı (yeniden-onay metasına tabidir).

## 4. Kanıt-JSON şeması (`kanit/<M#>.json`)

Kanonik kanıt = bu JSON. Alanlar:

```json
{
  "m_id": "M1",
  "komut": "npm run e2e -- --grep rozet",
  "komut_sha256": "<64-hex: sha256(komut-metni)>",
  "rc": 0,
  "counters": { "collected": 12, "passed": 12, "failed": 0, "skipped": 0 },
  "started_at": "2026-01-01T10:00:00+03:00",
  "finished_at": "2026-01-01T10:03:20+03:00",
  "runner": "generic-rc",
  "kirmizi_kanit_ref": "kanit/M1-kirmizi.json",
  "skill_version": "0.1.0-faz0",
  "proje_koku": "/yol/proje-X",
  "config_yolu": "/yol/proje-X/tooling/teslim/teslim-config.yaml"
}
```

Kurallar:
- `counters` runner-adapter parse edemezse `null` — `null` = ZAYIF-işaret: durum yine `kanitli`
  olabilir AMA rejenerasyon-raporunun `zayif_kanit` listesine girer (parse-fail asla PASS'e
  default'lanmaz; gate-sertleşmesi FAZ-1).
- `kirmizi_kanit_ref` — kırmızı-kanıt (FAIL-edebilirlik) koşumunun referansı; yoksa `null`
  (FAZ-1'de `kanitli` için zorunlu-şart olur).
- `proje_koku` + `config_yolu` — yol-çözüm-kontratı damgaları: motor yolları
  `git rev-parse --git-common-dir` ile ANA-depo köküne pinlenir (worktree'de bile);
  uyuşmazlık FAZ-1 lint'inde FAIL.

**Dörtlü-denetim** (`durum_uret.mjs` her satırda):
1. `kanit/<M#>.json` var ve geçerli-JSON mu?
2. `komut_sha256` == sha256(satırdaki doğrulama-komutu) mü? (rejeneratör satırdan komutu parse edip kendisi hash'ler)
3. `rc == 0` mı? (değilse durum = `fail`)
4. Tazelik: `finished_at` > etki-alanı-glob'unun son-git-commit zamanı mı?
   (git yok ya da glob'a dokunan commit yoksa bu denetim atlanır; denetim koşup DÜŞERSE durum `bekliyor` + stderr'e neden)

## 5. TSV = önbellek, kanonik = JSON

L0 (POSIX-sh/awk) lint'lerin JSON-parse kırılganlığı için kanıt-JSON yanına TSV-özet çift-emit
edilebilir. Statü kuralı: **TSV = ÖNBELLEK, kanonik = JSON.** Mekanik bağ: her TSV-satırında zorunlu
`json_sha256` kolonu (ilgili kanıt-JSON dosya-içeriğinin sha256'sı); lint `sha256sum` ile doğrular —
uyuşmazlık/eksik-kolon = FAIL. TSV her rejenerasyonda JSON'dan YENİDEN üretilir (elle-TSV yaşayamaz).
(TSV-emit'in kendisi FAZ-1 motor-işi; FAZ-0'da yalnız kural sabitlenir.)

## 6. Soyut örnek (proje-X)

```
| M# | C-ID | kaynak-cümle-verbatim | yuzey | kanıt-türü | doğrulama-komutu(+hash) | etki-alanı | veri-rejimi | durum | kanıt-JSON-ref |
|---|---|---|---|---|---|---|---|---|---|
| M1 | C-1a2b3c4d | Ana sayfa yüklendiğinde durum rozeti görünür. | web-ui-1 | e2e-check | `npm run e2e -- --grep rozet` sha256:0f3c9d2ab41e | src/ui/** | sentetik | bekliyor | kanit/M1.json |
| M2 | C-5e6f7a8b | Liste ucu boş kümede 200 döner. | api-1 | api-check | `sh checks/liste-bos.sh` sha256:77c1d02e9ab4 | src/api/** | sentetik | bekliyor | kanit/M2.json |
```

## 7. Genel kurallar

- Bu biçim GENERIC'tir: gerçek proje adları/portları/rol-adları normatif-metne giremez
  (jargon-lint PROMOTE-gate'te denetler); örnek gerekiyorsa soyut "proje-X".
- Matris-satırı serbest-metinle değiştirilemez; eksiklik ya satırı `fail`'e çevirir ya YENİ M-satırı
  doğurur (serbest "KALAN:" notu yasak — kanon §4.3).
- ONAY-1 sonrası gereklilik-cümlesi DOKUNULMAZ; yeni gereklilik append-only.
