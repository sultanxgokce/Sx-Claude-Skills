/**
 * postane postacısı — posta defterindeki mesajı alıcı ajanın CANLI Claude oturumuna yerel soketle iletir (POSTANE F1 · kutu içi teslim).
 *
 * Nasıl: Claude her oturum için <oturumDizin>/<pid>.json (messagingSocketPath · tmux · status) ve <pid>.<hash>.key (auth anahtarı, 0600) yazar.
 * Postacı (aynı kullanıcı) alıcıyı tmux oturum adından bulur (berid:@24.%24 → BERİD), postaneden `al` ile mesajı çeker, soketten
 * {type:auth,token} + {type:user,message} satırlarını yazar ve sonucu postaneye `iletim` olayı olarak bildirir.
 *
 * DEĞİŞMEZLER (Sultan/SERDAR, 25 Eki 2026):
 *  · Anahtar DEĞERİ hiçbir çıktıya/kayda/olaya yazılmaz; yalnız bellekte, soketi açarken kullanılır (her hata metni maskelenir).
 *  · Postacı KENDİ içerik üretmez: ilettiği metin yalnız postaneden `al` ile gelen mesajdır (başlık satırı mesajın alanlarından kurulur).
 *  · Her teslim denemesi postane olayı olur: 'iletildi' ya da 'iletilemedi' (+neden). İletilemezse mesaj 'teslim' durumunda kalır, kirası
 *    dolunca yeniden görünür, 3. denemeden sonra ölü mektup — sessiz düşme yok.
 *  · Oturum eşlemesi KAYITTAN (tmux oturum adı → ajan listesi); eşleşmeyen / ölü süreç / soketi olmayan oturuma teslim YOK.
 *  · Sürüm kapısı: peerProtocol 1 dışındaki kayıt atlanır (protokol sürüme bağlı, 2.1.310'da ölçüldü).
 */
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { adlariKur, MAX_DENEME } from './postane.mjs';

const PROTOKOL = 1;

export const yasiyor = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; } };

/** Kayıt dizininden ajan → oturum haritası. Anahtar OKUNMAZ (ayrı, teslim anında). */
export function oturumlariOku(dizin, adlar, { canli = yasiyor } = {}) {
  const harita = new Map();
  let dosyalar = [];
  try { dosyalar = fs.readdirSync(dizin).filter((f) => /^\d+\.json$/.test(f)); } catch { return harita; }
  for (const f of dosyalar) {
    let k;
    try { k = JSON.parse(fs.readFileSync(path.join(dizin, f), 'utf8')); } catch { continue; }
    if (!k || typeof k !== 'object' || !Number.isInteger(k.pid) || k.peerProtocol !== PROTOKOL) continue;
    if (typeof k.messagingSocketPath !== 'string' || !k.messagingSocketPath || typeof k.tmux !== 'string') continue;
    const ajan = adlar.coz(k.tmux.split(':')[0]);
    if (!ajan || !canli(k.pid)) continue;
    const eski = harita.get(ajan);
    if (!eski || (k.updatedAt ?? 0) > (eski.updatedAt ?? 0)) harita.set(ajan, { pid: k.pid, soket: k.messagingSocketPath, durum: k.status ?? '?', updatedAt: k.updatedAt ?? 0 });
  }
  return harita;
}

const maskele = (metin, jeton) => (jeton ? String(metin).split(jeton).join('<gizli>') : String(metin));

/** Anahtarı dizinden okur (yalnız bellekte). Yoksa null. */
export function anahtarOku(dizin, pid) {
  try {
    const f = fs.readdirSync(dizin).find((x) => x.startsWith(`${pid}.`) && x.endsWith('.key'));
    return f ? fs.readFileSync(path.join(dizin, f), 'utf8').trim() || null : null;
  } catch { return null; }
}

