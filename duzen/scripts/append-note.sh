#!/usr/bin/env bash
# append-note.sh — bookkeeping dosyalarına Read-gerektirmeyen güvenli ekleme
# (2026-07-03, ARAŞTIRMACI-denetimi #4)
#
# NEDEN: "File has not been read yet" 30 günde 256 gerçek fail'le en büyük tekil hata-sınıfı;
# hedeflerin %57'si zaten append-nitelikli bookkeeping (LEDGER / CONTEXT / plan dosyaları).
# Bu dosyalara not düşmek için Edit yerine bunu kullan — Read gerektirmez, mevcut içeriği
# bozamaz (YALNIZ sona ekler), eşzamanlı yazımda flock ile güvenli.
#
# Kullanım:
#   scripts/append-note.sh <dosya> "tek satırlık not"
#   printf 'çok\nsatırlı\nnot\n' | scripts/append-note.sh <dosya>
#   scripts/append-note.sh -t <dosya> "not"     # başına '## <ISO-zaman>' başlığı ekler
#   _agents/<ajan>/NOTES.md hedefinde günün '## ÇIPA YYYY-MM-DD' başlığı yoksa kendiliğinden yazılır (APPEND_NOTE_CIPA=0 kapatır)
#   _agents/<ajan>/NOTES.md hedefinde '- [AD]' · '- [AD → AD]' · '[AD → AD]' ile başlayan saatsiz satırın ayracına
#     '<gün> <Ay> HH:MM' yazılır: '- [BÂNİ → SERDAR] not' → '- [BÂNİ → SERDAR 23 Eki 15:12] not' (APPEND_NOTE_SAAT=0 kapatır)
set -euo pipefail

ts=0
if [ "${1:-}" = "-t" ]; then ts=1; shift; fi
file="${1:-}"; [ $# -gt 0 ] && shift
[ -n "$file" ] || { echo "kullanım: append-note.sh [-t] <dosya> [metin]" >&2; exit 2; }
[ -f "$file" ] || { echo "HATA: dosya yok: $file (append-note yeni dosya AÇMAZ — yanlış-yol koruması; önce dosyayı oluştur)" >&2; exit 1; }

if [ $# -gt 0 ]; then text="$*"; else text="$(cat)"; fi
[ -n "$text" ] || { echo "HATA: boş metin" >&2; exit 1; }

# NOTES GÜNLÜK BAŞLIĞI (BDX8N · retro W42 BÂNİ Ö4): hedef bir ajan defteriyse (_agents/<ajan>/NOTES.md) ve o günün
#   '## ÇIPA YYYY-MM-DD' satırı dosyada yoksa, eklemeden önce yazılır. Niçin: ajan satırları ('- [AD] HH:MM ·') tarihsizdir;
#   retro/bekçi/havuz günü yalnız üstteki en yakın tarihli satırdan çözer — başlık yoksa ölçüm "tarihsiz, sayılmadı" olur.
#   Yalnız ajan defterine dokunur; APPEND_NOTE_CIPA=0 kapatır; APPEND_NOTE_SIMDI=<epoch> sınav için günü sabitler.
#   🔒 append() içinden, yani flock KRİTİK BÖLÜMÜNDE çağrılır: 'var mı' denetimi ve yazım aynı kilit altındadır — eşzamanlı
#   iki çağrı başlığı iki kez yazamaz (A10 bunu 20 paralel çağrıyla ölçer). flock yoksa kilit de yoktur (eski davranış).
ajan_defteri() { case "$file" in */_agents/*/NOTES.md|_agents/*/NOTES.md) return 0 ;; *) return 1 ;; esac; }

cipa() {
  [ "${APPEND_NOTE_CIPA:-1}" = "0" ] && return 0
  ajan_defteri || return 0
  local gun; gun="$(date -d "@${APPEND_NOTE_SIMDI:-$(date +%s)}" +%F)"
  grep -qx "## ÇIPA $gun" "$file" 2>/dev/null && return 0
  printf '\n## ÇIPA %s\n' "$gun" >> "$file"
}

