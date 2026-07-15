# Probe — nexus-vps (K4: SERDAR/nexus-vps'in host-erişimi — açık-soru deterministik-kapanır)

**Komut:** `ssh -o BatchMode=yes -o ConnectTimeout=8 nexus-vps true; echo "exit=$?"`
**Ortam:** bulut-masaüstü cloudtop-code container, motor-1 (MOTORSERDAR) oturumu, 2026-07-15.
**Çıktı:** `exit=0`

**Durum: yeşil** — bu container'dan `ssh nexus-vps` de çalışıyor. K4'ün plan-metnindeki açık-soru
("SERDAR@nexus-vps'in host-erişimi DOĞRULANMADI") bu FAZ-0 probe'uyla deterministik kapandı: cevap
**erişim VAR** (en azından bu cloudtop-code container'ından). Sonuç plan-K4'ün öngördüğü ilkeyi doğrular:
İSKÂN SERDAR'a SPOF-bağımlı değildir — hostsrv-anahtarını taşıyan HERHANGİ BİR cloudtop-container-lead
(bu durumda MOTORSERDAR de dahil) host-işini icra edebilir.

**Not:** bu probe yalnız SSH-bağlanabilirliği doğrular; nexus-vps üzerinden hostsrv'e zincirleme-erişim
(nested-hop) veya nexus-vps'in KENDİ host-yetkisi ayrı bir sorudur ve bu FAZ-0'ın kapsamı dışındadır
(salt-okur probe, host'a yazma-dokunuşu yok).
