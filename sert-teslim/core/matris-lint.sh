#!/bin/sh
# matris-lint.sh — FORMAT-v0 denetçisi (L0: POSIX-sh+awk, MOTOR-sınıfı: proje-bilmez).
# Denetimler: (1) kolon-başlığı birebir; (2) M-satırı 10-hücre; (3) M#-tekilliği;
# (4) durum-enum üyeliği; (5) durum-hücresinde emoji/işaret-yasağı (C8+C12 mirası);
# (6) kanitli-satır -> kanit/<M#>.json VAR; (7) ozet.tsv varsa json_sha256 mekanik-bağı (sha256sum).
# Çıkış: RC=0 temiz; RC=1 ihlal(ler) — hepsi İSİMLİ stderr'e. Kullanım: matris-lint.sh <matris.md> <kanit-dizin>
set -eu

MATRIS="${1:?kullanım: matris-lint.sh <matris.md> <kanit-dizin>}"
KANIT="${2:?kullanım: matris-lint.sh <matris.md> <kanit-dizin>}"

[ -f "$MATRIS" ] || { echo "matris-lint: dosya yok: $MATRIS" >&2; exit 1; }
[ -d "$KANIT" ] || { echo "matris-lint: kanıt-dizini yok: $KANIT" >&2; exit 1; }

IHLAL=0
ihlal() { echo "matris-lint İHLAL: $*" >&2; IHLAL=1; }

BEKLENEN_BASLIK='| M# | C-ID | kaynak-cümle-verbatim | yuzey | kanıt-türü | doğrulama-komutu(+hash) | etki-alanı | veri-rejimi | durum | kanıt-JSON-ref |'

# (1) kolon-başlığı
grep -qF "$BEKLENEN_BASLIK" "$MATRIS" || ihlal "kolon-başlığı FORMAT-v0 ile birebir değil"

# (2)-(6) satır-denetimleri (awk; hücre-ayrımı kaçışsız-'|')
awk -v kanit_dizin="$KANIT" '
BEGIN { FS = "|"; ihlal = 0 }
{
  # M-satırı tespiti: 2. alan " M<sayı> "
  if ($2 !~ /^[ \t]*M[0-9]+[ \t]*$/) next
  m_id = $2; gsub(/[ \t]/, "", m_id)

  # (2) 10-hücre = 12 alan (bas/son boş)
  if (NF != 12) { printf "matris-lint İHLAL: %s hücre-sayısı 10 değil (%d) [satır %d]\n", m_id, NF-2, NR > "/dev/stderr"; ihlal = 1; next }

  # (3) tekillik
  if (m_id in gorulen) { printf "matris-lint İHLAL: %s TEKRAR ediyor [satır %d]\n", m_id, NR > "/dev/stderr"; ihlal = 1 }
  gorulen[m_id] = 1

  # (4) durum-enum
  durum = $10; gsub(/^[ \t]+|[ \t]+$/, "", durum)
  if (durum != "bekliyor" && durum != "kanitli" && durum != "fail" && durum != "engelli" && durum != "OLCULEMEZ") {
    printf "matris-lint İHLAL: %s durum-enum dışı: \"%s\"\n", m_id, durum > "/dev/stderr"; ihlal = 1
  }

  # (5) durum-hücresinde ASCII-dışı karakter yasağı (emoji/işaret — enum zaten saf-ASCII)
  if ($10 ~ /[^ -~]/) { printf "matris-lint İHLAL: %s durum-hücresinde ASCII-dışı karakter (emoji-yasağı, C8+C12 mirası)\n", m_id > "/dev/stderr"; ihlal = 1 }

  # (6) kanitli -> kanıt-JSON var
  if (durum == "kanitli") {
    yol = kanit_dizin "/" m_id ".json"
    if (system("[ -f \"" yol "\" ]") != 0) { printf "matris-lint İHLAL: %s kanitli ama kanıt-JSON yok: %s\n", m_id, yol > "/dev/stderr"; ihlal = 1 }
  }
}
END { exit ihlal }
' "$MATRIS" || IHLAL=1

# (7) TSV mekanik-bağı: ozet.tsv varsa her satırın json_sha256'sı gerçek-dosya-hash'iyle eşleşmeli
TSV="$KANIT/ozet.tsv"
if [ -f "$TSV" ]; then
  # başlık-kontrolü
  head -1 "$TSV" | grep -q "^m_id	durum	rc	json_sha256$" || ihlal "ozet.tsv başlığı beklenen-biçimde değil"
  tail -n +2 "$TSV" | while IFS='	' read -r m_id durum rc hash; do
    [ -n "$m_id" ] || continue
    JSON="$KANIT/$m_id.json"
    if [ "$hash" = "-" ]; then
      [ -f "$JSON" ] && echo "matris-lint İHLAL: $m_id TSV-hash '-' ama JSON var (bayat-TSV — rejenere et)" >&2 && exit 9
    else
      [ -f "$JSON" ] || { echo "matris-lint İHLAL: $m_id TSV-hash var ama JSON yok" >&2; exit 9; }
      GERCEK=$(sha256sum "$JSON" | cut -d' ' -f1)
      [ "$GERCEK" = "$hash" ] || { echo "matris-lint İHLAL: $m_id json_sha256 uyuşmuyor (TSV=önbellek kanonik=JSON — elle-TSV?)" >&2; exit 9; }
    fi
  done || IHLAL=1
fi

if [ "$IHLAL" -eq 0 ]; then
  echo "matris-lint: TEMİZ ($MATRIS)"
  exit 0
fi
exit 1
