#!/usr/bin/env bash
# retro.test.sh — retro.py kapıları (hermetik: mktemp depo, sahte kaynaklar, sahte havuz köprüsü, sabit tarih) + mutantlar.
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
export RETRO_DEPO_KOKU="$T/projeler-yok"   # HERMETİK: varsayılan keşif kökü /config/projects'tir — sınav gerçek depoları saymaz (T11 kendi kökünü verir)

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
# Havuz köprüsü (11F0Z0): `bulgu.sh havuz-cek` BİÇİMİNDE sahte köprüler (eşlemenin kendisi bulgu.test.sh'ta ölçülür).
#   bulgu-bos.sh  → varsayılan: 0 ham (1 acik + 1 bozuk satır) — T6-T9 akışı havuzsuz kalır
#   bulgu.sh      → 2 ham + 1 acik + 1 bozuk satır (T12/T13 ve mutantlar `env RETRO_BULGU_SH=` ile seçer)
#   olmez.sh      → köprü rc 3 (jeton yok) · yok.sh → dosya yok
mkdir -p "$T/kopru"; HS="$T/kopru/defter.jsonl"
cat > "$HS" <<'EOF'
{"id":"gorev_01M5M55BRC0V3G8A200PYTVZV9","tarih":"2026-10-23","baslik":"mihenk: PR'da testleri koşan küçük bir iş akışı gerek","detay":"","durum":"ham","kaynak":"defter","kutu":"code","etiket":"ozellik","eski_no":""}
{"id":"gorev_01M5M7Y1F90HTSRADKETDCX24C","tarih":"2026-10-23","baslik":"Denetçi düzeltme turu eski DENETIM kaydında tam fark gönderiyor","durum":"ham","kaynak":"defter","kutu":"code","etiket":"bug","eski_no":""}
{"id":"gorev_01M5M0000000000000000ACIK0","tarih":"2026-10-22","baslik":"Sırada olan kayıt (havuzda değil)","durum":"acik","kaynak":"defter"}
bozuk satır json değil
EOF
cp "$HS" "$T/kopru/defter.orig.jsonl"; grep -v '"durum":"ham"' "$HS" > "$T/kopru/defter-bos.jsonl"
printf '#!/usr/bin/env bash\n[ "$1" = havuz-cek ] || exit 2\ncat "%s"\n' "$HS" > "$T/kopru/bulgu.sh"
printf '#!/usr/bin/env bash\n[ "$1" = havuz-cek ] || exit 2\ncat "%s"\n' "$T/kopru/defter-bos.jsonl" > "$T/kopru/bulgu-bos.sh"
printf '#!/usr/bin/env bash\necho "🟡 defter jetonu yok (/x/jeton) — defterdeki bulgular ÖLÇÜLEMEDİ" >&2; exit 3\n' > "$T/kopru/olmez.sh"
export RETRO_BULGU_SH="$T/kopru/bulgu-bos.sh"
HB=(env RETRO_BULGU_SH="$T/kopru/bulgu.sh")

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
icerir "$(cat "$M")" "_(görev defterinde havuz kaydı yok — köprü okundu: 0 havuz kaydı · 1 BOZUK satır atlandı)_" "T6h2 havuz bölümü boşken köprünün okunduğu ve bozuk satır SÖYLENİR (0 sessiz değil)"
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
s=s.rstrip("\n")+"\n\n## Kaçış ve tıkanma\n- 9 kaçış kutu geneli · en sık: denetçi tur 4\n\n\n## Süzüm notları\nönek araç başlığına benzer ama elle yazıldı\n\n## Serbest not\nmerkezin kendi notu\n"
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
[ "$(grep '^## ' "$M" | tr '\n' '|')" = "## Katılım (araç yazdı)|## Süzüm — her öneri bir damga alır: \`→ gorev_<id>\` (görev defterine girdi) ya da \`→ RED: <gerekçe ≥10 karakter>\`|## Havuz süzümü — görev defterindeki 'havuz' kayıtları (\`bulgu.sh havuz-cek\` · durum=ham) · damga: \`→ gorev_<kendi id>\` (Sırada'ya alınır) ya da \`→ RED: <gerekçe ≥10 karakter>\`|## Dersler (merkez yorumu; kutu dersine D<n> ile atıf: \`BÂNİ D2\`)|## Görevler (Sultan ders ders onaylar · D1 damgası · görev defteri)|## Kaçış ve tıkanma|## Süzüm notları|## Serbest not|" ] && ok "T9i bölüm sırası korundu (araç bölümleri önde, elle bölümler yazıldığı sırada)" || kirmizi "T9i sıra: $(grep '^## ' "$M" | tr '\n' '|')"
icerir "$(grep "Ö2)" "$M")" "→ RED: ayrı kart olarak açıldı" "T9j süzüm damgası da korunmaya devam ediyor"
cmp -s <(sed -n '/^## Dersler/,$p' "$T/merkez-elle.md") <(sed -n '/^## Dersler/,$p' "$M") && ok "T9l elle bölümler BAYT BAYT aynı (çift boş satır, girinti, dosya sonu dahil)" || kirmizi "T9l elle bölüm baytları değişti: $(diff <(sed -n '/^## Dersler/,$p' "$T/merkez-elle.md") <(sed -n '/^## Dersler/,$p' "$M") | head -5)"
icerir "$(cat "$M")" "önek araç başlığına benzer ama elle yazıldı" "T9m '## Süzüm notları' (araç önekiyle başlayan elle bölüm) silinmedi — araç bölümü birebir başlıkla tanınır"
python3 "$R" merkez --yenile >/dev/null 2>&1; cmp -s <(sed '/^_yazildi:/d' "$M") <(python3 "$R" merkez --yenile >/dev/null 2>&1; sed '/^_yazildi:/d' "$M") && ok "T9k ikinci --yenile aynı dosyayı üretir (kararlı)" || kirmizi "T9k ardışık --yenile farklı"

