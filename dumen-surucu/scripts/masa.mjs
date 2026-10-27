// masa.mjs — ajanın bulut MASAÜSTÜNÜ (terminal dahil) kullandığı tek yol: masaüstü bekçisine (masa-kopru.py) konuşan eylem kapısı.
// Karar: görev …F9Y2Y · tasarım Nexus _agents/hezarfen/bilgi-havuzu/masaustu-kontrol-20261027/TASARIM.md · sözleşme cloudtop infra/dumen/SOZLESME.md §5.
//   - ÇİFT KİLİT: her çağrıdan önce merkez modu (GET <merkez>/dumen/mod); `ajan` değilse ya da merkez cevapsızsa eylem YAPILMAZ. Bekçi ayrıca kendi
//     mod dosyasından 423 döner — biri atlansa öteki tutar. 423 ya da mod `sultan` iken soket düşmesi HATA değil "Dümen Sultan'da" (KapiHata.neden = sultanda).
//   - Ham HTTP ajana VERİLMEZ: yalnız ekranAl/tik/yaz/tus/kaydir/durum vardır.
//   - DURMA NOKTASI ajan tarafındadır (bekçi hangi alanda olunduğunu bilmez): `yaz` hangi ALANA yazıldığını söylemeden çalışmaz; alan parola/SMS/kart/IBAN ise,
//     `tik` etiketi öde/onayla/gönder/sil ise eylem YAPILMAZ, merkeze durak bildirilir, ajan durur. Bu kapı ajanın beyanına dayanır (ekranı o okur) — kasıtlı
//     atlamayı değil, unutmayı ve yanlış varsayımı keser; zorlama bekçide yalnız mod kapısı + tuş kara listesidir.
//   - Yazılan metin ve ekran içeriği günlüğe (yaz callback) GİRMEZ; jeton dosyadan okunur, basılmaz.
import { readFileSync } from 'fs';
import { KapiHata } from './dumen.mjs';

const HASSAS_ALAN = /(parola|şifre|sifre|password|passwd|pin\b|otp|sms|doğrulama|dogrulama|tek kullanımlık|one-time|cvv|cvc|iban|kart.?no|card.?number|kredi)/i;
const GONDER_ETIKET = /(öde|ode\b|ödeme|odeme|satın al|satin al|onayla|gönder|gonder|confirm|pay\b|purchase|sil\b|delete|kalıcı|kalici)/i;

function masaJetonOku(dosya) {
  try { return readFileSync(dosya, 'utf8').trim() || null; } catch { return null; }
}
function defterJetonOku() {
  try { return readFileSync(process.env.DUMEN_DEFTER_JETON || '/config/defter-jeton', 'utf8').trim() || null; } catch { return null; }
}

export class Masa {
  #masa; #merkez; #jetonDosya; #zamanAsimiMs; #yaz;
  constructor({ masaUrl = 'http://172.30.0.2:9224', merkez, jetonDosya = process.env.DUMEN_MASA_JETON || '/config/dumen-masa-jeton', zamanAsimiMs = 8000, yaz = (s) => console.log(s) }) {
    this.#masa = masaUrl.replace(/\/$/, ''); this.#merkez = merkez.replace(/\/$/, ''); this.#jetonDosya = jetonDosya; this.#zamanAsimiMs = zamanAsimiMs; this.#yaz = yaz;
  }

