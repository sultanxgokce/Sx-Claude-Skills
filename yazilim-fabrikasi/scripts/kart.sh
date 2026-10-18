#!/usr/bin/env bash
# kart.sh — fabrika 0. adım (KABUL): iş kartını ARAÇ yazar; sınıfı dört soruyla ARAÇ sorar (K6).
#
# Kartlar BİRİNCİL depo kökünde yaşar: <depo>/_agents/fabrika/kartlar/<iş>.json (worktree'ler ortak görür).
# Dört sınıf sorusu cevapsız kart AÇILMAZ. Biri "e" ya da "?" ise → sultan=true (şüphede sınıf YUKARI).
#
# Kullanım:
#   kart.sh ac <iş> --is "tek cümle" --istedi <kim> --aldi <ajan> \
#          --geri-alinamaz e|h|? --para e|h|? --dis-yuzey e|h|? --yetki e|h|? [--kanit "nerede olacak"] [--oda <oda>] [--canli e|h]
#          --canli: cron/servis/sunucu işi gerçek ateşleme kaydı (kanit.sh canli) ister; verilmezse cümleden türetilir, karta yazılır
#   kart.sh bitti <iş> [--pr N]        durum=bitti; son DENETIM puanını ve KANIT durumunu karta işler (worktree'den de çağrılabilir)
#   kart.sh tikandi <iş> --yol devam|daralt|geri-al --neden "..."
#   kart.sh daralt <iş> --kalan "<kalan bulgu ≥20>" --cumle "<daraltılmış cümle ≥20>" --oturum <ref> [--yeni <ad>]
#     → kart cümlesi daraltılır (eskisi cumle_gecmisi'ne), kalan bulgu YENİ karta (aynı sınıf cevapları, aynı sahip),
#       karta daraltma kaydı (tur_sifir = o andaki denetim turu → denetçi yeni cümleyle sıfırdan sayar, kapı onu okur).
#       Sınıfsız kartta reis kararı 'daralt' kendiliğinden işlenir; SINIFLI kartta Sultan'ın 'daralt' kararı (sultan-dedi) ŞARTTIR.
#   kart.sh sultan-dedi <iş> --karar <devam|daralt|geri-al> --oturum <ref> --soz "<verbatim ≤15 kelime>" \
#          --beyan <AJAN> --gerekce "<niçin bu yol işe yarar — en az 20 karakter>"
#   kart.sh reis-dedi <iş> --karar <devam|daralt|geri-al> --reis <AD> --oturum <ref> \
#          --gerekce "<niçin — en az 20 karakter>"     ← YALNIZ SINIFSIZ kartta (sınıflı işin kararı Sultan'ındır)
#          Sultan'ın SÖZLÜ kararını KARTA işler (D1 deseni). Üç parça zorunlu: oturum-ref · kırpık · beyan.
#          🔴 A06: onay ÜRETMEZ, alınan onayı AKTARIR. Ref'siz beyan sayılmaz; uyduran kartta yakalanır.
#   kart.sh goster <iş> · kart.sh liste [--acik] · kart.sh canli-gerekir <iş>  → "E|H<TAB>sebep" (eski kartta cümleden türetir)
# Ortam: FABRIKA_TETIK (oda-tetik.sh yolu; --oda verilirse tetik atılır, düşerse iş düşmez) · KANIT_DEPO
# rc: 0 · 1 kullanım/eksik cevap · 3 ölçülemedi
set -uo pipefail
_hata() { printf '✗ %s\n' "$*" >&2; }
TETIK="${FABRIKA_TETIK:-/config/projects/Nexus/scripts/oda-tetik.sh}"

birincil_kok() {  # worktree içinden çağrılsa da BİRİNCİL depo kökü
  local c; c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  dirname "$c"
}
DEPO="${KANIT_DEPO:-$(birincil_kok)}"; [ -n "$DEPO" ] || { _hata "depo kökü bulunamadı"; exit 3; }
KD="$DEPO/_agents/fabrika/kartlar"; mkdir -p "$KD"

