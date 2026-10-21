#!/usr/bin/env bash
# denetci.sh — fabrika 4. adım: BAĞIMSIZ GÖZ. Yazandan FARKLI model diff + iş kartı + kanıt manifestini inceler,
# puanı iki satır verir (kod 0-5 · doğru şey E/H), sonucu DENETIM-<tur>.json'a ARAÇ yazar; dönüş tavanını uygular.
#
# Kurallar (Sultan K1/K4, 21-22 Eyl 2026):
#   · denetleyen model yazanla AYNI OLAMAZ (Claude→Codex, Codex→Claude; --denetci ile açıkça seçilebilir)
#   · kanıt yoksa ya da manifest bozuksa denetim AÇILMAZ (rc=2) — "kanıtsız adım 4 yok"
#   · tavan 3 tur; ilerleyen işe (puan↑ VE açık bulgu↓) +1; DÖRT mutlak → sonrası "tıkandı + üç yol" (rc=4)
#   · --sultan-devam : KARTA işlenmiş Sultan kararını (kart.sh sultan-dedi) okur ve "ilerlemiyor"
#     hükmünü aşar. Kartta kayıt yoksa AÇILMAZ. MUTLAK tavanı (4) AÇMAZ. Deftere yazılamazsa AÇILMAZ.
#   · --reis-devam   : SINIFSIZ işte KARTA işlenmiş sahip/reis kararını (kart.sh reis-dedi) okur; aynı sınırlar.
#     Sınıflı kartta AÇILMAZ (o kararın merci Sultan'dır). Defter satırı TAVAN-ACILDI-REIS, gün sonu özetinde görünür.
#
# Kullanım:
#   denetci.sh <iş> [--pr N | --diff DOSYA] [--kart DOSYA] [--yazan claude|codex] [--denetci auto|codex|claude]
#              [--model AD] [--depo KÖK] [--kare PNG/JPG]...
#   --kare : arayüz işinde kabul karesi (tekrarlanabilir, en çok 8). Kare bağımsız göze GÖRSEL olarak gider (codex exec -i);
#            istemde "ekte N kare" yazar, DENETIM kaydı kare adı + sha256 taşır. Dosya yok / görsel değil → rc 2 (sessiz atlama yok).
#            Neden (15 Eki, cloudtop #637 tur 2-3): göz "kabul karesi sunulmadı" diyordu; sha künyesi ve DOM tarifi kareyi görmenin yerini tutmuyor.
# rc: 0 GEÇTİ (5+E) · 1 adım 2'ye dön · 2 kanıt yok/bozuk · 3 denetçi ölçemedi (çıktı geçersiz) · 4 tıkandı (tavan)
# Ortam: DENETCI_KOMUT — denetçiyi değiştirir (sınav için): <komut> <istem-dosyası> → stdout'a JSON
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEMA="$HERE/../sablon/denetim-sema.json"
ISTEM="$HERE/../adimlar/denetci-istem.md"
TAVAN=3; MUTLAK=4

_hata() { printf '✗ %s\n' "$*" >&2; }
# 🔴 SESSİZ BİTİŞ YOK (SERDAR ACİL 21 Eki 19:49, Sultan: "işler sessizce duruyor"): bir günde iki ajan bitmiş göz turunu
#    1'er saat fark etmedi, biri HİÇ başlamamış denetçinin DENETIM-N.json'unu 1 saat bekledi. Kök üçlü: bitince haber yok,
#    zaman aşımı yok, başladığının izi yok. Çare: (1) başlarken DENETIM-<tur>.kosuyor izi (pid + başlangıç), bitince silinir;
#    (2) model çağrısı DENETCI_ZAMAN_ASIMI (varsayılan 900 sn) ile kesilir → rc 3 + HAM'a "ZAMAN AŞIMI";
#    (3) HER çıkış yolunda (EXIT tuzağı — DENETIM yazmayan erken çıkışlar dâhil) yazana tek satır zil; rc 3/4'te reise de.
#    Zil aracı yoksa (aile-notify bu kutuda yok) iş DURMAZ ama sessiz de geçmez: stderr'e yazılır.
KOSUYOR=""; TMP=""; ZAMAN_ASIMI=0
_zil() {   # _zil <rc> — yazana --done, rc 3/4'te reise --waiting
  local rc="$1" an="${FABRIKA_AILE_NOTIFY:-}" yazan="${AGENT_NAME:-}" reis="" k="" ne
  [ "$an" = "-" ] && return 0   # bilerek kapalı (sınavlar: denetçiyi yüzlerce kez koşturur, gerçek koltuklara zil çalmasın)
  if [ -z "$an" ] && [ -n "${DENETCI_KOMUT:-}" ]; then   # sınav kipi: gerçek zil ARANMAZ, yalnız açıkça verilen çalar
    printf '· sınav kipi (DENETCI_KOMUT): bitiş zili yalnız FABRIKA_AILE_NOTIFY ile — rc %s\n' "$rc" >&2; return 0; fi
  [ -n "$an" ] || an="$(command -v aile-notify.sh 2>/dev/null)"
  [ -n "$an" ] || for k in "${DEPO:-}/scripts/aile-notify.sh" /config/projects/Nexus/scripts/aile-notify.sh; do [ -f "$k" ] && { an="$k"; break; }; done
  if [ -z "$an" ] || [ ! -f "$an" ]; then printf '⚠ denetçi bitiş zili ATLANDI: aile-notify bulunamadı (FABRIKA_AILE_NOTIFY ile ver) — rc %s\n' "$rc" >&2; return 0; fi
  k="${KART_DEPO:-}/_agents/fabrika/kartlar/${IS:-}.json"
  if [ -f "$k" ]; then
    [ -n "$yazan" ] || yazan="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("aldi") or "")' "$k" 2>/dev/null)"
    reis="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("istedi") or "")' "$k" 2>/dev/null)"
  fi
  case "$reis" in ""|SULTAN|Sultan|"$yazan") reis="SERDAR" ;; esac   # sahipsiz · Sultan (koltuk değil, zil çalınmaz) · yazanın kendisi → kutular üstü reis
  # göz tur 2 (#404): AGENT_NAME yok ve kart yoksa (iş adı verilmeden en erken çıkış) yazan bilinmez — zil hedefsiz gitmesin, reise gider
  local yazansiz=0
  if [ -z "$yazan" ]; then yazansiz=1; yazan="$reis"; printf '⚠ denetçi zilinde yazan bilinmiyor (AGENT_NAME yok, kart yok) → %s\n' "$reis" >&2; fi
  case "$rc" in 0) ne="GEÇTİ" ;; 1) ne="düzelt, yeniden gönder" ;; 2) ne="kanıt/kullanım eksiği — denetim açılmadı" ;;
                3) ne="ÖLÇÜLEMEDİ"; [ "$ZAMAN_ASIMI" = 1 ] && ne="ZAMAN AŞIMI (${ZA} sn) — denetçi bitmedi" ;; 4) ne="TIKANDI — üç yol raporu" ;; *) ne="beklenmeyen çıkış" ;; esac
  local m="${IS:-?} tur ${TUR:-?}: ${PUAN:-—}/${DOGRU:-—} · bulgu ${NB:-—} · rc $rc · $ne"
  [ "$yazansiz" = 1 ] && m="$m · yazan bilinmiyor"
  # HEZARFEN ölçümü (20:38, #404): denetçiyi koşturan ajanın kendi penceresine giden zil, aile-notify'ın self-loop korumasına
  #   takılıp ATLANIYORDU ("atla(self): … çağıran-oturum") — bekleyen yine sessiz kalırdı. Yazanın zilinde TMUX kimliği soyulur:
  #   meşgul koltukta zil kuyruğa girer (ölçüldü: kanıt olcum-gercek-zil-sonra). Bedeli: gönderen "BILINMEYEN" görünür — aile-notify
  #   göndereni yalnız TMUX'tan çözer. Reis zili başka koltuğa gider; orada kimlik KORUNUR ki reis kimden geldiğini görsün.
  env -u TMUX -u TMUX_PANE bash "$an" --done ${yazan:+--amir "$yazan"} "denetçi: $m" </dev/null >/dev/null 2>&1 || printf '⚠ denetçi bitiş zili gönderilemedi (aile-notify rc %s): %s\n' "$?" "$m" >&2
  if { [ "$rc" = 3 ] || [ "$rc" = 4 ]; } && [ "$yazansiz" = 0 ]; then   # yazansızda reis zaten --done'u aldı, ikinci zil yok
    bash "$an" --waiting --amir "$reis" "denetçi (${yazan:-yazan?}): $m" </dev/null >/dev/null 2>&1 || printf '⚠ reis zili gönderilemedi (%s): %s\n' "$reis" "$m" >&2
  fi
}
_bitis() {   # EXIT tuzağı: çıkış kodu KORUNUR (tuzak exit çağırmaz)
  local rc=$?
  [ -n "$KOSUYOR" ] && rm -f "$KOSUYOR"
  [ -n "$TMP" ] && rm -rf "$TMP"
  _zil "$rc"
}
trap _bitis EXIT
ZA="${DENETCI_ZAMAN_ASIMI:-900}"; ZA_K="${DENETCI_ZAMAN_ASIMI_K:-30}"
# göz tur 1 (#404): sayı olmayan değer timeout'u rc 125'e düşürür ve "codex düştü" sanılıp yeniden denenirdi → doğrula, varsayılana dön
case "$ZA" in ''|*[!0-9]*|0) printf '⚠ DENETCI_ZAMAN_ASIMI=%s geçersiz (pozitif tam sayı sn olmalı) → 900\n' "$ZA" >&2; ZA=900 ;; esac
case "$ZA_K" in ''|*[!0-9]*|0) ZA_K=30 ;; esac
# _sinirli <komut…> — ZA sn sonra TERM, yutarsa ZA_K sn sonra KILL (göz tur 1: -k'sız timeout TERM'i yutan denetçide yine asılı kalır).
#   KILL ile biten aşım 137 döner; süre dolmuşsa o da zaman aşımıdır → 124'e çevrilir (tek anlam: aşım = 124).
_sinirli() {
  local b=$SECONDS r
  timeout -k "$ZA_K" "$ZA" "$@"; r=$?
  [ "$r" -eq 137 ] && [ $((SECONDS - b)) -ge "$ZA" ] && r=124
  return "$r"
}
_bilgi() { printf '%s\n' "$*"; }

KARELER=(); IS=""; PR=""; DIFF=""; KART=""; YAZAN="claude"; DENETCI="auto"; MODEL=""; DEPO="${KANIT_DEPO:-}"; SULTAN_DEVAM=0; REIS_DEVAM=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="$2"; shift 2 ;; --diff) DIFF="$2"; shift 2 ;; --kart) KART="$2"; shift 2 ;;
    --yazan) YAZAN="$2"; shift 2 ;; --denetci) DENETCI="$2"; shift 2 ;; --model) MODEL="$2"; shift 2 ;;
    --depo) DEPO="$2"; shift 2 ;;
    --kare) KARELER+=("$2"); shift 2 ;;
    --sultan-devam) SULTAN_DEVAM=1; shift ;;
    --reis-devam) REIS_DEVAM=1; shift ;;
    -h|--help) sed -n '1,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [ -z "$IS" ] && IS="$1" || { _hata "tanınmayan argüman: $1"; exit 1; }; shift ;;
  esac
