#!/usr/bin/env bash
# SALT OKUMA: verilen retro.py'nin olc() işlevi gerçek Nexus kökünde çağrılır (kutu DEĞİL — o canlı retro dizinine yazar).
# $1 = retro.py · sonra "AJAN:HAFTA" çiftleri. Basılan: kart açılan/bitti/tıkandı · göz turu · depo dökümü.
R="$1"; shift
python3 - "$R" "$@" <<'PY'
import importlib.util, sys
sp = importlib.util.spec_from_file_location("retro", sys.argv[1]); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
for c in sys.argv[2:]:
    ajan, hafta = c.split(":")
    k = m.olc("/config/projects/Nexus", ajan, hafta)["kart"]
    print("%-9s %s · kart %s/%s/%s · göz turu %s · depolar: %s · göz: %s" % (ajan, hafta, k["acilan"], k["bitti"], k["tikandi"], k["goz_turu"], " · ".join(k.get("depolar") or [k["yol"]]), " · ".join(k.get("goz_depolar") or [])))
PY
