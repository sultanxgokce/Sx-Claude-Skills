// durum_uret.test.mjs — durum-kolonu rejeneratörünün dörtlü-denetim + FAZ-1 kırmızı-kanıt-şartı
// sözleşmesi testleri. Her vaka mkdtemp ile izole fixture kurar: matris-md + kanit/-JSON (+ git).
// Kapsam: JSON-yok / hash-uyuşmaz / rc!=0 / bayat-tazelik / hepsi-geçer / counters-null(zayıf) /
// byte-korunum / engelli-koruması / kırmızı-yok / sahte-kırmızı / TSV-emit(önbellek-rejenerasyonu).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, utimesSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { rejenere, SKILL_VERSION } from '../durum_uret.mjs';

const sha256 = (s) => createHash('sha256').update(s, 'utf8').digest('hex');

const KOLON_BASLIK =
  '| M# | C-ID | kaynak-cümle-verbatim | yuzey | kanıt-türü | doğrulama-komutu(+hash) | etki-alanı | veri-rejimi | durum | kanıt-JSON-ref |';
const KOLON_AYRAC = '|---|---|---|---|---|---|---|---|---|---|';

function mSatiri(mId, komut, { etki = '-', durum = 'bekliyor' } = {}) {
  return `| ${mId} | C-deadbeef | Deneme gereklilik cümlesi. | arayuz-1 | komut | \`${komut}\` | ${etki} | sentetik | ${durum} | kanit/${mId}.json |`;
}

function fixtureKur(satirlar, { onsoz = '' } = {}) {
  const dizin = mkdtempSync(join(tmpdir(), 'durum-uret-'));
  const matrisYolu = join(dizin, 'MATRIS.md');
  const gevde = [onsoz, KOLON_BASLIK, KOLON_AYRAC, ...satirlar, ''].filter((s) => s !== null).join('\n');
  writeFileSync(matrisYolu, gevde);
  mkdirSync(join(dizin, 'kanit'), { recursive: true });
  return { dizin, matrisYolu, kanitDizini: join(dizin, 'kanit') };
}

// FAZ-1: kanitli için kırmızı-kanıt zorunlu -> fixture-default'u GEÇERLİ kırmızı içerir
// (kanit/<M#>-kirmizi.json, rc=1). Kırmızı-YOK vakası için ek.kirmizi_kanit_ref: null açıkça geçilir.
function kanitYaz(kanitDizini, mId, komut, ek = {}) {
  if (!('kirmizi_kanit_ref' in ek)) {
    writeFileSync(
      join(kanitDizini, `${mId}-kirmizi.json`),
      JSON.stringify({ m_id: mId, komut, komut_sha256: sha256(komut), rc: 1, runner: 'generic-rc' }, null, 2) + '\n',
    );
    ek = { ...ek, kirmizi_kanit_ref: `kanit/${mId}-kirmizi.json` };
  }
  const kanit = {
    m_id: mId,
    komut,
    komut_sha256: sha256(komut),
    rc: 0,
    counters: { collected: 1, passed: 1, failed: 0, skipped: 0 },
    started_at: '2026-01-01T00:00:00Z',
    finished_at: new Date(Date.now() + 3600 * 1000).toISOString(),
    runner: 'generic-rc',
    skill_version: '0.2.0-faz1',
    proje_koku: null,
    config_yolu: null,
    ...ek,
  };
  writeFileSync(join(kanitDizini, `${mId}.json`), JSON.stringify(kanit, null, 2) + '\n');
  return kanit;
}

function gitDeposuKur(dizin) {
  const git = (args) =>
    execFileSync('git', ['-c', 'user.email=deneme@yerel', '-c', 'user.name=deneme', ...args], {
      cwd: dizin,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  git(['init', '-q']);
  mkdirSync(join(dizin, 'src'), { recursive: true });
  writeFileSync(join(dizin, 'src', 'a.txt'), 'icerik\n');
  git(['add', 'src/a.txt']);
  git(['commit', '-q', '-m', 'ilk']);
}

function temizle(dizin) {
  rmSync(dizin, { recursive: true, force: true });
}

test('denetim-a: kanıt-JSON yok -> durum bekliyor (elle yazılmış kanitli EZİLİR)', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok', { durum: 'kanitli' })]);
  try {
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.json_gecerli, false);
    assert.ok(readFileSync(matrisYolu, 'utf8').includes('| bekliyor |'));
  } finally {
    temizle(dizin);
  }
});

test('denetim-a2: bozuk-JSON -> durum bekliyor + neden dolu', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    writeFileSync(join(kanitDizini, 'M1.json'), '{bozuk json');
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.ok(rapor.satirlar[0].neden.length > 0);
  } finally {
    temizle(dizin);
  }
});

test('denetim-b: komut-hash uyuşmaz -> durum bekliyor', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok', { komut_sha256: 'deadbeef'.repeat(8) });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.hash_uyum, false);
  } finally {
    temizle(dizin);
  }
});