done
[ -n "$IS" ] || { _hata "iş adı gerekiyor"; exit 1; }
KARE_TAVAN=8
[ "${#KARELER[@]}" -le "$KARE_TAVAN" ] || { _hata "--kare en çok $KARE_TAVAN (verilen ${#KARELER[@]}) — en çok tartışılacak kareleri seç"; exit 2; }
for _k in "${KARELER[@]}"; do
  [ -f "$_k" ] || { _hata "--kare dosyası yok: $_k (sessiz atlanmaz)"; exit 2; }
  # Yapı TAM doğrulanır (göz #331 tur 1-2): PNG = imza + CRC'li yığınlar + geçerli IHDR + IDAT AÇILIR ve boyutu w×h'ye tutar + IEND;
  #   JPEG = bölümler sırayla okunur (SOI → geçerli SOF → SOS → entropi → EOI tam sonda). Yalnız standart kütüphane (CI'da PIL yok).
  _kd="$(python3 - "$_k" <<'PYK'
import sys,struct,zlib
b=open(sys.argv[1],'rb').read()
def png(b):
    if b[:8]!=b'\x89PNG\r\n\x1a\n': return 'png imzası yok'
    i=8; ilk=True; son=None; ihdr=None; idat=b''
    while i+12<=len(b):
        n,=struct.unpack('>I',b[i:i+4]); t=b[i+4:i+8]
        if i+12+n>len(b): return 'kesik yığın ('+t.decode('latin1')+')'
        if zlib.crc32(t+b[i+8:i+8+n])&0xffffffff!=struct.unpack('>I',b[i+8+n:i+12+n])[0]: return 'CRC tutmuyor ('+t.decode('latin1')+')'
        if ilk and t!=b'IHDR': return 'ilk yığın IHDR değil'
        if t==b'IHDR': ihdr=b[i+8:i+8+n]
        if t==b'IDAT': idat+=b[i+8:i+8+n]
        ilk=False; son=t; i+=12+n
        if t==b'IEND': break
    if not (son==b'IEND' and i==len(b)): return 'IEND ile bitmiyor (kesik)'
    # göz #331 tur 2: CRC'li IHDR+IEND de "görüntü" değildir — başlık alanları geçerli olmalı ve piksel akışı AÇILIP boyutu tutmalı
    if ihdr is None or len(ihdr)!=13: return 'IHDR 13 bayt değil'
    w,h,bd,ct,cm,fm,il=struct.unpack('>IIBBBBB',ihdr)
    kanal={0:1,2:3,3:1,4:2,6:4}.get(ct); izinli={0:(1,2,4,8,16),2:(8,16),3:(1,2,4,8),4:(8,16),6:(8,16)}
    if not (0<w<=100000 and 0<h<=100000): return 'IHDR boyutu geçersiz'
    if kanal is None or bd not in izinli[ct] or cm!=0 or fm!=0 or il not in (0,1): return 'IHDR alanları geçersiz'
    if not idat: return 'IDAT yok (piksel verisi yok)'
    try: ham=zlib.decompress(idat)
    except zlib.error: return 'piksel akışı açılmıyor'
    # satır düzeni: geçişsiz = tek alt-görüntü; Adam7 (göz #331 tur 3) = yedi geçiş, her biri kendi genişliği/yüksekliğiyle
    gecis=[(0,0,1,1)] if il==0 else [(0,0,8,8),(4,0,8,8),(0,4,4,8),(2,0,4,4),(0,2,2,4),(1,0,2,2),(0,1,1,2)]
    j=0
    for xs,ys,dx,dy in gecis:
        pw=(w-xs+dx-1)//dx if w>xs else 0; ph=(h-ys+dy-1)//dy if h>ys else 0
        if not pw or not ph: continue
        sb=(pw*kanal*bd+7)//8
        for _ in range(ph):
            if j>=len(ham): return 'piksel akışı boyutu tutmuyor (kısa)'
            if ham[j]>4: return 'satır süzgeci geçersiz'
            j+=1+sb
    if j!=len(ham): return 'piksel akışı boyutu tutmuyor'
    return ''
def jpg(b):
    # göz #331 tur 2: işaret aramak yetmez — bölümler SIRAYLA okunur: SOI → (uzunluklu bölümler) → geçerli SOF → SOS → entropi verisi → … → EOI tam sonda
    if b[:2]!=b'\xff\xd8': return 'jpeg imzası yok'
    SOF=set(range(0xc0,0xd0))-{0xc4,0xc8,0xcc}; i=2; sof=False; sos=0; n=len(b)
    while True:
        if i+2>n or b[i]!=0xff: return 'bölüm sırası bozuk (kesik ya da düz veri)'
        while i+1<n and b[i+1]==0xff: i+=1
        if i+2>n: return 'kesik'
        m=b[i+1]
        if m==0xd9: return '' if (sof and sos and i+2==n) else ('EOI tam sonda değil' if i+2!=n else 'SOF/SOS olmadan EOI')
        if m==0x01 or 0xd0<=m<=0xd7: i+=2; continue
        if i+4>n: return 'kesik bölüm'
        L=(b[i+2]<<8)|b[i+3]
        if L<2 or i+2+L>n: return 'bölüm uzunluğu taşıyor (kesik)'
        if m in SOF:
            if L<8: return 'SOF kısa'
            hh=(b[i+5]<<8)|b[i+6]; ww=(b[i+7]<<8)|b[i+8]; nc=b[i+9]
            if not (hh>0 and ww>0 and nc>=1 and L==8+3*nc): return 'SOF alanları geçersiz'
            sof=True
        i+=2+L
        if m==0xda:
            if not sof: return 'SOF olmadan SOS'
            sos+=1; bas=i
            while i+1<n and not (b[i]==0xff and b[i+1]!=0x00 and not 0xd0<=b[i+1]<=0xd7): i+=1
            if i+1>=n: return 'EOI ile bitmiyor (kesik)'
            if i==bas: return 'tarama boş (piksel verisi yok)'   # göz #331 tur 3: SOS'tan hemen sonra işaret = görüntü yok
print(png(b) if b[:4]==b'\x89PNG' else jpg(b) if b[:2]==b'\xff\xd8' else 'PNG/JPG imzası yok')
PYK
)"
  [ -z "$_kd" ] || { _hata "--kare geçerli görsel değil ($_kd): $_k"; exit 2; }
done
# --pr da --diff de yoksa denetçi FARKI KENDİSİ alır (görev R7M76): yerel kip — aşağıda "3 · girdiler".
[ -n "$DEPO" ] || DEPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[ -n "$DEPO" ] || { _hata "depo kökü bulunamadı"; exit 3; }
DZ="$DEPO/_agents/fabrika/kanit/$IS"
# 🔴 KART TEK KAYNAK (15 Eki 2026, gorev_01M4Y4JX3NM4WFTQ9RG3YC1T2A): kart.sh kartı BİRİNCİL depoya yazar (git-common-dir); bu betik
#    iş alanındaki (worktree) kopyayı okuyordu → reis-dedi/sultan-dedi kapısı kopyalanmadan açılmıyordu (bir günde 4 koşum boşa).
#    Kart artık YALNIZ birincil depodan okunur; iş alanındaki kopya BAYAT sayılır ve HİÇ okunmaz (göz tur 1: "yoksa kopyayı oku"
#    geri-dönüşü yanlış davranışı sürdürüyordu) — birincilde kart yokken alanda kopya varsa denetim rc=3 ile durur. Kanıt için kartın
#    o anki hâli $DZ/KART.json'a kopyalanır — PR'a kart bununla gider, kartlar/ dizinindeki kopyayla değil; kopya yazılamazsa rc=3.
KART_DEPO="${KART_DEPO:-$(c="$(git -C "$DEPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && [ -n "$c" ] && dirname "$c")}"
[ -n "$KART_DEPO" ] || KART_DEPO="$DEPO"
kart_yolu() {  # birincil depodaki kart; yoksa boş. İş alanındaki kopya OKUNMAZ: birincilde yokken alanda kopya varsa rc=3 (bayat kart kapıyı yanıltır)
  if [ -f "$KART_DEPO/_agents/fabrika/kartlar/$IS.json" ]; then printf '%s' "$KART_DEPO/_agents/fabrika/kartlar/$IS.json"
  elif [ "$KART_DEPO" != "$DEPO" ] && [ -f "$DEPO/_agents/fabrika/kartlar/$IS.json" ]; then
    _hata "kart birincil depoda YOK ($KART_DEPO/_agents/fabrika/kartlar/$IS.json); iş alanındaki kopya BAYAT sayılır, OKUNMAZ — kart.sh ile birincile yaz, sonra denetçiyi koştur"; return 3
  fi
}

# ── 1 · kanıt kapısı ─────────────────────────────────────────────────────────────
KANIT_CIKTI="$(KANIT_DEPO="$DEPO" python3 "$HERE/kanit.py" dogrula "$IS" 2>&1)"; KRC=$?
case "$KRC" in
  0) KANIT_DURUM="sağlam (araç imzalı, sha'lar tutuyor)"
     # 4K938: geçersiz ilan edilen kayıt göze söylenir — manifestte durur ama kanıt sayılmaz
     NGEC=$(printf '%s\n' "$KANIT_CIKTI" | grep -c '^⛔ GEÇERSİZ')
     [ "$NGEC" -gt 0 ] && KANIT_DURUM="$KANIT_DURUM · $NGEC kayıt GEÇERSİZ ilan edildi, kanıt sayılmaz: $(printf '%s\n' "$KANIT_CIKTI" | grep '^⛔ GEÇERSİZ' | sed 's/^⛔ GEÇERSİZ: //' | paste -sd ';' -)" ;;
  1) _hata "kanıt manifesti BOZUK (elle yazılmış ya da dosya değişmiş) — denetim açılmaz"; printf '%s\n' "$KANIT_CIKTI" >&2; exit 2 ;;
  *) _hata "kanıt YOK — 'kanıtsız adım 4 yok'. Önce kanit.sh ile kanıt topla."; exit 2 ;;
esac

# ── 2 · tur ve tavan ─────────────────────────────────────────────────────────────
mkdir -p "$DZ"
ONCEKI=$(ls "$DZ"/DENETIM-*.json 2>/dev/null | wc -l)
TUR=$((ONCEKI+1))
# "denetçi başladı mı?" sorusunun cevabı: bekleyen bu dosyaya bakar (pid canlı mı, ne zamandan beri); bitince _bitis siler
# göz tur 1 (#404): SIGKILL/OOM'da EXIT tuzağı koşmaz → iz kalır. Kalan izin pid'i ölüyse BAYAT: söylenir ve silinir.
#   pid'i canlıysa aynı işte BAŞKA denetçi koşuyor: aynı turu ve izi paylaşırdı → bu koşum ölçülemedi (rc 3), öbürüne dokunulmaz.
_pid_kimlik() { ps -o lstart= -p "$1" 2>/dev/null | sed 's/^ *//'; }
for _iz in "$DZ"/DENETIM-*.kosuyor; do
  [ -f "$_iz" ] || continue
  _pid="$(sed -n 's/^pid=//p' "$_iz" | head -1)"
  # göz tur 2 (#404): pid yeniden verilmiş olabilir → canlılık yetmez, sürecin başlangıç anı (ps lstart) izdekiyle aynı olmalı.
  #   Eski biçimli izde (pid_kimlik yok) yalnız canlılık sayılır — temkinli: yanlışlıkla başkasının denetimini ezmekten iyidir.
  _kim_iz="$(sed -n 's/^pid_kimlik=//p' "$_iz" | head -1)"
  if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null && { [ -z "$_kim_iz" ] || [ "$_kim_iz" = "$(_pid_kimlik "$_pid")" ]; }; then
    _hata "bu işte başka denetçi koşuyor: $(basename "$_iz") (pid $_pid, $(sed -n 's/^baslangic=//p' "$_iz")) — bitmesini bekle"; exit 3
  fi
  _bilgi "⚠ bayat koşuyor izi silindi: $(basename "$_iz") (pid ${_pid:-?} yaşamıyor ya da başka sürece geçmiş — denetçi zil çalmadan öldü)"; rm -f "$_iz"
