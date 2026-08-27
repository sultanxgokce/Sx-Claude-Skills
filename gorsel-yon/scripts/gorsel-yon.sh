#!/usr/bin/env bash
# gorsel-yon.sh — üretilmiş görselle YÖN ARAYIŞI (kanıt üretmez).
#
# NİÇİN VAR: Nova sitesinin tüm iddiası GERÇEK İŞ. Üretilmiş görsel o iddiayı taşıyamaz.
#   Ama yön aramak, zemin dokusu denemek ve geçiş dilini göstermek üretilmiş görselle
#   yapılabilir — çünkü bunların hiçbiri ziyaretçiye "bu yapılmış iş" demez.
#
# 🔴 SINIR (SERDAR kararı 2026-08-25 · MÜZEYYİN'in talebi üzerine çizildi):
#   Ölçüt "üretilmiş mi" DEĞİL, "KANIT KONUMUNDA mı".
#   Bir görselin yanında hafta · çizim · karar duruyorsa o görsel KANITTIR → gerçek olmak
#   ZORUNDA. İddia taşımayan yüzey (zemin, geçiş, boşluk) üretilmiş olabilir.
#   Araç bu ayrımı KENDİ ZORLAR: --kullanim zorunludur ve kapalı kümedir.
#
# KULLANIM
#   gorsel-yon.sh dogrula                      # anahtar geçerli mi (KREDİ HARCAMAZ)
#   gorsel-yon.sh uret --kullanim <alan> --istem "..." [--sayi 1] [--uygula]
#   gorsel-yon.sh kullanimlar                  # izinli alanları listele
#
#   VARSAYILAN KURU-KOŞUM: --uygula verilmedikçe HİÇBİR kredi harcanmaz, istek gönderilmez.
#
# ÇIKIŞ: 0 tamam · 1 reddedildi (sınır/kısıt) · 2 kullanım/ortam · 3 ÖLÇEMEDİM (uç sessiz)
set -uo pipefail

TABAN="${HIGGSFIELD_TABAN:-https://platform.higgsfield.ai}"
# 🔴 UÇ TUZAĞI (ölçüldü 2026-08-23): `/v1` ÖNEKİ YOKTUR. /v1/... denenirse HER ŞEY 405 döner
#    ve "anahtar bozuk" sanılır. Kök neden anahtar değil ADRESTİR.
UC_URET="/higgsfield-ai/soul/standard"

# İZİNLİ KULLANIM ALANLARI — kapalı küme (sınırın kodda yaşayan hâli)
declare -A IZINLI=(
  [yon-arayisi]="kompozisyon/ışık denemesi — SİTEYE GİRMEZ, atılacak taslak"
  [doku-zemin]="içerik iddiası taşımayan soyut yüzey (zemin, boşluk dolgusu)"
  [hareket-dili]="geçişin nasıl olacağını GÖSTEREN örnek, içerik değil"
  [kesif-katalog]="müşteri-keşif katalog matrisi (stil×oda×palet) — HER kare ILHAM/YÖN rozetli; kanıt konumuna GEÇMEZ, site-yüzeyine SIZMAZ (Sultan-izni 2026-08-27, MİHMANDAR talebi; B3-site-yasağı katalog stillerine uygulanmaz)"
)
# 🔴 YASAK — bunlar kanıt konumudur, üretilmiş görsel giremez
YASAK_ANAHTAR="vaka|proje|once-sonra|önce-sonra|oncesi|öncesi|sonrasi|sonrası|santiye|şantiye|imalat|imalât|cizim|çizim|daire|mahal|portfolyo|referans"

