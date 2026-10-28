#!/usr/bin/env bash
# gorev.sh — kutu içinden görev defterine TEK KOMUT (dilim 1). Kutu kendi jetonuyla yazar; kimlik jetondan türer.
#   EYLEM TÜRÜ (Engel UX 2. tur B, 20 Eki): 'sıra sende'ye geçen her yazım --eylem onay|soru|komut|mac|bak taşır; türün eki ZORUNLU:
#            soru → --secenekler "A | B" [--oneri "A"] · komut → --komut "<komut>" --nerede "<kutu/terminal>" · mac → --mac-dosya /config/evraklar/Sultan/…md
#            (ac ve durum aynı bayrakları alır; tohum'da 6. sütun eylem)
#   gorev.sh ac "<başlık>" [--kapi dis-kurum|hukuk|ticari|karar] [--sahip sultan|<kutu>] [--ust <gorev_id>] [--durum acik|sira-bende|bekliyor] [--not "<neyi bekliyor>"]
#   gorev.sh ac "<ne lazım>" --kutu <B> --oda <istenen oda> --isteyen-oda <senin odan> --teslim YYYY-MM-DD --dugum <x>   → SİPARİŞ (Oda modeli 5 D2): üçü birlikte; --oda açıkça yazılır, --isteyen-oda verilmezse koltuğunun odası
#            (--durum bekliyor → --not ZORUNLU: defter neyi beklediği yazılmamış 'bekliyor'u reddeder · G12)
#   gorev.sh adim <gorev_id> "<ne yapıldı>" [--dugum <kutu>:<gorev_id>]  → adım EKLENİR (silinmez, değişmez; aynı metin ikinci kez eklenmez)
#   gorev.sh yildiz-oner <gorev_id> [--geri]  → ⭐ ÖNERİR (yıldızı yalnız Sultan koyar, A06) · gorev.sh not-okudum <gorev_id> → Sultan'ın "ajana" notunu okudum damgası
#            (--dugum: bu görev o kutunun görevini serbest bırakmak için çalışıyor → düğüm bağı + adım TEK istekte · 20 Eki)
#   DÜĞÜM AÇAN GÖREV (Sultan 20 Eki): ac/ekle … --dugum mmex:gorev_<kimlik> — bekleyen görev VAR olmalı, kutusu tutmalı, açık olmalı
#            --dugum gorev_<kimlik> (kutusuz) → kutu defterden çözülür (görebildiğin görevse); bekleyen görev AYNI yazımda 'bekliyor ← …' olur
#   PROTOKOL (18:0x): gorev.sh ac "<ne lazım>" --kutu <B> --dugum <x>   (A açar, B taşır)
#   gorev.sh dugum-kabul <y> "<gerekçe>"   → A: teslim tamam, x açılır          (yalnız A: x'in kutusu)
#   gorev.sh dugum-eksik <y> "<ne eksik>"  → A: y B'ye açık döner, x bekler     (yalnız A: x'in kutusu)
#   gorev.sh dugum-geri  <y> "<sebep>"     → B: yapamıyorum, y iptal, x açılır  (yalnız B: y'nin kutusu)
#            A teslimden sonra 2 saat (DEFTER_DUGUM_KABUL_DK) cevap vermezse merkez bekçisi YALNIZ kabul yazar: "[düğüm kendiliğinden kabul]"
#   KİMİ BEKLİYOR (CXE76D K1): 'bekliyor' işe --kimi sultan|serdar|dis-kurum|ci|ajan:<ad> (ne = gerekçe/--not). Yazılmazsa bekliyor yine geçer ama komut ipucu basar; zorunluluk (K2) eski kayıtlar doldurulunca. Ölçüm: bekleyen-kimi-say.sh.
#   gorev.sh durum <gorev_id> <acik|sira-bende|bekliyor|bitti|iptal> "<gerekçe ≥5>" [--kapi karar|hukuk|ticari|dis-kurum]   → önce tashih, sonra adım satırı
#            (bekliyor → gerekçe "neyi bekliyor" sayılır ve `not` alanına da yazılır)
#            (sira-bende → kayıtta kapı türü yoksa --kapi ZORUNLU: defter kapı türsüz 'sıra sende'yi reddeder · G12 mavisi)
#   gorev.sh liste                                      → görebildiğin görevler (kendi kutununkiler; gorev_gorur rolüyle hepsi)
#   gorev.sh sira --oda <oda> [--kutu <kutu>]            → ODA SİPARİŞ SIRASI (Oda 5 D3a · defter 1.39.0): açık siparişler + Sultan'ın o odadaki işleri, tek sıra
#            anahtarıyla (☀ Sultan sınıfı → Sultan'ın aciliyeti → istem sırası); teslim sırayı değiştirmez, geçmişse ⏰ geç. Kutu verilmezse senin kutun.
#   gorev.sh catisma <y1> <y2> "<neden ikisi birden yetişmez ≥10>"  → ÇATIŞMA BEYANI (Oda 5 D3b · defter 1.40.0 · sözleşme §3.2): aynı odada iki açık sipariş,
#            ikisi de Sultan sınıfı DIŞINDA, iki teslim bugün ya da geçmiş; siparişlerin kutusundan. Deftere [⚖ çatışma] iki kayda düşer; ev reisine
#            ulak ile ACİL zil gider (ulak yok/başarısızsa beyan yazılmıştır ama rc 4 — zili elle çal). Sultan işi reddedilir (§3.3).
#   gorev.sh hakem <kazanan> "<gerekçe ≥10>"           → HAKEM (yalnız kutunun reis jetonu, beyandan 60 dk içinde): kazanan iki sipariş arasında önce alınır;
#            süre dolduysa reddedilir, sıra istem sırasıyla yürür. Yalnız bu iki siparişin birbirine göre yeri değişir.
#   gorev.sh dugum <gorev_id>                           → SALT OKUR: düğümün iki ucu · sıra kimde (komutuyla) · bağ iki tarafa yazılmış mı
#            (y verilirse o düğüm, bekleyen x verilirse onu bekleten düğümler · rc 0 TAM · 1 YARIM · 3 ölçülemedi — dugum-bak.py)
#   gorev.sh tohum <dosya.tsv>                          → başlık<TAB>kapi<TAB>sahip[<TAB>durum[<TAB>not[<TAB>eylem]]] satırları (bekliyor → not ZORUNLU); AYNI BAŞLIK zaten varsa ATLAR
#   S-17 (Sultan 14 Eki, Görev Defteri — bulgu = etiketli görev):
#   gorev.sh ekle "<başlık>" --kutu <kutu> [--etiket bug|ozellik|yeni-kutu|bakim|arastirma|kisisel] [--aciliyet cok-acil|acil|esnek|rahat]
#            [--atanan <AJAN>] [--kaynak-kim <Sultan|AJAN>] [--kaynak-nereden "<sohbet|ekran|süreç adı>"] [--eski-no "<S-15 (maiset)|G0034>"]
#   gorev.sh ozet <gorev_id> "<Sultan-dili tek cümle: sebep → ne yapıldı → ne olacak>"  → ozet_sultan tashih; ADIM YAZMAZ, durumu değiştirmez
#            (ac/ekle … --ozet "…" ile açılışta da yazılır; yol/komut/kod terimi defterde reddedilir · Sultan 22 Eki gorev_…1RQHDM)
#   gorev.sh ata <gorev_id> <AJAN> "<gerekçe ≥5>"       → atanan tashih + adım
#   gorev.sh aciliyet <gorev_id> <aciliyet> "<gerekçe>" → aciliyet tashih + adım (kim değiştirdi kayıtta)
#   gorev.sh ustlen <gorev_id> --kim <AJAN> --tahmin <dk>  → atanan + tahmin_dk + durum calisiliyor + adım (tahmin ZORUNLU)
#   gorev.sh bitti <gorev_id> --kim <AJAN> (--kare <yol> --surum <sürüm> [--ekran "…"] | --olcum "…" | --belge <yol>) [--pr N] → kanıt sınıfı + durum onay-bekliyor (✓ bitti yalnız insan, A06); PR tek başına yetmez (KF22R)
#   gorev.sh bulgu "<başlık>" --kim <AJAN> [--not "<kanıt>"] [--etiket bug|ozellik]  → K1: bulgu = etiketli görev (bulgu.sh yaz ile aynı imza)
#   BEĞENİ DÖNGÜSÜ (--etiket begeni-dongusu · Sultan "tamam" diyene dek tur tur giden iş, çoğu ekran/tasarım · tasarım: Nexus _agents/spec/begeni-dongusu-DESIGN.md):
#            her tur TEK adım satırı: gorev.sh adim <id> '[tur N] kare: <yol/url> · Sultan: "<kısa yorum>"'  — karesiz tur yazılmaz/kapanmaz (FABRİKA adım 3)
#            Sultan yorumunu ajan ÜRETMEZ, gördüğünü aktarır (A06/D1) · tur sayısı için üst sınır YOK (göz tavanı 3+1 Sultan turları için değil)
#            kapanış yalnız Sultan "tamam" deyince: ajan bitti ile onay-bekliyor'a çeker, kapatamaz · verim bu turları geri dönüş saymaz, "beğeni turu" sayar
#   15 Eki (rutin + rapor; Sultan: "görevin kaynağı Sultan mı AI ajan mı süzme mi anlaşılmıyor"):
#   gorev.sh ekle … [--kaynak-sinif sultan|ajan|suzme|test|rutin] [--kaynak-rapor SÜZME-2026-W42]
#   gorev.sh rapor "<başlık>" --kod SÜZME-2026-W42 --tur suzme|denetim|ozet [--donem 2026-W42] [--ozet "…"] [--dosya <yol>] [--rutin <rutin_id>]
#   gorev.sh raporlar                                   → raporlar + her birinden doğan görev sayısı
#   gorev.sh rutin "<başlık>" --siklik gunluk|haftalik|aylik [--zaman "Pazartesi 09:00"] [--atanan <AJAN>] [--komut "<ne koşar>"] [--rapor-turu suzme]
#   gorev.sh kosu <rutin_id> "<ne oldu>" [--sonraki 2026-10-22T09:00]  → son_kosu=şimdi (+sonraki) tashih + koşu ADIM satırı, tek istekte
#   gorev.sh rutinler
# Jeton: $DEFTER_JETON_YOL (varsayılan /config/defter-jeton) — değer ekrana/kütüğe düşmez. Uç: $DEFTER_UC.
set -u
UC="${DEFTER_UC:-http://cloudtop-defter:8791}"; JY="${DEFTER_JETON_YOL:-/config/defter-jeton}"
[ -r "$JY" ] || { echo "KIRMIZI: defter jetonu okunamıyor ($JY) — bu kutuya jeton dağıtılmamış" >&2; exit 3; }
J="$(tr -d '\n' < "$JY")"
# YOL BİÇİMİ (kart kanit-yol-bicimi): geçidin YOL_OK eşi — ad.uzantı (ad noktayla başlamaz, uzantı 1-8 harf/rakam) ya da dizin/ad (son parça boş, '.' ya da '..' değil); boşluk yok
yol_mu() { local p="$1"; [ -n "$p" ] || return 1; case "$p" in *[[:space:]]*) return 1;; esac
  case "$p" in /*|*/|*//*|.|..|./*|../*|*/./*|*/../*|*/.|*/..) return 1;; */*) return 0;; *) printf '%s' "$p" | grep -qE '^[^.][^/]*\.[A-Za-z0-9]{1,8}$';; esac; }
