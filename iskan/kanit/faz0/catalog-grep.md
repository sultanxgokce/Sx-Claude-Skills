# Probe — K5: catalog.json id-benzersizliği (taze grep-kanıtı, sabit-sayı ezberi değil)

**Komut:** `cd /config/projects/_wt/motorserdar-iskan && grep -c iskan catalog.json; echo "exit=$?"`
**Çıktı:** `0` eşleşme, `exit=1` (grep 0-eşleşmede exit=1 döner — beklenen davranış)

**Durum: yeşil** — `catalog.json`'da bugün (2026-07-15, origin/main c7b6618) hiçbir `iskan` girdisi YOK.
K5'in "id-benzersizliği taze `grep -c` kanıt-kapısıyla doğrulanır, sabit-sayı ezberiyle değil" ilkesi bu
probe ile karşılanıyor: `iskan` adı ÇAKIŞMASIZ, FAZ-0'da catalog.json'a henüz kayıt YAPILMADI (bu FAZ'ın
kapsamı değil — `sync-skills.mjs`/catalog-kaydı owner-domain, ayrı adım, muhtemelen yayım-PR'ında).
