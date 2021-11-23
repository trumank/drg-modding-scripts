#!/bin/bash

set -a
. ./.env
set +a

UNPACKED=unpacked-mods/
PACKED=packed-mods/

unpack() {
  "$UNREAL/UnrealPak" "$(realpath "$1")" -Extract "$(realpath "$2")"
}

get-pak-mountpoint() {
  "$UNREAL/UnrealPak" -List "$(realpath "$1")" | sed -n -e 's/^.*LogPakFile: Display: Mount point ..\/..\/..\///p'
}

parse() {
  mono "$UASSETGUI" tojson $1 ${1%.*}.json 4.25
}

unpack-game() {
  unpack "$FSD_ORIG" unpacked/
}

unpack-mod() {
  local PAK="$(find "$MODIO/$1" -iname "*.pak")"
  local MOD="$(basename "$PAK")"
  local OUT="$UNPACKED/${MOD%.*}"
  unpack "$PAK" "$OUT"
}

pack-mod() {
  local OUT="$UNPACKED/${MOD%.*}"
  echo "\"$(realpath "$UNPACKED/$1/*")\" \"../../../FSD/Content/\"" > input.txt
  "$UNREAL/UnrealPak" $(realpath "$PACKED/$1.pak") -Create=$(realpath input.txt) -compress
  #"$MODIO/$1/$MOD" -Extract "$(realpath "$OUT")"
}

zip-mod() {
  pack-mod "$1"
  (cd packed-mods; zip "$1.zip" "$1.pak")
}

install-mod() {
  pack-mod "$1"
  cp "$PACKED/$1.pak" "$PAKS/"
}

# args:
#  uasset path (next to uexp pair)
# output:
#  JSON representation of uasset
get-json() {
  mono ~/Downloads/Release/UAssetGUI.exe tojson "$(realpath "$1")" >(cat) 518
}

# args:
#  uasset path (next to uexp pair)
# input:
#  JSON representation of uasset
write-uasset() {
  mono ~/Downloads/Release/UAssetGUI.exe fromjson <(cat) test.uasset < /dev/null
  #cat /dev/stdin
  #(sed -e 's/^/b /' <(sed -e 's/^/a /' <(tee /dev/stdout)))
}

# args:
#  uasset path A (next to uexp pair)
#  uasset path B (next to uexp pair)
# output:
#  diff of input assets
diff-json() {
  colordiff -U 1000 <(get-json "$1" | jq --sort-keys . ) <(get-json "$2" | jq --sort-keys .)
}

# simply checks if all the files in the mod match names in the game
# args:
#   mod name
validate-mod() {
  #diff -qr unpacked/FSD/Content "unpacked-mods/$1"
  echo "==== FILES NOT PRESENT IN GAME ===="
  comm -13 <(cd unpacked/FSD/Content; find . -type f | sort) <(cd "unpacked-mods/$1"; find . -type f | sort)
  echo "==== FILES TO BE REPLACED ===="
  comm -12 <(cd unpacked/FSD/Content; find . -type f | sort) <(cd "unpacked-mods/$1"; find . -type f | sort)
}

edit-asset() {
  WINEPREFIX="$HOME/prefix2" wine ~/Downloads/Release/UAssetGUI.exe "$1"
}

embed-mod() {
  rm -r embed-tmp
  mkdir embed-tmp
  unpack "$FSD_ORIG" embed-tmp

  for mod in "$@"; do
    unpack "$mod" "embed-tmp/$(get-pak-mountpoint "$mod")"
  done

  echo "\"$(realpath "embed-tmp/*")\" \"../../../\"" > input.txt
  "$UNREAL/UnrealPak" "$(realpath "$FSD")" -Create=$(realpath input.txt) -compress
}

"$@"
