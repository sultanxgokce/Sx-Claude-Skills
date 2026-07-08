// allowlist.test.mjs — kesif güvenlik-omurgası: origin-EXACT allowlist denetimi (bypass-kilit).
// prefix-match'in açtığı userinfo-hilesi (8000@evil.com) + subdomain-hilesi (8000.evil.com) KAPALI mı?
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { izinliUrl } from '../scripts/kesif_lib.mjs';

const ALLOW = ['http://127.0.0.1:8000'];

test('izinli: allowlist-origin altındaki yollar SERBEST', () => {
  assert.equal(izinliUrl('http://127.0.0.1:8000/', ALLOW), true);
  assert.equal(izinliUrl('http://127.0.0.1:8000/api/sources/health', ALLOW), true);
  assert.equal(izinliUrl('http://127.0.0.1:8000/assets/index-abc.js', ALLOW), true);
});

test('iç-şemalar (data:/about:/blob:) SERBEST', () => {
  assert.equal(izinliUrl('data:text/html,<h1>x</h1>', ALLOW), true);
  assert.equal(izinliUrl('about:blank', ALLOW), true);
});

test('BYPASS-KİLİT: userinfo-hilesi 8000@evil.com → BLOK (origin=http://evil.com)', () => {
  assert.equal(izinliUrl('http://127.0.0.1:8000@evil.com/', ALLOW), false);
});

test('BYPASS-KİLİT: subdomain-hilesi 8000.evil.com → BLOK (origin farklı)', () => {
  assert.equal(izinliUrl('http://127.0.0.1:8000.evil.com/steal', ALLOW), false);
});

test('BYPASS-KİLİT: farklı-port BLOK (8001 allowlist-dışı)', () => {
  assert.equal(izinliUrl('http://127.0.0.1:8001/', ALLOW), false);
});

test('BYPASS-KİLİT: https-şema-yükseltme hilesi (farklı-origin) BLOK', () => {
  assert.equal(izinliUrl('https://127.0.0.1:8000/', ALLOW), false); // https≠http origin
});

test('BYPASS-KİLİT: prefix-eşleşen-ama-origin-farklı BLOK (127.0.0.1:80000)', () => {
  assert.equal(izinliUrl('http://127.0.0.1:80000/', ALLOW), false);
});

test('geçersiz-URL → BLOK (sessiz-serbest yok)', () => {
  assert.equal(izinliUrl('düz-metin-değil-url', ALLOW), false);
});