echo "— T10 doldur: ajanın metnini iskelete ARAÇ yazar (KHX56 · ana dal kapısı Edit/Write'ı reddeder; kapı gevşetilmez)"
XD="$BOS/_agents/handoff/retro/2026-W42/X.md"; cp "$XD" "$T/x-iskelet.md"
olcum_imza(){ sed -n '1,/^## 1 · /p' "$1" | sed '$d'; }   # başlık + imza + ölçüm bloğu (aracın bölgesi)
cat > "$T/x-iyi.md" <<'EOF'
## 1 · Ne bitti
- B1) tmux bekçisi Sx #388 kapıda
## 2 · Nerede zaman kaybettim (ölçüyle)
- Z1) sembolik bağ döngüsüne takılan tarama · ölçü: 5 dk
## 3 · Hangi araç/kural beni yavaşlattı
- A1) ana dal kapısı retro iskeletini düzenletmiyordu
## 4 · Ne öğrendim
- D1) kapıyı gevşetme, yazmayı araca ver

## 5 · Merkeze önerim
- Ö1) retro dolumu yalnız retro.py doldur ile yapılsın
EOF
kapi "T10a iskelet yoksa rc=2 (ölçümü araç yazar, önce kutu)" 2 python3 "$R" doldur Q --kok "$BOS" --metin "$T/x-iyi.md"; icerir "$CIKTI" "önce \`retro.py kutu Q\`" "T10a2 ne yapılacağını söyler"
kapi "T10b --metin verilmezse rc=2" 2 python3 "$R" doldur X --kok "$BOS"
kapi "T10c metin dosyası yoksa rc=2" 2 python3 "$R" doldur X --kok "$BOS" --metin "$T/yok-metin.md"
sed 's/^- D1) .*/- D1) <ders tek cümle>/' "$T/x-iyi.md" > "$T/x-yer.md"
kapi "T10d yer tutucu kalmış metin → rc=1, YAZILMAZ" 1 python3 "$R" doldur X --kok "$BOS" --metin "$T/x-yer.md"; icerir "$CIKTI" "L7 yer tutucu" "T10d2 lint gerekçesi"
cmp -s "$XD" "$T/x-iskelet.md" && ok "T10d3 dosya bayt bayt eski hâli" || kirmizi "T10d3 geçersiz metin dosyayı değiştirdi"
sed 's/ · ölçü: 5 dk//' "$T/x-iyi.md" > "$T/x-olcusuz.md"
kapi "T10e ölçüsüz zaman kaybı → rc=1 (L5), YAZILMAZ" 1 python3 "$R" doldur X --kok "$BOS" --metin "$T/x-olcusuz.md"; icerir "$CIKTI" "L5" "T10e2 L5 gerekçesi"
{ cat "$T/x-iyi.md"; printf '\n## Ölçüm (araç yazdı · sahte)\n| NOTES mesaj satırı | 99 |\n'; } > "$T/x-sahte.md"   # başlıkların ARDINA gizlenmiş (önsöz denetimi görmez)
kapi "T10f metinde (başlıkların ardında) ölçüm bloğu → rc=2 (ajan ölçümü sahteleyemez)" 2 python3 "$R" doldur X --kok "$BOS" --metin "$T/x-sahte.md"; icerir "$CIKTI" "ölçüm bloğu ya da imza" "T10f2 gerekçe"
{ cat "$T/x-iyi.md"; printf '_koltuk: sahte:0\n'; } > "$T/x-imza.md"
kapi "T10g metinde imza satırı → rc=2" 2 python3 "$R" doldur X --kok "$BOS" --metin "$T/x-imza.md"
{ printf 'önsöz cümlesi\n'; cat "$T/x-iyi.md"; } > "$T/x-onsoz.md"
kapi "T10h '## 1 · ' öncesi metin → rc=2 (sessizce yutulmaz)" 2 python3 "$R" doldur X --kok "$BOS" --metin "$T/x-onsoz.md"
cmp -s "$XD" "$T/x-iskelet.md" && ok "T10h2 reddedilen hiçbir metin dosyaya dokunmadı" || kirmizi "T10h2 dosya değişti"
kapi "T10i geçerli metin dosyadan → rc=0" 0 python3 "$R" doldur X --kok "$BOS" --metin "$T/x-iyi.md"; icerir "$CIKTI" "öneri 1 · ders 1" "T10i2 sayım"
kapi "T10j sonuç lint'ten geçer" 0 python3 "$R" lint "$XD"
cmp -s <(olcum_imza "$XD") <(olcum_imza "$T/x-iskelet.md") && ok "T10k ölçüm bloğu ve imza satırları BAYT BAYT korundu" || kirmizi "T10k aracın bölgesi değişti: $(diff <(olcum_imza "$T/x-iskelet.md") <(olcum_imza "$XD") | head -4 | tr '\n' ' ')"
icerir "$(cat "$XD")" "- D1) kapıyı gevşetme, yazmayı araca ver" "T10l ajanın maddesi yerinde"
[ "$(grep -c '^<!-- Yorum satırları ajanındır' "$XD")" -eq 1 ] && ok "T10m dipnot bir kez" || kirmizi "T10m dipnot sayısı $(grep -c '^<!-- Yorum' "$XD")"
cp "$XD" "$T/x-dolu.md"
kapi "T10n stdin'den (--metin -) aynı metin → rc=0" 0 bash -c "python3 '$R' doldur X --kok '$BOS' --metin - < '$T/x-iyi.md'"
cmp -s "$XD" "$T/x-dolu.md" && ok "T10o ikinci dolum aynı baytları üretir (kararlı)" || kirmizi "T10o ikinci dolum farklı"
{ cat "$T/x-iyi.md"; printf '\n<!-- Yorum satırları ajanındır; merkez bunları DEĞİŞTİRMEZ. Z maddesi ölçüsüz geçmez. Ö maddesi en çok 5. -->\n'; } > "$T/x-dipnotlu.md"
python3 "$R" doldur X --kok "$BOS" --metin "$T/x-dipnotlu.md" >/dev/null 2>&1
cmp -s "$XD" "$T/x-dolu.md" && ok "T10p metindeki dipnot çoğalmaz" || kirmizi "T10p dipnotlu metin farklı sonuç verdi"
# Yarış olasılıklıdır: sabit adlı eski sürüm 40 dolumda 2 kez düştü (ölçüldü, kanıt dizini) → 5 tur × 8 eşzamanlı dolum.
es_rc=0; for tur in 1 2 3 4 5; do pids=""; for n in 1 2 3 4 5 6 7 8; do python3 "$R" doldur X --kok "$BOS" --metin "$T/x-iyi.md" > "$T/es-$tur-$n.out" 2>&1 & pids="$pids $!"; done
  for p in $pids; do wait "$p" || es_rc=1; done; done
