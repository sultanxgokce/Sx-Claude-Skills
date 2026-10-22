#!/usr/bin/env bash
# KHX56 vakası uçtan uca (geçici depo): paylaşılan ağaç ANA DALDA → retro.py kutu iskeleti yazar → ajan Edit'le dolduramaz
# (gerçek ana-dal-kapisi.sh rc 2) → $1 retro.py ile `doldur` denenir. rc 0 = ajan retroyu kapıyı gevşetmeden doldurdu ve lint geçti
# rc 1 = dolduramadı (vaka). Kullanım: vaka.sh <retro.py yolu> [ana-dal-kapisi.sh yolu]
set -u
R="${1:?retro.py yolu}"; KAPI="${2:-/config/projects/Nexus/scripts/hooks/ana-dal-kapisi.sh}"
T="$(mktemp -d)"; trap 'rm -r -f -- "$T"' EXIT
K="$T/depo"; mkdir -p "$K/_agents/mirahur"; printf '# M\n## ÇIPA 2026-10-14\n[MİRAHUR → SERDAR] 10:00 · iş\n' > "$K/_agents/mirahur/NOTES.md"
git -C "$K" init -q -b main && git -C "$K" -c user.email=s@s -c user.name=s commit -q --allow-empty -m ilk
export RETRO_BUGUN=2026-10-17 RETRO_KOK="$K"
python3 "$R" kutu MİRAHUR --koltuk MIRAHUR:0 >/dev/null; echo "kutu rc=$?"
D="$K/_agents/handoff/retro/2026-W42/MİRAHUR.md"
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$D" | bash "$KAPI" 2>/dev/null; echo "ana dal kapısı Edit'e rc=$? (2 = REDDETTİ — kapı yerinde, gevşetilmedi)"
cat > "$T/taslak.md" <<'EOF'
## 1 · Ne bitti
- B1) tmux bekçisi Sx #388 kapıda
## 2 · Nerede zaman kaybettim (ölçüyle)
- Z1) retro iskeletini ana ağaçta dolduramadım · ölçü: 1 kaçış
## 3 · Hangi araç/kural beni yavaşlattı
- A1) ana dal kapısı retro dosyasını düzenletmiyor
## 4 · Ne öğrendim
- D1) kapıyı gevşetme, yazmayı araca ver
## 5 · Merkeze önerim
- Ö1) retro dolumu retro.py doldur ile yapılsın
EOF
python3 "$R" doldur MİRAHUR --metin "$T/taslak.md"; d=$?; echo "doldur rc=$d"
python3 "$R" lint "$D" >/dev/null; l=$?; echo "lint rc=$l"
if [ "$d" = 0 ] && [ "$l" = 0 ]; then echo "SONUÇ: retro kapı gevşetilmeden dolduruldu, geçerli"; exit 0; fi
echo "SONUÇ: ajan retroyu DOLDURAMADI (vaka: kapı Edit'i reddediyor, araçta dolum yolu yok)"; exit 1
