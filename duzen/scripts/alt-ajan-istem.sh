#!/usr/bin/env bash
# alt-ajan-istem.sh — KOLTUKSUZ alt personel (BENNÂ · MÜZEHHİP · ŞAKİRD · ÇAPAR · TATAR · MESSÂH · MEREMMETÇİ · MÜCERRİB · MÜTEFENNİN …)
# için reisin Agent aracına yapıştıracağı TEK istem metnini üretir (yalnız stdout; hiçbir dosyaya yazmaz).
#
# Niçin: koltuksuz personel reisin oturumundan alt ajan olarak doğar ve SIFIR bağlamla başlar (Kuzey Yıldızı 3.3). Bu boşluğu
# el defteri telafi eder; ama kimlik + oda/yetki + defter + iş + kuralları her seferinde elle toplamak hem yavaş hem tutarsızdı
# (ÇIRAK emsali: _agents/cirak/cirak-istem.sh yalnız ÇIRAK'a özeldi). Bu betik her kutuda aynı altı bloğu basar.
#
# Kullanım:
#   alt-ajan-istem.sh <slug> --is "<tek cümle>" [--kart <iş>] [--dosyalar "<a,b>"] [--sure <dk>] [--depo <kutu kökü>]
#     <slug>      _agents/<slug>/AGENT.md (ör. sakird, benna, capar)
#     --is        işin tek cümlesi (kart varsa kartın cümlesi ÖNDE basılır, --is reis özeti olarak eklenir)
#     --kart      <depo>/_agents/fabrika/kartlar/<iş>.json → `cumle` alanı (yoksa `is`); kart okunamazsa uyarır, --is ile devam eder
#     --dosyalar  dokunulabilecek dosyalar (virgülle); verilmezse "sınırlanmadı" yazılır
#     --sure      süre tavanı dakika; verilmezse 120 varsayılır (yazılır)
#     --depo      kutu depo kökü (varsayılan: git toplevel, yoksa cwd)
# Ortam (sınav/elle): DUZEN_EL_DEFTERI_SH = el-defteri.sh yolu (varsayılan yan dosya) · DUZEN_SIMDI = epoch (tarih sabitlenir)
# Bloklar: 1 KİMLİK (AGENT.md `## ELLE` verbatim — ekipc üretilmiş ORTAK-TEMEL bölgesi alınmaz, çok uzun ve zaten tek kaynakta)
#          2 REİS·ODA·YETKİ (aile-registry oda:+amir:, sabit "birleştirme/canlı/host/sır reiste") · 3 EL DEFTERİ (el-defteri.sh çıktısı;
#          rc 3 = "defter boş, ilk görev" uyarısı, istem yine üretilir) · 4 İŞ · 5 DOSYALAR·SÜRE · 6 SABİT KURALLAR.
# Sır: AGENT.md/NOTES'tan gelen satırlarda token|sifre|şifre|parola geçiyorsa satır basılmaz, "[sır satırı süzüldü]" yazılır.
# rc: 0 istem basıldı (uyarılar başlıkta ⚠ ile) · 2 kullanım hatası · 3 kimlik yok (AGENT.md bulunamadı → önce /ise-alim)
set -uo pipefail
export LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SLUG=""; IS=""; KART=""; DOSYALAR=""; SURE=""; DEPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --is) IS="${2:-}"; shift 2 ;;
    --kart) KART="${2:-}"; shift 2 ;;
    --dosyalar) DOSYALAR="${2:-}"; shift 2 ;;
    --sure) SURE="${2:-}"; shift 2 ;;
    --depo) DEPO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    --*) echo "alt-ajan-istem: bilinmeyen seçenek: $1" >&2; exit 2 ;;
    *) [ -z "$SLUG" ] && SLUG="$1" || { echo "alt-ajan-istem: tek slug beklenir ('$SLUG' ve '$1')" >&2; exit 2; }; shift ;;
  esac
