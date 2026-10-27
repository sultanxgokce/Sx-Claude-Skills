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
  echo '{"a":1}' > "$D/KAYIT.json"; printf '#!/bin/sh\nexit 0\n' > "$D/scripts/ortak-yaz.sh"
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
rm_skills() { find "$1" -mindepth 1 -delete; rmdir "$1"; }
rm_skills "$D/oda-b/.claude/skills"; rm "$D/oda-b/hafiza/MEMORY.md"
bash "$ODA" dogrula "$D" >"$T/d.out" 2>&1; R=$?; [ $R -eq 1 ] && grep -q "oda-b: .claude/skills/ klasörü yok" "$T/d.out" && grep -q "oda-b: hafiza/MEMORY.md yok" "$T/d.out" && ok "O15 doğrula eksik iskeleti (skills/, MEMORY.md) KIRMIZI yakalar" || no "O15 eksik iskelet temiz sayıldı" "rc=$R $(cat "$T/d.out")"
bash "$ODA" uret "$D" >/dev/null 2>&1; [ -d "$D/oda-b/.claude/skills" ] && ok "O16 ayar aynı olsa da uret eksik klasörü yeniden kurar" || no "O16 uret eksik klasörü kurmadı"
echo "# oda-b odası hafızası" > "$D/oda-b/hafiza/MEMORY.md"
BD="$T/boş luk;\$x/depo"; mkdir -p "$BD"; kur_depo "$BD"
python3 -I -c "
import json,shlex,subprocess
c=json.load(open('$BD/oda-a/.claude/settings.json'))['hooks']['PreToolUse'][0]['hooks'][0]['command']
t=shlex.split(c); assert len(t)==5 and t[2]=='kanca' and t[3].endswith('/oda-a') and t[4].endswith('oda-ortak.json'),t
p=subprocess.run(c,shell=True,input=json.dumps({'tool_name':'Write','tool_input':{'file_path':'$BD/oda-b/x'},'cwd':'$BD/oda-a'}),capture_output=True,text=True)
assert p.returncode==2 and 'oda-b/x' in p.stderr,(p.returncode,p.stderr)
" && ok "O17 boşluk/;/\$ içeren depo yolunda kanca komutu alıntılı ve kabukta GERÇEKTEN çalışır" || no "O17 alıntılama kırık"
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
kanca "$D" oda-a Bash '{"command":"bash ../scripts/ortak-yaz.sh musteri ekle"}'; [ $? -eq 0 ] && ok "K14 çekirdeğin komutu (cekirdek_komutlar) SERBEST" || no "K14 çekirdek komut bloklandı" "$(cat "$T/kanca.err")"
kanca "$D" oda-a Bash '{"command":"bash ../scripts/ortak-yaz.sh x && echo kotu > ../veri/z.json"}'; [ $? -eq 2 ] && ok "K15 çekirdek komutu zincirin başında olsa da ardındaki yazım DURDURULDU" || no "K15 zincir tüm komutu izinli saydı"
kanca "$D" oda-a Bash '{"command":"python3 kod.py 2>&1 > /dev/null"}'; [ $? -eq 0 ] && ok "K16 2>&1 ve /dev/null yanlış alarm vermez" || no "K16 yanlış alarm" "$(cat "$T/kanca.err")"
kanca "$D" oda-a Bash '{"command":"echo x > kod.out"}'; [ $? -eq 0 ] && ok "K17 Bash ile kendi odaya yazma SERBEST" || no "K17"
mkdir -p "$D/oda-a/scripts"; printf '#!/bin/sh\nexit 0\n' > "$D/oda-a/scripts/ortak-yaz.sh"
kanca "$D" oda-a Bash '{"command":"bash scripts/ortak-yaz.sh cp a ../veri/b"}'; [ $? -eq 2 ] && ok "K22 oda İÇİNDE aynı adlı sahte betik çekirdek SAYILMAZ (gerçek yol eşleşmesi)" || no "K22 sahte betik çekirdek sayıldı"
kanca "$D" oda-a Bash '{"command":"bash ../scripts/ortak-yaz.sh cp a ../veri/b"}'; [ $? -eq 0 ] && ok "K23 gerçek çekirdek betiği (cwd'den çözülen yol eşit) SERBEST" || no "K23 gerçek çekirdek bloklandı" "$(cat "$T/kanca.err")"
kanca "$D" oda-a Bash '{"command":"bash ../scripts/ortak-yaz.sh x > ../veri/z"}'; [ $? -eq 2 ] && ok "K24 çekirdek komutunun ARDINA eklenen yönlendirme DURDURULDU" || no "K24 çekirdek parçada yönlendirme taranmadı"
kanca "$D" oda-a Bash '{"command":"bash ../scripts/ortak-yaz.sh x && cp a ../veri/b"}'; [ $? -eq 2 ] && ok "K26 çekirdek komutunu izleyen && cp ... zincir parçası ayrı taranır, DURDURULDU" || no "K26 zincirde cp geçti"
kanca "$D" oda-a Bash "{\"command\":\"bash $D/scripts/ortak-yaz.sh x\"}"; [ $? -eq 0 ] && ok "K25 çekirdek betiği MUTLAK yolla da tanınır" || no "K25 mutlak yol tanınmadı"
printf '%s' 'bozuk' | bash "$ODA" kanca "$D/oda-a" "$D/.claude/oda-ortak.json" >/dev/null 2>&1; [ $? -eq 2 ] && ok "K18 bozuk kanca girdisi → GÜVENLİ TARAFTA durdurur (fail-closed)" || no "K18 bozuk girdi geçti"
mv "$D/.claude/oda-ortak.json" "$D/.claude/oda-ortak.json.yedek"; kanca "$D" oda-a Write "{\"file_path\":\"$D/oda-a/kod.py\"}"; R=$?; mv "$D/.claude/oda-ortak.json.yedek" "$D/.claude/oda-ortak.json"; [ $R -eq 2 ] && ok "K19 ortak ayar kayıpsa durdurur (fail-closed), sessiz serbest bırakmaz" || no "K19 ortak ayarsız serbest bıraktı"
python3 -I -c "
import json;m=json.load(open('$D/oda-a/oda.json'));m['ek_yazma']=['scripts/**'];json.dump(m,open('$D/oda-a/oda.json','w'))"
kanca "$D" oda-a Write "{\"file_path\":\"$D/scripts/yardimci.sh\"}"; [ $? -eq 0 ] && ok "K20 oda.json ek_yazma ile açık tanınmış istisna SERBEST" || no "K20 ek_yazma çalışmıyor"
kanca "$D" oda-b Write "{\"file_path\":\"$D/scripts/yardimci.sh\"}"; [ $? -eq 2 ] && ok "K21 aynı yol ek_yazma'sı olmayan odada DURDURULDU" || no "K21 istisna başka odaya sızdı"

