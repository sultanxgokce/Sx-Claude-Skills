/**
 * postane — ajanlar arası mesajların TEK kaydı (POSTANE F1 · Sultan 24 Eki 2026, "sistem güzel lütfen kuralım").
 *
 * Niçin: bugünkü 12 yolda "teslim edildi" yalnız tuşların basıldığını söylüyordu; okundu/işlendi ölçülmüyordu,
 * 7 günde 132 zil sessizce düştü, 837 bitti/bekliyor zilinin çoğu toplu kapatıldı. Burada her mesajın bir durumu,
 * son tarihi ve izi vardır; hiçbir mesaj sessizce kaybolamaz: ya işlenir, ya reddedilir (gerekçeyle), ya ölü mektup olur.
 *
 * Durumlar:  gonderildi → teslim → goruldu → islendi | reddedildi        (olu: 3 denemede işlenmedi)
 *   teslim    = alıcının postacısı mesajı çekti (kira başladı)
 *   goruldu   = alıcı ajan mesajı okuduğunu bildirdi (daha uzun kira)
 *   kira dolarsa: deneme < 3 → mesaj yeniden görünür (gonderildi); deneme = 3 → olu (ölü mektup).
 *
 * Aciliyet (son tarih gönderimden itibaren): jet 30 sn · hizli 5 dk · orta 30 dk · genis 2 sa.
 * Son tarih dolup hâlâ işlenmediyse mesaj "geciken" olur (olaya bir kez yazılır) — kimse onu görmezden gelemez.
 *
 * Tekrar anahtarı: aynı gönderenin aynı anahtarla ikinci gönderimi YENİ mesaj açmaz, ilkini döndürür.
 * Ad katlaması: alıcı adı tek yazıma çevrilir (MUAVİN/muav/MUAVIN → MUAVİN); listede olmayan alıcı REDDEDİLİR —
 * sessiz düşmenin bir kaynağı tam buydu ("MUAVİN" → "muav"), bilinmeyen adı yola koymak mesajı yitirir.
 *
 * Bağımlılık YOK: yalnız node stdlib (node:sqlite, WAL). Saat dışarıdan verilir → sınanabilir.
 */
import { DatabaseSync } from 'node:sqlite';
import { AJAN_ADLARI, katla, tekYazim } from './ajan-adlari.mjs';
import { ulid } from './ulid.mjs';

export const ACILIYET = Object.freeze({ jet: 30_000, hizli: 300_000, orta: 1_800_000, genis: 7_200_000 });
export const KIRA_TESLIM_MS = 300_000;     // teslim edildi (5 dk: 2 dk iken meşgul koltukta aynı mektup ikinci kez basılıyordu — …H7A2), "gördüm" gelmezse mesaj yeniden görünür
export const KIRA_GORULDU_MS = 600_000;    // görüldü, "işlendi" gelmezse mesaj yeniden görünür
export const MAX_DENEME = 3;
export const ICERIK_AZAMI = 20_000;
export const KAPALI = Object.freeze(['islendi', 'reddedildi', 'olu', 'arsiv']);
export const OLU_ARSIV_MS = 86_400_000;   // ölü mektup 24 saat kimse kapatmazsa kendiliğinden arşive düşer (…1SSZVC: liste hiç erimiyordu)
const ACIK = Object.freeze(['gonderildi', 'teslim', 'goruldu']);

