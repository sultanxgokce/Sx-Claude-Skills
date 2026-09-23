#!/usr/bin/env bash
# denetci.sh — fabrika 4. adım: BAĞIMSIZ GÖZ. Yazandan FARKLI model diff + iş kartı + kanıt manifestini inceler,
# puanı iki satır verir (kod 0-5 · doğru şey E/H), sonucu DENETIM-<tur>.json'a ARAÇ yazar; dönüş tavanını uygular.
#
# Kurallar (Sultan K1/K4, 21-22 Eyl 2026):
#   · denetleyen model yazanla AYNI OLAMAZ (Claude→Codex, Codex→Claude; --denetci ile açıkça seçilebilir)
#   · kanıt yoksa ya da manifest bozuksa denetim AÇILMAZ (rc=2) — "kanıtsız adım 4 yok"
#   · tavan 3 tur; ilerleyen işe (puan↑ VE açık bulgu↓) +1; DÖRT mutlak → sonrası "tıkandı + üç yol" (rc=4)
#   · --sultan-devam "<gerekçe>" : Sultan "devam" dediyse "ilerlemiyor" hükmünü aşar (MUTLAK tavanı AÇMAZ).
#     Gerekçe ≥20 karakter, <depo>/_agents/fabrika/tavan-defteri.log'a yazılır, gün sonu özetinde görünür.
#
# Kullanım:
#   denetci.sh <iş> (--pr N | --diff DOSYA) [--kart DOSYA] [--yazan claude|codex] [--denetci auto|codex|claude]
#              [--model AD] [--depo KÖK]
# rc: 0 GEÇTİ (5+E) · 1 adım 2'ye dön · 2 kanıt yok/bozuk · 3 denetçi ölçemedi (çıktı geçersiz) · 4 tıkandı (tavan)
# Ortam: DENETCI_KOMUT — denetçiyi değiştirir (sınav için): <komut> <istem-dosyası> → stdout'a JSON
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEMA="$HERE/../sablon/denetim-sema.json"
ISTEM="$HERE/../adimlar/denetci-istem.md"
TAVAN=3; MUTLAK=4

_hata() { printf '✗ %s\n' "$*" >&2; }
_bilgi() { printf '%s\n' "$*"; }

IS=""; PR=""; DIFF=""; KART=""; YAZAN="claude"; DENETCI="auto"; MODEL=""; DEPO="${KANIT_DEPO:-}"; SULTAN_DEVAM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="$2"; shift 2 ;; --diff) DIFF="$2"; shift 2 ;; --kart) KART="$2"; shift 2 ;;
    --yazan) YAZAN="$2"; shift 2 ;; --denetci) DENETCI="$2"; shift 2 ;; --model) MODEL="$2"; shift 2 ;;
    --depo) DEPO="$2"; shift 2 ;;
    --sultan-devam) SULTAN_DEVAM="$2"; shift 2 ;;
    -h|--help) sed -n '1,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [ -z "$IS" ] && IS="$1" || { _hata "tanınmayan argüman: $1"; exit 1; }; shift ;;
  esac
done
[ -n "$IS" ] || { _hata "iş adı gerekiyor"; exit 1; }
[ -n "$PR$DIFF" ] || { _hata "--pr N ya da --diff DOSYA gerekiyor"; exit 1; }
[ -n "$DEPO" ] || DEPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[ -n "$DEPO" ] || { _hata "depo kökü bulunamadı"; exit 3; }
DZ="$DEPO/_agents/fabrika/kanit/$IS"

# ── 1 · kanıt kapısı ─────────────────────────────────────────────────────────────
KANIT_CIKTI="$(KANIT_DEPO="$DEPO" python3 "$HERE/kanit.py" dogrula "$IS" 2>&1)"; KRC=$?
case "$KRC" in
  0) KANIT_DURUM="sağlam (araç imzalı, sha'lar tutuyor)" ;;
  1) _hata "kanıt manifesti BOZUK (elle yazılmış ya da dosya değişmiş) — denetim açılmaz"; printf '%s\n' "$KANIT_CIKTI" >&2; exit 2 ;;
  *) _hata "kanıt YOK — 'kanıtsız adım 4 yok'. Önce kanit.sh ile kanıt topla."; exit 2 ;;
esac

