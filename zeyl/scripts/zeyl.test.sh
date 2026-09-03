#!/usr/bin/env bash
# zeyl — ÇİFT YÖNLÜ fikstür sınavı.
# 🔴 ALTIN yüz olmadan "her şeye kırmızı de" diyen bir betik de sınavı geçerdi.
#    ALTIN, BOŞ DEFTERİN ONURLU olduğunu ve alarm ÜRETMEDİĞİNİ kilitler — bu birimin
#    en eski kanunu ve gevşemesi en pahalı olan taraf.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
ok(){ if [ "$2" = "$3" ]; then echo "  ✅ $1"; gecen=$((gecen+1))
      else echo "  ❌ $1 — beklenen '$3', gelen '$2'"; kalan=$((kalan+1)); fi; }
kur(){ local t; t="$(mktemp -d)"; mkdir -p "$t/scripts"; cp "$KOK/scripts/zeyl.sh" "$t/scripts/"
       : > "$t/seyir-defteri.jsonl"; printf '%s' "$t"; }
# 2026-09-03 · SÖZLEŞME DEĞİŞTİ: zeyl artık defteri betiğin yanında değil, kardeş araç
# seyir-defteri.sh ile AYNI yerde arıyor (SEYIR_DEFTERI env → yoksa git-kökü → yoksa rc=2).
# Fikstür bu yüzden defteri env ile pinliyor. Değişimin kendisi G-A/G-B kapılarında ölçülüyor.
Z(){ SEYIR_DEFTERI="$1/seyir-defteri.jsonl" bash "$1/scripts/zeyl.sh" "${@:2}"; }

echo "zeyl — çift yönlü fikstür"

# ALTIN 1 — boş defter ONURLU
t="$(kur)"; Z "$t" doktor >/dev/null 2>&1; ok "ALTIN: boş defter → alarm YOK" "$?" "0"
ok "ALTIN: boş defterde özet SESSİZ (sıfır sayaç gürültüdür)" "$(Z "$t" ozet 2>/dev/null | wc -l)" "0"

# ALTIN 2 — yazıp verdikt verilmiş kayıt temiz
t="$(kur)"; Z "$t" yaz "bir gereklilik" >/dev/null 2>&1
id="$(Z "$t" bekleyen | head -1 | cut -d' ' -f1)"
Z "$t" verdikt "$id" acik >/dev/null 2>&1
Z "$t" doktor >/dev/null 2>&1; ok "ALTIN: verdikt verilmiş kayıt → alarm YOK" "$?" "0"

# KIRMIZI 1 — ÇIKIŞ ZORUNLULUĞU: verdiktsiz kayıt ihlaldir
t="$(kur)"; Z "$t" yaz "verdiktsiz kalan" >/dev/null 2>&1
Z "$t" doktor >/dev/null 2>&1; ok "KIRMIZI: verdiktsiz kayıt → ihlal" "$?" "1"

# KIRMIZI 2 — KANIT KAPISI: kanıtsız 'yapıldı' yazılamaz
t="$(kur)"; Z "$t" yaz "iş" >/dev/null 2>&1; id="$(Z "$t" bekleyen | head -1 | cut -d' ' -f1)"
Z "$t" yapildi "$id" >/dev/null 2>&1;                    ok "KIRMIZI: --kanit'sız yapıldı → RED" "$?" "2"
Z "$t" yapildi "$id" --kanit=yok.md >/dev/null 2>&1;     ok "KIRMIZI: çözülemeyen kanıt → RED" "$?" "2"
Z "$t" yapildi "$id" --kanit=scripts/zeyl.sh >/dev/null 2>&1; ok "ALTIN: diskte VAR olan kanıt → kabul" "$?" "0"

# KIRMIZI 3 — sebepsiz düşürme YASAK ("yapmayacağız" bir karardır)
t="$(kur)"; Z "$t" yaz "x" >/dev/null 2>&1; id="$(Z "$t" bekleyen | head -1 | cut -d' ' -f1)"
Z "$t" verdikt "$id" dustu >/dev/null 2>&1;             ok "KIRMIZI: sebepsiz 'dustu' → RED" "$?" "2"
Z "$t" verdikt "$id" dustu --sebep="gerekmiyor" >/dev/null 2>&1; ok "ALTIN: sebepli 'dustu' → kabul" "$?" "0"

# KIRMIZI 4 — SIR KALKANI
t="$(kur)"; Z "$t" yaz "token: sk-ABCDEFGH12345678 kullan" >/dev/null 2>&1
ok "KIRMIZI: sır-deseni taşıyan kayıt → RED" "$?" "2"

# KIRMIZI 5 — kapalı küme + taşma valfi
t="$(kur)"; Z "$t" yaz "x" --kaynak=uydurma >/dev/null 2>&1;  ok "KIRMIZI: küme-dışı kaynak → RED" "$?" "2"
Z "$t" yaz "x" --kaynak=bilinmeyen >/dev/null 2>&1;           ok "KIRMIZI: bilinmeyen ama notsuz → RED" "$?" "2"
Z "$t" yaz "x" --kaynak=bilinmeyen --not="yeni bir tür" >/dev/null 2>&1; ok "ALTIN: bilinmeyen + not → kabul" "$?" "0"