/** Soketle ilet. Dönüş {ok, neden}; neden anahtar içermez. */
export function iletSoket(soketYolu, jeton, metin, { sure = 4000 } = {}) {
  return new Promise((coz) => {
    let bitti = false;
    const bit = (r) => { if (bitti) return; bitti = true; try { s.destroy(); } catch { /* */ } coz(r); };
    const s = net.createConnection(soketYolu);
    const zaman = setTimeout(() => bit({ ok: false, neden: 'zaman_asimi' }), sure);
    s.on('error', (e) => { clearTimeout(zaman); bit({ ok: false, neden: maskele(e.code || e.message, jeton) }); });
    // Claude soketi kabulde onay yollamıyor (ölçüldü); ama pay içinde karşı uç kapatırsa ya da veri yollarsa (hata cevabı olabilir) başarı sayılmaz.
    s.on('close', () => { clearTimeout(zaman); bit({ ok: false, neden: 'karsi_uc_kapatti' }); });
    s.on('data', () => { clearTimeout(zaman); bit({ ok: false, neden: 'karsi_uc_cevap_verdi' }); });
    s.on('connect', () => {
      const satirlar = JSON.stringify({ type: 'auth', token: jeton }) + '\n' + JSON.stringify({ type: 'user', message: { role: 'user', content: metin } }) + '\n';
      s.write(satirlar, (e) => {
        if (e) { clearTimeout(zaman); return bit({ ok: false, neden: 'yazilamadi' }); }
        setTimeout(() => { clearTimeout(zaman); bit({ ok: true, neden: '' }); }, 500);   // soketin okuması için kısa pay; 'iletildi' = satıra yazıldı, alıcı onayı `posta gordum`dur
      });
    });
  });
}

/** Alıcının göreceği metin: yalnız mesajın kendi alanlarından kurulur. */
export function metinKur(m) {
  const son = Number.isFinite(m.kalan_ms) ? ` · son tarihe ${Math.round(m.kalan_ms / 60000)} dk` : '';
  // Soket onay yollamaz (en az bir kez teslim): 2. ve sonraki teslim ilkinin kopyası olabilir — alıcı yanılmasın (SERDAR 26 Eki, …H7A2).
  const tekrar = Number.isInteger(m.deneme) && m.deneme >= 1 ? ` · TEKRAR ${m.deneme + 1}/${MAX_DENEME} — daha önce ulaşmış olabilir` : '';
  return `[POSTANE ${m.id} · ${m.kimden} → ${m.kime} · ${m.aciliyet}${son}${tekrar}]\n${m.konu ? m.konu + '\n' : ''}${m.icerik}\n(görüldü: posta gordum ${m.id} --kim ${m.kime} · işlenince: posta isle ${m.id} --kim ${m.kime})`;
}

async function cagir(taban, jetonDosya, yontem, yol, govde) {
  const jeton = fs.readFileSync(jetonDosya, 'utf8').trim();
  const r = await fetch(taban + yol, { method: yontem, headers: { 'x-defter-jeton': jeton, 'content-type': 'application/json' }, body: govde ? JSON.stringify(govde) : undefined });
  return { kod: r.status, j: await r.json().catch(() => ({})) };
}

/** İletim olayını yazar; geçit hatası verirse bir kez daha dener. Dönüş: yazıldı mı. */
async function iletimYaz(taban, jetonDosya, govde) {
  for (let i = 0; i < 2; i++) {
    try { const r = await cagir(taban, jetonDosya, 'POST', '/iletim', govde); if (r.kod === 200) return true; } catch { /* yeniden dene */ }
  }
  return false;
}

/**
 * KURU tur: hiçbir şey yazmaz/iletmez/anahtar okumaz. Her eşleşen ajan için bekleyen (gonderildi) mesaj sayısını döker.
 * Kurulumdan önce "doğru oturuma doğru ajan eşleşiyor mu, bekleyen kaç mesaj var" görmek içindir.
 */
