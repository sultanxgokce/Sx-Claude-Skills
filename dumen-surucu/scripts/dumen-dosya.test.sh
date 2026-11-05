#!/usr/bin/env bash
# dumen-dosya.test.sh — 0.9.0 dosya/engel/süre sınavı + MUTANTLAR (kapı gevşerse sınav kırmızıya dönmeli). Chromium yoksa ÖLÇÜLEMEDİ (rc 3), yeşil değil.
# kabuk-testleri: sure=900
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CH="${DUMEN_CHROME:-$(ls -d /config/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell 2>/dev/null | tail -1)}"
[ -x "$CH" ] || { echo "ÖLÇÜLEMEDİ: headless Chromium yok (DUMEN_CHROME=<yol>)"; exit 3; }
export DUMEN_CHROME="$CH"
# MUTANT_HAM=<n>: yalnız n. mutantı kur ve sınavın HAM çıktısını ve çıkış kodunu ver (kanıt kaydı için: kırmızı = yakalandı). Kurulamazsa rc 9.
if [ -z "${MUTANT_HAM:-}" ]; then
  node "$HERE/dumen-dosya.test.mjs"; RC=$?
  [ "$RC" -eq 0 ] || exit "$RC"
  [ "${DUMEN_MUTANT:-1}" = 0 ] && exit 0
