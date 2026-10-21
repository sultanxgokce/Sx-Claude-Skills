#!/usr/bin/env bash
# mut-olcer.sh <betik-dizini> — #1136 tur 3 vakası: bilerek bozulmuş kodla kırmızı sınav göze nasıl gidiyor?
#   1 · araç mutasyon ölçümünü etiketleyebiliyor mu (--mutasyon)  2 · mutasyon ölçümünün rengi (kırmızı sınav = yakalandı)
#   3 · göz isteminde o ölçümün başlığı "MUTASYON KANITI" diyor mu, yoksa ✗ satırı çıplak mı gidiyor
# Önce = origin/main'in betik dizini kopyası, sonra = çalışma ağacı (girdi, sahte göz aynı).
set -uo pipefail
S="$(cd "$1" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
D="$T/depo"; mkdir -p "$D"; git -C "$D" init -q -b main; cd "$D"
export KANIT_DEPO="$D" FABRIKA_AILE_NOTIFY=-
bash "$S/kart.sh" ac is-m --is x --istedi SERDAR --aldi OLCER --geri-alinamaz h --para h --dis-yuzey h --yetki h >/dev/null 2>&1
bash "$S/kanit.sh" olcum is-m kilit --asama tek -- bash -c 'echo "  ✓ K5 kilit tutuyor"; exit 0' >/dev/null 2>&1
bash "$S/kanit.sh" olcum is-m mut-k5 --asama tek --mutasyon kilit -- bash -c 'echo "  ✗ K5 kilit tutuyor"; exit 1' > "$T/m.out" 2>&1; mrc=$?
etiket=1; [ "$mrc" -eq 2 ] && grep -q "unrecognized arguments" "$T/m.out" && etiket=0
if [ "$etiket" = 0 ]; then   # eski araç bayrağı tanımıyor: vakadaki gibi yalnız etiket adıyla kaydet
  bash "$S/kanit.sh" olcum is-m MUTASYON-KANITI-beklenen-kirmizi --asama tek -- bash -c 'echo "  ✗ K5 kilit tutuyor"; exit 1' >/dev/null 2>&1
fi
renk="$(python3 -c "import json,sys;k=[x for x in json.load(open(sys.argv[1]))['kayitlar'] if x['etiket']!='kilit'][-1];print(k['renk'], 'mutasyon' if k.get('mutasyon') else 'etiketsiz')" "$D/_agents/fabrika/kanit/is-m/KANIT.json")"
printf '#!/usr/bin/env bash\ncp "$1" "%s/istem.md"; printf "%%s" "{\\"kod_puani\\":5,\\"dogru_sey\\":\\"E\\",\\"ozet\\":\\"o\\",\\"bulgular\\":[],\\"kanit_gorusu\\":\\"k\\"}"\n' "$T" > "$T/goz.sh"; chmod +x "$T/goz.sh"
printf 'diff --git a/x b/x\n+m\n' > "$T/p"
DENETCI_KOMUT="$T/goz.sh" bash "$S/denetci.sh" is-m --diff "$T/p" >/dev/null 2>&1
echo "── 1 · araç mutasyonu etiketliyor mu: $([ $etiket = 1 ] && echo "EVET (--mutasyon, rc $mrc)" || echo 'HAYIR — --mutasyon tanınmıyor, yalnız etiket adı kalıyor')"
echo "── 2 · mutasyon ölçümünün kaydı: renk $renk"
echo "── 3 · göz isteminde ölçüm başlıkları:"
grep -E '^--- olcum-' "$T/istem.md" | sed 's/^/   /'
grep -A3 -E '^--- olcum-(mut-k5|MUTASYON)' "$T/istem.md" | grep -E '✗ K5' | sed 's/^/   göze giden satır: /'
bas=0; grep -qE '^--- olcum-[^ ]+ · 🧬 MUTASYON KANITI' "$T/istem.md" && bas=1
echo "── SONUÇ: etiket $([ $etiket = 1 ] && echo ✓ || echo ✗) · renk $([[ "$renk" == "yesil mutasyon" ]] && echo '✓ (yakalandı=yeşil)' || echo "✗ ($renk)") · istem başlığı $([ $bas = 1 ] && echo ✓ || echo '✗ (✗ satırı çıplak gidiyor)')"
[ $etiket = 1 ] && [[ "$renk" == "yesil mutasyon" ]] && [ $bas = 1 ] && exit 0
exit 1
