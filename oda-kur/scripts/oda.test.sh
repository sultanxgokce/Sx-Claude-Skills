#!/usr/bin/env bash
# oda.test.sh — oda-kur sınavı. HERMETİK: geçici sahte iki odalı depo, ağ yok, claude çağrılmaz.
# Mutant kipi: kanca/üretici gevşerse sınav KIRMIZI olmalı (ODA_MUTANT=0 ile kapatılır).
# kabuk-testleri: sure=300
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ODA="$HERE/oda.sh"
G=0; K=0
ok() { G=$((G+1)); echo "  ✓ $1"; }
no() { K=$((K+1)); echo "  ✗ $1${2:+  → $2}"; }
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT

kur_depo() {   # kur_depo <dizin> : iki odalı sahte depo + ortak ayar + ortak veri
  local D="$1"; mkdir -p "$D/.claude" "$D/veri" "$D/scripts"
  cat > "$D/.claude/oda-ortak.json" <<J
{"izin":{"allow":["Bash(git status)"],"deny":["Read(.env)"]},"ortak_veri":["veri/**","KAYIT.json"],"cekirdek_komutlar":["bash scripts/ortak-yaz.sh"]}
J
  echo '{"a":1}' > "$D/KAYIT.json"
  bash "$ODA" yeni "$D" oda-a --reis SERDAR --hedef "A hedefi" --olcu "A ölçüsü" >/dev/null 2>&1
  bash "$ODA" yeni "$D" oda-b --reis BERID --hedef "B hedefi" --olcu "B ölçüsü" >/dev/null 2>&1
}
kanca() {   # kanca <depo> <oda> <araç> <girdi-json> [cwd] → rc
  local D="$1" O="$2" A="$3" I="$4" C="${5:-$1/$2}"
  python3 -I -c "import json,sys;print(json.dumps({'tool_name':sys.argv[1],'tool_input':json.loads(sys.argv[2]),'cwd':sys.argv[3]}))" "$A" "$I" "$C" | bash "$ODA" kanca "$D/$O" "$D/.claude/oda-ortak.json" >"$T/kanca.out" 2>"$T/kanca.err"
  return $?
}
D="$T/depo"; kur_depo "$D"

