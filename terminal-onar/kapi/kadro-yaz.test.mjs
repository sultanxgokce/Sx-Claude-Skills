// kadro-yaz.test.mjs — KADRO E2 kayıt yazıcısı (hermetik: geçici dizin + sahte derleyici; gerçek kayda dokunmaz, ağ yok, tmux yok)
//   node kadro-yaz.test.mjs [--gercek]   (--gercek: kutulardaki GERÇEK kayıtların KOPYALARIYLA gidiş-dönüş bayt eşitliği)
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync, rmSync, statSync, chmodSync, existsSync, copyFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { kadroYaz, durumDegistir, kayitDosyalari, KadroHata, adetAyarla } from './kadro-yaz.mjs';
import { kayitOku, kadroBirlestir } from './kadro.mjs';
let g = 0, k = 0; const kapi = (ad, ok, ek = '') => { if (ok) { g++; console.log('  ✓ ' + ad); } else { k++; console.log('  ✗ ' + ad + ' ' + ek); } };
const T = mkdtempSync(join(tmpdir(), 'kadro-yaz-'));
const hata = (f) => { try { f(); return null; } catch (e) { return e; } };
const yaz = (y, m) => { mkdirSync(dirname(y), { recursive: true }); writeFileSync(y, m); };

console.log('── Y · saf dönüşüm (durumDegistir)');
const ELLE = 'meta:\n  aile: X\nuyeler:\n  - id: A\n    tmux: "a:0"\n    durum: canli   # yorum\n    rol: "bir"\n  - id: B\n    tmux: b:0\n    kanallar:\n      - x.md\n    rol: iki\n# son satır\n';
const y1 = durumDegistir(ELLE, 'id', 'A', 'emekli');
kapi('Y1 durum değeri yerinde değişir (satır yorumu kalır), önceki değer durum_once satırına; başka satır DEĞİŞMEZ', y1.metin === ELLE.replace('    durum: canli   # yorum\n', '    durum: emekli   # yorum\n    durum_once: canli\n') && y1.onceki === 'canli', JSON.stringify(y1.metin));
const y1g = durumDegistir(y1.metin, 'id', 'A', 'geri-ac');
kapi('Y2 geri aç önceki değeri koyar, durum_once satırı kalkar → BAYT BAYT ilk hâl (satır yorumu korunur)', y1g.metin === ELLE && y1g.yeni === 'canli');
const y3 = durumDegistir(ELLE, 'id', 'B', 'dondur');
kapi('Y3 durum satırı yoksa id satırının ALTINA iki satır, bloğun girintisiyle (iç içe liste bozulmaz)', y3.metin === ELLE.replace('  - id: B\n', '  - id: B\n    durum: dondurulmus\n    durum_once: yok\n'), JSON.stringify(y3.metin));
kapi('Y4 "yok" geri açılınca iki satır da kalkar → BAYT BAYT ilk hâl', durumDegistir(y3.metin, 'id', 'B', 'geri-ac').metin === ELLE);
const e409 = (f) => { const e = hata(f); return e instanceof KadroHata && e.kod === 409; };
kapi('Y5 zaten dondurulmuşu dondur/emekli et → 409 (üstüne yazıp önceki değeri kaybetmez)', e409(() => durumDegistir(y3.metin, 'id', 'B', 'dondur')) && e409(() => durumDegistir(y3.metin, 'id', 'B', 'emekli')));
kapi('Y6 dondurulmamışı geri aç → 409; durum_once\'suz emekliyi geri aç → 409', e409(() => durumDegistir(ELLE, 'id', 'A', 'geri-ac')) && e409(() => durumDegistir(ELLE.replace('durum: canli', 'durum: emekli'), 'id', 'A', 'geri-ac')));
kapi('Y7 aynı id iki kez → 409 (hangisine yazılacağı belirsiz)', e409(() => durumDegistir(ELLE + '  - id: A\n    tmux: z\n', 'id', 'A', 'dondur')));
const e404 = hata(() => durumDegistir(ELLE, 'id', 'YOK', 'dondur'));
kapi('Y8 kayıtta olmayan id → 404; düzenli ifade karakterli id ("A.*") başka kişiye eşleşmez', e404?.kod === 404 && hata(() => durumDegistir(ELLE, 'id', 'A.*', 'dondur'))?.kod === 404);
kapi('Y9 tuhaf şu anki değer ("can li") → 409 (satıra ham değer geri yazılmaz)', e409(() => durumDegistir(ELLE.replace('durum: canli   # yorum', 'durum: "can li"'), 'id', 'A', 'dondur')));
kapi('Y10 tuhaf durum_once ("a b") geri konmaz → 409', e409(() => durumDegistir(y1.metin.replace('durum_once: canli', 'durum_once: "a b"'), 'id', 'A', 'geri-ac')));
const MODEL = 'roller:\n- ad: MÜDÜR\n  olcek:\n    ornekler:\n    - kayit: u-yon\n      durum: canli\n      bolge: governance\n    - kayit: u-iki\n      durum: canli\n';
kapi('Y11 ekip modeli (`- kayit:` örnekleri, derin girinti) aynı kuralla', durumDegistir(MODEL, 'kayit', 'u-yon', 'dondur').metin === MODEL.replace('      durum: canli\n      bolge', '      durum: dondurulmus\n      durum_once: canli\n      bolge'));

