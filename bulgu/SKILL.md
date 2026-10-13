---
name: bulgu
version: 0.2.0
description: "Filonun TEK bulgu komutu — hangi kutuda olursan ol, gördüğün kusuru ya da fikri aynı komutla, aynı şemayla kutunun Bulgu Defteri'ne yaz (bulgu.mmepanel.com'da Sultan'ın tek sayfasında görünür). 'bulgu yaz', 'kusur kaydet', 'deftere düş' dendiğinde kullan."
allowed-tools: Bash
---

# /bulgu — bir kusuru ya da fikri, filonun her yerinde aynı biçimde kaydet

**Niçin (Sultan /goal K2, 12 Eki 2026):** filoda en az dört ayrı bulgu biçimi vardı (aday havuzu · bulgu-havuzu ·
Bulgu Defteri · NÂZIR havuzu) ve kutular deftere ya hiç yazmıyor ya elle yazıp şemayı bozuyordu (AKAR'ın 274
kaydı eski biçimde). Yazma aracı 10 kutuda kuruluydu ama hiçbir ajan bulamıyordu. Bu beceri o aracın kapısıdır.

## Komut (her kutuda AYNI)
```bash
bash /config/.claude/skills/bulgu/scripts/bulgu.sh yaz "<tek cümle başlık>" --kim <AJAN> [--not "<ayrıntı/kanıt>"]
bash /config/.claude/skills/bulgu/scripts/bulgu.sh liste            # bu kutunun defteri
bash /config/.claude/skills/bulgu/scripts/bulgu.sh hal S-12 uygulandi --kim <AJAN> --gerekce "PR #N birleşti"   # hâl geçişi (acik|uygulandi|canli)
bash /config/.claude/skills/bulgu/scripts/bulgu.sh sema             # bu kutunun kayıtları ortak şemayı geçiyor mu
```
- Numara (S-N) defterin çekirdeği verir; elle `id/no/sayi` yazma.
- `--kim` zorunlu: kaydı kimin açtığı (`acan`) sonradan sorulur.
- Başlık Sultan-dilinde tek cümle; kanıt `--not` içinde.
- Tik/onay alanına ajan YAZMAZ (A06) — hâl geçişi `bulgu.sh hal` (0.2.0; `onaylandi` reddedilir), onay yalnız insan.
- Beceri Sx deposunda yaşar (0.2.0'da adopte edildi; öncesinde ortak dizinde öksüzdü — kayıtsız beceri rebuild'de kaybolur).

## Ortak şema (defter çekirdeği `defter_ortak.yeni_kayit`)
`id · no · sayi · baslik · hal · surum · acan · kaynak · acilis · tur · notlar · gecisler` (+ isteğe bağlı `ek`).

## Sınırlar
- Defter kutuya `cloudtop/infra/bulgu-defteri/kur.sh` ile kurulur; kurulu değilse komut **rc=3** "bu kutuda defter yok"
  der ve hiçbir şey yazmaz (dosya uydurmaz). O zaman SERDAR'a yaz.
- Veri kutuda kalır (izolasyon); merkez yalnız salt-okur toplar (`toplac.py`, `filo.py bulgu`).