done
KOSUYOR="$DZ/DENETIM-$TUR.kosuyor"
# noclobber: denetimle yazım arasındaki dar aralıkta ikinci denetçi gelirse izi ezmez, ölçülemedi der
if ! ( set -C; printf 'pid=%s\npid_kimlik=%s\nbaslangic=%s\nzaman_asimi_sn=%s\n' "$$" "$(_pid_kimlik "$$")" "$(date -Iseconds)" "$ZA" > "$KOSUYOR" ) 2>/dev/null; then
  if [ -e "$KOSUYOR" ]; then KOSUYOR=""; _hata "bu işte başka denetçi aynı anda başladı (DENETIM-$TUR.kosuyor) — bitmesini bekle"; exit 3; fi
  KOSUYOR=""
fi
# ── DARALTMA SIFIRI (PCP7J, 18 Eki 2026): kart daraltıldıysa (kart.sh daralt) daraltmadan ÖNCEKİ turlar yeni
#    cümleyi puanlamadı; tavan ve "ilerliyor mu" yalnız daraltma SONRASI turlara bakar. Kart okunamazsa 0
#    (daraltma yok sayılır — kapı aynı kaydı ayrıca okur, bu kapı tek değildir).
TUR_SIFIR=0
_KY="$(kart_yolu 2>/dev/null || true)"
if [ -n "$_KY" ] && [ -r "$_KY" ]; then
  TUR_SIFIR="$(python3 - "$_KY" <<'PYTS'
import json,sys
try:
    k=json.load(open(sys.argv[1],encoding="utf-8")); d=k.get("daraltmalar") or []
    print(int(d[-1].get("tur_sifir",0)) if d else 0)
except Exception: print(0)
PYTS
)"
  case "$TUR_SIFIR" in ''|*[!0-9]*) TUR_SIFIR=0 ;; esac
  [ "$TUR_SIFIR" -gt 0 ] && _bilgi "· kart DARALTILMIŞ: ilk $TUR_SIFIR tur eski cümleye ait, sayılmıyor (tavan ve ilerleme daraltmadan sonra başlar)"
fi
# ── SAYILI TUR (gorev WC3VBZAA · ölçülmüş vaka: cloudtop #635 DÖRT turunu "canlıda kurulu
#    değil" bulgusuyla yaktı, kod kusursuzdu ve iş hiç ilerlemedi). Tavan ham tur sayısına değil,
#    İŞIN KUTUDA İLERLETİLEBİLDİĞİ tur sayısına uygulanır. Bir tur, bulgularının HEPSİ kutu-dışıysa
#    SAYILMAZ: o turda kutuda yapılacak bir şey söylenmemiştir, dolayısıyla tur yakmak haksızdır.
#    🔴 Sıfır bulgulu tur SAYILIR — eski davranış korunur; "bulgu yok ama 5 de yok" ayrı bir vakadır
#    ve bu kartın kapsamı değil (kapsam kayması olurdu).
# 🔴 TUR-1 BULGUSU (uygulama): fren "üst üste" diyordu ama sayacı KÜMÜLATİFtı
#    (ONCEKI-SAYILI). kutu-dışı / normal / kutu-dışı / normal / kutu-dışı dizisinde üç ardışık
#    yakmayan tur OLMADIĞI halde iş durabilirdi. Arada normal bir tur geçtiyse iş kutuda
#    İLERLİYOR demektir; sayacı orada SIFIRLAMAK gerekir. İki sayı ayrı üretiliyor:
#    SAYILI (tavan için, kümülatif) ve ARDISIK (fren için, yalnız KUYRUKTAKİ dizi).
read -r SAYILI ARDISIK_ONCE <<EOSAY
$(python3 - "$DZ" "$TUR_SIFIR" <<'PYSAY'
import json,glob,os,sys
sayan=[]; sifir=int(sys.argv[2])
for y in sorted(glob.glob(os.path.join(sys.argv[1],"DENETIM-[0-9]*.json")),
                key=lambda p:int(p.rsplit("-",1)[1].split(".")[0])):
    if int(y.rsplit("-",1)[1].split(".")[0]) <= sifir: continue   # daraltmadan önceki tur: eski cümle, sayılmaz
    try: b=json.load(open(y,encoding="utf-8"))["sonuc"]["bulgular"]
    except Exception: sayan.append(True); continue   # okunamayan tur SAYILIR (şüphede muafiyet YOK)
    sayan.append(bool(not b or any(x.get("agirlik")!="kutu-disi" for x in b)))
ard=0
for v in reversed(sayan):
    if v: break
    ard+=1
print(sum(1 for v in sayan if v), ard)
PYSAY
)
EOSAY
case "$SAYILI" in ''|*[!0-9]*) SAYILI="$ONCEKI" ;; esac
case "${ARDISIK_ONCE:-}" in ''|*[!0-9]*) ARDISIK_ONCE=0 ;; esac
ilerliyor_mu() {  # önceki iki turu kıyasla: puan↑ VE açık bulgu↓ (daraltma sonrası en az iki tur gerekir)
  [ $((ONCEKI - TUR_SIFIR)) -ge 2 ] || return 1
  python3 - "$DZ" "$ONCEKI" <<'PY'
import json,sys,os
dz,n=sys.argv[1],int(sys.argv[2])
a=json.load(open(os.path.join(dz,f"DENETIM-{n-1}.json")))["sonuc"]; b=json.load(open(os.path.join(dz,f"DENETIM-{n}.json")))["sonuc"]
# Kutu-dışı bulgu "açık bulgu" değildir: kutuda kapatılamaz, o yüzden ilerleme ölçümüne girmez.
ac=lambda r: len([x for x in r["bulgular"] if x.get("agirlik")!="kutu-disi"])
sys.exit(0 if (b["kod_puani"]>a["kod_puani"] and ac(b)<ac(a)) else 1)
PY
}
tikandi_raporu() {
  _bilgi ""
  _bilgi "⛔ TIKANDI — $ONCEKI turda 5+E'ye ulaşılamadı (tavan $TAVAN, ilerleyene +1, $MUTLAK mutlak; kutu-dışı bulgulu turlar sayılmaz)."
  _bilgi "   Üç yol (karar iş sahibinin/reisin, sınıf işiyse Sultan'ın):"
  _bilgi "   1) DEVAM — gerekçeyle: neden bir tur daha işe yarar?"
  _bilgi "   2) KAPSAMI DARALT — kart.sh daralt <iş> --kalan \"<bulgu>\" --cumle \"<daraltılmış cümle>\" --oturum <ref>: kalan yeni karta, tur sayacı sıfırlanır, aynı dal/PR sürer"
  _bilgi "   3) GERİ AL — alanı kapat, iş kartına 'tıkandı' damgası, ders deftere"
}
# 🔴 SULTAN KAPISI (23 Eyl 2026): tıkandı raporu "karar sınıf işiyse Sultan'ın" diyordu ama
#    araçta o kararı kabul edecek kapı YOKTU — kural insana havale ediyor, araç insanı dinlemiyordu.
#    Canlı vaka: kapı onarımında puanlar 3·3·2 gitti; düşüşün sebebi işin kötüleşmesi değil,
#    denetçinin her turda DAHA CİDDİ bir kusur bulmasıydı. "ilerliyor_mu" bu ikisini ayırt edemez.
#    Kapı gerekçesiz açılmaz (≥20 karakter), deftere yazılır, gün sonu özetinde Sultan'a görünür.
#    ⚠ MUTLAK tavanı AÇMAZ: dört tur hâlâ mutlaktır. Bu kapı yalnız "ilerlemiyor" hükmünü aşar.
#    ⚠ A06: bu bayrağı yazan ajan Sultan'ın onayını ÜRETMEZ; aldığı onayı AKTARIR. Gerekçe metni
#      denetlenebilir olsun diye deftere düşer — uyduran, defterde yakalanır.
sultan_kapisi() {
  [ "$SULTAN_DEVAM" = "1" ] || return 1
  # Karar KARTTAN okunur, komut satırından DEĞİL. (Bağımsız göz 23 Eyl, ciddi: serbest metinle
  # açılan yetki kapısı, kapı değildir.) Kartta D1 kaydı yoksa kapı AÇILMAZ.
  KARTYOL="$(kart_yolu)" || exit 3; [ -n "$KARTYOL" ] || KARTYOL="/nonexistent"   # göz tur 2: bayat kopya hatası (rc=3) bastırılmaz, "karar YOK" reddine dönüşmez
  GEREKCE="$(python3 - "$KARTYOL" "devam" 2>/dev/null <<'PY'
import json,sys
try: k=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: raise SystemExit(1)
kk=[x for x in (k.get("sultan_kararlari") or []) if x.get("karar")==sys.argv[2]]
if not kk: raise SystemExit(1)
x=kk[-1]
if not (x.get("oturum") and x.get("soz") and x.get("beyan")): raise SystemExit(1)
# gerekçe ayrı alandır: Sultan'ın sözü "ne dedi"yi, gerekçe "niçin işe yarar"ı taşır.
if len(x.get("gerekce") or "") < 20: raise SystemExit(1)
# 🔴 İKİNCİ ÇİT: kart elle düzenlenmiş olabilir, kart.sh'ın kapısından geçmemiş olabilir.
# Deftere yazmadan ÖNCE ayraç ve satır sonunu burada da temizliyoruz — tek çit, çit değildir.
def tmz(v): return " ".join(str(v).replace("|","/").split())
print(f'oturum={tmz(x["oturum"])} soz="{tmz(x["soz"])}" beyan={tmz(x["beyan"])} gerekce="{tmz(x["gerekce"])}"')
PY
)"
  if [ -z "$GEREKCE" ]; then
    _hata "--sultan-devam verildi ama KARTTA gerekçeli 'devam' kararı YOK — kapı açılmadı."
    _bilgi "   Sultan gerçekten 'devam' dediyse önce kayda geçir (A06: onay üretilmez, aktarılır):"
    _bilgi "     kart.sh sultan-dedi $IS --karar devam --oturum <ref> --soz \"<verbatim>\" --beyan <AJAN> \\"
    _bilgi "        --gerekce \"<niçin bir tur daha işe yarar — en az 20 karakter>\""
    return 2
  fi
  # 🔴 Deftere yazılamıyorsa kapı AÇILMAZ: kaydedilemeyen istisna, istisna değil DELİKTİR.
  #    (Bağımsız göz 23 Eyl: mkdir/printf hataları yutuluyor, kapı yine açılıyordu.)
  DEF="$DEPO/_agents/fabrika/tavan-defteri.log"
  mkdir -p "$DEPO/_agents/fabrika" || { _hata "tavan defteri dizini açılamadı — kapı AÇILMADI"; return 2; }
  SATIR="$(date -u +%Y-%m-%dT%H:%M:%SZ) | TAVAN-ACILDI | is=$IS tur=$TUR | $GEREKCE"
  # Tek kontrol, ama DOĞRU olanı: yaz ve GERİ OKU. Yazma hatasını ayrıca sınamaya gerek yok —
  # yazılamayan satır geri de okunamaz. İki ayrı kontrol koymak, ikincisini sınanamaz kılıyordu.
  printf '%s\n' "$SATIR" >> "$DEF" 2>/dev/null
  grep -qF "$SATIR" "$DEF" 2>/dev/null || { _hata "tavan defterine yazılan satır geri OKUNAMADI — kapı AÇILMADI"; return 2; }
  _bilgi "⚠ TAVAN AÇILDI (tur $TUR) — Sultan kararı karttan okundu ve deftere yazıldı: $GEREKCE"
  return 0
}
# 🔴 REİS KAPISI (8 Eki 2026 · A268): tıkandı raporu "karar iş sahibinin/reisin, sınıf işiyse Sultan'ın" diyordu
#    ama araçta yalnız Sultan yolu vardı — sınıfsız işin sahibi kendi kararını araca yazdıramıyor, kapı ya
#    kapalı kalıyor ya da A06'ya özendiriyordu (aynı gün iki vaka). Bu kapı YALNIZ sınıfsız kartta açılır;
#    sınıflı kartta reis kararı yok sayılır ve Sultan yolu gösterilir. Mutlak tavanı (4) yine AÇMAZ.
reis_kapisi() {
  [ "$REIS_DEVAM" = "1" ] || return 1
  KARTYOL="$(kart_yolu)" || exit 3; [ -n "$KARTYOL" ] || KARTYOL="/nonexistent"   # göz tur 2: bayat kopya hatası (rc=3) bastırılmaz, "karar YOK" reddine dönüşmez
  GEREKCE="$(python3 - "$KARTYOL" "devam" 2>/dev/null <<'PY'
import json,sys
try: k=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: raise SystemExit(1)
# sınıflı kart → bu yol KAPALI (merci Sultan). "sultan" bayrağı ya da sınıf listesi dolu ise reddet.
if k.get("sultan") or k.get("siniflar"): raise SystemExit(3)
kk=[x for x in (k.get("reis_kararlari") or []) if x.get("karar")==sys.argv[2]]
if not kk: raise SystemExit(1)
x=kk[-1]
if not (x.get("reis") and x.get("oturum")): raise SystemExit(1)
if len(x.get("gerekce") or "") < 20: raise SystemExit(1)
def tmz(v): return " ".join(str(v).replace("|","/").split())
print(f'reis={tmz(x["reis"])} oturum={tmz(x["oturum"])} gerekce="{tmz(x["gerekce"])}"')
PY
)"; prc=$?
  if [ "$prc" -eq 3 ]; then
    _hata "--reis-devam verildi ama kart SINIFLI — sınıf işinin kararı Sultan'ındır; reis kapısı AÇILMADI (yol: kart.sh sultan-dedi + --sultan-devam)."
    return 2
  fi
  if [ -z "$GEREKCE" ]; then
    _hata "--reis-devam verildi ama KARTTA gerekçeli reis 'devam' kararı YOK — kapı açılmadı."
    _bilgi "   Sınıfsız işin sahibi/reisi kararını önce kayda geçirir:"
    _bilgi "     kart.sh reis-dedi $IS --karar devam --reis <AD> --oturum <ref> --gerekce \"<niçin bir tur daha — en az 20 karakter>\""
    return 2
  fi
  DEF="$DEPO/_agents/fabrika/tavan-defteri.log"
  mkdir -p "$DEPO/_agents/fabrika" || { _hata "tavan defteri dizini açılamadı — kapı AÇILMADI"; return 2; }
  SATIR="$(date -u +%Y-%m-%dT%H:%M:%SZ) | TAVAN-ACILDI-REIS | is=$IS tur=$TUR | $GEREKCE"
  printf '%s\n' "$SATIR" >> "$DEF" 2>/dev/null
  grep -qF "$SATIR" "$DEF" 2>/dev/null || { _hata "tavan defterine yazılan satır geri OKUNAMADI — kapı AÇILMADI"; return 2; }
  _bilgi "⚠ TAVAN AÇILDI (tur $TUR) — REİS kararı karttan okundu ve deftere yazıldı (sınıfsız iş): $GEREKCE"
  return 0
}
# 🔴 ASIL YAKMA BURADA OLUYORDU (gorev WC3VBZAA): bu iki kapı denetçi HIÇ KOŞMADAN tavanı
#    kapatıyor ve HAM tur sayısına bakıyordu. cloudtop #635'in dört turu böyle yandı: her tur
#    "canlıda kurulu değil" bulgusu döndü, kutuda yapılacak bir şey söylenmedi, ama tur dolду.
#    Artık SAYILI tura bakılıyor: bulgularının hepsi kutu-dışı olan turlar tavandan düşmez.
KD_TAVAN="${DENETCI_KUTU_DISI_TAVAN:-2}"
YAKMAYAN_ONCE="$ARDISIK_ONCE"
# Muafiyet sınırsız değil: üst üste yalnız kutu-dışı bulgu dönen iş KUTUDA İLERLETİLEMİYOR demektir.
# Bu kapı denetçiden ÖNCE: boşuna bir codex koşumu daha yapmayalım.
if [ "$YAKMAYAN_ONCE" -gt "$KD_TAVAN" ]; then
  _bilgi ""
  _bilgi "⛔ KUTUDA İLERLETİLEMİYOR — son $YAKMAYAN_ONCE tur üst üste yalnız kutu-dışı bulgu döndü (tavan $KD_TAVAN); denetim koşulmadı."
  _bilgi "   Bu bir KOD tıkanması DEĞİLDİR; işin kalanı başka bir yüzeyde."
  _bilgi "   Gereken yüzeyler: $DZ/KUTU-DISI.jsonl"
  _bilgi "   Üç yol (karar iş sahibinin/reisin): 1) YÜZEYE GİT — o yüzeyde ölçen bir kart/görev aç"
  _bilgi "   2) KAPSAMI DARALT — kutuda biteni gönder, kutu-dışını yeni kart yap"
  _bilgi "   3) GERİ AL — alanı kapat, ders deftere"
  exit 4
