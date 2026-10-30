#!/usr/bin/env bash
# hasat.sh — HASAT KAPISI (1.19.0 · Meşveret 30 Eki madde 9, Sultan önem 2 · görev …ZM3PWD): havuzdaki bir bulgu göreve çevrilmeden
#   ÖNCE "sorun hâlâ var mı" ölçülür. Mevcut tazelik denetimi (sirada-bak 1.17) KAYDIN yaşına bakar; bu kapı SORUNUN yaşadığına bakar.
#   hasat.sh durum   <gorev_id> [--taze-gun N] [--birlesme YYYY-MM-DD | --yuzey <yol> [--depo <kök>]]   → SALT OKUR: hasat olur mu?
#   hasat.sh dogrula <gorev_id> --sonuc var|duzelmis|olculemedi --olcum "<komut ya da dosya>" [--yuzey <dosya|dizin|-> (var'da ZORUNLU)] [--sinif olcum|pr|ci|canli|kare]
#                    [--soz "<Sultan-dilinde 1-2 cümle>"] [--kapandi "<PR #N | commit | iş adı>"] [--tarih YYYY-MM-DD]
#                    → kayda MUHAKKİK biçiminde adım: "[doğrulama: var|düzelmiş|ölçülemedi] sınıf=… · ölçüm: … · tarih=… · <söz>"
#                      düzelmiş → --kapandi ZORUNLU; kayıt "kendiliğinden kapandı — <iş>" notuyla iptal edilir (gorev.sh durum … iptal)
#   hasat.sh ac      <havuz_id> "<gerekçe ≥5>" --kip otomatik|seansli [--baslik "<doğan görev başlığı>"] [--ozet "<ad (5-10 kelime): açıklama>"] [--kutu K] [--atanan A]
#                    → kapı OLUR ise havuz kaydı YERİNDE KALIR (durum havuz) ve ondan YENİ görev doğar (1.20.0, Kuzey G1.5/G1.6):
#                      doğan görevin açılış adımı "havuz kaydı <id>'den Otomatik|Seanslı Hasat ile açıldı", bağ havuz kaydının doğan_gorevler alanına yazılır
#                      (gorev.sh dogan). Başlık/özet verilmezse havuz kaydınınkiler kullanılır; doğan görev özet kapısından geçer (defter: tek cümle, ≤80 harf, ad 5-10 kelime).
#                      --kip seansli ise havuz kaydında Sultan'ın "[Seanslı Hasat] kabul|düzeltmeyle kabul" cevabı SON cevap olarak durmalıdır (yoksa rc 1: cevap uydurulmaz).
#   hasat.sh cevap   <havuz_id> kabul|baska-sun|duzeltmeyle-kabul --oturum <ref> --soz "<Sultan'ın sözü, verbatim>" [--duzeltme "<düzelttiği cümle>" (duzeltmeyle-kabul'de ZORUNLU)]
#                    → Seanslı Hasat'ın üç cevabını havuz kaydına adım olarak yazar: "[Seanslı Hasat] kabul · …" / "… başka sun · …" / "… düzeltmeyle kabul · …".
#                      Sultan'ın cevabını ajan ÜRETMEZ, gördüğünü aktarır (A06): --oturum ve --soz olmadan yazılmaz.
# Kapı (durum):  HASAT=OLUR yalnız şu dördü birlikteyse: kayıt havuzda · son doğrulama "var" · doğrulama ≤ taze-gun (vars. 7) gün önce ·
#   ilgili yüzeyde doğrulamadan SONRA birleşme yok (--birlesme tarihi · --yuzey yolu · bayraksız: son doğrulama adımındaki yüzey=; son commit günü, git). Doğrulama yok/bayat/düzelmiş/
#   ölçülemedi → HASAT=OLMAZ (rc 1) ve NEDEN= ne yapılacağını söyler. Tarih okunamıyor / git ölçemedi → HASAT=ÖLÇÜLEMEDİ (rc 3): "olur" UYDURULMAZ.
# Adım metnine tarih=… yazılır: gorev.sh adim aynı metni ikinci kez eklemez; tarihsiz metin yeniden ölçümde sessizce YUTULUR ve kayıt tazelenmezdi.
# rc: 0 olur/yazıldı · 1 kapı kapalı ya da defter reddetti · 2 kullanım · 3 ölçülemedi
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
GOREV="$(bash "$KOK/gorev-yolu.sh" 2>/dev/null)" || GOREV="${GUNLUK_PLAN_GOREV_SH:-/gorev.sh-yok}"
BUGUN="${GUNLUK_PLAN_TARIH:-$(date +%F)}"
kullanim() { sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^#  *//' >&2; exit 2; }
KOMUT="${1:-}"; [ $# -ge 1 ] && shift || kullanim
case "$KOMUT" in durum|dogrula|ac|cevap) ;; *) kullanim ;; esac
ID="${1:-}"; case "$ID" in gorev_*) shift ;; *) echo "HATA: gorev_id 'gorev_' ile başlamalı (verilen: '$ID')" >&2; exit 2 ;; esac
CEVAP=""; if [ "$KOMUT" = cevap ]; then CEVAP="${1:-}"; case "$CEVAP" in kabul|baska-sun|duzeltmeyle-kabul) shift ;; *) echo "HATA: cevap kabul|baska-sun|duzeltmeyle-kabul olmalı (verilen: '$CEVAP')" >&2; exit 2 ;; esac; fi
GEREKCE=""; if [ "$KOMUT" = ac ]; then GEREKCE="${1:-}"; [ -n "$(printf '%s' "$GEREKCE" | tr -d '[:space:]')" ] && [ ${#GEREKCE} -ge 5 ] || { echo "HATA: ac için gerekçe (≥5 harf) ister" >&2; exit 2; }; shift; fi
TAZE_GUN="${GUNLUK_PLAN_TAZE_GUN:-7}"; BIRLESME=""; YUZEY=""; DEPO="${HASAT_DEPO:-}"; SONUC=""; OLCUM=""; SINIF="olcum"; SOZ=""; KAPANDI=""; TARIH=""; KIP=""; BASLIK_ARG=""; OZET_ARG=""; KUTU_ARG=""; ATANAN_ARG=""; OTURUM=""; DUZELTME=""
while [ $# -gt 0 ]; do
  # göz tur 1: değersiz bayrakta 'shift 2' düşer, argüman listesi değişmez → sonsuz döngü. Değer ister bayrağı önce sına.
  case "$1" in --taze-gun|--birlesme|--yuzey|--depo|--sonuc|--olcum|--sinif|--soz|--kapandi|--tarih|--kip|--baslik|--ozet|--kutu|--atanan|--oturum|--duzeltme) [ $# -ge 2 ] || { echo "HATA: $1 değer ister" >&2; exit 2; } ;; esac
  case "$1" in
    --taze-gun) TAZE_GUN="${2:-}"; shift 2 ;; --birlesme) BIRLESME="${2:-}"; shift 2 ;; --yuzey) YUZEY="${2:-}"; shift 2 ;; --depo) DEPO="${2:-}"; shift 2 ;;
    --sonuc) SONUC="${2:-}"; shift 2 ;; --olcum) OLCUM="${2:-}"; shift 2 ;; --sinif) SINIF="${2:-}"; shift 2 ;; --soz) SOZ="${2:-}"; shift 2 ;;
    --kapandi) KAPANDI="${2:-}"; shift 2 ;; --tarih) TARIH="${2:-}"; shift 2 ;;
    --kip) KIP="${2:-}"; shift 2 ;; --baslik) BASLIK_ARG="${2:-}"; shift 2 ;; --ozet) OZET_ARG="${2:-}"; shift 2 ;; --kutu) KUTU_ARG="${2:-}"; shift 2 ;; --atanan) ATANAN_ARG="${2:-}"; shift 2 ;;
    --oturum) OTURUM="${2:-}"; shift 2 ;; --duzeltme) DUZELTME="${2:-}"; shift 2 ;;
    *) echo "bilinmeyen: $1" >&2; kullanim ;;
  esac
