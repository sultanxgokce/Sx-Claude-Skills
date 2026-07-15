# Probe — B5: ekip-kur scaffold headless-güvenliği (interaktif-bekleme var mı?)

**Komut:** `grep -n "read -p" /config/projects/_wt/motorserdar-iskan/ekip-kur/scaffold.sh; echo "grep_exit=$?"`
**Çıktı:** (eşleşme yok) `grep_exit=1`

**Durum: yeşil** — `ekip-kur/scaffold.sh` içinde `read -p` (interaktif-stdin-bekleme) deseni YOK.
`grep` eşleşme-bulamadığında exit=1 döner; bu BEKLENEN ve OLUMLU sonuçtur (script headless-çağrıya
hazır, İSKÂN'ın stdin-besleyen sarmalayıcıya FAZ-0'da ihtiyacı yok). B5'in "interaktif-bekleme varsa
İSKÂN stdin-besleyen sarmalayıcı yazar" şartı bu script için tetiklenmedi.

**Sınır:** bu probe yalnız `read -p` desenini tarar — `read` (bayraksız), `select`, veya başka bir
interaktiflik biçimi kapsam-dışıdır (plan-metninin B5 tanımı literal `read -p`). FAZ-6'daki gerçek
kanıt-kapısı ("N saniyede döndü, asılı-kalmadı" timeout-testi) bu FAZ-0 statik-taramanın YERİNE GEÇMEZ,
onu tamamlar.