echo "── cekirdek-yaz (Oda modeli 5 D4): sahte defter /ben, jeton kimliği, kayıt, ret"
cat > "$T/defter.py" <<'PYEOF'
import http.server, json, sys
JET = {'TOK-SERDAR': {'kutu': 'code', 'ajan': 'SERDAR'}, 'TOK-KUTU': {'kutu': 'code', 'ajan': ''}}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        k = JET.get(self.headers.get('x-defter-jeton', ''))
        if self.path != '/ben' or k is None:
            self.send_response(401); self.end_headers(); return
        b = json.dumps({'ok': True, **k}).encode()
        self.send_response(200); self.send_header('content-type', 'application/json'); self.end_headers(); self.wfile.write(b)
s = http.server.HTTPServer(('127.0.0.1', 0), H)
open(sys.argv[1], 'w').write(str(s.server_address[1]))
s.serve_forever()
PYEOF
python3 -I "$T/defter.py" "$T/port" >/dev/null 2>&1 & DSUNUCU=$!
for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
export DEFTER_UC="http://127.0.0.1:$(cat "$T/port")"
export ODA_TEST_VARSAYILAN_JETON="$T/jeton-serdar"   # yalnız mutant sınaması için: varsayılana düşen kod bunu bulur, doğru kod bakmaz
printf 'TOK-SERDAR' > "$T/jeton-serdar"; printf 'TOK-KUTU' > "$T/jeton-kutu"; printf 'TOK-YOK' > "$T/jeton-yok"
C="$T/cdepo"; kur_depo "$C"
GT="git -c user.email=t@t -c user.name=t"
( cd "$C" && git init -q . && git add -A && $GT commit -q -m ilk )
cy() { # cy <jeton dosyası|-> <cwd> <argümanlar…> : stdin'den içerik
  local J="$1" W="$2"; shift 2
  if [ "$J" = - ]; then ( cd "$W" && env -u DEFTER_JETON_YOL bash "$ODA" cekirdek-yaz "$@" ) 2>&1; else ( cd "$W" && DEFTER_JETON_YOL="$J" bash "$ODA" cekirdek-yaz "$@" ) 2>&1; fi
}
KS() { sha256sum "$C/KAYIT.json" | cut -d' ' -f1; }
ONCE="$(KS)"
echo '{"a":2}' | cy "$T/jeton-serdar" "$C" "$C" KAYIT.json --neden "ortak sayaç güncellendi" --siparis gorev_01ABCDEFGHJKMNPQRST >/dev/null; R=$?
SONRA="$(KS)"
[ "$R" -eq 0 ] && [ "$(cat "$C/KAYIT.json")" = '{"a":2}' ] && [ "$ONCE" != "$SONRA" ] && ok "C1 jetonlu yazım dosyayı değiştirdi" || no "C1 yazım olmadı" "rc=$R"
python3 -I -c "
import json
k=[json.loads(l) for l in open('$C/.claude/cekirdek-kayit.jsonl')]
r=k[-1]
assert len(k)==1 and r['kim']=='SERDAR' and r['kutu']=='code' and r['dosya']=='KAYIT.json'
assert r['onceki_sha']=='$ONCE' and r['sonraki_sha']=='$SONRA' and r['neden']=='ortak sayaç güncellendi'
assert r['siparis']=='gorev_01ABCDEFGHJKMNPQRST' and r['siparissiz'] is False and r['zaman']
" && ok "C2 kayıt: kim (jetondan) · dosya · önceki/sonraki sha · neden · sipariş · zaman" || no "C2 kayıt eksik/yanlış"
echo '{"a":3}' | cy "$T/jeton-serdar" "$C" "$C" KAYIT.json --neden "siparişsiz değişiklik denemesi" >/dev/null
python3 -I -c "
import json;r=[json.loads(l) for l in open('$C/.claude/cekirdek-kayit.jsonl')][-1];assert r['siparis'] is None and r['siparissiz'] is True" && ok "C3 siparişsiz yazım kayıtta AYRI işaretli (nabızda ayrı satır)" || no "C3 siparişsiz işaret yok"
echo '{"a":9}' | cy "$T/jeton-serdar" "$C" "$C" veri/yeni/dosya.json --neden "yeni ortak veri dosyası" >/dev/null
python3 -I -c "
import json;r=[json.loads(l) for l in open('$C/.claude/cekirdek-kayit.jsonl')][-1];assert r['onceki_sha'] is None and r['dosya']=='veri/yeni/dosya.json'" && [ -f "$C/veri/yeni/dosya.json" ] && ok "C4 yeni dosya: önceki sha boş (uydurulmaz), ara dizin kurulur" || no "C4 yeni dosya hatalı"
SAYI0="$(wc -l < "$C/.claude/cekirdek-kayit.jsonl")"; S0="$(KS)"
echo '{"a":666}' | cy - "$C" "$C" KAYIT.json --neden "jetonsuz süreç denemesi" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C5 Ö6 DEFTER_JETON_YOL yok: ret, yazım 0 (varsayılan jetona düşmez)" || no "C5 jetonsuz yazdı" "rc=$R"
echo '{"a":666}' | cy "$T/yok-dosya" "$C" "$C" KAYIT.json --neden "jeton dosyası yok denemesi" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C6 jeton dosyası okunamaz: ret" || no "C6 okunamayan jetonla yazdı"
echo '{"a":666}' | cy "$T/jeton-yok" "$C" "$C" KAYIT.json --neden "geçersiz jeton denemesi" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C7 defter jetonu tanımıyor (401): ret" || no "C7 geçersiz jetonla yazdı"
echo '{"a":666}' | cy "$T/jeton-kutu" "$C" "$C" KAYIT.json --neden "ajan kimliksiz kutu jetonu" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C8 ajan kimliği olmayan kutu jetonu: ret (koltuk ayırt edilemez)" || no "C8 ajansız jetonla yazdı"
echo '{"a":666}' | DEFTER_UC="http://127.0.0.1:1" cy "$T/jeton-serdar" "$C" "$C" KAYIT.json --neden "defter ulaşılamıyor denemesi" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C9 defter ulaşılamaz: ret (fail-closed)" || no "C9 defter yokken yazdı"
OB="$T/baska"; mkdir -p "$OB"; ( cd "$OB" && git init -q . )
echo '{"a":666}' | cy "$T/jeton-serdar" "$OB" "$C" KAYIT.json --neden "ayrı depodaki odadan deneme" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C10 Ö7 ayrı depodaki odadan (cwd başka git deposu): ret" || no "C10 ayrı depodan yazdı"
echo '{"a":666}' | cy "$T/jeton-serdar" "$C" "$T" KAYIT.json --neden "kutu deposu olmayan yol verildi" >/dev/null; R=$?
[ "$R" -ne 0 ] && ok "C11 verilen depo kutu deposu değil (oda-ortak.json yok): ret" || no "C11 sahte depo kabul"
echo x | cy "$T/jeton-serdar" "$C" "$C" ../kacis.txt --neden "depo dışına kaçış denemesi" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ ! -e "$T/kacis.txt" ] && ok "C12 depo dışı yol: ret" || no "C12 depo dışına yazdı"
echo x | cy "$T/jeton-serdar" "$C" "$C" oda-a/kod.py --neden "çekirdek olmayan dosya denemesi" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ ! -e "$C/oda-a/kod.py" ] && ok "C13 ortak_veri dışı dosya: ret (komut yalnız çekirdek içindir)" || no "C13 çekirdek dışına yazdı"
ln -s "$T" "$C/veri/kacak"
echo x | cy "$T/jeton-serdar" "$C" "$C" veri/kacak/sym.txt --neden "sembolik bağ kaçışı denemesi" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ ! -e "$T/sym.txt" ] && ok "C14 sembolik bağla depo dışına kaçış: ret (realpath)" || no "C14 symlink ile kaçtı"
echo x | cy "$T/jeton-serdar" "$C" "$C" KAYIT.json --neden "kısa" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C15 nedensiz/çok kısa nedenle yazım yok" || no "C15 nedensiz yazdı"
echo x | cy "$T/jeton-serdar" "$C" "$C" KAYIT.json --neden "bozuk sipariş biçimi denemesi" --siparis "gorev_" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ "$(KS)" = "$S0" ] && ok "C16 bozuk sipariş kimliği: ret" || no "C16 bozuk siparişle yazdı"
[ "$(wc -l < "$C/.claude/cekirdek-kayit.jsonl")" -eq "$SAYI0" ] && ok "C17 reddedilen hiçbir yazım kayıt satırı bırakmadı" || no "C17 ret kayıt bıraktı"
printf '%s' 'dosyadan içerik' > "$T/kaynak.txt"
cy "$T/jeton-serdar" "$C" "$C" veri/dosyadan.txt --neden "içerik --dosya ile verildi" --dosya "$T/kaynak.txt" </dev/null >/dev/null; R=$?
[ "$R" -eq 0 ] && [ "$(cat "$C/veri/dosyadan.txt")" = "dosyadan içerik" ] && ok "C18 --dosya ile içerik" || no "C18 --dosya çalışmadı"
echo "── kanca ret mesajı komutu gösterir (Ö4)"
MSG="$(python3 -I -c "import json;print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$C/KAYIT.json'},'cwd':'$C/oda-a'}))" | bash "$ODA" kanca "$C/oda-a" "$C/.claude/oda-ortak.json" 2>&1)"
grep -q "cekirdek-yaz" <<<"$MSG" && grep -q -- "--neden" <<<"$MSG" && ok "C19 doğrudan yazım reddi komutu (cekirdek-yaz … --neden) gösteriyor" || no "C19 ret komutu göstermiyor" "$MSG"
C2="$T/cdepo2"; kur_depo "$C2"
python3 -I -c "
import json;p='$C2/.claude/oda-ortak.json';d=json.load(open(p));d['ortak_veri']=['**'];json.dump(d,open(p,'w'))"
( cd "$C2" && git init -q . && git add -A && $GT commit -q -m ilk )
echo x | cy "$T/jeton-serdar" "$C2" "$C2" ../kacis2.txt --neden "glob her şeyi kapsarken depo dışı deneme" >/dev/null; R=$?
[ "$R" -ne 0 ] && [ ! -e "$T/kacis2.txt" ] && ok "C20 ortak_veri '**' olsa bile depo dışı yol ret (kapı glob'dan bağımsız)" || no "C20 glob '**' iken depo dışına yazdı"
kill "$DSUNUCU" 2>/dev/null; wait "$DSUNUCU" 2>/dev/null

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
mut "çekirdek eşleşmesi yalnız metin öneki" "                if cozumle(t, cwd) != os.path.realpath(kdosya):" "                if t != k:"
mut "çekirdek parçada yönlendirme taranmaz" "        hed.append(tirnak_sil(m.group(1)))
    if yalniz_yonlendirme:
        return hed" "        pass
    if yalniz_yonlendirme:
        return hed"