fi
if [ "$SAYILI" -ge "$MUTLAK" ]; then _hata "mutlak tavan ($MUTLAK) aşıldı — denetim koşulmadı"; tikandi_raporu; exit 4; fi
if [ "$SAYILI" -ge "$TAVAN" ]; then
  if ilerliyor_mu; then _bilgi "· tur $TUR: tavan $TAVAN aşıldı ama iş İLERLİYOR (puan↑, bulgu↓) → +1 tur payı"
  else
    sultan_kapisi; sk=$?
    [ "$sk" -eq 2 ] && exit 1
    if [ "$sk" -ne 0 ]; then
      reis_kapisi; rk=$?
      [ "$rk" -eq 2 ] && exit 1
      if [ "$rk" -ne 0 ]; then
        _hata "tavan ($TAVAN) doldu ve iş ilerlemiyor — denetim koşulmadı"; tikandi_raporu
        _bilgi "   Sultan 'devam' dediyse: önce kart.sh sultan-dedi ile kayda geçir, sonra --sultan-devam"
        _bilgi "   SINIFSIZ işte sahip/reis 'devam' diyorsa: kart.sh reis-dedi ile kayda geçir, sonra --reis-devam"
        exit 4
      fi
    fi
  fi
fi

# ── 3 · girdiler ─────────────────────────────────────────────────────────────────
TMP="$(mktemp -d)"   # temizliği _bitis (EXIT tuzağı) yapar
# 🔴 FARKI DENETÇİ KENDİSİ ALIR (18 Eki, gorev_01M54B2Y4QT7VWTJX10AFR7M76): elle hazırlanan fark üç kez tur yaktı (11 Eki):
#    iki-nokta `git diff origin/main` dal gerideyken başkasının eklemelerini "silinmiş" gösterdi, odaklı fark dosya kaçırdı.
#    Kural: (a) --diff verilmişse o (çağıranın sorumluluğu, fark kaynağı ekranda söylenir); (b) --pr ile GitHub farkı alınır AMA
#    PR dalının yerel kopyası varsa ve başı PR başından farklıysa DUR — o an hangi dalda durulduğundan bağımsız (itilmemiş/çekilmemiş commit);
#    (c) ikisi de yoksa yerel kip: fetch → dal ana hattın GERİSİNDEYSE DUR (rebase/merge çağıranın işi; araç dalı değiştirmez) →
#    kayıtsız değişiklik (kanıt/kart dizini dışında) varsa DUR (farka girmez) → üç-nokta `<ana>...HEAD`. Durmak rc=3 (ölçülemedi).
if [ -n "$DIFF" ]; then cp "$DIFF" "$TMP/diff.patch" || { _hata "diff okunamadı"; exit 3; }; FARK_KAYNAK="--diff $DIFF (çağıranın verdiği)"
elif [ -n "$PR" ]; then
  PR_BAS="$(cd "$DEPO" && gh pr view "$PR" --json headRefOid,headRefName --jq '.headRefOid+" "+.headRefName' 2>/dev/null)" \
    || { _hata "gh pr view $PR düştü — PR başı ölçülemedi"; exit 3; }
  # Karşılaştırılan şey PR dalının YEREL kopyasının başıdır — o an hangi dalda durulduğu değil (göz tur 1: "yalnız aynı daldaysan"
  # istisnası kartın şartından dardı). Yerel kopya yoksa (başkasının PR'ı, hiç çekilmemiş) itilmemiş commit de olamaz → devam.
  PR_DAL="${PR_BAS#* }"; PR_SHA="${PR_BAS%% *}"
  YEREL_BAS="$(git -C "$DEPO" rev-parse -q --verify "refs/heads/$PR_DAL" 2>/dev/null)"
  if [ -n "$PR_SHA" ] && [ -n "$YEREL_BAS" ] && [ "$YEREL_BAS" != "$PR_SHA" ]; then
    _hata "PR #$PR dalının ($PR_DAL) yerel başı (${YEREL_BAS:0:8}) PR başından (${PR_SHA:0:8}) FARKLI — itilmemiş ya da çekilmemiş commit var; göz GitHub'daki farkı puanlardı. Önce it/çek, sonra koştur"; exit 3
  fi
  (cd "$DEPO" && gh pr diff "$PR" > "$TMP/diff.patch") || { _hata "gh pr diff $PR düştü"; exit 3; }
  FARK_KAYNAK="gh pr diff $PR (baş ${PR_BAS:0:8})"
else
  ANA="$(git -C "$DEPO" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
  git -C "$DEPO" fetch -q origin 2>/dev/null || { _hata "git fetch origin düştü — ana hat ($ANA) ölçülemedi"; exit 3; }
  git -C "$DEPO" rev-parse --verify -q "$ANA" >/dev/null || { _hata "ana hat $ANA bulunamadı"; exit 3; }
  GERIDE="$(git -C "$DEPO" rev-list --count "HEAD..$ANA")"
  [ "$GERIDE" -eq 0 ] || { _hata "dal ana hattın ($ANA) $GERIDE commit GERİSİNDE — fark başkasının işini 'silinmiş' gösterirdi. Önce rebase/merge, sonra koştur"; exit 3; }
  KIRLI="$(git -C "$DEPO" status --porcelain -uall | grep -v -E '^.. _agents/fabrika/(kanit|kartlar)/' | wc -l)"
  [ "$KIRLI" -eq 0 ] || { _hata "$KIRLI kayıtsız değişiklik var (kanıt/kart dışı) — farka girmez, göz eksik kod görürdü. Önce commit'le"; exit 3; }
  git -C "$DEPO" diff "$ANA...HEAD" > "$TMP/diff.patch" || { _hata "git diff $ANA...HEAD düştü"; exit 3; }
  [ -s "$TMP/diff.patch" ] || { _hata "fark BOŞ ($ANA...HEAD) — denetlenecek değişiklik yok"; exit 3; }
  FARK_KAYNAK="yerel üç-nokta $ANA...HEAD ($(git -C "$DEPO" rev-list --count "$ANA..HEAD") commit)"
