#!/usr/bin/env bash
# kayit-koru.test.sh — kutudaki iskan-registry.yaml EZİLMEZ + kayit-fark salt-okur raporu (SERDAR 13 Eki).
# Hermetik: gerçek hostsrv'e bağlanmaz. ssh PATH'te sahte; host kökü geçici dizin (ISKAN_HOST_COMPOSE_ROOT).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$SCRIPT_DIR/iskan.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "  ✓ $1"; }
bad(){ FAIL=$((FAIL+1)); echo "  ✗ $1"; }
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT

# ── sahte ssh: docker çağrıları taklit, gerisi yerelde koşar; her çağrı LOG'a ──────────────
mkdir -p "$T/stub"
cat > "$T/stub/ssh" <<'STUB'
#!/usr/bin/env bash
cmd="${@: -1}"
printf '%s\n' "$cmd" >> "$KK_LOG"
case "$cmd" in
  true) exit 0 ;;
  *"docker inspect"*) echo true ;;
  *"docker exec"*"command -v"*) exit 0 ;;
  *"tmux list-sessions"*) printf 'denekAlfa\ndenekBeta\n' ;;
  *"docker exec"*) exit 0 ;;
  *) bash -c "${cmd//chown /: }" ;;   # chown 1000:1000 yalnız uid 1000'de geçer (CI koşucusu değil); düzenek sahipliği sınamaz
esac
STUB
chmod +x "$T/stub/ssh"
export KK_LOG="$T/ssh.log"

# ── hermetik cloudtop deposu: compose'da cloudtop-eytest (tek-mount) ────────────────────────
R="$T/repo"; mkdir -p "$R/infra"
cp "$SCRIPT_DIR/fixtures/compose-clean.yml" "$R/infra/docker-compose.server.yml"
cat >> "$R/infra/docker-compose.server.yml" <<'YML'

  cloudtop-eytest:
    image: lscr.io/linuxserver/code-server:latest
    container_name: cloudtop-eytest
    ports:
      - "127.0.0.1:9449:8443"
    volumes:
      - ./config-eytest:/config
YML
git -C "$R" init -q -b main
git -C "$R" -c user.email=t@t -c user.name=t add -A
git -C "$R" -c user.email=t@t -c user.name=t commit -qm x
git -C "$R" update-ref refs/remotes/origin/main HEAD

H="$T/host"; KP="$H/config-eytest/projects/eytest"
SID_A=11111111-1111-4111-8111-111111111111; SID_B=22222222-2222-4222-8222-222222222222
kutu_kur() { # kutu iskeleti: scaffold + baslat + banner'lar + ekip-registry var (hiçbir adım yazmasın)
  find "$H" "$T/tierc" -mindepth 1 -delete 2>/dev/null; mkdir -p "$KP/scripts" "$KP/_iskan" "$KP/_agents/handoff" "$H/infra" "$T/tierc/infra"
  : > "$KP/scripts/ekip-notify.sh"; : > "$KP/scripts/baslat-claude.sh"
  echo b > "$KP/_iskan/banner-denekAlfa.txt"; echo b > "$KP/_iskan/banner-denekBeta.txt"
  cat > "$KP/_agents/handoff/ekip-registry.yaml" <<'Y'
meta:
  ekip: "eytest-ekibi"
  uye_sayisi: 2
  yonetici: denekAlfa
uyeler:
  - id: denekAlfa
    tmux: "denekAlfa:0"
    rol: "deneme (yonetici)"
  - id: denekBeta
    tmux: "denekBeta:0"
    rol: "deneme (uye)"
Y
}
uretim() { # o koşumun üreteceği kayıt (üreticinin kendisiyle — elle kopya değil)
  EY_PROJE=eytest EY_CNAME=cloudtop-eytest EY_HOSTNAME=eytest.mmepanel.com EY_PORT=9449 EY_HOST_CFG=/opt/cloudtop/config-eytest \
  EY_HEDEF_ICI=/config/projects/eytest EY_REG_MEVCUT="${1:-}" \
  bash -c "source <(sed -n '/^_ey_registry_alan()/,/^}/p' '$SUT'); source <(sed -n '/^_ey_iskan_registry_icerik()/,/^}/p' '$SUT'); printf 'denekAlfa\tyonetici\t$SID_A\ndenekBeta\tuye\t$SID_B\n' | _ey_iskan_registry_icerik"
}
md5(){ md5sum "$1" 2>/dev/null | cut -d' ' -f1; }
ey() { # ekip-yerlestir sahte host'a karşı
  env PATH="$T/stub:$PATH" ISKAN_SSH_HOST=stubhost ISKAN_CLOUDTOP_REPO_DIR="$R" ISKAN_REPO_TIERC_DIR="$T/tierc" \
    ISKAN_HOST_COMPOSE_ROOT="$H" ISKAN_HOST_REGISTRY="$H/infra/iskan-registry.yaml" \
    ISKAN_EY_ROSTER="denekAlfa:yonetici denekBeta:uye" "$@"
}

