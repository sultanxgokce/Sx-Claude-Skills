#!/usr/bin/env bash
# bulgu.sh — filonun tek bulgu komutu (Sultan /goal K2). Kutunun kendi Bulgu Defteri'ne, defterin KENDİ
# kilitli yazıcısıyla (defter-yaz.py) yazar. Yeni yazıcı icat etmez; yalnız kapıdır.
# rc: 0 tamam · 1 yazıcı hatası · 2 kullanım · 3 bu kutuda defter kurulu değil (hiçbir şey yazılmadı)
#     4 kayıt YAZILDI ama düğümün bekleyen görevine "bekliyor" notu yazılamadı (yaz --dugum; defter sebebini söyler)
set -uo pipefail
KOK="${BULGU_KOK:-/config/.ic-sayfa}"
YAZ="$KOK/defter-yaz.py"
JSON="$KOK/bulgu-defteri/bulgular.json"
ALANLAR="id no sayi baslik hal surum acan kaynak acilis tur notlar gecisler"
_kur_yok() { echo "⛔ bu kutuda Bulgu Defteri kurulu değil ($YAZ yok) — hiçbir şey yazılmadı. SERDAR'a yaz: kur.sh --kutu <kutu>" >&2; exit 3; }
k="${1:-}"; shift || true
case "$k" in
  yaz)
    baslik="${1:-}"; shift || true
    [ -n "$baslik" ] || { echo "kullanım: bulgu.sh yaz \"<başlık>\" --kim <AJAN> [--not \"…\"] [--etiket bug|ozellik] [--dugum <kutu>:gorev_<kimlik>|gorev_<kimlik>] [--gorev]" >&2; exit 2; }
    kim=""; notu=""; etiket="bug"; dugum=""; durum="havuz"; gorev=0
    while [ $# -gt 0 ]; do case "$1" in
      --kim) [ $# -ge 2 ] || { echo "--kim değersiz" >&2; exit 2; }; kim="$2"; shift 2 ;;
      --not) [ $# -ge 2 ] || { echo "--not değersiz" >&2; exit 2; }; notu="$2"; shift 2 ;;
      --etiket) [ $# -ge 2 ] || { echo "--etiket değersiz" >&2; exit 2; }; etiket="$2"; shift 2 ;;
      --dugum) [ $# -ge 2 ] && [ -n "$2" ] || { echo "--dugum değersiz" >&2; exit 2; }; dugum="$2"; shift 2 ;;
      --gorev) durum="acik"; gorev=1; shift ;;   # 0.5.0: bulgu değil doğrudan İŞ (Sultan/reis talimatı) → Sırada'ya düşer
      *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
    [ -n "$kim" ] || { echo "--kim zorunlu (kaydı kim açıyor?)" >&2; exit 2; }
    case "$etiket" in bug|ozellik) ;; *) echo "--etiket bug ya da ozellik olmalı (K1: bulgu = bu iki etiketten biriyle görev)" >&2; exit 2 ;; esac
    # ── K1 (Sultan 14 Eki 2026, S-17): bulgu = türü bug/özellik olan GÖREV; TEK defter merkezî Görev Defteri'dir.
    #    Kutuda defter jetonu varsa kayıt ORAYA gider (kutu jetondan türer, beyan edilmez; kaynak_nereden = "bulgu komutu").
    #    Jeton yoksa eski kutu defterine düşer ve bunu SÖYLER — sessiz ikilik yok. Jeton değeri argv'ye/çıktıya düşmez (curl --config).
    JY="${DEFTER_JETON_YOL:-/config/defter-jeton}"; UC="${DEFTER_UC:-http://cloudtop-defter:8791}"
    # ── HAVUZ (0.5.0, Sultan D1 21 Eki "Eleme turu + bulgu kapısı"): bulgu VARSAYILAN olarak 'havuz' durumunda açılır — Sırada'ya
    #    düşmez, haftalık süzmede görev olur ya da iptal. Ölçüm: sırada 212 görevin 151'i bu komuttan 'acik' açılmıştı. --gorev = doğrudan iş.
    #    Düğüm açan kayıt havuzda bekleyemez (başka kutunun bekleyen işini tutuyor) ama tek istisna --gorev'dir (bağımsız göz tur 1):
    #    --dugum'u --gorev'siz vermek RED (rc 2) — sessizce 'acik'a çevrilmez, çağıran açıkça iş olduğunu söyler.
    #    Defter 'havuz'u tanımıyorsa (1.18.0 öncesi) 400 döner ve aşağıdaki ret yolu bunu SÖYLER; sessiz düşüş yok.
    if [ -n "$dugum" ] && [ "$gorev" != 1 ]; then echo "⛔ düğüm açan kayıt havuzda bekleyemez (başka kutunun işini tutuyor): --dugum ile birlikte --gorev ver — kayıt YAZILMADI" >&2; exit 2; fi
    # ── DÜĞÜM (0.4.0, SERDAR 20 Eki F3a): kayıt başka bir kutunun bekleyen görevini serbest bırakmak için açılıyorsa
    #    --dugum <kutu>:gorev_<kimlik> → defterin dugum_acar alanı. Biçim ve varlık kapısı DEFTERDE (burada kural kopyası yok).
    #    Çıplak gorev_<kimlik> verilirse kutu defterden okunur. Düğüm yalnız merkezî defterde yaşar: jetonsuz kutuda RED, sessiz düşmez.
    if [ -n "$dugum" ] && [ ! -r "$JY" ]; then echo "⛔ --dugum yalnız merkezî Görev Defteri'nde yaşar; bu kutuda defter jetonu yok ($JY) — hiçbir şey yazılmadı (SERDAR'a: jeton-dagit)" >&2; exit 2; fi
    if [ -r "$JY" ]; then
      cfg="$(mktemp)"; trap 'rm -f -- "$cfg"' EXIT
      printf 'header = "x-defter-jeton: %s"\n' "$(tr -d '\n' < "$JY")" > "$cfg"
      case "$dugum" in ''|*:*) ;; *)
        [[ "$dugum" =~ ^gorev_[A-Za-z0-9]+$ ]] || { echo "⛔ --dugum <kutu>:gorev_<kimlik> ya da gorev_<kimlik> olmalı: $dugum" >&2; exit 2; }
        cevap="$(curl -sS -m 15 --config "$cfg" "$UC/kayit/$dugum" -w '\n%{http_code}' 2>&1)" || { echo "⛔ düğümün kutusu okunamadı ($UC): $cevap — kayıt YAZILMADI" >&2; exit 1; }
        dugum="$(printf '%s' "$cevap" | python3 -c '