const MODEL2 = 'roller:\n- ad: MÜDÜR\n  olcek:\n    adet: 2   # not\n    tavan: 3\n    ornekler:\n    - kayit: a\n      durum: canli\n    - kayit: b\n      durum: canli\n- ad: ÖTEKİ\n  olcek:\n    adet: 5\n';
kapi('Y12 K13: adet yalnız kişinin KENDİ rolünde bir azalır/artar (yorum kalır; başka rolün adet\'i dokunulmaz); adet satırı yoksa metin aynen', adetAyarla(MODEL2, 'b', -1) === MODEL2.replace('adet: 2   # not', 'adet: 1   # not') && adetAyarla(adetAyarla(MODEL2, 'b', -1), 'b', 1) === MODEL2 && adetAyarla(MODEL, 'u-yon', -1) === MODEL);
console.log('── Z · dosya: elle kayıt (İSKÂN kutusu + merkez)');
const isk = join(T, 'iskan');
yaz(join(isk, 'iskan-registry.yaml'), 'ekip_registry_pointer: _agents/handoff/ekip-registry.yaml\nuyeler:\n  - id: REIS\n    tmux: "reis:0"\n');
yaz(join(isk, '_agents/handoff/ekip-registry.yaml'), 'uyeler:\n  - id: REIS\n    rol: başkâtip\n    hal: calisiyor\n');
chmodSync(join(isk, '_agents/handoff/ekip-registry.yaml'), 0o640);
kapi('Z1 yazma sırası okuyucuyla aynı: [iskan, ekip kaydı]', kayitDosyalari(isk).map((y) => y.slice(isk.length)).join() === '/iskan-registry.yaml,/_agents/handoff/ekip-registry.yaml');
const z = kadroYaz({ proje: isk, id: 'REIS', eylem: 'dondur' });
const okunan = kadroBirlestir({ uyeler: kayitOku(isk).uyeler, koltuklar: [], ana: '' }).kisiler[0];
kapi('Z2 SON kaynağa (ekip kaydı) yazıldı ve OKUYUCU onu görüyor: dondurulmus + geri açılır', z.dosya.endsWith('_agents/handoff/ekip-registry.yaml') && !z.uretilmis && okunan.hal_kayit === 'dondurulmus' && okunan.geri_acilir, JSON.stringify(okunan));
kapi('Z3 dosya kipi korunur (0640); iskan kaydına dokunulmadı', (statSync(join(isk, '_agents/handoff/ekip-registry.yaml')).mode & 0o777) === 0o640 && !readFileSync(join(isk, 'iskan-registry.yaml'), 'utf8').includes('durum'));
kadroYaz({ proje: isk, id: 'REIS', eylem: 'geri-ac' });
kapi('Z4 geri aç → dosya bayt bayt ilk hâl', readFileSync(join(isk, '_agents/handoff/ekip-registry.yaml'), 'utf8') === 'uyeler:\n  - id: REIS\n    rol: başkâtip\n    hal: calisiyor\n');