export async function postaciKuru({ taban, jetonDosya, oturumDizin, adlar = adlariKur(), canli = yasiyor }) {
  const sonuc = { oturumlar: [], bekleyen: 0, hata: null };
  const oturumlar = oturumlariOku(oturumDizin, adlar, { canli });
  for (const [ajan, o] of oturumlar) {
    let bekleyen = null;
    try { const k = await cagir(taban, jetonDosya, 'GET', `/kutu/${encodeURIComponent(ajan)}?durum=gonderildi`); if (k.kod === 200) bekleyen = (k.j.mesajlar ?? []).length; else sonuc.hata = `kutu ${ajan}: HTTP ${k.kod}`; } catch (e) { sonuc.hata = `kutu ${ajan}: ${e.code || e.message}`; }
    sonuc.oturumlar.push({ ajan, pid: o.pid, durum: o.durum, bekleyen });
    sonuc.bekleyen += bekleyen ?? 0;
  }
  return sonuc;
}

/**
 * Bir tur: kayıtlı her ajan oturumu için `gonderildi` kutusunu okur (durum DEĞİŞTİRMEZ) ve iletir.
 * Durum geçişi yalnız soket başarısıyla, postane tarafında olur (`/iletim`). Durum postanede tutulur: tur bellek taşımaz (cron tek tur çalıştırır).
 * Dönüş: iletim sayıları; olayHata = olay yazılamadı; belirsiz = önceki turdan sonuçsuz niyet (yeniden iletilmez).
 */
export async function postaciTur({ taban, jetonDosya, oturumDizin, adlar = adlariKur(), ilet = iletSoket, canli = yasiyor, log = () => {} }) {
  const sayac = { iletildi: 0, iletilemedi: 0, oturumsuz: 0, olayHata: 0, belirsiz: 0 };
  const oturumlar = oturumlariOku(oturumDizin, adlar, { canli });
  for (const [ajan, o] of oturumlar) {
    const o1 = await cagir(taban, jetonDosya, 'GET', `/ozet/${encodeURIComponent(ajan)}`);
    if (o1.kod !== 200 || !(o1.j.acik > 0)) continue;                                       // bekleyen yoksa anahtarı hiç okuma
    const kutu = await cagir(taban, jetonDosya, 'GET', `/kutu/${encodeURIComponent(ajan)}?durum=gonderildi`);
    if (kutu.kod !== 200) { log(`${ajan}: kutu okunamadı (${kutu.kod})`); continue; }
    const mesajlar = (kutu.j.mesajlar ?? []).slice(0, 10);
    if (!mesajlar.length) continue;                                                         // açıklar zaten teslimde: yeniden iletme yok
    const jeton = anahtarOku(oturumDizin, o.pid);
    if (!jeton) { sayac.oturumsuz++; log(`${ajan}: anahtar yok (pid ${o.pid}) — teslim yok`); continue; }
    for (const m of mesajlar) {
      // 1) Önceki turdan çözülmemiş niyet var mı? (soket yazılmış OLABİLİR ama sonuç olayı yazılamadı) → EN AZ BİR KEZ teslim:
      //    belirsiz niyet teslim SAYILMAZ; olay düşer ve mesaj aşağıda YENİDEN iletilir (alıcı aynı kimliği iki kez görebilir).
      //    Belirsizlik MAX_DENEME'yi bulursa sonsuz tekrar olmasın: 'iletilemedi' say (deneme artar, 3'te ölü mektup).
      const gecmis = await cagir(taban, jetonDosya, 'GET', `/mesaj/${encodeURIComponent(m.id)}`);
      const olaylar = gecmis.j.olaylar ?? [];
      // 'iletim_belirsiz' da son-olay hesabında: belirsiz yazıldı ama yeni niyet yazılamadıysa aynı niyet İKİNCİ kez belirsiz/başarısız sayılmaz (doğrudan yeniden iletilir).
      const son = olaylar.filter((x) => ['iletim_basladi', 'iletim_belirsiz', 'iletildi', 'iletilemedi'].includes(x.tur)).pop();
      if (son && son.tur === 'iletim_basladi') {
        const n = olaylar.filter((x) => x.tur === 'iletim_belirsiz').length + 1;
        const yazildi = await iletimYaz(taban, jetonDosya, { id: m.id, kim: 'postaci', sonuc: n >= MAX_DENEME ? 'iletilemedi' : 'belirsiz', ayrinti: `önceki iletimin sonucu yazılamamıştı (${n}/${MAX_DENEME})${n >= MAX_DENEME ? ': teslim kanıtlanamadı' : ': yeniden iletilecek'}` });
        sayac.belirsiz++; if (!yazildi) sayac.olayHata++;
        log(`${m.id} → ${ajan}: önceki iletim sonucu belirsiz (${n}/${MAX_DENEME})${yazildi ? '' : ' · OLAY YAZILAMADI'}`);
        if (n >= MAX_DENEME || !yazildi) continue;
      }
      // 2) Niyet olayı sokete yazmadan ÖNCE: yazılamazsa teslim hiç denenmez (izsiz teslim olmaz).
      if (!(await iletimYaz(taban, jetonDosya, { id: m.id, kim: 'postaci', sonuc: 'basladi', ayrinti: `pid ${o.pid}` }))) {
        sayac.olayHata++; log(`${m.id} → ${ajan}: niyet olayı yazılamadı — teslim denenmedi`); continue;
      }
      const r = await ilet(o.soket, jeton, metinKur(m));
      const sonuc = r.ok ? 'iletildi' : 'iletilemedi';
      const yazildi = await iletimYaz(taban, jetonDosya, { id: m.id, kim: 'postaci', sonuc, ayrinti: r.ok ? `pid ${o.pid} · ${o.durum}` : maskele(r.neden, jeton) });
      sayac[sonuc]++;
      if (!yazildi) sayac.olayHata++;
      log(`${m.id} → ${ajan} (pid ${o.pid}, ${o.durum}): ${sonuc}${r.ok ? '' : ' · ' + maskele(r.neden, jeton)}${yazildi ? '' : ' · OLAY YAZILAMADI'}`);
    }
  }
  return sayac;
}

