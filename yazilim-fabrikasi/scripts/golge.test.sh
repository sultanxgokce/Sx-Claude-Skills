#!/usr/bin/env bash
# golge.test.sh — golge-birlestirme.sh (kayıt) ve golge-rapor.sh (sahte yeşil sayımı): TCBXPP 1 haftalık yalnız-bildirim aşaması.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GB="$HERE/golge-birlestirme.sh"; GR="$HERE/golge-rapor.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'rm -r -f "$T"' EXIT
export FABRIKA_GOLGE_DEFTER="$T/defter.jsonl" FABRIKA_AILE_NOTIFY=- FABRIKA_GOREV_SH="$T/yok-gorev.sh"
D="$T/depo"; mkdir -p "$D/_agents/fabrika/kartlar"; ( cd "$D" && git init -q -b main && git remote add origin https://github.com/ornek/depo.git ) >/dev/null 2>&1
kart() { python3 - "$D/_agents/fabrika/kartlar/$1.json" "$2" "${3:-}" <<'PY'
import json,sys; f,sinif,gorev=sys.argv[1:]
json.dump({"is":sys.argv[1].split("/")[-1][:-5],"aldi":"HENDESE","siniflar":(["para"] if sinif=="sinifli" else []),"sultan":sinif=="sinifli","gorev":gorev},open(f,"w"))
PY
}

echo "════ G1 · kayıt ════"
kart is-a duz gorev_X; kart is-b sinifli
O="$(bash "$GB" is-a --depo "$D" --pr 10 --sha aaa 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "birleştirirdim: 'is-a' (PR #10) · ornek/depo" <<<"$O" && [ "$(wc -l < "$FABRIKA_GOLGE_DEFTER")" -eq 1 ]; g $? "G1 sınıfsız iş: satır yazılır, depo adı remote'tan çıkar" "→ $O"
python3 -c "import json;r=json.loads(open('$FABRIKA_GOLGE_DEFTER').read().splitlines()[0]);assert r['is']=='is-a' and r['pr']=='10' and r['sha']=='aaa' and r['repo']=='ornek/depo' and r['gorev']=='gorev_X', r"; g $? "G2 satırda iş·PR·baş·depo·görev alanları var"
grep -q "sahibi sensin" <<<"$O" && grep -q "KENDİN birleştir" <<<"$O" && grep -q "gh pr view 10 --json state,mergedAt" <<<"$O"; g $? "G19 gölge çıktısı işin sahibine 'sahibi sensin, kendin birleştir, önce gh pr view ile durumu oku' der (28 Eki akşamı dersi 6)" "→ $O"
bash "$GB" is-a --depo "$D" --pr 10 --sha aaa >/dev/null 2>&1; [ "$(wc -l < "$FABRIKA_GOLGE_DEFTER")" -eq 1 ]; g $? "G3 aynı (iş,PR,baş) ikinci kez yazılmaz"
bash "$GB" is-a --depo "$D" --pr 10 --sha bbb >/dev/null 2>&1; [ "$(wc -l < "$FABRIKA_GOLGE_DEFTER")" -eq 2 ]; g $? "G4 aynı PR'a yeni baş (yeni commit) YENİ kayıttır"
bash "$GB" is-b --depo "$D" --pr 11 --sha ccc >/dev/null 2>&1; ! grep -q '"is-b"' "$FABRIKA_GOLGE_DEFTER"; g $? "G5 sınıflı iş kayıt dışı"
bash "$GB" yok-kart --depo "$D" --pr 12 --sha ddd >/dev/null 2>&1; RC=$?; [ "$RC" -eq 0 ] && ! grep -q 'yok-kart' "$FABRIKA_GOLGE_DEFTER"; g $? "G6 kartsız iş kayıt dışı, rc=0"
FABRIKA_GOLGE=0 bash "$GB" is-a --depo "$D" --pr 13 --sha eee >/dev/null 2>&1; ! grep -q '"pr": "13"' "$FABRIKA_GOLGE_DEFTER"; g $? "G7 FABRIKA_GOLGE=0 kapatır"

echo "════ G2 · görev adımı ve zil (sahte araçlar) ════"
cat > "$T/gorev-sahte.sh" <<'SH'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "$1" "$2" "$3" >> "${GOREV_KAYIT:?}"
SH
cat > "$T/zil-sahte.sh" <<'SH'
#!/usr/bin/env bash
printf '%s|%s\n' "$1" "$2" >> "${ZIL_KAYIT:?}"
SH
chmod +x "$T/gorev-sahte.sh" "$T/zil-sahte.sh"; export GOREV_KAYIT="$T/gorev.log" ZIL_KAYIT="$T/zil.log"
FABRIKA_GOREV_SH="$T/gorev-sahte.sh" FABRIKA_AILE_NOTIFY="$T/zil-sahte.sh" bash "$GB" is-a --depo "$D" --pr 20 --sha fff >/dev/null 2>&1
grep -q "^adim|gorev_X|\[birleştirirdim\] birleştirirdim: 'is-a'" "$GOREV_KAYIT"; g $? "G8 görev defterine '[birleştirirdim]' adımı yazılır"
grep -q "^SERDAR|golge: birleştirirdim: 'is-a'" "$ZIL_KAYIT"; g $? "G9 SERDAR'a zil gider"
grep -q "GERÇEKTEN birleştirilmedi" "$ZIL_KAYIT"; g $? "G10 zil 'gerçekten birleştirilmedi' der (yanlış anlaşılmasın)"
FABRIKA_GOREV_SH="$T/gorev-sahte.sh" FABRIKA_AILE_NOTIFY="$T/zil-sahte.sh" bash "$GB" is-a --depo "$D" --pr 20 --sha fff >/dev/null 2>&1
[ "$(wc -l < "$GOREV_KAYIT")" -eq 1 ] && [ "$(wc -l < "$ZIL_KAYIT")" -eq 1 ]; g $? "G11 ikinci koşuda adım ve zil TEKRARLANMAZ"
kart is-g duz
FABRIKA_GOREV_SH="$T/gorev-sahte.sh" FABRIKA_AILE_NOTIFY="$T/zil-sahte.sh" bash "$GB" is-g --depo "$D" --pr 21 --sha ggg >/dev/null 2>&1
[ "$(wc -l < "$GOREV_KAYIT")" -eq 1 ] && [ "$(wc -l < "$ZIL_KAYIT")" -eq 2 ]; g $? "G12 görevsiz kartta adım yazılmaz ama zil yine gider"

echo "════ G2b · zil sonucu söylenir, yutulmaz (göz 1. tur bulgu 1) ════"
cat > "$T/zil-bozuk.sh" <<'SH'
#!/usr/bin/env bash
echo "tmux: no server running" >&2; exit 7
SH
cat > "$T/zil-kuyruk.sh" <<'SH'
#!/usr/bin/env bash
echo "KUYRUK: SERDAR koltuğu boşalınca teslim edilecek"; exit 1
SH
chmod +x "$T/zil-bozuk.sh" "$T/zil-kuyruk.sh"; kart is-z1 duz; kart is-z2 duz; kart is-z3 duz
O="$(FABRIKA_AILE_NOTIFY="$T/zil-bozuk.sh" bash "$GB" is-z1 --depo "$D" --sha z1 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "golge zili GÖNDERİLEMEDİ (aile-notify rc 7): tmux: no server running" <<<"$O"; g $? "G13 zil gerçekten düşerse (rc 7) stderr'e GÖNDERİLEMEDİ yazılır, kayıt kalır, rc=0" "→ $O"
O="$(FABRIKA_AILE_NOTIFY="$T/zil-kuyruk.sh" bash "$GB" is-z2 --depo "$D" --sha z2 2>&1)"
grep -q "zil: kuyrukta" <<<"$O" && ! grep -q "GÖNDERİLEMEDİ" <<<"$O"; g $? "G14 meşgul koltukta zil KUYRUĞA girer: 'kuyrukta' denir, sorun sayılmaz" "→ $O"
O="$(FABRIKA_AILE_NOTIFY="$T/zil-sahte.sh" bash "$GB" is-z3 --depo "$D" --sha z3 2>&1)"; grep -q "zil: SERDAR'a gitti" <<<"$O"; g $? "G15 zil gittiyse 'SERDAR'a gitti' denir"

echo "════ G2c · eşzamanlı kapı koşuları tek kayıt yazar (göz 1. tur bulgu 2) ════"
kart is-y duz gorev_Y; : > "$GOREV_KAYIT"; : > "$ZIL_KAYIT"; rm -f "$FABRIKA_GOLGE_DEFTER"
for n in 1 2 3 4 5 6; do GOLGE_SINAV_BEKLE=0.4 FABRIKA_GOREV_SH="$T/gorev-sahte.sh" FABRIKA_AILE_NOTIFY="$T/zil-sahte.sh" bash "$GB" is-y --depo "$D" --pr 40 --sha yyy >/dev/null 2>&1 & done; wait
[ "$(grep -c '"is": "is-y"' "$FABRIKA_GOLGE_DEFTER")" -eq 1 ] && [ "$(wc -l < "$GOREV_KAYIT")" -eq 1 ] && [ "$(wc -l < "$ZIL_KAYIT")" -eq 1 ]; g $? "G16 altı eşzamanlı koşu (bakma–ekleme arası 0,4 sn gecikme): 1 satır, 1 görev adımı, 1 zil" "→ satır $(grep -c '"is": "is-y"' "$FABRIKA_GOLGE_DEFTER") adım $(wc -l < "$GOREV_KAYIT") zil $(wc -l < "$ZIL_KAYIT")"
MK="$T/golge-kilitsiz.sh"; python3 - "$GB" "$MK" <<'PYK'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a="fcntl.flock(f,fcntl.LOCK_EX)"; assert s.count(a)==1
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(a,"pass"))
PYK
: > "$GOREV_KAYIT"; : > "$ZIL_KAYIT"; rm -f "$FABRIKA_GOLGE_DEFTER"
for n in 1 2 3 4 5 6; do GOLGE_SINAV_BEKLE=0.4 FABRIKA_GOREV_SH="$T/gorev-sahte.sh" FABRIKA_AILE_NOTIFY="$T/zil-sahte.sh" bash "$MK" is-y --depo "$D" --pr 40 --sha yyy >/dev/null 2>&1 & done; wait
[ "$(grep -c '"is": "is-y"' "$FABRIKA_GOLGE_DEFTER")" -gt 1 ]; g $? "G17 mutant (flock söküldü): aynı kayıt birden çok yazılır → G16 bu mutantta düşerdi" "→ satır $(grep -c '"is": "is-y"' "$FABRIKA_GOLGE_DEFTER")"
MZ="$T/golge-zilyutan.sh"; python3 - "$GB" "$MZ" <<'PYZ'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a='else printf \'⚠ golge zili GÖNDERİLEMEDİ'; assert s.count(a)==1
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(a,'else true; printf \'\' #'))
PYZ
O="$(FABRIKA_AILE_NOTIFY="$T/zil-bozuk.sh" bash "$MZ" is-z1 --depo "$D" --sha z9 2>&1)"; ! grep -q "GÖNDERİLEMEDİ" <<<"$O"; g $? "G18 mutant (zil hatası yine yutuluyor): uyarı kayboluyor → G13 bu mutantta düşerdi"