done
if [ "$KOMUT" = ac ]; then case "$KIP" in otomatik|seansli) ;; *) echo "HATA: ac --kip otomatik|seansli ister (verilen: '${KIP}') — doğan görevin açılış adımı kipi söyler" >&2; exit 2 ;; esac; fi
case "$TAZE_GUN" in ''|*[!0-9]*) echo "HATA: --taze-gun pozitif tam sayı olmalı (verilen: '$TAZE_GUN')" >&2; exit 2 ;; esac
[ "$TAZE_GUN" -ge 1 ] || { echo "HATA: --taze-gun en az 1" >&2; exit 2; }
[ -x "$GOREV" ] || [ -f "$GOREV" ] || { echo "ÖLÇÜLEMEDİ: gorev.sh yok ($GOREV)" >&2; exit 3; }
tarih_mi() { printf '%s' "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; }
# YÜZEY = sorunun yaşadığı dosya/dizin (DALGIÇ ön-göz tur 1: birleşme ölçümü bayrağa bağlıydı, sirada-bak yolunda hiç ölçülmüyordu).
#   dogrula 'var' yazarken yüzeyi MUTLAK yol olarak adıma koyar (yüzey=<yol>); durum bayraksız çağrıda onu kayıttan okur. '-' = kod yüzeyi yok (açık beyan).
yuzey_mutlak() { python3 -c 'import os,sys; y,d=sys.argv[1:3]; print(os.path.abspath(y if os.path.isabs(y) or not d else os.path.join(d,y)))' "$1" "${DEPO:-}"; }
yuzey_kok() { local d="$1"; while [ ! -d "$d" ] && [ "$d" != / ]; do d="$(dirname "$d")"; done; git -C "$d" rev-parse --show-toplevel 2>/dev/null; }
# birlesme_olc <mutlak yol> → stdout: son commit günü (boş = yüzeye hiç commit yok) · rc 3 ölçülemedi. Dal: HASAT_DAL, yoksa origin/main, yoksa HEAD.
#   DALGIÇ tur 2: (a) yerel origin/main bayat olabilir → origin varsa önce fetch; düşerse ÖLÇÜLEMEDİ (bayat kopyadan "birleşme yok" denmez; HASAT_FETCH=0 kapatır).
#   (b) hiç commit yok VE yol diskte yok = yanlış/uydurma yüzey → ÖLÇÜLEMEDİ ("birleşme yok" sayılmaz). Silinmiş dosyanın silme commit'i vardır, boş dönmez.
birlesme_olc() { local kok ref gun; kok="$(yuzey_kok "$1")" && [ -n "$kok" ] || return 3
  ref="${HASAT_DAL:-}"
  if [ -z "$ref" ] && git -C "$kok" remote get-url origin >/dev/null 2>&1; then
    if [ "${HASAT_FETCH:-1}" != 0 ]; then timeout 60 git -C "$kok" fetch -q origin main 2>/dev/null || return 3; fi
    ref=origin/main
  fi
  [ -n "$ref" ] || ref=HEAD
  gun="$(git -C "$kok" log -1 --format=%cs "$ref" -- "$1" 2>/dev/null)" || return 3
  [ -n "$gun" ] || [ -e "$1" ] || return 3
  printf '%s\n' "$gun"; }

# ── dogrula: ölçümü kayda yaz ────────────────────────────────────────────────────────────────────────────────────────────
if [ "$KOMUT" = dogrula ]; then
  case "$SONUC" in var|duzelmis|olculemedi) ;; *) echo "HATA: --sonuc var|duzelmis|olculemedi (verilen: '$SONUC')" >&2; exit 2 ;; esac
  [ -n "$(printf '%s' "$OLCUM" | tr -d '[:space:]')" ] || { echo "HATA: --olcum \"<komut ya da dosya yolu>\" ister — ölçümsüz doğrulama yazılmaz" >&2; exit 2; }
  case "$SINIF" in olcum|pr|ci|canli|kare) ;; *) echo "HATA: --sinif olcum|pr|ci|canli|kare (verilen: '$SINIF')" >&2; exit 2 ;; esac
  [ -n "$TARIH" ] || TARIH="$BUGUN"; tarih_mi "$TARIH" || { echo "HATA: tarih YYYY-MM-DD olmalı (verilen: '$TARIH')" >&2; exit 2; }
  if [ "$SONUC" = duzelmis ]; then [ -n "$(printf '%s' "$KAPANDI" | tr -d '[:space:]')" ] || { echo "HATA: düzelmiş bulgu hangi işle kapandığını söyler: --kapandi \"PR #N | commit | iş adı\" ZORUNLU" >&2; exit 2; }
  elif [ -n "$KAPANDI" ]; then echo "HATA: --kapandi yalnız --sonuc duzelmis ile" >&2; exit 2; fi
  if [ "$SONUC" = var ] && [ -z "$YUZEY" ]; then echo "HATA: 'var' ölçümü sorunun yaşadığı yüzeyi ister: --yuzey <dosya|dizin> (kod yüzeyi yoksa --yuzey -) — birleşme sonradan bu yüzeyde ölçülür" >&2; exit 2; fi
  if [ -n "$YUZEY" ] && [ "$YUZEY" != "-" ]; then
    YUZEY="$(yuzey_mutlak "$YUZEY")"; [ -e "$YUZEY" ] || { echo "HATA: yüzey diskte yok ($YUZEY) — sorunun yaşadığı var olan dosya/dizini ver (yanlış yol sonradan 'birleşme yok' sayılmasın)" >&2; exit 2; }
    [ -n "$(yuzey_kok "$YUZEY")" ] || { echo "HATA: yüzey bir git deposunda değil ($YUZEY) — birleşmesi ölçülemez; doğru yolu ver ya da --yuzey -" >&2; exit 2; }
  fi
  case "$SONUC" in var) HUKUM="var";; duzelmis) HUKUM="düzelmiş";; *) HUKUM="ölçülemedi";; esac
  # Alan sırası (DALGIÇ tur 3): tarih= ve yüzey= kullanıcı yazısı olan ölçüm/sözden ÖNCE; okuyucu ' · ' parçalarında TAM eşleşen ilk parçayı alır
  #   → '--olcum "grep tarih=2020-01-01 …"' son doğrulama tarihini bozamaz.
  METIN="[doğrulama: $HUKUM] sınıf=$SINIF · tarih=$TARIH"
  [ -z "$YUZEY" ] || METIN="$METIN · yüzey=$YUZEY"
  METIN="$METIN · ölçüm: $OLCUM"
  [ "$SONUC" != duzelmis ] || METIN="$METIN · kendiliğinden kapandı: $KAPANDI"
  [ -z "$SOZ" ] || METIN="$METIN · $SOZ"
  bash "$GOREV" adim "$ID" "$METIN" || { echo "KIRMIZI: doğrulama adımı yazılamadı (gorev.sh adim rc $?)" >&2; exit 1; }
  echo "DOGRULAMA=$SONUC"; echo "DOGRULAMA_TARIH=$TARIH"
  if [ "$SONUC" = duzelmis ]; then
    bash "$GOREV" durum "$ID" iptal "kendiliğinden kapandı — $KAPANDI${SOZ:+: $SOZ}" || { echo "KIRMIZI: kayıt kapatılamadı (gorev.sh durum rc $?) — doğrulama adımı yazıldı, kapanış yazılmadı" >&2; exit 1; }
    echo "KAPANDI=$KAPANDI"
  fi
  exit 0
