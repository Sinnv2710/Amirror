#!/bin/bash

# Build Amirror macOS app
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/.build"
ARCH="arm64-apple-macosx"
RELEASE_DIR="${BUILD_DIR}/${ARCH}/release"

echo "🔨 Building Amirror menu bar app..."

# Build with Swift (release mode)
cd "${SCRIPT_DIR}"
swift build -c release 2>&1 | grep -v "warning:" || true

# Check if build succeeded
if [ ! -f "${RELEASE_DIR}/Amirror" ]; then
    echo "❌ Build failed - executable not found at ${RELEASE_DIR}/Amirror"
    exit 1
fi

# Create app bundle structure
APP_BUNDLE="${SCRIPT_DIR}/Amirror.app"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${RELEASE_DIR}/Amirror" "${APP_BUNDLE}/Contents/MacOS/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/Amirror"

# Copy Info.plist
cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/"

# Create PkgInfo
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Create app icon if source icon exists
ICON_SOURCE="${SCRIPT_DIR}/icon/app_icon.png"
if [ -f "${ICON_SOURCE}" ]; then
    echo "🎨 Creating app icon..."
    python3 "${SCRIPT_DIR}/create_icon.py"
    
    # Also copy the icon for menu bar use (will be resized by the app)
    cp "${ICON_SOURCE}" "${APP_BUNDLE}/Contents/Resources/MenuBarIcon.png"
    echo "✅ Menu bar icon copied"
else
    echo "⚠️  No icon/app_icon.png found - using default icon"
fi

echo ""
echo "✅ Build complete!"
echo ""

# Install to Applications folder
echo "📦 Installing to /Applications..."
rm -rf "/Applications/Amirror.app"
cp -r "${APP_BUNDLE}" /Applications/

echo "✅ Installed to /Applications/Amirror.app"
echo ""
echo "To run the app:"
echo "  open /Applications/Amirror.app"
