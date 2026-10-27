// dumen.mjs — ajanın Dümen Chrome'unu SÜRDÜĞÜ tek yol: eylem kapısı + durma noktası + metin dışı alan dinleyicisi.
// Karar belgesi: Nexus _agents/hezarfen/bilgi-havuzu/dumen-arastirma-20261027/KARAR.md (Z8E7K7 · JN1K8K).
//   - Ham page.evaluate / ham CDP ajana VERİLMEZ: yalnız bu sarmalayıcının eylemleri vardır.
//   - FAIL-CLOSED: mod okunamadıysa ya da 'ajan' değilse eylem YAPILMAZ (reddedilir).
//   - Parola/telefon/tek kullanımlık kod/kart alanında eylem YAPILMAZ: durma noktası bildirilir, ajan durur.
//   - Dinleyici izole dünyada (sayfa betiklerinden önce, window capture) kurulur; binding sayfaya görünmez.
//     Dinleyici yalnız KAYIT/UYARIdır (sayfa sahte olay üretebilir → yanlış alarm; eylemi gizleyemez). Karar kapısı bu dosyadaki kapıdır.
import { createRequire } from 'module';

export class KapiHata extends Error {
  constructor(neden, ayrinti = '') { super(`dumen-kapi: ${neden}${ayrinti ? ' — ' + ayrinti : ''}`); this.neden = neden; }
}

const ADAYLAR = [process.env.DUMEN_PLAYWRIGHT, '/config/projects/vekatip/node_modules/playwright-core', '/config/projects/Nexus/ui/node_modules/playwright-core'].filter(Boolean);
export async function playwrightYukle() {
  try { return await import('playwright-core'); } catch { /* aday yollar */ }
  for (const a of ADAYLAR) {
    try { return createRequire(a.endsWith('package.json') ? a : a + '/package.json')('playwright-core'); } catch { /* sonraki */ }
  }
  throw new KapiHata('playwright-yok', 'DUMEN_PLAYWRIGHT=<playwright-core dizini> ver');
}

const HASSAS_TUR = new Set(['password', 'tel']);
const HASSAS_OTOTAMAM = /one-time-code|cc-(number|csc|exp)|current-password|new-password/i;
const HASSAS_AD = /(otp|sms|parola|sifre|şifre|password|passwd|cvv|cvc|iban|kart.?no|card.?number)/i;
const GONDER_METIN = /(öde|ode|satın al|satin al|onayla|gönder|gonder|confirm|pay|purchase|submit order)/i;
const ODEME_YOL = /(checkout|odeme|ödeme|payment|3d-?secure)/i;

export class Dumen {
  constructor({ page, cdp, merkez, zamanAsimiMs = 3000, yaz = (s) => console.log(s) }) {
    Object.assign(this, { page, cdp, merkez: merkez.replace(/\/$/, ''), zamanAsimiMs, yaz });
    this.olaylar = []; this.pencereler = []; this.sayac = 0;
  }

  static async baglan({ cdpUrl, merkez, zamanAsimiMs, yaz }) {
    const { chromium } = await playwrightYukle();
    const tarayici = await chromium.connectOverCDP(cdpUrl);
    const ctx = tarayici.contexts()[0] || await tarayici.newContext();
    const page = ctx.pages()[0] || await ctx.newPage();
    const d = new Dumen({ page, cdp: await ctx.newCDPSession(page), merkez, zamanAsimiMs, yaz });
    d.tarayici = tarayici;
    await d.dinleyiciKur();
    return d;
  }

