#!/usr/bin/env bash
# retro.test.sh — retro.py kapıları (hermetik: mktemp depo, sahte kaynaklar, sabit tarih) + 3 mutant.
# kabuk-testleri: sure=120
set -uo pipefail
B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$B/retro.py"
G=0; K=0
ok(){ G=$((G+1)); echo "  ✓ $1"; }
kirmizi(){ K=$((K+1)); echo "  ✗ $1"; }
kapi(){ # kapi <ad> <beklenen rc> <komut...>
  local ad="$1" bek="$2"; shift 2
  local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$bek" ]; then ok "$ad (rc=$rc)"; else kirmizi "$ad: rc=$rc beklenen $bek :: $(echo "$out" | head -3 | tr '\n' ' ')"; fi
  CIKTI="$out"
}
icerir(){ if grep -qF -- "$2" <<<"$1"; then ok "$3"; else kirmizi "$3 :: '$2' yok :: $(echo "$1" | head -4 | tr '\n' ' ')"; fi; }
icermez(){ if grep -qF -- "$2" <<<"$1"; then kirmizi "$3 :: '$2' VAR"; else ok "$3"; fi; }

export RETRO_BUGUN=2026-10-17   # 2026-W42 = 12..18 Eki
T="$(mktemp -d)"; trap 'rm -r -f -- "$T"' EXIT
KOK="$T/depo"; mkdir -p "$KOK/_agents/bani" "$KOK/_agents/mirahur" "$KOK/_agents/handoff" "$KOK/_agents/fabrika/kartlar" "$KOK/_agents/fabrika/kanit/is-a" "$KOK/_agents/fabrika/kanit/is-b"
export RETRO_KOK="$KOK" RETRO_BEKCI_LOG="$T/bekci.log" RETRO_REGISTRY="$KOK/_agents/handoff/aile-registry.yaml"

# NOTES: 2 tarihsiz satır · ÇIPA başlığından tarih devralan 3 satır (hafta içi, 1'i ders) · 1 satır başka hafta
cat > "$KOK/_agents/bani/NOTES.md" <<'EOF'
# BÂNİ — iş notları
[SERDAR → BÂNİ] 09:00 · tarihsiz satır 1
[BÂNİ → SERDAR] 09:10 · tarihsiz satır 2
## ÇIPA 2026-10-15 10:00
[BÂNİ → SERDAR] 10:05 · iş bitti
[SERDAR → BÂNİ] 10:20 · ders: kaçış defteri
[BÂNİ → SERDAR] 10:30 · devam
[BÂNİ → SERDAR] 2026-10-05 11:00 · geçen haftadan satır
EOF
printf '# M\n## ÇIPA 2026-10-14\n[MİRAHUR → SERDAR] 10:00 · cron\n' > "$KOK/_agents/mirahur/NOTES.md"
# kartlar: aldi=BANI (ASCII) ↔ ajan BÂNİ; is-a bitti hafta içi (2 DENETIM) · is-b tıkandı (1 DENETIM) · is-c geçen hafta
k(){ printf '{"is":"%s","aldi":"%s","zaman":"%s","durum":"%s","bitis":"%s"}' "$1" "$2" "$3" "$4" "$5" > "$KOK/_agents/fabrika/kartlar/$1.json"; }
k is-a BANI 2026-10-13T10:00:00+03:00 bitti 2026-10-14T10:00:00+03:00
k is-b BANI 2026-10-15T10:00:00+03:00 tikandi 2026-10-16T10:00:00+03:00
k is-c BANI 2026-10-01T10:00:00+03:00 bitti 2026-10-02T10:00:00+03:00
k is-d MIRAHUR 2026-10-14T10:00:00+03:00 acik ""
echo '{}' > "$KOK/_agents/fabrika/kanit/is-a/DENETIM-1.json"; echo '{}' > "$KOK/_agents/fabrika/kanit/is-a/DENETIM-2.json"; echo '{}' > "$KOK/_agents/fabrika/kanit/is-b/DENETIM-1.json"
printf '2026-10-15T14:34:31Z | KAPISIZ | a\n2026-10-01T14:34:31Z | KAPISIZ | eski\n' > "$KOK/_agents/fabrika/kacis-defteri.log"
printf '2026-10-17T14:49:02+03:00 bosta-bekcisi BERİD 16 dk boş\n2026-10-17T14:49:02+03:00 bosta-bekcisi BÂNİ 20 dk boş\n2026-10-17T14:49:02+03:00 bosta-bekcisi TUR uye=6\n' > "$T/bekci.log"
printf 'uyeler:\n  - id: SERDAR\n    tmux: "serdar:0"\n  - id: BÂNİ\n    tmux: "bani:0"\n  - id: MİRAHUR\n  - id: BASİRET\n' > "$RETRO_REGISTRY"