echo "── iskelet ve üretim"
[ -f "$D/oda-a/CLAUDE.md" ] && [ -f "$D/oda-a/oda.json" ] && [ -d "$D/oda-a/hafiza" ] && [ -d "$D/oda-a/.claude/skills" ] && [ -d "$D/oda-a/.claude/agents" ]
[ $? -eq 0 ] && ok "O1 oda iskeleti: CLAUDE.md · oda.json · hafiza/ · .claude/skills · .claude/agents" || no "O1 iskelet eksik"
grep -q "Hedef:\*\* A hedefi" "$D/oda-a/CLAUDE.md" && grep -q "Reis:\*\* SERDAR" "$D/oda-a/CLAUDE.md" && ok "O2 master prompt hedef + reis + ölçü taşıyor" || no "O2 master prompt eksik"
python3 -I -c "
import json,sys
a=json.load(open('$D/oda-a/.claude/settings.json')); b=json.load(open('$D/oda-b/.claude/settings.json'))
assert a['autoMemoryDirectory'].endswith('/oda-a/hafiza') and b['autoMemoryDirectory'].endswith('/oda-b/hafiza')
assert a['autoMemoryDirectory']!=b['autoMemoryDirectory']
assert a['permissions']['allow']==['Bash(git status)'] and a['permissions']['deny']==['Read(.env)']
assert a['hooks']['PreToolUse'][0]['hooks'][0]['command'].endswith('/oda-a '+'$D/.claude/oda-ortak.json')
" && ok "O3 ayar: hafıza oda başına AYRI, ortak izin her odada, kanca kendi odasına bağlı" || no "O3 üretilen ayar yanlış"
bash "$ODA" uret "$D" >"$T/u.out" 2>&1; grep -q "oda-a: aynı" "$T/u.out" && grep -q "oda-b: aynı" "$T/u.out" && ok "O4 uret idempotent (ikinci koşu 'aynı')" || no "O4 idempotent değil" "$(cat "$T/u.out")"
bash "$ODA" dogrula "$D" >"$T/d.out" 2>&1; [ $? -eq 0 ] && ok "O5 doğrula temiz (rc 0)" || no "O5 doğrula temiz değil" "$(cat "$T/d.out")"
echo '{"elle":1}' > "$D/oda-b/.claude/settings.json"
bash "$ODA" dogrula "$D" >"$T/d.out" 2>&1; R=$?; [ $R -eq 1 ] && grep -q "oda-b: .claude/settings.json ortak ayardan" "$T/d.out" && ok "O6 elle düzenlenmiş ayar KIRMIZI (rc 1, hangi oda söylenir)" || no "O6 elle düzenleme yakalanmadı" "rc=$R $(cat "$T/d.out")"
bash "$ODA" uret "$D" >/dev/null 2>&1; bash "$ODA" dogrula "$D" >/dev/null 2>&1 && ok "O7 uret elle düzenlemeyi geri sardı, doğrula yeşil" || no "O7 uret onarmadı"
echo '{"hooks":{}}' > "$D/oda-a/.claude/settings.oda.json"
bash "$ODA" uret "$D" >"$T/u.out" 2>&1; R=$?; [ $R -ne 0 ] && grep -q "üreticiye ait" "$T/u.out" && ok "O8 oda-özel ayar hooks/autoMemoryDirectory ezemez (üretici reddeder)" || no "O8 oda-özel parça kancayı ezebildi" "rc=$R $(cat "$T/u.out")"
echo '{"permissions":{"allow":["Bash(ls)"]}}' > "$D/oda-a/.claude/settings.oda.json"
bash "$ODA" uret "$D" >/dev/null 2>&1; python3 -I -c "
import json;a=json.load(open('$D/oda-a/.claude/settings.json'))['permissions']['allow'];assert a==['Bash(git status)','Bash(ls)'],a" && ok "O9 oda-özel izin ortakla BİRLEŞİR (ortak korunur)" || no "O9 birleşim yanlış"
bash "$ODA" yeni "$D" oda-a --reis X --hedef h --olcu o >/dev/null 2>&1; [ $? -ne 0 ] && ok "O10 var olan oda yeniden kurulamaz" || no "O10 var olan oda ezildi"
bash "$ODA" yeni "$D" "Kötü Ad" --reis X --hedef h --olcu o >/dev/null 2>&1; [ $? -ne 0 ] && ok "O11 geçersiz oda adı reddedildi" || no "O11 geçersiz ad kabul edildi"
bash "$ODA" yeni "$D" oda-c --reis X --hedef h >/dev/null 2>&1; [ $? -ne 0 ] && [ ! -d "$D/oda-c" ] && ok "O12 ölçüsüz oda kurulmaz (oda = hedef + reis + ölçü)" || no "O12 ölçüsüz oda kuruldu"
E="$T/bos"; mkdir -p "$E/.claude"; echo '{}' > "$E/.claude/oda-ortak.json"; bash "$ODA" dogrula "$E" >/dev/null 2>&1; [ $? -eq 3 ] && ok "O13 hiç oda yoksa doğrula ÖLÇÜLEMEDİ (rc 3), yeşil değil" || no "O13 odasız depo temiz sayıldı"

