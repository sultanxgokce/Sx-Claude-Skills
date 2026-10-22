/**
 * tarif.test.mjs — Kadro Uzmanlıklar + Terimler kaynakları (tarif.mjs · Mühürdarlık G12). Hermetik: geçici dizinde fikstür, ağ yok.
 *   node tarif.test.mjs     · mutasyon: tarif.mutasyon.sh
 * Ölçülen: beyaz liste (yol · kaynak · kapi_yolu · persona location/contact · diploma kanit/kume_sha SIZMAZ) · okunamayan kaynak = olc + null (boş liste DEĞİL) ·
 *   bozuk JSON / beklenmedik biçim = olc · boş diploma defteri = [] (ölçülmüş sıfır) · bozuk diploma satırı = olc · beceri kurulu/değil · adım sırası · bilinmeyen tür/durum.
 */
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tarifOku, uzmanlikOku, tarifYollari } from './tarif.mjs';
let gecen = 0, kalan = 0;
const kapi = (ad, k, ek = '') => { if (k) { gecen++; console.log(`  ✓ ${ad}`); } else { kalan++; console.log(`  ✗ ${ad} ${ek}`); } };
const T = mkdtempSync(join(tmpdir(), 'tarif-sinav-'));
const VERI = join(T, 'skills/tarif-kaydi/veri'); mkdirSync(VERI, { recursive: true }); mkdirSync(join(T, 'skills/tescil'), { recursive: true });
writeFileSync(join(T, 'skills/tescil/SKILL.md'), '---\nname: tescil\n---\n');
const SIR = '/config/projects/Nexus/_agents/GIZLI-YOL';
writeFileSync(join(VERI, 'kadro-tarifleri.json'), JSON.stringify({ sema_surumu: 2, kaynak: SIR,
  uzmanliklar: [{ sema_surumu: 2, id: 'muhurdarlik', ad: 'Mühürdarlık', unvan: 'mühürdar', vazifeler: ['tescil'], el_kitabi: 'tescil', sinav: { kume: SIR }, sicil_esigi: { kacirma: 2, pencere: 10 }, durum: 'planli' }],
  vazifeler: [{ id: 'tescil', ad: 'Tescil', uzmanlik: 'muhurdarlik', usuller: ['u1'], cakisir: ['ders-cikarma'], denetler: ['hedef-turu-is'], kor: true, yedek: { tur: 'bassiz-sapka', bekleme_dk: 30 }, model: 'x', gizli: SIR }],
  usuller: [{ id: 'u1', ad: 'Tescil usulü', vazife: 'tescil', tetik: 'teslim', cikti: SIR, adimlar: [
    { sira: 3, tur: 'sultan_eli', ne_yapar: 'Sultan dener', sultan_eli_tarifi: '10 sn bak' },
    { sira: 1, tur: 'kapi', kapi_yolu: SIR + '/kapi.sh', ne_yapar: 'biçim kapısı' },
    { sira: 2, tur: 'beceri', beceri_id: 'tescil', ne_yapar: 'sınar' },
    { sira: 4, tur: 'beceri', beceri_id: 'olmayan-beceri', ne_yapar: 'yok' },
    { sira: 5, tur: 'uydurma', ne_yapar: 'tür dışı' }] }] }));
writeFileSync(join(VERI, 'terim-kaydi.json'), JSON.stringify({ sema_surumu: 2, kaynak: SIR, kaynak_bicimi: SIR,
  terimler: [{ id: 'personel', ad: 'Personel', kok: 'personel', anlam: 'Ajan', isleyis: 'kayıtta yaşar', ornek: 'MUHAKKİK', karistirilan: ['koltuk'], ayirt_testi: null, sahip: 'SERDAR', durum: 'aday', kaynak: [SIR], katman: 'personel' }] }));
