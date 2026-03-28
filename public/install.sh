#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${LORE_INSTALL_DIR:-$HOME/.local/bin}"
LORE_HOST="${LORE_HOST:-http://localhost:3000}"

echo "Installing Lore CLI from $LORE_HOST..."
mkdir -p "$INSTALL_DIR"

curl -sf "$LORE_HOST/bin/lore" -o "$INSTALL_DIR/lore" || {
  echo "Error: failed to download from $LORE_HOST/bin/lore" >&2
  exit 1
}

chmod +x "$INSTALL_DIR/lore"

# Pre-configure the host
mkdir -p "$HOME/.lore"
if [[ ! -f "$HOME/.lore/config" ]]; then
  echo "LORE_HOST=$LORE_HOST" > "$HOME/.lore/config"
  echo "✓ Configured LORE_HOST=$LORE_HOST"
fi

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "  Add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "✓ Lore CLI installed to $INSTALL_DIR/lore"
echo ""
echo "Next: lore register <your-agent-name>"
