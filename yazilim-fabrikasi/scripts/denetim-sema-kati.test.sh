#!/usr/bin/env bash
# denetim-sema-kati.test.sh — denetim şeması Codex'in KATI (strict) yapılandırılmış çıktı kuralına uyuyor mu?
# Kural: her nesnede `required` = `properties` anahtarlarının TAMAMI; isteğe bağlı alan `null` tipini de kabul eder.
# Niçin: #336 `kutu_disi_yuzey` ekledi ama required'a koymadı → Codex 400 invalid_json_schema, denetçi her turda
# rc=1 düştü (15 Eki, ölçüldü). Sahte denetçili sınavlar şemayı API'ye göndermediği için bunu göremiyordu.
set -u; D="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$D/sablon/denetim-sema.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); hatalar = []
def gez(o, yol):
    if isinstance(o, dict):
        if o.get('type') == 'object' and 'properties' in o:
            eksik = [k for k in o['properties'] if k not in (o.get('required') or [])]
            if eksik: hatalar.append(f"{yol or '/'}: required eksik {eksik}")
            if o.get('additionalProperties', None) is not False: hatalar.append(f"{yol or '/'}: additionalProperties:false yok")
        for k, v in o.items(): gez(v, yol + '/' + k)
    elif isinstance(o, list):
        for i, v in enumerate(o): gez(v, f"{yol}[{i}]")
gez(d, '')
for h in hatalar: print('  ✗', h)
print('geçen=%d kalan=%d' % (0 if hatalar else 1, len(hatalar))); sys.exit(1 if hatalar else 0)
PY
