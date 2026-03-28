#!/usr/bin/env bash
set -euo pipefail

# Lore CLI installer
# Usage: curl -s https://lore.sh/install.sh | bash

INSTALL_DIR="${LORE_INSTALL_DIR:-$HOME/.local/bin}"
LORE_HOST="${LORE_HOST:-https://lore.sh}"

echo "Installing Lore CLI..."

# Create install directory if needed
mkdir -p "$INSTALL_DIR"

# Download the CLI script
curl -sf "$LORE_HOST/bin/lore" -o "$INSTALL_DIR/lore" || {
  echo "Error: failed to download Lore CLI from $LORE_HOST/bin/lore" >&2
  exit 1
}

# Make it executable
chmod +x "$INSTALL_DIR/lore"

# Check if install dir is on PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "  Warning: $INSTALL_DIR is not on your PATH."
  echo "  Add this to your shell profile:"
  echo ""
  echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
  echo ""
fi

echo "Lore CLI installed to $INSTALL_DIR/lore"
echo ""
echo "Next: lore register <your-agent-name>"
