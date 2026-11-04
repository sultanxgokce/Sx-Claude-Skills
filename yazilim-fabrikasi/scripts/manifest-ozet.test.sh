#!/usr/bin/env bash
# manifest-ozet.test.sh — denetçi istemindeki kanıt manifesti görünümü (gorev_01M6AX7Y31S4R4GK6NMDKT29NK).
# Hermetik: fikstürü kendisi üretir, ağ/depo yok. MUTANT_D=<denetci.sh yolu>, MUTANT_O=<manifest-ozet.py yolu> ile sahte kopya sınanır.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OZET="${MUTANT_O:-$HERE/manifest-ozet.py}"
DEN="${MUTANT_D:-$HERE/denetci.sh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# fikstür: N geçerli ölçüm + G (hedef ölçüm + ilan) çifti; neden uzun (mihenk vakasının gövdesi)
python3 - "$T" <<'PY'
import json, sys, hashlib
T = sys.argv[1]
def sha(s): return hashlib.sha256(s.encode()).hexdigest()
def kur(ad, n_gecerli, n_gecersiz, neden_uzun, hedef_eksik=False):
    k = []
    for i in range(n_gecerli):
        k.append({"tur": "olcum", "etiket": f"gecerli{i}", "asama": "sonra", "dosya": f"olcum-gecerli{i}-sonra.txt", "sha256": sha(f"g{i}"),
                  "komut": ["bash", "x.sh", str(i)], "rc": 0, "renk": "yesil", "zaman": "2026-11-01T10:00:00+03:00", "olcum_id": f"G{i:030d}"})
    for i in range(n_gecersiz):
        oid = f"X{i:030d}"
        if not (hedef_eksik and i == 0):
            k.append({"tur": "olcum", "etiket": f"bozuk{i}", "asama": "tek", "dosya": f"olcum-bozuk{i}-tek.txt", "sha256": sha(f"b{i}"),
                      "komut": ["bash", "-c", "uzun komut " + "z" * 200], "rc": 0, "renk": "yesil", "zaman": "2026-11-01T10:00:00+03:00", "olcum_id": oid})
        k.append({"tur": "gecersiz", "etiket": f"bozuk{i}", "asama": "tek", "dosya": f"gecersiz-olcum-bozuk{i}-{sha(str(i))[:12]}.txt", "sha256": sha(f"i{i}"),
                  "hedef_dosya": f"olcum-bozuk{i}-tek.txt", "hedef_olcum_id": oid, "hedef_sha256": sha(f"b{i}"), "hedef_zaman": "2026-11-01T10:00:00+03:00",
                  "hedef_renk": "yesil", "neden": ("kart daraltıldı: " + "ölçüm yanlış kapsamı ölçüyordu " * neden_uzun), "kim": "SERDAR", "karsi": None, "rc": 0,
                  "renk": "ilan", "zaman": "2026-11-01T11:00:00+03:00", "olcum_id": f"I{i:030d}"})
    json.dump({"is": "fikstur", "arac": "kanit.py/0.7.0", "guncelleme": "2026-11-01T12:00:00+03:00", "kayitlar": k, "imza": "SAHTE"},
              open(f"{T}/{ad}.json", "w"), ensure_ascii=False, indent=2)
kur("karma", 3, 2, 3)
kur("temiz", 4, 0, 1)
kur("eksikhedef", 2, 2, 2, hedef_eksik=True)
kur("mihenk", 23, 14, 20)       # 23 geçerli + 14 (hedef+ilan)=28 geçersizlik kaydı = 51 kayıt
open(f"{T}/bozuk.json", "w").write("{ bu json degil")
PY

