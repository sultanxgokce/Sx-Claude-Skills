#!/usr/bin/env bash
# denetci-on-goz.test.sh — ön göz denetime bağlı (görev W42-E1 …W7H1EBA dilim 3 · tasarım Nexus _agents/spec/on-goz-adimi-DESIGN.md S9-S12).
# Ölçtüğü: her denetim turu ön gözü (on-goz.py A1-A5 + DALGIÇ) koşar ve DENETIM kaydına on_goz alanını yazar; zorunlu kipte
#   (DENETCI_ON_GOZ_ZORUNLU=1 ya da depo bayrağı _agents/fabrika/on-goz-zorunlu origin/main'de) uyumsuz/ölçülemedi → denetim AÇILMAZ,
#   DENETIM yazılmaz (tur yanmaz); --on-goz-gec "<gerekçe ≥20>" bilinçli geçiştir: karta (on_goz_gecisleri[]) ve DENETIM'e yazılır, göz kartta görür;
#   --on-goz yalnız ön göz koşar (denetim yok, rc 0/1/3).
# Hermetik: çıplak uzak, gerçek kanit.sh + on-goz.py, sahte göz (DENETCI_KOMUT), sahte DALGIÇ, sahte gh. Zil kapalı.
# Mutantlar sınavın İÇİNDE değil (her biri süiti baştan koşturur; 12 mutantla CI 120 sn tavanını aştı, 7 Kas #739): kanıt betiği
#   _agents/fabrika/kanit/on-goz-denetime/kos.sh <mutant> her birini ayrı kayıt olarak koşar (on-goz.test.sh ile aynı desen). MUTANT_D=<bozuk denetci.sh>.
# kabuk-testleri: sure=120
set -uo pipefail
export KANIT_SIRA=0 DENETCI_SIRA=0 FABRIKA_AILE_NOTIFY=- ON_GOZ_SINAV=1   # sahte gözle ön göz yalnız ON_GOZ_SINAV=1 ile koşar (sınav dişi)
unset DENETCI_ON_GOZ_ZORUNLU DALGIC_KAPALI
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"; KS="$HERE/kart.sh"
GECEN=0; DUSEN=0
kapi() { local ad="$1" bek="$2"; shift 2
  "$@" >"$KOK/son.out" 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; sed 's/^/      | /' "$KOK/son.out" | tail -8; fi; }
dogru() { local ad="$1"; shift; if "$@"; then GECEN=$((GECEN+1)); echo "  ✓ $ad"; else DUSEN=$((DUSEN+1)); echo "  ✗ $ad"; fi; }
iceren() { if grep -qF -- "$2" "$3" 2>/dev/null; then GECEN=$((GECEN+1)); echo "  ✓ $1"; else DUSEN=$((DUSEN+1)); echo "  ✗ $1 ('$2' $3 içinde yok)"; fi; }
jdeger() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));
for p in sys.argv[2].split("."): d=d[int(p)] if isinstance(d,list) else d.get(p) if isinstance(d,dict) else None
print(d)' "$1" "$2" 2>/dev/null; }
KOK="$(mktemp -d)"; trap 'find "$KOK" -depth -delete 2>/dev/null' EXIT
git init -q --bare -b main "$KOK/o.git"; git clone -q "$KOK/o.git" "$KOK/w" 2>/dev/null
W="$KOK/w"; git -C "$W" config user.email t@t; git -C "$W" config user.name t
echo taban > "$W/a.txt"; git -C "$W" add a.txt; git -C "$W" commit -q -m taban; git -C "$W" push -q origin main 2>/dev/null
git -C "$W" remote set-head origin main >/dev/null 2>&1
SAHTE="$KOK/sahte.sh"; printf '#!/usr/bin/env bash\ncp "$1" "$SAHTE_ISTEM_KOPYA"; printf %%s "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"
export DENETCI_KOMUT="$SAHTE" SAHTE_ISTEM_KOPYA="$KOK/istem.md"
J5='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
# sahte DALGIÇ: çağrıldığını işaretler, DALGIC_RC ile döner
SDAL="$KOK/dalgic.sh"; printf '#!/usr/bin/env bash\ntouch "$DALGIC_IZ"; echo sahte-ongoz; exit "${DALGIC_RC:-0}"\n' > "$SDAL"; chmod +x "$SDAL"
export DALGIC_BIN="$SDAL" DALGIC_IZ="$KOK/dalgic.cagrildi"
# sahte gh: GH_RC verilirse o koduyla düşer; yoksa PR başı = HEAD
mkdir -p "$KOK/bin"; printf '#!/usr/bin/env bash\n[ -n "${GH_RC:-}" ] && exit "$GH_RC"\ncase "$*" in *headRefOid*) git rev-parse HEAD ;; *"pr diff"*) git diff origin/main...HEAD ;; *) echo "{}" ;; esac\n' > "$KOK/bin/gh"; chmod +x "$KOK/bin/gh"
export PATH="$KOK/bin:$PATH"
kart_ac() {  # kart_ac <iş> [cümle] — birincil kartlar dizinine sınıfsız kart (kart.sh ac'ın ölçüt/sınır kapıları bu sınavın konusu değil)
  mkdir -p "$W/_agents/fabrika/kartlar"
  python3 -c 'import json,sys;json.dump({"is":sys.argv[1],"cumle":sys.argv[2],"durum":"acik","sultan":False,"siniflar":[],"aldi":"BANI","istedi":"SERDAR"},open(sys.argv[3],"w"),ensure_ascii=False)' \
    "$1" "${2:-ön göz sınavı işi}" "$W/_agents/fabrika/kartlar/$1.json"; }
