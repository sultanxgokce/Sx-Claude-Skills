#!/usr/bin/env bash
# ortam-yukle.sh — ortam dosyasını KAYNAK ALMADAN yükleyen paylaşılan okuyucu (terminal-onar 2.22.0 · görev GQ9DY).
# Yan etkisiz, tek başına kaynak alınabilir: `. …/ortam-yukle.sh; ortam_yukle <dosya>`. ortak.sh de buradan alır;
# kapıyı başlatan tmux kabuğu (onar.sh) ve başka depolar (cloudtop mobile-start.sh) AYNI dosyayı kullanır — kopya yok.
# 22 Eki ölçümü: 303 satırlık gerçek dosyada 135 AD=değer dışı satır + 6 PEM işareti vardı; `set -a; . dosya` onları
# komut diye koşturup sır parçalarını iki bölmeye düşürdü. Bu okuyucu yalnız AD=değer satırını alır, gerisini sayar.
# 🔴 Ortam dosyası SOURCE EDİLMEZ (2.2.2 · 13 Eki ölçümü): üç kutuda dosyada AD=değer olmayan satırlar vardı; `. dosya`
#    bash'e o satırları KOMUT diye koşturdu, "command not found" ile değer parçaları stderr'e düştü (sır sızıntısı) ve
#    kabuk bir komut çalıştırmış da olabilirdi. Yalnız `AD=değer` biçimli satırlar okunur, çevreleyen tırnak soyulur,
#    gerisi SAYILIR ama ne koşturulur ne basılır (fail-closed: bozuk satır sayısı ölçülebilir, içerik görünmez).
ORTAM_BOZUK_SATIR=0
ortam_yukle() {  # $1 = dosya → yalnız AD=değer satırlarını ortama alır; bozuk satırları sayar (içerik basmaz)
  local d="$1" satir ad deger
  [ -f "$d" ] || return 1
  ORTAM_BOZUK_SATIR=0
  while IFS= read -r satir || [ -n "$satir" ]; do
    satir="${satir%$'\r'}"
    case "$satir" in ''|'#'*) continue ;; esac
    satir="${satir#export }"
    case "$satir" in
      [A-Za-z_]*=*) ad="${satir%%=*}"; deger="${satir#*=}"
        case "$ad" in *[!A-Za-z0-9_]*) ORTAM_BOZUK_SATIR=$((ORTAM_BOZUK_SATIR+1)); continue ;; esac
        case "$deger" in \"*\") deger="${deger#\"}"; deger="${deger%\"}" ;; \'*\') deger="${deger#\'}"; deger="${deger%\'}" ;; esac
        export "$ad=$deger" ;;
      *) ORTAM_BOZUK_SATIR=$((ORTAM_BOZUK_SATIR+1)) ;;
    esac
  done < "$d"
  return 0
}
