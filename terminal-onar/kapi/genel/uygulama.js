// Yerel saklama anahtari da kutudan turer — ayni tarayicida iki kutu acilirsa
// sabit ad ikisinin gorunum tercihini BIRBIRINE karistirirdi (bagimsiz goz tur 2).
const GORUNUM_ANAHTAR = ((window.__KUTU || 'kutu') + '-gorunum');
// ── TABAN YOLU ───────────────────────────────────────────────────────────────
// Sayfa kendi tabanını sunucudan öğrenir (index.html'e enjekte edilir). Merkez sayfa
// kutuları yol ile ayırdığı için (/sedir/ · /akar/) buradaki her çağrı o yolun altında
// kalmalı; kök yola giden bir istek MERKEZE düşer ve kutuya hiç ulaşmaz.
// Boşsa bugünkü kök davranışı aynen sürer.
const TABAN = (window.__TABAN || '');
const Y = (yol) => TABAN + yol;
// Sedir kapısı — telefon ekranı davranışı
const $ = (id) => document.getElementById(id);
const mesaj = $('mesaj'), ekler = $('ekler'), bildirimEl = $('bildirim');
const PARCA_AD = { ana_tmux: 'Konuşma odası', ana_claude: 'Konuşma (Claude)', web_terminal: 'Web terminali', kurtarici: 'Kurtarıcı ajan', bekci: 'Bekçi' };

async function api(yol, govde) {
  const r = await fetch(yol, govde === undefined ? { cache: 'no-store' } :
    { method: 'POST', headers: { 'content-type': 'application/json', 'x-kapi': '1' }, body: JSON.stringify(govde) });
  if (r.status === 401) { location.replace(Y('/giris')); throw new Error('oturum'); }
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.hata || 'İstek başarısız.');
  return j;
}
let bildirimZaman;
function bildir(metin) { bildirimEl.textContent = metin; bildirimEl.classList.add('acik'); clearTimeout(bildirimZaman); bildirimZaman = setTimeout(() => bildirimEl.classList.remove('acik'), 2600); }

// klavye açılınca görünür alanı izle (iOS 100dvh klavyeyi saymaz)
const vv = window.visualViewport;
function boyut() { document.documentElement.style.setProperty('--gorunur', (vv ? vv.height : innerHeight) + 'px'); scrollTo(0, 0); }
vv?.addEventListener('resize', boyut); addEventListener('resize', boyut); boyut();
// iOS klavye açılırken sayfayı yukarı iter (görünür alan kayar) → geri çek; odak yazma kutusuna gelince de.
vv?.addEventListener('scroll', () => { if (vv.offsetTop) scrollTo(0, 0); });
mesaj.addEventListener('focus', () => setTimeout(boyut, 250));
mesaj.addEventListener('blur', () => setTimeout(boyut, 250));

// mesaj kutusu kendini büyütür
function buyut() { mesaj.style.height = 'auto'; mesaj.style.height = Math.min(mesaj.scrollHeight + 2, innerHeight * 0.4) + 'px'; }
mesaj.addEventListener('input', buyut);