CMD="${1:-}"; IS="${2:-}"; shift 2 2>/dev/null || true
IS_C=""; ISTEDI=""; ALDI=""; GA=""; PARA=""; DIS=""; YETKI=""; KANIT=""; ODA=""; PR=""; YOL=""; NEDEN=""
KARAR=""; OTURUM=""; SOZ=""; BEYAN=""; GEREKCE=""; REIS=""; CANLI=""; KALAN=""; CUMLE=""; YENI=""
while [ $# -gt 0 ]; do case "$1" in
  --is) IS_C="$2"; shift 2 ;; --istedi) ISTEDI="$2"; shift 2 ;; --aldi) ALDI="$2"; shift 2 ;;
  --geri-alinamaz) GA="$2"; shift 2 ;; --para) PARA="$2"; shift 2 ;; --dis-yuzey) DIS="$2"; shift 2 ;; --yetki) YETKI="$2"; shift 2 ;;
  --kanit) KANIT="$2"; shift 2 ;; --oda) ODA="$2"; shift 2 ;; --pr) PR="$2"; shift 2 ;; --yol) YOL="$2"; shift 2 ;; --neden) NEDEN="$2"; shift 2 ;;
  --karar) KARAR="$2"; shift 2 ;; --oturum) OTURUM="$2"; shift 2 ;; --soz) SOZ="$2"; shift 2 ;; --beyan) BEYAN="$2"; shift 2 ;;
  --gerekce) GEREKCE="$2"; shift 2 ;; --reis) REIS="$2"; shift 2 ;; --canli) CANLI="$2"; shift 2 ;;
  --kalan) KALAN="$2"; shift 2 ;; --cumle) CUMLE="$2"; shift 2 ;; --yeni) YENI="$2"; shift 2 ;;
  --acik) ACIK=1; shift ;; *) _hata "tanınmayan argüman: $1"; exit 1 ;; esac; done

tetik() {  # tetik <oda> <başlık> <gövde>
  [ -n "$1" ] || return 0
  if [ ! -x "$TETIK" ]; then echo "· tetik atılmadı: $TETIK yok (mesaj kartta duruyor)"; return 0; fi
  local f; f="$(mktemp)"; printf '%s\n' "$3" > "$f"
  bash "$TETIK" gonder "$1" "$f" --ajan "${ALDI:-fabrika}" --baslik "$2" >/dev/null 2>&1 && echo "✓ tetik: $1 ← $2" || echo "· tetik düştü (mesaj kartta duruyor, iş düşmez)"
  rm -f "$f"
}

# 🔴 CANLI SINIFI (retro 17 Eki 2026 · ders 1): cron · servis · sunucu içeren iş, "git'te düzeltildi" ile bitmez — kanıtı
#    İLK GERÇEK ATEŞLEME kaydıdır (kanit.sh canli). Kart açılırken ARAÇ karar verir: --canli e|h verilmişse o; verilmemişse
#    cümledeki anahtar kelimelerden türetir ve sebebini karta yazar. Sahibin "h" demesi gizli kalmaz: karta ve ekrana yazılır,
#    bağımsız göz görür. Kapı (birlestirme-kapisi.sh 2b) bu alanı `kart.sh canli-gerekir` ile okur; alanı olmayan ESKİ kart
#    da cümleden türetilir — eski cron kartı kapsam dışı kalmaz.
# 🔴 GÖZ #353 tur 3: çıplak alt dize 'ghost' içindeki 'host'u yakalıyordu → kelime BAŞI sınırı (\b); Türkçe ek serbest (Sunucuda → sunucu)
# yedek göz #354: 'hosting' · 'zilli' gibi İngilizce/yabancı ekler sayılmasın → kelime SONU da sınır; yalnız Türkçe çekim ekleri serbest
CANLI_KELIME="\\b(?:cron|crontab|servis|service|systemd|daemon|timer|sunucu|host|ssh|zil|nöbet|nobet|bekçi|bekci|watcher|canlı|canli)(?:['’]?(?:lar|ler)?(?:[ıiuü]|[ıi]n|n[ıiuü]n|y[aeıiuü]|d[ae]|t[ae]|nd[ae]|d[ae]ki|t[ae]ki|nd[ae]ki|d[ae]n|t[ae]n|nd[ae]n|s[ıiuü]|y[ıi]|l[ae]r[ıi])?)?\\b"
canli_hesapla() {  # canli_hesapla <cümle> <--canli cevabı e|h|""> → "E|H<TAB>sebep"
  python3 - "$1" "$2" "$CANLI_KELIME" <<'PY'
import re,sys
cumle,cevap,kelime=sys.argv[1:]
hits=sorted(set(m.lower() for m in re.findall(kelime,cumle,re.I)))
if cevap=="e": print("E\t--canli e")
elif cevap=="h": print("H\t--canli h (sahip: canlı kanıt gerekmez dedi"+(f"; cümlede: {', '.join(hits)}" if hits else "")+")")
else: print(("E\tcümlede: "+", ".join(hits)) if hits else "H\t")
PY
}