echo "— T1 hafta"
kapi "T1a hafta kimliği sabit tarihten" 0 python3 "$R" hafta; icerir "$CIKTI" "2026-W42" "T1b ISO hafta"
kapi "T1c biçimsiz hafta rc=2" 2 python3 "$R" kutu BÂNİ --hafta 2026-42

echo "— T2 kutu: iskelet + ölçüm"
kapi "T2a iskelet yazıldı" 0 python3 "$R" kutu BÂNİ --koltuk bani:0 --json
D="$KOK/_agents/handoff/retro/2026-W42/BÂNİ.md"; [ -f "$D" ] && ok "T2b dosya yerinde" || kirmizi "T2b dosya yok"
icerir "$(cat "$D")" "| NOTES mesaj satırı | 3 (tarihsiz 2 sayılmadı) |" "T2c hafta içi 3 satır, tarihsiz 2 ayrı, geçen hafta sayılmadı"
icerir "$(cat "$D")" "| ders / zaman kaybı / tıkanma satırı | 1 |" "T2d ders satırı 1"
icerir "$(cat "$D")" "| kart açılan / bitti / tıkandı | 2 / 1 / 1 |" "T2e kart sayımı aldı=BANI↔BÂNİ, geçen hafta dışarıda"
icerir "$(cat "$D")" "| bağımsız göz turu · ortalama tur/kart | 3 · 1.5 |" "T2f DENETIM turları"
icerir "$(cat "$D")" "| kaçış (KUTU GENELİ, ajan ayrımı yok) | 1 |" "T2g kaçış hafta içi 1, etiketi kutu geneli"
icerir "$(cat "$D")" "| boşta bekçisi zili | 1 |" "T2h bekçi zili yalnız bu ajan, TUR satırı değil"
icerir "$(cat "$D")" "| Sultan-eli adımı | ÖLÇÜLEMEDİ: tanımlı kaynak yok |" "T2i ölçülemeyen kaynak sarı, 0 değil"
icerir "$(cat "$D")" "_koltuk: bani:0" "T2j koltuk beyanı"
icerir "$CIKTI" "iz: VAR" "T2k iz özeti"
kapi "T2l ikinci kutu rc=4 (ezmez)" 4 python3 "$R" kutu BÂNİ

