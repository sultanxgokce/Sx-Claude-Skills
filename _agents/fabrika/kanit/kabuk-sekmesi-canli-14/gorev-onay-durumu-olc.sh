#!/usr/bin/env bash
# gorev-onay-durumu-olc.sh — görev …GT5BTK defterde 'onay-bekliyor' mu? (gorev.sh bitti --olcum sonucu). Salt okur: defter GET /gorevler.
# rc 0 = durum onay-bekliyor ve son adımda ölçüm kanıtı var; rc 1 = değil; rc 3 = defter okunamadı (ölçülemedi).
set -u
cevap=$(curl -s -m 15 -H "x-defter-jeton: $(cat /config/defter-jeton)" "http://cloudtop-defter:8791/gorevler") || { echo "ÖLÇÜLEMEDİ: defter cevap vermedi"; exit 3; }
printf '%s' "$cevap" | python3 -c '
import sys, json, datetime
try: gs = json.load(sys.stdin)["gorevler"]
except Exception as e: print("ÖLÇÜLEMEDİ: defter çıktısı okunamadı", e); sys.exit(3)
g = [x for x in gs if x.get("id", "").endswith("GT5BTK")]
if not g: print("ÖLÇÜLEMEDİ: görev bulunamadı"); sys.exit(3)
g = g[0]; al = g.get("alanlar") or {}
durum = (al.get("gorev_durumu") or [{}])[-1]
print(datetime.datetime.now().astimezone().isoformat(timespec="seconds"), "görev", g["id"])
print("durum:", durum.get("deger"), "·", durum.get("ts"), "·", durum.get("kim") or durum.get("kutu") or "")
for k in ("kanit_sinifi", "kanit", "atanan"):
    v = al.get(k)
    if v: print(k + ":", str((v[-1] or {}).get("deger"))[:300])
for a in (g.get("adimlar") or [])[-3:]: print("ADIM", a.get("ts"), str(a.get("deger"))[:400])
bitirdi = [str(a.get("deger") or "") for a in (g.get("adimlar") or []) if str(a.get("deger") or "").startswith("[bitirdi]")]
ok = durum.get("deger") == "onay-bekliyor" and any("önce=0 sonra=14" in b for b in bitirdi)   # goz adimlari bitirdi adimindan sonra da yazilir; son adim degil, bitirdi adimi aranir
print("SONUÇ:", "onay-bekliyor + ölçüm kanıtı VAR" if ok else "onay-bekliyor DEĞİL ya da ölçüm adımı yok")
sys.exit(0 if ok else 1)'
