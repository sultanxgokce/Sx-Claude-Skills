#!/usr/bin/env bash
# kart.sh — fabrika 0. adım (KABUL): iş kartını ARAÇ yazar; sınıfı dört soruyla ARAÇ sorar (K6).
#
# Kartlar BİRİNCİL depo kökünde yaşar: <depo>/_agents/fabrika/kartlar/<iş>.json (worktree'ler ortak görür).
# Dört sınıf sorusu cevapsız kart AÇILMAZ. Biri "e" ya da "?" ise → sultan=true (şüphede sınıf YUKARI).
#
# 🔴 KURAL 0.21.0: adimlar/0-kabul.md "Sınıflı iş" (başlama izni Sultan'ın, kararlar reisin; izin tek yüzey: izin-durum).
#
# Kullanım:
#   kart.sh ac <iş> --is "tek cümle" --istedi <kim> --aldi <ajan> \
#          --geri-alinamaz e|h|? --para e|h|? --dis-yuzey e|h|? --yetki e|h|? [--kanit "nerede olacak"] [--oda <oda>] [--canli e|h] [--senaryo <dosya>] [--kare-onay "<D1>"]
#          --canli: cron/servis/sunucu işi gerçek ateşleme kaydı (kanit.sh canli) ister; verilmezse cümleden türetilir, karta yazılır
#          [--sayi-olcum '<komut>']: cümlede "13 görev" gibi bir sayı iddiası varsa onu KAYNAĞINDAN sayan komut (yoksa UYARI, red değil)
#   kart.sh goz-adim <iş> --not "<satır>"   (0.24.0) göz turunu göreve TEK adım yazar, durum değişmez (denetçi kendisi çağırır)
#   kart.sh bitti <iş> [--pr N]        durum=bitti; son DENETIM puanını ve KANIT durumunu karta işler (kanıt: çağrıldığı ağaç, yoksa kartın iş alanı — kanit_agaci)
#          sınıflıda birlestirme_karari yazar; VETOLU kartta rc 1
#   kart.sh tikandi <iş> --yol devam|daralt|geri-al --neden "..."
#   kart.sh daralt <iş> --kalan "<kalan bulgu ≥20>" --cumle "<daraltılmış cümle ≥20>" --oturum <ref> [--yeni <ad>]
#     → kart cümlesi daraltılır (eskisi cumle_gecmisi'ne), kalan bulgu YENİ karta (aynı sınıf cevapları, aynı sahip),
#       karta daraltma kaydı (tur_sifir = kanıt ağacındaki denetim turu → denetçi yeni cümleyle sıfırdan sayar, kapı onu okur).
#       Her kartta reis kararıyla (sınıflıda sinifli:true; eski Sultan 'daralt' tüketilir); VETOLU kartta rc 1.
#   kart.sh sultan-dedi <iş> --karar <devam|daralt|geri-al|canli-borc|basla|dur> --oturum <ref> --soz "<verbatim ≤15 kelime>" \
#          --beyan <AJAN> [--gerekce "<≥20 karakter>"] (basla|dur dışında zorunlu); dur = VETO
#   kart.sh reis-dedi <iş> --karar <devam|daralt|geri-al|birlestir> --reis <AD> --oturum <ref> \
#          --gerekce "<niçin — en az 20 karakter>"     ← her kartta; VETOLU kartta rc 1
#          Sultan'ın SÖZLÜ kararını KARTA işler (D1 deseni). Üç parça zorunlu: oturum-ref · kırpık · beyan.
#          🔴 A06: onay ÜRETMEZ, alınan onayı AKTARIR. Ref'siz beyan sayılmaz; uyduran kartta yakalanır.
#   kart.sh canli-borc <iş> --yazan <AD> --gerekce "<niçin canlı kayıt şimdi üretilemiyor — en az 20 karakter>"
#          CANLI BORÇ (5WYQMW · SERDAR 22 Eki 00:43): kart --canli e ve gerçek ateşleme kaydı HENÜZ üretilemiyorsa (dağıtım birleşmeden SONRA ya da
#          başkasında) birleştirme kapısı borç kaydıyla geçer; kart `bitti` DEĞİL `canli-borclu` olur; borç dağıtımdan sonra `kanit.sh canli` ile ödenir,
#          sonra `kart.sh bitti` kartı kapatır. SINIFSIZ kartta yazan kartın sahibidir (aldi); SINIFLI kartta borcu AJAN yazamaz: önce
#          `kart.sh sultan-dedi <iş> --karar canli-borc …` (Sultan'ın sözü, D1 deseni). 24 saat ödenmezse `kart.sh borclar` kırmızı (rc 1).
#   kart.sh canli-borc-durum <iş> → "yok|gecerli|gecersiz|odendi<TAB>açıklama" (kapının okuduğu yüzey) · kart.sh borclar → açık borçlar, yaşı
#   kart.sh sor <iş> --kime <AD> --eylem "<geri alınamaz eylem ≥5>" --soru "<soru ≥20>"   CEVAP BEKLE (gorev_…CMWNK): eylemi soruya bağlar
#   kart.sh cevap <iş> --no N --kim <sorulan> --karar evet|hayir --oturum <ref> --soz "<sorulanın sözü, birebir>"
#   kart.sh cevap-bekle <iş> → "yok|evet|acik|hayir<TAB>…"; rc 0 yok/evet · 3 açık · 4 hayır  (kart.sh cevap-bekle X && <eylem>)
#   kart.sh acik-soru <AJAN|'*'> → ajanın (ya da '*' = depodaki HERKESİN) kartlarındaki cevapsız sorular; rc 0 yok · 3 var · 2 okunamayan kart (ÖLÇÜLEMEDİ) · cevapsız soru varken kart.sh bitti REDDEDER
#   kart.sh izin-durum <iş> → "gerekmiyor|bekliyor|basla|dur<TAB>açıklama" (kart yok/bozuk rc 3 — fail-closed)
#   kart.sh goster <iş> · kart.sh liste [--acik] · kart.sh canli-gerekir <iş>  → "E|H<TAB>sebep" (eski kartta cümleden türetir)
#   kart.sh canli-ayarla <iş> --canli e|h --reis <AD=aldi> --gerekce "<≥20 karakter>"   AÇIK kartta canlı kanıt şartını SAHİP değiştirir:
#          --reis kartın aldı alanıyla aynı olmalı (reis-dedi emsali; başkasının kararı gerekçede atıfla); karta canli_sebep + geçmiş satırı yazılır
#   kart.sh sultan-turu <iş> --reis <AD=aldi> --gorev gorev_<kimlik> --tur <N>   BEĞENİ DÖNGÜSÜ: Sultan'ın N. "değiştir" turunu kaydeder, göz tavanı sayacını o ana çeker
#          (daralt'ın tur_sifir'i ile aynı mekanizma; yeni kart yok). Şartlar araçta: görev etiketi 'begeni-dongusu' (defterden) · görevde
#          [tur N] kare: <yol/url> · Sultan: "<yorum>" satırı · reis = kart sahibi · defter okunamazsa hiçbir şey değişmez. Mutlak 4. tavan kalkmaz.
# Ortam: FABRIKA_TETIK (oda-tetik.sh yolu; --oda verilirse tetik atılır, düşerse iş düşmez) · KANIT_DEPO
#   --gorev gorev_<kimlik> --tahmin <dk> (ac): kart defterdeki göreve bağlanır → açılış 'çalışılıyor' + atanan, bitti → göreve DİLİM adımı (durum kalır);
#          görev de bitecekse kart.sh bitti … --gorev-bitti --kare <yol> --surum <sürüm> | --olcum "…" | --belge <yol> → 'onay bekliyor' + kanıt sınıfı (KF22R)
#          + kanıt, tıkandı 'bekliyor' + not (kutunun defter jetonuyla; DEFTER_JETON_YOL · DEFTER_UC). Bağsız kart bunu söyler.
# rc: 0 · 1 kullanım/eksik cevap · 3 ölçülemedi · 4 kart işlendi ama bağlı görev deftere YAZILAMADI (sebep ekranda ve kartta)
set -uo pipefail
_hata() { printf '✗ %s\n' "$*" >&2; }
TETIK="${FABRIKA_TETIK:-/config/projects/Nexus/scripts/oda-tetik.sh}"

birincil_kok() {  # worktree içinden çağrılsa da BİRİNCİL depo kökü
  local c; c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  dirname "$c"
}
DEPO="${KANIT_DEPO:-$(birincil_kok)}"; [ -n "$DEPO" ] || { _hata "depo kökü bulunamadı"; exit 3; }

# 🔴 KANIT AĞACI (Nexus #1223, 22 Eki 2026): bitti/daralt BİRİNCİL checkout'tan çağrıldı; kanıt dizini iş alanı
#    dalındaydı → daralt tur_sifir=0 yazdı (olması gereken 3), denetçi eski turları sayıp tur 4'ü "mutlak tavan" gördü;
#    bitti aynı yoldan "KANIT YOK" damgalıyordu (Sx #383). Sessiz 0 YOK: kanıt ÖNCE çağrıldığı ağaçtan; orada kartın
#    kanıt dizini boşsa kartın İŞ ALANINDAN (is-alani.sh'ın dalı iş adı olan worktree'si); o da yoksa uyarı basar.
#    Nereden okuduğunu her hâlde söyler (stderr) — kapı kaydı.
kanit_var_mi() { [ -f "$1/KANIT.json" ] || compgen -G "$1/DENETIM-[0-9]*.json" >/dev/null; }
is_alani_yolu() {  # is_alani_yolu <iş> → dalı <iş> olan worktree'nin kökü (yoksa boş)
  git -C "$DEPO" worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$1" '/^worktree /{w=substr($0,10)} $0=="branch "b{print w; exit}'
}
kanit_agaci() {  # kanit_agaci <iş> → stdout: kanıt dizini · stderr: kaynak notu / uyarı
  local is="$1" wt dz alan adz
  wt="$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEPO")"; dz="$wt/_agents/fabrika/kanit/$is"
  if kanit_var_mi "$dz"; then printf '%s' "$dz"; return 0; fi
  alan="$(is_alani_yolu "$is")"; adz="${alan:+$alan/_agents/fabrika/kanit/$is}"
  if [ -n "$alan" ] && [ "$alan" != "$wt" ] && kanit_var_mi "$adz"; then
    printf '  ↳ kanıt bu ağaçta yok (%s) → kartın iş alanından okundu: %s\n' "$wt" "$alan" >&2
    printf '%s' "$adz"; return 0
  fi
  printf '  ⚠ kanıt dizini ne bu ağaçta (%s) ne kartın iş alanında%s → denetim turu 0, kanıt YOK sayılır (iş alanının İÇİNDEN çağır)\n' "$wt" "${alan:+ ($alan)}" >&2
  printf '%s' "$dz"
}
KD="$DEPO/_agents/fabrika/kartlar"; mkdir -p "$KD"

CMD="${1:-}"; IS="${2:-}"; if [ $# -ge 2 ]; then shift 2; else shift $#; fi   # tek argümanlı komut (liste · borclar) "tanınmayan argüman" olmasın
IS_C=""; ISTEDI=""; ALDI=""; GA=""; PARA=""; DIS=""; YETKI=""; KANIT=""; ODA=""; PR=""; YOL=""; NEDEN=""
KARAR=""; OTURUM=""; SOZ=""; BEYAN=""; GEREKCE=""; REIS=""; CANLI=""; KALAN=""; CUMLE=""; YENI=""; YAZAN=""
KIME=""; SORU=""; EYLEM=""; SNO=""; KIM=""   # cevap bekle (soru.py)
OLCUM_YERI=""; SAYI_OLCUM=""; GOREV_BITTI=""; KARE=""; SURUM=""; OLCUM=""; BELGE=""   # kart bitti: görevi de bitirmek için kanıt sınıfı (KF22R: dilim ≠ görev)
while [ $# -gt 0 ]; do case "$1" in
  --is) IS_C="$2"; shift 2 ;; --istedi) ISTEDI="$2"; shift 2 ;; --aldi) ALDI="$2"; shift 2 ;;
  --geri-alinamaz) GA="$2"; shift 2 ;; --para) PARA="$2"; shift 2 ;; --dis-yuzey) DIS="$2"; shift 2 ;; --yetki) YETKI="$2"; shift 2 ;;
  --kanit) KANIT="$2"; shift 2 ;; --oda) ODA="$2"; shift 2 ;; --pr) PR="$2"; shift 2 ;; --yol) YOL="$2"; shift 2 ;; --neden) NEDEN="$2"; shift 2 ;; --gorev-bitti) GOREV_BITTI=1; shift ;; --kare) KARE="$2"; shift 2 ;; --surum) SURUM="$2"; shift 2 ;; --olcum) OLCUM="$2"; shift 2 ;; --belge) BELGE="$2"; shift 2 ;;
  --karar) KARAR="$2"; shift 2 ;; --oturum) OTURUM="$2"; shift 2 ;; --soz) SOZ="$2"; shift 2 ;; --beyan) BEYAN="$2"; shift 2 ;;
  --gerekce) GEREKCE="$2"; shift 2 ;; --reis) REIS="$2"; shift 2 ;; --canli) CANLI="$2"; shift 2 ;; --yazan) YAZAN="$2"; shift 2 ;;
  --kalan) KALAN="$2"; shift 2 ;; --tur) TUR_N="$2"; shift 2 ;; --cumle) CUMLE="$2"; shift 2 ;; --yeni) YENI="$2"; shift 2 ;;
  --gorev) GOREV="$2"; shift 2 ;; --tahmin) TAHMIN="$2"; shift 2 ;; --sayi-olcum) SAYI_OLCUM="$2"; shift 2 ;; --olcum-yeri) OLCUM_YERI="$2"; shift 2 ;;
  --kime) KIME="$2"; shift 2 ;; --soru) SORU="$2"; shift 2 ;; --eylem) EYLEM="$2"; shift 2 ;; --no) SNO="$2"; shift 2 ;; --kim) KIM="$2"; shift 2 ;; --not) NOT_="$2"; shift 2 ;;
  --senaryo) SENARYO="$2"; shift 2 ;; --kare-onay) KARE_ONAY="$2"; shift 2 ;;
  --acik) ACIK=1; shift ;; *) _hata "tanınmayan argüman: $1"; exit 1 ;; esac; done