# 🟡 KAPSAM UYARISI (retro W42 ders M2 · gorev_01M57ZWR2TENPTZJVKRM9VAXCQ): kart kapsamı teslim birimiyle uyuşmayınca iş tıkanıyor —
#    iki depoya yayılan, yanlış depoda açılan, haftalık yazılıp günlük teslim edilen kartlar (W42'de beş kart). Kart açılırken ARAÇ
#    cümleye bakar ve UYARIR (red değil — kart açılır): (1) cümle iki depo adı anıyorsa → depo başına kart, (2) haftalık/çok günlük
#    kapsam → gün başına kart. Tek depo adı (başka depo olsa da) uyarı ALMAZ: kart cümlesi yalnız bu ikisini istedi (göz #384 tur 1).
#    Uyarılar karta da yazılır
#    (`kapsam_uyarilari`), bağımsız göz görür. Depo adları TAM yazımıyla, büyük-küçük harf duyarlı aranır (FABRIKA_DEPOLAR ile
#    değişir; "ad:takma" biçimi, ör. "Sx-Claude-Skills:Sx"). /config/projects dizin adları KULLANILMAZ: sohbet · ocak · sedir gibi
#    adlar sıradan kelimedir ve her cümlede yanlış alarm verirdi. Dürüst sınır: depo adı geçmeyen iki depolu iş (yalnız dosya yolu
#    ya da araç adı anan cümle) yakalanmaz — W42'nin beş kartından dördü böyleydi.
DEPOLAR="${FABRIKA_DEPOLAR:-Nexus cloudtop Sx-Claude-Skills:Sx MMEpanel MMEx}"
kapsam_uyar() {  # kapsam_uyar <iş> <cümle> <bu depo adı> → her satır bir uyarı (boş = uyarı yok)
  python3 - "$1" "$2" "$3" "$DEPOLAR" <<'PY'
import re, sys
is_, cumle, bu, depolar = sys.argv[1:]
tablo = {}
for d in depolar.split():
    ad, _, takma = d.partition(":")
    tablo[ad] = [ad] + [t for t in takma.split(",") if t]
def aniliyor(adlar):
    return any(re.search(r"(?<![\w-])" + re.escape(a) + r"(?![\w-])", cumle) for a in adlar)
anilan = sorted(ad for ad, adlar in tablo.items() if aniliyor(adlar))
if len(anilan) >= 2:
    print("İKİ DEPO: cümle %s anıyor — iş birden çok depoya yayılıyorsa depo başına kart aç (her depoda kendi kartı, kendi PR'ı): %s" % (
        " + ".join(anilan), " · ".join("kart.sh ac %s-%s …" % (is_, a.split("-")[0].lower()) for a in anilan)))
HAFTA = r"(?<!\w)(?:haftal[ıi]k\w*|hafta(?:s[ıi]|n[ıi]n|da|y[ıi])?|W\d{2}|\d+\.\s*hafta|[2-9]\s*g[üu]n(?:l[üu]k)?|her\s+g[üu]n|t[üu]m\s+hafta)(?!\w)"
h = sorted(set(m.group(0) for m in re.finditer(HAFTA, cumle, re.I)))
if h:
    print("ÇOK GÜNLÜK KAPSAM (%s): bir PR'da teslim edilmez — gün başına kart öner: %s-g1 · %s-g2 … (her biri günün teslim birimi)" % (", ".join(h), is_, is_))
PY
}

case "$CMD" in
  ac)
    [ -n "$IS" ] && [ -n "$IS_C" ] && [ -n "$ISTEDI" ] && [ -n "$ALDI" ] || { _hata "gerekli: <iş> --is --istedi --aldi"; exit 1; }
    for v in GA PARA DIS YETKI; do case "${!v}" in e|h|\?) ;; *) _hata "dört sınıf sorusu cevapsız kart AÇILMAZ: --geri-alinamaz --para --dis-yuzey --yetki (e|h|?)"; exit 1 ;; esac; done
    case "$CANLI" in ""|e|h) ;; *) _hata "--canli yalnız e|h olabilir ('$CANLI' değil): cron/servis/sunucu işi canlı kanıt ister mi?"; exit 1 ;; esac
    [ -f "$KD/$IS.json" ] && { _hata "kart zaten var: $IS (goster ile bak)"; exit 1; }
    IFS=$'\t' read -r CG CSEBEP <<<"$(canli_hesapla "$IS_C" "$CANLI")"; CSEBEP="${CSEBEP:-}"
    KUYARI="$(kapsam_uyar "$IS" "$IS_C" "$(basename "$DEPO")")" || { _hata "kapsam uyarısı ölçülemedi"; KUYARI="ÖLÇÜLEMEDİ: kapsam uyarısı aracı düştü"; }
    python3 - "$KD/$IS.json" "$IS" "$IS_C" "$ISTEDI" "$ALDI" "$GA" "$PARA" "$DIS" "$YETKI" "$KANIT" "$ODA" "$CG" "$CSEBEP" "$KUYARI" <<'PY'
