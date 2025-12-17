# Building the macOS App

## Requirements
- macOS 11+
- Xcode 13+ (for SwiftUI support)
- scrcpy and adb installed via homebrew

## Build Instructions

### Using Xcode (Recommended)
1. Create a new Xcode project:
   ```bash
   open -b com.apple.dt.Xcode
   ```
   
2. File → New → Project
3. Choose "macOS" → "App"
4. Set Product Name to "Amirror"
5. Replace the generated files with the contents from this directory
6. Build: ⌘B
7. Run: ⌘R

### Using Swift CLI
```bash
cd macos-app
swift build -c release
```

The app will be built to `.build/release/Amirror`

## Installation

After building, move to Applications:
```bash
cp .build/release/Amirror /Applications/Amirror.app
```

## Auto-launch at Login

To add to Login Items:
1. Open System Preferences → General → Login Items
2. Add Amirror.app
3. Or run:
   ```bash
   osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Amirror.app", hidden:false}'
   ```

## Features

- **Menu Bar App**: Click the Android icon in menu bar
- **Device List**: Shows all connected Android devices with model names
- **One-Click Mirror**: Click device to start scrcpy
- **Auto-Refresh**: Checks for device changes every 2 seconds
- **Manual Refresh**: Click refresh icon to check immediately
- **No Background Daemon**: Cleaner than monitoring service