import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
if kod!="200": print("⛔ düğümün bekleyen görevi %s görünmüyor (http %s) — <kutu>:%s biçimiyle ver; kayıt YAZILMADI" % (sys.argv[1], kod, sys.argv[1]), file=sys.stderr); sys.exit(1)
k=json.loads(g)["kayit"]; print("%s:%s" % (k["canli"].get("kutu") or k.get("ekleyen_kutu"), k["id"]), end="")' "$dugum")" || exit 1 ;;
      esac
      govde="$(python3 -c 'import sys,json
b,kim,notu,et,dg,dr=sys.argv[1:7]
d={"tur":"gorev","adlar":[b],"etiket":et,"kaynak_kim":kim,"kaynak_nereden":"bulgu komutu","kaynak_sinif":"ajan","gorev_durumu":dr}
if notu.strip(): d["adimlar"]=["[kanıt] "+notu.strip()]
if dg: d["dugum_acar"]=dg
print(json.dumps(d,ensure_ascii=False))' "$baslik" "$kim" "$notu" "$etiket" "$dugum" "$durum")"
      cevap="$(curl -sS -m 15 --config "$cfg" -X POST -H 'content-type: application/json' --data-binary "$govde" "$UC/kayit" -w '\n%{http_code}' 2>&1)"; rc=$?
      rm -f -- "$cfg"
      if [ $rc -ne 0 ]; then echo "⛔ merkezî Görev Defteri'ne ulaşılamadı ($UC): $cevap — kayıt YAZILMADI (eski deftere de düşmedi: ikilik olmasın; sonra yeniden dene ya da SERDAR'a yaz)" >&2; exit 1; fi
      printf '%s' "$cevap" | python3 -c '