  async modOku() {
    try {
      const r = await fetch(`${this.#merkez}/dumen/mod`, { signal: AbortSignal.timeout(this.#zamanAsimiMs) });
      if (!r.ok) throw new Error('http ' + r.status);
      return (await r.json()).mod;
    } catch (e) { throw new KapiHata('merkez-cevapsiz', String(e.message || e)); }   // fail-closed
  }

  async #sultanda(ayrinti) { this.#yaz("⏸ Dümen Sultan'da · bekliyorum"); return new KapiHata('sultanda', ayrinti); }

  async durak(neden) {
    // yalnız neden sözcüğü gider (sifre·sms·odeme·gonder) — alan değeri/metin/ekran ASLA. → true = merkez 2xx ile aldı
    try {
      const jeton = defterJetonOku();
      const r = await fetch(`${this.#merkez}/api/dumen/durak`, { method: 'POST', headers: { 'content-type': 'application/json', ...(jeton ? { 'x-defter-jeton': jeton } : {}) }, body: JSON.stringify({ neden }), signal: AbortSignal.timeout(this.#zamanAsimiMs) });
      return r.ok;
    } catch { return false; }
  }

  async #modKapisi() { const mod = await this.modOku(); if (mod !== 'ajan') throw await this.#sultanda(`mod=${mod}`); }   // durak bildirimi de dahil HER eylemden önce: Sultan'dayken merkeze 'durak' gitmesin

  async #durakKes(neden) {
    const bildirildi = await this.durak(neden);
    this.#yaz(bildirildi ? `⏸ Masaüstü: ${neden} durağında durdum · Dümeni al` : `⏸ Masaüstü: ${neden} durağında durdum · ⚠ merkeze İLETİLEMEDİ, Sultan haberdar değil`);
    const h = new KapiHata('durak', neden); h.bildirildi = bildirildi; return h;
  }

  async #istek(yontem, yol, govde) {
    const mod = await this.modOku();
    if (mod !== 'ajan') throw await this.#sultanda(`mod=${mod}`);
    const jeton = masaJetonOku(this.#jetonDosya);
    if (!jeton) throw new KapiHata('masa-jeton-yok', 'DUMEN_MASA_JETON dosyası okunamadı — kurulum eksik');
    let r;
    try {
      r = await fetch(this.#masa + yol, { method: yontem, headers: { 'x-dumen-jeton': jeton, ...(govde ? { 'content-type': 'application/json' } : {}) }, body: govde ? JSON.stringify(govde) : undefined, signal: AbortSignal.timeout(this.#zamanAsimiMs) });
    } catch (e) {
      const m = await this.modOku().catch(() => null);          // bağlantı koptu: Sultan mı aldı, yoksa gerçek kopma mı
      if (m && m !== 'ajan') throw await this.#sultanda(`mod=${m} (bağlantı düştü)`);
      throw new KapiHata('masa-koptu', String(e.message || e));
    }
    if (r.status === 423) throw await this.#sultanda('bekçi 423');
    if (r.status === 401) throw new KapiHata('masa-yetki', 'jeton reddedildi');
    if (r.status === 503) throw new KapiHata('masa-kapali', 'bekçi jeton dosyasını bulamıyor');
    let j = null; const tip = r.headers.get('content-type') || '';
    if (r.ok && tip.startsWith('image/')) return Buffer.from(await r.arrayBuffer());
    try { j = await r.json(); } catch { /* gövde yok */ }
    if (r.status === 403) throw new KapiHata('yasak', (j && j.aciklama) || '');
    if (r.status === 400) throw new KapiHata('istek', (j && j.aciklama) || '');
    if (!r.ok) throw new KapiHata('masa-hata', `http ${r.status} ${(j && j.aciklama) || ''}`.trim());
    return j;
  }

  durum() { return this.#istek('GET', '/durum'); }
  async ekranAl({ olcek = 1 } = {}) { return this.#istek('GET', `/ekran?olcek=${encodeURIComponent(olcek)}`); }   // PNG (Buffer)
  async tik(x, y, { dugme = 1, cift = false, etiket = '' } = {}) {
    await this.#modKapisi();
    if (GONDER_ETIKET.test(etiket)) throw await this.#durakKes(/öde|ode|satın|satin|pay|purchase/i.test(etiket) ? 'odeme' : 'gonder');
    return this.#istek('POST', '/tik', { x, y, dugme, cift });
  }
  async kaydir(x, y, dy) { return this.#istek('POST', '/kaydir', { x, y, dy }); }
  async yaz(metin, { alan } = {}) {
    await this.#modKapisi();
    if (typeof alan !== 'string' || !alan.trim()) throw new KapiHata('alan-belirtilmedi', "yaz(metin, { alan: '<hangi alana yazıyorsun>' }) — masaüstünde alan türü görünmez, ne yazdığını SEN söyle");
    if (HASSAS_ALAN.test(alan)) throw await this.#durakKes(/sms|otp|doğrulama|dogrulama|tek kullanımlık|one-time/i.test(alan) ? 'sms' : (/cvv|cvc|iban|kart|card|kredi/i.test(alan) ? 'odeme' : 'sifre'));
    return this.#istek('POST', '/yaz', { metin });
  }
  async tus(kombinasyon, { alan } = {}) {
    await this.#modKapisi();
    // harf harf yazma `yaz`ın alan kapısını delmesin: tek karakterli tuş (ctrl/alt'sız) da hangi alana basıldığını söylemeden gitmez
    const parcalar = String(kombinasyon).split('+'); const duzenleyici = parcalar.slice(0, -1).some((x) => /^(ctrl|control|alt|super|meta|win)/i.test(x));
    if (parcalar[parcalar.length - 1].length === 1 && !duzenleyici) {
      if (typeof alan !== 'string' || !alan.trim()) throw new KapiHata('alan-belirtilmedi', "tek karakterli tuş için tus(k, { alan: '<hangi alana>' }) gerekir");
      if (HASSAS_ALAN.test(alan)) throw await this.#durakKes(/sms|otp|doğrulama|dogrulama|tek kullanımlık|one-time/i.test(alan) ? 'sms' : (/cvv|cvc|iban|kart|card|kredi/i.test(alan) ? 'odeme' : 'sifre'));
    }
    return this.#istek('POST', '/tus', { kombinasyon });
  }
}
