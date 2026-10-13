// genel/pano.js — ttyd sayfasına KAPININ enjekte ettiği pano köprüsü (sunucu.mjs → ttydVekil).
//
// İki iş (Sultan, 12 Eki 2026, terminal.mmepanel.com'dan): "Cmd+C ile kopyalayamıyorum, resmi Cmd+V ile
// yapıştıramıyorum."
//   1) YAPIŞTIR — panoda resim varsa: küçült (2000px webp) → POST <taban>/api/resim → dönen yolu terminale yaz.
//      Metin yapıştırmaya DOKUNULMAZ (xterm kendi yolu; 2026-08-26 akar regresyonunun dersi).
//   2) KOPYALA — tmux `set-clipboard on` seçimi OSC 52 ("\e]52;c;<base64>\a") ile gönderir; ttyd'nin xterm paketinde
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
  var panoyaIndi = 0;
  function panoyaYaz(metin) {
    if (!navigator.clipboard || !navigator.clipboard.writeText) {
      bildir('✗ tarayıcı panoya izin vermiyor — Shift basılı sürükleyip Cmd+C ile kopyala', '#ff7b72', 6000); return;
    }
    navigator.clipboard.writeText(metin).then(function () { panoyaIndi = Date.now(); bildir('📋 seçim panoya kopyalandı', '#7ee787', 1800); },
      function (e) { bildir('✗ panoya yazılamadı (' + ((e && e.message) || 'izin') + ') — Shift basılı sürükle, sonra Cmd+C', '#ff7b72', 6000); });
  }
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
    window.__kapiPano = { surum: '1.0.0', osc52: true, taban: TABAN };   // ölçüm yüzeyi (sınav bunu okur)
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
    if (Date.now() - panoyaIndi < 3000) return;     // tmux seçimi zaten panoya indi
    if (ipucu) return; ipucu = true;
    bildir('Kopyalamak için: fareyle seçtiğin an panoya iner (Cmd+C gerekmez).\nTarayıcı seçimi istersen Shift basılı tutup sürükle, sonra Cmd+C.', '#ede5d7', 8000);
  }, true);
})();