SENARYO="${SENARYO:-}"; KARE_ONAY="${KARE_ONAY:-}"   # ekran kapısı (ac): senaryo kartı yolu · Sultan'ın kare onayı D1 damgası
GOREV="${GOREV:-}"; TAHMIN="${TAHMIN:-}"

# 🔴 GÖREV DURUMU (Sultan 20 Eki, gorev_…Y7J3Q "çalışılıyor görünümü güvenilmez"; ölçüm 21 Eki 00:00: koltukların 3'ü çalışıyor,
#    defterde 'çalışılıyor' 0). Kök: ajan işe başlarken/bırakırken deftere yazmıyordu. Her iş zaten bu araçtan geçtiği için yazımı
#    ARAÇ yapar: kart --gorev ile bağlanınca açılış → 'çalışılıyor' + atanan = kartı alan + tahmin · bitti → 'onay bekliyor' + kanıt
#    (PR / kanıt dizini) · tıkandı → 'bekliyor' + not (tıkanma nedeni). Kutunun KENDİ defter jetonuyla yazar (bulgu.sh ile aynı yol;
#    değer argv'ye/çıktıya düşmez). Defter yazamazsa kart YİNE işlenir ama bu söylenir, karta yazılır ve rc 4 döner — sessiz eksik yok.
DEFTER_JY="${DEFTER_JETON_YOL:-/config/defter-jeton}"; DEFTER_U="${DEFTER_UC:-http://cloudtop-defter:8791}"
# 🔴 ONAY KORUMASI (görev …774ZHG · 28 Eki ölçümü: D3 görevi Sultan'ın onay kuyruğundan sessizce düştü): bağlı görev 'onay-bekliyor' ya da 'bitti'
#    iken açılış (ac), başka işe geçiş (gecti) ve tıkanma (tikandi) görevin DURUMUNU yazmaz — yalnız adım düşer. Zincir şuydu: onay bekleyen göreve
#    kart bağlandı → ac 'çalışılıyor' yazdı → kart bitti (dilim, durum yazılmaz) → uzlaştırma açık kartı olmayan 'çalışılıyor'u 'bekliyor'a çekti.
#    Ajan 'onay-bekliyor'u ancak açık --gorev-bitti ile yazar; 'bitti' yalnız insanın (A06). Durum okunamazsa eski davranış (yazım zaten düşerdi).
gorev_durum_oku() {  # gorev_durum_oku <gorev_id> → stdout: "<gorev_durumu> <surum>" ya da boş (okunamadı)
  [ -r "$DEFTER_JY" ] || return 0
  local cfg; cfg="$(mktemp)"; printf 'header = "x-defter-jeton: %s"\n' "$(tr -d '\n' < "$DEFTER_JY")" > "$cfg"
  curl -sS -m 10 --config "$cfg" "$DEFTER_U/kayit/$1" 2>/dev/null | python3 -c 'import sys,json
try: k=json.load(sys.stdin).get("kayit") or {}; print(((k.get("canli") or {}).get("gorev_durumu") or "-") + " " + str(k.get("surum") or ""))
except Exception: pass' 2>/dev/null
  rm -f -- "$cfg"
}
gorev_yaz() {  # gorev_yaz <kart.json> <ac|bitti|tikandi> → rc 0 yazıldı · 4 yazılamadı (karta işlenir)
  local kj="$1" olay="$2" govde cfg cevap rc sonuc MEVCUT="" MSURUM="" oku deneme
  # Okuma ile yazma arasında görev değişirse (Sultan o an onaya aldıysa) eski okumayla durum EZİLMESİN: okunan sürüm yazıma eklenir (defterin
  # iyimser kilidi, 409 surum_catismasi) ve çatışmada BİR kez yeniden okunup gövde yeniden kurulur (göz tur 1 bulgusu, 774ZHG).
  for deneme in 1 2; do
  case "$olay" in ac|gecti|tikandi) oku="$(gorev_durum_oku "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["gorev"])' "$kj")")"; MEVCUT="${oku%% *}"; MSURUM="${oku#* }"; [ "$MEVCUT" = "-" ] && MEVCUT=""; [[ "$MSURUM" =~ ^[0-9]+$ ]] || MSURUM="" ;; esac
  govde="$(MEVCUT_DURUM="$MEVCUT" MEVCUT_SURUM="$MSURUM" DARALT_NOT="${DARALT_NOT:-}" GOZ_NOT="${GOZ_NOT:-}" GECTI_KART="${GECTI_KART:-}" GOREV_BITTI="${GOREV_BITTI:-}" KARE="${KARE:-}" SURUM="${SURUM:-}" OLCUM="${OLCUM:-}" BELGE="${BELGE:-}" python3 - "$kj" "$olay" "$(basename "$DEPO")" <<'PY'
import json,sys,os
k=json.load(open(sys.argv[1])); olay,depo=sys.argv[2:]; kim=k["aldi"]; is_=k["is"]
md=os.environ.get("MEVCUT_DURUM","")
KORU=md in ("onay-bekliyor","bitti")
if KORU and olay in ("ac","gecti","tikandi"):
    # ONAY KORUMASI: durum yazılmaz, yalnız adım (Sultan'ın kuyruğundaki iş yerinde kalır)
    neler={"ac":"kart %s açıldı (tahmin %s dk)" % (is_,k.get("tahmin_dk")),"gecti":"kart %s açıkken başka işe geçti: %s" % (is_,os.environ.get("GECTI_KART","?")),
           "tikandi":"kart %s tıkandı: %s" % (is_,((k.get("tikanma") or {}).get("neden","") or "tıkandı")[:300])}
    print(json.dumps({"adimlar":["[▶ dilim] %s · %s — görev '%s', durumu KORUNUR (onay kuyruğundan düşmez)" % (kim,neler[olay],md)]},ensure_ascii=False)); sys.exit(0)
if olay=="ac":
    y={"atanan":kim,"tahmin_dk":str(k.get("tahmin_dk","")),"gorev_durumu":"calisiliyor"}; ne="[▶ çalışılıyor] %s · kart %s açıldı, tahmin %s dk · sınıf: %s" % (kim,is_,k.get("tahmin_dk"),",".join(k.get("siniflar") or []) or "yok")   # 0.25.2: merkezin otomatik doğrulama devri sınıfsız işi buradan okur (sınıf bilinmiyorsa Doğrulat)
elif olay=="bitti":
    # DİLİM ≠ GÖREV (KF22R · Sultan D1 21 Eki): kart = dilim; PR birleşmesi görevi BİTİRMEZ. Varsayılan: göreve yalnız dilim adımı,
    #   durum 'çalışılıyor' kalır. Görev de bitecekse --gorev-bitti + kanıt sınıfı (ekran: --kare + --surum · ölçüm: --olcum · belge: --belge);
    #   geçit (defter 1.17.0) aynı sınıfı ister, PR tek başına 400 alır.
    pr=("%s PR #%s" % (depo,k["pr"])) if k.get("pr") else ""
    if k.get("durum")=="canli-borclu":
        # CANLI BORÇ: kart bitmedi — görev adımı borcu görünür kılar (Sultan tablosu görevden okur); görev 'çalışılıyor' kalır
        y=None; ne="[🧾 canlı borç] %s · kart %s kodu hazır%s, CANLI KAYIT BORÇLU — dağıtımdan sonra kanit.sh canli + kart.sh bitti %s; 24 sa içinde ödenmezse kırmızı" % (kim,is_,(" · "+pr) if pr else "",is_)
    elif os.environ.get("GOREV_BITTI"):
        kare,surum,olc,belge=(os.environ.get(x,"").strip() for x in ("KARE","SURUM","OLCUM","BELGE"))
        if kare or surum: sinif="[kare] %s · [surum] %s" % (kare,surum)
        elif olc: sinif="[olcum] %s" % olc
        else: sinif="[belge] %s" % belge
        kn=sinif+(" · [pr] #%s" % k["pr"] if k.get("pr") else "")+" · kanıt _agents/fabrika/kanit/%s/ (%s)" % (is_,depo)
        y={"gorev_durumu":"onay-bekliyor","kanit":kn}; ne="[⏸ onay bekliyor] %s · kart %s bitti · %s" % (kim,is_,kn)
    else:
        y=None; ne="[dilim bitti] %s · kart %s bitti%s · kanıt _agents/fabrika/kanit/%s/ (%s) — görev sürüyor; bitti için canlı kanıt sınıfı: kart.sh bitti %s --gorev-bitti --kare <yol> --surum <sürüm> | --olcum \"…\" | --belge <yol> (ya da gorev.sh bitti)" % (kim,is_,(" · "+pr) if pr else "",is_,depo,is_)
elif olay=="goz":
    # 0.24.0 (gorev_…Y7J3Q): bağımsız göz turu göreve TEK SATIR adım olarak düşer; durum DEĞİŞMEZ (görev çalışılıyor olmayabilir de)
    y=None; ne=os.environ.get("GOZ_NOT","").strip() or "[🔎 göz] kart %s" % is_
elif olay=="gecti":
    # 0.24.0: aynı ajan yeni işe geçti → önceki görev 'bekliyor' + sebep (bırakma anı artık araca geçer, ajanın hatırlamasına değil)
    yeni=os.environ.get("GECTI_KART","?")
    y={"gorev_durumu":"bekliyor","not":"başka işe geçti: %s" % yeni}; ne="[⏳ bekliyor] %s · kart %s açıkken başka işe geçti: %s" % (kim,is_,yeni)
elif olay=="daralt":
    y=None; ne=os.environ.get("DARALT_NOT","")
else:
    nd=(k.get("tikanma") or {}).get("neden","") or "tıkandı"
    y={"gorev_durumu":"bekliyor","not":"kart %s tıkandı: %s" % (is_,nd[:300])}; ne="[⏳ bekliyor] %s · kart %s tıkandı (%s): %s" % (kim,is_,(k.get("tikanma") or {}).get("yol",""),nd[:300])
g={"adimlar":[ne]} if y is None else {"yerine":y,"gerekce":ne,"adimlar":[ne]}
if y is not None and olay in ("ac","gecti","tikandi") and os.environ.get("MEVCUT_SURUM"): g["surum"]=int(os.environ["MEVCUT_SURUM"])   # iyimser kilit: okuduğumuz sürüm değiştiyse defter 409 döner
print(json.dumps(g,ensure_ascii=False))
PY
)" || return 4
  if [ ! -r "$DEFTER_JY" ]; then sonuc="yazılamadı: bu kutuda defter jetonu yok ($DEFTER_JY)"
  else
    cfg="$(mktemp)"; printf 'header = "x-defter-jeton: %s"\n' "$(tr -d '\n' < "$DEFTER_JY")" > "$cfg"
    cevap="$(curl -sS -m 15 --config "$cfg" -X PATCH -H 'content-type: application/json' --data-binary "$govde" "$DEFTER_U/kayit/$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["gorev"])' "$kj")" -w '\n%{http_code}' 2>&1)"; rc=$?
    rm -f -- "$cfg"
    if [ $rc -ne 0 ]; then sonuc="yazılamadı: deftere ulaşılamadı ($DEFTER_U)"
    else sonuc="$(printf '%s' "$cevap" | python3 -c '
import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
try: j=json.loads(g or "{}")
except Exception: j={}
if kod=="200": print("yazıldı")
else:
    e=j.get("ek") if isinstance(j.get("ek"),dict) else j
    print("yazılamadı: http %s · %s%s" % (kod, j.get("hata") or "cevap okunamadı", (" · " + str(e.get("yerine"))[:160]) if e.get("yerine") else ""))')"; fi
  fi
  [ "$deneme" = 1 ] && [ -n "$MSURUM" ] && [[ "$sonuc" == "yazılamadı: http 409 · surum_catismasi"* ]] || break
  done
  MEVCUT_DURUM="$MEVCUT" GOREV_BITTI="${GOREV_BITTI:-}" python3 - "$kj" "$olay" "$sonuc" <<'PY'
