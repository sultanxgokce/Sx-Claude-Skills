// kapi/kimlik.mjs — hangi tmux oturumunda HANGİ Claude konuşması çalışıyor (salt-okur). Kadro kişi↔oturum eşleşmesinin kimlik ayağı.
// SERDAR 16 Eki 00:4x (Sultan 00:22 karesi, huzur): eşleşme yalnız tmux adıyla yapılınca ana oturumda çalışan kişi iki satır oluyordu
// ("oturumu yok" + ana "kimliği yok"). Kimlik izi: Claude her süreç için `<yapılandırma>/sessions/<pid>.json` yazar —
// { pid, sessionId, tmux:"<oturum>:@N.%N", name, nameSource, pidDomain }. Kimlik tanıma kancası (aile-self-recognition) da kişinin
// kayıt satırına `session_id:` yazar. İkisi buluşunca kişi, adı ne olursa olsun çalıştığı oturuma bağlanır.
// 🔴 Ortak dizin: /config/.claude birçok kutuda paylaşılır → başka kutunun ya da ölmüş sürecin dosyası SAYILMAZ:
//    pidDomain bu sürecin pid alanı olmalı · /proc/<pid> yaşamalı · /proc/<pid>/cmdline'ın programı claude olmalı (pid yeniden kullanımı).
// 🔴 Hiçbir şey yazmaz; dizin okunamazsa boş döner (kimlik izi yoksa eşleşme tmux adına düşer — bugünkü davranış, uydurma yok).
import fs from 'node:fs';
import path from 'node:path';

export function oturumDizinleri(ortam = process.env) {
  if (ortam.KAPI_OTURUM_DIZ) return ortam.KAPI_OTURUM_DIZ.split(':').filter(Boolean);
  const kok = ortam.CLAUDE_CONFIG_DIR || '/config/.claude';
  const l = [path.join(kok, 'sessions'), '/config/.claude/sessions'];
  try { for (const h of fs.readdirSync('/config/.claude/hesaplar')) l.push(path.join('/config/.claude/hesaplar', h, 'sessions')); } catch {}
  return [...new Set(l)];
}

// → Map<tmuxOturumAdı, [{ sessionId, ad, adKaynak, pid }]>
export function oturumKimlikleri({ dizinler = oturumDizinleri(), procKok = '/proc', pidAlani } = {}) {
  let alan = pidAlani;
  if (alan === undefined) { try { alan = fs.readlinkSync(path.join(procKok, 'self/ns/pid')); } catch { alan = ''; } }
  const h = new Map(), gorulen = new Set();
  for (const d of dizinler) {
    let adlar; try { adlar = fs.readdirSync(d); } catch { continue; }
    for (const f of adlar) {
      if (!/^\d+\.json$/.test(f)) continue;
      let j; try { j = JSON.parse(fs.readFileSync(path.join(d, f), 'utf8')); } catch { continue; }
      const pid = String(j.pid || ''); if (!/^\d+$/.test(pid) || gorulen.has(pid)) continue;
      if (!alan || !String(j.pidDomain || '').endsWith(alan)) continue;                         // başka kutunun süreci
      let arg0 = ''; try { arg0 = fs.readFileSync(path.join(procKok, pid, 'cmdline'), 'utf8').split('\0')[0]; } catch { continue; }   // ölmüş
      if (!/(^|\/)claude$/.test(arg0)) continue;                                                 // pid başka programa geçmiş
      const oturum = String(j.tmux || '').split(':')[0]; if (!oturum || !j.sessionId) continue;
      gorulen.add(pid);
      if (!h.has(oturum)) h.set(oturum, []);
      h.get(oturum).push({ sessionId: String(j.sessionId), ad: String(j.name || ''), adKaynak: String(j.nameSource || ''), pid });
    }
  }
  return h;
}
