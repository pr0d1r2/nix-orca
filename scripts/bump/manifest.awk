# One asset's entry in an electron-builder latest-*.yml (manifest.sh):
# prints "size sha512" for the `files:` item whose url is `asset`.
/^  - url: / { url = $3; sha = ""; size = "" }
/^    sha512: / && url == asset { sha = $2 }
/^    size: / && url == asset { size = $2 }
url == asset && sha != "" && size != "" { print size, sha; exit }