done
[ -n "$SLUG" ] || { echo "alt-ajan-istem: slug yok (kullanım: alt-ajan-istem.sh <slug> --is \"…\")" >&2; exit 2; }
[[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "alt-ajan-istem: slug küçük harf/rakam/tire olmalı: '$SLUG'" >&2; exit 2; }
[ -n "$IS" ] || [ -n "$KART" ] || { echo "alt-ajan-istem: iş yok (--is \"<tek cümle>\" ya da --kart <iş>)" >&2; exit 2; }
if [ -n "$SURE" ]; then [[ "$SURE" =~ ^[1-9][0-9]*$ ]] || { echo "alt-ajan-istem: --sure dakika sayısı olmalı: '$SURE'" >&2; exit 2; }; fi
[ -n "$DEPO" ] || DEPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

AGENT="$DEPO/_agents/$SLUG/AGENT.md"
[ -f "$AGENT" ] || { echo "kimlik yok: $AGENT bulunamadı — önce /ise-alim (KÂHYA) ile kimlik üretilir; istem ÜRETİLMEDİ" >&2; exit 3; }

UYARI=()
AN="${DUZEN_SIMDI:-$(date +%s)}"; GUN="$(date -d "@$AN" +%F)"

# ── sır süzgeci: token|sifre|şifre|parola geçen satır basılmaz (büyük/küçük harf duyarsız) ──
SIR_DESEN='token|sifre|şifre|parola'
sir_suz() { awk -v d="$SIR_DESEN" 'BEGIN{IGNORECASE=1} tolower($0) ~ d {print "[sır satırı süzüldü]"; next} {print}'; }

# ── 1) kimlik: ## ELLE bölümü verbatim; yoksa üretilmiş bölge çıkarılmış gövde + uyarı ──
if grep -q '^## ELLE' "$AGENT"; then
  KIMLIK="$(awk '/^## ELLE/{f=1} f' "$AGENT" | sir_suz)"
  KIMLIK_KAYNAK="$AGENT → \`## ELLE\` bölümü (verbatim)"
else
  KIMLIK="$(awk '/ekipc:uretilen:basla/{s=1} !s{print} /ekipc:uretilen:bitti/{s=0}' "$AGENT" | sir_suz)"
  KIMLIK_KAYNAK="$AGENT (\`## ELLE\` başlığı YOK — üretilmiş bölge çıkarıldı, kalan gövde basıldı)"
  UYARI+=("AGENT.md'de '## ELLE' bölümü yok; kimlik gövdeden alındı — kimliği ekipc düzenine almak KÂHYA işi")
fi

# ── 2) reis · oda: aile-registry.yaml'dan kanallar'ı _agents/<slug>/ olan kayıt (yoksa id eşleşmesi) ──
REG="$DEPO/_agents/handoff/aile-registry.yaml"
AD=""; ODA=""; AMIR=""; ROL=""
if [ -f "$REG" ]; then
  KAYIT="$(python3 -I - "$REG" "$SLUG" <<'PY'
import sys, re
yol, slug = sys.argv[1], sys.argv[2]
bloklar = []; cur = None
for l in open(yol, encoding="utf-8"):
    m = re.match(r"^\s*-\s*id:\s*(.+?)\s*(#.*)?$", l)
    if m:
        cur = {"id": m.group(1).strip(), "satirlar": []}; bloklar.append(cur); continue
    if cur is not None and re.match(r"^\s+\w", l): cur["satirlar"].append(l.rstrip("\n"))
def alan(b, k):
    for s in b["satirlar"]:
        m = re.match(r"^\s*%s:\s*(.*?)\s*$" % k, s)
        if m:
            v = m.group(1)
            if not v.startswith(('"', "'")): v = v.split("#", 1)[0].strip()
            return v.strip().strip('"').strip("'")
    return ""
hedef = f"_agents/{slug}/"
sec = next((b for b in bloklar if any(hedef in s for s in b["satirlar"])), None)
if sec is None:
    def sl(a): return re.sub(r"[^a-z0-9-]", "", a.translate(str.maketrans("ÇĞİÖŞÜÂÎÛçğıöşüâîû", "CGIOSUAIUcgiosuaiu")).lower().replace(" ", "-"))
    sec = next((b for b in bloklar if sl(b["id"]) == slug), None)
if sec is None: sys.exit(1)
print(sec["id"]); print(alan(sec, "oda")); print(alan(sec, "amir")); print(alan(sec, "rol"))
PY
)" && { AD="$(sed -n 1p <<<"$KAYIT")"; ODA="$(sed -n 2p <<<"$KAYIT")"; AMIR="$(sed -n 3p <<<"$KAYIT")"; ROL="$(sed -n 4p <<<"$KAYIT")"; } \
    || UYARI+=("aile-registry'de '$SLUG' kaydı yok (kanallar _agents/$SLUG/ ya da id) — oda/amir bilinmiyor, reis kendini yazsın")
