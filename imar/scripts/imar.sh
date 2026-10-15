#!/usr/bin/env bash
# imar.sh — ⛩️ İMAR'ın tek şalteri: kur · ac · kapat · durum · acik-mi
#
# NİÇİN BÖYLE (Sultan, 5 Ekim · M13): "kapalıyken hiçbir şey kendiliğinden koşmasın."
# Kendiliğinden koşan her şey (ÇARK yuvaları, ikinci göz) ÖNCE bu şaltere bakar.
# Şalter tek dosyadır; her değişim tarihli kütüğe düşer (kanıt = kütük + tarih).
#
# FAIL-CLOSED: durum dosyası yoksa ya da okunamıyorsa İMAR KAPALI sayılır.
# "Emin değilim" hiçbir zaman "açık" demek değildir — belirsizlikte hiçbir şey koşmaz.
#
# Kullanım: bash scripts/imar.sh kur|ac|kapat|durum|acik-mi [--not "…"]
# Çıkış (acik-mi): 0 açık · 1 kapalı · 3 ölçülemedi (dosya yok/bozuk → kapalı MUAMELESİ görür)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DURUM="${IMAR_DURUM:-$REPO/_agents/spec/imar/DURUM.json}"
KUTUK="${IMAR_KUTUK:-$REPO/hafiza/imar-kutuk.log}"
EMIR="$REPO/_agents/spec/agentic-sistem/gun-emri.json"
SERI="${IMAR_SERI:?IMAR_SERI yok — profil çözülmedi (imar-profil.py cozumle)}"
KIM="${IMAR_KIM:-${CLAUDE_AGENT:-$(whoami)}}"

KOMUT="${1:-durum}"; shift || true
NOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --not) NOT="${2:-}"; shift 2;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 2;;
  esac
done

_log(){ mkdir -p "$(dirname "$KUTUK")"; printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$KUTUK"; }

_oku(){ # stdout: acik|kapali ; rc 0 ok · 3 ölçülemedi
  [ -r "$DURUM" ] || return 3
  python3 - "$DURUM" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1]))
a=d.get("acik")
if a is True: print("acik")
elif a is False: print("kapali")
else: sys.exit(3)
PY
}

_yaz(){ # $1 true|false
  mkdir -p "$(dirname "$DURUM")"
  python3 - "$DURUM" "$1" "$KIM" "$NOT" <<'PY'
import json,sys,datetime,os
yol,acik,kim,not_=sys.argv[1:5]
d={}
if os.path.exists(yol):
    try: d=json.load(open(yol))
    except Exception: d={}
d["_aciklama"]="⛩️ İMAR şalteri. acik=false iken ÇARK yuvaları ve ikinci göz KOŞMAZ. Elle düzenleme: scripts/imar.sh ac|kapat"
d["acik"]=(acik=="true")
d["degisti"]=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
d["kim"]=kim
d["not"]=not_
json.dump(d,open(yol,"w"),ensure_ascii=False,indent=2); open(yol,"a").write("\n")
PY
}

_tur_suruyor(){ # rc 0: şu an bir tur koşuyor
  [ -e /tmp/muneccim-kos.lock ] || return 1
  ! flock -n /tmp/muneccim-kos.lock true 2>/dev/null
}

