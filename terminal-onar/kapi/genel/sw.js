// Yalnız kabuk önbelleği; /api ve /tty ASLA önbelleğe girmez (canlı veri).
//
// 🔴 TABAN YOLU VE ÖNBELLEK AYRIMI (2026-09-27, merkez sayfaya geçişte bulundu):
//    Merkez sayfa altında BÜTÜN kutular aynı kaynağı (origin) paylaşıyor —
//    terminal.mmepanel.com/sedir ve /akar aynı tarayıcı kaynağıdır. Önbellek adı
//    kutuya çivili olsaydı ("sedir-kabuk") ikinci kutu birincinin kabuğunu görürdü;
//    KABUK yolları kök kalsaydı her kutu ötekinin dosyasını önbelleğe alırdı.
//    Taban, dosyanın KENDİ sunulduğu yoldan türetilir — tahmin yok, beyan yok.
const TABAN = self.location.pathname.replace(/\/sw\.js$/, '');   // "" ya da "/sedir"
const KAP = 'kabuk' + (TABAN || '-kok') + '-v3';
const KABUK = ['/zanaat.css', '/uygulama.js', '/ikon-192.png', '/archivo-400.ttf', '/archivo-600.ttf'].map((y) => TABAN + y);
self.addEventListener('install', (e) => { e.waitUntil(caches.open(KAP).then((c) => c.addAll(KABUK)).catch(() => {})); self.skipWaiting(); });
// Eski sürümleri temizlerken YALNIZ kendi tabanının kaplarına dokunur: başka kutunun
// önbelleğini silmek, onun çevrimdışı kabuğunu sessizce bozmak olurdu.
self.addEventListener('activate', (e) => { e.waitUntil(caches.keys().then((k) => Promise.all(
  k.filter((x) => x !== KAP && x.startsWith('kabuk' + (TABAN || '-kok'))).map((x) => caches.delete(x))))); self.clients.claim(); });
self.addEventListener('fetch', (e) => {
  const u = new URL(e.request.url);
  const p = u.pathname.startsWith(TABAN) ? u.pathname.slice(TABAN.length) : u.pathname;
  if (e.request.method !== 'GET' || u.origin !== location.origin || p.startsWith('/api') || p.startsWith('/tty') || p.startsWith('/giris')) return;
  e.respondWith(fetch(e.request).then((r) => { if (r.ok && KABUK.includes(u.pathname)) caches.open(KAP).then((c) => c.put(e.request, r.clone())); return r; })
    .catch(() => caches.match(e.request).then((m) => m || new Response('Bağlantı yok', { status: 503 }))));
});
