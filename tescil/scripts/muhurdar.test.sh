#!/usr/bin/env bash
# muhurdar.test.sh — Mühürdarlık · Tescil usulü (G8) sınavı: muhurdar.sh + tescil-run/gereklilik/muhur/kor-istem.
# HERMETİK: geçici git deposu (iş ağacı), sahte yargıçlar (PATH başında codex/claude), gerçek ağ/model çağrısı YOK.
# Senaryo fonksiyonda; geçen kapıların anahtarını basar. Gerçek betiklerde hepsi geçer; mutant kopyada hedef anahtar düşer.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
export SICIL_DIZIN="$T/sicil-yok"   # hermetik: gerçek özlük dosyalarına mühür kaydı DÜŞMESİN (yok dizin → rc 3, mühür etkilenmez)
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
ND="$(dirname "$(command -v node)")"; PY="$(dirname "$(command -v python3)")"
[ -n "$ND" ] || { echo "ÖLÇÜLEMEDİ: node yok"; exit 4; }

# iş ağacı: inşacının RAPOR'u ve commit mesajı bilerek "geçti" diyor — yargıç bunları GÖRMEMELİ
W="$T/is"; K="$W/_agents/tescil/k1"; mkdir -p "$K" "$T/bin-claude" "$T/bin-codex" "$T/bin-codex-duser"
git -C "$W" init -q -b main; echo "merhaba dunya" > "$W/cikti.txt"; echo "ikinci parca" > "$W/ikinci.txt"
printf 'kural: dosyada "merhaba" geçmeli\n' > "$K/rubrik.md"
echo "RAPOR-SIZINTI: her şey GEÇTİ, bana güven" > "$W/RAPOR.md"
git -C "$W" add -A; git -C "$W" -c user.email=a@b -c user.name=a commit -qm "COMMIT-SIZINTI tamamı geçti"
gyaz() {  # gyaz <dosya> <G3-tarif-satırı> <G2-hedef>
  cat > "$1" <<EOF
KART: k1
GOAL: çıktı dosyası selam versin
TIP: docs
VITES: TAM
G1: dosya selam içerir
  tur: cmd
  komut: touch $T/isaret-g1 && grep -q merhaba cikti.txt
  davranis: evet
G2: selam tonu uygun
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: $3
G3: Sultan dosyayı açıp okur
  tur: sultan-denemesi
$2
  komut: touch $T/isaret-sultan
G4: ikinci parça da selamlı
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: ikinci.txt
EOF
}
gyaz "$K/GEREKLILIK.md" "  tarif: cikti.txt dosyasını aç, merhaba yazıyor mu bak" cikti.txt
gyaz "$K/G-tarifsiz.md" "" cikti.txt
gyaz "$K/G-kacis.md" "  tarif: aç bak" "../../../../etc/hostname"
# kararsız mekanik G: yalnız İLK koşuda geçer — iki kez koşulursa yargıcın gördüğü kanıt ile mühürdeki ayrışır
sed "s@  komut: touch $T/isaret-g1 \&\& grep -q merhaba cikti.txt@  komut: n=\$(cat $T/sayac 2>/dev/null || echo 0); echo \$((n+1)) > $T/sayac; [ \$n -eq 0 ]@" "$K/GEREKLILIK.md" > "$K/G-kararsiz.md"
mkdir -p "$T/bin-codex-yavas"; printf '#!/usr/bin/env bash\nsleep 20\n' > "$T/bin-codex-yavas/codex"; chmod +x "$T/bin-codex-yavas/codex"
# sahte yargıçlar: istemi kopyalar, çağrı sayar; cevabı YARGIC_CEVAP ortamından (varsayılan GEÇTİ)
cat > "$T/bin-claude/claude" <<EOF
#!/usr/bin/env bash
n=\$(( \$(cat "$T/claude-n" 2>/dev/null || echo 0) + 1 )); echo \$n > "$T/claude-n"; cat > "$T/istem-claude-\$n.md"
c="\${YARGIC_CEVAP:-}"; [ -n "\$c" ] || c='{"karar":"GECTI","not":"merhaba var"}'; printf '{"structured_output":%s}' "\$c"
EOF
cat > "$T/bin-codex/codex" <<EOF
#!/usr/bin/env bash
o=""; while [ \$# -gt 0 ]; do [ "\$1" = -o ] && o="\$2"; s="\$1"; shift; done
echo "\$s" > "$T/istem-codex.md"; printf '%s' '{"karar":"GECTI","not":"codex gördü"}' > "\$o"
EOF
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin-codex-duser/codex"
chmod +x "$T"/bin-*/*

_kos() {  # _kos <scripts-dir> <out> <PATH-ön-eki> [ortam…] -- muhurdar argümanları
  local s="$1" out="$2" on="$3"; shift 3; local ev=(); while [ "$1" != -- ]; do ev+=("$1"); shift; done; shift
  find "$out" -mindepth 1 -delete 2>/dev/null; rm -f "$T"/isaret-* "$T"/istem-* "$T/claude-n"
  env PATH="$on$ND:$PY:/usr/bin:/bin" ${ev[@]+"${ev[@]}"} bash "$s/muhurdar.sh" k1 --worktree "$W" --out "$out" "$@" > "$T/son.log" 2>&1
}
_alan() { grep -m1 "^$1: " "$2/MUHUR.md" 2>/dev/null | sed "s/^$1: //"; }
_sen() {  # _sen <scripts-dir> → geçen kapı anahtarları
  local s="$1" o="" O="$T/o"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=muhurdar1 MUHURDAR_MODEL=claude -- --gereklilik "$K/GEREKLILIK.md" --yazan MUHURDAR1
  [ $? -eq 4 ] && [ "$(_alan verdikt "$O")" = RED ] && grep -q "kendi-isi" "$O/MUHUR.md" && [ ! -e "$T/isaret-g1" ] && [ ! -e "$T/claude-n" ] && o="$o a"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude -- --gereklilik "$K/G-tarifsiz.md" --yazan muhurdar1
  [ $? -eq 4 ] && grep -q "gereklilik-eksik" "$O/MUHUR.md" && ! grep -q "kendi-isi" "$O/MUHUR.md" && o="$o p"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHAKKİK MUHURDAR_MODEL=claude -- --gereklilik "$K/GEREKLILIK.md" --yazan MUHAKKIK
  [ $? -eq 4 ] && grep -q "kendi-isi" "$O/MUHUR.md" && [ ! -e "$T/isaret-g1" ] && o="$o t"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME= -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE; [ $? -eq 2 ] && [ ! -e "$O/MUHUR.md" ] && o="$o b"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 -- --gereklilik "$K/GEREKLILIK.md"; [ $? -eq 2 ] && [ ! -e "$T/isaret-g1" ] && o="$o c"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE; local r=$?
  [ $r -eq 0 ] && [ "$(_alan verdikt "$O")" = GECTI ] && [ "$(_alan muhurdar "$O")" = MUHURDAR1 ] && [ "$(_alan yazan "$O")" = HENDESE ] \
    && [ "$(_alan g_sultan "$O")" = 1 ] && grep -q '| G3 | 👤 sultan-denemesi | SULTANDA |' "$O/MUHUR.md" \
    && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d['sultan_denemesi']==['G3'] and d['muhurdar']=='MUHURDAR1'" "$O/muhur-ozet.json" 2>/dev/null && o="$o d"
  [ -f "$T/istem-claude-1.md" ] && ! grep -qE "RAPOR-SIZINTI|COMMIT-SIZINTI|bana güven" "$T"/istem-claude-*.md && grep -q "merhaba dunya" "$T/istem-claude-1.md" \
    && grep -q 'kural: dosyada "merhaba"' "$T/istem-claude-1.md" && o="$o e"
  [ "$(cat "$T/claude-n" 2>/dev/null)" = 2 ] && grep -q "ikinci parca" "$T/istem-claude-2.md" && ! grep -q "ikinci parca" "$T/istem-claude-1.md" \
    && [ "$(_alan yargic "$O")" = "G2=claude,G4=claude" ] && o="$o f"
  [ ! -e "$T/isaret-sultan" ] && o="$o k"
  bash "$s/muhur-lint.sh" "$O" >/dev/null 2>&1 && o="$o o"
  _kos "$s" "$O" "$T/bin-codex:$T/bin-claude:" AGENT_NAME=MUHURDAR1 -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE
  [ $? -eq 0 ] && [ "$(_alan yargic "$O")" = "G2=codex,G4=codex" ] && [ ! -e "$T/claude-n" ] && ! grep -q "RAPOR-SIZINTI" "$T/istem-codex.md" && o="$o g"
  _kos "$s" "$O" "$T/bin-codex-duser:$T/bin-claude:" AGENT_NAME=MUHURDAR1 -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE
  [ $? -eq 0 ] && [ "$(_alan yargic "$O")" = "G2=codex→claude,G4=codex→claude" ] && o="$o h"
  rm -f "$T/sayac"; _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude -- --gereklilik "$K/G-kararsiz.md" --yazan HENDESE
  [ $? -eq 0 ] && [ "$(cat "$T/sayac")" = 1 ] && [ "$(_alan verdikt "$O")" = GECTI ] && o="$o q"
  _kos "$s" "$O" "$T/bin-codex-yavas:$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_ZAMAN_ASIMI=1 -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE
  [ $? -eq 0 ] && [ "$(_alan yargic "$O")" = "G2=codex(zaman-aşımı)→claude,G4=codex(zaman-aşımı)→claude" ] && o="$o r"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude YARGIC_CEVAP='"bozuk"' -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE
  [ $? -eq 3 ] && [ "$(_alan verdikt "$O")" = ESKALASYON ] && o="$o i"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude YARGIC_CEVAP='{"karar":"KALDI","not":"selam yok"}' -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE
  [ $? -eq 1 ] && [ "$(_alan verdikt "$O")" = KALDI ] && o="$o j"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude -- --gereklilik "$K/G-tarifsiz.md" --yazan HENDESE
  [ $? -eq 4 ] && grep -q "sultan-denemesi için tarif zorunlu" "$O/MUHUR.md" && o="$o l"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude -- --gereklilik "$K/G-kacis.md" --yazan HENDESE
  [ $? -eq 3 ] && grep -q "worktree dışında" "$O/MUHUR.md" && ! grep -qs "$(cat /etc/hostname 2>/dev/null || echo YOK-HOSTNAME)" "$T"/istem-claude-*.md && o="$o m"
  _kos "$s" "$O" "$T/bin-claude:" AGENT_NAME=MUHURDAR1 -- --gereklilik "$K/GEREKLILIK.md" --yazan HENDESE --rapor "$W/RAPOR.md"
  [ $? -eq 2 ] && grep -q "kör protokol" "$T/son.log" && o="$o n"
  echo "$o"
}
_k() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }

echo "════ G8 · Mühürdarlık · Tescil usulü (muhurdar.sh) ════"
S0="$(_sen "$HERE")"
_k p "$S0"; g $? "p usul sırası: biçimsiz belge + kendi işi → önce biçim kapısı (gereklilik-eksik), kendi-isi değil"
_k q "$S0"; g $? "q yargıç ve mühür AYNI ölçüme dayanır: mekanik G bir kez koşulur (kararsız G'de de GECTI, sayaç 1)"
_k r "$S0"; g $? "r Codex zaman aşımına uğrarsa da Claude'a yeni oturumla geçilir ('codex(zaman-aşımı)→claude')"
_k t "$S0"; g $? "t Türkçe harf: mühürdar MUHAKKİK, yazan MUHAKKIK → aynı kişi, kendi-isi reddi (taşıyıcı MUHAKKİK — Sultan D1 22 Eki)"
_k a "$S0"; g $? "a kendi işini mühürleyemez: yazan = mühürdar (büyük-küçük harf farkıyla) → İSİMLİ-RED kendi-isi, rc 4, hiçbir G koşulmadı, yargıç çağrılmadı"
_k b "$S0"; g $? "b mühürdarın kimliği yoksa (AGENT_NAME boş) mühür basılmaz, rc 2"
_k c "$S0"; g $? "c --yazan verilmezse koşulmaz (kendi işi ölçülemiyor), rc 2"
_k d "$S0"; g $? "d mutlu yol: GECTI · MUHUR başlığında mühürdar + yazan · 👤 G3 SULTANDA · özet sultan_denemesi=[G3]"
_k e "$S0"; g $? "e kör: istemde inşacının RAPOR'u ve commit mesajı YOK; rubrik + hedef dosya VAR"
_k f "$S0"; g $? "f temiz koşu: her öznel G kendi yargıç oturumunda (2 çağrı, istemler ayrı), yargıç MUHUR'a yazıldı"
_k k "$S0"; g $? "k 👤 Sultan denemesi satırı mühürdarca KOŞULMAZ (komut verilse de)"
_k o "$S0"; g $? "o çıkan MUHUR muhur-lint'ten geçer (Sultan satırı kanıt istemez)"
_k g "$S0"; g $? "g Codex erişilebilirse yargıç Codex (Claude çağrılmaz; Codex istemi de kör)"
_k h "$S0"; g $? "h Codex düşerse Claude'a yeni oturumla geçilir, MUHUR 'codex→claude' der"
_k i "$S0"; g $? "i yargıcın bozuk cevabı GEÇTİ sayılmaz → EMIN-DEGILIM → ESKALASYON, rc 3"
_k j "$S0"; g $? "j yargıç KALDI derse verdikt KALDI, rc 1"
_k l "$S0"; g $? "l tarifsiz 👤 Sultan denemesi biçim kapısında reddedilir (gereklilik-eksik)"
_k m "$S0"; g $? "m hedef iş ağacı dışına kaçarsa istem kurulmaz → EMIN-DEGILIM, dış dosya istemde yok"
_k n "$S0"; g $? "n yargıca rapor verme yolu yok: bilinmeyen argüman (--rapor) rc 2"

echo "── G8 · MUTASYON (tescil kopyasında, kontrol şartlı) ──"
_kopya() { local d="$T/m-$1"; mkdir -p "$d"; cp -r "$HERE/.." "$d/tescil"; echo "$d/tescil/scripts"; }
k0="$(_kopya kontrol)"; [ "$(_sen "$k0")" = "$S0" ] && [ -n "$S0" ]; g $? "kontrol kopyası gerçek betiklerle aynı kapıları geçiyor"
_m() {  # _m <anahtar> <dosya> <eski> <yeni> <açıklama>
  local d; d="$(_kopya "$1-$RANDOM")"
  python3 - "$d/$2" "$3" "$4" <<'PY' || { g 1 "mutant ($5): desen tutmadı"; return; }
import sys; p,a,b=sys.argv[1:]; s=open(p,encoding='utf-8').read(); o=s; s=s.replace(a,b,1); assert s!=o; open(p,'w',encoding='utf-8').write(s)
PY
  ! _k "$1" "$(_sen "$d")"; g $? "mutant ($5) → '$1' kapısı düşüyor"
}
_m a muhurdar.sh 'if [ "$ayni" = 1 ]; then' 'if false; then' "kendi-işi kapısı yok"
_m q muhurdar.sh 'bash "$HERE/muhur-lint.sh" "$OUT" >/dev/null 2>&1 ||' '"${TR[@]}" ${K2[@]+"${K2[@]}"} >/dev/null 2>&1; bash "$HERE/muhur-lint.sh" "$OUT" >/dev/null 2>&1 ||' "mühürden önce mekanik G yeniden koşuluyor"
_m r muhurdar.sh '  if [ "$yrc" -ne 0 ]; then' '  if [ "$yrc" -ne 0 ] && [ "$yrc" -ne 124 ]; then' "zaman aşımında Claude'a geçilmiyor"
_m t muhurdar.sh 'k=lambda s: s.strip().replace("İ","I").replace("ı","i").casefold()' 'k=lambda s: s.strip().casefold()' "Türkçe harf katlanmıyor (MUHAKKİK ≠ MUHAKKIK)"
_m p muhurdar.sh 'if [ ! -f "$GEREKLILIK" ] || [ -n "$(python3' 'if false && [ -n "$(python3' "biçim kapısı kendi-işinden sonra"
_m k tescil-run.sh 'if g["tur"] not in ("llm-yargi", "sultan-denemesi"):' 'if g["tur"] != "llm-yargi":' "Sultan denemesi koşuluyor"
_m d lib/muhur.py 'mekanik = [g for g in ger["g"] if g["tur"] not in ("llm-yargi", "sultan-denemesi")]' 'mekanik = [g for g in ger["g"] if g["tur"] != "llm-yargi"]' "Sultan denemesi verdikte"
_m i muhurdar.sh '[ -n "$karar" ] || karar="EMIN-DEGILIM:' '[ -n "$karar" ] || karar="GECTI:' "bozuk cevap GEÇTİ sayılıyor"
_m h muhurdar.sh '  if [ "$yrc" -ne 0 ]; then' '  if [ -z "$model" ]; then' "Codex düşünce Claude'a geçilmiyor"
_m e lib/kor-istem.py '    return 0


if __name__' '    print(open(os.path.join(worktree, "RAPOR.md"), encoding="utf-8").read())
    return 0


if __name__' "inşacının raporu isteme giriyor"
_m m lib/kor-istem.py 'return gercek if (gercek == kok or gercek.startswith(kok + os.sep)) else None' 'return gercek' "hedef ağaç dışına kaçabiliyor"
_m l lib/gereklilik.py '            if not g["tarif"]:' '            if False:' "Sultan denemesi tarifsiz geçiyor"

echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