is_hazirla() {  # is_hazirla <iş> — dal + kod commit'i + HEAD'de kanıt
  git -C "$W" checkout -q -b "$1" origin/main 2>/dev/null
  printf '%s\n' "$1-kod" > "$W/$1.txt"; git -C "$W" add "$1.txt"; git -C "$W" commit -q -m "$1"
  KANIT_DEPO="$W" bash "$K" olcum "$1" o --asama tek -- true >/dev/null 2>&1
  kart_ac "$1"; }
bayat() { printf 'sonra\n' >> "$W/$1.txt"; git -C "$W" commit -q -am "$1 kanıttan sonra"; }   # A1: kanıt eski başta (ölçülen en sık sınıf, %32)
den() { local is="$1"; shift; ( cd "$W" && SAHTE_JSON="$J5" KANIT_DEPO="$W" bash "$D" "$is" "$@" < /dev/null ); }
kayit() { echo "$W/_agents/fabrika/kanit/$1/DENETIM-${2:-1}.json"; }

echo "════ S12 · uyumlu iş: denetim açılır, on_goz alanı dolu ════"
is_hazirla u1; rm -f "$DALGIC_IZ"
kapi "S12a uyumlu iş denetlenir (5/E → rc 0)" 0 den u1
dogru "S12b DENETIM on_goz.durum = uyumlu" [ "$(jdeger "$(kayit u1)" on_goz.durum)" = uyumlu ]
dogru "S12c beş kapı alanı da yazılı (kanit_basi·kanit_eksik·taban·agac·kapsam_dosya)" python3 -c 'import json,sys;o=json.load(open(sys.argv[1]))["on_goz"];sys.exit(0 if all(o.get(k) in ("uyumlu","uyumsuz","olculemedi") for k in ("kanit_basi","kanit_eksik","taban","agac","kapsam_dosya")) else 1)' "$(kayit u1)"
dogru "S12d DALGIÇ sonucu on_goz.dalgic'te" [ "$(jdeger "$(kayit u1)" on_goz.dalgic)" = uyumlu ]
dogru "S12e zorunlu kip kayıtta (kapali)" [ "$(jdeger "$(kayit u1)" on_goz.zorunlu)" = kapali ]
KD="$W/_agents/fabrika/karne.jsonl"   # denetçi her turun sonunda karne.sh yaz'ı kendisi çağırır
dogru "S12f karne satırı on_goz durumunu taşır" python3 -c 'import json,sys;r=[json.loads(l) for l in open(sys.argv[1]) if l.strip()];r=[x for x in r if x.get("is")=="u1"][-1];sys.exit(0 if r.get("on_goz")=="uyumlu" else 1)' "$KD"
( cd "$W" && bash "$HERE/karne.sh" ozet --gun 30 > "$KOK/ozet.out" 2>&1 )
iceren "S12g karne özeti ön göz kırılımını sayar" "ön göz" "$KOK/ozet.out"

