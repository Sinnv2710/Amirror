#!/bin/bash
# Amirror Uninstaller

echo ""
echo "🪞 Amirror Uninstaller"
echo ""

read -p "Are you sure you want to uninstall Amirror? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo "🗑️  Removing Amirror..."

# Remove app bundle
rm -rf "$HOME/Applications/Amirror.app" 2>/dev/null && echo "   ✓ Removed ~/Applications/Amirror.app"

# Remove CLI symlinks
sudo rm -f /usr/local/bin/amirror 2>/dev/null && echo "   ✓ Removed /usr/local/bin/amirror"
rm -f "$HOME/.local/bin/amirror" 2>/dev/null && echo "   ✓ Removed ~/.local/bin/amirror"

# Remove installation directory
rm -rf "$HOME/.amirror" 2>/dev/null && echo "   ✓ Removed ~/.amirror"

echo ""
echo "✅ Amirror has been uninstalled."
echo ""
echo "Note: scrcpy and coreutils were not removed."
echo "To remove them: brew uninstall scrcpy coreutils"
echo ""