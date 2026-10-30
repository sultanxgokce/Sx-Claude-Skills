---
name: bulgu
version: 0.6.3
description: "Filonun TEK bulgu komutu — hangi kutuda olursan ol, gördüğün kusuru ya da fikri aynı komutla yaz: bulgu = bug/özellik etiketli GÖREV (Sultan 14 Eki, K1); kutuda defter jetonu varsa merkezî Görev Defteri'ne (Sultan'ın görev ekranı) gider, yoksa eski kutu defterine düşer ve söyler. 'bulgu yaz', 'kusur kaydet', 'deftere düş' dendiğinde kullan."
allowed-tools: Bash
---

# /bulgu — bir kusuru ya da fikri, filonun her yerinde aynı biçimde kaydet

**Niçin (Sultan /goal K2, 12 Eki 2026):** filoda en az dört ayrı bulgu biçimi vardı (aday havuzu · bulgu-havuzu ·
Bulgu Defteri · NÂZIR havuzu) ve kutular deftere ya hiç yazmıyor ya elle yazıp şemayı bozuyordu (AKAR'ın 274
kaydı eski biçimde). Yazma aracı 10 kutuda kuruluydu ama hiçbir ajan bulamıyordu. Bu beceri o aracın kapısıdır.

## 0.3.0 — bulgu = GÖREV (Sultan 14 Ekim 2026, S-17 K1)
Bulgu artık ayrı bir kavram değil: **türü bug ya da özellik olan bir görevdir** ve TEK defter merkezî Görev Defteri'dir
(`cloudtop-defter:8791`, tür `gorev`; Sultan'ın görev ekranı 8794). `bulgu.sh yaz` kutuda defter jetonu (`/config/defter-jeton`)
varsa kaydı ORAYA yazar (kutu jetondan türer, `kaynak_nereden: bulgu komutu`, `--not` kanıt adımı olur, `--etiket bug|ozellik`,
varsayılan bug). Jeton yoksa eski kutu defterine düşer ve bunu söyler. Merkeze ulaşılamazsa kayıt HİÇBİR yere yazılmaz (ikilik olmasın)
ve rc 1 ile söylenir. `liste · hal · sema` eski kutu defteri içindir (taşıma: cloudtop `defter-gecit/gorev/tasima.py`).

## 0.4.0 — düğüm bağı (SERDAR 20 Ekim, F3a)
Açtığın kayıt başka bir kutunun **bekleyen** görevini serbest bırakmak için açılıyorsa `--dugum` ver:
`--dugum <kutu>:gorev_<kimlik>` ya da çıplak `--dugum gorev_<kimlik>` (kutu defterden okunur; görünmüyorsa rc 1, kayıt yazılmaz).
Kayıt defterin `dugum_acar` alanını taşır; biçim ve varlık kapısı **defterdedir** (hedef var mı, açık mı, kutusu tutuyor mu),
reddederse sebep aynen basılır (rc 1); bağ reddinde defterin `neden` ve `yapılacak` satırı da basılır (0.4.1, canlı koşuda bulundu). Defter 1.14.0 ve sonrası bekleyen göreve aynı yazımda "bekliyor ←" notu düşer ve komut
bunu söyler; not yazılamadıysa (ör. bekleyen görevi düzenleme yetkin yok) kayıt yine yazılır ve komut **rc 4** döner
(sebep basılır) — çağıran bağın yarım kaldığını anlar. Düğüm yalnız merkezî defterde yaşar: **jetonsuz kutuda `--dugum` reddedilir** (rc 2), bağ sessizce düşmez.

## 0.5.0 — bulgu HAVUZA yazılır, Sırada'ya düşmez (Sultan D1 21 Ekim, "Eleme turu + bulgu kapısı")
Ölçüm (21 Eki): sırada bekleyen 212 görevin 140'ı ajan bulgusuydu, 151'i bu komuttan doğrudan `acik` açılmıştı; kuyruk
günde ~25 artıyor, kimse çekmiyordu. Artık `yaz` kaydı **`gorev_durumu: havuz`** ile açar: görev ekranındaki Sırada
sayısına girmez, Sırada cümlesinin sonunda "N bulgu havuzda, süzülmeyi bekliyor" diye ayrı sayılır; haftalık süzme
(`/gunluk-plan` retrosu · `gorev.sh durum <id> acik "<gerekçe>"`) onu göreve çevirir ya da iptal eder.
- `--gorev` → eskisi gibi `acik` (Sultan/reis talimatıyla açılan doğrudan İŞ için). **0.6.1:** `--gorev` defterde açılışta Sultan özeti ister; `--ozet "<tek cümle: sebep → ne yapılacak → bitince ne olur>"` verilmezse komut deftere gitmeden rc 2 ile durur (eskiden defterden 400 `ozet_acilista_gerekli` dönüyordu). Havuz (varsayılan) özetsiz açılır.
- `--dugum …` tek başına RED (rc 2): başka kutunun bekleyen işini tutan kayıt havuzda bekleyemez, ama tek istisna `--gorev`dir — `--dugum --gorev` birlikte verilir; sessizce `acik`a çevrilmez.
- Jetonsuz kutuda (eski kutu defteri) havuz yoktur; komut bunu uyarıyla söyler, kayıt eski biçimde düşer.
- Defter 1.18.0 öncesiyse `havuz` 400 ile reddedilir ve komut bunu basar (rc 1); sessizce `acik`a düşmez.
- `kaynak_sinif: ajan` artık gövdede açıkça yazılır (ekranda "X açtı" künyesi defterin türetmesine bağlı kalmasın).

## 0.6.3 — `yaz --oda <oda>` (BÂNİ 30 Ekim, görev …GZF89Z)
Meşveret seansı maddeyi `bulgu.sh yaz … --oda <oda>` ile geçiriyordu; `yaz` bu bayrağı tanımadığından (`bilinmeyen: --oda`, rc 2)
hiçbir madde kaydedilemiyordu. Artık `--oda` alınır ve merkezî deftere `oda` alanı olarak gider (`gorev.sh ac --oda` ile aynı alan).
Jetonsuz kutuda eski defter oda alanı tanımaz: kayıt yazılır, odanın YAZILMADIĞI söylenir (sessiz düşme yok). Sınav OD1–OD4.

## Komut (her kutuda AYNI)
```bash
bash /config/.claude/skills/bulgu/scripts/bulgu.sh yaz "<tek cümle başlık>" --kim <AJAN> [--not "<ayrıntı/kanıt>"] [--etiket bug|ozellik] [--dugum <kutu>:gorev_<kimlik>] [--gorev]
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

## `havuz-cek` — fikir hattı köprüsü (0.6.0 · görev 4FDVE5)
`bulgu.sh havuz-cek` merkezî Görev Defteri'ndeki bulgu kayıtlarını (`kaynak_nereden: bulgu komutu` ya da etiket `bug`/`ozellik`) **eski `bulgu-havuzu.jsonl` biçiminde** stdout'a verir; bileyi ve mucit-t1 bu köprüyle okur — eşleme **tek burada** yaşar. `havuz` durumu `ham` olarak, ilk `[kanıt]` adımı `kanit`/`detay` olarak gelir; `sinif` bilerek boş; göçle taşınan kayıt `eski_no` taşır. Jeton yok · defter ulaşılamadı · yanıt bozuk → **rc 3 ÖLÇÜLEMEDİ** (sessiz boş liste yok). Sınav: `bulgu.test.sh` HC1-HC8.
