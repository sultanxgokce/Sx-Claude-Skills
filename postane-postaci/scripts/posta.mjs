#!/usr/bin/env node
/**
 * posta — ajanın posta komutu (POSTANE F1). Bağımlılık yok: node stdlib.
 *
 *   posta gonder <kime> "<metin>" --kimden AD [--aciliyet jet|hizli|orta|genis] [--konu "…"] [--tekrar ANAHTAR]
 *   posta olu-kapat <id> --neden "…"                  (merkez jetonu: ölü mektubu gerekçeyle arşive kapatır; kapatan = jetonun kutusu, ad verilmez)
 *   posta al      --kim AD [--limit N]          gelen kutudan çeker (teslim edildi); metinleri basar
 *   posta gordum  <id> --kim AD                  okudum (kira uzar)
 *   posta isle    <id> --kim AD [--reddet "gerekçe"]   işledim, ya da gerekçeyle reddettim
 *   posta liste   --kim AD                       açık kutu (durum değiştirmez)
 *   posta bak     <id>                           mesajın tüm izi
 *   posta geciken | olu | say                    merkez (kısıtsız jeton) görünümü
 *   posta kanca   --kim AD                       tur-sonu kancası: vadesi gelen mesaj varsa basar ve 2 ile çıkar (uyandır),
 *                                                yoksa "N mesaj var, en yakını X dk" tek satır, çıkış 0. KAYIT ETMEZ: kanca bağlama ayrı karar.
 *
 * Ortam: POSTANE_URL (varsayılan http://cloudtop-postane:8797) · jeton /config/defter-jeton ya da POSTANE_JETON.
 */
import { readFileSync } from 'node:fs';

const URL_ = (process.env.POSTANE_URL || 'http://cloudtop-postane:8797').replace(/\/+$/, '');
const jeton = () => {
  if (process.env.POSTANE_JETON) return process.env.POSTANE_JETON.trim();
  try { return readFileSync(process.env.POSTANE_JETON_DOSYA || '/config/defter-jeton', 'utf8').trim(); } catch { return ''; }
};

function bayrak(argv) {
  const poz = []; const b = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) { const ad = a.slice(2); const sonraki = argv[i + 1]; if (sonraki === undefined || sonraki.startsWith('--')) b[ad] = true; else { b[ad] = sonraki; i++; } }
    else poz.push(a);
  }
  return { poz, b };
}

async function cagri(yontem, yol, govde) {
  let r;
  try {
    r = await fetch(URL_ + yol, { method: yontem, headers: { 'x-defter-jeton': jeton(), 'content-type': 'application/json' }, body: govde ? JSON.stringify(govde) : undefined, signal: AbortSignal.timeout(10_000) });
  } catch (e) { return { ok: false, hata: 'ulasilamadi', neden: `${URL_} cevap vermedi (${e.cause?.code ?? e.name})` }; }
  try { return await r.json(); } catch { return { ok: false, hata: 'cevap_bozuk', neden: `HTTP ${r.status}` }; }
}

const dk = (ms) => (ms === null || ms === undefined ? '—' : ms < 0 ? `${Math.ceil(-ms / 60000)} dk GEÇTİ` : ms < 60000 ? `${Math.ceil(ms / 1000)} sn` : `${Math.ceil(ms / 60000)} dk`);
const satir = (m) => `${m.id} · ${m.kimden} → ${m.kime} · ${m.aciliyet.toUpperCase()} · ${m.durum} · son tarih ${dk(m.kalan_ms)}${m.konu ? ` · ${m.konu}` : ''}`;
const hataBas = (r) => { console.error(`✗ ${r.hata}${r.neden ? ` — ${r.neden}` : ''}`); return 1; };