_bitti_kullanim() { cat >&2 <<'K'
kullanım: gorev.sh bitti <gorev_id> --kim <AJAN> (--kare <yol> --surum <canlı sürüm> [--ekran "<ekran>"] | --olcum "önce=N sonra=M [dosya]" | --belge <yol>) [--pr N] [--madde N=kanıt ... | --madde-ayri N=gorev_<kimlik> ...] [--ayri gorev_<alt görev kimliği> ...]
  başlıkta (N) numaralı madde varsa HER biri için --madde N=kanıt (bölündüyse --madde-ayri): eksik madde onay kuyruğuna girmez.
  bitti = özellik Sultan'ın ekranında (dilim ≠ görev): ekran işinde canlı kare + sürüm, ölçüm işinde önce ve sonra sayısı (önce=N sonra=M; N/M ya da tek başına dosya yolu yetmez), belge işinde yol. PR numarası tek başına da belgeye sarılı da yetmez.
K
}
_cagir() {  # <metot> <yol> [json]
  if [ -n "${3:-}" ]; then curl -sS -m 15 -X "$1" -H "x-defter-jeton: $J" -H 'content-type: application/json' --data-binary "$3" "$UC$2" -w '\n%{http_code}'
  else curl -sS -m 15 -X "$1" -H "x-defter-jeton: $J" "$UC$2" -w '\n%{http_code}'; fi
}
_sonuc() {  # stdin: gövde+kod · $1: beklenen kod · $2: python ifadesi (j → çıktı)
  python3 -c '
import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
try: j=json.loads(g or "{}")
except Exception: j={"hata":"yanit_bozuk"}
if kod!=sys.argv[1]:
    ek=j.get("ek"); print("KIRMIZI http=%s · %s%s" % (kod, j.get("hata"), (" · "+json.dumps(ek,ensure_ascii=False)) if ek else (" · "+j["yerine"]) if isinstance(j.get("yerine"),str) else (" · "+g[:200] if g else ""))); sys.exit(1)
print(eval(sys.argv[2]))
if isinstance(j.get("uyari"),str) and j["uyari"]: print("⚠ "+j["uyari"])   # defter uyarı kipi (özet kapısı, ZQJR2Y)' "$1" "$2"
}
_jq() { python3 -c 'import sys,json; print(json.dumps(json.loads(sys.argv[1]),ensure_ascii=False))' "$1"; }
_json() { python3 -c 'import sys,json; print(json.dumps(sys.argv[1]))' "$1"; }
_url() { python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
# _sinif_sor <kim> <nereden> → kaynak sınıfı (sunucu kuralı GET /kaynak-sinif; boş = alınamadı/ipucu yok). Kural istemcide KOPYALANMAZ:
#   bulgu da ekle de buradan sorar (göz tur 3: bulgu kararı istemcide tekrar ediyordu). 1.27.0.
_sinif_sor() { _cagir GET "/kaynak-sinif?kim=$(_url "$1")&nereden=$(_url "$2")" 2>/dev/null | python3 -c 'import sys,json
t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
try: print((json.loads(g).get("sinif") or "") if kod=="200" else "")
except Exception: print("")'; }
# --dugum gorev_<id> (kutusuz) → kutuyu defterden çöz; "<kutu>:gorev_<id>" ve boş değer aynen geçer. Göremediğin görev → açık hata.
_dugum_coz() {
  case "${1:-}" in ''|*:*) printf '%s' "${1:-}"; return 0;; esac
  _cagir GET "/kayit/$1" | python3 -c '
import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1); g,kod=(t if len(t)==2 else (t[0],"000"))
if kod!="200": print("KIRMIZI: düğümün bekleyen görevi %s görünmüyor (http %s) — <kutu>:%s biçimiyle ver" % (sys.argv[1], kod, sys.argv[1]), file=sys.stderr); sys.exit(1)
k=json.loads(g)["kayit"]; print("%s:%s" % (k["canli"].get("kutu") or k.get("ekleyen_kutu"), k["id"]), end="")' "$1"
}
# _oda_coz <açık değer> → odanın adı (KUTU–ODA MODELİ · defter 1.36.0). Sıra: açık --oda > GOREV_ODA > yazan koltuğun ekip kaydındaki odası.
#   Bulunamazsa BOŞ döner ve alan hiç yazılmaz (bugünkü davranışla bayt-aynı): kayıt görünmüyorsa (izole kutu) sessizce tahmin edilmez.
#   Koltuk: GOREV_KOLTUK > çıpa aracının sorduğu ajan adı. Ekip kaydı: GOREV_EKIP_KAYDI > Nexus aile-registry.yaml (üye bloğundaki `oda:`).
_oda_coz() {
  if [ -n "${1:-}" ]; then printf '%s' "$1"; return 0; fi
  if [ -n "${GOREV_ODA:-}" ]; then printf '%s' "$GOREV_ODA"; return 0; fi
  local koltuk="${GOREV_KOLTUK:-}" kayit="${GOREV_EKIP_KAYDI:-/config/projects/Nexus/_agents/handoff/aile-registry.yaml}" cipa=/config/.claude/skills/gunluk-plan/scripts/cipa.sh
  if [ -z "$koltuk" ] && [ -f "$cipa" ]; then koltuk="$(bash "$cipa" ajan 2>/dev/null </dev/null | head -1)"; fi
  [ -n "$koltuk" ] && [ -r "$kayit" ] || return 0
  python3 -c 'import sys,re,unicodedata
def n(s): return "".join(c for c in unicodedata.normalize("NFKD", s.casefold()) if not unicodedata.combining(c))
ara=n(sys.argv[1]); bu=None
for s in open(sys.argv[2],encoding="utf-8"):
    m=re.match(r"^\s*-\s+id:\s*(\S+)",s)
    if m: bu=n(m.group(1)); continue
    m=re.match(r"^\s+oda:\s*([a-z][a-z0-9-]{1,30})\s*(#.*)?$",s)
    if m and bu==ara: print(m.group(1),end=""); break' "$koltuk" "$kayit" 2>/dev/null || true
}
_eylem_ekle() {  # <json> <--bayrak> <değer> → json'a alan ekler (değersiz bayrak rc 2)
  [ -n "${3:-}" ] || { echo "$2 değer ister" >&2; return 2; }
  python3 -c 'import sys,json; d=json.loads(sys.argv[1]); d[{"--kimi":"bekleyen_kimi"}.get(sys.argv[2], sys.argv[2].lstrip("-").replace("-","_"))]=sys.argv[3]; print(json.dumps(d,ensure_ascii=False))' "$1" "$2" "$3"
}
_dugum_fiil() {  # <fiil> <y> <gerekçe>
  [ -n "${2:-}" ] && [ "${#3}" -ge 5 ] || { echo "kullanım: gorev.sh dugum-$1 <gorev_id> \"<gerekçe ≥5>\"" >&2; exit 2; }
  G="$(python3 -c 'import sys,json; print(json.dumps({"dugum_fiil":sys.argv[1],"gerekce":sys.argv[2]},ensure_ascii=False))' "$1" "$3")"
  _cagir PATCH "/kayit/$2" "$G" | _sonuc 200 '"⛓ düğüm %s · %s · bekleyen %s %s" % (j["dugum_fiil"], j["kayit"]["canli"].get("gorev_durumu"), j["bekleyen"]["id"], "güncellendi" if j["bekleyen"]["yazildi"] else "DEĞİŞMEDİ — " + j["bekleyen"].get("sebep","zaten güncel"))'
}
case "${1:-}" in
  dugum-kabul) _dugum_fiil kabul "${2:-}" "${3:-}" ;;
  dugum-eksik) _dugum_fiil eksik "${2:-}" "${3:-}" ;;
  dugum-geri)  _dugum_fiil geri  "${2:-}" "${3:-}" ;;
  ac)
    shift; B="${1:-}"; shift || true; KAPI=karar; SAHIP=sultan; UST=""; DURUM=acik; NOTU=""; DUGUM=""; KUTU=""; EY='{}'; KAYNAK=ajan; OZET=""; ODA=""; ISTEYEN=""; TESLIM=""   # KAYNAK: kaynak sınıfı (kart cloudtop-gorev-ac-kaynak-yaz); bu komutu bir AJAN koşar → varsayılan ajan, Sultan'ın isteğini aktarıyorsan --kaynak sultan
    while [ $# -gt 0 ]; do case "$1" in --kapi) KAPI="$2"; shift 2;; --sahip) SAHIP="$2"; shift 2;; --ust) UST="$2"; shift 2;; --durum) DURUM="$2"; shift 2;; --not) NOTU="${2:-}"; shift 2;; --dugum) DUGUM="${2:-}"; shift 2;; --kutu) KUTU="${2:-}"; shift 2;; --oda) [ -n "${2:-}" ] || { echo "--oda değer ister (oda adı, ör. agentic-os)" >&2; exit 2; }; ODA="$2"; shift 2;; --isteyen-oda) [ -n "${2:-}" ] || { echo "--isteyen-oda değer ister (siparişi açan odanın adı, ör. mesajlasma)" >&2; exit 2; }; ISTEYEN="$2"; shift 2;; --teslim) [ -n "${2:-}" ] || { echo "--teslim değer ister (YYYY-MM-DD, İstanbul)" >&2; exit 2; }; TESLIM="$2"; shift 2;; --ozet) OZET="${2:-}"; shift 2;; --kaynak) [ -n "${2:-}" ] || { echo "--kaynak değer ister (sultan|ajan)" >&2; exit 2; }; KAYNAK="$2"; shift 2;;
      --eylem|--secenekler|--oneri|--komut|--nerede|--mac-dosya|--kimi) EY="$(_eylem_ekle "$EY" "$1" "${2:-}")" || exit 2; shift 2;; *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    # SİPARİŞ (Oda modeli 5 D2 · defter 1.38.0 · sözleşme §2): --isteyen-oda ya da --teslim verilen açılış bir siparişdir; oda + isteyen_oda + teslim üçü birlikte
    #   dolu olur. İSTENEN oda (--oda) siparişte varsayılana bırakılmaz (varsayılan isteyenin odasıdır → yanlış uç): AÇIKÇA yazılır. İsteyen oda verilmezse
    #   yazan koltuğun odasıdır (ekip kaydı); o da bulunamazsa sipariş açılmaz. Sipariş işareti yoksa bu blok hiçbir şey yapmaz (bayt-aynı).
    if [ -n "$ISTEYEN" ] || [ -n "$TESLIM" ]; then
      [ -n "$ODA" ] || { echo "sipariş istenen odayı açıkça ister: --oda <istenen oda> (varsayılan isteyenin odasıdır, siparişte yanlış uç olurdu)" >&2; exit 2; }
      [ -n "$TESLIM" ] || { echo "sipariş teslim günü ister: --teslim YYYY-MM-DD (İstanbul)" >&2; exit 2; }
      [ -n "$ISTEYEN" ] || ISTEYEN="$(_oda_coz "")"
      [ -n "$ISTEYEN" ] || { echo "sipariş isteyen odayı ister: --isteyen-oda <senin odan> (koltuğunun odası ekip kaydında bulunamadı)" >&2; exit 2; }
    fi
    DUGUM="$(_dugum_coz "$DUGUM")" || exit 1
    [ -n "$B" ] || { echo "kullanım: gorev.sh ac \"<başlık>\" [--kapi …] [--sahip …] [--ust …] [--durum …] [--not …] [--kaynak sultan|ajan]" >&2; exit 2; }
    G="$(python3 -c 'import sys,json; d={"tur":"gorev","adlar":[sys.argv[1]],"kapi":sys.argv[2],"sahip":sys.argv[3],"gorev_durumu":sys.argv[5]}