case "$KOMUT" in
  acik-mi)
    h="$(_oku)"; rc=$?
    case "$rc:$h" in
      0:acik)   echo "açık";   exit 0;;
      0:kapali) echo "kapalı"; exit 1;;
      *)        echo "ÖLÇÜLEMEDİ: durum dosyası yok ya da bozuk ($DURUM) → kapalı sayılır"; exit 3;;
    esac;;

  kur)
    # İdempotent kurulum: durum dosyası yoksa KAPALI açılır (fail-closed), varsa dokunulmaz.
    if [ -r "$DURUM" ] && [ "$(_oku)" ]; then
      echo "durum dosyası zaten var: $DURUM ($(_oku))"
    else
      _yaz false; _log "KUR · durum dosyası açıldı (kapalı) · kim=$KIM"
      echo "durum dosyası açıldı (KAPALI): $DURUM"
    fi
    # Zamanlayıcı kayıtlı mı? Kurulum cron'a dokunmaz — yalnız ölçer ve söyler.
    if crontab -l 2>/dev/null | grep -q 'cark-tur.sh'; then
      echo "zamanlayıcı: kayıtlı (ÇARK yuvaları) — kapalıyken yuva kendi atlar"
    else
      echo "zamanlayıcı: KAYITLI DEĞİL — ÇARK kendiliğinden dönmez (cron satırı için: scripts/cark-tur.sh başlığı)"
    fi
    for f in cark-tur.sh muneccim-kos.sh imar-ikinci-goz.sh imar-fikir-kapisi.py devir-ayikla.py; do
      [ -e "$REPO/scripts/$f" ] && echo "parça: $f ✓" || echo "parça: $f ✗ EKSİK"
    done
    # PDF aracı (8 Ekim): node_modules git'te değil; sıfırdan kurulumda buradan yakalanır.
    if [ -e "$REPO/scripts/pdf/node_modules/pdfjs-dist/legacy/build/pdf.mjs" ]; then echo "parça: pdf-metin (pdfjs-dist) ✓"
    else echo "parça: pdf-metin ✗ EKSİK — kur: cd scripts/pdf && npm install --no-audit --no-fund"; fi
    echo "kütük: $KUTUK"
    exit 0;;

  ac)
    once="$(_oku 2>/dev/null || echo yok)"
    _yaz true; _log "AÇ · önce=$once · kim=$KIM${NOT:+ · not=$NOT}"
    echo "⛩️ İMAR AÇIK — bundan sonra ÇARK yuvaları gün emrine göre kendiliğinden döner."
    [ "$once" = "acik" ] && echo "(zaten açıktı; tarih tazelendi)"
    echo "kütük: $(tail -1 "$KUTUK")"
    exit 0;;

  kapat)
    once="$(_oku 2>/dev/null || echo yok)"
    _yaz false; _log "KAPAT · önce=$once · kim=$KIM${NOT:+ · not=$NOT}"
    echo "⛩️ İMAR KAPALI — hiçbir yuva kendiliğinden koşmaz. Elle çağrı serbest."
    if _tur_suruyor; then
      echo "⚠ şu an bir tur SÜRÜYOR: öldürülmedi, kendi bitişine bırakıldı; yenisi başlamaz."
      _log "KAPAT · not: kapatma anında tur sürüyordu, bitişine bırakıldı"
    fi
    [ "$once" = "kapali" ] && echo "(zaten kapalıydı; tarih tazelendi)"
    echo "kütük: $(tail -1 "$KUTUK")"
    exit 0;;

  durum)
    h="$(_oku)"; rc=$?
    case "$rc:$h" in
      0:acik)   BAS="⛩️ İMAR AÇIK";;
      0:kapali) BAS="⛩️ İMAR KAPALI";;
      *)        BAS="⛩️ İMAR ÖLÇÜLEMEDİ (durum dosyası yok/bozuk → kapalı sayılıyor; kur: scripts/imar.sh kur)";;
    esac
    DEG="$(python3 -c "import json;d=json.load(open('$DURUM'));print(d.get('degisti','?'),'·',d.get('kim','?'))" 2>/dev/null || echo "?")"
    echo "$BAS  (son değişim: $DEG)"
    KOTA="$(python3 -c "import json;print(json.load(open('$EMIR')).get('tur','?'))" 2>/dev/null || echo "?")"
    KOSAN="$(cat "/tmp/cark-sayac/$(date +%F)" 2>/dev/null || echo 0)"
    YUVA="$(python3 -c "import json;print(' '.join(json.load(open('$EMIR')).get('yuvalar',[])))" 2>/dev/null || echo "?")"
    echo "ÇARK: bugün $KOSAN/$KOTA tur · yuvalar: $YUVA"
    if _tur_suruyor; then echo "şu an: bir tur SÜRÜYOR"; else echo "şu an: tur koşmuyor"; fi
    SON_TUR="$(ls -1t "$SERI"/gunluk/*-tur.md 2>/dev/null | head -1)"
    [ -n "$SON_TUR" ] && echo "son tur: $(basename "$SON_TUR")" || echo "son tur: yok"
    SON_GOZ="$(ls -1t "$SERI"/goz/*.goz.json 2>/dev/null | head -1)"
    if [ -n "$SON_GOZ" ]; then
      python3 - "$SON_GOZ" <<'PY' 2>/dev/null || echo "son göz: okunamadı"
