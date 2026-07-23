# vault-cek OpenBao adaptörü — TASLAK (L13, cutover AYRI karar)

`vault-cek-openbao.sh` = aynı public-kontrat (doctor/resolve/list/get · KEY→path · 600-env-yazıcı),
backend = OpenBao KV-v2 + AppRole. **INERT paralel-taslak** — `vault-cek.sh` (Infisical, bayt-aynı
`vault-cek-infisical.sh`) hâlâ aktif adaptördür; cutover Sultan-kararıyla ayrı iştir.

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

## Doğrulanmadı
Canlı OpenBao mount/policy adları (DESIGN tarafı — `olceklenebilir-vault-erisim-DESIGN.md`);
taslak canlı sunucuya karşı test edilmedi (host-mutasyon yasak, INERT teslim).