echo "════ G · bilgi kipi (zorunlu değil): uyumsuz ön göz denetimi durdurmaz ════"
is_hazirla b1; bayat b1
kapi "G1 bayat kanıt + zorunlu yok → denetim açılır (rc 0)" 0 den b1
dogru "G2 DENETIM on_goz.durum = uyumsuz, kanit_basi = uyumsuz" [ "$(jdeger "$(kayit b1)" on_goz.durum)/$(jdeger "$(kayit b1)" on_goz.kanit_basi)" = uyumsuz/uyumsuz ]
iceren "G3 ekranda bilgi kipi uyarısı" "ÖN GÖZ UYUMSUZ — bilgi kipi" "$KOK/son.out"

echo "════ D · sınav dişi: sahte göz varken ön göz yalnız ON_GOZ_SINAV=1 ile koşar ════"
is_hazirla s1; bayat s1; rm -f "$DALGIC_IZ"
kapi "D1 ON_GOZ_SINAV yok + bayraksız kip + bayat kanıt → ön göz koşmaz, denetim açılır (rc 0)" 0 env -u ON_GOZ_SINAV bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" s1 < /dev/null' _ "$W" "$J5" "$D"
dogru "D2 kayıtta on_goz.durum = sinav-kapali (ölçülmedi, uyumlu sayılmaz)" [ "$(jdeger "$(kayit s1)" on_goz.durum)" = sinav-kapali ]
dogru "D2b dişte DALGIÇ da koşmaz (çağrılmadı, kayıtta dalgic = sinav-kapali)" [ ! -e "$DALGIC_IZ" ] && [ "$(jdeger "$(kayit s1)" dalgic)" = sinav-kapali ]
is_hazirla s2; bayat s2
kapi "D3 ON_GOZ_SINAV yok ama ZORUNLU kip (ortam) → ön göz yine koşar, denetim açılmaz (rc 1)" 1 env -u ON_GOZ_SINAV DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" s2 < /dev/null' _ "$W" "$J5" "$D"
dogru "D3b DENETIM yazılmadı" [ ! -e "$(kayit s2)" ]
kapi "D4 ON_GOZ_SINAV yok + --on-goz-gec → ön göz koşar, geçiş kayda girer (rc 0)" 0 env -u ON_GOZ_SINAV bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" s2 --on-goz-gec "$4" < /dev/null' _ "$W" "$J5" "$D" "sınav dişi geçişte kapanmaz: sınav gerekçesi"
dogru "D4b DENETIM on_goz.durum = gecildi" [ "$(jdeger "$(kayit s2)" on_goz.durum)" = gecildi ]

echo "════ S9 · zorunlu kip: uyumsuz → denetim açılmaz, tur yanmaz ════"
is_hazirla z1; bayat z1; rm -f "$DALGIC_IZ"; : > "$KOK/istem.md"
kapi "S9a zorunlu + uyumsuz → rc 1" 1 env DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" z1 < /dev/null' _ "$W" "$J5" "$D"
dogru "S9b DENETIM-1.json YAZILMADI (tur yanmadı)" [ ! -e "$(kayit z1)" ]
dogru "S9c koşuyor izi kalmadı" [ -z "$(ls "$W/_agents/fabrika/kanit/z1/"*.kosuyor 2>/dev/null)" ]
dogru "S9d bağımsız göz çağrılmadı (istem boş)" [ ! -s "$KOK/istem.md" ]
dogru "S9e A uyumsuzken DALGIÇ çağrılmadı (para harcanmaz)" [ ! -e "$DALGIC_IZ" ]
iceren "S9f sebep ve geçiş yolu söylenir" "--on-goz-gec" "$KOK/son.out"
iceren "S9f2 sebebi A1 satırı (kanıt eski başta)" "✗ A1 kanıt başı" "$KOK/son.out"

