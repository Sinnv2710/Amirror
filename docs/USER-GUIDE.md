# Android Screen Mirror Script

A professional bash script for mirroring Android device screens on macOS using `scrcpy` with comprehensive error handling, device selection, and logging.

## Features

### Enhanced Version 2.0.0 🎉

✨ **User-Friendly Interface**
- Interactive device selection menu with model and Android version info
- Auto-selection when only one device is connected
- Beautiful terminal UI with colors and progress indicators
- User-friendly error messages with actionable suggestions

🛡️ **Advanced Error Handling** (NEW!)
- **Standardized error codes** - 10+ specific error codes for different scenarios
- **Stack traces** - Full call stack on errors for debugging
- **Try-catch pattern** - Bash implementation of exception handling
- **Timeout protection** - All operations have configurable timeouts (prevents hanging)
- **Input validation** - Validates device serials, user input, and command availability
- **Separate error log** - Dedicated error-only log file for quick debugging

📊 **Comprehensive Logging** (ENHANCED!)
- Multi-level logging (DEBUG, INFO, WARN, ERROR, FATAL)
- All operations logged to timestamped files in `logs/` directory
- Runtime logs hidden from terminal (only in log files)
- Separate error log file for quick issue diagnosis
- Caller information (file:line) in each log entry

🔄 **Reliability & Recovery** (NEW!)
- **Automatic retry with exponential backoff** - Retries failed operations intelligently
- **ADB recovery** - Automatically restarts ADB server on failure
- **Device validation** - Verifies device state before operations
- **Cleanup registration** - Automatic cleanup on any exit type
- **Process management** - Proper PID tracking and graceful shutdown

⚡ **Performance Optimized**
- Native bash for maximum compatibility and speed
- Minimal overhead, direct process execution
- Uses scrcpy (the fastest Android screen mirroring tool)
- Efficient error handling with minimal performance impact

## Requirements

- **macOS** (tested on macOS 10.15+, compatible with Bash 3.2+)
- **Homebrew** (for installing dependencies)
- **Android device** with USB debugging enabled

> **Note**: The scripts are compatible with macOS default Bash 3.2 and work seamlessly without requiring Bash 4.0+

## Installation

### 1. Install Dependencies

```bash
# Install scrcpy (includes adb)
brew install scrcpy
```

### 2. Download the Scripts

```bash
# Clone or download the repository
git clone <your-repo-url>
cd roid-mirror

# Scripts are ready to use (wrapper scripts in root, actual code in src/)
```

### 3. Enable USB Debugging on Your Android Device

1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times to enable Developer Options
3. Go to **Settings** → **Developer Options**
4. Enable **USB Debugging**
5. Connect your device via USB and authorize the computer

## Usage

### Option 1: Auto-Connect (Recommended)

Enable automatic device detection - a dialog appears when you plug in your Android device:

```bash
./roid-mirror install
```

After installation, just plug in your device and click "Yes" when prompted!

[See full Auto-Connect guide](docs/AUTO-CONNECT.md)

### Option 2: Manual Run

```bash
./roid-mirror start
```

### What Happens

1. **Dependency Check**: Verifies `adb` and `scrcpy` are installed
2. **Device Detection**: Lists all connected Android devices
3. **Device Selection**: You select which device to mirror (or auto-select if only one)
4. **Connection Verification**: Verifies the device connection with a loading indicator
5. **Screen Mirroring**: Starts mirroring with these parameters:
   - `--prefer-text`: Prefer text injection over key events
   - `--turn-screen-off`: Turn device screen off during mirroring
   - `--stay-awake`: Keep device awake while connected

### Stopping the Mirror

Press `Ctrl+C` to stop the mirroring session. The script will:
- Gracefully terminate the scrcpy process
- Clean up PID files
- Log the shutdown
- Exit cleanly

## Script Parameters

The script runs `scrcpy` with the following parameters:

| Parameter | Description |
|-----------|-------------|
| `--prefer-text` | Use text injection method (more reliable) |
| `--turn-screen-off` | Automatically turn off the device screen |
| `--stay-awake` | Keep the device awake while connected |

### Customizing Parameters

To modify scrcpy parameters, edit the `start_scrcpy()` function in the script:

```bash
scrcpy --serial="${device_id}" \
       --prefer-text \
       --turn-screen-off \
       --stay-awake \
       --max-fps 60 \          # Add frame rate limit
       --bit-rate 8M \          # Add custom bitrate
       >> "${LOG_FILE}" 2>&1 &
```

See all scrcpy options: `scrcpy --help`

## Log Files

Logs are stored in the `logs/` directory with timestamps:

```
logs/
  └── android-mirror-20241212_143022.log
```

### Log Levels

- **INFO**: General information (script start, device selection, etc.)
- **DEBUG**: Detailed debugging information
- **ERROR**: Error messages with context

