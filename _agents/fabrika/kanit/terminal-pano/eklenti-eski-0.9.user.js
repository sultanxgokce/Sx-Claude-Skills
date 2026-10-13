// ==UserScript==
// @name         Cloudtop terminal image paste
// @namespace    cloudtop.mmepanel
// @version      0.9
// @description  code-server terminaline resim yapıştır (Cmd/Ctrl+V) → yol otomatik yazılır; AYRICA sesli dikte: köşedeki 🎤 (ya da Ctrl/Cmd+Shift+M) → konuş → metin terminale (Groq Whisper).
// 🔴 JOKER @match ŞART (2026-08-26 canlı yakalama): burada dört adres tek tek
// yazılıydı, ama Sultan'ın tarayıcısında KURULU olan sürüm `https://*.mmepanel.com/*`
// taşıyordu. Yani depo, fiilen çalışandan DARDI. Üzerine yazılsaydı nova · tellal ·
// huzur · akar · sedir · tez · nazir · s02 · mihenk kutularında yapıştırma ÖLÜRDÜ —
// aynı gün 15 kutuya dağıtılan şey tek tıkla geri alınmış olacaktı.
// Tampermonkey'in "@match değişti" uyarısı bunu yakalattı; ders: kurulu-gerçek ⟂ depo.
// @match        https://*.mmepanel.com/*
// @downloadURL  https://code.mmepanel.com/proxy/8391/cloudtop-terminal-image.user.js
// @updateURL    https://code.mmepanel.com/proxy/8391/cloudtop-terminal-image.user.js
// @run-at       document-idle
// @grant        GM_addStyle
// ==/UserScript==
// NOT: @grant 'none' DEĞİL. code.mmepanel.com'un katı CSP'si ('script-src self')
// sayfa-bağlamı enjeksiyonunu engelliyordu → script hiç çalışmıyordu. Bir grant
// vermek (GM_addStyle kullanılmasa da) Tampermonkey'i kendi izole/sandbox
// bağlamında çalıştırır; bu bağlam sayfa CSP'sine TABİ DEĞİL → script çalışır.
(function () {
  'use strict';

  // POSTs go SAME-ORIGIN through code-server's built-in port proxy, which
  // forwards to the localhost terminal-image-listener (127.0.0.1:8391). No CORS,
  // and the Cloudflare Access cookie rides along automatically.
  const UPLOAD_URL = '/proxy/8391/upload';
  const VOICE_URL = '/proxy/8391/voice';
  // Selector that identifies the integrated-terminal input across VS Code / xterm.
  const TERM_SEL = '.xterm, .terminal-wrapper, .integrated-terminal, .terminal, .xterm-helper-textarea';
  // İzole konteynerler (vekatip / mmex / medigate) Groq egress'i olmadan çalışır → sesli dikte
  // orada yok; 🎤 butonu bastırılır, kullanıcı Mac OS-seviyesi uygulamayla dikte eder. (Resim
  // yapıştırma HEPSİNDE çalışır — her konteynerin kendi 127.0.0.1:8391 listener'ı + /proxy/8391/.)
  const IS_VOICE_OFF = /(^|\.)(vekatip|mmex|medi)\./.test(location.hostname);
  const log = (...a) => console.log('[term-paste]', ...a);
  log('userscript loaded', IS_VOICE_OFF ? '(izole: voice off)' : '(voice on)');

  let busy = false;
  let lastFire = 0; // dedup: the paste-event path and the keydown path can both
                    // fire for one Cmd+V — collapse them within a short window.

  function inTerminal(el) { return !!(el && el.closest && el.closest(TERM_SEL)); }
  function terminalFocused() { return inTerminal(document.activeElement); }

  // Remember the last focused terminal input so voice (whose button/tap may steal
  // focus, esp. on touch) can re-target it before inserting the transcript.
  let lastTermEl = null;
  document.addEventListener('focusin', () => {
    const ae = document.activeElement;
    if (inTerminal(ae)) lastTermEl = ae;
  }, true);
  function focusTerminal() {
    try { if (lastTermEl && document.contains(lastTermEl)) { lastTermEl.focus(); return true; } } catch (e) {}
    return terminalFocused();
  }

  // ── YÜKLEME ÖNCESİ KÜÇÜLTME (2026-09-11) ─────────────────────────────────────
  //
  // 🔴 ÖLÇÜLDÜ, tahmin değil. Sultan "resim yapıştırma çok yavaş" dedi; boru baştan
  //    sona ölçüldü:
  //      sunucu (listener, 1.18 MB gerçek PNG, ağ YOK) : 2-10 ms   → darboğaz DEĞİL
  //      inbox'taki 815 görselin ortancası               : 1.148 KB
  //      en büyüğü                                       : 6.297 KB
  //    Yani zaman tamamen TELDE geçiyor: Mac → Cloudflare tüneli → code-server proxy.
  //    Ev yüklemesi ~5 Mbps ise 1,1 MB ≈ 2 sn, 6 MB ≈ 10 sn. "Yükleniyor…" o kadar durur.
  //
  //    macOS tam-ekran görüntüsü 2992×1934 PNG geliyor. Ama okuyan taraf onu zaten
  //    ~2000px'e indirerek görüyor — yani 2992px'in fazlası TELDE taşınıp sonra atılıyor.
  //
  //    ÖLÇÜM (aynı görsel, gerçek dosya):
  //      kaynak PNG 2992px : 1.179 KB
  //      2000px WebP q88   :   282 KB   ← %24, ve OKUNABİLİRLİK KAYBI YOK (uçtan uca sınandı)
  //      1600px WebP q88   :   208 KB   (daha küçük ama küçük punto riski → seçilmedi)
  //
  // 🔴 FAIL-OPEN: küçültme herhangi bir sebeple tutmazsa (tarayıcı desteklemiyor, kodek
  //    yok, sonuç daha BÜYÜK çıktı) ORİJİNAL gönderilir. Bu yol bir hızlandırmadır;
  //    yapıştırmayı ASLA engellememeli. Sessizce de geçmez — konsola sebebini yazar.
  const MAX_EN = 2000;      // okuyan taraf zaten bu genişlikte görüyor
  const KALITE = 0.88;

  async function kucult(blob) {
    if (!blob || !blob.type || blob.type.indexOf('image/') !== 0) return null;
    if (blob.type === 'image/gif') return null;            // animasyon kaybolur — dokunma
    if (blob.size < 300 * 1024) return null;               // zaten küçük; tur harcama
    if (typeof createImageBitmap !== 'function' || typeof OffscreenCanvas !== 'function') {
      log('kucultme yok: tarayici desteklemiyor'); return null;
    }
    try {
      const bmp = await createImageBitmap(blob);
      const olcek = bmp.width > MAX_EN ? MAX_EN / bmp.width : 1;
      const g = Math.round(bmp.width * olcek), y = Math.round(bmp.height * olcek);
      const cv = new OffscreenCanvas(g, y);
      const ctx = cv.getContext('2d');
      ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(bmp, 0, 0, g, y);
      bmp.close && bmp.close();
      let out = await cv.convertToBlob({ type: 'image/webp', quality: KALITE });
      // WebP kodeği yoksa tarayıcı sessizce PNG döndürür — o PNG genelde DAHA BÜYÜK olur.
      if (!out || out.type !== 'image/webp') {
        out = await cv.convertToBlob({ type: 'image/jpeg', quality: KALITE });
      }
      if (!out || out.size >= blob.size) {
        log('kucultme atlandi: sonuc daha buyuk', out && out.size, '>=', blob.size);
        return null;
      }
      log('kucultuldu', blob.size, '→', out.size, `(%${Math.round(out.size * 100 / blob.size)})`, out.type, `${g}x${y}`);
      return out;
    } catch (e) {
      log('kucultme hatasi, orijinal gonderilecek:', e.message);
      return null;
    }
  }

  async function handleImageBlob(blob) {
    const now = Date.now();
    if (busy || now - lastFire < 1500) return; // already handling this paste
    lastFire = now;
    busy = true;
    showPreview(blob);
    try {
      const kucuk = await kucult(blob);
      const govde = kucuk || blob;
      const resp = await fetch(UPLOAD_URL, {
        method: 'POST',
        headers: { 'X-Requested-With': 'dashboard', 'Content-Type': govde.type || 'application/octet-stream' },
        body: govde,
      });
      const data = await resp.json().catch(() => null);
      if (resp.ok && data && data.ok && data.path) {
        // Baştaki boşluk bilerek: pano sadeleştirmesi herhangi bir sebeple
        // tutmadıysa yol, önündeki metne YAPIŞMASIN. Satır başındayken zararsız.
        insertText(' ' + data.path + ' ');
        flash('ok');
        log('uploaded + inserted', data.path);
      } else {
        flash('err', (data && data.error) || ('HTTP ' + resp.status));
        log('upload failed', data);
      }
    } catch (e) {
      flash('err', e.message);
      log('error', e);
    } finally {
      busy = false;
    }
  }

  // Type the path into the focused terminal. Three strategies, most-reliable first.
  function insertText(text) {
    const ae = document.activeElement;
    try {
      if (ae && (ae.tagName === 'TEXTAREA' || ae.isContentEditable)) {
        ae.focus();
        if (document.execCommand('insertText', false, text)) { log('inserted via execCommand'); return; }
      }
    } catch (e) {}
    try {
      const dt = new DataTransfer();
      dt.setData('text/plain', text);
      const ev = new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true });
      (ae || document).dispatchEvent(ev);
      log('inserted via synthetic paste');
      return;
    } catch (e) {}
    try { navigator.clipboard.writeText(text); flash('clip'); log('path copied to clipboard'); } catch (e) {}
  }

  // ── Pano ön-sadeleştirmesi (0.8 · yapışık blob: linki) ─────────────────────
  // SORUN (Sultan, 2026-08-29): WhatsApp Web'den resim kopyalanıp terminale
  // yapıştırılınca satır şöyle çıkıyordu:
  //   blob:https://web.whatsapp.com/<uuid>/config/projects/sedir/.cc-images/…png
  // Yani iki ayrı şey YAPIŞIK: WhatsApp'ın panoya bıraktığı işe yaramaz `blob:`
  // metni + bizim yazdığımız gerçek dosya yolu.
  //
  // NİÇİN ESKİ ÇÖZÜM GERİ ALINDI: 0.5/0.6'da yapıştırmayı tamamen devralmıştık
  // (preventDefault). WhatsApp düzeldi ama akar kutusunda DÜZ METİN YAPIŞTIRMA
  // ÖLDÜ — tarayıcı ucu sunucudan sınanamadığı için kusur ancak Sultan bildirince
  // görüldü. O yüzden burada yapıştırmaya HİÇ dokunulmuyor.
  //
  // BU ÇÖZÜM: yapıştırma anına değil, ÖNCESİNE müdahale eder. Sekmeye dönüldüğü
  // anda pano yoklanır; içinde HEM resim HEM `blob:` ile başlayan bir metin varsa
  // panoya yalnız resim geri yazılır. Ctrl+V geldiğinde yapıştırılacak metin
  // kalmamıştır — yerleşik yol kendi işini yapar, biz yolu ekleriz.
  //
  // 🔴 ÜÇ EMNİYET: (a) metin `blob:` ile başlamıyorsa DOKUNULMAZ — kullanıcının
  // gerçek metni asla silinmez; (b) panoda resim yoksa DOKUNULMAZ; (c) herhangi
  // bir adım düşerse sessizce eski davranışa dönülür (fail-soft) — bu kozmetik
  // bir kusur, günlük işi riske atacak bir kapı değil.
  let sonSadelestirme = 0;

  function blobArtigiMi(metin) {
    return typeof metin === 'string' && /^\s*blob:/i.test(metin);
  }

  async function panoyuSadelestir() {
    if (!navigator.clipboard || !navigator.clipboard.read || !navigator.clipboard.write) return;
    if (typeof ClipboardItem === 'undefined') return;
    const now = Date.now();
    if (now - sonSadelestirme < 1000) return;      // sekme odağı hızlı gidip gelebilir
    try {
      const items = await navigator.clipboard.read();
      for (const it of items) {
        const types = it.types || [];
        const resimTipi = types.find((t) => t.indexOf('image/') === 0);
        if (!resimTipi) continue;                  // (b) resim yok → bizim işimiz değil
        const metinTipi = types.find((t) => t === 'text/plain');
        if (!metinTipi) return;                    // zaten sade
        const metin = await (await it.getType(metinTipi)).text();
        if (!blobArtigiMi(metin)) return;          // (a) gerçek metin → DOKUNMA
        const resim = await it.getType(resimTipi);
        await navigator.clipboard.write([new ClipboardItem({ [resimTipi]: resim })]);
        sonSadelestirme = Date.now();
        log('panodaki blob: artığı temizlendi — yapıştırma sade');
        return;
      }
    } catch (e) {                                  // (c) fail-soft
      log('pano sadeleştirilemedi, eski davranış sürüyor', e && e.message);
    }
  }

  window.addEventListener('focus', panoyuSadelestir);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) panoyuSadelestir(); });

  // Path A: native DOM paste event (fires if VS Code doesn't swallow it first).
  document.addEventListener('paste', (e) => {
    if (!terminalFocused()) return;
    const items = (e.clipboardData && e.clipboardData.items) || [];
    for (const it of items) {
      if (it.kind === 'file' && it.type && it.type.indexOf('image/') === 0) {
        const blob = it.getAsFile();
        if (blob) { e.preventDefault(); e.stopPropagation(); handleImageBlob(blob); return; }
      }
    }
  }, true);

  // Path B: Cmd/Ctrl+V keydown → read the clipboard ourselves. VS Code's terminal
  // paste is a command (may not emit a DOM paste event).
  //
  document.addEventListener('keydown', async (e) => {
    const isPaste = (e.key === 'v' || e.key === 'V') && (e.metaKey || e.ctrlKey) && !e.altKey && !e.shiftKey;
    if (!isPaste || !terminalFocused()) return;
    if (!navigator.clipboard || !navigator.clipboard.read) return;

    // 🔴 DEVRALMA GERİ ALINDI (2026-08-26, Sultan bildirdi — CANLI REGRESYON).
    // v0.5/0.6'da burada preventDefault çağırıp yapıştırmayı TAMAMEN devralıyorduk.
    // WhatsApp çift-yapıştırması düzeldi AMA akar kutusunda DÜZ METİN YAPIŞTIRMA
    // ÇALIŞMAZ oldu: devraldıktan sonra metni kendimiz yazma yolu Sultan'ın
    // tarayıcısında tutmadı ve yapıştırma tamamen kayboldu.
    // Ders: tarayıcı ucu sunucudan sınanamıyor; sınanamayan bir yolda kullanıcının
    // GÜNLÜK işini (metin yapıştırma) riske atmak, kozmetik bir kusurdan beterdir.
    // Bu yüzden eski, kanıtlanmış davranışa dönüldü: preventDefault YOK — resim
    // varsa yolu EKLERİZ, metin yapıştırma yerleşik yoldan aynen çalışır.
    // Çift-yapıştırma kusuru geri geldi ve AÇIK kayıtlıdır (L79 kardeşi ayrı iş):
    // güvenli çözüm, senkron karar verebilmek için pano-durumunu ÖNCEDEN yoklamak.
    try {
      const items = await navigator.clipboard.read();
      for (const it of items) {
        const type = (it.types || []).find((t) => t.indexOf('image/') === 0);
        if (type) { const blob = await it.getType(type); handleImageBlob(blob); return; }
      }
    } catch (err) {
      log('clipboard.read failed (permission?) — Path A may still work', err && err.message);
    }
  }, true);

  // ===========================================================================
  // SESLİ DİKTE — köşedeki 🎤 butonu (dokun/tıkla: başlat→durdur) ya da
  // Ctrl/Cmd+Shift+M. Tarayıcı mikrofonundan kayıt → /voice (Groq Whisper) →
  // metin odaktaki terminale insertText() ile yazılır (Enter'ı kullanıcı basar).
  // Buton iPhone Safari'de DOKUNMATİK çalışır (orada Cmd tuşu yok); masaüstünde
  // ayrıca hotkey var. vekatip'te tamamen kapalı (Groq erişimi yok).
  // ===========================================================================
  let micBtn = null;
  let recording = false;
  let mediaRec = null;
  let audioChunks = [];
  let micStream = null;

  function setMicState(s) {
    if (!micBtn) return;
    if (s === 'rec') { micBtn.textContent = '⏺'; micBtn.style.background = '#b62324'; micBtn.style.transform = 'scale(1.08)'; }
    else if (s === 'busy') { micBtn.textContent = '⏳'; micBtn.style.background = '#1f6feb'; micBtn.style.transform = 'none'; }
    else { micBtn.textContent = '🎤'; micBtn.style.background = '#1e1e1e'; micBtn.style.transform = 'none'; }
  }

  function ensureMicButton() {
    if (IS_VOICE_OFF || micBtn || !document.body) return;
    micBtn = document.createElement('button');
    micBtn.type = 'button';
    micBtn.tabIndex = -1; // never part of tab order
    micBtn.setAttribute('aria-label', 'Sesli dikte');
    micBtn.title = 'Sesli dikte — dokun/tıkla: başlat→durdur (Ctrl/Cmd+Shift+M)';
    micBtn.textContent = '🎤';
    micBtn.style.cssText = 'position:fixed;left:16px;bottom:16px;z-index:2147483647;width:46px;height:46px;border-radius:50%;border:1px solid #444;background:#1e1e1e;color:#eee;font-size:20px;line-height:1;padding:0;cursor:pointer;display:flex;align-items:center;justify-content:center;box-shadow:0 6px 20px rgba(0,0,0,.45);transition:background .15s,transform .1s;-webkit-tap-highlight-color:transparent';
    // Keep the terminal focused on desktop click (mousedown would otherwise move
    // focus to the button). On touch, focus may still shift → focusTerminal()
    // re-targets before insert.
    micBtn.addEventListener('mousedown', (e) => e.preventDefault());
    micBtn.addEventListener('click', (e) => { e.preventDefault(); toggleRecording(); });
    document.body.appendChild(micBtn);
    log('mic button ready');
  }

  async function toggleRecording() {
    if (IS_VOICE_OFF) return;
    if (recording) { stopRecording(); return; }
    await startRecording();
  }

  async function startRecording() {
    if (recording) return;
    focusTerminal(); // snapshot/restore terminal target before mic prompt
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || !window.MediaRecorder) {
      voiceToast('✗ tarayıcı ses kaydını desteklemiyor', '#ff7b72', 6000);
      return;
    }
    try {
      micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (e) {
      voiceToast('🎤 mikrofon izni verilmedi', '#ff7b72', 6000);
      log('getUserMedia failed', e && e.message);
      return;
    }
    let mime = '';
    for (const c of ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4', 'audio/aac', 'audio/ogg']) {
      try { if (MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(c)) { mime = c; break; } } catch (e) {}
    }
    try { mediaRec = mime ? new MediaRecorder(micStream, { mimeType: mime }) : new MediaRecorder(micStream); }
    catch (e) { mediaRec = new MediaRecorder(micStream); }
    audioChunks = [];
    mediaRec.ondataavailable = (e) => { if (e.data && e.data.size) audioChunks.push(e.data); };
    mediaRec.onstop = onRecordingStop;
    mediaRec.start();
    recording = true;
    setMicState('rec');
    voiceToast('🎤 dinliyor… durdurmak için tekrar dokun', '#ff7b72', 60000);
    log('recording started', mime || '(default)');
  }

  function stopRecording() {
    if (!recording || !mediaRec) return;
    recording = false;
    setMicState('busy');
    try { mediaRec.stop(); } catch (e) {}
  }

  function releaseMic() {
    try { if (micStream) micStream.getTracks().forEach((t) => t.stop()); } catch (e) {}
    micStream = null;
  }

  async function onRecordingStop() {
    const type = (mediaRec && mediaRec.mimeType) || (audioChunks[0] && audioChunks[0].type) || 'audio/webm';
    const blob = new Blob(audioChunks, { type });
    audioChunks = [];
    releaseMic();
    if (!blob.size) { voiceToast('✗ ses alınamadı', '#ff7b72', 5000); setMicState('idle'); return; }
    voiceToast('⏳ yazıya çevriliyor…', '#79c0ff', 60000);
    try {
      const resp = await fetch(VOICE_URL, {
        method: 'POST',
        headers: { 'X-Requested-With': 'dashboard', 'Content-Type': type },
        body: blob,
      });
      const data = await resp.json().catch(() => null);
      if (resp.ok && data && data.ok && typeof data.text === 'string') {
        const text = data.text.trim();
        if (text) {
          focusTerminal();
          insertText(text + ' ');
          voiceToast('✓ yazıldı — gözden geçir, Enter ile gönder', '#7ee787', 3500);
          log('transcribed', JSON.stringify(text).slice(0, 160));
        } else {
          voiceToast('… ses boş / algılanmadı', '#d29922', 4000);
        }
      } else {
        voiceToast('✗ ' + ((data && data.error) || ('HTTP ' + resp.status)), '#ff7b72', 8000);
        log('voice failed', data);
      }
    } catch (e) {
      voiceToast('✗ ' + e.message, '#ff7b72', 8000);
      log('voice error', e);
    } finally {
      setMicState('idle');
    }
  }

  // Desktop push-to-talk hotkey (toggle): Ctrl/Cmd+Shift+M. Capture-phase so it
  // wins over VS Code when the terminal is focused; doesn't touch Cmd+V (images).
  document.addEventListener('keydown', (e) => {
    if (IS_VOICE_OFF) return;
    if (!(e.metaKey || e.ctrlKey) || !e.shiftKey || e.altKey || e.code !== 'KeyM') return;
    if (!recording && !terminalFocused()) return; // start only from terminal; stop from anywhere
    e.preventDefault();
    e.stopPropagation();
    toggleRecording();
  }, true);

  // Voice status toast (separate from the image preview box so they don't clash).
  let vbox = null;
  function voiceToast(msg, color, ttl) {
    if (!vbox) {
      vbox = document.createElement('div');
      vbox.style.cssText = 'position:fixed;left:16px;bottom:72px;z-index:2147483647;background:#1e1e1e;border:1px solid #444;border-radius:8px;padding:8px 10px;box-shadow:0 6px 20px rgba(0,0,0,.45);font:12px -apple-system,BlinkMacSystemFont,sans-serif;max-width:260px;pointer-events:none';
      document.body.appendChild(vbox);
    }
    vbox.textContent = msg;
    vbox.style.color = color || '#ddd';
    vbox.style.display = 'block';
    clearTimeout(vbox._t);
    vbox._t = setTimeout(() => { vbox.style.display = 'none'; }, ttl || 4000);
  }

  // Mount the mic button now and keep it alive across code-server re-renders.
  ensureMicButton();
  if (!IS_VOICE_OFF) {
    setInterval(() => {
      if (!micBtn || !document.body.contains(micBtn)) { micBtn = null; ensureMicButton(); }
    }, 5000);
  }

  // --- preview overlay (bottom-right) ---
  let box;
  function ensureBox() {
    if (box) return box;
    box = document.createElement('div');
    box.style.cssText = 'position:fixed;right:16px;bottom:16px;z-index:2147483647;background:#1e1e1e;border:1px solid #444;border-radius:8px;padding:8px;box-shadow:0 6px 20px rgba(0,0,0,.45);font:12px -apple-system,BlinkMacSystemFont,sans-serif;color:#ddd;max-width:240px;pointer-events:none';
    document.body.appendChild(box);
    return box;
  }
  function showPreview(blob) {
    const b = ensureBox();
    if (b._url) { try { URL.revokeObjectURL(b._url); } catch (e) {} }
    const url = URL.createObjectURL(blob);
    b._url = url;
    b.innerHTML = '';
    const img = document.createElement('img');
    img.src = url;
    img.style.cssText = 'max-width:220px;max-height:140px;border-radius:4px;display:block';
    const cap = document.createElement('div');
    cap.textContent = '⬆ yükleniyor…';
    cap.style.cssText = 'margin-top:6px;color:#aaa';
    b.appendChild(img);
    b.appendChild(cap);
    b._cap = cap;
    b.style.display = 'block';
    clearTimeout(b._t);
  }
  function flash(state, msg) {
    const b = ensureBox();
    const cap = b._cap || b;
    if (state === 'ok') { cap.textContent = '✓ yol terminale eklendi — Enter ile gönder'; cap.style.color = '#7ee787'; }
    else if (state === 'clip') { cap.textContent = '📋 yol panoda — terminale Cmd+V'; cap.style.color = '#79c0ff'; }
    else { cap.textContent = '✗ ' + (msg || 'hata'); cap.style.color = '#ff7b72'; }
    clearTimeout(b._t);
    b._t = setTimeout(() => {
      if (b._url) { try { URL.revokeObjectURL(b._url); } catch (e) {} b._url = null; }
      b.style.display = 'none';
    }, state === 'ok' ? 3000 : 7000);
  }
})();
