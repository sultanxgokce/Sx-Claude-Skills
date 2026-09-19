// kontrast-olc.mjs — sahnedeki soluk metinlerin kontrastı, GERÇEK zemin piksellerinden.
// Yöntem: metin kutularını al → metni saydam yap → ekran görüntüsünde kutunun içindeki zemin
// piksellerini oku → iki oran: p95 parlaklığa göre ve en açık piksele göre (en kötü hâl).
//
// 🔴 TAŞINABİLİRLİK (MUAVİN, 2026-09-17 paketleme): araç AKAR kutusunda doğdu ve tarayıcı yolu
// oraya SABİT yazılmıştı (/config/tooling/pw-runtime · /config/.local/micromamba/envs/pw-libs).
// Başka kutuda o yol yok → araç "Cannot find module" ile ölürdü. Artık yol ÖLÇÜLÜR: env →
// bilinen adaylar → normal çözümleme. Hiçbiri yoksa rc=3 ÖLÇÜLEMEDİ (temiz DEMEZ).
//
// 🔴 SIFIR METİN = ÖLÇÜM YOK (NAKKAŞ'ın uyarısı): seçiciler bu sayfada tutmazsa eskiden
// "0 metin · 5,5 altı: 0" basılıyordu — bu "temiz" gibi okunuyor. Artık rc=3.
//
// 🔴 ÖZEL SEÇİCİ GİZLENMİYORDU (MUAVİN, 2026-09-19): gizleme stili sabit seçicilerle yazılıydı;
// FRONTEND_BOOST_SECICILER ile verilen metinler saydam yapılmıyor → zemin yerine yazının KENDİ
// pikseli okunuyor, oran 1,00 çıkıyordu. Artık gizleme = sabit liste ∪ SECICILER (SAHNE altında).
// Oranı 1,00 (±0,005) çıkan kutu ÖLÇÜLEMEDİ sayılır (zemin okunamadı) → rc=3, eşik ihlali DEĞİL.
//
// Kullanım: node kontrast-olc.mjs <file://… | http…> [çıpa,çıpa]
// Çıkış: 0 eşik temiz · 1 eşik AŞILDI · 2 kullanım · 3 ÖLÇÜLEMEDİ (runtime/seçici yok)
// Ayar: FRONTEND_BOOST_PW (playwright-core modül yolu) · FRONTEND_BOOST_PW_LIBS (lib/fontconfig kökü)
//       FRONTEND_BOOST_SECICILER (virgüllü seçici listesi) · FRONTEND_BOOST_SAHNE (sahne seçicisi)
const hedef = process.argv[2];
if (!hedef) { console.error('kullanım: kontrast-olc.mjs <file:// ya da http adresi> [çıpa,çıpa]'); process.exit(2); }

const fs = await import('node:fs');
const LIBS = process.env.FRONTEND_BOOST_PW_LIBS || '/config/.local/micromamba/envs/pw-libs';
if (fs.existsSync(LIBS)) {
  process.env.LD_LIBRARY_PATH ||= `${LIBS}/lib`;
  process.env.FONTCONFIG_PATH ||= `${LIBS}/etc/fonts`;
  process.env.FONTCONFIG_FILE ||= `${LIBS}/etc/fonts/fonts.conf`;
}
const adaylar = [
  process.env.FRONTEND_BOOST_PW,
  '/config/tooling/pw-runtime/node_modules/playwright-core/index.js',
  '/config/.claude/tooling/pw-runtime/node_modules/playwright-core/index.js',
  'playwright-core', 'playwright',
].filter(Boolean);
let pw = null, denenen = [];
for (const a of adaylar) {
  try { pw = (await import(a.startsWith('/') && !fs.existsSync(a) ? '\0yok' : a)).default; if (pw) break; }
  catch { denenen.push(a); }
}
if (!pw) {
  console.error('ÖLÇÜLEMEDİ: bu kutuda tarayıcı çalışma-zamanı (playwright) bulunamadı — kontrast ÖLÇÜLMEDİ, "temiz" DEĞİL.');
  console.error('  denenen: ' + denenen.join(' · '));
  console.error('  çözüm: FRONTEND_BOOST_PW=<playwright-core/index.js yolu> ver ya da kutuya playwright kur.');
  process.exit(3);
}
const SAHNE = process.env.FRONTEND_BOOST_SAHNE || '.sahne';
const SECICILER = (process.env.FRONTEND_BOOST_SECICILER ||
  'text.ce, .gun, .sentetik, .okuma span, .dikey .onc, .dugme.sade, .hs span');