import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
try: j=json.loads(g or "{}")
except Exception: j={"hata":"yanit_bozuk"}
if kod!="201":
    ek=j.get("ek") if isinstance(j.get("ek"),dict) else j   # canlı geçit ek alanlarını düzleştirir (ret): neden/yerine üst düzeyde
    print("⛔ merkezî defter reddetti http=%s · %s · %s" % (kod, j.get("hata"), j.get("bekleniyor") or j.get("alanlar") or ""), file=sys.stderr)
    # defter bağ reddinde sebebi ve çareyi verir (bag_hedefi_yok: neden · yerine) — kullanıcı ne yapacağını görsün
    if ek.get("neden") or ek.get("yerine"): print("   neden: %s%s" % (ek.get("neden") or "?", " · yapılacak: %s" % ek["yerine"] if ek.get("yerine") else ""), file=sys.stderr)
    # 0.5.0: defter havuz durumunu tanimiyorsa (1.18.0 oncesi: alan_degeri_gecersiz, alan gorev_durumu) sebebi ve sirayi soyle; acik durumuna DUSULMEZ
    if j.get("hata")=="alan_degeri_gecersiz" and (ek.get("alan")=="gorev_durumu" or "gorev_durumu" in str(ek.get("bekleniyor") or "")): print("   defter havuz durumunu tanımıyor (defter 1.18.0 öncesi) — önce defteri yenile (cloudtop #762), sonra bu komutu; kayıt YAZILMADI, acik durumuna düşülmedi", file=sys.stderr)
    sys.exit(1)
k=j["kayit"]; print("📌 %s · %s · %s — %s (açan: %s) · Görev Defteri" % (k["id"], k["canli"].get("kutu") or k.get("ekleyen_kutu"), k["canli"].get("etiket"), k["adlar"][0]["deger"], k["canli"].get("kaynak_kim")))
if k["canli"].get("dugum_acar"): print("  ⛓ düğüm: %s" % k["canli"]["dugum_acar"])
b=j.get("dugum_bekleyen")
if b: print("  ⛓ bekleyen %s: %s" % (b.get("id"), "bekliyor notu yazıldı" if b.get("yazildi") else "NOT YAZILMADI — " + str(b.get("sebep","?"))))
if b and not b.get("yazildi"): sys.exit(4)'
    else
      [ -f "$YAZ" ] || _kur_yok
      echo "ℹ bu kutuda defter jetonu yok ($JY) — kayıt ESKİ kutu defterine yazılıyor (merkeze taşınması için SERDAR'a: jeton-dagit)" >&2
      echo "⚠ havuz yalnız merkezî defterde var: bu kayıt eski kutu defterine 'acik' hâliyle düşüyor, Sırada ayrımı UYGULANMADI (--gorev burada anlamsız)" >&2
      if [ -n "$notu" ]; then python3 "$YAZ" yeni --baslik "$baslik" --kim "$kim" --not "$notu" --kok "$KOK"
      else python3 "$YAZ" yeni --baslik "$baslik" --kim "$kim" --kok "$KOK"; fi
    fi ;;
  havuz-cek)
    # ── FİKİR HATTI KÖPRÜSÜ (gorev 4FDVE5 · B16BJ parçası): 22 Eki'den beri bulgular merkezî Görev Defteri'ne düşüyor
    #    ('bulgu komutu', etiket bug/ozellik, durum 'havuz'); bileyi ve mucit-t1 ise yalnız eski bulgu-havuzu.jsonl'u okuyordu →
    #    yeni bulgular fikir hattına HİÇ girmiyordu (Nexus havuzunun son satırı b0143, 8 Eki). Bu komut defterdeki bulgu kayıtlarını
    #    ESKİ HAVUZ BİÇİMİNDE JSONL olarak stdout'a verir; eşleme TEK burada yaşar (iki tüketicide kopyası yok).
    #    Eşleme: id=gorev_id · tarih=oluşturma · baslik=ad · detay+kanit+gercek=ilk [kanıt] adımı · bulan=kaynak_kim · kutu · etiket ·
    #    defter_durumu=asıl durum · durum: 'havuz' → 'ham' (süzülmemiş havuz, mucit'in uygunluk dili), öbürleri aynen (mucit onları ELER).
    #    'sinif' BİLEREK boş: bug/ozellik kaba etiketi sınıf sayımında sahte tekrar üretirdi (bileyi kutu defteri emsali).
    #    eski_no: 14-15 Eki toplu aktarımda kutu Bulgu Defteri'nden taşınan kaydın eski numarası ("S-4 (code)") — tüketici aynı