fi

# ── durum / ac: kaydı oku, kapıyı ölç ────────────────────────────────────────────────────────────────────────────────────
# Kayıt okuma bu betikte yaşar (gorev.sh paket kopyasıdır, cloudtop kanoniğiyle bayt eş kalmalı — gorev-yolu.test Y7). Aynı uç ve jeton.
#   Çıktı: KAYIT<TAB>id<TAB>durum<TAB>atanan<TAB>başlık<TAB>kutu<TAB>özet · ADIM<TAB>ts<TAB>metin. HASAT_KAYIT_OKU=<betik> verilirse (sınav) o betik <id> ile çağrılır.
kayit_oku() {
  if [ -n "${HASAT_KAYIT_OKU:-}" ]; then bash "$HASAT_KAYIT_OKU" "$1"; return $?; fi
  local jy="${DEFTER_JETON_YOL:-/config/defter-jeton}" uc="${DEFTER_UC:-http://cloudtop-defter:8791}"
  [ -r "$jy" ] || { echo "defter jetonu okunamıyor ($jy)" >&2; return 3; }
  curl -sS -m 15 -H "x-defter-jeton: $(tr -d '\n' < "$jy")" "$uc/kayit/$1" -w '\n%{http_code}' | python3 -c '
import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
if kod!="200": print("kayıt okunamadı http=%s" % kod, file=sys.stderr); sys.exit(3)
k=json.loads(g).get("kayit") or {}; c=k.get("canli",{}); tm=lambda s: str(s).replace("\t"," ").replace("\n"," ")
print("KAYIT\t%s\t%s\t%s\t%s\t%s\t%s" % (k.get("id",""), tm(c.get("gorev_durumu","")), tm(c.get("atanan","-")), tm((k.get("adlar") or [{}])[-1].get("deger","")), tm(c.get("kutu","")), tm(c.get("ozet_sultan",""))))
for a in k.get("adimlar",[]): print("ADIM\t%s\t%s" % (tm(a.get("ts","")), tm(a.get("deger",""))))'
}
KAYIT="$(kayit_oku "$ID" 2>/dev/null)"; KRC=$?
[ "$KRC" -eq 0 ] && [ -n "$KAYIT" ] || { echo "ÖLÇÜLEMEDİ: kayıt okunamadı (rc=$KRC) — 'hasat olur' DENMEZ" >&2; exit 3; }
# ── cevap: Seanslı Hasat'ın üç cevabını havuz kaydına adım yaz (kapı ölçülmez: cevap Sultan'ındır, kapı açılışta koşar) ──
if [ "$KOMUT" = cevap ]; then
  [ -n "$(printf '%s' "$OTURUM" | tr -d '[:space:]')" ] && [ -n "$(printf '%s' "$SOZ" | tr -d '[:space:]')" ] || { echo "⛔ A06: --oturum (ref) ve --soz (Sultan'ın verbatim sözü) zorunlu; cevap yazılmadı" >&2; exit 2; }
  if [ "$CEVAP" = duzeltmeyle-kabul ]; then [ -n "$(printf '%s' "$DUZELTME" | tr -d '[:space:]')" ] || { echo "HATA: duzeltmeyle-kabul Sultan'ın düzelttiği cümleyi ister: --duzeltme \"…\"" >&2; exit 2; }
  elif [ -n "$DUZELTME" ]; then echo "HATA: --duzeltme yalnız duzeltmeyle-kabul ile" >&2; exit 2; fi
  DURUM_C="$(printf '%s\n' "$KAYIT" | python3 -c 'import sys