import json,sys,datetime
p,olay,sonuc=sys.argv[1:]; k=json.load(open(p))
k.setdefault("gorev_yazimlari",[]).append({"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),"olay":olay,"sonuc":sonuc})
json.dump(k,open(p,"w"),ensure_ascii=False,indent=2)
import os
d={"ac":"çalışılıyor","bitti":("canlı borç adımı (görev çalışılıyor kalır)" if k.get("durum")=="canli-borclu" else "onay bekliyor" if os.environ.get("GOREV_BITTI") else "dilim adımı (görev çalışılıyor kalır; bitti = canlı kanıt sınıfıyla)"),"tikandi":"bekliyor","goz":"göz adımı (durum değişmez)","gecti":"bekliyor (başka işe geçti)","daralt":"ölçüt adımı (görev durumu değişmez)"}[olay]
md=os.environ.get("MEVCUT_DURUM","")
if md in ("onay-bekliyor","bitti") and olay in ("ac","gecti","tikandi"): d="yalnız adım — görev '%s', durumu korundu" % md
print(("  ✓ görev %s → %s (defter)" % (k["gorev"],d)) if sonuc=="yazıldı" else ("  ⚠ GÖREV YAZILAMADI: %s → %s — %s (kart işlendi; karta yazıldı, rc 4)" % (k["gorev"],d,sonuc)))
PY
  [ "$sonuc" = "yazıldı" ]
}

# 🔴 ÇALIŞILIYOR UZLAŞTIRMASI (DKYSHH + X666 · SERDAR 26 Eki): açılış ve bitiş/tıkanmadan SONRA ajanın 'çalışılıyor' görevleri açık kartlarıyla
#    uzlaştırılır: açık kartı olmayan görev ve ajan başına 2'den fazlası 'bekliyor + başka işe geçti' olur. En iyi gayret: defter yoksa/yazamazsa
#    kart İŞLENMİŞ kalır (söylenir, rc'yi bozmaz). KART_UZLASTIR=0 kapatır; KART_UZLASTIR_KOKLER (boşlukla) kart dizinlerini değiştirir (sınav).
uzlastir() {  # uzlastir <ajan>
  [ "${KART_UZLASTIR:-1}" = 0 ] && return 0
  local kok args=() kokler="${KART_UZLASTIR_KOKLER:-}"
  if [ -z "$kokler" ]; then kokler="$KD"; for kok in /config/projects/*/_agents/fabrika/kartlar; do [ -d "$kok" ] && kokler="$kokler $kok"; done; fi
  for kok in $kokler; do args+=(--kart-kok "$kok"); done
  python3 "$(dirname "${BASH_SOURCE[0]}")/calisiliyor-uzlastir.py" --ajan "$1" --uygula "${args[@]}" || true
}

tetik() {  # tetik <oda> <başlık> <gövde> → 0 gitti/oda yok · 1 atılmadı/düştü (sınıfsız çağıran yok sayar: iş düşmez;
           #   sınıflı açılış bunu "Sultan'a ulaşılamadı" sayar ve kartı geri alır — göz 23 Eki tur 2)
  [ -n "$1" ] || return 0
  if [ ! -x "$TETIK" ]; then echo "· tetik atılmadı: $TETIK yok (mesaj kartta duruyor)"; return 1; fi
  local f r=0; f="$(mktemp)"
  # HEDEF: oda-tetik.sh dağıtımı YALNIZ mektubun HEDEF: alanına göre yapar (oda argümanı tek başına yetmez; alan yoksa 'hedef-yok' iadesi
  #   → sınıflı kart hiç açılamıyordu, lifeos-kalan 23 Eki). Alan ilk 5 satırda aranır: ilk satıra konur.
  printf 'HEDEF: %s\n%s\n' "$1" "$3" > "$f"
  if bash "$TETIK" gonder "$1" "$f" --ajan "${ALDI:-fabrika}" --baslik "$2" >/dev/null 2>&1; then echo "✓ tetik: $1 ← $2"
  else echo "· tetik düştü (mesaj kartta duruyor, iş düşmez)"; r=1; fi
  rm -f "$f"; return "$r"
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
# ATIF KAPSAM DEĞİLDİR (20 Eki: bir günde üç yanlış alarm — "hafta raporu E3", "retro W42 HENDESE Ö1", "retro W42 ders M2"):
#   haftanın ADI geçiyor ama iş o haftaya yayılmıyor. "retro " önündeki hafta, ve ardından rapor/kapı/kapanış/retro/ders/Ö<n>
#   gelen "hafta"/"W<nn>" atıftır; "W42 boyunca", "1. hafta", "haftalık", "her gün" kapsam olarak kalır.
ATIF_SONRA = r"(?!\s+(?:rapor|kap[ıi]s|kapan[ıi]ş|retro|ders|Ö\d))"
HAFTA = (r"(?<!\w)(?<!retro )(?:haftal[ıi]k\w*|hafta(?:s[ıi]|n[ıi]n|da|y[ıi])?(?!\w)" + ATIF_SONRA + r"|W\d{2}(?!\w)" + ATIF_SONRA
         + r"|\d+\.\s*hafta|[2-9]\s*g[üu]n(?:l[üu]k)?|her\s+g[üu]n|t[üu]m\s+hafta)(?!\w)")
h = sorted(set(m.group(0) for m in re.finditer(HAFTA, cumle, re.I)))
if h:
    print("ÇOK GÜNLÜK KAPSAM (%s): bir PR'da teslim edilmez — gün başına kart öner: %s-g1 · %s-g2 … (her biri günün teslim birimi)" % (", ".join(h), is_, is_))
PY
}

# 🟡 SAYI UYARISI (retro W42 MUAVİN Ö3 · gorev_01M57ZV15AARDJDVV9NK3WNMSQ · SERDAR kararı: UYARI, red değil): yöneticinin
#    "13 görev" sözü kart cümlesine aynen girdi; kaynakta sayı farklıydı, iki göz turu yandı, iş daraltıldı (Nexus #1213).
#    Kart açılırken ARAÇ cümledeki "sayı + ad" iddialarını ("13 görev", "ayda 173 kez", "%50") arar ve UYARIR; karta
#    `sayi_uyarilari` olarak yazılır, bağımsız göz görür. --sayi-olcum '<komut>' verilirse komut deponun kökünde koşulur
#    (30 sn tavan), çıkış kodu + çıktının başı karta `sayi_olcum` olarak işlenir: sayının KAYNAĞI karttadır, uyarı düşer.
#    Sayı SAYILMAYAN yazımlar (atıf/ölçü, iddia değil): kimlik (gorev_…, W42, Ö3, 81D0W) · #PR · sürüm (0.18.1) · tarih/saat
#    (2026-10-23, 04:30, "23 Eki") · sıra ("1. hafta") · birimli eşik/süre (40 dk, 100 KB, 390 px). Dürüst sınır: yazıyla sayı
#    ("on üç görev") ve birimle yazılmış GÖZLEM ("ayda 40 dk kayıp") yakalanmaz; uyarı ölçümün yerini tutmaz, yalnız hatırlatır.
# 🔴 ÖLÇÜT NEREDE ÖLÇÜLECEK (görev …90KA6C · SERDAR 23 Eki "69/43 saatlik iş" araştırması): W1G2N'nin başlığı "4 paralel iş ≤6 dk" diyordu; ölçüt
#    2 çekirdekli CI'da fiziken tutamazdı (korpus 568 sn, iş toplamı 11-13 dk), yalnız 12 çekirdekli kutuda tutardı — "geçti", sonra "kaldı", ~4,5 saat.
#    Kök: kartta sayının NEREDE ölçüleceği yoktu. Şimdi: cümlede sayısal ölçüt (eşik işaretli sayı + birim) varsa --olcum-yeri ZORUNLU, yoksa kart AÇILMAZ.
#    Ölçüt sayılan yazımlar: "≤6 dk" · "<5 sn" · "en çok 40 MB" · "6 dk altında" · "40 dk'dan az". Sayılmayan: işaretsiz süre/boyut ("40 dk", "4 saat adımsız"),
#    atıf/kimlik/sürüm/tarih. Dürüst sınır: yazıyla sayı ("altı dakika") ve eşik kelimesiz ölçüt yakalanmaz; araç hatırlatır, ölçümün yerini tutmaz.
olcut_bul() {  # olcut_bul <cümle> → her satır bir sayısal ölçüt (boş = yok)
  python3 - "$1" <<'PY'
import re, sys
c = sys.argv[1]
B = r"(?:[^\W\d_]+|%)"   # her birim: zaman/boyut/piksel/yüzde ve sayılan şey (puan, istek, hata…) — dar sözlük göz tur 1 bulgusu
S = r"\d+(?:[.,]\d+)?"
DESEN = [rf"(?:≤|<=|<|≥|>=|>)\s*{S}\s*{B}(?!\w)",
         rf"(?<!\w)en\s+(?:çok|az|fazla)\s+{S}\s*{B}(?!\w)",
         rf"(?<![\w.,]){S}\s*{B}\s+(?:altında|altı|içinde|üstünde|üzerinde|üzeri|kadar)(?!\w)",
         rf"(?<![\w.,]){S}\s*{B}['’]?(?:den|dan|ten|tan)\s+(?:az|kısa|çok|fazla|uzun)(?!\w)"]
bul = []
for d in DESEN:
    bul += [m.group(0).strip() for m in re.finditer(d, c, re.I)]
for b in dict.fromkeys(bul): print(b)
PY
}
olcum_yeri_gecerli() {  # olcum_yeri_gecerli <değer> → rc 0: yer adı (yerel|CI|canlı) var; yerel/CI için çekirdek sayısı da var
  python3 - "$1" <<'PY'
import re, sys
y = sys.argv[1].lower()
yerler = {("canlı" if m == "canli" else m) for m in re.findall(r"(?<!\w)(yerel|ci|canlı|canli)(?!\w)", y)}
if len(yerler) != 1: raise SystemExit(1)   # yok ya da birden çok yüzey ('canlı, CI') belirsiz: tek yer adı şart
if "canlı" in yerler: raise SystemExit(0)
raise SystemExit(0 if re.search(r"\d+\s*(?:çekirdek|cekirdek|vcpu|core)", y) else 1)
PY
}
olcut_zorunlu() {  # olcut_zorunlu <cümle> <nerede: ac|daralt> → rc 0 uygun · rc 1 hata basılmış
  local o; o="$(olcut_bul "$1")" || { _hata "ölçüt aracı düştü — kart AÇILMADI (ölçemediğine temiz denmez)"; return 1; }
  [ -n "$o" ] || return 0
  olcum_yeri_gecerli "$OLCUM_YERI" && return 0
  _hata "cümlede sayısal ölçüt var ($(printf '%s' "$o" | head -3 | tr '\n' ';' | sed 's/;$//')) ama NEREDE ölçüleceği yok: --olcum-yeri \"yerel, 12 çekirdek\" | \"CI, 2 çekirdek\" | \"canlı\" (yerel ve CI için çekirdek sayısı şart — W1G2N: '≤6 dk' 2 çekirdekli CI'da imkânsızdı, ~4,5 saat boşa gitti). İş $2 EDİLMEDİ"
  return 1
}

sayi_uyar() {  # sayi_uyar <cümle> → her satır bir ölçümsüz sayı iddiası (boş = yok)
  python3 - "$1" <<'PY'
import re, sys
cumle = sys.argv[1]
AY = r"(?:oca|şub|sub|mar|nis|may|haz|tem|ağu|agu|eyl|eki|kas|ara)\w*"
BIRIM = r"(?:ms|sn|saniye|dk|dakika|sa|saat|kb|mb|gb|tb|px|pt|em|rem|bayt|byte)(?!\w)"
bul = []
for m in re.finditer(r"(?<![\w#.:/+%-])(\d+(?:[.,]\d+)?)(?![\w.,:/-])\s+([^\W\d_][\w']*)", cumle):
    ad = m.group(2)
    if re.match(AY + r"$", ad, re.I) or re.match(BIRIM, ad, re.I): continue
    bul.append(m.group(0))
bul += [m.group(0) for m in re.finditer(r"%\d+(?:[.,]\d+)?(?![\w.,])", cumle)]
for b in dict.fromkeys(bul): print(b)
PY
}

# 🔴 EKRAN KAPISI (gorev_01M5WD813JB48V06QKQKQQWRDT · M4PZV4 dersi): Sultan'a görünen ekran, planla başlar ve kare onayıyla ilerler.
#    İki kapı, ikisi de kart AÇILMADAN ölçer ve kart CÜMLESİNDEN tetiklenir (kaçış bayrağı yok; "Kart cümlesinde olmayan kaçış yolu eklenmez"):
#    (1) dış yüzey ekran kartı → --senaryo <dosya>: ui-tasarim-akisi Durak 2 senaryo kartı (başlık "### E# · …" + yedi alan: Amaç·Giriş·İlk bakışta·Ana akış·Tık bütçesi·Kenar durumlar·Kısıt kancaları), "Tık bütçesi:" DOLU (rakamlı, şablon yer tutucusu değil)
#    (2) sürüm paketi kartı → --kare-onay "<D1 damgası>": Sultan'ın karelere onayı (YYYY-MM-DD Sultan: kare onay (sohbet · <ref> · "<≤15 kelime>" · beyan:<AJAN>))
#    DÜRÜST SINIR: ikisi de BİÇİM ve VARLIK ölçer — damganın gerçekten Sultan'dan geldiğini araç bilemez (A06: ajan Sultan'ın sözünü üretmez, gördüğünü
#    referansla aktarır; haftalık onay-parity örneklem denetler); senaryo kartının İÇERİĞİNİN doğru olduğunu da ölçmez, yalnız dolu olduğunu.
ekran_kapisi() {  # → rc 0 uygun · rc 1 hata basılmış
  local c rc
  c="$(DIS="$DIS" python3 - "$IS_C" "$SENARYO" "$KARE_ONAY" "$DEPO" <<'PY'
import os,re,sys
cumle,senaryo,onay,depo=sys.argv[1:5]; dis=os.environ.get("DIS","")
hata=[]
if dis!="h" and re.search(r"ekran|sayfa|panel|arayüz|arayuz|görünüm|gorunum|pano",cumle,re.I):
    if not senaryo:
        hata.append("dış yüzey ekran kartı senaryo kartı ister: --senaryo <dosya> (ui-tasarim-akisi Durak 2 kartı; 'Tık bütçesi:' satırı dolu olmalı) — kart AÇILMADI")
    else:
        yol=senaryo if os.path.isabs(senaryo) else os.path.join(depo,senaryo)
        if not os.path.isfile(yol): hata.append("--senaryo dosyası yok: %s — kart AÇILMADI" % senaryo)
        else:
            ic=open(yol,encoding="utf-8").read()
            deger={}
            for x in ("Amaç","Giriş","İlk bakışta","Ana akış","Tık bütçesi","Kenar durumlar","Kısıt kancaları"):
                m=re.search(r"\*\*"+x+r":\*\*(.*?)(?=\n\*\*[^\n]*:\*\*|\Z)",ic,re.S)
                if m and m.group(1).strip() and not m.group(1).strip().startswith("<"): deger[x]=m.group(1).strip()
            eksik=[x for x in ("Amaç","Giriş","İlk bakışta","Ana akış","Tık bütçesi","Kenar durumlar","Kısıt kancaları") if x not in deger]
            if eksik or not re.search(r"^#{2,4} E\d+ · \S",ic,re.M):
                hata.append("--senaryo bir ui-tasarim-akisi Durak 2 senaryo kartı değil (başlık '### E# · <ekran adı>' ve yedi alanın HEPSİ dolu olmalı; eksik/boş: %s) — kart AÇILMADI" % (", ".join(eksik) or "E# · ekran adı başlığı"))
            elif not re.search(r"\d",deger["Tık bütçesi"]):
                hata.append("--senaryo kartında 'Tık bütçesi:' rakamsız (yazım: \"3 tık + 2 alan\") — kart AÇILMADI")
if re.search(r"s[üu]r[üu]m\s+paket",cumle,re.I):
    m=re.fullmatch(r'\d{4}-\d{2}-\d{2} Sultan: (.+?) \(sohbet · ([^·()]+?) · "([^"]+)" · beyan:([\w-]+)\)',onay.strip())
    if not onay: hata.append("sürüm paketi kartı Sultan'ın kare onayı olmadan açılmaz: --kare-onay \"YYYY-MM-DD Sultan: kare onay (sohbet · <oturum-ref> · \\\"<≤15 kelime>\\\" · beyan:<AJAN>)\" — kart AÇILMADI")
    elif not m: hata.append("--kare-onay D1 biçiminde değil (oturum-ref · tırnaklı kırpık · beyan:<AJAN> üç parça zorunlu) — kart AÇILMADI")
    elif not (re.search(r"kare",m.group(1),re.I) and re.search(r"onay|uygun|kabul",m.group(1),re.I)): hata.append("--kare-onay sonucu bir kare onayı değil (sonuçta 'kare' ve 'onay|uygun|kabul' geçmeli) — kart AÇILMADI")
    elif len(m.group(3).split())>15: hata.append("--kare-onay kırpığı 15 kelimeyi aşıyor — kart AÇILMADI")
print("\n".join(hata)); raise SystemExit(1 if hata else 0)
PY
)"; rc=$?
  [ "$rc" -le 1 ] || { _hata "ekran kapısı aracı düştü (rc=$rc) — kart AÇILMADI (ölçemediğine temiz denmez)"; return 1; }
  [ "$rc" -eq 0 ] && return 0
  while IFS= read -r c; do [ -n "$c" ] && _hata "$c"; done <<<"$c"; return 1
}

case "$CMD" in
  ac)
    [ -n "$IS" ] && [ -n "$IS_C" ] && [ -n "$ISTEDI" ] && [ -n "$ALDI" ] || { _hata "gerekli: <iş> --is --istedi --aldi"; exit 1; }
    for v in GA PARA DIS YETKI; do case "${!v}" in e|h|\?) ;; *) _hata "dört sınıf sorusu cevapsız kart AÇILMAZ: --geri-alinamaz --para --dis-yuzey --yetki (e|h|?)"; exit 1 ;; esac; done
    case "$CANLI" in ""|e|h) ;; *) _hata "--canli yalnız e|h olabilir ('$CANLI' değil): cron/servis/sunucu işi canlı kanıt ister mi?"; exit 1 ;; esac
    [ -f "$KD/$IS.json" ] && { _hata "kart zaten var: $IS (goster ile bak)"; exit 1; }
    olcut_zorunlu "$IS_C" "AÇILMADI" || exit 1
    ekran_kapisi || exit 1
    OLCUT="$(olcut_bul "$IS_C")"
    # 🔴 SULTAN'A ULAŞIM YOLU (göz 23 Eki tur 2 · fabrika-merge-reise): sınıflı kartın başlama izni Sultan'a GİDER — yol yoksa kart
    #    AÇILMAZ (fail-closed, rc 1). Ölçüldü: eski araç "BAŞLAMA İZNİ SULTAN'A GİDER" basıp rc 0 dönüyordu; --oda yoksa tetik() sessizce
    #    çıkıyor, tetik betiği yoksa "atılmadı" deyip yine 0 — veto penceresi Sultan'ın hiç görmediği bir pencere oluyordu.
    #    Varsayılan oda UYDURULMAZ: oda-tetik.sh'ta "merkez/Sultan" diye bir oda yok; tahmin edilen oda sessiz kayıp olurdu.
    #    Sınıfsız kart DEĞİŞMEDİ (--oda isteğe bağlı, tetik best-effort).
    SINIFLI=0; case "${GA}${PARA}${DIS}${YETKI}" in *e*|*\?*) SINIFLI=1 ;; esac
    if [ "$SINIFLI" = 1 ]; then
      [ -n "$ODA" ] || { _hata "Sultan'a ulaşılamadı: --oda ver ya da tetik betiğini kur — sınıflı işin başlama izni Sultan'a gitmeli, --oda verilmedi (kart AÇILMADI)"; exit 1; }
      [ -x "$TETIK" ] || { _hata "Sultan'a ulaşılamadı: --oda ver ya da tetik betiğini kur — tetik betiği yok: $TETIK (FABRIKA_TETIK; kart AÇILMADI)"; exit 1; }
    fi
    if [ -n "$GOREV" ]; then
      [[ "$GOREV" =~ ^gorev_[A-Za-z0-9]{10,40}$ ]] || { _hata "--gorev gorev_<kimlik> biçiminde olmalı ('$GOREV' değil)"; exit 1; }
      [[ "$TAHMIN" =~ ^[1-9][0-9]{0,4}$ ]] || { _hata "--gorev verilince --tahmin <dk> ZORUNLU (defter 'çalışılıyor'a tahminsiz geçmez; Sultan: başladıysa tahmini bitiş)"; exit 1; }
    elif [ -n "$TAHMIN" ]; then _hata "--tahmin yalnız --gorev ile anlamlı (hangi görevin tahmini?)"; exit 1; fi
    IFS=$'\t' read -r CG CSEBEP <<<"$(canli_hesapla "$IS_C" "$CANLI")"; CSEBEP="${CSEBEP:-}"
    KUYARI="$(kapsam_uyar "$IS" "$IS_C" "$(basename "$DEPO")")" || { _hata "kapsam uyarısı ölçülemedi"; KUYARI="ÖLÇÜLEMEDİ: kapsam uyarısı aracı düştü"; }
    SUYARI="$(sayi_uyar "$IS_C")" || { _hata "sayı uyarısı ölçülemedi"; SUYARI="ÖLÇÜLEMEDİ: sayı uyarısı aracı düştü"; }
    SRC=""; SCIKTI=""
    if [ -n "$SAYI_OLCUM" ]; then   # sayının kaynağı: deponun kökünde, girdisiz, 30 sn tavanlı; çıkış kodu SAKLANIR (boru yutmaz)
      SCIKTI="$(cd "$DEPO" && timeout 30 bash -c "$SAYI_OLCUM" </dev/null 2>&1)"; SRC=$?
    fi
    # 🔴 ATOMİK YAYIM (göz 23 Eki tur 3 · PR #445): kart önce GEÇİCİ dosyaya yazılır, tetik başarıdan sonra tek adımda (ln: var olanı ezmez)
    #    yayımlanır. Tetik sırasında süreç kesilirse görünür kart KALMAZ (izin isteği gitmemiş kart yok); başarısızlıkta yalnız KENDİ geçici
    #    dosyamız silinir — aynı kimlikle eşzamanlı açılan başkasının kartına dokunulmaz.
    KART_TMP="$KD/$IS.json.acilis-$$"
    SENARYO="$SENARYO" KARE_ONAY="$KARE_ONAY" OLCUT="$OLCUT" OLCUM_YERI="$OLCUM_YERI" python3 - "$KART_TMP" "$IS" "$IS_C" "$ISTEDI" "$ALDI" "$GA" "$PARA" "$DIS" "$YETKI" "$KANIT" "$ODA" "$CG" "$CSEBEP" "$KUYARI" "$GOREV" "$TAHMIN" "$SUYARI" "$SAYI_OLCUM" "$SRC" "$SCIKTI" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY'
import json,sys,datetime
yol,is_,cumle,istedi,aldi,ga,para,dis,yetki,kanit,oda,cg,csebep,kuyari,gorev,tahmin,suyari,skomut,src,scikti,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from izin import KURAL_SURUMU
cev={"geri_alinamaz":ga,"para":para,"dis_yuzey":dis,"yetki":yetki}
siniflar=[k for k,v in cev.items() if v in("e","?")]
simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
kart={"is":is_,"cumle":cumle,"istedi":istedi,"aldi":aldi,"zaman":simdi,
      "sinif_cevaplari":cev,"siniflar":siniflar,"sultan":bool(siniflar),"kanit_nerede":kanit,"oda":oda,"durum":"acik","gecmis":[],
      "canli_gerekir":cg=="E","canli_sebep":csebep,"kapsam_uyarilari":[u for u in kuyari.splitlines() if u.strip()]}
if siniflar:
    # 0.21.0: sınıflı kartta başlama izni (veto penceresi)
    kart["baslama_izni"]={"durum":"bekliyor","istendi":simdi}; kart["kural_surumu"]=KURAL_SURUMU
if gorev: kart["gorev"]=gorev; kart["tahmin_dk"]=int(tahmin)
import os
if os.environ.get("SENARYO"): kart["senaryo"]=os.environ["SENARYO"]
if os.environ.get("KARE_ONAY"): kart["kare_onayi"]=os.environ["KARE_ONAY"]
if os.environ.get("OLCUT") or os.environ.get("OLCUM_YERI"):
    kart["olcut"]=[x for x in os.environ.get("OLCUT","").splitlines() if x.strip()]; kart["olcum_yeri"]=os.environ.get("OLCUM_YERI","")
sayilar=[u for u in suyari.splitlines() if u.strip()]
TAVAN=2000   # kart bir JSON kaydıdır, ölçüm arşivi değil: tavan AÇIK yazılır, kesilme SESSİZ değildir (göz #430 tur 1)
if skomut:
    kart["sayi_olcum"]={"komut":skomut,"rc":int(src),"cikti":scikti[:TAVAN],"cikti_bayt":len(scikti.encode()),"kirpildi":len(scikti)>TAVAN,"zaman":kart["zaman"]}
    if len(scikti)>TAVAN: kart["sayi_olcum"]["son_satirlar"]=scikti.rstrip().splitlines()[-5:]   # sonuç çoğu zaman sondadır
kaynakli = bool(skomut) and src=="0"
kart["sayi_uyarilari"]=[] if kaynakli else sayilar
json.dump(kart,open(yol,"w"),ensure_ascii=False,indent=2)
print(f"✓ kart açıldı: {is_} · sınıf: {', '.join(siniflar) if siniflar else 'yok'} · {'BAŞLAMA İZNİ SULTAN\'A GİDER (veto penceresi: iş yürür; ara ve birleştirme kararları reisin)' if siniflar else 'ekipte biter, gün sonu özetine girer'}")
for u in kart["kapsam_uyarilari"]: print(f"  ⚠ KAPSAM — {u} (uyarı, red değil; karta yazıldı)")
if kart["sayi_uyarilari"]:
    print("  ⚠ SAYI — cümlede kaynağı ölçülmemiş sayı: %s → kaynağından sayan komutu ver: kart.sh ac … --sayi-olcum '<komut>' (uyarı, red değil; karta yazıldı)" % " · ".join("'%s'" % u for u in kart["sayi_uyarilari"]))
if skomut:
    ilk=(scikti.strip().splitlines() or ["(çıktı yok)"])[0][:120]
    print(f"  · sayı kaynağı karta yazıldı (rc={src}): {ilk}" if kaynakli else f"  ⚠ SAYI — ölçüm komutu DÜŞTÜ (rc={src}) — sayı kaynaksız sayıldı: {ilk}")
    if kart["sayi_olcum"]["kirpildi"]: print(f"  ⚠ SAYI — ölçüm çıktısı {kart['sayi_olcum']['cikti_bayt']} bayt: karta ilk {TAVAN} karakter + son 5 satır yazıldı (KIRPILDI); tam çıktı için kanit.sh olcum")
if kart.get("olcut"): print("  · ölçüt: %s → ölçüleceği yer: %s (karta yazıldı)" % (" · ".join("'%s'" % u for u in kart["olcut"]), kart["olcum_yeri"]))
if cg=="E": print(f"  · CANLI kanıt zorunlu ({csebep}): gerçek ateşleme kaydı (kanit.sh canli) olmadan birleştirme kapısı geçmez")
elif csebep: print(f"  ⚠ canlı kanıt istenmedi — {csebep}; karta yazıldı, bağımsız göz görür")
if not gorev: print("  · görev bağı yok — iş Sultan'ın 'çalışılıyor' görünümüne DÜŞMEZ (bağlamak için: kart.sh ac … --gorev gorev_<kimlik> --tahmin <dk>)")
PY
    # Sultan'a giden satır Sultan-dilindedir: Sultan komut yazmaz (göz 23 Eki tur 2). Ajan tarafı: kart.sh sultan-dedi <iş> --karar dur
    IZIN_NOT=""; [ "$SINIFLI" = 1 ] && IZIN_NOT=" · başlama izni bekleniyor (veto penceresi: iş yürür; durdurmak için 'dur' demen yeter)"
    TRC=0; tetik "$ODA" "iş alındı: $IS" "$IS_C · sahip $ALDI · istedi $ISTEDI · sınıf: ${GA}${PARA}${DIS}${YETKI}$IZIN_NOT" || TRC=1
    if [ "$SINIFLI" = 1 ] && [ "$TRC" -ne 0 ]; then   # izin isteği GİTMEDİ → kart hiç yayımlanmaz (yalnız kendi geçici dosyamız silinir)
      rm -f -- "$KART_TMP"; _hata "Sultan'a ulaşılamadı: --oda ver ya da tetik betiğini kur — '$ODA' odasına tetik düştü, başlama izni GİTMEDİ (kart GERİ ALINDI, açılmadı)"; exit 1
    fi
    ln -- "$KART_TMP" "$KD/$IS.json" 2>/dev/null || { rm -f -- "$KART_TMP"; _hata "kart zaten var: $IS (açılış sırasında başkası açtı; onun kartına dokunulmadı)"; exit 1; }
    rm -f -- "$KART_TMP"
    GRC=0; [ -n "$GOREV" ] && { gorev_yaz "$KD/$IS.json" ac || GRC=4; }
    # 0.24.0: aynı ajanın BAŞKA açık, görev bağlı kartı varsa o görev 'bekliyor' + 'başka işe geçti: <bu kart>' (bırakma anı araçta)
    if [ -n "$GOREV" ]; then
      for ONC in $(python3 - "$KD" "$IS" "$ALDI" "$GOREV" <<'PY'
import json,glob,os,sys
kd,yeni,aldi,gorev=sys.argv[1:]
for f in sorted(glob.glob(kd+"/*.json")):
    try: k=json.load(open(f))
    except Exception: continue
    if k.get("is")!=yeni and k.get("aldi")==aldi and k.get("durum")=="acik" and k.get("gorev") and k.get("gorev")!=gorev: print(k["is"])
PY
); do GECTI_KART="$IS" gorev_yaz "$KD/$ONC.json" gecti || GRC=4; done
    fi
    uzlastir "$ALDI"
    exit $GRC
    ;;
  bitti|tikandi)
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    [ "$CMD" = "tikandi" ] && { [ -n "$YOL" ] && [ -n "$NEDEN" ] || { _hata "tikandi --yol devam|daralt|geri-al --neden gerekiyor"; exit 1; }; }
    # 🔴 CEVAP BEKLE (gorev_…CMWNK): soruya bağlı eylemin cevabı gelmeden iş kapanmaz — kapanış "eylem yapıldı ya da gerekmedi" demektir.
    #    tikandi serbest (tıkanmanın nedeni zaten cevapsız soru olabilir).
    if [ "$CMD" = "bitti" ]; then
      SD="$(bash "${BASH_SOURCE[0]}" cevap-bekle "$IS" 2>&1)"; SRC=$?
      [ "$SRC" -eq 3 ] && { _hata "kartta CEVAPSIZ SORU var — cevap gelmeden kart kapanmaz: ${SD#*$'\t'} (cevap: kart.sh cevap $IS --no N …)"; exit 1; }
      [ "$SRC" -eq 0 ] || [ "$SRC" -eq 4 ] || { _hata "soru durumu okunamadı (cevap-bekle rc $SRC) — kart kapanmadı: $SD"; exit 1; }
    fi
    # kanıt/denetim: çağrıldığı ağaçtan, orada yoksa kartın iş alanından okunur (kanit_agaci)
    DZ="$(kanit_agaci "$IS")"
    # 🔴 GÖZ #353 tur 3: eski kart (alan yok) kapıda cümleden "canlı ister" sayılıyor ama bitti uyarmıyordu → aynı yüzeyden (canli-gerekir) okunur
    # yedek göz #354: fail-open değil — okunamazsa '?' olur ve bitti bunu uyarı olarak basar (kapı aynı durumda rc=3)
    IFS=$'\t' read -r CGB _ <<<"$(bash "${BASH_SOURCE[0]}" canli-gerekir "$IS" 2>&1)"; case "$CGB" in E|H) ;; *) CGB="?" ;; esac
    python3 - "$KD/$IS.json" "$CMD" "$PR" "$YOL" "$NEDEN" "$DZ" "$CGB" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY' || exit 1
import json,sys,os,glob,datetime
yol,cmd,pr,yolu,neden,dz,cgb,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from kanit import etkin_kayitlar   # 4K938: etkin renk tek yerden
from canli_borc import durum as borc_durum                  # 5WYQMW: canlı borç tek yerden
from izin import izin_durumu, siniflimi                     # 0.21.0: başlama izni / veto tek yerden
k=json.load(open(yol)); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
# 🔴 VETO çiti · bitti (göz tur 1): dur ya da okunamayan izin → kart bitmez, birleştirme kararı yazılmaz
iz,iza=("gerekmiyor","") if not siniflimi(k) else izin_durumu(k)
if cmd=="bitti" and iz in ("dur","olculemedi"):
    print(f"✗ {'Sultan DUR dedi' if iz=='dur' else 'kartın başlama izni OKUNAMADI'} — kart bitirilmez, birleştirme kararı yazılmaz ({iza}); "
          f"önce kart.sh sultan-dedi {k['is']} --karar basla. PR zaten birleştiyse geri alma kararı Sultan'ın", file=sys.stderr); raise SystemExit(1)
den=sorted(glob.glob(os.path.join(dz,"DENETIM-[0-9]*.json")),key=lambda p:int(p.rsplit("-",1)[1].split(".")[0]))
son=json.load(open(den[-1]))["sonuc"] if den else None
kanit=os.path.exists(os.path.join(dz,"KANIT.json"))
canli=[x for x in (etkin_kayitlar(json.load(open(os.path.join(dz,"KANIT.json")))) if kanit else []) if x.get("tur")=="canli"]
cy=sum(1 for x in canli if x["etkin_renk"]=="yesil")
k["canli_kanit"]="var" if cy else ("sari" if canli else "yok")
bd,bac=borc_durum(k,canli)
borclu=False
if cmd=="bitti" and bd=="gecersiz":
    print("✗ canlı borç GEÇERSİZ: "+bac+" — kart kapanmadı (ya borcu düzelt ya da gerçek canlı kaydı al: kanit.sh canli)",file=sys.stderr); raise SystemExit(1)
borclu=(cmd=="bitti" and bd=="gecerli")   # geçerli ve ÖDENMEMİŞ borç: kart bitmez, borçlu kalır
if cmd=="bitti" and bd=="odendi": k["canli_borc"]["odendi"]=simdi
k["durum"]="canli-borclu" if borclu else cmd; k["bitis"]=None if borclu else simdi; k["pr"]=pr or k.get("pr","")
k["puan"]={"kod":son["kod_puani"],"dogru":son["dogru_sey"],"tur":len(den)} if son else None
k["kanit_var"]=kanit
if cmd=="tikandi": k["tikanma"]={"yol":yolu,"neden":neden}
k["gecmis"].append({"zaman":simdi,"olay":cmd})
# 0.21.0: sınıflı kartta birleştirme kararı karta (karar_veren: reis — A06: Sultan sözü değil)
if cmd=="bitti" and siniflimi(k) and not k.get("birlestirme_karari"):
    rb=[x for x in (k.get("reis_kararlari") or []) if x.get("karar")=="birlestir"]
    k["birlestirme_karari"]={"karar_veren":"reis","reis":os.environ.get("AGENT_NAME") or k.get("aldi"),"pr":k.get("pr",""),"zaman":simdi,
        "dayanak":f"tur {len(den)} {son['kod_puani']}/{son['dogru_sey']}" if son else "denetim YOK",
        "kanit":"var" if kanit else "yok","izin":iz,"gerekce":(rb[-1].get("gerekce") if rb else None)}
json.dump(k,open(yol,"w"),ensure_ascii=False,indent=2)
uyari=""
if cmd=="bitti" and not kanit: uyari+=" ⚠ KANIT YOK (kanıtsız bitti sayılmaz — gün sonu özetinde işaretlenir)"
if cmd=="bitti" and son and not(son["kod_puani"]==5 and son["dogru_sey"]=="E"): uyari+=" ⚠ son denetim 5+E DEĞİL"
if cmd=="bitti" and cgb=="?": uyari+=" ⚠ kartın canlı şartı OKUNAMADI (kart.sh canli-gerekir) — kapı bunu ÖLÇÜLEMEDİ sayar"
if cmd=="bitti" and cgb=="E" and not cy and bd=="yok": uyari+=" ⚠ CANLI KANIT YOK (cron/servis/sunucu işi gerçek ateşleme kaydı ister: kanit.sh canli)"
if borclu:
    print(f"🧾 kart CANLI BORÇLU (bitti DEĞİL): {k['is']} · {bac}\n   ödeme: dağıtımdan sonra kanit.sh canli {k['is']} <etiket> --kaynak … --desen …; sonra kart.sh bitti {k['is']} (24 sa içinde; aksi hâlde kart.sh borclar kırmızı)")
else:
    bk=k.get("birlestirme_karari") if cmd=="bitti" else None
    print(f"✓ kart {cmd}: {k['is']} · puan {k['puan']} · kanıt {'var' if kanit else 'YOK'}{uyari}"+(f" · {bac}" if bd=="odendi" else "")
          +(f" · birleştirme kararı: {bk['karar_veren']} ({bk['reis']}) · izin: {bk['izin']} · dağıtım Sultan eli" if bk else ""))
PY
    if [ "$CMD" = bitti ] && [ -n "$GOREV_BITTI" ] && [ "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8")).get("durum"))' "$KD/$IS.json")" = canli-borclu ]; then
      _hata "kart CANLI BORÇLU — --gorev-bitti reddedildi: görev canlı kayıt ödenmeden bitmez (önce kanit.sh canli, sonra kart.sh bitti)"; exit 1
    fi
    if [ "$CMD" = bitti ] && [ -n "$GOREV_BITTI" ]; then   # görevi de bitir: kanıt sınıfı ŞART (geçitle aynı kural)
      if [ -n "$KARE" ] || [ -n "$SURUM" ]; then [ -n "$KARE" ] && [ -n "$SURUM" ] || { _hata "--gorev-bitti ekran işinde kare + sürüm BİRLİKTE: --kare <yol> --surum <canlı sürüm> (kare hangi sürümün?)"; exit 1; }
        case "$KARE" in */*|*.*) ;; *) _hata "--kare bir dosya yolu olmalı ('/' ya da '.' taşır): $KARE"; exit 1 ;; esac
      elif [ -n "$OLCUM" ]; then [ "${#OLCUM}" -ge 3 ] || { _hata "--olcum en az 3 harf (önce=N sonra=M ya da dosya)"; exit 1; }
      elif [ -n "$BELGE" ]; then [ "${#BELGE}" -ge 3 ] || { _hata "--belge en az 3 harf (yol ya da PR)"; exit 1; }
      else _hata "--gorev-bitti kanıt sınıfı ister: --kare <yol> --surum <sürüm> | --olcum \"…\" | --belge <yol> (PR tek başına dilimdir, görev değil)"; exit 1; fi
      export GOREV_BITTI KARE SURUM OLCUM BELGE
    fi
    GRC=0; [ -n "$(python3 -c "import json;print(json.load(open('$KD/$IS.json')).get('gorev',''))")" ] && { gorev_yaz "$KD/$IS.json" "$CMD" || GRC=4; }
    uzlastir "$(python3 -c "import json;print(json.load(open('$KD/$IS.json')).get('aldi',''))")"
    tetik "$(python3 -c "import json;print(json.load(open('$KD/$IS.json')).get('oda',''))")" "iş $CMD: $IS" "$(python3 -c "import json;k=json.load(open('$KD/$IS.json'));print(k['cumle'],'· puan',k.get('puan'),'· pr',k.get('pr'))")"
    exit $GRC
    ;;
  supur)   # supur kuru|uygula [--aldi AD] — PR'ı BİRLEŞMİŞ açık/tıkandı kartları toplu kapatır (HSKJCE: elle kapatma 'KANIT YOK' damgalıyordu)
    # Kural: kuru yalnız listeler (hiçbir şey yazmaz); uygula kapatır. Eşleşme: kartta pr varsa O PR birleşmiş olmalı; yoksa dal adı = iş adı olan
    #   BİRLEŞMİŞ PR aranır (dar varyant: 'ekip/ad' öneki ya da 'ad-2' soneki; altdize YOK, başka kartın kendi adı olan dal sayılmaz). SINIFLI kart atlanır (birleştirme kararı reis/Sultan kararıdır, süpürme onu vermez). Görev defterine DOKUNMAZ
    #   (görev kapanışı kanıt sınıfı ister, süpürme kanıt üretmez). Kapanan kart 'supuruldu' damgası taşır: gün sonu 'KANIT YOK' demez,
    #   'süpürüldü' der. PR listesi okunamadı / tavana dayandı / kart bozuk → ÖLÇÜLEMEDİ (rc 3): "listede yok" ≠ "birleşmedi".
    case "$IS" in kuru|uygula) ;; *) _hata "kullanım: kart.sh supur kuru|uygula [--aldi AD]  (kuru = yalnız listeler, uygula = kapatır)"; exit 1 ;; esac
    GH_BIN="${KART_GH:-gh}"; SUP_TAVAN="${KART_SUPUR_TAVAN:-3000}"
    SUP_JSON="$(cd "$DEPO" && "$GH_BIN" pr list --state merged --base main --limit "$SUP_TAVAN" --json number,headRefName,mergedAt 2>&1)"; SRC=$?
    [ "$SRC" -eq 0 ] || { _hata "birleşmiş PR listesi okunamadı (gh rc $SRC) — süpürme ÖLÇÜLEMEDİ, hiçbir kart değişmedi: ${SUP_JSON:0:200}"; exit 3; }
    SUP_JSON="$SUP_JSON" python3 - "$KD" "$IS" "$ALDI" "$SUP_TAVAN" <<'SUPPY'