fi
echo "· fark: $FARK_KAYNAK"
# ── KANIT FARKA İKİNCİ KEZ GİRMESİN (15 Eki 2026, gorev_01M4ZSKHD1Y1FFT8P6Z5YMPTF9)
#    Ölçülmüş vaka (PR #329, aynı gün): istem 135.913 bayt oldu, 110.000'de kırpıldı ve denetçi ÜRETİM KODU
#    farkını hiç göremedi — "kodun kendisi bütünüyle denetlenemedi, bu eksikle 5 verilemez" dedi. Bir tur
#    yandı, kod kusursuzdu: aynı kod kırpılmamış farkla 5/5+E aldı. Şişkinliğin kaynağı şuydu: farkın
#    136 KB'ının ~90 KB'ı `_agents/fabrika/kanit/` altındaki ölçüm dökümleriydi — oysa kanıt manifesti VE
#    ölçüm çıktıları denetçiye aşağıda ZATEN AYRI gidiyor. Aynı veri farka ikinci kez giriyor ve asıl
#    kanıtı, yani kodu, istemden dışarı itiyordu.
#    Bu AYIKLAMA, saklama DEĞİL: ayıklanan şey denetçiye ayrı başlıklarla sunulur ve ayıklandığı hem ekrana
#    hem DENETIM kaydına yazılır. Kapatmak için: DENETCI_KANIT_AYIKLA=0.
AYIKLANAN_DOSYA=0; AYIKLANAN_BAYT=0
if [ "${DENETCI_KANIT_AYIKLA:-1}" != 0 ]; then
  python3 - "$TMP/diff.patch" "$TMP/diff-ayik.patch" <<'PYA'
import re, sys
ham = open(sys.argv[1], encoding="utf-8", errors="replace").read()
# Birleşik farkı dosya bloklarına böl: her blok "diff --git " ile başlar. Baştaki başlık (varsa) korunur.
parcalar = re.split(r'(?m)^(?=diff --git )', ham)
tut, at = [], []

# 🔴 TUR-2 BULGUSU (uygulama): yol yalnız `^diff --git a/(\S+) b/(\S+)` ile okunuyordu. `\S+` BOŞLUKTA
#    kesilir ve git'in tırnaklı yol biçimini (`diff --git "a/x y" "b/x y"`) hiç tanımaz; eşleşme düşünce
#    blok korunuyordu, yani boşluklu ya da tırnaklı bir kanıt dosyası farkta kalıp istemi yeniden
#    şişirebilirdi. `+++ b/<yol>` satırı tek anlamlıdır (sekmeye kadar); silinen dosyada `--- a/<yol>`
#    kullanılır. Üçü sırayla denenir ve tırnaklı biçim C-kaçışlarıyla çözülür.
BASLIK = re.compile(r'(?m)^(?:\+\+\+ |--- )(?!/dev/null$)(.+?)(?:\t.*)?$')
GIT = re.compile(r'(?m)^diff --git (?:"((?:[^"\\]|\\.)*)"|(\S+)) (?:"((?:[^"\\]|\\.)*)"|(\S+))\s*$')


def _coz(y):
    """Tırnaklı/kaçışlı git yolunu çöz, a/ · b/ önekini at."""
    y = y.strip()
    if len(y) >= 2 and y[0] == '"' and y[-1] == '"':
        y = y[1:-1]
        if "\\" in y:
            try:
                y = y.encode("latin-1", "backslashreplace").decode("unicode_escape")
            except Exception:
                pass
    return y[2:] if y[:2] in ("a/", "b/") else y


def blok_yolu(blok):
    for m in BASLIK.finditer(blok):
        y = _coz(m.group(1))
        if y and y != "/dev/null":
            return y
    m = GIT.search(blok)
    if m:
        for g in (m.group(3), m.group(4), m.group(1), m.group(2)):
            if g:
                return _coz(g if g.startswith(('"', "a/", "b/")) else '"' + g + '"')
    return None


for blok in parcalar:
    if not blok.startswith("diff --git "):
        tut.append(blok)            # fark olmayan baş kısım: dokunulmaz
        continue
    yol = blok_yolu(blok)
    # 🔴 Yol ÖLÇÜLEMEDİYSE blok KORUNUR: ayıklama şüphede ayıklamaz. Yanlış ayıklama, ayıklamamaktan
    #    pahalıdır — sessizce üretim kodunu gizler.
    if yol is None:
        tut.append(blok)
        continue
    # 🔴 TUR-1 BULGUSU (uygulama): koşul alt dize arıyordu — `docs/_agents/fabrika/kanit/x` adlı bir
    #    ÜRETİM dosyası da sessizce denetçiden çıkardı. Fark yolları depo köküne göredir; eşleşme de
    #    kökten olmalı.
    if yol.startswith("_agents/fabrika/kanit/"):
        at.append((yol, len(blok.encode("utf-8"))))
    else:
        tut.append(blok)
open(sys.argv[2], "w", encoding="utf-8").write("".join(tut))
# Sayılar çağıran tarafında zaten hesaplanıyor; buraya yazınca her koşumda ekrana "0 0" düşüyordu
# (kendi #332 işimden sızan gürültü, bu turda yakalandı).
pass
PYA
  # 🔴 TUR-1 BULGUSU (uygulama): eski kapı "ayıklanmış fark BOŞ değilse" diyordu; fark TAMAMEN kanıt
  #    dosyalarından oluştuğunda (kanıt tazeleme commit'i) ayıklama devre dışı kalıyor ve şişkin fark
  #    olduğu gibi gidiyordu — yani ayıklama tam gerektiği yerde çalışmıyordu. Boş fark meşru bir
  #    sonuçtur: denetçi o turda kanıt manifestine bakar, ve farkın NİÇİN boş olduğu kendisine yazılır.
  if [ -f "$TMP/diff-ayik.patch" ]; then
    OLD_B=$(wc -c < "$TMP/diff.patch"); NEW_B=$(wc -c < "$TMP/diff-ayik.patch")
    if [ "$NEW_B" -lt "$OLD_B" ]; then
      AYIKLANAN_BAYT=$((OLD_B - NEW_B))
      AYIKLANAN_DOSYA=$(grep -c '^diff --git ' "$TMP/diff.patch")
      KALAN=$(grep -c '^diff --git ' "$TMP/diff-ayik.patch")
      AYIKLANAN_DOSYA=$((AYIKLANAN_DOSYA - KALAN))
      mv "$TMP/diff-ayik.patch" "$TMP/diff.patch"
      _bilgi "· farktan AYIKLANDI: $AYIKLANAN_DOSYA kanıt dosyası ($AYIKLANAN_BAYT bayt) — kanıt manifesti ve ölçüm çıktıları denetçiye AYRI gidiyor, farka ikinci kez girmesin (kırpılma panzehiri)"
      [ -s "$TMP/diff.patch" ] || _bilgi "· ⚠ fark TAMAMEN kanıt dosyalarından oluşuyordu → kod farkı BOŞ; denetçiye söylendi (bu turda yalnız kanıt tazelendi)"
    fi
  else
    _bilgi "· ⚠ kanıt ayıklaması KOŞMADI (ayıklayıcı çıktı üretmedi) — fark olduğu gibi gider"
  fi
fi
if [ -z "$KART" ]; then KART="$(kart_yolu)" || exit 3; fi   # 0. adım kartı varsa o (YALNIZ birincil depodan; alandaki bayat kopya → rc=3)
[ -z "$KART" ] || [ -r "$KART" ] || { _hata "--kart dosyası okunamadı: $KART (verilen kart yoksa denetim kartsız SÜRMEZ)"; exit 3; }   # eskiden cp hatası sessizce yutuluyordu
# göz tur 3: --kart "kart TEK kaynak"ı aşamaz — birincil kart VARKEN içeriği farklı bir dosya iş kartı olamaz (rc=3); birincil yokken serbest
if [ -n "$KART" ]; then BIRINCIL="$(kart_yolu)" || exit 3
  if [ -n "$BIRINCIL" ] && ! cmp -s "$KART" "$BIRINCIL"; then _hata "kart TEK kaynak: --kart ($KART) birincil karttan ($BIRINCIL) FARKLI — birincil kart varken başka dosya iş kartı olamaz; --kart'ı bırak"; exit 3; fi
  # göz tur 4: içerik aynı olsa da OKUNAN YOL birincil karttır — harici kopya iş kartı/KART.json kaynağı olmaz (yol düzeyinde tek kaynak)
  if [ -n "$BIRINCIL" ] && [ "$KART" != "$BIRINCIL" ]; then KART="$BIRINCIL"; _bilgi "· --kart harici kopya (aynı içerik); okunan yol birincil kart: $KART"; fi
fi
if [ -n "$KART" ] && [ -d "$DZ" ]; then   # kanıt dizinine anlık kopya: PR'a kart bununla gider — yazılamadıysa sessiz geçilmez (göz tur 1)
  cp "$KART" "$DZ/KART.json" 2>/dev/null || { _hata "kartın anlık kopyası kanıt dizinine YAZILAMADI ($DZ/KART.json) — PR'a kart gitmezdi, denetim açılmaz"; exit 3; }
