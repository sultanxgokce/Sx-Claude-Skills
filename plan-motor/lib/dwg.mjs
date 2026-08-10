// DWG yazıcı — @node-projects/acad-ts (MIT) DwgWriter ile. AIA katman adları, birim cm.
//
// ⚠️ Bu paket zaten DWG OKUMAK için kuruluydu; yazma yeteneği (DwgWriter) fark edilmemişti.
// Yeni bağımlılık YOK. Kanıt ve API tuzakları: _agents/spec/DWG-YAZMA-KANIT.md (tellal).
//
// 🔴 API TUZAKLARI (README'si yanlış — ölçülerek çıkarıldı):
//   · new DwgWriter(stream, document)  → belge İKİNCİ argüman
//   · writeToStream STATİKtir, örnek metodu değil
//   · lwPolyline.vertices bir DİZİdir (.push), koleksiyon değil (.add YOK)
//   · ArrayBuffer ÖN-TAHSİS edilir; gerçek uzunluk writer.bytesWritten'dır
//     (kullanılmazsa dolgulu dev dosya yazılır)
import {
  CadDocument, ACadVersion, DwgWriter, Layer, XY, XYZ,
  LwPolyline, LwPolylineVertex, Line, Arc, TextEntity, Circle,
  TextStyle, Hatch, HatchPattern, HatchPatternLine, Color,
  HatchBoundaryPath, HatchBoundaryPathPolyline,
} from '@node-projects/acad-ts';
import { duvarNoktasi, agirlikMerkezi, alanM2 } from './geometri.mjs';
import { duvarGovdesi } from './duvar-govde.mjs';

// Katman şeması AIA (`A-*`). Referans çizim `px_*` kullanıyor ama o bir ÜRETİCİ İMZASI,
// mimarlık kanonu değil — kopyalanmadı. Referanstan alınan şey katman ADLARI değil,
// katman ROLLERİ: taramanın ayrı katmanda olması (mimar taramayı kapatıp çalışır).
// Ölçüm: tellal/_agents/spec/REFERANS-CIZIM-ANALIZI.md §7
const KATMAN = {
  duvar: 'A-WALL', duvarTarama: 'A-WALL-PATT', kapi: 'A-DOOR', pencere: 'A-GLAZ',
  etiket: 'A-AREA-IDEN', mobilya: 'A-FURN',
};

// Kalem (lineWeight) 1/100 mm. Referansta ölçülen kural: kalem VARLIKTA değil KATMANDA yaşar
// (168 varlığın hepsi ByLayer). Açıklıklar 0.09 mm ince, duvar varsayılan.
// -3 = varsayılan (ByLayer'ın kendisi değil, "Default" kalem).
const KATMAN_KALEM = {
  duvar: 50, duvarTarama: 9, kapi: 9, pencere: 9, etiket: -3, mobilya: 18,
};
// AutoCAD indeks renkleri (255-renk paleti).
const KATMAN_RENK = {
  duvar: 7, duvarTarama: 8, kapi: 4, pencere: 5, etiket: 2, mobilya: 3,
};

// DWG çıktısı AC1027 (AutoCAD 2013). AC1021 acad-ts'in yazma matrisinde YOK.

