#!/usr/bin/env bash
# sirada-bak-sultan-karari.test.sh — hermetik: sahte defter (GET /gorevler, GET /kayit/<id>, PATCH kaydı tutar).
# SERDAR 1 Kas 2026 (AAHWYF243): "sirada-bak Sultan karar sorusunu ajan üstüne alıyor — MÜZEHHİP'i bu sabah iki kez yanılttı."
#   Kök: gorev.sh liste satırı sahip/kapı alanını taşımıyordu, sirada-bak Sultan'ın karar kartını (sahip sultan, kapı karar/ticari…) ajan işi sandı.
#   Beklenen: liste satırı SONUNA "  sahip: sultan" / "  kapi: <kapı>" işaretleri eklenir (eski okuyucular split(None,6) ile ilk 7 alanı okur: bozulmaz);
#   sirada-bak işaretli kaydı ne Sırada'ya ne havuz sayısına katar, ne de ustlen eder.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'kill $SP 2>/dev/null; rm -r -- "$T"' EXIT
printf 'sinav-jeton\n' > "$T/jeton"
python3 - "$T" <<'PY' &
import sys, json, http.server
T=sys.argv[1]
def k(i, durum, aciliyet, atanan, baslik, **ek):
    c={"kutu":"menzil","gorev_durumu":durum,"aciliyet":aciliyet,"etiket":"ozellik","atanan":atanan,"ozet_sultan":"Sultan-dili özet var"}; c.update(ek)
    return {"id":"gorev_"+i,"baslik":baslik,"adlar":[{"deger":baslik}],"canli":c,"son_adim":"2026-01-01T00:00"}
NORMAL=[
 k("A","acik","acil","MENZILCI","İş A (acil)"),
 k("O","acik","esnek","MENZILCI","Not:  sahip: sultan  kapi: karar yazısı başlıkta geçen sıradan iş", oda="agentic-os", sahip="menzil"),
 k("N3","sira-bende","esnek","-","Sahipsiz sıradan iş"),
 k("H2","havuz","esnek","MENZILCI","Havuzda sıradan iş"),
]
SULTAN=[
 k("S1","acik","acil","MENZILCI","Karar sorusu: başlansın mı", sahip="sultan", kapi="karar", eylem="soru"),
 k("S2","sira-bende","esnek","-","Sahipsiz Sultan sorusu", sahip="sultan"),
 k("K1","acik","esnek","-","Ticari kapı işi", sahip="menzil", kapi="ticari"),
 k("H1","havuz","esnek","MENZILCI","Havuzda Sultan kararı", sahip="sultan", kapi="karar"),
]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def _yaz(self,kod,obj):
        self.send_response(kod); self.send_header("content-type","application/json"); self.end_headers(); self.wfile.write(json.dumps(obj).encode())
    def do_GET(self):
        import os
        tum=SULTAN if os.path.exists(T+"/sadece-sultan") else SULTAN+NORMAL
        if self.path.rstrip("/").endswith("/gorevler"): return self._yaz(200,{"gorevler":tum})
        i=self.path.rsplit("/",1)[-1]
        for g in NORMAL+SULTAN:
            if g["id"]==i: return self._yaz(200,{"kayit":g})
        return self._yaz(404,{"hata":"kayit_yok"})
    def do_PATCH(self):
        n=int(self.headers.get("content-length") or 0); b=self.rfile.read(n) or b"{}"
        open(T+"/yama.log","a").write(self.path.rsplit("/",1)[-1]+"\n")
        i=self.path.rsplit("/",1)[-1]; g=[x for x in NORMAL+SULTAN if x["id"]==i] or [{"id":i,"canli":{}}]
        self._yaz(200,{"kayit":g[0],"ok":True})
s=http.server.HTTPServer(("127.0.0.1",0),H); open(T+"/port","w").write(str(s.server_address[1])); s.serve_forever()
PY
SP=$!; for _ in $(seq 50); do [ -s "$T/port" ] && break; sleep 0.1; done; PORT="$(cat "$T/port")"
printf '# yorum\n' > "$T/esleme.tsv"