_hata(){ echo "HATA: $*" >&2; }
# 🔴 Anahtar KASADA (openbao secret/nexus/HIGGSFIELD_API_KEY) — .env'de DEĞİL.
#    Değer stdout/log/chat'e ASLA basılmaz; yalnız değişkene alınır (credentials.yaml kuralı).
_anahtar(){
  local v="${HIGGSFIELD_API_KEY:-}"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  # v0.3.0: env-dosyası ÖNCE okunur — kasa-çekimi düşse bile eldeki anahtar kullanılır
  # (Nova vakası 2026-08-27: anahtar aynalanmış env-dosyasındaydı, get-fail her şeyi düşürüyordu)
  local envf="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
  v="$(sed -n 's/^export HIGGSFIELD_API_KEY=//p;s/^HIGGSFIELD_API_KEY=//p' "$envf" 2>/dev/null | head -1)"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  local vc="${VAULT_CEK:-/config/.claude/skills/vault-cek/scripts/vault-cek.sh}"
  [ -x "$vc" ] || [ -f "$vc" ] || return 1
  bash "$vc" get HIGGSFIELD_API_KEY >/dev/null 2>&1 || return 1
  v="$(sed -n 's/^export HIGGSFIELD_API_KEY=//p;s/^HIGGSFIELD_API_KEY=//p' "$envf" 2>/dev/null | head -1)"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  return 1
}

kullanimlar(){
  echo "İzinli kullanım alanları (kapalı küme):"
  for k in "${!IZINLI[@]}"; do printf '  %-14s %s\n' "$k" "${IZINLI[$k]}"; done
  echo
  echo "🔴 Bu kapalı kümenin DIŞI reddedilir. Ölçüt 'üretilmiş mi' değil, 'KANIT konumunda mı'."
  echo "   Yanında hafta/çizim/karar duran her görsel kanıttır → gerçek olmak zorundadır."
}

dogrula(){
  local a; a="$(_anahtar)"
  [ -n "$a" ] || { _hata "anahtar ÇEKİLEMEDİ (kasa: secret/nexus/HIGGSFIELD_API_KEY) — vault-cek doctor koş"; return 2; }
  # NEGATİF-KONTROLLÜ SINAMA — kredi HARCAMAZ (ölçüldü 2026-08-23):
  #   anahtarLA 404 {"detail":"Not found"} · anahtarSIZ 401 {"detail":"Invalid credentials"}
  #   İki yanıtın FARKI = kimlik kabul edildi.
  local sahte="00000000-0000-4000-8000-000000000000" ile siz
  ile="$(printf 'header = "Authorization: Key %s"\nurl = "%s/requests/%s/status"\nsilent\nwrite-out = "%%{http_code}"\noutput = "/dev/null"\nmax-time = 20\n' \
        "$a" "$TABAN" "$sahte" | curl --config - 2>/dev/null)"
  siz="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$TABAN/requests/$sahte/status" 2>/dev/null)"
  if [ -z "$ile" ] || [ -z "$siz" ]; then
    echo "RC=3 ÖLÇEMEDİM — uç yanıt vermedi (ağ/servis). 'anahtar bozuk' DEME."; return 3
  fi
  echo "anahtarLA=$ile · anahtarSIZ=$siz"
  if [ "$ile" != "$siz" ] && [ "$siz" = "401" ]; then
    echo "✅ anahtar GEÇERLİ (kimlik kabul edildi · kredi harcanmadı)"; return 0
  fi
  if [ "$ile" = "405" ]; then
    _hata "405 → ADRES yanlış olabilir. Taban '/v1' ÖNEKSİZ olmalı: $TABAN$UC_URET"; return 1
  fi
  echo "🔴 anahtar REDDEDİLDİ ya da uç değişti (ile=$ile siz=$siz)"; return 1
}

