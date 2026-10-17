// kapi/bugun.mjs — BUGÜNÜN LİSTESİ: kutudaki ajanların gün çıpalarını (gunluk-plan/cipa.sh'ın yazdığı dosyalar) OKUR, maddeleri
// yapılandırır. gorev_01M54SCQE08KTG9YERG2BBR604 (Sultan 17 Eki: "görev havuzundan ayrışmış bugün bölümü … terminalden aç kapa").
//
// 🔴 YENİ DEFTER KURULMAZ: kaynak çıpadır (`<proje>/_agents/handoff/gunluk-plan-cipa.<ajan>.md`, ajan başına; cipa.sh yazar,
//    cipa-ekle.sh gün ortası G<n>) maddelerini ekler). Bu modül yalnız okur ve ayrıştırır; yazma yolu yok.
// 🔴 Biçim cipa.sh'ın kendisinden (tek kaynak): başlık `# ⚓ GÜNÜN PLANI ÇIPASI · YYYY-MM-DD`; madde `- [x|~| |-] N) metin` ya da
//    `- [..] G<n>) metin`; `→ KAPANDI · not` / `→ YARIM · not` / `→ GERİ ALINDI` kuyruğu; `_yazıldı:` / `_dokunuldu:` damgaları.
//    Havuz bağı: metinde geçen `gorev_<ULID>` kimlikleri (madde ↔ havuz görevi ilişkisi — Sultan eki 14:3x).
// 🔴 Bugüne ait OLMAYAN çıpa listeye GİRMEZ (başka günün planı bugünün listesi değildir) ama adıyla `bugun_degil`de görünür —
//    "o ajanın çıpası yok" ile "bayat çıpası var" ayrı şeylerdir. Yedek (`.yedek.md`) ve eski tek dosya (`gunluk-plan-cipa.md`)
//    taranmaz; bozuk/okunamayan dosya `okunamadi`ya düşer, sessizce atlanmaz.
import fs from 'node:fs';
import path from 'node:path';

export const DURUM = { ' ': 'acik', '~': 'yarim', 'x': 'bitti', 'X': 'bitti', '-': 'geri' };
const MADDE = /^- \[([ ~xX-])\]\s*((G?\d+)\))?\s*(.*)$/;
const GOREV = /gorev_[A-Za-z0-9]{10,40}/g;
const DOSYA = /^gunluk-plan-cipa\.(.+)\.md$/;

export function cipaAyristir(metin) {
  const satirlar = String(metin || '').split('\n');
  const bas = satirlar.find((s) => /GÜNÜN PLANI ÇIPASI/.test(s)) || '';
  const tarih = (bas.match(/(\d{4}-\d{2}-\d{2})/) || [])[1] || null;
  const maddeler = [];
  for (const s of satirlar) {
    const m = s.match(MADDE);
    if (!m) continue;
    const govde = m[4].trim();
    // kuyruk: "→ KAPANDI · not" | "→ YARIM · not" | "→ GERİ ALINDI" — sonuç + not ayrılır, metin temiz kalır
    const k = govde.match(/^(.*?)\s*→\s*([A-ZĞÜŞİÖÇ][A-ZĞÜŞİÖÇ ]{2,})(?:\s*·\s*(.*))?$/);
    const etiket = m[3] || '';
    maddeler.push({
      etiket, tur: etiket.startsWith('G') ? 'gun-ortasi' : (etiket ? 'sabah' : 'serbest'),
      durum: DURUM[m[1]] || 'acik',
      metin: (k ? k[1] : govde).trim(),
      sonuc: k ? k[2].trim() : '', not: k && k[3] ? k[3].trim() : '',
      gorevler: Array.from(new Set((govde.match(GOREV) || []))),
    });
  }
  const damga = (ad) => (((satirlar.find((s) => s.startsWith('_' + ad + ':')) || '').match(/:\s*(\S+)/) || [])[1] || '').replace(/_+$/, '') || null;
  return { tarih, maddeler, yazildi: damga('yazıldı'), dokunuldu: damga('dokunuldu') };
}

export function sayilar(maddeler) {
  const s = { acik: 0, yarim: 0, bitti: 0, geri: 0, toplam: maddeler.length };
  for (const m of maddeler) s[m.durum] = (s[m.durum] || 0) + 1;
  return s;
}

/** Kutunun bugünkü listesi. bugun: 'YYYY-MM-DD' (sınav dikişi; varsayılan yerel bugün). */
export function bugunOku(proje, bugun) {
  const gun = bugun || yerelTarih();
  const diz = path.join(proje, '_agents', 'handoff');
  const sonuc = { tarih: gun, dizin: diz, ajanlar: [], bugun_degil: [], okunamadi: [], var: fs.existsSync(diz) };
  if (!sonuc.var) return sonuc;
  let adlar = [];
  try { adlar = fs.readdirSync(diz).filter((a) => DOSYA.test(a) && !/\.yedek\.md$/.test(a)).sort(); }
  catch (e) { sonuc.okunamadi.push({ dosya: diz, hata: e.code || String(e) }); return sonuc; }
  for (const ad of adlar) {
    const ajan = ad.match(DOSYA)[1];
    const yol = path.join(diz, ad);
    let metin;
    try { metin = fs.readFileSync(yol, 'utf8'); } catch (e) { sonuc.okunamadi.push({ dosya: ad, hata: e.code || String(e) }); continue; }
    const c = cipaAyristir(metin);
    if (c.tarih !== gun) { sonuc.bugun_degil.push({ ajan, dosya: ad, tarih: c.tarih }); continue; }
    sonuc.ajanlar.push({ ajan, dosya: ad, ...c, sayilar: sayilar(c.maddeler) });
  }
  sonuc.toplam = sayilar(sonuc.ajanlar.flatMap((a) => a.maddeler));
  return sonuc;
}

export function yerelTarih(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