[ "$es_rc" = 0 ] && ok "T10s 5 tur × 8 eşzamanlı dolumun hepsi rc=0 (geçici dosyalar çarpışmaz · göz tur 1)" || kirmizi "T10s eşzamanlı dolum düştü: $(cat "$T"/es-*.out | grep -v '✓' | head -3 | tr '\n' ' ')"
cmp -s "$XD" "$T/x-dolu.md" && ok "T10t eşzamanlı dolum sonrası dosya geçerli ve beklenen baytlarda" || kirmizi "T10t eşzamanlı dolum sonrası dosya farklı"
[ -z "$(find "$(dirname "$XD")" -name '*.yeni' 2>/dev/null)" ] && ok "T10u geride geçici dosya kalmadı" || kirmizi "T10u kalan: $(find "$(dirname "$XD")" -name '*.yeni')"
kapi "T10q doldurulmuş dosyada kutu --yenile çalışır (ölçüm bloğu bulunur)" 0 python3 "$R" kutu X --kok "$BOS" --yenile
icerir "$(cat "$XD")" "- D1) kapıyı gevşetme, yazmayı araca ver" "T10r yenilemeden sonra ajanın yorumu korundu"
cp "$T/x-iskelet.md" "$XD"

echo "— T11 çok depo: kart + göz ölçüsü kutunun bütün depolarından (CQ46Y + NFS16 · W42'de Sx işi retrodan görünmüyordu)"
# KOK'ta 1 kart (DENETIM diskte) · projeler/Sx git deposunda 1 kart: DENETIM'ler YALNIZ origin/main'de (birincil kopya başka dalda,
# Sx'in 20 Eki hali) · projeler/_wt/… çalışma kopyası SAYILMAZ · projeler/Bos kartsız depo · RETRO_DEPOLAR tekrarı tekilleşir
P="$T/projeler"; SX="$P/Sx"; mkdir -p "$P/Bos/_agents" "$KOK/_agents/fabrika/kanit/sira-n"
printf '{"is":"sira-n","aldi":"SIRA","zaman":"2026-10-13T10:00:00+03:00","durum":"bitti","bitis":"2026-10-14T10:00:00+03:00"}' > "$KOK/_agents/fabrika/kartlar/sira-n.json"
echo '{}' > "$KOK/_agents/fabrika/kanit/sira-n/DENETIM-1.json"
( export GIT_AUTHOR_NAME=s GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=s GIT_COMMITTER_EMAIL=s@s GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  git init -q --bare -b main "$T/sx-origin.git" && git clone -q "$T/sx-origin.git" "$SX" 2>/dev/null
  mkdir -p "$SX/_agents/fabrika/kanit/sira-s" && echo '{}' > "$SX/_agents/fabrika/kanit/sira-s/DENETIM-1.json" && echo '{}' > "$SX/_agents/fabrika/kanit/sira-s/DENETIM-2.json"
  git -C "$SX" add -A && git -C "$SX" commit -qm kanit && git -C "$SX" push -q origin main 2>/dev/null
  git -C "$SX" checkout -q -b baska-dal && git -C "$SX" rm -q -r _agents/fabrika/kanit && git -C "$SX" commit -qm sil ) || kirmizi "T11 önkoşul: Sx deposu kurulamadı"
