// DXF renderer — @tarikjabiri/dxf ile. AIA katman adları. Birim: cm (INSUNITS=5).
// Geometri fail-closed kapıdan geçmiş modeldir; DIMENSION ek açıklaması başarısız olursa
// uyarı verilir ama geometri çıktısı geçerli kalır (ölçek bütünlüğü geometridedir).
import { DxfWriter, Units, point3d, Colors } from '@tarikjabiri/dxf';
import { uzunluk, agirlikMerkezi, alanM2, bbox, duvarNoktasi } from './geometri.mjs';

const KATMAN = {
  duvar: 'A-WALL', kapi: 'A-DOOR', pencere: 'A-GLAZ',
  etiket: 'A-AREA-IDEN', olcu: 'A-ANNO-DIMS',
};

export function dxfUret(model) {
  const dxf = new DxfWriter();
  dxf.setUnits(Units.Centimeters);
  dxf.addLayer(KATMAN.duvar, Colors.White);
  dxf.addLayer(KATMAN.kapi, Colors.Red);
  dxf.addLayer(KATMAN.pencere, Colors.Cyan);
  dxf.addLayer(KATMAN.etiket, Colors.Green);
  dxf.addLayer(KATMAN.olcu, Colors.Yellow);

  const noktalar = model.noktalar;
  // DXF'te y yukarı artar; model ekran-düzeninde (y aşağı) → y'yi aynala
  const Y = (y) => -y;

  const uyarilar = [];

  // duvarlar: merkez hattı LWPOLYLINE, sabit genişlik = kalinlik
  dxf.setCurrentLayerName(KATMAN.duvar);
  for (const d of model.duvarlar ?? []) {
    const a = noktalar[d.bas], b = noktalar[d.son];
    try {
      dxf.addLWPolyline(
        [
          { point: point3d(a[0], Y(a[1]), 0), startingWidth: d.kalinlik, endingWidth: d.kalinlik },
          { point: point3d(b[0], Y(b[1]), 0) },
        ],
        {}
      );
    } catch {
      dxf.addLine(point3d(a[0], Y(a[1]), 0), point3d(b[0], Y(b[1]), 0));
      uyarilar.push(`duvar ${d.id}: genişlikli polyline yazılamadı, çizgiye düşüldü`);
    }
  }

  // açıklıklar
  for (const ac of model.acikliklar ?? []) {
    const d = (model.duvarlar ?? []).find((x) => x.id === ac.duvar);
    if (!d) continue;
    const A = noktalar[d.bas], B = noktalar[d.son];
    const { nokta: merkez, u } = duvarNoktasi(A, B, ac.oran);
    const g = ac.genislik;
    const p1 = [merkez[0] - u[0] * g / 2, merkez[1] - u[1] * g / 2];
    const p2 = [merkez[0] + u[0] * g / 2, merkez[1] + u[1] * g / 2];
    dxf.setCurrentLayerName(ac.tip === 'pencere' ? KATMAN.pencere : KATMAN.kapi);
    dxf.addLine(point3d(p1[0], Y(p1[1]), 0), point3d(p2[0], Y(p2[1]), 0));
    if (ac.tip === 'kapi') {
      const yon = ac.aci_yonu === -1 ? -1 : 1;
      const n = [-u[1] * yon, u[0] * yon];
      const uc = [p1[0] + n[0] * g, p1[1] + n[1] * g];
      dxf.addLine(point3d(p1[0], Y(p1[1]), 0), point3d(uc[0], Y(uc[1]), 0));
      try {
        const bas = Math.atan2(Y(p2[1]) - Y(p1[1]), p2[0] - p1[0]) * 180 / Math.PI;
        const son = Math.atan2(Y(uc[1]) - Y(p1[1]), uc[0] - p1[0]) * 180 / Math.PI;
        // DXF yayı DAİMA saat-yönü-tersine bas→son süpürülür; ±180° dalında min/max
        // 270°'lik büyük yayı çizer. Küçük (90°) yayı veren yönü seç:
        const fark = (son - bas + 360) % 360;
        if (fark <= 180) dxf.addArc(point3d(p1[0], Y(p1[1]), 0), g, bas, son);
        else dxf.addArc(point3d(p1[0], Y(p1[1]), 0), g, son, bas);
      } catch {
        uyarilar.push(`kapı ${ac.id}: yay yazılamadı`);
      }
    }
  }

  // oda etiketleri
  dxf.setCurrentLayerName(KATMAN.etiket);
  for (const o of model.odalar ?? []) {
    const koseler = o.dongu.map((nid) => noktalar[nid]);
    const [cx, cy] = agirlikMerkezi(koseler);
    const m2 = alanM2(koseler);
    dxf.addText(point3d(cx, Y(cy), 0), 22, `${o.ad ?? o.id} ${m2.toFixed(1)} m2${o.guven === 'dusuk' ? ' [SAHA OLCUMU BEKLIYOR]' : ''}`);
  }

  // genel ölçü çizgileri (bbox) — başarısızlık geometriyi düşürmez
  try {
    const kutu = bbox(Object.values(noktalar));
    dxf.setCurrentLayerName(KATMAN.olcu);
    dxf.addLinearDim(
      point3d(kutu.minX, Y(kutu.maxY), 0),
      point3d(kutu.maxX, Y(kutu.maxY), 0),
      { offset: -80 }
    );
    dxf.addLinearDim(
      point3d(kutu.minX, Y(kutu.maxY), 0),
      point3d(kutu.minX, Y(kutu.minY), 0),
      { offset: -80, angle: 90 }
    );
  } catch (e) {
    uyarilar.push(`genel ölçü çizgisi yazılamadı: ${e.message}`);
  }

  return { icerik: dxf.stringify(), uyarilar };
}