import json,os,sys,glob,datetime,re
kd,mod,aldi,tavan=sys.argv[1:]; tavan=int(tavan)
try: prler=json.loads(os.environ["SUP_JSON"])
except Exception as e:
    print(f"✗ PR listesi JSON değil ({e}) — ÖLÇÜLEMEDİ, kart değişmedi",file=sys.stderr); raise SystemExit(3)
if not isinstance(prler,list):
    print("✗ PR listesi liste değil — ÖLÇÜLEMEDİ, kart değişmedi",file=sys.stderr); raise SystemExit(3)
if len(prler)>=tavan:   # tavan okuması olay değil tavandır (sayfa boyu dersi): eksik liste 'birleşmedi' sanılmasın
    print(f"✗ PR listesi tavana dayandı ({len(prler)}/{tavan}) — eksik olabilir, ÖLÇÜLEMEDİ, kart değişmedi (KART_SUPUR_TAVAN ile büyüt)",file=sys.stderr); raise SystemExit(3)
dal={}; no={}
for p in prler:
    if p.get("mergedAt"):
        dal.setdefault(p["headRefName"],p); no[int(p["number"])]=p
simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
adlar={os.path.basename(f)[:-5] for f in glob.glob(os.path.join(kd,"*.json"))}   # her kartın adı (durumundan bağımsız)
sahipli=[]
def dal_bul(ad):
    # tam eşleşme; yoksa DAR varyant: 'ekip/ad' öneki ya da 'ad-<sayı>' soneki. Başka bir kartın kendi adı olan dal o kartındır (varyanta düşmez).
    # Altdize eşlemesi YOK: 'x-kalan' kartı açık işin kalanıdır, 'x' dalının birleşmesi onu kapatmaz.
    if ad in dal: return dal[ad],"dal-adi"
    for h,pr_ in dal.items():
        ad_h=h.split("/",1)[-1]
        eslesir=ad_h==ad or re.fullmatch(re.escape(ad)+r"-\d+",ad_h)
        if ({h,ad_h}-{ad}) & adlar:   # dal başka bir kartın adıysa o kartındır: süpürülmez, ama 'devam kartı olabilir' diye gösterilir
            if eslesir: sahipli.append((ad,h,pr_["number"]))
            continue
        if eslesir: return pr_,"dal-adi-varyant"
    return None,"dal-adi"