#    bulguyu kutu defterinden de okuyorsa İKİ KEZ saymasın diye taşınır (ölçüldü: code kutusunun 20 kaydından 15'i defterde).
#    Hangi kayıt bulgudur: kaynak_nereden='bulgu komutu' YA DA etiket bug|ozellik (14-15 Eki toplu aktarım da bulgudur).
    #    rc: 0 tamam (0 kayıt da 0; sayı stderr'de) · 3 ÖLÇÜLEMEDİ (jeton yok · defter ulaşılamadı · yanıt bozuk) — sessiz boş liste YOK.
    JY="${DEFTER_JETON_YOL:-/config/defter-jeton}"; UC="${DEFTER_UC:-http://cloudtop-defter:8791}"
    [ -r "$JY" ] || { echo "🟡 defter jetonu yok ($JY) — defterdeki bulgular ÖLÇÜLEMEDİ" >&2; exit 3; }
    cfg="$(mktemp)"; trap 'rm -f -- "$cfg"' EXIT
    printf 'header = "x-defter-jeton: %s"\n' "$(tr -d '\n' < "$JY")" > "$cfg"
    cevap="$(curl -sS -m 20 --config "$cfg" "$UC/gorevler" -w '\n%{http_code}' 2>&1)" || { echo "🟡 defter ulaşılamadı ($UC) — defterdeki bulgular ÖLÇÜLEMEDİ" >&2; exit 3; }
    rm -f -- "$cfg"
    printf '%s' "$cevap" | python3 -c '
import sys, json
t = sys.stdin.read().rstrip("\n").rsplit("\n", 1); g, kod = (t if len(t) == 2 else (t[0], "000"))
if kod != "200":
    print("🟡 defter okunamadı (http %s) — defterdeki bulgular ÖLÇÜLEMEDİ" % kod, file=sys.stderr); sys.exit(3)
try:
    L = json.loads(g)["gorevler"]
except Exception:
    L = None
if not isinstance(L, list):   # göz #431 tur 1: {"gorevler":{}} de "liste yok"tur — TypeError ile rc 1 değil, ÖLÇÜLEMEDİ
    print("🟡 defter yanıtı bozuk (gorevler listesi yok) — defterdeki bulgular ÖLÇÜLEMEDİ", file=sys.stderr); sys.exit(3)
