#!/usr/bin/env bash
# is-alani.sh — fabrika 1. adım (İZOLE): paylaşılan depoda GÜVENLİ çalışma alanı aç/kapat.
#
# NİÇİN VAR: depo birden çok ajanın ORTAK alanı. Dal, global ve değişken bir durum: sen `checkout -b`
# yapıp çalışırken başka bir ajan `checkout main` derse dal ayağının altından çekilir ve SONRAKİ
# commit'lerin ONUN dalına düşer (cloudtop 2026-08-04: aynı gün üç kez; biri başkasının PR'ına karıştı).
# Çözüm dikkat değil YAPI: iş kendi worktree'sinde yapılır. Orada dal senin, kimse çekemez.
#
# Fabrika sürümü (cloudtop scripts/is-alani.sh temel; iki ek):
#   · KAPSAM KONTROLÜ: `--dosyalar a,b,c` verilirse açık PR'ların dosyalarıyla çakışma aranır.
#     İKİ YÜZEY: GitHub dosya listesi ∩ merge-base farkı (main'i merge etmiş PR'ın artıkları sayılmaz); git yolu düşerse tek yüzey + uyarı.
#     ÜÇÜNCÜ YÜZEY (30 Eki · görev …7PRJ07): aynı DOSYA engel değil UYARIDIR — alan açılır, PR'ın o dosyadaki satır blokları basılır ve
#     karta yazılır; gerçek çakışma SATIR kesişimidir ve ancak alan yazdıktan sonra ölçülebilir → `kapsam-olc` (kesişim >0 → rc 2 DUR).
#   · KALICI DİZİN: /config/projects/_wt (/tmp konteyner yeniden başlayınca silinir; kayıtsız iş kaybolur).
#
# Kullanım:
#   is-alani.sh ac <iş> [--dosyalar a,b,c]  → origin/main'den TAZE worktree: <KOK>/<depo>-<iş>, dal <iş>
#   is-alani.sh kontrol                     → güvenli(0) / riskli(1) / ölçülemedi(2)
#   is-alani.sh liste                       → açık çalışma alanları
#   is-alani.sh kapat <iş>                  → worktree'yi kaldırır; kayıtsız iş varsa SİLMEZ (rc=1)
#   is-alani.sh kapsam-olc [<iş>]           → alanın yazdığı satır blokları ∩ açık PR'ların blokları: kesişim yok(0) / VAR → DUR(2) / ölçülemedi(3)
#   is-alani.sh kanca-kur                   → pre-commit korumasını BU klonda kurar (idempotent)
# Ortam: IS_ALANI_DEPO (depo kökü) · IS_ALANI_KOK (alan dizini) · IS_ALANI_ANA (ana dal, vars. main)
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 🔴 BİRİNCİL depo (13 Eki): `--show-toplevel` bağlı bir worktree'nin İÇİNDEN çağrılınca worktree'nin kendisini
#    döndürür → DEPO_AD "cloudtop-<iş>" olur, `kapat` yolu "<kök>/cloudtop-<iş>-<iş>" diye arar, "zaten yok" der.
#    Birincil depo git-common-dir'in üstüdür; linked worktree'de de aynı yere çıkar.
_birincil_depo() {
  local c
  c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$c" ] || return 1
  case "$c" in */.git) printf '%s' "${c%/.git}" ;; *) git rev-parse --show-toplevel 2>/dev/null ;; esac
}
DEPO="${IS_ALANI_DEPO:-$(_birincil_depo || echo "")}"
KOK="${IS_ALANI_KOK:-/config/projects/_wt}"
ANA="${IS_ALANI_ANA:-main}"
KANCA_SABLON="$HERE/../sablon/pre-commit"

_hata() { printf '✗ %s\n' "$*" >&2; }
_bilgi() { printf '%s\n' "$*"; }

[ -n "$DEPO" ] || { _hata "git deposu bulunamadı"; exit 1; }
DEPO_AD="$(basename "$DEPO")"

# BULUNDUĞUN yer birincil çalışma ağacı mı? (linked worktree'de git-dir ile git-common-dir AYRIŞIR)
# Bilerek cwd'ye bakar, $DEPO'ya değil: IS_ALANI_DEPO dışarıdan verilmişken worktree içinden çağrılan
# `kontrol` yanlışlıkla "riskli" dememeli.
birincil_mi() {
  local d c
  d="$(git rev-parse --absolute-git-dir 2>/dev/null || echo x)"
  c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo y)"
  [ "$d" = "$c" ]
}

