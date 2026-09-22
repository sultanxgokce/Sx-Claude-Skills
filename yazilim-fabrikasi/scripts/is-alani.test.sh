#!/usr/bin/env bash
# is-alani.test.sh — iş-alanı korumasını SAHTE depoda gerçekten koşturur (cloudtop sınavı temel + kapsam kontrolü).
# İki yönü de ölçer: engellemesi gerekeni engelliyor mu, meşru işi (main'e commit, izole alan) engellemiyor mu.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS="$HERE/is-alani.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

commit_gorunuyor() {
  local dizin="$1" mesaj="$2" i
  for i in 1 2 3 4 5; do
    ( cd "$dizin" && git log --oneline 2>/dev/null | grep -q -- "$mesaj" ) && return 0
    sleep 0.05
  done
  return 1
}

kur() {
  local T; T="$(mktemp -d)"
  mkdir -p "$T/uzak" "$T/depo"
  ( cd "$T/uzak" && git init -q --bare ) >/dev/null 2>&1
  ( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T &&
    echo ilk > dosya.txt && git add -A && git commit -qm "chore: ilk" &&
    git remote add origin "$T/uzak" && git push -q -u origin main ) >/dev/null 2>&1
  echo "$T"
}

T="$(kur)"
export IS_ALANI_DEPO="$T/depo" IS_ALANI_KOK="$T/alan"

echo "════ T0 · kanca-kur: şablondan kopyalar, hooksPath ayarlar, idempotent ════"
( cd "$T/depo" && bash "$IS" kanca-kur ) >/dev/null 2>&1; g $? "kanca kuruldu"
[ -x "$T/depo/.githooks/pre-commit" ]; g $? "pre-commit dosyası var ve çalıştırılabilir"
[ "$(git -C "$T/depo" config core.hooksPath)" = ".githooks" ]; g $? "core.hooksPath=.githooks"
# Not: `komut | grep -q` KULLANMA — grep ilk eşleşmede kapanır, üretici SIGPIPE alır, pipefail rc'yi kirletir (sahte kırmızı).
CIKTI="$( cd "$T/depo" && bash "$IS" kanca-kur 2>&1 )"; grep -q "zaten" <<<"$CIKTI"; g $? "ikinci kurulum: dokunmadı (idempotent)"

echo "════ T1 · paylaşılan ağaç · main → SERBEST ════"
( cd "$T/depo" && echo a >> dosya.txt && git add -A && git commit -qm "chore: ana dal" ) >/dev/null 2>&1
g $? "main'e commit atılabildi"
commit_gorunuyor "$T/depo" "chore: ana dal"; g $? "commit gerçekten düştü"

echo "════ T2 · paylaşılan ağaç · özellik dalı → BLOKE ════"
( cd "$T/depo" && git checkout -q -b ozellik && echo b >> dosya.txt && git add -A )
CIKTI="$( cd "$T/depo" && git commit -m "chore: ozellik" 2>&1 )"; RC=$?
[ "$RC" -ne 0 ]; g $? "commit ENGELLENDİ (rc=$RC)"
grep -q "is-alani.sh ac" <<<"$CIKTI"; g $? "ne yapılacağı komutla yazılı"
( cd "$T/depo" && ! git log --oneline | grep -q "chore: ozellik" ); g $? "commit gerçekten düşmedi"

echo "════ T3 · acil kaçış ════"
( cd "$T/depo" && PAYLASILAN_COMMIT=1 git commit -qm "chore: acil" ) >/dev/null 2>&1
g $? "PAYLASILAN_COMMIT=1 ile geçilebiliyor"
( cd "$T/depo" && git checkout -q main ) >/dev/null 2>&1

echo "════ T4 · ac: kendi alanı, origin/main'den, <depo>-<iş> adıyla ════"
CIKTI="$( cd "$T/depo" && bash "$IS" ac yeni-is 2>&1 )"; g $? "alan açıldı"
grep -q "TAZE" <<<"$CIKTI"; g $? "origin/main üstünde açtığını söylüyor"
grep -q "PAYLAŞILAN KAYNAĞI izole etmez" <<<"$CIKTI"; g $? "paylaşılan-kaynak uyarısı basıldı"
grep -q "dosya listesi verilmedi" <<<"$CIKTI"; g $? "kapsam bakılmadığını SÖYLÜYOR (sessiz atlama yok)"
[ -d "$T/alan/depo-yeni-is" ]; g $? "worktree dizini <depo>-<iş> adıyla var"
( cd "$T/alan/depo-yeni-is" && echo c >> dosya.txt && git add -A && git commit -qm "chore: izole" ) >/dev/null 2>&1
g $? "İZOLE alanda özellik dalına commit SERBEST"
commit_gorunuyor "$T/alan/depo-yeni-is" "chore: izole"; g $? "commit düştü"
( cd "$T/depo" && bash "$IS" ac yeni-is >/dev/null 2>&1 ); [ $? -ne 0 ]; g $? "aynı adla ikinci açılış REDDEDİLDİ"

