// cumle_bolucu.mjs — deterministik cümle-bölücü (FAZ-0 iskelet, MOTOR-sınıfı: proje-bilmez).
// Markdown alır (stdin veya dosya); başlık/kod-bloğu/tablo satırları normatif-aday DEĞİLDİR
// (kod-bloğu/tablo `atlananlar`da etiketle listelenir, başlık tip=baslik ile işaretlenir).
// Paragraf metni tr/en cümlelere bölünür (`. ! ?` sınırları + basit kısaltma-listesi koruması);
// her cümleye deterministik kimlik verilir: C-<sha256(boşluk-normalize(cümle))[0:8]>.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const SKILL_VERSION = '0.2.1-faz1';

// Tematik-ayraç (yatay-çizgi): tek-başına 3+ `-`/`*`/`_`. Normatif-aday DEĞİL (biçim, cümle değil).
const TEMATIK_AYRAC = /^(-{3,}|\*{3,}|_{3,})$/;

// Kısaltma-koruması: basit kapalı-liste (küçük-harf karşılaştırılır). FAZ-1: config'ten ek-liste.
const KISALTMALAR = new Set(['ör.', 'vb.', 'bkz.', 'dr.', 'no.', 'vs.']);

// Boşluk-normalize: trim + çoklu-boşluk -> tek boşluk. Harf-büyüklüğü/karakterler VERBATIM korunur
// (lowercase YAPILMAZ) — C-ID bu normalize edilmiş metnin sha256'sından türetilir.
export function normalize(metin) {
  return metin.trim().replace(/\s+/g, ' ');
}

export function cIdUret(metin) {
  return 'C-' + createHash('sha256').update(normalize(metin), 'utf8').digest('hex').slice(0, 8);
}