# ── 2 · tur ve tavan ─────────────────────────────────────────────────────────────
mkdir -p "$DZ"
ONCEKI=$(ls "$DZ"/DENETIM-*.json 2>/dev/null | wc -l)
TUR=$((ONCEKI+1))
ilerliyor_mu() {  # önceki iki turu kıyasla: puan↑ VE açık bulgu↓
  [ "$ONCEKI" -ge 2 ] || return 1
  python3 - "$DZ" "$ONCEKI" <<'PY'
import json,sys,os
dz,n=sys.argv[1],int(sys.argv[2])
a=json.load(open(os.path.join(dz,f"DENETIM-{n-1}.json")))["sonuc"]; b=json.load(open(os.path.join(dz,f"DENETIM-{n}.json")))["sonuc"]
sys.exit(0 if (b["kod_puani"]>a["kod_puani"] and len(b["bulgular"])<len(a["bulgular"])) else 1)
PY
}
tikandi_raporu() {
  _bilgi ""
  _bilgi "⛔ TIKANDI — $ONCEKI turda 5+E'ye ulaşılamadı (tavan $TAVAN, ilerleyene +1, $MUTLAK mutlak)."
  _bilgi "   Üç yol (karar iş sahibinin/reisin, sınıf işiyse Sultan'ın):"
  _bilgi "   1) DEVAM — gerekçeyle: neden bir tur daha işe yarar?"
  _bilgi "   2) KAPSAMI DARALT — iş kartını küçült, geçen kısmı gönder, kalanı yeni kart"
  _bilgi "   3) GERİ AL — alanı kapat, iş kartına 'tıkandı' damgası, ders deftere"
}
# 🔴 SULTAN KAPISI (23 Eyl 2026): tıkandı raporu "karar sınıf işiyse Sultan'ın" diyordu ama
#    araçta o kararı kabul edecek kapı YOKTU — kural insana havale ediyor, araç insanı dinlemiyordu.
#    Canlı vaka: kapı onarımında puanlar 3·3·2 gitti; düşüşün sebebi işin kötüleşmesi değil,
#    denetçinin her turda DAHA CİDDİ bir kusur bulmasıydı. "ilerliyor_mu" bu ikisini ayırt edemez.
#    Kapı gerekçesiz açılmaz (≥20 karakter), deftere yazılır, gün sonu özetinde Sultan'a görünür.
#    ⚠ MUTLAK tavanı AÇMAZ: dört tur hâlâ mutlaktır. Bu kapı yalnız "ilerlemiyor" hükmünü aşar.
#    ⚠ A06: bu bayrağı yazan ajan Sultan'ın onayını ÜRETMEZ; aldığı onayı AKTARIR. Gerekçe metni
#      denetlenebilir olsun diye deftere düşer — uyduran, defterde yakalanır.
sultan_kapisi() {
  [ -n "$SULTAN_DEVAM" ] || return 1
  if [ "${#SULTAN_DEVAM}" -lt 20 ]; then
    _hata "--sultan-devam GEREKÇE ister (en az 20 karakter) — 'Sultan dedi' tek başına kayıt değildir"
    return 2
  fi
  mkdir -p "$DEPO/_agents/fabrika" 2>/dev/null
  printf '%s | TAVAN-ACILDI | is=%s tur=%s | %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$IS" "$TUR" "$SULTAN_DEVAM" \
    >> "$DEPO/_agents/fabrika/tavan-defteri.log" 2>/dev/null
  _bilgi "⚠ TAVAN AÇILDI (tur $TUR) — Sultan kararı, deftere yazıldı: $SULTAN_DEVAM"
  return 0
}
if [ "$TUR" -gt "$MUTLAK" ]; then _hata "mutlak tavan ($MUTLAK) aşıldı — denetim koşulmadı"; tikandi_raporu; exit 4; fi
if [ "$TUR" -gt "$TAVAN" ]; then
  if ilerliyor_mu; then _bilgi "· tur $TUR: tavan $TAVAN aşıldı ama iş İLERLİYOR (puan↑, bulgu↓) → +1 tur payı"
  else
    sultan_kapisi; sk=$?
    [ "$sk" -eq 2 ] && exit 1
    if [ "$sk" -ne 0 ]; then
      _hata "tavan ($TAVAN) doldu ve iş ilerlemiyor — denetim koşulmadı"; tikandi_raporu
      _bilgi "   Sultan 'devam' dediyse: --sultan-devam \"<en az 20 karakterlik gerekçe>\" (deftere yazılır)"
      exit 4
    fi
  fi
fi