# 🔴 İKİ YÜZEY (30 Eki 2026 · kart is-alani-kapsam-iki-yuzey · ŞAKİRD T12): GitHub'ın `pr diff --name-only` listesi PR dalı
#    main'i MERGE etmişse main'den gelen dosyaları da sayar (cloudtop #1185: gh 275 dosya · merge-base farkı 21 · yalnız GitHub'da 265)
#    → dokunulmayan dosya için SAHTE çakışma, rc 2, alan açılmıyordu. İkinci yüzey: dal adı `gh pr view --json headRefName,baseRefName`,
#    `git fetch origin <dal>` sonrası `git diff --name-only origin/<ana>...origin/<dal>` (merge-base farkı = PR'ın GERÇEKTEN değiştirdiği).
#    Çakışma = (GitHub listesi ∩ merge-base farkı) ∩ --dosyalar. Git yolu düşerse (pr view · fetch · diff) GitHub listesine düşülür ve
#    "◻ tek yüzey (merge-base ölçülemedi)" uyarısı basılır — sessiz düşme yok; tek yüzeyle verilen çakışma hükmü uyarısıyla gider.
# _pr_merge_base_farki <N> → rc 0: stdout = PR'ın merge-base farkındaki dosyalar · rc 1: stdout = ölçülememe SEBEBİ
#   (çağıran $(…) içinde koşturur; alt kabukta değişken kaybolur, sebep bu yüzden stdout'tan döner — DALGIÇ/ilk koşu: sebep "?" çıktı)
_pr_merge_base_farki() {
  local n="$1" json dal ana
  json="$(cd "$DEPO" && gh pr view "$n" --json headRefName,baseRefName 2>/dev/null </dev/null)" || { printf "%s" "gh pr view düştü"; return 1; }
  dal="$(printf '%s' "$json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("headRefName",""))' 2>/dev/null)" || dal=""
  ana="$(printf '%s' "$json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("baseRefName",""))' 2>/dev/null)" || ana=""
  [ -n "$dal" ] || { printf "%s" "dal adı okunamadı (gh pr view yanıtı)"; return 1; }
  [ -n "$ana" ] || ana="$ANA"
  git -C "$DEPO" fetch -q origin "$dal" "$ana" 2>/dev/null </dev/null || { printf "%s" "git fetch origin $dal düştü"; return 1; }
  git -C "$DEPO" diff --name-only "origin/$ana...origin/$dal" 2>/dev/null || { printf "%s" "git diff origin/$ana...origin/$dal düştü"; return 1; }
}