// Gizleme: sabit liste (eski sayfalar için) hem `.sahne` hem SAHNE altında ∪ SECICILER (SAHNE altında,
// çocuklarıyla). :is() virgüllü listeyi olduğu gibi taşır; seçiciyi elle bölmeye gerek kalmaz.
const SABIT_GIZLE = ['text', '.gun', '.sentetik', '.okuma', '.dikey *', '.dugme', 'h1'];
const GIZLE = [...new Set(['.sahne', SAHNE].flatMap(k => SABIT_GIZLE.map(x => `${k} ${x}`)))].concat([`${SAHNE} :is(${SECICILER})`, `${SAHNE} :is(${SECICILER}) *`]).join(',');
let toplamMetin = 0, ihlal = 0;
const olculemeyen = [];
let t;
try { t = await pw.chromium.launch({args:['--no-sandbox','--force-color-profile=srgb']}); }
catch (e) {
  console.error('ÖLÇÜLEMEDİ: tarayıcı başlatılamadı — kontrast ÖLÇÜLMEDİ, "temiz" DEĞİL.');
  console.error('  neden: ' + String(e && e.message || e).split('\n')[0]);
  process.exit(3);
}
for(const [en,boy,cipa] of [[1440,900,'acik'],[1440,900,'koyu'],[1280,800,'acik'],[390,844,'acik']]){
const s=await t.newPage({viewport:{width:en,height:boy}});
await s.goto(hedef+'#'+cipa);await s.evaluate(()=>document.fonts.ready);await s.waitForTimeout(3200);
// sahnedeki soluk metinlerin kutuları ve renkleri
const kutular=await s.evaluate(({SAHNE,SECICILER})=>{const sahne=document.querySelector(SAHNE);if(!sahne)return[];const r=[];
  sahne.querySelectorAll(SECICILER).forEach(e=>{const b=e.getBoundingClientRect();if(!b.width||b.bottom>innerHeight)return;const c=getComputedStyle(e);
    r.push({m:e.textContent.trim().slice(0,28),x:b.x,y:b.y,w:b.width,h:b.height,renk:(e.tagName==='text'?c.fill:c.color)});});return r;},{SAHNE,SECICILER});
await s.addStyleTag({content:GIZLE+'{color:transparent!important;fill:transparent!important}'});
await s.waitForTimeout(200);
const png=(await s.screenshot()).toString('base64');
const son=await s.evaluate(async({png,kutular})=>{const im=new Image();im.src='data:image/png;base64,'+png;await im.decode();const c=document.createElement('canvas');c.width=im.width;c.height=im.height;const g=c.getContext('2d');g.drawImage(im,0,0);
  const f=v=>{v/=255;return v<=.03928?v/12.92:Math.pow((v+.055)/1.055,2.4)};const L=(r,gg,b)=>.2126*f(r)+.7152*f(gg)+.0722*f(b);
  return kutular.map(k=>{const d=g.getImageData(Math.max(0,Math.floor(k.x)),Math.max(0,Math.floor(k.y)),Math.ceil(k.w),Math.ceil(k.h)).data;const ls=[];for(let i=0;i<d.length;i+=4)ls.push(L(d[i],d[i+1],d[i+2]));ls.sort((x,y)=>x-y);const enAcik=ls[Math.floor(ls.length*.95)],tepe=ls[ls.length-1];
    const m=k.renk.match(/[\d.]+/g).map(Number);const lt=L(m[0],m[1],m[2]);return {m:k.m,oran:+((lt+.05)/(enAcik+.05)).toFixed(2),tepe:+((lt+.05)/(tepe+.05)).toFixed(2)};});},{png,kutular});
// oran 1,00 (±0,005) = zemin değil yazının kendisi ya da zeminle aynı renk okundu → ÖLÇÜLEMEDİ, eşiğe sayılmaz
const bir=son.filter(o=>Math.abs(o.oran-1)<=0.005);bir.forEach(o=>olculemeyen.push(`${en} ${cipa} · ${o.m}`));
son.splice(0,son.length,...son.filter(o=>!bir.includes(o)));
son.sort((a,b)=>a.oran-b.oran);toplamMetin+=son.length;ihlal+=son.filter(o=>o.oran<5.5).length+son.filter(o=>o.tepe<4.5).length;console.log(`${en} ${cipa} · ${son.length} metin${bir.length?` (+${bir.length} ölçülemedi)`:''} · en düşük:`,son.slice(0,5).map(o=>`${o.m}=${o.oran} (en açık piksel ${o.tepe})`).join(' | '),'· 5,5 altı (p95):',son.filter(o=>o.oran<5.5).length,'· 4,5 altı (en açık piksel):',son.filter(o=>o.tepe<4.5).length);
await s.close();}
await t.close();
if (olculemeyen.length > 0) {
  console.error(`ÖLÇÜLEMEDİ: ${olculemeyen.length} kutuda oran 1,00 çıktı — zemin yerine yazının kendi pikseli (ya da zeminle aynı renk) okundu; bu kutular ÖLÇÜLMEDİ.`);
  olculemeyen.slice(0, 8).forEach(x => console.error('  · ' + x));
  console.error(`  ölçülen ${toplamMetin} kutuda eşik ihlali: ${ihlal} — sonuç ne "temiz" (rc=0) ne "eşik aşıldı" (rc=1): rc=3.`);
  console.error('  çözüm: metnin gizlenebildiğini ve zeminin metinden farklı olduğunu denetle; FRONTEND_BOOST_SAHNE / FRONTEND_BOOST_SECICILER doğru mu?');
  process.exit(3);
}
if (toplamMetin === 0) {
  console.error(`ÖLÇÜLEMEDİ: "${SAHNE}" altında "${SECICILER}" seçicileriyle HİÇ metin bulunamadı — bu sayfa ÖLÇÜLMEDİ, "temiz" DEĞİL.`);
  console.error('  çözüm: FRONTEND_BOOST_SAHNE / FRONTEND_BOOST_SECICILER ile bu sayfanın seçicilerini ver.');
  process.exit(3);
}
process.exit(ihlal > 0 ? 1 : 0);
