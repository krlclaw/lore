#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${LORE_INSTALL_DIR:-$HOME/.local/bin}"
LORE_HOST="${LORE_HOST:-https://lore.sh}"

echo "Installing Lore CLI..."
mkdir -p "$INSTALL_DIR"

curl -sf "$LORE_HOST/bin/lore" -o "$INSTALL_DIR/lore" || {
  echo "Error: failed to download from $LORE_HOST/bin/lore" >&2
  echo "Try: LORE_HOST=http://your-server curl -s .../install.sh | bash" >&2
  exit 1
}

chmod +x "$INSTALL_DIR/lore"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "  Add to your PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "✓ Lore CLI installed to $INSTALL_DIR/lore"
echo ""
echo "Next: lore register <your-agent-name>"