# 🔴 ÜÇÜNCÜ YÜZEY — SATIR BLOKLARI (30 Eki 2026 · görev …7PRJ07 · kart fabrika-kapsam-satir-kesisimi · BENNÂ): dosya ADI çakışması
#    engel sayılıyordu; Sx'te her beceri sürümü catalog.json'a dokunduğundan açık bir PR varken HİÇBİR alan açılamıyordu (bir günde 3× ölçüldü:
#    #506 @1564 · #586 @1530 · iskan @905 · gunluk-plan @1426 — satır kesişimi 0, rc 2). Alan henüz yazmadığı için satır kesişimi `ac`
#    anında ölçülEMEZ: aynı dosya → UYARI (dosya + PR + PR'ın satır blokları basılır, karta yazılır), alan AÇILIR. Gerçek kesişim yazdıktan
#    sonra `kapsam-olc` ile ölçülür: alanın blokları (merge-base'e göre -U0) ∩ açık PR'ların blokları; kesişim >0 → rc 2 DUR. Sessiz gevşeme yok.
#    Dürüst sınır: bloklar TABAN (eski taraf) satır numarasıdır; PR dalı main'i merge etmişse merge-base kayar ve numaralar birkaç satır şaşabilir.
# _hunklar [dosya…] ← stdin: birleşik fark · stdout: "<dosya>\t<a>-<b>" (taban tarafı aralığı; ekleme a-a = a. satırdan sonra; dosya başına ekleme 0-0)
#   ya da "<dosya>\t*" (YENİ dosya = tümü; `--- /dev/null`dan bilinir — DALGIÇ tur 1: `-0,0` başlığı dosya başına eklemeyle aynıdır, 0-0 ile karıştırılmaz). Dosya verilirse süzer.
_hunklar() {
  python3 -c '
import re,sys
suz=set(sys.argv[1:]); f=None; yeni=False
for l in sys.stdin.read().splitlines():
    if l.startswith("diff --git "):
        m=re.match(r"diff --git a/(.*?) b/(.*)$",l); f=m.group(2) if m else None; yeni=False; continue
    if l.startswith("--- "): yeni=(l[4:].strip()=="/dev/null"); continue
    if l.startswith("+++ "):
        p=l[4:].strip()
        if p!="/dev/null": f=p[2:] if p.startswith("b/") else p
        continue
    m=re.match(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@",l)
    if m and f and (not suz or f in suz):
        if yeni: print(f"{f}\t*"); continue
        a=int(m.group(1)); b=int(m.group(2)) if m.group(2) is not None else 1
        print(f"{f}\t{a}-{a+b-1 if b>0 else a}")
' "$@"
}
# _pr_hunklar <N> <dosya…> → stdout: ilk satır "#kaynak\t<nasıl ölçüldü>", sonra "<dosya>\t<a>-<b>"; rc 1: PR farkı hiç okunamadı
_pr_hunklar() {
  local n="$1" json dal ana; shift
  json="$(cd "$DEPO" && gh pr view "$n" --json headRefName,baseRefName 2>/dev/null </dev/null)" || json=""
  dal="$(printf '%s' "$json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("headRefName",""))' 2>/dev/null)" || dal=""
  ana="$(printf '%s' "$json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("baseRefName",""))' 2>/dev/null)" || ana=""
  [ -n "$ana" ] || ana="$ANA"
  local fark
  # DALGIÇ tur 1: `git diff … | _hunklar; return 0` diff düşse de 0 dönüyordu → fark önce değişkene alınır, düşerse gh yoluna düşülür
  if [ -n "$dal" ] && git -C "$DEPO" fetch -q origin "$dal" "$ana" 2>/dev/null </dev/null && fark="$(git -C "$DEPO" diff -U0 "origin/$ana...origin/$dal" -- "$@" 2>/dev/null)"; then
    printf '#kaynak\tmerge-base (git diff -U0 origin/%s...origin/%s)\n' "$ana" "$dal"
    printf '%s\n' "$fark" | _hunklar "$@"; return 0
  fi
  local ham; ham="$(cd "$DEPO" && gh pr diff "$n" 2>/dev/null </dev/null)" || return 1
  printf '#kaynak\tgh pr diff (±3 satır bağlam dahil — aralıklar gerçekten geniş olabilir)\n'
  printf '%s\n' "$ham" | _hunklar "$@"
}
# _blok_metni ← stdin: _pr_hunklar çıktısı · stdout: "dosya: a-b c-d · dosya2: …" tek satır (0-0 → "yeni dosya (tümü)")
_blok_metni() {
  python3 -c '
import sys
d={}
for l in sys.stdin.read().splitlines():
    if l.startswith("#") or "\t" not in l: continue
    f,r=l.split("\t",1); d.setdefault(f,[]).append("yeni dosya (tümü)" if r=="*" else r)
print(" · ".join(f"{f}: {chr(32).join(v)}" for f,v in d.items()) or "(satır blokları okunamadı: PR farkı çözülemedi)")
'
}
# _kesisim <alan-bloklar-dosyası> <pr-bloklar-dosyası> → stdout: "dosya\talan a-b\tPR c-d" (kesişen çiftler) · rc 0 kesişim VAR · 1 yok · 3 ÖLÇÜLEMEDİ
#   (DALGIÇ tur 1: python çökerse rc 1 "yok" sayılıyordu → çöküş rc 3, çağıran ölçülemedi der)
_kesisim() {
  python3 - "$1" "$2" <<'PYK'
import sys
def oku(p):
    d={}
    for l in open(p,encoding="utf-8").read().splitlines():
        if l.startswith("#") or "\t" not in l: continue
        f,r=l.split("\t",1)
        d.setdefault(f,[]).append(None if r=="*" else tuple(int(x) for x in r.split("-")))
    return d
try:
    A,B=oku(sys.argv[1]),oku(sys.argv[2]); var=False
    for f in A:
        for x in A[f]:
            for y in B.get(f,[]):
                if x is None or y is None or (x[0]<=y[1] and y[0]<=x[1]):
                    g=lambda r: "yeni dosya (tümü)" if r is None else f"{r[0]}-{r[1]}"
                    print(f"{f}\talan {g(x)}\tPR {g(y)}"); var=True
    sys.exit(0 if var else 1)
except Exception as e:
    print(f"#hata\t{e}"); sys.exit(3)
PYK
}
# kapsam_kontrol <dosyalar,virgüllü> → 0 temiz · 4 aynı dosya UYARISI (alan açılır; "⚠ PR #" satırları stdout'ta) · 3 ölçülemedi (gh yok/yetkisiz)
kapsam_kontrol() {
  local dosyalar="$1" prs n cakisan=0 tek_yuzey=0
  command -v gh >/dev/null 2>&1 || { _bilgi "◻ kapsam kontrolü YAPILAMADI — gh yok (açık PR'lara bakılmadı)"; return 3; }
  prs="$(cd "$DEPO" && gh pr list --state open --limit 30 --json number --jq '.[].number' 2>/dev/null)" \
    || { _bilgi "◻ kapsam kontrolü YAPILAMADI — gh pr list düştü (yetki/ağ)"; return 3; }
  [ -n "$prs" ] || { _bilgi "✓ kapsam: açık PR yok"; return 0; }
  [ "$(printf '%s' "$prs" | wc -w)" -ge 30 ] && _bilgi "⚠ açık PR sayısı tavana (30) ulaştı — daha eski açık PR'lara bakılmadı"
  for n in $prs; do
    local pr_dosyalar gercek aday ort
    pr_dosyalar="$(cd "$DEPO" && gh pr diff "$n" --name-only 2>/dev/null)" || continue
    # 2. yüzey: merge-base farkı; ölçüldüyse aday = iki listenin KESİŞİMİ, ölçülemediyse GitHub listesi + uyarı
    if gercek="$(_pr_merge_base_farki "$n")"; then
      aday="$(printf '%s\n' "$pr_dosyalar" | grep -Fx -f <(printf '%s\n' "$gercek") || true)"
    else
      aday="$pr_dosyalar"; tek_yuzey=$((tek_yuzey+1))
      _bilgi "◻ PR #$n tek yüzey (merge-base ölçülemedi: ${gercek:-?}) — GitHub dosya listesi olduğu gibi kullanıldı; main'den gelen artıklar sayılmış olabilir"
    fi
    ort="$(printf '%s\n' "$dosyalar" | tr ',' '\n' | grep -Fx -f <(printf '%s\n' "$aday") || true)"
    if [ -n "$ort" ]; then
      cakisan=$((cakisan+1))
      # shellcheck disable=SC2046
      _bilgi "⚠ PR #$n aynı dosyaya dokunuyor → $(_pr_hunklar "$n" $(printf '%s' "$ort" | tr '\n' ' ') | _blok_metni)"
    fi
  done
  if [ "$cakisan" -gt 0 ]; then
    _bilgi "⚠ KAPSAM UYARISI — $cakisan açık PR aynı dosyalara dokunuyor (satır blokları yukarıda). Aynı dosya engel DEĞİL: alan AÇILIYOR."
    _bilgi "  Gerçek çakışma satır kesişimidir ve ancak yazdıktan sonra ölçülür → PR'dan ÖNCE: bash $HERE/is-alani.sh kapsam-olc <iş>  (kesişim >0 → rc 2 DUR)"
    return 4
  fi
  _bilgi "✓ kapsam: açık PR'larla dosya çakışması yok ($(printf '%s' "$prs" | wc -w) PR bakıldı$( [ "$tek_yuzey" -gt 0 ] && printf ', %s tek yüzey' "$tek_yuzey" ))"
  return 0
}