async function main() {
  const [komut, ...rest] = process.argv.slice(2);
  const { poz, b } = bayrak(rest);
  const kim = b.kim || b.kimden;
  switch (komut) {
    case 'gonder': {
      const [kime, ...metin] = poz;
      if (!kime || !metin.length || !b.kimden) { console.error('kullanım: posta gonder <kime> "<metin>" --kimden AD [--aciliyet jet|hizli|orta|genis] [--konu …] [--tekrar …]'); return 2; }
      const r = await cagri('POST', '/gonder', { kimden: b.kimden, kime, aciliyet: b.aciliyet || 'orta', icerik: metin.join(' '), konu: b.konu || '', tekrar: b.tekrar || null });
      if (!r.ok) return hataBas(r);
      console.log(`${r.tekrar ? '= aynı mesaj zaten vardı' : '✓ gönderildi'}: ${satir(r.mesaj)}`); return 0;
    }
    case 'al': {
      if (!kim) { console.error('kullanım: posta al --kim AD [--limit N]'); return 2; }
      const r = await cagri('POST', '/al', { kime: kim, limit: b.limit ? Number(b.limit) : undefined });
      if (!r.ok) return hataBas(r);
      if (!r.mesajlar.length) { console.log('posta kutusu boş'); return 0; }
      for (const m of r.mesajlar) console.log(`${satir(m)}\n${m.icerik}\n`);
      console.log(`→ okuyunca: posta gordum <id> --kim ${kim} · bitirince: posta isle <id> --kim ${kim} [--reddet "gerekçe"]`); return 0;
    }
    case 'gordum': case 'isle': {
      const id = poz[0];
      if (!id || !kim) { console.error(`kullanım: posta ${komut} <id> --kim AD${komut === 'isle' ? ' [--reddet "gerekçe"]' : ''}`); return 2; }
      const r = await cagri('POST', `/${komut}`, { id, kim, ...(komut === 'isle' && b.reddet ? { reddet: b.reddet === true ? '' : b.reddet } : {}) });
      if (!r.ok) return hataBas(r);
      console.log(`${r.tekrar ? '= zaten' : '✓'} ${r.mesaj.durum}: ${satir(r.mesaj)}`); return 0;
    }
    case 'liste': {
      if (!kim) { console.error('kullanım: posta liste --kim AD'); return 2; }
      const r = await cagri('GET', `/kutu/${encodeURIComponent(kim)}`);
      if (!r.ok) return hataBas(r);
      if (!r.mesajlar.length) console.log('açık mesaj yok'); for (const m of r.mesajlar) console.log(satir(m)); return 0;
    }
    case 'bak': {
      if (!poz[0]) { console.error('kullanım: posta bak <id>'); return 2; }
      const r = await cagri('GET', `/mesaj/${encodeURIComponent(poz[0])}`);
      if (!r.ok) return hataBas(r);
      console.log(satir(r.mesaj)); for (const o of r.olaylar) console.log(`  ${new Date(o.ts).toISOString()} ${o.tur}${o.kim ? ` · ${o.kim}` : ''}${o.ayrinti ? ` · ${o.ayrinti}` : ''}`); return 0;
    }
    case 'olu-kapat': {
      const id = poz[0];
      if (!id || !b.neden || b.neden === true) { console.error('kullanım: posta olu-kapat <id> --neden "…"  (yalnız merkez jetonu; kapatan adı sunucuda jetondan türer; ölü mektup arşive düşer)'); return 2; }
      const r = await cagri('POST', '/olu-kapat', { id, neden: b.neden });
      if (!r.ok) return hataBas(r);
      console.log(`✓ ${r.mesaj.durum}: ${satir(r.mesaj)}`); return 0;
    }
    case 'geciken': case 'olu': {
      const r = await cagri('GET', `/${komut}`);
      if (!r.ok) return hataBas(r);
      if (!r.mesajlar.length) console.log(komut === 'olu' ? 'ölü mektup yok' : 'geciken mesaj yok'); for (const m of r.mesajlar) console.log(satir(m)); return 0;
    }
    case 'say': {
      const r = await cagri('GET', '/say');
      if (!r.ok) return hataBas(r);
      console.log(`toplam ${r.toplam}`); for (const g of r.gruplar) console.log(`  ${g.durum} · ${g.aciliyet}: ${g.n}`); return 0;
    }
    case 'kanca': {
      if (!kim) { console.error('kullanım: posta kanca --kim AD'); return 2; }
      const r = await cagri('POST', '/al', { kime: kim, vadeli: true });
      if (!r.ok) { console.error(`posta kancası: ${r.hata}${r.neden ? ` — ${r.neden}` : ''}`); return 0; }   // postane kapalıyken ajanı uyandırma: sessiz geç, hata stderr'de
      if (r.mesajlar.length) {
        console.log(`📨 POSTA · ${r.mesajlar.length} mesajın vadesi geldi — önce bunlara bak:`);
        for (const m of r.mesajlar) console.log(`${satir(m)}\n${m.icerik}\n`);
        console.log(`→ okuyunca: posta gordum <id> --kim ${kim} · bitirince: posta isle <id> --kim ${kim}`);
        return 2;
      }
      const o = await cagri('GET', `/ozet/${encodeURIComponent(kim)}`);
      if (o.ok && o.acik > 0) console.log(`📬 ${o.acik} mesaj var, en yakınının son tarihi ${dk(o.en_yakin_ms)} sonra — uygun anında: posta al --kim ${kim}`);
      return 0;
    }
    default:
      console.error('kullanım: posta gonder|al|gordum|isle|liste|bak|geciken|olu|say|kanca  (ayrıntı: dosya başı)'); return 2;
  }
}
main().then((c) => process.exit(c), (e) => { console.error(`posta: ${e.message}`); process.exit(1); });