mkdir -p "$SX/_agents/fabrika/kartlar" "$P/_wt/Sx-x/_agents/fabrika/kartlar"
printf '{"is":"sira-s","aldi":"SIRA","zaman":"2026-10-15T10:00:00+03:00","durum":"bitti","bitis":"2026-10-16T10:00:00+03:00"}' > "$SX/_agents/fabrika/kartlar/sira-s.json"
printf '{"is":"sira-wt","aldi":"SIRA","zaman":"2026-10-15T10:00:00+03:00","durum":"bitti","bitis":"2026-10-16T10:00:00+03:00"}' > "$P/_wt/Sx-x/_agents/fabrika/kartlar/sira-wt.json"
SD="$KOK/_agents/handoff/retro/2026-W42/SIRA.md"
kapi "T11a iki depolu kutu ölçüldü" 0 env RETRO_DEPO_KOKU="$P" python3 "$R" kutu SIRA --koltuk s:0
icerir "$(cat "$SD")" "| kart açılan / bitti / tıkandı | 2 / 2 / 0 |" "T11b kartlar İKİ depodan (KOK + Sx), _wt kopyası sayılmadı"
icerir "$(cat "$SD")" "| bağımsız göz turu · ortalama tur/kart | 3 · 1.5 |" "T11c Sx göz turları origin/main'den (birincil kopya başka dalda, diskte DENETIM yok)"
icerir "$(cat "$SD")" "Sx 1/1/0" "T11d kanıt sütunu depo başına döker"
icerir "$(grep "^| bağımsız göz turu" "$SD")" "depo başına: depo 1 · Sx 2" "T11d2 göz turu da depo başına dökülür (KOK 1 · Sx 2 · göz tur 2)"
rm -f "$SD"
kapi "T11e RETRO_DEPOLAR verilince keşif yerine o liste; aynı depo iki kez sayılmaz" 0 env RETRO_DEPO_KOKU="$P" RETRO_DEPOLAR="$KOK:$KOK" python3 "$R" kutu SIRA --koltuk s:0
icerir "$(cat "$SD")" "| kart açılan / bitti / tıkandı | 1 / 1 / 0 |" "T11f yalnız KOK, tekrar tekilleşti"
rm -f "$SD"
kapi "T11g keşif kökü yoksa yalnız KOK (eski davranış)" 0 env RETRO_DEPO_KOKU="$T/yok-boyle" python3 "$R" kutu SIRA --koltuk s:0
icerir "$(cat "$SD")" "| kart açılan / bitti / tıkandı | 1 / 1 / 0 |" "T11h keşifsiz tek depo"
rm -f "$SD"
# origin/main OKUNAMAZSA sayım sessizce eksik kalmaz (göz tur 1): Sx kopyasında uzak dal referansı silinir → depo ADIYLA uyarı
P2="$T/projeler2"; mkdir -p "$P2"; cp -r "$SX" "$P2/Sx"; git -C "$P2/Sx" update-ref -d refs/remotes/origin/main
kapi "T11i origin/main okunamayan depolu ölçüm yine yazılır" 0 env RETRO_DEPO_KOKU="$P2" python3 "$R" kutu SIRA --koltuk s:0
icerir "$(cat "$SD")" "| bağımsız göz turu · ortalama tur/kart | 1 · 0.5 |" "T11j okunamayınca yalnız disk sayılır (değer gerçek)"
icerir "$(cat "$SD")" "origin/main OKUNAMADI: Sx" "T11k … ve kanıt sütunu eksikliği depo adıyla söyler (sessiz eksik yok)"
icermez "$(cat "$SD")" "(disk ∪ origin/main)" "T11l … ve 'disk ∪ origin/main' diye yanlış etiketlemez"
rm -f "$SD"
kapi "T11m git deposu olmayan KOK uyarı üretmez (okunacak origin yok)" 0 env RETRO_DEPO_KOKU="$T/yok-boyle" python3 "$R" kutu SIRA --koltuk s:0
icermez "$(cat "$SD")" "OKUNAMADI" "T11n git'siz depo için OKUNAMADI yok"
rm -f "$SD"