echo "── manifest-ozet.py ──"
python3 "$OZET" "$T/karma.json" > "$T/karma.out" 2>"$T/karma.err"; RC=$?
[ "$RC" -eq 0 ] && ok "K1 karma manifest rc=0" || fail "K1 rc=$RC: $(cat "$T/karma.err")"
[ "$(grep -c '^⛔ GEÇERSİZ' "$T/karma.out")" -eq 2 ] && ok "K2 iki ilan = iki TEK satır" || fail "K2 satır sayısı: $(grep -c '^⛔ GEÇERSİZ' "$T/karma.out")"
for i in 0 1 2; do grep -q "\"etiket\": \"gecerli$i\"" "$T/karma.out" || { fail "K3 geçerli kayıt gecerli$i DÜŞTÜ"; break; }; done; [ "$FAIL" -eq 0 ] && ok "K3 üç geçerli kayıt tam duruyor"
! grep -q '"tur": "gecersiz"' "$T/karma.out" && ok "K4 ilan kaydı JSON gövdesinde YOK (tek satıra indi)" || fail "K4 ilan hâlâ JSON olarak basılıyor"
! grep -q 'olcum-bozuk0-tek.txt".*sha256' "$T/karma.out" && ! grep -q 'hedef_sha256' "$T/karma.out" && ok "K5 sha/kimlik alanları geçersizden gelmiyor" || fail "K5 sha alanı sızdı"
grep -q 'imza' "$T/karma.out" && grep -q '"is": "fikstur"' "$T/karma.out" && ok "K6 üst alanlar (is, imza) korundu" || fail "K6 üst alan kayboldu"
grep -q 'GÖRÜNÜM' "$T/karma.out" && ok "K7 başlık görünümün özet olduğunu ve diskteki imzalı dosyanın aynen durduğunu söylüyor" || fail "K7 başlık yok"
grep -q 'uzun komut' "$T/karma.out" && ok "K8 hedefin komutu (kısaltılmış) satırda" || fail "K8 komut yok"
python3 "$OZET" "$T/temiz.json" > "$T/temiz.out"; [ "$(grep -c '"tur": "olcum"' "$T/temiz.out")" -eq 4 ] && ! grep -q 'GEÇERSİZ İLAN EDİLENLER' "$T/temiz.out" && ok "T1 geçersizsiz manifest: 4 kayıt aynen, bölüm yok" || fail "T1: $(cat "$T/temiz.out" | head -3)"
python3 "$OZET" "$T/bozuk.json" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "B1 bozuk dosya rc=2 (çağıran ham cat'e düşer)" || fail "B1 bozuk dosya rc≠2"
python3 "$OZET" "$T/yok.json" >/dev/null 2>&1; [ "$?" -eq 2 ] && ok "B2 olmayan dosya rc=2" || fail "B2"
python3 "$OZET" "$T/eksikhedef.json" > "$T/eh.out" 2>/dev/null; [ "$(grep -c '^⛔ GEÇERSİZ' "$T/eh.out")" -eq 2 ] && grep -q '"etiket": "gecerli1"' "$T/eh.out" && ok "E1 hedefi bulunamayan ilan YİNE tek satır, geçerli kayıt düşmedi" || fail "E1: $(grep -c '^⛔ GEÇERSİZ' "$T/eh.out") satır"
HAM=$(wc -c < "$T/mihenk.json"); OZ=$(python3 "$OZET" "$T/mihenk.json" | wc -c)
echo "     mihenk ölçeği (51 kayıt, 28'i geçersizlik): ham=$HAM özet=$OZ bayt"
[ "$OZ" -lt $((HAM / 2)) ] && ok "M1 mihenk ölçeğinde görünüm ham dosyanın YARISINDAN küçük" || fail "M1 kazanç yok: $OZ / $HAM"
[ "$(python3 "$OZET" "$T/mihenk.json" | grep -c '^⛔ GEÇERSİZ')" -eq 14 ] && ok "M2 14 ilan = 14 satır (28 kayıt → 14 satır)" || fail "M2"

echo "── denetci.sh bağlantısı ──"
grep -q 'manifest-ozet.py' "$DEN" && ok "D1 denetci.sh manifest-ozet.py'yi çağırıyor" || fail "D1 çağrı YOK (ham cat kalmış)"
grep -q 'manifest-ozet.py" "\$DZ/KANIT.json" 2>/dev/null || cat "\$DZ/KANIT.json"' "$DEN" && ok "D2 özet çıkmazsa ham dosyaya düşer (eksik veri yok)" || fail "D2 yedek yol yok"

echo
echo "SONUÇ: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