test('denetim-c: rc!=0 -> durum fail (bekliyor DEĞİL)', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok', { rc: 3 });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'fail');
    assert.equal(rapor.satirlar[0].denetim.rc_sifir, false);
  } finally {
    temizle(dizin);
  }
});

test('denetim-d: bayat kanıt (finished_at <= etki-alanının son-commit zamanı) -> bekliyor + neden', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok', { etki: 'src/**' })]);
  try {
    gitDeposuKur(dizin);
    kanitYaz(kanitDizini, 'M1', 'printf ok', { finished_at: '2000-01-01T00:00:00Z' });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.tazelik, 'dustu');
    assert.ok(rapor.satirlar[0].neden.includes('bayat'));
  } finally {
    temizle(dizin);
  }
});

test('denetim-d2: taze kanıt git-deposunda tazelik-denetimini GEÇER -> kanitli', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok', { etki: 'src/**' })]);
  try {
    gitDeposuKur(dizin);
    kanitYaz(kanitDizini, 'M1', 'printf ok'); // finished_at gelecekte -> commit'ten yeni
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'kanitli');
    assert.equal(rapor.satirlar[0].denetim.tazelik, 'gecti');
    assert.ok(rapor.proje_koku && rapor.proje_koku.length > 0); // yol-çözüm damgası
  } finally {
    temizle(dizin);
  }
});

test('hepsi-geçer (git-siz: tazelik atlanır) -> kanitli, matris dosyasına yazılır', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok');
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'kanitli');
    assert.ok(readFileSync(matrisYolu, 'utf8').includes('| kanitli |'));
    assert.equal(rapor.skill_version, SKILL_VERSION);
  } finally {
    temizle(dizin);
  }
});

test('counters=null: durum kanitli KALIR ama zayif_kanit listesine girer', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok', { counters: null });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'kanitli');
    assert.deepEqual(rapor.zayif_kanit, ['M1']);
  } finally {
    temizle(dizin);
  }
});

test('byte-korunum: yalnız durum-hücresi değişir, diğer hücreler ve matris-dışı satırlar aynen kalır', () => {
  const onsoz = '# Deneme matrisi\n\nSerbest açıklama satırı burada durur.\n';
  const { dizin, matrisYolu, kanitDizini } = fixtureKur(
    [mSatiri('M1', 'printf ok'), mSatiri('M2', 'printf iki', { etki: 'src/**' })],
    { onsoz },
  );
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok'); // M1 -> kanitli, M2 -> bekliyor (JSON yok)
    const eski = readFileSync(matrisYolu, 'utf8');
    rejenere({ matrisYolu, kanitDizini });
    const yeni = readFileSync(matrisYolu, 'utf8');
    const eskiSatirlar = eski.split('\n');
    const yeniSatirlar = yeni.split('\n');
    assert.equal(eskiSatirlar.length, yeniSatirlar.length);
    for (let i = 0; i < eskiSatirlar.length; i++) {
      const eskiHucreler = eskiSatirlar[i].split('|');
      if (!/^\s*M\d+\s*$/.test(eskiHucreler[1] ?? '')) {
        // M-satırı değil -> byte-korunur
        assert.equal(yeniSatirlar[i], eskiSatirlar[i]);
        continue;
      }
      const yeniHucreler = yeniSatirlar[i].split('|');
      assert.equal(eskiHucreler.length, yeniHucreler.length);
      for (let h = 0; h < eskiHucreler.length; h++) {
        if (h === 9) continue; // durum-hücresi — değişebilir
        assert.equal(yeniHucreler[h], eskiHucreler[h]);
      }
    }
    assert.ok(yeniSatirlar.find((s) => s.includes('| M1 |')).includes('| kanitli |'));
    assert.ok(yeniSatirlar.find((s) => s.includes('| M2 |')).includes('| bekliyor |'));
  } finally {
    temizle(dizin);
  }
});

test('FAZ-1 kırmızı-yok: kirmizi_kanit_ref=null -> kanitli OLAMAZ (bekliyor + neden)', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok', { kirmizi_kanit_ref: null });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.kirmizi_kanit, 'yok');
    assert.ok(rapor.satirlar[0].neden.includes('kırmızı-kanıt yok'));
  } finally {
    temizle(dizin);
  }
});

test('FAZ-1 sahte-kırmızı: kirmizi-JSON rc=0 -> kanitli OLAMAZ (hiç-FAIL-etmemiş koşum kanıt değil)', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    writeFileSync(
      join(kanitDizini, 'M1-kirmizi.json'),
      JSON.stringify({ m_id: 'M1', rc: 0, runner: 'generic-rc' }) + '\n',
    );
    kanitYaz(kanitDizini, 'M1', 'printf ok', { kirmizi_kanit_ref: 'kanit/M1-kirmizi.json' });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.kirmizi_kanit, 'sahte');
  } finally {
    temizle(dizin);
  }
});

test('FAZ-1 kırmızı-dosya-yok: ref var ama dosya yok -> bekliyor', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok', { kirmizi_kanit_ref: 'kanit/olmayan-kirmizi.json' });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.kirmizi_kanit, 'dosya-yok');
  } finally {
    temizle(dizin);
  }
});

test('§1.2 komut-kilidi: kırmızı-kanıt FARKLI komuttan (komut_sha256≠) -> kanitli OLAMAZ', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok')]);
  try {
    // kırmızı-JSON rc=1 AMA başka-komutun hash'iyle (alakasız-FAIL sahte-kırmızı vektörü)
    writeFileSync(
      join(kanitDizini, 'M1-kirmizi.json'),
      JSON.stringify({ m_id: 'M1', komut: 'BASKA komut', komut_sha256: sha256('BASKA komut'), rc: 1, runner: 'generic-rc' }) + '\n',
    );
    kanitYaz(kanitDizini, 'M1', 'printf ok', { kirmizi_kanit_ref: 'kanit/M1-kirmizi.json' });
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.kirmizi_kanit, 'farkli-komut');
    assert.ok(rapor.satirlar[0].neden.includes('FARKLI komut'));
  } finally {
    temizle(dizin);
  }
});

test('§1.4 working-tree: commit-taze AMA etki-alanında commitlenmemiş-değişiklik kanıttan-yeni -> bekliyor', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok', { etki: 'src/**' })]);
  try {
    gitDeposuKur(dizin); // src/a.txt commit'li (commit-zamanı ~now)
    // finished_at commit'ten SONRA (so (d) commit-tazelik GEÇER) ama working-tree dosya daha da YENİ
    const finished = new Date(Date.now() + 60 * 1000).toISOString();
    kanitYaz(kanitDizini, 'M1', 'printf ok', { finished_at: finished });
    // src/a.txt'i DEĞİŞTİR (commitleme) + mtime'ı finished_at'ten sonraya al
    const dosya = join(dizin, 'src', 'a.txt');
    writeFileSync(dosya, 'kanittan-SONRA yazıldı\n');
    const sonra = new Date(Date.now() + 3600 * 1000);
    utimesSync(dosya, sonra, sonra);
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'bekliyor');
    assert.equal(rapor.satirlar[0].denetim.calisma_agaci, 'bayat');
    assert.ok(rapor.satirlar[0].neden.includes('commitlenmemiş'));
  } finally {
    temizle(dizin);
  }
});

test('§1.4 working-tree temiz: değişiklik-yok -> tazelik GEÇER (false-red yok)', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok', { etki: 'src/**' })]);
  try {
    gitDeposuKur(dizin);
    kanitYaz(kanitDizini, 'M1', 'printf ok'); // finished_at gelecekte; working-tree temiz
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.equal(rapor.satirlar[0].yeni_durum, 'kanitli');
    assert.equal(rapor.satirlar[0].denetim.calisma_agaci, 'temiz');
  } finally {
    temizle(dizin);
  }
});

test('FAZ-1 TSV-emit: ozet.tsv JSON-lardan rejenere edilir + json_sha256 doğru + elle-TSV ölür', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([mSatiri('M1', 'printf ok'), mSatiri('M2', 'printf iki')]);
  try {
    kanitYaz(kanitDizini, 'M1', 'printf ok'); // M1 kanitli-aday; M2 JSON-suz -> bekliyor
    writeFileSync(join(kanitDizini, 'ozet.tsv'), 'm_id\tdurum\trc\tjson_sha256\nM2\tkanitli\t0\tsahte-hash\n'); // elle-TSV (oynama-girişimi)
    rejenere({ matrisYolu, kanitDizini });
    const tsv = readFileSync(join(kanitDizini, 'ozet.tsv'), 'utf8').trim().split('\n');
    assert.equal(tsv[0], 'm_id\tdurum\trc\tjson_sha256');
    const m1 = tsv.find((s) => s.startsWith('M1\t')).split('\t');
    assert.equal(m1[1], 'kanitli');
    assert.equal(m1[3], sha256(readFileSync(join(kanitDizini, 'M1.json'), 'utf8'))); // mekanik-bağ
    const m2 = tsv.find((s) => s.startsWith('M2\t')).split('\t');
    assert.equal(m2[1], 'bekliyor'); // elle-'kanitli' TSV'si EZİLDİ
    assert.equal(m2[3], '-');
  } finally {
    temizle(dizin);
  }
});

test('engelli/OLCULEMEZ iş-sahibi-gate durumları KORUNUR (rejeneratör ezmez, raporda isimli)', () => {
  const { dizin, matrisYolu, kanitDizini } = fixtureKur([
    mSatiri('M1', 'printf ok', { durum: 'engelli' }),
    mSatiri('M2', 'printf iki', { durum: 'OLCULEMEZ' }),
  ]);
  try {
    const rapor = rejenere({ matrisYolu, kanitDizini });
    assert.deepEqual(rapor.korunan, ['M1', 'M2']);
    const yeni = readFileSync(matrisYolu, 'utf8');
    assert.ok(yeni.includes('| engelli |'));
    assert.ok(yeni.includes('| OLCULEMEZ |'));
  } finally {
    temizle(dizin);
  }
});