console.log('── U · üretilmiş kayıt: kaynak model + derleyici');
const ur = join(T, 'uretilmis');
const AILE = 'uyeler:\n- id: u-yon\n  tmux: u-yon:0\n  rol: defteri akıtmak\n';
const URETILEN = (d) => '# <!-- ekipc:uretilen:basla surum=1 hash=' + d + ' -->\nuyeler:\n  - id: u-yon\n    rol: MÜDÜR\n    durum: ' + d + '\n    tmux: null\n# <!-- ekipc:uretilen:bitti -->\n\n# ## ELLE (ekipc dokunmaz)\n';
const kur = () => { yaz(join(ur, '_agents/ekip-os/mudur/AGENT.md'), '# MÜDÜR\n'); yaz(join(ur, '_agents/handoff/aile-registry.yaml'), AILE); yaz(join(ur, '_agents/ekip-os/ekip-registry.yaml'), URETILEN('canli')); yaz(join(ur, '_agents/ekip-modeli.yaml'), MODEL.replace(/u-yon/g, 'u-yon')); };
kur();
const ilk = { m: readFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'utf8'), r: readFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), 'utf8') };
const yok = hata(() => kadroYaz({ proje: ur, id: 'u-yon', eylem: 'dondur', ortam: {} }));
kapi('U1 derleyici yok → 503, model ve üretilmiş kayıt BAYT BAYT aynı (yarım yazma yok)', yok?.kod === 503 && readFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'utf8') === ilk.m && readFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), 'utf8') === ilk.r, String(yok?.message));
// Sahte derleyici: argümanları kaydeder, modeldeki u-yon durumunu üretilmiş kayda taşır (ekipc'nin bu alandaki işi)
const DERLE = join(T, 'ekipc-sahte.sh'), DEFTER = join(T, 'ekipc-defter');
writeFileSync(DERLE, `#!/usr/bin/env bash\necho "$*" >> ${JSON.stringify(DEFTER)}\n[ -n "$SAHTE_DUS" ] && { echo "lint kırmızı" >&2; exit 4; }\nm="$3"; h="$5"\nd=$(awk '/- kayit: u-yon/{f=1;next} f&&/durum:/{print $2;exit}' "$m")\n[ -n "$SAHTE_UNUT" ] && exit 0\nawk -v d="$d" '/- id: /{b=($3=="u-yon")} b&&/^    durum: /{$0="    durum: " d} {print}' "$h/ekip-registry.yaml" > "$h/r.y" && mv "$h/r.y" "$h/ekip-registry.yaml"\nsed -i "s/hash=[a-z0-9]*/hash=$d/" "$h/ekip-registry.yaml"\n[ -n "$SAHTE_BASKA" ] && awk '/- id: u-baska/{b=1} b&&/durum: canli/{sub(/canli/,"emekli");b=0} {print}' "$h/ekip-registry.yaml" > "$h/r.y" && mv "$h/r.y" "$h/ekip-registry.yaml"\necho "derleyicinin bekleyen farkı" >> "$h/mudur/AGENT.md"; echo yeni > "$h/yeni-dosya.md"\n`);
const ortam = { KAPI_EKIPC: DERLE };
const u2 = kadroYaz({ proje: ur, id: 'u-yon', eylem: 'dondur', ortam });
const okU = kadroBirlestir({ uyeler: kayitOku(ur).uyeler, koltuklar: [], ana: '' }).kisiler.find((x) => x.id === 'u-yon');
kapi('U2 üretilmiş bölgedeki kişi → yazım MODELE gider, derleyici KUTUNUN aile kaydıyla (--aile) --apply koşar; üretilmiş kayıt elle yazılmadı', u2.uretilmis && u2.dosya.endsWith('_agents/ekip-modeli.yaml') && /derle --manifest .*ekip-modeli\.yaml --hedef .*_agents\/ekip-os --aile .*uretilmis\/_agents\/handoff\/aile-registry\.yaml --apply/.test(readFileSync(DEFTER, 'utf8')), readFileSync(DEFTER, 'utf8'));
kapi('U2b derleyicinin KAYIT DIŞI farkları (başka kimlik dosyası, yeni dosya) uygulanmaz, sayısı söylenir', u2.uygulanmayan_fark === 2 && readFileSync(join(ur, '_agents/ekip-os/mudur/AGENT.md'), 'utf8') === '# MÜDÜR\n' && !existsSync(join(ur, '_agents/ekip-os/yeni-dosya.md')), JSON.stringify(u2));
kapi('U3 okuyucu: durum üretilmiş kayıttan (dondurulmus), durum_once modelden → geri açılır; rol aile kaydından', okU.hal_kayit === 'dondurulmus' && okU.geri_acilir && okU.rol === 'defteri akıtmak', JSON.stringify(okU));
kadroYaz({ proje: ur, id: 'u-yon', eylem: 'geri-ac', ortam });
kapi('U4 geri aç → model ve üretilmiş kayıt BAYT BAYT ilk hâl', readFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'utf8') === ilk.m && readFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), 'utf8') === ilk.r);
const dus = hata(() => kadroYaz({ proje: ur, id: 'u-yon', eylem: 'emekli', ortam: { ...ortam, SAHTE_DUS: '1' } }));
kapi('U5 derleyici düşerse 502 + model geri alındı (bayt eşit)', dus?.kod === 502 && readFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'utf8') === ilk.m, String(dus?.message));
const unut = hata(() => kadroYaz({ proje: ur, id: 'u-yon', eylem: 'emekli', ortam: { ...ortam, SAHTE_UNUT: '1' } }));
kapi('U6 derleyici "başarılı" ama üretilmiş kayıt değişmedi → 502 + geri alındı (ekranda görünmeyecek yazım kabul edilmez)', unut?.kod === 502 && readFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'utf8') === ilk.m, String(unut?.message));
// Derleyici AYNI kayıt dosyasında başka kişinin satırını da değiştirirse (bekleyen fark) yazım kabul edilmez (bağımsız göz tur 1)
yaz(join(ur, '_agents/ekip-os/ekip-registry.yaml'), URETILEN('canli').replace('# <!-- ekipc:uretilen:bitti -->', '  - id: u-baska\n    rol: KÂŞİF\n    durum: canli\n# <!-- ekipc:uretilen:bitti -->'));
const ilk2 = { m: readFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'utf8'), r: readFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), 'utf8') };
const bas = hata(() => kadroYaz({ proje: ur, id: 'u-yon', eylem: 'dondur', ortam: { ...ortam, SAHTE_BASKA: '1' } }));
kapi('U8 derleyici aynı dosyada BAŞKA kişinin satırını değiştirdi → 409, model ve kayıt BAYT BAYT ilk hâl', bas?.kod === 409 && /ilgisiz bekleyen derleme farkı/.test(bas.message) && readFileSync(join(ur, '_agents/ekip-modeli.yaml'), 'utf8') === ilk2.m && readFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), 'utf8') === ilk2.r, String(bas?.message));
const tam = kadroYaz({ proje: ur, id: 'u-yon', eylem: 'dondur', ortam });
kapi('U9 aynı dosyada yalnız kişinin bloğu + hash satırı değişirse kabul (sahte derleyici hash satırını da yeniler)', tam.uretilmis && readFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), 'utf8').includes('hash=dondurulmus'));
kadroYaz({ proje: ur, id: 'u-yon', eylem: 'geri-ac', ortam }); kur();
// Üretilmiş dosyanın ELLE bölgesindeki kişi elle yazılır (derleyici o bölgeye dokunmaz)
yaz(join(ur, '_agents/ekip-os/ekip-registry.yaml'), URETILEN('canli') + 'uyeler_elle:\n  - id: u-elle\n    durum: canli\n');
yaz(join(ur, '_agents/handoff/aile-registry.yaml'), AILE + '- id: u-elle\n  tmux: u-elle:0\n');
const u7 = kadroYaz({ proje: ur, id: 'u-elle', eylem: 'dondur', ortam: {} });
kapi('U7 aynı dosyanın ELLE bölgesindeki kişi → derleyicisiz doğrudan yazılır', !u7.uretilmis && readFileSync(join(ur, '_agents/ekip-os/ekip-registry.yaml'), 'utf8').includes('  - id: u-elle\n    durum: dondurulmus\n    durum_once: canli'));