# ÖLÇÜLEMEDİ ≠ TEMİZ
t="$(mktemp -d)"; mkdir -p "$t/scripts"; cp "$KOK/scripts/zeyl.sh" "$t/scripts/"
Z "$t" doktor >/dev/null 2>&1; ok "defter YOK → 'ölçülemedi' (2), 'temiz' DEĞİL" "$?" "2"

# HOŞGÖRÜLÜ OKUYUCU — bozuk satır defteri KÖRLEŞTİRMEZ
t="$(kur)"; printf '## bozuk markdown satiri\n' >> "$t/seyir-defteri.jsonl"
Z "$t" yaz "bozuktan sonra yazilan" >/dev/null 2>&1
ok "bozuk satırdan SONRAKİ kayıt görünüyor" "$(Z "$t" bekleyen | grep -c bozuktan)" "1"



# ── GLOBALLEŞTİRME KAPILARI (2026-09-03, SERDAR) ─────────────────────────────
# Devralınan sürüm defteri betiğin YANINDA arıyordu. Global skill olarak kurulunca
# bu, defteri 15 kutunun paylaştığı ortak dizine düşürürdü (İ1 ihlali). Aşağıdaki
# kapılar yeni sözleşmeyi kilitler — gevşerse kırmızıya döner.

# G-A · git-kökü YOK ve env YOK → rc=2 (ölçülemedi). Ortak-mount'a DÜŞMEZ.
t="$(mktemp -d)"; mkdir -p "$t/scripts"; cp "$KOK/scripts/zeyl.sh" "$t/scripts/"
: > "$t/seyir-defteri.jsonl"
( cd "$t" && env -u SEYIR_DEFTERI bash "$t/scripts/zeyl.sh" doktor ) >/dev/null 2>&1
ok "G-A: git-kökü yoksa rc=2 (ortak dizine düşmez, fail-closed)" "$?" "2"

# G-B · betiğin yanına ASLA defter yazılmaz (yazsaydı skill dizini kirlenirdi)
t2="$(mktemp -d)"; mkdir -p "$t2/kurulum/scripts" "$t2/depo"
cp "$KOK/scripts/zeyl.sh" "$t2/kurulum/scripts/"
: > "$t2/depo/seyir-defteri.jsonl"
SEYIR_DEFTERI="$t2/depo/seyir-defteri.jsonl" ZEYL_KIM=TEST \
  bash "$t2/kurulum/scripts/zeyl.sh" yaz "kapi testi" --kaynak=gun-ici-not >/dev/null 2>&1
ok "G-B: kayıt DEPOYA yazıldı" "$(grep -c 'kapi testi' "$t2/depo/seyir-defteri.jsonl" 2>/dev/null)" "1"
ok "G-B2: kurulum dizinine defter SIZMADI" "$(ls "$t2/kurulum" 2>/dev/null | grep -c seyir-defteri)" "0"

# G-C · kimlik uydurulmaz: MİHENK'e sabitlenmiş ad ARTIK YOK
ok "G-C: kayıtta sabitlenmiş kutu-adı yok" \
   "$(grep -c 'NİŞANCI' "$t2/depo/seyir-defteri.jsonl" 2>/dev/null)" "0"
ok "G-C2: verilen kimlik kayda geçer" \
   "$(grep -c '"kim":"TEST"' "$t2/depo/seyir-defteri.jsonl" 2>/dev/null)" "1"


# G-D · ÖZETİN BASTIĞI REÇETE FİİLEN KOŞMALI (2026-09-03, canlı vaka)
# Devralınan sürüm sabit 'bash scripts/zeyl.sh bekleyen' basıyordu. Global kurulumda
# betik ~/.claude/skills/zeyl/scripts/ altında yaşar; çalışma dizininde 'scripts/zeyl.sh'
# YOKTUR → kimlik bloğu kullanıcıya ÖLÜ BİR YOL gösteriyordu. Bugün canlı görüldü.
# Bu kapı reçeteyi metin olarak değil, KOŞARAK ölçer.
t3="$(mktemp -d)"; mkdir -p "$t3/kurulum/derin/scripts" "$t3/depo"
cp "$KOK/scripts/zeyl.sh" "$t3/kurulum/derin/scripts/"
: > "$t3/depo/seyir-defteri.jsonl"
SEYIR_DEFTERI="$t3/depo/seyir-defteri.jsonl" ZEYL_KIM=TEST \
  bash "$t3/kurulum/derin/scripts/zeyl.sh" yaz "recete kapisi" --kaynak=gun-ici-not >/dev/null 2>&1
RECETE="$(SEYIR_DEFTERI="$t3/depo/seyir-defteri.jsonl" \
  bash "$t3/kurulum/derin/scripts/zeyl.sh" ozet 2>/dev/null | sed -n 's/.*→ verdikt: //p')"
ok "G-D: özet bir reçete basar" "$([ -n "$RECETE" ] && echo var || echo yok)" "var"
# Reçeteyi BAŞKA bir dizinden koş — sabit göreli yol burada ölür, mutlak yol yaşar.
( cd "$t3" && SEYIR_DEFTERI="$t3/depo/seyir-defteri.jsonl" bash $RECETE ) >/dev/null 2>&1
ok "G-D2: basılan reçete BAŞKA dizinden koşulunca ÇALIŞIR (ölü uç değil)" "$?" "0"

echo "── $gecen geçti · $kalan kaldı"
[ "$kalan" = 0 ]