### Viewing Logs

```bash
# View the latest log
tail -f logs/android-mirror-*.log | tail -1

# View all logs
cat logs/android-mirror-20241212_143022.log
```

## Error Handling & Messages

The enhanced version provides comprehensive error handling with specific error codes and detailed messages:

### Error Codes

| Code | Scenario | Description |
|------|----------|-------------|
| 10 | Missing Dependencies | Required tools (adb/scrcpy) not installed |
| 11 | No Devices | No Android devices connected |
| 12 | Device Disconnected | Device lost connection during operation |
| 13 | Scrcpy Failed | Screen mirroring failed to start |
| 14 | ADB Error | ADB server communication error |
| 17 | Timeout | Operation exceeded timeout limit |
| 18 | Invalid Input | User provided invalid input |

### Example Error Messages

**No Devices Connected:**

```
✗ Error (Code: 11)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
No Android devices detected.

Suggestions:
1. Ensure device is connected via USB
2. Enable USB debugging on your device:
   Settings → Developer Options → USB Debugging
3. Accept the authorization prompt on your device
4. Try a different USB cable or port
5. Run 'adb devices' manually to verify

Log file: logs/android-mirror-20241212_143022.log
Error log: logs/error-20241212_143022.log
```

**Missing Dependencies:**

```
✗ Error (Code: 10)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Missing dependency: scrcpy

Suggestions:
Install with: brew install scrcpy
```

**Connection Failed:**

```
✗ Error (Code: 12)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Device connection lost.

Suggestions:
1. Check USB cable connection
2. Device may have disconnected
3. USB debugging may have been disabled
4. Try reconnecting the device
```

**Timeout Error:**

```
✗ Error (Code: 17)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Operation timed out after 10 seconds.

Suggestions:
1. Device may be unresponsive
2. Try unplugging and replugging your device
3. Restart ADB server: adb kill-server && adb start-server
```

## Troubleshooting

### Device Not Detected

1. Ensure USB debugging is enabled
2. Try a different USB cable (data cable, not charge-only)
3. Revoke and re-authorize USB debugging
4. Check `adb devices` manually

### Scrcpy Won't Start

1. Check log file for detailed errors
2. Ensure device screen is unlocked
3. Try disconnecting and reconnecting the device
4. Restart adb server: `adb kill-server && adb start-server`

### Permission Issues

```bash
# Make script executable
chmod +x roid-mirror

# Check log directory permissions
chmod -R 755 logs/
```

### Multiple Devices

If you have multiple devices connected, the script will show a menu. Select the device number you want to mirror.

## Performance Notes

### Why Bash?

- **Native**: Pre-installed on all macOS systems
- **Fast**: Direct process execution, no interpretation overhead
- **Compatible**: Works on all macOS versions (10.x - 15.x)
- **Simple**: Easy to debug and modify
- **Reliable**: Mature, stable language for system scripting

### Why Scrcpy?

scrcpy is the **industry standard** for Android screen mirroring:

- Written in **C** for maximum performance
- **Low latency** (35-70ms)
- **High frame rate** (30-60 fps)
- **Low bandwidth** usage
- Open source and actively maintained
- No device-side installation required

There is no better alternative with the same feature set and performance.

## Advanced Usage

### Running in Background (Not Recommended)

While the script is designed to run in the foreground, you can run it in the background:

```bash
nohup ./roid-mirror start > /dev/null 2>&1 &
```

However, you won't be able to select devices interactively.

### Auto-Selecting a Specific Device

If you want to skip device selection, modify the script to hardcode a device ID:

```bash
# In the main() function, replace:
device_id=$(select_device)

# With:
device_id="YOUR_DEVICE_ID_HERE"
```

### Running on System Startup

Create a Launch Agent for automatic startup:

```bash
# Create plist file
cat > ~/Library/LaunchAgents/com.user.android-mirror.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.android-mirror</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/android-mirror.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the agent
launchctl load ~/Library/LaunchAgents/com.user.android-mirror.plist
```

## Project Structure

```
roid-mirror/
├── README.md                   # Main documentation
├── android-mirror.sh           # Wrapper script (run from root)
├── install-monitor.sh          # Auto-monitor installer wrapper
├── uninstall-monitor.sh        # Auto-monitor uninstaller wrapper
├── src/                        # 📦 Source code
│   ├── android-mirror.sh      # Main mirroring script
│   ├── usb-monitor.sh         # USB device monitor
│   ├── install-monitor.sh     # Monitor installation script
│   ├── uninstall-monitor.sh   # Monitor uninstallation script
│   └── com.user.android.usb-monitor.plist
├── lib/                        # 📚 Libraries
│   └── error-handler.sh       # Reusable error handling library
├── docs/                       # 📄 Documentation
│   ├── USER-GUIDE.md           # Documentation index (this file)
│   ├── DEVELOPMENT.md          # Developer guide
│   ├── AUTO-CONNECT.md         # Auto-connect setup guide
│   └── QUICKSTART.md           # Quick start guide
└── logs/                       # 📊 Logs (auto-generated)
    ├── android-mirror-*.log   # Main operation logs
    └── error-*.log            # Error-only logs
```

