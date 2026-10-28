// dumen-bekle.mjs — Dümen Sultan'dayken ajanın BEKLEME yolu: merkez modu 'ajan' olunca biter; arka plan bitişi ajanı uyandırır.
// Görev …9JMK89 (yarı 2): merkez ajana tmux ile ulaşamaz; ajanın kendi uyanma yolu arka plan komutunun bitişidir.
//   Kullanım (Bash run_in_background:true):  node dumen-bekle.mjs [--merkez <url>] [--azami-dk 120] [--aralik-sn 10]
//   Çıkış: 0 = Dümen ajanda (zaten ya da geri verildi) · 3 = süre doldu, Dümen hâlâ Sultan'da · 4 = merkez art arda cevap vermedi (ÖLÇÜLEMEDİ).
//   Yalnız GET <merkez>/dumen/mod okur (oturumsuz, yalnız mod); hiçbir şey yazmaz, jeton kullanmaz.
import { resolve } from 'path';
import { pathToFileURL } from 'url';
const CEVAPSIZ_TAVAN = 6;   // art arda bu kadar cevapsız okuma → rc 4 (sessizce sonsuza beklemez, 'ajan' da varsaymaz)

export async function bekle({ merkez, azamiMs = 120 * 60000, aralikMs = 10000, yaz = (s) => console.log(s), okuyucu = fetch, simdi = () => Date.now(), uyu = (ms) => new Promise((r) => setTimeout(r, ms)) }) {
  const uc = String(merkez || '').replace(/\/$/, '');
  if (!uc) { yaz('✗ merkez adresi yok (--merkez ya da DUMEN_MERKEZ)'); return 2; }
  const bas = simdi(); let cevapsiz = 0; let ilk = true;
  for (;;) {
    let mod = null;
    try { const r = await okuyucu(`${uc}/dumen/mod`, { signal: AbortSignal.timeout(8000) }); if (r.ok) mod = (await r.json()).mod; } catch { /* aşağıda sayılır */ }
    if (mod === 'ajan' || mod === 'sultan') {
      cevapsiz = 0;
      if (mod === 'ajan') { yaz(ilk ? '▶ Dümen zaten ajanda — devam edebilirsin' : `▶ Dümen geri verildi (${Math.round((simdi() - bas) / 60000)} dk sonra) — devam edebilirsin`); return 0; }
      if (ilk) yaz("⏸ Dümen Sultan'da · geri verilince haber vereceğim");
    } else {
      cevapsiz++;
      if (cevapsiz >= CEVAPSIZ_TAVAN) { yaz(`✗ merkez ${CEVAPSIZ_TAVAN} okumadır cevap vermiyor — Dümen kimde bilinmiyor (ÖLÇÜLEMEDİ, devam sayılmaz)`); return 4; }
    }
    ilk = false;
    if (simdi() - bas >= azamiMs) { yaz(`⏳ ${Math.round(azamiMs / 60000)} dk doldu, Dümen hâlâ Sultan'da — SERDAR'a haber ver ya da yeniden bekle`); return 3; }
    await uyu(aralikMs);
  }
}

const arg = (a, v) => { const i = process.argv.indexOf(a); return i > 0 ? process.argv[i + 1] : v; };
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const rc = await bekle({ merkez: arg('--merkez', process.env.DUMEN_MERKEZ), azamiMs: Number(arg('--azami-dk', 120)) * 60000, aralikMs: Number(arg('--aralik-sn', 10)) * 1000 });
  process.exit(rc);
}
