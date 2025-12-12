# Development Guide

## Project Structure

```
roid-mirror/
├── roid-mirror            # Main CLI entry point (user-facing CLI; delegates to src/android-mirror.sh and other scripts)
├── src/                   # Source scripts
│   ├── android-mirror.sh  # Core mirroring logic (invoked by roid-mirror; not intended for direct use)
│   ├── usb-monitor.sh     # USB device detection
│   ├── install-monitor.sh # Auto-monitor installer
│   └── uninstall-monitor.sh
├── lib/                   # Reusable libraries
│   └── error-handler.sh   # Error handling framework
├── test/                  # Test suite
│   └── test-runner.sh     # Automated tests
└── docs/                  # Documentation
```

## Architecture

### Main Entry Point (`roid-mirror`)

Single CLI that routes commands:
- Parses global options (`--help`, `--version`, `--debug`)
- Routes to subcommands (`start`, `install`, `status`, etc.)
- Built-in commands: `list`, `status`, `logs`
- Delegates complex operations to `src/` scripts

### Error Handling Library (`lib/error-handler.sh`)

Reusable error handling with:
- **Error codes**: 10+ standardized codes
- **Try-catch pattern**: Bash exception handling
- **Retry logic**: Exponential backoff
- **Timeout protection**: Configurable timeouts
- **Validation**: Input, file, command checks
- **Logging**: Multi-level (DEBUG, INFO, WARN, ERROR, FATAL)

### Core Scripts (`src/`)

- **android-mirror.sh**: Device selection, connection, scrcpy management
- **usb-monitor.sh**: Detects USB connections, shows dialogs
- **install-monitor.sh**: Sets up Launch Agent
- **uninstall-monitor.sh**: Removes Launch Agent

## Testing

Run all tests:
```bash
./test/test-runner.sh
```

Tests cover:
- Project structure validation
- Syntax checking (all scripts)
- Command functionality
- Exit codes
- Error messages

Further test documentation will be added soon.

## Adding New Features

### 1. Add a new command

In `roid-mirror`:
```bash
# Add handler function
cmd_my_feature() {
    # Your logic or delegate to src/
    exec "${SRC_DIR}/my-feature.sh"
}

# Add to case statement in main()
case "$command" in
    # ... existing commands
    my-feature)
        cmd_my_feature "$@"
        ;;
esac
```

### 2. Add error handling

Use the library in your script:
```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/error-handler.sh"
init_error_handling

# Use features
execute_with_timeout 10 "My operation" my_command
retry_with_backoff 3 2 "Connect" my_connection_func
validate_file "$input_file"
```

### 3. Add tests

In `test/test-runner.sh`:
```bash
test_my_feature() {
    test_start "My feature works"
    
    local output
    output=$("${MAIN_SCRIPT}" my-feature 2>&1)
    
    assert_output_contains "$output" "expected text" || return 1
    test_pass
}

# Add to run_all_tests()
```

## Compatibility

### macOS Bash 3.2

The project is compatible with macOS default Bash 3.2:
- No associative arrays (use indexed arrays)
- No `mapfile` (use `while read` loops)
- Arithmetic: `$((var + 1))` not `((var++))`
- Always test on macOS before release

### Shell Detection

Error handler detects shell type:
```bash
SHELL_TYPE="bash"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
fi
```

## Code Style

- **Functions**: `snake_case`
- **Constants**: `UPPER_SNAKE_CASE`
- **Local variables**: `local var_name`
- **Error codes**: Define in `ERROR_CODES` array
- **Logging**: Use `log_info`, `log_error`, `log_debug`
- **Comments**: Document complex logic

## Release Checklist

- [ ] All tests pass (`./test/test-runner.sh`)
- [ ] Version updated in `roid-mirror`
- [ ] CHANGELOG updated (if exists)
- [ ] Documentation reflects changes
- [ ] Tested on macOS Bash 3.2
- [ ] README.md is current
- [ ] Commit and tag release

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new features
4. Ensure all tests pass
5. Update documentation
6. Submit pull request

## Troubleshooting Development

### Bash 3.2 Compatibility Issues

```bash
# BAD: Not in Bash 3.2
mapfile -t array < <(command)
declare -A assoc_array
((counter++))

# GOOD: Compatible
while IFS= read -r line; do
    array+=("$line")
done < <(command)
# Use parallel arrays or different structure
counter=$((counter + 1))
```

### Testing Locally

```bash
# Check syntax
bash -n script.sh

# Run with debug
bash -x script.sh

# Test error handling
DEBUG=1 ./roid-mirror start
```

### Log Analysis

```bash
# View latest logs
ls -t logs/*.log | head -1 | xargs tail -50

# Find errors
grep ERROR logs/*.log

# Follow live
tail -f logs/android-mirror-*.log
```