kapanan=[]; sinifli=[]; bozuk=[]; bekleyen=0; yazilacak=[]
for f in sorted(glob.glob(os.path.join(kd,"*.json"))):
    try: k=json.load(open(f,encoding="utf-8"))
    except Exception: bozuk.append(os.path.basename(f)); continue
    if k.get("durum") not in ("acik","tikandi"): continue
    if aldi and k.get("aldi")!=aldi: continue
    pn=str(k.get("pr") or "").strip().lstrip("#")
    if pn.isdigit(): p=no.get(int(pn)); yontem="kart-pr"
    else: p,yontem=dal_bul(k.get("is"))
    if not p: bekleyen+=1; continue
    if k.get("siniflar"): sinifli.append((k["is"],p["number"])); continue
    kapanan.append((k["is"],p["number"],p["mergedAt"],yontem,k.get("durum")))
    yazilacak.append((f,k,p,yontem))
if bozuk:   # atomik: okunamayan kart varken kısmi uygulama YOK ('ÖLÇÜLEMEDİ' sonrası durum değişmiş olmasın)
    print(f"✗ {len(bozuk)} kart okunamadı ({', '.join(bozuk[:5])}) — süpürme ÖLÇÜLEMEDİ, HİÇBİR kart değişmedi (kartı onar ya da kaldır, yeniden koş)",file=sys.stderr); raise SystemExit(3)