# kos <betik-dizini> <sessiz:0|1>  → dönüş: düşen sayısı (stdout'a ✓/✗ yazar, sessizde yazmaz)
kos(){
  local D="$1" S="$2" g=0 k=0
  ok(){ if eval "$2"; then g=$((g+1)); [ "$S" = 1 ] || echo "  ✓ $1"; else k=$((k+1)); [ "$S" = 1 ] || echo "  ✗ $1"; fi; }
  local E=(env DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton" GUNLUK_PLAN_AJAN=MENZILCI GUNLUK_PLAN_TARIH=2026-01-02 GUNLUK_PLAN_ESLEME="$T/esleme.tsv" GUNLUK_PLAN_GOREV_SH="$D/gorev.sh")
  rm -f "$T/sadece-sultan" "$T/yama.log"
  local L; L="$("${E[@]}" bash "$D/gorev.sh" liste 2>&1)"
  satir(){ printf '%s\n' "$L" | grep "^gorev_$1 "; }
  ok "L1 Sultan kararı (sahip sultan + kapı karar): satır sonunda iki işaret de var" '[[ "$(satir S1)" == *"  sahip: sultan"* && "$(satir S1)" == *"  kapi: karar"* ]]'
  ok "L2 yalnız sahip sultan: sahip işareti var, kapı işareti YOK" '[[ "$(satir S2)" == *"  sahip: sultan"* && "$(satir S2)" != *"  kapi: "* ]]'
  ok "L3 yalnız kapı (ticari): kapı işareti var, sahip işareti YOK" '[[ "$(satir K1)" == *"  kapi: ticari"* && "$(satir K1)" != *"  sahip: sultan"* ]]'
  ok "L4 sıradan iş işaret taşımaz; oda işareti eskisi gibi kalır" '[[ "$(satir A)" != *"sahip:"* && "$(satir A)" != *"kapi:"* && "$(satir O)" == *"  oda: agentic-os"* ]]'
  ok "L5 eski okuyucu (split(None,6)): ilk 6 sütun ve başlık işaretlerden etkilenmez" '[ "$(satir S1 | python3 -c "import sys; p=sys.stdin.read().rstrip().split(None,6); print(p[1],p[2],p[3],p[5],p[6].split(\"  (son:\")[0])")" = "menzil acik acil MENZILCI Karar sorusu: başlansın mı" ]'
  local C; C="$("${E[@]}" bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI --bak 2>&1)"
  ok "S1 Sırada yalnız sıradan işleri sayar (A, O, N3 = 3); Sultan kararları (S1, S2, K1) SAYILMAZ" '[ "$(printf "%s\n" "$C" | grep "^SIRADA=")" = "SIRADA=3" ]'
  ok "S2 havuz da yalnız sıradan işi sayar (H2 = 1); Sultan kararı H1 SAYILMAZ" '[ "$(printf "%s\n" "$C" | grep "^HAVUZDA=")" = "HAVUZDA=1" ]'
  ok "S3 ISI/MADDE satırlarında hiçbir Sultan kararı yok" '! printf "%s\n" "$C" | grep -E "^(ISI|MADDE)=" | grep -qE "S1|S2|K1|H1"'
  ok "S4 başlıkta geçen \"sahip: sultan\" metni sıradan işi ELEMEZ (işaret yalnız satır sonundan okunur)" 'printf "%s\n" "$C" | grep -q "^ISI=gorev_O "'
  rm -f "$T/yama.log"; "${E[@]}" bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI >/dev/null 2>&1
  ok "S5 varsayılan koşuda ustlen YALNIZ sıradan işe gider (A); Sultan kararına PATCH yok" '[ "$(cat "$T/yama.log" 2>/dev/null | sort -u | tr "\n" " ")" = "gorev_A " ]'
  : > "$T/sadece-sultan"; rm -f "$T/yama.log"
  local C2; C2="$("${E[@]}" bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI 2>&1)"
  ok "S6 kutuda yalnız Sultan kararı varsa: SIRADA=0, HAVUZDA=0, başlamaz, hiçbir şey yazılmaz" '[ "$(printf "%s\n" "$C2" | grep "^SIRADA=")" = "SIRADA=0" ] && [ "$(printf "%s\n" "$C2" | grep "^HAVUZDA=")" = "HAVUZDA=0" ] && ! printf "%s\n" "$C2" | grep -q "^BASLADI=" && [ ! -e "$T/yama.log" ]'
  rm -f "$T/sadece-sultan"
  rm -f "$T/sadece-sultan"
  # KÖR KANON KOPYASI (kart sirada-bak-sultan-isi · SERDAR 4 Kas, bulgu …7411VJ): gorev-yolu.sh cloudtop'taki kanonik gorev.sh'ı seçer; o kopyanın `liste`si Sultan/kapı işaretlerini BASMAZ.
  #   Eskiden süzgeç kör kalıyor, Sultan'ın karar işi üstlenilebiliyordu. Kör kopya = gerçek betiğin liste çıktısından işaretlerin sökülmüş hâli (diğer komutlar aynen geçer).
  local KOR="$T/kor-$$-$RANDOM.sh"
  printf '#!/usr/bin/env bash\ncase "${1:-}" in liste) bash "%s/gorev.sh" liste | sed -E -e "s/  sahip: sultan//" -e "s/  kapi: [^ ]+//";; *) exec bash "%s/gorev.sh" "$@";; esac\n' "$D" "$D" > "$KOR"; chmod +x "$KOR"
  local E2=(env DEFTER_UC="http://127.0.0.1:$PORT" DEFTER_JETON_YOL="$T/jeton" GUNLUK_PLAN_AJAN=MENZILCI GUNLUK_PLAN_TARIH=2026-01-02 GUNLUK_PLAN_ESLEME="$T/esleme.tsv" GUNLUK_PLAN_CLOUDTOP_GOREV="$KOR")
  ok "K0 kör kopya gerçekten kör: liste çıktısında hiçbir işaret yok (sınavın ön koşulu)" '! bash "$KOR" liste 2>&1 | grep -qE "  sahip: sultan|  kapi: "'
  local C3; C3="$("${E2[@]}" bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI --bak 2>&1)"
  ok "K1 kör kopyayla bile Sırada yalnız sıradan işleri sayar (3) ve ISI/MADDE'de Sultan kararı YOK" '[ "$(printf "%s\n" "$C3" | grep "^SIRADA=")" = "SIRADA=3" ] && ! printf "%s\n" "$C3" | grep -E "^(ISI|MADDE)=" | grep -qE "S1|S2|K1|H1"'
  ok "K2 kör kopyayla havuz da yalnız sıradan işi sayar (1)" '[ "$(printf "%s\n" "$C3" | grep "^HAVUZDA=")" = "HAVUZDA=1" ]'
  rm -f "$T/yama.log"; "${E2[@]}" bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI >/dev/null 2>&1
  ok "K3 kör kopyayla varsayılan koşuda ustlen YALNIZ sıradan işe gider; Sultan kararına PATCH yok" '[ "$(cat "$T/yama.log" 2>/dev/null | sort -u | tr "\n" " ")" = "gorev_A " ]'
  rm -f "$T/yama.log"; local C4; C4="$("${E2[@]}" GUNLUK_PLAN_ISARET_SH=/yok/gorev.sh bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI 2>&1)"; local R4=$?
  ok "K4 işaret ikinci kaynaktan okunamazsa ÖLÇÜLEMEDİ (rc 3), hiçbir şey üstlenilmez" '[ "$R4" = 3 ] && printf "%s\n" "$C4" | grep -q "ÖLÇÜLEMEDİ" && [ ! -s "$T/yama.log" ]'
  local D6="$T/paketsiz-$$-$RANDOM"; mkdir -p "$D6"; cp "$D/sirada-bak.sh" "$D/kimlik-coz.sh" "$D/kutu-bul.sh" "$D/gorev-yolu.sh" "$D/hasat.sh" "$D6/" 2>/dev/null
  rm -f "$T/yama.log"; local C6; C6="$("${E[@]}" bash "$D6/sirada-bak.sh" --kutu menzil --kim MENZILCI 2>&1)"; local R6=$?
  ok "K6 paketli ikinci kaynak (scripts/gorev.sh) yoksa ve seçilen kopya başkaysa ÖLÇÜLEMEDİ rc 3, hiçbir şey üstlenilmez (doğrulanamayan Sultan işi sayılmaz)" '[ "$R6" = 3 ] && printf "%s\n" "$C6" | grep -q "ikinci kaynak" && [ ! -s "$T/yama.log" ]'
  rm -f "$T/yama.log"; local C5; C5="$("${E[@]}" GUNLUK_PLAN_GOREV_SH="$KOR" bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI 2>&1)"
  ok "K5 🔴 AÇIK GUNLUK_PLAN_GOREV_SH ile seçilen KÖR kopya da ikinci okumadan muaf DEĞİL: ISI/MADDE'de Sultan kararı yok, ustlen yalnız sıradan işe (göz tur 1)" '! printf "%s\n" "$C5" | grep -E "^(ISI|MADDE)=" | grep -qE "S1|S2|K1|H1" && [ "$(cat "$T/yama.log" 2>/dev/null | sort -u | tr "\n" " ")" = "gorev_A " ]'
  rm -f "$T/yama.log"; local C7; C7="$("${E2[@]}" GUNLUK_PLAN_ISARET_SH=- bash "$D/sirada-bak.sh" --kutu menzil --kim MENZILCI 2>&1)"; local R7=$?
  ok "K7 🔴 ikinci okuma ortam değişkeniyle KAPATILAMAZ: GUNLUK_PLAN_ISARET_SH=- → ÖLÇÜLEMEDİ rc 3, hiçbir şey üstlenilmez (göz tur 2)" '[ "$R7" = 3 ] && printf "%s\n" "$C7" | grep -q "ÖLÇÜLEMEDİ" && [ ! -s "$T/yama.log" ]'
  [ "$S" = 1 ] || echo "── $g geçti · $k kaldı"
  return $k
}

# SADECE_MUTANT=<ad>: yalnız o mutantı kurar ve sınavı koşar; çıkış kodu = kırmızı vaka sayısı (0 = mutant YAŞIYOR). Kanıt aracı mutant başına bu kipi kaydeder.
RC=0
if [ -z "${SADECE_MUTANT:-}" ]; then echo "── gerçek betikler"; kos "$HERE" 0; RC=$?; fi

# Mutantlar: her biri betiklerin TEMİZ kopyasında tek bozulma; sınav o mutantta kırmızıya DÖNMELİ (dönmezse sınav süstür).
echo "── mutantlar"
mut(){  # <ad> <dosya> <python-değiştirme: eski||yeni>
  [ -z "${SADECE_MUTANT:-}" ] || [ "$SADECE_MUTANT" = "$1" ] || return 0
  local d="$T/mut-$1"; mkdir -p "$d"; cp "$HERE"/*.sh "$d"/ 2>/dev/null
  python3 - "$d/$2" "$3" <<'PY'
import sys
p, spec = sys.argv[1], sys.argv[2]; eski, yeni = spec.split("||", 1)
s = open(p, encoding="utf-8").read()
if eski not in s: print("DESEN-YOK"); sys.exit(7)
open(p, "w", encoding="utf-8").write(s.replace(eski, yeni, 1))
PY
  local prc=$?; [ $prc -eq 0 ] || { echo "  ✗ mutant $1 kurulamadı (desen tutmadı, rc=$prc)"; MUTK=$((MUTK+1)); return; }
  local q=1; [ -z "${SADECE_MUTANT:-}" ] || q=0   # tek-mutant kipi AYRINTILI basar: kanıt aracı düşen kapıyı (✗ satırı, "N kaldı") çıktıdan tanır
  kos "$d" "$q"; local r=$?
  [ -z "${SADECE_MUTANT:-}" ] || exit $((r > 0 ? 1 : 0))   # yakalandı → rc 1 (kanıt aracı rc 3/9'u ÖLÇÜLEMEDİ okur: vaka sayısı rc OLMAZ), yaşıyor → 0
  if [ $r -gt 0 ]; then echo "  ✓ mutant $1 yakalandı ($r vaka kırmızı)"; else echo "  ✗ mutant $1 YAŞIYOR — sınav bu bozulmayı görmüyor"; MUTK=$((MUTK+1)); fi
}
MUTK=0
mut sirada-suzgeci-yok sirada-bak.sh 'if "  sahip: sultan" in ek or "  kapi: " in ek: continue||pass'
mut yalniz-kapi-suzer sirada-bak.sh 'if "  sahip: sultan" in ek or "  kapi: " in ek: continue||if "  kapi: " in ek: continue'
mut yalniz-sahip-suzer sirada-bak.sh 'if "  sahip: sultan" in ek or "  kapi: " in ek: continue||if "  sahip: sultan" in ek: continue'
mut tum-satiri-tarar sirada-bak.sh 'ek=p[6].rsplit("(son:",1)[-1]||ek=p[6]'
mut ikinci-okuma-yok sirada-bak.sh 'if [ -z "$ISARET_SH" ] && [ "$GOREV" != "$KOK/gorev.sh" ]; then||if false; then'
mut isaret-kapagi-var sirada-bak.sh 'if [ -n "$ISARET_SH" ]; then||if [ -n "$ISARET_SH" ] && [ "$ISARET_SH" != "-" ]; then'
mut acik-gorev-muaf sirada-bak.sh 'if [ -z "$ISARET_SH" ] && [ "$GOREV" != "$KOK/gorev.sh" ]; then||if [ -z "$ISARET_SH" ] && [ -z "${GUNLUK_PLAN_GOREV_SH:-}" ] && [ "$GOREV" != "$KOK/gorev.sh" ]; then'
mut isaret-suzgeci-yok sirada-bak.sh 'if p[0] in sultan: continue||pass'
mut okunamazsa-devam sirada-bak.sh 'DENMEZ, üstlenme yapılmadı" >&2; exit 3; }||DENMEZ, üstlenme yapılmadı" >&2; }'
mut liste-sahip-isareti-yok gorev.sh '+ ("  sahip: sultan" if str(g["canli"].get("sahip","")).strip().lower()=="sultan" else "")||'
mut liste-kapi-isareti-yok gorev.sh '+ (("  kapi: %s" % g["canli"]["kapi"].strip()) if isinstance(g["canli"].get("kapi"),str) and g["canli"]["kapi"].strip() else "")||'
[ -z "${SADECE_MUTANT:-}" ] || { echo "SADECE_MUTANT=$SADECE_MUTANT tanımsız ad" >&2; exit 99; }
echo "── mutant özeti: $MUTK yaşayan/kurulamayan"
[ "$RC" -eq 0 ] && [ "$MUTK" -eq 0 ]