echo "════ S9g · depo bayrağı (origin/main'de) zorunlu kipi açar ════"
git -C "$W" checkout -q main 2>/dev/null; mkdir -p "$W/_agents/fabrika"; printf 'W42-E1 pilot\n' > "$W/_agents/fabrika/on-goz-zorunlu"
git -C "$W" add _agents/fabrika/on-goz-zorunlu; git -C "$W" commit -q -m bayrak; git -C "$W" push -q origin main 2>/dev/null
is_hazirla z2; git -C "$W" rm -q --cached _agents/fabrika/on-goz-zorunlu 2>/dev/null; rm -f "$W/_agents/fabrika/on-goz-zorunlu"; git -C "$W" commit -q -m bayrak-alanda-yok
bayat z2
kapi "S9g alanda bayrak yok ama origin/main'de var → zorunlu, rc 1" 1 den z2
dogru "S9h DENETIM yazılmadı" [ ! -e "$(kayit z2)" ]
iceren "S9i kaynak söylenir (origin/main bayrağı)" "zorunlu kip: origin/main" "$KOK/son.out"

echo "════ S10 · gerekçeli geçiş ════"
is_hazirla g1; bayat g1; : > "$KOK/istem.md"
GER="kanıt eski başta bilerek: sınav fikstürü burada"
kapi "S10a gerekçe <20 → rc 2 (denetim açılmaz)" 2 env DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" g1 --on-goz-gec "kısa gerekçe" < /dev/null' _ "$W" "$J5" "$D"
dogru "S10b kısa gerekçede DENETIM yok" [ ! -e "$(kayit g1)" ]
kapi "S10a2 tam 19 karakter (yığın tek sayılır: '  abcdefghi   jklmnopqr ') → rc 2" 2 env DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" g1 --on-goz-gec "  abcdefghi   jklmnopqr " < /dev/null' _ "$W" "$J5" "$D"
iceren "S10a3 mesaj sayılan uzunluğu söyler (19 yazıldı)" "19 yazıldı" "$KOK/son.out"
kapi "S10c gerekçe ≥20 → denetim açılır (rc 0)" 0 env DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" g1 --on-goz-gec "$4" < /dev/null' _ "$W" "$J5" "$D" "$GER"
dogru "S10d DENETIM on_goz.durum = gecildi" [ "$(jdeger "$(kayit g1)" on_goz.durum)" = gecildi ]
dogru "S10e DENETIM gecis_gerekcesi = verilen" [ "$(jdeger "$(kayit g1)" on_goz.gecis_gerekcesi)" = "$GER" ]
dogru "S10f kartta on_goz_gecisleri[0].gerekce" [ "$(jdeger "$W/_agents/fabrika/kartlar/g1.json" on_goz_gecisleri.0.gerekce)" = "$GER" ]
iceren "S10g göz istemi gerekçeyi kart metninde görür" "$GER" "$KOK/istem.md"

is_hazirla g2
kapi "S10h ön göz UYUMLU iken --on-goz-gec → denetim açılır (rc 0)" 0 den g2 --on-goz-gec "$GER"
dogru "S10i uyumluda geçiş YAZILMAZ: DENETIM durum uyumlu, gerekçe yok, kartta on_goz_gecisleri yok" [ "$(jdeger "$(kayit g2)" on_goz.durum)/$(jdeger "$(kayit g2)" on_goz.gecis_gerekcesi)/$(jdeger "$W/_agents/fabrika/kartlar/g2.json" on_goz_gecisleri)" = "uyumlu/None/None" ]
iceren "S10j söylenir: geçiş gerekmedi" "geçiş gerekmedi, karta yazılmadı" "$KOK/son.out"

