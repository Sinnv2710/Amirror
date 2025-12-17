#!/usr/bin/env bash

################################################################################
# Amirror - Android Screen Mirroring Script
# Description: Manages Android device screen mirroring with scrcpy
# Requirements: adb, scrcpy (install via: brew install scrcpy)
# Features: Comprehensive error handling, retry logic, timeouts, validation
################################################################################

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly LOG_FILE="${LOG_DIR}/amirror-$(date +%Y%m%d_%H%M%S).log"
readonly ERROR_LOG="${LOG_DIR}/error-$(date +%Y%m%d_%H%M%S).log"
readonly PID_FILE="${SCRIPT_DIR}/.scrcpy.pid"

# Create log directory
mkdir -p "${LOG_DIR}"

# Source error handling library
if [[ ! -f "${PROJECT_ROOT}/src/lib/error-handler.sh" ]]; then
    echo "Error: error-handler.sh library not found"
    exit 1
fi

source "${PROJECT_ROOT}/src/lib/error-handler.sh"

# Ensure critical paths are in PATH for homebrew installations
# This fixes issues when script is called from contexts with minimal PATH
# Include GNU coreutils bin directory for 'timeout' command
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

# Find the actual adb binary location for use in subcommands
# This ensures ADB works even when called through timeout/subshells
ADB_BIN=""
if command -v adb &>/dev/null; then
    ADB_BIN=$(command -v adb)
elif [[ -f "/opt/homebrew/bin/adb" ]]; then
    ADB_BIN="/opt/homebrew/bin/adb"
else
    ADB_BIN="adb"
fi
export ADB_BIN

# Initialize error handling
init_error_handling

################################################################################
# Cleanup Functions
################################################################################

