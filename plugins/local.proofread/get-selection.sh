#!/bin/bash
if [[ -z "$WAYLAND_DISPLAY" ]]; then
  socket=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | head -n1)
  [[ -n "$socket" ]] && export WAYLAND_DISPLAY="${socket##*/}"
fi

# Grab primary selection (highlighted text on screen)
sel=$(wl-paste -p --type text --no-newline 2>/dev/null || wl-paste -p --no-newline 2>/dev/null)

if [[ -n "${sel//[[:space:]]/}" ]]; then
  printf "%s" "$sel"
  exit 0
fi

# Only fallback to standard clipboard if explicitly requested via --all
if [[ "$1" == "--all" || "$1" == "--clipboard" ]]; then
  clip=$(wl-paste --type text --no-newline 2>/dev/null || wl-paste --no-newline 2>/dev/null)
  if [[ -n "${clip//[[:space:]]/}" ]]; then
    printf "%s" "$clip"
    exit 0
  fi
fi

exit 0