for s in sys.stdin:
    p=s.rstrip("\n").split("\t")
    if p[0]=="KAYIT" and len(p)>=3: print(p[2]); break')"
  [ "$DURUM_C" = havuz ] || { echo "HATA: kayıt havuzda değil (durum: ${DURUM_C:-?}) — Seanslı Hasat yalnız havuz kaydına sorulur" >&2; exit 1; }
  case "$CEVAP" in kabul) AD_C="kabul";; baska-sun) AD_C="başka sun";; *) AD_C="düzeltmeyle kabul";; esac
  METIN_C="[Seanslı Hasat] $AD_C"
  [ -z "$DUZELTME" ] || METIN_C="$METIN_C · düzeltme: \"$DUZELTME\""
  METIN_C="$METIN_C · D1 $BUGUN Sultan: $AD_C (sohbet · $OTURUM · \"$SOZ\" · beyan:${AGENT_NAME:-REİS})"
  bash "$GOREV" adim "$ID" "$METIN_C" || { echo "KIRMIZI: cevap adımı yazılamadı (gorev.sh adim rc $?)" >&2; exit 1; }
  echo "CEVAP=$AD_C"; echo "KAYIT=$ID"
  exit 0
fi
[ -z "$YUZEY" ] || [ -z "$BIRLESME" ] || { echo "HATA: --birlesme ile --yuzey birlikte olmaz" >&2; exit 2; }
YKAYNAK="bayrak"
if [ -z "$YUZEY" ] && [ -z "$BIRLESME" ]; then   # bayraksız: yüzey SON doğrulama adımından okunur
  YUZEY="$(printf '%s\n' "$KAYIT" | python3 -c '