echo "— T3 lint"
kapi "T3a ham iskelet GEÇERSİZ (yer tutucu)" 1 python3 "$R" lint "$D"; icerir "$CIKTI" "L7 yer tutucu" "T3b L7 gerekçesi"
doldur(){ # doldur <dosya> — 5 başlığı geçerli maddelerle doldurur
python3 - "$1" <<'PY'
import re,sys;p=sys.argv[1];s=open(p,encoding="utf-8").read()
s=re.sub(r"- B1\) .*",  "- B1) canlı kanıt sınıfı Sx #354 kapıda",s)
s=re.sub(r"- Z1\) .*",  "- Z1) kanıt dizinini rm ile sildim · ölçü: 1 tur boşa",s)
s=re.sub(r"- A1\) .*",  "- A1) denetci.sh daralt kararını okumuyor · tur sayımı elle",s)
s=re.sub(r"- D1\) .*",  "- D1) kart depo başına açılır",s)
s=re.sub(r"- Ö1\) .*",  "- Ö1) kart.sh canli-ayarla sahip doğrulamalı\n- Ö2) denetci.sh --reis-daralt bayrağı → daralt yeni kart istemesin",s)
open(p,"w",encoding="utf-8").write(s)
PY
}
doldur "$D"
V(){ mkdir -p "$T/fx-$1/2026-W42"; sed "$2" "$D" > "$T/fx-$1/2026-W42/BÂNİ.md"; printf '%s' "$T/fx-$1/2026-W42/BÂNİ.md"; }
kapi "T3c dolu retro GEÇERLİ" 0 python3 "$R" lint "$D"; icerir "$CIKTI" "öneri 2 · ders 1" "T3d öneri/ders sayımı"
Z="$(V z 's/ · ölçü: 1 tur boşa//')"; kapi "T3e zaman kaybı ölçüsüz → L5" 1 python3 "$R" lint "$Z"; icerir "$CIKTI" "L5" "T3f L5 gerekçesi"
O="$(V o 's/^- Ö2) \(.*\)$/- Ö2) \1\n- Ö3) fazladan öneri madde 3\n- Ö4) fazladan öneri madde 4\n- Ö5) fazladan öneri madde 5\n- Ö6) fazladan öneri madde 6/')"; kapi "T3g 6 öneri → L6" 1 python3 "$R" lint "$O"; icerir "$CIKTI" "L6" "T3h L6"
Bv="$(V b '/^## 4 · /d;/^- D1)/d')"; kapi "T3i başlık yok → L4" 1 python3 "$R" lint "$Bv"; icerir "$CIKTI" "L4 başlık yok" "T3j L4"
Mv="$(V m '/^## Ölçüm/,/^## 1 · /{/^## 1 · /!d}')"; kapi "T3k ölçüm bloğu yok → L3 (elle retro geçersiz)" 1 python3 "$R" lint "$Mv"; icerir "$CIKTI" "L3 ölçüm bloğu yok" "T3l L3"
Kv="$(V k 's/^_koltuk: .*/_koltuk: /')"; kapi "T3m koltuk boş → L2" 1 python3 "$R" lint "$Kv"; icerir "$CIKTI" "L2" "T3m2 L2 gerekçesi"
Vv="$(V v 's/| 3 (tarihsiz 2 sayılmadı) |/| bilmem |/')"; kapi "T3n ölçüm değeri ne sayı ne ÖLÇÜLEMEDİ → L3" 1 python3 "$R" lint "$Vv"; icerir "$CIKTI" "L3 ölçüm değeri" "T3n2 L3 gerekçesi"
Ev="$(V e 's/^- D1) /- B1) /')"; kapi "T3o yanlış etiket → L4" 1 python3 "$R" lint "$Ev"; icerir "$CIKTI" "yanlış etiket" "T3p etiket gerekçesi"
kapi "T3q dosya yok rc=2" 2 python3 "$R" lint "$T/yok.md"

echo "— T4 kaynak yokluğu sarıdır"
BOS="$T/bos"; mkdir -p "$BOS/_agents/x"; printf '# X\n' > "$BOS/_agents/x/NOTES.md"
kapi "T4a kaynaksız depoda kutu yazılır" 0 python3 "$R" kutu X --kok "$BOS" --koltuk x:0
X="$BOS/_agents/handoff/retro/2026-W42/X.md"
icerir "$(cat "$X")" "| kart açılan / bitti / tıkandı | ÖLÇÜLEMEDİ: fabrika kartları yok |" "T4b kart kaynağı yok → ÖLÇÜLEMEDİ"
icerir "$(cat "$X")" "| kaçış (KUTU GENELİ, ajan ayrımı yok) | ÖLÇÜLEMEDİ: kaçış defteri yok |" "T4c kaçış defteri yok → ÖLÇÜLEMEDİ"
icermez "$(cat "$X")" "| kart açılan / bitti / tıkandı | 0 / 0 / 0 |" "T4d sıfır ile ölçülemedi aynı hücreye yazılmaz"
icerir "$CIKTI" "iz: YOK" "T4e iz yok"

echo "— T5 yenile: ölçüm değişir, yorum korunur"
k is-e BANI 2026-10-16T10:00:00+03:00 bitti 2026-10-17T10:00:00+03:00
kapi "T5a --yenile" 0 python3 "$R" kutu BÂNİ --yenile
icerir "$(cat "$D")" "| kart açılan / bitti / tıkandı | 3 / 2 / 1 |" "T5b yeni kart sayıldı"
icerir "$(cat "$D")" "- Ö2) denetci.sh --reis-daralt bayrağı" "T5c yorum satırı korundu"
icerir "$(cat "$D")" "_olcum_yenilendi: 20" "T5d yenileme damgası"
kapi "T5e yenilenmiş dosya hâlâ geçerli" 0 python3 "$R" lint "$D"

