// kapi/kadro.mjs — KADRO: kutunun personel KAYDI ile canlı KOLTUKLARI birleştirir (Kadro E1 önkoşul 1+3,
// gorev_01M4WVHD00GF5MAQD1J7G74RZ4 · Sultan 14 Eki: "kutu içindeki personellerin durumu … düştü ise ayağa kaldırmak").
// Ölçüm SERDAR 14 Eki (18 kutu): 39 çalışıyor · 40 kayıtta var oturumu yok · 15 oturum açık içi boş (ASIL düşenler) · 22 kayıtsız.
//
// 🔴 KAYIT TEK KALIR, ikinci liste açılmaz: hâl bilgisi kaydın `hal:` alanından okunur (calisiyor · gecici · yedek · emekli);
//    alanı olmayan kişi 'bilinmiyor'dur — hiçbir şey uydurulmaz (taslak §4.1). 40 kişiyi "düştü" diye kırmızı basmak yalan alarm olurdu.
// 🔴 Kayıt dosyaları kutuya göre (koltuk-ac.sh ile aynı sıra): İSKÂN kutusu `iskan-registry.yaml` (id/tmux) + işaret ettiği
//    `ekip-registry.yaml` (rol/mod/hal); merkez `_agents/handoff/aile-registry.yaml`. Hiçbiri yoksa kayıt yok → herkes "kayıtsız".
// 🔴 Bu modül DOSYA OKUR, hiçbir şey yazmaz, tmux'a dokunmaz; koltuk listesi dışarıdan (koltuk-bagla --liste) verilir.
//    Yazma (E2: emekli et · geri aç · dondur) ayrı modülde: kapi/kadro-yaz.mjs — kayda `durum:` + `durum_once:` yazar, `hal:` açmaz.
import fs from 'node:fs';
import path from 'node:path';

export const HAL_KAYIT = ['calisiyor', 'gecici', 'yedek', 'emekli'];   // kaydın `hal:` alanı — kapalı küme; dışı 'bilinmiyor'
export const GRUPLAR = ['calisan', 'dusen', 'kayitta-var-calismiyor', 'gecici-emekli'];
// E2 (SERDAR 16 Eki · BÂNİ 15 Eki 18:31 ölçümü): kadro eylemleri `hal:` AÇMAZ (ekipc derleyicisi taşımıyor) — kaydın `durum:` alanına
// yazar. Bu iki değer `hal:`'dan ÖNCE gelir: E2 yazdıysa o kayıt dondurulmuş/emeklidir, eski `hal: calisiyor` satırı onu örtemez.
export const DURUM_HAL = { emekli: 'emekli', dondurulmus: 'dondurulmus' };

// ── ALTYAPI (E2 · SERDAR 16 Eki): kutunun KENDİ işleyişini taşıyan oturumlar personel değildir. Sultan'ın karesinde bunlar kırmızı
//    "ajan yok — boş oturum" görünüyordu — yanlış mesaj: içlerinde ajan olması beklenmez. 'altyapı' etiketiyle ayrı listelenir ve
//    kadro eylemleri (kapat · dondur · emekli) onlara UYGULANAMAZ (uç 403). koltuk-bagla.sh gizli() listesi bunun alt kümesidir
//    (o oturumlar ekranda hiç görünmez; burada yine de korunur — liste değişirse koruma düşmesin). Eşdeğerlik kadro.test.mjs'te ölçülür.
export function altyapiNeden(ad, ana = '') {
  const a = String(ad || '');
  if (!a) return '';
  if (ana && a === ana) return 'ana oturum';
  if (a === 'dash' || a === 'dashproxy' || a === 'dashwatch') return 'mobil panel';
  if (a.startsWith('ttyd-')) return 'web terminali';
  if (a.startsWith('kapi-')) return 'kutu kapısı';
  if (a.endsWith('-kurtarici')) return 'kurtarıcı ajan';
  if (a.endsWith('-kabuk')) return 'el kabuğu';   // Sultan'ın elle komut sekmesi: görünür (gizli değil) ama kadro eylemi uygulanamaz
  if (a.startsWith('imglistener')) return 'görsel dinleyici';
  return '';
}

