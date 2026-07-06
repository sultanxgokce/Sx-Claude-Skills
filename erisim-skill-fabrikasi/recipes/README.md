# Auth reçeteleri — erisim-skill-fabrikasi bilgi tabanı

Her `<platform>.md` = o platformun **erişim/auth reçetesi**: fabrikanın `<platform>-erisim` skill'ini
doğru üretmesi için gereken bilgi. Adversaryal-doğrulanmış üretilir; bir platform eksikse fabrika
Adım 2'de web ile araştırıp buraya kaydeder (bilgi tabanı büyür).

## Format (Markdown frontmatter)

```yaml
---
platform: railway
summary: >
  Bir cümle — bu platformda API/CLI erişimi nasıl kurulur.
honesty_constraint: >
  Baştan dürüstçe söylenecek GERÇEK kısıt (ör. kullanıcı-adı+şifre→token API YOK; dashboard-only).
credential_intake: >
  Kullanıcının BİR KEZ verdiği şey + nasıl (token yapıştır / OAuth device-flow / service-account JSON).
token_mint: >
  Skill dar-yetkili token'ı PROGRAMATİK üretebilir mi? Kesin API endpoint / CLI komutu; yoksa "dashboard-only: <adım>".
scopes: >
  Yaygın işler için least-privilege scope/permission seti.
forbidden: >
  Anti-patternler / sır-sızıntı riskleri (ör. `railway variables --set <deger>` → değer process-list'e sızar).
verify: >
  Kimliği doğrulayan ucuz komut/endpoint (whoami/read).
cli_tool: gh | gcloud | railway | vercel | aws | doctl | hcloud | openai | "none (saf API)"
env_var: RAILWAY_TOKEN        # cortex-access.env için konvansiyonel ad
confidence: high | medium | low
sources: [<doğrulanan resmi doküman URL'leri>]
---
```

Gövdede (opsiyonel): örnek `login`/`doctor`/iş komutları, tuzaklar, platforma özgü notlar.

## Değişmez kurallar (tüm reçetelerde)
- **Sır değeri asla dosya/chat/log/argv'ye** — yalnız `~/.config/cortex-access.env` (600) + registry pointer.
- Üretilen skill **3-durumlu doctor** (yeşil/kırmızı-fail/doğrulanmadı) taşır.
- `forbidden` maddelerine üretilen skill'de UYULUR (ör. Railway `variables --set` yerine dashboard).