echo "— T12 havuz süzümü: görev defterindeki 'havuz' kayıtları merkez süzüm listesine (11F0Z0 · bulgu.sh havuz-cek köprüsü)"
HK="$T/havuz-kok"; mkdir -p "$HK/_agents/x"; printf '# X\n' > "$HK/_agents/x/NOTES.md"
HM="$HK/_agents/handoff/retro/2026-W42/MERKEZ.md"
kapi "T12a merkez havuz bölümünü yazar (rc 0: X çalışmadı)" 0 "${HB[@]}" python3 "$R" merkez --kok "$HK" --ajanlar X
icerir "$CIKTI" "havuz 2 (damga bekliyor: 2; 2 havuz kaydı · 1 BOZUK satır atlandı)" "T12b özet: 2 ham, bozuk satır söylendi"
icerir "$(cat "$HM")" "## Havuz süzümü — görev defterindeki 'havuz' kayıtları" "T12c bölüm başlığı"
[ "$(grep -cE '^- gorev_[0-9A-Z]{26} · ' "$HM")" -eq 2 ] && ok "T12d 2 havuz satırı (acik kayıt dışarıda, bozuk satır atlandı)" || kirmizi "T12d havuz satırı: $(grep -c '^- gorev_' "$HM")"
icerir "$(cat "$HM")" "- gorev_01M5M55BRC0V3G8A200PYTVZV9 · mihenk: PR'da testleri koşan küçük bir iş akışı gerek →" "T12e satır biçimi '- <gorev_id> · <başlık> → ' (damga boş)"
icermez "$(cat "$HM")" "Sırada olan kayıt" "T12f durum=acik kayıt havuz listesine girmedi"
cp "$HM" "$T/havuz-merkez-damgasiz.md"
kapi "T12g damgasız havuz satırı → suzum KIRMIZI" 1 python3 "$R" suzum --kok "$HK"; icerir "$CIKTI" "havuz gorev_01M5M55BRC0V3G8A200PYTVZV9 damgasız" "T12h gerekçe havuz kimliğiyle"
icerir "$CIKTI" "0 öneri + 2 havuz kaydı, 2 sorun" "T12i sayım"
python3 - "$HM" <<'PY'
import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read()
s=s.replace("küçük bir iş akışı gerek →","küçük bir iş akışı gerek → gorev_01M5M55BRC0V3G8A200PYTVZV9").replace("tam fark gönderiyor →","tam fark gönderiyor → RED: kısa")
open(p,"w",encoding="utf-8").write(s)
PY
kapi "T12j RED gerekçesi kısa → kırmızı, yalnız o satır" 1 python3 "$R" suzum --kok "$HK"; icerir "$CIKTI" "havuz gorev_01M5M7Y1F90HTSRADKETDCX24C damgasız ya da biçimsiz: 'RED: kısa'" "T12k biçimsiz gerekçe"
icermez "$CIKTI" "PYTVZV9" "T12l kendi-id damgası (= Sırada'ya alındı) geçerli"
sed -i 's/→ RED: kısa/→ RED: ayrı kart olarak açıldı (denetçi düzeltme turu farkı)/' "$HM"
kapi "T12m iki havuz satırı damgalı → yeşil" 0 python3 "$R" suzum --kok "$HK"; icerir "$CIKTI" "2 havuz kaydının tümü damgalı" "T12n sayım"
# göz #442 tur 1: oku silinmiş havuz satırı sözlüğe girmiyor, süzüm onu görmüyordu → bölümdeki çözülemeyen satır KIRMIZI
cp "$HM" "$T/havuz-merkez-iyi.md"; sed -i 's/^- gorev_01M5M55BRC0V3G8A200PYTVZV9 · \(.*\) → gorev_01M5M55BRC0V3G8A200PYTVZV9$/- gorev_01M5M55BRC0V3G8A200PYTVZV9 · \1/' "$HM"
grep -q '^- gorev_01M5M55BRC0V3G8A200PYTVZV9 · .*→' "$HM" && kirmizi "T12m2 önkoşul: ok silinemedi" || ok "T12m2 önkoşul: havuz satırının oku silindi"
kapi "T12m3 oku silinmiş (çözülemeyen) havuz satırı → suzum KIRMIZI, sessiz atlanmaz" 1 python3 "$R" suzum --kok "$HK"; icerir "$CIKTI" "havuz satırı ÇÖZÜLEMEDİ (biçimsiz" "T12m4 gerekçe"
sed -i '/^## Havuz süzümü/a - gorev_KISA · kimliği bozuk satır → RED: kimlik bozuk olsa da' "$HM"   # bölümün İÇİNE (dosya sonu elle bölümdür)
kapi "T12m5 kimliği bozuk satır da kırmızı" 1 python3 "$R" suzum --kok "$HK"; icerir "$CIKTI" "ÇÖZÜLEMEDİ (biçimsiz, süzüm sayılamaz): '- gorev_KISA" "T12m6 bozuk kimlik gerekçesi"
cp "$T/havuz-merkez-iyi.md" "$HM"
kapi "T12m7 bozuk satır kaldırılınca yeniden yeşil (aracın '_(… yok …)_' notu ve boş satır bozuk sayılmaz)" 0 python3 "$R" suzum --kok "$HK"
printf '\n## Serbest havuz notu\nmerkezin havuz notu\n' >> "$HM"
kapi "T12o merkez --yenile" 0 "${HB[@]}" python3 "$R" merkez --kok "$HK" --ajanlar X --yenile
icerir "$(cat "$HM")" "→ gorev_01M5M55BRC0V3G8A200PYTVZV9" "T12p kendi-id damgası korundu"; icerir "$(cat "$HM")" "→ RED: ayrı kart olarak açıldı (denetçi" "T12q RED damgası korundu"
icerir "$(cat "$HM")" "merkezin havuz notu" "T12r elle bölüm korundu"
[ "$(grep -c '^## Havuz süzümü' "$HM")" -eq 1 ] && ok "T12s havuz bölümü bir kez (araç bölümü birebir başlıkla tanındı)" || kirmizi "T12s bölüm sayısı $(grep -c '^## Havuz' "$HM")"
icerir "$CIKTI" "havuz 2 (damga bekliyor: 0" "T12t yenilemede bekleyen 0"
kapi "T12u yenileme sonrası süzüm hâlâ yeşil" 0 python3 "$R" suzum --kok "$HK"
cp "$HM" "$T/havuz-merkez.md"
"${HB[@]}" python3 "$R" merkez --kok "$HK" --ajanlar X --yenile >/dev/null 2>&1; cmp -s <(sed '/^_yazildi:/d' "$T/havuz-merkez.md") <(sed '/^_yazildi:/d' "$HM") && ok "T12u2 ikinci --yenile aynı dosyayı üretir (havuz satırları kimliğe göre sıralı, kararlı)" || kirmizi "T12u2 ardışık --yenile farklı"
python3 - "$HS" <<'PY'
import sys,json;p=sys.argv[1];out=[]
for l in open(p,encoding="utf-8").read().splitlines():
    try: k=json.loads(l)
    except Exception: out.append(l); continue
    if k.get("id")=="gorev_01M5M55BRC0V3G8A200PYTVZV9": k["baslik"]+=" (CI)"
    if k.get("id")=="gorev_01M5M7Y1F90HTSRADKETDCX24C": k["durum"]="acik"
    out.append(json.dumps(k,ensure_ascii=False))
