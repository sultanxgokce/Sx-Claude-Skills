#!/usr/bin/env bash
# girdi-kapisi.sh — zincire GIRECEK gorselin gercekten FOTOGRAF oldugunu sinar.
#
# ── 🔴 NEDEN VAR (2026-08-30, para yakarak ogrenildi) ────────────────────────
# D-003 setinin 14 karesinden UCU fotograf degil, ilan sayfasinin EKRAN
# GORUNTUSUYDU: ortada dar bir foto seridi, iki yaninda tarayici cercevesi,
# reklam ve kucuk resimler. Bunlardan birini (03) filigran temizligine soktum;
# model "temizlerken" OLMAYAN BIR ODA UYDURUP sol alta yapistirdi ve bolge
# siniri keskin bir dikdortgen olarak kaldi. Yani girdi kapisi olmayinca AI
# yalniz para yakmiyor, UYDURMA URETIYOR — ve uydurma bir emlak gorseli
# bizim en sert kirmizi cizgimiz.
#
# ── OLCULEN IMZA (14 karede, sinirda tek vaka YOK) ──────────────────────────
#   ekran goruntusu : sol/sag %13'luk bantlar ort~19-22, std~7  (koyu VE duz)
#   gercek fotograf : ort 72-175, std 16-72
# Ayrim bu kadar keskin oldugu icin esik ORTADAN secildi: ort<70 VE std<45.
#
# 🔴 FAIL-CLOSED: karar verilemiyorsa (dosya okunamadi, olcum bos) RED.
# Bir supheliyi zincire sokmanin bedeli uydurma; disarida birakmanin bedeli
# bir insanin bakip "bu aslinda fotograf" demesi. Ikincisi ucuz.
#
# Kullanim: girdi-kapisi.sh <gorsel> [--sessiz]   · rc=0 fotograf · rc=1 degil
set -uo pipefail
G="${1:-}"; SESSIZ="${2:-}"
[ -f "$G" ] || { echo "[kirmizi] dosya yok: $G" >&2; exit 1; }

olc() { # $1=genislik-orani $2=x-orani -> "ort std"
  ffmpeg -hide_banner -loglevel error -i "$G" -vf "crop=iw*$1:ih:iw*$2:0,format=gray" -f rawvideo - 2>/dev/null \
  | python3 -c "
import sys
d=sys.stdin.buffer.read()
if not d: print('BOS'); raise SystemExit
n=len(d); m=sum(d)/n; v=(sum((x-m)**2 for x in d)/n)**0.5
print('%.0f %.0f' % (m,v))"
}
read -r SO SS < <(olc 0.13 0) || true
read -r AO AS < <(olc 0.13 0.87) || true
case "$SO$SS$AO$AS" in ''|*BOS*|*[!0-9\ ]*) echo "[kirmizi] olculemedi — fail-closed RED: $G" >&2; exit 1 ;; esac

if [ "$SO" -lt 70 ] && [ "$AO" -lt 70 ] && [ "$SS" -lt 45 ] && [ "$AS" -lt 45 ]; then
  [ "$SESSIZ" = --sessiz ] || echo "[kirmizi] EKRAN GORUNTUSU (yan bantlar koyu+duz: sol $SO/$SS · sag $AO/$AS) — zincire ALINMAZ: $G" >&2
  exit 1
fi
[ "$SESSIZ" = --sessiz ] || echo "[yesil] fotograf (yan bantlar sol $SO/$SS · sag $AO/$AS)"
exit 0