import json,sys,os,collections
d=json.load(open(sys.argv[1])); c=collections.Counter(x.get("hukum","?") for x in d.get("dersler",[]))
print("son göz:", os.path.basename(sys.argv[1]), "·", " · ".join(f"{k} {v}" for k,v in c.items()) or "ders yok")
PY
    else echo "son göz: yok"; fi
    if [ -r "$SERI/DERSLER.md" ]; then
      DERS="$(grep -c -E '^(###? |\*\*|[0-9]+\. \*\*)?D-[0-9]{3}' "$SERI/DERSLER.md")"
      GOZLU="$(grep -c 'İkinci göz:' "$SERI/DERSLER.md")"
      # betik bekçisi: üç ölçülmüş tuzak (çift sıfır · kabuk öldürme · yasaklı silme).
      # 🔴 Kural CLAUDE.md'de ve reçetede YAZILIydı, koşan kapısı YOKTU — bileyi turu 12 Eki.
      if [ -x "$REPO/scripts/betik-bekcisi.sh" ]; then
        BB="$(bash "$REPO/scripts/betik-bekcisi.sh" 2>/dev/null | grep -m1 "^— kırmızı" || true)"
        echo "betik bekçisi : ${BB:-ÖLÇÜLEMEDİ}"
      else echo "betik bekçisi : ÖLÇÜLEMEDİ (betik yok)"; fi
      # demo açılış süresi: dosya beş günde 54→69 KB büyüdü, süre hiç ölçülmüyordu (13 Eki)
      DEMO="$REPO/tasarim/mobilyaci/ciktilar/defter-demo.html"
      if [ -r "$DEMO" ] && [ -r "$REPO/scripts/tarayici/acilis-olc.mjs" ]; then
        AC="$(node "$REPO/scripts/tarayici/acilis-olc.mjs" "$DEMO" --yavas 3g --json 2>/dev/null)"
        if [ -n "$AC" ]; then
          echo "demo açılış   : $(printf '%s' "$AC" | python3 -c "import json,sys;d=json.load(sys.stdin);print('%.1f KB · ilk anlamlı boya %s ms (3g · 4x yavaş) · eşik %s ms → %s' % (d['boyut_bayt']/1024, d['ilk_anlamli_boya_ms'], d['esik_ms'], 'altında' if d['olcut_ms']<=d['esik_ms'] else 'AŞILDI'))")"
        else echo "demo açılış   : ÖLÇÜLEMEDİ (tarayıcı yok ya da sayfa boya üretmedi)"; fi
      fi
      echo "dersler: $DERS (ikinci gözden geçen: $GOZLU)"
    else echo "dersler: ölçülemedi (DERSLER.md yok)"; fi
    if [ -x /config/.ic-sayfa/defter-yaz.py ] || [ -r /config/.ic-sayfa/defter-yaz.py ]; then
      FD="$(python3 /config/.ic-sayfa/defter-yaz.py listele 2>/dev/null | tail -1)"; echo "fikir defteri: ${FD:-ölçülemedi}"
    fi
    MEZ="$(wc -l < "$REPO/hafiza/fikir-mezarligi.jsonl" 2>/dev/null || echo 0)"; echo "mezarlık: $MEZ fikir"
    # M10: Sultan'ın önünde bekleyen fikir varsa SENDE satırı (seç/öldür: /imar-sec)
    if [ -r "$REPO/scripts/imar-defter.py" ]; then
      BEK="$(python3 "$REPO/scripts/imar-defter.py" gelen 2>/dev/null | head -1)"
      case "$BEK" in *": 0") ;; "") ;; *) echo "SENDE · $BEK (seç/öldür: /imar-sec)";; esac
    fi
    [ -r "$KUTUK" ] && { echo "son kütük satırları:"; tail -3 "$KUTUK" | sed 's/^/  /'; }
    exit 0;;

  *) echo "kullanım: imar.sh kur|ac|kapat|durum|acik-mi [--not …]" >&2; exit 2;;
esac
