#!/usr/bin/env bash
# denetci-karne.test.sh — "denetçi karneyi kendisi yazar" + "5/H ile biten iş kırıldı adayıdır" kapıları (görev NPTHAQ 2. yarı).
#
# ÖLÇÜLMÜŞ VAKA (SERDAR, 17 Eki 2026): karne.jsonl o hafta 0 satır (son 29 Eyl), yalnız Nexus'ta vardı; denetci.sh karne.sh'ı
# çağırmıyordu. denetci-test-mutant-suresi (Sx) ve gorev-satir-sade-sultan (cloudtop) 5/H ile bitti — hiçbir yerde sayılmadı.
#
# HERMETİK: gerçek denetçi çağrılmaz (DENETCI_KOMUT sahte betik); geçici birincil depo + iş adıyla aynı dalda worktree.
# Mutantlar geçici kopyada; kontrol kopyası önce gerçek betikle aynı kapıları geçmeli (kopyada çöken sınav sahte yeşil vermesin).
set -uo pipefail
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-   # denetçi bitiş zili sınavda KAPALI
HERE="$(cd "$(dirname "$0")" && pwd)"
GECEN=0; DUSEN=0
g() { if [ "$1" -eq 0 ]; then GECEN=$((GECEN+1)); echo "  ✓ $2"; else DUSEN=$((DUSEN+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT

GECTI='{"kod_puani":5,"dogru_sey":"E","ozet":"s","bulgular":[],"kanit_gorusu":"s"}'
NORMAL='{"kod_puani":3,"dogru_sey":"H","ozet":"s","bulgular":[{"ne":"gercek kusur","kanit":"k","konum":"x:1","agirlik":"uygulama"}],"kanit_gorusu":"s"}'

_sen() {  # _sen <scripts-dir> → geçen kapı anahtarları
  local S="$1" k="$T/k$RANDOM" o="" r
  local P="$k/birincil" KR="$k/birincil/_agents/fabrika/karne.jsonl"; mkdir -p "$P"
  ( cd "$P" && git init -q -b main . && git config user.email s@s && git config user.name s && echo a > a.txt && git add -A && git commit -q -m "chore: sinav" )
  printf 'diff --git a/u/k.py b/u/k.py\n--- a/u/k.py\n+++ b/u/k.py\n@@ -1 +1 @@\n-e\n+y\n' > "$k/f.patch"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$SONUC_JSON"\n' > "$k/sd.sh"; chmod +x "$k/sd.sh"
  kart() { mkdir -p "$P/_agents/fabrika/kartlar"; printf '{"is":"%s","cumle":"s","istedi":"s","aldi":"s","cevaplar":{"geri_alinamaz":"h","para":"h","dis_yuzey":"h","yetki":"h"},"siniflar":[],"sultan":false,"durum":"%s","gecmis":[]}\n' "$1" "${2:-acik}" > "$P/_agents/fabrika/kartlar/$1.json"; }
  alan() {  # alan <iş> → iş adıyla dal açan worktree; kanıt manifesti araçla
    local w="$k/wt-$1"; git -C "$P" worktree add -q -b "$1" "$w" >/dev/null 2>&1; kart "$1"
    ( cd "$w" && KANIT_DEPO="$w" python3 "$S/kanit.py" olcum "$1" s --asama tek -- echo o >/dev/null 2>&1 && git add -A && git commit -q -m "chore: kanit" )
    echo "$w"; }
  kos() {  # kos <iş> <depo> <json> [ortam…]
    local is="$1" d="$2" js="$3"; shift 3
    ( cd "$d" && env KANIT_DEPO="$d" KART_DEPO="$P" DENETCI_KOMUT="$k/sd.sh" SONUC_JSON="$js" "$@" bash "$S/denetci.sh" "$is" --diff "$k/f.patch" --depo "$d" ) > "$k/son.log" 2>&1; }
  satir() {  # satir <iş> <alan> → o işin karne satırlarından alanın değerleri (boşlukla)
    [ -f "$KR" ] || return 0
    python3 -c "import json,sys;print(' '.join(str(r.get(sys.argv[2])) for r in map(json.loads,open(sys.argv[1],encoding='utf-8')) if r.get('is')==sys.argv[3]))" "$KR" "$2" "$1"; }

  # a · iş alanında 5/E turu → BİRİNCİL depodaki karneye tek satır (iş alanında karne YOK), denetçi söyler, rc 0
  local W; W="$(alan is-a)"; kos is-a "$W" "$GECTI"; r=$?
  [ $r -eq 0 ] && [ "$(satir is-a tur)" = 1 ] && [ "$(satir is-a puan)" = 5 ] && [ "$(satir is-a dogru)" = E ] && [ "$(satir is-a gecti)" = True ] \
    && [ ! -e "$W/_agents/fabrika/karne.jsonl" ] && grep -q "✓ karne: is-a · tur 1" "$k/son.log" && o="$o a"
  # b · kalan tur (3/H) da yazılır: geçmedi, rc 1 aynen
  local Wb; Wb="$(alan is-b)"; kos is-b "$Wb" "$NORMAL"; r=$?
  [ $r -eq 1 ] && [ "$(satir is-b puan)" = 3 ] && [ "$(satir is-b gecti)" = False ] && o="$o b"
  # c · ikinci tur ikinci satır (her turun satırı; son satır = son tur)
  local Wc; Wc="$(alan is-c)"; kos is-c "$Wc" "$NORMAL"; kos is-c "$Wc" "$GECTI"; r=$?
  [ $r -eq 0 ] && [ "$(satir is-c tur)" = "1 2" ] && [ "$(satir is-c dogru)" = "H E" ] && o="$o c"
  # d · DENETCI_KARNE=0 → satır yok, söylenir
  local Wd; Wd="$(alan is-d)"; kos is-d "$Wd" "$GECTI" DENETCI_KARNE=0
  [ -z "$(satir is-d tur)" ] && grep -q "karne kapalı (DENETCI_KARNE=0)" "$k/son.log" && o="$o d"
  # e · karne YAZILAMAZSA söylenir, turun sonucu (rc 0) değişmez — karne kapı değil kayıttır
  local Pe="$k/birincil-e"; git -C "$P" worktree add -q -b is-e "$k/wt-is-e" >/dev/null 2>&1; kart is-e
  ( cd "$k/wt-is-e" && KANIT_DEPO="$k/wt-is-e" python3 "$S/kanit.py" olcum is-e s --asama tek -- echo o >/dev/null 2>&1 && git add -A && git commit -q -m "chore: kanit" )
  [ -f "$KR" ] && mv "$KR" "$Pe.yedek"; mkdir -p "$KR"   # defter yolu dizin → yazma düşer (mutantta defter hiç açılmamış olabilir)
  kos is-e "$k/wt-is-e" "$GECTI"; r=$?
  rmdir "$KR"; [ -f "$Pe.yedek" ] && mv "$Pe.yedek" "$KR"
  [ $r -eq 0 ] && grep -q "⚠ karne yazılamadı" "$k/son.log" && grep -q "✓ GEÇTİ" "$k/son.log" && o="$o e"
  # j · birincil checkout'ta koşan denetçi de yazar (kayıt commit'i orada yok ama karne var)
  git -C "$P" checkout -q -b is-j || { echo KURULUM-HATASI; return 1; }; kart is-j
  ( cd "$P" && KANIT_DEPO="$P" python3 "$S/kanit.py" olcum is-j s --asama tek -- echo o >/dev/null 2>&1 )
  kos is-j "$P" "$GECTI"; [ "$(satir is-j tur)" = 1 ] && o="$o j"
  git -C "$P" checkout -q -f main || { echo KURULUM-HATASI; return 1; }   # kurulum düşerse kapılar KIRMIZI (yutulmaz)
  # p · birincil checkout'ta karne zaten açıkken YEREL kip (fark kendisi, --diff yok) kir saymaz — yoksa karne bir sonraki turu kilitler
  git clone -q --bare "$P" "$k/o.git" 2>/dev/null; git -C "$P" remote add origin "$k/o.git"; git -C "$P" fetch -q origin 2>/dev/null
  git -C "$P" checkout -q -b is-p || { echo KURULUM-HATASI; return 1; }; echo p > "$P/p.txt"; git -C "$P" add p.txt; git -C "$P" commit -q -m "feat: p"; kart is-p
  ( cd "$P" && KANIT_DEPO="$P" python3 "$S/kanit.py" olcum is-p s --asama tek -- echo o >/dev/null 2>&1 )
  [ -f "$KR" ] && ( cd "$P" && env KANIT_DEPO="$P" KART_DEPO="$P" DENETCI_KOMUT="$k/sd.sh" SONUC_JSON="$GECTI" bash "$S/denetci.sh" is-p --depo "$P" < /dev/null ) > "$k/son.log" 2>&1 \
    && [ "$(satir is-p tur)" = 1 ] && o="$o p"
  git -C "$P" checkout -q -f main || { echo KURULUM-HATASI; return 1; }

  # ── karne.sh ozet: kırıldı adayı ──
  local Q="$k/ozet"; mkdir -p "$Q"; ( cd "$Q" && git init -q -b main . )
  den() {  # den <iş> <tur> <puan> <E/H> [kart-durumu|yok]
    mkdir -p "$Q/_agents/fabrika/kanit/$1" "$Q/_agents/fabrika/kartlar"
    python3 - "$Q/_agents/fabrika/kanit/$1/DENETIM-$2.json" "$2" "$3" "$4" "$1" <<'PY'
import json,sys,datetime
p,tur,puan,dogru,is_=sys.argv[1:]
json.dump({"tur":int(tur),"is":is_,"pr":"7","yazan":"claude","denetci":"codex","zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),"sonuc":{"kod_puani":int(puan),"dogru_sey":dogru,"ozet":"","bulgular":[],"kanit_gorusu":""}},open(p,"w"))
PY
    [ "${5:-acik}" = yok ] || printf '{"is":"%s","durum":"%s"}\n' "$1" "${5:-acik}" > "$Q/_agents/fabrika/kartlar/$1.json"
    ( cd "$Q" && KANIT_DEPO="$Q" bash "$S/karne.sh" yaz "$1" ) >/dev/null 2>&1; }
  den is-k 3 5 H bitti; den is-l 3 5 H acik; den is-m 3 5 H yok; den is-n 2 5 E bitti; den is-n2 3 4 H bitti
  local OZ; OZ="$(cd "$Q" && KANIT_DEPO="$Q" bash "$S/karne.sh" ozet 2>&1)"
  # k · kartı bitmiş 5/H iş kırıldı adayı: sayı 1 ve satırı
  grep -q "KIRILDI ADAYI (5/H ile bitti): 1" <<<"$OZ" && grep -q "? is-k (PR 7) — 5/H ile bitti" <<<"$OZ" && o="$o k"
  # l · kartı AÇIK 5/H iş aday değil (iş sürüyor)
  grep -q "KIRILDI ADAYI (5/H ile bitti): 1" <<<"$OZ" && ! grep -q "? is-l " <<<"$OZ" && o="$o l"
  # m · kartı okunamayan 5/H iş sayılmaz ama SÖYLENİR (ölçülemedi ≠ aday değil)
  grep -q "◻ is-m (PR 7) — son tur 5/H, kartı okunamadı" <<<"$OZ" && ! grep -q "? is-m " <<<"$OZ" && o="$o m"
  # n · 5/E ve 4/H ile biten aday değil (yalnız 5/H)
  ! grep -q "? is-n " <<<"$OZ" && ! grep -q "? is-n2 " <<<"$OZ" && o="$o n"
  # o · aynı turun satırı ikinci kez yazılmaz
  local ik; ik="$(cd "$Q" && KANIT_DEPO="$Q" bash "$S/karne.sh" yaz is-k 2>&1)"
  [ "$(grep -c '"is": "is-k"' "$Q/_agents/fabrika/karne.jsonl")" = 1 ] && grep -q "zaten yazılı" <<<"$ik" && o="$o o"
  echo "$o"
}
_k() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

echo "════ NPTHAQ · denetçi karneyi kendisi yazar ════"
S0="$(_sen "$HERE")"
_k a "$S0"; g $? "a iş alanındaki 5/E turu birincil depodaki karneye tek satır yazar (iş alanında karne yok), söylenir"
_k b "$S0"; g $? "b kalan tur (3/H) da yazılır, rc 1 aynen"
_k c "$S0"; g $? "c ikinci tur ikinci satır: tur 1 2 · H E"
_k d "$S0"; g $? "d DENETCI_KARNE=0 → satır yok, söylenir"
_k e "$S0"; g $? "e karne yazılamazsa söylenir, GEÇTİ ve rc 0 değişmez"
_k j "$S0"; g $? "j birincil checkout'ta koşan denetçi de yazar"
_k p "$S0"; g $? "p birincil checkout'ta karne açıkken yerel kip (fark kendisi) karneyi kir saymaz"
echo "════ NPTHAQ · karne özeti: 5/H ile biten iş kırıldı adayı ════"
_k k "$S0"; g $? "k kartı bitmiş 5/H iş kırıldı adayı (sayı 1 + satırı)"
_k l "$S0"; g $? "l kartı açık 5/H iş aday değil"
_k m "$S0"; g $? "m kartı okunamayan 5/H iş sayılmaz ama söylenir"
_k n "$S0"; g $? "n 5/E ve 4/H ile biten iş aday değil"
_k o "$S0"; g $? "o aynı turun satırı ikinci kez yazılmaz"

echo "── MUTASYON (betik kopyasında, kontrol şartlı) ──"
_kopya() { local d="$T/m-$1"; mkdir -p "$d"; cp -r "$HERE/." "$d/"; echo "$d"; }
k0="$(_kopya kontrol)"; [ "$(_sen "$k0")" = "$S0" ] && [ -n "$S0" ]; g $? "kontrol kopyası gerçek betikle aynı kapıları geçiyor"
_m() {  # _m <anahtar> <dosya> <eski> <yeni> <açıklama>
  local d; d="$(_kopya "$1-$RANDOM")"
  python3 - "$d/$2" "$3" "$4" <<'PY' || { g 1 "mutant ($5): desen tutmadı"; return; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding='utf-8').read(); assert s.count(a)==1; open(p,'w',encoding='utf-8').write(s.replace(a,b))
PY
  ! _k "$1" "$(_sen "$d")"; g $? "mutant ($5) → '$1' kapısı düşüyor"
}
_m a denetci.sh 'karne_yaz
# 🔴 GÖZ ADIMI GÖREVE' '# 🔴 GÖZ ADIMI GÖREVE' "denetçi karneyi çağırmıyor"
_m a denetci.sh 'KANIT_DEPO="" bash "$HERE/karne.sh" yaz "$IS" --depo "$KART_DEPO"' 'bash "$HERE/karne.sh" yaz "$IS"' "birincil yönlendirmesi yok → karne iş alanına düşüyor"
_m d denetci.sh '[ "${DENETCI_KARNE:-1}" = 1 ] ||' 'true ||' "DENETCI_KARNE=0 dinlenmiyor"
_m e denetci.sh 'else _bilgi "   ⚠ karne yazılamadı' 'else exit 9; _bilgi "   ⚠ karne yazılamadı' "karne düşüşü turun sonucunu değiştiriyor"
_m p denetci.sh "grep -v -E '^.. _agents/fabrika/((kanit|kartlar)/|karne\\.jsonl\$)'" "grep -v -E '^.. _agents/fabrika/(kanit|kartlar)/'" "karne kir sayılıyor"
_m l karne.sh 'if durum=="bitti": aday.append(r)' 'aday.append(r)' "kart durumu okunmuyor"
_m n karne.sh 'if r["puan"]!=5 or r["dogru"]!="H": continue' 'if r["puan"]!=5: continue' "doğru-şey şartı yok"
_m m karne.sh 'except (OSError,ValueError): okunamadi.append(r); continue' 'except (OSError,ValueError): continue' "okunamayan kart sessiz düşüyor"
_m o karne.sh 'print(f"· karne: {is_} tur {d['"'"'tur'"'"']} zaten yazılı"); sys.exit(0)' 'pass' "aynı tur ikinci kez yazılıyor"

echo ""; echo "── SONUÇ: $GECEN geçti · $DUSEN kaldı ──"
[ "$DUSEN" -eq 0 ]