if sys.argv[4]: d["ust_gorev_id"]=sys.argv[4]
if sys.argv[6].strip(): d["not"]=sys.argv[6].strip()
if sys.argv[7]: d["dugum_acar"]=sys.argv[7]
if sys.argv[8]: d["kutu"]=sys.argv[8]
d.update(json.loads(sys.argv[9]))
d["kaynak_sinif"]=sys.argv[10]   # ekran "Kaynağı bilinmiyor" demesin; geçerli küme defterde (sultan ajan suzme test rutin), bozuk değer KIRMIZI
if sys.argv[11].strip(): d["ozet_sultan"]=sys.argv[11].strip()
if sys.argv[12]: d["oda"]=sys.argv[12]
if sys.argv[13]: d["isteyen_oda"]=sys.argv[13]
if sys.argv[14]: d["teslim"]=sys.argv[14]
print(json.dumps(d,ensure_ascii=False))' "$B" "$KAPI" "$SAHIP" "$UST" "$DURUM" "$NOTU" "$DUGUM" "$KUTU" "$EY" "$KAYNAK" "$OZET" "$(_oda_coz "$ODA")" "$ISTEYEN" "$TESLIM")"
    _cagir POST /kayit "$G" | _sonuc 201 '"açıldı: %s · %s" % (j["kayit"]["id"], j["kayit"]["adlar"][0]["deger"]) + (("\n  ⛓ bekleyen %s: %s" % (j["dugum_bekleyen"]["id"], "bekliyor notu yazıldı" if j["dugum_bekleyen"]["yazildi"] else "NOT YAZILMADI — " + j["dugum_bekleyen"].get("sebep","?"))) if j.get("dugum_bekleyen") else "")'; rc=$?; [ $rc -ne 0 ] || [ -n "$OZET" ] || echo "ⓘ Sultan-dili özet yok — ekle: gorev.sh ozet <id> \"sebep → ne yapıldı → ne olacak\"" >&2; exit $rc ;;
  ekle)
    shift; B="${1:-}"; shift || true; KUTU=""; ETIKET=""; ACIL=""; ATANAN=""; KKIM=""; KNERE=""; ESKI=""; SAHIP=""; KSINIF=""; KRAPOR=""; DUGUM=""; OZET=""; ODA=""
    while [ $# -gt 0 ]; do case "$1" in
      --kutu) KUTU="${2:-}"; shift 2;; --etiket) ETIKET="${2:-}"; shift 2;; --aciliyet) ACIL="${2:-}"; shift 2;; --atanan) ATANAN="${2:-}"; shift 2;;
      --kaynak-kim) KKIM="${2:-}"; shift 2;; --kaynak-nereden) KNERE="${2:-}"; shift 2;; --eski-no) ESKI="${2:-}"; shift 2;; --sahip) SAHIP="${2:-}"; shift 2;;
      --kaynak-sinif) KSINIF="${2:-}"; shift 2;; --kaynak-rapor) KRAPOR="${2:-}"; shift 2;; --dugum) DUGUM="${2:-}"; shift 2;; --ozet) OZET="${2:-}"; shift 2;; --oda) [ -n "${2:-}" ] || { echo "--oda değer ister (oda adı, ör. agentic-os)" >&2; exit 2; }; ODA="$2"; shift 2;;
      *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    DUGUM="$(_dugum_coz "$DUGUM")" || exit 1
    [ -n "$B" ] && [ -n "$KUTU" ] || { echo "kullanım: gorev.sh ekle \"<başlık>\" --kutu <kutu> [--etiket …] [--aciliyet …] [--atanan …] [--kaynak-kim …] [--kaynak-nereden …] [--eski-no …]" >&2; exit 2; }
    # KAYNAK SINIFI (defter 1.27.0 · gorev_01M5FBXAM080SEVNNFPJP21Q93): ekle komutu sınıfı AÇIKÇA yazar ama kuralı istemcide KOPYALAMAZ —
    #   sunucuya sorar (GET /kaynak-sinif; tek kural: gecit.mjs kaynakSinifTuret = kaynak-goc.py sinif()). --kaynak-nereden verilmediyse
    #   nereden "ekle komutu"dur (bulgu komutu emsali — bu komutu bir ajan koşar) → sınıf ajan; --kaynak-kim Sultan → sultan; nereden
    #   süzme/BUG-AVI/rutin → suzme/test/rutin. Ölçüldü (23 Eki): #766 sonrası sınıfsız doğan 22 görevin 5'i nereden'li ekle, 3'ü
    #   ipuçsuz ekle (SERDAR, --atanan ile) idi. Sunucu ucu cevap vermezse (eski defter) sınıf gönderilmez ve SÖYLENİR — sessiz uydurma yok.
    [ -n "$KNERE" ] || KNERE="ekle komutu"
    if [ -z "$KSINIF" ]; then
      KSINIF="$(_sinif_sor "$KKIM" "$KNERE")"
      [ -n "$KSINIF" ] || echo "not: kaynak sınıfı sunucudan alınamadı (eski defter ya da ipucu yok) — sınıfsız gönderildi; defter 1.27.0 kendi türetir, ipucu yoksa boş kalır" >&2
    fi
    G="$(python3 -c 'import sys,json