echo "════ T5 · kontrol üç durum ════"
CIKTI="$( cd "$T/alan/depo-yeni-is" && bash "$IS" kontrol 2>&1 )"; grep -q "güvenli" <<<"$CIKTI"; g $? "izole alanda: güvenli (IS_ALANI_DEPO dışarıdan verilmişken bile)"
CIKTI="$( cd "$T/depo" && bash "$IS" kontrol 2>&1 )"; grep -q "güvenli" <<<"$CIKTI"; g $? "paylaşılan+main: güvenli"
( cd "$T/depo" && git checkout -q -b riskli-dal )
CIKTI="$( cd "$T/depo" && bash "$IS" kontrol 2>&1 )"; RC=$?
[ "$RC" -eq 1 ]; g $? "paylaşılan+özellik dalı: rc=1"
grep -q "RİSKLİ" <<<"$CIKTI"; g $? "riskli olduğunu söylüyor"
( cd "$T/depo" && git checkout -q main )

echo "════ T6 · kapat: kirli alanı silmez ════"
echo kirli > "$T/alan/depo-yeni-is/kirli.txt"
( cd "$T/depo" && bash "$IS" kapat yeni-is >/dev/null 2>&1 ); [ $? -ne 0 ]; g $? "kayıtsız değişiklik varken KAPATMADI"
[ -d "$T/alan/depo-yeni-is" ]; g $? "alan yerinde (iş kaybı yok)"
rm -f "$T/alan/depo-yeni-is/kirli.txt"
( cd "$T/depo" && bash "$IS" kapat yeni-is ) >/dev/null 2>&1
[ ! -d "$T/alan/depo-yeni-is" ]; g $? "temizken kapatıldı"

echo "════ T7 · kapsam kontrolü (sahte gh): çakışma → rc=2, açmaz; temiz → açar ════"
SAHTE="$T/sahte-bin"; mkdir -p "$SAHTE"
cat > "$SAHTE/gh" <<'GH'
#!/usr/bin/env bash
# sahte gh: tek açık PR (#7) dosya.txt ve b.txt'ye dokunuyor
case "$1 $2" in
  "pr list") echo 7 ;;
  "pr diff") printf 'dosya.txt\nb.txt\n' ;;
  *) exit 1 ;;
esac
GH
chmod +x "$SAHTE/gh"
CIKTI="$( cd "$T/depo" && PATH="$SAHTE:$PATH" bash "$IS" ac cakisan-is --dosyalar dosya.txt,z.txt 2>&1 )"; RC=$?
[ "$RC" -eq 2 ]; g $? "çakışmada rc=2"
grep -q "PR #7" <<<"$CIKTI"; g $? "hangi PR'la çakıştığı yazılı"
[ ! -d "$T/alan/depo-cakisan-is" ]; g $? "alan AÇILMADI"
CIKTI="$( cd "$T/depo" && PATH="$SAHTE:$PATH" bash "$IS" ac temiz-is --dosyalar z.txt 2>&1 )"; RC=$?
[ "$RC" -eq 0 ]; g $? "çakışma yokken rc=0"
grep -q "çakışması yok" <<<"$CIKTI"; g $? "kaç PR'a bakıldığı yazılı"
( cd "$T/depo" && bash "$IS" kapat temiz-is ) >/dev/null 2>&1

echo "════ T8 · gh DÜŞÜNCE (yetkisiz/ağsız): ölçülemedi der, yine açar (sessiz atlama yok) ════"
BOZUK="$T/bozuk-bin"; mkdir -p "$BOZUK"; printf '#!/usr/bin/env bash\nexit 1\n' > "$BOZUK/gh"; chmod +x "$BOZUK/gh"
CIKTI="$( cd "$T/depo" && PATH="$BOZUK:$PATH" bash "$IS" ac ghsiz --dosyalar z.txt 2>&1 )"; RC=$?
grep -q "YAPILAMADI" <<<"$CIKTI"; g $? "kapsam kontrolü yapılamadığını söyledi"
[ -d "$T/alan/depo-ghsiz" ]; g $? "alan yine açıldı"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