import sys,re; y=""
for s in sys.stdin:
    p=s.rstrip("\n").split("\t")
    if p[0]=="ADIM" and len(p)>=3 and re.match(r"\[doğrulama: (var|düzelmiş|ölçülemedi)\]","\t".join(p[2:])):
        y=next((x[len("yüzey="):] for x in "\t".join(p[2:]).split(" · ") if x.startswith("yüzey=")), "")
print(y)')"; YKAYNAK="kayıt"
fi
BIRLESME_BEYAN=""
if [ "$YUZEY" = "-" ]; then BIRLESME_BEYAN="beyan"
elif [ -n "$YUZEY" ]; then
  [ "$YKAYNAK" = kayıt ] || YUZEY="$(yuzey_mutlak "$YUZEY")"
  BIRLESME="$(birlesme_olc "$YUZEY")" || {
    echo "KAYIT=$ID"; echo "YUZEY=$YUZEY"; echo "BIRLESME=ÖLÇÜLEMEDİ"; echo "HASAT=ÖLÇÜLEMEDİ"; echo "NEDEN=yüzeyin birleşme tarihi ölçülemedi ($YUZEY: git okunamadı, uzak depo tazelenemedi ya da yol hiç var olmamış) — birleşme yok DENMEZ; --birlesme ile tarihi ver ya da yüzeyi düzeltip yeniden ölç"; exit 3; }
  # yüzeye hiç commit yoksa boş döner: birleşme yok (ölçüldü, uydurulmadı)