// `key: "v"` · `key: 'v'` · `key: v   # yorum` — ekip-ac.sh'nin skaler() kuralıyla aynı (üç biçim; yoksa null)
function skaler(line, key) {
  let m = line.match(new RegExp('^\\s*' + key + ':\\s*"([^"]*)"\\s*(?:#.*)?$')); if (m) return m[1];
  m = line.match(new RegExp("^\\s*" + key + ":\\s*'([^']*)'\\s*(?:#.*)?$")); if (m) return m[1];
  m = line.match(new RegExp('^\\s*' + key + ':\\s*([^#\\s][^#]*?)\\s*(?:#.*)?$')); if (m) return m[1];
  return null;
}
// Dava Rafı (Parça B · SERDAR 16 Eki 16:26): son_calisma (dondurulurken yazılan epoch) · dondurma (kural = bekçi dondurdu) ·
// bagla_ile (kayda E4 bağlamayla girdi → 'bağlamayı geri al' sunulur) · bagla_once (kişiye bağlamada önceki session_id).
const ALANLAR = ['tmux', 'rol', 'mod', 'durum', 'durum_once', 'hal', 'arz_adi', 'cwd', 'session_id', 'son_calisma', 'dondurma', 'bagla_ile', 'bagla_once'];

// YAML metni → üyeler. Satır tabanlı: `- id: X` blok açar; blok içindeki bilinen skalerler alınır. `uyeler:` dışı
// `- id:` (ör. meta) yoktur; `tmux: null` → ''. Bilinmeyen anahtar yok sayılır (şema genişlemesi kırmaz).
// anahtar: blok açan alan — kayıtlarda `id`, ekip modelinde (`_agents/ekip-modeli.yaml` örnekleri) `kayit` (E2).
export function kayitAyristir(metin, anahtar = 'id') {
  const uyeler = []; let cur = null;
  const ac = new RegExp('^\\s*-\\s*' + anahtar + ':\\s*("([^"]*)"|\'([^\']*)\'|(\\S+))');
  for (const line of String(metin || '').split('\n')) {
    const m = line.match(ac);
    if (m) { cur = { id: m[2] ?? m[3] ?? m[4] }; uyeler.push(cur); continue; }
    if (!cur) continue;
    for (const k of ALANLAR) { const v = skaler(line, k); if (v !== null) { cur[k] = v === 'null' || v === '~' ? '' : v; break; } }
  }
  return uyeler;
}

// id'ye göre birleştir. ÖNCELİK ALANA GÖRE (göz tur 3): `tmux` İLK kaynaktan (İSKÂN doğum kaydı canlı oturumu bilir);
// rol · mod · hal · durum · arz_adi · cwd SONRAKİ kaynaktan (ekip kaydı kimliği/hâli bilir) — dolu geldiyse ÜSTÜNE yazar.
// Eski "yalnız boşu doldur" kuralı İSKÂN'daki bayat rol/hâl'i ekip kaydının önüne geçiriyordu.
const ILK_KAZANIR = new Set(['tmux']);
// Listenin `yalniz` kümesi verilmişse (E2: aile dalındaki üretilmiş ekip kaydı) o listeden YALNIZ bu alanlar alınır ve yalnız var
// olan üyelere işlenir — yeni üye eklemez, rol/tmux'u değiştirmez (kutunun bugünkü görünümü bayt bayt aynı kalır).
function birlestir(listeler) {
  const h = new Map();
  for (const l of listeler) for (const u of l) {
    const k = u.id; if (!k) continue;
    if (!h.has(k)) { if (!l.yalniz) h.set(k, { ...u }); continue; }
    const v = h.get(k);
    for (const [a, b] of Object.entries(u)) { if (!b || (l.yalniz && !l.yalniz.includes(a))) continue; if (ILK_KAZANIR.has(a)) { if (!v[a]) v[a] = b; } else v[a] = b; }
  }
  return [...h.values()];
}

