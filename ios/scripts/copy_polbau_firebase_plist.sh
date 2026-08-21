#!/bin/sh
set -e

DEST="${SRCROOT}/GoogleService-Info.plist"

case "${CONFIGURATION}" in
  Debug-polbauDemo|Profile-polbauDemo)
    SOURCE="${SRCROOT}/Runner/polbauDemo/GoogleService-Info-demo.plist"
    ;;
  Release-polbauDemo)
    SOURCE="${SRCROOT}/Runner/polbauDemo/GoogleService-Info.plist"
    ;;
  *)
    exit 0
    ;;
esac

if [ ! -f "$SOURCE" ]; then
  echo "error: Firebase plist not found at $SOURCE" >&2
  exit 1
fi

cp "$SOURCE" "$DEST"
echo "Copied $(basename "$SOURCE") for ${CONFIGURATION}"