if mod=="uygula":
    for f,k,p,yontem in yazilacak:
        onceki=k.get("durum"); tk=k.pop("tikanma",None)
        k["durum"]="bitti"; k["bitis"]=simdi; k["pr"]=str(p["number"])   # bitis = süpürme anı (gün sonu o gün kapanana bakar); birleşme zamanı damgada
        k["supuruldu"]={"zaman":simdi,"pr":p["number"],"birlesti":p["mergedAt"],"yontem":yontem,"onceki_durum":onceki}
        if tk: k["supuruldu"]["onceki_tikanma"]=tk
        k.setdefault("gecmis",[]).append({"zaman":simdi,"olay":"supuruldu","pr":p["number"]})
        json.dump(k,open(f,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
bas="KAPATILDI" if mod=="uygula" else "KAPATILIRDI (kuru-koşu, hiçbir şey yazılmadı)"
print(f"supur {mod}: {len(kapanan)} kart {bas} · {bekleyen} kartın birleşmiş PR'ı yok (açık kalır) · {len(sinifli)} sınıflı kart atlandı")
for is_,n,m,y,d in kapanan: print(f"  ✓ {is_} ← PR #{n} ({m[:10]}, {y}, önceki: {d})")
for is_,n in sinifli: print(f"  · {is_} — PR #{n} birleşmiş ama kart SINIFLI: birleştirme kararı reis/Sultan'ındır, süpürülmez")
vistel={x[0] for x in kapanan}
for ad,h,n in sahipli:
    if ad not in vistel: print(f"  ? {ad} — '{h}' dalı başka bir kartındır (PR #{n}); {ad}'in devamı olabilir ama süpürülmez, gözle bak")
raise SystemExit(0)
SUPPY
    exit $?
    ;;
  goz-adim)   # goz-adim <iş> --not "<tek satır>" — bağımsız göz turunu göreve adım olarak yazar; durum DEĞİŞMEZ; görev bağı yoksa sessiz geçer
    [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 1; }
    [ -n "${NOT_:-}" ] || { _hata "gerekli: --not \"<tek satır>\""; exit 1; }
    if [ -z "$(python3 -c "import json;print(json.load(open('$KD/$IS.json')).get('gorev',''))")" ]; then echo "  · görev bağı yok — göz adımı deftere yazılmadı"; exit 0; fi
    GOZ_NOT="$NOT_" gorev_yaz "$KD/$IS.json" goz || exit 4
    exit 0
    ;;
  sultan-dedi)
    # 🔴 Sultan'ın sözlü kararı KARTA girer, komut satırında kalmaz. Niçin: bir yetki kapısını
    #    serbest bir metinle açmak, kapıyı hiç koymamakla neredeyse aynıdır (bağımsız göz,
    #    23 Eyl: "komutu çalıştırabilen herkes 20 karakterlik herhangi bir metinle açabiliyor").
    #    Karta yazmak da uydurmayı imkânsız kılmaz — ama uydurmayı KAYITLI, yapılandırılmış ve
    #    sonradan denetlenebilir bir yalan hâline getirir. A06'nın verebileceği en güçlü şey budur.
    [ -n "$IS" ] || { _hata "iş adı gerekiyor"; exit 1; }
    [ -f "$KD/$IS.json" ] || { _hata "kart YOK: $KD/$IS.json"; exit 1; }
    # 0.21.0: kapalı küme (canlıda 13 serbest-metin karar vardı); basla|dur = başlama izni.
    case "$KARAR" in devam|daralt|geri-al|canli-borc|basla|dur) ;; "") ;; *) _hata "--karar yalnız devam|daralt|geri-al|canli-borc|basla|dur olabilir ('$KARAR' değil) — kapalı küme, serbest metin karta girmez"; exit 1 ;; esac
    eksik=""
    [ -n "$KARAR" ] || eksik="$eksik --karar"
    [ -n "$OTURUM" ] || eksik="$eksik --oturum"
    [ -n "$SOZ" ] || eksik="$eksik --soz"
    [ -n "$BEYAN" ] || eksik="$eksik --beyan"
    case "$KARAR" in basla|dur) ;; *) [ -n "$GEREKCE" ] || eksik="$eksik --gerekce" ;; esac   # başlama izni/veto sözün kendisidir; gerekçe isteğe bağlı
    [ -z "$eksik" ] || { _hata "eksik:$eksik — ref'siz, kırpıksız ya da GEREKÇESİZ beyan SAYILMAZ (D1 deseni)"; exit 1; }
    # 🔴 Gerekçe ayrı bir alandır ve Sultan'ın sözünün yerine GEÇMEZ. Tıkanma raporu şunu ister:
    #    "DEVAM — gerekçeyle: neden bir tur daha işe yarar?" Yani iki ayrı şey kayda geçer:
    #    (a) Sultan ne dedi (verbatim, kısa)  (b) bu yolun niçin işe yarayacağı (muhakeme).
    #    İkisini birleştirmek, "devam" sözcüğünü gerekçe saymak olurdu — bağımsız göz 23 Eyl tur 2.
    [ -z "$GEREKCE" ] || [ "${#GEREKCE}" -ge 20 ] || { _hata "--gerekce en az 20 karakter — 'devam' bir gerekçe değildir"; exit 1; }
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
    python3 - "$KD/$IS.json" "$KARAR" "$OTURUM" "$SOZ" "$BEYAN" "$GEREKCE" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY' || exit 1
import json,sys,datetime
yol,karar,oturum,soz,beyan,gerekce,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from izin import siniflimi, KURAL_SURUMU
k=json.load(open(yol,encoding="utf-8")); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
kayit={"karar":karar,"oturum":oturum,"soz":soz,"beyan":beyan,"gerekce":gerekce,"zaman":simdi}
if karar in ("basla","dur") and not siniflimi(k):
    # sınıfsız kartta veto penceresi yok (rc 1)
    print(f"✗ kart SINIFSIZ ({k['is']}): başlama izni / veto penceresi YOK — '{karar}' karta YAZILMADI (yazılsaydı hiçbir kapı okumazdı). "
          f"Sınıfsız iş ekipte biter; durdurmak reisin kararı: kart.sh reis-dedi {k['is']} --karar geri-al --reis {k.get('aldi')} --oturum … --gerekce …  "
          f"Sultan'a sorulmalıydıysa sınıf kuralı bu vakayla düzelir (0-kabul.md 'Sınıfsız iş').", file=sys.stderr); raise SystemExit(1)
k.setdefault("sultan_kararlari",[]).append(kayit)
ek=""
if karar in ("basla","dur"):
    # 0.21.0: başlama izni / VETO — son basla/dur kazanır (eski kart alanı burada kazanır)
    bi=k.get("baslama_izni") if isinstance(k.get("baslama_izni"),dict) else {}
    k["baslama_izni"]={"durum":karar,"istendi":bi.get("istendi") or k.get("zaman"),"zaman":simdi,"oturum":oturum,"soz":soz,"beyan":beyan}
    k.setdefault("kural_surumu",KURAL_SURUMU)
    ek+=(" · ⛔ VETO: reis durur; reis-dedi, daralt ve bitti kapalı — kaldırmak Sultan'ın (--karar basla)" if karar=="dur"
         else " · başlama izni verildi (varsa veto kalktı); iş reis kararlarıyla sürer, dağıtım Sultan eli")
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"✓ Sultan karari karta islendi: {karar} · oturum {oturum} · beyan {beyan}{ek}")
PY
    ;;
  reis-dedi)
    # 🔴 SAHİP/REİS KARARI (8 Eki 2026 · A268): hat "sınıfsız işin kararı sahibinin/reisin" diyordu ama araç
    #    yalnız Sultan'ın kararını okuyordu. Sonuç: sınıfsız bir işin sahibi kendi yetkisindeki kararı yazdıramıyor,
    #    kapı ya kapalı kalıyor ya da birisi Sultan'ın ağzından yazmaya özeniyor (A06). Aynı gün iki vaka
    #    (DEVRİYE doğrulayıcısı · kokpit A2). Karar AYRI alana girer (reis_kararlari) — Sultan'ın alanına değil.
    # 0.21.0: sınıflı kartta da kabul (sinifli:true); tek çit VETO (rc 1).
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
    case "$KARAR" in devam|daralt|geri-al|birlestir) ;; *) _hata "--karar yalnız devam|daralt|geri-al|birlestir olabilir ('$KARAR' değil)"; exit 1 ;; esac
    for v in KARAR REIS OTURUM GEREKCE; do
      d="${!v}"
      if [[ "$d" == *"|"* || "$d" == *$'\n'* ]]; then
        _hata "--$(printf '%s' "$v" | tr 'A-Z' 'a-z') içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1
      fi
    done
    python3 - "$KD/$IS.json" "$KARAR" "$REIS" "$OTURUM" "$GEREKCE" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY' || exit 1
import json,sys,datetime
yol,karar,reis,oturum,gerekce,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from izin import izin_durumu, siniflimi
k=json.load(open(yol,encoding="utf-8"))
# 🔴 (bağımsız göz 8 Eki tur 1) kararı veren, KARTTA yazılı iş sahibi (aldi) olmalı — araç kimlik doğrulayamaz,
#    ama en azından karta yazılı sahipten başka bir adı kabul etmez. Başka bir reisin kararı (ör. SERDAR'ın MUAVİN'in
#    işine "devam" demesi) mektupla gelir; sahip kendi adıyla işler ve gerekçede o mektuba atıf yapar.
if reis != k.get("aldi"):
    print(f"✗ --reis '{reis}' kartın sahibi değil (kartta aldi: {k.get('aldi')}) — sahip kendi adıyla işler, başkasının kararına gerekçede atıf yapar", file=sys.stderr); raise SystemExit(1)
sinifli=siniflimi(k); iz,iza=izin_durumu(k) if sinifli else ("gerekmiyor","")
if sinifli and iz=="dur":   # VETO çiti · reis-dedi
    print(f"✗ Sultan DUR dedi — reis kararı yazılmadı; önce kart.sh sultan-dedi {k['is']} --karar basla (A06: vetoyu yalnız Sultan kaldırır). {iza}", file=sys.stderr); raise SystemExit(1)
if sinifli and iz not in ("bekliyor","basla"):
    print(f"✗ kartın başlama izni OKUNAMADI ({iza}) — reis kararı yazılmadı (fail-closed)", file=sys.stderr); raise SystemExit(1)