# benzer_pr_uyar <iş> <kart> → her zaman 0 (YALNIZ UYARI). Dosya listesi verilmediğinde açık PR'lara iş adı + kart cümlesiyle bakar.
#   NİÇİN (görev …Z2G): aynı iş iki kez inşa edildi (agent-dashboard #2 ve #3, 20 gün sonra hakem). Kapsam kontrolü yalnız
#   --dosyalar ile çalışıyor ve kimse vermiyor. Sezgisel: ≥2 ortak anlamlı kök (ilk 5 harf, ≥5 harfli sözcük) → "DUR ve sor".
#   Sezgi eksik de olabilir (ad farklı yazılmışsa kaçırır) → kesin çare --dosyalar; engellemez çünkü yanlış alarm işi durdurmasın.
benzer_pr_uyar() {
  local is="$1" kart="$2" json
  command -v gh >/dev/null 2>&1 || { _bilgi "◻ benzer iş kontrolü YAPILAMADI — gh yok"; return 0; }
  json="$(cd "$DEPO" && gh pr list --state open --limit 50 --json number,title,headRefName 2>/dev/null)" \
    || { _bilgi "◻ benzer iş kontrolü YAPILAMADI — gh pr list düştü (yetki/ağ)"; return 0; }
  python3 - "$is" "$kart" "$json" <<'PY'
import json,re,sys
is_,kart,raw=sys.argv[1:4]
try: prs=json.loads(raw or "[]")
except Exception:
    print("  ◻ benzer iş kontrolü YAPILAMADI — gh yanıtı çözülemedi (açık PR'lara bakılmadı)"); sys.exit(0)
cumle=""
try: cumle=json.load(open(kart,encoding="utf-8")).get("cumle","") or ""
except Exception: pass
DUR={"icin","için","olsun","gelsin","bitti","yapilsin","yapılsın","ile","gibi","kadar","sonra","once","önce","zaman","tekrar","olarak","dosya","dosyası","kural","kartı","iş"}
def kok(m):
    return {t[:5] for t in re.findall(r"[a-zçğıöşüA-ZÇĞİÖŞÜ0-9]+",m.lower().replace("i̇","i")) if len(t)>=5 and t not in DUR}
benim=kok(is_.replace("-"," ")+" "+cumle)
bulunan=[]
for pr in prs:
    if pr.get("headRefName")==is_: continue
    ortak=benim & kok((str(pr.get("headRefName",""))+" "+str(pr.get("title",""))).replace("-"," "))
    if len(ortak)>=2: bulunan.append((pr.get("number","?"),pr.get("headRefName",""),sorted(ortak)))
for n,d,o in bulunan:
    print(f"  ⚠ BENZER İŞ: açık PR #{n} ({d}) ortak kökler: {' '.join(o)} — aynı işi iki kez yazma: DUR, PR'a bak, gerekirse sor")
if not bulunan: print(f"  ✓ benzer iş: {len(prs)} açık PR bakıldı, iş adı/cümle ile benzeyen yok (sezgisel; kesin çare --dosyalar)")
if len(prs)>=50: print("  ⚠ açık PR sayısı tavana (50) ulaştı — daha eski açık PR'lar bakılmadı olabilir")
PY
  local prc=$?
  [ "$prc" -eq 0 ] || _bilgi "  ◻ benzer iş kontrolü YAPILAMADI — iç hata (rc=$prc); açık PR'lara bakılmadı"
  return 0
}

ac() {
  local is="" dosyalar="" kartsiz=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dosyalar) dosyalar="${2:-}"; shift 2 ;;
      --kartsiz) kartsiz=1; shift ;;
      *) is="$1"; shift ;;
    esac
  done
  [ -n "$is" ] || { _hata "iş adı gerekiyor: is-alani.sh ac <iş> [--dosyalar a,b,c] [--kartsiz]"; exit 1; }
  # 0. adım kapısı: iş kartı yoksa alan açılmaz (K6 — sınıf işin başında belli olur). Kaçış: --kartsiz →
  # kart ARAÇ tarafından "cevapsız" açılır ve sultan=true damgalanır (şüphede sınıf yukarı); kaçış gün sonu özetinde görünür.
  local kart="$DEPO/_agents/fabrika/kartlar/$is.json"
  if [ ! -f "$kart" ]; then
    if [ "$kartsiz" -eq 0 ]; then
      _hata "iş kartı yok: $is — önce: bash $HERE/kart.sh ac $is --is \"…\" --istedi … --aldi … --geri-alinamaz/--para/--dis-yuzey/--yetki e|h|?"
      _hata "  (kaçış: --kartsiz → kart cevapsız açılır ve Sultan'a gider)"; exit 1
    fi
    mkdir -p "$(dirname "$kart")"
    python3 - "$kart" "$is" <<'PY'