import json,sys,datetime
yol,is_,cumle,istedi,aldi,ga,para,dis,yetki,kanit,oda,cg,csebep,kuyari=sys.argv[1:]
cev={"geri_alinamaz":ga,"para":para,"dis_yuzey":dis,"yetki":yetki}
siniflar=[k for k,v in cev.items() if v in("e","?")]
kart={"is":is_,"cumle":cumle,"istedi":istedi,"aldi":aldi,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
      "sinif_cevaplari":cev,"siniflar":siniflar,"sultan":bool(siniflar),"kanit_nerede":kanit,"oda":oda,"durum":"acik","gecmis":[],
      "canli_gerekir":cg=="E","canli_sebep":csebep,"kapsam_uyarilari":[u for u in kuyari.splitlines() if u.strip()]}
json.dump(kart,open(yol,"w"),ensure_ascii=False,indent=2)
print(f"✓ kart açıldı: {is_} · sınıf: {', '.join(siniflar) if siniflar else 'yok'} · {'SULTAN\'A GİDER' if siniflar else 'ekipte biter, gün sonu özetine girer'}")
for u in kart["kapsam_uyarilari"]: print(f"  ⚠ KAPSAM — {u} (uyarı, red değil; karta yazıldı)")
if cg=="E": print(f"  · CANLI kanıt zorunlu ({csebep}): gerçek ateşleme kaydı (kanit.sh canli) olmadan birleştirme kapısı geçmez")
elif csebep: print(f"  ⚠ canlı kanıt istenmedi — {csebep}; karta yazıldı, bağımsız göz görür")
PY
    tetik "$ODA" "iş alındı: $IS" "$IS_C · sahip $ALDI · istedi $ISTEDI · sınıf: ${GA}${PARA}${DIS}${YETKI}"
    ;;
  bitti|tikandi)
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    [ "$CMD" = "tikandi" ] && { [ -n "$YOL" ] && [ -n "$NEDEN" ] || { _hata "tikandi --yol devam|daralt|geri-al --neden gerekiyor"; exit 1; }; }
    # kanıt/denetim: çağrıldığı ağaçtan (worktree olabilir) okunur
    WT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEPO")"; DZ="$WT/_agents/fabrika/kanit/$IS"
    # 🔴 GÖZ #353 tur 3: eski kart (alan yok) kapıda cümleden "canlı ister" sayılıyor ama bitti uyarmıyordu → aynı yüzeyden (canli-gerekir) okunur
    # yedek göz #354: fail-open değil — okunamazsa '?' olur ve bitti bunu uyarı olarak basar (kapı aynı durumda rc=3)
    IFS=$'\t' read -r CGB _ <<<"$(bash "${BASH_SOURCE[0]}" canli-gerekir "$IS" 2>&1)"; case "$CGB" in E|H) ;; *) CGB="?" ;; esac
    python3 - "$KD/$IS.json" "$CMD" "$PR" "$YOL" "$NEDEN" "$DZ" "$CGB" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY'