[ "$(bash "$ODA" yol "$D" oda-a 2>/dev/null)" = "$D/oda-a" ] && bash "$ODA" yol "$D" yok-oda >/dev/null 2>&1; [ $? -ne 0 ] && ok "O14 yol: var olan odanın mutlak klasörü basılır, olmayan oda rc≠0" || no "O14 yol komutu yanlış"
echo "── kanca (Write/Edit/Bash)"
kanca "$D" oda-a Write "{\"file_path\":\"$D/oda-a/kod.py\"}"; [ $? -eq 0 ] && ok "K1 kendi oda klasörüne yazma SERBEST" || no "K1" "$(cat "$T/kanca.err")"
kanca "$D" oda-a Write "{\"file_path\":\"$D/oda-b/kod.py\"}"; R=$?; [ $R -eq 2 ] && grep -q "oda-b/kod.py" "$T/kanca.err" && ok "K2 kardeş odaya yazma DURDURULDU, mesaj yolu söyler" || no "K2 kardeş odaya yazılabildi" "rc=$R"
kanca "$D" oda-a Edit "{\"file_path\":\"$D/veri/musteri.json\"}"; R=$?; [ $R -eq 2 ] && grep -q "ortak veri" "$T/kanca.err" && ok "K3 ortak veriye doğrudan Edit DURDURULDU" || no "K3 ortak veriye yazılabildi" "rc=$R"
kanca "$D" oda-a Write "{\"file_path\":\"$D/KAYIT.json\"}"; [ $? -eq 2 ] && ok "K4 kökteki ortak veri dosyası (KAYIT.json) DURDURULDU" || no "K4"
kanca "$D" oda-a Write "{\"file_path\":\"$D/.claude/oda-ortak.json\"}"; [ $? -eq 2 ] && ok "K5 ajan ortak ayarı (.claude/oda-ortak.json) DEĞİŞTİREMEZ" || no "K5 ortak ayar yazılabildi"
kanca "$D" oda-a Write "{\"file_path\":\"$D/.git/config\"}"; [ $? -eq 2 ] && ok "K6 depo içi .git/ yazımı DURDURULDU" || no "K6"
kanca "$D" oda-a Write "{\"file_path\":\"/tmp/oda-sinav-disari.txt\"}"; [ $? -eq 0 ] && ok "K7 depo DIŞINA yazma bu kancanın işi değil (serbest)" || no "K7 depo dışı bloklandı"
ln -s "$D/oda-b" "$D/oda-a/kacak"; kanca "$D" oda-a Write "{\"file_path\":\"$D/oda-a/kacak/x.py\"}"; [ $? -eq 2 ] && ok "K8 sembolik bağ ile kardeş odaya kaçış DURDURULDU (realpath)" || no "K8 symlink kaçışı"
kanca "$D" oda-a Read "{\"file_path\":\"$D/veri/musteri.json\"}"; [ $? -eq 0 ] && ok "K9 ortak veriyi OKUMA serbest" || no "K9"
kanca "$D" oda-a Bash '{"command":"echo x > ../veri/a.json"}'; R=$?; [ $R -eq 2 ] && ok "K10 Bash yönlendirmesiyle ortak veriye yazma DURDURULDU" || no "K10 yönlendirme geçti" "rc=$R"
kanca "$D" oda-a Bash '{"command":"echo x | tee -a ../oda-b/n.txt"}'; [ $? -eq 2 ] && ok "K11 tee ile kardeş odaya yazma DURDURULDU" || no "K11"
kanca "$D" oda-a Bash '{"command":"sed -i s/a/b/ ../veri/musteri.json"}'; [ $? -eq 2 ] && ok "K12 sed -i ile ortak veriye yazma DURDURULDU" || no "K12"
kanca "$D" oda-a Bash '{"command":"cp kod.py ../oda-b/kod.py"}'; [ $? -eq 2 ] && ok "K13 cp hedefi kardeş oda DURDURULDU" || no "K13"
kanca "$D" oda-a Bash '{"command":"bash scripts/ortak-yaz.sh musteri ekle"}'; [ $? -eq 0 ] && ok "K14 çekirdeğin komutu (cekirdek_komutlar) SERBEST" || no "K14 çekirdek komut bloklandı" "$(cat "$T/kanca.err")"
kanca "$D" oda-a Bash '{"command":"bash scripts/ortak-yaz.sh x && echo kotu > ../veri/z.json"}'; [ $? -eq 2 ] && ok "K15 çekirdek komutu zincirin başında olsa da ardındaki yazım DURDURULDU" || no "K15 zincir tüm komutu izinli saydı"
kanca "$D" oda-a Bash '{"command":"python3 kod.py 2>&1 > /dev/null"}'; [ $? -eq 0 ] && ok "K16 2>&1 ve /dev/null yanlış alarm vermez" || no "K16 yanlış alarm" "$(cat "$T/kanca.err")"
kanca "$D" oda-a Bash '{"command":"echo x > kod.out"}'; [ $? -eq 0 ] && ok "K17 Bash ile kendi odaya yazma SERBEST" || no "K17"
printf '%s' 'bozuk' | bash "$ODA" kanca "$D/oda-a" "$D/.claude/oda-ortak.json" >/dev/null 2>&1; [ $? -eq 2 ] && ok "K18 bozuk kanca girdisi → GÜVENLİ TARAFTA durdurur (fail-closed)" || no "K18 bozuk girdi geçti"
mv "$D/.claude/oda-ortak.json" "$D/.claude/oda-ortak.json.yedek"; kanca "$D" oda-a Write "{\"file_path\":\"$D/oda-a/kod.py\"}"; R=$?; mv "$D/.claude/oda-ortak.json.yedek" "$D/.claude/oda-ortak.json"; [ $R -eq 2 ] && ok "K19 ortak ayar kayıpsa durdurur (fail-closed), sessiz serbest bırakmaz" || no "K19 ortak ayarsız serbest bıraktı"
python3 -I -c "
import json;m=json.load(open('$D/oda-a/oda.json'));m['ek_yazma']=['scripts/**'];json.dump(m,open('$D/oda-a/oda.json','w'))"
kanca "$D" oda-a Write "{\"file_path\":\"$D/scripts/yardimci.sh\"}"; [ $? -eq 0 ] && ok "K20 oda.json ek_yazma ile açık tanınmış istisna SERBEST" || no "K20 ek_yazma çalışmıyor"
kanca "$D" oda-b Write "{\"file_path\":\"$D/scripts/yardimci.sh\"}"; [ $? -eq 2 ] && ok "K21 aynı yol ek_yazma'sı olmayan odada DURDURULDU" || no "K21 istisna başka odaya sızdı"