# SAAT DAMGASI (236W42 · retro W42): ajan defterine yazılan satırın saatini ajan değil ARAÇ yazar. Niçin: ajanlar saati elle
#   yazıyordu, çoğu unutuyor ya da 'HH:MM' yerine '21:4x' gibi yuvarlıyordu; bekçi/retro satırın yaşını saatten çözer, saatsiz
#   satır "ne zaman?" sorusuna cevap vermez. Kural: metin '- [AD]' · '- [AD → AD]' · '[AD → AD]' ile başlıyor ve ayraç
#   İÇİNDE HH:MM yoksa ayraca '<gün> <Ay> HH:MM' eklenir — bekçinin zaten tanıdığı biçim ('[SERDAR → BÂNİ 22 Eki 21:40]',
#   mesaj_basi: ad = ilk sözcük). Zaten saatli satır, başka biçimde başlayan satır ve ajan defteri olmayan dosya aynen kalır.
#   APPEND_NOTE_SAAT=0 kapatır; APPEND_NOTE_SIMDI=<epoch> (ÇIPA ile aynı değişken) sınav için anı sabitler. Yerel saat.
AYLAR=(Oca Şub Mar Nis May Haz Tem Ağu Eyl Eki Kas Ara)
saat_damgasi() {  # → '<gün> <Ay> HH:MM' (ör. '23 Eki 15:12')
  local an; an="${APPEND_NOTE_SIMDI:-$(date +%s)}"
  printf '%s %s %s' "$(date -d "@$an" +%-d)" "${AYLAR[$((10#$(date -d "@$an" +%m) - 1))]}" "$(date -d "@$an" +%H:%M)"
}
saatle() {  # stdin: metin → stdout: ajan-defteri satırlarının ayracına damga eklenmiş metin (öteki satırlar aynen)
  if [ "${APPEND_NOTE_SAAT:-1}" = "0" ] || ! ajan_defteri; then cat; return 0; fi
  local damga line on ic son; damga="$(saat_damgasi)"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^(-[[:space:]]+)?\[([^]]*)\](.*)$ ]]; then
      on="${BASH_REMATCH[1]}"; ic="${BASH_REMATCH[2]}"; son="${BASH_REMATCH[3]}"
      local -a p=(); read -ra p <<<"$ic"
      # biçim kapısı: '[AD]' yalnız tireyle ('- [AD]'); '[AD → AD]' tireli ya da tiresiz. Başka içerik (tarih, saat, üç sözcük…) dokunulmaz.
      if { [ ${#p[@]} -eq 1 ] && [ -n "$on" ]; } || { [ ${#p[@]} -eq 3 ] && [ "${p[1]}" = "→" ]; }; then
        if ! [[ "$ic" =~ [0-9]{2}:[0-9]{2} ]]; then   # saat kapısı: ayraç içinde HH:MM varsa aynen (göz tur 1: '21:4x' saat DEĞİLDİR, damgalanır)
          line="${on}[${ic} ${damga}]${son}"   # SAAT-EKLE
        fi
      fi
    fi
    printf '%s\n' "$line"
  done
}

append() {
  # dosya-sonu newline garantisi (yoksa ekle) — sonra içerik
  if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l | tr -d ' ')" = "0" ]; then printf '\n' >> "$file"; fi
  cipa
  if [ "$ts" -eq 1 ]; then printf '\n## %s\n' "$(date -Iseconds)" >> "$file"; fi
  printf '%s\n' "$text" | saatle >> "$file"
}

if command -v flock >/dev/null 2>&1; then
  { flock 9; append; } 9>>"$file"
else
  append
fi

echo "OK: eklendi → $file (+$(printf '%s\n' "$text" | wc -l | tr -d ' ') satır)"