import json,sys,datetime
yol,is_=sys.argv[1:]
json.dump({"is":is_,"cumle":"(kartsız açıldı — --kartsiz kaçışı)","istedi":"?","aldi":"?","zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
           "sinif_cevaplari":{},"siniflar":["cevapsiz"],"sultan":True,"kanit_nerede":"","oda":"","durum":"acik","kacis":True,"gecmis":[]},open(yol,"w"),ensure_ascii=False,indent=2)
PY
    _bilgi "⚠ --kartsiz: kart CEVAPSIZ açıldı, sultan=true damgalı (şüphede sınıf yukarı); gün sonu özetinde görünür"
  fi
  git -C "$DEPO" fetch -q origin || { _hata "fetch düştü — taze başlangıç garanti edilemez, DURDUM"; exit 1; }
  if git -C "$DEPO" show-ref --verify --quiet "refs/heads/$is"; then
    _hata "'$is' dalı zaten var — başka ad seç ya da önce kapat (asla zorla üstüne yazma)"; exit 1
  fi
  local krc=0 kuyari=""
  if [ -n "$dosyalar" ]; then
    kuyari="$(kapsam_kontrol "$dosyalar")"; krc=$?
    printf '%s\n' "$kuyari"
  else
    _bilgi "· kapsam: dosya listesi verilmedi (--dosyalar a,b,c) — dosya çakışmasına bakılmadı; yalnız ad/cümle benzerliği aranıyor:"
    benzer_pr_uyar "$is" "$kart"
  fi
  local yol="$KOK/$DEPO_AD-$is"
  mkdir -p "$KOK"
  [ -e "$yol" ] && { _hata "$yol zaten var"; exit 1; }
  git -C "$DEPO" worktree add -q -b "$is" "$yol" "origin/$ANA" || { _hata "worktree açılamadı"; exit 1; }
  # 🔴 KART KOPYALANMAZ (15 Eki 2026): kart TEK kaynaktır, birincil depoda yaşar (kart.sh oraya yazar, denetci.sh oradan okur).
  #    Eskiden buraya kopyalanıyordu → kopya bayatlıyor (reis-dedi/bitti birincile düşüyor), PR kartlar/ dosyasını taşıyınca
  #    birincildeki kayıtsız kart "untracked would be overwritten" ile ana dal pull'unu tıkıyordu. PR'a kart, denetci.sh'ın kanıt
  #    dizinine yazdığı KART.json anlık kopyasıyla gider.
  _bilgi "✓ çalışma alanı hazır (origin/$ANA üstünde, TAZE) · kart birincil depoda ($kart), kopyalanmadı"
  _bilgi "  cd $yol"
  _bilgi "  ⚠ worktree PAYLAŞILAN KAYNAĞI izole etmez: port · veritabanı · kilit dosyası ortaktır;"
  _bilgi "    port cevap veriyorsa SENİN süreç mi bak; kilit çakışırsa elle birleştirme, yeniden üret."
  # aynı-dosya uyarısı KARTA yazılır (kapsam_uyarilari — kart.sh goster basar, bağımsız göz görür): uyarı ekranda kalıp unutulmasın (sessiz gevşeme yok)
  if [ "$krc" -eq 4 ]; then
    python3 - "$kart" "$kuyari" <<'PYK' 2>/dev/null || _bilgi "  ◻ kapsam uyarısı karta YAZILAMADI (kart okunamadı) — yalnız ekranda"
import json,sys,datetime
yol,metin=sys.argv[1:3]
k=json.load(open(yol,encoding="utf-8")); u=k.setdefault("kapsam_uyarilari",[])
z=datetime.datetime.now().astimezone().strftime("%d.%m %H:%M")
for l in metin.splitlines():
    if l.startswith("⚠ PR #"): u.append(f"{z} is-alani: {l[2:]} — PR'dan önce kapsam-olc")
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PYK
    _bilgi "  ⚠ aynı-dosya uyarısı karta yazıldı · PR'dan ÖNCE: bash $HERE/is-alani.sh kapsam-olc $is"
  fi
  _bilgi "  bitince: bash $HERE/is-alani.sh kapat $is"
}

