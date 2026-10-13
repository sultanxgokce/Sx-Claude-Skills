#!/usr/bin/env bash
# Mutasyon turu: her kapıyı tek tek öldür, sınav KIRMIZI olmalı. Olmazsa kapı YOKTUR.
# Betik kanıtla aynı yerde yaşar — yeniden üretilemeyen kanıt bir beyandır.
set -u
D="$(cd "$(dirname "$0")" && pwd)"
cd "$D" || exit 9
gecti=0; dusen=0
dene() {
  local ad="$1" dosya="$2" kod="$3"
  cp "$dosya" "$dosya.yedek"
  python3 - "$dosya" <<PY
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
$kod
open(p,'w',encoding='utf-8').write(s)
PY
  if ! cmp -s "$dosya" "$dosya.yedek"; then
    if node sunucu.test.mjs >/dev/null 2>&1; then
      echo "  ✗ $ad — kapı ÖLDÜ ama sınav YEŞİL (kapı yok)"; dusen=$((dusen+1))
    else
      echo "  ✓ $ad — kapı ölünce sınav KIRMIZI"; gecti=$((gecti+1))
    fi
  else
    echo "  ✗ $ad — mutasyon UYGULANAMADI (desen tutmadı)"; dusen=$((dusen+1))
  fi
  mv "$dosya.yedek" "$dosya"
}

dene "M1 taban dışı reddi" sunucu.mjs "s=s.replace(\"else { res.writeHead(404); return res.end('yok'); }   // taban dışı istek bu kapıya ait değil\",'')"
dene "M2 taban sonu yönlendirme" sunucu.mjs "s=s.replace(\"if (y === TABAN) { res.writeHead(302, { location: TABAN + '/' }); return res.end(); }\",'')"
dene "M3 çerez kapsamı" sunucu.mjs "s=s.replace('Path=\${TABAN || \\'/\\'}','Path=/')"
dene "M4 giriş yönlendirmesi tabanlı" sunucu.mjs "s=s.replace(\"location: T('/giris')\",\"location: '/giris'\")"
dene "M5 sayfaya taban enjeksiyonu" sunucu.mjs "s=s.replace('window.__TABAN=\${JSON.stringify(TABAN)};','')"
dene "M6 html varlık yolları" sunucu.mjs "s=s.replace('if (TABAN) h = h.replace(','if (false) h = h.replace(')"
dene "M7 PWA kimliği kutu başına" sunucu.mjs "s=s.replace(\"start_url: TABAN + '/', scope: TABAN + '/'\",\"start_url: '/', scope: '/'\")"
# ── Tarayıcı akışı mutantları (28-29 Eylül · bağımsız göz, CİDDİ)
dene "M10 giris sayfasi tabani tasir" sunucu.mjs "s=s.replace(\"GET') return dosyaTabanli(res, 'giris\",\"GET') return dosya(res, 'giris\")"
dene "M11 parola vekilligi" sunucu.mjs "s=s.replace('process.env[SIFRE_ANAHTAR] ||','process.env[SIFRE_ANAHTAR] || process.env.SEDIR__TERMINAL_SIFRE ||')"
dene "M12 onbellek siniri" genel/sw.js "s=s.replace('(TABAN || \'-kok\') + \'-v\';','(TABAN || \'-kok\');')"
dene "M13 gorunen ad kutudan turer" genel/giris.html "s=s.replace('<h1>{{KUTU}}</h1>','<h1>Sedir</h1>')"
dene "M8 WS upgrade taban denetimi" sunucu.mjs "s=s.replace('_yol === _tty ||','true ||')"
dene "M9 WS giris denetimi" sunucu.mjs "s=s.replace('!girisli(req) ||','false ||')"
# ── Pano köprüsü mutantları (2.3.0 · 13 Ekim) — her biri PN sınavını kırmızıya çevirmeli
dene "M14 pano köprüsü gömülür" sunucu.mjs "s=s.replace(\"h = h.includes('</body>') ? h.replace('</body>', () => ek + '</body>') : h + ek;\",'')"
dene "M15 ttyd'den düz gövde istenir" sunucu.mjs "s=s.replace(\"if (PANO_ACIK && req.method === 'GET') delete bas['accept-encoding'];\",'')"
dene "M16 content-length yeniden hesaplanır" sunucu.mjs "s=s.replace(\"b2['content-length'] = String(govde.length);\",\"b2['content-length'] = String(govde.length - 10);\")"
dene "M17 sıkıştırılmış ttyd cevabına dokunulmaz" sunucu.mjs "s=s.replace(\" || (kodlama && kodlama !== 'identity')) {\",\") {\")"
dene "M18 kapatma anahtarı (KAPI_PANO=0)" sunucu.mjs "s=s.replace(\"const PANO_ACIK = process.env.KAPI_PANO !== '0';\",\"const PANO_ACIK = true;\")"
dene "M19 köprü tabanı taşır" sunucu.mjs "s=s.replace('const ek = \`<script>window.__TABAN=\${JSON.stringify(TABAN)};','const ek = \`<script>window.__TABAN=\"\";')"
# ── Koltuk aç mutantları (2.4.0 · 13 Ekim)
dene "M20 rc→HTTP eşlemesi (409/202/502)" sunucu.mjs "s=s.replace(\"const kod = r.kod === 0 ? 200 : r.kod === 3 ? 202 : r.kod === 4 ? 409 : 502;\",\"const kod = 200;\")"
dene "M21 --eski bayrağı betiğe geçer" sunucu.mjs "s=s.replace(\"if (g.eski === true) arg.push('--eski');\",'')"
dene "M22 bozuk koltuk adı yola girmez" sunucu.mjs "s=s.replace(\"/^\\\\/api\\\\/koltuk\\\\/([A-Za-z0-9_-]{1,64})(\\\\/ac)?$/\",\"/^\\\\/api\\\\/koltuk\\\\/([^/]{1,64})(\\\\/ac)?$/\")"
echo "─────────────"
echo "MUTASYON: gecti=$gecti dusen=$dusen"
[ "$dusen" = 0 ] || exit 1
