#!/usr/bin/env bash
# kisi-kur.sh — kısıtlı kişi (Ayşenur) için kutuda KOLTUK KÖPRÜSÜ düzenini kurar (A5-2 · görev …A5Y3P). Host/konteyner KÖK işidir.
#
#   kisi-kur.sh [--kutu K] [--kisi aysenur] [--kullanici ayse] [--uid 2001] [--beceri DİZİN] [--uygula] [--kok DİZİN]
#   VARSAYILAN = KURU KİP: ne yapacağını ADIM ADIM basar, hiçbir şeyi değiştirmez (rc 0). --uygula yalnız Sultan/host elinde, KÖK ile.
#   --kok DİZİN: tüm yolları o dizin altına taşır ve kullanıcı/grup/sahiplik adımlarını ATLAR (sınav kum havuzu).
# Kurulanlar (hepsi İDEMPOTENT):
#   1 grup+kullanıcı   `ayse` (sistem, ev dizini YOK, kabuk nologin, grup `ayse`; abc bu gruba ÜYE DEĞİL — soket grup izniyle açılır)
#   2 /run/kisi        3770 abc:ayse (setgid: köprü soketi 0660 abc:ayse olur; yapışkan: ayse yalnız kendi ttyd soketini açıp silebilir; 0750'de ttyd bind EACCES verip sıkı döngüye giriyordu)
#   3 izin dosyası     /config/.terminal-onar/kisi/izin.json (merkez-kisiler.json biçimi; YOKSA boş iskelet, VARSA dokunulmaz — Sultan yazar)
#   4 köprü            abc olarak: koltuk-koprusu.py (KOPRU_SOKET=/run/kisi/koprusu.sock)
#   4b istemci kopyası /opt/kisi/kisi-istemci.py (kök sahipli; ayse /config'e erişemez)
#   5 ttyd-kisi        ayse olarak: ttyd -i /run/kisi/ayse-ttyd.sock -U ayse:ayse -a -W … kisi-istemci.py   (komut SABİT, kabuk YOK)
# 🔴 ttyd-kisi'de -W (yazılabilir) ZORUNLUDUR: istemci m/rakam/q tuşlarını ttyd'den alır; -W'siz ttyd girdiyi atar ve düğmeler ölür.
#    Güvence ttyd'nin salt okurluğunda DEĞİL, arkasındaki sürecin KABUKSUZ ve `ayse` yetkisiz olmasındadır; ham tuş köprüde zaten yok.
# 🔴 abc'ye `ayse` grubunu EKLEME: köprü soketine abc zaten sahip; abc'yi gruba katmak `ayse` dosyalarını abc'ye açar, tersi gerekmez.
# Geri alma: kisi-sok.sh (aynı klasör).
set -euo pipefail
KUTU=""; KISI="aysenur"; KULLANICI="ayse"; UID_="2001"; UYGULA=0; KOK=""; BECERI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --kutu) KUTU="$2"; shift 2 ;; --kisi) KISI="$2"; shift 2 ;; --kullanici) KULLANICI="$2"; shift 2 ;; --uid) UID_="$2"; shift 2 ;;
    --beceri) BECERI="$2"; shift 2 ;; --uygula) UYGULA=1; shift ;; --kok) KOK="$2"; shift 2 ;;
    -h|--help) sed -n 2,19p "$0"; exit 0 ;;
    *) echo "kisi-kur: bilinmeyen bayrak: $1" >&2; exit 1 ;;
  esac
done
[[ "$KULLANICI" =~ ^[a-z][a-z0-9_-]{0,30}$ ]] || { echo "kisi-kur: kullanıcı adı geçersiz" >&2; exit 1; }
[[ "$KISI" =~ ^[a-z0-9-]{1,32}$ ]] || { echo "kisi-kur: kişi kimliği geçersiz" >&2; exit 1; }
[[ "$UID_" =~ ^[0-9]{4,5}$ ]] && [ "$UID_" -ge 1001 ] || { echo "kisi-kur: uid 1001 ve üstü, 4-5 haneli olmalı" >&2; exit 1; }
[ -n "$KUTU" ] || KUTU="$(hostname 2>/dev/null | sed 's/^cloudtop-//')"
[[ "$KUTU" =~ ^[a-z0-9._-]{1,40}$ ]] || { echo "kisi-kur: kutu adı geçersiz: $KUTU" >&2; exit 1; }
if [ "$UYGULA" = 1 ] && [ -z "$KOK" ] && [ "$(id -u)" != 0 ]; then echo "kisi-kur: --uygula KÖK ister (host elinde); kuru koş" >&2; exit 2; fi