// Birleşik paragraf-metnini cümle parçalarına böler; her parçanın birleşik-metin içindeki
// başlangıç-ofsetini döndürür (satır-numarası eşlemesi için).
function cumleParcala(birlesik) {
  const parcalar = [];
  let baslangic = 0;
  for (let i = 0; i < birlesik.length; i++) {
    const kr = birlesik[i];
    if (kr !== '.' && kr !== '!' && kr !== '?') continue;
    // ardışık sonlandırıcıları tek sınır say (ör. "..." / "?!")
    let j = i;
    while (j + 1 < birlesik.length && '.!?'.includes(birlesik[j + 1])) j++;
    const sonraki = birlesik[j + 1];
    // sınır sayılması için sonda olmalı ya da boşluk izlemeli (ondalık/dosya-adı koruması)
    if (sonraki !== undefined && !/\s/.test(sonraki)) {
      i = j;
      continue;
    }
    if (kr === '.' && j === i) {
      // kısaltma-koruması: noktayla biten son kelimeye bak
      const oncesi = birlesik.slice(baslangic, i + 1);
      const kelime = oncesi.match(/(\S+)$/);
      if (kelime) {
        const aday = kelime[1].replace(/^[(["'«]+/, '').toLowerCase();
        if (KISALTMALAR.has(aday)) {
          i = j;
          continue;
        }
      }
    }
    const metin = birlesik.slice(baslangic, j + 1);
    if (metin.trim()) parcalar.push({ metin, baslangic });
    i = j;
    baslangic = j + 1;
  }
  const kalan = birlesik.slice(baslangic);
  if (kalan.trim()) parcalar.push({ metin: kalan, baslangic });
  return parcalar;
}

// Ana giriş: markdown metnini cümle-adaylarına böler.
// Dönüş: { kaynak_dosya, cumleler: [{c_id, metin, satir_no, tip: paragraf|baslik|liste}],
//          atlananlar: [{satir_no, tip: kod-blogu|tablo, metin}] }
export function bol(hamMetin, kaynakDosya = '<stdin>') {
  const satirlar = hamMetin.split(/\r?\n/);
  const cumleler = [];
  const atlananlar = [];
  let kodIcinde = false;
  let paragraf = []; // {metin, satirNo}

  const paragrafiBosalt = () => {
    if (!paragraf.length) return;
    let birlesik = '';
    const dilimler = []; // birleşik-metin ofseti -> satır-numarası eşlemesi
    for (const p of paragraf) {
      if (birlesik) birlesik += ' ';
      dilimler.push({ baslangic: birlesik.length, satirNo: p.satirNo });
      birlesik += p.metin;
    }
    for (const parca of cumleParcala(birlesik)) {
      const norm = normalize(parca.metin);
      if (!norm) continue;
      const etkinBaslangic = parca.baslangic + (parca.metin.length - parca.metin.trimStart().length);
      let satirNo = dilimler[0].satirNo;
      for (const d of dilimler) if (d.baslangic <= etkinBaslangic) satirNo = d.satirNo;
      cumleler.push({ c_id: cIdUret(norm), metin: norm, satir_no: satirNo, tip: 'paragraf' });
    }
    paragraf = [];
  };

  // YAML-frontmatter: dosya-başı `---` … `---` bloğu normatif-aday DEĞİLDİR (metadata, cümle değil).
  // Dogfood-kanıtı: frontmatter paragraf-sayılıp gerçek FIX-gerekliliğine karışmıştı (gürültü).
  let baslangicIdx = 0;
  if ((satirlar[0] ?? '').trim() === '---') {
    let kapanis = -1;
    for (let k = 1; k < satirlar.length; k++) {
      if (satirlar[k].trim() === '---') { kapanis = k; break; }
    }
    if (kapanis !== -1) {
      for (let k = 0; k <= kapanis; k++) atlananlar.push({ satir_no: k + 1, tip: 'frontmatter', metin: satirlar[k] });
      baslangicIdx = kapanis + 1;
    }
  }

  for (let i = baslangicIdx; i < satirlar.length; i++) {
    const ham = satirlar[i];
    const kirpik = ham.trim();
    const satirNo = i + 1;

    // kod-bloğu çiti (``` / ~~~): çit satırları + içerik normatif-aday değildir
    if (/^(```|~~~)/.test(kirpik)) {
      paragrafiBosalt();
      kodIcinde = !kodIcinde;
      atlananlar.push({ satir_no: satirNo, tip: 'kod-blogu', metin: kirpik });
      continue;
    }
    if (kodIcinde) {
      atlananlar.push({ satir_no: satirNo, tip: 'kod-blogu', metin: ham });
      continue;
    }
    if (!kirpik) {
      paragrafiBosalt();
      continue;
    }
    // tablo satırı: normatif-aday değildir, etiketle listelenir
    if (kirpik.startsWith('|')) {
      paragrafiBosalt();
      atlananlar.push({ satir_no: satirNo, tip: 'tablo', metin: kirpik });
      continue;
    }
    // tematik-ayraç (yatay çizgi): biçim-öğesi, normatif-aday değil (liste-maddesinden ÖNCE denetlenir)
    if (TEMATIK_AYRAC.test(kirpik)) {
      paragrafiBosalt();
      atlananlar.push({ satir_no: satirNo, tip: 'tematik-ayrac', metin: kirpik });
      continue;
    }
    // başlık: normatif-aday değildir, tip=baslik etiketiyle listelenir
    const baslik = kirpik.match(/^#{1,6}\s+(.*)$/);
    if (baslik) {
      paragrafiBosalt();
      const norm = normalize(baslik[1]);
      if (norm) cumleler.push({ c_id: cIdUret(norm), metin: norm, satir_no: satirNo, tip: 'baslik' });
      continue;
    }
    // liste-maddesi (- / * / + / 1. / 1)): madde bütünüyle TEK cümle-adayıdır
    const liste = kirpik.match(/^([-*+]|\d+[.)])\s+(.*)$/);
    if (liste) {
      paragrafiBosalt();
      const norm = normalize(liste[2]);
      if (norm) cumleler.push({ c_id: cIdUret(norm), metin: norm, satir_no: satirNo, tip: 'liste' });
      continue;
    }
    // paragraf satırı (alıntı işaretleri soyularak biriktirilir)
    paragraf.push({ metin: kirpik.replace(/^(>\s?)+/, ''), satirNo });
  }
  paragrafiBosalt();

  return { kaynak_dosya: kaynakDosya, cumleler, atlananlar };
}

function kullanim() {
  process.stderr.write('kullanım: node cumle_bolucu.mjs <dosya|-> [--json <çıktı-yolu>]\n');
  process.exit(2);
}

function main() {
  const argv = process.argv.slice(2);
  let dosya = null;
  let jsonYolu = null;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--json') {
      jsonYolu = argv[++i];
      if (!jsonYolu) kullanim();
    } else if (argv[i] === '--help' || argv[i] === '-h') {
      kullanim();
    } else if (dosya === null) {
      dosya = argv[i];
    } else {
      kullanim();
    }
  }
  const ham = !dosya || dosya === '-' ? readFileSync(0, 'utf8') : readFileSync(dosya, 'utf8');
  const sonuc = bol(ham, dosya && dosya !== '-' ? dosya : '<stdin>');
  sonuc.skill_version = SKILL_VERSION; // çıktı-raporu damgası
  const cikti = JSON.stringify(sonuc, null, 2) + '\n';
  if (jsonYolu) writeFileSync(jsonYolu, cikti);
  else process.stdout.write(cikti);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
