#!/usr/bin/env bash
# calisiliyor-uzlastir-mutasyon.sh — uzlaştırma kurallarını (DKYSHH + X666) tek tek öldürür; ilgili sınav KIRMIZI olmalı.
#   Kopya üstünde koşar. Önce pozitif kontrol: dokunulmamış kopya YEŞİL olmalı. U* = calisiliyor-uzlastir.test.sh · G* = kart.test.sh
set -u
D="$(cd "$(dirname "$0")" && pwd)"; E="$(mktemp -d)"
sil() { python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$1"; }
trap 'sil "$E"' EXIT
gecti=0; dusen=0
kopya() { sil "$E/m"; cp -r "$D" "$E/m"; }
kopya; if bash "$E/m/calisiliyor-uzlastir.test.sh" >/dev/null 2>&1; then echo "  ✓ pozitif kontrol: dokunulmamış kopya YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI — ölçüm geçersiz"; exit 1; fi
dene() {  # dene <ad> <dosya> <sınav> <eski> <yeni>
  kopya
  if ! python3 - "$E/m/$2" "$4" "$5" <<'PY'
import sys; p,e,y=sys.argv[1:]; s=open(p,encoding='utf-8').read()
if s.count(e)!=1: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(e,y))
PY
  then echo "  ✗ $1 — mutasyon UYGULANAMADI (desen tutmadı)"; dusen=$((dusen+1)); return; fi
  if bash "$E/m/$3" >/dev/null 2>&1; then echo "  ✗ $1 — kural ÖLDÜ ama sınav YEŞİL"; dusen=$((dusen+1))
  else echo "  ✓ $1 — kural ölünce sınav KIRMIZI"; gecti=$((gecti+1)); fi
}
P=calisiliyor-uzlastir.py; U=calisiliyor-uzlastir.test.sh; K=kart.sh; KT=kart.test.sh
dene "UM1 azami yok sayılır (fazlası çalışılıyor kalır)" $P $U 'kartli[azami:]' 'kartli[azami+99:]'
dene "UM2 kartsız çalışılıyor görev dokunulmaz (X666)" $P $U 'plan = [(g, "açık kartı yok") for g in kart_yok]' 'plan = []'
dene "UM3 canlı-borçlu/bitti kart da açık sayılır" $P $U 'k.get("durum") == "acik" and k.get("gorev")' 'k.get("gorev")'
dene "UM4 başka ajanın görevi de çekilir" $P $U 'and norm((g.get("canli") or {}).get("atanan")) == ajan]' ']'
dene "UM5 ad yazımı normalize edilmez (BERID ≠ BERİD)" $P $U 'return "".join(c for c in s if not unicodedata.combining(c)).upper().strip()' 'return str(ad or "").strip()'
dene "UM6 KURU'da da yazar" $P $U 'if not s.uygula:' 'if False:'
dene "UM7 yazım başarısızken rc 0" $P $U 'print("  ⚠ %s bekliyor'"'"'a çekilemedi (http %s)" % (g["id"], kod)); rc = 4' 'print("  ⚠ %s bekliyor'"'"'a çekilemedi (http %s)" % (g["id"], kod)); rc = 0'
dene "UM8 en yeni iş bırakılır (sıra ters)" $P $U 'key=lambda g: g.get("son_adim", ""), reverse=True)' 'key=lambda g: g.get("son_adim", ""), reverse=False)'
dene "UM9 çekilen görev için sahibine zil çalınmaz" $P $U 'if s.zil_komut and not zil(s.zil_komut, kimden, sahip,' 'if False and not zil(s.zil_komut, kimden, sahip,'
dene "UM10 zil tekrar anahtarı yok (aynı görev tekrar zil çalar)" $P $U '"uzlastir-cek-%s-%s" % (g["id"], g.get("son_adim", ""))' '"%s" % os.urandom(4).hex()'
dene "UM11 zil gitmezse rc 0 (sessiz geçer)" $P $U 'print("  ⚠ %s: sahibine zil gidemedi (posta)" % g["id"]); rc = 4' 'print("  ⚠ %s: sahibine zil gidemedi (posta)" % g["id"])'
dene "UM12 koltuk eşiği yok sayılır (her boş koltuğa zil)" $P $U 'bos[0] >= s.koltuk_bos_dk' 'True'
dene "UM13 hâl=bos şartı atlanır (çalışan koltuk da boş sayılır)" $P $U 'k["hal"] == "bos"' 'True'
dene "UM14 koltuk-boş görevi kendiliğinden çeker (öneri değil)" $P $U 'print("  · koltuk %d dk'"'"'dır boş, çalışılıyor: %s" % (bos[0], liste))' 'print("  · koltuk %d dk'"'"'dır boş, çalışılıyor: %s" % (bos[0], liste)); [cagir(s.defter_uc, jeton, "PATCH", "/kayit/" + g["id"], {"yerine": {"gorev_durumu": "bekliyor", "not": "x"}, "gerekce": "x", "adimlar": ["x"]}) for g in kalan]'
dene "UM15 koltuk listesi okunamazsa boş sayılır" $P $U 'if c.returncode != 0:
        return None' 'if c.returncode != 0:
        return []'
dene "UM16 süpürme tür=ajan şartını atlar (ajan olmayan koltuk da taranır)" $P $U 'if k["tur"] == "ajan" and norm(k["ad"]) not in ajanlar' 'if norm(k["ad"]) not in ajanlar'
dene "UM17 süpürmede koltuk listesi okunamazsa devam eder" $P $U 'print("  ⚠ süpürme atlandı: koltuk listesi okunamadı"); return 4' 'pass'
dene "UM9 bekliyor'a notsuz çekilir (defter reddeder)" $P $U '{"yerine": {"gorev_durumu": "bekliyor", "not": not_}' '{"yerine": {"gorev_durumu": "bekliyor"}'
dene "UM10 jeton okunamayınca sessiz geçer" $P $U 'print("  ⚠ uzlaştırma atlandı: defter jetonu okunamadı"); return 4' 'return 0'
dene "UK1 kart açılışından sonra uzlaştırma çağrılmaz" $K $KT '    uzlastir "$ALDI"
    exit $GRC' '    exit $GRC'
dene "UK2 bitti/tıkandı sonrası uzlaştırma çağrılmaz" $K $KT '    uzlastir "$(python3' '    : "$(python3'
dene "UK3 KART_UZLASTIR=0 anahtarı yok sayılır" $K $KT '[ "${KART_UZLASTIR:-1}" = 0 ] && return 0' ':'
dene "UK4 jeton okunamayınca uzlaştırma sessiz atlar" $K $KT '  local kok args=() kokler=' '  [ -r "$DEFTER_JY" ] || return 0
  local kok args=() kokler='
echo "─────────────"; echo "MUTASYON: gecti=$gecti dusen=$dusen"; [ $dusen -eq 0 ]
