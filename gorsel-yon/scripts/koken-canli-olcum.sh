#!/usr/bin/env bash
# koken-canli-olcum.sh — SIKILAŞTIRMANIN YANLIŞ-KIRMIZI ÜRETMEDİĞİNİ gerçek dosyalarla ölçer.
#
# 🔴 NİÇİN AYRI BETİK (bağımsız göz · jpeg-sos tur-1): sınavın 57 kapısı HERMETİKTİR, yani
#    sentetik fikstürlerle koşar. "Gerçek dosyalarda yanlış-kırmızı yok" cümlesi bambaşka bir
#    iddiadır ve o cümleyi tarifin içine yazmıştım ama kanıt defterinde KARŞILIĞI YOKTU.
#    Elle koşturulmuş bir ölçüm, kayıtsızsa iddia değil anıdır. Bu betik onu ölçülebilir kılar.
#
# KULLANIM: koken-canli-olcum.sh <dizin|dosya…>   (varsayılan: Sultan'ın gelen klasörü)
# ÇIKTI: kaç dosya ayrıştırıldı · kaç 'okunamadi' · biçim ve durum dağılımı · tavan uyarısı
#
# 🔴 BU BETİĞİN ÖLÇTÜĞÜ ŞEY DARDIR (bağımsız göz · jpeg-sos tur-2 rötuşu): sahadaki gerçek
#    dosyaların yapısal ayrıştırmadan geçip geçmediğini sayar. Dosyaların hepsinin GEÇERLİ
#    olduğunu bağımsız bir referansla doğrulamaz ve kapının öteki kararlarına bakmaz.
#    Bu yüzden çıktı "yanlış-kırmızı yok" DEMEZ; "bu kümede okunamadi yok" der. Aradaki fark,
#    vekil-ölçüt tuzağının ta kendisidir: ölçtüğün şeyin adını olduğundan büyük söylemek.
# ÇIKIŞ: 0 hiç 'okunamadi' yok · 1 var (yanlış-kırmızı şüphesi) · 2 ölçülecek dosya yok
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
TAVAN="${KOKEN_OLCUM_TAVAN:-500}"
hedef=("$@"); [ "${#hedef[@]}" -gt 0 ] || hedef=("/config/evraklar/Sultan/0-Gelen")
mapfile -t dosyalar < <(for h in "${hedef[@]}"; do
  if [ -d "$h" ]; then find "$h" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null
  elif [ -f "$h" ]; then printf '%s\n' "$h"; fi
done | head -"$TAVAN")
[ "${#dosyalar[@]}" -gt 0 ] || { echo "HATA: ölçülecek görsel yok" >&2; exit 2; }
# 🔴 TAVAN AÇIKÇA BASILIR: sayım tavana dayandıysa ölçtüğüm şey olay değil TAVANDIR.
echo "ölçülen dosya: ${#dosyalar[@]} (tavan $TAVAN$([ "${#dosyalar[@]}" -eq "$TAVAN" ] && echo ' · TAVANA DAYANDI'))"
python3 "$D/koken.py" "${dosyalar[@]}" --json 2>/dev/null | python3 -c '
import collections, json, sys
d = json.load(sys.stdin)
kayit = d["kayitlar"]
bicim = collections.Counter(str(k["bicim"]) for k in kayit)
durum = collections.Counter(k["koken_durumu"] for k in kayit)
okunamadi = durum.get("okunamadi", 0)
print("biçim :", dict(bicim))
print("durum :", dict(durum))
print(f"okunamadi: {okunamadi}/{len(kayit)}")
if okunamadi:
    print("🔴 YANLIŞ-KIRMIZI ŞÜPHESİ: gerçek dosyalar ayrıştırılamadı — sıkılaştırma fazla sıkı olabilir.")
    for k in kayit:
        if k["koken_durumu"] == "okunamadi": print("   ", k["dosya"])
else:
    print("🟢 ölçülen gerçek dosyaların HİÇBİRİ okunamadi dönmedi.")
    print("   Bu cümlenin kapsamı: yapısal ayrıştırma. Ölçülmeyen: bu dosyaların hepsinin")
    print("   gerçekten geçerli olduğu (bağımsız bir referansla doğrulanmadı) ve kapının")
    print("   öteki kararları. Yani hiç yanlış-kırmızı yok DEĞİL: bu kümede okunamadi yok.")
sys.exit(1 if okunamadi else 0)'
