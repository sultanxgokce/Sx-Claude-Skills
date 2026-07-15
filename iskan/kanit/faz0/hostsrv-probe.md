# Probe — hostsrv (K4: host-erişim, cloudtop-container'dan)

**Komut:** `ssh -o BatchMode=yes -o ConnectTimeout=8 hostsrv true; echo "exit=$?"`
**Ortam:** bulut-masaüstü cloudtop-code container, motor-1 (MOTORSERDAR) oturumu, 2026-07-15.
**Çıktı:** `exit=0`

**Durum: yeşil** — bu container'dan `ssh hostsrv` çalışıyor (root@cloudtop-hel, host-seviye erişim var).
K4'ün önceden-kanıtlı yolu (Z1) bu oturumda taze-tekrar doğrulandı.