const NX = join(T, 'nexus/_agents/orchestration'); mkdirSync(NX, { recursive: true });
writeFileSync(join(NX, 'agent-registry.json'), JSON.stringify({ personas: [
  { ad: 'MUHAKKİK', location: SIR, contact: 'gizli@x', runtime: SIR, uzmanliklar: [{ uzmanlik: 'muhurdarlik', durum: 'aday', yedek_icin: [SIR] }, { uzmanlik: 'x', durum: 'uydurma' }] },
  { ad: 'SERDAR', location: SIR }, { kimlik: 'adsiz' }] }));
writeFileSync(join(NX, 'diploma-defteri.jsonl'), '');
const O = { TO_TARIF_DIZIN: VERI, TO_AJAN_KAYDI: join(NX, 'agent-registry.json') };

// ── tarif ──
const t = tarifOku(O), J = JSON.stringify(t);
kapi('T1 yollar: beceri dizini veri dizininin iki üstü (skills/), diploma kaydın yanında', tarifYollari(O).beceri === join(T, 'skills') && tarifYollari(O).diploma === join(NX, 'diploma-defteri.jsonl'));
kapi('T2 tarif okunur: 1 uzmanlık · 1 vazife · 1 usul; olc yok', t.tarif && t.tarif.uzmanliklar.length === 1 && t.tarif.vazifeler.length === 1 && t.tarif.usuller.length === 1 && t.olc.tarif === null && t.olc.terim === null, J.slice(0, 300));
kapi('T3 SIZINTI YOK: gizli yol · kapi_yolu · kaynak · model · cikti · sinav yanıtta geçmez', !J.includes('GIZLI-YOL') && !J.includes('kapi_yolu') && !J.includes('"kaynak"') && !J.includes('"model"') && !J.includes('"cikti"') && !J.includes('"sinav"'), J.match(/.{40}GIZLI-YOL.{10}/)?.[0] || '');
const u = t.tarif.usuller[0];
kapi('T4 adımlar sıraya dizilir (1 kapı · 2 beceri · 3 Sultan eli · …); kapı adımında yol yok, ne yaptığı var', u.adimlar.map((a) => a.sira + a.tur).join(',') === '1kapi,2beceri,3sultan_eli,4beceri,5bilinmiyor' && u.adimlar[0].ne_yapar === 'biçim kapısı', JSON.stringify(u.adimlar));
kapi('T5 beceri adımı: kurulu (SKILL.md var) → kurulu:true · kurulu değil → kurulu:false; tür dışı adım "bilinmiyor"', u.adimlar[1].beceri_id === 'tescil' && u.adimlar[1].kurulu === true && u.adimlar[3].kurulu === false && u.adimlar[4].tur === 'bilinmiyor');
kapi('T6 Sultan eli adımı tarifiyle; vazife çakışır/denetler/kör/yedek taşınır', u.adimlar[2].sultan_eli_tarifi === '10 sn bak' && JSON.stringify(t.tarif.vazifeler[0]) === JSON.stringify({ id: 'tescil', ad: 'Tescil', uzmanlik: 'muhurdarlik', usuller: ['u1'], cakisir: ['ders-cikarma'], denetler: ['hedef-turu-is'], kor: true, yedek: { tur: 'bassiz-sapka', bekleme_dk: 30 } }), JSON.stringify(t.tarif.vazifeler[0]));
kapi('T7 terim: anlam · işleyiş · örnek · karıştırılan · sahip · durum · katman; kök ve kaynak yok', JSON.stringify(t.terim.terimler[0]) === JSON.stringify({ id: 'personel', ad: 'Personel', anlam: 'Ajan', isleyis: 'kayıtta yaşar', ornek: 'MUHAKKİK', karistirilan: ['koltuk'], ayirt_testi: null, sahip: 'SERDAR', durum: 'aday', katman: 'personel' }), JSON.stringify(t.terim.terimler[0]));
// ── ölçülemedi ≠ boş ──
const t0 = tarifOku({ TO_TARIF_DIZIN: join(T, 'yok') });
kapi('T8 kaynak YOK → tarif ve terim null + olc "kaynak yok" (boş liste DEĞİL)', t0.tarif === null && t0.terim === null && t0.olc.tarif === 'kaynak yok' && t0.olc.terim === 'kaynak yok', JSON.stringify(t0));
const B = join(T, 'bozuk'); mkdirSync(B); writeFileSync(join(B, 'kadro-tarifleri.json'), '{ yarım'); writeFileSync(join(B, 'terim-kaydi.json'), JSON.stringify({ terimler: 'dizi değil' }));
const tb = tarifOku({ TO_TARIF_DIZIN: B });
kapi('T9 bozuk JSON → olc "bozuk"; terimler dizi değil → olc "biçimi beklenmedik" (ikisi de null)', tb.tarif === null && /bozuk/.test(tb.olc.tarif) && tb.terim === null && /biçimi beklenmedik/.test(tb.olc.terim), JSON.stringify(tb));
const D = join(T, 'dizin'); mkdirSync(join(D, 'kadro-tarifleri.json'), { recursive: true }); writeFileSync(join(D, 'terim-kaydi.json'), JSON.stringify({ terimler: [] }));
const td = tarifOku({ TO_TARIF_DIZIN: D });
kapi('T10 dosya yerinde dizin (okunamıyor) → "kaynak okunamadı"; terimler GERÇEKTEN boşsa [] (ölçülmüş sıfır, olc yok)', td.tarif === null && td.olc.tarif === 'kaynak okunamadı' && Array.isArray(td.terim.terimler) && td.terim.terimler.length === 0 && td.olc.terim === null, JSON.stringify(td));
// ── uzmanlık ──
const z = uzmanlikOku(O), ZJ = JSON.stringify(z);
kapi('Z1 personel: adı olan her persona (adsız atlanır); MUHAKKİK aday Mühürdarlık, bilinmeyen durum "bilinmiyor"; SERDAR uzmanlıksız', z.personel.length === 2 && JSON.stringify(z.personel[0]) === JSON.stringify({ ad: 'MUHAKKİK', uzmanliklar: [{ uzmanlik: 'muhurdarlik', durum: 'aday' }, { uzmanlik: 'x', durum: 'bilinmiyor' }] }) && z.personel[1].uzmanliklar.length === 0, ZJ);
kapi('Z2 SIZINTI YOK: location · contact · runtime · yedek_icin yanıtta geçmez', !ZJ.includes('GIZLI-YOL') && !ZJ.includes('gizli@x') && !ZJ.includes('location') && !ZJ.includes('yedek_icin'), ZJ);
kapi('Z3 boş diploma defteri → [] (ölçülmüş sıfır, olc yok)', Array.isArray(z.diploma) && z.diploma.length === 0 && z.olc.diploma === null && z.olc.personel === null, ZJ);
const NX2 = join(T, 'nx2'); mkdirSync(NX2);
writeFileSync(join(NX2, 'agent-registry.json'), JSON.stringify({ personas: [] }));
writeFileSync(join(NX2, 'diploma-defteri.jsonl'), JSON.stringify({ ts: '2026-10-22T05:00:00Z', personel: 'MUHAKKİK', uzmanlik: 'muhurdarlik', el_kitabi: 'tescil', el_kitabi_surum: '0.3.0', kume_sha: 'abc123gizli', sonuc: { dogru: 3 }, gecti: 'e', kanit: SIR }) + '\n');
const z2 = uzmanlikOku({ TO_AJAN_KAYDI: join(NX2, 'agent-registry.json') });
kapi('Z4 diploma satırı: ts · personel · uzmanlık · el kitabı sürümü · geçti; kanit ve kume_sha YOK', JSON.stringify(z2.diploma) === JSON.stringify([{ ts: '2026-10-22T05:00:00Z', personel: 'MUHAKKİK', uzmanlik: 'muhurdarlik', el_kitabi_surum: '0.3.0', gecti: 'e' }]) && !JSON.stringify(z2).includes('gizli'), JSON.stringify(z2));
writeFileSync(join(NX2, 'diploma-defteri.jsonl'), JSON.stringify({ personel: 'A', uzmanlik: 'b', gecti: 'e' }) + '\n{bozuk\n');
const z3 = uzmanlikOku({ TO_AJAN_KAYDI: join(NX2, 'agent-registry.json') });
kapi('Z5 okunamayan diploma satırı → diploma null + olc (yarım liste "sağlam" diye dönmez)', z3.diploma === null && /okunamayan satır/.test(z3.olc.diploma), JSON.stringify(z3));
const z4 = uzmanlikOku({ TO_AJAN_KAYDI: join(T, 'yok/agent-registry.json') });
kapi('Z6 kayıt YOK → personel null + olc "kaynak yok"; diploma da "kaynak yok" (boş liste DEĞİL)', z4.personel === null && z4.olc.personel === 'kaynak yok' && z4.diploma === null && z4.olc.diploma === 'kaynak yok', JSON.stringify(z4));
writeFileSync(join(NX2, 'agent-registry.json'), JSON.stringify({ personas: { ad: 'dizi değil' } }));
const z5 = uzmanlikOku({ TO_AJAN_KAYDI: join(NX2, 'agent-registry.json') });
kapi('Z7 personas dizi değil → personel null + "biçimi beklenmedik"', z5.personel === null && /biçimi beklenmedik/.test(z5.olc.personel), JSON.stringify(z5));
// ── GERÇEK KAYIT (fikstür dersi: biçim gerçek kayıttan doğrulanır) — bu depodaki tarif-kaydi/veri ──
const GERCEK = join(fileURLToPath(new URL('.', import.meta.url)), '../../tarif-kaydi/veri');
const g = tarifOku({ TO_TARIF_DIZIN: GERCEK }), GJ = JSON.stringify(g);
kapi('G1 gerçek tarif-kaydi: 1 uzmanlık (Mühürdarlık) · 3 vazife · 3 usul · 36 terim, olc yok', g.tarif && g.tarif.uzmanliklar.length === 1 && g.tarif.uzmanliklar[0].ad === 'Mühürdarlık' && g.tarif.vazifeler.length === 3 && g.tarif.usuller.length === 3 && g.terim && g.terim.terimler.length === 36 && !g.olc.tarif && !g.olc.terim, `→ ${JSON.stringify(g.olc)} ${g.terim?.terimler.length}`);
// sızıntı ölçütü KAYNAĞIN KENDİSİNDEN: ham dosyalardaki her `kaynak` değeri ve her `kapi_yolu` — yanıtta bütün bir değer olarak geçmemeli (düz yazıda "beceri:x" ifadesi yol değildir)
const ham = [readFileSync(join(GERCEK, 'kadro-tarifleri.json'), 'utf8'), readFileSync(join(GERCEK, 'terim-kaydi.json'), 'utf8')].map((x) => JSON.parse(x));
const yollar = []; const topla = (o) => { if (Array.isArray(o)) o.forEach(topla); else if (o && typeof o === 'object') for (const [k, v] of Object.entries(o)) { if (k === 'kaynak' || k === 'kapi_yolu' || k === 'kaynak_bicimi') [].concat(v).forEach((x) => typeof x === 'string' && x && yollar.push(x)); else topla(v); } }; ham.forEach(topla);
kapi(`G2 gerçek kayıtta sızıntı yok: kaynaktaki ${yollar.length} kaynak/kapı yolu değerinin hiçbiri yanıtta değer olarak geçmez; her usul adımı bilinen türde`, yollar.length > 30 && !yollar.some((y) => GJ.includes(JSON.stringify(y))) && g.tarif.usuller.every((u) => u.adimlar.length && u.adimlar.every((a) => a.tur !== 'bilinmiyor')), `→ ${yollar.length} yol · sızan: ${yollar.filter((y) => GJ.includes(JSON.stringify(y))).slice(0, 3)}`);
console.log(`\nSONUÇ: ${gecen} geçti · ${kalan} kaldı`);
process.exit(kalan ? 1 : 0);