is_hazirla g3; bayat g3
kapi "S10k tam 20 karakter ('abcdefghij klmnopqrs') → denetim açılır (rc 0)" 0 env DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" g3 --on-goz-gec "abcdefghij klmnopqrs" < /dev/null' _ "$W" "$J5" "$D"
dogru "S10l 20 karakterde durum gecildi" [ "$(jdeger "$(kayit g3)" on_goz.durum)" = gecildi ]

echo "════ Z · zorunlu kipte denetçinin kendi tavan satırı (--reis-devam yazımı) denetimi kapatmaz (A4 defter istisnası) ════"
git -C "$W" checkout -q main 2>/dev/null; mkdir -p "$W/_agents/fabrika"; printf 'baslik\n' > "$W/_agents/fabrika/tavan-defteri.log"
git -C "$W" add _agents/fabrika/tavan-defteri.log; git -C "$W" commit -q -m tavan-defteri; git -C "$W" push -q origin main 2>/dev/null
is_hazirla t1; printf '2026-11-07T00:00:00Z | TAVAN-ACILDI-REIS | is=t1 tur=3 | reis=BANI\n' >> "$W/_agents/fabrika/tavan-defteri.log"
kapi "Z1 zorunlu + yalnız tavan defteri kirli → ön göz uyumlu, denetim açılır (rc 0)" 0 env DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" t1 < /dev/null' _ "$W" "$J5" "$D"
dogru "Z2 DENETIM on_goz.agac = uyumlu (tavan satırı kirli sayılmadı)" [ "$(jdeger "$(kayit t1)" on_goz.agac)" = uyumlu ]
git -C "$W" checkout -q -- _agents/fabrika/tavan-defteri.log

echo "════ S11 · ölçülemedi uyumlu sayılmaz ════"
is_hazirla o1
kapi "S11a PR başı okunamıyor (gh rc 255) + zorunlu → rc 3" 3 env GH_RC=255 DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" o1 --pr 7 --diff /dev/null < /dev/null' _ "$W" "$J5" "$D"
dogru "S11b DENETIM yazılmadı" [ ! -e "$(kayit o1)" ]
iceren "S11c ÖLÇÜLEMEDİ — denetim açılmadı" "ÖN GÖZ ÖLÇÜLEMEDİ — denetim AÇILMADI" "$KOK/son.out"
iceren "S11d sebep PR başının okunamaması (A1 ○)" "PR #7 başı okunamadı" "$KOK/son.out"

echo "════ B · DALGIÇ uyumsuz da zorunlu kipte durdurur ════"
is_hazirla d1; rm -f "$DALGIC_IZ"
kapi "B1 A uyumlu + DALGIÇ uyumsuz + zorunlu → rc 1" 1 env DALGIC_RC=1 DENETCI_ON_GOZ_ZORUNLU=1 bash -c 'cd "$1" && SAHTE_JSON="$2" KANIT_DEPO="$1" bash "$3" d1 < /dev/null' _ "$W" "$J5" "$D"
dogru "B2 DALGIÇ çağrıldı" [ -e "$DALGIC_IZ" ]
dogru "B3 DENETIM yazılmadı" [ ! -e "$(kayit d1)" ]

echo "════ Y · --on-goz yalnız ön göz ════"
is_hazirla y1
kapi "Y1 uyumlu → rc 0" 0 den y1 --on-goz
dogru "Y2 DENETIM yazılmadı, kanıt dizininde koşuyor izi yok" [ ! -e "$(kayit y1)" ] && [ -z "$(ls "$W/_agents/fabrika/kanit/y1/"*.kosuyor 2>/dev/null)" ]
iceren "Y3 hüküm satırı" "ÖN GÖZ" "$KOK/son.out"
bayat y1
kapi "Y4 uyumsuz → rc 1" 1 den y1 --on-goz
kapi "Y5 --on-goz ile --on-goz-gec birlikte → rc 2 (kullanım)" 2 den y1 --on-goz --on-goz-gec "$GER"

echo "SONUÇ: $GECEN geçti, $DUSEN düştü"; [[ $DUSEN -eq 0 ]]