echo "════ G3 · rapor ════"
cat > "$T/gh-sahte.sh" <<'SH'
#!/usr/bin/env bash
[ -n "${GH_RC:-}" ] && exit "$GH_RC"
cat "${GH_CIKTI:?}"
SH
chmod +x "$T/gh-sahte.sh"; export GOLGE_GH="$T/gh-sahte.sh" GH_CIKTI="$T/prler.json"
: > "$FABRIKA_GOLGE_DEFTER"; D2="$T/depo2"; mkdir -p "$D2/_agents/fabrika/kartlar"
for n in 1 2 3 4 5; do kart_is="r$n"; cp "$D/_agents/fabrika/kartlar/is-a.json" "$D2/_agents/fabrika/kartlar/$kart_is.json"; done
( cd "$D2" && git init -q -b main && git remote add origin https://github.com/ornek/depo.git ) >/dev/null 2>&1
for n in 1 2 3 4 5; do bash "$GB" "r$n" --depo "$D2" --pr "$((100+n))" --sha "s$n" >/dev/null 2>&1; done
cat > "$GH_CIKTI" <<'JS'
[{"number":101,"state":"MERGED","title":"feat: bir","body":"","mergedAt":"2026-10-26T10:00:00Z"},
 {"number":102,"state":"MERGED","title":"feat: iki","body":"","mergedAt":"2026-10-26T11:00:00Z"},
 {"number":103,"state":"CLOSED","title":"feat: üç","body":"","mergedAt":null},
 {"number":104,"state":"OPEN","title":"feat: dört","body":"","mergedAt":null},
 {"number":150,"state":"MERGED","title":"Revert \"feat: iki\"","body":"Reverts ornek/depo#102","mergedAt":"2026-10-27T10:00:00Z"}]
JS
O="$(bash "$GR" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "5 'birleştirirdim' kaydı · birleşti 1 · geri alındı 1 · birleşmeden kapandı 1 · hâlâ açık 1 · ölçülemedi 1" <<<"$O"; g $? "R1 beş kaydın akıbeti doğru sayılır (birleşti/geri/kapandı/açık/listede yok)" "→ $O"
grep -q "SAHTE YEŞİL: 2 / 3 hükme varmış" <<<"$O"; g $? "R2 sahte yeşil = geri alınan + birleşmeden kapanan; payda yalnız hükme varanlar (açık ve ölçülemeyen hariç)"
grep -q "r2 PR #102 — birleşti, sonra GERİ ALINDI" <<<"$O" && grep -q "r3 PR #103 — kapı geçti ama PR BİRLEŞMEDEN kapandı" <<<"$O"; g $? "R3 sahte yeşiller adıyla listelenir"
grep -q "r5 PR #105 — listede yok" <<<"$O"; g $? "R4 listede olmayan PR 'ölçülemedi' (birleşmedi sayılmaz)"
O="$(GH_RC=4 bash "$GR" 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "SAHTE YEŞİL: 0 / 0" <<<"$O"; g $? "R5 gh düşerse rc 3 ve 'temiz' denmez (hepsi ölçülemedi)" "→ rc=$RC"
# tavan: liste 5/5'e dayanınca hüküm LİSTEDEN verilmez; PR numarasıyla tek tek sorulur (view) + Revert numarayla aranır (list --search)
cat > "$T/gh-tekil.sh" <<'SH'
#!/usr/bin/env bash
[ "$2" = view ] && { [ -n "${GH_VIEW_RC:-}" ] && exit "$GH_VIEW_RC"; python3 -c "
import json,sys; n=int(sys.argv[1]); l=json.load(open(sys.argv[2])); p=[x for x in l if x['number']==n]
sys.exit(1) if not p else print(json.dumps(p[0]))" "$3" "$GH_CIKTI"; exit; }
case " $* " in *" --search "*) python3 -c "
import json,sys; print(json.dumps([x for x in json.load(open(sys.argv[1])) if x['title'].startswith('Revert')]))" "$GH_CIKTI" ;; *) cat "$GH_CIKTI" ;; esac
SH
chmod +x "$T/gh-tekil.sh"
O="$(GOLGE_GH="$T/gh-tekil.sh" GOLGE_TAVAN=5 bash "$GR" 2>&1)"; grep -q "5 'birleştirirdim' kaydı · birleşti 1 · geri alındı 1 · birleşmeden kapandı 1 · hâlâ açık 1 · ölçülemedi 1" <<<"$O"; g $? "R6 liste tavana dayanınca (5/5) kayıtlar PR numarasıyla tek tek sorulur: R1 ile AYNI akıbet sayıları (eskiden hepsi ölçülemedi)"
O="$(GOLGE_GH="$T/gh-tekil.sh" GOLGE_TAVAN=5 GH_VIEW_RC=4 bash "$GR" 2>&1)"; RC=$?; [ "$RC" -eq 3 ] && grep -q "ölçülemedi 5" <<<"$O"; g $? "R6b tavanda tek PR sorusu da düşerse hepsi ölçülemedi, rc 3 (yeşil denmez)" "→ rc=$RC"
O="$(FABRIKA_GOLGE_DEFTER="$T/yok.jsonl" bash "$GR" 2>&1)"; RC=$?; [ "$RC" -eq 3 ]; g $? "R7 defter yoksa rc 3 (kayıt yok ≠ sıfır sahte yeşil)"
O="$(bash "$GR" --gun 0 2>&1)"; grep -q "kayıt yok" <<<"$O"; g $? "R8 pencere dışı kayıtlar sayılmaz"
MT="$T/rapor-tavan-mutant.sh"; python3 - "$GR" "$MT" <<'PYT'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a='rev=json.load(open(rf,encoding="utf-8")) if os.path.exists(rf) else None'; assert s.count(a)==1
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(a,'rev=[]'))
PYT
O="$(GOLGE_GH="$T/gh-tekil.sh" GOLGE_TAVAN=5 bash "$MT" 2>&1)"; ! grep -q "geri alındı 1" <<<"$O"; g $? "R6c mutant (tavan yolunda Revert araması söküldü): geri alınan PR kaçar → R6 bu mutantta düşerdi"
# mutant: geri alma tespiti söküldü → R1/R2 düşmeli
MR="$T/rapor-mutant.sh"; python3 - "$GR" "$MR" <<'PYM'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a='geri=birl and any('; assert s.count(a)==1
open(sys.argv[2],"w",encoding="utf-8").write(s.replace(a,'geri=False and any('))
PYM
O="$(bash "$MR" 2>&1)"; ! grep -q "SAHTE YEŞİL: 2 / 3" <<<"$O"; g $? "R9 mutant (geri alma tespiti söküldü): sahte yeşil eksik sayılır → R2 bu mutantta düşerdi"
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