// 🔴 DAVA DOSYASI (Sx #350 · SERDAR 10:50 + 09:25 kararı (b)): dava satırları (rol: dava) iskan-registry'den AYRI tutulur — kutunun
//    kayıt kopyası (filo üç-kopya eşitleyicisi) iskan'ı ezdiğinde dava satırları sessizce gitmesin. Kutu içinde, registry'nin yanında.
//    iskan'da yalnız `dava_kurali` kök satırı kalır. Okuyucu ve yazıcı bu yolu TEK yerden alır.
export function davalarYolu(proje, ortam = process.env) {
  return ortam.DAVALAR_REGISTRY || path.join(path.dirname(ortam.ISKAN_REGISTRY || path.join(proje, 'iskan-registry.yaml')), 'davalar.yaml');
}

// Kutunun kayıt dosyalarını bul ve oku → { kaynak: [yol…], uyeler } (okunamayan dosya atlanır, adı `okunamadi`ye düşer)
export function kayitOku(proje, ortam = process.env) {
  const kaynak = [], okunamadi = [], listeler = [];
  let dava_kurali = null;
  const oku = (y) => { try { const t = fs.readFileSync(y, 'utf8'); kaynak.push(y); if (!dava_kurali) dava_kurali = davaKuraliAyristir(t); return kayitAyristir(t); } catch { if (fs.existsSync(y)) okunamadi.push(y); return null; } };
  const iskan = ortam.ISKAN_REGISTRY || path.join(proje, 'iskan-registry.yaml');
  const aile = ortam.AILE_REGISTRY || path.join(proje, '_agents/handoff/aile-registry.yaml');
  if (fs.existsSync(iskan)) {
    const l = oku(iskan); if (l) listeler.push(l);
    const dav = davalarYolu(proje, ortam);
    if (fs.existsSync(dav)) { const ld = oku(dav); if (ld) listeler.push(ld); }
    // ekip_registry_pointer: iskan dosyasının başındaki skaler (varsa) — yoksa olağan iki yer denenir
    let isaret = ''; try { isaret = skaler((fs.readFileSync(iskan, 'utf8').split('\n').find((x) => /^\s*ekip_registry_pointer:/.test(x)) || ''), 'ekip_registry_pointer') || ''; } catch {}
    for (const y of [isaret && path.join(proje, isaret), path.join(proje, '_agents/handoff/ekip-registry.yaml'), path.join(proje, '_agents/ekip-os/ekip-registry.yaml')].filter(Boolean)) {
      if (fs.existsSync(y)) { const l2 = oku(y); if (l2) { listeler.push(l2); break; } }
    }
  } else if (fs.existsSync(aile)) {
    const l = oku(aile); if (l) listeler.push(l);
    // 🔴 E2: üretilmiş kutularda (s02 · sedir · nova …) `durum:` aile kaydında DEĞİL, ekipc'nin ürettiği ekip kaydında durur
    //    (kaynağı ekip-modeli.yaml). Okunmazsa E2'nin yazdığı 'dondurulmus'/'emekli' bu kutularda hiç görünmezdi. Yalnız durum alanları.
    for (const y of [path.join(proje, '_agents/ekip-os/ekip-registry.yaml'), path.join(proje, '_agents/handoff/ekip-registry.yaml')]) {
      if (fs.existsSync(y)) { const l2 = oku(y); if (l2) { l2.yalniz = ['durum', 'durum_once']; listeler.push(l2); break; } }
    }
  } else {
    for (const y of [path.join(proje, '_agents/handoff/ekip-registry.yaml'), path.join(proje, '_agents/ekip-os/ekip-registry.yaml')]) {
      if (fs.existsSync(y)) { const l = oku(y); if (l) listeler.push(l); break; }
    }
  }
  // E2: üretilmiş kayıtta `durum_once` YOKTUR (derleyici taşımıyor) — kaynağı ekip modelidir. Yalnız o alan, yalnız var olan üyeye.
  //    Okunmazsa üretilmiş kutuda 'geri aç' hiç sunulmazdı. Model yoksa ya da okunamazsa sessiz geçilir (bu alan kadroyu değiştirmez).
  const model = path.join(proje, '_agents/ekip-modeli.yaml');
  if (listeler.length && fs.existsSync(model)) {
    try { const l3 = kayitAyristir(fs.readFileSync(model, 'utf8'), 'kayit'); l3.yalniz = ['durum_once']; listeler.push(l3); } catch {}
  }
  return { kaynak, okunamadi, uyeler: birlestir(listeler), ...(dava_kurali ? { dava_kurali } : {}) };
}