echo "── K: ekip-yerlestir kutu kaydını ezmez ──"

# K1 POZİTİF KONTROL: kutu kopyası yeni üretimle bayt-eş → apply YAZAR (sahte host gerçekten yazılabiliyor)
kutu_kur; uretim > "$KP/iskan-registry.yaml"; : > "$KK_LOG"
out="$(ey bash "$SUT" ekip-yerlestir eytest --apply 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ -f "$H/infra/iskan-registry.yaml" ] && [ -f "$T/tierc/infra/iskan-registry/eytest.yaml" ] && printf '%s' "$out" | grep -q 'bayt-eş → ezme yok' \
  && ok "K1 pozitif kontrol: kutu = üretim → apply rc=0, host+repo kopyaları YAZILDI (düzenek yazımı görebiliyor)" \
  || { bad "K1 pozitif kontrol düştü (rc=$rc)"; printf '%s\n' "$out" | tail -8; }

# K2 kutuda elle alan (koltuk ekranının yazacağı türden) → DUR, HİÇBİR kopya yazılmaz
kutu_kur; uretim | sed "/session_id: $SID_A/a\\    gorunen_ad: Başyazıcı" > "$KP/iskan-registry.yaml"
m_kutu="$(md5 "$KP/iskan-registry.yaml")"; : > "$KK_LOG"
out="$(ey bash "$SUT" ekip-yerlestir eytest --apply 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'kayit-farki' && printf '%s' "$out" | grep -q -- '-    gorunen_ad: Başyazıcı' \
  && ok "K2 kutuda elle alan → apply rc=1 + 'kayit-farki' + silinecek satır diff'te görünür" \
  || { bad "K2 elle alan ezilmeye gitti ya da fark gösterilmedi (rc=$rc)"; printf '%s\n' "$out" | tail -8; }
[ "$m_kutu" = "$(md5 "$KP/iskan-registry.yaml")" ] && [ ! -e "$H/infra/iskan-registry.yaml" ] && [ ! -e "$T/tierc/infra/iskan-registry/eytest.yaml" ] \
  && ok "K2 sıfır-yazım: kutu kopyası bayt-değişmez, host ve repo kopyası YAZILMADI" \
  || bad "K2 durması gerekirken bir kopya yazıldı"
! grep -qE 'cat >|tar -C|git init|new-session' "$KK_LOG" \
  && ok "K2 sıfır-yazım (ssh günlüğü): hiçbir yazan uzak komut koşmadı (scaffold/git init/tmux dahil)" \
  || { bad "K2 durmadan önce uzak yazım koştu"; grep -E 'cat >|tar -C|git init|new-session' "$KK_LOG" | head -3; }

# K3 kutuda değer değişikliği (cwd) → DUR
kutu_kur; uretim | sed '0,/cwd: \/config\/projects\/eytest/s##cwd: /config/projects/eytest/alt#' > "$KP/iskan-registry.yaml"
out="$(ey bash "$SUT" ekip-yerlestir eytest --apply 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q -- '-    cwd: /config/projects/eytest/alt' \
  && ok "K3 kutudaki değer farklı (cwd) → rc=1, değişecek satır gösterildi" \
  || bad "K3 değer değişikliği geçti (rc=$rc)"

# K4 --dry-run aynı farkı GÖSTERİR ama durmaz (plan-exit 3 korunur)
kutu_kur; uretim | sed "/session_id: $SID_A/a\\    gorunen_ad: Başyazıcı" > "$KP/iskan-registry.yaml"
out="$(ey bash "$SUT" ekip-yerlestir eytest --dry-run 2>&1)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'kayit-farki' && printf '%s' "$out" | grep -q 'apply bu farkla DURUR' \
  && ok "K4 dry-run: fark gösterildi + 'apply bu farkla DURUR', rc=3" \
  || bad "K4 dry-run farkı göstermedi ya da rc bozuldu (rc=$rc)"

# K5 bilinçli geçiş: ISKAN_EY_KAYIT_FARK=kabul → yazar ve kayda geçer
out="$(ey env ISKAN_EY_KAYIT_FARK=kabul bash "$SUT" ekip-yerlestir eytest --apply 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'bilinçli geçildi' && ! grep -q gorunen_ad "$KP/iskan-registry.yaml" \
  && ok "K5 ISKAN_EY_KAYIT_FARK=kabul → bilinçli geçiş görünür, kutu yeni üretime döndü" \
  || bad "K5 bilinçli geçiş kırık (rc=$rc)"

