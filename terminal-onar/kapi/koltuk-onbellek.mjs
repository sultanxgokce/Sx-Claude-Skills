// kapi/koltuk-onbellek.mjs — /api/koltuklar için kısa süreli önbellek (ölçüldü 31 Eki: koltuk-bagla.sh --liste yük altında 1,4-3,1 sn; uç her istekte betiği koşuyordu).
// Üç kural: (1) taze penceresinde betik koşmaz · (2) bayat penceresinde son cevap hemen döner, arkada TEK yenileme koşar · (3) eşzamanlı istekler tek koşuya iner.
// Başarısız üretim saklanmaz: bayat sonuç hatayı gizlemez, pencere dolunca istek hatayı görür. Değişiklikten sonra dusur() eldekini atar; yoldaki koşunun sonucu da yazılmaz.
export function onbellekKur(uret, { taze = 4000, bayat = 60000, saat = Date.now } = {}) {
  let son = null, ts = 0, ucak = null, kusak = 0;
  const yenile = () => {
    if (ucak) return ucak;
    const k = kusak;
    const p = Promise.resolve().then(uret).then((v) => { if (v?.ok && k === kusak) { son = v; ts = saat(); } return v; })
      .finally(() => { if (ucak === p) ucak = null; });
    ucak = p; return p;
  };
  return {
    async al() {
      const yas = saat() - ts;
      if (son && yas < taze) return { deger: son, yas };
      if (son && yas < bayat) { yenile().catch(() => {}); return { deger: son, yas }; }
      return { deger: await yenile(), yas: 0 };
    },
    dusur() { son = null; ts = 0; ucak = null; kusak++; },
  };
}