mut "kanca komutu alıntısız" "'bash ' + ' '.join(shlex.quote(x) for x in (kanca_betik, 'kanca', abs_oda, ortak_yol))" "f'bash {kanca_betik} kanca {abs_oda} {ortak_yol}'"
mut "uret ayar aynıysa iskeleti kurmaz" "        for alt in ('skills', 'agents'):
            os.makedirs(os.path.join(depo, oda, '.claude', alt), exist_ok=True)   # ayar aynı olsa da iskelet eksiksiz kalır
        os.makedirs(os.path.join(depo, oda, 'hafiza'), exist_ok=True)
        if eski == yeni:" "        if eski == yeni:"
mut "doğrula MEMORY.md kontrolü yok" "        if not os.path.isfile(os.path.join(k, 'hafiza', 'MEMORY.md')):" "        if False:"
mut "oda-özel parça kancayı ezebilir" "        if yasak:" "        if False:"
mut "hafıza ayrılığı bozuk (hepsi aynı yol)" "ayar['autoMemoryDirectory'] = os.path.join(abs_oda, 'hafiza')" "ayar['autoMemoryDirectory'] = os.path.join(os.path.dirname(abs_oda), 'hafiza')"
mut "uret yazmıyor (sessiz)" "        yaz_json(hedef, yeni)
        sonuc.append((oda, 'üretildi'))" "        sonuc.append((oda, 'üretildi'))"