elif [ -z "$BIRLESME" ]; then BIRLESME_BEYAN="yok"   # son doğrulamada yüzey yok (eski biçim / elle yazılmış): birleşme ölçülemez
fi
[ -z "$BIRLESME" ] || tarih_mi "$BIRLESME" || { echo "HATA: --birlesme YYYY-MM-DD olmalı (verilen: '$BIRLESME')" >&2; exit 2; }
PY="$(cat <<'PYKOD'
import sys, re, datetime
gid, bugun, gun, birlesme, beyan = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
durum = "?"; son = None   # son doğrulama: (hüküm, tarih-metni)
for s in sys.stdin:
    p = s.rstrip("\n").split("\t")
    if p[0] == "KAYIT" and len(p) >= 3: durum = p[2] or "?"; continue
    if p[0] != "ADIM" or len(p) < 3: continue
    ts, metin = p[1], "\t".join(p[2:])
    m = re.match(r"\[doğrulama: (var|düzelmiş|ölçülemedi)\]", metin)
    if not m: continue
    t = next((x[6:] for x in metin.split(" · ") if re.fullmatch(r"tarih=\d{4}-\d{2}-\d{2}", x)), "")   # tam parça, ilk (yazıcı ölçümden önce koyar)
    son = (m.group(1), t or (ts[:10] if re.match(r"\d{4}-\d{2}-\d{2}", ts) else ""))
