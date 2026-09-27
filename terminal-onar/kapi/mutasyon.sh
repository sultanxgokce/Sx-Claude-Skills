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
dene "M8 WS upgrade taban denetimi" sunucu.mjs "s=s.replace(\"!req.url.startsWith(T('/tty'))\",\"!req.url.startsWith('/tty')\")"
dene "M9 WS giris denetimi" sunucu.mjs "s=s.replace('if (!girisli(req) || !req.url.startsWith(T(\'/tty\')))','if (false)')"
echo "─────────────"
echo "MUTASYON: gecti=$gecti dusen=$dusen"
[ "$dusen" = 0 ] || exit 1
