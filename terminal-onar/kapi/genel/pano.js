// genel/pano.js — ttyd sayfasına KAPININ enjekte ettiği pano köprüsü (sunucu.mjs → ttydVekil).
//
// İki iş (Sultan, 12 Eki 2026, terminal.mmepanel.com'dan): "Cmd+C ile kopyalayamıyorum, resmi Cmd+V ile
// yapıştıramıyorum."
//   1) YAPIŞTIR — panoda resim varsa: küçült (2000px webp) → POST <taban>/api/resim → dönen yolu terminale yaz.
//      Metin yapıştırmaya DOKUNULMAZ (xterm kendi yolu; 2026-08-26 akar regresyonunun dersi).
//   2) KOPYALA — tmux `set-clipboard on` seçimi OSC 52 ("\e]52;c;<base64>\a") ile gönderir; ttyd'nin xterm paketinde
//      (1.2.0, Safari — Sultan 15 Eki: "request is not allowed by the user agent"): yazım hareket anında başlar (mouseup'ta
//      clipboard.write'a SÖZ), OSC 52 gelince söz çözülür; reddedilirse tıklanabilir Kopyala düğmesi; Shift+sürükle seçimini
//      copy olayında köprü kendisi yazar (odaktan bağımsız).
//      bu komutu işleyen YOK (ölçüldü 2026-10-13: pakette `registerOscHandler(52` geçmiyor) → seçim hiçbir yere
//      inmiyordu. Burada işlenir: metin tarayıcı panosuna yazılır. Cmd+C'ye basıp seçimi olmayana bir kez ipucu.
//
// Niçin kapıda, niçin userscript değil: ttyd `window.term`'i (xterm) dışa verir → `term.paste` ve
// `term.parser.registerOscHandler` hazır; kapı tabanı (`__TABAN`) zaten bilir; Tampermonkey kurulu olmayan
// tarayıcıda, kokpit çerçevesinde, merkez yolunda ve doğrudan kutu adresinde AYNI sayfa çalışır.
// Bağımlılık yok. kapanış script etiketi bu dosyada GEÇEMEZ (satır içi gömülür; sınav denetler).
(function () {
  'use strict';
  var TABAN = String(window.__TABAN || '');
  var RESIM_URL = TABAN + '/api/resim';
  var MAX_EN = 2000, KALITE = 0.88;      // userscript ölçümü (2026-09-11): 2992px PNG 1.179 KB → 2000px webp 282 KB, okunurluk kaybı yok
  function log() { try { console.log.apply(console, ['[kapi-pano]'].concat([].slice.call(arguments))); } catch (e) { /* yok */ } }
  // Tarayıcı eklentisi (cloudtop-terminal-image.user.js) bu işareti görür ve ttyd sayfasında kendini çeker — çift yükleme olmaz.
  document.documentElement.setAttribute('data-kapi-pano', '1');

  // ── bildirim (sağ alt, tek kutu) ────────────────────────────────────────────────
  var kutu = null, zaman = 0;
  function bildir(metin, renk, sure) {
    if (!document.body) return;
    if (!kutu) {
      kutu = document.createElement('div');
      kutu.id = 'kapi-pano-bildirim';
      kutu.setAttribute('role', 'status');
      kutu.style.cssText = 'position:fixed;right:14px;bottom:14px;z-index:2147483647;max-width:320px;padding:9px 12px;border-radius:8px;' +
        'background:#1e1a14;border:1px solid #4a3f33;color:#ede5d7;font:13px/1.35 system-ui,-apple-system,sans-serif;' +
        'box-shadow:0 6px 20px rgba(0,0,0,.45);pointer-events:none;white-space:pre-wrap';
      document.body.appendChild(kutu);
    }
    kutu.textContent = metin; kutu.style.color = renk || '#ede5d7'; kutu.style.display = 'block';
    clearTimeout(zaman); zaman = setTimeout(function () { kutu.style.display = 'none'; }, sure || 4000);
  }

  // ── küçültme: FAIL-OPEN — tutmazsa orijinal gider, yapıştırma asla engellenmez ───
  async function kucult(blob) {
    if (!blob || !blob.type || blob.type.indexOf('image/') !== 0) return null;
    if (blob.type === 'image/gif') return null;                       // animasyon kaybolur
    if (blob.size < 300 * 1024) return null;                          // zaten küçük
    if (typeof createImageBitmap !== 'function' || typeof OffscreenCanvas !== 'function') return null;
    try {
      var bmp = await createImageBitmap(blob);
      var olcek = bmp.width > MAX_EN ? MAX_EN / bmp.width : 1;
      var g = Math.round(bmp.width * olcek), y = Math.round(bmp.height * olcek);
      var cv = new OffscreenCanvas(g, y); var ctx = cv.getContext('2d');
      ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(bmp, 0, 0, g, y); if (bmp.close) bmp.close();
      var out = await cv.convertToBlob({ type: 'image/webp', quality: KALITE });
      if (!out || out.type !== 'image/webp') out = await cv.convertToBlob({ type: 'image/jpeg', quality: KALITE });
      if (!out || out.size >= blob.size) { log('küçültme atlandı: sonuç daha büyük'); return null; }
      log('küçültüldü', blob.size, '→', out.size, out.type, g + 'x' + y);
      return out;
    } catch (e) { log('küçültme hatası, orijinal gidiyor:', e && e.message); return null; }
  }

  // ── terminale yazma: önce ttyd'nin xterm'i (term.paste), yoksa yardımcı textarea'ya yapay paste ──
  function terminaleYaz(metin) {
    var t = window.term;
    if (t && typeof t.paste === 'function') { t.paste(metin); return 'term.paste'; }
    var ta = document.querySelector('.xterm-helper-textarea');
    if (ta && typeof DataTransfer === 'function' && typeof ClipboardEvent === 'function') {
      var dt = new DataTransfer(); dt.setData('text/plain', metin);
      ta.dispatchEvent(new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true }));
      return 'yapay-paste';
    }
    return '';
  }

  var mesgul = false;
  async function resimIsle(blob) {
    if (mesgul) return; mesgul = true;
    bildir('⬆ resim yükleniyor…', '#c9914f', 60000);
    try {
      var kucuk = await kucult(blob); var govde = kucuk || blob;
      var r = await fetch(RESIM_URL, { method: 'POST', credentials: 'same-origin',
        headers: { 'x-kapi': '1', 'content-type': govde.type || 'application/octet-stream' }, body: govde });
      var j = null; try { j = await r.json(); } catch (e) { /* gövde json değil */ }
      if (r.ok && j && j.yol) {
        var nasil = terminaleYaz(' ' + j.yol + ' ');
        if (nasil) { bildir('✓ resmin yolu terminale yazıldı — Enter ile gönder', '#7ee787', 3500); log('yazıldı', nasil, j.yol); }
        else {
          try { await navigator.clipboard.writeText(j.yol); bildir('📋 yol panoda — Cmd+V ile yapıştır', '#79c0ff', 6000); }
          catch (e) { bildir('✗ yol terminale yazılamadı: ' + j.yol, '#ff7b72', 9000); }
        }
      } else bildir('✗ ' + ((j && j.hata) || ('HTTP ' + r.status)), '#ff7b72', 7000);
    } catch (e) { bildir('✗ ' + (e && e.message), '#ff7b72', 7000); }
    finally { mesgul = false; }
  }

  // Cmd/Ctrl+V → tarayıcı `paste` olayı xterm'in textarea'sına düşer; belgede YAKALAMA fazında önce biz görürüz.
  // Resim varsa olayı burada bitiririz (xterm'e ve varsa tarayıcı eklentisine gitmez); metinse HİÇ dokunmayız.
  document.addEventListener('paste', function (e) {
    var items = (e.clipboardData && e.clipboardData.items) || [];
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (it.kind === 'file' && it.type && it.type.indexOf('image/') === 0) {
        var blob = it.getAsFile(); if (!blob) continue;
        e.preventDefault(); e.stopImmediatePropagation();
        resimIsle(blob); return;
      }
    }
  }, true);

  // ── OSC 52 → tarayıcı panosu ─────────────────────────────────────────────────────
  function b64coz(s) {
    var bin = atob(s.replace(/\s+/g, '')); var b = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) b[i] = bin.charCodeAt(i);
    return new TextDecoder('utf-8').decode(b);
  }
  var panoyaIndi = 0, sonMetin = '', sonMetinAn = 0;   // sonMetin: son tmux seçimi — seçimsiz Cmd+C onu panoya GERİ yazar (Sultan 15 Eki 01:45)
  var SON_METIN_OMRU = 10 * 60 * 1000;   // bağımsız göz tur 1: süresiz tutulan seçim saatler sonra panoyu ezerdi → 10 dk; sonrası ipucu
  function sonMetinTaze() { return !!sonMetin && (Date.now() - sonMetinAn) < SON_METIN_OMRU; }
  var sonYol = '';                        // ölçüm: son pano yazımı hangi yoldan indi (soz · writeText · copy · dugme)
  // 1.2.1 (Sultan Safari 15 Eki 13:33): seçim panoya İNDİKTEN sonra kırmızı "reddedildi" + Kopyala düğmesi çıkıyordu. Aynı seçim için
  //    ikinci bir yazım (yinelenen OSC 52 / geç writeText) hareket dışında reddediliyor ve başarının ÜSTÜNE uyarı basıyordu.
  //    Kural: metin az önce panoya indiyse (5 sn) aynı metin için yazım DENENMEZ, ret SESSİZ geçer; söz yazımı sürüyorsa ret onun
  //    sonucunu bekler. Düğme yalnız metin gerçekten panoya inmediyse çıkar.
  var sonIndiMetin = '', sonIndiAn = 0, yazimSurer = null, INDI_OMRU = 5000;
  function zatenIndi(m) { return m === sonIndiMetin && (Date.now() - sonIndiAn) < INDI_OMRU; }
  var indi = function (yol, metin) { panoyaIndi = Date.now(); sonYol = yol; if (metin != null) { sonIndiMetin = metin; sonIndiAn = panoyaIndi; }
    dugmeGizle(); bildir('📋 seçim panoya kopyalandı — yapışmazsa Cmd+C\'ye bas', '#7ee787', 2400); };
  function retEt(metin, neden) {   // yazım reddedildi: yalnız metin gerçekten panoda DEĞİLSE düğme + uyarı
    if (zatenIndi(metin)) return;
    if (yazimSurer && yazimSurer.metin === metin && yazimSurer.wp) {
      yazimSurer.wp.then(function () { /* söz yolu indirdi: sessiz */ }, function () { if (!zatenIndi(metin)) kopyaDugmesi(metin, neden); }); return;
    }
    kopyaDugmesi(metin, neden);
  }
  // ── Kopyala düğmesi: pano yazımı reddedilince (Safari: hareket dışı yazım yasak) tıklama = kullanıcı hareketi → writeText o anda geçer
  var dugme = null, dugmeZaman = 0;
  function dugmeGizle() { if (dugme) dugme.style.display = 'none'; clearTimeout(dugmeZaman); }
  function kopyaDugmesi(metin, neden) {
    if (!document.body) return;
    if (!dugme) {
      dugme = document.createElement('button'); dugme.id = 'kapi-pano-kopyala'; dugme.type = 'button'; dugme.textContent = '📋 Kopyala';
      dugme.style.cssText = 'position:fixed;right:14px;bottom:64px;z-index:2147483647;padding:9px 14px;border-radius:8px;cursor:pointer;' +
        'background:#c9914f;border:1px solid #e0b070;color:#1e1a14;font:600 13px/1.2 system-ui,-apple-system,sans-serif;box-shadow:0 6px 20px rgba(0,0,0,.45)';
      dugme.addEventListener('mousedown', function (e) { e.preventDefault(); });   // odak terminalden kaçmasın
      dugme.addEventListener('click', function () {
        var m = dugme.getAttribute('data-metin') || ''; if (!m) return;
        if (!navigator.clipboard || !navigator.clipboard.writeText) { bildir('✗ tarayıcı panoya izin vermiyor — Shift basılı sürükleyip Cmd+C', '#ff7b72', 6000); return; }
        navigator.clipboard.writeText(m).then(function () { indi('dugme', m); },     // tıklama içinde EŞZAMANLI çağrı: Safari geçirir
          function (e) { bildir('✗ panoya yine yazılamadı (' + ((e && e.message) || 'izin') + ') — Shift basılı sürükleyip Cmd+C', '#ff7b72', 7000); });
      });
      document.body.appendChild(dugme);
    }
    dugme.setAttribute('data-metin', metin); dugme.style.display = 'block';
    clearTimeout(dugmeZaman); dugmeZaman = setTimeout(dugmeGizle, 20000);
    bildir('✗ pano yazımı reddedildi (' + neden + ') — Kopyala düğmesine bas ya da Cmd+C', '#ff7b72', 8000);
  }
  // ── Safari: pano yazımı yalnız kullanıcı hareketi İÇİNDE geçer; tmux seçimi OSC 52 ile GEÇ gelir (WebSocket) → writeText
  //    'request is not allowed by the user agent' ile düşer (Sultan 15 Eki). WebKit'in bu iş için tanımladığı yol: hareket anında
  //    (mouseup) clipboard.write'a bir SÖZ (Promise) verilir; metin sonra gelince söz çözülür. Söz 1500 ms'de çözülmezse reddedilir
  //    ve pano DEĞİŞMEZ. Chromium da sözü kabul eder; aynı yol her tarayıcıda.
  var bekleyen = null, SOZ_OMRU = 1500;
  function panoyaYaz(metin) {
    sonMetin = metin; sonMetinAn = Date.now();
    if (bekleyen) { var b = bekleyen; bekleyen = null; clearTimeout(b.zaman); b.metin = metin; b.cozuldu = true; yazimSurer = b; b.coz(metin); return; }
    if (zatenIndi(metin) || (yazimSurer && yazimSurer.metin === metin)) return;   // yinelenen OSC 52: aynı metin indi/iniyor — yazım denenmez
    if (!navigator.clipboard || !navigator.clipboard.writeText) { retEt(metin, 'tarayıcı izin vermiyor'); return; }
    navigator.clipboard.writeText(metin).then(function () { indi('writeText', metin); },
      function (e) { retEt(metin, (e && e.message) || 'izin'); });
  }
  var basX = 0, basY = 0;
  document.addEventListener('mousedown', function (e) { basX = e.clientX; basY = e.clientY; }, true);
  document.addEventListener('mouseup', function (e) {
    if (e.button !== 0 || e.shiftKey || e.altKey || e.metaKey || e.ctrlKey) return;   // tarayıcı seçimi (Shift/Option): OSC 52 gelmez, copy olayı yolu
    var surukle = Math.abs(e.clientX - basX) + Math.abs(e.clientY - basY) >= 3, cift = e.detail >= 2;
    if (!surukle && !cift) return;                                                   // düz tık: seçim yok, pano'ya dokunulmaz
    if (!navigator.clipboard || typeof navigator.clipboard.write !== 'function' || typeof ClipboardItem !== 'function') return;
    if (bekleyen) { clearTimeout(bekleyen.zaman); bekleyen.red(new Error('yeni seçim')); bekleyen = null; }
    var b = { cozuldu: false, metin: '' };
    var soz = new Promise(function (coz, red) { b.coz = function (m) { coz(new Blob([m], { type: 'text/plain' })); }; b.red = red; });
    soz.catch(function () { /* süre doldu ya da yeni seçim: sessiz */ });
    b.zaman = setTimeout(function () { if (bekleyen === b) { bekleyen = null; b.red(new Error('OSC 52 gelmedi')); } }, SOZ_OMRU);
    bekleyen = b;
    try {
      b.wp = navigator.clipboard.write([new ClipboardItem({ 'text/plain': soz })]);
      b.wp.then(function () { if (yazimSurer === b) yazimSurer = null; indi('soz', b.metin); },
        function (e) { if (bekleyen === b) { bekleyen = null; clearTimeout(b.zaman); } if (yazimSurer === b) yazimSurer = null;
          if (b.cozuldu && !zatenIndi(b.metin)) kopyaDugmesi(b.metin, (e && e.message) || 'izin'); });   // metin geldi ama inmedi → düğme; süre dolduysa sessiz
    } catch (err) { if (bekleyen === b) bekleyen = null; clearTimeout(b.zaman); }   // ClipboardItem söz kabul etmiyor (eski tarayıcı): writeText yolu kalır
  }, true);
  // ── seçimsiz Cmd+C / Ctrl+Insert = 'copy' olayı: son tmux seçimini panoya yaz (Sultan 15 Eki: "kopyalandı diyor ama kopyalanmıyor").
  //    xterm.js'in kopya işleyicisi seçim yokken olayı kendi (boş) seçimiyle doldurur; önce biz görürüz (yakalama fazı) ve
  //    panoya son seçimi koyarız. Tarayıcı seçimi (Shift/Option+sürükle) varsa DOKUNMAYIZ — o yol xterm'in/tarayıcının.
  document.addEventListener('copy', function (e) {
    var t = window.term;
    var xsec = t && typeof t.hasSelection === 'function' && t.hasSelection();
    var ssec = !!(window.getSelection && String(window.getSelection()));
    if (!e.clipboardData) return;
    if (xsec) {   // Shift/Option+sürükle seçimi: odak nerede olursa olsun köprü yazar (Safari'de odak textarea'dan kaçınca xterm'in işleyicisi olayı görmüyordu)
      var m = t.getSelection(); if (!m) return;
      e.preventDefault(); e.stopImmediatePropagation();
      e.clipboardData.setData('text/plain', m); panoyaIndi = Date.now(); sonYol = 'copy'; sonIndiMetin = m; sonIndiAn = panoyaIndi; dugmeGizle();
      bildir('📋 seçim panoya yazıldı (Cmd+C)', '#7ee787', 1800); return;
    }
    if (ssec || !sonMetinTaze()) return;   // bayat seçim (>10 dk) panoya YAZILMAZ — olay tarayıcıya kalır
    e.preventDefault(); e.stopImmediatePropagation();
    e.clipboardData.setData('text/plain', sonMetin); panoyaIndi = Date.now(); sonYol = 'copy'; sonIndiMetin = sonMetin; sonIndiAn = panoyaIndi; dugmeGizle();
    bildir('📋 son seçim panoya yazıldı (Cmd+C)', '#7ee787', 1800);
  }, true);
  function osc52(veri) {                       // veri: "c;<base64>" · "?" sorgusu desteklenmez (pano OKUNMAZ)
    var s = String(veri || ''); var i = s.indexOf(';'); if (i < 0) return false;
    var icerik = s.slice(i + 1); if (!icerik || icerik === '?') return false;
    var metin; try { metin = b64coz(icerik); } catch (e) { return false; }
    if (!metin) return false;
    panoyaYaz(metin); return true;
  }
  function termBagla() {
    var t = window.term;
    if (!t || !t.parser || typeof t.parser.registerOscHandler !== 'function') return false;
    t.parser.registerOscHandler(52, osc52);
    window.__kapiPano = { surum: '1.2.1', osc52: true, cmdc: true, soz: true, dugme: true, taban: TABAN, sonMetinOmruMs: SON_METIN_OMRU,
      _eskit: function () { sonMetinAn = 0; }, _sonYol: function () { return sonYol; }, _sozBekliyor: function () { return !!bekleyen; },
      _sozOmru: function (ms) { SOZ_OMRU = ms; }, _indiOmru: function (ms) { INDI_OMRU = ms; } };   // ölçüm yüzeyi (sınav okur; _eskit: son seçimi bayatlatır; _sozOmru: sınav süreyi kısaltır)
    log('bağlandı: OSC 52 → pano · resim → ' + RESIM_URL);
    return true;
  }
  (function bekle(n) { if (termBagla()) return; if (n > 0) setTimeout(function () { bekle(n - 1); }, 100); else log('window.term bulunamadı; OSC 52 bağlanamadı'); })(150);

  // ── Cmd+C (Mac) / Ctrl+Shift+C: tarayıcı seçimi yoksa fare tmux'a gidiyordur — bir kez yol göster ──
  var ipucu = false;
  document.addEventListener('keydown', function (e) {
    var kopya = (e.key === 'c' || e.key === 'C') && !e.altKey && ((e.metaKey && !e.ctrlKey && !e.shiftKey) || (e.ctrlKey && e.shiftKey && !e.metaKey));
    if (!kopya) return;
    var t = window.term;
    var secim = t && typeof t.hasSelection === 'function' ? t.hasSelection() : !!(window.getSelection && String(window.getSelection()));
    if (secim) return;                              // tarayıcı seçimi var → Cmd+C normal kopyalar
    if (sonMetinTaze()) return;                     // taze tmux seçimi var → 'copy' olayı onu panoya yazar (yukarıda)
    if (ipucu) return; ipucu = true;
    bildir('Kopyalamak için: fareyle seçtiğin an panoya iner (Cmd+C gerekmez).\nTarayıcı seçimi istersen Shift basılı tutup sürükle, sonra Cmd+C.', '#ede5d7', 8000);
  }, true);
})();
