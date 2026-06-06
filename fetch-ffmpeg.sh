#!/bin/bash
# Statik ffmpeg/ffprobe ikililerini indirir (arm64 + x86_64) ve `lipo` ile
# universal tek dosyalar üretir: vendor/ffmpeg, vendor/ffprobe.
# Bu ikililer hiçbir homebrew dylib'ine bağlı değildir; her Mac'te çalışır.
#
# Kaynaklar:
#   arm64   : https://www.osxexperts.net  (Martin Riedl statik derlemeleri)
#   x86_64  : https://evermeet.cx/ffmpeg  (statik derlemeler)
set -e
cd "$(dirname "$0")"

VENDOR="vendor"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$VENDOR"

ARM_FFMPEG="https://www.osxexperts.net/ffmpeg81arm.zip"
ARM_FFPROBE="https://www.osxexperts.net/ffprobe81arm.zip"
X86_FFMPEG="https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip"
X86_FFPROBE="https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip"

fetch() { # url dest
    echo "  indiriliyor: $1"
    curl -fsSL --max-time 180 "$1" -o "$2"
}

extract_bin() { # zip dest_binary
    local dir="$WORK/x_$(basename "$2")_$RANDOM"
    mkdir -p "$dir"
    unzip -oq "$1" -d "$dir"
    # zip içindeki çalıştırılabilir dosyayı bul (ffmpeg/ffprobe).
    local found
    found="$(find "$dir" -type f \( -name ffmpeg -o -name ffprobe \) | head -1)"
    [ -n "$found" ] || { echo "HATA: ikili bulunamadı: $1"; exit 1; }
    cp "$found" "$2"
    chmod +x "$2"
}

build_universal() { # name arm_url x86_url
    local name="$1"
    echo "▶ $name"
    fetch "$2" "$WORK/${name}_arm.zip"
    fetch "$3" "$WORK/${name}_x86.zip"
    extract_bin "$WORK/${name}_arm.zip" "$WORK/${name}_arm"
    extract_bin "$WORK/${name}_x86.zip" "$WORK/${name}_x86"

    local arm_arch x86_arch
    arm_arch="$(lipo -archs "$WORK/${name}_arm" 2>/dev/null || true)"
    x86_arch="$(lipo -archs "$WORK/${name}_x86" 2>/dev/null || true)"
    echo "  arm zip arch: $arm_arch | x86 zip arch: $x86_arch"

    # İkisini de tek universal dosyada birleştir (mümkün olan mimarileri al).
    local inputs=()
    case "$arm_arch" in *arm64*) inputs+=("$WORK/${name}_arm");; esac
    case "$x86_arch" in *x86_64*) inputs+=("$WORK/${name}_x86");; esac
    if [ "${#inputs[@]}" -eq 2 ]; then
        lipo -create "${inputs[@]}" -output "$VENDOR/$name"
    else
        # En azından arm64'ü koy.
        cp "$WORK/${name}_arm" "$VENDOR/$name"
    fi
    chmod +x "$VENDOR/$name"

    echo "  sonuç arch: $(lipo -archs "$VENDOR/$name")"
    # homebrew dylib bağımlılığı kalmadığını doğrula.
    if otool -L "$VENDOR/$name" | grep -q "/opt/homebrew\|/usr/local/lib\|/opt/local"; then
        echo "  ⚠ UYARI: $name hâlâ homebrew dylib'ine bağlı görünüyor!"
        otool -L "$VENDOR/$name" | grep "/opt/homebrew\|/usr/local/lib\|/opt/local" || true
    else
        echo "  ✓ bağımsız (yalnızca sistem kütüphaneleri)"
    fi
}

build_universal ffmpeg  "$ARM_FFMPEG"  "$X86_FFMPEG"
build_universal ffprobe "$ARM_FFPROBE" "$X86_FFPROBE"

echo
echo "✓ Bitti. vendor/ffmpeg ve vendor/ffprobe hazır."
echo "  Şimdi ./build.sh çalıştır — bunlar uygulamaya gömülür."