/**
 * SÜREKLİ kip (F2): merkezle AÇIK bağlantı tutar — `/bekle` uzun bekleme ucunda asılı durur, kutuda `gonderildi` mesaj belirince
 * saniyeler içinde uyanır ve bir tur çalıştırır. Eski 5 sn'lik düz yoklamanın yerini alır (aynı teslim kuralları: durum postanede).
 * ÇÖKME/KOPMA: postacı bellek taşımaz. Süreç ölürse yeniden başlayınca ilk işi bir tur atmaktır (`gonderildi` mesajlar postanede durur);
 * bağlantı kopar/hata gelirse 1→30 sn üstel bekleyişle yeniden bağlanır, bağlanamama TUR'u durdurmaz (yedek yoklama: en geç `yedekMs`'te bir tur).
 * YENİ OTURUM: bekleme çağrısı başladığı andaki ajan listesini taşır; araya giren oturumun bekleyeni en geç `bekleSn` (10) sonra, bir sonraki döngü başında liste değişimi görülünce hemen tur atılarak yakalanır.
 * Dönüş: durdurulunca özet sayaç (sınav için); gerçek süreçte `dur()` hiç true olmaz.
 */
export async function postaciSurekli({ taban, jetonDosya, oturumDizin, adlar = adlariKur(), bekleSn = 10, yedekMs = 60_000, ilkBeklemeMs = 1000, enCokBeklemeMs = 30_000,
  bekle = bekleCagir, tur = postaciTur, uyu = (ms) => new Promise((r) => setTimeout(r, ms)), saat = () => Date.now(), dur = () => false, canli = yasiyor, log = () => {} }) {
  const sayac = { tur: 0, uyanma: 0, zamanAsimi: 0, hata: 0, oturumsuz: 0 };
  let sonTur = -Infinity; let bekleme = ilkBeklemeMs; let sonAjanlar = null;
  const turAt = async () => { sonTur = saat(); sayac.tur++; try { await tur({ taban, jetonDosya, oturumDizin, adlar, canli, log }); } catch (e) { log('tur hatası: ' + (e.code || e.message)); } };
  await turAt();                                                                            // yeniden başlama: kaldığı yerden — bekleyen ne varsa hemen
  while (!dur()) {
    const ajanlar = [...oturumlariOku(oturumDizin, adlar, { canli }).keys()];
    if (!ajanlar.length) { sayac.oturumsuz++; await uyu(Math.min(5000, yedekMs)); continue; }   // oturum yoksa bağlanacak yer de yok
    // Asılı bekleme çağrısı başladığı andaki ajan listesini taşır: araya yeni oturum girdiyse (liste değiştiyse) o ajanın bekleyeni
    // bu çağrıda görünmez → liste her döngü başında karşılaştırılır, değiştiyse HEMEN bir tur atılır (en geç bekleSn sonra).
    const anahtar = ajanlar.slice().sort().join(',');
    if (sonAjanlar !== null && anahtar !== sonAjanlar) { sayac.listeDegisti = (sayac.listeDegisti ?? 0) + 1; await turAt(); }
    sonAjanlar = anahtar;
    let r;
    try { r = await bekle({ taban, jetonDosya, ajanlar, sn: bekleSn }); bekleme = ilkBeklemeMs; }
    catch (e) { sayac.hata++; log(`merkeze bağlanılamadı (${e.code || e.message}) — ${bekleme} ms sonra yeniden`); await uyu(bekleme); bekleme = Math.min(bekleme * 2, enCokBeklemeMs); if (saat() - sonTur >= yedekMs) await turAt(); continue; }
    if (dur()) break;
    if (r.bekleyen && Object.keys(r.bekleyen).length) { sayac.uyanma++; await turAt(); await uyu(200); }   // 200 ms: hep-başarısız mesajda sıkı döngü olmasın
    else { sayac.zamanAsimi++; if (saat() - sonTur >= yedekMs) await turAt(); }
  }
  return sayac;
}