import json,sys,os,glob,datetime
yol,cmd,pr,yolu,neden,dz,cgb,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from kanit import etkin_kayitlar   # 4K938: etkin renk tek yerden
k=json.load(open(yol)); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
den=sorted(glob.glob(os.path.join(dz,"DENETIM-[0-9]*.json")),key=lambda p:int(p.rsplit("-",1)[1].split(".")[0]))
son=json.load(open(den[-1]))["sonuc"] if den else None
kanit=os.path.exists(os.path.join(dz,"KANIT.json"))
canli=[x for x in (etkin_kayitlar(json.load(open(os.path.join(dz,"KANIT.json")))) if kanit else []) if x.get("tur")=="canli"]
cy=sum(1 for x in canli if x["etkin_renk"]=="yesil")
k["canli_kanit"]="var" if cy else ("sari" if canli else "yok")
k["durum"]=cmd; k["bitis"]=simdi; k["pr"]=pr or k.get("pr","")
k["puan"]={"kod":son["kod_puani"],"dogru":son["dogru_sey"],"tur":len(den)} if son else None
k["kanit_var"]=kanit
if cmd=="tikandi": k["tikanma"]={"yol":yolu,"neden":neden}
k["gecmis"].append({"zaman":simdi,"olay":cmd})
json.dump(k,open(yol,"w"),ensure_ascii=False,indent=2)
uyari=""
if cmd=="bitti" and not kanit: uyari=" ⚠ KANIT YOK (kanıtsız bitti sayılmaz — gün sonu özetinde işaretlenir)"
if cmd=="bitti" and son and not(son["kod_puani"]==5 and son["dogru_sey"]=="E"): uyari+=" ⚠ son denetim 5+E DEĞİL"
if cmd=="bitti" and cgb=="?": uyari+=" ⚠ kartın canlı şartı OKUNAMADI (kart.sh canli-gerekir) — kapı bunu ÖLÇÜLEMEDİ sayar"
if cmd=="bitti" and cgb=="E" and not cy: uyari+=" ⚠ CANLI KANIT YOK (cron/servis/sunucu işi gerçek ateşleme kaydı ister: kanit.sh canli)"
print(f"✓ kart {cmd}: {k['is']} · puan {k['puan']} · kanıt {'var' if kanit else 'YOK'}{uyari}")
PY
    tetik "$(python3 -c "import json;print(json.load(open('$KD/$IS.json')).get('oda',''))")" "iş $CMD: $IS" "$(python3 -c "import json;k=json.load(open('$KD/$IS.json'));print(k['cumle'],'· puan',k.get('puan'),'· pr',k.get('pr'))")"
    ;;
  sultan-dedi)
    # 🔴 Sultan'ın sözlü kararı KARTA girer, komut satırında kalmaz. Niçin: bir yetki kapısını
    #    serbest bir metinle açmak, kapıyı hiç koymamakla neredeyse aynıdır (bağımsız göz,
    #    23 Eyl: "komutu çalıştırabilen herkes 20 karakterlik herhangi bir metinle açabiliyor").
    #    Karta yazmak da uydurmayı imkânsız kılmaz — ama uydurmayı KAYITLI, yapılandırılmış ve
    #    sonradan denetlenebilir bir yalan hâline getirir. A06'nın verebileceği en güçlü şey budur.
    [ -n "$IS" ] || { _hata "iş adı gerekiyor"; exit 1; }
    [ -f "$KD/$IS.json" ] || { _hata "kart YOK: $KD/$IS.json"; exit 1; }
    eksik=""
    [ -n "$KARAR" ] || eksik="$eksik --karar"
    [ -n "$OTURUM" ] || eksik="$eksik --oturum"
    [ -n "$SOZ" ] || eksik="$eksik --soz"
    [ -n "$BEYAN" ] || eksik="$eksik --beyan"
    [ -n "$GEREKCE" ] || eksik="$eksik --gerekce"
    [ -z "$eksik" ] || { _hata "eksik:$eksik — ref'siz, kırpıksız ya da GEREKÇESİZ beyan SAYILMAZ (D1 deseni)"; exit 1; }
    # 🔴 Gerekçe ayrı bir alandır ve Sultan'ın sözünün yerine GEÇMEZ. Tıkanma raporu şunu ister:
    #    "DEVAM — gerekçeyle: neden bir tur daha işe yarar?" Yani iki ayrı şey kayda geçer:
    #    (a) Sultan ne dedi (verbatim, kısa)  (b) bu yolun niçin işe yarayacağı (muhakeme).
    #    İkisini birleştirmek, "devam" sözcüğünü gerekçe saymak olurdu — bağımsız göz 23 Eyl tur 2.
    [ "${#GEREKCE}" -ge 20 ] || { _hata "--gerekce en az 20 karakter — 'devam' bir gerekçe değildir"; exit 1; }
    # 🔴 DEFTER AYRAÇ GÜVENLİĞİ (bağımsız göz 23 Eyl tur 3): bu alanlar sonradan "|" ayrımlı bir
    #    kayıt satırına yazılıyor. İçinde "|" ya da satır sonu olan bir değer, gün sonu özetinde
    #    sütunları kaydırır ya da SAHTE bir ek kayıt gibi görünür. Denetim defterine kendi eliyle
    #    satır ekleyebilen bir alan, denetim defteri değildir. Kaynağında reddediyoruz.
    # ⚠ İlk denememde satır-sonu desenini `*"$(printf '\n')"*` ile yazdım: komut ikamesi sondaki
    #   satır sonunu yuttuğu için desen boş dizgeye dönüştü ve HER değeri reddetti. Sınav yakaladı.
    for v in KARAR OTURUM SOZ BEYAN GEREKCE; do
      d="${!v}"
      if [[ "$d" == *"|"* || "$d" == *$'\n'* ]]; then
        _hata "--$(printf '%s' "$v" | tr 'A-Z' 'a-z') içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1
      fi
    done
    python3 - "$KD/$IS.json" "$KARAR" "$OTURUM" "$SOZ" "$BEYAN" "$GEREKCE" <<'PY' || exit 1
