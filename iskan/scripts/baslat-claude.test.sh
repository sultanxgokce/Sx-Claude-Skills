#!/usr/bin/env bash
# baslat-claude.test.sh — "yeniden başlatma insan-eli istemesin" kapısı.
#
# NİÇİN (2026-07-31, NÂZIR bildirdi → firsthand ölçüldü): launcher her açılışta
# `claude --session-id <SID>` çağırıyordu. İkinci çağrıda claude reddediyor:
#     --session-id <var olan> → exit 1 · "Session ID … is already in use."
# Etkileşimli kipte bu, üyeyi "oturum eski, özetten devam?" menüsünde asılı bırakıyor;
# MÜDÜR menüyü açamıyor (pane'e tuş göndermek haklı olarak yasak) → her restart, her
# odada bir insan-eli. 10 kutuluk filoda 1 restart = 10 müdahale.
#
# ÖLÇÜLEN ÇÖZÜM (aynı turda gerçek claude ile kanıtlandı):
#     --resume <var olan> → exit 0, önceki konuşmayı HATIRLIYOR
#     --resume <yeni>     → exit 1 · "No conversation found with session ID: …"
#
# Bu test GERÇEK claude çağırmaz (jeton harcamaz, ağ istemez): PATH'e sahte bir `claude`
# koyar ve launcher'ın DALLANMASINI ölçer — hangi bayrakla, hangi sırayla, düşünce ne yapıyor.
set -uo pipefail
BURASI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SABLON="$BURASI/../templates/baslat-claude.sh"
G=0; D=0
ok(){ G=$((G+1)); printf '  ✓ %s\n' "$1"; }
no(){ D=$((D+1)); printf '  ✗ %s\n     %s\n' "$1" "${2:-}"; }

EV=$(mktemp -d); trap 'find "$EV" -mindepth 1 -delete 2>/dev/null; rmdir "$EV" 2>/dev/null' EXIT
mkdir -p "$EV/bin" "$EV/proje/_agents/handoff" "$EV/ev"

# Registry: launcher rol→(sid, permission-mode) çözer.
cat > "$EV/proje/iskan-registry.yaml" <<'REG'
uyeler:
  - id: nazir-yon
    session_id: "11111111-2222-3333-4444-555555555555"
    permission_mode: "bypassPermissions"
REG
# ⚠️ Şema anahtarı `id:` — `rol:` DEĞİL (parser `- id: <rol>` arıyor). İlk kurgumda `rol:`
#   yazmıştım ve dört senaryo da "rol-kayitsiz" ile kırmızı döndü; testin kendi fixture'ı
#   yanlıştı, kod değil. Şemayı fixture'da varsaymak yerine parser'dan okumak gerekiyordu.

# Sahte claude: DAVRANIŞI ortam değişkeniyle kurulur; çağrıldığı bayrakları günlüğe yazar.
cat > "$EV/bin/claude" <<'SAHTE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SAHTE_GUNLUK"
case "${SAHTE_MOD:-}" in
  resume_ok)      [ "${1:-}" = "--resume" ] && exit 0; echo "Error: Session ID x is already in use." >&2; exit 1 ;;
  taze_ok)        [ "${1:-}" = "--session-id" ] && exit 0; echo "No conversation found with session ID: x" >&2; exit 1 ;;
  hep_dusuk)      echo "boom: tanimadigimiz bir hata" >&2; exit 7 ;;
esac
exit 0
SAHTE
chmod +x "$EV/bin/claude"

kos(){ # kos <mod> → çıktı; rc korunur
  # Registry yolu şablonun KENDİ konumundan türetiliyor; test onu ISKAN_REGISTRY ile
  # sahte kayda bağlar (yoksa dört senaryo da "registry yok" diye kırmızı döner ve
  # test yanlış sebepten geçmiş/düşmüş olur — ilk koşuda tam bu yaşandı).
  SAHTE_MOD="$1" SAHTE_GUNLUK="$EV/cagri.log" HOME="$EV/ev" BASLAT_IZ_DIR="$EV/ev/.iz" \
  ISKAN_REGISTRY="$EV/proje/iskan-registry.yaml" \
  PATH="$EV/bin:$PATH" bash "$SABLON" nazir-yon 2>&1
}
cagrilar(){ cat "$EV/cagri.log" 2>/dev/null; }
sifirla(){ : > "$EV/cagri.log"; }

