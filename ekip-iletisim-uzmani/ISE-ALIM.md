# İŞE ALIM — başka bir kutuda bu rolün mirasçısını açmanın EN KISA yolu

Beş adım, dört komut. Her adım kanıt ister; kanıtsız adım atlanmış sayılır.

## 0 · Ön koşul (tek satır ölçüm)
Bu beceri kutuda kurulu mu? `ls /config/.claude/skills/ekip-iletisim-uzmani/scripts/iletisim-nabiz.sh`
Değilse önce dağıt (filo beceri dağıtıcısı ya da `node sync-skills.mjs --skill ekip-iletisim-uzmani --apply`).

## 1 · İhtiyaç + çakışma ölçümü (30 sn)
```
bash /config/.claude/skills/ekip-iletisim-uzmani/scripts/iletisim-nabiz.sh
```
Kırmızı bulgu **yoksa** ve ekipte zaten iletişimi gözeten biri varsa → işe alma; ölçüm raporla bitir.
Kırmızı **varsa** → devam. Ad tekilliği: `kapimda`/registry'de aynı ad var mı bak (`grep -c "id: <AD>" _agents/handoff/ekip-registry.yaml` → 0 olmalı).

## 2 · Koltuk aç (İSKÂN — kayıt + tmux + kimlik dosyası tek komutta)
```
bash /config/.claude/skills/iskan/scripts/iskan.sh uye-ekle <kutu> <AD> --gorev ekip-iletisim-uzmani --dry-run
bash /config/.claude/skills/iskan/scripts/iskan.sh uye-ekle <kutu> <AD> --gorev ekip-iletisim-uzmani --apply
```
İsteğe bağlı: `--settings-file /config/projects/<kutu>/_agents/<AD>/izin.json` (silme yasağı gibi koltuğa özel izin).
Nexus ailesi (cloudtop-code) için İSKÂN çalışmaz → `/ise-alim` (KÂHYA).

## 3 · Overlay yaz (yalnız yerel bilgi; çekirdek KOPYALANMAZ)
`_agents/<AD>/AGENT.md` içine şu blok — başka bir şey değil:
```
miras: ekip-iletisim-uzmani@0.1.0 sha=<bash scripts/miras-damga.sh çıktısı>
ad: <AD> — <etimoloji tek cümle>
bölge: <ör. ozel/ekip-iletisim>
kanallar: _agents/handoff/ekip-sinyal.log · _agents/durum/ · 0-teslimat/gelen
taskHint: <kutu>:iletisim
iş-notu: Notlarim/notlarim.md ([<AD>] etiketiyle)
başlatıcı: <claude | codex-serit | kapi>   ← model/effort BURADA, çekirdekte değil
```
Kural: çekirdek metni (`ROL-CEKIRDEGI.md`) buraya yapıştırılmaz; yapıştırılırsa ilk çekirdek değişiminde bayatlar.

## 4 · Devir sınavı (kurulunca, aktivasyondan ÖNCE) → `DEVIR-SINAVI.md`
Beş kapı; hepsi yeşil olmadan pane "canlı" ilan edilmez.

## 5 · Aktivasyon + ilk rapor
Pencerede ilk mesaj: *"Rolün: ekip-iletisim-uzmani mirasçısı <AD>. Nabzı al, reise raporla."*
Çıktı: nabız raporu (üç durumlu) + kendi durum dosyası (`durum-yaz.sh --ad <AD> …`).

## Geri alma / emeklilik
Koltuğu kapat: İSKÂN kaydından üye düşer, AGENT.md `durum: emekli` alır; çekirdek ve geçmiş kanıt **silinmez**.

## Bu tarifin sınırı (dürüstçe)
NÂZIR'ın 12 adımlı tam protokolünün (bölge-grant, bağımsız tescilci, cross-container fixture, evergreen) burada olmayan
maddeleri Nexus kanonundaki katmanlı-miras işiyle gelecek (2. parça). Bugün kurulan mirasçı o iş inince
**yeniden kurulmaz**; yalnız `miras:` satırı yeni sürüme çekilir.