  async dinleyiciKur() {
    const kaynak = `(()=>{const gizli=t=>/password|tel/.test(t.type||'')||/one-time-code|cc-|password/i.test(t.autocomplete||'')||/(otp|sms|parola|sifre|şifre|password|cvv|cvc|iban|kart)/i.test((t.name||'')+(t.id||''));`
      + `const g=e=>{const t=e.target;if(!t||!t.tagName)return;window.__dumenBekci(JSON.stringify({o:e.type,id:t.id||t.name||'',tur:t.type||t.tagName,trusted:e.isTrusted,deger:gizli(t)?'<gizli>':String(t.value??t.checked)}))};`
      + `window.addEventListener('input',g,true);window.addEventListener('change',g,true);})();`;
    await this.cdp.send('Runtime.enable');
    await this.cdp.send('Page.enable');
    await this.cdp.send('Runtime.addBinding', { name: '__dumenBekci', executionContextName: 'dumen-bekci' });
    this.cdp.on('Runtime.bindingCalled', (e) => { try { this.olaylar.push({ ...JSON.parse(e.payload), t: Date.now() }); } catch { /* bozuk yük yok sayılır */ } });
    await this.cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: kaynak, worldName: 'dumen-bekci' });
    await this.page.reload().catch(() => {});   // mevcut belgeye de uygulansın
  }

  async modOku() {
    try {
      const r = await fetch(`${this.merkez}/dumen/mod`, { signal: AbortSignal.timeout(this.zamanAsimiMs) });
      if (!r.ok) throw new Error('http ' + r.status);
      const j = await r.json();
      return j.mod;
    } catch (e) { throw new KapiHata('merkez-cevapsiz', String(e.message || e)); }   // fail-closed
  }

  async kapi(eylemAdi, hedef) {
    const mod = await this.modOku();
    if (mod !== 'ajan') {
      this.yaz("⏸ Dümen Sultan'da · bekliyorum");
      throw new KapiHata('sultanda', `mod=${mod}`);
    }
    const neden = await this.durmaNoktasi(eylemAdi, hedef);
    if (neden) {
      await this.durakBildir(neden);
      this.yaz(`⏸ Dümen: ${neden} alanında durdum · Dümeni al`);
      throw new KapiHata('durak', neden);
    }
  }

  async durmaNoktasi(eylemAdi, hedef) {
    if (eylemAdi === 'goto') return null;
    if (ODEME_YOL.test(this.page.url()) && /click|press/.test(eylemAdi)) {
      const metin = hedef ? await this.page.locator(hedef).first().innerText({ timeout: 1500 }).catch(() => '') : '';
      if (GONDER_METIN.test(metin)) return 'odeme';
    }
    if (!hedef) return null;
    const bilgi = await this.page.locator(hedef).first().evaluate((el) => ({
      tur: (el.type || '').toLowerCase(), oto: el.autocomplete || '', ad: (el.name || '') + ' ' + (el.id || ''),
      etiket: el.tagName, metin: (el.innerText || el.value || '').slice(0, 60),
    }), { timeout: 1500 }).catch(() => null);
    if (!bilgi) return null;
    if (HASSAS_TUR.has(bilgi.tur) || HASSAS_OTOTAMAM.test(bilgi.oto) || HASSAS_AD.test(bilgi.ad)) {
      return bilgi.tur === 'tel' || /otp|sms|one-time/i.test(bilgi.ad + bilgi.oto) ? 'sms' : (/cc-|cvv|cvc|kart|card|iban/i.test(bilgi.ad + bilgi.oto) ? 'odeme' : 'sifre');
    }
    if (/click/.test(eylemAdi) && GONDER_METIN.test(bilgi.metin) && ODEME_YOL.test(this.page.url())) return 'odeme';
    return null;
  }

  async durakBildir(neden) {
    // yalnız neden sözcüğü gider (şifre·sms·odeme·gonder) — alan değeri, adres, çerez ASLA
    try {
      await fetch(`${this.merkez}/api/dumen/durak`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ neden }), signal: AbortSignal.timeout(this.zamanAsimiMs) });
    } catch { /* bildirim yolu kopuksa da eylem YAPILMAZ; yukarıdaki fırlatma sürer */ }
  }

  async #uygula(ad, hedef, fn) {
    await this.kapi(ad, hedef);
    const p = { id: ++this.sayac, ad, hedef, t0: Date.now() };
    try { return await fn(); }
    finally { await new Promise((r) => setTimeout(r, 120)); p.t1 = Date.now(); this.pencereler.push(p); }
  }

  goto(url, o) { return this.#uygula('goto', null, () => this.page.goto(url, o)); }
  fill(sel, v, o) { return this.#uygula('fill', sel, () => this.page.fill(sel, v, o)); }
  selectOption(sel, v, o) { return this.#uygula('selectOption', sel, () => this.page.selectOption(sel, v, o)); }
  check(sel, o) { return this.#uygula('check', sel, () => this.page.check(sel, o)); }
  click(sel, o) { return this.#uygula('click', sel, () => this.page.click(sel, o)); }
  press(sel, k, o) { return this.#uygula('press', sel, () => this.page.press(sel, k, o)); }

  // ajan eylem penceresine düşen olay = ajanın; düşmeyen = insan ya da sayfa (kaynak eşlemesi — isTrusted ayırıcı DEĞİLDİR)
  eslesmis() { return this.olaylar.filter((o) => this.pencereler.some((p) => o.t >= p.t0 && o.t <= p.t1 + 50)); }
  yabanci() { return this.olaylar.filter((o) => !this.pencereler.some((p) => o.t >= p.t0 && o.t <= p.t1 + 50)); }
  async kapat() { await this.tarayici?.close().catch(() => {}); }
}
