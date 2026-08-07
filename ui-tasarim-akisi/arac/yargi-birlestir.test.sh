#!/usr/bin/env bash
# yargi-birlestir.test.sh — G1 oy-birleştirme zincirinin hermetik sınavı.
# AĞ KULLANMAZ: yargıç yanıtları sentetik üretilir → CI'da koşar, kapıya bağlı değildir.
# Her kapı, ölçülmüş bir zaafı temsil eder; biri düşerse kapı devreye alınmaz.
set -u

ARAC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIRLESTIR="$ARAC/yargi-birlestir.py"
RUBRIK="$ARAC/rubrik/urun-ui-v1.md"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
GECTI=0; KALDI=0

kapi() { # kapi <ad> <beklenen-rc> <komut...>
  local ad="$1" bek="$2"; shift 2
  local cikti rc
  cikti="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$bek" ]; then
    echo "  ✓ $ad (rc=$rc)"; GECTI=$((GECTI + 1))
  else
    echo "  ✗ $ad — beklenen rc=$bek, gelen rc=$rc"; echo "$cikti" | sed 's/^/      /'
    KALDI=$((KALDI + 1))
  fi
  SON_CIKTI="$cikti"
}

icerir() { # icerir <ad> <desen>
  if printf '%s' "$SON_CIKTI" | grep -qF -- "$2"; then
    echo "  ✓ $1"; GECTI=$((GECTI + 1))
  else
    echo "  ✗ $1 — çıktıda yok: $2"; KALDI=$((KALDI + 1))
  fi
}

icermez() {
  if printf '%s' "$SON_CIKTI" | grep -qF -- "$2"; then
    echo "  ✗ $1 — çıktıda OLMAMALIYDI: $2"; KALDI=$((KALDI + 1))
  else
    echo "  ✓ $1"; GECTI=$((GECTI + 1))
  fi
}

# ── ekran fikstürü ────────────────────────────────────────────────────────────
mkdir -p "$T/ekran"
cat > "$T/ekran/E1.html" <<'HTML'
<!doctype html><html><body>
<!-- bilesen: Ozet seridi -->
<h1>Bu ay 3 sozlesme yenileniyor</h1>
<p>Toplam 42 kayittan 3 tanesi dikkat istiyor.</p>
<!-- bilesen: Kayit listesi -->
<ul><li>Kayit A</li><li>Kayit B</li></ul>
</body></html>
HTML

# ── yargıç yanıtı üretici (kapının Anthropic-biçimli ham yanıtı) ──────────────
yanit() { # yanit <dizin> <ekran> <yargic> <maddeler-json>
  mkdir -p "$1"
  python3 - "$1/$2__$3.json" "$4" <<'PY'
import json, sys
json.dump({"content": [{"type": "text", "text": sys.argv[2]}], "stop_reason": "end_turn"},
          open(sys.argv[1], "w"))
PY
}

M() { # M <id> <puan> <kanit>  → tek madde
  printf '{"id":"%s","puan":%s,"kanit":"%s","gerekce":"sinav"}' "$1" "$2" "$3"
}
SEMA() { printf '{"maddeler":[%s]}' "$(IFS=,; echo "$*")"; }

Q1="Bu ay 3 sozlesme yenileniyor"      # ekranda BİREBİR var
Q2="Toplam 42 kayittan 3 tanesi"       # ekranda BİREBİR var
QX="Bu ekranda asla gecmeyen cumle"    # UYDURMA

echo "── 1 · temiz küme: hiçbir madde düşmüyor → rc=0"
D="$T/y-temiz"
for J in kimi glm qwen; do
  yanit "$D" E1 "$J" "$(SEMA "$(M M1 2 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q2")" \
                            "$(M M4 2 "$Q2")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q2")")"
done
kapi "temiz küme rc=0" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran"
icerir "hüküm KIRMIZI-DEĞİL" "HÜKÜM: KIRMIZI-DEĞİL"

echo "── 2 · kırmızı çizgi: geçerli-alıntılı TEK 0, diğer ikisi 2 → madde 0"
D="$T/y-cizgi"
yanit "$D" E1 kimi "$(SEMA "$(M M1 0 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q1")" "$(M M4 2 "$Q1")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q1")")"
yanit "$D" E1 glm  "$(SEMA "$(M M1 2 "$Q2")" "$(M M2 2 "$Q2")" "$(M M3 2 "$Q2")" "$(M M4 2 "$Q2")" "$(M M5 2 "$Q2")" "$(M M6 2 "$Q2")")"
yanit "$D" E1 qwen "$(SEMA "$(M M1 2 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q1")" "$(M M4 2 "$Q1")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q1")")"
kapi "tek 0 madde-0 yapar, ekran RED değil (1<3)" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran"
icerir "M1 düşürüldü" "↓ M1"

echo "── 3 · alıntı kapısı: UYDURMA alıntılı 0 sayılmaz"
D="$T/y-uydurma"
yanit "$D" E1 kimi "$(SEMA "$(M M1 0 "$QX")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q1")" "$(M M4 2 "$Q1")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q1")")"
yanit "$D" E1 glm  "$(SEMA "$(M M1 2 "$Q2")" "$(M M2 2 "$Q2")" "$(M M3 2 "$Q2")" "$(M M4 2 "$Q2")" "$(M M5 2 "$Q2")" "$(M M6 2 "$Q2")")"
yanit "$D" E1 qwen "$(SEMA "$(M M1 2 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q1")" "$(M M4 2 "$Q1")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q1")")"
kapi "uydurma alıntı hükmü düşürmez" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran"
icermez "M1 düşmedi" "↓ M1"
icerir "karnede alıntı-düşen sayıldı" "5/1"