# kapsam_olc [<iş>] → alanın SATIR blokları ∩ açık PR'ların blokları. İş verilmezse içinde bulunulan alan (birincil ağaçta çağrılamaz).
#   Alanın farkı: çalışma ağacı vs merge-base(origin/ANA, HEAD) -U0 → commit'lenmemiş satırlar da sayılır, main'in ilerlemesi sayılmaz.
#   Kendi PR'ı (dal adı = alan dalı) sayılmaz. rc 0 kesişim yok · 2 kesişim VAR (DUR) · 3 ölçülemedi (gh yok/düştü · alan yok).
kapsam_olc() {
  local is="${1:-}" yol dal mb kes
  if [ -n "$is" ]; then yol="$KOK/$DEPO_AD-$is"
  else
    birincil_mi && { _hata "birincil ağaçtasın — kapsam-olc alanın içinden ya da iş adıyla çağrılır: is-alani.sh kapsam-olc <iş>"; return 3; }
    yol="$(git rev-parse --show-toplevel 2>/dev/null)"
  fi
  [ -d "$yol" ] || { _hata "çalışma alanı YOK: $yol — ölçülemedi"; return 3; }
  dal="$(git -C "$yol" symbolic-ref --short -q HEAD 2>/dev/null || echo "")"
  git -C "$yol" fetch -q origin "$ANA" 2>/dev/null </dev/null || _bilgi "◻ origin/$ANA tazelenemedi — eldeki origin/$ANA ile ölçülüyor"
  mb="$(git -C "$yol" merge-base "origin/$ANA" HEAD 2>/dev/null)" || { _hata "merge-base bulunamadı (origin/$ANA ↔ HEAD) — ölçülemedi"; return 3; }
  local T; T="$(mktemp -d)"
  # DALGIÇ tur 2: `git diff | _hunklar || …` boruda yalnız _hunklar'ın rc'si görünür (pipefail yok) → fark önce değişkene alınır, git düşerse rc 3
  local fark; fark="$(git -C "$yol" diff -U0 "$mb" 2>/dev/null)" || { _hata "alanın farkı okunamadı (git diff $mb düştü) — ölçülemedi"; rm -r -f "$T"; return 3; }
  printf '%s\n' "$fark" | _hunklar > "$T/alan"
  # DALGIÇ tur 1: izlenmeyen (henüz `git add` edilmemiş) yeni dosya `git diff`te görünmez → yalnız yeni dosya yazan alan 'hiçbir satır değiştirmedi' çıkardı. Onlar '*' (tümü) olarak eklenir.
  git -C "$yol" ls-files --others --exclude-standard 2>/dev/null | sed 's/$/\t*/' >> "$T/alan"
  if [ ! -s "$T/alan" ]; then _bilgi "✓ kapsam-olc: alan henüz hiçbir satır değiştirmedi (merge-base ${mb:0:8}) — kesişim yok"; rm -r -f "$T"; return 0; fi
  local benim_dosyalar; benim_dosyalar="$(cut -f1 "$T/alan" | sort -u)"
  command -v gh >/dev/null 2>&1 || { _hata "gh yok — açık PR'ların blokları ölçülemedi"; rm -r -f "$T"; return 3; }
  local prs satirlar kesisen=0 bakilan=0 ayni_dosya=0 olcemedi=0 n pdal pr_dosyalar ort kaynak
  prs="$(cd "$DEPO" && gh pr list --state open --limit 30 --json number,headRefName 2>/dev/null </dev/null)" \
    || { _hata "gh pr list düştü (yetki/ağ) — ölçülemedi"; rm -r -f "$T"; return 3; }
  satirlar="$(printf '%s' "$prs" | python3 -c 'import json,sys;[print(p.get("number",""),p.get("headRefName","")) for p in json.load(sys.stdin)]' 2>/dev/null)" \
    || { _hata "gh pr list yanıtı çözülemedi — ölçülemedi"; rm -r -f "$T"; return 3; }
  _bilgi "── kapsam-olc · alan ${dal:-?} · $(printf '%s\n' "$benim_dosyalar" | grep -c .) dosyada $(grep -c . "$T/alan") blok (merge-base ${mb:0:8})"
  [ "$(printf '%s\n' "$satirlar" | grep -c .)" -ge 30 ] && _bilgi "⚠ açık PR sayısı tavana (30) ulaştı — daha eski açık PR'lara bakılmadı"
  while read -r n pdal; do
    [ -n "$n" ] || continue
    # kendi PR'ı = dal adı BİREBİR aynı (DALGIÇ tur 2: yalnız son parça karşılaştırılırsa fabrika/x ile fix/x karışır, gerçek kesişim kaçar)
    if [ -n "$dal" ] && [ "$pdal" = "$dal" ]; then _bilgi "· PR #$n kendi PR'ın ($pdal) — sayılmaz"; continue; fi
    bakilan=$((bakilan+1))
    pr_dosyalar="$(cd "$DEPO" && gh pr diff "$n" --name-only 2>/dev/null </dev/null)" || { _bilgi "◻ PR #$n dosya listesi okunamadı — bu PR ölçülemedi"; olcemedi=$((olcemedi+1)); continue; }
    ort="$(printf '%s\n' "$benim_dosyalar" | grep -Fx -f <(printf '%s\n' "$pr_dosyalar") || true)"
    [ -n "$ort" ] || continue
    ayni_dosya=$((ayni_dosya+1))
    # shellcheck disable=SC2046
    _pr_hunklar "$n" $(printf '%s' "$ort" | tr '\n' ' ') > "$T/pr-$n" || { _bilgi "◻ PR #$n aynı dosya ($(printf '%s' "$ort" | tr '\n' ' ')) ama farkı okunamadı — kesişim ölçülemedi"; olcemedi=$((olcemedi+1)); continue; }
    kaynak="$(sed -n 's/^#kaynak\t//p' "$T/pr-$n")"
    # PR aynı dosyaya dokunuyor ama bloğu okunamadıysa bu "kesişim yok" DEĞİL ölçülemedi (DALGIÇ tur 1)
    if ! grep -qv '^#' "$T/pr-$n"; then _bilgi "◻ PR #$n aynı dosya ($(printf '%s' "$ort" | tr '\n' ' ')) ama satır blokları boş okundu ($kaynak) — kesişim ölçülemedi"; olcemedi=$((olcemedi+1)); continue; fi
    kes="$(_kesisim "$T/alan" "$T/pr-$n")"; local krc=$?
    case "$krc" in
      0) kesisen=$((kesisen+1))
         _bilgi "✗ PR #$n ($pdal) SATIR KESİŞİMİ ($kaynak):"
         printf '%s\n' "$kes" | while IFS=$'\t' read -r f a b; do _bilgi "    · $f: $a ∩ $b"; done ;;
      1) _bilgi "· PR #$n ($pdal) aynı dosya, satır kesişimi YOK ($kaynak) — PR: $(_blok_metni < "$T/pr-$n") · alan: $(grep -F -f <(printf '%s\n' "$ort" | sed 's/$/\t/') "$T/alan" | _blok_metni)" ;;
      *) _bilgi "◻ PR #$n kesişim hesabı DÜŞTÜ (${kes#\#hata$'\t'}) — ölçülemedi"; olcemedi=$((olcemedi+1)) ;;
    esac
  done <<<"$satirlar"
  rm -r -f "$T"
  if [ "$kesisen" -gt 0 ]; then
    _hata "SATIR KESİŞİMİ — $kesisen açık PR aynı satırları değiştiriyor. DUR: önce o PR birleşsin ve alan onun üstüne alınsın, ya da reise sor."
    return 2
  fi
  if [ "$olcemedi" -gt 0 ]; then _hata "kapsam-olc ÖLÇÜLEMEDİ — $olcemedi PR'ın kesişimi hesaplanamadı (yukarıda); 'kesişim yok' DENMEZ (rc 3)"; return 3; fi
  _bilgi "✓ kapsam-olc: satır kesişimi yok ($bakilan açık PR bakıldı, $ayni_dosya aynı dosyaya dokunuyor)"
  return 0
}

