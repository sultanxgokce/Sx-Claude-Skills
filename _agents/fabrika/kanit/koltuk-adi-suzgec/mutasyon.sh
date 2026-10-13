#!/usr/bin/env bash
# Mutasyon (koltuk-adi-suzgec): kuralı boz → koltuk-adi.test.sh KIRMIZI olmalı. Kopyada koşar; pozitif kontrol + desen-yok kapısı.
K="$(cd "$(dirname "$0")/../../../.." && pwd)/terminal-onar"; M="$(mktemp -d)"; trap 'find "$M" -mindepth 1 -delete; rmdir "$M"' EXIT; r=0
kopya(){ find "$M" -mindepth 1 -delete; cp -r "$K/scripts" "$K/kapi" "$M/"; }
# sınav türüne göre koşucu: .mjs → node --test (bash ile koşmak HER ZAMAN düşer = sahte kırmızı)
kos(){ case "$1" in *.mjs) (cd "$M/$(dirname "$1")" && node --test "$(basename "$1")") >/dev/null 2>&1 ;; *) bash "$M/$1" >/dev/null 2>&1 ;; esac; }
kopya; if kos kapi/sunucu.test.mjs; then echo "  ✓ pozitif kontrol (sunucu) YEŞİL"; else echo "  ✗ pozitif kontrol (sunucu) KIRMIZI"; r=1; fi
kopya; if bash "$M/kapi/koltuk-xss.tarayici.sh" >/dev/null 2>&1; then echo "  ✓ pozitif kontrol (tarayıcı) YEŞİL"; else echo "  ✗ pozitif kontrol (tarayıcı) KIRMIZI"; r=1; fi
kopya; if bash "$M/scripts/koltuk-adi.test.sh" >/dev/null 2>&1; then echo "  ✓ pozitif kontrol YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI"; r=1; fi
mut(){ kopya; python3 -c 'import sys;p,a,b=sys.argv[1:4];s=open(p).read()
if a not in s: sys.exit(1)
open(p,"w").write(s.replace(a,b,1))' "$M/$1" "$2" "$3" || { echo "  ✗ $4 → desen yok"; r=1; return; }
  if kos "${5:-scripts/koltuk-adi.test.sh}"; then echo "  ✗ $4 → YEŞİL kaldı"; r=1; else echo "  ✓ $4 → kırmızı"; fi; }
mut kapi/sunucu.mjs 'const KOLTUK_AD_DESEN = /^(?![\s$@%=])(?!.*\s$)[^\x00-\x1f\x7f:.]{1,200}$/u;' 'const KOLTUK_AD_DESEN = /^[A-Za-z0-9_-]{1,64}$/;' "KA1 kapı eski desene döndü ('/' düşer)"
mut scripts/koltuk-adi.sh "[[:space:]]|'\$'|'@'|'%'|'=') return 1" "[[:space:]]|'@'|'%'|'=') return 1" "KA2 kabuk '\$1' önekine izin verdi"
mut kapi/sunucu.mjs '([^/]{1,1800})(\/ac)?' '([^/]{1,200})(\/ac)?' "KA6 tekil uç sınırı yine ÇÖZÜMDEN ÖNCE (200'lük '/'lı ad 404)" kapi/sunucu.test.mjs
mut scripts/koltuk-adi.sh "case \"\${1: -1}\" in [[:space:]]) return 1 ;; esac" ":" "KA7 kabuk sondaki boşluğa izin verdi (iki dil ayrışır)"
mut kapi/sunucu.mjs 'const KOLTUK_AD_DESEN = /^(?![\s$@%=])(?!.*\s$)[^\x00-\x1f\x7f:.]{1,200}$/u;' 'const KOLTUK_AD_DESEN = /^(?![\s$@%=])(?!.*\s$)[^\x00-\x1f\x7f:]{1,200}$/u;' "KA3 kapı '.'ya izin verdi (iki dil ayrıştı)"
mut kapi/genel/uygulama.js '<option value="${kac(k.ad)}"' '<option value="${k.ad}"' "KA4 seçici option değeri kaçışsız (x\"y adı kırılır)" kapi/koltuk-xss.tarayici.sh
mut kapi/genel/uygulama.js "</option>\`).join('');" "</option>\`).join('').replace(/&lt;img/g, '<img');" "KA5 ad metni HTML olarak yorumlanıyor (<img> doğar)" kapi/koltuk-xss.tarayici.sh
mut kapi/sunucu.mjs '{1,200}$/u;' '{1,200}$/;' "KA8 kapı UTF-16 birimi sayıyor (emoji adında iki dil ayrışır)"
mut scripts/koltuk-adi.sh '  local LC_ALL=C.UTF-8' '  :' "KA9 kabuk çağıranın yerel ayarıyla sayıyor (C'de bayt)"
exit $r
