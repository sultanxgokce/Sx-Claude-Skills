#!/usr/bin/env bash
# dayanak.test.sh — "eşit" ile "doğrulandı"yı ayıran kapının sınavı. Hermetik, ağa çıkmaz.
#
# 🔴 NİÇİN VAR (ölçüldü 2026-08-25, FAZ 3 envanteri):
#    Kuruş kapısı ÜÇ tanıkla çalışır: topla() · urun_kapisi() · DAYANAK.
#    İlk ikisi aynı varsayımı paylaşır (`ödenecek = matrah + KDV`); kapıya gücünü veren
#    ÜÇÜNCÜSÜDÜR ve o DIŞARIDAN gelir (fiş paketinin gerçek tutarı).
#    Dayanak kalemlerden türetilmişse üçüncü tanık YOKTUR: kapı kendi hesabını kendi
#    hesabıyla karşılaştırır, birebir eşitlik görür, yeşil yakar — ve hiçbir şey kanıtlamaz.
#    ÖLÇÜLMÜŞ VAKA: `TEST_FATURA` dayanağı 12,00 · tek kalemi 10,00 (10 × 1,20 = 12).
#    Gerçek faturaların dayanağı fiş paketindendi. İkisi kodda AYNI biçimdeydi; kapı
#    ikisine de aynı yeşili verdi.
#
#    İkinci kör nokta: yalnız TOPLAM sınanırken `kdv_orani` ile oynayıp kapıyı geçirmek
#    mümkündü. Kapı sayıyı denetler, NİYETİ denetlemez. Kırılım sınaması onu kapatır.
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
python3 - <<'PY'
import sys, io, contextlib; sys.path.insert(0, ".")
from decimal import Decimal as D
from fatura_hazirla import (kurus_kapisi, dayanak_gucu, KurusHatasi,
                            DayanakBeyaniYok, KAYNAKLAR)
G=D_=0
def gec(m):
    global G; G+=1; print(f"  ✓ {m}")
def dus(m):
    global D_; D_+=1; print(f"  ✗ {m}")
def kos(**kw):
    """Kapıyı koşar; İNSAN-UYARILARINI stderr'den toplar.

    🔴 Uyarılar bilerek stderr'e gider: stdout bu hatta VERİ kanalıdır (`kurus.test.sh`
       GEC/RET ayrıştırıyor) ve bir kapının insan-mesajı veri kanalına karışırsa onu
       okuyan her aracı bozar. Sınav da o sözleşmeye uyar — stdout'u dinleseydi
       kapıyı değil, kendi yanlış varsayımını ölçerdi.
    """
    b=io.StringIO()
    with contextlib.redirect_stderr(b): o=kurus_kapisi(**kw)
    return o, b.getvalue()

KAL=[("mal","1000.00")]; TOP="1200.00"

print("Y1 🔴 · BEYAN ZORUNLU — beyansız çağrı üretim yapamaz (fail-closed)")
try:
    kurus_kapisi(KAL, TOP, 20); dus("beyansız çağrı GEÇTİ — kapı isteğe bağlı olmuş")
except DayanakBeyaniYok as e:
    gec("beyansız çağrı DayanakBeyaniYok ile durdu")
    gec("hata mesajı geçerli kaynakları sayıyor") if "fis_paketi" in str(e) else dus("kaynak listesi yok")
except Exception as e: dus(f"yanlış istisna: {type(e).__name__}")

print("\nY2 · tanınmayan kaynak da reddedilir (yazım hatası sessizce geçmesin)")
for kotu in ("fis paketi", "FIS_PAKETI", "tahmin", ""):
    try:
        kurus_kapisi(KAL, TOP, 20, dayanak_kaynagi=kotu); dus(f"{kotu!r} kabul edildi")
    except DayanakBeyaniYok: pass
    except Exception as e: dus(f"{kotu!r} → yanlış istisna {type(e).__name__}")
else: gec("dört bozuk kaynak da reddedildi (tam eşleşme şart)")

print("\nY3 🔴 · TÜRETİLMİŞ dayanak — eşitlik sağlanır AMA 'doğrulandı' DEMEZ")
o,c = kos(kalemler=KAL, dayanak_toplam=TOP, kdv_orani=20,
          dayanak_kaynagi="kalemlerden_turetildi")
gec("belge reddedilmedi (meşru kullanım)") if o["odenecek"]==D("1200.00") else dus("hesap bozuldu")
gec("dogrulandi=False") if o["dogrulandi"] is False else dus(f"dogrulandi={o['dogrulandi']} — SESSİZ YEŞİL")
gec("ekrana 'DOĞRULAMADI' basıldı") if "DOĞRULAMADI" in c else dus("uyarı basılmadı — sessiz geçti")
gec("özet kaynağı taşıyor (deftere yazılabilsin)") if o["dayanak_kaynagi"]=="kalemlerden_turetildi" \
  else dus("kaynak özette yok")

print("\nY4 · BAĞIMSIZ dayanak — doğrulandı der")
o,c = kos(kalemler=KAL, dayanak_toplam=TOP, kdv_orani=20, dayanak_kaynagi="fis_paketi")
gec("dogrulandi=True") if o["dogrulandi"] else dus("bağımsız tanık doğrulanmadı sayıldı")
gec("'DOĞRULAMADI' uyarısı BASILMIYOR (yanlış alarm yok)") if "DOĞRULAMADI" not in c \
  else dus("bağımsız dayanakta yanlış uyarı")
gec("tek-tanık notu basılıyor (kırılım verilmedi)") if "tek-tanık" in c else dus("tek-tanık notu yok")
gec("insan_beyani da bağımsız sayılıyor") if dayanak_gucu("insan_beyani") else dus("insan_beyani reddedildi")

print("\nY5 🔴 · KIRILIM KAPISI — toplamı tutturan yanlış oran yakalanıyor mu")
# Gerçek: 1000 matrah + %20 = 1200. Sahte oran %20 yerine başka bir kırılım iddiası:
try:
    kos(kalemler=KAL, dayanak_toplam=TOP, kdv_orani=20, dayanak_kaynagi="fis_paketi",
        dayanak_kirilimi=("900.00","300.00"))          # toplam yine 1200!
    dus("toplam tutuyor diye YANLIŞ KIRILIM geçti — oran-oynatması açık")
except KurusHatasi as e:
    gec("toplam tutsa bile kırılım tutmuyorsa DURUYOR")
    gec("mesaj 'toplamı tutturan oran ≠ doğru fatura' diyor") if "DEĞİLDİR" in str(e) \
      else dus("gerekçe basılmıyor")
o,c = kos(kalemler=KAL, dayanak_toplam=TOP, kdv_orani=20, dayanak_kaynagi="fis_paketi",
          dayanak_kirilimi=("1000.00","200.00"))
gec("doğru kırılım geçiyor") if o["kirilim_sinandi"] else dus("kırılım bayrağı yok")
gec("kırılım sınandıysa tek-tanık notu BASILMIYOR") if "tek-tanık" not in c else dus("gereksiz not")

print("\nY6 · eşitsizlik hâlâ kırmızı (yeni kapı eskisini gevşetmedi)")
try:
    kos(kalemler=KAL, dayanak_toplam="1160.00", kdv_orani=20, dayanak_kaynagi="fis_paketi")
    dus("tevkifatlı fark GEÇTİ — kuruş kapısı gevşemiş")
except KurusHatasi: gec("40,00'lık fark hâlâ durduruluyor")

print(f"\ntoplam={G+D_} geçen={G} düşen={D_}")
sys.exit(1 if D_ else 0)
PY