P() { printf '%s%s' "$KOK" "$1"; }   # yol → kök önekli
RUN="$(P /run/kisi)"; IZIN_DIR="$(P /config/.terminal-onar/kisi)"; IZIN="$IZIN_DIR/izin.json"
SOKET="/run/kisi/koprusu.sock"; TTYD_SOKET="/run/kisi/${KULLANICI}-ttyd.sock"
# ttyd'nin TAM yolu: `ayse` süreci çıplak adı kendi PATH'inde bulamaz (medigate'te ttyd yalnız /config/.local/bin'de; 26 Eki ölçümü) → yol çözülür, `ayse` çalıştırabilmeli
TTYD="${TTYD_BIN:-$(command -v ttyd 2>/dev/null || true)}"
if [ -z "$TTYD" ]; then for c in /config/.local/bin/ttyd /usr/local/bin/ttyd /usr/bin/ttyd; do [ -x "$c" ] && { TTYD="$c"; break; }; done; fi
if [ -z "$KOK" ]; then
  [ -n "$TTYD" ] && [ -x "$TTYD" ] || { echo "kisi-kur: ttyd bulunamadı (PATH, /config/.local/bin, /usr/local/bin) — kurulmadı; TTYD_BIN=<yol> ver" >&2; exit 3; }
  case "$TTYD" in /*) ;; *) echo "kisi-kur: TTYD_BIN mutlak yol olmalı (verilen: $TTYD) — kurulmadı" >&2; exit 3 ;; esac
  TTYD="$(readlink -f "$TTYD")"   # sembolik bağ çözülür: komuta yazılan yol gerçek dosyanın yolu
  # `$KULLANICI` bu dosyayı çalıştırabilmeli. Kullanıcı varsa GERÇEK sınav (onun kimliğiyle); yoksa dosya + bütün üst dizinlerde "diğerleri x" biti aranır (ACL/grup izni sayılmaz: dar ama güvenli taraf)
  if [ "$(id -u)" = 0 ] && id -u "$KULLANICI" >/dev/null 2>&1; then
    su -s /bin/sh "$KULLANICI" -c 'test -x "$1"' _ "$TTYD" || { echo "kisi-kur: \`$KULLANICI\` $TTYD dosyasını çalıştıramıyor (kullanıcı kimliğiyle sınandı) — kurulmadı" >&2; exit 3; }
  else
    p="$TTYD"
    while :; do
      [ $(( $(stat -c %a "$p") % 2 )) -eq 1 ] || { echo "kisi-kur: $p diğer kullanıcılara çalıştırılabilir/geçilebilir değil — \`$KULLANICI\` $TTYD dosyasını çalıştıramaz, kurulmadı (TTYD_BIN=<herkese açık yol>)" >&2; exit 3; }
      [ "$p" = / ] && break; p="$(dirname "$p")"
    done
  fi
fi
n=0; adim() { n=$((n+1)); printf '\nADIM %d — %s\n' "$n" "$1"; }
yap() {  # yap <komut...>: kuru kipte yalnız basar
  printf '  $ %s\n' "$*"
  [ "$UYGULA" = 1 ] && "$@"
  return 0
}
[ "$UYGULA" = 1 ] && echo "kisi-kur: UYGULA kipi · kutu=$KUTU · kişi=$KISI · kullanıcı=$KULLANICI($UID_)" || echo "kisi-kur: KURU KİP (hiçbir şey değişmez) · kutu=$KUTU · kişi=$KISI · kullanıcı=$KULLANICI($UID_)"

adim "grup ve kullanıcı ($KULLANICI, ev dizini yok, kabuk nologin)"
if [ -n "$KOK" ]; then echo "  (kum havuzu: kullanıcı adımı atlandı)"
elif getent passwd "$KULLANICI" >/dev/null 2>&1; then
  [ "$(id -u "$KULLANICI")" = "$UID_" ] && echo "  ✓ zaten var (uid $UID_)" || { echo "  ✗ '$KULLANICI' başka uid ile var ($(id -u "$KULLANICI")) — DURDU" >&2; exit 3; }
else
  getent group "$KULLANICI" >/dev/null 2>&1 || yap groupadd -r -g "$UID_" "$KULLANICI"
  yap useradd -r -M -N -g "$KULLANICI" -u "$UID_" -s /usr/sbin/nologin "$KULLANICI"
fi

adim "soket dizini $RUN (3770 abc:$KULLANICI — ayse ttyd soketini burada açar; yapışkan bit koprusu.sock'u silmesini/değiştirmesini önler, grup biti köprü soketini ayse grubuna verir)"
if [ -n "$KOK" ]; then yap install -d -m 0770 "$RUN"; else yap install -d -m 0770 -o abc -g "$KULLANICI" "$RUN"; fi
yap chmod 3770 "$RUN"   # install -d özel bitleri düşürebilir → ayrı chmod'la sabitlenir

adim "izin dosyası $IZIN (VARSA dokunulmaz)"
if [ -e "$IZIN" ]; then echo "  ✓ var — dokunulmadı"; else
  yap install -d -m 0750 "$IZIN_DIR"
  printf '  (iskelet) {"kisiler":[{"id":"%s","kutular":{"%s":[]}}]}\n' "$KISI" "$KUTU"
  [ "$UYGULA" = 1 ] && printf '{"kisiler":[{"id":"%s","kutular":{"%s":[]}}]}\n' "$KISI" "$KUTU" > "$IZIN"
  [ "$UYGULA" = 1 ] && [ -z "$KOK" ] && chown abc:abc "$IZIN_DIR" "$IZIN" && chmod 0640 "$IZIN"
  echo "  ⚠ koltuk listesini SULTAN yazar (ajan yazmaz): kutular.$KUTU = [\"<koltuk>\", …]"
fi

adim "istemci kopyası $(P /opt/kisi)/kisi-istemci.py (kök sahipli 0755: $KULLANICI /config'i OKUYAMAZ, istemciyi buradan çalıştırır)"
yap install -d -m 0755 "$(P /opt/kisi)"
yap install -m 0755 "$BECERI/kisi-istemci.py" "$(P /opt/kisi)/kisi-istemci.py"

adim "köprü (abc olarak) — $SOKET"
KOPRU_ENV="KOPRU_SOKET=$SOKET KOPRU_GRUP=$KULLANICI KOPRU_KULLANICI=$KULLANICI KOPRU_KUTU=$KUTU KOPRU_KISI=$KISI KOPRU_IZIN_DOSYA=/config/.terminal-onar/kisi/izin.json KOPRU_LISTE_KOMUT='bash /config/.claude/skills/terminal-onar/scripts/koltuk-bagla.sh --liste' KOPRU_MESAJ_KOMUT='bash $BECERI/kisi-mesaj.sh' KOPRU_IZ=/config/.terminal-onar/kisi/iz.jsonl"
[ -n "$KOK" ] && echo "  (kum havuzu: süreç başlatma atlandı)" || yap bash -c "setsid nohup su abc -s /bin/bash -c \"env $KOPRU_ENV python3 $BECERI/koltuk-koprusu.py\" >>/config/.terminal-onar/kisi/koprusu.log 2>&1 &"

adim "ttyd-kisi ($KULLANICI olarak, YAZILABİLİR -W, komut sabit: kisi-istemci)"
[ -n "$KOK" ] && echo "  (kum havuzu: süreç başlatma atlandı)" || yap bash -c "setsid nohup su $KULLANICI -s /bin/bash -c \"KOPRU_SOKET=$SOKET $TTYD -i $TTYD_SOKET -U $KULLANICI:$KULLANICI -a -W python3 /opt/kisi/kisi-istemci.py & P=\\\$!; i=0; while [ ! -S $TTYD_SOKET ] && [ \\\$i -lt 50 ]; do sleep 0.2; i=\\\$((i+1)); done; chmod 0666 $TTYD_SOKET; wait \\\$P\" >>/tmp/ttyd-kisi.log 2>&1 &"

echo; [ "$UYGULA" = 1 ] && echo "kisi-kur: bitti." || echo "kisi-kur: KURU KİP bitti — hiçbir şey değişmedi. Gerçek kurulum: Sultan/host elinde --uygula."