// ---- fotoğraflar: telefonda küçültülür (en uzun kenar 2000px, JPEG), sonra yüklenir
const bekleyen = []; // {el, yol, soz}
async function kucult(dosya) {
  try {
    const bmp = await createImageBitmap(dosya, { imageOrientation: 'from-image' });
    const o = Math.min(1, 2000 / Math.max(bmp.width, bmp.height));
    const c = document.createElement('canvas'); c.width = Math.round(bmp.width * o); c.height = Math.round(bmp.height * o);
    c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
    return await new Promise((ok) => c.toBlob(ok, 'image/jpeg', 0.86));
  } catch { return dosya; }
}
$('foto').addEventListener('click', () => $('dosya').click());
$('dosya').addEventListener('change', (e) => { [...e.target.files].forEach(ekle); e.target.value = ''; });
function ekle(dosya) {
  const el = document.createElement('div'); el.className = 'ek'; el.dataset.d = 'yukleniyor';
  const img = document.createElement('img'); img.alt = ''; img.src = URL.createObjectURL(dosya);
  const x = document.createElement('button'); x.type = 'button'; x.textContent = '×'; x.setAttribute('aria-label', 'Fotoğrafı çıkar');
  el.append(img, x); ekler.append(el);
  const kayit = { el, yol: null };
  kayit.soz = (async () => {
    const blob = await kucult(dosya);
    const r = await fetch(Y('/api/resim'), { method: 'POST', headers: { 'x-kapi': '1', 'content-type': blob.type || 'application/octet-stream' }, body: blob });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.hata || 'Fotoğraf yüklenemedi.');
    kayit.yol = j.yol; el.dataset.d = 'hazir';
  })().catch((h) => { el.dataset.d = 'hata'; bildir(h.message); });
  x.addEventListener('click', () => { el.remove(); bekleyen.splice(bekleyen.indexOf(kayit), 1); });
  bekleyen.push(kayit);
}

// ---- gönder
let gidiyor = false;
async function gonder() {
  if (gidiyor) return;
  const metin = mesaj.value.trim();
  if (!metin && !bekleyen.length) { mesaj.focus(); return; }
  gidiyor = true; $('gonder').disabled = true;
  try {
    await Promise.allSettled(bekleyen.map((k) => k.soz));
    const yollar = bekleyen.filter((k) => k.yol).map((k) => k.yol);
    if (bekleyen.length && yollar.length < bekleyen.length) throw new Error('Bir fotoğraf yüklenemedi. Çıkarıp tekrar dene.');
    await api(Y('/api/gonder'), { metin: [...yollar, metin].filter(Boolean).join(' ') });
    mesaj.value = ''; buyut(); ekler.replaceChildren(); bekleyen.length = 0;
    if (dokunmatik) mesaj.blur();
    ekranH = ''; setTimeout(ekranCek, 300);
  } catch (h) { if (h.message !== 'oturum') bildir(h.message); }
  gidiyor = false; $('gonder').disabled = false;
}
$('yaz').addEventListener('submit', (e) => { e.preventDefault(); gonder(); });
// masaüstü: Enter gönderir, Shift+Enter yeni satır. Telefonda Enter yeni satır; gönder düğmesi gönderir.
const dokunmatik = matchMedia('(pointer: coarse)').matches;
mesaj.addEventListener('keydown', (e) => { if (!dokunmatik && e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); gonder(); } });

// ---- hızlı tuşlar
document.querySelectorAll('[data-tus]').forEach((b) => b.addEventListener('click', async () => {
  try { await api(Y('/api/tus'), { tus: b.dataset.tus }); ekranH = ''; setTimeout(ekranCek, 250); } catch (h) { if (h.message !== 'oturum') bildir(h.message); }
}));