cleanup() {
    log_info "Starting cleanup process"
    
    # Kill scrcpy process if running
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid=$(<"${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_info "Terminating scrcpy process (PID: ${pid})"
            kill "${pid}" 2>/dev/null || true
            sleep 1
            # Force kill if still running
            if kill -0 "${pid}" 2>/dev/null; then
                log_warn "Process still alive, forcing kill"
                kill -9 "${pid}" 2>/dev/null || true
            fi
        fi
        rm -f "${PID_FILE}"
    fi
    
    # Kill any remaining scrcpy processes
    if pkill -0 -f "scrcpy" 2>/dev/null; then
        log_info "Killing remaining scrcpy processes"
        pkill -f "scrcpy" 2>/dev/null || true
    fi
    
    log_info "Cleanup completed"
}

# Register cleanup function
register_cleanup cleanup

################################################################################
# Dependency Checks
################################################################################

check_dependencies() {
    log_info "Checking dependencies"
    
    local missing_deps=()
    
    # Check for adb
    if ! assert_command_exists adb ""; then
        missing_deps+=("adb (Android Debug Bridge)")
    fi
    
    # Check for scrcpy
    if ! assert_command_exists scrcpy ""; then
        missing_deps+=("scrcpy")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "   - ${dep}"
        done
        echo ""
        echo -e "${YELLOW}To install missing dependencies, run:${NC}"
        echo -e "   ${BLUE}brew install scrcpy${NC}"
        echo ""
        log_error "Missing dependencies: ${missing_deps[*]}"
        throw "${ERROR_CODES[MISSING_DEPENDENCIES]}" "Please install missing dependencies"
    fi
    
    log_info "All dependencies found"
    show_success "All dependencies found"
}

################################################################################
# Device Management
################################################################################

get_connected_devices() {
    log_info "Fetching connected devices"
    
    local output
    local exit_code
    local adb_cmd="${ADB_BIN:-adb}"
    
    # Execute adb devices with timeout and retry
    if ! output=$(execute_with_timeout 10 "ADB device scan" "$adb_cmd" devices -l); then
        exit_code=$?
        
        if [[ $exit_code -eq ${ERROR_CODES[TIMEOUT]} ]]; then
            show_error "${ERROR_CODES[TIMEOUT]}" \
                "ADB device scan timed out." \
                "1. Try unplugging and replugging your device\n2. Restart ADB server: $adb_cmd kill-server && $adb_cmd start-server\n3. Check USB cable connection"
            throw "${ERROR_CODES[TIMEOUT]}"
        fi
        
        # Try to restart ADB server and retry
        log_warn "ADB scan failed, attempting to restart ADB server"
        show_warning "Device scan failed, restarting ADB server..."
        
        if execute_safe "Kill ADB server" "$adb_cmd" kill-server && \
           execute_safe "Start ADB server" "$adb_cmd" start-server; then
            
            sleep 2
            if ! output=$(execute_with_timeout 10 "ADB device scan (retry)" "$adb_cmd" devices -l); then
                show_error "${ERROR_CODES[ADB_ERROR]}" \
                    "Failed to communicate with ADB after restart." \
                    "1. Ensure ADB is properly installed: brew install scrcpy\n2. Try unplugging all devices and restart\n3. Reboot your Mac if problem persists"
                throw "${ERROR_CODES[ADB_ERROR]}"
            fi
        else
            show_error "${ERROR_CODES[ADB_ERROR]}" \
                "Failed to restart ADB server." \
                "Try manually: adb kill-server && adb start-server"
            throw "${ERROR_CODES[ADB_ERROR]}"
        fi
    fi
    
    # Parse and validate devices
    local devices=()
    while IFS= read -r line; do
        # Match device lines (serial + "device" state)
        if [[ $line =~ ^([a-zA-Z0-9._:-]+)[[:space:]]+device ]]; then
            local serial="${BASH_REMATCH[1]}"
            if validate_serial "$serial"; then
                devices+=("$serial")
                log_debug "Found valid device: $serial"
            else
                log_warn "Invalid device serial format: $serial"
            fi
        fi
    done <<< "$output"
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_error "No devices found"
        show_error "${ERROR_CODES[NO_DEVICES]}" \
            "No Android devices detected." \
            "1. Ensure device is connected via USB\n2. Enable USB debugging on your device:\n   Settings → Developer Options → USB Debugging\n3. Accept the authorization prompt on your device\n4. Try a different USB cable or port\n5. Run 'adb devices' manually to verify"
        throw "${ERROR_CODES[NO_DEVICES]}"
    fi
    
    log_info "Found ${#devices[@]} device(s): ${devices[*]}"
    printf '%s\n' "${devices[@]}"
    return 0
}

get_device_info() {
    local serial=$1
    local property=$2
    local timeout=${3:-5}
    local adb_cmd="${ADB_BIN:-adb}"
    
    log_debug "Getting device property: $property for $serial"
    
    local output
    if output=$(execute_with_timeout "$timeout" \
        "Get device $property" \
        "$adb_cmd" -s "$serial" shell getprop "$property" 2>/dev/null); then
        # Remove carriage returns and newlines
        echo "${output//[$'\r\n']}"
        return 0
    else
        log_warn "Could not get $property for device $serial"
        echo "Unknown"
        return 1
    fi
}

display_device_menu() {
    local devices=("$@")
    local device_array=()
    local counter=1
    
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}    Connected Android Devices${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    for device_id in "${devices[@]}"; do
        # Get device model and version with timeout
        local model
        local android_version
        
        model=$(get_device_info "${device_id}" "ro.product.model" 3)
        android_version=$(get_device_info "${device_id}" "ro.build.version.release" 3)
        
        device_array+=("${device_id}")
        echo -e "  ${BLUE}[${counter}]${NC} ${device_id}"
        echo -e "      Model: ${model}"
        echo -e "      Android: ${android_version}\n"
        
        ((counter++))
    done
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Return device array as a newline-separated string
    printf "%s\n" "${device_array[@]}"
}

select_device() {
    local devices
    local device_array=()
    
    # Get connected devices (Bash 3.2 compatible)
    while IFS= read -r line; do
        device_array+=("$line")
    done < <(get_connected_devices)
    
    local device_count=${#device_array[@]}
    
    if [[ "${device_count}" -eq 1 ]]; then
        local device_id="${device_array[0]}"
        log_info "Only one device found, auto-selecting: ${device_id}"
        # Send display output to stderr, only device ID to stdout
        echo "" >&2
        echo -e "${GREEN}✓ Auto-selected device: ${device_id}${NC}" >&2
        echo "${device_id}"
        return 0
    fi
    
    # Multiple devices found, show menu
    local device_list
    device_list=$(display_device_menu "${device_array[@]}")
    
    local attempts=0
    local max_attempts=5
    
    while [[ $attempts -lt $max_attempts ]]; do
        read -rp "Select device number (1-${device_count}): " choice
        
        # Validate input
        if ! is_positive_integer "$choice"; then
            show_warning "Please enter a valid number between 1 and ${device_count}"
            ((attempts++))
            continue
        fi
        
        if [[ "${choice}" -ge 1 ]] && [[ "${choice}" -le "${device_count}" ]]; then
            local selected_device
            selected_device=$(echo "${device_list}" | sed -n "${choice}p")
            
            if ! assert_not_empty "selected_device" "$selected_device"; then
                log_error "Failed to get selected device"
                show_error "${ERROR_CODES[GENERAL_ERROR]}" "Failed to select device. Please try again."
                ((attempts++))
                continue
            fi
            
            log_info "User selected device: ${selected_device}"
            echo "${selected_device}"
            return 0
        else
            show_warning "Invalid selection. Please enter a number between 1 and ${device_count}"
            ((attempts++))
        fi
    done
    
    log_error "Too many invalid selection attempts"
    show_error "${ERROR_CODES[INVALID_INPUT]}" \
        "Too many invalid attempts." \
        "Please restart the script and select a valid device number."
    throw "${ERROR_CODES[INVALID_INPUT]}"
}

################################################################################
# Device Connection Verification
################################################################################

verify_device_connection() {
    local device_id="$1"
    
    log_info "Verifying device connection: ${device_id}"
    
    # Validate device serial format
    if ! validate_serial "$device_id"; then
        log_error "Invalid device serial format: $device_id"
        show_error "${ERROR_CODES[INVALID_INPUT]}" \
            "Invalid device serial: $device_id"
        throw "${ERROR_CODES[INVALID_INPUT]}"
    fi
    
    # Check device state with retry
    local state
    local adb_cmd="${ADB_BIN:-adb}"
    if ! state=$(retry_with_backoff 3 1 "Get device state" \
        "$adb_cmd" -s "$device_id" get-state 2>/dev/null); then
        
        log_error "Failed to get device state for $device_id after retries"
        show_error "${ERROR_CODES[DEVICE_DISCONNECTED]}" \
            "Cannot connect to device: $device_id" \
            "1. Check USB cable connection\n2. Device may have disconnected\n3. USB debugging may have been disabled\n4. Try reconnecting the device"
        throw "${ERROR_CODES[DEVICE_DISCONNECTED]}"
    fi
    
    # Remove any whitespace/newlines
    state=$(trim "$state")
    
    if [[ "$state" != "device" ]]; then
        log_error "Device $device_id is not in 'device' state: $state"
        show_error "${ERROR_CODES[DEVICE_DISCONNECTED]}" \
            "Device is not ready (state: $state)" \
            "1. Ensure USB debugging is authorized on device\n2. Check device connection\n3. Try reconnecting the device"
        throw "${ERROR_CODES[DEVICE_DISCONNECTED]}"
    fi
    
    # Additional connectivity test with timeout
    if ! execute_with_timeout 5 "Device shell test" \
        "$adb_cmd" -s "$device_id" shell echo "connection_test" &>/dev/null; then
        
        log_error "Device shell test failed for $device_id"
        show_error "${ERROR_CODES[DEVICE_DISCONNECTED]}" \
            "Device connection test failed." \
            "The device may be unresponsive or disconnected."
        throw "${ERROR_CODES[DEVICE_DISCONNECTED]}"
    fi
    
    log_info "Device connection verified successfully: $device_id"
    return 0
}

################################################################################
# Progress Indicator
################################################################################

show_loading() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    
    while kill -0 "${pid}" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            if ! kill -0 "${pid}" 2>/dev/null; then
                break 2
            fi
            echo -ne "\r${BLUE}${frame}${NC} ${message}..."
            sleep "${delay}"
        done
    done
    
    echo -ne "\r"
}

################################################################################
# Scrcpy Management
################################################################################

start_scrcpy() {
    local device_id="$1"
    
    log_info "Starting scrcpy for device: ${device_id}"
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}    Starting Screen Mirror${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Verify device connection in background for progress indicator
    (verify_device_connection "${device_id}") &
    local verify_pid=$!
    show_loading ${verify_pid} "Connecting to device"
    
    if ! wait ${verify_pid}; then
        # Error already shown by verify_device_connection
        log_error "Device verification failed"
        throw "${ERROR_CODES[DEVICE_DISCONNECTED]}"
    fi
    
    show_success "Device connected successfully"
    echo ""
    
    # Start scrcpy with specified parameters
    log_info "Launching scrcpy with parameters: --prefer-text --turn-screen-off --stay-awake"
    echo -e "${BLUE}Starting mirror session...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop mirroring${NC}\n"
    
    # Prepare scrcpy command
    local scrcpy_cmd=(
        scrcpy
        --serial="${device_id}"
        --prefer-text
        --turn-screen-off
        --stay-awake
    )
    
    log_debug "scrcpy command: ${scrcpy_cmd[*]}"
    
    # Run scrcpy and capture output
    local scrcpy_output_file="${LOG_DIR}/scrcpy-output-$(date +%Y%m%d_%H%M%S).log"
    
    try
        "${scrcpy_cmd[@]}" >> "${scrcpy_output_file}" 2>&1 &
        local scrcpy_pid=$!
        local scrcpy_exit_code
    catch || {
        scrcpy_exit_code=$?
        log_error "Failed to launch scrcpy (exit code: $scrcpy_exit_code)"
        show_error "${ERROR_CODES[SCRCPY_FAILED]}" \
            "Failed to start scrcpy." \
            "1. Check log file: ${scrcpy_output_file}\n2. Ensure device is unlocked\n3. Try restarting ADB server\n4. Close any other screen mirroring apps"
        throw "${ERROR_CODES[SCRCPY_FAILED]}"
    }
    
    echo "${scrcpy_pid}" > "${PID_FILE}"
    log_info "scrcpy started with PID: ${scrcpy_pid}"
    
    # Wait a moment and check if scrcpy started successfully
    sleep 2
    
    if ! kill -0 "${scrcpy_pid}" 2>/dev/null; then
        rm -f "${PID_FILE}"
        log_error "scrcpy process died immediately after start"
        
        # Read last few lines of output for error details
        local error_details=""
        if [[ -f "${scrcpy_output_file}" ]]; then
            error_details=$(tail -n 5 "${scrcpy_output_file}" 2>/dev/null || echo "")
        fi
        
        log_error "scrcpy output: $error_details"
        
        show_error "${ERROR_CODES[SCRCPY_FAILED]}" \
            "Screen mirroring failed to start." \
            "Check log file: ${scrcpy_output_file}\n\nPossible causes:\n1. Device screen may be locked\n2. Another mirroring app may be running\n3. Device disconnected during startup\n4. scrcpy version incompatibility"
        throw "${ERROR_CODES[SCRCPY_FAILED]}"
    fi
    
    show_success "Screen mirroring active"
    log_info "Screen mirroring session started successfully"
    
    # Wait for scrcpy process to finish
    try
        wait "${scrcpy_pid}"
        scrcpy_exit_code=$?
    catch || {
        scrcpy_exit_code=$?
    }
    
    rm -f "${PID_FILE}"
    log_info "scrcpy process ended with exit code: ${scrcpy_exit_code}"
    
    # Handle exit codes
    case $scrcpy_exit_code in
        0)
            echo -e "\n${GREEN}✓ Screen mirroring stopped normally${NC}"
            ;;
        130)
            echo -e "\n${YELLOW}Screen mirroring stopped by user (Ctrl+C)${NC}"
            ;;
        *)
            echo -e "\n${YELLOW}Screen mirroring stopped (exit code: ${scrcpy_exit_code})${NC}"
            log_warn "Unexpected scrcpy exit code: ${scrcpy_exit_code}"
            ;;
    esac
}

