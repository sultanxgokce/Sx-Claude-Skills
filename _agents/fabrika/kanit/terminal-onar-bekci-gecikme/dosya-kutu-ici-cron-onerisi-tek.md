# Öteki 17 kutunun cron'ları için öneri (kart cron-dakika-dagitimi · 18 Eki 2026)

Bu PR yalnız code kutusunun crontab'ını (infra/cron/crontab-abc) dağıtır. Öteki kutuların crontab'ları o kutuların
kendi içinde yaşar; uygulama kutu reislerinde. Ölçüm (salt-okur, `docker exec -u abc <kutu> crontab -l`, 18 Eki 15:5x):

| kutu | etkin satır | dakikalık (*) | */N | sleep önekli |
|---|---:|---:|---:|---:|
| akar | 19 | 2 | 5 | 0 |
| mmex | 18 | 1 | 5 | 0 |
| nazir | 11 | 2 | 2 | 0 |
| huma · vekatip | 8 · 8 | 1 · 1 | 2 · 1 | 0 |
| mihenk | 6 | 1 | 2 | 0 |
| huzur · medigate · tellal | 5 · 5 · 5 | 1 · 1 · 1 | 3 · 2 · 3 | 0 |
| nova · sedir · tez | 4 · 4 · 4 | 1 · 1 · 1 | 1 · 2 · 2 | 0 |
| maiset · menzil · revak | 2 · 2 · 2 | 1 · 1 · 2 | 1 · 1 · 0 | 0 |
| enis | 1 | 1 | 0 | 0 |

**Bulgu:** 16 kutunun HER BİRİNDE en az bir dakikalık satır var (terminal-onar bekçisi `* * * * * … bekci.sh`) ve hiçbiri
gecikmeli değil → her dakika başında 16 bekçi + code'un satırları aynı saniyede uyanıyor (host çalışma kuyruğu dakika
başında ort 102, tepe 179; diğer saniyeler 21).

**Öneri (en büyük kazanç, tek yerden):** terminal-onar becerisinin bekçi satırını kuran yer (`kur.sh`) satırı kutuya özgü
sabit gecikmeyle yazsın: `sleep $(( (kutu adının cksum'u) % 50 + 5 )) && …` — böylece 16 bekçi 5-54. saniyelere dağılır,
her kutu her dakika aynı saniyede kalır (tekrarlanabilir). Bu Sx-Claude-Skills'te bir beceri değişikliği → ayrı kart,
kurulumdan sonra kutularda `kur.sh` yeniden koşturulur.

**Kutu reislerine (kendi crontab'ları):** `*/N` satırlarına bu PR'daki kuralı uygulasınlar — dakikalık satır 3-15 sn,
seyrek satır 2-58 sn, `;` DEĞİL `&&` ile (`sleep N && komut`; `;` canlılık envanterinin iş adını ve damgasını bozar —
ölçüldü: 24 işin damgası kaybolurdu). En çok satır: akar (7), mmex (6), huzur/tellal (4).