echo "— T6 merkez"
kapi "T6a merkez: EKSİK var → rc=1 (kırmızı: ölçtü, tutmuyor)" 1 python3 "$R" merkez
icerir "$CIKTI" "OK        BÂNİ" "T6b BÂNİ OK"
icerir "$CIKTI" "EKSİK     MİRAHUR" "T6c MİRAHUR iz var, retro yok → EKSİK"
icerir "$CIKTI" "ÇALIŞMADI BASİRET" "T6d BASİRET iz yok → ÇALIŞMADI (zorunlu değil)"
icermez "$CIKTI" "SERDAR" "T6e merkez (SERDAR) hariç"
M="$KOK/_agents/handoff/retro/2026-W42/MERKEZ.md"; [ -f "$M" ] && ok "T6f MERKEZ.md iskeleti" || kirmizi "T6f MERKEZ.md yok"
icerir "$(cat "$M")" "- M1) <ders> · kaynak:" "T6f2 ilk yazımda (elle bölüm yokken) Dersler/Görevler iskeleti basılır"
icerir "$(cat "$M")" "- BÂNİ Ö1) kart.sh canli-ayarla sahip doğrulamalı →" "T6g öneri süzüm listesinde, damga boş"
icerir "$(cat "$M")" "| MİRAHUR | EKSİK |" "T6h katılım tablosu"
cp "$Z" "$KOK/_agents/handoff/retro/2026-W42/MİRAHUR.md"   # BÂNİ başlıklı dosya MİRAHUR adıyla → GEÇERSİZ
kapi "T6i geçersiz kutu retrosu → GEÇERSİZ, rc=1" 1 python3 "$R" merkez --yenile; icerir "$CIKTI" "GEÇERSİZ  MİRAHUR" "T6j GEÇERSİZ etiketi"
rm -f "$KOK/_agents/handoff/retro/2026-W42/MİRAHUR.md"
kapi "T6k --ajanlar ile liste" 0 python3 "$R" merkez --ajanlar BÂNİ --yenile
[ "$(grep -c "yeni kart istemesin" "$M")" -eq 1 ] && ok "T6m boş damgalı satır --yenile'de çoğalmadı (metindeki ok damga sanılmadı)" || kirmizi "T6m Ö2 metni çoğaldı: $(grep -n 'Ö2)' "$M")"
kapi "T6l registry ve --ajanlar yok → rc=3 SARI (katılım ölçülemez)" 3 env RETRO_REGISTRY="$T/yok.yaml" python3 "$R" merkez --kok "$BOS"

echo "— T7 süzüm"
kapi "T7a damgasız → kırmızı" 1 python3 "$R" suzum; icerir "$CIKTI" "Ö1) damgasız" "T7b gerekçe"
python3 - "$M" <<'PY'
import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read()
s=s.replace("sahip doğrulamalı →","sahip doğrulamalı → gorev_01M54APFDAHKN72VKBWTGKSAAM").replace("yeni kart istemesin →","yeni kart istemesin → RED: kısa")
open(p,"w",encoding="utf-8").write(s)
PY
kapi "T7c RED gerekçesi kısa → kırmızı" 1 python3 "$R" suzum; icerir "$CIKTI" "Ö2) damgasız ya da biçimsiz: 'RED: kısa'" "T7d yalnız Ö2 sorunlu; metindeki ok damga sanılmadı (SON ok)"
sed -i 's/→ RED: kısa/→ RED: ayrı kart olarak açıldı, denetci.sh daralt kararı okur/' "$M"
kapi "T7e hepsi damgalı → yeşil" 0 python3 "$R" suzum; icerir "$CIKTI" "2 önerinin 2'i damgalı" "T7f sayım"
kapi "T7g merkez --yenile damgayı KORUR" 1 python3 "$R" merkez --yenile
icerir "$(cat "$M")" "→ gorev_01M54APFDAHKN72VKBWTGKSAAM" "T7h gorev damgası korundu"
kapi "T7i damga korunduğu için süzüm hâlâ yeşil" 0 python3 "$R" suzum
kapi "T7j MERKEZ yok → rc=3 SARI (ölçülemedi)" 3 python3 "$R" suzum --kok "$BOS"
echo "— T8 damga metne bağlı (göz #359 tur 1)"
sed -i 's/^- Ö1) kart.sh canli-ayarla sahip doğrulamalı$/- Ö1) kart.sh canli-ayarla sahip doğrulamalı ve zaman damgalı/' "$D"
kapi "T8a kutu önerisi değişti → eski gorev damgası BAYAT, kırmızı" 1 python3 "$R" suzum; icerir "$CIKTI" "Ö1) damga BAYAT" "T8b bayat gerekçesi"
icermez "$CIKTI" "Ö2)" "T8c değişmeyen Ö2 damgası geçerli"
kapi "T8d merkez --yenile bayat damgayı düşürür" 1 python3 "$R" merkez --yenile; icerir "$CIKTI" "damga DÜŞTÜ (öneri metni değişti" "T8e düşme uyarısı"
icerir "$(grep "Ö1)" "$M")" "ve zaman damgalı →" "T8f yeni metin damgasız yazıldı"
icermez "$(grep "Ö1)" "$M")" "gorev_01M54APFDAHKN72VKBWTGKSAAM" "T8g eski gorev damgası taşınmadı"
icerir "$(grep "Ö2)" "$M")" "→ RED: ayrı kart olarak açıldı" "T8h değişmeyen Ö2 damgası korundu"
kapi "T8i yeni metin damgasız → süzüm kırmızı" 1 python3 "$R" suzum; icerir "$CIKTI" "Ö1) damgasız" "T8j artık bayat değil, damgasız"

