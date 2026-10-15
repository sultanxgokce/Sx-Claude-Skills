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

# ══ L57/F5 · YARGI KATMANININ FİKSTÜRLERİ VE ÇAĞIRANI ════════════════════════
# Bu bölüme kadar sınav yalnız SENTETİK oylarla zinciri ölçüyordu; hattın kendi
# fikstürleri (ALTIN + KIRMIZI ekran) ya yoktu ya da çağıranı yoktu. Ağ hâlâ
# kullanılmaz: LLM'in yerine ön-kayıtlı oy konur, ölçülen şey ZİNCİRİN o fikstürlere
# verdiği hükümdür.
ISTEK="$ARAC/yargi-istek-yap.py"
KAPI="$ARAC/yogunluk-denetle.py"
FIK="$ARAC/fikstur"
CEK="$ARAC/../cekirdek/sozlesme.md"
YALTIN="$FIK/yargi/altin/E1-bulgu-dili.html"
YKIRMIZI="$FIK/yargi/kirmizi/M2-borc-dili.html"

echo "── 15 · yargı fikstürleri MEKANİK olarak temiz (yargı-kırmızısı anlam boyutundandır)"
kapi "ALTIN mekanik rc=0" 0 python3 "$KAPI" "$FIK/yargi/altin" --profil "$FIK/kapi-profili.json"
kapi "M2 KIRMIZI mekanik rc=0" 0 python3 "$KAPI" "$FIK/yargi/kirmizi" --profil "$FIK/kapi-profili.json"
# NİÇİN: M2 fikstürü önceden fikstur/kirli/ içindeydi; orada mekanik kümeye katılıp X1
# gezinme kirliliği üretiyor, "yargıyı izole ediyorum" iddiasını çürütüyordu.

echo "── 16 · istek gövdesi: ÇEKİRDEK prompta fiilen giriyor mu (M1'in çatalı)"
kapi "gövde kuruldu" 0 python3 "$ISTEK" --rubrik "$RUBRIK" --ekran "$YALTIN" \
     --model "raf/x" --out "$T/govde.json" --cekirdek "$CEK"
PROMPT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["messages"][0]["content"])' "$T/govde.json")"
for AD in "Liste satırı" "Form alanı" "Onay diyaloğu" "Sayfa başlığı"; do
  if printf '%s' "$PROMPT" | grep -qF -- "$AD"; then
    echo "  ✓ çekirdek adı promptta: $AD"; GECTI=$((GECTI + 1))
  else
    echo "  ✗ çekirdek adı promptta YOK: $AD — M1 onu 'sessiz icat' sanar"; KALDI=$((KALDI + 1))
  fi
done
if printf '%s' "$PROMPT" | grep -qF "ÇEKİRDEK SÖZLEŞME"; then
  echo "  ✓ çekirdek bölümü etiketli (yargıç hangi parçanın filo kuralı olduğunu görür)"
  GECTI=$((GECTI + 1))
else
  echo "  ✗ çekirdek bölüm başlığı yok"; KALDI=$((KALDI + 1))
fi
if printf '%s' "$PROMPT" | grep -qF "$(head -c 60 "$YALTIN" | tail -c 20)"; then
  echo "  ✓ ekran gövdesi promptta"; GECTI=$((GECTI + 1))
else
  echo "  ✗ ekran gövdesi promptta yok"; KALDI=$((KALDI + 1))
fi

echo "── 16b · çekirdek okunamazsa gövde YAZILMAZ (yarım sözleşmeyle hüküm istenmez)"
kapi "çekirdeksiz → rc=2" 2 python3 "$ISTEK" --rubrik "$RUBRIK" --ekran "$YALTIN" \
     --model "raf/x" --out "$T/olmaz.json" --cekirdek "$T/yok.md"
if [ ! -f "$T/olmaz.json" ]; then
  echo "  ✓ gövde dosyası hiç oluşmadı"; GECTI=$((GECTI + 1))
else
  echo "  ✗ rc=2 dendi ama gövde YAZILDI — kapıya yarım prompt gidebilir"; KALDI=$((KALDI + 1))
fi

echo "── 17 · ÇİFT YÖNLÜ HÜKÜM: ALTIN ayakta kalır, M2 düşer (aynı oy şeması)"
# M2 alıntısı KIRMIZI ekranda birebir vardır; ALTIN ekranda kendi manşeti alıntılanır.
QK="Bugün 119 iş dikkat istiyor"
QA="Dört sözleşmede fazla ödeme bulundu"
mkdir -p "$T/ek-altin" "$T/ek-kirmizi"
cp "$YALTIN" "$T/ek-altin/E1.html"; cp "$YKIRMIZI" "$T/ek-kirmizi/E1.html"

D="$T/y-yargi-altin"
for J in kimi glm; do
  yanit "$D" E1 "$J" "$(SEMA "$(M M1 2 "$QA")" "$(M M2 2 "$QA")" "$(M M3 2 "$QA")" \
                            "$(M M4 2 "$QA")" "$(M M5 2 "$QA")" "$(M M6 2 "$QA")")"
