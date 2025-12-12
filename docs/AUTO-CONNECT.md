# Auto-Connect Setup Guide

## What is Auto-Connect?

When enabled, your Mac will automatically detect when you connect an Android device via USB and show a dialog asking if you want to start screen mirroring. No need to manually run the script!

## How It Works

1. **USB Detection**: Monitors USB connections using macOS Launch Agent
2. **Device Recognition**: Detects Android devices via `adb`
3. **User Prompt**: Shows native macOS dialog with "Yes" or "No" options
4. **Auto-Launch**: Opens Terminal and runs the mirror script if you click "Yes"

## Installation

### Step 1: Install Dependencies

```bash
brew install scrcpy
```

### Step 2: Install the USB Monitor

```bash
./install-monitor.sh
```

That's it! The monitor is now active.

## Testing

1. **Disconnect** your Android device (if connected)
2. **Reconnect** it via USB
3. You should see a dialog: **"Android device detected! Would you like to start screen mirroring?"**
4. Click **"Yes"** → Terminal opens and runs the script
5. Click **"No"** → Nothing happens

## What Gets Installed

- **Launch Agent**: `~/Library/LaunchAgents/com.user.android.usb-monitor.plist`
- **Trigger**: Monitors `/var/run/usbmuxd` for USB changes
- **Script**: Runs `usb-monitor.sh` automatically when USB devices change
- **Logs**: Stored in `logs/usb-monitor.log`

## Usage Examples

### Scenario 1: First Connection Today
1. Plug in Android device
2. Dialog appears: "Android device detected! Would you like to start screen mirroring?"
3. Click "Yes"
4. Terminal opens with device selection menu
5. Select your device
6. Screen mirroring starts

### Scenario 2: Reconnecting Same Device
1. Plug in Android device (same device as before)
2. Dialog appears again
3. Click "Yes" to connect or "No" to skip

### Scenario 3: Multiple Devices
1. Plug in first device → Dialog appears
2. Click "No" (not interested right now)
3. Plug in second device → Dialog appears again
4. Click "Yes" → Choose which device from the menu

## Uninstallation

To disable auto-detection:

```bash
./uninstall-monitor.sh
```

This removes the Launch Agent. You can still manually run `./android-mirror.sh` anytime.

## Troubleshooting

### Dialog Not Appearing

**Check if service is running:**
```bash
launchctl list | grep android
```

You should see: `com.user.android.usb-monitor`

**Manually trigger the monitor:**
```bash
./usb-monitor.sh
```

**Check logs:**
```bash
cat logs/usb-monitor.log
```

### Permission Issues

If the dialog doesn't appear, grant Terminal accessibility permissions:

1. Go to **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Accessibility**
3. Add **Terminal** if not listed
4. Enable the checkbox

### Service Not Starting

**Unload and reload:**
```bash
launchctl unload ~/Library/LaunchAgents/com.user.android.usb-monitor.plist
launchctl load ~/Library/LaunchAgents/com.user.android.usb-monitor.plist
```

**Check for errors:**
```bash
cat logs/usb-monitor-stderr.log
```

### adb Not Found

The Launch Agent needs to know where `adb` is located:

```bash
# Find adb location
which adb

# If it's in /opt/homebrew/bin, the plist already includes it
# If it's elsewhere, you may need to edit the plist PATH
```

## Technical Details

### Launch Agent Configuration

The plist file watches `/var/run/usbmuxd`, which changes whenever USB devices connect/disconnect. This is the most reliable way to detect device changes on macOS.

### State Tracking

The monitor keeps track of connected devices in `.last_devices` to avoid showing dialogs repeatedly for the same device without changes.

### Dialog vs Terminal

- **Dialog**: Native macOS dialog using AppleScript (`osascript`)
- **Terminal**: Opens a new Terminal window/tab for the mirror script
- **Clean Exit**: Terminal closes when you press Ctrl+C in the mirror script

## Advanced Configuration

### Change Dialog Behavior

Edit `usb-monitor.sh` to customize the dialog:

```bash
# Change dialog text
display dialog "Your custom message" buttons {"Cancel", "Connect"} default button "Connect"

# Change icon (note, caution, stop)
with icon caution
```

### Run Without Dialog

To auto-connect without asking (not recommended):

```bash
# In usb-monitor.sh, replace prompt_user() with:
prompt_user() {
    osascript <<EOF
tell application "Terminal"
    do script "cd '${SCRIPT_DIR}' && '${MAIN_SCRIPT}'"
end tell
EOF
}
```

### Disable for Specific Devices

Add device filtering in `usb-monitor.sh`:

```bash
# Skip specific device IDs
if [[ "${new_devices}" == "ABC123456" ]]; then
    log_monitor "Ignoring device: ${new_devices}"
    return
fi
```

## Security Considerations

- The monitor only runs when USB changes are detected (low resource usage)
- No automatic connections without user approval
- All actions are logged for audit trail
- No network access required
- Runs in user space (no system/root privileges needed)

## Performance Impact

- **CPU**: Negligible (only runs on USB events)
- **Memory**: ~5MB for Launch Agent
- **Battery**: No measurable impact
- **Startup**: No impact (doesn't run at boot unless device connected)

## Comparison: Manual vs Auto

| Feature | Manual (`./android-mirror.sh`) | Auto (`install-monitor.sh`) |
|---------|-------------------------------|----------------------------|
| Detection | Manual | Automatic |
| User Action | Open Terminal, run script | Just plug in device |
| Dialog | No | Yes |
| Convenience | Low | High |
| Control | Full | Opt-in per connection |

## FAQ

**Q: Does this work with wireless debugging?**  
A: No, it only detects USB connections. Wireless ADB connections won't trigger the dialog.

**Q: Can I auto-connect without the dialog?**  
A: Yes, but not recommended. See "Advanced Configuration" above.

**Q: What if I have multiple Macs?**  
A: Install on each Mac separately. The monitor is per-machine.

**Q: Does this drain my battery?**  
A: No, it only activates when USB devices change.

**Q: Can I customize the dialog?**  
A: Yes, edit `usb-monitor.sh` to change the text, buttons, or icon.

**Q: Will this interfere with other USB devices?**  
A: No, it only responds to Android devices (via `adb devices`).

---

**Ready to enable auto-connect?** Run `./install-monitor.sh` now!