echo "── 4 · RED: 3 madde 0 → rc=1"
D="$T/y-red"
for J in kimi glm qwen; do
  yanit "$D" E1 "$J" "$(SEMA "$(M M1 0 "$Q1")" "$(M M2 0 "$Q1")" "$(M M3 0 "$Q2")" \
                            "$(M M4 2 "$Q2")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q2")")"
done
kapi "3 düşen madde → RED rc=1" 1 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran" --json "$T/red.json"
icerir "hüküm RED" "HÜKÜM: RED"

echo "── 5 · imza: sayısal puan İMZAYA GİRMEZ (dönme-freni sakatlanmasın)"
kapi "imza okunuyor" 0 python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
assert d["imza"]==["E1:M1","E1:M2","E1:M3"], d["imza"]
assert all(not any(ch.isdigit() and ch not in "123456" for ch in s) for s in d["imza"])
assert "puan" not in json.dumps(d["imza"])
print("imza:", d["imza"])' "$T/red.json"

echo "── 6 · yeter sayı: ayakta <2 oy → EMİN-DEĞİLİM, rc=2 (unknown ≠ pass)"
D="$T/y-yetersiz"
yanit "$D" E1 kimi "$(SEMA "$(M M1 2 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q1")" "$(M M4 2 "$Q1")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q1")")"
kapi "tek yargıç → rc=2" 2 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran"
icerir "hüküm EMİN-DEĞİLİM" "EMİN-DEĞİLİM"

echo "── 7 · parse kapısı: şemasız cevap düşer (çıktı bozulması)"
D="$T/y-bozuk"
yanit "$D" E1 kimi "Tabii, bu ekran bence gayet iyi görünüyor."
yanit "$D" E1 glm  "$(SEMA "$(M M1 2 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q1")" "$(M M4 2 "$Q1")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q1")")"
yanit "$D" E1 qwen "$(SEMA "$(M M1 2 "$Q2")" "$(M M2 2 "$Q2")" "$(M M3 2 "$Q2")" "$(M M4 2 "$Q2")" "$(M M5 2 "$Q2")" "$(M M6 2 "$Q2")")"
kapi "bozuk cevap düşer, kalan 2 oy yeter" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran"
icerir "karnede parse-düşen görünür" "0/1"

echo "── 8 · medyan AŞAĞI yuvarlar (ortalama değil)"
D="$T/y-medyan"
yanit "$D" E1 kimi "$(SEMA "$(M M1 1 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q1")" "$(M M4 2 "$Q1")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q1")")"
yanit "$D" E1 glm  "$(SEMA "$(M M1 2 "$Q2")" "$(M M2 2 "$Q2")" "$(M M3 2 "$Q2")" "$(M M4 2 "$Q2")" "$(M M5 2 "$Q2")" "$(M M6 2 "$Q2")")"
kapi "2 oy [1,2] → medyan 1" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran" --json "$T/med.json"
kapi "M1=1 doğrulandı" 0 python3 -c '
import json,sys
p=json.load(open(sys.argv[1]))["ekranlar"]["E1"]["puanlar"]
assert p["M1"]==1, p; print("M1 =", p["M1"])' "$T/med.json"

echo "── 9 · MÜHÜR: rubrik sha uyuşmazsa koşu REDDEDİLİR"
kapi "yanlış mühür → rc=2" 2 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$T/y-temiz" \
     --ekran-dir "$T/ekran" --muhur "0000000000000000000000000000000000000000000000000000000000000000"
icerir "mühür uyuşmazlığı bildirildi" "MÜHÜR UYUŞMAZLIĞI"
SHA="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$RUBRIK")"
kapi "doğru mühür → geçer" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$T/y-temiz" \
     --ekran-dir "$T/ekran" --muhur "$SHA"

echo "── 10 · rubriksiz koşu 'temiz' sayılmaz → rc=2"
kapi "rubrik yok → rc=2" 2 python3 "$BIRLESTIR" --rubrik "$T/yok.md" --yanit "$T/y-temiz" --ekran-dir "$T/ekran"
icerir "yargı yapılmadı denir" "Yargı yapılmadı"

echo "── 11 · yanıt yok → rc=2 (sessiz yeşil yok)"
mkdir -p "$T/y-bos"
kapi "boş yanıt dizini → rc=2" 2 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$T/y-bos" --ekran-dir "$T/ekran"

echo "── 12 · tescil kolu: --katman2 sözcesi üretilir"
kapi "tescil sözcesi (RED→KALDI)" 1 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$T/y-red" \
     --ekran-dir "$T/ekran" --tescil-g G3
icerir "katman2 KALDI" "--katman2 G3=KALDI"
kapi "tescil sözcesi (temiz→GECTI)" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$T/y-temiz" \
     --ekran-dir "$T/ekran" --tescil-g G3
icerir "katman2 GECTI" "--katman2 G3=GECTI"

echo "── 13 · panel süzgeci: --panel dışındaki yargıç sayılmaz"
kapi "panel=kimi,glm → qwen'in 0'ı sayılmaz" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" \
     --yanit "$T/y-cizgi" --ekran-dir "$T/ekran" --panel glm,qwen
icermez "kimi'nin M1=0'ı panelde yok" "↓ M1"

echo "── 14 · ekran HTML'i yoksa oy sayılmaz (alıntı doğrulanamaz)"
D="$T/y-oksuz"
yanit "$D" YOKEKRAN kimi "$(SEMA "$(M M1 0 "$Q1")")"
kapi "öksüz yanıt → rc=2" 2 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ekran"
icerir "ekran HTML'i yok uyarısı" "ekran HTML'i bulunamadı"

echo
echo "TOPLAM: $GECTI geçti · $KALDI kaldı"
[ "$KALDI" -eq 0 ]
