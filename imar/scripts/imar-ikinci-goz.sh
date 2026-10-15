#!/usr/bin/env bash
# imar-ikinci-goz.sh — İMAR M9: üretenin işini ÇÜRÜTMEYE çalışan bağımsız göz.
#
# NİÇİN VAR (ölçüldü 5-6 Ekim): kapatıcı "yalnız benimki" deyip herkesinkini kapsıyordu;
# alarm sessizce ölüydü; ders kapısı masumu suçladı. Üçünü de ÜRETEN buldu — ama günler sonra.
# Üretenle denetleyen aynı kafa olunca kusur kurulduğu gün görünmüyor.
#
# BAĞIMSIZLIK BU KUTUDA NE DEMEK: codex yok (ölçüldü). "Bağımsız" = üretenin aklını GÖRMEYEN,
# ayrı süreçte, ayrı modelde (sonnet), tek işi çürütmek olan göz. Aynı aile — dürüstçe yazılı.
#
# DEĞİŞMEZ: göz YEŞİL ÜRETMEZ. Üç hüküm: ayakta · çürüdü · ölçülemedi. "Ayakta" = çürütemedim
# demektir, doğru demek değil. Göz koşamazsa hüküm ÖLÇÜLEMEDİ'dir, ayakta değil.
#
# Kullanım: bash scripts/imar-ikinci-goz.sh <tur-ciktisi.md> [--kuru]
# Çıkış: 0 hüküm yazıldı · 1 en az bir ders ÇÜRÜDÜ · 2 kullanım · 3 ÖLÇÜLEMEDİ
#
# "HÜKÜM ÜRETİCİYE ULAŞMADIYSA GÜN ÖLÇÜLEMEDİ'DİR": hüküm dosyası yazılsa bile damga ders defterine
# basılamadıysa (defter yok ya da ders numarası defterde bulunamadı) çıkış 3'tür, 0/1 değil. Niçin:
# sonraki turun brifi defterin damgalarından beslenir; ulaşmayan çürütme AYAKTA diye görünür ve
# üretici onun üstüne inşa eder. Kütük de 0/1'i "ayakta/ÇÜRÜYEN" yazıp günü kusursuz sayardı.
set -uo pipefail
for _d in "$HOME"/.nvm/versions/node/*/bin; do [ -x "$_d/claude" ] && case ":$PATH:" in *":$_d:"*) ;; *) PATH="$_d:$PATH";; esac; done; export PATH

TUR="${1:-}"; KURU=0; [ "${2:-}" = "--kuru" ] && KURU=1
[ -n "$TUR" ] || { echo "kullanım: $0 <tur-ciktisi.md> [--kuru]" >&2; exit 2; }
[ -f "$TUR" ] || { echo "ÖLÇÜLEMEDİ: tur dosyası yok: $TUR" >&2; exit 3; }
EV="${MUNECCIM_EV:?MUNECCIM_EV yok — profil çözülmedi (imar-profil.py cozumle)}"
SERI="$EV/arastirma-serisi"; DERSLER="$SERI/DERSLER.md"; GOZ="$SERI/goz"; mkdir -p "$GOZ"
AD="$(basename "$TUR" .md)"; CIKTI="$GOZ/$AD.goz.json"; BUGUN="$(date +%F)"
DAMGALA=0; for a in "$@"; do [ "$a" = "--damgala" ] && DAMGALA=1; done
# 🔴 ÜSTÜNE YAZMA YOK (ölçüldü 11 Ekim): göz aynı tura ikinci kez koşturulunca ilk hüküm dosyası
# ezildi; iki koşu üç dersin ÜÇÜNDE farklı hüküm vermişti ve ilk hüküm kayboldu. Hüküm bir kayıttır,
# ezilmez: ikinci koşu .goz.2.json'a yazılır ve ilk hükümle farkı basılır (göz tutarsızlığı ölçülür).
if [ "$DAMGALA" = "0" ] && [ -s "$CIKTI" ]; then
  n=2; while [ -s "$GOZ/$AD.goz.$n.json" ]; do n=$((n+1)); done
  ONCEKI="$CIKTI"; CIKTI="$GOZ/$AD.goz.$n.json"
fi

DEVIR="$(python3 - "$TUR" <<'PY'
import re,sys
t=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r"^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?DEV[İI]R[^\n]*$(.*)", t, re.M|re.S)
if m: print(m.group(1).strip())
else:
    # DEVİR üst başlığı şablonda zorunlu değil (ölçüldü 12 Ekim): dört-bölüm içeriği varsa devir odur
    m2=re.search(r"^#{1,4}\s*(?:\d+\s*[·.)\-]\s*)?(?:Ne yaptım|Dersler)\b[^\n]*$", t, re.M|re.I)
    print(t[m2.start():].strip() if m2 else "")
PY
)"
[ -n "$DEVIR" ] || { echo "ÖLÇÜLEMEDİ: turda DEVİR bölümü yok — göz tartacak ders bulamadı" >&2; exit 3; }

BRIF="$(mktemp)"; trap 'rm -f "$BRIF"' EXIT
cat > "$BRIF" <<KURAL
Sen bağımsız bir denetçisin. Aşağıda bir araştırma turunun DEVİR bölümü var: dersler, kanıtları,
çürütme şartları. Üreticinin aklını, niyetini, bağlamını GÖRMÜYORSUN — yalnız metni görüyorsun.
Tek işin: her dersi ÇÜRÜTMEYE çalışmak.

Her ders için şunlara bak:
1. Kanıt gerçekten iddiayı taşıyor mu, yoksa iddia kanıttan daha büyük mü?
2. "Ne olursa çürür" şartı gerçekten sınanabilir mi, yoksa laf mı?
3. Kanıt sınıfı dürüst mü (kaynak mı, ölçüm mü, yoksa yorum mu)?
4. Dersin içinde kendi güven sınırını işaretlemiş mi; işaretlediyse hükmünde bunu dikkate al.

Hükümlerin yalnız şunlardan biri olabilir:
- "ayakta"     = çürütemedim (DOĞRU demek değil)
- "curudu"     = kanıt iddiayı taşımıyor ya da şart sınanamaz — gerekçeyi yaz
- "olculemedi" = metinden karar verilemiyor — neyin eksik olduğunu yaz

Yalnız şu JSON'u ver, başka hiçbir şey yazma:
{"dersler":[{"no":"D-013","hukum":"ayakta|curudu|olculemedi","gerekce":"tek cümle"}], "genel":"tek cümle"}

--- DEVİR ---
$DEVIR
KURAL

if [ "$KURU" = "1" ]; then echo "KURU: brif $(wc -l < "$BRIF") satır · çıktı $CIKTI · model sonnet"; exit 0; fi
if [ "$DAMGALA" = "1" ]; then
  # --damgala: model ÇAĞRILMAZ; var olan hüküm dosyasından damga basılır (yeniden işleme, kazara yeni hüküm üretmez)
  [ -s "$CIKTI" ] || { echo "ÖLÇÜLEMEDİ: damgalanacak hüküm dosyası yok: $CIKTI" >&2; exit 3; }
  HAM="$(cat "$CIKTI")"; RC=0
else
  command -v claude >/dev/null || { echo "ÖLÇÜLEMEDİ: claude yok" >&2; exit 3; }
  HAM="$(timeout 300 claude -p "$(cat "$BRIF")" --model sonnet 2>"$CIKTI.hata")"; RC=$?
fi
if [ "$RC" -ne 0 ] || [ -z "$HAM" ]; then
  echo "ÖLÇÜLEMEDİ: göz koşamadı (rc=$RC)" >&2
  printf '{"tur":"%s","tarih":"%s","hukum":"olculemedi","sebep":"göz koşamadı rc=%s"}\n' "$AD" "$BUGUN" "$RC" > "$CIKTI"
  exit 3
fi
# JSON'u ayıkla (model gevezelik ederse ilk { … son } arası)
python3 - "$HAM" "$CIKTI" "$DERSLER" "$BUGUN" "${ONCEKI:-}" <<'PY'
import json,re,sys,os
ham,cikti,dersler_y,bugun,onceki=sys.argv[1:6]
m=re.search(r"\{.*\}", ham, re.S)
try: d=json.loads(m.group(0)) if m else None
except Exception: d=None
if not d or "dersler" not in d:
    json.dump({"tarih":bugun,"hukum":"olculemedi","sebep":"göz JSON vermedi","ham":ham[:400]}, open(cikti,"w"), ensure_ascii=False)
    print("ÖLÇÜLEMEDİ: göz geçerli hüküm vermedi — ham çıktı kaydedildi", file=sys.stderr); sys.exit(3)
d["tarih"]=bugun; json.dump(d, open(cikti,"w"), ensure_ascii=False, indent=1)
curuyen=sum(1 for h in d["dersler"] if h.get("hukum")=="curudu")
# önceki koşuyla fark: göz tutarsızlığı ÖLÇÜLÜR, gizlenmez
if onceki and os.path.isfile(onceki):
    try:
        o={h.get("no"):h.get("hukum") for h in json.load(open(onceki,encoding="utf-8")).get("dersler",[])}
        fark=[(h.get("no"),o.get(h.get("no")),h.get("hukum")) for h in d["dersler"] if o.get(h.get("no")) and o.get(h.get("no"))!=h.get("hukum")]
        if fark: print("⚠ GÖZ TUTARSIZ: önceki koşuyla %d/%d derste hüküm değişti: %s" % (len(fark),len(d["dersler"])," · ".join("%s %s→%s"%f for f in fark)))
    except Exception as e: print("⚠ önceki hüküm karşılaştırılamadı: %s" % e)
# 🔴 FAIL-CLOSED DAMGA (ölçüldü 10-11 Ekim): ders defteri yoktu, bu blok çöktü, çöküşün çıkış kodu (1)
# "çürüyen ders var" koduyla aynıydı → iki gün üst üste ölçülmemiş şeye hüküm yazıldı. Artık: defter
# yoksa damga atlanır ve SÖYLENİR; beklenmeyen hata = 3 (ölçülemedi), asla 1.
if not os.path.isfile(dersler_y):
    print("ÖLÇÜLEMEDİ: ders defteri YOK (%s) — 0 ders damgalandı, hüküm üreticiye ULAŞMADI · çürüyen %d · genel: %s"
          % (dersler_y,curuyen,d.get("genel","")), file=sys.stderr)
    sys.exit(3)
try:
  s=open(dersler_y,encoding="utf-8").read(); islenen=0; zaten=0
  for h in d["dersler"]:
    no=h.get("no",""); hk=h.get("hukum",""); g=(h.get("gerekce") or "").strip()
    etiket={"ayakta":"ayakta (çürütülemedi)","curudu":"🔴 ÇÜRÜDÜ","olculemedi":"ölçülemedi"}.get(hk,"?")
    # 🔴 İDEMPOTENT (ölçüldü 11 Ekim): eski kontrol damgayı yalnız "Son doğrulama" satırına KADAR arıyordu,
    # damga ondan SONRA duruyor → her koşu yeniden basıyordu (defterde çift damga oluştu). Artık ders bloğunun tamamına bakılır.
    blk=re.search(r"### %s ·.*?(?=\n### |\Z)" % re.escape(no), s, re.S)
    if blk and "İkinci göz:**" in blk.group(0): zaten+=1; continue
    desen=r"(### %s ·.*?\n- \*\*Son doğrulama:\*\*[^\n]*)" % re.escape(no)
    if re.search(desen, s, re.S):
        s=re.sub(desen, lambda mm: mm.group(1)+"\n- **İkinci göz:** %s · %s — %s" % (etiket,bugun,g), s, count=1, flags=re.S); islenen+=1
  open(dersler_y,"w",encoding="utf-8").write(s)
except Exception as e:
  print("ÖLÇÜLEMEDİ: damga basılamadı (%s: %s) — hüküm dosyada (%s), defter değişmedi" % (type(e).__name__, e, cikti), file=sys.stderr); sys.exit(3)
bulunamadi=len(d["dersler"])-islenen-zaten
ozet="%d ders işlendi%s · çürüyen %d · genel: %s" % (islenen, (" · zaten damgalı %d" % zaten) if zaten else "", curuyen, d.get("genel",""))
# 🔴 DAMGA EKSİĞİ = GÜN ÖLÇÜLEMEDİ (ölçüldü 14 Ekim): eski kod "⚠ defterde bulunamadı N" diye UYARIYOR,
# sonra hükmün koduyla (0/1) çıkıyordu. Kütük o kodu "ayakta/ÇÜRÜYEN" diye yazıyor, karne de günü
# KUSURSUZ sayıyordu — yani deftere hiç ulaşmamış bir çürütme damga sayacını ilerletiyordu. Üstelik
# brif ders defterinin damgalarından besleniyor: ulaşmayan çürütme, sonraki tura AYAKTA diye görünür.
# Uyarı bir kapı değildir: hüküm üreticiye ulaşmadıysa gün ÖLÇÜLEMEDİ'dir.
if bulunamadi:
    print("ÖLÇÜLEMEDİ: %d hüküm defterde yerini bulamadı (damga basılamadı, hüküm üreticiye ULAŞMADI) · %s"
          % (bulunamadi, ozet), file=sys.stderr)
    sys.exit(3)
print("göz hükmü: " + ozet)
sys.exit(1 if curuyen else 0)
PY
