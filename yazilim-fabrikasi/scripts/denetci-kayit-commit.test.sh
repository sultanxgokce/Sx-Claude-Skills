#!/usr/bin/env bash
# denetci-kayit-commit.test.sh — "denetçi kaydını iş dalına kendisi commit'ler" kapıları (görev B2DBS6).
#
# ÖLÇÜLMÜŞ VAKA (HENDESE, 22 Eki 2026): Sx #411 tur 3-6 + #412 tur 4-8 — dokuz göz turunun dokuzunda DENETIM-N.json iş alanında
# kayıtsız kaldı ve elle commit'lendi; 20 Eki filo taramasında kartı 'bitti' 47 alanın 27'sinde kalan YALNIZ kanıt dosyalarıydı.
#
# HERMETİK: gerçek denetçi çağrılmaz (DENETCI_KOMUT sahte betik); geçici birincil depo + iş adıyla aynı dalda worktree.
# Mutantlar geçici kopyada; kontrol kopyası önce gerçek betikle aynı kapıları geçmeli (kopyada çöken sınav sahte yeşil vermesin).
set -uo pipefail
export DALGIC_KAPALI=1   # ön-göz (ZP640T) sınavda KAPALI: gerçek model çağrısı yok; kendi sınavı denetci.test.sh T-ONGOZ
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-   # denetçi bitiş zili sınavda KAPALI
# Karne bu sınavın konusu değil (denetci-karne.test.sh'ın): açık kalırsa birincile yazılan karne e kapısındaki `git add -A` ile
# dala girer, sonra değişir ve `checkout main` reddedilir — göz #418 tur 1 bunu yakaladı (8 yutulan checkout hatası, 14/14 yeşil).
export DENETCI_KARNE=0
HERE="$(cd "$(dirname "$0")" && pwd)"
GECEN=0; DUSEN=0
g() { if [ "$1" -eq 0 ]; then GECEN=$((GECEN+1)); echo "  ✓ $2"; else DUSEN=$((DUSEN+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'rm -r -f "$T" 2>/dev/null' EXIT

GECTI='{"kod_puani":5,"dogru_sey":"E","ozet":"s","bulgular":[],"kanit_gorusu":"s"}'
NORMAL='{"kod_puani":3,"dogru_sey":"H","ozet":"s","bulgular":[{"ne":"gercek kusur","kanit":"k","konum":"x:1","agirlik":"uygulama"}],"kanit_gorusu":"s"}'
KD='{"kod_puani":4,"dogru_sey":"E","ozet":"s","bulgular":[{"ne":"canlida yok","kanit":"k","konum":"y:2","agirlik":"kutu-disi","kutu_disi_yuzey":"canli site"}],"kanit_gorusu":"s"}'

_sen() {  # _sen <scripts-dir> → geçen kapı anahtarları
  local S="$1" k="$T/k$RANDOM" o="" r
  local P="$k/birincil"; mkdir -p "$P"
  ( cd "$P" && git init -q -b main . && git config user.email s@s && git config user.name s && echo a > a.txt && git add -A && git commit -q -m "chore: sinav" )
  printf 'diff --git a/u/k.py b/u/k.py\n--- a/u/k.py\n+++ b/u/k.py\n@@ -1 +1 @@\n-e\n+y\n' > "$k/f.patch"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$SONUC_JSON"\n' > "$k/sd.sh"; chmod +x "$k/sd.sh"
  kart() { mkdir -p "$P/_agents/fabrika/kartlar"; printf '{"is":"%s","cumle":"s","istedi":"s","aldi":"s","cevaplar":{"geri_alinamaz":"h","para":"h","dis_yuzey":"h","yetki":"h"},"siniflar":[],"sultan":false,"durum":"acik","gecmis":[]}\n' "$1" > "$P/_agents/fabrika/kartlar/$1.json"; }
  alan() {  # alan <iş> [dal] → iş adıyla (ya da verilen adla) dal açan worktree; kanıt manifesti araçla
    local w="$k/wt-$1"; git -C "$P" worktree add -q -b "${2:-$1}" "$w" >/dev/null 2>&1; kart "$1"
    ( cd "$w" && KANIT_DEPO="$w" python3 "$S/kanit.py" olcum "$1" s --asama tek -- echo o >/dev/null 2>&1 && git add -A && git commit -q -m "chore: kanit" )
    echo "$w"; }
  kos() {  # kos <iş> <depo> <json> [ortam…]
    local is="$1" d="$2" js="$3"; shift 3
    ( cd "$d" && env KANIT_DEPO="$d" KART_DEPO="$P" DENETCI_KOMUT="$k/sd.sh" SONUC_JSON="$js" "$@" bash "$S/denetci.sh" "$is" --diff "$k/f.patch" --depo "$d" ) > "$k/son.log" 2>&1; }
  son_dosyalar() { git -C "$1" show --name-only --pretty=format: HEAD | sed '/^$/d' | sort | tr '\n' ' '; }

  # a · iş alanında (dal = iş adı) 5/E turunun kaydı dala commit'lenir: tek dosya, mesaj puanı taşır, ağaç temiz, push yok
  local W; W="$(alan is-a)"; local h0; h0="$(git -C "$W" rev-parse HEAD)"
  kos is-a "$W" "$GECTI"; r=$?
  [ $r -eq 0 ] && [ "$(git -C "$W" rev-list --count "$h0"..HEAD)" = 1 ] && [ "$(son_dosyalar "$W")" = "_agents/fabrika/kanit/is-a/DENETIM-1.json _agents/fabrika/kanit/is-a/KART.json " ] \
    && [ "$(git -C "$W" log -1 --format=%s)" = "docs: is-a göz tur 1 kaydı — 5/E" ] && [ -z "$(git -C "$W" status --porcelain)" ] \
    && grep -q "kayıt dala commit'lendi" "$k/son.log" && o="$o a"
  # b · kalan tur da commit'lenir (3/H, rc 1) — her turun kaydı dalda
  local Wb; Wb="$(alan is-b)"; kos is-b "$Wb" "$NORMAL"; r=$?
  [ $r -eq 1 ] && [ "$(son_dosyalar "$Wb")" = "_agents/fabrika/kanit/is-b/DENETIM-1.json _agents/fabrika/kanit/is-b/KART.json " ] && [ -z "$(git -C "$Wb" status --porcelain)" ] && [ "$(git -C "$Wb" log -1 --format=%s)" = "docs: is-b göz tur 1 kaydı — 3/H" ] && o="$o b"
  # c · pathspec'li: önceden STAGED başka değişiklik commit'e GİRMEZ, staged kalır
  local Wc; Wc="$(alan is-c)"; echo baska > "$Wc/baska.txt"; git -C "$Wc" add baska.txt
  kos is-c "$Wc" "$GECTI"
  [ "$(son_dosyalar "$Wc")" = "_agents/fabrika/kanit/is-c/DENETIM-1.json _agents/fabrika/kanit/is-c/KART.json " ] && git -C "$Wc" diff --cached --name-only | grep -qx baska.txt && o="$o c"
  # d · dal iş adı DEĞİLSE commit'lenmez ve söylenir
  local Wd; Wd="$(alan is-d baska-dal)"; local hd; hd="$(git -C "$Wd" rev-parse HEAD)"; kos is-d "$Wd" "$GECTI"
  [ "$(git -C "$Wd" rev-parse HEAD)" = "$hd" ] && grep -q "kayıt commit'lenmedi: dal 'baska-dal'" "$k/son.log" && o="$o d"
  # e · birincil checkout'ta (dal adı iş adı olsa da) commit'lenmez ve söylenir
  git -C "$P" checkout -q -b is-e || { echo KURULUM-HATASI; return 1; }; kart is-e; ( cd "$P" && KANIT_DEPO="$P" python3 "$S/kanit.py" olcum is-e s --asama tek -- echo o >/dev/null 2>&1 && git add -A && git commit -q -m "chore: kanit" )
  local he; he="$(git -C "$P" rev-parse HEAD)"; kos is-e "$P" "$GECTI"
  [ "$(git -C "$P" rev-parse HEAD)" = "$he" ] && grep -q "kayıt commit'lenmedi: birincil checkout" "$k/son.log" && o="$o e"
  git -C "$P" checkout -q main || { echo KURULUM-HATASI; return 1; }   # kurulum düşerse kapılar KIRMIZI (yutulmaz)
  # f · kutu-dışı bulgulu turda KUTU-DISI.jsonl de aynı commit'te
  local Wf; Wf="$(alan is-f)"; kos is-f "$Wf" "$KD"
  [ "$(son_dosyalar "$Wf")" = "_agents/fabrika/kanit/is-f/DENETIM-1.json _agents/fabrika/kanit/is-f/KART.json _agents/fabrika/kanit/is-f/KUTU-DISI.jsonl " ] && o="$o f"
  # g · DENETCI_KAYIT_COMMIT=0 → commit yok, söylenir
  local Wg; Wg="$(alan is-g)"; local hg; hg="$(git -C "$Wg" rev-parse HEAD)"; kos is-g "$Wg" "$GECTI" DENETCI_KAYIT_COMMIT=0
  [ "$(git -C "$Wg" rev-parse HEAD)" = "$hg" ] && grep -q "kayıt commit'i kapalı" "$k/son.log" && o="$o g"
  echo "$o"
}
_k() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

echo "════ B2DBS6 · denetçi kaydını iş dalına commit'ler ════"
S0="$(_sen "$HERE")"
_k a "$S0"; g $? "a iş alanında (dal = iş adı) 5/E kaydı + KART.json kopyası dala commit'lenir: mesaj puanlı, ağaç TEMİZ"
_k b "$S0"; g $? "b kalan tur (3/H) da commit'lenir"
_k c "$S0"; g $? "c pathspec'li: önceden staged başka değişiklik commit'e girmez, staged kalır"
_k d "$S0"; g $? "d dal iş adı değilse commit'lenmez, söylenir"
_k e "$S0"; g $? "e birincil checkout'ta commit'lenmez, söylenir"
_k f "$S0"; g $? "f kutu-dışı bulgulu turda KUTU-DISI.jsonl aynı commit'te"
_k g "$S0"; g $? "g DENETCI_KAYIT_COMMIT=0 → commit yok, söylenir"

echo "── MUTASYON (betik kopyasında, kontrol şartlı) ──"
_kopya() { local d="$T/m-$1"; mkdir -p "$d"; cp -r "$HERE/." "$d/"; echo "$d"; }
k0="$(_kopya kontrol)"; [ "$(_sen "$k0")" = "$S0" ] && [ -n "$S0" ]; g $? "kontrol kopyası gerçek betikle aynı kapıları geçiyor"
_m() {  # _m <anahtar> <eski> <yeni> <açıklama>
  local d; d="$(_kopya "$1-$RANDOM")"
  python3 - "$d/denetci.sh" "$2" "$3" <<'PY' || { g 1 "mutant ($4): desen tutmadı"; return; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding='utf-8').read(); assert s.count(a)==1; open(p,'w',encoding='utf-8').write(s.replace(a,b))
PY
  ! _k "$1" "$(_sen "$d")"; g $? "mutant ($4) → '$1' kapısı düşüyor"
}
_m a 'kayit_commitle
# 🔴 KARNE' '# 🔴 KARNE' "kayıt commit'i çağrılmıyor"
_m c 'git commit -q -m "docs: $IS göz tur $TUR kaydı — $PUAN/$DOGRU" -- "${yol[@]}"' 'git commit -q -m "docs: $IS göz tur $TUR kaydı — $PUAN/$DOGRU"' "commit pathspec'siz (staged her şey girer)"
_m d '  if [ "$dal" != "$IS" ]; then' '  if false; then' "dal denetimi yok"
_m e '  if [ "$(cd "$DEPO" && pwd -P)" = "$(cd "$KART_DEPO" 2>/dev/null && pwd -P)" ]; then' '  if false; then' "birincil checkout denetimi yok"
_m f '  [ -f "$DZ/KUTU-DISI.jsonl" ] && yol+=' '  false && yol+=' "KUTU-DISI.jsonl commit'e girmiyor"
_m a '  [ -f "$DZ/KART.json" ] && yol+=' '  false && yol+=' "KART.json kopyası kayıtsız kalıyor"

echo ""; echo "── SONUÇ: $GECEN geçti · $DUSEN kaldı ──"
[ "$DUSEN" -eq 0 ]