kontrol() {
  local dal
  dal="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [ -z "$dal" ]; then _bilgi "◻ ölçülemedi — dal okunamadı"; return 2; fi
  if ! birincil_mi; then
    _bilgi "✓ güvenli — kendi çalışma alanındasın (dal: $dal)"; return 0
  fi
  if [ "$dal" = "$ANA" ]; then
    _bilgi "✓ güvenli — paylaşılan ağaçta ve $ANA üstündesin (commit için worktree aç)"; return 0
  fi
  _bilgi "⚠ RİSKLİ — PAYLAŞILAN ağaçta '$dal' dalındasın."
  _bilgi "  Başka bir ajan dal değiştirirse commit'in ONUN dalına düşer (2026-08-04'te 3 kez oldu)."
  _bilgi "  Yapılacak: bash $HERE/is-alani.sh ac <iş>  → kendi alanında çalış"
  return 1
}

liste() { git -C "$DEPO" worktree list | sed 's/^/  /'; }

# 🟡 KART KAPANIŞI (görev CBBQEE · B16BJ parçası, 23 Eki): kart = dilim; PR birleşince kartın 'bitti' olması ajanın
#    hatırlamasına kalıyordu ve iki ayrı tuzak üretti — kart açık kalıyordu (17 Eki hijyeni: 30 sınıflı kart PR'ı birleşmiş ama
#    açık) ya da `kart.sh bitti` alan kapandıktan SONRA koşulup "KANIT YOK" damgalıyordu. Çağıran: her işin zaten koştuğu bu
#    kapanış adımı (yeni kanca/cron YOK). Kart AÇIKSA ve dalın PR'ı BİRLEŞMİŞSE `kart.sh bitti <iş> --pr N` alanın İÇİNDEN koşar.
#    PR birleşmemişse (geri al, terk) ya da ölçülemezse (gh yok · ağ yok) kart AÇIK kalır ve bu SÖYLENİR — kapanış durmaz:
#    alanı kapatmak kartı kapatmaktan bağımsız bir iştir. Kartı olmayan ya da zaten kapanmış iş için hiçbir şey yapılmaz.
#    Dürüst sınır: alanı hiç kapatılmayan iş bu yoldan geçmez; kart→PR eşleşmesi dal adından (dal = iş adı).
kart_kapanisi() {
  local is="$1" yol="$2" kj="$DEPO/_agents/fabrika/kartlar/$1.json" durum pr
  [ -f "$kj" ] || return 0
  durum="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8")).get("durum",""))' "$kj" 2>/dev/null)"
  [ "$durum" = acik ] || return 0
  if ! pr="$(cd "$yol" && gh pr list --head "$is" --state merged --json number -q '.[0].number' 2>/dev/null </dev/null)"; then
    _bilgi "· kartın PR'ı ÖLÇÜLEMEDİ (gh) — kart AÇIK kaldı; birleştiyse elle: (cd $yol && kart.sh bitti $is --pr <N>)"; return 0
  fi
  if [ -z "$pr" ]; then
    _bilgi "· '$is' dalının birleşmiş PR'ı yok — kart AÇIK kaldı (geri alındıysa: kart.sh tikandi $is --yol geri-al …)"; return 0
  fi
  ( cd "$yol" && bash "$HERE/kart.sh" bitti "$is" --pr "$pr" </dev/null ); local rc=$?
  case "$rc" in
    0) _bilgi "✓ kart kendiliğinden bitti: $is · PR #$pr birleşmiş (alanın içinden)" ;;
    4) _bilgi "✓ kart kendiliğinden bitti: $is · PR #$pr — ⚠ görev defterine YAZILAMADI (yukarıdaki sebep); görev adımını elle yaz" ;;
    # kart KAPANMADIYSA alan SİLİNMEZ: silinirse kart bir daha alanın içinden kapatılamaz ("KANIT YOK" tuzağı) — önce kartı düzelt
    *) _hata "kart.sh bitti $is --pr $pr rc=$rc — kart kapanmadı, alan SİLİNMEDİ (kanıt alanın içinde); sebebi düzeltip yeniden kapat"; exit 1 ;;
  esac
}

