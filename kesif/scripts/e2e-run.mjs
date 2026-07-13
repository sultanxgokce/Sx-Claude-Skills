// e2e-run.mjs — kesif E2E-runner (generic, proje-bilmez). Canlı-panele allowlist-guard'lı goto,
// senaryoları koşar (DOM↔API çapraz-kanıt), kanıt-JSON + trace (lokal) emit eder. Karar saf-kod.
// Kullanım: node e2e-run.mjs --panel-url <url> --allowlist <csv> --senaryolar <path> --kanit <dir> [--api-base <url>]
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import process from 'node:process';
import { acStandart } from './kesif_lib.mjs';

export const SKILL_VERSION = '0.1.0-faz0';

// Panelin tükettiği API-uçlarını BAĞIMSIZ çeker (ground-truth çapraz-kanıt). Uçlar PROJE-config'ten
// (senaryo-modülünün apiEndpoints export'u) — generic-runner endpoint-BİLMEZ (hardcode YOK).
export async function apiCek(apiBase, endpoints) {
  const g = async (yol) => {
    const r = await fetch(apiBase + yol);
    if (!r.ok) throw new Error(`${yol} → HTTP ${r.status}`);
    return r.json();
  };
  const out = {};
  await Promise.all(Object.entries(endpoints ?? {}).map(async ([key, yol]) => { out[key] = await g(yol); }));
  return out;
}

export async function kosSenaryolar({ panelUrl, allowlist, senaryolarYolu, kanitDizini, apiBase }) {
  mkdirSync(kanitDizini, { recursive: true });
  const mod = await import(pathToFileURL(resolve(senaryolarYolu)).href);
  const { senaryolar, apiEndpoints, readySelector } = mod;
  const api = await apiCek(apiBase ?? panelUrl.replace(/\/$/, ''), apiEndpoints);

  const tracePath = join(kanitDizini, 'e2e-trace.zip');
  const { page, blocked, kapat } = await acStandart({ allowlist, tracePath });
  const sonuclar = [];
  try {
    await page.goto(panelUrl, { waitUntil: 'networkidle', timeout: 20000 });
    if (readySelector) await page.waitForSelector(readySelector, { timeout: 10000 }).catch(() => {});
    for (const s of senaryolar) {
      let r;
      try {
        r = await s.calistir(page, api);
      } catch (e) {
        r = { gecti: false, detay: `istisna: ${e.message}` };
      }
      sonuclar.push({ ad: s.ad, aciklama: s.aciklama, gecti: r.gecti, detay: r.detay });
    }
  } finally {
    await kapat();
  }

  const gecen = sonuclar.filter((s) => s.gecti).length;
  const rapor = {
    skill_version: SKILL_VERSION,
    panel_url: panelUrl,
    allowlist,
    toplam: sonuclar.length,
    gecen,
    kalan: sonuclar.length - gecen,
    allowlist_ihlali: blocked, // allowlist-dışı istek olduysa burada görünür (olmamalı)
    senaryolar: sonuclar,
    trace: tracePath,
  };
  writeFileSync(join(kanitDizini, 'e2e-senaryolar.json'), JSON.stringify(rapor, null, 2) + '\n');
  return rapor;
}

function kullanim() {
  process.stderr.write('kullanım: node e2e-run.mjs --panel-url <url> --allowlist <csv> --senaryolar <path> --kanit <dir> [--api-base <url>]\n');
  process.exit(2);
}

async function main() {
  const argv = process.argv.slice(2);
  const arg = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--panel-url') arg.panelUrl = argv[++i];
    else if (argv[i] === '--allowlist') arg.allowlist = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (argv[i] === '--senaryolar') arg.senaryolarYolu = argv[++i];
    else if (argv[i] === '--kanit') arg.kanitDizini = argv[++i];
    else if (argv[i] === '--api-base') arg.apiBase = argv[++i];
    else kullanim();
  }
  if (!arg.panelUrl || !arg.allowlist || !arg.senaryolarYolu || !arg.kanitDizini) kullanim();
  const rapor = await kosSenaryolar(arg);
  for (const s of rapor.senaryolar) {
    process.stderr.write(`${s.gecti ? 'PASS' : 'FAIL'} · ${s.ad} — ${s.detay}\n`);
  }
  process.stderr.write(`E2E: ${rapor.gecen}/${rapor.toplam} PASS · allowlist-ihlali=${rapor.allowlist_ihlali.length}\n`);
  process.stdout.write(JSON.stringify({ gecen: rapor.gecen, toplam: rapor.toplam, kalan: rapor.kalan }) + '\n');
  process.exit(rapor.kalan === 0 && rapor.allowlist_ihlali.length === 0 ? 0 : 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