b,kutu,et,ac,at,kk,kn,es,sa,ks,kr,dg,oz,od=sys.argv[1:15]
d={"tur":"gorev","adlar":[b],"kutu":kutu,"sahip":sa or kutu,"gorev_durumu":"acik"}
for k,v in (("etiket",et),("aciliyet",ac),("atanan",at),("kaynak_kim",kk),("kaynak_nereden",kn),("eski_no",es),("kaynak_sinif",ks),("kaynak_rapor",kr),("dugum_acar",dg),("ozet_sultan",oz.strip()),("oda",od)):
    if v: d[k]=v
print(json.dumps(d,ensure_ascii=False))' "$B" "$KUTU" "$ETIKET" "$ACIL" "$ATANAN" "$KKIM" "$KNERE" "$ESKI" "$SAHIP" "$KSINIF" "$KRAPOR" "$DUGUM" "$OZET" "$(_oda_coz "$ODA")")"
    _cagir POST /kayit "$G" | _sonuc 201 '"📌 %s · %s · %s · %s — %s · kaynak: %s" % (j["kayit"]["id"], j["kayit"]["canli"].get("kutu",""), j["kayit"]["canli"].get("etiket","tür?"), j["kayit"]["canli"].get("aciliyet","aciliyet?"), j["kayit"]["adlar"][0]["deger"], j["kayit"]["canli"].get("kaynak_sinif") or "sınıfsız")'; rc=$?; [ $rc -ne 0 ] || [ -n "$OZET" ] || echo "ⓘ Sultan-dili özet yok — ekle: gorev.sh ozet <id> \"sebep → ne yapıldı → ne olacak\"" >&2; exit $rc ;;
  ozet)
    [ $# -ge 3 ] && [ -n "${3// /}" ] || { echo "kullanım: gorev.sh ozet <gorev_id> \"<Sultan-dili tek cümle: sebep → ne yapıldı → ne olacak>\"" >&2; exit 2; }
    # tashih (tekil alan, eski özet damgasıyla kayıtta kalır); adimlar YOK → adım yazmaz, durumu değiştirmez (SERDAR tasarımı 22 Eki)
    G="$(python3 -c 'import sys,json; print(json.dumps({"yerine":{"ozet_sultan":sys.argv[1].strip()},"gerekce":"Sultan-dili özet yazıldı"},ensure_ascii=False))' "$3")"
    _cagir PATCH "/kayit/$2" "$G" | _sonuc 200 '"özet yazıldı · adım yazılmadı · durum: %s" % j["kayit"]["canli"].get("gorev_durumu","acik")' ;;
  yildiz-oner)
    # 1.33.0 (YWDW2X): ajan Sultan adına yıldız KOYMAZ (A06) — yalnız önerir; Sultan ekranında ⭐ önerisi görünür, yıldızı Sultan koyar
    ID="${2:-}"; [ -n "$ID" ] || { echo "kullanım: gorev.sh yildiz-oner <gorev_id> [--geri]" >&2; exit 2; }
    V=evet; [ "${3:-}" = "--geri" ] && V=hayir; [ $# -le 3 ] || { echo "bilinmeyen: ${4}" >&2; exit 2; }
    G="$(python3 -c 'import sys,json; print(json.dumps({"yerine":{"onerilen_yildiz":sys.argv[1]},"gerekce":"ajan yıldız önerisi","adimlar":["[yıldız önerisi → %s]" % sys.argv[1]]},ensure_ascii=False))' "$V")"
    _cagir PATCH "/kayit/$ID" "$G" | _sonuc 200 '"⭐ önerisi: %s · Sultan ekranında görünür (yıldızı Sultan koyar)" % j["kayit"]["canli"].get("onerilen_yildiz")' ;;
  not-okudum)
    # 1.33.0 (YWDW2X): Sultan'ın "ajana" notunu okudum damgası — hâl yalnız ileri gider (yeni → okundu → islendi); adım kayda düşer
    ID="${2:-}"; [ -n "$ID" ] && [ $# -le 2 ] || { echo "kullanım: gorev.sh not-okudum <gorev_id>" >&2; exit 2; }
    G='{"yerine":{"not_ajana_hal":"okundu"},"gerekce":"ajana not okundu","adimlar":["[ajana not okundu]"]}'
    _cagir PATCH "/kayit/$ID" "$G" | _sonuc 200 '"✉ not okundu · adım yazıldı"' ;;
  ata)
    [ $# -ge 4 ] && [ "${#4}" -ge 5 ] || { echo "kullanım: gorev.sh ata <gorev_id> <AJAN> \"<gerekçe ≥5>\"" >&2; exit 2; }
    G="$(python3 -c 'import sys,json; print(json.dumps({"yerine":{"atanan":sys.argv[1]},"gerekce":sys.argv[2],"adimlar":["[atandı → %s] %s" % (sys.argv[1], sys.argv[2])]},ensure_ascii=False))' "$3" "$4")"
    _cagir PATCH "/kayit/$2" "$G" | _sonuc 200 '"atanan: %s · adım yazıldı" % j["kayit"]["canli"].get("atanan")' ;;
  aciliyet)
    [ $# -ge 4 ] && [ "${#4}" -ge 5 ] || { echo "kullanım: gorev.sh aciliyet <gorev_id> <cok-acil|acil|esnek|rahat> \"<gerekçe ≥5>\"" >&2; exit 2; }
    G="$(python3 -c 'import sys,json; print(json.dumps({"yerine":{"aciliyet":sys.argv[1]},"gerekce":sys.argv[2],"adimlar":["[aciliyet → %s] %s" % (sys.argv[1], sys.argv[2])]},ensure_ascii=False))' "$3" "$4")"
    _cagir PATCH "/kayit/$2" "$G" | _sonuc 200 '"aciliyet: %s · adım yazıldı" % j["kayit"]["canli"].get("aciliyet")' ;;
  ustlen)
    ID="${2:-}"; shift 2 2>/dev/null || { echo "kullanım: gorev.sh ustlen <gorev_id> --kim <AJAN> --tahmin <dk>" >&2; exit 2; }
    KIM=""; TAH=""
    while [ $# -gt 0 ]; do case "$1" in --kim) KIM="${2:-}"; shift 2;; --tahmin) TAH="${2:-}"; shift 2;; *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    [ -n "$ID" ] && [ -n "$KIM" ] && [ -n "$TAH" ] || { echo "kullanım: gorev.sh ustlen <gorev_id> --kim <AJAN> --tahmin <dk> — tahmin ZORUNLU (Sultan: başladıysa tahmini bitiş)" >&2; exit 2; }
    G="$(python3 -c 'import sys,json; print(json.dumps({"yerine":{"atanan":sys.argv[1],"tahmin_dk":sys.argv[2],"gorev_durumu":"calisiliyor"},"gerekce":"%s üstlendi, tahmin %s dk" % (sys.argv[1],sys.argv[2]),"adimlar":["[üstlendi] %s · tahmin %s dk" % (sys.argv[1],sys.argv[2])]},ensure_ascii=False))' "$KIM" "$TAH")"
    _cagir PATCH "/kayit/$ID" "$G" | _sonuc 200 '"▶ çalışılıyor · %s · ~%s dk" % (j["kayit"]["canli"].get("atanan"), j["kayit"]["canli"].get("tahmin_dk"))' ;;
  bitti)
    # DİLİM ≠ GÖREV (KF22R · Sultan D1 21 Eki): bitti = özellik Sultan'ın ekranında. PR birleşmesi dilimdir; kanıt bir SINIF taşır:
    #   ekran işi: --kare <yol> --surum <canlı sürüm> [--ekran "<ekran adı>"] · ölçüm işi: --olcum "önce=N sonra=M (+ dosya yolu)" · belge işi: --belge <yol>
    #   [--pr N] eklenir ama tek başına yetmez. Eski --kanit "…" KALKTI (göz #759 tur 3: sınıf yalnız bayrakla gelir, serbest metinle kaçış yok). Geçit de aynı kuralı sınar (BK1-13).
    ID="${2:-}"; shift 2 2>/dev/null || { _bitti_kullanim; exit 2; }
    KIM=""; KARE=""; SURUM=""; EKRAN=""; OLCUM=""; BELGE=""; PRNO=""; MADDE=(); AYRI=()
    while [ $# -gt 0 ]; do case "$1" in --kim) KIM="${2:-}"; shift 2;; --kanit) echo "--kanit kalktı: kanıt sınıfı bayrakla gelir — --kare <yol> --surum <sürüm> | --olcum \"önce=N sonra=M\" | --belge <yol>" >&2; exit 2;; --kare) KARE="${2:-}"; shift 2;; --surum) SURUM="${2:-}"; shift 2;;
      --ekran) EKRAN="${2:-}"; shift 2;; --olcum) OLCUM="${2:-}"; shift 2;; --belge) BELGE="${2:-}"; shift 2;; --pr) PRNO="${2:-}"; shift 2;;
      --madde) MADDE+=("m:${2:-}"); shift 2;; --madde-ayri) MADDE+=("a:${2:-}"); shift 2;; --ayri) AYRI+=("${2:-}"); shift; [ $# -gt 0 ] && shift;; *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    [ -n "$ID" ] && [ -n "$KIM" ] || { _bitti_kullanim; exit 2; }
    SINIF=""
    if [ -n "$KARE" ] || [ -n "$SURUM" ] || [ -n "$EKRAN" ]; then
      [ -n "$KARE" ] && [ -n "$SURUM" ] || { echo "ekran işinde kare + sürüm BİRLİKTE şart: --kare <yol> --surum <canlı sürüm> (kare hangi sürümün?)" >&2; exit 2; }
      yol_mu "$KARE" || { echo "--kare bir dosya yolu olmalı (ad.uzantı ya da dizin/ad; boşluksuz): $KARE" >&2; exit 2; }
      SINIF="[kare] $KARE · [surum] $SURUM${EKRAN:+ · ekran: $EKRAN}"
    elif [ -n "$OLCUM" ]; then printf '%s' "$OLCUM" | grep -qiE 'önce *= *-?[0-9]+([.,][0-9]+)?([^0-9.,a-zçğıöşü_]|$).*sonra *= *-?[0-9]+([.,][0-9]+)?([^0-9.,a-zçğıöşü_]|$)' || { echo "--olcum ölçümün kendisini taşır: önce=N sonra=M (N, M sayı; N/M yetmez — hangisi önce?); dosya yolu sayıların yanına eklenir, tek başına ölçüm değildir — \"$OLCUM\" bunlardan değil" >&2; exit 2; }; SINIF="[olcum] $OLCUM"
    elif [ -n "$BELGE" ]; then { yol_mu "$BELGE" && ! printf '%s' "$BELGE" | grep -qiE '^ *(pr *)?#?[0-9]+ *$|^ *pr *#?[0-9]+'; } || { echo "--belge bir YOL ister (ad.uzantı ya da dizin/ad; boşluksuz); PR numarası belge değildir, dilimdir: \"$BELGE\"" >&2; exit 2; }; SINIF="[belge] $BELGE"
    elif [ -n "$PRNO" ]; then echo "kanıt sınıfı yok — PR birleşmesi dilimdir, görev değil: --kare <yol> --surum <sürüm> | --olcum \"önce=N sonra=M\" | --belge <yol>" >&2; exit 2
    else _bitti_kullanim; exit 2; fi
    # BAŞLIK MADDELERİ (retro W42 MUHAKKİK Ö2 · …42BBPK): başlıkta (1)(2).. numaralı madde varsa her biri için --madde N=kanıt (bölündüyse --madde-ayri N=gorev_<kimlik>)
    for m in "${MADDE[@]:-}"; do [ -n "$m" ] || continue
      v="${m#*:}"; n="${v%%=*}"; x="${v#*=}"
      { [[ "$n" =~ ^[0-9]{1,2}$ ]] && [ "$x" != "$v" ] && [ -n "$x" ]; } || { echo "--madde$([ "${m%%:*}" = a ] && echo -ayri) N=değer biçiminde olmalı (N sayı): \"$v\"" >&2; exit 2; }
      case "$x" in *·*|*\[*) echo "madde kanıtında '·' ve '[' olamaz: \"$x\"" >&2; exit 2;; esac
      if [ "${m%%:*}" = a ]; then [[ "$x" =~ ^gorev_[0-9A-Za-z]{10,}$ ]] || { echo "--madde-ayri N=gorev_<kimlik> ister (bölünen işin görev kimliği): \"$x\"" >&2; exit 2; }; SINIF="$SINIF · [madde $n ayri] $x"
      else [ "${#x}" -ge 3 ] || { echo "madde kanıtı en az 3 karakter: \"$v\"" >&2; exit 2; }; SINIF="$SINIF · [madde $n] $x"; fi
    done
    # ön-kontrol (sunucu yine hakemdir): başlıktaki numaralı maddelerden kanıtsız kalan var mı → ağa yazmadan söyle
    EKS="$(_cagir GET "/kayit/$ID" 2>/dev/null | python3 -c '
import sys,json,re
t=sys.stdin.read().rstrip("\n").rsplit("\n",1)
if len(t)!=2 or t[1]!="200": sys.exit(0)
try: ad=[x["deger"] for x in json.loads(t[0])["kayit"]["adlar"]]
except Exception: sys.exit(0)
nums=sorted({int(n) for a in ad for n in re.findall(r"\((\d{1,2})\)",a)})
k=sys.argv[1]
print(",".join(str(n) for n in nums if not (re.search(r"\[madde\s*%d\]\s*[^\s·\[]{3,}"%n,k,re.I) or re.search(r"\[madde\s*%d\s+ayr[ıi]\]\s*gorev_[0-9A-Za-z]{10,}"%n,k,re.I))))' "$SINIF")"
    [ -z "$EKS" ] || { echo "başlıkta numaralı maddeler var; kanıtsız: $EKS — her biri için --madde N=kanıt (bölündüyse --madde-ayri N=gorev_<kimlik>). Eksik madde onay kuyruğuna girmez." >&2; exit 2; }
    # AYRILAN ALT GÖREV (kart alt-gorev-ayri-bayragi · SERDAR 24 Eki, sert kip öncesi): numarasız işte bilerek ayrı işe bırakılan alt görev
    #   --ayri gorev_<kimlik> (tekrarlanabilir) → kanıta "[ayri] <kimlik>"; defterin alt görev kapısı onu engel saymaz, bağ ve durum DEĞİŞMEZ.
    #   Boş değer reddedilir (göz tur 1: "${AYRI[@]:-}" boş dizide tek boş eleman verir; eski "boşsa atla" gerçek boş girdiyi de yutuyordu).
    #   Başlıkta numaralı madde varsa --ayri REDDEDİLİR: o işte bölünen madde --madde-ayri N=<kimlik> ile yazılır, iki yol olmaz (göz tur 1).
    if [ ${#AYRI[@]} -gt 0 ]; then
      NUMLI="$(_cagir GET "/kayit/$ID" 2>/dev/null | python3 -c '
import sys,json,re
t=sys.stdin.read().rstrip("\n").rsplit("\n",1)
if len(t)!=2 or t[1]!="200": sys.exit(0)
try: ad=[x["deger"] for x in json.loads(t[0])["kayit"]["adlar"]]
except Exception: sys.exit(0)
print(",".join(sorted({n for a in ad for n in re.findall(r"\((\d{1,2})\)",a)}, key=int)))')"
      [ -z "$NUMLI" ] || { echo "--ayri yalnız numarasız işte: başlıkta numaralı maddeler var ($NUMLI) — bölünen madde için --madde-ayri N=gorev_<kimlik> kullan" >&2; exit 2; }
    fi
    for a in "${AYRI[@]}"; do
      [ -n "$a" ] || { echo "--ayri değeri boş: --ayri gorev_<kimlik> ister (ayrılan alt görevin tam kimliği)" >&2; exit 2; }
      [[ "$a" =~ ^gorev_[0-9A-Za-z]{10,40}$ ]] || { echo "--ayri gorev_<kimlik> ister (ayrılan alt görevin tam kimliği): \"$a\"" >&2; exit 2; }
      [ "$a" != "$ID" ] || { echo "--ayri görevin kendisi olamaz: $a" >&2; exit 2; }
      SINIF="$SINIF · [ayri] $a"
    done
    [ -n "$PRNO" ] && SINIF="$SINIF · [pr] #${PRNO#\#}"
    # BAŞLIK BAYAT UYARISI (tarama kaydı …E466J · SERDAR 27 Eki: bugün 3 kabul 'başlıktaki sayı ⟷ --olcum' uyuşmazlığından KALDI):
    #   --olcum verilmişse görev başlığındaki sayılar ölçümdeki sayılarla kıyaslanır; ölçümde karşılığı olmayan başlık sayısı varsa
    #   uyarı basılır ve ayrı bir adım olarak kayda düşer. ENGELLEMEZ (rc/PATCH değişmez); başlık okunamazsa sessiz geçer, "temiz" demez.
    BAYAT=""
    if [ -n "$OLCUM" ]; then
      BAYAT="$(_cagir GET "/kayit/$ID" 2>/dev/null | python3 -c '
import sys,json,re
t=sys.stdin.read().rstrip("\n").rsplit("\n",1)
if len(t)!=2 or t[1]!="200": sys.exit(0)
try: ad=[x["deger"] for x in json.loads(t[0])["kayit"]["adlar"]]
except Exception: sys.exit(0)
if not ad: sys.exit(0)
def sayilar(m):
    m=re.sub(r"\(\d{1,2}\)"," ",m); m=re.sub(r"gorev_[0-9A-Za-z]+"," ",m)
    return [x.replace(",",".") for x in re.findall(r"\d+(?:[.,]\d+)?",m)]
b=ad[-1]; bs=sayilar(b); os_=sayilar(sys.argv[1])
ov={float(x) for x in os_}   # 30 ⟷ 30.0 ⟷ 30,0 aynı değer (göz tur 1 bulgu 2)
yok=[x for x in bs if float(x) not in ov]
if yok: print("başlık bayat: başlıkta %s, ölçümde %s" % (",".join(dict.fromkeys(yok)), ",".join(dict.fromkeys(sorted(os_,key=float))) or "yok"))' "$OLCUM")"
      [ -z "$BAYAT" ] || echo "⚠ $BAYAT — başlığı güncelle ya da başlığın sayısını ölçümle açıkla (kapatmayı engellemez)" >&2
    fi
    # ✓ bitti İNSANIN tikidir (K3/A06): kutu 'onay-bekliyor' + kanıt adımını TEK istekte yazar; Sultan ekranı ✓ verir.
    G="$(python3 -c 'import sys,json; print(json.dumps({"yerine":{"gorev_durumu":"onay-bekliyor","kanit":sys.argv[2]},"gerekce":"%s bitirdi; Sultan onayı bekler" % sys.argv[1],"adimlar":["[bitirdi] %s · kanıt: %s" % (sys.argv[1], sys.argv[2])]+(["[uyarı] "+sys.argv[3]] if sys.argv[3] else [])},ensure_ascii=False))' "$KIM" "$SINIF" "$BAYAT")"
    _cagir PATCH "/kayit/$ID" "$G" | _sonuc 200 '"👀 onay bekliyor · %s — ✓ bitti yalnız Sultan ekranından" % j["kayit"]["id"]' ;;
  bulgu)
    # K1 (Sultan 14 Eki): bulgu = türü bug/özellik olan GÖREV. İmza bulgu.sh yaz ile BİREBİR (başlık · --kim · --not) + isteğe bağlı --etiket;
    # kutu = jetonun kutusu (beyan edilemez), kaynak_nereden = "bulgu komutu". Sx'teki bulgu.sh bu fiile ince köprü olur.
    shift; B="${1:-}"; shift || true; KIM=""; NOTU=""; ETIKET="bug"; ODA=""
    while [ $# -gt 0 ]; do case "$1" in --oda) [ -n "${2:-}" ] || { echo "--oda değer ister (oda adı, ör. agentic-os)" >&2; exit 2; }; ODA="$2"; shift 2;; --kim) KIM="${2:-}"; shift 2;; --not) NOTU="${2:-}"; shift 2;; --etiket) ETIKET="${2:-}"; shift 2;; *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    [ -n "$B" ] && [ -n "$KIM" ] || { echo "kullanım: gorev.sh bulgu \"<tek cümle başlık>\" --kim <AJAN> [--not \"<kanıt>\"] [--etiket bug|ozellik]" >&2; exit 2; }
    # 1.27.0: havuz AÇIKÇA (Sultan D1 21 Eki: bulgu Sırada listesine düşmez — imzaya bel bağlanmaz) · sınıf SUNUCUDAN sorulur ve açıkça yazılır
    #   (kural tek yerde; kim Sultan → sultan, ajan adı → ajan); uç cevap vermezse (eski defter) sınıf gönderilmez ve söylenir.
    KSINIF="$(_sinif_sor "$KIM" "bulgu komutu")"
    [ -n "$KSINIF" ] || echo "not: kaynak sınıfı sunucudan alınamadı (eski defter?) — sınıfsız gönderildi; defter 1.27.0 kendi türetir" >&2
    G="$(python3 -c 'import sys,json
b,kim,notu,et,ks,od=sys.argv[1:7]
d={"tur":"gorev","adlar":[b],"etiket":et,"kaynak_kim":kim,"kaynak_nereden":"bulgu komutu","gorev_durumu":"havuz"}   # kutu: sunucu jetondan türetir
if ks: d["kaynak_sinif"]=ks
if od: d["oda"]=od
if notu.strip(): d["adimlar"]=["[kanıt] "+notu.strip()]
print(json.dumps(d,ensure_ascii=False))' "$B" "$KIM" "$NOTU" "$ETIKET" "$KSINIF" "$(_oda_coz "$ODA")")"
    _cagir POST /kayit "$G" | _sonuc 201 '"📌 %s · %s · %s — %s (açan: %s)" % (j["kayit"]["id"], j["kayit"]["canli"].get("kutu") or j["kayit"].get("ekleyen_kutu"), j["kayit"]["canli"].get("etiket"), j["kayit"]["adlar"][0]["deger"], j["kayit"]["canli"].get("kaynak_kim"))' ;;
  adim)
    [ $# -ge 3 ] && [ -n "$(printf '%s' "$3" | tr -d '[:space:]')" ] || { echo "kullanım: gorev.sh adim <gorev_id> \"<ne yapıldı>\" [--dugum <kutu>:<gorev_id>] — boş adım yazılmaz" >&2; exit 2; }
    DUGUM=""; if [ "${4:-}" = "--dugum" ]; then DUGUM="${5:-}"; [ -n "$DUGUM" ] || { echo "--dugum değer ister: <kutu>:gorev_<kimlik>" >&2; exit 2; }; DUGUM="$(_dugum_coz "$DUGUM")" || exit 1; elif [ -n "${4:-}" ]; then echo "bilinmeyen: $4" >&2; exit 2; fi
    # --dugum: bağ TASHİH (gerekçe = adım metni) + adım TEK istekte — ikisi ya birlikte yazılır ya hiç (durum emsali)
    G="$(python3 -c 'import sys,json
a,dg=sys.argv[1:3]; d={"adimlar":[a]}
if dg: d={"yerine":{"dugum_acar":dg},"gerekce":a,"adimlar":["[düğüm → %s] %s" % (dg, a)]}
print(json.dumps(d,ensure_ascii=False))' "$3" "$DUGUM")"
    _cagir PATCH "/kayit/$2" "$G" | _sonuc 200 '(("adım eklendi" if j["degisti"] else "bu adım zaten yazılı") + " · toplam %d" % len(j["kayit"].get("adimlar",[])))' ;;   # adım durumu değiştirmez (defter 1.26.0, YG1); üstlenme: gorev.sh ustlen
  durum)
    [ $# -ge 4 ] || { echo "kullanım: gorev.sh durum <gorev_id> <durum> \"<gerekçe>\" [--kapi <tür>]" >&2; exit 2; }
    DID="$2"; DDUR="$3"; DGER="$4"; shift 4; DKAPI=""; EY='{}'
    while [ $# -gt 0 ]; do case "$1" in
      --kapi) DKAPI="${2:-}"; [ -n "$DKAPI" ] || { echo "--kapi değer ister: karar|hukuk|ticari|dis-kurum" >&2; exit 2; }; shift 2;;
      --eylem|--secenekler|--oneri|--komut|--nerede|--mac-dosya|--kimi) EY="$(_eylem_ekle "$EY" "$1" "${2:-}")" || exit 2; shift 2;;
      *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    case "$DDUR$EY" in bekliyor*bekleyen_kimi*) ;; bekliyor*) echo "ⓘ kimi bekliyor yazılmadı — ekle: --kimi sultan|serdar|dis-kurum|ci|ajan:<ad> (CXE76D K1; şimdilik zorunlu değil)" >&2;; esac
    set -- durum "$DID" "$DDUR" "$DGER"
    # tashih + adım TEK istekte (atomik): ikisi ya birlikte yazılır ya hiç (bağımsız göz tur 2)
    # bekliyor: gerekçe = "neyi bekliyor" → `not` alanına da yazılır (defter notsuz bekliyor'u reddeder · G12)
    G="$(python3 -c 'import sys,json; y={"gorev_durumu":sys.argv[1]}
