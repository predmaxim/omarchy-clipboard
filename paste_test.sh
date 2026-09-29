#!/bin/bash
# Stubs record what paste.sh copies and which key it sends. Run: bash paste_test.sh
cd "$(dirname "$0")"
stubs=$(mktemp -d); trap 'rm -rf "$stubs"' EXIT
export LOG=$stubs/log HOME=$stubs
mkdir -p "$HOME/.local/state/omarchy"
printf '[{"type":"text","text":"file:///tmp/a%%20b.txt\\nfile:///tmp/c.png"}]' > "$HOME/.local/state/omarchy/clipboard-history.json"
printf 'PNG' > "$stubs/img.png"
cat > "$stubs/hyprctl" <<'S'
#!/bin/bash
echo "{\"tags\":[$TAGS]}"
S
cat > "$stubs/wl-copy" <<'S'
#!/bin/bash
echo "copy $* [$(cat)]" >> "$LOG"
S
cat > "$stubs/wtype" <<'S'
#!/bin/bash
echo "key $*" >> "$LOG"
S
printf '#!/bin/bash\n' > "$stubs/sleep"
chmod +x "$stubs"/*
export PATH=$stubs:$PATH
fail=0
check() { # name expected
  if [[ $(cat "$LOG") == "$2" ]]; then echo "ok   $1"; else echo "FAIL $1"; echo "  want: $2"; echo "  got:  $(cat "$LOG")"; fail=1; fi
  : > "$LOG"
}
: > "$LOG"
TAGS='"terminal*"' ./paste.sh image image/png "$stubs/img.png"
check "image into terminal = path" "copy  [$stubs/img.png]
key -M shift -k Insert -m shift"
TAGS='"default-opacity*"' ./paste.sh image image/png "$stubs/img.png"
check "image into app = image" "copy --type image/png [PNG]
key -M shift -k Insert -m shift"
TAGS='"terminal*"' ./paste.sh files 0 "/tmp/a b.txt" /tmp/c.png
check "files into terminal = quoted paths" 'copy  [/tmp/a\ b.txt /tmp/c.png]
key -M shift -k Insert -m shift'
TAGS='' ./paste.sh files 0 "/tmp/a b.txt" /tmp/c.png
check "files into app = uri-list" "copy --type text/uri-list [file:///tmp/a%20b.txt
file:///tmp/c.png]
key -M ctrl -k v -m ctrl"
exit $fail