# ── 3 · girdiler ─────────────────────────────────────────────────────────────────
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [ -n "$DIFF" ]; then cp "$DIFF" "$TMP/diff.patch" || { _hata "diff okunamadı"; exit 3; }
else (cd "$DEPO" && gh pr diff "$PR" > "$TMP/diff.patch") || { _hata "gh pr diff $PR düştü"; exit 3; }; fi
if [ -z "$KART" ] && [ -f "$DEPO/_agents/fabrika/kartlar/$IS.json" ]; then KART="$DEPO/_agents/fabrika/kartlar/$IS.json"; fi   # 0. adım kartı varsa o
if [ -n "$KART" ]; then cp "$KART" "$TMP/kart.md"
elif [ -n "$PR" ]; then (cd "$DEPO" && gh pr view "$PR" --json title,body --jq '"# \(.title)\n\n\(.body)"' > "$TMP/kart.md") || echo "(iş kartı okunamadı)" > "$TMP/kart.md"
else echo "(iş kartı verilmedi — talep bilinmiyor; DOĞRU ŞEY Mİ sorusu H'ye yakın değerlendirilir)" > "$TMP/kart.md"; fi
{
  cat "$ISTEM"
  printf '\n\n===== İŞ KARTI (talep) =====\n'; cat "$TMP/kart.md"
  printf '\n\n===== KANIT MANİFESTİ — durum: %s =====\n' "$KANIT_DURUM"; cat "$DZ/KANIT.json"
  printf '\n\n===== ÖLÇÜM ÇIKTILARI (ilk 60 satır/dosya) =====\n'
  for f in "$DZ"/olcum-*.txt; do [ -f "$f" ] && { printf -- '--- %s ---\n' "$(basename "$f")"; head -60 "$f"; }; done
  printf '\n\n===== DEĞİŞİKLİK (diff) =====\n'; cat "$TMP/diff.patch"
  [ "$TUR" -gt 1 ] && { printf '\n\n===== ÖNCEKİ TUR (%s) =====\n' "$ONCEKI"; cat "$DZ/DENETIM-$ONCEKI.json"; }
} > "$TMP/istem.md"

# ── 4 · denetçiyi seç ve koş (yazan ≠ denetleyen) ───────────────────────────────
if [ "$DENETCI" = "auto" ]; then case "$YAZAN" in codex) DENETCI="claude" ;; *) DENETCI="codex" ;; esac; fi
[ "$DENETCI" != "$YAZAN" ] || { _hata "denetleyen ($DENETCI) yazanla ($YAZAN) AYNI — K1 ihlali; --denetci ile farklı model seç"; exit 1; }
HAM="$TMP/ham.json"
if [ -n "${DENETCI_KOMUT:-}" ]; then
  DENETCI_AD="$DENETCI_KOMUT (sınav)"; $DENETCI_KOMUT "$TMP/istem.md" > "$HAM" 2>"$TMP/err"; DRC=$?
elif [ "$DENETCI" = "codex" ]; then
  command -v codex >/dev/null || { _hata "codex yok — denetçi ölçemedi"; exit 3; }
  DENETCI_AD="codex${MODEL:+ ($MODEL)}"
  # İstem ARGÜMAN olarak verilir, dosya olarak değil: bu konteynerde Codex'in kum havuzu (bwrap) ad-alanı
  # açamıyor ve "dosyayı oku" komutu düşüyor (22 Eyl canlı koşum: 2/H "istem.md okunamadı"). Tek argüman
  # sınırı ~128 KB → diff büyükse kırpılır ve istemde SÖYLENİR (sessiz kırpma yok).
  BOYUT=$(wc -c < "$TMP/istem.md")
  if [ "$BOYUT" -gt 120000 ]; then
    head -c 110000 "$TMP/istem.md" > "$TMP/istem-kirpik.md"
    printf '\n\n[UYARI: istem %s bayttı, 110000 baytta KIRPILDI — diff'"'"'in sonu görülmedi; puanı buna göre ver, kırpıldığını özete yaz]\n' "$BOYUT" >> "$TMP/istem-kirpik.md"
    mv "$TMP/istem-kirpik.md" "$TMP/istem.md"; _bilgi "⚠ istem $BOYUT bayt → 110000'e kırpıldı (denetçiye söylendi)"
  fi
  codex exec -s read-only --skip-git-repo-check --ephemeral -C "$TMP" ${MODEL:+-m "$MODEL"} \
    --output-schema "$SEMA" -o "$HAM" "$(printf 'Hiçbir komut koşma, dosya okuma; gereken her şey aşağıda. Talimata göre YALNIZ JSON üret.\n\n'; cat "$TMP/istem.md")" >"$TMP/log" 2>"$TMP/err"; DRC=$?
else
  command -v claude >/dev/null || { _hata "claude yok — denetçi ölçemedi"; exit 3; }
  DENETCI_AD="claude${MODEL:+ ($MODEL)}"
  claude -p ${MODEL:+--model "$MODEL"} --output-format json --json-schema "$(cat "$SEMA")" < "$TMP/istem.md" > "$TMP/claude.json" 2>"$TMP/err"; DRC=$?
  python3 -c "import json,sys;d=json.load(open('$TMP/claude.json'));r=d.get('structured_output') or d.get('result');print(r if isinstance(r,str) else json.dumps(r,ensure_ascii=False))" > "$HAM" 2>/dev/null || cp "$TMP/claude.json" "$HAM"
