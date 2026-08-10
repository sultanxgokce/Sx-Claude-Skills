// KURAL MOTORU (ŞAKÜL FAZ 1) — kural VERİSİNİ modele uygular. Eşikler burada YAŞAMAZ:
// motor yalnız ölçer ve karşılaştırır; sayılar kural-seti JSON'undan gelir (mevzuat değişince
// veri güncellenir, kod değil). Fail-closed: bozuk kural-seti = RC 1, sessiz atlama yok.
import { readFileSync } from 'fs';
import { MotorHata } from './model.mjs';
import { denetimBaglami } from './turet.mjs';

const SIDDETLER = ['hata', 'uyari'];
const OPLAR = {
  '>=': (a, b) => a >= b, '<=': (a, b) => a <= b, '>': (a, b) => a > b,
  '<': (a, b) => a < b, '==': (a, b) => a === b, '!=': (a, b) => a !== b,
};
// Kapsam-başına tanınan ölçütler — bilinmeyen ölçüt kural-setini geçersiz kılar (sessiz-yeşil yasak)
const OLCUTLER = {
  oda: ['net_alan_m2', 'dar_kenar_cm', 'kapi_sayisi', 'kapi_gecis_sayisi', 'dogrudan_isik'],
  aciklik: ['genislik_cm'],
  plan: ['oda_sayisi', 'erisilemeyen_oda_sayisi'],
};
// uygulanir'da tanınan seçiciler — yazım hatalı anahtar ("oda.tp") tüm varlıkları sessizce
// 'belirsiz'e düşürür ve kural körleşirdi; bilinmeyen seçici de kural-setini geçersiz kılar
const SECICILER = {
  oda: ['oda.tip'],
  aciklik: ['aciklik.tip', 'aciklik.rol', 'aciklik.dis', 'aciklik.belirsiz'],
  plan: [],
};

function kapsamCoz(k) {
  if (k.uygulanir?.kapsam === 'plan') return 'plan';
  const onekler = new Set(Object.keys(k.uygulanir ?? {}).filter((x) => x !== 'kapsam').map((x) => x.split('.')[0]));
  if (onekler.size > 1) throw new MotorHata(`kural-seti geçersiz: ${k.id} — uygulanir karışık kapsam (${[...onekler].join('+')})`, 1);
  if (onekler.has('aciklik')) return 'aciklik';
  if (k.uygulanir?.kapsam === 'aciklik') return 'aciklik';
  return 'oda';
}

export function kuralSetiYukle(yol) {
  let ks;
  try { ks = JSON.parse(readFileSync(yol, 'utf8')); }
  catch (e) { throw new MotorHata(`kural-seti okunamadı: ${yol} — ${e.message}`, 1); }
  if (!Array.isArray(ks.kurallar) || !ks.kurallar.length) throw new MotorHata('kural-seti geçersiz: kurallar listesi boş', 1);
  const idler = new Set();
  for (const k of ks.kurallar) {
    if (!k.id) throw new MotorHata('kural-seti geçersiz: id\'siz kural var', 1);
    if (idler.has(k.id)) throw new MotorHata(`kural-seti geçersiz: id tekrarı ${k.id}`, 1);
    idler.add(k.id);
    if (!k.kaynak) throw new MotorHata(`kural-seti geçersiz: ${k.id} — kaynak beyanı yok (kaynaksız kural = kanıtsız kural)`, 1);
    if (!SIDDETLER.includes(k.siddet)) throw new MotorHata(`kural-seti geçersiz: ${k.id} — siddet "${k.siddet}" (${SIDDETLER.join('|')})`, 1);
    if (!Array.isArray(k.sart) || !k.sart.length) throw new MotorHata(`kural-seti geçersiz: ${k.id} — sart listesi boş`, 1);
    const kapsam = kapsamCoz(k);
    for (const anahtar of Object.keys(k.uygulanir ?? {})) {
      if (anahtar === 'kapsam') continue;
      if (!SECICILER[kapsam].includes(anahtar)) throw new MotorHata(`kural-seti geçersiz: ${k.id} — seçici "${anahtar}" ${kapsam} kapsamında tanımsız (var: ${SECICILER[kapsam].join(', ') || 'yalnız kapsam'})`, 1);
    }
    for (const s of k.sart) {
      if (!OLCUTLER[kapsam].includes(s.olcut)) throw new MotorHata(`kural-seti geçersiz: ${k.id} — ölçüt "${s.olcut}" ${kapsam} kapsamında tanımsız (var: ${OLCUTLER[kapsam].join(', ')})`, 1);
      if (!OPLAR[s.op]) throw new MotorHata(`kural-seti geçersiz: ${k.id} — op "${s.op}" tanımsız (${Object.keys(OPLAR).join(' ')})`, 1);
      if (s.deger === undefined) throw new MotorHata(`kural-seti geçersiz: ${k.id} — deger yok`, 1);
    }
  }
  return ks;
}