else
  UYARI+=("aile kaydı yok: $REG — oda/amir ölçülemedi")
fi
if [ -z "$AD" ]; then
  AD="$(grep -m1 -E '^# [^ ]+ —' <<<"$KIMLIK" | sed -E 's/^# ([^—]+) —.*/\1/; s/[[:space:]]+$//')"
  [ -n "$AD" ] || AD="$(tr '[:lower:]' '[:upper:]' <<<"$SLUG")"
fi
[ -n "$ODA" ] || ODA="?"; [ -n "$AMIR" ] || AMIR="?"

# ── 3) el defteri: el-defteri.sh çıktısı; rc 3 → "defter boş, ilk görev" (istem yine üretilir) ──
ELD="${DUZEN_EL_DEFTERI_SH:-$HERE/el-defteri.sh}"
if [ -f "$ELD" ]; then
  DEFTER_ERR="$(mktemp)"; DEFTER="$(DUZEN_SIMDI="$AN" bash "$ELD" --ajan "$AD" --depo "$DEPO" 2>"$DEFTER_ERR")"; drc=$?
  case $drc in
    0) DEFTER="$(sir_suz <<<"$DEFTER")" ;;
    3) DEFTER="(defter boş, ilk görev — $(head -c200 "$DEFTER_ERR" | tr -d '\n'))"; UYARI+=("el defteri yok (el-defteri.sh rc 3): bu personelin ilk görevi; iş bitince NOTES.md'ye ilk satırı append-note.sh ile yazsın") ;;
    *) DEFTER="(el defteri ölçülemedi: el-defteri.sh rc $drc — $(head -c200 "$DEFTER_ERR" | tr -d '\n'))"; UYARI+=("el-defteri.sh rc $drc ile düştü; defter bloğu boş — ÖLÇÜLEMEDİ, 'defter yok' sayılmaz") ;;
  esac
  rm -f "$DEFTER_ERR"
else
  DEFTER="(el-defteri.sh bulunamadı: $ELD — defter ölçülemedi)"; UYARI+=("el-defteri.sh yok ($ELD); duzen paketi eksik kurulu olabilir")
fi

# ── 4) iş: kart cümlesi (varsa) + --is ──
KART_CUMLE=""
if [ -n "$KART" ]; then
  KJ="$DEPO/_agents/fabrika/kartlar/$KART.json"
  if [ -f "$KJ" ]; then
    KART_CUMLE="$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); print((d.get("cumle") or d.get("is") or "").strip())' "$KJ" 2>/dev/null)" \
      || UYARI+=("kart okunamadı (bozuk JSON): $KJ")
    [ -n "$KART_CUMLE" ] || UYARI+=("kartta cümle yok: $KJ")
  else
    UYARI+=("kart bulunamadı: $KJ — iş yalnız --is cümlesinden")
  fi
fi
[ -n "$KART_CUMLE" ] || [ -n "$IS" ] || { echo "alt-ajan-istem: ne kart cümlesi okunabildi ne --is verildi — iş yok, istem ÜRETİLMEDİ" >&2; exit 2; }

# ── 5) dosyalar · süre ──
[ -n "$SURE" ] || SURE=120
if [ -n "$DOSYALAR" ]; then DOSYA_SATIR="$DOSYALAR (yalnız bunlar; başka dosya gerekirse DUR, reise yaz)"; else DOSYA_SATIR="sınırlanmadı — iş alanını \`is-alani.sh ac <iş> --dosyalar …\` ile açarken dokunacağın dosyaları KENDİN yaz; ürün UI (P07) ve canlı-yazılan dosyalar (aile-registry · NOTES · *.jsonl · Notlarim/) dışarıda"; fi

