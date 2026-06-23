#!/usr/bin/env bash
# MAPL Player — install to user-local paths (no sudo required)
# Works on KDE Plasma 6 / Fedora

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/native/build/mapl-player"
ICON="$SCRIPT_DIR/public/mapl-player-icon.png"
DESKTOP="$SCRIPT_DIR/mapl-player.desktop"

# --- Verify build exists ---
if [ ! -f "$BINARY" ]; then
    echo "❌ Binary not found: $BINARY"
    echo "   Run 'make -j\$(nproc)' inside native/build/ first."
    exit 1
fi

# --- Install binary ---
install -Dm755 "$BINARY" "$HOME/.local/bin/mapl-player"
echo "✅ Binary installed → ~/.local/bin/mapl-player"

# --- Install icon ---
install -Dm644 "$ICON" "$HOME/.local/share/icons/hicolor/256x256/apps/mapl-player.png"
echo "✅ Icon installed → ~/.local/share/icons/hicolor/256x256/apps/"

# --- Install .desktop entry ---
install -Dm644 "$DESKTOP" "$HOME/.local/share/applications/mapl-player.desktop"
echo "✅ Desktop entry installed → ~/.local/share/applications/"

# --- Rebuild KDE / XDG caches ---
# Rebuild the XDG MIME database so Dolphin & xdg-open recognise the new entry
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null && \
    echo "✅ XDG desktop database updated" || true

# Rebuild KDE's own service cache (Plasma 6)
if command -v kbuildsycoca6 &>/dev/null; then
    kbuildsycoca6 --noincremental 2>/dev/null && echo "✅ KDE service cache rebuilt (kbuildsycoca6)" || true
elif command -v kbuildsycoca5 &>/dev/null; then
    kbuildsycoca5 --noincremental 2>/dev/null && echo "✅ KDE service cache rebuilt (kbuildsycoca5)" || true
fi

# --- Set as default for common video formats ---
echo ""
echo "Setting MAPL Player as default for common video/audio formats..."
for mime in video/mp4 video/x-matroska video/x-msvideo video/quicktime \
            video/webm video/mpeg audio/mpeg audio/flac audio/ogg \
            audio/mp4 audio/aac; do
    xdg-mime default mapl-player.desktop "$mime" 2>/dev/null && \
        echo "  ✓ $mime" || echo "  ⚠ $mime (xdg-mime failed, set manually)"
done

echo ""
echo "🎉 Done! MAPL Player is installed."
echo ""
echo "To set it as default for all formats:"
echo "  System Settings → Applications → Default Applications → Video Player"
echo ""
echo "Or right-click any video/audio file in Dolphin → Open With → Other Application → set as default."
