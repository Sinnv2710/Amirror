# Amirror

🪞 Professional Android screen mirroring for macOS with friendly error messages and comprehensive features. Because your phone screen is too small and your neck deserves better.

## Features

- 📱 Single CLI for all operations (`./amirror start`, `./amirror doctor`, etc.)
- 🛡️ Comprehensive error handling with helpful suggestions
- 📊 Multi-level logging (DEBUG, INFO, WARN, ERROR)
- ⚡ Built on scrcpy - the fastest Android mirroring tool
- ✅ 18 automated tests included

## Quick Start

```bash
# 1. Check your system (recommended first step)
./amirror doctor

# 2. Install missing dependencies (if needed)
./amirror doctor --fix

# 3. Run the mirror
./amirror start

# Check status
./amirror status
```

## Requirements

- macOS 10.15+ (Bash 3.2+ compatible)
- Android device with USB debugging enabled
- [scrcpy](https://github.com/Genymobile/scrcpy) (includes adb)
- GNU coreutils (`timeout` command - install via: `brew install coreutils`)

## System Setup

### Check Your System (Recommended)

Before running Amirror, check that everything is set up correctly:

```bash
./amirror doctor
```

This will verify:

- ✅ Homebrew installation
- ✅ Required tools (scrcpy, adb, coreutils)
- ✅ System configuration
- ✅ File permissions
- ✅ Log directory setup
- ✅ Connected Android devices

### Auto-Fix Missing Dependencies

If something is missing, let the doctor fix it:

```bash
./amirror doctor --fix        # Install missing dependencies
./amirror doctor --install-all # Install/update all dependencies
```

## Commands

```bash
./amirror doctor             # Check system readiness
./amirror doctor --fix       # Install missing dependencies
./amirror start              # Start mirroring
./amirror start -s <serial>  # Mirror specific device
./amirror list               # Show connected devices
./amirror status             # Check system status
./amirror logs               # View recent logs
./amirror help               # Show all commands
```

## Documentation

- 📖 [User Guide](docs/USER-GUIDE.md) - Complete features and usage
- 🚀 [Quick Start](docs/QUICKSTART.md) - Get started in 2 minutes
- 🛠️ [Development](docs/DEVELOPMENT.md) - Architecture and contributing
- 🧪 [Testing](test/README.md) - Running the test suite

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

- 📝 [Issues](https://github.com/amirror/amirror/issues) - Bug reports and feature requests
- 📚 [scrcpy docs](https://github.com/Genymobile/scrcpy) - Underlying mirroring tool
- 💬 Check `logs/` directory for detailed error information
