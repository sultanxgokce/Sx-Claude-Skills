// kapi/kadro-yaz.mjs — KADRO E2: kişinin kayıt HÂLİNİ yazar (emekli et · dondur · geri aç). Oturum kapatma burada DEĞİL (sunucu.mjs).
// Sultan onaylı (SERDAR 16 Eki 00:3x, D1); ölçüm BÂNİ 15 Eki 18:31 (_agents/bani/NOTES.md).
//
// 🔴 YAZMA KAYNAĞA GİDER. Kayıtlar iki cins:
//    ELLE      — kişinin `- id:` bloğunun durduğu dosya (İSKÂN kutusunda işaretli ekip kaydı · merkezde aile kaydı): blokta `durum:` satırı.
//    ÜRETİLMİŞ — blok ekipc'nin ürettiği bölgede (`ekipc:uretilen:basla` … `bitti`): oraya elle yazmak bir sonraki derlemede silinir ve
//                derleyici hash tutmaz diye durur. Yazma kaynağa gider: `_agents/ekip-modeli.yaml` içinde `kayit: <id>` örneği → `durum:`,
//                ardından derleyici (ekipc derle --apply). Derleyici kutuda yoksa HİÇBİR ŞEY YAZILMAZ (yarım yazma yok) → kod 503.
// 🔴 Yeni `hal:` alanı AÇILMAZ (derleyici taşımıyor; iki cins ayrışırdı). Önceki değer `durum_once:` satırına yazılır; 'geri aç' onu
//    geri koyar ve `durum_once:` satırını siler. Önceki değer yoksa `durum_once: yok` yazılır → geri açınca `durum:` satırı kalkar.
// 🔴 Hangi dosya: okuyucunun (kadro.mjs kayitOku) `durum`'u SON okuduğu kaynak, yani kişinin bloğunu taşıyan son dosya. Okuyucu ile
//    yazıcı aynı sırayı kullanmazsa yazılan değer ekranda görünmez — sıra tek yerde: kayitDosyalari().
// 🔴 Biçim korunur: yalnız iki satıra dokunulur, geri kalan bayt bayt aynıdır; yazım geçici dosya + rename (yarım dosya kalmaz).
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

export const YAZILAN = ['emekli', 'dondurulmus'];
const ONCEKI_YOK = 'yok';
const DEGER_DESEN = /^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ-]{1,40}$/u;   // geri konan önceki değer de bu kümeden olmalı (satır enjeksiyonu yok)
const URETILEN_BAS = 'ekipc:uretilen:basla', URETILEN_SON = 'ekipc:uretilen:bitti';

// Süreçler arası kayıt kilidi (Parça B7): kapı (süreç içi kuyruk) ile günlük bekçi turu AYNI kayda yazar → ikisi de bu kilidi alır.
// O_EXCL dosyası; 120 sn'den eski kilit ölmüş süreçten kalmıştır, kaldırılır. 30 sn'de alınamazsa KadroHata 503 (hiçbir şey yazılmaz).
export async function dosyaKilit(dizin, { bekleMs = 30000, bayatMs = 120000 } = {}) {
  const y = path.join(dizin, 'kadro.kilit'); const bas = Date.now();
  for (;;) {
    try { const fd = fs.openSync(y, 'wx'); fs.writeSync(fd, String(process.pid)); fs.closeSync(fd); return () => { try { fs.unlinkSync(y); } catch {} }; }
    catch (e) { if (e.code !== 'EEXIST') throw e; }
    try { if (Date.now() - fs.statSync(y).mtimeMs > bayatMs) { fs.unlinkSync(y); continue; } } catch { continue; }
    if (Date.now() - bas > bekleMs) throw new KadroHata(503, 'Kayıt başka bir işlemce kilitli — biraz sonra yeniden dene.');
    await new Promise((r) => setTimeout(r, 100));
  }
}

export class KadroHata extends Error { constructor(kod, mesaj) { super(mesaj); this.kod = kod; } }

