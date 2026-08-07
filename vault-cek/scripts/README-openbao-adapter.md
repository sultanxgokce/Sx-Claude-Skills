# vault-cek OpenBao adaptörü — **CANLI VARSAYILAN** (L54 cutover, 2026-08-07)

`vault-cek-openbao.sh` = aynı public-kontrat (doctor/resolve/list/get · KEY→path · 600-env-yazıcı),
backend = OpenBao KV-v2 + AppRole. **2026-08-07'den beri aktif adaptör** — `vault-cek.sh` artık
bir DİSPATCHER'dır ve varsayılan olarak buraya yönlendirir. `vault-cek-infisical.sh` silinmedi;
30-gün salt-okur fallback olarak duruyor.

## Hangi kasa aktif? (teşhis)

```
vault-cek backend        # aktif backbone + nereden geldiği (env / kutu-dosyası / varsayılan)
```

Seçim önceliği: `$VAULT_BACKEND` → `~/.config/vault-backend` (kutu-başına, tek kelime) → varsayılan `openbao`.

**Geri dönüş (tek kelime, kutu-başına):** `echo infisical > ~/.config/vault-backend`

**Niçin dosya:** skill-dizini 13 konteynerde TEK ve ORTAK mount'tur (aynı inode) — dosyayı
değiştirmek filoyu tek anda çevirir. `~/.config` kutu-başına ayrıdır; cutover'ın tenant-tenant
yürüyebilmesi ve tek-kelimeyle geri alınabilmesi bu ayrımdan gelir.

## Eşlemeler (Infisical → OpenBao)

| Infisical | OpenBao |
|---|---|
| `identity.env` CID/CSEC/PROJECT_ID | `~/.config/openbao/identity.env` → `BAO_ADDR` + `BAO_ROLE_ID` + `BAO_SECRET_ID` (600) |
| universal-auth login | AppRole login (`auth/approle/login`) → `BAO_TOKEN` (yalnız shell-değişkeni) |
| folder `/kaynak` + düz KEY | KEY-başına-secret: `secret/<kaynak>/<KEY>`, field=`value` (KV-v2) |
| `--domain` | `--mount` (`BAO_KV_MOUNT`, default `secret`) |
| doctor `-o dotenv` probu | `kv list` / metadata-LIST exit-code probu (exit-4 + 3-durum korunur) |

## Motor
`bao` CLI varsa CLI-yolu; yoksa curl+jq HTTP-API fallback. Sır-değeri stdout/log/chat'e ASLA;
`get` yalnız `cortex-access.env`'e (600, orijinal KEY-adıyla) yazar.

## Cutover kanıtı (2026-08-07, değer-okumayan)
- `/nexus` 43 + `/shared` 1 = **44 anahtarın 44'ü iki kasada BAYT-AYNI** (dosya-karşılaştırma; değer basılmadı).
- Kutu doktorları: code · tellal · huzur · mihenk · mmex → `exit=0` (openbao).
- Çapraz-kiracı negatif test: 12 denemeden 11'i **reddedildi**; izin verilen tek satır kimliğin KENDİ kapsamı.

## Hâlâ doğrulanmadı
- `/mmex` klasörü (Infisical'da 3 anahtar) OpenBao'ya **taşınmadı** — `tenant-mmex` policy'si de yok.
  O kutu bugün `mmepanel` rolüyle çalışıyor (mmepanel 43 + shared 1). Kalan iş: provizyon + göç.
- İzole kutuların (vekatip · medigate · huma · akar · s02) kimlik dosyası YOK — o kutularda
  `vault-cek` hiçbir kasayla çalışmıyor (cutover ÖNCESİ de böyleydi; regresyon değil).
