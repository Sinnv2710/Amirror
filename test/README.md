# Test Suite for Amirror

This directory contains automated tests to validate all functionality before release.

## Quick Start

Run all tests:
```bash
./test/test-runner.sh
```

## Project Structure

```
amirror-mac/
├── src/
│   ├── cli/           # CLI tools
│   │   ├── amirror
│   │   ├── amirror.sh
│   │   └── doctor.sh
│   ├── lib/           # Shared libraries
│   │   └── error-handler.sh
│   └── app/           # macOS GUI app
│       ├── AmirrorApp.swift
│       ├── Package.swift
│       ├── Info.plist
│       ├── build.sh
│       └── create_icon.py
├── docs/
├── test/
└── README.md
```

## What Gets Tested

### 1. Project Structure
- ✓ All required directories exist (src/cli/, src/lib/, src/app/, docs/, test/)
- ✓ Main script exists and is executable
- ✓ All CLI scripts exist and are executable
- ✓ Documentation files exist (README.md, USER-GUIDE.md, DEVELOPMENT.md)

### 2. Syntax Validation
- ✓ Main script has valid Bash syntax
- ✓ Error handler library has valid syntax
- ✓ Amirror script has valid syntax
- ✓ Doctor script has valid syntax
- ✓ Swift app has valid syntax (if swiftc available)

### 3. Command Functionality
- ✓ No arguments shows help (default behavior)
- ✓ `help` command displays documentation
- ✓ `--help` flag works
- ✓ `version` command shows version
- ✓ `--version` flag works
- ✓ Invalid commands show error messages
- ✓ `status` command runs without errors
- ✓ `list` command runs (even without devices)
- ✓ `devices` alias works
- ✓ `logs` command runs without errors

### 4. macOS App
- ✓ App source files exist (AmirrorApp.swift, Package.swift, Info.plist)
- ✓ Build script exists and is executable
- ✓ Swift syntax is valid (if swiftc available)

## Test Output

The test runner provides:
- Clear pass/fail status for each test
- Color-coded results (green for pass, red for fail)
- Summary of total tests, passed, and failed
- List of failed tests with reasons

## Example Output

```
╔════════════════════════════════════════════════════╗
║   Amirror - Test Suite                            ║
╚════════════════════════════════════════════════════╝

Project Structure Tests
─────────────────────────────────────────────────────
▶ Testing: Required directories exist
  ✓ PASS

▶ Testing: Main script exists and is executable
  ✓ PASS

Syntax Validation Tests
─────────────────────────────────────────────────────
▶ Testing: Main script has valid syntax
  ✓ PASS

Command Functionality Tests
─────────────────────────────────────────────────────
▶ Testing: help command displays documentation
  ✓ PASS

macOS App Tests
─────────────────────────────────────────────────────
▶ Testing: App source files exist
  ✓ PASS

═════════════════════════════════════════════════════
Test Results
─────────────────────────────────────────────────────
Total Tests:  22
Passed:       22
═════════════════════════════════════════════════════
✓ All tests passed!
```

## Adding New Tests

To add a new test, create a function in `test-runner.sh`:

```bash
test_your_feature() {
    test_start "Description of your test"
    
    # Your test logic here
    local output
    output=$(./amirror your-command 2>&1)
    
    assert_output_contains "$output" "expected text" || return 1
    
    test_pass
}
```

Then add it to the `run_all_tests()` function.

## Test Framework Functions

- `test_start "name"` - Start a test
- `test_pass` - Mark test as passed
- `test_fail "reason"` - Mark test as failed
- `assert_exit_code expected actual command` - Check exit code
- `assert_output_contains output text` - Check output contains text
- `assert_output_not_contains output text` - Check output doesn't contain text
- `assert_file_exists path` - Check file/directory exists

## CI/CD Integration

You can integrate this into CI/CD pipelines:

```bash
# Run tests and exit with appropriate code
./test/test-runner.sh
```

Exit codes:
- `0` - All tests passed
- `1` - One or more tests failed
