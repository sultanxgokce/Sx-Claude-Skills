// dumen.mjs — ajanın Dümen Chrome'unu SÜRDÜĞÜ tek yol: eylem kapısı + durma noktası + metin dışı alan dinleyicisi.
// Karar belgesi: Nexus _agents/hezarfen/bilgi-havuzu/dumen-arastirma-20261027/KARAR.md (Z8E7K7 · JN1K8K).
//   - Ham page.evaluate / ham CDP ajana VERİLMEZ: yalnız bu sarmalayıcının eylemleri vardır.
//   - FAIL-CLOSED: mod okunamadıysa ya da 'ajan' değilse eylem YAPILMAZ (reddedilir).
//   - Parola/telefon/tek kullanımlık kod/kart alanında eylem YAPILMAZ: durma noktası bildirilir, ajan durur.
//   - Dinleyici izole dünyada (sayfa betiklerinden önce, window capture) kurulur; binding sayfaya görünmez.
//     Dinleyici yalnız KAYIT/UYARIdır (sayfa sahte olay üretebilir → yanlış alarm; eylemi gizleyemez). Karar kapısı bu dosyadaki kapıdır.
import { createRequire } from 'module';
import { readFileSync, realpathSync, statSync, lstatSync, writeFileSync, existsSync } from 'fs';
import { createHash } from 'crypto';
import { basename, dirname, extname, join, resolve, sep } from 'path';

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

// Merkez durak ucu defter jetonu ister (x-defter-jeton). Jeton dosyadan okunur, ASLA yazdırılmaz/günlüğe girmez.
function jetonOku() {
  try { return readFileSync(process.env.DUMEN_DEFTER_JETON || '/config/defter-jeton', 'utf8').trim() || null; } catch { return null; }
}
const KOPMA = /(closed|disconnected|ECONNRESET|ECONNREFUSED|socket|Target page|Connection terminated)/i;

const HASSAS_TUR = new Set(['password', 'tel']);
const HASSAS_OTOTAMAM = /one-time-code|cc-(number|csc|exp)|current-password|new-password/i;
const HASSAS_AD = /(otp|sms|parola|sifre|şifre|password|passwd|cvv|cvc|iban|kart.?no|card.?number)/i;
const GONDER_METIN = /(öde|ode|satın al|satin al|onayla|gönder|gonder|confirm|pay|purchase|submit order)/i;
const ODEME_YOL = /(checkout|odeme|ödeme|payment|3d-?secure)/i;
// 0.9.0 DOSYA: yükleme/indirme yalnız izinli dizinde, izinli türde, tavanlı boyutta; sır taşıyabilecek yol HİÇBİR koşulda geçmez.
const DOSYA_TAVAN = 50 * 1024 * 1024;
const DOSYA_TUR = new Set(['.pdf', '.png', '.jpg', '.jpeg', '.webp', '.gif', '.csv', '.xlsx', '.xls', '.txt', '.zip', '.xml']);
const DOSYA_YASAK = /(^|\/)(\.ssh|\.gnupg|\.claude|\.aws|\.filo|credentials?|secrets?)(\/|$)|(^|\/)\.env|jeton|token|parola|sifre|\.pem$|\.key$|id_(rsa|ed25519)/i;
const SIHIR = { '.pdf': [0x25, 0x50, 0x44, 0x46], '.png': [0x89, 0x50, 0x4e, 0x47], '.jpg': [0xff, 0xd8, 0xff], '.jpeg': [0xff, 0xd8, 0xff], '.gif': [0x47, 0x49, 0x46], '.zip': [0x50, 0x4b], '.xlsx': [0x50, 0x4b] };
const CEREZ_BAGLAM = '(çerez|cerez|cookie)';
const CEREZ_RED = '^(reddet|tümünü reddet|hepsini reddet|tüm çerezleri reddet|reject all|reject|decline|yalnızca gerekli|yalnızca gerekli çerezler|only necessary)$';
const CEREZ_KABUL = '^(kabul et|tümünü kabul et|hepsini kabul et|accept all|accept)$';
const TUR_GEC = '^(turu geç|turu gec|turu atla|turu kapat|skip tour|skip the tour)$';
const ANKET_SEC = ['iframe[src*="qualaroo" i]', 'iframe[id*="qualaroo" i]', '[id^="qual_ol"]'];
const uyu = (ms) => new Promise((r) => setTimeout(r, ms));

export class Dumen {
  // Ham nesneler ÖZELDİR (#): çağıran d.page / d.cdp / d.tarayici ile kapıyı atlayamaz. Zorlama yine de köprüdedir (SKILL.md).
  #page; #cdp; #tarayici; #cdpUrl; #merkez; #zamanAsimiMs; #yaz; #olaylar = []; #uyarilar = []; #uyariVerilen = new Set(); #aktif = 0; #iletimler = new Set(); #pencereler = []; #sayac = 0; #kopuk = false; #baglanmaSayisi = 0; #sekme; #hedefId = null; #kendiSekmem = false; #eylemAzamiMs; #dosyaKok; #acilanlar = new Set(); #kapandi = false; #eylemSureMs;
  constructor({ cdpUrl, merkez, zamanAsimiMs = 3000, yaz = (s) => console.log(s), sekme, eylemAzamiMs = 45000, eylemSureMs = 15000, dosyaKok }) {
    this.#eylemSureMs = eylemSureMs; this.#eylemAzamiMs = eylemAzamiMs; this.#dosyaKok = dosyaKok; this.#sekme = sekme; this.#cdpUrl = cdpUrl; this.#merkez = merkez.replace(/\/$/, ''); this.#zamanAsimiMs = zamanAsimiMs; this.#yaz = yaz;
  }