uret(){
  local kullanim="" istem="" sayi=1 uygula=0 oran="16:9"
  while [ $# -gt 0 ]; do
    case "$1" in
      --kullanim) kullanim="${2:-}"; shift 2 ;;
      --istem)    istem="${2:-}";    shift 2 ;;
      --sayi)     sayi="${2:-1}";    shift 2 ;;
      --oran)     oran="${2:-16:9}";  shift 2 ;;
      --uygula)   uygula=1;          shift ;;
      *) shift ;;
    esac
  done
  [ -n "$kullanim" ] || { _hata "--kullanim ZORUNLU. Alanlar: ${!IZINLI[*]}"; return 2; }
  [ -n "${IZINLI[$kullanim]:-}" ] || {
    _hata "izinsiz kullanım alanı: '$kullanim'"
    echo "  İzinli: ${!IZINLI[*]}" >&2
    echo "  🔴 Sınır: üretilmiş görsel KANIT konumunda duramaz." >&2
    return 1; }
  [ -n "$istem" ] || { _hata "--istem ZORUNLU"; return 2; }

  # KISIT KAPISI — istemde kanıt-konumu sızdıran kelime varsa REDDET (fail-closed)
  if printf '%s' "$istem" | grep -qiE "$YASAK_ANAHTAR"; then
    _hata "istem KANIT konumuna işaret ediyor (eşleşen desen: $YASAK_ANAHTAR)"
    echo "  Vaka/şantiye/çizim/daire görselleri GERÇEK olmak zorunda — üretilemez." >&2
    return 1
  fi
  # B3 YASAKLARI — Sultan'ın seçtiği yönün ihlali (fail-closed)
  if printf '%s' "$istem" | grep -qiE "luxury|lüks|altin|altın|gold|mermer|marble|render|3d|photoreal|foto.?ger|stok|stock"; then
    _hata "istem B3 yasaklarına giriyor (lüks emlak parlaklığı · render ağırlıklı dil)"
    return 1
  fi

  # NOVA YÖN ÇİTİ — her isteme Sultan'ın seçtiği yön otomatik eklenir (unutulamaz)
  local yon="natural diffuse daylight, soft shadows, generous negative space, calm restraint; \
materials: natural wood and matte black/anthracite metal; no ornament, no gloss, no gold; \
composition led by light and emptiness, not decoration; legible at small size on a phone screen at night"

  echo "── gorsel-yon · kullanım=$kullanim · sayı=$sayi"
  echo "   alan: ${IZINLI[$kullanim]}"
  echo "   istem: $istem"
  echo "   +yön çiti: (otomatik eklendi, çıkarılamaz)"
  if [ "$uygula" -ne 1 ]; then
    echo
    echo "KURU-KOŞUM (varsayılan) — kredi HARCANMADI, istek GÖNDERİLMEDİ."
    echo "Gerçekten üretmek için: --uygula  (her koşum kredi harcar)"
    return 0
  fi
  local a; a="$(_anahtar)"
  [ -n "$a" ] || { _hata "anahtar yok"; return 2; }
  # 🔴 GÖVDE ŞEMASI — uç `prompt`'u KÖKTE ister, `params` altında DEĞİL.
  # Ölçüm (2026-08-25, kredi harcamayan negatif-kontrollü prob):
  #   {"params":{"prompt":…}}  → 422  loc=["body","prompt"] "Field required"
  #   {"prompt":…,"resolution":"9999p"} → 422 YALNIZ resolution için → kök-prompt KABUL
  # `quality` diye bir alan YOK (sessizce yok sayılıyordu); doğrusu `resolution`.
  local govde; govde="$(python3 -c '
import json,sys
print(json.dumps({"prompt":sys.argv[1]+" — "+sys.argv[2],
                  "resolution":"1080p","aspect_ratio":sys.argv[4],
                  "batch_size":(4 if sys.argv[3]=="4" else 1)}))' "$istem" "$yon" "$sayi" "$oran")"
  local yanit; yanit="$(printf 'header = "Authorization: Key %s"\nheader = "Content-Type: application/json"\nurl = "%s%s"\nsilent\nmax-time = 120\n' \
    "$a" "$TABAN" "$UC_URET" | curl --config - -X POST -d "$govde" 2>/dev/null)"
  local rid; rid="$(printf '%s' "$yanit" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("request_id",""))