const kacir = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Okuyucu ile AYNI sıra (kadro.mjs kayitOku): son eleman `durum`'u belirler.
export function kayitDosyalari(proje, ortam = process.env) {
  const iskan = ortam.ISKAN_REGISTRY || path.join(proje, 'iskan-registry.yaml');
  const aile = ortam.AILE_REGISTRY || path.join(proje, '_agents/handoff/aile-registry.yaml');
  const ekip = [path.join(proje, '_agents/handoff/ekip-registry.yaml'), path.join(proje, '_agents/ekip-os/ekip-registry.yaml')];
  const ilk = (l) => l.find((y) => y && fs.existsSync(y));
  if (fs.existsSync(iskan)) {
    let isaret = '';
    try { const m = fs.readFileSync(iskan, 'utf8').match(/^\s*ekip_registry_pointer:\s*["']?([^"'#\s]+)/m); isaret = m ? m[1] : ''; } catch {}
    return [iskan, ilk([isaret && path.join(proje, isaret), ...ekip])].filter(Boolean);
  }
  if (fs.existsSync(aile)) return [aile, ilk([ekip[1], ekip[0]])].filter(Boolean);
  return [ilk(ekip)].filter(Boolean);
}

// `- <anahtar>: <id>` bloğu → { bas, son, girinti } (satır indisleri; son = bloğun son satırı). Yoksa null; birden çoksa hata.
export function blokBul(satirlar, anahtar, id) {
  const re = new RegExp('^(\\s*)-\\s*' + anahtar + ':\\s*(["\']?)' + kacir(id) + '\\2\\s*(#.*)?$');
  const bulunan = []; satirlar.forEach((l, i) => { if (re.test(l)) bulunan.push(i); });
  if (!bulunan.length) return null;
  if (bulunan.length > 1) throw new KadroHata(409, `Kayıtta "${id}" birden çok kez geçiyor — hangisine yazılacağı belirsiz, dokunulmadı.`);
  const bas = bulunan[0], tire = satirlar[bas].match(/^(\s*)/)[1].length;
  const girinti = satirlar[bas].indexOf(anahtar, tire);
  let son = bas;
  for (let i = bas + 1; i < satirlar.length; i++) {
    const l = satirlar[i]; if (!l.trim()) continue;
    if (l.match(/^(\s*)/)[1].length <= tire) break;
    son = i;
  }
  return { bas, son, girinti };
}

// Bloğun DOĞRUDAN alanını oku (aynı girintide `alan:`) → { i, deger } | null
// yorum: satır sonundaki ` # …` (önündeki boşluklarla) — değer değişirken KORUNUR (kayıttaki insan notu silinmez)
function alanBul(satirlar, b, alan) {
  const re = new RegExp('^ {' + b.girinti + '}' + alan + ':\\s*(?:"([^"]*)"|\'([^\']*)\'|([^#\\s][^#]*?))?(\\s*#.*)?$');
  for (let i = b.bas + 1; i <= b.son; i++) { const m = satirlar[i].match(re); if (m) return { i, deger: (m[1] ?? m[2] ?? m[3] ?? '').trim(), yorum: m[4] || '' }; }
  return null;
}

// Saf metin dönüşümü: blokta durum'u `yeni`'ye çevir, öncekini durum_once'a yaz (ileri) ya da durum_once'ı geri koy (geri).
// Dönen: { metin, onceki } — onceki: yazımdan önceki durum (yoksa ''), sınav ve kayıt için.
export function durumDegistir(metin, anahtar, id, eylem) {
  const satirlar = String(metin).split('\n');
  const b = blokBul(satirlar, anahtar, id);
  if (!b) throw new KadroHata(404, `Kayıtta "${id}" yok.`);
  const sp = ' '.repeat(b.girinti);
  const d = alanBul(satirlar, b, 'durum'), o = alanBul(satirlar, b, 'durum_once');
  const simdi = d ? d.deger : '';
  if (eylem === 'geri-ac') {
    if (!YAZILAN.includes(simdi)) throw new KadroHata(409, `"${id}" emekli ya da dondurulmuş değil (şu an: ${simdi || 'durum yok'}).`);
    if (!o || !o.deger) throw new KadroHata(409, `"${id}" için önceki hâl kayıtlı değil — neyin geri konacağı bilinmiyor, dokunulmadı.`);
    if (o.deger !== ONCEKI_YOK && !DEGER_DESEN.test(o.deger)) throw new KadroHata(409, `Önceki hâl okunamadı ("${o.deger}") — dokunulmadı.`);
    // Önce durum_once satırı silinir (indis kaymasın diye büyük indisten küçüğe)
    const sil = [o.i]; if (o.deger === ONCEKI_YOK) sil.push(d.i); else satirlar[d.i] = sp + 'durum: ' + o.deger + d.yorum;
    for (const i of sil.sort((x, y) => y - x)) satirlar.splice(i, 1);
    return { metin: satirlar.join('\n'), onceki: simdi, yeni: o.deger === ONCEKI_YOK ? '' : o.deger };
  }
  const yeni = eylem === 'emekli' ? 'emekli' : eylem === 'dondur' ? 'dondurulmus' : null;
  if (!yeni) throw new KadroHata(400, 'Bilinmeyen eylem.');
  if (YAZILAN.includes(simdi)) throw new KadroHata(409, `"${id}" zaten ${simdi === 'emekli' ? 'emekli' : 'dondurulmuş'} — önce geri aç.`);
  if (simdi && !DEGER_DESEN.test(simdi)) throw new KadroHata(409, `Şu anki durum okunamadı ("${simdi}") — dokunulmadı.`);
  const onceSatir = sp + 'durum_once: ' + (simdi || ONCEKI_YOK);
  if (d) { satirlar[d.i] = sp + 'durum: ' + yeni + d.yorum; if (o) satirlar[o.i] = onceSatir; else satirlar.splice(d.i + 1, 0, onceSatir); }
  else { if (o) satirlar.splice(o.i, 1); satirlar.splice(b.bas + 1, 0, sp + 'durum: ' + yeni, onceSatir); }
  return { metin: satirlar.join('\n'), onceki: simdi, yeni };
}

// 🔴 K13 (ekip-modeli-lint, gerçek derleyiciyle ölçüldü 16 Eki): modelde `olcek.adet` = `durum: canli` örnek sayısı olmak ZORUNDA.
//    Canlı bir örneği dondurmak/emekli etmek adet'i bir azaltır, geri açmak bir artırır — yoksa lint kırmızı, derleyici reddeder.
//    adet satırı örneğin `ornekler:` listesiyle AYNI girintide, ondan önce aranır; bulunmazsa (K13 kapsamı dışı) dokunulmaz.
export function adetAyarla(metin, id, fark) {
  if (!fark) return metin;
  const satirlar = String(metin).split('\n');
  const b = blokBul(satirlar, 'kayit', id); if (!b) return metin;
  let oi = -1; const dash = satirlar[b.bas].match(/^(\s*)/)[1].length;
  for (let i = b.bas - 1; i >= 0; i--) { const m = satirlar[i].match(/^(\s*)ornekler:\s*(#.*)?$/); if (m && m[1].length <= dash) { oi = i; break; } }
  if (oi < 0) return metin;
  const gi = satirlar[oi].match(/^(\s*)/)[1].length;
  for (let i = oi - 1; i >= 0; i--) {
    const l = satirlar[i]; if (!l.trim()) continue;
    const ind = l.match(/^(\s*)/)[1].length; if (ind < gi) break;
    const m = ind === gi && l.match(/^(\s*adet:\s*)(\d+)(.*)$/);
    if (m) { const yeni = +m[2] + fark; if (yeni < 0) return metin; satirlar[i] = m[1] + yeni + m[3]; return satirlar.join('\n'); }
  }
  return metin;
}

function atomikYaz(yol, metin) {
  const st = fs.statSync(yol);
  const gecici = yol + '.kadro-' + process.pid + '-' + Date.now();
  fs.writeFileSync(gecici, metin, { mode: st.mode & 0o777 });
  fs.renameSync(gecici, yol);
}

// Blok üretilmiş bölgede mi (ekipc işaretleri arasında)
function uretilmisMi(satirlar, b) {
  let bas = -1, son = -1; satirlar.forEach((l, i) => { if (bas < 0 && l.includes(URETILEN_BAS)) bas = i; if (l.includes(URETILEN_SON)) son = i; });
  return bas >= 0 && son > bas && b.bas > bas && b.bas < son;
}

// Dizindeki her dosyanın içeriği (özyinelemeli; derleyicinin hedef dizini küçük: onlarca dosya)
function dizinFoto(kok) {
  const h = new Map();
  const gez = (d) => { let l; try { l = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of l) { const y = path.join(d, e.name); if (e.isDirectory()) gez(y); else if (e.isFile()) h.set(y, fs.readFileSync(y, 'utf8')); } };
  gez(kok); return h;
}

function derleyiciBul(proje, ortam) {
  const y = ortam.KAPI_EKIPC || path.join(proje, 'scripts/ekipc.sh');
  return fs.existsSync(y) ? y : '';
}

// ── Dava Rafı (Parça B) ─────────────────────────────────────────────────────────────────────────────────────────────────────
// Bloğun doğrudan alanlarını yaz/sil: degisim = { alan: deger | null }. Var olan satır yerinde değişir (yorumu korunur), olmayan
// bloğun sonuna eklenir, null satırı siler. Değerler çağıranda doğrulanır; burada yalnız satır kırıcı karakter reddedilir.
export function alanlarYaz(metin, anahtar, id, degisim) {
  let satirlar = String(metin).split('\n');
  for (const [alan, deger] of Object.entries(degisim)) {
    if (deger !== null && /[\n\r]/.test(String(deger))) throw new KadroHata(400, 'Değer satır sonu taşıyamaz.');
    const b = blokBul(satirlar, anahtar, id); if (!b) throw new KadroHata(404, `Kayıtta "${id}" yok.`);
    const a = alanBul(satirlar, b, alan), sp = ' '.repeat(b.girinti);
    if (deger === null) { if (a) satirlar.splice(a.i, 1); continue; }
    const satir = sp + alan + ': ' + deger + (a ? a.yorum : '');
    if (a) satirlar[a.i] = satir; else satirlar.splice(b.son + 1, 0, satir);
  }
  return satirlar.join('\n');
}

// Kişinin bloğunu taşıyan dosya → { hedef, satirlar, b }. `alan` verilirse o alanı TAŞIYAN dosya önce gelir (session_id İSKÂN
// kutusunda iskan-registry'dedir — açıcı baslat-claude.sh oradan okur; ekip kaydına yazılsa kadro görür, açıcı görmezdi: DV28).
// Yoksa SON dosya (okuyucunun alanı son okuduğu yer).
function blokDosyasi(proje, ortam, id, alan = '') {
  let son = null, alanli = null;
  for (const y of kayitDosyalari(proje, ortam)) {
    let m; try { m = fs.readFileSync(y, 'utf8'); } catch { throw new KadroHata(500, 'Kayıt okunamadı: ' + y); }
    const s = m.split('\n'); const b = blokBul(s, 'id', id); if (!b) continue;
    son = { hedef: y, satirlar: s, b }; if (alan && alanBul(s, b, alan)) alanli = son;
  }
  return alanli || son;
}

export const DOSYA_NO = /^[0-9]{4}\/[0-9]{1,6}$/;
// Kayda yazılan oturum adı: koltuk adı kuralının DARALTILMIŞI — boşluk ve tırnak yok (açıcıların satır ayrıştırıcıları `\S+` okur)
const TMUX_KAYIT = /^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ-]{1,60}$/u;
const SID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
export function kisaAdGecerli(s) { const t = String(s || ''); return t.trim() === t && t.length >= 1 && [...t].length <= 60 && !/["\\\x00-\x1f\x7f]/.test(t); }

// E4 · yeni dava satırı (B6): kaydın ilk dosyasının (İSKÂN kutusunda iskan-registry.yaml — açıcı baslat-claude.sh de onu okur)
// `uyeler:` listesinin SONUNA blok eklenir. id başka bir dosyada da yoksa yazılır (409 "zaten rafta").
export function davaEkle({ proje, ortam = process.env, id, tmux, arz_adi, session_id, cwd }) {
  if (!DOSYA_NO.test(id)) throw new KadroHata(400, 'Dosya no YYYY/N biçiminde olmalı (ör. 2025/42).');
  if (!kisaAdGecerli(arz_adi)) throw new KadroHata(400, 'Kısa ad 1-60 harf olmalı; tırnak ve ters bölü olamaz.');
  if (!TMUX_KAYIT.test(tmux)) throw new KadroHata(409, `Oturum adı ("${tmux}") kayda yazılamaz — boşluk/özel karakter taşıyan oturum bağlanamaz.`);
  if (!SID.test(session_id)) throw new KadroHata(409, 'Oturumdaki Claude kimliği okunamadı.');
  const dosyalar = kayitDosyalari(proje, ortam);
  if (!dosyalar.length) throw new KadroHata(409, 'Bu kutuda kayıt dosyası yok — dava eklenecek yer yok.');
  for (const y of dosyalar) { let m; try { m = fs.readFileSync(y, 'utf8'); } catch { throw new KadroHata(500, 'Kayıt okunamadı: ' + y); }
    if (blokBul(m.split('\n'), 'id', id)) throw new KadroHata(409, `"${id}" zaten rafta.`); }
  const hedef = dosyalar[0]; const satirlar = fs.readFileSync(hedef, 'utf8').split('\n');
  const u = satirlar.findIndex((l) => /^uyeler:\s*(#.*)?$/.test(l));
  if (u < 0) throw new KadroHata(409, 'Kayıtta "uyeler:" listesi yok — dava eklenecek yer yok, dokunulmadı.');
  // listenin sonu: girintisiz ilk dolu satırdan önceki son dolu satır; öğe girintisi ilk `- ` satırından (yoksa 2)
  let son = u, tire = -1;
  for (let i = u + 1; i < satirlar.length; i++) { const l = satirlar[i]; if (!l.trim()) continue; if (!/^\s/.test(l)) break; son = i;
    if (tire < 0) { const m = l.match(/^(\s*)-\s/); if (m) tire = m[1].length; } }
  if (tire < 0) tire = 2;
  const sp = ' '.repeat(tire), ic = ' '.repeat(tire + 2);
  const blok = [sp + '- id: ' + id, ic + 'rol: dava', ic + 'tmux: "' + tmux + ':0"', ic + 'arz_adi: "' + arz_adi + '"',
    ic + 'session_id: ' + session_id, ...(cwd && /^\/[^\s"#]*$/.test(cwd) ? [ic + 'cwd: ' + cwd] : []), ic + 'bagla_ile: true'];
  satirlar.splice(son + 1, 0, ...blok);
  atomikYaz(hedef, satirlar.join('\n'));
  return { dosya: hedef };
}

// E4 · kişiye bağla (B6): oturum o kişinin oturumu sayılır → kişinin bloğuna session_id (kimlik eşleşmesi önce onu arar);
// önceki değer bagla_once'a (yoksa 'yok'). Üretilmiş bölgedeki kişiye yazılmaz (derleyici siler).
export function kisiyeBagla({ proje, ortam = process.env, id, session_id }) {
  if (!SID.test(session_id)) throw new KadroHata(409, 'Oturumdaki Claude kimliği okunamadı.');
  const f = blokDosyasi(proje, ortam, id, 'session_id'); if (!f) throw new KadroHata(404, `Kayıtta "${id}" yok.`);
  if (uretilmisMi(f.satirlar, f.b)) throw new KadroHata(409, `"${id}" derlenen kayıtta — bağlama oraya yazılamaz.`);
  const a = alanBul(f.satirlar, f.b, 'bagla_ile'); if (a && a.deger === 'true') throw new KadroHata(409, `"${id}" zaten bir bağlamayla gelmiş — önce onu geri al.`);
  const once = alanBul(f.satirlar, f.b, 'session_id');
  atomikYaz(f.hedef, alanlarYaz(f.satirlar.join('\n'), 'id', id, { session_id, bagla_once: once && once.deger ? once.deger : ONCEKI_YOK, bagla_ile: 'true' }));
  return { dosya: f.hedef, onceki: once ? once.deger : '' };
}

// G7 · bağlamayı geri al: yalnız `bagla_ile: true` taşıyan kayıt. Dava bloğu (bagla_once yok) bütünüyle silinir; kişide önceki
// session_id geri konur. Oturuma dokunulmaz — çağıran kapatmaz, oturum yeniden kayıtsız görünür.
export function baglaGeriAl({ proje, ortam = process.env, id }) {
  const f = blokDosyasi(proje, ortam, id, 'bagla_ile'); if (!f) throw new KadroHata(404, `Kayıtta "${id}" yok.`);
  const a = alanBul(f.satirlar, f.b, 'bagla_ile'); if (!a || a.deger !== 'true') throw new KadroHata(409, 'Bu kayıt bağlamayla gelmedi.');
  const o = alanBul(f.satirlar, f.b, 'bagla_once');
  if (!o) { const s = f.satirlar.slice(); s.splice(f.b.bas, f.b.son - f.b.bas + 1); atomikYaz(f.hedef, s.join('\n')); return { dosya: f.hedef, silindi: true }; }
  if (o.deger !== ONCEKI_YOK && !SID.test(o.deger)) throw new KadroHata(409, `Önceki kimlik okunamadı ("${o.deger}") — dokunulmadı.`);
  atomikYaz(f.hedef, alanlarYaz(f.satirlar.join('\n'), 'id', id, { session_id: o.deger === ONCEKI_YOK ? null : o.deger, bagla_once: null, bagla_ile: null }));
  return { dosya: f.hedef, silindi: false };
}

// Ana iş: kişinin hâlini yaz. Dönen: { dosya, uretilmis, onceki, yeni, derleme? }. Hata: KadroHata(kod, mesaj).
// ek: { alan: deger|null } — durumla AYNI yazımda bloğa işlenir (Dava Rafı: son_calisma · dondurma). Yalnız elle kayıtta;
// üretilmiş kayıtta ek yok sayılır (davalar orada yaşamaz, derleyici taşımaz).
export function kadroYaz({ proje, id, eylem, ortam = process.env, calistir = execFileSync, ek = null }) {
  const dosyalar = kayitDosyalari(proje, ortam);
  let hedef = null, satirlar = null, b = null;
  for (const y of dosyalar) {
    let m; try { m = fs.readFileSync(y, 'utf8'); } catch { throw new KadroHata(500, 'Kayıt okunamadı: ' + y); }
    const s = m.split('\n'); const bb = blokBul(s, 'id', id);
    if (bb) { hedef = y; satirlar = s; b = bb; }
  }
  if (!hedef) throw new KadroHata(404, `Kayıtta "${id}" yok.`);
  if (!uretilmisMi(satirlar, b)) {
    const r = durumDegistir(satirlar.join('\n'), 'id', id, eylem);
    atomikYaz(hedef, ek && Object.keys(ek).length ? alanlarYaz(r.metin, 'id', id, ek) : r.metin);
    return { dosya: hedef, uretilmis: false, onceki: r.onceki, yeni: r.yeni };
  }
  // ÜRETİLMİŞ: kaynak model + derleyici
  const model = path.join(proje, '_agents/ekip-modeli.yaml');
  const derleyici = derleyiciBul(proje, ortam);
  if (!derleyici) throw new KadroHata(503, 'Bu kutunun kaydı derleyiciyle üretiliyor ama derleyici kutuda yok — hiçbir şey yazılmadı.');
  let eski; try { eski = fs.readFileSync(model, 'utf8'); } catch { throw new KadroHata(500, 'Kayıt kaynağı okunamadı: ' + model); }
  const r = durumDegistir(eski, 'kayit', id, eylem);
  const fark = (r.onceki === 'canli' ? -1 : 0) + (r.yeni === 'canli' ? 1 : 0);
  atomikYaz(model, adetAyarla(r.metin, id, fark));
  // 🔴 TEMEL KATALOG DERLEYİCİNİNKİDİR (--base-katalog VERİLMEZ): kutularda _agents/ekip-os-base yok; boş yol verilince derleyici
  //    MÜDÜR kimliğindeki ortak-temel bölümünü siliyordu (gerçek ekipc ile s02 kopyasında ölçüldü, 52 satır).
  const hedefDiz = path.join(proje, '_agents/ekip-os');
  const derle = () => calistir('bash', [derleyici, 'derle', '--manifest', model, '--hedef', hedefDiz,
    // --aile: lint K8/K9 KUTUNUN kendi aile kaydını okumalı; verilmezse derleyicinin deposundakini (Nexus) okur ve her seferinde kırmızı verir (ölçüldü)
    ...(fs.existsSync(path.join(proje, '_agents/handoff/aile-registry.yaml')) ? ['--aile', path.join(proje, '_agents/handoff/aile-registry.yaml')] : []), '--apply'],
    { encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, ...ortam } });
  // 🔴 DERLEMENİN ETKİSİ YALNIZ KAYITLA SINIRLI: derleyici bekleyen başka farkları da yayar (ölçüldü 16 Eki: s02 · sedir · huzur'da merkezdeki
  //    güncel ortak-temel MÜDÜR kimliğine iniyordu). "Dondur" düğmesi başka bir ajanın kimlik metnini sessizce değiştirmemeli → derleme
  //    öncesi hedef dizinin fotoğrafı alınır; kayıt dosyası DIŞINDA değişen/eklenen her dosya eski hâline döner. Sayısı yanıtta söylenir.
  const foto = dizinFoto(hedefDiz);
  const sinirla = () => {
    let geri = 0;
    const simdi = dizinFoto(hedefDiz);
    for (const [y, m] of simdi) if (y !== hedef && foto.get(y) !== m) { if (foto.has(y)) atomikYaz(y, foto.get(y)); else fs.unlinkSync(y); geri++; }
    for (const [y, m] of foto) if (!simdi.has(y)) { fs.writeFileSync(y, m); geri++; }
    return geri;
  };
  // Geri alma derleyicisiz: model + hedef dizin derleme ÖNCESİ fotoğraftan bayt bayt geri konur (derleyiciyi yeniden koşturmak
  // bekleyen yabancı farkı tekrar yazıyordu — bağımsız göz tur 1 bulgusunun sınavında ölçüldü).
  const geriAl = () => {
    atomikYaz(model, eski);
    const simdi = dizinFoto(hedefDiz);
    for (const [y, m] of foto) if (simdi.get(y) !== m) { if (simdi.has(y)) atomikYaz(y, m); else fs.writeFileSync(y, m); }
    for (const y of simdi.keys()) if (!foto.has(y)) fs.unlinkSync(y);
  };
  try { derle(); }
  catch (e) { geriAl(); throw new KadroHata(502, 'Derleyici düştü, kaynak geri alındı: ' + String(e.stderr || e.message || '').trim().split('\n').pop()); }
  const baskaFark = sinirla();
  // Doğrula: üretilen kayıt yeni değeri taşıyor mu (taşımıyorsa ekranda görünmez → geri al)
  const s2 = fs.readFileSync(hedef, 'utf8').split('\n'); const b2 = blokBul(s2, 'id', id); const d2 = b2 && alanBul(s2, b2, 'durum');
  if ((d2 ? d2.deger : '') !== r.yeni) { geriAl(); throw new KadroHata(502, 'Derleme sonrası kayıt beklenen değeri taşımıyor, kaynak geri alındı.'); }
  // 🔴 KAYIT DOSYASININ İÇİ de sınırlı (bağımsız göz tur 1): derleyici aynı dosyada BAŞKA kişilerin satırlarını da değiştirdiyse
  //    (bekleyen derleme farkı) yazım kabul edilmez. Yalnız bu kişinin bloğu + üretilmiş bölgenin hash satırı değişebilir.
  //    Kısmi birleştirme YAPILMAZ: hash bütün üretilmiş gövdeyi kapsar, yarısını geri koymak bir sonraki derlemeyi "elle dokunulmuş"a
  //    düşürürdü. Dürüst yol: geri al, söyle (önce kutuda tam derleme gerekir — o Sultan'ın ayrı kararı).
  const s1 = foto.get(hedef).split('\n');
  const yabanci = s1.length !== s2.length ? -1 : s2.filter((l, i) => l !== s1[i] && !(i >= b2.bas && i <= b2.son) && !l.includes(URETILEN_BAS)).length;
  if (yabanci !== 0) { geriAl(); throw new KadroHata(409, 'Kayıt dosyasında bu kişiyle ilgisiz bekleyen derleme farkı var (' + (yabanci < 0 ? 'satır sayısı değişti' : yabanci + ' satır') + ') — hiçbir şey yazılmadı; önce kutuda tam derleme gerekir.'); }
  return { dosya: model, uretilmis: true, onceki: r.onceki, yeni: r.yeni, uygulanmayan_fark: baskaFark };
}

// Bir kadro eylemini GERİ ALIR (oturum kapatılamadıysa çağrılır): emekli/dondur → geri-ac ile aynı dönüşüm.
export function kadroGeriAl({ proje, id, ortam = process.env, calistir = execFileSync }) {
  return kadroYaz({ proje, id, eylem: 'geri-ac', ortam, calistir });
}