// ---- sesle yazma (tarayıcının Türkçe dinleyicisi). iPhone'da "sürekli dinleme" sonuç vermeyebildiği
//      için kısa oturumlarla dinlenir, sen durdurana kadar kendiliğinden yeniden başlar.
//      iPhone çoğu zaman sonucu "kesin" diye işaretlemeden oturumu bitirir → her oturumun SON hâli
//      (kesin + geçici) oturum bitince metne işlenir; yoksa yeniden başlarken söylenen silinir.
const Tanima = window.SpeechRecognition || window.webkitSpeechRecognition;
let tanima = null, dinle = false, onceki = '', oturumMetni = '', bosBitis = 0;
function mikGoster(a) { $('mik').classList.toggle('dinliyor', a); $('mik').setAttribute('aria-pressed', String(a)); }
function dinlemeBaslat() {
  const t = new Tanima(); tanima = t; oturumMetni = '';
  t.lang = 'tr-TR'; t.interimResults = true; t.continuous = false;
  const basla = Date.now();
  t.onresult = (e) => {
    let m = '';
    for (let i = 0; i < e.results.length; i++) m += e.results[i][0].transcript;
    oturumMetni = m.trim();
    mesaj.value = onceki + oturumMetni; buyut();
  };
  t.onerror = (e) => {
    const m = { 'not-allowed': 'Mikrofon izni yok (Ayarlar → Safari → Mikrofon).', 'service-not-allowed': 'Bu ekranda sesle yazma kapalı — klavyedeki mikrofonu kullan.',
      'network': 'Dinleme servisine ulaşılamadı.', 'audio-capture': 'Mikrofon bulunamadı.', 'language-not-supported': 'Türkçe dinleme bu cihazda yok — klavyedeki mikrofonu kullan.' }[e.error];
    if (m) { dinle = false; bildir(m); } else if (e.error !== 'no-speech' && e.error !== 'aborted') bildir('Dinleme hatası: ' + e.error);
  };
  t.onend = () => {
    if (oturumMetni) { onceki += oturumMetni + ' '; mesaj.value = onceki; buyut(); bosBitis = 0; }
    else if (Date.now() - basla < 1500) bosBitis++;   // hemen bitip duruyorsa (iPhone izin vermiyor) döngüye girme
    oturumMetni = ''; if (tanima === t) tanima = null;
    if (dinle && bosBitis < 3) { try { dinlemeBaslat(); return; } catch {} }
    if (dinle && bosBitis >= 3) bildir('Dinleme sürmüyor — klavyedeki mikrofonu kullan.');
    dinle = false; mikGoster(false);
  };
  t.start();
}
$('mik').addEventListener('click', () => {
  if (!Tanima) { bildir('Bu tarayıcı dinleyemiyor — klavyedeki mikrofon tuşunu kullan.'); mesaj.focus(); return; }
  if (dinle) { dinle = false; tanima?.stop(); return; }
  dinle = true; bosBitis = 0; onceki = mesaj.value ? mesaj.value.replace(/\s*$/, ' ') : '';
  mikGoster(true); bildir('Dinliyorum… bitince mikrofona tekrar bas.');
  try { dinlemeBaslat(); } catch (h) { dinle = false; mikGoster(false); bildir('Dinleme başlatılamadı.'); }
});

// ---- nabız
const nabiz = $('nabiz'), durumYazi = $('durumYazi');
let sonDurum = null;
async function olc() {
  try {
    const [d, g] = await Promise.all([api(Y('/api/durum')), api(Y('/api/gunluk'))]);
    sonDurum = d;
    const calisiyor = (g.merdiven || '').startsWith('koşuyor');
    nabiz.dataset.d = calisiyor ? 'calisiyor' : d.saglam ? 'iyi' : 'kotu';
    durumYazi.textContent = calisiyor ? 'onarılıyor…' : d.saglam ? 'canlı' : 'bozuk — Onar';
    if ($('onarim').open) ciz(d, g);
  } catch (h) { if (h.message !== 'oturum') { nabiz.dataset.d = 'kotu'; durumYazi.textContent = 'bağlantı yok'; } }
}
function ciz(d, g) {
  $('parcalar').replaceChildren(...Object.entries(PARCA_AD).map(([k, ad]) => {
    const li = document.createElement('li'); const s = document.createElement('span'); s.textContent = ad;
    const r = document.createElement('span'); r.className = 'rozet'; const v = d[k] || '?';
    r.dataset.d = v === 'ok' ? 'ok' : 'yok'; r.textContent = v === 'ok' ? 'sağlam' : 'bozuk';
    li.append(s, r); return li;
  }));
  $('gunluk').textContent = (g?.satir || []).join('\n');
  const calisiyor = (g?.merdiven || '').startsWith('koşuyor');
  $('onarBasla').disabled = calisiyor;
  $('onarBasla').textContent = calisiyor ? 'Onarılıyor…' : 'Onarımı başlat';
}
$('onarAc').addEventListener('click', async () => { $('onarim').showModal(); if (sonDurum) ciz(sonDurum, null); olc(); });
$('onarKapat').addEventListener('click', () => $('onarim').close());
$('onarBasla').addEventListener('click', async () => {
  try { await api(Y('/api/onar'), {}); bildir('Onarım başladı. Sonucu WhatsApp’tan da bildireceğim.'); setTimeout(olc, 1500); } catch (h) { bildir(h.message); }
});
let surum = null;
async function surumBak() {
  try { const j = await api(Y('/api/surum')); if (surum && j.surum !== surum) location.reload(); surum = j.surum; } catch {}
}
surumBak(); setInterval(surumBak, 20000);
olc(); setInterval(olc, 15000);
document.addEventListener('visibilitychange', () => { if (!document.hidden) { olc(); surumBak(); } });