// 🔴 TÜRKÇE — BEŞ YOL DENENDİ, DÖRDÜ ELENDİ (AutoCAD 2027'de Sultan ölçtü, 2026-08-07)
//
//   1) ham UTF-8 + codePage ANSI_1252  → "Odas?"            ELENDİ
//   2) \U+XXXX kaçışı + düz TEXT       → "Odas\U+0131"      ELENDİ (harfiyen basıldı)
//   3) ham + codePage ANSI_1254        → "Odas?"            ELENDİ (kod sayfası çözüm değil)
//   4) MTEXT (ham VE kaçışlı)          → HİÇ GÖRÜNMEDİ      ELENDİ (ayrı kusur: acad-ts MText
//                                                            yazıyor ama AutoCAD render etmiyor)
//   5) HARF ÇEVİRİSİ                   → "Odasi"            geçici çare (ARTIK GEREKMİYOR)
//   6) TEXT + TrueType stil (Arial)    → "GİYİNME ODASI ş ı ğ Ü Ç ö"   ✅✅ KALICI ÇÖZÜM
//
// Neden `?` çıkıyor: AutoCAD'in varsayılan SHX fontunda (txt.shx) Türkçe glifleri YOK.
// `Ç` ve `â` düzgün çıkıyor çünkü onlar Latin-1'de ve fontta var. Yani sorun kodlama DEĞİL, FONT.
//
// ✅ ÇÖZÜLDÜ (2026-08-07, AutoCAD 2027'de Sultan GÖZLE doğruladı — TESHIS-2 şerit A):
// `Standard` metin stiline `Arial.ttf` (TrueType) yazılınca düz TEXT ham Türkçeyi
// KUSURSUZ gösteriyor: "A) GİYİNME ODASI — ş ı ğ Ü Ç ö". Harf çevirisi KALDIRILDI.
//
// Teşhis referans çizimden gelmişti: Sultan'ın `ss/ornekcizim.dwg` dosyası da Standard'da
// Arial.ttf taşıyor ve `DUŞ` · `GİYİNME ODASI` · `Buzdolabı` yazılarını sorunsuz gösteriyor.
//
// ⚠️ MTEXT hâlâ ELENMİŞ durumda: şerit B ve C AutoCAD'de HİÇ görünmedi (ham da, font-kodlu
// da). Referansın MText'leri düzgün göründüğüne göre kusur MText'te değil bizim yazışımızda.
// Çok satırlı metin gerekirse MText'e GÜVENME — çözülene kadar düz TEXT kullan.
export const TURKCE_SADELESTIRILDI = false;

// Metin artık DOKUNULMADAN yazılır. Fonksiyon, çağrı yerlerini bozmamak ve kod sayfası
// tekrar sorun çıkarırsa tek noktadan müdahale edebilmek için duruyor.
function cadMetin(s) {
  return String(s ?? '');
}

// Metni odaya SIĞDIR. plan-dekor'da bu çözülmüştü ama DWG yazıcısına taşınmamıştı —
// AutoCAD'de oda etiketleri komşu odaya taşıp mobilya adlarına bindi.
// DWG'de tek satır metin kullanıyoruz; sığdırma = punto küçültme (sarma yok).
function puntoSigdir(metin, genislikCm, tavan) {
  // AutoCAD SHX tek-aralıklı yaklaşık: karakter genişliği ≈ punto × 0.72
  const gerekli = metin.length * 0.72;
  const sigan = (genislikCm * 0.88) / Math.max(1, gerekli / 1);
  return Math.max(6, Math.min(tavan, sigan));
}

const SURUM = ACadVersion.AC1027;

// Duvar dolgusu (poché) varsayılanı.
//   'ansi31' — 45° eğik tarama (mimari poché geleneği; referans çizim de bunu kullanıyor).
//              ✅ GÖZLE DOĞRULANDI 2026-08-08 (TESHIS-4, üç aralıkta da temiz eğik çizgi).
//   'solid'  — KATI dolgu. Doğrulandı (TESHIS-2 şerit E) — alternatif olarak duruyor.
//   'yok'    — dolgu yazma.
//
// 🔴 SIKLIK, DESEN ÇİZGİSİNİN OFSETİNE GÖMÜLÜR — `_patternScale` alanına DEĞİL.
// İki tur ölçümle bulundu: TESHIS-3'te ölçek 1/5/25 ve açı varyantlarının BEŞİ DE düz beyaz
// çıktı. Sultan taramayı AutoCAD'de elle düzenleyince (ölçek 5→4) eğik çizgiler ANINDA belirdi.
// Teşhis: AutoCAD dosya AÇILIRKEN saklı desen tanımından çizer; `_patternScale` yalnız
// KULLANICI düzenleyince acad.pat'tan yeniden üretmek için kullanılır. Yani yanlış olan
// saklı tanımdı. Ofsete gömülünce TESHIS-4'te üç aralık da doğru çıktı.
const TARAMA_VARSAYILAN = 'ansi31';
// ANSI31 dik çizgi aralığı, CM. Ölçek alanına değil ofsete gömülür (yukarıdaki nota bak).
// 25 cm'lik duvarda ~8 çizgi verir. Bu GÖRSEL bir tercihtir, ölçülmüş kural değil.
const TARAMA_ARALIK_CM = 3;