if sys.argv[1]=="bekliyor": y["not"]=sys.argv[2]
if sys.argv[3]: y["kapi"]=sys.argv[3]
y.update(json.loads(sys.argv[4]))
print(json.dumps({"yerine":y,"gerekce":sys.argv[2],"adimlar":["[%s] %s" % (sys.argv[1], sys.argv[2])]},ensure_ascii=False))' "$3" "$4" "$DKAPI" "$EY")"
    _cagir PATCH "/kayit/$2" "$G" | _sonuc 200 '"durum: %s · %s" % (j["kayit"]["canli"].get("gorev_durumu"), "adım satırı yazıldı" if j.get("adim_yazildi") else "adım zaten yazılıydı")' ;;
  dugum)
    case "${2:-}" in gorev_*) ;; *) echo "kullanım: gorev.sh dugum <gorev_id>" >&2; exit 2;; esac
    DG="$(mktemp)"; trap 'rm -f "$DG"' EXIT
    _cagir GET /gorevler > "$DG.ham" || { rm -f "$DG.ham"; echo "ÖLÇÜLEMEDİ defter okunamadı" ; exit 3; }
    python3 -c '
import sys; t=open(sys.argv[1],encoding="utf-8").read().rstrip("\n").rsplit("\n",1)
if len(t)!=2 or t[1]!="200": print("ÖLÇÜLEMEDİ defter http=%s" % (t[1] if len(t)==2 else "000")); sys.exit(3)
open(sys.argv[2],"w",encoding="utf-8").write(t[0])' "$DG.ham" "$DG"; r=$?; rm -f "$DG.ham"; [ $r = 0 ] || exit 3
    python3 "$(dirname "${BASH_SOURCE[0]}")/dugum-bak.py" "$DG" "$2" "${DUGUM_BAK_SIMDI:-}"; exit $? ;;
  liste)
    _cagir GET /gorevler | _sonuc 200 '"\n".join("%s  %-10s %-14s %-9s %-8s %-10s %s  (son: %s)" % (g["id"], g["canli"].get("kutu") or g.get("ekleyen_kutu",""), g["canli"].get("gorev_durumu",""), g["canli"].get("aciliyet","-"), g["canli"].get("etiket","-"), g["canli"].get("atanan","-"), g["adlar"][0]["deger"], g.get("son_adim","")[:16]) for g in j["gorevler"]) or "görev yok"' ;;
  sira)
    shift; ODA=""; KQ=""
    while [ $# -gt 0 ]; do case "$1" in --oda|--kutu) [ $# -ge 2 ] && [ -n "$2" ] || { echo "$1 bir değer ister" >&2; exit 2; }; [ "$1" = --oda ] && ODA="$2" || KQ="$2"; shift 2;; *) echo "bilinmeyen: $1 (sira --oda <oda> [--kutu <kutu>])" >&2; exit 2;; esac; done
    [ -n "$ODA" ] || { echo "kullanım: gorev.sh sira --oda <oda> [--kutu <kutu>]" >&2; exit 2; }
    _cagir GET "/siparis-sirasi?oda=$(_url "$ODA")${KQ:+&kutu=$(_url "$KQ")}" | _sonuc 200 '("%s/%s · %s · %d iş\n" % (j["kutu"], j["oda"], j["gun"], j["adet"])) + ("\n".join("%2d. %s %s  %-24s %s%s%s" % (x["sira"], "☀" if x["sinif"] == "sultan" else "·", x["id"], (x["isteyen_oda"] and ("← " + (x["ekleyen_kutu"] + "/" if x["ekleyen_kutu"] != j["kutu"] else "") + x["isteyen_oda"])) or "Sultan", x["baslik"], ("  (teslim " + x["teslim"] + (" ⏰ geç" if x["gec"] else "") + ")") if x["teslim"] else "", {"acik": "  ⚖ çatışma: hakem bekleniyor", "karar": "  ⚖ hakem kararı", "sure_doldu": "  ⚖ hakem süresi doldu → istem sırası"}.get((x.get("catisma") or {}).get("hal"), "")) for x in j["sira"]) or "sırada iş yok")' ;;
  catisma)
    [ $# -ge 4 ] || { echo 'kullanım: gorev.sh catisma <y1> <y2> "<neden ikisi birden yetişmez>"' >&2; exit 2; }
    G="$(python3 -c 'import sys,json; print(json.dumps({"catisma_fiil":"beyan","ile":sys.argv[1],"gerekce":sys.argv[2]},ensure_ascii=False))' "$3" "$4")"
    C="$(_cagir PATCH "/kayit/$2" "$G")"
    printf '%s' "$C" | _sonuc 200 '"⚖ çatışma beyan edildi: %s ↔ %s · hakem %s dk içinde: %s" % (j["kayit"]["id"], j["ile"], j["hakem_dk"], j["zil"]["kime"] or "YOK (kutu reisi tanımsız → istem sırası)")' || exit 1
    KIME="$(printf '%s' "$C" | python3 -c 'import sys,json; t=sys.stdin.read().rstrip("\n").rsplit("\n",1)[0]; j=json.loads(t); print(j["zil"]["kime"] or "", j.get("beyan_eden",""), sep="\t")')"
    REIS="${KIME%%	*}"; BEYAN="${KIME#*	}"
    [ -n "$REIS" ] || exit 0
    [ "$REIS" != "$BEYAN" ] || { echo "ⓘ beyanı reisin kendisi yazdı — zil gerekmez"; exit 0; }
    UL="${GOREV_ULAK:-ulak}"
    command -v "$UL" >/dev/null 2>&1 || { echo "⚠ ZİL GİDEMEDİ: ulak yok — beyan defterde, $REIS'e elle haber ver" >&2; exit 4; }
    "$UL" gonder "$REIS" "⚖ çatışma ($BEYAN): $2 ↔ $3 — $4 · karar ≤60 dk: gorev.sh hakem <kazanan> \"<gerekçe>\" · karar yoksa istem sırası yürür" --kimden HARICI --onem acil >/dev/null 2>&1 \
      && echo "🔔 $REIS'e acil zil gitti" || { echo "⚠ ZİL GİDEMEDİ ($UL rc≠0) — beyan defterde, $REIS'e elle haber ver" >&2; exit 4; } ;;
  hakem)
    [ $# -ge 3 ] || { echo 'kullanım: gorev.sh hakem <kazanan sipariş> "<gerekçe>"' >&2; exit 2; }
    G="$(python3 -c 'import sys,json; print(json.dumps({"catisma_fiil":"hakem","gerekce":sys.argv[1]},ensure_ascii=False))' "$3")"
    _cagir PATCH "/kayit/$2" "$G" | _sonuc 200 '"⚖ hakem: %s önce (öteki %s) · beyandan %s dk sonra" % (j["kazanan"], j["oteki"], j["gecen_dk"])' ;;
  rapor)
    shift; B="${1:-}"; shift || true; KOD=""; TUR=""; DON=""; OZ=""; DOS=""; RUT=""
    while [ $# -gt 0 ]; do case "$1" in --kod) KOD="${2:-}"; shift 2;; --tur) TUR="${2:-}"; shift 2;; --donem) DON="${2:-}"; shift 2;; --ozet) OZ="${2:-}"; shift 2;; --dosya) DOS="${2:-}"; shift 2;; --rutin) RUT="${2:-}"; shift 2;; *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    [ -n "$B" ] && [ -n "$KOD" ] && [ -n "$TUR" ] || { echo "kullanım: gorev.sh rapor \"<başlık>\" --kod SÜZME-2026-W42 --tur suzme|denetim|ozet [--donem …] [--ozet …] [--dosya …] [--rutin <rutin_id>]" >&2; exit 2; }
    G="$(python3 -c 'import sys,json
b,kod,tur,don,oz,dos,rut=sys.argv[1:8]
d={"tur":"rapor","adlar":[b],"kod":kod,"rapor_turu":tur}
for k,v in (("rapor_donemi",don),("ozet",oz),("dosya",dos),("rutin_id",rut)):
    if v: d[k]=v
print(json.dumps(d,ensure_ascii=False))' "$B" "$KOD" "$TUR" "$DON" "$OZ" "$DOS" "$RUT")"
    _cagir POST /kayit "$G" | _sonuc 201 '"🗂 %s · %s — %s" % (j["kayit"]["id"], j["kayit"]["canli"].get("kod"), j["kayit"]["adlar"][0]["deger"])' ;;
  raporlar)
    _cagir GET /raporlar | _sonuc 200 '"\n".join("%s  %-18s %-8s %-9s %3d görev  %s" % (r["id"], r["canli"].get("kod",""), r["canli"].get("rapor_turu",""), r["canli"].get("rapor_donemi","-"), len(r.get("bagli_gorevler",[])), r["adlar"][0]["deger"]) for r in j["raporlar"]) or "rapor yok"' ;;
  rutin)
    shift; B="${1:-}"; shift || true; SIK=""; ZAM=""; ATA=""; KOM=""; RTUR=""
    while [ $# -gt 0 ]; do case "$1" in --siklik) SIK="${2:-}"; shift 2;; --zaman) ZAM="${2:-}"; shift 2;; --atanan) ATA="${2:-}"; shift 2;; --komut) KOM="${2:-}"; shift 2;; --rapor-turu) RTUR="${2:-}"; shift 2;; *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    [ -n "$B" ] && [ -n "$SIK" ] || { echo "kullanım: gorev.sh rutin \"<başlık>\" --siklik gunluk|haftalik|aylik [--zaman …] [--atanan …] [--komut …] [--rapor-turu …]" >&2; exit 2; }
    G="$(python3 -c 'import sys,json
b,sik,zam,ata,kom,rt=sys.argv[1:7]
d={"tur":"rutin","adlar":[b],"siklik":sik,"rutin_durumu":"aktif"}
for k,v in (("zaman",zam),("atanan",ata),("komut",kom),("rapor_turu",rt)):
    if v: d[k]=v
print(json.dumps(d,ensure_ascii=False))' "$B" "$SIK" "$ZAM" "$ATA" "$KOM" "$RTUR")"
    _cagir POST /kayit "$G" | _sonuc 201 '"🔁 %s · %s — %s" % (j["kayit"]["id"], j["kayit"]["canli"].get("siklik"), j["kayit"]["adlar"][0]["deger"])' ;;
  kosu)
    ID="${2:-}"; NE="${3:-}"; shift 3 2>/dev/null || { echo "kullanım: gorev.sh kosu <rutin_id> \"<ne oldu>\" [--sonraki …]" >&2; exit 2; }
    SON=""; while [ $# -gt 0 ]; do case "$1" in --sonraki) SON="${2:-}"; shift 2;; *) echo "bilinmeyen: $1" >&2; exit 2;; esac; done
    [ -n "$(printf '%s' "$NE" | tr -d '[:space:]')" ] || { echo "kullanım: gorev.sh kosu <rutin_id> \"<ne oldu>\" — boş koşu yazılmaz" >&2; exit 2; }
    G="$(python3 -c 'import sys,json,datetime
ne,son=sys.argv[1:3]; t=datetime.datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M")
y={"son_kosu":t}
if son: y["sonraki"]=son
print(json.dumps({"yerine":y,"gerekce":"rutin koştu: "+ne,"adimlar":["[koşu] "+ne]},ensure_ascii=False))' "$NE" "$SON")"
    _cagir PATCH "/kayit/$ID" "$G" | _sonuc 200 '"🔁 koşu yazıldı · son %s · sonraki %s" % (j["kayit"]["canli"].get("son_kosu"), j["kayit"]["canli"].get("sonraki","-"))' ;;
  rutinler)
    _cagir GET /rutinler | _sonuc 200 '"\n".join("%s  %-9s %-12s %-16s son:%-16s sonraki:%-16s %s" % (r["id"], r["canli"].get("siklik",""), r["canli"].get("rutin_durumu",""), r["canli"].get("zaman","-"), r["canli"].get("son_kosu","-"), r["canli"].get("sonraki","-"), r["adlar"][0]["deger"]) for r in j["rutinler"]) or "rutin yok"' ;;
  tohum)
    [ -r "${2:-}" ] || { echo "kullanım: gorev.sh tohum <dosya.tsv>" >&2; exit 2; }
    MEVCUT="$(_cagir GET /gorevler | _sonuc 200 '"\n".join(g["adlar"][0]["deger"] for g in j["gorevler"])')" || exit 1
    eklendi=0; atlandi=0; dusen=0
    # 🔴 sekme IFS'de "boşluk" sayılır: art arda iki sekme (boş not sütunu) YUTULUR, eylem nota kayardı → satır \x1f ile bölünür (boş sütun korunur)
    while IFS= read -r satir; do IFS=$'\x1f' read -r baslik kapi sahip durum notu eylem <<<"$(printf '%s' "$satir" | tr '\t' '\037')"
      case "${baslik:-}" in ''|'#'*) continue;; esac
      if printf '%s\n' "$MEVCUT" | grep -qxF "$baslik"; then echo "atlandı (zaten var): $baslik"; atlandi=$((atlandi+1)); continue; fi
      # Düşen satır SAYILIR ve sonuç kodunu kırmızıya çevirir — kısmi tohumlama "başarılı" görünmesin (bağımsız göz).
      # Eklenen başlık MEVCUT kümesine de girer: aynı dosyada iki kez geçen başlık iki kez açılmasın (bağımsız göz, tur 2).
      if bash "$0" ac "$baslik" --kapi "${kapi:-karar}" --sahip "${sahip:-sultan}" --durum "${durum:-acik}" --not "${notu:-}" ${eylem:+--eylem "$eylem"}; then eklendi=$((eklendi+1)); MEVCUT="$MEVCUT
$baslik"; else echo "DÜŞTÜ: $baslik"; dusen=$((dusen+1)); fi
    done < "$2"
    echo "tohum: eklendi=$eklendi atlandı=$atlandi düşen=$dusen"; [ "$dusen" -eq 0 ] ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2;;
esac