echo "— T9 merkez --yenile elle yazılan bölümleri KORUR (gorev_01M58987YSBASEXV1MF7T2GJHP · 19 Eki W42 MERKEZ.md silindi)"
python3 - "$M" <<'PY'
import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read()
s=s.replace("- M1) <ders> · kaynak: <AJAN D<n> | ölçüm>","- M1) vekil ölçütü önce adıyla ölç · kaynak: MİRAHUR D1\n\n  ikinci paragraf: girintili açıklama").replace("- <gorev_… · ders M<n>>","- gorev_01M58987YSBASEXV1MF7T2GJHP · ders M1")
s=s.rstrip("\n")+"\n\n## Kaçış ve tıkanma\n- 9 kaçış kutu geneli · en sık: denetçi tur 4\n\n## Serbest not\nmerkezin kendi notu\n"
open(p,"w",encoding="utf-8").write(s)
PY
cp "$M" "$T/merkez-elle.md"
kapi "T9a merkez --yenile (rc 1: EKSİK hâlâ var)" 1 python3 "$R" merkez --yenile
icerir "$(cat "$M")" "- M1) vekil ölçütü önce adıyla ölç · kaynak: MİRAHUR D1" "T9b Dersler satırı korundu"
icerir "$(cat "$M")" "  ikinci paragraf: girintili açıklama" "T9c bölüm içi boş satır + girinti korundu"
icerir "$(cat "$M")" "- gorev_01M58987YSBASEXV1MF7T2GJHP · ders M1" "T9d Görevler satırı korundu"
icerir "$(cat "$M")" "## Kaçış ve tıkanma" "T9e iskelette olmayan Kaçış bölümü korundu"
icerir "$(cat "$M")" "merkezin kendi notu" "T9f serbest bölüm korundu"
icermez "$(cat "$M")" "<ders> · kaynak:" "T9g iskelet yer tutucusu geri gelmedi"
[ "$(grep -c '^## Dersler' "$M")" -eq 1 ] && [ "$(grep -c '^## Kaçış' "$M")" -eq 1 ] && ok "T9h bölümler çoğalmadı (her biri bir kez)" || kirmizi "T9h bölüm sayısı: $(grep -n '^## ' "$M")"
[ "$(grep '^## ' "$M" | tr '\n' '|')" = "## Katılım (araç yazdı)|## Süzüm — her öneri bir damga alır: \`→ gorev_<id>\` (görev defterine girdi) ya da \`→ RED: <gerekçe ≥10 karakter>\`|## Dersler (merkez yorumu; kutu dersine D<n> ile atıf: \`BÂNİ D2\`)|## Görevler (Sultan ders ders onaylar · D1 damgası · görev defteri)|## Kaçış ve tıkanma|## Serbest not|" ] && ok "T9i bölüm sırası korundu (araç bölümleri önde, elle bölümler yazıldığı sırada)" || kirmizi "T9i sıra: $(grep '^## ' "$M" | tr '\n' '|')"
icerir "$(grep "Ö2)" "$M")" "→ RED: ayrı kart olarak açıldı" "T9j süzüm damgası da korunmaya devam ediyor"
python3 "$R" merkez --yenile >/dev/null 2>&1; cmp -s <(sed '/^_yazildi:/d' "$M") <(python3 "$R" merkez --yenile >/dev/null 2>&1; sed '/^_yazildi:/d' "$M") && ok "T9k ikinci --yenile aynı dosyayı üretir (kararlı)" || kirmizi "T9k ardışık --yenile farklı"