// true = uygulanır · false = uygulanmaz · 'belirsiz' = ayırt-edici alan beyan edilmemiş.
// Öncelik: tanımlı bir seçici UYMUYORSA sonuç false'tur — başka bir alan eksik olsa bile
// ('belirsiz' yalnız "uyup uymadığı bilinemiyor" demek; uymadığı KESİNSE belirsizlik yok).
function uygulanirMi(varlik, uygulanir) {
  let eksik = false;
  for (const [anahtar, beklenen] of Object.entries(uygulanir ?? {})) {
    if (anahtar === 'kapsam') continue;
    const deger = varlik[anahtar.split('.')[1]];
    if (deger === undefined) { eksik = true; continue; }
    const uydu = Array.isArray(beklenen) ? beklenen.includes(deger) : deger === beklenen;
    if (!uydu) return false;
  }
  return eksik ? 'belirsiz' : true;
}

export function denetleKos(model, ks) {
  const b = denetimBaglami(model);
  const ihlaller = [], uyarilar = [], bilgiler = [];
  const kaynakSatiri = (k) => `${k.kaynak}${k.kaynak_url ? ` · ${k.kaynak_url}` : ''}`;

  for (const a of b.acikliklar) {
    if (a.belirsiz) bilgiler.push(`açıklık ${a.id} (${a.tip}): karşı taraf modellenmemiş/bulunamadı — erişim grafına kenar eklemedi (fail-closed)`);
  }
  if (b.erisilemeyen.length) bilgiler.push(`dış kapıdan erişilemeyen odalar: ${b.erisilemeyen.join(', ')}`);

  for (const k of ks.kurallar) {
    const kapsam = kapsamCoz(k);
    const varliklar = kapsam === 'plan' ? [{ id: 'plan', ...b.plan }] : kapsam === 'aciklik' ? b.acikliklar : b.odalar;
    let uygulanan = 0, belirsiz = 0;
    for (const v of varliklar) {
      const u = uygulanirMi(v, k.uygulanir);
      if (u === 'belirsiz') { belirsiz++; continue; }
      if (!u) continue;
      uygulanan++;
      for (const s of k.sart) {
        const deger = v[s.olcut];
        const gecti = OPLAR[s.op](deger, s.deger);
        const yaklasik = s.olcut === 'dar_kenar_cm' && v.dar_kenar_yaklasik;
        const satir = `[${k.id}] ${kapsam} "${v.id}": ${s.olcut} ${JSON.stringify(deger)} (şart: ${s.op} ${JSON.stringify(s.deger)})${yaklasik ? ' — YAKLAŞIK ölçüm (dikdörtgen-dışı, bbox ÜST-sınırı)' : ''} — ${kaynakSatiri(k)}`;
        if (!yaklasik) {
          if (!gecti) (k.siddet === 'hata' ? ihlaller : uyarilar).push(satir);
          continue;
        }
        // Yaklaşık dar-kenar bir ÜST-sınırdır (bbox ≥ gerçek dar geçit). Yön-farkındalık:
        // üst-sınırla alt-sınır şartını (>=, >) GEÇMEK hiçbir şey kanıtlamaz; KALMAK kesindir.
        // Üst-sınırla üst-sınır şartını (<=, <) geçmek kesindir; kalmak kanıtlamaz.
        // Kanıtsız sonuç hata-şiddet kuralda İHLAL sayılır (fail-closed: RC yalan söyleyemez —
        // inceleme bulgusu 2026-08-04: 45° döndürülmüş 90cm koridor RC 0 geçiyordu).
        const kesin = (['>=', '>'].includes(s.op) && !gecti) || (['<=', '<'].includes(s.op) && gecti);
        if (kesin) {
          if (!gecti) (k.siddet === 'hata' ? ihlaller : uyarilar).push(satir);
        } else {
          const d = `${satir} — DOĞRULANAMADI: yaklaşık üst-sınır bu şartı kanıtlayamaz; fail-closed gereği ${k.siddet === 'hata' ? 'İHLAL sayıldı — modeli eksen-hizalı böl ya da saha ölçümü gir' : 'uyarıya yazıldı'}`;
          (k.siddet === 'hata' ? ihlaller : uyarilar).push(d);
        }
      }
    }
    // KÖR NOKTA raporu KOŞULSUZDUR: kural başka varlıklara uygulanmış olsa bile, ayırt-edici
    // alanı beyan etmeyen varlıklar İZSİZ atlanamaz (inceleme bulgusu 2026-08-04: tipsiz 90cm
    // koridor "0 uyarı, 0 bilgi" ile kayboluyordu — sessiz atlama yasağının doğrudan ihlaliydi).
    if (belirsiz) uyarilar.push(`[${k.id}] ${belirsiz}/${varliklar.length} varlık ayırt-edici alanı (ör. oda.tip / aciklik.rol) beyan etmemiş — kural onlara UYGULANAMADI: KÖR NOKTA, geçti sayılmaz`);
    if (!uygulanan && !belirsiz) bilgiler.push(`[${k.id}] uygulanacak varlık yok (plan bu kapsamda öğe içermiyor)`);
  }
  return { ihlaller, uyarilar, bilgiler, baglam: b };
}
