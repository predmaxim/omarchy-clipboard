#!/bin/bash
# Paste a clipboard history entry into the focused window.
#   paste.sh image <mime> <path>
#   paste.sh files <history-index> <path>...
# Terminals only take text, so they get paths (Claude Code turns a pasted
# image path into an attachment); other windows get the image itself or the
# files as text/uri-list. Text entries go through omarchy-clipboard-paste-text.

sleep 0.15 # let the panel hand focus back

terminal=false
hyprctl activewindow -j | jq -e '.tags // [] | any(sub("\\*$"; "") == "terminal")' >/dev/null && terminal=true

kind=$1; shift
case $kind in
image)
  [[ -r $2 ]] || exit 1
  if $terminal; then printf '%q' "$2" | wl-copy
  else wl-copy --type "$1" < "$2"; fi
  ;;
files)
  index=$1; shift
  if $terminal; then
    printf -v quoted '%q ' "$@"
    printf '%s' "${quoted% }" | wl-copy
  else
    jq -j --argjson i "$index" '.[$i].text | split("\n") | map(select(startswith("file://"))) | join("\n")' \
      "$HOME/.local/state/omarchy/clipboard-history.json" | wl-copy --type text/uri-list
    exec wtype -M ctrl -k v -m ctrl
  fi
  ;;
*) exit 1 ;;
esac

# Foot and the other Omarchy terminals paste the clipboard on Shift+Insert;
# GTK and Chromium do too.
wtype -M shift -k Insert -m shift
