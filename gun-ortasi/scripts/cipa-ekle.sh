#!/usr/bin/env bash
# cipa-ekle.sh — gün ortası maddelerini BUGÜNÜN çıpasına EKLER ya da GERİ ALIR (sabahki maddelere dokunmaz).
#
# 🔴 NİÇİN (kör-1/kör-2, 2026-10-02): gunluk-plan/cipa.sh'ta "ekle" yok — `tazele` yalnız var olan maddeyi
#   değiştirir, `yaz` sabahki çıpayı SİLİP yeniden yazar. Çıpa plan sunulur sunulmaz (onaydan ÖNCE) yazıldığı
#   için Sultan başka şık seçerse önerilen maddeler GERİ ALINABİLMELİ; yoksa akşam kapanışında sahte açık iş kalır.
#     ekle   : son maddenin ARKASINA `- [ ] …`; aynı metin zaten AÇIKSA ikinci kez yazmaz; GERİ ALINMIŞSA yeniden açar
#     geri-al: ETİKETİ birebir eşleşen (`G<n>)`) açık maddeyi `- [-] … → GERİ ALINDI` yapar (iz kalır)
#   Gün ortası maddeleri `G<n>) …` etiketiyle yazılır; sabahın `1) …` maddelerine geri-al DOKUNAMAZ (kör-3 Y2).
#   Çıpa yoksa ya da bugüne ait değilse YAZMAZ (rc=1) — o durumda `cipa.sh yaz` kullanılır.
#   Eşzamanlı yazıma karşı cipa.sh ile AYNI kilidi (`$CIPA.kilit`) alır — iki araç birbirini bekler.
# Yol kuralı cipa.sh'ın KENDİSİNDEN okunur (`cipa.sh yol`) — bu betikte ikinci bir türetme YOK.
#
# KULLANIM: cipa-ekle.sh --plan "G1) madde … | G2) madde …"
#           cipa-ekle.sh --geri-al "G1) | G2)"
# ÇIKIŞ: 0 tamam · 1 çıpa yok/bugüne ait değil/eşleşme yok/yazılamadı · 2 kullanım
set -uo pipefail
BUGUN="${GUNLUK_PLAN_TARIH:-$(date +%F)}"
# 🔴 YOL SORULUR, TÜRETİLMEZ (2026-10-05, MUAVİN onarımı · b0097'nin ikinci yüzü).
#    Bu betik yolu kendisi türetiyordu: `<depo>/_agents/handoff/gunluk-plan-cipa.md`.
#    Ama cipa.sh aynı gün AJAN BAŞINA dosyaya geçti (`…-cipa.<ajan>.md`). Sonuç ölçüldü:
#    ekleme kimsenin OKUMADIĞI eski dosyaya gidiyor ve "ortak kilit" düzeltmesi de fiilen
#    ölüyordu (iki araç iki ayrı kilit dosyası → beklemesi gereken ekleme 9 ms'de geçti).
#    Çare yolu BURADA ikinci kez yazmak DEĞİL — sahibine sormak. Tek kaynak: `cipa.sh yol`.
#    Sorulamıyorsa FAIL-CLOSED: tahminle yazmak, sessizce yanlış dosyaya yazmaktır.
SK="${GUN_ORTASI_SK:-/config/.claude/skills}"
CIPA_ARAC="${GUNLUK_PLAN_CIPA_ARAC:-$SK/gunluk-plan/scripts/cipa.sh}"
[ -f "$CIPA_ARAC" ] || { echo "HATA: cipa.sh bulunamadı ($CIPA_ARAC) — çıpa yolu TAHMİN EDİLMEZ" >&2; exit 1; }
CIPA="$(bash "$CIPA_ARAC" yol 2>/dev/null)"
[ -n "$CIPA" ] || { echo "HATA: cipa.sh 'yol' komutunu desteklemiyor (eski sürüm) — çıpa yolu TAHMİN EDİLMEZ" >&2; exit 1; }
kullanim(){ echo "kullanım: cipa-ekle.sh --plan \"G1) … | G2) …\"  |  --geri-al \"G1) | G2)\"" >&2; exit 2; }
KIP=""; METIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plan|--geri-al) [ $# -ge 2 ] || kullanim; KIP="${1#--}"; METIN="$2"; shift 2 ;;   # değersiz bayrak sonsuz döngü yapıyordu (kör-2 N1)
    *) kullanim ;;
  esac