open(p,"w",encoding="utf-8").write("\n".join(out)+"\n")
PY
kapi "T12v --yenile: başlığı değişen kaydın damgası düşer, havuzdan çıkan (acik) satır düşer" 0 "${HB[@]}" python3 "$R" merkez --kok "$HK" --ajanlar X --yenile
icerir "$CIKTI" "havuz damgası DÜŞTÜ (kayıt başlığı değişti" "T12w düşme uyarısı"; icerir "$CIKTI" "havuzdan çıkan damgalı kayıt" "T12x çıkan kayıt notu (sessiz düşmez)"
icerir "$(grep PYTVZV9 "$HM")" "iş akışı gerek (CI) →" "T12y yeni başlık damgasız yazıldı"; icermez "$(grep PYTVZV9 "$HM")" "→ gorev_" "T12z eski damga taşınmadı"
icermez "$(cat "$HM")" "DCX24C" "T12z2 havuzdan çıkan kayıt listede değil"
kapi "T12z3 yeniden damgasız → süzüm kırmızı" 1 python3 "$R" suzum --kok "$HK"
cp "$T/kopru/defter.orig.jsonl" "$HS"; cp "$T/havuz-merkez.md" "$HM"

echo "— T13 havuz köprüsü ölçemezse MERKEZ.md yazılmaz: ÖLÇÜLEMEDİ rc 3, '0 havuz' DEĞİL"
kapi "T13a köprü rc 3 (jeton yok) → merkez rc 3" 3 env RETRO_BULGU_SH="$T/kopru/olmez.sh" python3 "$R" merkez --kok "$HK" --ajanlar X --yenile
icerir "$CIKTI" "ÖLÇÜLEMEDİ: havuz okunamadı — defter jetonu yok" "T13b sebep köprünün kendi cümlesinden"; icermez "$CIKTI" "havuz 0" "T13c 0 havuz denmedi"
cmp -s "$HM" "$T/havuz-merkez.md" && ok "T13d MERKEZ.md bayt bayt değişmedi (damgalar ve elle bölüm yerinde)" || kirmizi "T13d MERKEZ.md değişti"
kapi "T13e köprü dosyası yok → rc 3" 3 env RETRO_BULGU_SH="$T/kopru/yok.sh" python3 "$R" merkez --kok "$HK" --ajanlar X --yenile; icerir "$CIKTI" "köprü yok" "T13f sebep"
kapi "T13g ilk yazımda da köprü yoksa dosya üretilmez" 3 env RETRO_BULGU_SH="$T/kopru/yok.sh" python3 "$R" merkez --kok "$BOS" --ajanlar X
[ ! -f "$BOS/_agents/handoff/retro/2026-W42/MERKEZ.md" ] && ok "T13h MERKEZ.md yazılmadı" || kirmizi "T13h MERKEZ.md yazıldı"
sed -i '/^## Havuz süzümü/,/^## Serbest havuz notu/{/^## Serbest havuz notu/!d}' "$HM"
kapi "T13i bölümsüz (1.3.0 öncesi) MERKEZ.md → suzum uyarır, geriye dönük kırmızıya çevirmez" 0 python3 "$R" suzum --kok "$HK"; icerir "$CIKTI" "Havuz süzümü bölümü yok" "T13j uyarı"
kapi "T13k --yenile bölümü ekler" 0 "${HB[@]}" python3 "$R" merkez --kok "$HK" --ajanlar X --yenile
[ "$(grep -cE '^- gorev_[0-9A-Z]{26} · ' "$HM")" -eq 2 ] && ok "T13l 2 havuz satırı geri geldi" || kirmizi "T13l havuz satırı $(grep -c '^- gorev_' "$HM")"
icerir "$(cat "$HM")" "merkezin havuz notu" "T13m elle bölüm korundu"
cp "$T/havuz-merkez.md" "$HM"

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
m_elle(){ local rc; cp "$T/merkez-elle.md" "$M"; python3 "$1" merkez --yenile >/dev/null 2>&1; grep -qF "## Kaçış ve tıkanma" "$M" && grep -qF "vekil ölçütü önce adıyla ölç" "$M" && grep -qF "önek araç başlığına benzer" "$M" && cmp -s <(sed -n '/^## Dersler/,$p' "$T/merkez-elle.md") <(sed -n '/^## Dersler/,$p' "$M"); rc=$?; cp "$T/merkez-elle.md" "$M"; return $rc; }
mut "M5 elle bölümler taşınmazsa --yenile Dersler/Kaçış'ı siler (eski hata · kapı yakalar)" 's/            elle = merkez_elle_ham(eski)/            elle = ""/' m_elle
mut "M6 araç bölümü ÖNEKLE tanınırsa '## Süzüm notları' silinir (kapı yakalar)" 's/            icinde = s.rstrip("\\r\\n") not in MERKEZ_ARAC_BOLUMLERI/            icinde = not s.startswith(("## Katılım", "## Süzüm", "## Havuz"))/' m_elle
mut "M7 boş satırlar daraltılırsa bayt eşitliği bozulur (kapı yakalar)" 's/            ham.append(s)$/            ham.append(s) if (s.strip() or not ham or ham[-1].strip()) else None/' m_elle

