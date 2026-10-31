// kapi/koltuk-onbellek.mjs — /api/koltuklar için kısa süreli önbellek (ölçüldü 31 Eki: koltuk-bagla.sh --liste yük altında 1,4-3,1 sn; uç her istekte betiği koşuyordu).
// Bayat pencere 150 sn: merkezin soru bekçisi her kapıyı dakikada bir çağırır, önbellek canlıda sıcak kalır; Sultan'ın ilk açılışı da betiği beklemez. Soğuk kalan yalnız kapı yeniden açıldıktan sonraki ilk istektir.
// Üç kural: (1) taze penceresinde betik koşmaz · (2) bayat penceresinde son cevap hemen döner, arkada TEK yenileme koşar · (3) eşzamanlı istekler tek koşuya iner.
// Başarısız üretim saklanmaz: bayat sonuç hatayı gizlemez, pencere dolunca istek hatayı görür. Değişiklikten sonra dusur() eldekini atar; yoldaki koşunun sonucu da yazılmaz.
// Koltuk listesini değiştiren uçlar. Başarısız ya da ilgisiz istek önbelleği düşürmez; 504 açmada oturum arkada doğmuş olabilir, düşürür.
export const koltukDegistirir = (yol, kod) => /^\/api\/koltuk\/[^/]+\/ac$/.test(yol) || yol === '/api/kadro/hal' || yol === '/api/onar' ? kod < 300 || kod === 504 : false;
export function onbellekKur(uret, { taze = 4000, bayat = 150000, saat = Date.now } = {}) {
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