except Exception: print("")' 2>/dev/null)"
  if [ -z "$rid" ]; then
    _hata "uç istek kimliği döndürmedi — ham yanıt:"; printf '%s\n' "$yanit" >&2; return 3
  fi
  _defter_yaz "$kullanim" "$sayi" "$rid" "$istem"
  echo "🧾 iş kabul edildi · kimlik: $rid  (deftere yazıldı)"
  echo "   sonucu almak için:  gorsel-yon.sh bekle $rid --indir <dizin>"
  echo
}

# ═══ v0.2.0 · GAZ KATMANI — bekleme · indirme · maliyet defteri · yön turu ═══
# Niçin: v0.1 yalnız istek GÖNDERİYORDU. Uç ASENKRON çalışır ({"status":"queued",...});
# bekleyen/indiren hiçbir şey yoktu → üretilen görsele hiçbir zaman ULAŞILAMAZDI.
# (Ölçüm 2026-08-25: ilk gerçek koşum 480ff754… kuyruğa girdi, sonucu alan yok.)

DEFTER="${GORSEL_YON_DEFTER:-$HOME/.claude/gorsel-yon-defteri.jsonl}"

# Her GERÇEK çağrı deftere düşer — kapısız ders deftere girmez, defterisiz harcama ölçülemez.
_defter_yaz(){
  local kullanim="$1" sayi="$2" rid="$3" istem="$4"
  mkdir -p "$(dirname "$DEFTER")" 2>/dev/null
  python3 -c 'import json,sys,datetime
print(json.dumps({"zaman":datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
 "kullanim":sys.argv[1],"adet":int(sys.argv[2]),"istek":sys.argv[3],
 "istem":sys.argv[4][:200],"durum":"kuyrukta"},ensure_ascii=False))' \
    "$kullanim" "$sayi" "$rid" "$istem" >> "$DEFTER"
}

_defter_kapat(){  # istek tamamlanınca durumu + görsel sayısını işle
  local rid="$1" durum="$2" adet="$3"
  [ -f "$DEFTER" ] || return 0
  python3 - "$DEFTER" "$rid" "$durum" "$adet" <<'PYEOF'
import json,sys,io
yol,rid,durum,adet=sys.argv[1:5]
sat=io.open(yol,encoding="utf-8").read().splitlines()
for i,l in enumerate(sat):
    if not l.strip(): continue
    try: r=json.loads(l)
    except Exception: continue
    if r.get("istek")==rid:
        r["durum"]=durum; r["gelen_gorsel"]=int(adet)
        sat[i]=json.dumps(r,ensure_ascii=False)
io.open(yol,"w",encoding="utf-8").write("\n".join(sat)+"\n")
PYEOF
}

defter(){
  [ -f "$DEFTER" ] || { echo "defter boş — bugüne dek hiç gerçek üretim koşulmadı."; return 0; }
  echo "🧾 GÖRSEL DEFTERİ · $DEFTER"
  python3 - "$DEFTER" <<'PYEOF'
import json,sys,io,collections
sat=[json.loads(l) for l in io.open(sys.argv[1],encoding="utf-8") if l.strip()]
top=collections.Counter(); gor=0
for r in sat:
    top[r.get("kullanim","?")]+=r.get("adet",1); gor+=int(r.get("gelen_gorsel",0) or 0)
    print("  %s  %-13s %s adet  durum=%-9s %s" % (r.get("zaman","")[:16], r.get("kullanim","?"),
          r.get("adet",1), r.get("durum","?"), (r.get("istem","") or "")[:48]))
print("\n  TOPLAM istek: %d · istenen kare: %d · fiilen gelen: %d" % (len(sat), sum(top.values()), gor))
print("  alan dağılımı: " + " · ".join("%s=%d"%(k,v) for k,v in top.items()))
print("  🔴 Birim kredi maliyeti ÖLÇÜLMEDİ (sağlayıcı resmî fiyat yayımlamıyor) — bu defter")
print("     harcamanın ADEDİNİ sayar, LİRASINI değil. Fiyat öğrenilirse çarpanı buraya girer.")
PYEOF
}