import json,sys,datetime
yol,karar,oturum,soz,beyan,gerekce=sys.argv[1:]
k=json.load(open(yol,encoding="utf-8"))
k.setdefault("sultan_kararlari",[]).append({
  "karar":karar,"oturum":oturum,"soz":soz,"beyan":beyan,"gerekce":gerekce,
  "zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds")})
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"\u2713 Sultan karari karta islendi: {karar} \u00b7 oturum {oturum} \u00b7 beyan {beyan}")
PY
    ;;
  reis-dedi)
    # 🔴 SAHİP/REİS KARARI (8 Eki 2026 · A268): hat "sınıfsız işin kararı sahibinin/reisin" diyordu ama araç
    #    yalnız Sultan'ın kararını okuyordu. Sonuç: sınıfsız bir işin sahibi kendi yetkisindeki kararı yazdıramıyor,
    #    kapı ya kapalı kalıyor ya da birisi Sultan'ın ağzından yazmaya özeniyor (A06). Aynı gün iki vaka
    #    (DEVRİYE doğrulayıcısı · kokpit A2). Karar AYRI alana girer (reis_kararlari) — Sultan'ın alanına değil —
    #    ve YALNIZ sınıfsız kartta kabul edilir: sınıf işinin tek karar mercii Sultan'dır, bu yol onu AÇMAZ.
    [ -n "$IS" ] || { _hata "iş adı gerekiyor"; exit 1; }
    [ -f "$KD/$IS.json" ] || { _hata "kart YOK: $KD/$IS.json"; exit 1; }
    eksik=""
    [ -n "$KARAR" ] || eksik="$eksik --karar"
    [ -n "$REIS" ] || eksik="$eksik --reis"
    [ -n "$OTURUM" ] || eksik="$eksik --oturum"
    [ -n "$GEREKCE" ] || eksik="$eksik --gerekce"
    [ -z "$eksik" ] || { _hata "eksik:$eksik — adsız, ref'siz ya da GEREKÇESİZ reis kararı SAYILMAZ"; exit 1; }
    [ "${#GEREKCE}" -ge 20 ] || { _hata "--gerekce en az 20 karakter — 'devam' bir gerekçe değildir"; exit 1; }
    # 🔴 (bağımsız göz 8 Eki tur 1) karar kapalı kümedir; araç tanımadığı bir kararı karta YAZMAZ
    case "$KARAR" in devam|daralt|geri-al) ;; *) _hata "--karar yalnız devam|daralt|geri-al olabilir ('$KARAR' değil)"; exit 1 ;; esac
    for v in KARAR REIS OTURUM GEREKCE; do
      d="${!v}"
      if [[ "$d" == *"|"* || "$d" == *$'\n'* ]]; then
        _hata "--$(printf '%s' "$v" | tr 'A-Z' 'a-z') içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1
      fi
    done
    python3 - "$KD/$IS.json" "$KARAR" "$REIS" "$OTURUM" "$GEREKCE" <<'PY' || exit 1
import json,sys,datetime
yol,karar,reis,oturum,gerekce=sys.argv[1:]
k=json.load(open(yol,encoding="utf-8"))
# 🔴 (bağımsız göz 8 Eki tur 1) kararı veren, KARTTA yazılı iş sahibi (aldi) olmalı — araç kimlik doğrulayamaz,
#    ama en azından karta yazılı sahipten başka bir adı kabul etmez. Başka bir reisin kararı (ör. SERDAR'ın MUAVİN'in
#    işine "devam" demesi) mektupla gelir; sahip kendi adıyla işler ve gerekçede o mektuba atıf yapar.
if reis != k.get("aldi"):
    print(f"\u2717 --reis '{reis}' kartın sahibi değil (kartta aldi: {k.get('aldi')}) — sahip kendi adıyla işler, başkasının kararına gerekçede atıf yapar", file=sys.stderr); raise SystemExit(1)
if k.get("sultan") or k.get("siniflar"):
    print(f"\u2717 kart SINIFLI ({', '.join(k.get('siniflar') or ['?'])}) — sınıf işinin kararı SULTAN'ındır; reis kararı bu kartı AÇAMAZ (kart.sh sultan-dedi)", file=sys.stderr); raise SystemExit(1)
