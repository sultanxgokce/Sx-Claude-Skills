# AHÎ — 4-Kademe AI-Yetenek Fabrikası

> Sultan'ın ekosisteminde yeni AI-yetenek üretimini **tek-standarda** oturtan meta-fabrika.
> "Ahî" = Osmanlı esnaf-loncası kardeşliği; zanaat-standardının bekçisi.

## Ne bu?
İki-yüzlü bir standart: **DOKÜMAN** ("Değişmezler Kitabı" = kanon) + **ÜRETEÇ** (`ahi` skill = kanonu deterministik zorlayan "el").
Yeni skill/sistem üretimini kademe-kademe standartlaştırır — böylece her yeni-yetenek "tek fabrikadan çıkmış gibi" aynı standarda sahip olur.

## Kademeler (zanaat-rütbesi — tertipli, atlanamaz)
**Çırak** (S1 · yerel skill) → **Kalfa** (S2 · paketli skill) → **Usta** (S3 · bileşik sistem) → **Pîr/Lonca** (S4 · yaşayan sistem).

## Dizin
```
ahi/
  DOCTRINE.md          Değişmezler Kitabı (kanon — önce bunu oku)
  tiers/               Kademe-kartları (cirak/kalfa/usta/pir — her biri 9-boyut)
  SKILL.md             ahi skill tanımı (üreteç-yüzü)
  scripts/ahi.sh       CLI (doctrine/tiers CANLI; new/check/promote/... FAZ-1..4)
  schema/              Manifest-şeması + vendored-validator + fixtures  [FAZ-0b]
  templates/           Kademe-iskelet şablonları                        [FAZ-1]
  ADR/                 Mimari-karar-kayıtları (ADR-001: drift-otorite ayrımı)
```

## Hızlı başlangıç
```
ahi doctrine        # kanonu oku
ahi tiers kalfa     # Kalfa kademe-kartı
ahi --help          # komutlar
```

## Statü
**FAZ-0a** (kanon-kilit): DOCTRINE + kademe-kartları + skill-kabuğu KURULDU. Komutlar FAZ-1..4'te dolar.
Değişmez: additive/INERT · mevcut-sistemlere-dokunmaz (özellikle `sync-skills.mjs`, ADR-001) · value-safe.
Ev: `Sx-Claude-Skills/ahi/` · Dağıtım: `_global` (elle-apply). Sahip: SERDAR/KÂHYA review-kapısı.