kapat() {
  local is="${1:-}"
  [ -n "$is" ] || { _hata "iş adı gerekiyor"; exit 1; }
  local yol="$KOK/$DEPO_AD-$is"
  if [ -d "$yol" ]; then
    local kirli
    # YALNIZ kayıtsız (??) kartlar/ kopyası kayıtsız iş DEĞİL (kart birincilde; eski aracın bıraktığı kopya). İzlenen/değiştirilmiş (' M', 'A ' …)
    # kartlar/ dosyası İŞTİR ve sayılır — göz tur 1: yol metniyle eşleyen eski süzgeç izlenen değişikliği de kir dışı bırakıp SİLEBİLİYORDU.
    kirli="$(git -C "$yol" status --porcelain -uall 2>/dev/null | grep -v '^?? _agents/fabrika/kartlar/' | wc -l)"
    if [ "$kirli" -gt 0 ]; then
      _hata "$yol içinde $kirli kayıtsız değişiklik var — önce commit'le ya da bilinçli sil (iş kaybı yok)"
      exit 1
    fi
    # kartlar/ altındaki kayıtsız kopyalar (eski aracın bıraktığı) iş değildir ama `worktree remove`yi engeller → önce onlar kaldırılır
    if [ -n "$(git -C "$yol" status --porcelain -uall 2>/dev/null | grep '^?? _agents/fabrika/kartlar/')" ]; then
      git -C "$yol" status --porcelain -uall | grep '^?? _agents/fabrika/kartlar/' | sed 's/^...//' | while IFS= read -r f; do rm -f "$yol/$f"; done
      _bilgi "· kartlar/ kayıtsız kopyası kaldırıldı (kart birincil depoda, iş kaybı yok)"
    fi
    kart_kapanisi "$is" "$yol"   # alan silinmeden ÖNCE: kart.sh bitti kanıtı ve denetimi alanın içinden okur
    git -C "$DEPO" worktree remove "$yol" || { _hata "worktree kaldırılamadı"; exit 1; }
    _bilgi "✓ çalışma alanı kaldırıldı: $yol"
  else
    # 🔴 Olmayan alanı "kapattım" diye yeşil basmak sahte başarıdır (13 Eki): adı yanlış yazılmış ya da yol yanlış
    #    türetilmiş olabilir. Dal silmeye de geçilmez; çağıran yolu görür ve karar verir.
    _hata "çalışma alanı YOK: $yol — kapatılacak bir şey bulunamadı (ad doğru mu? alanlar: $(ls -d "$KOK/$DEPO_AD-"* 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' '))"
    exit 2
  fi
  git -C "$DEPO" branch -d "$is" 2>/dev/null && _bilgi "✓ dal silindi: $is" \
    || _bilgi "· dal silinmedi (squash-merge sonrası -d reddeder; iş merge olduysa: git branch -D $is)"
}

kanca_kur() {
  local mevcut
  mkdir -p "$DEPO/.githooks"
  if [ ! -f "$DEPO/.githooks/pre-commit" ]; then
    cp "$KANCA_SABLON" "$DEPO/.githooks/pre-commit" && chmod +x "$DEPO/.githooks/pre-commit" \
      && _bilgi "✓ pre-commit kancası kopyalandı (.githooks/pre-commit)" \
      || { _hata "kanca kopyalanamadı"; exit 1; }
  else
    _bilgi "· .githooks/pre-commit zaten var — dokunulmadı"
  fi
  mevcut="$(git -C "$DEPO" config core.hooksPath 2>/dev/null || echo "")"
  if [ "$mevcut" = ".githooks" ]; then
    _bilgi "· koruma zaten kurulu (core.hooksPath=.githooks)"
  elif [ -n "$mevcut" ]; then
    _hata "core.hooksPath başka bir yere bakıyor ($mevcut) — üstüne YAZMADIM; elle karar ver"; exit 1
  else
    git -C "$DEPO" config core.hooksPath .githooks || { _hata "ayarlanamadı"; exit 1; }
    _bilgi "✓ koruma kuruldu (core.hooksPath=.githooks)"
  fi
  [ -x "$DEPO/.githooks/pre-commit" ] && _bilgi "✓ pre-commit yerinde ve çalıştırılabilir" \
    || { _hata "pre-commit çalıştırılamaz — koruma ETKİSİZ"; exit 1; }
}

case "${1:-kontrol}" in
  ac)        shift; ac "$@" ;;
  kanca-kur) kanca_kur ;;
  kontrol)   kontrol ;;
  liste)     liste ;;
  kapat)     shift; kapat "$@" ;;
  kapsam-olc) shift; kapsam_olc "$@" ;;
  *)         sed -n '1,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