if (process.argv.includes('--gercek')) {
  console.log('── G · gerçek kayıtların KOPYALARI: dondur → geri aç bayt eşitliği (kaynağa dokunulmaz)');
  for (const [kutu, dosya, anahtar] of [['huma', '_agents/handoff/ekip-registry.yaml', 'id'], ['mihenk', '_agents/handoff/ekip-registry.yaml', 'id'], ['Nexus', '_agents/handoff/aile-registry.yaml', 'id'], ['s02', '_agents/ekip-modeli.yaml', 'kayit'], ['sedir', '_agents/ekip-modeli.yaml', 'kayit']]) {
    const kaynak = join('/config/projects', kutu, dosya);
    if (!existsSync(kaynak)) { kapi(`G ${kutu}: ölçülemedi (dosya yok)`, false); continue; }
    const m = readFileSync(kaynak, 'utf8');
    const idler = [...m.matchAll(new RegExp('^\\s*-\\s*' + anahtar + ':\\s*["\']?([^"\'#\\s]+)', 'gm'))].map((x) => x[1]);
    let tamam = 0, atla = 0;
    for (const id of idler) {
      let a; try { a = durumDegistir(m, anahtar, id, 'dondur'); } catch (e) { if (e.kod === 409) { atla++; continue; } throw e; }
      if (durumDegistir(a.metin, anahtar, id, 'geri-ac').metin === m) tamam++;
    }
    kapi(`G ${kutu}: ${tamam}/${idler.length - atla} kişi dondur→geri aç bayt eşit (${atla} atlandı: zaten emekli/belirsiz)`, idler.length > 0 && tamam === idler.length - atla && tamam > 0);
  }
}
console.log('── K · kayıt kilidi (B7): yazım kilit altında');
const KP = join(T, 'kilitli'), KR = join(KP, 'iskan-registry.yaml'), KO = { ISKAN_REGISTRY: KR };
yaz(KR, ELLE);
writeFileSync(join(KP, 'kadro.kilit'), process.pid + ' canli');
const k503 = hata(() => kadroYaz({ proje: KP, id: 'A', eylem: 'dondur', ortam: KO }));
kapi('K1 kayıt başka CANLI süreçte kilitliyken → 503, kayıt dosyası aynen kalır', k503 instanceof KadroHata && k503.kod === 503 && readFileSync(KR, 'utf8') === ELLE, String(k503?.kod));
rmSync(join(KP, 'kadro.kilit'));
const kr = kadroYaz({ proje: KP, id: 'A', eylem: 'dondur', ortam: KO });
kapi('K2 kilit yokken yazım tutar; iş bitince kadro.kilit kalmaz', kr.dosya === KR && readFileSync(KR, 'utf8').includes('durum: dondurulmus') && !existsSync(join(KP, 'kadro.kilit')));
rmSync(T, { recursive: true, force: true });
console.log(`\nSONUÇ: ${g} geçti · ${k} kaldı`); process.exit(k ? 1 : 0);