mut "cekirdek-yaz: env yoksa varsayılan jetona düşer" "jy = os.environ.get('DEFTER_JETON_YOL', '')" "jy = os.environ.get('DEFTER_JETON_YOL', os.environ.get('ODA_TEST_VARSAYILAN_JETON', ''))"
mut "cekirdek-yaz: ajansız jetonu kabul eder" "if not (isinstance(ajan, str) and ajan.strip() and isinstance(kutu, str) and kutu.strip()):" "if not isinstance(kutu, str):"
mut "cekirdek-yaz: defter ulaşılamazsa devam eder" "raise PermissionError('defter kimliği sorulamadı (ulaşılamıyor/bozuk yanıt) — çekirdeğe yazılmaz')" "return 'bilinmiyor', 'bilinmiyor'"
mut "cekirdek-yaz: ayrı depo (cwd) denetimi yok" "    if cwd_kok != depo_r:" "    if False:"
mut "cekirdek-yaz: ortak_veri glob denetimi yok" "    if not glob_uyar(rel, ortak.get('ortak_veri', [])):" "    if False:"
mut "cekirdek-yaz: depo dışı yol denetimi yok" "    if not icinde(hedef, depo_r):" "    if False:"
mut "cekirdek-yaz: önceki sha yazılmaz" "'onceki_sha': onceki," "'onceki_sha': None,"
mut "cekirdek-yaz: siparişsiz işareti yok" "'siparis': siparis or None, 'siparissiz': not siparis," "'siparis': siparis or None, 'siparissiz': False,"
mut "cekirdek-yaz: neden zorunlu değil" "    if not neden or len(neden.strip()) < 10:" "    if False:"
mut "kanca ret mesajı komutu göstermiyor" "yazma yalnız çekirdeğin komutundan: bash {CEKIRDEK_KOMUT}" "yazma yalnız çekirdeğin komutundan: ({CEKIRDEK_KOMUT[:0]}"
find "$M" -mindepth 1 -delete; rmdir "$M"
[ "$MK" -eq 0 ] && echo "MUTANT: hepsi yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