m_dl(){ local rc; cp "$T/x-iskelet.md" "$XD"; python3 "$1" doldur X --kok "$BOS" --metin "$2" >/dev/null 2>&1; rc=$?; cmp -s "$XD" "$T/x-iskelet.md"; local ayni=$?; cp "$T/x-iskelet.md" "$XD"; [ "$rc" -ne 0 ] && [ "$ayni" -eq 0 ]; }
m_dl_yer(){ m_dl "$1" "$T/x-yer.md"; }; m_dl_sahte(){ m_dl "$1" "$T/x-sahte.md" && m_dl "$1" "$T/x-imza.md"; }; m_dl_onsoz(){ m_dl "$1" "$T/x-onsoz.md"; }
mut "M8 doldur lint'i atlarsa yer tutuculu metin yazılır (kapı yakalar)" 's/^    if h:$/    if False:/' m_dl_yer
mut "M9 ölçüm/imza reddi kalkınca sahte ölçüm dosyaya girer (kapı yakalar)" 's/^    if re.search(r"^## Ölçüm", metin, re.M) or /    if False and re.search(r"^## Ölçüm", metin, re.M) or /' m_dl_sahte
mut "M10 önsöz denetimi kalkınca metin sessizce yutulur (kapı yakalar)" 's/^    if metin\[:m.start()\].strip():$/    if False:/' m_dl_onsoz

m_cok(){ local rc; rm -f "$SD"; env RETRO_DEPO_KOKU="$P" python3 "$1" kutu SIRA --koltuk s:0 >/dev/null 2>&1
  grep -qF "| kart açılan / bitti / tıkandı | 2 / 2 / 0 |" "$SD" && grep -qF "| bağımsız göz turu · ortalama tur/kart | 3 · 1.5 |" "$SD"; rc=$?; rm -f "$SD"; return $rc; }
m_tek(){ local rc; rm -f "$SD"; env RETRO_DEPO_KOKU="$P" RETRO_DEPOLAR="$KOK:$KOK" python3 "$1" kutu SIRA --koltuk s:0 >/dev/null 2>&1
  grep -qF "| kart açılan / bitti / tıkandı | 1 / 1 / 0 |" "$SD"; rc=$?; rm -f "$SD"; return $rc; }
m_cok "$R" && m_tek "$R" && ok "M11-13 pozitif kontrol: bozmasız araçla iki yoklama da GEÇER (ısırık sahte değil)" || kirmizi "M11-13 pozitif kontrol: gerçek araç yoklamayı geçemiyor"
mut "M11 depo keşfi kalkınca Sx kartı sayılmaz (kapı yakalar)" 's/        aday += \[os.path.dirname(os.path.dirname(os.path.dirname(k)))/        aday += [] and [os.path.dirname(os.path.dirname(os.path.dirname(k)))/' m_cok
mut "M12 origin\/main okuması kalkınca birincil kopya başka daldayken göz turları eksik (kapı yakalar)" 's/^    if not om:$/    if True:/' m_cok
mut "M13 tekilleştirme kalkınca aynı depo iki kez sayılır (kapı yakalar)" 's/        if r not in gorulen and os.path.isdir/        if os.path.isdir/' m_tek
m_uyari(){ local rc; rm -f "$SD"; env RETRO_DEPO_KOKU="$P2" python3 "$1" kutu SIRA --koltuk s:0 >/dev/null 2>&1; grep -qF "origin/main OKUNAMADI: Sx" "$SD"; rc=$?; rm -f "$SD"; return $rc; }
m_uyari "$R" && ok "M14 pozitif kontrol: bozmasız araç okunamayan depoyu adıyla söyler" || kirmizi "M14 pozitif kontrol: gerçek araç uyarı basmıyor"
mut "M14 okunamama uyarısı susturulunca eksik sayım yeşil görünür (kapı yakalar)" 's/("`_agents\/fabrika\/kanit\/\*\/DENETIM-\*.json` (disk ∪ origin\/main)" if not k\["okunamadi"\] else/("`_agents\/fabrika\/kanit\/*\/DENETIM-*.json` (disk ∪ origin\/main)" if True else/' m_uyari
m_goz(){ local rc; rm -f "$SD"; env RETRO_DEPO_KOKU="$P" python3 "$1" kutu SIRA --koltuk s:0 >/dev/null 2>&1; grep "^| bağımsız göz turu" "$SD" | grep -qF "depo başına: depo 1 · Sx 2"; rc=$?; rm -f "$SD"; return $rc; }
m_goz "$R" && ok "M15 pozitif kontrol: bozmasız araç göz turunu depo başına döker" || kirmizi "M15 pozitif kontrol: gerçek araç dökmüyor"
mut "M15 depo başına göz sayacı artmazsa döküm yalan söyler (kapı yakalar)" 's/turlar.append(len(ad)); dg += len(ad); /turlar.append(len(ad)); /' m_goz