bekle(){
  local rid="${1:-}" indir="" azami="${GORSEL_YON_AZAMI:-300}"
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --indir) indir="${2:-}"; shift 2 ;;
      --azami) azami="${2:-300}"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -n "$rid" ] || { _hata "kullanım: bekle <istek-kimliği> [--indir <dizin>] [--azami <sn>]"; return 2; }
  local a; a="$(_anahtar)"; [ -n "$a" ] || { _hata "anahtar yok"; return 2; }

  local gecen=0 yanit durum
  while [ "$gecen" -lt "$azami" ]; do
    yanit="$(printf 'header = "Authorization: Key %s"\nurl = "%s/requests/%s/status"\nsilent\nmax-time = 25\n' \
             "$a" "$TABAN" "$rid" | curl --config - 2>/dev/null)"
    [ -n "$yanit" ] || { echo "RC=3 ÖLÇEMEDİM — uç sessiz."; return 3; }
    durum="$(printf '%s' "$yanit" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("status",""))
except Exception: print("")')"
    case "$durum" in
      completed|succeeded|success|done) break ;;
      failed|error|canceled|cancelled)
        _defter_kapat "$rid" "$durum" 0
        _hata "iş DÜŞTÜ (durum=$durum)"; printf '%s\n' "$yanit" >&2; return 1 ;;
      "" ) _hata "yanıtta durum alanı yok"; printf '%s\n' "$yanit" >&2; return 3 ;;
      *) printf '  … %s (%ssn)\n' "$durum" "$gecen"; sleep 10; gecen=$((gecen+10)) ;;
    esac
  done
  if [ "$gecen" -ge "$azami" ]; then
    echo "⏳ süre doldu ($azami sn) — iş HÂLÂ sürüyor olabilir, DÜŞTÜ DEME."
    echo "   tekrar: gorsel-yon.sh bekle $rid --indir <dizin>"; return 3
  fi

  # görsel adreslerini çıkar (şema esnek: url/raw/min alanlarını tara)
  local adresler; adresler="$(printf '%s' "$yanit" | python3 -c '
import json,sys,re
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
bulunan=[]
def gez(o):
    if isinstance(o,dict):
        for k,v in o.items():
            if isinstance(v,str) and re.match(r"^https?://.+\.(png|jpg|jpeg|webp)(\?|$)",v,re.I): bulunan.append(v)
            else: gez(v)
    elif isinstance(o,list):
        for v in o: gez(v)
gez(d)
print("\n".join(dict.fromkeys(bulunan)))')"
  local n; n="$(printf '%s' "$adresler" | grep -c . || true)"
  _defter_kapat "$rid" "tamam" "${n:-0}"
  echo "✅ iş tamam · gelen görsel: ${n:-0}"
  if [ "${n:-0}" = "0" ]; then
    echo "  ⚠️ Adres bulunamadı — yanıt şeması beklenenden farklı. HAM yanıt:"; printf '%s\n' "$yanit"; return 3
  fi
  printf '%s\n' "$adresler"
  if [ -n "$indir" ]; then
    mkdir -p "$indir" || return 2
    local i=1
    while IFS= read -r u; do
      [ -n "$u" ] || continue
      curl -s -L --max-time 90 -o "$indir/${rid}-$i.png" "$u" && echo "  ⤓ $indir/${rid}-$i.png"
      i=$((i+1))
    done <<< "$adresler"
  fi
}

case "${1:-}" in
  dogrula)      shift; dogrula "$@" ;;
  uret)         shift; uret "$@" ;;
  kullanimlar)  shift; kullanimlar "$@" ;;
  bekle)        shift; bekle "$@" ;;
  defter)       shift; defter "$@" ;;
  *) sed -n '2,26p' "$0"; exit 2 ;;
esac