const SEMA = `
CREATE TABLE IF NOT EXISTS mesaj (
  id TEXT PRIMARY KEY, kimden TEXT NOT NULL, kutu TEXT NOT NULL, kime TEXT NOT NULL,
  aciliyet TEXT NOT NULL, son_tarih INTEGER NOT NULL, konu TEXT NOT NULL DEFAULT '', icerik TEXT NOT NULL,
  durum TEXT NOT NULL, tekrar TEXT, olusturma INTEGER NOT NULL,
  teslim_ts INTEGER, goruldu_ts INTEGER, islendi_ts INTEGER, deneme INTEGER NOT NULL DEFAULT 0,
  kira_bitis INTEGER, gerekce TEXT, gecikti_ts INTEGER
);
CREATE UNIQUE INDEX IF NOT EXISTS mesaj_tekrar ON mesaj(kimden, tekrar) WHERE tekrar IS NOT NULL;
CREATE INDEX IF NOT EXISTS mesaj_kutu ON mesaj(kime, durum, son_tarih);
CREATE TABLE IF NOT EXISTS olay (
  sira INTEGER PRIMARY KEY AUTOINCREMENT, mesaj_id TEXT NOT NULL, ts INTEGER NOT NULL,
  tur TEXT NOT NULL, kim TEXT NOT NULL DEFAULT '', ayrinti TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS olay_mesaj ON olay(mesaj_id, sira);
`;

const hata = (kod, neden, durum = 400) => ({ ok: false, durum, hata: kod, neden });

/** Ad listesi: ajan-adlari + isteğe bağlı ek ad listesi (yeni ajan eklemek kodu değiştirmeyi gerektirmesin). */
export function adlariKur(ek = []) {
  const liste = [...AJAN_ADLARI];
  const harita = new Map(liste.map((a) => [katla(a), a]));
  for (const a of ek) { const k = katla(a); if (k && !harita.has(k)) { harita.set(k, a); liste.push(a); } }
  return { liste, coz: (ad) => harita.get(katla(ad)) ?? null };
}