# Havuz mutantları her koşuda TAZE kök açar (mktemp -d, $T altında; dosya silinmez, trap toplar): durum sızmaz.
m_havuz(){ local K; K="$(mktemp -d -p "$T")"; "${HB[@]}" python3 "$1" merkez --kok "$K" --ajanlar X >/dev/null 2>&1; [ "$(grep -cE '^- gorev_[0-9A-Z]{26} · ' "$K/_agents/handoff/retro/2026-W42/MERKEZ.md" 2>/dev/null)" -eq 2 ]; }
m_havuz "$R" && ok "M16-17 pozitif kontrol: bozmasız araç 2 havuz satırı yazar" || kirmizi "M16-17 pozitif kontrol: gerçek araç 2 satır yazmıyor"
mut "M16 köprü çağrısı silinince havuz satırı yazılmaz (kapı yakalar)" 's/\["bash", bsh, "havuz-cek"\]/["true"]/' m_havuz
mut "M17 ham süzgeci kalkınca acik kayıt da listeye girer (kapı yakalar)" 's/        if k.get("durum") != "ham":/        if False:/' m_havuz
m_h_sari(){ local K rc; K="$(mktemp -d -p "$T")"; env RETRO_BULGU_SH="$T/kopru/yok.sh" python3 "$1" merkez --kok "$K" --ajanlar X >/dev/null 2>&1; rc=$?; [ "$rc" -eq 3 ] && [ ! -f "$K/_agents/handoff/retro/2026-W42/MERKEZ.md" ]; }
m_h_sari "$R" && ok "M18 pozitif kontrol: köprü yokken rc 3, dosya yok" || kirmizi "M18 pozitif kontrol: gerçek araç köprüsüz yazıyor"
mut "M18 köprü yokluğu boş listeye çevrilince '0 havuz' sessiz yeşil olur (kapı yakalar)" 's/        return None, f"köprü yok: {bsh}"/        return [], "köprü yok"/' m_h_sari
m_h_suzum(){ local rc; cp "$T/havuz-merkez-damgasiz.md" "$HM"; python3 "$1" suzum --kok "$HK" >/dev/null 2>&1; rc=$?; cp "$T/havuz-merkez.md" "$HM"; [ "$rc" -ne 0 ]; }
m_h_suzum "$R" && ok "M19 pozitif kontrol: damgasız havuz satırında gerçek suzum kırmızı" || kirmizi "M19 pozitif kontrol: gerçek suzum damgasız havuzu geçiriyor"
mut "M19 havuz damga denetimi kalkınca damgasız havuz satırı süzümden geçer (kapı yakalar)" 's/        if not damga_gecerli(d):/        if False:/' m_h_suzum
m_h_bozuk(){ local rc; cp "$T/havuz-merkez.md" "$HM"; sed -i 's/^- gorev_01M5M55BRC0V3G8A200PYTVZV9 · \(.*\) → gorev_01M5M55BRC0V3G8A200PYTVZV9$/- gorev_01M5M55BRC0V3G8A200PYTVZV9 · \1/' "$HM"; python3 "$1" suzum --kok "$HK" >/dev/null 2>&1; rc=$?; cp "$T/havuz-merkez.md" "$HM"; [ "$rc" -ne 0 ]; }
m_h_bozuk "$R" && ok "M20 pozitif kontrol: oku silinmiş havuz satırında gerçek suzum kırmızı" || kirmizi "M20 pozitif kontrol: gerçek suzum çözülemeyen satırı geçiriyor"
mut "M20 çözülemeyen satır sessizce atlanınca süzümden kaçar (göz #442 tur 1 · kapı yakalar)" 's/            bozuk.append(s.strip())/            pass/' m_h_bozuk

echo "— T20 ek-ad eşlemesi: kayıttaki kısa ad (KALFA) ↔ oturum adı (nova-kalfa); eşleşme tutmazsa 0 değil ÖLÇÜLEMEDİ (W43 retro A1 · nova)"
ek_satir(){ local K f; K="$(mktemp -d -p "$T")"; mkdir -p "$K/_agents/fabrika/kartlar"
  printf '{"is":"ek-a","aldi":"KALFA","zaman":"2026-10-13T10:00:00+03:00","durum":"bitti","bitis":"2026-10-14T10:00:00+03:00"}' > "$K/_agents/fabrika/kartlar/ek-a.json"
  python3 "$R" kutu "$1" --kok "$K" --koltuk e:0 >/dev/null 2>&1; f="$(ls "$K"/_agents/handoff/retro/2026-W42/*.md 2>/dev/null | head -1)"; [ -n "$f" ] && grep "^| kart açılan" "$f"; }
icerir "$(ek_satir nova-kalfa)" "| kart açılan / bitti / tıkandı | 1 / 1 / 0 |" "T20a oturum adı nova-kalfa → kayıttaki KALFA kartı sayılır"
icerir "$(ek_satir KALFA)" "| kart açılan / bitti / tıkandı | 1 / 1 / 0 |" "T20b kısa ad KALFA aynen çalışır (gerileme yok)"
icerir "$(ek_satir nova-bani)" "ÖLÇÜLEMEDİ: ad eşleşmedi" "T20c hiçbir ad tutmuyorsa 0 değil ÖLÇÜLEMEDİ: ad eşleşmedi"
icermez "$(ek_satir nova-bani)" "| 0 / 0 / 0 |" "T20d eşleşmeyen ad sessiz sıfır basmaz"
icermez "$(ek_satir alfa)" "| 1 / 1 / 0 |" "T20e yanlış-pozitif yok: 'alfa' KALFA'nın içinde geçse de eşleşmez"

echo; echo "GECEN=$G DUSEN=$K"
[ "$K" -eq 0 ]
