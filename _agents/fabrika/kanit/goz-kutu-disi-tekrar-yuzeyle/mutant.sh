#!/usr/bin/env bash
# Mutasyon kanıtı: denetci.sh GEÇİCİ KOPYADA bozulur (çalışma ağacına dokunulmaz), denetci-kutu-disi.test.sh o kopyada koşar.
#   yuzey-yok        → yüzey eşlemesi kalkar, tekrar yine yalnız birebir metinle aranır (eski kural)        (beklenen düşen kapı: K2)
#   isaret-yok       → başka sözle gelen tekrar deftere işaretsiz yazılır                                    (beklenen düşen kapı: K4)
#   hep-tekrar       → yüzeyi olan her kutu dışı bulgu tekrar sayılır (ortak parça aranmaz)                  (beklenen düşen kapı: K5)
#   kelime-kesisimi  → parça tam eşleşmez, kelime kesişimi yeter ("telefonu" = "Sultan'ın telefonu")         (beklenen düşen kapı: K6)
#   ayni-tur         → aynı turdaki bulgular birbirini tekrar sayar                                          (beklenen düşen kapı: K7)
#   ayni-metin-yazar → birebir aynı metin her turda deftere yeniden yazılır                                  (beklenen düşen kapı: K8)
#   kesme-sayilir    → kesme işareti ve harf büyüklüğü farkı ayrı yüzey sayılır                              (beklenen düşen kapı: K2)
# Çıkış: sınavın rc'si · mutant kurulamazsa 9.
set -u
ad="${1:-}"; kok="$(git rev-parse --show-toplevel)" || exit 9
T="$(mktemp -d)"; trap 'find "$T" -mindepth 0 -delete 2>/dev/null' EXIT
git -C "$kok" archive HEAD yazilim-fabrikasi | tar -x -C "$T" || exit 9
python3 - "$T/yazilim-fabrikasi/scripts/denetci.sh" "$ad" <<'PY' || exit 9
import sys
p, ad = sys.argv[1], sys.argv[2]
M = {
  'yuzey-yok':        [('            ortak=sorted(parcalar(b.get("kutu_disi_yuzey"))&eski)\n', '            ortak=[]\n')],
  'isaret-yok':       [('                kayit["tekrar"]=True; kayit["ortak_yuzey"]=ortak\n', '                pass\n')],
  'hep-tekrar':       [('            ortak=sorted(parcalar(b.get("kutu_disi_yuzey"))&eski)\n', '            ortak=sorted(parcalar(b.get("kutu_disi_yuzey")))\n')],
  'kelime-kesisimi':  [('        if len(p)>=3: cik.add(p)\n', '        cik.update(w for w in p.split() if len(w)>=3)\n')],
  'ayni-tur':         [('            f.write(json.dumps(kayit,ensure_ascii=False)+"\\n")\n', '            f.write(json.dumps(kayit,ensure_ascii=False)+"\\n"); eski|=parcalar(b.get("kutu_disi_yuzey"))\n')],
  'ayni-metin-yazar': [('                tekrar.append({"ne":b.get("ne"),"yuzey":b.get("kutu_disi_yuzey")}); continue\n', '                tekrar.append({"ne":b.get("ne"),"yuzey":b.get("kutu_disi_yuzey")})\n')],
  'kesme-sayilir':    [('    y=str(y or "").replace("İ","i").replace("I","ı").lower().replace("’","\'")\n', '    y=str(y or "")\n')],
}
if ad not in M: print('bilinmeyen mutant: ' + ad); sys.exit(9)
s = open(p, encoding='utf-8').read()
for a, b in M[ad]:
    if s.count(a) != 1: print('mutant kurulamadı: çapa %d kez bulundu: %s' % (s.count(a), a[:60])); sys.exit(9)
    s = s.replace(a, b)
open(p, 'w', encoding='utf-8').write(s); print('MUTANT kuruldu: ' + ad)
PY
bash -n "$T/yazilim-fabrikasi/scripts/denetci.sh" || exit 9
bash "$T/yazilim-fabrikasi/scripts/denetci-kutu-disi.test.sh"
