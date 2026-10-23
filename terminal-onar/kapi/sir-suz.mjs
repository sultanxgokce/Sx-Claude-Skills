// kapi/sir-suz.mjs — koltuk ekranından okunan metin kutudan çıkmadan ÖNCE sır desenlerini gizler (2.23.0 · K1 · SERDAR 23 Eki 14:42 şart 4).
// Ekran metni sır taşıyabilir: ajan bir komutun çıktısını, bir .env satırını ya da bir anahtarı sorunun içinde gösterebilir. Soru metni
// merkez paneline ve deftere gider; süzgeç kaynağında (kutuda) uygulanır, merkez ikinci kez uygular (savunma derinliği).
// Biçim tabanlıdır (içerik tahmini yok); desen tutarsa parça '••• gizlendi' olur, metnin geri kalanı aynen kalır.
// Akraba: sert-teslim/core/redaction.mjs (aynı fikir, ayrı beceri — terminal-onar kutulara AYRI kurulduğu için içe aktarılamaz).
export const GIZLI = '••• gizlendi';

// Sıra önemli: özgül desenler genel uzun-dizgi deseninden ÖNCE koşar.
export const SIR_DESENLERI = [
  { ad: 'pem', desen: /-----BEGIN [A-Z0-9 ]+-----[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)/g },
  { ad: 'url-kimlik', desen: /\b([a-z][a-z0-9+.-]*:\/\/)[^\s:/@]+:[^\s@]+@/gi, yerine: (_m, s) => s + GIZLI + '@' },
  { ad: 'bearer', desen: /\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi },
  { ad: 'anthropic-openai', desen: /\bsk-[A-Za-z0-9_-]{16,}/g },
  { ad: 'github', desen: /\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/g },
  { ad: 'slack', desen: /\bxox[abprs]-[A-Za-z0-9-]{10,}/g },
  { ad: 'aws', desen: /\bAKIA[0-9A-Z]{16}\b/g },
  { ad: 'jwt', desen: /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g },
  // anahtar=değer: ad kalır, değer gizlenir (Sultan neyin gizlendiğini anlasın: "token = ••• gizlendi")
  { ad: 'anahtar-deger', desen: /\b(api[_-]?key|access[_-]?key|secret|token|password|passwd|parola|şifre|sifre|jeton)(\s*[:=]\s*)(["']?)[^\s"']{6,}\3/gi, yerine: (_m, a, ayr) => a + ayr + GIZLI },
  // tek başına duran uzun dizgi (base64/hex/url-güvenli): 40+ karakter, çevresi boşluk ya da metin sınırı — gömülü parçaya dokunulmaz
  { ad: 'uzun-dizgi', desen: /(?<![^\s])[A-Za-z0-9+/_-]{40,}={0,2}(?![^\s])/g },
];

export function sirSuz(metin) {
  let s = String(metin == null ? '' : metin);
  for (const d of SIR_DESENLERI) s = s.replace(d.desen, d.yerine || GIZLI);
  return s;
}
