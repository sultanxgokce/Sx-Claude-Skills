#!/usr/bin/env bash
# tarif.mutasyon.sh — Kadro tarif/uzmanlık uçlarının kurallarını (tarif.mjs · sunucu.mjs) tek tek öldürür; sınav KIRMIZI olmalı. Kopyada, pozitif kontrollü.
#   Kopya depo düzeniyle alınır (terminal-onar/ + tarif-kaydi/): tarif.test.mjs gerçek kayda göreli yoldan bakar.
set -u
K="$(cd "$(dirname "$0")" && pwd)"; R="$(cd "$K/../.." && pwd)"; E="$(mktemp -d)"
sil() { python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$1"; }
trap 'sil "$E"' EXIT
gecti=0; dusen=0
kopya() { sil "$E/m"; mkdir -p "$E/m"; cp -r "$R/terminal-onar" "$R/tarif-kaydi" "$E/m/"; }
kos() { (cd "$E/m/terminal-onar/kapi" && timeout 300 node "$1" >/dev/null 2>&1); }
kopya; if kos tarif.test.mjs && kos sunucu.test.mjs; then echo "  ✓ pozitif kontrol: dokunulmamış kopya YEŞİL (tarif.test + sunucu.test)"; else echo "  ✗ pozitif kontrol KIRMIZI — ölçüm geçersiz"; exit 1; fi
dene() {  # dene <ad> <sınav> <dosya> <eski> <yeni>
  kopya
  if ! python3 - "$E/m/terminal-onar/kapi/$3" "$4" "$5" <<'PY'
import sys; p,e,y=sys.argv[1:]; s=open(p,encoding='utf-8').read()
if s.count(e)!=1: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(e,y))
PY
  then echo "  ✗ $1 — mutasyon UYGULANAMADI (desen tutmadı)"; dusen=$((dusen+1)); return; fi
  if kos "$2"; then echo "  ✗ $1 — kural ÖLDÜ ama sınav YEŞİL"; dusen=$((dusen+1)); else echo "  ✓ $1 — kural ölünce sınav KIRMIZI"; gecti=$((gecti+1)); fi
}
T=tarif.mjs
dene "TM1 terimin kaynak yolu sızar" tarif.test.mjs $T "sahip: yazi(t.sahip, 40), durum: yazi(t.durum, 40), katman: yazi(t.katman, 40) };" "sahip: yazi(t.sahip, 40), durum: yazi(t.durum, 40), katman: yazi(t.katman, 40), kaynak: t.kaynak };"
dene "TM2 kapı adımının yolu sızar" tarif.test.mjs $T "return { sira: Number(a && a.sira) || 0, tur, ne_yapar: yazi(a && a.ne_yapar)," "return { sira: Number(a && a.sira) || 0, tur, kapi_yolu: a && a.kapi_yolu, ne_yapar: yazi(a && a.ne_yapar),"
dene "TM3 persona konumu sızar" tarif.test.mjs $T "map((p) => ({ ad: p.ad.slice(0, 40)," "map((p) => ({ ad: p.ad.slice(0, 40), location: p.location,"
dene "TM4 diploma kanıt yolu sızar" tarif.test.mjs $T "el_kitabi_surum: yazi(d.el_kitabi_surum, 40), gecti:" "el_kitabi_surum: yazi(d.el_kitabi_surum, 40), kanit: d.kanit, kume_sha: d.kume_sha, gecti:"
dene "TM5 tarif okunamayınca ölçülemedi yerine BOŞ LİSTE" tarif.test.mjs $T "if (t.olc) olc.tarif = t.olc;" "if (t.olc) tarif = { uzmanliklar: [], vazifeler: [], usuller: [] };"
dene "TM6 kayıt okunamayınca personel BOŞ LİSTE" tarif.test.mjs $T "if (k.olc) olc.personel = k.olc;" "if (k.olc) personel = [];"
dene "TM7 bozuk diploma satırı sessizce atlanır" tarif.test.mjs $T "{ olc.diploma = 'kaynakta okunamayan satır var'; break; }" "continue;"
dene "TM8 beceri kurulu ölçülmez (hep kurulu)" tarif.test.mjs $T "kurulu: b ? fs.existsSync(path.join(beceriDizin, b, 'SKILL.md')) : null" "kurulu: true"
dene "TM9 adımlar sıralanmaz" tarif.test.mjs $T ".map((a) => adimSec(a, beceriDizin)).sort((x, y) => x.sira - y.sira) };" ".map((a) => adimSec(a, beceriDizin)) };"
dene "TM10 yazma yolu açık (POST da 200)" sunucu.test.mjs sunucu.mjs "if (req.method !== 'GET') return json(res, 405, { hata: 'Bu uç yalnız okur (GET).' });" ""
echo "─────────────"; echo "MUTASYON: gecti=$gecti dusen=$dusen"
[ "$dusen" -eq 0 ]