echo "── söz dizimi ──"
bash -n "$SABLON" && ok "şablon söz dizimi" || no "şablon söz dizimi"

echo "── 1) İLK açılış: iz yok → --session-id ile taze başlar ──"
sifirla; cikti=$(kos taze_ok); rc=$?
[ "$rc" = 0 ] && ok "ilk açılış rc=0" || no "ilk açılış rc=0" "gelen=$rc · $cikti"
case "$(cagrilar)" in --session-id*) ok "ilk çağrı --session-id (doğru)" ;;
  *) no "ilk çağrı yanlış bayrak" "çağrılar: $(cagrilar)" ;; esac
[ -f "$EV/ev/.iz/11111111-2222-3333-4444-555555555555.acildi" ] \
  && ok "başarılı açılışta iz bırakıldı" || no "iz bırakılmadı" "sonraki restart yine taze denerdi"

echo "── 2) YENİDEN açılış: iz var → --resume (menüye düşmez) ──"
sifirla; cikti=$(kos resume_ok); rc=$?
[ "$rc" = 0 ] && ok "yeniden açılış rc=0" || no "yeniden açılış rc=0" "gelen=$rc · $cikti"
case "$(cagrilar)" in --resume*) ok "--resume ile açıldı (insan-eli gerekmez)" ;;
  *) no "--resume kullanılmadı" "çağrılar: $(cagrilar)" ;; esac
case "$(cagrilar)" in *--session-id*) no "gereksiz --session-id denemesi" "menü riski geri gelir" ;;
  *) ok "boşuna --session-id denenmedi" ;; esac

echo "── 3) İZ KAYBOLMUŞ ama oturum VAR → kendi kendini onarır ──"
# İşaret dosyasını sil, claude 'already in use' desin: launcher --resume'a düşmeli.
find "$EV/ev/.iz" -type f -delete 2>/dev/null
sifirla; cikti=$(kos resume_ok); rc=$?
[ "$rc" = 0 ] && ok "iz kayıpken de rc=0 (kendini onardı)" || no "iz kayıpken düştü" "gelen=$rc · $cikti"
case "$cikti" in *"iz yoktu ama oturum VAR"*) ok "onarımı açıkça söylüyor (sessiz değil)" ;;
  *) no "onarım sessiz" "çıktı: $cikti" ;; esac
[ -f "$EV/ev/.iz/11111111-2222-3333-4444-555555555555.acildi" ] \
  && ok "iz yeniden yazıldı" || no "iz onarılmadı"

echo "── 4) TANIMADIĞIMIZ hata → körlemesine taze oturum AÇMAZ ──"
# En tehlikeli hâl: gerçek bir arıza varken 'nasılsa taze açayım' demek, geçmişi olan
# bir kimliği ezebilir. Launcher burada DURMALI.
sifirla; cikti=$(kos hep_dusuk); rc=$?
[ "$rc" != "0" ] && ok "tanınmayan hatada rc≠0 (sahte-yeşil yok)" || no "tanınmayan hatada rc=0" "sahte-yeşil"
case "$cikti" in *"beklenmedik"*) ok "ham çıktıyı gösteriyor (teşhis edilebilir)" ;;
  *) no "hata sessiz" "çıktı: $cikti" ;; esac

echo "── 5) prob için --print KULLANILMIYOR (jeton + sahte-mesaj) ──"
# İlk tasarımımda `--resume --print "hazir"` ile prob atıyordum: her açılışta gerçek bir
# model çağrısı + ekibin sohbetine sahte bir alışveriş. Bu satır o tasarımın geri gelmesini engeller.
! grep -qE '^[^#]*--print' "$SABLON" && ok "şablonda --print yok" \
  || no "şablonda --print VAR" "her açılışta jeton harcar + sohbete sahte mesaj ekler"

echo "── 6) transcript ağacına DOKUNMUYOR (yüzey-daraltması değişmezi) ──"
! grep -qE '^[^#]*\.claude/projects' "$SABLON" && ok "transcript yolu şablonda geçmiyor" \
  || no "transcript ağacına dokunuyor" "o ağaca dokunan tek yer ekip-ac.sh::_transcript_var_mi olmalı"

echo
printf 'baslat-claude: GEÇTI=%s DUSTU=%s\n' "$G" "$D"
[ "$D" -eq 0 ] || exit 1
