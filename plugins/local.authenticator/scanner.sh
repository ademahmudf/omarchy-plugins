#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-screen}"

case "$MODE" in
  screen)
    # Give a tiny delay for popup dismiss, then slurp area selection
    TMP_IMG="/tmp/omarchy_2fa_qr_$$.png"
    if grim -g "$(slurp)" "$TMP_IMG" 2>/dev/null; then
      if [ -f "$TMP_IMG" ]; then
        zbarimg --raw "$TMP_IMG" 2>/dev/null || true
        rm -f "$TMP_IMG"
      fi
    fi
    ;;
  camera)
    # Scan from webcam with zbarcam (exit after first QR code or 15s)
    if command -v zbarcam >/dev/null 2>&1; then
      timeout 15s zbarcam --raw --nodisplay /dev/video0 2>/dev/null | head -n 1 || true
    fi
    ;;
  file)
    # File picker dialog
    if command -v zenity >/dev/null 2>&1; then
      IMG_FILE=$(zenity --file-selection --title="Select 2FA QR Code Image" --file-filter="Images | *.png *.jpg *.jpeg *.webp *.svg *.gif" 2>/dev/null || true)
      if [ -n "$IMG_FILE" ] && [ -f "$IMG_FILE" ]; then
        zbarimg --raw "$IMG_FILE" 2>/dev/null || true
      fi
    fi
    ;;
  *)
    echo "Usage: $0 [screen|camera|file]" >&2
    exit 1
    ;;
esac