def cik(dog, tarih, yas, hasat, neden): print("\t".join([durum, dog, tarih or "-", str(yas) if yas is not None else "-", hasat, neden])); sys.exit(0)
if son is None: cik("yok", "", None, "OLMAZ", "doğrulama yok: bulgu ölçülmeden hasat edilmez → bash hasat.sh dogrula %s --sonuc var|duzelmis|olculemedi --olcum \"<komut>\"" % gid)
dog, tarih = son
try: bg = datetime.date.fromisoformat(bugun)
except Exception: cik(dog, tarih, None, "ÖLÇÜLEMEDİ", "bugünün tarihi okunamadı (GUNLUK_PLAN_TARIH='%s')" % bugun)
if dog == "düzelmiş": cik("duzelmis", tarih, None, "OLMAZ", "son ölçüm 'düzelmiş': bulgu hasat edilmez, kapanır (hasat.sh dogrula --sonuc duzelmis --kapandi … kaydı kapatır)")
if dog == "ölçülemedi": cik("olculemedi", tarih, None, "OLMAZ", "son ölçüm 'ölçülemedi': hasat için 'var' ölçümü gerekir → yeniden ölç")
if not tarih: cik("var", "", None, "ÖLÇÜLEMEDİ", "son doğrulamanın tarihi okunamadı (adımda tarih= yok, zaman damgası da yok) — taze DENMEZ, yeniden ölç")
try: dt = datetime.date.fromisoformat(tarih)
except Exception: cik("var", tarih, None, "ÖLÇÜLEMEDİ", "son doğrulamanın tarihi bozuk ('%s') — yeniden ölç" % tarih)
yas = (bg - dt).days
if yas < 0: cik("var", tarih, yas, "ÖLÇÜLEMEDİ", "son doğrulama gelecek tarihli (%s, bugün %s) — saat kayması ya da bozuk veri; yeniden ölç" % (tarih, bugun))
if durum != "havuz": cik("var", tarih, yas, "OLMAZ", "kayıt havuzda değil (durum: %s) — hasat yalnız havuz kaydını göreve çevirir" % durum)
if yas > gun: cik("var", tarih, yas, "OLMAZ", "son doğrulama %d gün önce (pencere %d): bayat — yeniden ölçülmeden hasat edilmez" % (yas, gun))
if beyan == "yok": cik("var", tarih, yas, "OLMAZ", "son doğrulamada yüzey yok: birleşme ölçülemez — yeniden ölç ve yüzeyi yaz (hasat.sh dogrula … --yuzey <dosya|dizin>, kod yüzeyi yoksa --yuzey -)")
if birlesme:
    try: bt = datetime.date.fromisoformat(birlesme)
    except Exception: cik("var", tarih, yas, "ÖLÇÜLEMEDİ", "birleşme tarihi bozuk ('%s')" % birlesme)
    if bt >= dt: cik("var", tarih, yas, "OLMAZ", "ilgili yüzeyde doğrulamadan sonra (ya da aynı gün) birleşme var (%s ≥ %s): bulgu düzelmiş olabilir — yeniden ölç" % (birlesme, tarih))
cik("var", tarih, yas, "OLUR", "son doğrulama %d gün önce 'var'%s — hasat edilebilir" % (yas, (" · yüzeyde sonradan birleşme yok" if birlesme else (" · kod yüzeyi yok (beyan)" if beyan == "beyan" else " · yüzeye hiç birleşme yok"))))
PYKOD
)"
IFS=$'\t' read -r DURUM DOG DTARIH YAS HASAT NEDEN < <(printf '%s\n' "$KAYIT" | python3 -c "$PY" "$ID" "$BUGUN" "$TAZE_GUN" "$BIRLESME" "$BIRLESME_BEYAN")
[ -n "${HASAT:-}" ] || { echo "KAYIT=$ID"; echo "HASAT=ÖLÇÜLEMEDİ"; echo "NEDEN=kapı hesabı çıktı vermedi (python3 çöktü ya da bulunamadı) — 'olur' DENMEZ"; exit 3; }
echo "KAYIT=$ID"; echo "DURUM=$DURUM"; echo "DOGRULAMA=$DOG"; echo "DOGRULAMA_TARIH=$DTARIH"; echo "DOGRULAMA_YAS_GUN=$YAS"; echo "YUZEY=${YUZEY:--}"; echo "BIRLESME=${BIRLESME:--}"; echo "TAZE_GUN=$TAZE_GUN"
echo "HASAT=$HASAT"; echo "NEDEN=$NEDEN"
case "$HASAT" in OLUR) ;; OLMAZ) exit 1 ;; *) exit 3 ;; esac
[ "$KOMUT" = ac ] || exit 0
# ── ac: havuz kaydı YERİNDE kalır; ondan YENİ görev doğar (1.20.0) ──
case "$KIP" in otomatik) KIP_AD="Otomatik" ;; *) KIP_AD="Seanslı" ;; esac
KAYIT_SATIRI="$(printf '%s\n' "$KAYIT" | python3 -c 'import sys
for s in sys.stdin:
    p=s.rstrip("\n").split("\t")
    if p[0]=="KAYIT":
        p=(p+["","","","","",""])[:7]; print("\t".join(p[3:7])); break')"
