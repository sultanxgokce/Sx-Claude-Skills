// durum_uret.mjs — matris durum-kolonu REJENERATÖRÜ (FAZ-1, MOTOR-sınıfı: proje-bilmez).
// "durum = türetilmiş-veri" ilkesinin by-construction TEK-YAZARI: her M-satırı için
// kanit/<M#>.json bulunur, DÖRTLÜ-DENETİM (a: geçerli-JSON, b: komut-hash eşleşmesi,
// c: rc==0, d: tazelik>son-git-commit + d2: working-tree invalidasyonu) + FAZ-1 KIRMIZI-KANIT-ŞARTI
// (kanitli için kirmizi_kanit_ref zorunlu + §1.2 KOMUT-KİLİDİ: kırmızı AYNI komutun FAIL'i olmalı —
// hiç-FAIL-edemeyen ya da FARKLI-komuttan test kanıt sayılmaz) uygulanır; diğer hücreler byte-korunur.
// TSV-emit (FORMAT §5): kanit/ozet.tsv her rejenerasyonda JSON'lardan YENİDEN üretilir
// (TSV=önbellek, kanonik=JSON; elle-TSV yaşayamaz). Yol-çözüm: git-common-dir → ana-depo kökü.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, dirname, basename, join } from 'node:path';
import { pathToFileURL } from 'node:url';

export const SKILL_VERSION = '0.2.1-faz1';

// İş-sahibi-gate'li durumlar: kanıttan türetilemez, rejeneratör bunlara DOKUNMAZ (raporda isimli).
const KORUNAN_DURUMLAR = new Set(['engelli', 'OLCULEMEZ']);

export function sha256Hex(metin) {
  return createHash('sha256').update(metin, 'utf8').digest('hex');
}

