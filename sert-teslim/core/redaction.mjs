// redaction.mjs — format-tabanlı sır-redaksiyonu + instruction-desen karantina-dedektörü
// (FAZ-0 STUB ama gerçek-çekirdekli, MOTOR-sınıfı: proje-bilmez). Bilinen sır-biçimlerini
// placeholder'a çevirir (pg-dsn / bearer / fernet / aws-key / yalnız-tek-token uzun-b64);
// instruction-desenli satırları DEĞİŞTİRMEDEN işaretler (karantina-raporu).
// TODO(FAZ-1): config'ten ek-desen okuma (proje-özel desenler CONFIG-sınıfıdır).
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const SKILL_VERSION = '0.1.0-faz0';

// MOTOR-desenleri (sıra önemli: özgül desenler genel b64'ten ÖNCE koşar).
const DESENLER = [
  { ad: 'pg-dsn', desen: /postgres:\/\/[^\s]+/g },
  { ad: 'bearer', desen: /Bearer [A-Za-z0-9._-]+/g },
  { ad: 'fernet', desen: /gAAAAA[A-Za-z0-9_-]{20,}/g },
  { ad: 'aws-key', desen: /AKIA[A-Z0-9]{16}/g },
  // uzun-b64: YALNIZ tek-token'sa (öncesi/sonrası boşluk ya da metin-sınırı) — gömülü parçalara dokunulmaz
  { ad: 'b64', desen: /(?<![^\s])[A-Za-z0-9+/]{40,}={0,2}(?![^\s])/g },
];

// Instruction-desen dedektörü (stub): işaretler, metni DEĞİŞTİRMEZ.
const INSTRUCTION_DESENI = /ignore (all )?(previous|above) instructions|system prompt|<\s*script/i;

// Sır-biçimlerini placeholder'a çevirir; metnin geri kalanına dokunmaz.
export function redakte(metin) {
  let sonuc = metin;
  for (const { ad, desen } of DESENLER) {
    sonuc = sonuc.replace(desen, `[REDACTED:${ad}]`);
  }
  return sonuc;
}

// Satır-bazlı karantina taraması. Dönüş: { karantina: bool, satirlar: [{satir_no, metin}] }.
// Rapordaki satır-metni de redakte edilir (rapor kanalından sır sızmasın).
export function karantinaTara(metin) {
  const satirlar = [];
  const parcalar = metin.split(/\r?\n/);
  for (let i = 0; i < parcalar.length; i++) {
    if (INSTRUCTION_DESENI.test(parcalar[i])) {
      satirlar.push({ satir_no: i + 1, metin: redakte(parcalar[i]) });
    }
  }
  return { karantina: satirlar.length > 0, satirlar };
}

function kullanim() {
  process.stderr.write('kullanım: node redaction.mjs <dosya|-> (stdout: redakte-metin, stderr: karantina-raporu JSON)\n');
  process.exit(2);
}

function main() {
  const argv = process.argv.slice(2);
  if (argv.length > 1 || argv[0] === '--help' || argv[0] === '-h') kullanim();
  const dosya = argv[0];
  const ham = !dosya || dosya === '-' ? readFileSync(0, 'utf8') : readFileSync(dosya, 'utf8');
  process.stdout.write(redakte(ham));
  const rapor = karantinaTara(ham);
  rapor.skill_version = SKILL_VERSION;
  process.stderr.write(JSON.stringify(rapor, null, 2) + '\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