# K6 bilinmeyen değer → rc=2, sessizce 'kabul' ya da 'dur' sayılmaz
kutu_kur; uretim | sed "/session_id: $SID_A/a\\    gorunen_ad: X" > "$KP/iskan-registry.yaml"
out="$(ey env ISKAN_EY_KAYIT_FARK=evet bash "$SUT" ekip-yerlestir eytest --apply 2>&1)"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q "ISKAN_EY_KAYIT_FARK='evet' tanınmıyor" \
  && ok "K6 ISKAN_EY_KAYIT_FARK=evet → rc=2 yapılandırma hatası" \
  || bad "K6 bilinmeyen değer yutuldu (rc=$rc)"

# K7 kutuda kopya yok → yeni yazılır (ilk doğum yolu bozulmadı)
kutu_kur
out="$(ey bash "$SUT" ekip-yerlestir eytest --apply 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ -f "$KP/iskan-registry.yaml" ] && printf '%s' "$out" | grep -q 'yok → yeni yazılacak' \
  && ok "K7 kutuda kayıt yok → apply rc=0, kutu kopyası yazıldı (ilk doğum yolu)" \
  || bad "K7 ilk doğum yolu bozuldu (rc=$rc)"

echo "── U: uye-ekle de ezmez; yalnız-ekleme geçer ──"
ue() { env PATH="$T/stub:$PATH" ISKAN_SSH_HOST=stubhost ISKAN_CLOUDTOP_REPO_DIR="$R" ISKAN_REPO_TIERC_DIR="$T/tierc" \
  ISKAN_HOST_COMPOSE_ROOT="$H" ISKAN_HOST_REGISTRY="$H/infra/iskan-registry.yaml" bash "$SUT" uye-ekle eytest denekGama "$@"; }

# U1 kutu = üretim; yeni üye yalnız EKLEME → geçer, AGENT.md yazılır
kutu_kur; uretim > "$KP/iskan-registry.yaml"
out="$(ue --apply 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'yalnız EKLEME' && grep -q 'id: denekGama' "$KP/iskan-registry.yaml" && grep -q "session_id: $SID_A" "$KP/iskan-registry.yaml" \
  && ok "U1 uye-ekle yalnız-ekleme → rc=0, Gama eklendi, eski üyenin kimliği korundu" \
  || { bad "U1 uye-ekle yalnız-ekleme yolu kırık (rc=$rc)"; printf '%s\n' "$out" | tail -6; }

# U2 kutuda elle alan → uye-ekle DURUR, AGENT.md / ekip-registry YAZILMAZ
kutu_kur; uretim | sed "/session_id: $SID_B/a\\    gorunen_ad: Kâtip" > "$KP/iskan-registry.yaml"
m_ekip="$(md5 "$KP/_agents/handoff/ekip-registry.yaml")"
out="$(ue --apply 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'kayit-farki' && [ ! -e "$KP/_agents/denekGama/AGENT.md" ] && [ "$m_ekip" = "$(md5 "$KP/_agents/handoff/ekip-registry.yaml")" ] \
  && ok "U2 uye-ekle kutuda elle alan → rc=1, AGENT.md yazılmadı, ekip-registry bayt-değişmez" \
  || bad "U2 uye-ekle durması gerekirken yazdı (rc=$rc)"