fi
if [ -n "$KART" ]; then cp "$KART" "$TMP/kart.md"
elif [ -n "$PR" ]; then (cd "$DEPO" && gh pr view "$PR" --json title,body --jq '"# \(.title)\n\n\(.body)"' > "$TMP/kart.md") || echo "(iş kartı okunamadı)" > "$TMP/kart.md"
else echo "(iş kartı verilmedi — talep bilinmiyor; DOĞRU ŞEY Mİ sorusu H'ye yakın değerlendirilir)" > "$TMP/kart.md"; fi
# İstem PARÇA PARÇA kurulur, sonra birleşir (BÂNİ 21:59, 18 Eki): boyut kapısı aşağıda istemin tamamını ölçer ve
# aşınca HANGİ parçanın şiştiğini söyler. Birleşen metin eskisiyle bayt bayt aynıdır.
{ cat "$ISTEM"; } > "$TMP/p-sablon.md"
{ printf '\n\n===== İŞ KARTI (talep) =====\n'; cat "$TMP/kart.md"; } > "$TMP/p-kart.md"
{ printf '\n\n===== KANIT MANİFESTİ — durum: %s =====\n' "$KANIT_DURUM"; cat "$DZ/KANIT.json"; } > "$TMP/p-kanit.md"
# ÖLÇÜM ÇIKTISININ SONU DA GİDER (gorev_01M5890SCNMSR4DFTGHVWEJEC3, retro W42 HENDESE Ö1): eskiden her ölçüm dosyasının
#   ilk 60 satırı gidiyordu. Sınavın sonuç satırı ("SONUÇ: 156 geçti · 0 kaldı") dosyanın SONUNDA; 184 satırlık bir sınav
#   ölçümünde göz yalnız baştaki kapıları görüyor, sonucu hiç görmüyordu. Artık 60 satırı aşan dosyada: stdout'un başı +
#   kaç satırın atlandığı + stdout'un sonu; stderr ayrıca kendi sonuyla (uzun stderr sonuç satırını dışarı itmesin).
#   Tavan aynı (dosya başı ≤ 60 satır), kısa dosya bayt bayt aynen.
olcum_ozeti() {   # olcum_ozeti <ölçüm dosyası>
  python3 - "$1" <<'PY'
import sys
HAM = open(sys.argv[1], encoding="utf-8", errors="replace").read()
L = HAM.split("\n")
if L and L[-1] == "": L.pop()
SINIR, BAS, SON, HSON, SECME = 60, 25, 12, 10, 8
if len(L) <= SINIR: sys.stdout.write(HAM); sys.exit()   # bayt bayt AYNEN (ayırıcı satır sonunu çağıran ekler — göz #392 tur 5)
# ATLANAN ORTADAN SEÇME (göz #392 tur 2): sonuç satırı her zaman en sonda değil (ardından 12'den fazla satır gelebilir) ve
#   kırmızı kapı (✗) ortada kalırsa kırpma onu SAKLAR — göz "yeşil" sanır. Ortadan SONUÇ/✗ taşıyan satırlar (en çok 8) taşınır.
SECILIR = ("SONUÇ", "SONUC", "✗", "Traceback")
e = len(L)
cik, err = L[:e], L[e:]
if len(err) > HSON + 1: err = [err[0], "[… stderr'den %d satır atlandı …]" % (len(err) - 1 - HSON)] + err[-HSON:]
if len(cik) > BAS + SON + 1:
    orta = cik[BAS:-SON]; sec = [x for x in orta if any(k in x for k in SECILIR)]
    atlanan = len(orta) - min(len(sec), SECME)          # seçilip gösterilenler atlanmış SAYILMAZ (göz #392 tur 3)
    not_ = "[… %d satır atlandı (dosya %d satır) — ölçümün SONU aşağıda …]" % (atlanan, len(L))
    if sec:
        not_ = "[… %d satır atlandı (dosya %d satır); ortadan SONUÇ/✗ taşıyan %d satır%s: …]" % (
            atlanan, len(L), len(sec), "" if len(sec) <= SECME else " (ilk %d'i)" % SECME)
    cik = cik[:BAS] + [not_] + sec[:SECME] + (["[… ölçümün SONU …]"] if sec else []) + cik[-SON:]
print("\n".join(cik + err))
PY
}
{
  printf '\n\n===== ÖLÇÜM ÇIKTILARI (60 satıra kadar aynen; uzunda baş + atlanan ortadan SONUÇ/✗ satırları + SON) =====\n'
  for f in "$DZ"/olcum-*.txt; do [ -f "$f" ] && { printf -- '--- %s ---\n' "$(basename "$f")"; olcum_ozeti "$f"; [ -z "$(tail -c1 "$f")" ] || echo; }; done   # satır sonuyla bitmeyen dosyadan sonra başlık yeni satırda
} > "$TMP/p-olcum.md"
{
  printf '\n\n===== DEĞİŞİKLİK (diff) =====\n'
  [ "$AYIKLANAN_DOSYA" -gt 0 ] && [ ! -s "$TMP/diff.patch" ] && printf '[NOT: bu turda fark TAMAMEN kanıt dosyalarından oluşuyordu (%s dosya, %s bayt); ÜRETİM KODU farkı BOŞTUR — eksik verilmedi, bu turda kod değişmedi. Hükmünü kanıt manifestine ve iş kartına dayandır.]\n' "$AYIKLANAN_DOSYA" "$AYIKLANAN_BAYT"
  [ "$AYIKLANAN_DOSYA" -gt 0 ] && [ -s "$TMP/diff.patch" ] && printf '[NOT: bu farktan %s kanıt dosyası (%s bayt) AYIKLANDI — kanıt manifesti ve ölçüm çıktıları yukarıda AYRI başlıklarda duruyor; saklanan bir şey yok, aynı veri farka ikinci kez girmesin diye çıkarıldı. Aşağısı ÜRETİM KODU farkıdır, eksik değildir.]\n' "$AYIKLANAN_DOSYA" "$AYIKLANAN_BAYT"
  cat "$TMP/diff.patch"
} > "$TMP/p-fark.md"
{ [ "$TUR" -gt 1 ] && { printf '\n\n===== ÖNCEKİ TUR (%s) =====\n' "$ONCEKI"; cat "$DZ/DENETIM-$ONCEKI.json"; }; } > "$TMP/p-onceki.md"
{
  if [ "${#KARELER[@]}" -gt 0 ]; then
    printf '\n\n===== KARELER (%s adet, bu isteme GÖRSEL olarak ekli — kabulün görsel kısmını bunlara bakarak değerlendir) =====\n' "${#KARELER[@]}"
    _i=0; for _k in "${KARELER[@]}"; do _i=$((_i+1)); printf '%s. %s · sha256 %s\n' "$_i" "$(basename "$_k")" "$(sha256sum "$_k" | cut -c1-16)"; done
  fi
} > "$TMP/p-kare.md"
ISTEM_PARCALARI=(sablon kart kanit olcum fark onceki kare)
for _p in "${ISTEM_PARCALARI[@]}"; do cat "$TMP/p-$_p.md"; done > "$TMP/istem.md"

# ── 4 · denetçiyi seç ve koş (yazan ≠ denetleyen) ───────────────────────────────
SEC_AUTO=0
if [ "$DENETCI" = "auto" ]; then SEC_AUTO=1; case "$YAZAN" in codex) DENETCI="claude" ;; *) DENETCI="codex" ;; esac; fi
[ "$DENETCI" != "$YAZAN" ] || { _hata "denetleyen ($DENETCI) yazanla ($YAZAN) AYNI — K1 ihlali; --denetci ile farklı model seç"; exit 1; }
# ── YEDEK GÖZ (Sultan Y0006, 12 Eki 2026): "codex kurulabilir ama eğer codex çalışmazsa claude ile puanlanabilir iş durmamalı."
#    Yalnız AUTO kipinde: codex YOKSA ya da iki denemede de DÜŞERSE, yazandan farklı YENİ bir Claude oturumu (claude -p) yedek
#    göz olur; iş "ölçemedim" diye durmaz. Kayıtta `yedek` alanı sebebi taşır — yedekle alınan puan, codex puanı sanılmaz.
#    Açık `--denetci codex` isteğinde eski sert davranış sürer (rc=3); DENETCI_YEDEK=0 yedeği kapatır.
#    Yedek yalnız yazanın modeli BİLDİRİLMİŞSE koşar (DENETCI_YAZAN_MODEL) ve ondan FARKLI bir kademe seçer; bildirilmemişse
#    rc=3 ve yeniden koşma satırı basılır — "farklı" iddiası ölçülmeden yeşil basılmaz (tur 2-3 bulguları).
YEDEK=""; YEDEK_MODEL=""; YAZAN_MODEL="${DENETCI_YAZAN_MODEL:-}"; YAZAN_MODEL_KAYNAK="${YAZAN_MODEL:+bildirim}"
# 🔴 Tur 4 (bağımsız göz #296): yazanın modeli ayrıca BİLDİRİLMESE de iş durmaz — ÖLÇÜLÜR. Denetçi hemen her zaman
#    yazanın kendi oturumundan çağrılır; o oturumun modeli iki yüzeyden okunur: (1) oturum sürecinin komut satırındaki
#    --model (CLAUDE_PID), (2) kullanıcı ayar dosyasındaki model. İkisi de yoksa ölçülemez → yedek koşmaz (rc=3, satır basılır).
if [ -z "$YAZAN_MODEL" ] && [ -n "${CLAUDE_PID:-}" ] && [ -r "/proc/$CLAUDE_PID/cmdline" ]; then
  YAZAN_MODEL="$(tr '\0' ' ' < "/proc/$CLAUDE_PID/cmdline" 2>/dev/null | grep -oE -- '--model[ =][^ ]+' | head -1 | sed 's/^--model[ =]//')"
  [ -n "$YAZAN_MODEL" ] && YAZAN_MODEL_KAYNAK="oturum-komutu"
fi
if [ -z "$YAZAN_MODEL" ] && [ -r "${DENETCI_AYAR_DOSYASI:-$HOME/.claude/settings.json}" ]; then
  YAZAN_MODEL="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));m=d.get('model');print(m if isinstance(m,str) else '')" "${DENETCI_AYAR_DOSYASI:-$HOME/.claude/settings.json}" 2>/dev/null)"
  [ -n "$YAZAN_MODEL" ] && YAZAN_MODEL_KAYNAK="ayar-dosyasi"
fi
_ayni_model() { case "$1" in *"$2"*) return 0 ;; esac; case "$2" in *"$1"*) return 0 ;; esac; return 1; }   # "sonnet" ≈ "claude-sonnet-5"
HAM="$TMP/ham.json"
# ── KIRPMA KAYDI (NÂZIR/RASATÇI 8 Eki 2026): kırpma eskiden yalnız istemin sonuna ve ekrana düşüyordu, ikisi de
#    kayboluyordu; DENETIM-<tur>.json'da alan yoktu. Artık her turda `kirpildi` {oldu · istem_bayt · esik} yazılır —
#    kırpılmamış turda da (oldu=false), "yok" ile "yazılmadı" ayırt edilsin. Kırpma Codex yoluna özgüdür (tek argüman
#    sınırı ~128 KB); DENETCI_KIRP_ESIK dikişi sınav için eşiği düşürür ve kırpmayı sahte denetçi yolunda da uygular.
KIRP_ESIK="${DENETCI_KIRP_ESIK:-110000}"; KIRP_TETIK=$((KIRP_ESIK + KIRP_ESIK/11))   # varsayılan 110000 → 120000
# ── İŞİ BÖL (PCP7J, 18 Eki 2026): kanıt ayıklandıktan sonra ÜRETİM FARKI tek başına eşiği aşıyorsa kırpıp
#    denetlemek yerine durulur: kırpılmış farkta denetçi sonu görmeden puan veriyordu (PR #329: üretim kodu
#    kırpıkta kaldı). Tur YAKILMAZ (DENETIM yazılmaz), rc=1 ile adım 2'ye dönülür; çare kart.sh daralt ile
#    iki iş. Kaçış yolu YOK — kart cümlesinde yok (18 Eki dersi).
# ── İSTEMİN TAMAMI ÖLÇÜLÜR (BÂNİ 21:59, 18 Eki · cloudtop #712 tur 4): kapı eskiden yalnız FARKI ölçüyordu. Fark 73 KB
#    olarak kapıdan geçti, ama göze giden istem = şablon + iş kartı + kanıt manifesti + ölçüm çıktıları + fark + önceki
#    tur 129.519 bayttı → 110.000'de kırpıldı, göz "diff sonu görülmedi" dedi ve mutlak dört tur içeriksiz yandı.
#    Kapı artık kırpma eşiğinin kendisini (KIRP_TETIK) istemin TAMAMINA uygular: kırpılacak istem gönderilmez, tur
#    yakılmaz, hangi parçanın şiştiği bayt bayt basılır.
#    Yalnız AYIKLANMIŞ farkta anlamlı: ayıklama kapalıysa (DENETCI_KANIT_AYIKLA=0) kanıt da farkın içindedir, işi
#    bölmek boyutu düşürmez → eski kırpma yolu sürer (ölçemediğine "böl" demez).
ISTEM_BAYT=$(wc -c < "$TMP/istem.md"); KIRPILDI=0
if { [ "$DENETCI" = "codex" ] || [ -n "${DENETCI_KIRP_ESIK:-}" ]; } && [ "${DENETCI_KANIT_AYIKLA:-1}" != "0" ] && [ "$ISTEM_BAYT" -gt "$KIRP_TETIK" ]; then
  declare -A _AD=([sablon]="istem şablonu" [kart]="iş kartı" [kanit]="kanıt manifesti" [olcum]="ölçüm çıktıları" [fark]="üretim farkı" [onceki]="önceki tur kaydı" [kare]="kare listesi")
  _DOKUM=""; _EN=""; _EN_B=-1
  for _p in "${ISTEM_PARCALARI[@]}"; do
    _b=$(wc -c < "$TMP/p-$_p.md"); _DOKUM="$_DOKUM · ${_AD[$_p]} $_b"
    [ "$_b" -gt "$_EN_B" ] && { _EN="$_p"; _EN_B="$_b"; }
  done
  _hata "İŞİ BÖL — göze giden istem $ISTEM_BAYT bayt > $KIRP_TETIK (kırpma eşiği; kanıt dosyaları farktan ayıklandıktan sonra): kırpık istemle denetim yapılmaz, tur yakılmadı."
  _bilgi "   parçalar (bayt):${_DOKUM}"
  _bilgi "   en büyük parça: ${_AD[$_EN]} ($_EN_B bayt)"
  case "$_EN" in
    olcum|kanit) _bilgi "   yol: ölçüm kayıtlarını küçült (yalnız kartın istediği ölçümler kalsın; yanlış kaydı kanit.sh gecersiz ile ilan et) ya da işi böl: kart.sh daralt <iş> --kalan \"<ikinci yarı>\" --cumle \"<bu PR'ın yaptığı>\" --oturum <ref>" ;;
    *) _bilgi "   yol: kart.sh daralt <iş> --kalan \"<ikinci yarı>\" --cumle \"<bu PR'ın yaptığı>\" --oturum <ref> → kalan yarı yeni kart/dal; bu dalda yalnız daraltılmış cümle kalsın" ;;
  esac
  exit 1   # İŞİ BÖL
