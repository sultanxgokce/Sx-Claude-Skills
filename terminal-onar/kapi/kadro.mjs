// kapi/kadro.mjs — KADRO: kutunun personel KAYDI ile canlı KOLTUKLARI birleştirir (Kadro E1 önkoşul 1+3,
// gorev_01M4WVHD00GF5MAQD1J7G74RZ4 · Sultan 14 Eki: "kutu içindeki personellerin durumu … düştü ise ayağa kaldırmak").
// Ölçüm SERDAR 14 Eki (18 kutu): 39 çalışıyor · 40 kayıtta var oturumu yok · 15 oturum açık içi boş (ASIL düşenler) · 22 kayıtsız.
//
// 🔴 KAYIT TEK KALIR, ikinci liste açılmaz: hâl bilgisi kaydın `hal:` alanından okunur (calisiyor · gecici · yedek · emekli);
//    alanı olmayan kişi 'bilinmiyor'dur — hiçbir şey uydurulmaz (taslak §4.1). 40 kişiyi "düştü" diye kırmızı basmak yalan alarm olurdu.
// 🔴 Kayıt dosyaları kutuya göre (koltuk-ac.sh ile aynı sıra): İSKÂN kutusu `iskan-registry.yaml` (id/tmux) + işaret ettiği
//    `ekip-registry.yaml` (rol/mod/hal); merkez `_agents/handoff/aile-registry.yaml`. Hiçbiri yoksa kayıt yok → herkes "kayıtsız".
// 🔴 Bu modül DOSYA OKUR, hiçbir şey yazmaz, tmux'a dokunmaz; koltuk listesi dışarıdan (koltuk-bagla --liste) verilir.
import fs from 'node:fs';
import path from 'node:path';

export const HAL_KAYIT = ['calisiyor', 'gecici', 'yedek', 'emekli'];   // kaydın `hal:` alanı — kapalı küme; dışı 'bilinmiyor'
export const GRUPLAR = ['calisan', 'dusen', 'kayitta-var-calismiyor', 'gecici-emekli'];

// `key: "v"` · `key: 'v'` · `key: v   # yorum` — ekip-ac.sh'nin skaler() kuralıyla aynı (üç biçim; yoksa null)
function skaler(line, key) {
  let m = line.match(new RegExp('^\\s*' + key + ':\\s*"([^"]*)"\\s*(?:#.*)?$')); if (m) return m[1];
  m = line.match(new RegExp("^\\s*" + key + ":\\s*'([^']*)'\\s*(?:#.*)?$")); if (m) return m[1];
  m = line.match(new RegExp('^\\s*' + key + ':\\s*([^#\\s][^#]*?)\\s*(?:#.*)?$')); if (m) return m[1];
  return null;
}
const ALANLAR = ['tmux', 'rol', 'mod', 'durum', 'hal', 'arz_adi', 'cwd'];

// YAML metni → üyeler. Satır tabanlı: `- id: X` blok açar; blok içindeki bilinen skalerler alınır. `uyeler:` dışı
// `- id:` (ör. meta) yoktur; `tmux: null` → ''. Bilinmeyen anahtar yok sayılır (şema genişlemesi kırmaz).
export function kayitAyristir(metin) {
  const uyeler = []; let cur = null;
  for (const line of String(metin || '').split('\n')) {
    const m = line.match(/^\s*-\s*id:\s*("([^"]*)"|'([^']*)'|(\S+))/);
    if (m) { cur = { id: m[2] ?? m[3] ?? m[4] }; uyeler.push(cur); continue; }
    if (!cur) continue;
    for (const k of ALANLAR) { const v = skaler(line, k); if (v !== null) { cur[k] = v === 'null' || v === '~' ? '' : v; break; } }
  }
  return uyeler;
}

// id'ye göre birleştir: ilk kaynak tmux'u, sonraki kaynaklar boş alanları doldurur (rol/mod/hal ekip kaydından gelir).
function birlestir(listeler) {
  const h = new Map();
  for (const l of listeler) for (const u of l) {
    const k = u.id; if (!k) continue;
    if (!h.has(k)) { h.set(k, { ...u }); continue; }
    const v = h.get(k); for (const [a, b] of Object.entries(u)) if (b && !v[a]) v[a] = b;
  }
  return [...h.values()];
}