/** Uzun bekleme çağrısı: HTTP hatası / geçersiz cevap = atılan hata (üstel geri çekilmeye girer). */
export async function bekleCagir({ taban, jetonDosya, ajanlar, sn }) {
  const k = await cagir(taban, jetonDosya, 'GET', `/bekle?ajanlar=${encodeURIComponent(ajanlar.join(','))}&sn=${sn}`);
  if (k.kod !== 200 || !k.j || k.j.ok !== true) throw Object.assign(new Error(`bekle HTTP ${k.kod}`), { code: `HTTP_${k.kod}` });
  return k.j;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const taban = (process.env.POSTANE_URL || 'http://cloudtop-postane:8797').replace(/\/+$/, '');
  const jetonDosya = process.env.POSTACI_JETON || '/config/defter-jeton';
  const oturumDizin = process.env.OTURUM_DIZIN || '/config/.claude/sessions';
  const ek = (process.env.POSTANE_EK_ADLAR || '').split(',').map((s) => s.trim()).filter(Boolean);
  const adlar = adlariKur(ek);
  const dongu = async () => { try { await postaciTur({ taban, jetonDosya, oturumDizin, adlar, log: (m) => console.log(new Date().toISOString(), m) }); } catch (e) { console.log(new Date().toISOString(), 'tur hatası:', e.code || e.message); } };
  if (process.argv.includes('--kuru')) {
    postaciKuru({ taban, jetonDosya, oturumDizin, adlar }).then((r) => {
      for (const o of r.oturumlar) console.log(`${o.ajan}\tpid ${o.pid}\t${o.durum}\tbekleyen ${o.bekleyen ?? '?'}`);
      console.log(`KURU: ${r.oturumlar.length} oturum eşleşti · ${r.bekleyen} bekleyen mesaj${r.hata ? ' · HATA ' + r.hata : ''} (hiçbir şey iletilmedi/yazılmadı)`);
      process.exit(r.hata ? 3 : 0);
    });
  } else if (process.argv.includes('--surekli')) { console.log(`postaci basladi (surekli, uzun bekleme) · ${taban} · oturum dizini ${oturumDizin}`); postaciSurekli({ taban, jetonDosya, oturumDizin, adlar, log: (m) => console.log(new Date().toISOString(), m) }); }
  else dongu().then(() => process.exit(0));                                               // varsayılan: tek tur (cron + flock)
}