// ── DAVA KURALI (Parça B1): kayıt KÖKÜNDE `dava_kurali: {tavan: 4, gun: 14}` (akış biçimi) ya da blok biçimi
//    dava_kurali:\n  tavan: 4\n  gun: 14. Raf yalnız bu alan varsa çıkar → davası olmayan kutuda raf yok, kutu adı koda gömülmez.
//    İki sayı da 1..99 tam sayı olmalı; biri eksik/bozuksa kural YOK sayılır (yarım kuralla dava dondurulmaz).
export function davaKuraliAyristir(metin) {
  const satirlar = String(metin || '').split('\n');
  const i = satirlar.findIndex((l) => /^dava_kurali:/.test(l)); if (i < 0) return null;
  const h = {};
  const akis = satirlar[i].match(/^dava_kurali:\s*\{([^}]*)\}\s*(#.*)?$/);
  if (akis) for (const p of akis[1].split(',')) { const m = p.match(/^\s*(tavan|gun)\s*:\s*(\d+)\s*$/); if (m) h[m[1]] = +m[2]; }
  else if (/^dava_kurali:\s*(#.*)?$/.test(satirlar[i])) {
    for (let j = i + 1; j < satirlar.length; j++) { const l = satirlar[j]; if (!l.trim() || /^\s*#/.test(l)) continue; if (!/^\s/.test(l)) break;
      const m = l.match(/^\s+(tavan|gun)\s*:\s*(\d+)\s*(#.*)?$/); if (m) h[m[1]] = +m[2]; }
  }
  const ok = (n) => Number.isInteger(n) && n >= 1 && n <= 99;
  return ok(h.tavan) && ok(h.gun) ? { tavan: h.tavan, gun: h.gun } : null;
}

export const DAVA_ROL = 'dava';
const GUN_SN = 86400;
const davaAcik = (k) => k.rol === DAVA_ROL && k.hal_kayit !== 'dondurulmus' && k.hal_kayit !== 'emekli';
// Açık davanın son hareketi: canlı oturumun `son`u (tmux bölmesi) — oturumu yoksa kayıttaki son_calisma (yoksa 0 = en eski sayılır)
const davaSon = (k) => (k.oturum && k.oturum.son) || k.son_calisma || 0;

// /api/kadro `davalar` alanı (B2). dondurulacak: kuralın son üç gününe girmiş açık davalar (kalan_gun 0 = bugünkü turda dondurulur).
export function davaOzet(kisiler, kural, simdi = Math.floor(Date.now() / 1000)) {
  const acik = kisiler.filter(davaAcik);
  const dondurulacak = acik.filter((k) => k.oturum && k.oturum.son && simdi - k.oturum.son > (kural.gun - 3) * GUN_SN)
    .map((k) => ({ id: k.id, kalan_gun: Math.max(0, kural.gun - Math.floor((simdi - k.oturum.son) / GUN_SN)) }));
  return { tavan: kural.tavan, gun: kural.gun, acik: acik.length, dondurulacak };
}

// Aç'ta yer açma (B4): istenen dava HARİÇ açık dava sayısı ≥ tavan ise en uzun süredir dokunulmayan açık dava. Yer varsa null.
// Altyapıya bağlanmış dava aday olamaz (zaten eylem uygulanamaz).
export function yerAcAday(kisiler, kural, haric) {
  const acik = kisiler.filter((k) => davaAcik(k) && k.id !== haric);
  if (acik.length < kural.tavan) return null;
  const aday = acik.filter((k) => !k.altyapi).sort((a, b) => davaSon(a) - davaSon(b))[0];
  return aday || null;
}

// Kendiliğinden dondurma (B7): açık, oturumu olan ve `gun` gündür tmux bölmesi kıpırdamayan davalar. Oturumu olmayan açık dava
// burada dondurulmaz (kapatılacak oturum yok; son hareketi ölçülemez — uydurulmaz).
export function kendiligindenDondurulacak(kisiler, kural, simdi = Math.floor(Date.now() / 1000)) {
  return kisiler.filter((k) => davaAcik(k) && !k.altyapi && k.oturum && k.oturum.son && simdi - k.oturum.son >= kural.gun * GUN_SN);
}

// Yalnız büyük/küçük harf farkı tolere edilir (berid ↔ BERID). Baştaki rakamı SOYMA: '20' ile '2026' aynı boş anahtara düşüp
// yanlış personele bağlanırdı (bağımsız göz tur 1) — ad kimliktir, kırpılmaz.
const norm = (s) => String(s || '').trim().toLowerCase();

// Kayıt + canlı koltuklar → kadro. koltuklar: koltukSatirlari() çıktısı ({ad, son, claude, tur?, hal?, ne?}); ana: ana koltuk adı.
// kimlikler (kimlik.mjs oturumKimlikleri): Map<koltuk adı, [{sessionId, ad, adKaynak}]> — verilirse eşleşme ÖNCE kimlikle yapılır
// (SERDAR 16 Eki 00:4x: huzur-yon huzur-ana'da çalışırken "oturumu yok" + ana "kimliği yok" — aynı kişi iki satır):
//   1) kayıttaki session_id (kimlik tanıma kancasının yazdığı) == oturumdaki Claude'un sessionId'si
//   2) Claude'a kullanıcının verdiği ad (nameSource user: `claude -n X`) == kayıt id'si
//   3) tmux adı (eski kural). Kimlik tek bir koltuğa çıkmalı; iki koltuğa çıkarsa kimlik eşleşmesi YAPILMAZ (tahmin yok), 3'e düşülür.
export function kadroBirlestir({ uyeler = [], koltuklar = [], ana = '', kimlikler = null } = {}) {
  const kalan = new Map(koltuklar.map((k) => [k.ad, k]));
  // Basamaklar KADRO GENELİNDE sırayla (bağımsız göz tur 1-2): önce BÜTÜN kişiler için session_id geçişi, sonra kalanlar için ad geçişi.
  // Kişi başına sıralamak yetmiyordu: önce işlenen kişinin ad eşleşmesi, sonra gelenin daha güçlü session_id eşleşmesini yiyebiliyordu.
  // Her basamakta aday tek olmalı — iki aday tahmin gerektirir, o kişi o basamakta atlanır.
  const kimlikle = new Map();
  if (kimlikler && kimlikler.size) {
    const basamaklar = [(u) => (c) => !!u.session_id && c.sessionId === u.session_id, (u) => (c) => c.adKaynak === 'user' && !!c.ad && norm(c.ad) === norm(u.id)];
    for (const uyarFn of basamaklar) for (const u of uyeler) {
      if (kimlikle.has(u)) continue;
      const uyar = uyarFn(u); const aday = [...kalan.keys()].filter((ad) => (kimlikler.get(ad) || []).some(uyar));
      if (aday.length === 1) { kimlikle.set(u, kalan.get(aday[0])); kalan.delete(aday[0]); }
    }
  }
  const bul = (tmux) => {
    const ad = String(tmux || '').split(':')[0]; if (!ad) return null;
    if (kalan.has(ad)) { const k = kalan.get(ad); kalan.delete(ad); return k; }
    const n = norm(ad); for (const [a, k] of kalan) if (norm(a) === n) { kalan.delete(a); return k; }   // yalnız casing varyantı
    return null;
  };
  // soru (2.23.0 · K1): koltuk soru hâlindeyken sorunun kendisi (koltuklar.mjs soruAyikla süzdü); yoksa alan yok
  const oturumSade = (k) => k ? { ad: k.ad, claude: !!k.claude, hal: k.hal || 'bilinmiyor', ne: k.ne || '', son: k.son || 0, tur: k.tur || '', ...(k.soru ? { soru: k.soru } : {}) } : null;
  const kisiler = uyeler.map((u) => {
    const ok = kimlikle.get(u), o = ok || bul(u.tmux);
    const hal = DURUM_HAL[u.durum] || ((u.hal && HAL_KAYIT.includes(u.hal)) ? u.hal : '');
    let grup;
    if (hal === 'gecici' || hal === 'yedek' || hal === 'emekli' || hal === 'dondurulmus') grup = 'gecici-emekli';
    else if (o && o.claude) grup = 'calisan';
    else if (o) grup = 'dusen';                       // oturum açık, içinde ajan yok — ASIL düşen; bekçi bunu kaldırmıyordu
    else grup = 'kayitta-var-calismiyor';
    const tmux = String(u.tmux || '').split(':')[0];
    // geri_acilir: E2'nin yazdığı önceki değer kayıtta duruyor mu — yoksa 'geri aç' neyi geri koyacağını bilemez (uç 409)
    const geri = (hal === 'emekli' || hal === 'dondurulmus') && !!u.durum_once;
    // altyapı: kayıttaki koltuk ya da FİİLEN bağlandığı oturum altyapıysa (ör. kişi ana oturumda çalışıyor) kadro eylemi uygulanmaz
    const alt = altyapiNeden(o ? o.ad : '', ana) || altyapiNeden(tmux, ana);
    return { id: u.id, rol: u.rol || '', mod: u.mod || '', hal_kayit: hal || 'bilinmiyor', tmux, oturum: oturumSade(o), grup,
      geri_acilir: geri, ...(ok ? { eslesme: 'kimlik' } : {}), ...(alt ? { altyapi: alt } : {}),
      // Dava Rafı alanları yalnız kayıtta varsa çıkar (davasız kutunun yanıtı bayt bayt aynı kalır)
      ...(u.arz_adi ? { arz_adi: u.arz_adi } : {}), ...(/^\d+$/.test(u.son_calisma || '') ? { son_calisma: +u.son_calisma } : {}),
      ...(u.dondurma === 'kural' && hal === 'dondurulmus' ? { dondurma: 'kural' } : {}), ...(u.bagla_ile === 'true' ? { bagla_ile: true } : {}) };
  });
  // E2: kayıtta olmayan ALTYAPI oturumları (ana dahil) kayıtsızlara düşmez, ayrı listelenir — kapatılamaz/emekli edilemez.
  // (Eski davranış: ana "(kimliği yok)" diye kişilerde, boş kabuksa DÜŞEN sayılıyordu; dash/dashproxy kırmızı kayıtsızdı.)
  const altyapi = [];
  for (const [ad, k] of [...kalan]) { const n = altyapiNeden(ad, ana); if (n) { kalan.delete(ad); altyapi.push({ ...oturumSade(k), altyapi: n, ...(ad === ana ? { ana: true } : {}) }); } }
  // 🔴 KAPAT KORUMASI (2.17.0, SERDAR 17 Eki 18:55): içinde Claude çalışan oturum "kayıtsız" görünse bile kapatılamaz —
  //    kayıt okunamadığında canlı ajanlar buraya düşüyordu ve tek eylem "Oturumu kapat"tı. Yalnız Claude'suz (sorunlu) oturum kapatılır.
  const kayitsiz = [...kalan.values()].map((k) => ({ ...oturumSade(k), kapatilabilir: !k.claude }));
  const sayilar = Object.fromEntries(GRUPLAR.map((g) => [g, kisiler.filter((k) => k.grup === g).length]));
  sayilar.kayitsiz = kayitsiz.length;
  sayilar.altyapi = altyapi.length;
  return { kisiler, kayitsiz, altyapi, sayilar };
}
