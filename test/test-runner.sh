#!/usr/bin/env bash

################################################################################
# Test Runner for Android Mirror
# Description: Validates all commands and parameters work correctly
################################################################################

set -eo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly MAIN_SCRIPT="${PROJECT_ROOT}/roid-mirror"

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

################################################################################
# Test Framework Functions
################################################################################

test_start() {
    local test_name="$1"
    echo -e "${BLUE}▶${NC} Testing: ${test_name}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "  ${GREEN}✓${NC} PASS"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
}

test_fail() {
    local reason="$1"
    echo -e "  ${RED}✗${NC} FAIL: ${reason}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("${test_name}: ${reason}")
    echo ""
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local cmd="$3"
    
    if [[ "$actual" -eq "$expected" ]]; then
        return 0
    else
        test_fail "Expected exit code ${expected}, got ${actual} for: ${cmd}"
        return 1
    fi
}

assert_output_contains() {
    local output="$1"
    local expected="$2"
    
    if echo "$output" | grep -q "$expected"; then
        return 0
    else
        test_fail "Output does not contain: ${expected}"
        return 1
    fi
}

assert_output_not_contains() {
    local output="$1"
    local unexpected="$2"
    
    if ! echo "$output" | grep -q "$unexpected"; then
        return 0
    else
        test_fail "Output should not contain: ${unexpected}"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    
    if [[ -f "$file" ]] || [[ -d "$file" ]]; then
        return 0
    else
        test_fail "File/directory does not exist: ${file}"
        return 1
    fi
}

################################################################################
# Test Cases
################################################################################

test_script_exists() {
    test_start "Main script exists and is executable"
    
    if [[ ! -f "$MAIN_SCRIPT" ]]; then
        test_fail "Main script not found at ${MAIN_SCRIPT}"
        return 1
    fi
    
    if [[ ! -x "$MAIN_SCRIPT" ]]; then
        test_fail "Main script is not executable"
        return 1
    fi
    
    test_pass
}

test_no_args_shows_help() {
    test_start "Running without arguments shows help"
    
    local output
    output=$("${MAIN_SCRIPT}" 2>&1 || true)
    
    assert_output_contains "$output" "Android Mirror" || return 1
    assert_output_contains "$output" "USAGE:" || return 1
    assert_output_contains "$output" "COMMANDS:" || return 1
    
    test_pass
}