done
kapi "ALTIN → RED değil (rc=0)" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ek-altin"

# EŞİK DÜZELTMESİ (ilk yazdığım iddia YANLIŞTI, kriteri değil testi düzelttim):
# rubrik `red_esigi: 3` diyor — RED için geçerli-alıntılı ÜÇ sıfır gerekir. Tek M2=0
# RED üretmez, üretmemelidir. Aşağıdaki panel rubriğin kendi kalibrasyon kaydındaki üç
# maddeyi kullanır (manşetin öznesi M2 · manşetin evi M4 · payda görünürlüğü M6).
D="$T/y-yargi-kirmizi"
for J in kimi glm; do
  yanit "$D" E1 "$J" "$(SEMA "$(M M1 2 "$QK")" "$(M M2 0 "$QK")" "$(M M3 2 "$QK")" \
                            "$(M M4 0 "$QK")" "$(M M5 2 "$QK")" "$(M M6 0 "$QK")")"
done
kapi "M2 fikstürü → RED (rc=1)" 1 python3 "$BIRLESTIR" --rubrik "$RUBRIK" --yanit "$D" --ekran-dir "$T/ek-kirmizi"
icerir "düşen madde M2" "↓ M2"

echo "── 17b · EŞİK ALTI dürüstlüğü: tek M2=0 RED DEĞİLDİR ama sessiz de geçmez"
D="$T/y-yargi-tekil"
for J in kimi glm; do
  yanit "$D" E1 "$J" "$(SEMA "$(M M1 2 "$QK")" "$(M M2 0 "$QK")" "$(M M3 2 "$QK")" \
                            "$(M M4 2 "$QK")" "$(M M5 2 "$QK")" "$(M M6 2 "$QK")")"
done
kapi "tek sıfır → KIRMIZI-DEĞİL (rc=0)" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" \
     --yanit "$D" --ekran-dir "$T/ek-kirmizi"
icerir "rc=0 olsa da düşen madde raporlanır" "↓ M2"

# ⚠️ ÖLÇÜLMEYENİN İTİRAFI: yukarıdaki oylar ÖN-KAYITLI/sentetiktir (CI ağa çıkmaz).
# Kanıtlanan şey ZİNCİRİN bu fikstürlere verdiği hükümdür; canlı yargıcın M2 fikstürüne
# fiilen 0 verip vermediği burada ÖLÇÜLMEZ — o, `yargi-panel.sh` ile kapıya çıkan
# kalibrasyon koşusunun işidir.

echo "── L57-EK2 · ALTIN: yargı hükmü havuza REFERANS DAMGASIYLA düşer"
#   NİÇİN: kırmızı bir hükmün HANGİ ZEMİNE karşı verildiği kayda geçmezse, hüküm sonradan
#   savunulamaz — geçmiş kayda damga basılamaz. Ölçüm (NAKKAŞ 2026-08-08): tik 5/5 ve
#   yogunluk 5/5 damgalıyken yargi 0/3 idi; iki ayrı havuz-yazıcıdan yalnız biri bayrağı
#   biliyordu (prompt-yap.sh geçiriyor, yargi-birlestir.py geçirmiyordu).
#   Yargının referansı kapı-profili DEĞİL RUBRİKTİR; rubrik sha'sı zaten hesaplanıyor.
#   KIRMIZI yüz zaten var (havuz.test.sh: desene uymayan profil_sha → rc=1); eksik olan
#   ALTIN yüzdü — hatayı gizleyen boşluk tam olarak buydu.
D="$T/y-damga"; HAVUZ="$T/damga.jsonl"
for J in kimi glm qwen; do
  yanit "$D" E1 "$J" "$(SEMA "$(M M1 2 "$Q1")" "$(M M2 2 "$Q1")" "$(M M3 2 "$Q2")" \
                            "$(M M4 2 "$Q2")" "$(M M5 2 "$Q1")" "$(M M6 2 "$Q2")")"
done
kapi "havuza yazan yargı koşumu rc=0" 0 python3 "$BIRLESTIR" --rubrik "$RUBRIK" \
     --yanit "$D" --ekran-dir "$T/ekran" --havuz-kutu sinav --havuz "$HAVUZ"

SON_CIKTI="$(python3 - "$HAVUZ" <<'PY'
import json, re, sys
for satir in open(sys.argv[1], encoding="utf-8"):
    k = json.loads(satir)
    if k.get("kapi") == "yargi":
        s = k.get("profil_sha", "")
        print("DAMGA-VAR" if re.fullmatch(r"[0-9a-f]{12}", s) else "DAMGA-YOK", s)
PY
)"
icerir "yargı kaydı 12-hane referans damgası taşıyor" "DAMGA-VAR"

SON_CIKTI="$(python3 "$ARAC/havuz.py" ozet --havuz "$HAVUZ" 2>&1)"
icermez "damgalı ölçüm 'parmak-izi YOK' sayacına DÜŞMEZ" "profil parmak-izi YOK"

echo
echo "TOPLAM: $GECTI geçti · $KALDI kaldı"
[ "$KALDI" -eq 0 ]