echo "── F: kayit-fark salt-okur raporu ──"
mkdir -p "$R/infra/iskan-registry"
uretim > "$R/infra/iskan-registry/eytest.yaml"
printf 'proje: kanontek\n' > "$R/infra/iskan-registry/kanontek.yaml"
git -C "$R" -c user.email=t@t -c user.name=t add -A; git -C "$R" -c user.email=t@t -c user.name=t commit -qm kanon; git -C "$R" update-ref refs/remotes/origin/main HEAD
git -C "$R" remote add origin "$R"   # fetch koşsaydı başarır ve .git'e yazardı — F3 bunu yakalamalı
git_iz() { { git -C "$R" for-each-ref; stat -c '%n %s %Y' "$R"/.git/* 2>/dev/null; cat "$R/.git/FETCH_HEAD" 2>/dev/null; } | md5sum; }
kf() { env PATH="$T/stub:$PATH" ISKAN_SSH_HOST=stubhost ISKAN_CLOUDTOP_REPO_DIR="$R" bash "$SUT" kayit-fark "$@"; }

# rapor /opt/cloudtop altını okur → sahte ssh'e yol çevirisi ekle
cat > "$T/stub/ssh" <<STUB
#!/usr/bin/env bash
cmd="\${@: -1}"
printf '%s\n' "\$cmd" >> "\$KK_LOG"
[ "\$cmd" = true ] && exit 0
cmd="\${cmd//\/opt\/cloudtop/$H}"
bash -c "\$cmd" | sed "s#$H#/opt/cloudtop#g"
exit "\${PIPESTATUS[0]}"
STUB
chmod +x "$T/stub/ssh"

kutu_kur; uretim > "$KP/iskan-registry.yaml"
mkdir -p "$H/config-kututek/projects/kututek"; printf 'proje: kututek\n' > "$H/config-kututek/projects/kututek/iskan-registry.yaml"
m0="$(find "$H" "$R/infra" -type f -exec md5sum {} + | sort | md5sum)"
out="$(kf 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q '✓ eytest: ayni' && printf '%s' "$out" | grep -q '✗ kanontek: kutu-yok' && printf '%s' "$out" | grep -q '✗ kututek: kanon-yok' \
  && ok "F1 keşif iki yönlü: aynı · kutu-yok (yalnız kanonda) · kanon-yok (yalnız kutuda) ayrı ayrı; rc=1" \
  || { bad "F1 rapor sınıflaması bozuk (rc=$rc)"; printf '%s\n' "$out"; }

uretim | sed "/session_id: $SID_A/a\\    gorunen_ad: Başyazıcı" > "$KP/iskan-registry.yaml"
out="$(kf eytest 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q '✗ eytest: farkli (0 satır yalnız kanonda · 1 satır yalnız kutuda)' && printf '%s' "$out" | grep -q '+    gorunen_ad: Başyazıcı' \
  && ok "F2 fark: yön doğru ('+' = yalnız kutuda), sayım doğru, diff basıldı" \
  || { bad "F2 fark raporu bozuk (rc=$rc)"; printf '%s\n' "$out"; }
m1="$(find "$H" "$R/infra" -type f -exec md5sum {} + | sort | md5sum)"
[ "$m0" != "$m1" ] || bad "F (düzenek) kutu değişikliği md5'e yansımadı"
sleep 1   # stat %Y saniye çözünürlüklü: aynı saniyedeki yazım görünmez olmasın
m2="$(find "$H" "$R/infra" -type f -exec md5sum {} + | sort | md5sum)"; g2="$(git_iz)"; : > "$KK_LOG"; kf >/dev/null 2>&1
[ "$m2" = "$(find "$H" "$R/infra" -type f -exec md5sum {} + | sort | md5sum)" ] && [ "$g2" = "$(git_iz)" ] && [ -s "$KK_LOG" ] && ! sed 's#2>/dev/null##g' "$KK_LOG" | grep -qE '>|tee |cp |mv |rm |mkdir|chown' \
  && ok "F3 salt-okur: kutu+kanon ağaçları ve .git (ref + FETCH_HEAD) bayt-eş, yazan uzak komut yok" \
  || bad "F3 rapor bir şey yazdı"

mkdir -p "$T/stub-yok"; printf '#!/usr/bin/env bash\nexit 255\n' > "$T/stub-yok/ssh"; chmod +x "$T/stub-yok/ssh"
out="$(env PATH="$T/stub-yok:$PATH" ISKAN_SSH_HOST=stubhost ISKAN_CLOUDTOP_REPO_DIR="$R" bash "$SUT" kayit-fark eytest 2>&1)"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'olculemedi' && ! printf '%s' "$out" | grep -q '✓ eytest' \
  && ok "F4 ssh yok → rc=2 'olculemedi' (ölçülemeyen 'ayni' sayılmaz)" \
  || { bad "F4 ssh yokken sahte-yeşil (rc=$rc)"; printf '%s\n' "$out"; }

out="$(kf eytest 2>&1)"
printf '%s' "$out" | grep -q "kanon: .* origin/main $(git -C "$R" rev-parse --short=12 origin/main) " \
  && ok "F6 kanon tazeliği görünür: hangi commit'ten okunduğu çıktıda" \
  || bad "F6 kanonun commit'i çıktıda yok"

out="$(kf 'kötü;ad' 2>&1)"; rc=$?
[ "$rc" = 2 ] && ok "F5 ad hijyeni: kabuk karakterli proje adı rc=2" || bad "F5 kötü ad kabul edildi (rc=$rc)"

echo "== ${PASS} geçti / ${FAIL} kaldı =="
[ "$FAIL" -eq 0 ]
