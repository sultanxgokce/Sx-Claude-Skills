// a4_dogrula.mjs — A4-MUTABAKAT'ın SAYIMSAL doğrulayıcısı (FAZ-1, MOTOR-sınıfı: proje-bilmez).
// A4-subagent'ı (taze-context, builder-transkripti GÖRMEDEN) her C-ID için {normatif?, m_refs[]}
// SINIFLANDIRMA-tablosu emit eder; PASS/FAIL kararını o LLM DEĞİL bu script verir (tasarım RT1-K4):
//   (1) cumle_bolucu-çıktısındaki HER C-ID tabloda TAM-1-kez;
//   (2) normatif=true -> m_refs en-az-1 VE her m_ref matris'te var;
//   (3) tabloda cumle-listesinde olmayan C-ID yok (uydurma-satır yasağı);
//   (4) "normatif-değil" listesi çıktıya İSİMLİ (iş-sahibi veto-yüzeyi — sessiz-düşürme yok).
// Girdi: --cumleler <cumle_bolucu-json> --eslesme <a4-tablo-json> --matris <matris-md>
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const SKILL_VERSION = '0.2.1-faz1';

function matrisMIdleri(matrisMetni) {
  const idler = new Set();
  const cIdler = new Map(); // M# -> C-ID (matris-satırındaki)
  for (const satir of matrisMetni.split('\n')) {
    const parcalar = satir.split(/(?<!\\)\|/);
    if (parcalar.length >= 3 && /^\s*M\d+\s*$/.test(parcalar[1] ?? '')) {
      const mId = parcalar[1].trim();
      idler.add(mId);
      cIdler.set(mId, (parcalar[2] ?? '').trim());
    }
  }
  return { idler, cIdler };
}

export function dogrula({ cumlelerYolu, eslesmeYolu, matrisYolu }) {
  const cumleler = JSON.parse(readFileSync(cumlelerYolu, 'utf8'));
  const eslesme = JSON.parse(readFileSync(eslesmeYolu, 'utf8'));
  const { idler: matristeki, cIdler: matrisCIdler } = matrisMIdleri(readFileSync(matrisYolu, 'utf8'));

  const ihlaller = [];
  const normatifDegil = [];
  const kaynakCIdler = new Set(
    (cumleler.cumleler ?? []).filter((c) => c.tip !== 'baslik').map((c) => c.c_id),
  );
  // Tüm cümle C-ID'leri (baslik dahil) — matris-satırının işaret ettiği C-ID kaynak-listede OLMALI.
  const tumCIdler = new Set((cumleler.cumleler ?? []).map((c) => c.c_id));

  const tablo = Array.isArray(eslesme.tablo) ? eslesme.tablo : eslesme;
  const gorulen = new Map();
  const a4Map = new Map(); // c_id -> A4-girdisi (matris↔A4 self-tutarlılık için)
  for (const girdi of tablo) {
    const cId = girdi.c_id;
    gorulen.set(cId, (gorulen.get(cId) ?? 0) + 1);
    a4Map.set(cId, girdi);
    if (!kaynakCIdler.has(cId)) {
      ihlaller.push(`uydurma-satır: ${cId} cumle-listesinde yok (A4 kaynak-dışı C-ID üretemez)`);
      continue;
    }
    if (girdi.normatif === true) {
      const refs = Array.isArray(girdi.m_refs) ? girdi.m_refs : [];
      if (refs.length === 0) {
        ihlaller.push(`eşlenmemiş-normatif: ${cId} normatif ama hiçbir M-satırına bağlanmamış (gereklilik-atlaması)`);
      }
      for (const ref of refs) {
        if (!matristeki.has(ref)) ihlaller.push(`kırık-ref: ${cId} -> ${ref} matris'te yok`);
      }
    } else {
      normatifDegil.push({ c_id: cId, gerekce: girdi.gerekce ?? null });
    }
  }
  for (const [cId, adet] of gorulen) {
    if (adet > 1) ihlaller.push(`çift-sınıflandırma: ${cId} tabloda ${adet} kez (tam-1-kez kuralı)`);
  }
  for (const cId of kaynakCIdler) {
    if (!gorulen.has(cId)) ihlaller.push(`eksik-sınıflandırma: ${cId} A4-tablosunda hiç yok (her cümle sınıflandırılır)`);
  }

  // MATRİS↔A4 SELF-TUTARLILIK (cIdler yarım-kablosu kapatıldı): matris-satırının C-ID-kolonu
  // (1) kaynak-cümle-listesinde OLMALI (uydurma-çıpa yasağı); (2) A4-tablosunca normatif işaretlenmiş
  // VE m_refs o M#'i içermeli (matris "M ← C" der, A4 bunu doğrulamalı — iki-yön kilit).
  for (const [mId, cId] of matrisCIdler) {
    if (!tumCIdler.has(cId)) {
      ihlaller.push(`matris-uydurma-C-ID: ${mId} satırı ${cId} işaret ediyor ama cumleler-listesinde yok`);
      continue;
    }
    const g = a4Map.get(cId);
    if (!g || g.normatif !== true) {
      ihlaller.push(`matris↔A4 tutarsız: ${mId} ← ${cId} ama A4 bu C-ID'yi normatif işaretlememiş`);
    } else if (!(Array.isArray(g.m_refs) && g.m_refs.includes(mId))) {
      ihlaller.push(`matris↔A4 tutarsız: ${mId} satırı ${cId}'i çıpalıyor ama A4 m_refs bu M#'i içermiyor`);
    }
  }

  return {
    skill_version: SKILL_VERSION,
    gecti: ihlaller.length === 0,
    ihlaller,
    normatif_degil: normatifDegil, // İSİMLİ — iş-sahibi bu listeyi görür, veto edebilir
    sayim: { kaynak_cumle: kaynakCIdler.size, tablo_girdisi: tablo.length, normatif_degil: normatifDegil.length, matris_satir: matrisCIdler.size },
  };
}

function kullanim() {
  process.stderr.write('kullanım: node a4_dogrula.mjs --cumleler <json> --eslesme <json> --matris <md>\n');
  process.exit(2);
}

function main() {
  const argv = process.argv.slice(2);
  const arg = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--cumleler') arg.cumlelerYolu = argv[++i];
    else if (argv[i] === '--eslesme') arg.eslesmeYolu = argv[++i];
    else if (argv[i] === '--matris') arg.matrisYolu = argv[++i];
    else kullanim();
  }
  if (!arg.cumlelerYolu || !arg.eslesmeYolu || !arg.matrisYolu) kullanim();
  const sonuc = dogrula(arg);
  process.stdout.write(JSON.stringify(sonuc, null, 2) + '\n');
  process.exit(sonuc.gecti ? 0 : 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