### Why This Structure?

- **Root level**: Clean interface with wrapper scripts and README
- **src/**: All executable scripts and configuration files
- **lib/**: Reusable libraries and utilities
- **docs/**: Complete documentation separate from code
- **logs/**: Auto-generated, not tracked in git

## Script Architecture

### Error Handling

The script uses bash's `set -euo pipefail` for strict error handling:

- `set -e`: Exit on any error
- `set -u`: Exit on undefined variables
- `set -o pipefail`: Exit on pipe failures

Plus trap handlers for:
- `INT/TERM`: Handles Ctrl+C gracefully
- `ERR`: Catches and logs all errors

### Cleanup Process

The `cleanup()` function ensures:
1. PID file is read
2. scrcpy process is terminated (SIGTERM)
3. Force kill if needed (SIGKILL)
4. PID file is removed
5. Any zombie processes are cleaned up

### Logging System

All operations are logged with:
- Timestamp
- Log level (INFO/DEBUG/ERROR)
- Detailed message

Logs are appended to timestamped files for historical tracking.

## Contributing

Feel free to modify the script for your needs. Common modifications:

- Add custom scrcpy parameters
- Change log format or location
- Modify UI colors or styling
- Add additional error checks
- Implement configuration file support

## License

This script is provided as-is for personal and commercial use.

## Support

For issues with:
- **This script**: Check the log files in `logs/` directory
- **scrcpy**: Visit https://github.com/Genymobile/scrcpy
- **adb**: Visit https://developer.android.com/tools/adb

## Advanced Features (v2.0.0)

### Error Handling Library

The script includes a reusable error handling library (`lib/error-handler.sh`) with:

- **Try-Catch Pattern**: Bash implementation of exception handling
- **Retry Logic**: Automatic retry with exponential backoff
- **Timeout Protection**: Configurable timeouts for all operations
- **Stack Traces**: Full call stack on errors for debugging
- **Validation Functions**: Input validation, file checks, command verification
- **Cleanup Management**: Registered cleanup functions run on any exit

### Using the Library in Your Scripts

```bash
#!/bin/bash

# Source the error handling library
source "lib/error-handler.sh"
init_error_handling

# Use safe execution with timeout
execute_with_timeout 10 "Check device" adb devices

# Retry with exponential backoff
retry_with_backoff 3 2 "Connect to device" adb connect 192.168.1.100

# Validate inputs
assert_not_empty "device_id" "$DEVICE_ID"
validate_serial "$DEVICE_ID"

# Use try-catch
try
    my_risky_command
catch || {
    show_error "${ERROR_CODES[GENERAL_ERROR]}" "Command failed"
    throw "${ERROR_CODES[GENERAL_ERROR]}"
}
```

### Automatic Recovery Features

1. **ADB Server Recovery**: Automatically restarts ADB server on communication failures
2. **Device State Validation**: Verifies device is ready before operations
3. **Connection Retry**: Retries device connections with exponential backoff
4. **Timeout Recovery**: Handles hung operations gracefully

### Logging System

**Two log files per execution:**
- `logs/android-mirror-TIMESTAMP.log` - Complete operation log
- `logs/error-TIMESTAMP.log` - Errors only for quick debugging

**Log levels:**
- `DEBUG` - Detailed diagnostic information
- `INFO` - General informational messages
- `WARN` - Warning messages (non-fatal issues)
- `ERROR` - Error messages (recoverable errors)
- `FATAL` - Fatal errors (unrecoverable)

**View logs:**
```bash
# View latest main log
ls -t logs/android-mirror-*.log | head -1 | xargs tail -50

# View latest errors only
ls -t logs/error-*.log | head -1 | xargs cat

# Follow live logging
tail -f logs/android-mirror-$(date +%Y%m%d)*.log
```

## Version History

- **v2.0.0** (2024-12-12) - Enhanced Version
  - Added comprehensive error handling library
  - Implemented standardized error codes (10+)
  - Added stack traces on errors
  - Implemented try-catch pattern for Bash
  - Added timeout protection for all operations
  - Implemented automatic retry with exponential backoff
  - Added ADB server auto-recovery
  - Enhanced logging with multiple levels
  - Added separate error log file
  - Improved input validation
  - Added cleanup function registration
  - Enhanced USB monitor with better error handling

- **v1.0.0** (2024-12-12) - Initial Release
  - Device selection menu
  - Basic error handling
  - Logging system
  - Process management
  - Loading indicators
  - USB auto-detection

---