done
[ -n "$KIP" ] || kullanim
printf '%s' "$METIN" | tr '|' '\n' | grep -q '[^[:space:]]' || { echo "HATA: boş madde listesi" >&2; exit 2; }
# KİLİT cipa.sh ile AYNI dosya (`$CIPA.kilit`): farklı kilit iki aracı birbirinden habersiz
#   bırakır — eşzamanlı ekle/tazele ezişirdi (2026-10-03 ölçüldü). Ortak kilit = karşılıklı dışlama.
# 🔴 DOĞRULAMA KİLİDİN İÇİNDE (bağımsız göz tur 3, 2026-10-05): eskiden varlık ve TARİH
#    kontrolü kilitten ÖNCE yapılıyordu. Kilidi beklerken `cipa.sh yaz` dosyayı BAŞKA bir
#    güne/plana çevirebilir; biz kilidi aldıktan sonra tekrar sormadığımız için gün ortası
#    maddesini YANLIŞ GÜNÜN çıpasına yazardık. Kontrol-sonra-kullan (TOCTOU) açığı.
#    Sıra artık: kilitle → DOĞRULA → yaz.
exec 9>>"$CIPA.kilit" && flock -w 10 9 || { echo "HATA: çıpa kilidi alınamadı" >&2; exit 1; }
[ -f "$CIPA" ] || { echo "HATA: çıpa yok ($CIPA) — önce: cipa.sh yaz --plan …" >&2; exit 1; }
grep -q "GÜNÜN PLANI ÇIPASI · $BUGUN" "$CIPA" || { echo "HATA: çıpa bugüne ait değil — cipa.sh yaz ile bugünün çıpasını aç" >&2; exit 1; }
python3 - "$CIPA" "$KIP" "$METIN" <<'PY'; prc=$?; [ "$prc" -eq 0 ] || exit "$prc"
import sys, re
yol, kip, metin = sys.argv[1:4]
s = open(yol, encoding='utf-8').read().split('\n')
ogeler = [p.strip() for p in metin.split('|') if p.strip()]
ETIKET = re.compile(r'^G[0-9]+\)')
if kip == 'plan' and not all(ETIKET.match(p) and len(p.split(None, 1)) == 2 for p in ogeler):
    sys.stderr.write('HATA: her gün ortası maddesi "G<n>) metin" biçiminde olmalı\n'); sys.exit(2)
if kip == 'geri-al' and not all(re.fullmatch(r'G[0-9]+\)', p) for p in ogeler):
    sys.stderr.write('HATA: geri-al yalnız etiket alır: "G1) | G2)"\n'); sys.exit(2)
govde_al = lambda t: re.sub(r'\s*→ (KAPANDI|YARIM|AÇILMADI|GERİ ALINDI)\b.*$', '', t).strip()
madde = lambda l: re.match(r'^- \[(.)\] (.*)$', l)
idx = [i for i, l in enumerate(s) if madde(l)]
if not idx:
    sys.stderr.write('HATA: çıpada madde satırı yok — biçim tanınmadı\n'); sys.exit(1)
if kip == 'plan':
    durum = {govde_al(madde(s[i]).group(2)): (i, madde(s[i]).group(1)) for i in idx}
    # aynı ETİKET farklı metinle gelemez (kör-4 Y4): ikinci gün ortası turu numarayı kaldığı yerden sürdürür
    etiketler = {}
    for g in durum:
        e = ETIKET.match(g)
        if e: etiketler[e.group(0)] = g
    for p in ogeler:
        e = ETIKET.match(p).group(0)
        if e in etiketler and etiketler[e] != p:
            sys.stderr.write(f'HATA: {e} etiketi çıpada başka metinle var ("{etiketler[e]}") — sıradaki numarayı kullan\n'); sys.exit(2)
    yeni, acilan = [], 0
    for p in ogeler:
        if p in durum and durum[p][1] == '-':          # geri alınmıştı → yeniden aç (kör-3 Y1)
            s[durum[p][0]] = f'- [ ] {p}'; acilan += 1
        elif p not in durum:
            yeni.append(f'- [ ] {p}')
    s[idx[-1]+1:idx[-1]+1] = yeni
    print(f'✓ {len(yeni)} madde eklendi · {acilan} geri alınmış madde yeniden açıldı · {len(ogeler)-len(yeni)-acilan} zaten açıktı')
else:
    n = 0
    for p in ogeler:
        hedef = [i for i in idx if madde(s[i]).group(1) in (' ', '~') and madde(s[i]).group(2).startswith(p + ' ')]
        if len(hedef) > 1:   # çoklu eşleşme: hangisi kastedildi belirsiz → hiçbirine dokunma (kör-4 Y4)
            sys.stderr.write(f'HATA: {p} etiketi {len(hedef)} açık maddeyle eşleşti — hiçbiri geri alınmadı\n'); sys.exit(2)
        for i in hedef:
            s[i] = f'- [-] {govde_al(madde(s[i]).group(2))} → GERİ ALINDI'; n += 1
    if n == 0:
        sys.stderr.write('HATA: geri alınacak açık madde bulunamadı\n'); sys.exit(1)
    print(f'✓ {n} madde geri alındı')
open(yol, 'w', encoding='utf-8').write('\n'.join(s))
PY