n = bozuk = 0
for k in L:
    # bozuk öğe (nesne değil · kimliksiz · canli nesne değil) SESSİZCE atlanmaz: sayılır ve söylenir
    if not isinstance(k, dict) or not str(k.get("id") or "").strip() or not isinstance(k.get("canli") or {}, dict):
        bozuk += 1; continue
    try:   # eşleme kayıt başına korunur: adlar/adimlar beklenmedik türde gelirse kayıt BOZUK sayılır, akış çökmez
        c = k.get("canli") or {}
        if not (c.get("kaynak_nereden") == "bulgu komutu" or c.get("etiket") in ("bug", "ozellik")): continue
        ad = ((k.get("adlar") or [{}])[0] or {}).get("deger", "")
        if not str(ad).strip(): continue
        kanit = next((str(a.get("deger", ""))[len("[kanıt] "):] for a in (k.get("adimlar") or []) if str(a.get("deger", "")).startswith("[kanıt] ")), "")
        dd = c.get("gorev_durumu"); dd = dd[-1] if isinstance(dd, list) else dd   # çatışmalı durum: son değer
        satir = json.dumps({"id": k["id"], "tarih": str(k.get("olusturma") or "")[:10], "baslik": ad, "detay": kanit, "kanit": kanit,
                      "gercek": kanit, "bulan": c.get("kaynak_kim") or "", "kutu": c.get("kutu") or k.get("ekleyen_kutu") or "",
                      "etiket": c.get("etiket") or "", "eski_no": str(c.get("eski_no") or ""), "defter_durumu": dd or "", "durum": "ham" if dd == "havuz" else (dd or ""),
                      "kaynak": "defter"}, ensure_ascii=False)
    except (AttributeError, TypeError, IndexError, KeyError):
        bozuk += 1; continue
    print(satir); n += 1
print("· defterden %d bulgu kaydı (%d görev tarandı)" % (n, len(L)) + (" · %d BOZUK kayıt atlandı" % bozuk if bozuk else ""), file=sys.stderr)' ;;
  liste)
    [ -f "$YAZ" ] || _kur_yok; python3 "$YAZ" listele --kok "$KOK" ;;
  hal)
    # Hâl geçişi (13 Eki, MUAVİN): acik → uygulandi → canli; 'onaylandi' İNSANINDIR (A06) — bu kapı onu reddeder.
    [ -f "$YAZ" ] || _kur_yok
    no="${1:-}"; yeni="${2:-}"; shift 2 2>/dev/null || { echo "kullanım: bulgu.sh hal <S-N> <acik|uygulandi|canli> --kim <AJAN> --gerekce \"…\"" >&2; exit 2; }
    case "$yeni" in acik|uygulandi|canli) ;; onaylandi) echo "⛔ 'onaylandi' yalnız insanın tikidir (A06) — ajan yazamaz" >&2; exit 2 ;;
      *) echo "bilinmeyen hâl: $yeni (acik|uygulandi|canli)" >&2; exit 2 ;; esac
    [[ "$no" =~ ^S-[0-9]+$ ]] || { echo "kayıt numarası S-N biçiminde olmalı: $no" >&2; exit 2; }
    kim=""; gerekce=""
    while [ $# -gt 0 ]; do case "$1" in
      --kim) [ $# -ge 2 ] || { echo "--kim değersiz" >&2; exit 2; }; kim="$2"; shift 2 ;;
      --gerekce) [ $# -ge 2 ] || { echo "--gerekce değersiz" >&2; exit 2; }; gerekce="$2"; shift 2 ;;
      *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
    [ -n "$kim" ] || { echo "--kim zorunlu (geçişi kim yapıyor?)" >&2; exit 2; }
    [ -n "$gerekce" ] || { echo "--gerekce zorunlu (niçin bu hâle geçti? kanıt/PR/commit)" >&2; exit 2; }
    python3 "$YAZ" hal "$no" --hal "$yeni" --gerekce "$gerekce" --kim "$kim" --kok "$KOK" ;;
  sema)
    [ -f "${1:-$JSON}" ] || _kur_yok
    python3 - "${1:-$JSON}" "$ALANLAR" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8")); alan = sys.argv[2].split()
b = d.get("bulgular", []) if isinstance(d, dict) else []
ok = [x for x in b if all(k in x for k in alan) and isinstance(x.get("sayi"), int)]
print(json.dumps({"toplam": len(b), "sema_gecen": len(ok), "gecmeyen": len(b) - len(ok),
                  "son_gecen": [x["no"] + " " + str(x.get("acan")) for x in ok[-3:]]}, ensure_ascii=False))
PY
    ;;
  *) sed -n '2,4p' "$0"; echo "komutlar: yaz · havuz-cek · liste · hal · sema"; exit 2 ;;
esac
