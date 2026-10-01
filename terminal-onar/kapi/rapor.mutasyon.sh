#!/usr/bin/env bash
# Rapor yolu mutasyon turu: her korumayı tek tek öldür → rapor.test.mjs KIRMIZI olmalı. Olmazsa koruma ölçülmüyor.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; cd "$D" || exit 9
gecti=0; dusen=0
dene() {
  local ad="$1" eski="$2" yeni="$3"
  cp sunucu.mjs sunucu.mjs.yedek
  ESKI="$eski" YENI="$yeni" python3 -c "
import os;p='sunucu.mjs';s=open(p,encoding='utf-8').read();e=os.environ['ESKI']
open(p,'w',encoding='utf-8').write(s.replace(e,os.environ['YENI'],1))"
  if cmp -s sunucu.mjs sunucu.mjs.yedek; then echo "  ✗ $ad — desen tutmadı"; dusen=$((dusen+1))
  elif node rapor.test.mjs >/dev/null 2>&1; then echo "  ✗ $ad — koruma öldü ama sınav YEŞİL"; dusen=$((dusen+1))
  else echo "  ✓ $ad — sınav KIRMIZI"; gecti=$((gecti+1)); fi
  mv sunucu.mjs.yedek sunucu.mjs
}
dene "M1 giriş kapısı rapora uygulanmıyor" "if (!girisli(req)) {" "if (!girisli(req) && !y.startsWith('/rapor/')) {"
dene "M2 rapor adı kısıtı kalktı" "/^[a-z0-9-]{1,40}\$/.test(ad || '')" "true"
dene "M3 x-kapi başlık şartı kalktı" "if (req.headers['x-kapi'] !== '1') return json(res, 403, { hata: 'Başlık eksik.' });" ""
dene "M4 JSON doğrulaması kalktı" "JSON.parse(g.toString('utf8'));" ""
dene "M5 yalnız veri.json şartı kalktı" "if (req.method === 'PUT' && ic === 'veri.json') {" "if (req.method === 'PUT') {"
dene "M6 1 MB tavanı kalktı" "govde(req, 1024 * 1024)" "govde(req, 64 * 1024 * 1024)"
dene "M7 atomik yazım bozuldu" "fs.renameSync(gecici, yol);" ""
dene "M8 önbellek yasağı kalktı" "'cache-control': 'no-store' });
    return fs.createReadStream(yol).pipe(res);" "'cache-control': 'max-age=3600' });
    return fs.createReadStream(yol).pipe(res);"
# M9 BİLİNÇLİ OLARAK ÖLÇÜLEMEZ: yol dışı kaçış kontrolü (yol.startsWith(kok)) ikinci savunma hattıdır. HTTP ile
# tetiklenemiyor: sunucu yolu `new URL()` ile ayrıştırır ve WHATWG ayrıştırıcısı '..' ile '%2e%2e' parçalarını kod
# kontrole varmadan normalleştirir; '%2f' ise çözülmez (tek parça ad olarak kalır). Mutasyonu bilgi için koşturulur,
# sonucu tura sayılmaz. Kontrol yine de kalmalı: ayrıştırıcı değişirse tek savunma odur.
bilgi() { cp sunucu.mjs sunucu.mjs.yedek; ESKI="$1" python3 -c "
import os;p='sunucu.mjs';s=open(p,encoding='utf-8').read();open(p,'w',encoding='utf-8').write(s.replace(os.environ['ESKI'],'',1))"
  node rapor.test.mjs >/dev/null 2>&1 && echo "  · M9 (bilgi) kaçış kontrolü kalkınca sınav yeşil — HTTP'den erişilemiyor, beklenen" || echo "  · M9 (bilgi) kırmızı"
  mv sunucu.mjs.yedek sunucu.mjs; }
bilgi "if (!yol.startsWith(kok + path.sep)) { res.writeHead(404); return res.end('yok'); }" ""
echo "── $gecti kırmızıya döndü · $dusen yeşil kaldı/uygulanamadı"
[ "$dusen" = 0 ]