fi
echo "── mutantlar (her biri sınavı KIRMALI)"
T="$(mktemp -d)"; trap 'python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T"' EXIT; cp "$HERE/dumen.mjs" "$HERE/dumen-dosya.test.mjs" "$HERE/sinav-cocuk.mjs" "$T/"
MK=0; MS=0
mut() { # mut <ad> <çapa> <yerine> : kopyayı bozar, sınavı koşar, KIRMIZI beklenir. Yalnız TEK=<n> verilirse o mutant koşar.
  MS=$((MS+1)); [ -n "${TEK:-}" ] && [ "$TEK" != "$MS" ] && return 0
  [ -n "${MUTANT_HAM:-}" ] && [ "$MUTANT_HAM" != "$MS" ] && return 0
  cp "$HERE/dumen.mjs" "$T/dumen.mjs"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$T/dumen.mjs" "$2" "$3" || { echo "  ✗ $MS $1: MUTASYON ÜRETİLEMEDİ (çapa kaydı)"; MK=$((MK+1)); [ -n "${MUTANT_HAM:-}" ] && exit 9; return; }
  node --check "$T/dumen.mjs" 2>/dev/null || { echo "  ✗ $MS $1: mutant SÖZDİZİMİ bozuk (yakalandı sayılmaz)"; MK=$((MK+1)); return; }
  if [ -n "${MUTANT_HAM:-}" ]; then echo "MUTANT $MS: $1"; DUMEN_ILK_KIRMIZI=1 DUMEN_LIB="$T/dumen.mjs" timeout 150 node "$T/dumen-dosya.test.mjs"; R=$?; find "$T" -mindepth 1 -delete; rmdir "$T"; exit "$R"; fi
  if DUMEN_ILK_KIRMIZI=1 DUMEN_LIB="$T/dumen.mjs" timeout 150 node "$T/dumen-dosya.test.mjs" >"$T/o.txt" 2>&1; then echo "  ✗ $MS $1: sınav YEŞİL kaldı (mutant yakalanmadı)"; MK=$((MK+1))
  elif grep -q 'SINAV ÇÖKTÜ' "$T/o.txt"; then echo "  ✗ $MS $1: sınav ÇÖKTÜ (yakalandı sayılmaz) — $(grep -m1 'ÇÖKTÜ' "$T/o.txt" | cut -c1-160)"; MK=$((MK+1))
  elif ! grep -q '  ✗' "$T/o.txt"; then echo "  ✗ $MS $1: sınav kırmızı ama DÜŞEN KAPI yok (yakalandı sayılmaz) — $(tail -2 "$T/o.txt" | tr '\n' ' ' | cut -c1-160)"; MK=$((MK+1))
  else echo "  ✓ $MS $1: yakalandı — $(grep -m1 '  ✗' "$T/o.txt" | cut -c1-110)"; fi
}
mut "yükleme onayı aranmaz" "Dumen.onayDogrula(onay, Dumen.dosyaIzi(k.yol));" "void 0;"
mut "onay tarihi ölçülmez" "if (m[1] !== bugun) throw" "if (false) throw"
mut "onay dosya izi ölçülmez (başka dosyanın onayı geçer)" "if (!String(onay).includes(iz)) throw" "if (false) throw"
mut "yüklenen dosya izinli dizinde aranmaz" "if (!this.#icinde(g)) throw new KapiHata('dosya-izinsiz', 'dosya izinli dizinin dışında');" ""
mut "bağ çözülmeden kabul edilir" "let g; try { g = realpathSync(resolve(String(yol))); }" "let g; try { g = resolve(String(yol)); statSync(g); }"
mut "sır taşıyabilecek yol yüklenir" "if (DOSYA_YASAK.test(g)) throw new KapiHata('dosya-yasak', 'sır taşıyabilecek yol yüklenmez');" ""
mut "izinli dizin verilmese de dosya işi yürür" "if (!l.length) throw new KapiHata('dosya-kok-yok'" "if (false) throw new KapiHata('dosya-kok-yok'"
mut "indirme hedefi izinli dizinde aranmaz" "if (!this.#icinde(g)) throw new KapiHata('dosya-izinsiz', 'hedef izinli dizinin dışında');" ""
mut "var olan dosya sormadan ezilir" "if (!ustuneYaz) throw new KapiHata('dosya-var'" "if (false) throw new KapiHata('dosya-var'"
mut "dosya yerine gelen giriş sayfası dosya sayılır" "throw new KapiHata('indirme-sayfa'" "void new KapiHata('indirme-sayfa'"
mut "indirilen içeriğin türü ölçülmez" "if (imza && !imza.every(" "if (false && !imza.every("
mut "başka kökenden indirmede yedek yol yok" "catch (e) { if (!/^https?:/i.test(adres)) throw e; return this.#baytAgdan(adres); }" "catch (e) { throw e; }"
mut "indirmenin açtığı sekme açık kalır" "page.off('popup', topla); for (const s of acilan) await s.close().catch(() => {}); }" "page.off('popup', topla); }"
mut "çerez kutusu aranmaz (sayfadaki her Reddet tıklanır)" "if (!B) return e;" "return e;"
mut "çerez kabulü onaysız geçer" "if (cerez === 'kabul' && !/" "if (false && !/"
mut "ödeme sayfasında engel kapatılır" "if (ODEME_YOL.test(page.url())) throw new KapiHata('durak', 'ödeme sayfasında engel kapatılmaz');" ""
mut "sert süre sınırı yok" "return Promise.race([is, sinir]).finally(() => clearTimeout(z));" "sinir.catch(() => {}); return is.finally(() => clearTimeout(z));"
mut "eylemler süresiz bekler" "page.setDefaultTimeout(this.#eylemSureMs);" "page.setDefaultTimeout(0);"
mut "kapat() tıklamanın açtığı sekmeyi bırakır" "for (const s of [...this.#acilanlar]) await s.close().catch(() => {});" ""
mut "kos() iş bitince kapatmaz" "process.off('SIGINT', sinyal); await d.kapat(); }" "process.off('SIGINT', sinyal); }"
mut "dosya yolu terminale yazılır" "dosya alana eklendi (\${k.uzanti}," "dosya alana eklendi (\${k.yol},"
mut "durma noktası ölçümünün süresi uygulanmaz (olmayan öğede kapı asılır)" "}), undefined, { timeout: 1500 }).catch(() => null);" "}), { timeout: 1500 }).catch(() => null);"
mut "süre dolunca eylem kesilmez (yarım tıklama sonradan gerçekleşir)" "if (kes) this.#kes();" ""
mut "kapı ve eylem ayrı ayrı tam süre alır (tavan iki katına çıkar)" "Math.max(1, son - Date.now())" "ms"
mut "kapatılan Dümen yeniden bağlanıp eylem yapar" "if (this.#kapandi) throw new KapiHata('kapali'" "if (false) throw new KapiHata('kapali'"
mut "bağlantı düşmüşken kendi sekmesi açık kalır" "if (this.#kendiSekmem && this.#hedefId) await fetch(" "if (false) await fetch("
mut "sayfaya gömülü dosya aranmaz (blob: fatura penceresi indirme-yok döner)" "if (y) { coz({ gom: y }); return; }" "if (false) { coz({ gom: y }); return; }"
mut "tıklamadan önce açık duran pencere yeni sayılır (eski dosya alınır)" ".find((x) => !once.has(x.u))" ".find(() => true)"
mut "indirAdres blob: adresini almaz" "const blob = /^blob:/i.test(a);" "const blob = false;"
mut "indirGomulu öğedeki adresin türüne bakmaz" "if (!/^(blob:|https?:\/\/)/i.test(u)) throw new KapiHata('indirme-yok', 'seçilen" "if (false) throw new KapiHata('indirme-yok', 'seçilen"
find "$T" -mindepth 1 -delete; rmdir "$T"
[ "$MK" -eq 0 ] && echo "MUTANT: $MS/$MS yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