  // sekme: yok/'yeni' → YENİ sekme açılır (varsayılan: Sultan'ın sekmelerine dokunulmaz) · 'ilk' → ilk sekme (eski davranış, açıkça istenir)
  //        · string (adres parçası) ya da RegExp → adresi eşleşen sekme, yoksa yeni sekme. kapat() yalnız KENDİ açtığı sekmeyi kapatır.
  // eylemSureMs (15 sn): tek bir eylemin öğeyi bekleme süresi · eylemAzamiMs (45 sn): eylemin kapı dahil SERT tavanı · dosyaKok: yükleme/indirme için izinli dizin(ler)
  static async baglan({ cdpUrl, merkez, zamanAsimiMs, yaz, sekme, eylemAzamiMs, eylemSureMs, dosyaKok }) {
    const d = new Dumen({ cdpUrl, merkez, zamanAsimiMs, yaz, sekme, eylemAzamiMs, eylemSureMs, dosyaKok });
    await d.#sureli('baglan', null, () => d.#bagla(), 60000);   // bağlanma da asılamaz
    return d;
  }

  // 0.9.0 KAPAT GARANTİSİ: bağlan → işi koş → HER koşulda kapat (hata, süre dolması, SIGTERM/SIGINT). Artık sekme kalmaz.
  //   await Dumen.kos({ cdpUrl, merkez, dosyaKok }, async (d) => { … }, { toplamAzamiMs: 300000 })
  static async kos(secenek, is, { toplamAzamiMs = 300000 } = {}) {
    const d = await Dumen.baglan(secenek);
    const sinyal = () => { d.kapat().finally(() => process.exit(143)); };
    process.once('SIGTERM', sinyal); process.once('SIGINT', sinyal);
    try { return await d.#sureli('toplam', null, () => is(d), toplamAzamiMs); }
    finally { process.off('SIGTERM', sinyal); process.off('SIGINT', sinyal); await d.kapat(); }
  }

  // SERT SÜRE SINIRI: hiçbir eylem ya da okuma bundan uzun süremez (5 Kas: tıklama sonrası 80-85 sn yanıtsız kalış, iki kez).
  // Süre dolunca KapiHata('zaman-asimi'); sayfanın hâli BİLİNMEZ — çağıran kare()/adres() ile ölçer, körlemesine yinelemez.
  #sureli(ad, hedef, fn, ms = this.#eylemAzamiMs) {
    let z; const is = Promise.resolve().then(fn); is.catch(() => {});   // süre dolduktan sonra gelen ret sahipsiz kalmasın
    const sinir = new Promise((_, red) => { z = setTimeout(() => red(new KapiHata('zaman-asimi', `${ad}${hedef ? ' ' + hedef : ''}: ${ms} ms içinde bitmedi — sayfanın hâli BİLİNMİYOR; kare() ve adres() ile ölç, körlemesine yineleme`)), ms); });
    return Promise.race([is, sinir]).finally(() => clearTimeout(z));
  }

