# roid-mirror

🪞 Professional Android screen mirroring for macOS with auto-USB detection, friendly error messages, and the patience of a saint. Because your phone screen is too small and your neck deserves better.

## Features

- 📱 Single CLI for all operations (`./roid-mirror start`, `./roid-mirror install`, etc.)
- 🔌 Auto-detects USB devices with macOS dialog prompts
- 🛡️ Comprehensive error handling with helpful suggestions
- 📊 Multi-level logging (DEBUG, INFO, WARN, ERROR)
- ⚡ Built on scrcpy - the fastest Android mirroring tool
- ✅ 18 automated tests included

## Quick Start

```bash
# Install dependencies
brew install scrcpy

# Run the mirror
./roid-mirror start

# Enable auto-detection when USB plugged in
./roid-mirror install

# Check status
./roid-mirror status
```

## Requirements

- macOS 10.15+ (Bash 3.2+ compatible)
- Android device with USB debugging enabled
- [scrcpy](https://github.com/Genymobile/scrcpy) (includes adb)

## Commands

```bash
./roid-mirror start              # Start mirroring
./roid-mirror start -s <serial>  # Mirror specific device
./roid-mirror list               # Show connected devices
./roid-mirror install            # Install auto-detection
./roid-mirror status             # Check system status
./roid-mirror logs               # View recent logs
./roid-mirror help               # Show all commands
```

## Documentation

- 📖 [User Guide](docs/USER-GUIDE.md) - Complete features and usage
- 🚀 [Quick Start](docs/QUICKSTART.md) - Get started in 2 minutes
- 🔌 [Auto-Connect](docs/AUTO-CONNECT.md) - USB auto-detection setup
- 🛠️ [Development](docs/DEVELOPMENT.md) - Architecture and contributing
- 🧪 [Testing](test/README.md) - Running the test suite

## Testing

```bash
./test/test-runner.sh
```

All 18 tests validate structure, syntax, and functionality before release.

## Acknowledgments

This project is powered by these amazing open-source tools:

- 🎯 **[scrcpy](https://github.com/Genymobile/scrcpy)** by [Genymobile](https://github.com/Genymobile) - The incredible screen mirroring engine that makes this all possible. Low latency, high performance, and rock solid.
- 🔧 **[Android Debug Bridge (adb)](https://developer.android.com/tools/adb)** by Google - The foundation for Android device communication.

Huge thanks to the maintainers and contributors of these projects! 🙏

## License

MIT License - use freely for personal or commercial projects.

## Support

- 📝 [Issues](https://github.com/YOUR_USERNAME/roid-mirror/issues) - Bug reports and feature requests
- 📚 [scrcpy docs](https://github.com/Genymobile/scrcpy) - Underlying mirroring tool
- 💬 Check `logs/` directory for detailed error information
