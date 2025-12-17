# 🪞 Amirror

Professional Android screen mirroring for macOS — like iPhone Mirroring, but for Android.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

- 🔌 USB and wireless connection support
- 🖥️ High-quality screen mirroring via scrcpy
- ⌨️ Keyboard and mouse input passthrough
- 📱 Menu bar app for quick access
- 🛠️ Powerful CLI for automation

## 📋 Requirements

- macOS 13.0 (Ventura) or later
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools
- Android device with USB debugging enabled

## 📦 Install / Uninstall

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/Sinnv2710/Amirror/main/install.sh | bash

# Uninstall
curl -fsSL https://raw.githubusercontent.com/Sinnv2710/Amirror/main/uninstall.sh | bash
```

This will:

1. Install dependencies (scrcpy, coreutils)
2. Build the app from source
3. Install to `~/Applications/Amirror.app`
4. Set up the `amirror` CLI command

## 🛠️ Manual Installation

### 1. Install Prerequisites

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Xcode CLI tools
xcode-select --install

```

### 2. Clone & Build

```bash
# Clone the repository
git clone https://github.com/praparn/amirror-mac.git
cd amirror-mac

# Build the Swift app
cd src/app
swift build -c release

# Or use the build script
./build.sh
```

### 3. Run

```bash
# CLI usage (from project root)
./amirror doctor   # Check system requirements
./amirror start    # Start mirroring
./amirror list     # List connected devices
./amirror help     # Show all commands
```

## 📱 Enable USB Debugging on Android

1. Go to **Settings** → **About phone**
2. Tap **Build number** 7 times to enable Developer options
3. Go to **Settings** → **Developer options**
4. Enable **USB debugging**
5. Connect your phone via USB
6. Accept the debugging prompt on your phone

## 🎮 CLI Commands

| Command            | Description               |
| ------------------ | ------------------------- |
| `amirror start`  | Start screen mirroring    |
| `amirror stop`   | Stop mirroring            |
| `amirror list`   | List connected devices    |
| `amirror doctor` | Check system requirements |
| `amirror help`   | Show help                 |

## 🔧 Development

```bash
# Run tests
./test/test-runner.sh

# Build release
cd src/app && swift build -c release

# Build app bundle
cd src/app && ./build.sh
```

## 📁 Project Structure

```
amirror-mac/
├── amirror              # CLI entry point (symlink)
├── install.sh           # One-liner installer
├── src/
│   ├── cli/
│   │   ├── amirror      # Main CLI script
│   │   ├── amirror.sh   # Mirroring logic
│   │   └── doctor.sh    # System checks
│   └── app/
│       ├── AmirrorApp.swift  # Menu bar app
│       ├── Package.swift     # Swift package
│       └── build.sh          # Build script
└── test/
    └── test-runner.sh   # Test suite
```

## 🙏 Credits

- [scrcpy](https://github.com/Genymobile/scrcpy) - The amazing Android mirroring tool
- [Homebrew](https://brew.sh) - Package manager for macOS

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**Made with ❤️ for Android users on Mac**