fi
if { [ "$DENETCI" = "codex" ] || [ -n "${DENETCI_KIRP_ESIK:-}" ]; } && [ "$ISTEM_BAYT" -gt "$KIRP_TETIK" ]; then
  # İstem ARGÜMAN olarak verilir, dosya olarak değil: bu konteynerde Codex'in kum havuzu (bwrap) ad-alanı
  # açamıyor ve "dosyayı oku" komutu düşüyor (22 Eyl canlı koşum: 2/H "istem.md okunamadı"). Tek argüman
  # sınırı ~128 KB → diff büyükse kırpılır ve istemde SÖYLENİR (sessiz kırpma yok).
  head -c "$KIRP_ESIK" "$TMP/istem.md" > "$TMP/istem-kirpik.md"
  printf '\n\n[UYARI: istem %s bayttı, %s baytta KIRPILDI — diff'"'"'in sonu görülmedi; puanı buna göre ver, kırpıldığını özete yaz]\n' "$ISTEM_BAYT" "$KIRP_ESIK" >> "$TMP/istem-kirpik.md"
  mv "$TMP/istem-kirpik.md" "$TMP/istem.md"; KIRPILDI=1; _bilgi "⚠ istem $ISTEM_BAYT bayt → $KIRP_ESIK'e kırpıldı (denetçiye söylendi, DENETIM kaydına yazılır)"
fi
if [ -n "${DENETCI_KOMUT:-}" ]; then
  DENETCI_AD="$DENETCI_KOMUT (sınav)"; _sinirli $DENETCI_KOMUT "$TMP/istem.md" > "$HAM" 2>"$TMP/err"; DRC=$?
else
  kos_codex() {
    # 🔴 STDIN KAPALI (15 Eki, 68 dk boşa): istem argümanla verildiği hâlde Codex stdin TTY değilse "Reading additional input
    #    from stdin..." deyip EOF bekler; arka plandan (run_in_background, cron) çağrıda stdin açık socket olunca denetim sonsuza
    #    dek asılı kalır (CPU 0, log boş). Girdi her koşulda /dev/null'dan: çağıranın stdin'i ne olursa olsun denetçi biter.
    local kare_arg=(); for _k in "${KARELER[@]}"; do kare_arg+=(-i "$_k"); done   # kareler GÖRSEL ek (codex exec -i)
    _sinirli codex exec -s read-only --skip-git-repo-check --ephemeral -C "$TMP" ${MODEL:+-m "$MODEL"} "${kare_arg[@]}" \
      --output-schema "$SEMA" -o "$HAM" "$(printf 'Hiçbir komut koşma, dosya okuma; gereken her şey aşağıda. Talimata göre YALNIZ JSON üret.\n\n'; cat "$TMP/istem.md")" </dev/null >"$TMP/log" 2>"$TMP/err"; DRC=$?
  }
  kos_claude() {   # yeni oturum: claude -p her çağrıda sıfırdan açılır → yazanın oturumu değildir
    command -v claude >/dev/null || { _hata "claude yok — denetçi ölçemedi"; exit 3; }
    # 🔴 K1 YENİDEN (bağımsız göz #296 tur 1): yazan claude ise yedek göz de claude olur — AYNI MODELİ aynı oturumda
    #    kullanmak K1 ihlali olurdu. Y0006 şartı "yazandan farklı oturum/model" der; yedek bu yüzden (1) yeni oturum ve
    #    (2) AÇIKÇA farklı bir model kademesi (DENETCI_YEDEK_MODEL, varsayılan sonnet) ile koşar; kademe kayda yazılır.
    #    🔴 Tur 2 (bağımsız göz #296): "farklı kademe" varsayılan bir adla ÖRTÜLMEZ, yazanın modeliyle KARŞILAŞTIRILIR.
    #    Yazanın modeli DENETCI_YAZAN_MODEL ile bildirilir; seçilen yedek ona eşitse merdivende bir sonrakine geçilir
    #    (tercih: DENETCI_YEDEK_MODEL > --model > sonnet > haiku > opus). Bildirilmediyse fark GARANTİ EDİLEMEZ: kayda
    #    yazan_model=null yazılır ve ekranda söylenir — "farklı" iddiası ölçülmemişken yeşil basılmaz.
    local ymodel="$MODEL" aday
    if [ -n "$YEDEK" ] && [ "$YAZAN" = "claude" ]; then
      # 🔴 Tur 3 (bağımsız göz #296): yazanın modeli BİLİNMEDEN yedek koşmaz — "farklı" iddiası ölçülemiyorsa kapı KAPALIDIR
      #    (K1 yazan ≠ denetleyen). İş durmaz: aynı komut DENETCI_YAZAN_MODEL=<yazanın modeli> ile yeniden koşulur (tek satır).
      if [ -z "$YAZAN_MODEL" ]; then
        _hata "yedek göz için yazanın modeli ÖLÇÜLEMEDİ (oturum komut satırında --model yok, ayar dosyasında model yok): DENETCI_YAZAN_MODEL=<model> ile yeniden koş (ör. DENETCI_YAZAN_MODEL=fable) — 'yazandan farklı' ölçülmeden yedek koşmaz (K1)"
        exit 3
      fi
      ymodel=""
      for aday in "${DENETCI_YEDEK_MODEL:-}" "${MODEL:-}" sonnet haiku opus; do
        [ -n "$aday" ] || continue
        if [ -n "$YAZAN_MODEL" ] && _ayni_model "$aday" "$YAZAN_MODEL"; then continue; fi
        ymodel="$aday"; break
      done
      YEDEK_MODEL="$ymodel"
      [ -n "$ymodel" ] && ! _ayni_model "$ymodel" "$YAZAN_MODEL" || { _hata "yazandan farklı yedek model bulunamadı (yazan: $YAZAN_MODEL)"; exit 3; }
      _bilgi "· yedek kademe: yazan $YAZAN_MODEL ($YAZAN_MODEL_KAYNAK) ≠ yedek $ymodel (ölçüldü)"
    fi
    DENETCI_AD="claude${ymodel:+ ($ymodel)}${YEDEK:+ (YEDEK GÖZ: $YEDEK · yazandan farklı yeni oturum + farklı model kademesi${YAZAN_MODEL:+ [yazan: $YAZAN_MODEL]} · Sultan Y0006)}"
    if [ "${#KARELER[@]}" -gt 0 ]; then printf '\n\n[UYARI: %s kare bu yedek göze GÖRSEL olarak verilemedi (claude -p kanalı görsel taşımıyor) — görsel kabul için yalnız adlara ve ölçüm çıktılarına bakabilirsin; bunu özete yaz]\n' "${#KARELER[@]}" >> "$TMP/istem.md"; KARE_VERILEMEDI=1; fi
    _sinirli claude -p ${ymodel:+--model "$ymodel"} --output-format json --json-schema "$(cat "$SEMA")" < "$TMP/istem.md" > "$TMP/claude.json" 2>"$TMP/err"; DRC=$?
    python3 -c "import json,sys;d=json.load(open('$TMP/claude.json'));r=d.get('structured_output') or d.get('result');print(r if isinstance(r,str) else json.dumps(r,ensure_ascii=False))" > "$HAM" 2>/dev/null || cp "$TMP/claude.json" "$HAM"
  }
  yedek_olur_mu() { [ "$SEC_AUTO" = 1 ] && [ "${DENETCI_YEDEK:-1}" != 0 ]; }
  if [ "$DENETCI" = "codex" ]; then
    if ! command -v codex >/dev/null; then
      if yedek_olur_mu; then YEDEK="codex yok"; _bilgi "⚠ codex yok → YEDEK GÖZ: yazandan farklı yeni Claude oturumu (Sultan Y0006)"; kos_claude
      else _hata "codex yok — denetçi ölçemedi"; exit 3; fi
    else
      DENETCI_AD="codex${MODEL:+ ($MODEL)}"; kos_codex
      # zaman aşımında yeniden deneme/yedek YOK: her biri 15 dk daha bekletirdi (45 dk sessizlik) — aşım ölçülemedi'dir, rc 3
      if [ "$DRC" -ne 0 ] && [ "$DRC" -ne 124 ]; then _bilgi "⚠ codex düştü (rc=$DRC) — bir kez daha deneniyor"; kos_codex; fi
      if [ "$DRC" -ne 0 ] && [ "$DRC" -ne 124 ] && yedek_olur_mu; then
        YEDEK="codex düştü (2 deneme, rc=$DRC)"; _bilgi "⚠ codex iki denemede düştü → YEDEK GÖZ: yazandan farklı yeni Claude oturumu (Sultan Y0006)"; kos_claude
      fi
    fi
  else kos_claude; fi
fi
if [ "$DRC" -eq 124 ]; then
  ZAMAN_ASIMI=1; _hata "denetçi ($DENETCI_AD) ZAMAN AŞIMI: $ZA sn içinde bitmedi — ölçülemedi (rc 3)"
  { printf 'ZAMAN AŞIMI — denetçi (%s) %s sn içinde bitmedi (DENETCI_ZAMAN_ASIMI); puan yok, tur sayılmaz.\n--- kısmi çıktı ---\n' "$DENETCI_AD" "$ZA"; cat "$HAM" 2>/dev/null; } > "$DZ/DENETIM-$TUR-HAM.txt"
  exit 3
fi
if [ "$DRC" -ne 0 ]; then _hata "denetçi ($DENETCI_AD) düştü rc=$DRC"; head -5 "$TMP/err" >&2; cp "$HAM" "$DZ/DENETIM-$TUR-HAM.txt" 2>/dev/null; exit 3; fi