k.setdefault("reis_kararlari",[]).append({
  "karar":karar,"reis":reis,"oturum":oturum,"gerekce":gerekce,
  "zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds")})
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"\u2713 reis karari karta islendi: {karar} \u00b7 reis {reis} \u00b7 oturum {oturum} (sinifsiz is)")
PY
    ;;
  daralt)
    # 🔴 DARALTMA ADIMI (PCP7J, 18 Eki 2026): tıkanma raporu "kapsamı daralt" diyordu ama hatta adımı yoktu —
    #    daralt kararı verilen iş (cloudtop #668) tur açamadı, 4. tur mutlak dolan iş (#670) bir daha denetlenemedi,
    #    kapı reis kararını hiç okumadı. Geçici yol "yeni kart + yeni dal + yeni PR" Sultan'a günde ~30 karar yüklüyordu.
    #    Şimdi: cümle daraltılır, kalan bulgu yeni karta, karta daraltma kaydı; denetçi daraltmadan ÖNCEKİ turları saymaz.
    [ -n "$IS" ] || { _hata "iş adı gerekiyor"; exit 1; }
    [ -f "$KD/$IS.json" ] || { _hata "kart YOK: $KD/$IS.json"; exit 1; }
    eksik=""
    [ -n "$KALAN" ] || eksik="$eksik --kalan"
    [ -n "$CUMLE" ] || eksik="$eksik --cumle"
    [ -n "$OTURUM" ] || eksik="$eksik --oturum"
    [ -z "$eksik" ] || { _hata "eksik:$eksik — kalan bulgu, daraltılmış cümle ve oturum ref'i olmadan daraltma SAYILMAZ"; exit 1; }
    [ "${#KALAN}" -ge 20 ] || { _hata "--kalan en az 20 karakter — kalan bulgu bir cümledir, etiket değil"; exit 1; }
    [ "${#CUMLE}" -ge 20 ] || { _hata "--cumle en az 20 karakter — daraltılmış cümle yine bir iş cümlesidir"; exit 1; }
    for v in KALAN CUMLE OTURUM YENI; do d="${!v}"; if [[ "$d" == *"|"* || "$d" == *$'\n'* ]]; then _hata "--$(printf '%s' "$v" | tr 'A-Z' 'a-z') içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1; fi; done
    YENI="${YENI:-$IS-kalan}"
    # 🔴 (bağımsız göz tur 1) kart adı dosya adıdır: yol ayracı, '..' ya da boşluk kabul edilirse kart dizini DIŞINA yazılır
    case "$YENI" in ''|*/*|*..*|.*|*[!a-zA-Z0-9_-]*) _hata "--yeni geçersiz kart adı: '$YENI' (yalnız harf/rakam/-/_, yol ayracı ve '..' yok)"; exit 1 ;; esac
    [ -f "$KD/$YENI.json" ] && { _hata "kalan kart zaten var: $YENI (--yeni ile başka ad ver)"; exit 1; }
    # tur_sifir: çağrıldığı ağaçtaki (worktree) denetim sayısı — daraltmadan önceki turlar yeni cümleyi puanlamadı
    WT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEPO")"; DZ="$WT/_agents/fabrika/kanit/$IS"
    TS=$(ls "$DZ"/DENETIM-[0-9]*.json 2>/dev/null | wc -l)
    python3 - "$KD/$IS.json" "$KD/$YENI.json" "$YENI" "$KALAN" "$CUMLE" "$OTURUM" "$TS" <<'PY' || exit 1
import json,sys,datetime
yol,yyol,yeni,kalan,cumle,oturum,ts=sys.argv[1:]
k=json.load(open(yol,encoding="utf-8")); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
if k.get("durum") not in ("acik","tikandi"):
    print(f"✗ kart durumu '{k.get('durum')}' — yalnız açık ya da tıkanmış kart daraltılır", file=sys.stderr); raise SystemExit(1)
if k.get("sultan") or k.get("siniflar"):
    # sınıf işinin kararı Sultan'ındır: karta işlenmiş, HENÜZ KULLANILMAMIŞ 'daralt' kararı yoksa araç daraltmaz (A06).
    # 🔴 (bağımsız göz tur 1) karar TEK KULLANIMLIKTIR: bir daraltma bir karar tüketir; eski bir 'daralt' sözü
    #    sonraki daraltmaları yetkilendiremez — her daraltma için Sultan'ın güncel kararı gerekir.
    acik=[x for x in (k.get("sultan_kararlari") or []) if x.get("karar")=="daralt" and not x.get("kullanildi")]
    if not acik:
        print(f"✗ kart SINIFLI ({', '.join(k.get('siniflar') or ['?'])}) ve karta işlenmiş KULLANILMAMIŞ Sultan 'daralt' kararı YOK — her daraltma için yeni kart.sh sultan-dedi --karar daralt", file=sys.stderr); raise SystemExit(1)
    acik[0]["kullanildi"]={"zaman":simdi,"kalan_kart":yeni}
else:
    k.setdefault("reis_kararlari",[]).append({"karar":"daralt","reis":k.get("aldi"),"oturum":oturum,
        "gerekce":f"daraltma: kalan bulgu yeni karta ({yeni}) — {kalan}","zaman":simdi})
k.setdefault("cumle_gecmisi",[]).append({"cumle":k["cumle"],"zaman":simdi,"kalan_kart":yeni})
k["cumle"]=cumle
k.setdefault("daraltmalar",[]).append({"zaman":simdi,"kalan_kart":yeni,"kalan":kalan,"tur_sifir":int(ts),"oturum":oturum})
if k.get("durum")=="tikandi": k["durum"]="acik"
k["gecmis"].append({"zaman":simdi,"olay":"daralt","kalan_kart":yeni,"tur_sifir":int(ts)})
y={"is":yeni,"cumle":kalan,"istedi":k.get("istedi"),"aldi":k.get("aldi"),"zaman":simdi,
   "sinif_cevaplari":k.get("sinif_cevaplari"),"siniflar":k.get("siniflar") or [],"sultan":bool(k.get("siniflar")),
   "kanit_nerede":k.get("kanit_nerede",""),"oda":k.get("oda",""),"durum":"acik","gecmis":[{"zaman":simdi,"olay":"daraltmadan dogdu","koken":k["is"]}],
   "canli_gerekir":k.get("canli_gerekir",False),"canli_sebep":k.get("canli_sebep",""),"koken":k["is"]}
# 🔴 (bağımsız göz tur 1) iki kart ATOMİK yazılır: önce yeni kart geçici dosyaya + yerine koyma, sonra ana kart;
#    ana kart yazılamazsa yeni kart geri alınır → "daraltılmış ana kart, kalan kart yok" hâli oluşmaz.
import os
# (göz tur 2) iki dosya tek bir atomik işlemle değiştirilemez (POSIX'te çift rename yok). Yapılan: ÖNCE iki geçici
# dosya da tamamen yazılır (serileştirme/disk hatası burada yakalanır, hiçbir kart değişmez), SONRA iki rename art
# arda; ikinci rename düşerse kalan kart geri alınır. Kalan pencere yalnız iki rename ARASINDA süreç ölmesidir
# (mikrosaniye); o hâlde kalan kart `koken` alanıyla ayakta kalır, ana kart eski cümlesiyle durur — veri kaybı yok,
# yetim kalan kart `kart.sh liste`de görünür ve daralt yeniden koşulunca "kalan kart zaten var" der (--yeni ile sürer).
gy, ga = yyol+".tmp", yol+".tmp"
try:
    with open(gy,"w",encoding="utf-8") as f: json.dump(y,f,ensure_ascii=False,indent=2)
    with open(ga,"w",encoding="utf-8") as f: json.dump(k,f,ensure_ascii=False,indent=2)
except Exception as e:
    for g in (gy,ga):
        try: os.remove(g)
        except Exception: pass
    print(f"✗ kartlar hazırlanamadı ({e}) — hiçbir kart DEĞİŞMEDİ", file=sys.stderr); raise SystemExit(1)
try:
    os.replace(gy,yyol)
except Exception as e:
    for g in (gy,ga):
        try: os.remove(g)
        except Exception: pass
    print(f"✗ kalan kart yerine konamadı ({e}) — ana kart DOKUNULMADI", file=sys.stderr); raise SystemExit(1)
try:
    os.replace(ga,yol)
except Exception as e:
    for g in (yyol,ga):
        try: os.remove(g)
        except Exception: pass
    print(f"✗ ana kart yerine konamadı ({e}) — kalan kart geri alındı, daraltma OLMADI", file=sys.stderr); raise SystemExit(1)
print(f"✓ kart daraltıldı: {k['is']} (tur sıfırı {ts}) · kalan bulgu yeni karta: {yeni} · {'SINIFLI, Sultan kararıyla' if y['sultan'] else 'sınıfsız, reis kararı işlendi'}")
print("  · denetçi bundan sonra yalnız daraltmadan SONRAKİ turları sayar; kapı daraltma sonrası en az bir 5/E tur ister")
PY
    ;;
  canli-gerekir)
    # Kapının okuduğu tek yüzey. Alanı olmayan ESKİ kartta cümleden türetir — eski cron kartı kapsam dışı kalmaz.
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    durum="$(python3 -c 'import json,sys;k=json.load(open(sys.argv[1],encoding="utf-8"));cg=k.get("canli_gerekir");print(("yok" if cg is None else ("E" if cg else "H"))+"\t"+(k.get("canli_sebep") or "").replace("\n"," ").replace("\t"," "))' "$KD/$IS.json")"
    IFS=$'\t' read -r cg sebep <<<"$durum"; sebep="${sebep:-}"
    if [ "$cg" = "yok" ]; then
      cumle="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8")).get("cumle",""))' "$KD/$IS.json")"
      IFS=$'\t' read -r cg sebep <<<"$(canli_hesapla "$cumle" "")"; sebep="eski kart · ${sebep:-cümlede anahtar yok}"
    fi
    printf '%s\t%s\n' "$cg" "$sebep" ;;
  goster) [ -f "$KD/$IS.json" ] && cat "$KD/$IS.json" || { _hata "kart yok: $IS"; exit 3; } ;;
  liste)
    ls "$KD"/*.json >/dev/null 2>&1 || { echo "◻ kart yok"; exit 0; }
    python3 - "$KD" "${ACIK:-0}" <<'PY'
import json,sys,glob,os
kd,acik=sys.argv[1],sys.argv[2]=="1"
for p in sorted(glob.glob(os.path.join(kd,"*.json"))):
    k=json.load(open(p))
    if acik and k["durum"]!="acik": continue
    print(f"{k['durum']:8} {k['is']:30} {'SULTAN' if k['sultan'] else 'ekip  '} {k['aldi']:10} {k['zaman'][:16]}  {k['cumle'][:60]}")
PY
    ;;
  *) sed -n '1,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
