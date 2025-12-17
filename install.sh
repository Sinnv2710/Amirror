#!/bin/bash
# Amirror Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/praparn/amirror-mac/main/install.sh | bash

set -e

echo ""
echo "🪞 =================================="
echo "   Amirror Installer"
echo "   Android Mirroring for macOS"
echo "==================================="
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This script only works on macOS"
    exit 1
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi
echo "✅ macOS detected ($ARCH)"

# Check Homebrew
echo ""
echo "📦 Checking dependencies..."
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found."
    echo ""
    echo "Install Homebrew first:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
    exit 1
fi
echo "✅ Homebrew found"

# Install dependencies
echo ""
echo "📦 Installing dependencies (scrcpy, coreutils)..."
brew install scrcpy coreutils 2>/dev/null || brew upgrade scrcpy coreutils 2>/dev/null || true
echo "✅ Dependencies installed"

# Check Xcode CLI tools
if ! xcode-select -p &> /dev/null; then
    echo ""
    echo "📦 Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "⏳ Please complete the Xcode CLI installation, then run this script again."
    exit 0
fi
echo "✅ Xcode CLI tools found"

# Clone repository
echo ""
echo "📥 Downloading Amirror..."
INSTALL_DIR="$HOME/.amirror"

if [ -d "$INSTALL_DIR" ]; then
    echo "   Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull --quiet
else
    git clone --depth 1 https://github.com/praparn/amirror-mac.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi
echo "✅ Downloaded to $INSTALL_DIR"

# Make scripts executable
chmod +x amirror
chmod +x src/cli/amirror
chmod +x src/cli/amirror.sh
chmod +x src/cli/doctor.sh

# Build the Swift app
echo ""
echo "🔨 Building Amirror app..."
cd "$INSTALL_DIR/src/app"
swift build -c release 2>&1 | grep -E "(Build|error|warning)" || true
echo "✅ Build complete"

# Create app bundle
echo ""
echo "📦 Creating app bundle..."

# Detect architecture for build path
if [[ "$ARCH" == "arm64" ]]; then
    RELEASE_DIR=".build/arm64-apple-macosx/release"
else
    RELEASE_DIR=".build/x86_64-apple-macosx/release"
fi

# Fallback to release directory if architecture-specific doesn't exist
if [ ! -d "$RELEASE_DIR" ]; then
    RELEASE_DIR=".build/release"
fi

APP_DIR="$HOME/Applications"
APP_BUNDLE="$APP_DIR/Amirror.app"

mkdir -p "$APP_DIR"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$RELEASE_DIR/Amirror" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/Amirror"

# Copy Info.plist
cp "Info.plist" "$APP_BUNDLE/Contents/"

# Create icon (if pillow available)
if command -v python3 &> /dev/null; then
    python3 -c "import PIL" 2>/dev/null && {
        python3 create_icon.py 2>/dev/null || true
        if [ -d "AppIcon.iconset" ]; then
            iconutil -c icns AppIcon.iconset -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true
        fi
    } || true
fi

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "✅ App bundle created at $APP_BUNDLE"

# Create CLI symlink
echo ""
echo "🔗 Setting up CLI..."

CLI_PATH="/usr/local/bin/amirror"
if [ -w "/usr/local/bin" ] || sudo -n true 2>/dev/null; then
    sudo ln -sf "$INSTALL_DIR/amirror" "$CLI_PATH" 2>/dev/null && {
        echo "✅ CLI installed at $CLI_PATH"
    } || {
        # Fallback to local bin
        mkdir -p "$HOME/.local/bin"
        ln -sf "$INSTALL_DIR/amirror" "$HOME/.local/bin/amirror"
        echo "✅ CLI installed at ~/.local/bin/amirror"
        echo "   Add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
    }
else
    mkdir -p "$HOME/.local/bin"
    ln -sf "$INSTALL_DIR/amirror" "$HOME/.local/bin/amirror"
    echo "✅ CLI installed at ~/.local/bin/amirror"
    echo "   Add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Done!
echo ""
echo "🎉 =================================="
echo "   Installation Complete!"
echo "==================================="
echo ""
echo "📍 App:  $APP_BUNDLE"
echo "📍 CLI:  amirror"
echo "📍 Repo: $INSTALL_DIR"
echo ""
echo "🚀 Quick Start:"
echo "   amirror doctor   # Check system"
echo "   amirror start    # Start mirroring"
echo "   amirror list     # List devices"
echo ""
echo "📱 Or open Amirror from ~/Applications"
echo ""