IFS=$'\t' read -r K_ATANAN K_BASLIK K_KUTU K_OZET <<<"$KAYIT_SATIRI"
if [ "$KIP" = seansli ]; then   # Sultan cevabı kayıtta SON Seanslı cevap olarak durmalı; ajan cevap üretmez
  SON_CEVAP="$(printf '%s\n' "$KAYIT" | python3 -c 'import sys
son=""
for s in sys.stdin:
    p=s.rstrip("\n").split("\t")
    if p[0]=="ADIM" and len(p)>=3 and p[2].startswith("[Seanslı Hasat] "): son=p[2][len("[Seanslı Hasat] "):].split(" · ")[0]
print(son)')"
  case "$SON_CEVAP" in "kabul"|"düzeltmeyle kabul") ;; *) echo "KIRMIZI: Seanslı Hasat'ta Sultan'ın kabul cevabı kayıtta yok (son cevap: ${SON_CEVAP:-yok}) — önce: hasat.sh cevap $ID kabul|duzeltmeyle-kabul --oturum <ref> --soz \"<Sultan'ın sözü>\"" >&2; exit 1 ;; esac
fi
BASLIK="${BASLIK_ARG:-$K_BASLIK}"; OZET="${OZET_ARG:-$K_OZET}"; KUTU="${KUTU_ARG:-$K_KUTU}"; ATANAN="${ATANAN_ARG:-}"
[ -n "$ATANAN" ] || { [ "$K_ATANAN" != "-" ] && ATANAN="$K_ATANAN"; }
[ -n "$(printf '%s' "$BASLIK" | tr -d '[:space:]')" ] || { echo "HATA: doğan görev başlığı yok (--baslik ver)" >&2; exit 2; }
[ -n "$(printf '%s' "$OZET" | tr -d '[:space:]')" ] || { echo "HATA: doğan görev özeti yok (--ozet \"<ad (5-10 kelime): açıklama>\" ver; özet kapısı tek cümle, 80 harften kısa ister)" >&2; exit 2; }
[ -n "$KUTU" ] || { echo "HATA: doğan görevin kutusu okunamadı (--kutu ver)" >&2; exit 2; }
EKLE=(ekle "$BASLIK" --kutu "$KUTU" --ozet "$OZET" --kaynak-kim "${AGENT_NAME:-REİS}" --kaynak-nereden "Hasat ($KIP_AD)")
[ -z "$ATANAN" ] || EKLE+=(--atanan "$ATANAN")
CIKTI="$(bash "$GOREV" "${EKLE[@]}" 2>&1)" || { echo "KIRMIZI: doğan görev açılamadı (gorev.sh ekle rc $?): ${CIKTI:0:300}" >&2; exit 1; }
YENI="$(printf '%s\n' "$CIKTI" | grep -oE 'gorev_[0-9A-Z]+' | head -1)"
[ -n "$YENI" ] || { echo "KIRMIZI: doğan görevin kimliği okunamadı (gorev.sh ekle çıktısı: ${CIKTI:0:200}) — havuz kaydına bağ YAZILMADI" >&2; exit 1; }
bash "$GOREV" adim "$YENI" "havuz kaydı $ID'den $KIP_AD Hasat ile açıldı · $GEREKCE · son doğrulama $DTARIH var" || { echo "KIRMIZI: doğan görev $YENI açıldı ama açılış adımı yazılamadı (gorev.sh adim rc $?)" >&2; exit 1; }
bash "$GOREV" dogan "$ID" "$YENI" || { echo "KIRMIZI: doğan görev $YENI açıldı ama havuz kaydına bağ yazılamadı (gorev.sh dogan rc $?) — elle: gorev.sh dogan $ID $YENI" >&2; exit 1; }
echo "HAVUZ_KAYDI=$ID (yerinde, durum havuz)"; echo "DOGAN=$YENI"; echo "KIP=$KIP_AD Hasat"