  async #bagla() {
    const { chromium } = await playwrightYukle();
    const tarayici = await chromium.connectOverCDP(this.#cdpUrl, { timeout: 20000 });
    const ctx = tarayici.contexts()[0] || await tarayici.newContext();
    const hedefId = async (p) => { const o = await ctx.newCDPSession(p); try { return (await o.send('Target.getTargetInfo')).targetInfo.targetId; } finally { await o.detach().catch(() => {}); } };
    let page = null;
    if (this.#hedefId) {   // yeniden bağlanma: AYNI sekmeye dön — öteki sekmelere oturum AÇILMAZ: aranan sekmenin adresi /json/list'ten (tek sorgu) okunur, oturum YALNIZ aynı adresli adaylarda kimlik doğrulaması için açılır
      let liste = null;
      try { const r = await fetch(`${this.#cdpUrl.replace(/\/$/, '')}/json/list`, { signal: AbortSignal.timeout(this.#zamanAsimiMs) }); if (r.ok) liste = await r.json(); } catch { liste = null; }
      const kayit = liste ? liste.find((t) => t.id === this.#hedefId && t.type === 'page') : null;
      // liste okunamadı ya da sekme kapanmış → hiçbir sekmeye oturum açılmaz; aşağıda seçim ilkesiyle (yeni sekme / desen) sekme seçilir
      const adaylar = kayit ? ctx.pages().filter((p) => p.url() === kayit.url) : [];
      for (const p of adaylar) { if (await hedefId(p).catch(() => null) === this.#hedefId) { page = p; break; } }
    }
    if (!page) {
      const s = this.#sekme;
      if (s === 'ilk') { page = ctx.pages()[0] || null; this.#kendiSekmem = false; }
      else if (typeof s === 'string' && s !== 'yeni') { page = ctx.pages().find((p) => p.url().includes(s)) || null; this.#kendiSekmem = false; }
      else if (s instanceof RegExp) { const re = new RegExp(s.source, s.flags); page = ctx.pages().find((p) => re.test(p.url())) || null;   // çağıranın nesnesi değil taze kopya: g/y lastIndex taşımaz, bayrak anlamı korunur
        this.#kendiSekmem = false; }
      if (!page) { page = await ctx.newPage(); this.#kendiSekmem = true; }
    }
    this.#tarayici = tarayici; this.#page = page; this.#cdp = await ctx.newCDPSession(page);
    page.setDefaultTimeout(this.#eylemSureMs); page.setDefaultNavigationTimeout(30000);   // süresiz eylem YOK: örtülü öğeye tıklama sonsuza dek yeniden denemez
    page.on('popup', (s) => { this.#acilanlar.add(s); s.once('close', () => this.#acilanlar.delete(s)); });   // kendi tıklamamın açtığı sekmeler: kapat() bunları da toplar
    this.#hedefId = await hedefId(page).catch(() => this.#hedefId);
    tarayici.on('disconnected', () => { if (this.#tarayici === tarayici) this.#kopuk = true; });
    this.#kopuk = false; this.#baglanmaSayisi++;
    await this.dinleyiciKur();   // yeniden bağlanınca sayfa yeniden okunur (reload) — insan eylemi aktarılmaz
  }

  async #yenidenBagla() {
    await this.#tarayici?.close().catch(() => {});
    try { await this.#bagla(); } catch (e) { throw new KapiHata('baglanti-yok', String(e.message || e)); }
  }

  // salt-okur durum: kapıyı atlatmaz (ham nesne vermez)
  durum() { return { kopuk: this.#kopuk, baglanmaSayisi: this.#baglanmaSayisi }; }

  async dinleyiciKur() {
    const kaynak = `(()=>{const gizli=t=>/password|tel/.test(t.type||'')||/one-time-code|cc-|password/i.test(t.autocomplete||'')||/(otp|sms|parola|sifre|şifre|password|cvv|cvc|iban|kart)/i.test((t.name||'')+(t.id||''));`
      + `const g=e=>{const t=e.target;if(!t||!t.tagName)return;window.__dumenBekci(JSON.stringify({o:e.type,id:t.id||t.name||'',tur:t.type||t.tagName,trusted:e.isTrusted,deger:gizli(t)?'<gizli>':String(t.value??t.checked)}))};`
      + `window.addEventListener('input',g,true);window.addEventListener('change',g,true);})();`;
    await this.#cdp.send('Runtime.enable');
    await this.#cdp.send('Page.enable');
    await this.#cdp.send('Runtime.addBinding', { name: '__dumenBekci', executionContextName: 'dumen-bekci' });
    this.#cdp.on('Runtime.bindingCalled', (e) => { try { this.#olaylar.push({ ...JSON.parse(e.payload), t: Date.now() }); setTimeout(() => this.#yabanciTara(), 450).unref?.(); } catch { /* bozuk yük yok sayılır */ } });
    await this.#cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: kaynak, worldName: 'dumen-bekci' });
    await this.#page.reload().catch(() => {});   // mevcut belgeye de uygulansın
  }

  async modOku() {
    try {
      const r = await fetch(`${this.#merkez}/dumen/mod`, { signal: AbortSignal.timeout(this.#zamanAsimiMs) });
      if (!r.ok) throw new Error('http ' + r.status);
      const j = await r.json();
      return j.mod;
    } catch (e) { throw new KapiHata('merkez-cevapsiz', String(e.message || e)); }   // fail-closed
  }

  async kapi(eylemAdi, hedef) {
    this.#yabanciTara();   // önceki eylemlerden sonra gelen eylem-dışı değişiklikler burada uyarıya döner
    const mod = await this.modOku();
    if (mod !== 'ajan') {
      this.#yaz("⏸ Dümen Sultan'da · bekliyorum");   // mod sultan iken köprü soketi düşer (okuma dahil): hata değil, bekleme; yeniden bağlanma YOK
      throw new KapiHata('sultanda', `mod=${mod}`);
    }
    if (this.#kopuk) await this.#yenidenBagla();   // mod ajan'a döndü ve soket düşmüştü → ancak şimdi yeniden bağlan
    const neden = await this.durmaNoktasi(eylemAdi, hedef);
    if (neden) {
      const bildirildi = await this.durakBildir(neden);
      this.#yaz(bildirildi ? `⏸ Dümen: ${neden} alanında durdum · Dümeni al` : `⏸ Dümen: ${neden} alanında durdum · ⚠ merkeze İLETİLEMEDİ, Sultan haberdar değil`);
      const h = new KapiHata('durak', neden); h.bildirildi = bildirildi; throw h;
    }
  }

  async durmaNoktasi(eylemAdi, hedef) {
    if (eylemAdi === 'goto') return null;
    if (ODEME_YOL.test(this.#page.url()) && /click|press/.test(eylemAdi)) {
      const metin = hedef ? await this.#page.locator(hedef).first().innerText({ timeout: 1500 }).catch(() => '') : '';
      if (GONDER_METIN.test(metin)) return 'odeme';
    }
    if (!hedef) return null;
    const bilgi = await this.#page.locator(hedef).first().evaluate((el) => ({
      tur: (el.type || '').toLowerCase(), oto: el.autocomplete || '', ad: (el.name || '') + ' ' + (el.id || ''),
      etiket: el.tagName, metin: (el.innerText || el.value || '').slice(0, 60),
    }), undefined, { timeout: 1500 }).catch(() => null);   // 0.9.0: süre seçeneği ÜÇÜNCÜ argümandır — ikinci argümanda verilince uygulanmıyor, olmayan öğede okuma/eylem 30 sn asılıyordu
    if (!bilgi) return null;
    if (HASSAS_TUR.has(bilgi.tur) || HASSAS_OTOTAMAM.test(bilgi.oto) || HASSAS_AD.test(bilgi.ad)) {
      return bilgi.tur === 'tel' || /otp|sms|one-time/i.test(bilgi.ad + bilgi.oto) ? 'sms' : (/cc-|cvv|cvc|kart|card|iban/i.test(bilgi.ad + bilgi.oto) ? 'odeme' : 'sifre');
    }
    if (/click/.test(eylemAdi) && GONDER_METIN.test(bilgi.metin) && ODEME_YOL.test(this.#page.url())) return 'odeme';
    return null;
  }

  async durakBildir(neden) {
    // yalnız neden sözcüğü gider (şifre·sms·odeme·gonder) — alan değeri, adres, çerez ASLA. → true = merkez 2xx ile aldı
    try {
      const jeton = jetonOku();
      const r = await fetch(`${this.#merkez}/api/dumen/durak`, { method: 'POST', headers: { 'content-type': 'application/json', ...(jeton ? { 'x-defter-jeton': jeton } : {}) }, body: JSON.stringify({ neden }), signal: AbortSignal.timeout(this.#zamanAsimiMs) });
      return r.ok;
    } catch { return false; }   // bildirim ulaşmasa da eylem YAPILMAZ; ama çağıran "bildirildi" sanmaz
  }

  async #uygula(ad, hedef, fn, ms) {
    await this.#sureli(ad + ' (kapı)', hedef, () => this.kapi(ad, hedef), ms);
    const p = { id: ++this.#sayac, ad, hedef, t0: Date.now() };
    this.#aktif++;
    try { return await this.#sureli(ad, hedef, fn, ms); }
    catch (e) {
      if (this.#kopuk || KOPMA.test(String(e && e.message))) {
        this.#kopuk = true;
        const mod = await this.modOku().catch(() => null);
        if (mod && mod !== 'ajan') { this.#yaz("⏸ Dümen Sultan'da · bekliyorum"); throw new KapiHata('sultanda', `mod=${mod} (soket düştü)`); }
        throw new KapiHata('baglanti-koptu', String(e.message || e));
      }
      throw e;
    }
    finally { await new Promise((r) => setTimeout(r, 120)); p.t1 = Date.now(); this.#pencereler.push(p); this.#aktif--; this.#gorulemeyenTara(p); this.#yabanciTara(); }
  }

  // her eylem seçeneğinde { azamiMs } = o eyleme özel sert süre sınırı (varsayılan baglan({ eylemAzamiMs }) = 45 sn); kalan seçenekler Playwright'a gider
  #ayir(o) { if (!o) return [undefined, undefined]; const { azamiMs, ...pw } = o; return [pw, azamiMs]; }
  goto(url, o) { const [pw, ms] = this.#ayir(o); return this.#uygula('goto', null, () => this.#page.goto(url, pw), ms); }
  fill(sel, v, o) { const [pw, ms] = this.#ayir(o); return this.#uygula('fill', sel, () => this.#page.fill(sel, v, pw), ms); }
  selectOption(sel, v, o) { const [pw, ms] = this.#ayir(o); return this.#uygula('selectOption', sel, () => this.#page.selectOption(sel, v, pw), ms); }
  check(sel, o) { const [pw, ms] = this.#ayir(o); return this.#uygula('check', sel, () => this.#page.check(sel, pw), ms); }
  click(sel, o) { const [pw, ms] = this.#ayir(o); return this.#uygula('click', sel, () => this.#page.click(sel, pw), ms); }
  press(sel, k, o) { const [pw, ms] = this.#ayir(o); return this.#uygula('press', sel, () => this.#page.press(sel, k, pw), ms); }

  // SALT-OKUR (SİNAN/VADE 31 Eki): sayfa hiçbir şekilde değiştirilmez. Aynı "Dümen kimde" kapısından geçer (mod ajan değilse okuma da YOK),
  // eylem penceresi AÇMAZ (okuma eylem sayılmaz), dönen metin/kare hiçbir kütüğe, merkeze ya da terminale YAZILMAZ — yalnız çağırana döner.
  // Parola/SMS/kart alanını hedef gösteren okuma durma noktasına takılır (yazmadaki kapı okumada da geçerli). innerText giriş değerlerini içermez.
  async #okuKapi(ad, hedef) {
    await this.kapi(ad, hedef);
    if (this.#kopuk) throw new KapiHata('baglanti-koptu', 'okuma öncesi');
  }
  metin(sel = 'body', { enCok = 20000, azamiMs = 15000 } = {}) {
    return this.#sureli('metin', sel, async () => {
    await this.#okuKapi('metin', sel === 'body' ? null : sel);
    const m = await this.#page.locator(sel).first().innerText({ timeout: 5000 });
    return m.length > enCok ? m.slice(0, enCok) : m;
    }, azamiMs);
  }
  async kare(yol, { tamSayfa = false, azamiMs = 30000 } = {}) {
    if (!yol) throw new KapiHata('kare-yolu-yok', 'kare(yol) dosya yolu ister');
    return this.#sureli('kare', null, async () => {
      await this.#okuKapi('kare', null);
      await this.#page.screenshot({ path: yol, fullPage: tamSayfa, timeout: 20000 });
      return yol;
    }, azamiMs);
  }
  // 0.8.0 (pazaryeri-mesaj · BÂNİ 3 Kas): liste okuma — aynı salt-okur kapı; metin() tek öğe verirken metinler()/nitelikler() seçiciye uyan
  // ÖĞELERİN HEPSİNİ (tavanlı) verir. nitelikler() hassas nitelik adlarını (parola/çerez/jeton/kod) reddeder; adres() sayfa adresini verir (giriş sayfası tespiti).
  adres() { return this.#sureli('adres', null, async () => { await this.#okuKapi('adres', null); return this.#page.url(); }, 15000); }
  metinler(sel, { enCok = 50, enCokHarf = 2000, azamiMs = 15000 } = {}) {
    return this.#sureli('metinler', sel, async () => {
      await this.#okuKapi('metinler', sel);
      const l = await this.#page.locator(sel).allInnerTexts();
      return l.slice(0, enCok).map((m) => (m.length > enCokHarf ? m.slice(0, enCokHarf) : m));
    }, azamiMs);
  }
  async nitelikler(sel, ad, { enCok = 50 } = {}) {
    if (/password|parola|sifre|şifre|otp|sms|cookie|cerez|çerez|token|jeton|secret|cvv|cvc/i.test(String(ad))) throw new KapiHata('durak', `hassas nitelik okunmaz: ${ad}`);
    return this.#sureli('nitelikler', sel, async () => {
      await this.#okuKapi('nitelikler', sel);
      const l = this.#page.locator(sel); const n = Math.min(await l.count(), enCok); const out = [];
      for (let i = 0; i < n; i++) out.push(await l.nth(i).getAttribute(ad, { timeout: 3000 }));
      return out;
    }, 20000);
  }
  // ── 0.9.0 · DOSYA YÜKLE / İNDİR · YENİ SEKME · ENGEL · ÖĞE DURUMU (NARH fatura vakası · Sultan 5 Kas) ─────────────────
  // Hepsi AYNI kapıdan geçer (Dümen kimde + durma noktası + sert süre). Ham page/CDP yine dışarı verilmez.
  static bugun() { return new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' }); }
  static dosyaIzi(yol) { return 'dosya#' + createHash('sha256').update(readFileSync(yol)).digest('hex').slice(0, 10); }
  // YÜKLEME ONAYI (A06): yükleme dışarıya giden eylemin ön adımıdır → Sultan onayının D1 damgası ister ve damga O DOSYANIN izini taşır.
  //   "YYYY-AA-GG Sultan: <sonuç> (<kaynak> · <ref> · "<söz>" · dosya#<iz> · beyan:<AJAN>)" — onayı ÜRETME, gördüğünü aktar.
  static onayDogrula(onay, iz, bugun = Dumen.bugun()) {
    const m = /^(\d{4}-\d{2}-\d{2}) Sultan: .+\(.+ · .+ · ".+".* · beyan:(\S+)\)\s*$/.exec(String(onay || ''));
    if (!m) throw new KapiHata('onay-yok', 'yükleme Sultan onayı ister: YYYY-AA-GG Sultan: <sonuç> (<kaynak> · <ref> · "<söz>" · dosya#<iz> · beyan:<AJAN>)');
    if (m[1] !== bugun) throw new KapiHata('onay-bayat', `onay tarihi ${m[1]}, bugün ${bugun}`);
    if (!String(onay).includes(iz)) throw new KapiHata('onay-dosya', `onay bu dosyaya ait değil (beklenen iz ${iz})`);
    return { tarih: m[1], beyan: m[2] };
  }
  #kokler() {
    const ham = this.#dosyaKok ?? (process.env.DUMEN_DOSYA_KOK || '').split(':');
    const l = (Array.isArray(ham) ? ham : [ham]).filter(Boolean).map((k) => { try { return realpathSync(k); } catch { return null; } }).filter(Boolean);
    if (!l.length) throw new KapiHata('dosya-kok-yok', 'izinli dizin verilmedi: baglan({ dosyaKok: [...] }) ya da DUMEN_DOSYA_KOK=<dizin[:dizin]>');   // fail-closed
    return l;
  }
  #icinde(gercek) { return this.#kokler().some((k) => gercek.startsWith(k.endsWith(sep) ? k : k + sep)); }
  #turKumesi(turler) { return turler ? new Set([...turler].map((t) => String(t).toLowerCase())) : DOSYA_TUR; }
  #kaynakDosya(yol, turler) {   // yüklenecek dosya: var, düz dosya, izinli dizinde (bağ çözülmüş), sır yolu değil, izinli tür, tavan altı
    let g; try { g = realpathSync(resolve(String(yol))); } catch { throw new KapiHata('dosya-yok', 'dosya okunamadı'); }
    const st = statSync(g); if (!st.isFile()) throw new KapiHata('dosya-yok', 'düz dosya değil');
    if (!this.#icinde(g)) throw new KapiHata('dosya-izinsiz', 'dosya izinli dizinin dışında');
    if (DOSYA_YASAK.test(g)) throw new KapiHata('dosya-yasak', 'sır taşıyabilecek yol yüklenmez');
    const u = extname(g).toLowerCase(); if (!this.#turKumesi(turler).has(u)) throw new KapiHata('dosya-turu', `izinli tür değil: ${u || '(uzantısız)'}`);
    if (st.size === 0 || st.size > DOSYA_TAVAN) throw new KapiHata('dosya-boyut', `${st.size} bayt (izinli: 1 … ${DOSYA_TAVAN})`);
    return { yol: g, bayt: st.size, uzanti: u };
  }
  #hedefDosya(yol, { ustuneYaz = false, turler } = {}) {   // indirilecek yer: izinli dizinde, sır yolu değil, bağ değil; var olan dosya ancak açıkça istenirse ezilir
    const h = resolve(String(yol)); let dz; try { dz = realpathSync(dirname(h)); } catch { throw new KapiHata('dosya-yok', 'hedef dizin yok'); }
    const g = join(dz, basename(h));
    if (!this.#icinde(g)) throw new KapiHata('dosya-izinsiz', 'hedef izinli dizinin dışında');
    if (DOSYA_YASAK.test(g)) throw new KapiHata('dosya-yasak', 'sır taşıyabilecek yola yazılmaz');
    const u = extname(g).toLowerCase(); if (!this.#turKumesi(turler).has(u)) throw new KapiHata('dosya-turu', `izinli tür değil: ${u || '(uzantısız)'}`);
    if (existsSync(g)) { if (lstatSync(g).isSymbolicLink()) throw new KapiHata('dosya-izinsiz', 'hedef bir bağ'); if (!ustuneYaz) throw new KapiHata('dosya-var', 'hedef dosya var (ezmek için { ustuneYaz: true })'); }
    return g;
  }

  // yukle(sel, dosya, { onay }): dosyayı alana EKLER (göndermez — gönder düğmesi ayrı eylemdir ve kendi kapısından geçer).
  //   sel = input[type=file] (gizli olabilir) · { secici: true } → sel dosya penceresini açan düğmedir (input sayfada yoksa).
  //   Uzak tarayıcıda da çalışır: dosya içerik olarak taşınır (Playwright ≥ 1.40, 50 MB altı).
  async yukle(sel, dosya, { onay, turler, secici = false, olayMs = 10000, azamiMs } = {}) {
    const k = this.#kaynakDosya(dosya, turler);
    Dumen.onayDogrula(onay, Dumen.dosyaIzi(k.yol));
    await this.#uygula(secici ? 'click-yukle' : 'yukle', sel, async () => {
      if (!secici) return this.#page.setInputFiles(sel, k.yol, { timeout: 10000 });
      const pencere = this.#page.waitForEvent('filechooser', { timeout: olayMs }); pencere.catch(() => {});
      await this.#page.click(sel, { timeout: 10000 });
      let p; try { p = await pencere; } catch { throw new KapiHata('yukleme-penceresi-yok', 'tıklama dosya penceresi açmadı'); }
      await p.setFiles(k.yol);
    }, azamiMs);
    this.#yaz(`⬆ Dümen: dosya alana eklendi (${k.uzanti}, ${k.bayt} bayt) — GÖNDERME ayrı eylemdir`);   // dosya adı yazılmaz (müşteri verisi taşıyabilir)
    return { bayt: k.bayt, uzanti: k.uzanti };
  }

  // Baytları TARAYICININ İÇİNDEN al (çerez ve çıkış adresi tarayıcınınki): uzak tarayıcıda diske düşen dosyaya erişilemez, saveAs çalışmaz.
  async #baytSayfadan(sayfa, adres) {
    const r = await sayfa.evaluate(async ({ u, tavan }) => {
      try {
        const y = await fetch(u, { credentials: 'include' }); if (!y.ok) return { hata: 'http ' + y.status };
        const b = new Uint8Array(await y.arrayBuffer()); if (b.length > tavan) return { hata: 'boyut ' + b.length };
        let s = ''; for (let i = 0; i < b.length; i += 32768) s += String.fromCharCode.apply(null, b.subarray(i, i + 32768));
        return { b64: btoa(s), tur: y.headers.get('content-type') || '' };
      } catch (e) { return { hata: String((e && e.message) || e).slice(0, 80) }; }
    }, { u: adres, tavan: DOSYA_TAVAN });
    if (r.hata) throw new KapiHata('indirme-okunamadi', r.hata);
    return { veri: Buffer.from(r.b64, 'base64'), tur: r.tur };
  }
  // Yedek yol: tarayıcının ağ yığınıyla (çerezli, köken kısıtı yok) — sayfa içi fetch başka kökene takılınca.
  async #baytAgdan(adres) {
    const { frameTree } = await this.#cdp.send('Page.getFrameTree');
    const r = await this.#cdp.send('Network.loadNetworkResource', { frameId: frameTree.frame.id, url: adres, options: { disableCache: false, includeCredentials: true } });
    const k = r.resource; if (!k.success || !k.stream) throw new KapiHata('indirme-okunamadi', k.netErrorName || ('http ' + k.httpStatusCode));
    const parcalar = []; let toplam = 0;
    try {
      for (;;) {
        const o = await this.#cdp.send('IO.read', { handle: k.stream, size: 1 << 20 });
        const b = Buffer.from(o.data, o.base64Encoded ? 'base64' : 'utf8'); toplam += b.length; parcalar.push(b);
        if (toplam > DOSYA_TAVAN) throw new KapiHata('indirme-okunamadi', 'boyut tavanı aşıldı');
        if (o.eof) break;
      }
    } finally { await this.#cdp.send('IO.close', { handle: k.stream }).catch(() => {}); }
    const bas = k.headers || {}; const tur = bas['content-type'] || bas['Content-Type'] || '';
    return { veri: Buffer.concat(parcalar), tur };
  }
  async #baytAl(sayfa, adres) {
    try { return await this.#baytSayfadan(sayfa, adres); }
    catch (e) { if (!/^https?:/i.test(adres)) throw e; return this.#baytAgdan(adres); }
  }
  // İNDİRDİĞİNİ ÖLÇ: boş dosya, dosya yerine gelen sayfa (giriş ekranı/hata) ve uzantıyla uyuşmayan içerik DOSYA SAYILMAZ, diske yazılmaz.
  #dosyaYaz(hedef, veri, tur, kaynak) {
    const u = extname(hedef).toLowerCase(); const imza = SIHIR[u];
    if (!veri.length) throw new KapiHata('indirme-bos', '0 bayt geldi');
    const bas = veri.subarray(0, 300).toString('latin1').toLowerCase();
    if (/text\/html/i.test(tur) || /<!doctype html|<html[\s>]/.test(bas)) throw new KapiHata('indirme-sayfa', 'dosya yerine sayfa geldi (giriş ekranı ya da hata sayfası olabilir) — yazılmadı');
    if (imza && !imza.every((b, i) => veri[i] === b)) throw new KapiHata('indirme-tur', `içerik ${u} dosyası değil — yazılmadı`);
    writeFileSync(hedef, veri, { mode: 0o600 });
    this.#yaz(`⬇ Dümen: dosya alındı (${u}, ${veri.length} bayt)`);
    return { yol: hedef, bayt: veri.length, tur, kaynak };
  }

  // indir(sel, hedefYol): sel'e tıklar; tıklama İNDİRME başlatırsa ya da dosyayı YENİ SEKMEDE açarsa baytları alıp hedefYol'a yazar.
  //   Kendi tıklamasının açtığı sekmeyi kapatır. Hiçbiri olmazsa 'indirme-yok' (asılmaz).
  async indir(sel, hedefYol, { ustuneYaz = false, turler, olayMs = 15000, azamiMs = 60000, ...pw } = {}) {
    const hedef = this.#hedefDosya(hedefYol, { ustuneYaz, turler });
    return this.#uygula('click-indir', sel, async () => {
      const page = this.#page; let coz; const ilk = new Promise((r) => { coz = r; });
      const ind = (x) => coz({ ind: x }); const sek = (x) => coz({ sek: x });
      const acilan = []; const topla = (s) => acilan.push(s);   // bu tıklamanın açtığı HER sekme (indirme olayı sekmeden önce gelse de) kapatılır
      page.once('download', ind); page.once('popup', sek); page.on('popup', topla);
      let sekme = null;
      try {
        await page.click(sel, { timeout: 10000, ...pw });
        let o = await Promise.race([ilk, uyu(olayMs).then(() => null)]);
        if (!o) throw new KapiHata('indirme-yok', `tıklama ${olayMs} ms içinde ne indirme başlattı ne yeni sekme açtı`);
        if (o.sek) {   // yeni sekme: ya dosyayı gösterir, ya da indirmeye döner (indirme olayı açan sayfaya ya da sekmeye düşer)
          sekme = o.sek;
          const sonraki = new Promise((r) => { page.once('download', r); sekme.once('download', r); });
          await sekme.waitForLoadState('domcontentloaded', { timeout: 8000 }).catch(() => {});
          const dosyaMi = /^https?:/i.test(sekme.url());
          const d = await Promise.race([sonraki, uyu(dosyaMi ? 400 : 5000).then(() => null)]);
          if (d) o = { ind: d };
          else if (dosyaMi) { const b = await this.#baytAl(sekme, sekme.url()); return this.#dosyaYaz(hedef, b.veri, b.tur, 'yeni-sekme'); }
          else throw new KapiHata('indirme-yok', 'açılan sekme boş kaldı, indirme de başlamadı');
        }
        const d = o.ind; let b;   // saveAs/path KULLANILMAZ: Dümen'in tarayıcısı başka makinede, diske düşen dosya buradan okunamaz
        try { b = await this.#baytAl(page, d.url()); }
        catch (e) { throw new KapiHata('indirme-uzakta', `dosya tarayıcının makinesinde kaldı, baytları alınamadı (${String(e.message || e).slice(0, 80)})`); }
        finally { await d.cancel().catch(() => {}); await d.delete().catch(() => {}); }
        return this.#dosyaYaz(hedef, b.veri, b.tur, 'indirme');
      } finally { page.off('download', ind); page.off('popup', sek); page.off('popup', topla); for (const s of acilan) await s.close().catch(() => {}); }
    }, azamiMs);
  }
  // indirAdres(adres, hedefYol): adresi bilinen dosyayı (ör. yeniSekmeAdresi() ya da nitelikler(sel,'href') ile okunan) tarayıcının oturumuyla alır.
  async indirAdres(adres, hedefYol, { ustuneYaz = false, turler, azamiMs = 60000 } = {}) {
    if (!/^https?:\/\//i.test(String(adres))) throw new KapiHata('kullanim', 'indirAdres yalnız http(s) adresi alır');
    const hedef = this.#hedefDosya(hedefYol, { ustuneYaz, turler });
    return this.#uygula('indir-adres', null, async () => { const b = await this.#baytAl(this.#page, String(adres)); return this.#dosyaYaz(hedef, b.veri, b.tur, 'adres'); }, azamiMs);
  }
  // yeniSekmeAdresi(sel): sel'e tıklar, açılan YENİ SEKMENİN adresini döndürür ve o sekmeyi kapatır (başkasının sekmesine dokunmaz).
  async yeniSekmeAdresi(sel, { olayMs = 10000, azamiMs = 30000, ...pw } = {}) {
    return this.#uygula('click-sekme', sel, async () => {
      const acilan = this.#page.waitForEvent('popup', { timeout: olayMs }); acilan.catch(() => {});
      await this.#page.click(sel, { timeout: 10000, ...pw });
      let s; try { s = await acilan; } catch { throw new KapiHata('sekme-yok', 'tıklama yeni sekme açmadı'); }
      try { for (let i = 0; i < 25 && !/^https?:/i.test(s.url()); i++) await uyu(200); return s.url(); }
      finally { await s.close().catch(() => {}); }
    }, azamiMs);
  }

  // engelKapat(): tıklamayı örten katmanları kaldırır — Escape×3 · çerez şeridi (varsayılan REDDET; düğme ancak çerez yazılı bir kutunun içindeyse) ·
  //   tanıtım turu ("Turu Geç") · anket çerçeveleri gizlenir. Çerez KABUL etmek Sultan izni ister. Ödeme sayfasında çalışmaz.
  //   { ek: ['seçici', …] } görünürse tıklanacak ek kapatma düğmeleri · { gizle: ['seçici', …] } gizlenecek ek katmanlar.
  async engelKapat({ cerez = 'reddet', cerezOnay, ek = [], gizle = [], azamiMs = 30000 } = {}) {
    if (!['reddet', 'kabul', 'dokunma'].includes(cerez)) throw new KapiHata('kullanim', "cerez: 'reddet' | 'kabul' | 'dokunma'");
    if (cerez === 'kabul' && !/^\d{4}-\d{2}-\d{2} Sultan: .+beyan:\S+/.test(String(cerezOnay || ''))) throw new KapiHata('onay-yok', 'çerez KABUL etmek Sultan izni ister ({ cerezOnay: D1 damgası }); varsayılan Reddet');
    return this.#uygula('click-engel', null, async () => {
      const page = this.#page; const rapor = { escape: 0, tiklanan: [], gizlenen: 0 };
      if (ODEME_YOL.test(page.url())) throw new KapiHata('durak', 'ödeme sayfasında engel kapatılmaz');
      for (let i = 0; i < 3; i++) { await page.keyboard.press('Escape').catch(() => {}); rapor.escape++; }
      const bul = ({ re, baglam }) => {
        const R = new RegExp(re, 'i'); const B = baglam ? new RegExp(baglam, 'i') : null;
        const gor = (e) => { const r = e.getBoundingClientRect(); const s = getComputedStyle(e); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none'; };
        for (const e of document.querySelectorAll('button, [role="button"], a, input[type="button"]')) {
          if (!R.test((e.innerText || e.value || '').trim()) || !gor(e)) continue;
          if (!B) return e;
          for (let a = e.parentElement, i = 0; a && i < 6 && a !== document.body && a !== document.documentElement; a = a.parentElement, i++) { const m = a.innerText || ''; if (m.length > 800) break; if (B.test(m)) return e; }   // düğme, çerez yazılı KÜÇÜK bir kutunun içinde olmalı: sayfadaki başka "Reddet" (iade, talep) tıklanmaz
        }
        return null;
      };
      const kaliplar = [...(cerez === 'reddet' ? [{ re: CEREZ_RED, baglam: CEREZ_BAGLAM }] : cerez === 'kabul' ? [{ re: CEREZ_KABUL, baglam: CEREZ_BAGLAM }] : []), { re: TUR_GEC }];
      for (const k of kaliplar) for (let tur = 0; tur < 3; tur++) {
        const h = (await page.evaluateHandle(bul, k)).asElement(); if (!h) break;
        const yazi = (await h.innerText().catch(() => '')).trim().slice(0, 30);
        try { await h.click({ timeout: 2000 }); rapor.tiklanan.push(yazi); } catch { break; }
        await uyu(250);
      }
      for (const s of ek) { const l = page.locator(s).first(); if (await l.isVisible().catch(() => false)) { try { await l.click({ timeout: 2000 }); rapor.tiklanan.push(String(s).slice(0, 30)); } catch { /* görünür ama tıklanamadı: rapora girmez */ } } }
      rapor.gizlenen = await page.evaluate((sec) => { let n = 0; for (const e of document.querySelectorAll(sec)) { if (e.style.display !== 'none') { e.style.setProperty('display', 'none', 'important'); n++; } } return n; }, [...ANKET_SEC, ...gizle].join(', ')).catch(() => 0);
      return rapor;
    }, azamiMs);
  }

  // SALT-OKUR · ogeDurumu(sel): yazmadan/tıklamadan ÖNCE ölç — kaç öğe eşleşti, kaçı görünür, ilk görünürün sırası, o öğe etkin mi.
  //   Gizli öğeye çözülen seçiciyi (sayi > gorunurSayi) ve pasif alanı (etkin: false) boşa tıklamadan gösterir: `sel >> nth=<ilkGorunur>`.
  ogeDurumu(sel, { azamiMs = 15000 } = {}) {
    return this.#sureli('ogeDurumu', sel, async () => {
      await this.#okuKapi('ogeDurumu', sel);
      const d = await this.#page.locator(sel).evaluateAll((es) => es.slice(0, 200).map((e) => { const r = e.getBoundingClientRect(); const s = getComputedStyle(e);
        return { g: r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none', e: !(e.disabled || e.readOnly || e.getAttribute('aria-disabled') === 'true' || e.closest('fieldset[disabled]')) }; }));
      const i = d.findIndex((x) => x.g);
      return { sayi: d.length, gorunurSayi: d.filter((x) => x.g).length, ilkGorunur: i, gorunur: i >= 0, etkin: i >= 0 ? d[i].e : false };
    }, azamiMs);
  }
  // SALT-OKUR · bekle(sel): sabit uyku yerine — öğe görünene (ya da { durum: 'hidden' } kaybolana) dek bekler; süre dolarsa false döner (atmaz).
  bekle(sel, { durum = 'visible', azamiMs = 10000 } = {}) {
    return this.#sureli('bekle', sel, async () => {
      await this.#okuKapi('bekle', sel);
      try { await this.#page.locator(sel).first().waitFor({ state: durum, timeout: azamiMs }); return true; } catch (e) { if (/Timeout/i.test(String(e.message))) return false; throw e; }
    }, azamiMs + 5000);
  }

  // KÖR NOKTA (JN1K8K): fill(tarih/renk/aralık)/selectOption değeri sayfa JS'iyle yazar → CDP Input.* YOK, köprü bu eylemi GÖRMEZ.
  // O eylemin penceresine düşen isTrusted=false olay = "köprüde görünmeyen eylem": uyarı basılır (yalnız kayıt/uyarı; karar kapısı değil — KARAR.md).
  // Uyarıda alan DEĞERİ yok (parola gizleme dinleyicide; burada kimlik+tür+sayı).
  #uyari(kod, ayrinti, ileti) { this.#uyarilar.push({ kod, ...ayrinti, t: Date.now() }); this.#yaz(ileti); this.#uyariIlet(kod, ayrinti.n); }
  // Merkeze (Dümen paneli + kütük) YALNIZ kod ve sayı gider — alan değeri, hedef, adres, çerez ASLA. Eylemi bekletmez; merkez cevap vermezse eylem etkilenmez, terminale UYARIR.
  #uyariIlet(kod, n) {
    const jeton = jetonOku();
    if (!jeton) { this.#yaz('⚠ Dümen: uyarı merkeze İLETİLEMEDİ (kutu jetonu okunamadı) — yalnız burada görünür'); return; }   // jetonsuz istek GÖNDERİLMEZ
    const sayi = Math.min(Math.max(Number.isInteger(n) ? n : 1, 1), 999);
    const p = fetch(`${this.#merkez}/api/dumen/uyari`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-defter-jeton': jeton }, body: JSON.stringify({ kod, n: sayi }), signal: AbortSignal.timeout(this.#zamanAsimiMs) })
      .then((r) => { if (!r.ok) this.#yaz(`⚠ Dümen: uyarı merkeze İLETİLEMEDİ (http ${r.status}) — yalnız burada görünür`); })
      .catch(() => { this.#yaz('⚠ Dümen: uyarı merkeze İLETİLEMEDİ (merkez cevapsız) — yalnız burada görünür'); });
    this.#iletimler.add(p); p.finally(() => this.#iletimler.delete(p));
  }
  iletimBekle() { return Promise.allSettled([...this.#iletimler]); }   // yalnız sınav/kapanış için: giden uyarı iletimlerinin bitmesini bekler
  #gorulemeyenTara(p) {
    if (!/^(fill|selectOption)$/.test(p.ad)) return;   // yalnız değeri sayfa JS'iyle yazan eylemler; click/press/goto sırasında sayfanın sentetik olayı 'köprüde görünmez' DEĞİLDİR
    const gor = this.#olaylar.filter((o) => o.t >= p.t0 && o.t <= p.t1 + 50 && o.trusted === false);
    if (gor.length) this.#uyari('gorulemeyen-eylem', { ad: p.ad, hedef: p.hedef, n: gor.length }, `⚠ Dümen: ${p.ad} ${p.hedef || ''} köprüde GÖRÜNMEZ (sayfa JS'iyle yazıldı, CDP Input yok; ${gor.length} olay) — yalnız dinleyici kaydı`);
  }
  #yabanciTara() {
    if (this.#aktif > 0) return;   // süren eylemin penceresi henüz kapanmadı: olay ona ait olabilir (eylem bitince yeniden taranır)
    for (const o of this.yabanci()) {
      const k = `${o.t}|${o.id}|${o.o}`;
      if (this.#uyariVerilen.has(k)) continue;
      this.#uyariVerilen.add(k);
      this.#uyari('yabanci-olay', { hedef: o.id, tur: o.tur }, `⚠ Dümen: ajan eylemi DIŞINDA alan değişti (${o.id || o.tur}) — insan ya da sayfa`);
    }
  }
  uyarilar() { this.#yabanciTara(); return this.#uyarilar.map((u) => ({ ...u })); }   // salt-okur kopya

  // ajan eylem penceresine düşen olay = ajanın; düşmeyen = insan ya da sayfa (kaynak eşlemesi — isTrusted ayırıcı DEĞİLDİR)
  olayKaydi() { return this.#olaylar.map((o) => ({ ...o })); }   // salt-okur kopya (ham nesne değil)
  eslesmis() { return this.#olaylar.filter((o) => this.#pencereler.some((p) => o.t >= p.t0 && o.t <= p.t1 + 50)); }
  yabanci() { return this.#olaylar.filter((o) => !this.#pencereler.some((p) => o.t >= p.t0 && o.t <= p.t1 + 50)); }
  // yalnız KENDİ açtığı sekme (ve kendi tıklamasının açtığı sekmeler) kapanır · iki kez çağrılabilir · kendisi de asılamaz (8 sn tavan)
  async kapat() {
    if (this.#kapandi) return; this.#kapandi = true;
    this.#yaz('Dümen bulgu hatırlatması: gördüğün hata ya da geliştirme önerisini yazdın mı? → bash /config/.claude/skills/bulgu/scripts/bulgu.sh yaz …');
    const is = (async () => {
      for (const s of [...this.#acilanlar]) await s.close().catch(() => {});
      if (this.#kendiSekmem) await this.#page?.close().catch(() => {});
      await this.#tarayici?.close().catch(() => {});
    })();
    await Promise.race([is, new Promise((r) => { const z = setTimeout(r, 8000); z.unref?.(); })]);
  }
}