fi
if [ "$DRC" -ne 0 ]; then _hata "denetçi ($DENETCI_AD) düştü rc=$DRC"; head -5 "$TMP/err" >&2; cp "$HAM" "$DZ/DENETIM-$TUR-HAM.txt" 2>/dev/null; exit 3; fi

# ── 5 · çıktıyı doğrula, kaydet, karar ver ───────────────────────────────────────
# 🔴 Doğrulanmış JSON kabuğa DEĞİŞKEN olarak taşınmaz, DOSYADA kalır. Neden: denetçi Türkçe yazıyor ve
# metindeki kesme işareti python gömmesini kırıyordu (23 Eyl canlı koşum: tur 1 sonucu diske yazıldı ama
# betik JSONDecodeError verdi, ardından "[: : integer expression expected"). Araçlar arası veri dosyadan
# geçer, kabuk alıntısından değil.
DOGRULANMIS="$TMP/sonuc.json"
python3 - "$HAM" "$DOGRULANMIS" <<'PY'
import json,sys,re
ham=open(sys.argv[1],encoding='utf-8').read().strip()
m=re.search(r'\{.*\}',ham,re.S)
try: d=json.loads(m.group(0) if m else ham)
except Exception as e: print("GEÇERSİZ:"+str(e),file=sys.stderr); sys.exit(3)
ok=isinstance(d.get("kod_puani"),int) and 0<=d["kod_puani"]<=5 and d.get("dogru_sey") in("E","H") and isinstance(d.get("bulgular"),list)
if not ok: print("GEÇERSİZ: alanlar eksik/yanlış",file=sys.stderr); sys.exit(3)
for b in d["bulgular"]:
    if not all(k in b for k in("ne","kanit","konum","agirlik")): print("GEÇERSİZ: bulgu alanları eksik",file=sys.stderr); sys.exit(3)
json.dump(d,open(sys.argv[2],"w",encoding="utf-8"),ensure_ascii=False)
PY
SRC=$?
if [ "$SRC" -ne 0 ]; then _hata "denetçi çıktısı geçersiz — ölçemedi"; cp "$HAM" "$DZ/DENETIM-$TUR-HAM.txt"; exit 3; fi
python3 - "$DZ/DENETIM-$TUR.json" "$TUR" "$IS" "$PR" "$YAZAN" "$DENETCI_AD" "$KANIT_DURUM" "$DOGRULANMIS" <<'PY'
import json,sys,datetime
yol,tur,is_,pr,yazan,den,kd,sonuc_yolu=sys.argv[1:]
json.dump({"tur":int(tur),"is":is_,"pr":pr,"yazan":yazan,"denetci":den,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
           "kanit_durumu":kd,"sonuc":json.load(open(sonuc_yolu,encoding="utf-8"))},open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PY
_oku() { python3 -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));print(len(d['bulgular']) if sys.argv[2]=='n' else d[sys.argv[2]])" "$DOGRULANMIS" "$1"; }
PUAN="$(_oku kod_puani)"; DOGRU="$(_oku dogru_sey)"; NB="$(_oku n)"
[ -n "$PUAN" ] && [ -n "$DOGRU" ] || { _hata "puan okunamadı — ölçemedi"; exit 3; }
_bilgi "── DENETİM tur $TUR · denetçi: $DENETCI_AD · yazan: $YAZAN"
_bilgi "   KOD İYİ Mİ: $PUAN/5 · DOĞRU ŞEY Mİ: $DOGRU · bulgu: $NB · kanıt: $KANIT_DURUM"
python3 - "$DOGRULANMIS" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
print("   özet: "+d["ozet"])
for b in d["bulgular"]: print(f"   • [{b['agirlik']}] {b['ne']} — {b['konum']} — kanıt: {b['kanit']}")
PY
_bilgi "   kayıt: $DZ/DENETIM-$TUR.json"
if [ "$PUAN" -eq 5 ] && [ "$DOGRU" = "E" ]; then _bilgi "✓ GEÇTİ — merge kararı: sınıf işi Sultan, sınıfsız iş kutu reisi"; exit 0; fi
if [ "$TUR" -ge "$TAVAN" ]; then
  ONCEKI=$TUR
  if [ "$TUR" -lt "$MUTLAK" ] && ilerliyor_mu; then _bilgi "↩ adım 2'ye dön (tur $TUR/$TAVAN) — iş ilerliyor, +1 tur payı var"; exit 1; fi
  tikandi_raporu; exit 4
fi
_bilgi "↩ adım 2'ye dön: düzelt → yeniden kanıtla → yeniden gönder (tur $TUR/$TAVAN)"; exit 1