// Yol-çözüm-kontratı: ana-depo kökü `git rev-parse --git-common-dir` üzerinden bulunur
// (worktree'de bile ana-depoya işaret eder). Git yoksa null (tazelik-denetimi atlanır).
function anaDepoKoku(baslangicDizini) {
  try {
    const cikti = execFileSync('git', ['rev-parse', '--git-common-dir'], {
      cwd: baslangicDizini,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    const mutlak = resolve(baslangicDizini, cikti);
    return basename(mutlak) === '.git' ? dirname(mutlak) : mutlak;
  } catch {
    return null;
  }
}

// Etki-alanı glob'una dokunan son commit'in zamanı (ISO). Git yok / glob boş / commit yok -> null.
function sonCommitZamani(depoKoku, etkiAlani) {
  if (!depoKoku || !etkiAlani) return null;
  try {
    const cikti = execFileSync('git', ['log', '-1', '--format=%cI', '--', etkiAlani], {
      cwd: depoKoku,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    return cikti || null;
  } catch {
    return null;
  }
}

// Glob'u git-pathspec prefix'ine indirger (`panel/src/**` -> `panel/src`); git `**`'ı normal
// pathspec'te özel-saymaz, dizin-prefix'i tüm-alt-ağacı kapsar (muhafazakâr = daha-geniş tazelik).
function pathspec(etkiAlani) {
  return etkiAlani.replace(/\/\*+$/, '').replace(/\*+$/, '') || '.';
}

// §1.4 KANIT-İNVALİDASYONU (working-tree): etki-alanında HEAD'e göre commitlenmemiş değişiklik var VE
// o değişikliğin diskteki mtime'ı finished_at'ten YENİ ise -> kanıt bayat (kod kanıttan-sonra değişti).
// Committed-baseline sonCommitZamani ile ayrı kapatılır; bu, döngü-içi uncommitted-iterasyon false-green'i.
// Dönüş: {bayat: bool, dosya: string|null, mtime: string|null}. Git yok / değişiklik yok -> {bayat:false}.
function calismaAgaciBayat(depoKoku, etkiAlani, finishedAtIso) {
  if (!depoKoku || !etkiAlani || !finishedAtIso) return { bayat: false, dosya: null, mtime: null };
  const finishedMs = Date.parse(finishedAtIso);
  if (Number.isNaN(finishedMs)) return { bayat: false, dosya: null, mtime: null };
  let degisenler;
  try {
    degisenler = execFileSync('git', ['diff', 'HEAD', '--name-only', '--', pathspec(etkiAlani)], {
      cwd: depoKoku, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).split('\n').map((s) => s.trim()).filter(Boolean);
  } catch {
    return { bayat: false, dosya: null, mtime: null };
  }
  for (const gorece of degisenler) {
    const tam = resolve(depoKoku, gorece);
    try {
      const mt = statSync(tam).mtimeMs;
      if (mt > finishedMs) return { bayat: true, dosya: gorece, mtime: new Date(mt).toISOString() };
    } catch {
      // silinmiş dosya vb. — mtime okunamıyor; kanıtı bayatlatma (muhafazakâr)
    }
  }
  return { bayat: false, dosya: null, mtime: null };
}

// Hücre ayrımı: kaçırılmamış `|` üzerinden (hücre içinde ham `|` -> `\|` kaçışı, FORMAT §1).
function hucreAyir(satir) {
  return satir.split(/(?<!\\)\|/);
}

// doğrulama-komutu hücresinden komut-metnini çıkarır: ters-tırnak içi kanonik;
// tırnak yoksa `sha256:<hex>` bilgi-eki soyulmuş düz metin (geriye-uyum).
function komutuAyikla(hucre) {
  const tirnakli = hucre.match(/`([^`]+)`/);
  if (tirnakli) return tirnakli[1];
  return hucre.replace(/\bsha256:[0-9a-fA-F]+\b/g, '').trim() || null;
}

function etkiAlaniAyikla(hucre) {
  const temiz = hucre.trim().replace(/^`|`$/g, '').trim();
  return temiz && temiz !== '-' ? temiz : null;
}

// DÖRTLÜ-DENETİM (tek satır): dönüş {durum, denetim, neden, kanit}.
// (a) düşer -> bekliyor · (b) düşer -> bekliyor · (c) düşer -> fail · (d) düşer -> bekliyor.
function denetle({ mId, komut, etkiAlani, kanitDizini, depoKoku }) {
  const denetim = { json_gecerli: false, hash_uyum: null, rc_sifir: null, tazelik: null };
  const kanitYolu = join(kanitDizini, `${mId}.json`);

  if (komut === null) {
    return { durum: 'bekliyor', denetim, neden: 'doğrulama-komutu hücresi ayrıştırılamadı', kanit: null };
  }
  // (a) geçerli-JSON
  if (!existsSync(kanitYolu)) {
    return { durum: 'bekliyor', denetim, neden: `kanıt-JSON yok: ${kanitYolu}`, kanit: null };
  }
  let kanit;
  try {
    kanit = JSON.parse(readFileSync(kanitYolu, 'utf8'));
  } catch (hata) {
    return { durum: 'bekliyor', denetim, neden: `kanıt-JSON geçersiz: ${hata.message}`, kanit: null };
  }
  denetim.json_gecerli = true;
  // (b) komut-hash: satırdaki komut buradan hash'lenir, kanıttaki değerle karşılaştırılır
  const beklenenHash = sha256Hex(komut);
  denetim.hash_uyum = typeof kanit.komut_sha256 === 'string' && kanit.komut_sha256.toLowerCase() === beklenenHash;
  if (!denetim.hash_uyum) {
    return { durum: 'bekliyor', denetim, neden: "komut_sha256, satırdaki doğrulama-komutunun hash'i ile uyuşmuyor", kanit };
  }
  // (c) rc==0
  denetim.rc_sifir = kanit.rc === 0;
  if (!denetim.rc_sifir) {
    return { durum: 'fail', denetim, neden: `komut düştü: rc=${kanit.rc}`, kanit };
  }
  // (d) tazelik: finished_at > etki-alanının son-commit zamanı; git-yok/glob-boş -> denetim atlanır
  const commitZamani = sonCommitZamani(depoKoku, etkiAlani);
  if (commitZamani === null) {
    denetim.tazelik = 'atlandi';
  } else {
    const taze = typeof kanit.finished_at === 'string' && Date.parse(kanit.finished_at) > Date.parse(commitZamani);
    denetim.tazelik = taze ? 'gecti' : 'dustu';
    if (!taze) {
      return {
        durum: 'bekliyor',
        denetim,
        neden: `bayat kanıt: finished_at=${kanit.finished_at ?? 'yok'} <= son-commit=${commitZamani} (etki-alanı: ${etkiAlani})`,
        kanit,
      };
    }
  }
  // (d2) §1.4 working-tree invalidasyonu: commit-baseline taze OLSA bile, etki-alanında kanıttan-SONRA
  // yazılmış commitlenmemiş değişiklik varsa kanıt bayattır (uncommitted-iterasyon false-green'i).
  const wt = calismaAgaciBayat(depoKoku, etkiAlani, kanit.finished_at);
  if (wt.bayat) {
    denetim.calisma_agaci = 'bayat';
    return {
      durum: 'bekliyor',
      denetim,
      neden: `commitlenmemiş değişiklik kanıttan yeni: ${wt.dosya} mtime=${wt.mtime} > finished_at=${kanit.finished_at} (etki-alanı: ${etkiAlani})`,
      kanit,
    };
  }
  denetim.calisma_agaci = 'temiz';
  // (e) FAZ-1 KIRMIZI-KANIT-ŞARTI: kanitli için FAIL-edebilirlik kanıtı zorunlu.
  // kirmizi_kanit_ref -> var olan geçerli-JSON + rc != 0 (gerçekten-FAIL-etmiş koşum).
  // rc==0'lık "kırmızı" = sahte-kırmızı (hiç-FAIL-etmemiş) -> kanıt sayılmaz.
  const kirmiziRef = kanit.kirmizi_kanit_ref;
  if (typeof kirmiziRef !== 'string' || !kirmiziRef) {
    denetim.kirmizi_kanit = 'yok';
    return { durum: 'bekliyor', denetim, neden: 'kırmızı-kanıt yok (kirmizi_kanit_ref boş) — FAIL-edebilirlik kanıtlanmadı', kanit };
  }
  // Göreli-ref çözüm-sırası: (1) feature-kökü (kanit-dizininin ebeveyni — FORMAT-örneği
  // `kanit/M1-kirmizi.json` buna göredir), (2) ana-depo kökü. İlk-var-olan kazanır.
  const adaylar = [resolve(dirname(kanitDizini), kirmiziRef)];
  if (depoKoku) adaylar.push(resolve(depoKoku, kirmiziRef));
  const kirmiziYolu = adaylar.find((y) => existsSync(y));
  if (!kirmiziYolu) {
    denetim.kirmizi_kanit = 'dosya-yok';
    return { durum: 'bekliyor', denetim, neden: `kırmızı-kanıt dosyası yok (denenen: ${adaylar.join(' , ')})`, kanit };
  }
  let kirmizi;
  try {
    kirmizi = JSON.parse(readFileSync(kirmiziYolu, 'utf8'));
  } catch (hata) {
    denetim.kirmizi_kanit = 'gecersiz';
    return { durum: 'bekliyor', denetim, neden: `kırmızı-kanıt geçersiz-JSON: ${hata.message}`, kanit };
  }
  if (kirmizi.rc === 0) {
    denetim.kirmizi_kanit = 'sahte';
    return { durum: 'bekliyor', denetim, neden: 'sahte-kırmızı: kirmizi_kanit rc=0 (koşum hiç FAIL etmemiş) — kanıt sayılmaz', kanit };
  }
  // §1.2 KOMUT-KİLİDİ: kırmızı-kanıt AYNI komutun FAIL-edebildiğini kanıtlamalı. Farklı bir komutun
  // (alakasız build/başka-test) FAIL'i, BU satırın FAIL-edebilirliğini kanıtlamaz — sahte-kırmızı vektörü.
  if (kirmizi.komut_sha256 !== kanit.komut_sha256) {
    denetim.kirmizi_kanit = 'farkli-komut';
    return {
      durum: 'bekliyor',
      denetim,
      neden: `kırmızı-kanıt FARKLI komuttan (kirmizi.komut_sha256≠kanit.komut_sha256) — bu satırın FAIL-edebilirliği kanıtlanmadı`,
      kanit,
    };
  }
  denetim.kirmizi_kanit = 'gecti';
  return { durum: 'kanitli', denetim, neden: null, kanit };
}

// TSV-emit (FORMAT §5): kanit/ozet.tsv — TSV=ÖNBELLEK, kanonik=JSON. Her rejenerasyonda
// JSON'lardan yeniden üretilir; her satırda json_sha256 (kanıt-JSON dosya-İÇERİĞİNİN hash'i)
// mekanik-bağı. L0-lint sha256sum ile doğrular; elle-TSV bir sonraki rejenerasyonda ölür.
function tsvYaz(kanitDizini, raporSatirlari) {
  const satirlar = ['m_id\tdurum\trc\tjson_sha256'];
  for (const s of raporSatirlari) {
    const jsonYolu = join(kanitDizini, `${s.m_id}.json`);
    let rc = '-';
    let hash = '-';
    if (existsSync(jsonYolu)) {
      const ham = readFileSync(jsonYolu, 'utf8');
      hash = sha256Hex(ham);
      try { rc = String(JSON.parse(ham).rc); } catch { rc = '-'; }
    }
    satirlar.push(`${s.m_id}\t${s.yeni_durum}\t${rc}\t${hash}`);
  }
  writeFileSync(join(kanitDizini, 'ozet.tsv'), satirlar.join('\n') + '\n');
}

// Ana giriş: matrisi okur, her M-satırının durum'unu rejenere eder, dosyayı yeniden yazar
// (yalnız durum-hücresi değişir), rejenerasyon-raporu nesnesini döndürür.
export function rejenere({ matrisYolu, kanitDizini }) {
  const matrisMutlak = resolve(matrisYolu);
  const kanitMutlak = resolve(kanitDizini);
  const depoKoku = anaDepoKoku(dirname(matrisMutlak));

  const icerik = readFileSync(matrisMutlak, 'utf8');
  const satirlar = icerik.split('\n'); // '\n' üzerinden ayır/birleştir = kayıpsız
  const rapor = {
    skill_version: SKILL_VERSION, // yalnız kendi çıktı-raporuna damga (kanıt-JSON karşılaştırması FAZ-1)
    proje_koku: depoKoku,
    matris: matrisMutlak,
    kanit_dizini: kanitMutlak,
    satirlar: [],
    zayif_kanit: [],
    korunan: [],
    bozuk_satirlar: [],
    degisen_sayisi: 0,
  };

  for (let i = 0; i < satirlar.length; i++) {
    const parcalar = hucreAyir(satirlar[i]);
    // M-satırı: `| M<sayı> | ... |` -> 10 hücre (parcalar[0]='' önü, parcalar[11]='' sonu)
    if (parcalar.length < 11 || !/^\s*M\d+\s*$/.test(parcalar[1] ?? '')) continue;
    const mId = parcalar[1].trim();
    if (parcalar.length !== 12) {
      rapor.bozuk_satirlar.push({ m_id: mId, satir_no: i + 1, neden: `hücre sayısı 10 değil (${parcalar.length - 2})` });
      continue;
    }
    const eskiDurum = parcalar[9].trim();
    if (KORUNAN_DURUMLAR.has(eskiDurum)) {
      rapor.korunan.push(mId);
      rapor.satirlar.push({ m_id: mId, eski_durum: eskiDurum, yeni_durum: eskiDurum, denetim: null, neden: "iş-sahibi-gate'li durum — rejeneratör dokunmaz" });
      continue;
    }
    const komut = komutuAyikla(parcalar[6]);
    const etkiAlani = etkiAlaniAyikla(parcalar[7]);
    const sonuc = denetle({ mId, komut, etkiAlani, kanitDizini: kanitMutlak, depoKoku });
    if (sonuc.durum === 'kanitli' && sonuc.kanit && sonuc.kanit.counters === null) {
      rapor.zayif_kanit.push(mId); // ZAYIF-işaret: kanitli kalır ama raporda isimli
    }
    if (sonuc.durum !== eskiDurum) {
      parcalar[9] = ` ${sonuc.durum} `;
      satirlar[i] = parcalar.join('|');
      rapor.degisen_sayisi++;
    }
    rapor.satirlar.push({ m_id: mId, eski_durum: eskiDurum, yeni_durum: sonuc.durum, denetim: sonuc.denetim, neden: sonuc.neden });
  }

  writeFileSync(matrisMutlak, satirlar.join('\n'));
  tsvYaz(kanitMutlak, rapor.satirlar);
  return rapor;
}

function kullanim() {
  process.stderr.write('kullanım: node durum_uret.mjs --matris <yol> --kanit <dizin>\n');
  process.exit(2);
}

function main() {
  const argv = process.argv.slice(2);
  let matrisYolu = null;
  let kanitDizini = null;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--matris') matrisYolu = argv[++i];
    else if (argv[i] === '--kanit') kanitDizini = argv[++i];
    else kullanim();
  }
  if (!matrisYolu || !kanitDizini) kullanim();
  const rapor = rejenere({ matrisYolu, kanitDizini });
  for (const satir of rapor.satirlar) {
    if (satir.neden && satir.yeni_durum !== satir.eski_durum) {
      process.stderr.write(`${satir.m_id}: ${satir.yeni_durum} — ${satir.neden}\n`);
    } else if (satir.neden && satir.denetim === null) {
      process.stderr.write(`${satir.m_id}: korundu — ${satir.neden}\n`);
    }
  }
  process.stdout.write(JSON.stringify(rapor, null, 2) + '\n');
  // Not: rejeneratör gate DEĞİLDİR — çıkış-kodu her zaman 0; eşik-zorlama teslim-lint'in işi (FAZ-1).
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
