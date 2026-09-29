#!/usr/bin/env bash
# canli-prova.sh — araç GERÇEK ölçerle (ağ) çalışıyor mu? Kayıt GEÇİCİ dizine yazılır; gerçek kayda dokunulmaz.
# Ölçülen: kapı arkasındaki üç gerçek sayfa kayda giriyor mu · olmayan adres reddediliyor mu · dogrula yeşil mi.
# rc: 0 hepsi beklendiği gibi · 1 değil · 3 ölçülemedi (ağ yok)
set -uo pipefail
KOK="$(git rev-parse --show-toplevel)"; A="$KOK/canli-sayfa/scripts/canli-sayfa.sh"
T="$(mktemp -d /tmp/canli-sayfa-prova.XXXXXX)" || exit 3
trap 'find "$T" -delete' EXIT
export CANLI_SAYFA_DIZIN="$T/kayit"
curl -s -o /dev/null -m 10 https://www.cloudflare.com/ || { echo "ÖLÇÜLEMEDİ · bu kutudan dışarı çıkılamıyor"; exit 3; }
k=0
dene() {  # dene <beklenen rc> <başlık> <araç argümanları…>
  local b="$1" t="$2"; shift 2
  c="$(bash "$A" "$@" 2>&1)"; r=$?
  if [ "$r" -eq "$b" ]; then echo "✓ $t (rc $r)"; else echo "✗ $t (beklenen rc $b · gelen $r)"; k=1; fi
  printf '%s\n' "$c" | head -3 | sed 's/^/     /'
}
dene 0 "bulgu sayfası kayda girdi" ekle --adres https://bulgu.mmepanel.com --ad "Bulgu Defteri" --ne "Kutulardan gelen bulguların tek listesi" --kutu merkez --ekleyen SERDAR
dene 0 "fikir sayfası kayda girdi" ekle --adres https://fikir.mmepanel.com --ad "Fikir Defteri" --ne "Yeni iş fikirlerinin tutulduğu defter" --kutu mihenk --ekleyen SERDAR
dene 0 "kokpit kayda girdi" ekle --adres https://kokpit.mmepanel.com --ad "Kokpit" --ne "Bütün kutuların hâli ve seni bekleyen işler" --kutu merkez --ekleyen SERDAR
dene 3 "olmayan adres reddedildi" ekle --adres https://boyle-bir-sayfa-yok-7f3a.mmepanel.com --ad "Olmayan Sayfa" --ne "Hiç kurulmamış bir sayfa" --kutu merkez --ekleyen SERDAR
dene 4 "kapısız açılan sayfa onaysız reddedildi" ekle --adres https://www.cloudflare.com --ad "Kapısız Sayfa" --ne "Herkese açık bir sayfa örneği" --kutu merkez --ekleyen SERDAR
for f in bulgu fikir kokpit; do
  g="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["giris"])' "$CANLI_SAYFA_DIZIN/$f.mmepanel.com.json" 2>/dev/null)"
  if [ "$g" = kapali ]; then echo "✓ $f: giriş kapalı ölçüldü"; else echo "✗ $f: giriş '$g'"; k=1; fi
done
dene 0 "liste üç sayfayı gösteriyor" liste
[ "$(bash "$A" liste --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["sayfalar"]))')" = 3 ] && echo "✓ menü biçiminde 3 sayfa" || { echo "✗ menü biçiminde sayı tutmuyor"; k=1; }
dene 0 "dogrula: üçü de açılıyor, kapıları yerinde" dogrula
exit "$k"