// Kutunun kayıt dosyalarını bul ve oku → { kaynak: [yol…], uyeler } (okunamayan dosya atlanır, adı `okunamadi`ye düşer)
export function kayitOku(proje, ortam = process.env) {
  const kaynak = [], okunamadi = [], listeler = [];
  const oku = (y) => { try { const t = fs.readFileSync(y, 'utf8'); kaynak.push(y); return kayitAyristir(t); } catch { if (fs.existsSync(y)) okunamadi.push(y); return null; } };
  const iskan = ortam.ISKAN_REGISTRY || path.join(proje, 'iskan-registry.yaml');
  const aile = ortam.AILE_REGISTRY || path.join(proje, '_agents/handoff/aile-registry.yaml');
  if (fs.existsSync(iskan)) {
    const l = oku(iskan); if (l) listeler.push(l);
    // ekip_registry_pointer: iskan dosyasının başındaki skaler (varsa) — yoksa olağan iki yer denenir
    let isaret = ''; try { isaret = skaler((fs.readFileSync(iskan, 'utf8').split('\n').find((x) => /^\s*ekip_registry_pointer:/.test(x)) || ''), 'ekip_registry_pointer') || ''; } catch {}
    for (const y of [isaret && path.join(proje, isaret), path.join(proje, '_agents/handoff/ekip-registry.yaml'), path.join(proje, '_agents/ekip-os/ekip-registry.yaml')].filter(Boolean)) {
      if (fs.existsSync(y)) { const l2 = oku(y); if (l2) { listeler.push(l2); break; } }
    }
  } else if (fs.existsSync(aile)) {
    const l = oku(aile); if (l) listeler.push(l);
  } else {
    for (const y of [path.join(proje, '_agents/handoff/ekip-registry.yaml'), path.join(proje, '_agents/ekip-os/ekip-registry.yaml')]) {
      if (fs.existsSync(y)) { const l = oku(y); if (l) listeler.push(l); break; }
    }
  }
  return { kaynak, okunamadi, uyeler: birlestir(listeler) };
}

// Yalnız büyük/küçük harf farkı tolere edilir (berid ↔ BERID). Baştaki rakamı SOYMA: '20' ile '2026' aynı boş anahtara düşüp
// yanlış personele bağlanırdı (bağımsız göz tur 1) — ad kimliktir, kırpılmaz.
const norm = (s) => String(s || '').trim().toLowerCase();

// Kayıt + canlı koltuklar → kadro. koltuklar: koltukSatirlari() çıktısı ({ad, son, claude, tur?, hal?, ne?}); ana: ana koltuk adı.
export function kadroBirlestir({ uyeler = [], koltuklar = [], ana = '' } = {}) {
  const kalan = new Map(koltuklar.map((k) => [k.ad, k]));
  const bul = (tmux) => {
    const ad = String(tmux || '').split(':')[0]; if (!ad) return null;
    if (kalan.has(ad)) { const k = kalan.get(ad); kalan.delete(ad); return k; }
    const n = norm(ad); for (const [a, k] of kalan) if (norm(a) === n) { kalan.delete(a); return k; }   // yalnız casing varyantı
    return null;
  };
  const oturumSade = (k) => k ? { ad: k.ad, claude: !!k.claude, hal: k.hal || 'bilinmiyor', ne: k.ne || '', son: k.son || 0, tur: k.tur || '' } : null;
  const kisiler = uyeler.map((u) => {
    const o = bul(u.tmux);
    const hal = (u.hal && HAL_KAYIT.includes(u.hal)) ? u.hal : (u.durum === 'emekli' ? 'emekli' : '');
    let grup;
    if (hal === 'gecici' || hal === 'yedek' || hal === 'emekli') grup = 'gecici-emekli';
    else if (o && o.claude) grup = 'calisan';
    else if (o) grup = 'dusen';                       // oturum açık, içinde ajan yok — ASIL düşen; bekçi bunu kaldırmıyordu
    else grup = 'kayitta-var-calismiyor';
    return { id: u.id, rol: u.rol || '', mod: u.mod || '', hal_kayit: hal || 'bilinmiyor', tmux: String(u.tmux || '').split(':')[0], oturum: oturumSade(o), grup };
  });
  // ana koltuk kayıtta yoksa "kimliği yok" diye kişilerde durur (taslak: "● ana — (kimliği yok)"), kayıtsızlara düşmez
  if (ana && kalan.has(ana)) {
    const k = kalan.get(ana); kalan.delete(ana);
    kisiler.push({ id: '', rol: '(kimliği yok)', mod: '', hal_kayit: 'bilinmiyor', tmux: ana, oturum: oturumSade(k), grup: k.claude ? 'calisan' : 'dusen', ana: true });
  }
  const kayitsiz = [...kalan.values()].map(oturumSade);
  const sayilar = Object.fromEntries(GRUPLAR.map((g) => [g, kisiler.filter((k) => k.grup === g).length]));
  sayilar.kayitsiz = kayitsiz.length;
  return { kisiler, kayitsiz, sayilar };
}