echo "SONUÇ: geçti=$G kaldı=$K"
[ "$K" -eq 0 ] || exit 1
[ "${ODA_MUTANT:-1}" = 0 ] && exit 0
echo "── mutantlar (her biri sınavı KIRMALI)"
M="$(mktemp -d)"; MK=0
mut() { # mut <ad> <çapa> <yerine>
  cp "$HERE/oda.py" "$M/oda.py"; cp "$HERE/oda.sh" "$M/oda.sh"; cp "$HERE/oda.test.sh" "$M/oda.test.sh"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$M/oda.py" "$2" "$3" || { echo "  ✗ $1: MUTASYON ÜRETİLEMEDİ"; MK=$((MK+1)); return; }
  if ODA_MUTANT=0 bash "$M/oda.test.sh" >"$M/o.txt" 2>&1; then echo "  ✗ $1: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1)); else echo "  ✓ $1: yakalandı ($(grep -c '  ✗' "$M/o.txt") kapı kırmızı: $(grep '  ✗' "$M/o.txt" | head -3 | cut -c1-24 | tr '\n' ' '))"; fi
}
mut "ortak veri kuralı kapalı" "if glob_uyar(rel, ortak_veri):" "if False:"
mut "oda dışı kuralı kapalı" "return False, f'{rel}: bu odanın" "return True, f'{rel}: bu odanın"
mut "realpath yok (symlink kaçışı)" "return os.path.realpath(yol)" "return os.path.abspath(yol)"
mut "bozuk girdi serbest (fail-open)" "güvenli tarafta durduruldu', file=sys.stderr)
        return 2" "güvenli tarafta durduruldu', file=sys.stderr)
        return 0"
mut "ortak ayar yoksa serbest (fail-open)" "(oda.sh dogrula)', file=sys.stderr)
        return 2" "(oda.sh dogrula)', file=sys.stderr)
        return 0"
mut "çekirdek komutu tüm zinciri izinli sayar" "        for parca in ZINCIR.split(komut):" "        for parca in [komut]:"
mut "ek_yazma her odaya açık" "    ek = oda_meta.get('ek_yazma', [])" "    ek = ['**']"
mut "oda-özel parça kancayı ezebilir" "        if yasak:" "        if False:"
mut "hafıza ayrılığı bozuk (hepsi aynı yol)" "ayar['autoMemoryDirectory'] = os.path.join(abs_oda, 'hafiza')" "ayar['autoMemoryDirectory'] = os.path.join(os.path.dirname(abs_oda), 'hafiza')"
mut "uret yazmıyor (sessiz)" "        yaz_json(hedef, yeni)
        sonuc.append((oda, 'üretildi'))" "        sonuc.append((oda, 'üretildi'))"
find "$M" -mindepth 1 -delete; rmdir "$M"
[ "$MK" -eq 0 ] && echo "MUTANT: hepsi yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