echo "— M mutasyon (kopya üstünde; her mutant en az bir kapıyı kızartmalı)"
mut(){ # mut <ad> <sed> <komut...> : mutant kopyada komut BAŞARILI (rc=0) kalırsa sınav onu yakalamıyor demektir
  local ad="$1" sed_="$2"; shift 2; local MR="$T/mut-$RANDOM.py"; sed -e "$sed_" "$R" > "$MR"
  if cmp -s "$MR" "$R"; then kirmizi "$ad: sed hiçbir şeyi değiştirmedi"; return; fi
  if "$@" "$MR" >/dev/null 2>&1; then kirmizi "$ad: mutant YAŞIYOR (kapı ısırmadı)"; else ok "$ad: mutant ısırıldı"; fi
}
m_l5(){ python3 "$1" lint "$Z" >/dev/null 2>&1; [ $? -ne 0 ]; }       # L5 kalkınca ölçüsüz Z geçer → rc 0 → fonksiyon 1 döner
mut "M1 L5 (ölçüsüz zaman kaybı) kalkınca ölçüsüz dosya geçmemeli" 's/if not re.search(r"· ölçü: .\*\\d", metin_m):/if False:/' m_l5
m_sari(){ local Y="$BOS/_agents/handoff/retro/2026-W42/Y.md" rc; rm -f "$Y"; python3 "$1" kutu Y --kok "$BOS" --koltuk y:0 >/dev/null 2>&1; grep -qF "ÖLÇÜLEMEDİ: fabrika kartları yok" "$Y"; rc=$?; rm -f "$Y"; return $rc; }
mut "M2 kaynak yokluğu sıfıra çevrilince sarı kaybolmalı (kapı yakalar)" 's/"ÖLÇÜLEMEDİ: fabrika kartları yok"/"0 \/ 0 \/ 0"/' m_sari
m_iz(){ python3 "$1" merkez --yenile 2>&1 | grep -qF "ÇALIŞMADI BASİRET"; }
# M4 için: Ö1'e gorev damgası ver, sonra kutu metnini değiştir; gerçek araç BAYAT der (rc 1), metin kıyası kalkmış mutant yeşil (rc 0) döner
python3 - "$M" <<'PY'
import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read()
s=s.replace("ve zaman damgalı →","ve zaman damgalı → gorev_01M54APFDAHKN72VKBWTGKSAAM"); open(p,"w",encoding="utf-8").write(s)
PY
kapi "M4-önkoşul: damgalı → yeşil" 0 python3 "$R" suzum
sed -i 's/^- Ö1) kart.sh canli-ayarla sahip doğrulamalı ve zaman damgalı$/- Ö1) kart.sh canli-ayarla sahip doğrulamalı, zaman damgalı ve kayıtlı/' "$D"
kapi "M4-önkoşul: metin değişti → gerçek araç BAYAT (kırmızı)" 1 python3 "$R" suzum
m_bayat(){ python3 "$1" suzum >/dev/null 2>&1; [ $? -ne 0 ]; }
mut "M4 metin kıyası kalkınca bayat damga geçer (kapı yakalar)" 's/            if e and e\[0\] != t.strip():/            if False:/' m_bayat
mut "M3 iz ayrımı kalkınca BASİRET EKSİK sayılır (kapı yakalar)" 's/    return bool((n and n\["satir"\] > 0)/    return True or bool((n and n["satir"] > 0)/' m_iz
m_elle(){ local rc; cp "$T/merkez-elle.md" "$M"; python3 "$1" merkez --yenile >/dev/null 2>&1; grep -qF "## Kaçış ve tıkanma" "$M" && grep -qF "vekil ölçütü önce adıyla ölç" "$M"; rc=$?; cp "$T/merkez-elle.md" "$M"; return $rc; }
mut "M5 elle bölümler taşınmazsa --yenile Dersler/Kaçış'ı siler (eski hata · kapı yakalar)" 's/            elle = merkez_elle_bolumler(eski)/            elle = []/' m_elle

echo; echo "GECEN=$G DUSEN=$K"
[ "$K" -eq 0 ]
