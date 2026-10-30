#!/usr/bin/env bash
# graf-koprusu.test.sh — LIFTING → MODEL köprüsü kapısı, PAKETİN İÇİNDE.
#
# 🔴 NEDEN VAR: köprü YOKTU. lifting bir oda GRAFI üretiyordu (poligon + mühür), model değil;
# iki pakette de o çıktıyı okuyan tek tüketici bile yoktu. Modeller elle kuruluyor, `acikliklar`
# boş kalıyor ve "kapı önü boş kalsın" kuralı denetleyecek veri bulamadığı için SESSİZCE
# geçiyordu. Gerçek müşteri dosyasında ölçüldü (2026-08-13): açıklıklar modele girer girmez
# o teslimat 13 SERT İHLAL verdi. Boş küme üstünde koşan denetim, geçtiğini değil BAKMADIĞINI söyler.
#
# DEĞİŞMEZ: bu betik TELLAL reposuna bağlı DEĞİLDİR ve müşteri dosyası KULLANMAZ.
# Fixture sentetik olarak, FAIL-LOUD üretilir; her iddia mutasyonla kırmızı-kanıtlıdır.
#
# Kullanım: bash tests/graf-koprusu.test.sh   ·   Exit: 0 tuttu · 1 kırıldı
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1

GECTI=0; KALDI=0
iddia() { # iddia <beklenen-rc> <ad> <komut...>
  local bek="$1" ad="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" = "$bek" ]; then GECTI=$((GECTI+1)); echo "  ✓ $ad"
  else KALDI=$((KALDI+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; printf '%s\n' "$out" | sed 's/^/      /' | head -10; fi
}

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export T PAKET

# ── FIXTURE (fail-loud; hedefi önce sil — bayat fixture sessizce kullanılmayacak) ──
# İki oda YAN YANA, aralarında 20 cm boşluk = İÇ DUVAR. Dış kenarların karşısında oda YOK.
# Sol odanın sağ yüzünde 90 cm'lik bir mühür = kapı ağzı.
# Sol odanın üst kenarına 2 cm'lik merdiven basamağı konur: sadeleştirmenin ızgara artığını
# temizlediği, ama ALANI bozmadığı ölçülebilsin.
rm -f "$T/graf.json" "$T/uzak.json"
node --input-type=module -e '
import { writeFileSync } from "fs";
const T = process.env.T;
const oda = (x0, y0, x1, y1) => [[x0,y0],[x1,y0],[x1,y1],[x0,y1]];
// sol oda 0..400, sağ oda 420..820 → yüzler arası 20 cm
// 2 cm basamak ÜST kenarda: sağ yüz (x=400) TEMİZ dikey kalsın ki ölçülen kalınlık
// fixture artığı değil gerçek boşluk (20 cm) olsun.
const sol = [[0,0],[400,0],[400,300],[200,300],[200,298],[0,298]];
const sag = oda(420, 0, 820, 300);
const graf = {
  odalar: [
    { ad: "SOL",  m2_poligon: 12.0, poligon: sol },
    { ad: "SAG",  m2_poligon: 12.0, poligon: sag },
  ],
  // kapı ağzı: sol odanın SAĞ yüzünde (x≈400), y 100..190 → 90 cm
  muhurler: [ { a: [400, 100], b: [400, 190] } ],
};
writeFileSync(T + "/graf.json", JSON.stringify(graf));
// MUTASYON fixture: odalar 300 cm ayrık → arama penceresi dışı, iç duvar OLMAMALI
const uzak = JSON.parse(JSON.stringify(graf));
uzak.odalar[1].poligon = oda(700, 0, 1100, 300);
uzak.muhurler = [];
writeFileSync(T + "/uzak.json", JSON.stringify(uzak));
' || { echo "✗ fixture üretilemedi — sessiz geçilmez"; exit 1; }
node --input-type=module -e '
import { writeFileSync } from "fs";
const T = process.env.T;
// 50 cm derinliğinde GERÇEK girinti: agresif toleransla düzleşir → alan bozulur.
// (Dikdörtgenin köşeleri hiçbir toleransla silinmez; fail-closed kanıtı gerçek girinti ister.)
const girintili = [[0,0],[400,0],[400,120],[350,120],[350,180],[400,180],[400,300],[0,300]];
writeFileSync(T + "/girintili.json", JSON.stringify({
  odalar: [{ ad: "GIRINTILI", m2_poligon: 11.7, poligon: girintili }], muhurler: [],
}));
' || { echo "✗ girintili fixture üretilemedi"; exit 1; }
[ -s "$T/graf.json" ] && [ -s "$T/uzak.json" ] && [ -s "$T/girintili.json" ] || { echo "✗ fixture BOŞ"; exit 1; }

cat > "$T/olc.mjs" <<'MJS'
import { readFileSync } from "fs";
const { grafiModeleCevir } = await import(process.env.PAKET + "/lib/graf-koprusu.mjs");
const graf = JSON.parse(readFileSync(process.argv[2], "utf8"));
const { model, rapor } = grafiModeleCevir(graf, {});
let v = { model, rapor };
for (const k of process.argv[3].split(".")) v = v?.[k];
console.log(typeof v === "object" ? JSON.stringify(v) : String(v));
MJS

olc() { node "$T/olc.mjs" "$1" "$2"; }
export -f olc

echo "── lifting → model köprüsü ──"

iddia 0 "köprü modeli dogrula'dan GEÇER" \
  bash -c '
    node --input-type=module -e "
      import { readFileSync, writeFileSync } from \"fs\";
      const { grafiModeleCevir } = await import(process.env.PAKET + \"/lib/graf-koprusu.mjs\");
      const { dogrula } = await import(process.env.PAKET + \"/lib/model.mjs\");
      const { model } = grafiModeleCevir(JSON.parse(readFileSync(process.env.T + \"/graf.json\",\"utf8\")), {});
      const { hatalar } = dogrula(model);
      if (hatalar.length) { console.error(hatalar.slice(0,5).join(\" | \")); process.exit(1); }
    "'

iddia 0 "İÇ duvar türetildi ve kalınlığı ÖLÇÜLDÜ (≈20 cm)" \
  bash -c 'ic=$(olc "$T/graf.json" rapor.duvar_ic); k=$(olc "$T/graf.json" rapor.olculen_ic_kalinlik_cm)
    [ "$ic" -gt 0 ] || { echo "iç duvar yok"; exit 1; }
    echo "$k" | grep -q "\"ortanca\":20" || { echo "ölçülen kalınlık: $k"; exit 1; }'

iddia 0 "DIŞ duvar var ve kalınlığı ÖLÇÜLMEDİ diye işaretli (uydurma yok)" \
  bash -c 'd=$(olc "$T/graf.json" rapor.duvar_dis); s=$(olc "$T/graf.json" rapor.dis_duvar_kalinligi)
    [ "$d" -gt 0 ] || { echo "dış duvar yok"; exit 1; }
    echo "$s" | grep -q "ÖLÇÜLMEDİ" || { echo "dış kalınlık ölçülmüş gibi sunulmuş: $s"; exit 1; }'

# MUTASYON: odaları arama penceresi dışına taşı → iç duvar KALMAMALI.
# Bu iddia olmasaydı "iç duvar>0" sabit bir doğruyu tekrarlayabilirdi (ölü kapı).
iddia 0 "mutasyon: odalar uzaklaşınca İÇ duvar SIFIRLANIR (kapı veriyi ölçüyor)" \
  bash -c 'a=$(olc "$T/graf.json" rapor.duvar_ic); b=$(olc "$T/uzak.json" rapor.duvar_ic)
    [ "$a" -gt 0 ] || { echo "temel durumda iç duvar yok"; exit 1; }
    [ "$b" = "0" ] || { echo "uzak fixture yine iç duvar buldu: $b"; exit 1; }'

iddia 0 "mühür AÇIKLIĞA çevrildi ve tipi 'gecis' (kapı/pencere uydurulmadı)" \
  bash -c 'n=$(olc "$T/graf.json" rapor.aciklik); t=$(olc "$T/graf.json" model.acikliklar)
    [ "$n" -ge 1 ] || { echo "açıklık yok"; exit 1; }
    echo "$t" | grep -q "\"tip\":\"gecis\"" || { echo "açıklık tipi: $t"; exit 1; }
    echo "$t" | grep -qE "\"tip\":\"(kapi|pencere)\"" && { echo "kapı/pencere UYDURULMUŞ"; exit 1; }
    exit 0'

iddia 0 "sadeleştirme köşe azaltır ama ALANI bozmaz (pay içinde)" \
  bash -c 's=$(olc "$T/graf.json" rapor.sadelestirme)
    echo "$s" | grep -q "\"kose_once\":6" || { echo "beklenen ham köşe yok: $s"; exit 1; }
    echo "$s" | grep -q "\"kose_sonra\":4" || { echo "2 cm basamak temizlenmedi: $s"; exit 1; }'

# FAIL-CLOSED kanıtı: alan payını sıfıra çekince (ve tolerans yüksekken) köprü DURMALI.
iddia 1 "alan sapması payı aşılınca model YAZILMAZ (fail-closed)" \
  node --input-type=module -e '
    import { readFileSync } from "fs";
    const { grafiModeleCevir, ayarYukle } = await import(process.env.PAKET + "/lib/graf-koprusu.mjs");
    const ayar = ayarYukle();
    ayar.esdogrusal_tolerans_cm = 60;      // girintiyi düzleştirecek kadar agresif
    ayar.azami_alan_sapmasi_yuzde = 0.001; // pay yok
    grafiModeleCevir(JSON.parse(readFileSync(process.env.T + "/girintili.json","utf8")), { ayar });
  '

# FAIL-CLOSED kanıtı: mühürlerin yarısından azı bağlanabiliyorsa köprü DURMALI.
iddia 1 "mühürlerin yarısı bağlanamazsa model YAZILMAZ (yarım açıklık kümesi tehlikelidir)" \
  node --input-type=module -e '
    import { readFileSync } from "fs";
    const { grafiModeleCevir } = await import(process.env.PAKET + "/lib/graf-koprusu.mjs");
    const graf = JSON.parse(readFileSync(process.env.T + "/graf.json","utf8"));
    // hiçbir duvara denk gelmeyen mühürler ekle (uzayda boşta)
    graf.muhurler.push({ a: [5000, 5000], b: [5000, 5090] });
    graf.muhurler.push({ a: [6000, 6000], b: [6000, 6090] });
    grafiModeleCevir(graf, {});
  '

iddia 0 "tip beyan edilmemiş oda RAPORLANIR (kör nokta sessiz geçmez)" \
  bash -c 't=$(olc "$T/graf.json" rapor.tipsiz_oda); echo "$t" | grep -q "SOL" || { echo "tipsiz oda raporlanmadı: $t"; exit 1; }'

# ── EKSEN SÖZLEŞMESİ: model Y AŞAĞI büyür (CAD'in tersi) ──────────────────────
# 🔴 Model sözleşmesi Y-aşağıdır (bkz. model-sema.md · dxf.mjs:23 · dwg.mjs:159 CAD'e
# yazarken -y uygular). lifting grafı ham CAD'dir (Y yukarı) → köprü ÇEVİRMEK zorunda.
# Çevirmezse `ciz --dxf/--dwg` mimara AYNALANMIŞ dosya teslim eder (2026-08-14'te ölçüldü).
# Fixture: SAG odası KUZEYDE (graf Y'si büyük). Modelde Y'si KÜÇÜK olmalı.
node --input-type=module -e '
import { writeFileSync } from "fs";
const T = process.env.T;
const oda = (x0,y0,x1,y1) => [[x0,y0],[x1,y0],[x1,y1],[x0,y1]];
writeFileSync(T + "/eksen.json", JSON.stringify({ odalar: [
  { ad: "GUNEY", m2_poligon: 6, poligon: oda(0,   0, 300, 200) },
  { ad: "KUZEY", m2_poligon: 6, poligon: oda(0, 500, 300, 700) },
], muhurler: [] }));
' || { echo "✗ eksen fixture üretilemedi"; exit 1; }

iddia 0 "eksen sözleşmesi: CAD'de kuzeydeki oda MODELDE küçük Y alır (çevrildi)" \
  bash -c '
    node --input-type=module -e "
      import { readFileSync } from \"fs\";
      const { grafiModeleCevir } = await import(process.env.PAKET + \"/lib/graf-koprusu.mjs\");
      const g = JSON.parse(readFileSync(process.env.T + \"/eksen.json\",\"utf8\"));
      const { model } = grafiModeleCevir(g, {});
      const y = (id) => { const o = model.odalar.find(x => x.id === id);
        const v = o.dongu.map(n => model.noktalar[n][1]); return v.reduce((a,b)=>a+b,0)/v.length; };
      const kuzey = y(\"kuzey\"), guney = y(\"guney\");
      // grafta KUZEY yukarıdaydı (Y büyük) → modelde Y KÜÇÜK olmalı
      if (!(kuzey < guney)) { console.error(\"eksen çevrilmemiş: kuzey=\" + kuzey + \" guney=\" + guney); process.exit(1); }
    "'

echo
echo "GEÇTİ=$GECTI KALDI=$KALDI"
[ "$KALDI" = 0 ] && { echo "SONUC: GECTI"; exit 0; } || { echo "SONUC: KALDI"; exit 1; }