kayit={"karar":karar,"reis":reis,"oturum":oturum,"gerekce":gerekce,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds")}
if sinifli: kayit["sinifli"]=True; kayit["izin"]=iz   # reis kararı, Sultan sözü DEĞİL — ayrı alan, etiketli
k.setdefault("reis_kararlari",[]).append(kayit)
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"✓ reis karari karta islendi: {karar} · reis {reis} · oturum {oturum} ({'SINIFLI is · izin: '+iz+' · reis karari, Sultan sozu degil' if sinifli else 'sinifsiz is'})")
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
    olcut_zorunlu "$CUMLE" "DARALTILMADI" || exit 1
    OLCUT_YENI="$(olcut_bul "$CUMLE")"
    for v in KALAN CUMLE OTURUM YENI; do d="${!v}"; if [[ "$d" == *"|"* || "$d" == *$'\n'* ]]; then _hata "--$(printf '%s' "$v" | tr 'A-Z' 'a-z') içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1; fi; done
    YENI="${YENI:-$IS-kalan}"
    # 🔴 (bağımsız göz tur 1) kart adı dosya adıdır: yol ayracı, '..' ya da boşluk kabul edilirse kart dizini DIŞINA yazılır
    case "$YENI" in ''|*/*|*..*|.*|*[!a-zA-Z0-9_-]*) _hata "--yeni geçersiz kart adı: '$YENI' (yalnız harf/rakam/-/_, yol ayracı ve '..' yok)"; exit 1 ;; esac
    [ -f "$KD/$YENI.json" ] && { _hata "kalan kart zaten var: $YENI (--yeni ile başka ad ver)"; exit 1; }
    # tur_sifir: kanıt ağacındaki denetim sayısı (kanit_agaci: bu ağaç, yoksa iş alanı) — daraltmadan önceki turlar yeni cümleyi puanlamadı
    DZ="$(kanit_agaci "$IS")"
    TS=$(ls "$DZ"/DENETIM-[0-9]*.json 2>/dev/null | wc -l)
    OLCUT_YENI="$OLCUT_YENI" OLCUM_YERI="$OLCUM_YERI" python3 - "$KD/$IS.json" "$KD/$YENI.json" "$YENI" "$KALAN" "$CUMLE" "$OTURUM" "$TS" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY' || exit 1
import json,sys,datetime
yol,yyol,yeni,kalan,cumle,oturum,ts,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from izin import izin_durumu, siniflimi, KURAL_SURUMU
k=json.load(open(yol,encoding="utf-8")); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
if k.get("durum") not in ("acik","tikandi"):
    print(f"✗ kart durumu '{k.get('durum')}' — yalnız açık ya da tıkanmış kart daraltılır", file=sys.stderr); raise SystemExit(1)
# 0.21.0: daralt her kartta reis kararıyla; vetoda hiçbir kart değişmez; eski Sultan 'daralt' tüketilir
sinifli=siniflimi(k); iz,iza=izin_durumu(k) if sinifli else ("gerekmiyor","")
if sinifli and iz=="dur":   # VETO çiti · daralt
    print(f"✗ Sultan DUR dedi — daraltma yok, hiçbir kart değişmedi; önce kart.sh sultan-dedi {k['is']} --karar basla. {iza}", file=sys.stderr); raise SystemExit(1)
if sinifli and iz not in ("bekliyor","basla"):
    print(f"✗ kartın başlama izni OKUNAMADI ({iza}) — daraltma yok (fail-closed)", file=sys.stderr); raise SystemExit(1)
acik=[x for x in (k.get("sultan_kararlari") or []) if x.get("karar")=="daralt" and not x.get("kullanildi")]
kim="reis"
if acik:
    acik[0]["kullanildi"]={"zaman":simdi,"kalan_kart":yeni}; kim="Sultan"
rk={"karar":"daralt","reis":k.get("aldi"),"oturum":oturum,"gerekce":f"daraltma: kalan bulgu yeni karta ({yeni}) — {kalan}","zaman":simdi}
if sinifli: rk["sinifli"]=True; rk["izin"]=iz
if acik: rk["sultan_karari_tuketildi"]=True   # reis kaydı yine düşer (defter tam), ama kararın sahibi Sultan'dı
k.setdefault("reis_kararlari",[]).append(rk)
k.setdefault("cumle_gecmisi",[]).append({"cumle":k["cumle"],"zaman":simdi,"kalan_kart":yeni})
k["cumle"]=cumle
# ÖLÇÜT (…90KA6C): daralma ölçütü değiştirdiyse eski ölçüt GEÇERSİZDİR — kartta eski/yeni birlikte durur, görev adımına yazılır
import os
eski_olcut=list(k.get("olcut") or []); yeni_olcut=[x for x in os.environ.get("OLCUT_YENI","").splitlines() if x.strip()]
if eski_olcut!=yeni_olcut:
    k.setdefault("olcut_gecmisi",[]).append({"zaman":simdi,"eski":eski_olcut,"yeni":yeni_olcut,"olcum_yeri":os.environ.get("OLCUM_YERI","")})
    k["olcut"]=yeni_olcut; k["olcum_yeri"]=os.environ.get("OLCUM_YERI","") if yeni_olcut else ""
k.setdefault("daraltmalar",[]).append({"zaman":simdi,"kalan_kart":yeni,"kalan":kalan,"tur_sifir":int(ts),"oturum":oturum})
if k.get("durum")=="tikandi": k["durum"]="acik"
k["gecmis"].append({"zaman":simdi,"olay":"daralt","kalan_kart":yeni,"tur_sifir":int(ts)})
y={"is":yeni,"cumle":kalan,"istedi":k.get("istedi"),"aldi":k.get("aldi"),"zaman":simdi,
   "sinif_cevaplari":k.get("sinif_cevaplari"),"siniflar":k.get("siniflar") or [],"sultan":bool(k.get("siniflar")),
   "kanit_nerede":k.get("kanit_nerede",""),"oda":k.get("oda",""),"durum":"acik","gecmis":[{"zaman":simdi,"olay":"daraltmadan dogdu","koken":k["is"]}],
   "canli_gerekir":k.get("canli_gerekir",False),"canli_sebep":k.get("canli_sebep",""),"koken":k["is"]}
if sinifli:
    # 0.21.0: kalan kart kökün başlama iznini miras alır
    y["baslama_izni"]=dict(k["baslama_izni"] if isinstance(k.get("baslama_izni"),dict) else {"durum":iz,"istendi":k.get("zaman")}); y["baslama_izni"]["miras"]=k["is"]
    y["kural_surumu"]=k.get("kural_surumu") or KURAL_SURUMU
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
print(f"✓ kart daraltıldı: {k['is']} (tur sıfırı {ts}) · kalan bulgu yeni karta: {yeni} · {('SINIFLI, Sultan kararıyla (eski karar tüketildi)' if kim=='Sultan' else 'SINIFLI, reis kararı işlendi · izin: '+iz) if y['sultan'] else 'sınıfsız, reis kararı işlendi'}")
print("  · denetçi bundan sonra yalnız daraltmadan SONRAKİ turları sayar; kapı daraltma sonrası en az bir 5/E tur ister")
if eski_olcut!=yeni_olcut:
    print("  ⚠ ÖLÇÜT değişti: eski %s GEÇERSİZ → yeni %s%s (karta yazıldı; görev başlığındaki eski ölçüt defterde güncellenmeli — başlık eklemeli alandır, bu araç yeniden adlandıramaz)" % (eski_olcut or "yok", yeni_olcut or "yok", (" · ölçüleceği yer: "+os.environ.get("OLCUM_YERI","")) if yeni_olcut else ""))
PY
    OLCUT_NOT="$(python3 - "$KD/$IS.json" <<'PY2'
import json,sys
k=json.load(open(sys.argv[1],encoding="utf-8")); g=(k.get("olcut_gecmisi") or [None])[-1]; d=(k.get("daraltmalar") or [None])[-1]
if k.get("gorev") and g and d and g.get("zaman")==d.get("zaman"):
    print("[✂ ölçüt daraltıldı] %s · kart %s: eski ölçüt %s GEÇERSİZ → yeni %s%s" % (k.get("aldi"),k["is"],g["eski"] or "yok",g["yeni"] or "yok",(" · ölçüleceği yer: "+g["olcum_yeri"]) if g["yeni"] else ""))
PY2
)"
    if [ -n "$OLCUT_NOT" ]; then DARALT_NOT="$OLCUT_NOT" gorev_yaz "$KD/$IS.json" daralt || exit 4; fi
    ;;
  canli-borc)
    # 🔴 CANLI BORÇ (5WYQMW): kapıyı GEVŞETMEZ, borcu KAYDEDER ve görünür kılar. Koşullar canli_borc.py'de (tek gerçek).
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    [ -n "$YAZAN" ] && [ -n "$GEREKCE" ] || { _hata "canli-borc: --yazan <AD> ve --gerekce \"…\" gerekiyor (borcu kartın sahibi yazar, gerekçe en az 20 karakter)"; exit 1; }
    GEREKCE="$(printf '%s' "$GEREKCE" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"   # göz tur 2: 20 boşluk gerekçe sayılmaz
    [ "${#GEREKCE}" -ge 20 ] || { _hata "--gerekce en az 20 karakter (baş/son boşluk sayılmaz) — 'sonra bakarız' bir gerekçe değildir"; exit 1; }
    for v in YAZAN GEREKCE; do d="${!v}"; if [[ "$d" == *"|"* || "$d" == *$'\n'* ]]; then _hata "--$(printf '%s' "$v" | tr 'A-Z' 'a-z') içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1; fi; done
    IFS=$'\t' read -r CGB _ <<<"$(bash "${BASH_SOURCE[0]}" canli-gerekir "$IS" 2>&1)"
    [ "$CGB" = "E" ] || { _hata "bu kart canlı kanıt İSTEMİYOR (canli-gerekir=${CGB:-?}) — borç yalnız --canli e olan kartta olur"; exit 1; }
    python3 - "$KD/$IS.json" "$YAZAN" "$GEREKCE" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY' || exit 1
import json,sys,datetime
yol,yazan,gerekce,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from canli_borc import durum, siniflimi
k=json.load(open(yol,encoding="utf-8"))
if k.get("durum") in ("bitti","canli-borclu") or k.get("canli_borc"):
    print(f"✗ kartta zaten {'borç' if k.get('canli_borc') else 'bitti kaydı'} var (durum {k.get('durum')}) — ikinci borç yazılmaz", file=sys.stderr); raise SystemExit(1)
k["canli_borc"]={"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),"yazan":yazan,"gerekce":gerekce,"odendi":None}
ad,ac=durum(k,[])
if ad!="gecerli":
    print(f"✗ canlı borç YAZILMADI ({ad}): {ac}", file=sys.stderr); raise SystemExit(1)
k.setdefault("gecmis",[]).append({"zaman":k["canli_borc"]["zaman"],"olay":"canli-borc"})
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"🧾 canlı borç kaydedildi: {k['is']} · {ac}\n   kapı bu kartı borçla geçirir; kart 'bitti' olmaz, 'canli-borclu' olur. Ödeme: dağıtımdan sonra kanit.sh canli, sonra kart.sh bitti.")
PY
    ;;
  canli-borc-durum)
    # Kapının okuduğu yüzey: "yok|gecerli|gecersiz|odendi<TAB>açıklama". Kanıt kaydı kanit_agaci ile okunur (bitti ile aynı kural).
    # Kaynak notu / yokluk uyarısı makine satırından SONRA basılır (göz #414 tur 1): kapı bu çıktıyı 2>&1 ile `read` eder,
    # yani yalnız İLK satırı alır — not önce gelse "OKUNAMADI" olurdu, hiç gelmese kartın "dört komut da söyler" şartı düşerdi.
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    KANIT_NOTU="$(mktemp)"; DZ="$(kanit_agaci "$IS" 2>"$KANIT_NOTU")"
    python3 - "$KD/$IS.json" "$DZ" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY'
import json,sys,os
yol,dz,hdir=sys.argv[1:]
sys.path.insert(0,hdir); from canli_borc import durum; from kanit import etkin_kayitlar
k=json.load(open(yol,encoding="utf-8")); kp=os.path.join(dz,"KANIT.json")
canli=[x for x in (etkin_kayitlar(json.load(open(kp,encoding="utf-8"))) if os.path.exists(kp) else []) if x.get("tur")=="canli"]
ad,ac=durum(k,canli); print(ad+"\t"+ac.replace("\n"," ").replace("\t"," "))
PY
    RC=$?; [ -s "$KANIT_NOTU" ] && cat "$KANIT_NOTU" >&2; rm -f "$KANIT_NOTU"; [ "$RC" -eq 0 ] || exit 3
    ;;
  borclar)
    # Açık canlı borçlar ve yaşları. rc 1 = 24 saati aşan borç var (bekçi/nabız bunu okur); rc 0 = borç yok ya da hepsi süresinde.
    python3 - "$KD" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY'
import json,sys,glob,os
kd,hdir=sys.argv[1:]; sys.path.insert(0,hdir); from canli_borc import yas_saat, SURE_SAAT; from izin import izin_durumu, siniflimi
ac=[];gec=0
for p in sorted(glob.glob(os.path.join(kd,"*.json"))):
    try: k=json.load(open(p,encoding="utf-8"))
    except Exception: continue
    if k.get("durum")!="canli-borclu": continue
    y=yas_saat(k); kirmizi=(y is None) or y>SURE_SAAT; gec+=1 if kirmizi else 0
    ac.append((k["is"],y,kirmizi,k["aldi"],("sınıflı · izin: "+izin_durumu(k)[0]) if siniflimi(k) else "ekip"))
if not ac: print("◻ açık canlı borç yok"); raise SystemExit(0)
for is_,y,kr,al,sn in ac: print(f"{'🔴' if kr else '🟡'} {is_:34} {('?' if y is None else '%.1f sa'%y):>8} {al:10} {sn}  {'SÜRE AŞILDI' if kr else ''}")
print(f"── {len(ac)} açık canlı borç · {gec} süresi aşılmış")
raise SystemExit(1 if gec else 0)
PY
    ;;
  izin-durum)
    # 0.21.0: izin TEK yüzeyi (izin.py); kart yok / bozuk → rc 3 (fail-closed, canli-gerekir deseni).
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    python3 - "$KD/$IS.json" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY' || exit 3
import json,sys
yol,hdir=sys.argv[1:]; sys.path.insert(0,hdir); from izin import izin_durumu
try: k=json.load(open(yol,encoding="utf-8"))
except Exception as e: print("olculemedi\tkart okunamadı: %s" % e); raise SystemExit(3)
d,a=izin_durumu(k); print(d+"\t"+a.replace("\n"," ").replace("\t"," "))
raise SystemExit(3 if d=="olculemedi" else 0)
PY
    ;;
  canli-ayarla)
    # Kartı açarken canlı şartı yanlış türemişse (cümlede "cron" geçen belge işi) ya da bu alandan ÖNCE açılmış kartta: şartı sahibi gerekçeyle
    # değiştirir. Eskiden kart dosyası elle düzenleniyordu — aktör de gerekçe de kayıtsızdı. Kapı yine canli-gerekir'den okur; bağımsız göz
    # kartın canli_sebep satırında kararı ve gerekçesini görür. (BÂNİ'nin #352 gerçeklemesi daraltmada çıkmıştı; retro W42 Ö2.)
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    case "$CANLI" in e|h) ;; *) _hata "--canli e|h gerekiyor"; exit 1 ;; esac
    [ -n "$REIS" ] || { _hata "--reis <AD> gerekiyor: canlı şartını yalnız kartın sahibi (aldı alanı) ayarlar (reis-dedi emsali)"; exit 1; }
    GEREKCE="$(printf '%s' "$GEREKCE" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ "${#GEREKCE}" -ge 20 ] || { _hata "--gerekce en az 20 karakter (baş/son boşluk sayılmaz) — canlı şartını koymak ya da kaldırmak gerekçesiz olmaz; bağımsız göz görür"; exit 1; }
    if [[ "$GEREKCE" == *"|"* || "$GEREKCE" == *$'\n'* ]]; then _hata "--gerekce içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1; fi
    python3 - "$KD/$IS.json" "$CANLI" "$GEREKCE" "$REIS" <<'PY' || exit 1
import json,sys,datetime
yol,cevap,gerekce,reis=sys.argv[1:]
k=json.load(open(yol,encoding="utf-8")); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
if k.get("durum")!="acik":
    print(f"✗ kart açık değil (durum: {k.get('durum')}) — kapanmış kartın canlı şartı sonradan değiştirilmez; bitmiş işe geriye dönük gerekçe yazılmaz", file=sys.stderr); raise SystemExit(1)
if reis != k.get("aldi"):
    print(f"✗ --reis '{reis}' kartın sahibi değil (kartta aldı: {k.get('aldi')}) — canlı şartını yalnız sahip ayarlar; başkasının kararı gerekçede atıfla", file=sys.stderr); raise SystemExit(1)
k["canli_gerekir"]=(cevap=="e"); k["canli_sebep"]=f"sahip {reis} ayarladı (--canli {cevap}): {gerekce}"
k.setdefault("gecmis",[]).append({"zaman":simdi,"olay":"canli-ayarla","reis":reis,"canli":cevap,"gerekce":gerekce})
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"✓ canlı şartı karta işlendi: {'GEREKİR' if cevap=='e' else 'istenmedi'} — {gerekce}")
PY
    ;;
  sultan-turu)
    # 🔴 BEĞENİ DÖNGÜSÜ (BPV3A/2BXA6J, Sultan 24 Eki): Sultan bir işi "tamam" diyene dek tur tur götürür; her "şunu değiştir"den sonra gelen yeni
    #    göz turları 3+1 tavanını yiyordu. Bu komut o turu KAYDEDER ve tavan sayacını o ana kadarki denetim sayısına çeker (daralt'ın tur_sifir
    #    mekanizması; denetçi ve kapı iki sıfırın büyüğünü alır). Bedava tur değildir, dört şart ARACA bağlı (ajan beyanına değil):
    #    (1) görevin etiketi 'begeni-dongusu' (defterden okunur; etiketi görevi AÇAN koyar) · (2) görevde sıradaki tur satırı yazılı:
    #    [tur N] kare: <yol/url> · Sultan: "<yorum>" (N = bugüne dek kayıtlı Sultan turu + 1) · (3) reis = kartın sahibi · (4) defter okunamazsa
    #    HİÇBİR ŞEY değişmez (fail-closed). Yeni kart, yeni PR yok: aynı iş sürer. Sultan'ın yorumunu ajan ÜRETMEZ; satır gördüğünü aktarır (A06/D1).
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    [ -n "$REIS" ] && [ -n "$GOREV" ] && [ -n "${TUR_N:-}" ] || { _hata "sultan-turu: --reis <AD> --gorev gorev_<kimlik> --tur <N> gerekiyor"; exit 1; }
    [[ "$TUR_N" =~ ^[1-9][0-9]{0,2}$ ]] || { _hata "--tur pozitif tam sayı olmalı"; exit 1; }
    [[ "$GOREV" =~ ^gorev_[A-Z0-9]{20,40}$ ]] || { _hata "--gorev geçerli bir görev kimliği değil (gorev_<ULID>)"; exit 1; }
    [ -r "$DEFTER_JY" ] || { _hata "defter jetonu yok ($DEFTER_JY) — görevin etiketi ve tur satırı okunamadı, tur KAYDEDİLMEDİ (fail-closed)"; exit 4; }
    cfg="$(mktemp)"; printf 'header = "x-defter-jeton: %s"\n' "$(tr -d '\n' < "$DEFTER_JY")" > "$cfg"
    GJ="$(mktemp)"
    kod="$(curl -sS -m 15 --config "$cfg" -o "$GJ" -w '%{http_code}' "$DEFTER_U/kayit/$GOREV" 2>/dev/null)"; crc=$?
    rm -f -- "$cfg"
    if [ $crc -ne 0 ] || [ "$kod" != "200" ]; then rm -f -- "$GJ"; _hata "görev defterden okunamadı (http $kod, curl rc $crc) — tur KAYDEDİLMEDİ (fail-closed)"; exit 4; fi
    DZ="$(kanit_agaci "$IS")"
    # kanıt dizini yoksa sayım sessizce 0 olurdu ("sıfırlandı" sanılır, gerçekte etkisiz): reddet. Sayım denetçiyle AYNI ölçü: en büyük DENETIM-N indeksi.
    kanit_var_mi "$DZ" || { rm -f -- "$GJ"; _hata "kartın kanıt dizini bulunamadı ($DZ) — tur sıfırı ölçülemedi, tur KAYDEDİLMEDİ (iş alanının İÇİNDEN çağır)"; exit 3; }
    TS=$(ls "$DZ"/DENETIM-[0-9]*.json 2>/dev/null | sed -E 's/.*DENETIM-([0-9]+)\.json/\1/' | sort -n | tail -1); TS="${TS:-0}"
    KARTLAR_DIZ="$KD" python3 - "$KD/$IS.json" "$GJ" "$REIS" "$TUR_N" "$TS" "$GOREV" <<'PY'; rc=$?; rm -f -- "$GJ"; [ $rc -eq 0 ] || exit 1
import json,sys,datetime,re
yol,gj,reis,tur,ts,gorev=sys.argv[1:]; tur=int(tur); ts=int(ts)
k=json.load(open(yol,encoding="utf-8")); simdi=datetime.datetime.now().astimezone().isoformat(timespec="seconds")
def red(m): print("✗ "+m, file=sys.stderr); raise SystemExit(1)
if k.get("durum")!="acik": red(f"kart açık değil (durum: {k.get('durum')}) — kapanmış kartta Sultan turu kaydedilmez")
if reis!=k.get("aldi"): red(f"--reis '{reis}' kartın sahibi değil (aldı: {k.get('aldi')}) — Sultan turunu yalnız sahip kaydeder")
try: g=json.load(open(gj,encoding="utf-8")).get("kayit") or {}
except Exception as e: red(f"görev kaydı okunamadı ({e}) — tur KAYDEDİLMEDİ")
et=(g.get("canli") or {}).get("etiket")
if et!="begeni-dongusu": red(f"görevin etiketi 'begeni-dongusu' değil (defterde: {et or 'yok'}) — etiketi görevi AÇAN koyar; ajan kendi işine etiket koyarak tavanı aşamaz, etiketsiz işte tavan aynen geçerli")
onceki=k.get("sultan_turlari") or []
# görev ↔ kart bağı: ajan başka (ya da kendi işinden bağımsız) bir beğeni görevinin satırıyla sayacı sıfırlayamaz
bagli=k.get("gorev") or (onceki[0].get("gorev") if onceki else None)
if bagli and bagli!=gorev: red(f"bu kartın Sultan turları {bagli} görevine bağlı, '{gorev}' değil — tüm turlar aynı görevden kaydedilir")
import glob,os
for f in glob.glob(os.path.join(os.environ.get("KARTLAR_DIZ",""),"*.json")):
    if os.path.abspath(f)==os.path.abspath(yol): continue
    try: o=json.load(open(f,encoding="utf-8"))
    except Exception: continue
    if any((t or {}).get("gorev")==gorev for t in (o.get("sultan_turlari") or [])): red(f"görev {gorev} Sultan turu kanıtı olarak başka kartta ({os.path.basename(f)}) zaten kullanıldı — bir görevin turları tek karta aittir")
if tur!=len(onceki)+1: red(f"--tur {tur} sıradaki değil: kartta {len(onceki)} Sultan turu kayıtlı, sıradaki {len(onceki)+1}")
kalip=re.compile(r"^\[tur "+str(tur)+r"\] kare: \S.* · Sultan: \".{3,}\"\s*$")
satir=[a.get("deger","") for a in (g.get("adimlar") or []) if kalip.match((a.get("deger") or "").strip())]
if not satir: red(f"görevde tur satırı yok: önce görev adımına tek satır yaz → [tur {tur}] kare: <yol/url> · Sultan: \"<kısa yorum>\" (kare olmadan tur kapanmaz; yorumu ajan üretmez, gördüğünü aktarır)")
onceki_ts=int(onceki[-1]["tur_sifir"]) if onceki else 0
if ts<onceki_ts: red(f"kanıt ağacında {ts} denetim var, önceki Sultan turu {onceki_ts} sayıda sıfırlamıştı — kanıt ağacı geriye gitmiş, tur KAYDEDİLMEDİ")
k.setdefault("sultan_turlari",[]).append({"zaman":simdi,"tur":tur,"tur_sifir":ts,"gorev":gorev,"reis":reis,"satir":satir[-1].strip()[:300]})
k.setdefault("gecmis",[]).append({"zaman":simdi,"olay":"sultan-turu","tur":tur,"tur_sifir":ts,"gorev":gorev})
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(f"✓ Sultan turu {tur} kaydedildi: {k['is']} (tur sıfırı {ts}) · denetçi bundan sonra yalnız bu turdan SONRAKİ göz turlarını tavana sayar")
print("  · kapı bu turdan sonra en az bir 5/E göz turu ister; 4. tur mutlak tavanı kalkmaz")
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
  sor|cevap)
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 3; }
    if [ "$CMD" = sor ]; then
      [ -n "$KIME" ] && [ -n "$EYLEM" ] && [ -n "$SORU" ] || { _hata "sor: --kime <AD> --eylem \"<ne yapılacak>\" --soru \"<soru>\" gerekiyor"; exit 1; }
      EYLEM="$(printf '%s' "$EYLEM" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"; SORU="$(printf '%s' "$SORU" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ "${#EYLEM}" -ge 5 ] || { _hata "--eylem en az 5 karakter — hangi geri alınamaz eylem soruya bağlanıyor?"; exit 1; }
      [ "${#SORU}" -ge 20 ] || { _hata "--soru en az 20 karakter (baş/son boşluk sayılmaz)"; exit 1; }
      ALANLAR="KIME EYLEM SORU"
    else
      [[ "$SNO" =~ ^[1-9][0-9]{0,3}$ ]] || { _hata "cevap: --no <soru numarası> gerekiyor"; exit 1; }
      eksik=""; for v in KIM KARAR OTURUM SOZ; do [ -n "${!v}" ] || eksik="$eksik --$(printf '%s' "$v" | tr 'A-Z' 'a-z')"; done
      [ -z "$eksik" ] || { _hata "eksik:$eksik — kimin, hangi oturumda, hangi sözle cevap verdiği olmadan cevap SAYILMAZ (D1 deseni)"; exit 1; }
      ALANLAR="KIM KARAR OTURUM SOZ"
    fi
    for v in $ALANLAR; do d="${!v}"; if [[ "$d" == *"|"* || "$d" == *$'\n'* ]]; then _hata "--$(printf '%s' "$v" | tr 'A-Z' 'a-z') içinde '|' ya da satır sonu olamaz (defter ayracı)"; exit 1; fi; done
    python3 - "$KD/$IS.json" "$CMD" "$KIME" "$EYLEM" "$SORU" "$SNO" "$KIM" "$KARAR" "$OTURUM" "$SOZ" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY' || exit 1
import json,sys
yol,cmd,kime,eylem,soru,no,kim,karar,oturum,soz,hdir=sys.argv[1:]
sys.path.insert(0,hdir); import soru as S
k=json.load(open(yol,encoding="utf-8"))
try:
    if cmd=="sor":
        n=S.sor(k,kime,eylem,soru); msg=f"❓ soru {n} karta bağlandı → {kime}: {eylem}\n   cevap gelmeden: kart.sh cevap-bekle {k['is']} rc 3 · kart.sh bitti reddeder"
    else:
        s=S.cevapla(k,int(no),kim,karar,oturum,soz); msg=f"{'✓' if karar=='evet' else '✗'} soru {s['no']} cevaplandı: {karar.upper()} · {kim} · oturum {oturum}" + ("" if karar=="evet" else f"\n   eylem koşmaz: {s['eylem']}")
except ValueError as e:
    print(f"✗ {e}",file=sys.stderr); raise SystemExit(1)
k.setdefault("gecmis",[]).append({"zaman":S.simdi(),"olay":cmd})
json.dump(k,open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
print(msg)
PY
    ;;
  cevap-bekle)
    # Makine yüzeyi: İLK satır "ad<TAB>açıklama" (kapı/kanca 2>&1 ile read eder). rc: 0 yok/evet · 3 açık · 4 hayır · 2 okunamadı.
    [ -n "$IS" ] && [ -f "$KD/$IS.json" ] || { _hata "kart yok: $IS"; exit 2; }
    python3 - "$KD/$IS.json" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY'
import json,sys
yol,hdir=sys.argv[1:]; sys.path.insert(0,hdir); import soru as S
try: k=json.load(open(yol,encoding="utf-8"))
except Exception as e: print(f"okunamadi\tkart okunamadı: {e}"); raise SystemExit(2)
ad,ac=S.durum(k); print(ad+"\t"+ac.replace("\n"," ").replace("\t"," "))
raise SystemExit({"yok":0,"evet":0,"acik":3,"hayir":4}[ad])
PY
    ;;
  acik-soru)
    # Ajanın (kartı ALAN) bütün kartlarındaki cevapsız sorular. Kanca dilimi bunu okur: açık soru varken yıkıcı komut koşmaz.
    [ -n "$IS" ] || { _hata "acik-soru <AJAN> — hangi ajanın soruları?"; exit 2; }
    python3 - "$KD" "$IS" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY'
import json,sys,glob,os
kd,ajan,hdir=sys.argv[1:]; sys.path.insert(0,hdir); import soru as S
# 🔴 FAIL-CLOSED (göz #444 tur 1): bu çıktı yıkıcı komut kancasının tek kaynağı olacak. Okunamayan kart (bozuk JSON ya da bozuk
#    sorular listesi) atlanıp rc 0 dönülürse "cevapsız soru yok" yalanı kapıyı açık bırakır → cevapsız soru yoksa ve okunamayan
#    kart varsa rc 2 (ÖLÇÜLEMEDİ). Kimin kartı olduğu okunamıyorsa da sayılır (bozuk kart herkesin kapısını kapatır).
n=0; bozuk=[]
for p in sorted(glob.glob(os.path.join(kd,"*.json"))):
    try:
        k=json.load(open(p,encoding="utf-8"))
        if ajan!="*" and not S.ayni_ad(k.get("aldi"),ajan): continue   # yazım farkı (BERİD/BERID) kartı gizlemez; '*' = HERKES (kimliği çözülemeyen oturum için kanca)
        ac=[(s["no"],s["kime"],s["eylem"],s["zaman"]) for s in S.acik(k)]
    except Exception: bozuk.append(os.path.basename(p)); continue
    for no,kime,eylem,zaman in ac: n+=1; print(f"❓ {k['is']} · soru {no} → {kime}: {eylem} ({zaman}'den beri)")
if n: print(f"── {ajan if ajan!='*' else 'herkes'}: {n} cevapsız soru"); raise SystemExit(3)
if bozuk: print(f"ÖLÇÜLEMEDİ: {len(bozuk)} kart okunamadı ({', '.join(bozuk[:5])}) — 'cevapsız soru yok' DENEMEZ"); raise SystemExit(2)
print(f"◻ {ajan}: cevapsız soru yok"); raise SystemExit(0)
PY
    ;;
  goster) [ -f "$KD/$IS.json" ] && cat "$KD/$IS.json" || { _hata "kart yok: $IS"; exit 3; } ;;
  liste)
    ls "$KD"/*.json >/dev/null 2>&1 || { echo "◻ kart yok"; exit 0; }
    python3 - "$KD" "${ACIK:-0}" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" <<'PY'
import json,sys,glob,os
kd,acik,hdir=sys.argv[1],sys.argv[2]=="1",sys.argv[3]; sys.path.insert(0,hdir); from izin import izin_durumu, siniflimi
for p in sorted(glob.glob(os.path.join(kd,"*.json"))):
    k=json.load(open(p))
    if acik and k["durum"]!="acik": continue
    et=("sınıflı · izin: "+izin_durumu(k)[0]) if siniflimi(k) else "ekip"   # 0.21.0: 'SULTAN' etiketi "Sultan bekliyor" gibi okunuyordu
    print(f"{k['durum']:8} {k['is']:30} {et:24} {k['aldi']:10} {k['zaman'][:16]}  {k['cumle'][:60]}")
PY
    ;;
  *) sed -n '1,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
