// Kutu font taşımayabilir (bu kutuda sıfır sistem-fontu ölçüldü) → motor kendi fontunu taşır.
// dejavu-fonts-ttf npm paketi + çalışma anında üretilen fontconfig ayarı; sharp (libvips/pango)
// import edilmeden ÖNCE çağrılmalı. Sistem fontconfig'i varsa dokunulmaz.
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { createRequire } from 'module';
import { dirname, join } from 'path';
import { tmpdir } from 'os';

export function fontHazirla() {
  if (process.env.FONTCONFIG_FILE || process.env.FONTCONFIG_PATH) return; // kullanıcı ayarına saygı
  let ttfDizini;
  try {
    const require = createRequire(import.meta.url);
    ttfDizini = join(dirname(require.resolve('dejavu-fonts-ttf/package.json')), 'ttf');
  } catch {
    return; // font paketi yoksa sessiz geç — SVG yine doğru, yalnız PNG metni düşer
  }
  if (!existsSync(ttfDizini)) return;
  const kokDizin = join(tmpdir(), 'plan-motor-fontconfig');
  mkdirSync(join(kokDizin, 'cache'), { recursive: true });
  const ayarYolu = join(kokDizin, 'fonts.conf');
  writeFileSync(ayarYolu, `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>${ttfDizini}</dir>
  <cachedir>${join(kokDizin, 'cache')}</cachedir>
</fontconfig>
`);
  process.env.FONTCONFIG_FILE = ayarYolu;
}