# ── 5 · çıktıyı doğrula, kaydet, karar ver ───────────────────────────────────────
# 🔴 Doğrulanmış JSON kabuğa DEĞİŞKEN olarak taşınmaz, DOSYADA kalır. Neden: denetçi Türkçe yazıyor ve
# metindeki kesme işareti python gömmesini kırıyordu (23 Eyl canlı koşum: tur 1 sonucu diske yazıldı ama
# betik JSONDecodeError verdi, ardından "[: : integer expression expected"). Araçlar arası veri dosyadan
# geçer, kabuk alıntısından değil.
DOGRULANMIS="$TMP/sonuc.json"
python3 - "$HAM" "$DOGRULANMIS" <<'PY'
import json,sys,re
ham=open(sys.argv[1],encoding='utf-8').read().strip()
m=re.search(r'\{.*\}',ham,re.S)
try: d=json.loads(m.group(0) if m else ham)
except Exception as e: print("GEÇERSİZ:"+str(e),file=sys.stderr); sys.exit(3)
ok=isinstance(d.get("kod_puani"),int) and 0<=d["kod_puani"]<=5 and d.get("dogru_sey") in("E","H") and isinstance(d.get("bulgular"),list)
if not ok: print("GEÇERSİZ: alanlar eksik/yanlış",file=sys.stderr); sys.exit(3)
# 🔴 KUTU-DIŞI SINIFI FAIL-CLOSED (gorev WC3VBZAA): sınıf bir MUAFİYET taşıyor (puanı düşürmez, tur
#    yakmaz). Muafiyeti bedelsiz vermek, her bulguyu "kutuda ölçemedim" diye etiketlemenin kapısını
#    açardı. Bedel şudur: HANGİ yüzey gerekiyor, yazılmak zorunda. Yüzey yoksa sınıf DÜŞÜRÜLÜR
#    (uygulama) ve düşürüldüğü kayda yazılır — sessizce kabul de, sessizce ret de etmiyoruz.
dusurulen=[]
for b in d["bulgular"]:
    if not all(k in b for k in("ne","kanit","konum","agirlik")): print("GEÇERSİZ: bulgu alanları eksik",file=sys.stderr); sys.exit(3)
    if b.get("agirlik")=="kutu-disi":
        yuzey=str(b.get("kutu_disi_yuzey","") or "").strip()
        if len(yuzey)<3:
            b["agirlik"]="uygulama"; b["_sinif_dusuruldu"]="kutu-disi → uygulama: kutu_disi_yuzey boş ya da çok kısa"
            dusurulen.append(b.get("ne","?")[:60])
json.dump(d,open(sys.argv[2],"w",encoding="utf-8"),ensure_ascii=False)
if dusurulen:
    sys.stderr.write("SINIF-DUSURULDU: "+" · ".join(dusurulen)+"\n")
PY
SRC=$?
if [ "$SRC" -ne 0 ]; then _hata "denetçi çıktısı geçersiz — ölçemedi"; cp "$HAM" "$DZ/DENETIM-$TUR-HAM.txt"; exit 3; fi
KARE_KAYIT="$(for _k in "${KARELER[@]}"; do printf '%s\t%s\n' "$(basename "$_k")" "$(sha256sum "$_k" | cut -d' ' -f1)"; done)"
python3 - "$DZ/DENETIM-$TUR.json" "$TUR" "$IS" "$PR" "$YAZAN" "$DENETCI_AD" "$KANIT_DURUM" "$DOGRULANMIS" "$KIRPILDI" "$ISTEM_BAYT" "$KIRP_ESIK" "$YEDEK" "$YAZAN_MODEL" "$YEDEK_MODEL" "$YAZAN_MODEL_KAYNAK" "$AYIKLANAN_DOSYA" "$AYIKLANAN_BAYT" "$KARE_KAYIT" "${KARE_VERILEMEDI:-0}" <<'PY'
import json,sys,datetime
yol,tur,is_,pr,yazan,den,kd,sonuc_yolu,kirp,bayt,esik,yedek,yazan_model,yedek_model,ym_kaynak,ayik_dosya,ayik_bayt,kare_kayit,kare_verilemedi=sys.argv[1:]
kareler=[{"ad":a,"sha256":h} for a,h in (l.split("\t") for l in kare_kayit.splitlines() if "\t" in l)]
json.dump({"tur":int(tur),"is":is_,"pr":pr,"yazan":yazan,"denetci":den,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
           "kanit_durumu":kd,
           "yedek":(yedek or None),   # Sultan Y0006: yedek gözle alınan puan codex puanı sanılmasın; sebebi kayıtta
           "yazan_model":(yazan_model or None), "yazan_model_kaynak":(ym_kaynak or None), "yedek_model":(yedek_model or None),   # yedek koşumunda dolu (ölçülemezse yedek koşmaz, rc=3)

           "kirpildi":{"oldu":kirp=="1","istem_bayt":int(bayt),"esik":int(esik)},   # kalıcı kayıt: kırpılan denetim "tam gördü" sanılmasın
           # Kanıt dökümleri farka ikinci kez girip kodu istemden dışarı itiyordu (PR #329 turu yandı).
           # Ayıklama kayıtta durur: "fark eksikti" ile "kanıt ayrı gitti" sonradan ayırt edilsin.
           "kanit_ayiklandi":{"dosya":int(ayik_dosya),"bayt":int(ayik_bayt)},
           "kareler":({"adet":len(kareler),"gorsel_verildi":kare_verilemedi!="1","liste":kareler} if kareler else None),   # --kare: göz kareyi GÖRDÜ mü (yedek gözde hayır)
           "sonuc":json.load(open(sonuc_yolu,encoding="utf-8"))},open(yol,"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PY
_oku() { python3 -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));print(len(d['bulgular']) if sys.argv[2]=='n' else d[sys.argv[2]])" "$DOGRULANMIS" "$1"; }
PUAN="$(_oku kod_puani)"; DOGRU="$(_oku dogru_sey)"; NB="$(_oku n)"
[ -n "$PUAN" ] && [ -n "$DOGRU" ] || { _hata "puan okunamadı — ölçemedi"; exit 3; }
_bilgi "── DENETİM tur $TUR · denetçi: $DENETCI_AD · yazan: $YAZAN"
_bilgi "   KOD İYİ Mİ: $PUAN/5 · DOĞRU ŞEY Mİ: $DOGRU · bulgu: $NB · kanıt: $KANIT_DURUM"
[ "$KIRPILDI" -eq 1 ] && _bilgi "   ⚠ KIRPILDI: istem $ISTEM_BAYT bayt → $KIRP_ESIK (diff'in sonu görülmedi; kayıtta kirpildi.oldu=true)"
python3 - "$DOGRULANMIS" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
print("   özet: "+d["ozet"])
kd=[b for b in d["bulgular"] if b.get("agirlik")=="kutu-disi"]
for b in d["bulgular"]:
    if b.get("agirlik")=="kutu-disi": continue
    ds=" ⚠ "+b["_sinif_dusuruldu"] if b.get("_sinif_dusuruldu") else ""
    print(f"   • [{b['agirlik']}] {b['ne']} — {b['konum']} — kanıt: {b['kanit']}{ds}")
if kd:
    print(f"   ── KUTU-DIŞI ({len(kd)}) — bu kutuda ölçülemez/düzeltilemez; tur YAKMAZ, puanı DÜŞÜRMEZ:")
    for b in kd:
        print(f"   ⊗ {b['ne']} — gereken yüzey: {b.get('kutu_disi_yuzey','?')} — {b['konum']}")
    print("   → bu bulgular işin SAHIBINE gider (ayrı kart/görev); kutuda kapatılamaz.")
PY
_bilgi "   kayıt: $DZ/DENETIM-$TUR.json"
# 🔴 Kutu-dışı bulgu "tur yakmadı" diye KAYBOLMAMALI: muafiyetin karşılığı izlenebilirliktir.
#    Ayrı bir deftere (append-only) yazılır; işin sahibi buradan kart/görev açar.
python3 - "$DOGRULANMIS" "$DZ/KUTU-DISI.jsonl" "$TUR" "$IS" <<'PYKD'
import json,sys,datetime
sonuc,defter,tur,is_=sys.argv[1:]
kd=[b for b in json.load(open(sonuc,encoding="utf-8"))["bulgular"] if b.get("agirlik")=="kutu-disi"]
if kd:
    var=set()
    try:
        for sat in open(defter,encoding="utf-8"):
            sat=sat.strip()
            if sat: var.add(json.loads(sat).get("ne",""))
    except FileNotFoundError: pass
    with open(defter,"a",encoding="utf-8") as f:
        for b in kd:
            if b.get("ne","") in var: continue      # aynı bulgu her turda yeniden yazılmaz
            f.write(json.dumps({"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
                                "is":is_,"tur":int(tur),"ne":b.get("ne"),
                                "yuzey":b.get("kutu_disi_yuzey"),"konum":b.get("konum"),
                                "kanit":b.get("kanit")},ensure_ascii=False)+"\n")
    print(f"   kutu-dışı defteri: {defter}")
PYKD
if [ "$PUAN" -eq 5 ] && [ "$DOGRU" = "E" ]; then _bilgi "✓ GEÇTİ — merge kararı: sınıf işi Sultan, sınıfsız iş kutu reisi"; exit 0; fi
# 🔴 Tavan SAYILI tura uygulanır (bu turun kendisi dahil edilerek yeniden hesaplanır).
SAYILI_SON=$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
b=d['bulgular']
print(int(sys.argv[2]) + (1 if (not b or any(x.get('agirlik')!='kutu-disi' for x in b)) else 0))
" "$DOGRULANMIS" "$SAYILI")
case "$SAYILI_SON" in ''|*[!0-9]*) SAYILI_SON="$TUR" ;; esac
# Bu turun kendisi yakmadıysa ardışık dizi uzar; yaktıysa SIFIRLANIR.
if [ "$SAYILI_SON" -gt "$SAYILI" ]; then YAKMAYAN=0; else YAKMAYAN=$((ARDISIK_ONCE + 1)); fi
[ "$SAYILI_SON" -lt "$TUR" ] && _bilgi "   ℹ sayılı tur $SAYILI_SON/$TUR — $YAKMAYAN tur yakmadı (bulgularının hepsi kutu-dışıydı)"
# 🔴 Muafiyet SıNIRSIZ değil: her tur kutu-dışı bulgu yazarak sonsuz döngü kurulabilirdi.
#    Yakmayan tur $KD_TAVAN'ı geçerse iş tavanda değil ama KUTUDA İLERLETİLEMİYOR demektir —
#    ayrı gerçekeçli rc=4 ve ayrı üç yol (devam demeğil: yüzeye git).
if [ "$YAKMAYAN" -gt "$KD_TAVAN" ]; then
  _bilgi ""
  _bilgi "⛔ KUTUDA İLERLETİLEMİYOR — son $YAKMAYAN tur üst üste yalnız kutu-dışı bulgu döndü (tavan $KD_TAVAN)."
  _bilgi "   Bu bir KOD tıkanması DEĞİLDİR; işin kalanı başka bir yüzeyde."
  _bilgi "   Gereken yüzeyler: $DZ/KUTU-DISI.jsonl"
  _bilgi "   Üç yol (karar iş sahibinin/reisin): 1) YÜZEYE GİT — o yüzeyde ölçen bir kart/görev aç"
  _bilgi "   2) KAPSAMI DARALT — kutuda biteni gönder, kutu-dışını yeni kart yap"
  _bilgi "   3) GERİ AL — alanı kapat, ders deftere"
  exit 4
fi
if [ "$SAYILI_SON" -ge "$TAVAN" ]; then
  ONCEKI=$TUR
  if [ "$SAYILI_SON" -lt "$MUTLAK" ] && ilerliyor_mu; then _bilgi "↩ adım 2'ye dön (sayılı tur $SAYILI_SON/$TAVAN) — iş ilerliyor, +1 tur payı var"; exit 1; fi
  tikandi_raporu; exit 4
fi
_bilgi "↩ adım 2'ye dön: düzelt → yeniden kanıtla → yeniden gönder (sayılı tur $SAYILI_SON/$TAVAN)"; exit 1
