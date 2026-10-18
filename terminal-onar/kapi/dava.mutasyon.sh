#!/usr/bin/env bash
# Dava Rafı mutasyon turu: her korumayı tek tek öldür → dava.test.mjs KIRMIZI olmalı. Olmazsa o koruma ölçülmüyor.
# Kaynağa DOKUNMAZ: beceri her bozma için geçici dizine ayrı kopyalanır (kesintide çalışma ağacı mutasyonlu kalmaz).
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], True)" "$T"' EXIT
gecti=0; dusen=0; n=0
dene() {   # ad dosya(kapi/ altında göreli) eski yeni
  local ad="$1" dosya="$2" eski="$3" yeni="$4"; n=$((n+1)); local b="$T/b$n"
  cp -r "$D" "$b"
  ESKI="$eski" YENI="$yeni" python3 -c "
import os,sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();e=os.environ['ESKI']
open(p,'w',encoding='utf-8').write(s.replace(e,os.environ['YENI'],1))" "$b/kapi/$dosya"
  if cmp -s "$b/kapi/$dosya" "$D/kapi/$dosya"; then echo "  ✗ $ad — desen tutmadı"; dusen=$((dusen+1))
  elif node "$b/kapi/dava.test.mjs" >/dev/null 2>&1; then echo "  ✗ $ad — koruma öldü ama sınav YEŞİL"; dusen=$((dusen+1))
  else echo "  ✓ $ad — sınav KIRMIZI"; gecti=$((gecti+1)); fi
}
dene 'M1 Aç yer açmaz (tavan yok sayılır)' kadro.mjs 'if (acik.length < kural.tavan) return null;' 'return null;'
dene 'M2 yer açan dondurma geri alınırken son_calisma artığı kalır' dava.mjs "try { kadroYazKilitAltinda({ proje, id: kisi.id, eylem: 'geri-ac', ek: davaGeriEk(kisi) });" "try { kadroYazKilitAltinda({ proje, id: kisi.id, eylem: 'geri-ac', ek: { dondurma: null } });"
dene 'M3 kişiye bağlama kimliği açıcının okumadığı dosyaya yazar' kadro-yaz.mjs "blokDosyasi(proje, ortam, id, 'session_id')" "blokDosyasi(proje, ortam, id)"
dene 'M4 bekçi personeli de dondurur (rol=dava süzgeci yok)' kadro.mjs "const davaAcik = (k) => k.rol === DAVA_ROL && " "const davaAcik = (k) => "
dene "M5 bağla, iki Claude'lu oturumda ilkini seçer" sunucu.mjs 'if (kim.length !== 1)' 'if (kim.length < 1)'
dene 'M6 bağlamayı geri al, bagla_ile olmayan kaydı da siler' kadro-yaz.mjs "if (!a || a.deger !== 'true') throw new KadroHata(409, 'Bu kayıt bağlamayla gelmedi.');" ''
dene 'M7 hal ucu kilidi bekçiden AYRI dosyada alır (kapı ile bekçi birbirini görmez)' sunucu.mjs "dosyaBirak = dosyaKilit(PROJE, { bekleMs: KILIT_BEKLE_MS })" "dosyaBirak = dosyaKilit(DURUM_DIZ, { bekleMs: KILIT_BEKLE_MS })"
dene 'M8 bekçi turu kilit almaz (kapı yazarken bekçi de yazar)' dava-bekci.mjs "if (!KURU) { try { birak = dosyaKilit(PROJE," "if (false) { try { birak = dosyaKilit(PROJE,"
dene 'M9 dava dondurma kilit altında kilidi YENİDEN ister (kendi kendini kilitler → yer aç 503)' dava.mjs "const s = kadroYazKilitAltinda({ proje, id: kisi.id, eylem: 'dondur'" "const s = kadroYaz({ proje, id: kisi.id, eylem: 'dondur'"
dene 'M10 dava satırı iskana yazılır (eşitleyici ezer, davalar.yaml boş kalır)' kadro-yaz.mjs "const hedef = iskanVar ? davalarYolu(proje, ortam) : dosyalar[0];" "const hedef = dosyalar[0];"
echo; echo "MUTASYON: $gecti yakalandı · $dusen kaçtı"; [ "$dusen" = 0 ]