test_help_command() {
    test_start "help command displays documentation"
    
    local output
    output=$("${MAIN_SCRIPT}" help 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "${MAIN_SCRIPT} help" || return 1
    assert_output_contains "$output" "USAGE:" || return 1
    assert_output_contains "$output" "EXAMPLES:" || return 1
    assert_output_contains "$output" "DOCUMENTATION:" || return 1
    
    test_pass
}

test_help_flag() {
    test_start "--help flag displays documentation"
    
    local output
    output=$("${MAIN_SCRIPT}" --help 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "${MAIN_SCRIPT} --help" || return 1
    assert_output_contains "$output" "Android Mirror" || return 1
    
    test_pass
}

test_version_command() {
    test_start "version command shows version"
    
    local output
    output=$("${MAIN_SCRIPT}" version 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "${MAIN_SCRIPT} version" || return 1
    assert_output_contains "$output" "Android Mirror v" || return 1
    
    test_pass
}

test_version_flag() {
    test_start "--version flag shows version"
    
    local output
    output=$("${MAIN_SCRIPT}" --version 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "${MAIN_SCRIPT} --version" || return 1
    assert_output_contains "$output" "Android Mirror v" || return 1
    
    test_pass
}

test_invalid_command() {
    test_start "Invalid command shows error"
    
    local output
    local exit_code
    output=$("${MAIN_SCRIPT}" invalid_command 2>&1) || exit_code=$?
    
    assert_exit_code 1 $exit_code "${MAIN_SCRIPT} invalid_command" || return 1
    assert_output_contains "$output" "Unknown command" || return 1
    
    test_pass
}

test_status_command() {
    test_start "status command runs without errors"
    
    local output
    output=$("${MAIN_SCRIPT}" status 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "${MAIN_SCRIPT} status" || return 1
    assert_output_contains "$output" "System Status" || return 1
    assert_output_contains "$output" "Dependencies:" || return 1
    assert_output_contains "$output" "Auto-Monitor:" || return 1
    assert_output_contains "$output" "Connected Devices:" || return 1
    
    test_pass
}

test_list_command() {
    test_start "list command runs without errors"
    
    # Check if adb is available
    if ! command -v adb &> /dev/null; then
        echo -e "  ${YELLOW}⊘${NC} SKIP: adb not installed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo ""
        return 0
    fi
    
    local output
    output=$("${MAIN_SCRIPT}" list 2>&1 || true)
    local exit_code=$?
    
    # Should succeed even if no devices found
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
        assert_output_contains "$output" "Scanning for Android devices" || return 1
        test_pass
    else
        test_fail "Unexpected exit code: ${exit_code}"
        return 1
    fi
}

test_devices_alias() {
    test_start "devices is alias for list"
    
    if ! command -v adb &> /dev/null; then
        echo -e "  ${YELLOW}⊘${NC} SKIP: adb not installed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo ""
        return 0
    fi
    
    local output
    output=$("${MAIN_SCRIPT}" devices 2>&1 || true)
    
    assert_output_contains "$output" "Scanning for Android devices" || return 1
    
    test_pass
}

test_logs_command() {
    test_start "logs command runs without errors"
    
    local output
    output=$("${MAIN_SCRIPT}" logs 2>&1)
    local exit_code=$?
    
    assert_exit_code 0 $exit_code "${MAIN_SCRIPT} logs" || return 1
    # Should show either logs or "No logs found"
    
    test_pass
}

test_source_scripts_exist() {
    test_start "All source scripts exist"
    
    local required_scripts=(
        "${PROJECT_ROOT}/src/android-mirror.sh"
        "${PROJECT_ROOT}/src/install-monitor.sh"
        "${PROJECT_ROOT}/src/uninstall-monitor.sh"
        "${PROJECT_ROOT}/src/usb-monitor.sh"
        "${PROJECT_ROOT}/lib/error-handler.sh"
    )
    
    local missing=()
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            missing+=("$script")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        test_fail "Missing scripts: ${missing[*]}"
        return 1
    fi
    
    test_pass
}

test_source_scripts_executable() {
    test_start "All source scripts are executable"
    
    local scripts=(
        "${PROJECT_ROOT}/src/android-mirror.sh"
        "${PROJECT_ROOT}/src/install-monitor.sh"
        "${PROJECT_ROOT}/src/uninstall-monitor.sh"
        "${PROJECT_ROOT}/src/usb-monitor.sh"
    )
    
    local not_executable=()
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            not_executable+=("$script")
        fi
    done
    
    if [[ ${#not_executable[@]} -gt 0 ]]; then
        test_fail "Not executable: ${not_executable[*]}"
        return 1
    fi
    
    test_pass
}

test_error_handler_syntax() {
    test_start "Error handler library has valid syntax"
    
    if ! bash -n "${PROJECT_ROOT}/lib/error-handler.sh" 2>&1; then
        test_fail "Syntax errors in error-handler.sh"
        return 1
    fi
    
    test_pass
}

test_main_script_syntax() {
    test_start "Main script has valid syntax"
    
    if ! bash -n "${PROJECT_ROOT}/roid-mirror" 2>&1; then
        test_fail "Syntax errors in roid-mirror"
        return 1
    fi
    
    test_pass
}

test_android_mirror_syntax() {
    test_start "Android mirror script has valid syntax"
    
    if ! bash -n "${PROJECT_ROOT}/src/android-mirror.sh" 2>&1; then
        test_fail "Syntax errors in android-mirror.sh"
        return 1
    fi
    
    test_pass
}

test_documentation_exists() {
    test_start "Documentation files exist"
    
    local docs=(
        "${PROJECT_ROOT}/README.md"
        "${PROJECT_ROOT}/docs/QUICKSTART.md"
        "${PROJECT_ROOT}/docs/AUTO-CONNECT.md"
    )
    
    local missing=()
    for doc in "${docs[@]}"; do
        if [[ ! -f "$doc" ]]; then
            missing+=("$doc")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        test_fail "Missing documentation: ${missing[*]}"
        return 1
    fi
    
    test_pass
}

test_directory_structure() {
    test_start "Required directories exist"
    
    local dirs=(
        "${PROJECT_ROOT}/src"
        "${PROJECT_ROOT}/lib"
        "${PROJECT_ROOT}/docs"
        "${PROJECT_ROOT}/test"
    )
    
    local missing=()
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing+=("$dir")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        test_fail "Missing directories: ${missing[*]}"
        return 1
    fi
    
    test_pass
}

################################################################################
# Test Suite Runner
################################################################################

run_all_tests() {
    echo -e "${BOLD}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   Android Mirror - Test Suite                     ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Structure tests
    echo -e "${BOLD}Project Structure Tests${NC}"
    echo "─────────────────────────────────────────────────────"
    test_directory_structure
    test_script_exists
    test_source_scripts_exist
    test_source_scripts_executable
    test_documentation_exists
    echo ""
    
    # Syntax tests
    echo -e "${BOLD}Syntax Validation Tests${NC}"
    echo "─────────────────────────────────────────────────────"
    test_main_script_syntax
    test_error_handler_syntax
    test_android_mirror_syntax
    echo ""
    
    # Command tests
    echo -e "${BOLD}Command Functionality Tests${NC}"
    echo "─────────────────────────────────────────────────────"
    test_no_args_shows_help
    test_help_command
    test_help_flag
    test_version_command
    test_version_flag
    test_invalid_command
    test_status_command
    test_list_command
    test_devices_alias
    test_logs_command
    echo ""
}

show_summary() {
    echo "═════════════════════════════════════════════════════"
    echo -e "${BOLD}Test Results${NC}"
    echo "─────────────────────────────────────────────────────"
    echo -e "Total Tests:  ${TESTS_RUN}"
    echo -e "${GREEN}Passed:       ${TESTS_PASSED}${NC}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed:       ${TESTS_FAILED}${NC}"
        echo ""
        echo -e "${RED}Failed Tests:${NC}"
        for failed in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} ${failed}"
        done
    fi
    
    echo "═════════════════════════════════════════════════════"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}✗ Some tests failed${NC}"
        return 1
    fi
}

################################################################################
# Main Entry Point
################################################################################

main() {
    cd "$PROJECT_ROOT"
    
    run_all_tests
    show_summary
    
    exit $?
}

main "$@"