// Pencere cam çizgileri arası mesafe, CM. ÖLÇÜLDÜ: `ss/ornekcizim.dwg` px_openings
// katmanındaki 10 çizgi çiftinin HEPSİ 3.0 cm aralıklı (bkz. açıklık döngüsündeki not).
const CAM_ARALIK_CM = 3;

// Ön-tahsis tavanı. Aşılırsa fail-closed: sessizce kırpılmış dosya YAZILMAZ.
const TAMPON_BAYT = 32 * 1024 * 1024;

export function dwgUret(model, { yerlesimler = [], tarama } = {}) {
  const taramaModu = tarama ?? TARAMA_VARSAYILAN;
  if (!["solid", "ansi31", "yok"].includes(taramaModu)) {
    throw new Error(`bilinmeyen tarama modu "${taramaModu}" — solid|ansi31|yok`);
  }
  const doc = new CadDocument();
  doc.header.version = SURUM;
  // ⚠️ `uyarilar` EN BAŞTA tanımlanır: aşağıdaki catch blokları ona yazıyor. Eskiden bildirim
  // daha aşağıdaydı ve codePage catch'i tetiklenseydi TDZ hatası verecekti (gizli kusur).
  const uyarilar = [];

  // INSUNITS = 5 (santimetre). Ölçek beyanı DWG'ye de işlenmeli — yoksa plan-motor'un
  // ölçek disiplini DWG kolunda kopar ve dosya "birimsiz" açılır.
  try { doc.header.insUnits = 5; } catch { /* alan yoksa aşağıda uyarı düşer */ }

  // 🔴 TÜRKÇE KOD SAYFASI (2026-08-07, AutoCAD'de ölçülerek bulundu).
  // acad-ts varsayılanı ANSI_1252 (Latin-1) — Türkçeye özel ş ı ğ İ Ş Ğ o kümede YOK,
  // AutoCAD onları "?" gösteriyordu. ANSI_1254 = Türkçe kod sayfası.
  // (İlk düzeltme denemesi \U+XXXX kaçışıydı; AutoCAD düz TEXT'te onu ÇÖZMEDİ,
  //  harfiyen "Odas\U+0131" bastı — yani kaçış yolu ÖLÇÜLDÜ ve ELENDİ.)
  try { doc.header.codePage = 'ANSI_1254'; } catch { uyarilar.push('kod sayfası ayarlanamadı'); }

  // 🔴 METİN STİLİ — TrueType (referans çizimden öğrenildi, 2026-08-07).
  // Referansın `Standard` stili `Arial.ttf` taşıyor ve ham Türkçeyi (DUŞ · GİYİNME · Buzdolabı)
  // sorunsuz gösteriyor. Bizim "?" sorunumuzun sebebi kodlama değil FONT'tu: AutoCAD'in
  // varsayılan txt.shx fontunda Türkçe glifleri yok.
  // Arial STANDARD stiline yazılır — Standard varsayılandır, stil atanmamış varlık da doğru
  // fontu alır (referansın yaptığı da bu; ayrı stil yaratmaktan daha sağlam).
  try {
    let std = [...doc.textStyles].find((s) => s.name === 'Standard');
    if (!std) { std = new TextStyle('Standard'); doc.textStyles.add(std); }
    std.filename = 'Arial.ttf';
    std.trueType = true;
  } catch (e) { uyarilar.push(`metin stili ayarlanamadı: ${e.message}`); }

  const katmanlar = {};
  for (const [anahtar, ad] of Object.entries(KATMAN)) {
    const k = new Layer(ad);
    try { k.lineWeight = KATMAN_KALEM[anahtar] ?? -3; } catch { /* kalem ikincil */ }
    // ⚠️ Renk `new Color(idx)` İSTER. Düz `{_color: n}` nesnesi atamak hata VERMEZ ama
    // hiçbir şey de yapmaz — tüm katmanlar aynı yanlış değerle geri okunuyordu (ölçüldü).
    // Sessiz başarısızlık; geri-okuma olmasa fark edilmezdi.
    try { if (KATMAN_RENK[anahtar] != null) k.color = new Color(KATMAN_RENK[anahtar]); } catch (e) { uyarilar.push(`katman ${ad}: renk atanamadı (${e.message})`); }
    doc.layers.add(k);
    katmanlar[anahtar] = k;
  }

  const noktalar = model.noktalar;
  // DXF/DWG'de y YUKARI artar; model ekran düzeninde (y aşağı) → aynala. dxf.mjs ile aynı kural.
  const Y = (y) => -y;
  const sayac = { duvar: 0, kapi: 0, pencere: 0, gecis: 0, etiket: 0, mobilya: 0, tarama: 0 };

  const ekle = (ent, katman) => { ent.layer = katman; doc.entities.add(ent); };

  // ---- duvarlar: BİRLEŞİK GÖVDE KONTURU (+ tarama) ----
  //
  // 🔴 STRATEJİ DEĞİŞİKLİĞİ (2026-08-07). Önceden her duvar "kalın genişlikli merkez hattı"
  // olarak yazılıyordu. Kalın polyline'ın ucu düz kesiktir → iki duvar köşede buluşunca
  // dışarıda çentik, içeride bindirme kalıyordu (Sultan: "kenar birleşimleri kötü duruyor").
  // Artık duvar ağının BİRLEŞİK konturu yazılıyor — referans çizimin tekniği.
  // Model DOKUNULMADI: ölçü hâlâ merkez hatlarında yaşıyor, değişen yalnız çizim.
  const { halkalar: govde, dikdortgenler: govdeParcalari, uyarilar: govdeUyari } = duvarGovdesi(model);
  uyarilar.push(...govdeUyari);

  const halkaPolyline = (halka) => {
    const pl = new LwPolyline();
    pl.isClosed = true;
    for (const [x, y] of halka) {
      const v = new LwPolylineVertex();
      v.location = new XY(x, Y(y));   // genişlik YOK — kontur ince çizgi, kalem katmandan gelir
      pl.vertices.push(v);
    }
    return pl;
  };

  for (const p of govde) {
    ekle(halkaPolyline(p.dis), katmanlar.duvar);
    sayac.duvar++;
    for (const delik of p.delikler) { ekle(halkaPolyline(delik), katmanlar.duvar); sayac.duvar++; }
  }

  // ---- duvar DOLGUSU (poché) ----
  //
  // 🔴 ADA (island) YOLU ELENDİ — AutoCAD'de ölçüldü 2026-08-07. Delikli tek tarama sınırı
  // yazdım (dış halka + oda delikleri); AutoCAD delikleri ADA olarak TANIMADI ve taramayı
  // BÜTÜN DAİREYE yaydı. Sultan ekranda gördü, "gariplik var" deyip sildi.
  // Referans çizim de ada bayrağı kullanmıyor: duvar gövdesini ayrı BASİT bölgelere ayırmış.
  //
  // Bu yüzden dolgu, birleşik halkalardan DEĞİL, tek tek duvar DİKDÖRTGENLERİNDEN çiziliyor.
  // Her dolgu tek dış sınırlı basit bir bölge → ada anlambilimine hiç girilmiyor.
  // Köşelerde dikdörtgenler bindirir; KATI dolguda bu görünmez. Kontur yine birleşik
  // halkadan geliyor, dolayısıyla köşeler temiz kalmaya devam ediyor.
  if (taramaModu !== 'yok') {
    const kati = taramaModu === 'solid';
    for (const dikdortgen of govdeParcalari) {
      try {
        const h = new Hatch();
        h.isAssociative = false;   // sınırı BİZ veriyoruz; AutoCAD'in sınır-hesabına gerek yok
        h.isDouble = false;
        h.style = 0;               // normal
        if (kati) {
          h.isSolid = true;
          h.patternType = 0;
          h.pattern = HatchPattern.solid ?? new HatchPattern('SOLID');
        } else {
          h.isSolid = false;
          h.patternType = 1;
          // 🔴 ÖLÇEK, DESEN ÇİZGİSİNİN OFSETİNE GÖMÜLÜR — `_patternScale` alanına DEĞİL.
          // Ölçüldü (TESHIS-3, AutoCAD 2027, 2026-08-08): ölçek 1/5/25 ve açı varyantlarının
          // BEŞİ DE düz beyaz çıktı. Sebep: AutoCAD sıklığı desen çizgisinin ofsetinden okur;
          // `_patternScale` yalnız diyalog için taşınan bir meta-alandır. Ofset sabit kalınca
          // sıklık her varyantta 0.125 cm oldu — santimetre biriminde katı dolgu gibi görünür.
          const desen = new HatchPattern('ANSI31');
          const cizgi = new HatchPatternLine();
          cizgi.angle = Math.PI / 4;
          cizgi.basePoint = new XY(0, 0);
          // Dik aralık = TARAMA_ARALIK_CM; ofset o aralığın 45°'ye dik bileşenidir.
          const k = TARAMA_ARALIK_CM * Math.SQRT1_2;
          cizgi.offset = new XY(-k, k);
          cizgi.dashLengths = [];
          desen.lines.push(cizgi);
          h.pattern = desen;
          h._patternScale = 1;   // ofset zaten gerçek ölçekte — burada 1 kalmalı, yoksa çift uygulanır
          h._patternAngle = 0;
        }
        const yol = new HatchBoundaryPath();
        yol._flags = 7;            // 1 dış + 2 polyline + 4 türetilmiş (referansın kullandığı)
        const pl = new HatchBoundaryPathPolyline();
        pl.isClosed = true;
        for (const [x, y] of dikdortgen) pl.vertices.push(new XYZ(x, Y(y), 0));
        yol.edges.push(pl);
        h.paths.push(yol);
        ekle(h, katmanlar.duvarTarama);
        sayac.tarama++;
      } catch (e) {
        // Dolgu İKİNCİLDİR — geometri yazıldı, dolgu düşerse çizim yine doğrudur.
        uyarilar.push(`duvar dolgusu yazılamadı (${e.message}) — kontur yazıldı`);
      }
    }
  }

  // ---- açıklıklar ----
  // 🔴 KANONİK SIRA — varlık sırası çıktının parçasıdır ve deterministik olmalı.
  // Çırak hasadı (2026-08-10) bunu yakaladı: duvar sırası zaten kanonikti ama AÇIKLIK
  // sırası değildi; açıklıkları ters sırayla veren geometrik olarak AYNI model farklı
  // çıktı üretiyordu. Aynı ders daha önce plan-dekor'da ödenmişti (aday üretimi) —
  // orada öğrenilmiş, buraya taşınmamıştı.
  const acikliklarSirali = [...(model.acikliklar ?? [])]
    .sort((a, b) => String(a.id ?? '').localeCompare(String(b.id ?? '')) ||
                    String(a.duvar ?? '').localeCompare(String(b.duvar ?? '')) ||
                    (Number(a.oran) || 0) - (Number(b.oran) || 0));
  for (const ac of acikliklarSirali) {
    const d = (model.duvarlar ?? []).find((x) => x.id === ac.duvar);
    if (!d) { uyarilar.push(`açıklık ${ac.id}: duvar yok`); continue; }
    const A = noktalar[d.bas], B = noktalar[d.son];
    const { nokta: merkez, u } = duvarNoktasi(A, B, ac.oran);
    const g = ac.genislik;
    const p1 = [merkez[0] - u[0] * g / 2, merkez[1] - u[1] * g / 2];
    const p2 = [merkez[0] + u[0] * g / 2, merkez[1] + u[1] * g / 2];
    const katman = ac.tip === 'pencere' ? katmanlar.pencere
      : ac.tip === 'gecis' ? katmanlar.duvar : katmanlar.kapi;

    // Açıklık boyunca, duvar EKSENİNDEN `ofset` kadar kaydırılmış bir çizgi.
    const boyCizgi = (ofset) => {
      const n = [-u[1], u[0]];
      const ln = new Line();
      ln.startPoint = new XYZ(p1[0] + n[0] * ofset, Y(p1[1] + n[1] * ofset), 0);
      ln.endPoint = new XYZ(p2[0] + n[0] * ofset, Y(p2[1] + n[1] * ofset), 0);
      return ln;
    };

    if (ac.tip === 'pencere') {
      // 🔴 PENCERE = DÖRT PARALEL ÇİZGİ (tek eksen çizgisi DEĞİL).
      //
      // Ölçüm (2026-08-10, `ss/ornekcizim.dwg`, `px_openings` katmanı — 50 LwPolyline + 20 Line):
      // referansta pencerelerin ortasında TEK çizgi YOK. Her açıklıkta boyunca uzanan
      // ÇİFT paralel çizgi var (10 çift ölçüldü; her çift birbirine 3.0 cm mesafede,
      // duvar kalınlığının İÇİNDE) + uçlarda 7 cm'lik kapalı dikdörtgen zinciri.
      //   örn. açıklık y1624.0→1678.0 · çizgiler x=483.1 ve x=486.1 (Δ=3.0)
      //   duvar yüzleri aynı yerde x=475.1 ve x=495.1 (kalınlık 20 cm, px_walls'tan ölçüldü)
      // 3.0 cm = ısıcamın plan kalınlığı. 7 cm dikdörtgenler = PVC kasa/kanat profilleri
      // (sürme pencere: iki kanat 7 cm ayrı düzlemde, bu yüzden çizgi çiftleri kaydırılmış).
      //
      // Profil zincirini KOPYALAMIYORUZ: o doğrama detayı, pencere başına bespoke ve
      // modelimizde doğrama verisi YOK (uydurma olurdu). Kopyalanan şey ÖLÇÜLEN KURAL:
      // cam çizgileri duvar kalınlığının İÇİNDE, eksende değil. Buna denizlik olarak iki
      // yüz çizgisi eklenir — açıklık boyunca duvar yüzü sürer (mimari plan geleneği;
      // referansta bu rolü kasa profillerinin dış kenarı üstleniyor).
      //
      // ⚠️ Duvar gövdesi açıklıktan KESİLMEYE devam ediyor (kapı-kesme kapısı bunu ölçer);
      // bu çizgiler kesilen boşluğun İÇİNE yazılır, kesmeyi geri almaz.
      const kalinlik = Number(d.kalinlik);
      const yuz = Number.isFinite(kalinlik) && kalinlik > 0 ? kalinlik / 2 : 0;
      // Cam aralığı: ölçülen 3.0 cm; ince duvarda yüzlere yapışmasın diye kalınlığın 1/3'ü tavan.
      const cam = Math.min(CAM_ARALIK_CM, (yuz * 2) / 3) / 2;
      if (yuz > 0) {
        ekle(boyCizgi(-yuz), katman);   // denizlik / duvar yüzü (dış)
        ekle(boyCizgi(+yuz), katman);   // denizlik / duvar yüzü (iç)
        ekle(boyCizgi(-cam), katman);   // cam
        ekle(boyCizgi(+cam), katman);   // cam
      } else {
        // Kalınlık okunamadı — sessizce eksik çizim yerine eksen çizgisine düş + uyar.
        uyarilar.push(`açıklık ${ac.id}: duvar kalınlığı okunamadı, cam çizgisi yerine eksen çizildi`);
        ekle(boyCizgi(0), katman);
      }
    } else {
      ekle(boyCizgi(0), katman);
    }

    if (ac.tip === 'kapi') {
      // Kapı KANADI + süpürme YAYI — çizimin "kapı" olduğunu anlatan şey budur.
      const yon = ac.aci_yonu === -1 ? -1 : 1;
      const n = [-u[1] * yon, u[0] * yon];
      const uc = [p1[0] + n[0] * g, p1[1] + n[1] * g];

      const kanat = new Line();
      kanat.startPoint = new XYZ(p1[0], Y(p1[1]), 0);
      kanat.endPoint = new XYZ(uc[0], Y(uc[1]), 0);
      ekle(kanat, katmanlar.kapi);

      try {
        const yay = new Arc();
        yay.center = new XYZ(p1[0], Y(p1[1]), 0);
        yay.radius = g;
        // Açılar DWG düzleminde (y aynalanmış) hesaplanır — model açısı doğrudan kullanılamaz.
        const a0 = Math.atan2(Y(p2[1]) - Y(p1[1]), p2[0] - p1[0]);
        const a1 = Math.atan2(Y(uc[1]) - Y(p1[1]), uc[0] - p1[0]);
        const norm = (r) => ((r % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
        let bas = norm(a0), son = norm(a1);
        if (norm(son - bas) > Math.PI) { const t = bas; bas = son; son = t; }
        yay.startAngle = bas;
        yay.endAngle = son;
        ekle(yay, katmanlar.kapi);
      } catch (e) {
        uyarilar.push(`açıklık ${ac.id}: kapı yayı yazılamadı (${e.message})`);
      }
      sayac.kapi++;
    } else if (ac.tip === 'pencere') sayac.pencere++;
    else sayac.gecis++;
  }

  // ---- oda etiketleri (metin) ----
  const odalarSirali = [...(model.odalar ?? [])]
    .sort((a, b) => String(a.id ?? '').localeCompare(String(b.id ?? '')));
  for (const o of odalarSirali) {
    const koseler = o.dongu.map((nid) => noktalar[nid]).filter(Boolean);
    if (koseler.length < 3) continue;
    const [cx, cy] = agirlikMerkezi(koseler);
    const m2 = alanM2(koseler);
    try {
      // Oda genişliği — etiket buna sığdırılır (AutoCAD'de taşıp mobilyaya biniyordu)
      const xs = koseler.map((k) => k[0]);
      const odaGen = Math.max(...xs) - Math.min(...xs);

      const ad = cadMetin(o.ad ?? o.id);
      const alan = `${m2.toFixed(1)} m2`;
      const punto = puntoSigdir(ad, odaGen, Math.max(12, Math.min(26, Math.sqrt(m2) * 5)));

      const t = new TextEntity();
      t.value = ad;
      t.height = punto;
      t.insertPoint = new XYZ(cx - (ad.length * punto * 0.72) / 2, Y(cy) + punto * 0.3, 0);
      ekle(t, katmanlar.etiket);

      // Alan AYRI SATIRDA — tek satırda yan yana yazmak taşmanın ana sebebiydi
      const t2 = new TextEntity();
      t2.value = alan;
      t2.height = punto * 0.8;
      t2.insertPoint = new XYZ(cx - (alan.length * punto * 0.8 * 0.72) / 2, Y(cy) - punto * 0.9, 0);
      ekle(t2, katmanlar.etiket);
      sayac.etiket++;
    } catch (e) {
      uyarilar.push(`oda ${o.id}: etiket yazılamadı (${e.message})`);
    }
  }

  // Oda İÇ sınırları — mobilya etiketini kelepçelemek için. Oda döngüsü duvar MERKEZ
  // hatlarından geçer; iç yüz yarım kalınlık içeridedir. En kalın duvarla hesaplamak
  // muhafazakârdır: dar tarafta biraz fazla içeri çeker, ama duvara asla girmez.
  const yariKalinlik = Math.max(0, ...(model.duvarlar ?? []).map((d) => Number(d.kalinlik) || 0)) / 2;
  const odaIcSiniri = {};
  for (const o of model.odalar ?? []) {
    const koseler = (o.dongu ?? []).map((nid) => noktalar[nid]).filter(Boolean);
    if (koseler.length < 3) continue;
    const xs = koseler.map((c) => c[0]);
    odaIcSiniri[o.id] = { x0: Math.min(...xs) + yariKalinlik, x1: Math.max(...xs) - yariKalinlik };
  }

  // ---- mobilya (plan-dekor yerleşimi verilirse) ----
  // ⚠️ Mobilya BEYAN EDİLEN kutusuyla çizilir — sembol detayı DEĞİL. Sebep: plan-dekor'un
  // değişmezi "çizim, modelin ölçtüğünden fazlasını iddia edemez". DWG'de mimar zaten kendi
  // blok kütüphanesini kullanır; bizim işimiz YERİ ve ÖLÇÜYÜ doğru vermek.
  const yerlesimlerSirali = [...yerlesimler].sort((a, b) =>
    (a.kutu?.x ?? 0) - (b.kutu?.x ?? 0) || (a.kutu?.y ?? 0) - (b.kutu?.y ?? 0) ||
    String(a.ad ?? '').localeCompare(String(b.ad ?? '')));
  for (const y of yerlesimlerSirali) {
    const k = y.kutu;
    if (!k) continue;
    const pl = new LwPolyline();
    pl.isClosed = true;
    for (const [x, yy] of [[k.x, k.y], [k.x + k.g, k.y], [k.x + k.g, k.y + k.d], [k.x, k.y + k.d]]) {
      const v = new LwPolylineVertex();
      v.location = new XY(x, Y(yy));
      pl.vertices.push(v);
    }
    ekle(pl, katmanlar.mobilya);
    sayac.mobilya++;

    try {
      const t = new TextEntity();
      t.value = cadMetin(y.ad ?? y.mobilya ?? '');
      // Mobilya adı KENDİ kutusuna sığsın — taşan ad komşu mobilyanın üstüne biniyordu
      t.height = Math.max(5, Math.min(10, puntoSigdir(t.value, k.g, 10)));

      // 🔴 ETİKET DUVARA GİRMESİN (ölçüldü 2026-08-07: 24 etiketin 9'u duvar gövdesindeydi).
      // Eski hâl: metin kutunun SOL-ALT köşesinden başlıyordu. İki ayrı kaçak üretiyordu:
      //   · x — sol duvara dayalı mobilyada daha ilk harfte duvarın içinde,
      //   · y — alt kenara dayalı mobilyada taban çizgisi YATAY duvarın içinde.
      // İlk düzeltmem yalnız x'i kelepçeledi ve 9 ihlalin 4'ü kaldı (ölçüldü).
      // Doğru çözüm: etiketi kutunun MERKEZİNE koy. Mobilya kutusu zaten odanın içine
      // gömülüdür (yerleştirici kalınlık/2 içeri çeker), dolayısıyla merkez her zaman güvenlidir.
      // x ayrıca odanın İÇ sınırına kelepçelenir — kutudan uzun ad taşmasın diye.
      const genislik = t.value.length * t.height * 0.72;
      let x = k.x + (k.g - genislik) / 2;
      const sinir = odaIcSiniri[y.oda];
      if (sinir) {
        // PAY: tam sınıra oturmak duvar YÜZÜNE değmek demektir (sınır noktası duvar sayılır).
        const pay = 2;
        const alt = sinir.x0 + pay, ust = sinir.x1 - pay - genislik;
        x = ust >= alt ? Math.min(Math.max(x, alt), ust) : alt;
      }
      t.insertPoint = new XYZ(x, Y(k.y + k.d / 2) - t.height / 2, 0);
      ekle(t, katmanlar.mobilya);
    } catch { /* etiket ikincil — geometri korunur */ }
  }

  // ---- yaz ----
  const tampon = new ArrayBuffer(TAMPON_BAYT);
  const w = new DwgWriter(tampon, doc);
  w.write();
  const n = w.bytesWritten;

  // FAIL-CLOSED: tampon dolduysa dosya kırpılmış olurdu — sessizce bozuk DWG yazmaktansa dur.
  if (!(n > 0)) throw new Error('DwgWriter bytesWritten=0 — DWG yazılamadı');
  if (n >= TAMPON_BAYT) {
    throw new Error(`DWG tamponu doldu (${n} ≥ ${TAMPON_BAYT}) — kırpılmış dosya YAZILMADI`);
  }

  const bayt = Buffer.from(tampon.slice(0, n));

  // ÖZ-DENETİM: sihirli bayt. ezdxf gibi bazı kütüphaneler .dwg uzantısıyla kaydedip İÇİNE
  // DXF yazar; uzantıya bakan kapı o yalanı göremez, sihirli bayt görür.
  const sihir = bayt.subarray(0, 6).toString('ascii');
  if (!/^AC10\d\d$/.test(sihir)) {
    throw new Error(`çıktı DWG DEĞİL — sihirli bayt "${sihir}" (beklenen AC10xx)`);
  }

  return { bayt, sihir, sayac, uyarilar };
}