# ───────────────────────────── çıktı ─────────────────────────────
echo "# ALT AJAN İSTEMİ · $AD ($SLUG) · $GUN · üretici: duzen/scripts/alt-ajan-istem.sh · kutu: $DEPO"
for u in "${UYARI[@]+"${UYARI[@]}"}"; do echo "⚠ $u"; done
cat <<T

## 1 · KİMLİK — sen $AD'sın
Kaynak: $KIMLIK_KAYNAK. Tam kimlik (ORTAK-TEMEL + ELLE) o dosyadadır; şüphede onu oku, ELLE bu istemden üstündür.

$KIMLIK

## 2 · REİS · ODA · YETKİ ÖNCELİĞİ
- Reis (amir): **$AMIR** · Oda: **$ODA** · Kutu deposu: $DEPO${ROL:+
- Kayıtlı rol: $ROL}
- Koltuğun yok: reisin oturumundan alt ajan olarak doğdun, iş bitince kapanırsın. Soruların reise gider, Sultan'a DEĞİL.
- **Birleştirme · canlıya alma · host · sır DEĞERİ reiste kalır.** Sen PR açar, kanıtı bağlar, reise TEK satır dönersin.
- Sınıflı iş (geri alınamaz · para · dış yüzey · yetki) sana gelmez; işin sınıflı çıkarsa DUR ve reise yaz.

## 3 · EL DEFTERİ (sıfır bağlamın telafisi — araç bastı, uydurulmadı)
$DEFTER

## 4 · İŞ
${KART_CUMLE:+- Kart ($KART): $KART_CUMLE
}${IS:+- Reisin cümlesi: $IS
}${KART:+- Kart adı: $KART (kart.sh ac zaten yapıldıysa yeniden açma; yoksa \`kart.sh ac $KART --aldi $AD\`)
}
## 5 · DOSYALAR · SÜRE
- Dokunabileceğin dosyalar: $DOSYA_SATIR
- Süre tavanı: $SURE dk — aşarsan "tıkandı + üç yol" (devam · daralt · geri al) raporuyla reise dön.

## 6 · SABİT KURALLAR
1. **Hat (FABRIKA.md):** KABUL (kart) → İZOLE (is-alani.sh; ana dalda ASLA) → İNŞA → KANITLA (kanit.sh; önce/sonra, boru arkası yok) → GÖNDER (denetci.sh bağımsız göz, tavan 3 tur). Adım atlanmaz.
2. **Sultan-dili:** Sultan'a/deftere görünen her metin jargonsuz Türkçe. Sultan uyuyor olabilir — soru SORMA, Sultan kararı gerektireni raporda listele.
3. **Kanıt:** "çalışıyor / bitti" kanıt değildir; kırpılmamış çıktı + \`; echo exit=\$?\`. Boş çıktı + rc 0 = ÖLÇÜLEMEDİ. Mutant çökünce "yakalandı" sanılmaz.
4. **Ölçmeden hüküm yok:** olumsuz hüküm ("yok · kurulu değil · düştü") İKİ bağımsız yüzey + pozitif kontrol ister; tek yüzeyle yalnız olumlu hüküm.
5. **Sır:** değer çıktıya/dosyaya/nota düşmez; yalnız konum/prosedür konuşulur. Onay alanına (Sultan sözü · GO · DEVAM) ajan yazamaz.
6. **Geçici dosya:** scratchpad'de ve \`alt-ajan-istem-\` önekiyle (dizin öteki alt ajanlarla ortak).
7. **CI:** hiçbir run'ı yeniden koşturma — rerun reisindir. CI'ı \`gh pr checks N --watch\` ile arka planda izle.
8. **Bitince:** \`_agents/$SLUG/NOTES.md\`'ye append-note.sh ile TEK satır (ne yapıldı · PR · kanıt) ve reise tek satır: "$AD: <iş> PR #N · göz <puan> · kapı rc<k>".
T
exit 0
