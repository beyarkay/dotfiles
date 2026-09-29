#!/usr/bin/env bash
# Build "Open in Nvim.app" and make it the default for every extension in
# open-in-nvim/extensions.txt. Safe to re-run.
set -euo pipefail

BUNDLE_ID="com.brk.open-in-nvim"
DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
APP="$HOME/Applications/Open in Nvim.app"
PLIST="$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
EXTENSIONS=()
while IFS= read -r ext; do
  [[ -n "$ext" ]] && EXTENSIONS+=("$ext")
done <"$DOTFILES/open-in-nvim/extensions.txt"
UTIS=(public.json public.yaml net.daringfireball.markdown)

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "open-in-nvim: macOS only, skipping" >&2
  exit 0
fi

mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" "$DOTFILES/open-in-nvim/open-in-nvim.applescript"

$PB -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null ||
  $PB -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST"
$PB -c "Delete :CFBundleDocumentTypes" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleDocumentTypes array" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$PLIST"
for i in "${!EXTENSIONS[@]}"; do
  $PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:$i string ${EXTENSIONS[$i]}" "$PLIST"
done
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"
for i in "${!UTIS[@]}"; do
  $PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:$i string ${UTIS[$i]}" "$PLIST"
done

codesign --force --deep --sign - "$APP"
"$LSREGISTER" -f "$APP"

for ext in "${EXTENSIONS[@]}"; do
  duti -s "$BUNDLE_ID" ".$ext" all
done
for uti in "${UTIS[@]}"; do
  duti -s "$BUNDLE_ID" "$uti" all
done

wrong=()
for ext in "${EXTENSIONS[@]}"; do
  [[ "$(duti -x "$ext" 2>/dev/null | sed -n 3p)" == "$BUNDLE_ID" ]] || wrong+=("$ext")
done
if ((${#wrong[@]})); then
  echo "open-in-nvim: not the default for: ${wrong[*]}" >&2
  exit 1
fi