export function postaneAc(dosya, { adlar = adlariKur() } = {}) {
  const db = new DatabaseSync(dosya);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000; PRAGMA synchronous = NORMAL;');
  db.exec(SEMA);

  const sec = (sql, ...p) => db.prepare(sql).all(...p);
  const bir = (sql, ...p) => db.prepare(sql).get(...p);
  const calis = (sql, ...p) => db.prepare(sql).run(...p);
  const islem = (fn) => {
    db.exec('BEGIN IMMEDIATE');
    try { const s = fn(); db.exec('COMMIT'); return s; } catch (e) { db.exec('ROLLBACK'); throw e; }
  };
  const olay = (id, ts, tur, kim = '', ayrinti = '') =>
    calis('INSERT INTO olay (mesaj_id, ts, tur, kim, ayrinti) VALUES (?,?,?,?,?)', id, ts, tur, kim, ayrinti);
  const goster = (m, now) => (m ? { ...m, kalan_ms: ACIK.includes(m.durum) ? m.son_tarih - now : null } : null);

  /** Kira dolanları yeniden görünür kılar / ölü mektup yapar; son tarihi geçenleri bir kez "gecikti" diye işaretler. */
  function supur(now) {
    return islem(() => {
      const sayac = { yeniden: 0, olu: 0, gecikti: 0 };
      for (const m of sec(`SELECT id, deneme FROM mesaj WHERE durum IN ('teslim','goruldu') AND kira_bitis <= ?`, now)) {
        if (m.deneme >= MAX_DENEME) {
          calis(`UPDATE mesaj SET durum='olu', kira_bitis=NULL WHERE id=?`, m.id);
          olay(m.id, now, 'olu', 'postane', `${MAX_DENEME} denemede işlenmedi`);
          sayac.olu++;
        } else {
          calis(`UPDATE mesaj SET durum='gonderildi', kira_bitis=NULL WHERE id=?`, m.id);
          olay(m.id, now, 'kira_doldu', 'postane', `deneme ${m.deneme}/${MAX_DENEME}: işlenmedi, yeniden görünür`);
          sayac.yeniden++;
        }
      }
      // Ölü mektup 24 saat kapatılmazsa arşiv: SERDAR'ın listesi erir, zil üretmez (…1SSZVC). Ölüm anı olay kaydından okunur (şema değişmez).
      sayac.arsiv = 0;
      for (const m of sec(`SELECT m.id FROM mesaj m JOIN olay o ON o.mesaj_id=m.id AND o.tur='olu' WHERE m.durum='olu' AND o.ts <= ?`, now - OLU_ARSIV_MS)) {
        calis(`UPDATE mesaj SET durum='arsiv' WHERE id=?`, m.id);
        olay(m.id, now, 'olu_arsiv', 'postane', '24 saat kimse kapatmadı, arşive düştü');
        sayac.arsiv++;
      }
      for (const m of sec(`SELECT id FROM mesaj WHERE durum IN ('gonderildi','teslim','goruldu') AND son_tarih < ? AND gecikti_ts IS NULL`, now)) {
        calis('UPDATE mesaj SET gecikti_ts=? WHERE id=?', now, m.id);
        olay(m.id, now, 'gecikti', 'postane', 'son tarih doldu, işlenmedi');
        sayac.gecikti++;
      }
      return sayac;
    });
  }

  function gonder({ kimden, kutu, kime, aciliyet = 'orta', icerik, konu = '', tekrar = null }, now) {
    if (typeof kimden !== 'string' || !kimden.trim()) return hata('kimden_yok', 'gönderen adı (kimden) gerekli');
    if (typeof kime !== 'string' || !kime.trim()) return hata('kime_yok', 'alıcı adı (kime) gerekli');
    if (!Object.hasOwn(ACILIYET, aciliyet)) return hata('aciliyet_gecersiz', `aciliyet ${Object.keys(ACILIYET).join(' | ')} olmalı`);
    if (typeof icerik !== 'string' || !icerik.trim()) return hata('icerik_yok', 'mesaj metni boş olamaz');
    if (icerik.length > ICERIK_AZAMI) return hata('icerik_uzun', `mesaj en çok ${ICERIK_AZAMI} karakter`);
    if (typeof konu !== 'string' || konu.length > 200) return hata('konu_uzun', 'konu en çok 200 karakter');
    if (tekrar !== null && (typeof tekrar !== 'string' || !tekrar || tekrar.length > 200)) return hata('tekrar_gecersiz', 'tekrar anahtarı 1-200 karakter');
    const alici = adlar.coz(kime);
    if (!alici) return hata('alici_bilinmiyor', `alıcı '${kime}' ajan listesinde yok — mesaj sessizce düşmesin diye kabul edilmedi`, 422);
    const gonderen = adlar.coz(kimden);
    if (!gonderen) return hata('gonderen_bilinmiyor', `gönderen '${kimden}' ajan listesinde yok — gönderen taklidi/yazım hatası kabul edilmez`, 422);

    return islem(() => {
      if (tekrar !== null) {
        const var_ = bir('SELECT * FROM mesaj WHERE kimden=? AND tekrar=?', gonderen, tekrar);
        if (var_) return { ok: true, tekrar: true, mesaj: goster(var_, now) };
      }
      const id = `msg_${ulid(now)}`;
      calis(`INSERT INTO mesaj (id, kimden, kutu, kime, aciliyet, son_tarih, konu, icerik, durum, tekrar, olusturma)
             VALUES (?,?,?,?,?,?,?,?,'gonderildi',?,?)`,
        id, gonderen, kutu ?? '', alici, aciliyet, now + ACILIYET[aciliyet], konu, icerik, tekrar, now);
      olay(id, now, 'gonderildi', gonderen, `${gonderen} → ${alici} · ${aciliyet}`);
      return { ok: true, tekrar: false, mesaj: goster(bir('SELECT * FROM mesaj WHERE id=?', id), now) };
    });
  }

  /** Alıcının postacısı çeker: gonderildi → teslim (kira başlar, deneme artar). vadeli=true → yalnız jet ve son tarihi gelenler. */
  function al({ kime, limit = 10, vadeli = false }, now) {
    const alici = adlar.coz(kime);
    if (!alici) return hata('alici_bilinmiyor', `'${kime}' ajan listesinde yok`, 422);
    const n = Math.min(Math.max(Number.isInteger(limit) ? limit : 10, 1), 50);
    supur(now);
    return islem(() => {
      const vade = vadeli ? `AND (aciliyet='jet' OR son_tarih <= ${Number(now)})` : '';
      const satirlar = sec(`SELECT * FROM mesaj WHERE kime=? AND durum='gonderildi' ${vade} ORDER BY son_tarih ASC, id ASC LIMIT ?`, alici, n);
      for (const m of satirlar) {
        calis(`UPDATE mesaj SET durum='teslim', deneme=deneme+1, teslim_ts=COALESCE(teslim_ts, ?), kira_bitis=? WHERE id=?`, now, now + KIRA_TESLIM_MS, m.id);
        olay(m.id, now, 'teslim', alici, `deneme ${m.deneme + 1}/${MAX_DENEME}`);
      }
      const yeni = satirlar.map((m) => goster(bir('SELECT * FROM mesaj WHERE id=?', m.id), now));
      return { ok: true, mesajlar: yeni };
    });
  }

  const mesajBul = (id) => bir('SELECT * FROM mesaj WHERE id=?', id);

  function gordum(id, kim, now) {
    return islem(() => {
      const m = mesajBul(id);
      if (!m) return hata('mesaj_yok', `${id} yok`, 404);
      if (KAPALI.includes(m.durum)) return hata('durum_kapali', `mesaj zaten ${m.durum}`, 409);
      if (m.durum === 'goruldu') return { ok: true, tekrar: true, mesaj: goster(m, now) };
      if (m.durum !== 'teslim') return hata('durum_sirasi', `mesaj '${m.durum}' durumunda: önce posta al ile teslim alınmalı (kira dolduysa yeniden alınır)`, 409);
      calis(`UPDATE mesaj SET durum='goruldu', goruldu_ts=?, kira_bitis=? WHERE id=?`, now, now + KIRA_GORULDU_MS, id);
      olay(id, now, 'goruldu', kim);
      return { ok: true, tekrar: false, mesaj: goster(mesajBul(id), now) };
    });
  }

  /**
   * Postacının soket teslimi. Durum geçişi YALNIZ soket başarısıyla olur (kart: "teslim yalnız soket başarısıyla işaretlenir"):
   *  · gonderildi + iletildi    → teslim (deneme+1, kira başlar), olaylar: teslim + iletildi
   *  · gonderildi + iletilemedi → gonderildi kalır, deneme+1; MAX_DENEME dolunca ölü mektup (sessiz düşme yok)
   *  · basladi                  → niyet olayı (sokete yazmadan ÖNCE); durum değişmez
   *  · belirsiz                 → önceki niyetin sonucu yazılamamıştı; olay, durum değişmez (EN AZ BİR KEZ teslim: yeniden iletilir)
   *  · teslim/goruldu           → yalnız olay (durum değişmez; görüldü/işlendi alıcının işi)
   * Kapalı mesaja yazılmaz. 'iletildi' = satıra yazıldı; alıcı onayı = alıcının `posta gordum`u.
   */
  function iletim(id, kim, sonuc, ayrinti, now) {
    if (!['iletildi', 'iletilemedi', 'basladi', 'belirsiz'].includes(sonuc)) return hata('sonuc_gecersiz', "sonuc 'basladi', 'belirsiz', 'iletildi' ya da 'iletilemedi' olmalı", 422);
    return islem(() => {
      const m = mesajBul(id);
      if (!m) return hata('mesaj_yok', `${id} yok`, 404);
      if (KAPALI.includes(m.durum)) return hata('durum_kapali', `mesaj zaten ${m.durum}`, 409);
      const det = String(ayrinti ?? '').slice(0, 200);
      // 'basladi' = niyet olayı: sokete YAZMADAN önce düşer (iz olmadan teslim olmasın); durum değişmez.
      if (sonuc === 'basladi') { olay(id, now, 'iletim_basladi', kim, det); return { ok: true, mesaj: goster(m, now) }; }
      // 'belirsiz' = önceki niyetin sonucu yazılamamıştı: teslim SAYILMAZ, olay düşer, mesaj yeniden iletilir (en az bir kez teslim).
      if (sonuc === 'belirsiz') { olay(id, now, 'iletim_belirsiz', kim, det); return { ok: true, mesaj: goster(m, now) }; }
      if (m.durum === 'gonderildi') {
        const deneme = m.deneme + 1;
        if (sonuc === 'iletildi') {
          calis(`UPDATE mesaj SET durum='teslim', deneme=?, teslim_ts=COALESCE(teslim_ts, ?), kira_bitis=? WHERE id=?`, deneme, now, now + KIRA_TESLIM_MS, id);
          olay(id, now, 'teslim', kim, `deneme ${deneme}/${MAX_DENEME} · soket`);
          olay(id, now, 'iletildi', kim, det);
        } else if (deneme >= MAX_DENEME) {
          calis(`UPDATE mesaj SET durum='olu', deneme=?, kira_bitis=NULL WHERE id=?`, deneme, id);
          olay(id, now, 'iletilemedi', kim, det);
          olay(id, now, 'olu', 'postane', `${MAX_DENEME} soket denemesi başarısız`);
        } else {
          calis(`UPDATE mesaj SET deneme=? WHERE id=?`, deneme, id);
          olay(id, now, 'iletilemedi', kim, `deneme ${deneme}/${MAX_DENEME} · ${det}`.slice(0, 200));
        }
      } else {
        olay(id, now, sonuc, kim, det);
      }
      return { ok: true, mesaj: goster(mesajBul(id), now) };
    });
  }

  /** İşlendi, ya da gerekçeli reddedildi. Kapalı mesaja aynı sonuçla tekrar → idempotent; başka sonuçla → 409. */
  function isle(id, kim, { reddet = null } = {}, now) {
    const ret = reddet !== null;
    if (ret && (typeof reddet !== 'string' || !reddet.trim())) return hata('gerekce_yok', 'reddetmek için gerekçe şart');
    const sonuc = ret ? 'reddedildi' : 'islendi';
    return islem(() => {
      const m = mesajBul(id);
      if (!m) return hata('mesaj_yok', `${id} yok`, 404);
      if (m.durum === sonuc) return { ok: true, tekrar: true, mesaj: goster(m, now) };
      if (KAPALI.includes(m.durum)) return hata('durum_kapali', `mesaj zaten ${m.durum}`, 409);
      // Zincir atlanmaz: işlendi de reddedildi de YALNIZ görüldü durumundan gelir (teslim → görüldü → karar).
      if (m.durum !== 'goruldu') {
        return hata('durum_sirasi', `mesaj '${m.durum}' durumunda: ${m.durum === 'gonderildi' ? 'önce posta al, sonra posta gordum' : 'önce posta gordum'} gerekir`, 409);
      }
      calis(`UPDATE mesaj SET durum=?, islendi_ts=?, goruldu_ts=COALESCE(goruldu_ts, ?), gerekce=?, kira_bitis=NULL WHERE id=?`,
        sonuc, now, now, ret ? reddet.trim() : null, id);
      olay(id, now, sonuc, kim, ret ? reddet.trim() : '');
      return { ok: true, tekrar: false, mesaj: goster(mesajBul(id), now) };
    });
  }

  /** Okuma (durum değiştirmez): bir ajanın açık kutusu, en yakın son tarih üstte. */
  function kutuListe(kime, { durum = null, limit = 50 } = {}, now) {
    const alici = adlar.coz(kime);
    if (!alici) return hata('alici_bilinmiyor', `'${kime}' ajan listesinde yok`, 422);
    const n = Math.min(Math.max(Number.isInteger(limit) ? limit : 50, 1), 200);
    const satirlar = durum
      ? sec('SELECT * FROM mesaj WHERE kime=? AND durum=? ORDER BY son_tarih ASC, id ASC LIMIT ?', alici, durum, n)
      : sec(`SELECT * FROM mesaj WHERE kime=? AND durum IN ('gonderildi','teslim','goruldu') ORDER BY son_tarih ASC, id ASC LIMIT ?`, alici, n);
    return { ok: true, kime: alici, mesajlar: satirlar.map((m) => goster(m, now)) };
  }

  /** Alıcının açık kutusunun özeti: kaç mesaj, en yakın son tarih. Kanca "N mesaj var, en yakını X dk" satırını buradan kurar. */
  function ozet(kime, now) {
    const alici = adlar.coz(kime);
    if (!alici) return hata('alici_bilinmiyor', `'${kime}' ajan listesinde yok`, 422);
    const satir = bir(`SELECT COUNT(*) AS n, MIN(son_tarih) AS en_yakin,
        SUM(CASE WHEN aciliyet='jet' THEN 1 ELSE 0 END) AS jet,
        SUM(CASE WHEN son_tarih < ? THEN 1 ELSE 0 END) AS geciken
      FROM mesaj WHERE kime=? AND durum IN ('gonderildi','teslim','goruldu')`, now, alici);
    return { ok: true, kime: alici, acik: satir.n, jet: satir.jet ?? 0, geciken: satir.geciken ?? 0,
      en_yakin_ms: satir.en_yakin === null ? null : satir.en_yakin - now };
  }

  function mesaj(id, now) {
    const m = mesajBul(id);
    if (!m) return hata('mesaj_yok', `${id} yok`, 404);
    return { ok: true, mesaj: goster(m, now), olaylar: sec('SELECT ts, tur, kim, ayrinti FROM olay WHERE mesaj_id=? ORDER BY sira', id) };
  }

  function geciken(now, { limit = 100 } = {}) {
    supur(now);
    const satirlar = sec(`SELECT * FROM mesaj WHERE durum IN ('gonderildi','teslim','goruldu') AND son_tarih < ? ORDER BY son_tarih ASC LIMIT ?`, now, limit);
    return { ok: true, mesajlar: satirlar.map((m) => goster(m, now)) };
  }

  /** SERDAR (merkez) ölü mektubu gerekçeyle kapatır: durum arsiv, olay 'olu_kapandi'. Yalnız 'olu' durumundaki mesaj (…1SSZVC: alici_degil ile kapatamıyordu). */
  function oluKapat(id, kim, neden, now) {
    if (typeof id !== 'string' || !id) return hata('id_gerekli', 'mesaj kimliği gerekli');
    if (typeof kim !== 'string' || !kim.trim()) return hata('kim_gerekli', 'kapatan ad gerekli');
    if (typeof neden !== 'string' || neden.trim().length < 5) return hata('neden_gerekli', 'kapatma nedeni en az 5 karakter');
    return islem(() => {
      const m = bir('SELECT * FROM mesaj WHERE id=?', id);
      if (!m) return hata('mesaj_yok', 'böyle bir mesaj yok', 404);
      if (m.durum !== 'olu') return hata('olu_degil', `mesaj ölü değil (${m.durum}) — yalnız ölü mektup kapatılır`, 409);
      calis(`UPDATE mesaj SET durum='arsiv', gerekce=? WHERE id=?`, neden.trim(), id);
      olay(id, now, 'olu_kapandi', kim.trim(), neden.trim());
      return { ok: true, mesaj: goster(bir('SELECT * FROM mesaj WHERE id=?', id), now) };
    });
  }

  function olu(now, { limit = 100 } = {}) {
    supur(now);
    return { ok: true, mesajlar: sec(`SELECT * FROM mesaj WHERE durum='olu' ORDER BY olusturma DESC LIMIT ?`, limit).map((m) => goster(m, now)) };
  }

  // 'olu' = ölü mektubun ALICIYA zili (mesaj başına) · 'olu_serdar' = SERDAR'a giden TOPLU zil (tur başına tek satır; bu kayıt yalnız o mesajın dahil edildiğini tutar).
  const ZIL_NEDEN = Object.freeze(['geciken', 'olu', 'olu_serdar']);
  const ZIL_AZAMI_DENEME = 3;

  /**
   * Sonuçsuz çalma hakkı var mı: son 'zil_basladi'den sonra sonuç ('zil' / 'zil_gidemedi') yok. SÜRESİZ: "bir kez" güvencesi için
   * hak alınıp sonuç yazılamamış zil bir daha çalınmaz (zil dışarıda gitmiş olabilir; mükerrer zil, eksik zilden kötüdür — mesaj
   * `posta geciken` / `posta olu` ile görünür kalır ve liste `belirsiz` olarak bildirir).
   */
  function aktifTalep(id, neden) {
    const b = bir(`SELECT sira FROM olay WHERE mesaj_id=? AND tur='zil_basladi' AND ayrinti=? ORDER BY sira DESC LIMIT 1`, id, neden);
    if (!b) return false;
    return bir(`SELECT COUNT(*) AS n FROM olay WHERE mesaj_id=? AND tur IN ('zil','zil_gidemedi') AND ayrinti=? AND sira>?`, id, neden, b.sira).n === 0;
  }

  /**
   * Zil bekleyenler: son tarihi geçmiş açık mesaj (neden 'geciken') ya da ölü mektup (neden 'olu'); her (mesaj, neden) için zil
   * yazılmamış olanlar. İçerik ve konu DÖNMEZ (zil yalnız "şu mesaj gecikti" der). 3 başarısız zil denemesinden sonra liste dışı kalır
   * (sonsuz döngü yok; mesaj `posta geciken`/`posta olu` ile görünür kalır).
   */
  function zilBekleyen(now, { limit = 100 } = {}) {
    supur(now);
    const n = Math.min(Math.max(Number.isInteger(limit) ? limit : 100, 1), 500);
    const aday = [
      ...sec(`SELECT id, kimden, kime, aciliyet, son_tarih, 'geciken' AS neden FROM mesaj WHERE durum IN ('gonderildi','teslim','goruldu') AND son_tarih < ?`, now),
      ...sec(`SELECT id, kimden, kime, aciliyet, son_tarih, 'olu' AS neden FROM mesaj WHERE durum='olu'`),
      // SERDAR'a toplu zil: rahat (genis) mektup ve kendine yazılmış mektup (cron öz-mektubu) ölünce çalmaz — alıcının zili ('olu') kalır (…1SSZVC).
      ...sec(`SELECT id, kimden, kime, aciliyet, son_tarih, 'olu_serdar' AS neden FROM mesaj WHERE durum='olu' AND aciliyet<>'genis' AND kimden<>kime`),
    ];
    const say = (id, tur, neden) => bir('SELECT COUNT(*) AS n FROM olay WHERE mesaj_id=? AND tur=? AND ayrinti=?', id, tur, neden).n;
    const bekleyen = aday
      .filter((m) => say(m.id, 'zil', m.neden) === 0 && say(m.id, 'zil_gidemedi', m.neden) < ZIL_AZAMI_DENEME && !aktifTalep(m.id, m.neden))
      .sort((a, b) => a.son_tarih - b.son_tarih || (a.id < b.id ? -1 : 1))
      .slice(0, n)
      .map((m) => ({ ...m, gecikme_ms: now - m.son_tarih }));
    // Belirsiz: hak alınmış ama sonucu yazılmamış zil — tekrar çalınmaz; zilci bunu raporlar.
    const belirsiz = aday.filter((m) => say(m.id, 'zil', m.neden) === 0 && aktifTalep(m.id, m.neden)).map((m) => ({ id: m.id, neden: m.neden, kime: m.kime }));
    return { ok: true, bekleyen, belirsiz };
  }

  /** Zil sonucunu yazar: 'gitti' → bu (mesaj, neden) için bir daha zil çalmaz; 'gidemedi' → sayılır, 3'te vazgeçilir. */
  function zilYaz(id, neden, kim, sonuc, ayrinti, now) {
    if (!ZIL_NEDEN.includes(neden)) return hata('neden_gecersiz', "neden 'geciken', 'olu' ya da 'olu_serdar' olmalı", 422);
    if (!['basladi', 'gitti', 'gidemedi'].includes(sonuc)) return hata('sonuc_gecersiz', "sonuc 'basladi', 'gitti' ya da 'gidemedi' olmalı", 422);
    return islem(() => {
      const m = mesajBul(id);
      if (!m) return hata('mesaj_yok', `${id} yok`, 404);
      // Zil gerçekten gerekli bir durumda yazılır: geciken → mesaj hâlâ açık ve vadesi geçmiş (ya da sonradan ölmüş); olu → ölü mektup.
      const gecerli = neden !== 'geciken' ? m.durum === 'olu' : (ACIK.includes(m.durum) && m.son_tarih < now) || m.durum === 'olu' || m.gecikti_ts !== null;
      if (!gecerli) return hata('zil_gereksiz', `mesaj '${m.durum}' durumunda: '${neden}' zili gerekmez`, 409);
      const det = String(ayrinti ?? '').slice(0, 200);
      const gitmis = bir('SELECT COUNT(*) AS n FROM olay WHERE mesaj_id=? AND tur=? AND ayrinti=?', id, 'zil', neden).n > 0;
      // 'basladi' = zili ÇALMA HAKKI: çalmadan ÖNCE, tek işlemde alınır → eşzamanlı iki tur ya da sonuç yazılamayan tur aynı zili iki kez çalamaz.
      if (sonuc === 'basladi') {
        if (gitmis || aktifTalep(id, neden) || bir('SELECT COUNT(*) AS n FROM olay WHERE mesaj_id=? AND tur=? AND ayrinti=?', id, 'zil_gidemedi', neden).n >= ZIL_AZAMI_DENEME) return { ok: true, alindi: false, mesaj: goster(m, now) };
        olay(id, now, 'zil_basladi', kim, neden);
        return { ok: true, alindi: true, mesaj: goster(mesajBul(id), now) };
      }
      if (sonuc === 'gitti' && gitmis) return { ok: true, tekrar: true, mesaj: goster(m, now) };
      olay(id, now, sonuc === 'gitti' ? 'zil' : 'zil_gidemedi', kim, neden);
      if (det && sonuc === 'gidemedi') olay(id, now, 'zil_neden', kim, det);
      return { ok: true, tekrar: false, mesaj: goster(mesajBul(id), now) };
    });
  }

  function say(now) {
    supur(now);
    const gruplar = sec('SELECT durum, aciliyet, COUNT(*) AS n FROM mesaj GROUP BY durum, aciliyet ORDER BY durum, aciliyet');
    const toplam = bir('SELECT COUNT(*) AS n FROM mesaj').n;
    return { ok: true, toplam, gruplar };
  }

  /** WAL'ı ana dosyaya işler: yedek (dizin kopyası) en çok bir kontrol aralığı kadar geriden gelir, -wal dosyası şişmez. */
  const kontrol = () => { const r = bir('PRAGMA wal_checkpoint(TRUNCATE)'); return { ok: r.busy === 0, ...r }; };

  return { kontrol, supur, gonder, al, gordum, isle, iletim, kutuListe, ozet, mesaj, geciken, olu, oluKapat, zilBekleyen, zilYaz, say, adlar, kapat: () => db.close() };
}

export { tekYazim };