################################################################################
# Main Function
################################################################################

main() {
    log_info "=========================================="
    log_info "Android Mirror Script Started (Enhanced Version)"
    log_info "Arguments: $*"
    log_info "=========================================="
    
    # Clear screen for better UX
    clear
    
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║   Android Screen Mirror - Enhanced v2.0.0         ║"
    echo "║   With Advanced Error Handling & Retry Logic      ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${RESET}\n"
    
    # Check dependencies
    echo -e "${BLUE}Checking dependencies...${NC}"
    check_dependencies
    echo ""
    
    # Select device
    echo -e "${BLUE}Scanning for connected devices...${NC}"
    local device_id
    device_id=$(select_device)
    
    if ! assert_not_empty "device_id" "$device_id"; then
        log_error "Device selection failed - empty device ID"
        show_error "${ERROR_CODES[GENERAL_ERROR]}" "Failed to select device"
        throw "${ERROR_CODES[GENERAL_ERROR]}"
    fi
    
    echo -e "\n${GREEN}✓${NC} Device selected: ${BOLD}${device_id}${RESET}\n"
    log_info "Selected device: $device_id"
    
    # Start scrcpy
    start_scrcpy "${device_id}"
    
    # Normal exit
    log_info "Script completed successfully"
    echo -e "\n${GREEN}✓${NC} Goodbye!\n"
    
    exit 0
}

################################################################################
# Script Entry Point
################################################################################

# Run main function with error handling
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    try
        main "$@"
    catch || {
        local exit_code=$?
        
        # If it's user cancellation, exit quietly
        if [[ $exit_code -eq 130 ]] || [[ $exit_code -eq ${ERROR_CODES[USER_CANCELLED]} ]]; then
            log_info "User cancelled operation"
            exit 0
        fi
        
        # Otherwise, show error summary
        log_fatal "Script failed with exit code: $exit_code"
        
        if [[ -n "${ERROR_LOG:-}" ]] && [[ -f "${ERROR_LOG}" ]]; then
            echo -e "${RED}For detailed error information, check:${NC}"
            echo -e "${CYAN}${ERROR_LOG}${NC}\n"
        fi
        
        exit "$exit_code"
    }
fi