if ('serviceWorker' in navigator) navigator.serviceWorker.register(Y('/sw.js'), { scope: (TABAN || '') + '/' }).catch(() => {});

// ---- OKUMA GÖRÜNÜMÜ: konuşma metin olarak gelir; tmux'a bağlanmadığı için Mac'teki ekran bozulmaz
const okuma = $('okuma'), enAlta = $('enAlta'), kaydir = $('kaydir');
const RENK16 = ['#2b2621', '#e77f66', '#86c08a', '#e2b34f', '#7fa7d9', '#c792c9', '#6fc2c0', '#d9d1c3',
  '#6f665a', '#ff9a82', '#a6dba9', '#f2cd72', '#a3c4f0', '#dfb0e0', '#93dcda', '#f5efe6'];
function renk256(n) {
  if (n < 16) return RENK16[n];
  if (n >= 232) { const v = 8 + (n - 232) * 10; return `rgb(${v},${v},${v})`; }
  n -= 16; const k = [0, 95, 135, 175, 215, 255];
  return `rgb(${k[Math.floor(n / 36)]},${k[Math.floor(n / 6) % 6]},${k[n % 6]})`;
}
// tut: satırdan satıra taşınan renk durumu (ekran satır satır çizildiği için)
function ansiHtml(metin, tut = { d: {} }) {
  const kacis = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  let d = tut.d, cikti = '';
  for (const parca of metin.split(/(\x1b\[[0-9;:]*m)/)) {
    const m = /^\x1b\[([0-9;:]*)m$/.exec(parca);
    if (!m) {
      if (!parca) continue;
      const sinif = [d.b && 'b', d.d && 'd', d.i && 'i', d.u && 'u'].filter(Boolean).join(' ');
      let fg = d.fg, bg = d.bg; if (d.ters) [fg, bg] = [bg || '#15120e', fg || '#d9d1c3'];
      const stil = (fg ? `color:${fg};` : '') + (bg ? `background:${bg};` : '');
      const t = kacis(parca.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, ''));
      cikti += sinif || stil ? `<span${sinif ? ` class="${sinif}"` : ''}${stil ? ` style="${stil}"` : ''}>${t}</span>` : t;
      continue;
    }
    const k = (m[1] || '0').split(/[;:]/).map(Number);
    for (let i = 0; i < k.length; i++) {
      const c = k[i];
      if (c === 0) d = {};
      else if (c === 1) d.b = 1; else if (c === 2) d.d = 1; else if (c === 3) d.i = 1; else if (c === 4) d.u = 1; else if (c === 7) d.ters = 1;
      else if (c === 22) { d.b = 0; d.d = 0; } else if (c === 23) d.i = 0; else if (c === 24) d.u = 0; else if (c === 27) d.ters = 0;
      else if (c >= 30 && c <= 37) d.fg = RENK16[c - 30]; else if (c >= 90 && c <= 97) d.fg = RENK16[c - 82];
      else if (c >= 40 && c <= 47) d.bg = RENK16[c - 40]; else if (c >= 100 && c <= 107) d.bg = RENK16[c - 92];
      else if (c === 39) d.fg = null; else if (c === 49) d.bg = null;
      else if ((c === 38 || c === 48) && k[i + 1] === 5) { d[c === 38 ? 'fg' : 'bg'] = renk256(k[i + 2]); i += 2; }
      else if ((c === 38 || c === 48) && k[i + 1] === 2) { d[c === 38 ? 'fg' : 'bg'] = `rgb(${k[i + 2]},${k[i + 3]},${k[i + 4]})`; i += 4; }
    }
  }
  tut.d = d;
  return cikti;
}
const altta = () => kaydir.scrollHeight - kaydir.scrollTop - kaydir.clientHeight < 60;
let ekranH = '', ekranCalisiyor = false, gorunumTerminal = false;
// Ekran satır satır çizilir; yalnız DEĞİŞEN satıra dokunulur → titreme yok, değişmeyen satırda seçim
// korunur. Okumada metin seçiliyken hiç çizilmez (kopyalama yarıda kalmasın); seçim bitince yetişir.
let cizili = [];
function ekranCiz(metin) {
  const tut = { d: {} };
  const yeni = metin.split('\n').map((l) => ansiHtml(l, tut));
  const satirlar = okuma.children;
  if (satirlar.length !== cizili.length) { okuma.replaceChildren(); cizili = []; }
  yeni.forEach((h, i) => {
    if (cizili[i] === h) return;
    let el = satirlar[i];
    if (!el) { el = document.createElement('div'); okuma.append(el); }
    el.innerHTML = h;
  });
  while (satirlar.length > yeni.length) satirlar[satirlar.length - 1].remove();
  cizili = yeni;
}
function seciliyor() {
  const s = getSelection();
  return !!s && !s.isCollapsed && s.rangeCount > 0 && okuma.contains(s.getRangeAt(0).commonAncestorContainer);
}
async function ekranCek() {
  if (ekranCalisiyor || document.hidden || gorunumTerminal) return;
  ekranCalisiyor = true;
  try {
    const j = await api(Y('/api/ekran?h=') + ekranH);
    if (!j.ayni && !seciliyor()) {
      const yapis = altta() || !ekranH;
      ekranCiz(j.metin.replace(/[─━]{16,}/g, (k) => k.slice(0, 16))); ekranH = j.h;
      if (yapis) kaydir.scrollTop = kaydir.scrollHeight; else enAlta.hidden = false;
    }
  } catch (h) { if (h.message !== 'oturum') { nabiz.dataset.d = 'kotu'; durumYazi.textContent = 'bağlantı yok'; } }
  ekranCalisiyor = false;
}
kaydir.addEventListener('scroll', () => { if (altta()) enAlta.hidden = true; }, { passive: true });
enAlta.addEventListener('click', () => { kaydir.scrollTop = kaydir.scrollHeight; enAlta.hidden = true; });
// önceki mesajlar: dokununca konuşma kaydından son 30 mesaj gelir, "daha eski" ile 30'ar artar
let gecmisAdet = 0;
const saat = (z) => { try { return new Date(z).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' }); } catch { return ''; } };
$('gecmisAc').addEventListener('click', async () => {
  const dugme = $('gecmisAc'); dugme.disabled = true; dugme.textContent = 'Yükleniyor…';
  try {
    gecmisAdet = Math.min(gecmisAdet + 30, 200);
    const j = await api(Y('/api/gecmis?adet=') + gecmisAdet);
    const once = kaydir.scrollHeight - kaydir.scrollTop;   // okunan yer kaymasın
    const liste = j.mesajlar.map((m) => {
      const d = document.createElement('div'); d.className = 'msj'; d.dataset.kim = m.kim;
      const k = document.createElement('small'); k.textContent = (m.kim === 'sen' ? 'Sen' : 'Sedir') + ' · ' + saat(m.zaman);
      d.append(k, document.createTextNode(m.metin)); return d;
    });
    const simdi = document.createElement('p'); simdi.className = 'simdi'; simdi.textContent = '— şimdi ekranda —';
    $('gecmisListe').replaceChildren(...liste, simdi);
    kaydir.scrollTop = kaydir.scrollHeight - once;
    const bitti = gecmisAdet >= 200 || j.mesajlar.length < gecmisAdet;
    dugme.textContent = bitti ? 'Daha eskisi yok' : '↑ Daha eski mesajlar'; dugme.disabled = bitti;
  } catch (h) { gecmisAdet = Math.max(gecmisAdet - 30, 0); dugme.disabled = false; dugme.textContent = '↑ Önceki mesajlar'; if (h.message !== 'oturum') bildir(h.message); }
});
// konuşmaya dokununca klavye kapanır
// yazma kutusu dışında herhangi bir yere dokununca klavye kapanır (gönder/mikrofon/foto hariç)
document.addEventListener('touchstart', (e) => {
  if (document.activeElement !== mesaj) return;
  if (e.target.closest('#mesaj, #gonder, #mik, #foto')) return;
  mesaj.blur();
}, { passive: true, capture: true });
setInterval(ekranCek, 1000); ekranCek();
document.addEventListener('visibilitychange', () => { if (!document.hidden) { ekranH = ''; ekranCek(); } });

// ---- tam terminal (isteğe bağlı): gerçek ttyd — bağlanınca tmux bu cihazın boyutuna uyar
//      Uygulama arka plana geçince bağlantı KESİLİR (Mac ekranı telefona göre daralmış kalmasın),
//      öne gelince yeniden kurulur. ttyd "Press ⏎ to Reconnect" derse telefonda Enter'a basılamaz →
//      kendimiz yeniden bağlarız.
function ttyKur() {
  if ($('tty')) return;
  const f = document.createElement('iframe'); f.id = 'tty'; f.src = Y('/tty/'); f.title = 'Canlı terminal';
  $('ekran').append(f);
}
function ttySok() { $('tty')?.remove(); }
function gorunumAyarla(terminal) {
  gorunumTerminal = terminal;
  $('gorunum').setAttribute('aria-pressed', String(terminal));
  $('gorunum').textContent = terminal ? 'Okuma' : 'Terminal';
  if (terminal) { ttyKur(); kaydir.hidden = true; enAlta.hidden = true; }
  else { ttySok(); kaydir.hidden = false; ekranH = ''; ekranCek(); }
  try { localStorage.setItem(GORUNUM_ANAHTAR, terminal ? 'terminal' : 'okuma'); } catch {}
}
document.addEventListener('visibilitychange', () => {
  if (!gorunumTerminal) return;
  if (document.hidden) ttySok(); else ttyKur();
});
let kopukSayac = 0;
setInterval(() => {  // kopmuş terminali yakala: ttyd'nin kapanış yazısı iframe'de görünüyorsa yeniden bağlan
  const f = $('tty'); if (!f || document.hidden) return;
  let yazi = '';
  try { yazi = [...(f.contentDocument?.querySelectorAll('.xterm > div:not([class])') || [])].map((d) => d.textContent).join(' '); } catch {}  // ttyd'nin yazı katmanı sınıfsız bir div
  if (/Reconnect|Connection Closed/.test(yazi) && !/Reconnecting/.test(yazi)) {
    if (++kopukSayac >= 2) { kopukSayac = 0; ttySok(); ttyKur(); }
  } else kopukSayac = 0;
}, 1500);
$('gorunum').addEventListener('click', () => {
  if (!gorunumTerminal && matchMedia('(pointer: coarse)').matches) bildir('Tam terminal açıkken Mac ekranı telefona göre daralır; Okuma’ya dönünce düzelir.');
  gorunumAyarla(!gorunumTerminal);
});
try { if (localStorage.getItem(GORUNUM_ANAHTAR) === 'terminal' && !matchMedia('(pointer: coarse)').matches) gorunumAyarla(true); } catch {}
