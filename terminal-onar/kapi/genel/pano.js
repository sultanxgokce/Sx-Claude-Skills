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
  // 1.2.2 (Sultan 15 Eki, İKİNCİ kez "resim yapıştırma çok yavaş" · gorev AT9J8305): Safari WebP KODLAYAMAZ — convertToBlob('image/webp')
  //   sessizce PNG döner; eski kod sonra JPEG'i İKİNCİ kez kodluyordu (2000 px PNG kodlaması bedavaya gelmez). Destek bir kez yoklanır,
  //   yoksa doğrudan JPEG: her yapıştırmada tek kodlama.
  var WEBP = null;   // null = henüz yoklanmadı
  function webpVarMi() {
    if (WEBP !== null) return WEBP;
    try { var c = document.createElement('canvas'); c.width = c.height = 1; WEBP = c.toDataURL('image/webp').indexOf('data:image/webp') === 0; }
    catch (e) { WEBP = false; }
    return WEBP;
  }
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
      var tip = webpVarMi() ? 'image/webp' : 'image/jpeg';
      var out = await cv.convertToBlob({ type: tip, quality: KALITE });
      if (tip === 'image/webp' && (!out || out.type !== 'image/webp')) { WEBP = false; out = await cv.convertToBlob({ type: 'image/jpeg', quality: KALITE }); }   // yoklama yanıldıysa bir kez, sonra hep JPEG
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

  // adım süreleri bildirimde (1.2.2): "yavaş" olunca nerede beklendiği ekrandan okunur — küçültme mi, yükleme mi (sunucu/ağ)
  function sn(ms) { return (ms / 1000).toFixed(1).replace('.', ',') + ' sn'; }
  function kb(b) { return b >= 1024 * 1024 ? (b / 1048576).toFixed(1).replace('.', ',') + ' MB' : Math.round(b / 1024) + ' KB'; }
  var sonOlcum = null;
  var mesgul = false;
  async function resimIsle(blob) {
    if (mesgul) return; mesgul = true;
    var t0 = performance.now();
    bildir('⏳ resim küçültülüyor… (' + kb(blob.size) + ')', '#c9914f', 60000);
    try {
      var kucuk = await kucult(blob); var govde = kucuk || blob, t1 = performance.now();
      bildir('⬆ resim yükleniyor… (' + kb(govde.size) + ' · küçültme ' + sn(t1 - t0) + ')', '#c9914f', 60000);
      var r = await fetch(RESIM_URL, { method: 'POST', credentials: 'same-origin',
        headers: { 'x-kapi': '1', 'content-type': govde.type || 'application/octet-stream' }, body: govde });
      var j = null; try { j = await r.json(); } catch (e) { /* gövde json değil */ }
      var t2 = performance.now();
      sonOlcum = { kucultMs: Math.round(t1 - t0), yukleMs: Math.round(t2 - t1), ilkBayt: blob.size, bayt: govde.size, tip: govde.type || '' };
      var sure = 'küçültme ' + sn(t1 - t0) + ' · yükleme ' + sn(t2 - t1) + ' · ' + kb(govde.size);
      log('süreler', sonOlcum);
      if (r.ok && j && j.yol) {
        var nasil = terminaleYaz(' ' + j.yol + ' ');
        if (nasil) { bildir('✓ resmin yolu terminale yazıldı — Enter ile gönder\n' + sure, '#7ee787', 6000); log('yazıldı', nasil, j.yol); }
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
    // Odak terminal dışı bir yazı alanındaysa (ör. görev kartının "Madde ekle" kutusu) yapıştırma o alanındır;
    // xterm'in kendi yardımcı textarea'sı .xterm içinde olduğu için yakalanmaya devam eder.
    var t = e.target;
    if (t && t.closest && !t.closest('.xterm') && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
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
  // ── DİM OKUNURLUK (1.3.0 · Sultan 16 Eki 10:10 karesi, nazir-yon): Claude Code soru satırlarını ve şık açıklamalarını
  //    ESC[2m (dim) basar; xterm dim'i rengi yarıya soldurarak çizer (DIM_OPACITY 0.5) ve bunu minimumContrastRatio'dan
  //    SONRA uygular → "dim + gri-244" koyu temada 2,08:1 (ölçüldü, Chromium piksel), okunmuyor; minimumContrastRatio=7 bile
  //    dim'e İŞLEMEZ (ölçüldü). Çare: SGR ayrıştırıcıya kanca — dim (2) → "ön plan brightBlack" (SGR 90): temada brightBlack
  //    okunur bir ikincil ton (onar.sh: #a89f91, ≥7:1). 22 (dim kapat) gelince dim'den ÖNCEKİ açık renk (yoksa varsayılan)
  //    geri konur; 2'den sonra gelen açık renk (2;38;5;244) kendi kazanır (gri-244 4,7:1). Dim'siz SGR'ye DOKUNULMAZ.
  //    Genel API parametreleri dizi verir (alt-parametre iç dizi) ve kopyadır → düzleştirip çekirdeğin charAttributes'ına veririz.
  var dimAcik = false, fgSon = null;   // fgSon: son açık ön plan SGR'si (ör. [32] · [38,5,244]) — 22'de geri konur
  function dimKanca(t) {
    var ih = t._core && t._core._inputHandler;
    if (!ih || typeof ih.charAttributes !== 'function' || typeof t.parser.registerCsiHandler !== 'function') return false;
    t.parser.registerCsiHandler({ final: 'm' }, function (arr) {
      var flat = [], i, v, degisti = false;
      for (i = 0; i < arr.length; i++) { if (Array.isArray(arr[i])) flat.push.apply(flat, arr[i]); else flat.push(arr[i]); }
      if (!flat.length) flat.push(0);
      for (i = 0; i < flat.length; i++) {
        v = flat[i];
        if (v === 2) { flat[i] = 90; dimAcik = true; degisti = true; }
        else if (v === 0) { dimAcik = false; fgSon = null; }
        else if (v === 39) { dimAcik = false; fgSon = null; }
        else if ((v >= 30 && v <= 37) || (v >= 90 && v <= 97)) { dimAcik = false; fgSon = [v]; }
        else if (v === 38) { var n = flat[i + 1] === 5 ? 2 : flat[i + 1] === 2 ? 4 : 0; fgSon = flat.slice(i, i + 1 + n); dimAcik = false; i += n; }
        else if (v === 48 || v === 58) { i += flat[i + 1] === 5 ? 2 : flat[i + 1] === 2 ? 4 : 0; }
        else if (v === 22 && dimAcik) { flat.push.apply(flat, fgSon || [39]); dimAcik = false; degisti = true; }
      }
      if (!degisti) return false;   // dim'siz dizi: xterm'in kendi yolu, bayt bayt eski davranış
      ih.charAttributes({ length: flat.length, params: flat, hasSubParams: function () { return false; }, getSubParams: function () { return null; }, getSubParamsAll: function () { return {}; } });
      return true;
    });
    return true;
  }
  function termBagla() {
    var t = window.term;
    if (!t || !t.parser || typeof t.parser.registerOscHandler !== 'function') return false;
    t.parser.registerOscHandler(52, osc52);
    var dimOkunur = false; try { dimOkunur = dimKanca(t); } catch (e) { log('dim kancası takılamadı: ' + (e && e.message)); }
    window.__kapiPano = { surum: '1.3.0', dimOkunur: dimOkunur, sonResim: function () { return sonOlcum; }, osc52: true, cmdc: true, soz: true, dugme: true, taban: TABAN, sonMetinOmruMs: SON_METIN_OMRU,
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

  // ── TELEFONDA GÖRÜNTÜ EKLE (2.36.5 · Sultan 30 Eki 21:16, görev …HJKXAB): telefonda pano resmi terminale yapıştırılamıyor —
  //    galeriden seçme ya da kamerayla çekme yolu YOK. Telefonda (dokunmatik + dar ekran; merkezin TEL_BAS ölçütüyle AYNI sorgu) terminalin
  //    ÜSTÜNE tek düğme: seçilen dosya yapıştırmayla AYNI yoldan geçer (resimIsle: küçültme → /api/resim → yol terminale). Masaüstünde
  //    düğme HİÇ yaratılmaz.
  //    TEK düğme, capture YOK (seçim gerekçesi): accept="image/*" iOS Safari'de ve Android Chrome'da işletim sisteminin kendi menüsünü açar
  //    (Fotoğraf Arşivi · Fotoğraf Çek · Dosya Seç) — galeri ile kamera aynı dokunuşta. capture="environment" galeriyi KAPATIR (doğrudan kamera);
  //    ikinci düğme ise terminalin üstünden bir dokunma hedefi daha yer. Bu davranış platform belgesidir, bu kutuda ölçülemedi (gerçek telefon yok).
  //    Terminal metnini ÖRTMEZ: düğme terminal kabının DIŞINDA; kap 52 px aşağı itilir, yüksekliği o kadar kısalır, ttyd yeniden sığdırır.
  //    Dokunma hedefi ≥ 44 px (Apple İK). Merkezin sağ üstteki "dar" düğmesiyle çakışmasın diye SOLDA.
  var RESIM_SERIT = 52;
  //    "Dar": sayfa genişliği YA DA cihaz ekranı ≤ 720 px — merkez (TEL_BAS) görünüm etiketini koyar, sayfa 390 px olur; doğrudan kutu adresinde
  //    etiket yoktur, sayfa 980 px çizilir ama cihaz ekranı yine dardır (screen.width).
  function telefonMu() {
    try { return !!(window.matchMedia && matchMedia('(pointer:coarse)').matches && (matchMedia('(max-width:720px)').matches || (screen && screen.width <= 720))); }
    catch (e) { return false; }
  }
  function resimDugmesiKur() {
    if (!telefonMu() || !document.body || document.getElementById('kapi-resim-ekle')) return false;
    var kap = document.getElementById('terminal-container'); if (!kap) return false;
    var etiket = document.createElement('label'); etiket.id = 'kapi-resim-ekle'; etiket.setAttribute('role', 'button');
    etiket.setAttribute('aria-label', 'Terminale görüntü ekle (galeri ya da kamera)');
    etiket.style.cssText = 'position:fixed;top:4px;left:8px;z-index:2147483646;display:inline-flex;align-items:center;gap:6px;min-height:44px;min-width:44px;' +
      // görsel dil = merkezin "Dar görünüm" hapı (aynı ekranda iki ayrı dil olmasın): koyu zemin · ince kenar · açık metin · emoji YOK.
      //   Birincil eylem yazmaktır, bu düğme değil — dolu vurgu rengi terminalin en parlak öğesi olurdu. Değişkenler merkezde tanımlı; kapının kendi sayfasında yedek değer.
      'box-sizing:border-box;padding:0 16px;border-radius:999px;cursor:pointer;background:var(--zemin,#120e0a);border:1px solid var(--kenar,#3a2f24);' +
      'color:var(--metin,#f4ede2);opacity:.94;font:14px/1 -apple-system,"Segoe UI",Roboto,Helvetica,Arial,system-ui,sans-serif;' +
      '-webkit-tap-highlight-color:transparent;user-select:none;-webkit-user-select:none';
    etiket.textContent = 'Görüntü ekle';
    var girdi = document.createElement('input'); girdi.type = 'file'; girdi.accept = 'image/*'; girdi.id = 'kapi-resim-girdi';
    girdi.style.cssText = 'position:absolute;width:1px;height:1px;opacity:0;overflow:hidden;pointer-events:none';
    girdi.addEventListener('change', function () {
      var f = girdi.files && girdi.files[0]; girdi.value = '';
      if (!f) return;
      if (!f.type || f.type.indexOf('image/') !== 0) { bildir('✗ bu bir görüntü değil (' + (f.type || 'tür yok') + ')', '#ff7b72', 6000); return; }
      resimIsle(f);
    });
    etiket.appendChild(girdi);
    // şerit zemini: terminalin kendi zemin rengi (ttyd teması) — düğmenin arkası beyaz bir boşluk olmasın; merkezin sağ üst düğmesi (z 5) önde kalır
    var zemin = '#15120e'; try { var tz = window.term && window.term.options && window.term.options.theme; if (tz && tz.background) zemin = tz.background; } catch (e) { /* varsayılan */ }
    var serit = document.createElement('div'); serit.id = 'kapi-resim-serit';
    serit.style.cssText = 'position:fixed;top:0;left:0;right:0;height:' + RESIM_SERIT + 'px;z-index:1;background:' + zemin + ';pointer-events:none';
    document.body.appendChild(serit); document.body.appendChild(etiket);
    kap.style.marginTop = RESIM_SERIT + 'px'; kap.style.height = 'calc(100% - ' + RESIM_SERIT + 'px)';
    try { window.dispatchEvent(new Event('resize')); } catch (e) { /* eski tarayıcı */ }
    var klavye = klavyeUyumKur(kap);
    window.__kapiResim = { surum: '1.1.0', dugme: true, serit: RESIM_SERIT, klavye: klavye };
    return true;
  }
  // ── KLAVYE AÇIKKEN YAZI ALANI GÖRÜNÜR (1.1.0 · BÂNİ 30 Eki, Kuzey Yıldızı G2.9): telefonda klavye açılınca tarayıcı yalnız GÖRÜNEN alanı
  //    (visualViewport) küçültür; sayfa ve terminal tam boyda kalır → terminalin alt satırları (Claude'un yazı kutusu) klavyenin ALTINDA kalır.
  //    Çare: görünen alan sayfadan belirgin kısaysa (klavye) terminal kabı görünen alana sığdırılır, ttyd yeniden sığdırır (satır azalır);
  //    tmux imleci izler, yazı satırı görünür kalır. Klavye kapanınca eski boy. Telefon ignore-size ile bağlı: pencere küçülmez, masaüstü etkilenmez.
  function klavyeUyumKur(kap) {
    var vv = window.visualViewport; if (!vv || typeof vv.addEventListener !== 'function') return false;
    var son = '';
    function uygula() {
      var acik = vv.height < window.innerHeight - 80;                    // 80 px'ten az fark: adres çubuğu oynaması, klavye değil
      var boy = acik ? Math.max(120, Math.round(vv.height - RESIM_SERIT)) + 'px' : 'calc(100% - ' + RESIM_SERIT + 'px)';
      if (boy === son) return; son = boy;
      kap.style.height = boy;
      if (acik && vv.offsetTop) { try { window.scrollTo(window.scrollX, 0); } catch (e) { /* yok */ } }   // iOS sayfayı kaydırmışsa şerit+terminal başa döner
      try { window.dispatchEvent(new Event('resize')); } catch (e) { /* eski tarayıcı */ }
    }
    vv.addEventListener('resize', uygula); vv.addEventListener('scroll', uygula);
    return true;
  }
  (function bekleDugme(n) { if (resimDugmesiKur() || !telefonMu()) return; if (n > 0) setTimeout(function () { bekleDugme(n - 1); }, 100); })(100);
})();
