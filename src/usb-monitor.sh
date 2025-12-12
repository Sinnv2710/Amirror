#!/usr/bin/env bash

################################################################################
# USB Android Device Monitor - Enhanced Version
# Description: Monitors for Android device connections and prompts user
# Features: Comprehensive error handling, validation, retry logic
################################################################################

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly MAIN_SCRIPT="${SCRIPT_DIR}/android-mirror.sh"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly MONITOR_LOG="${LOG_DIR}/usb-monitor-$(date +%Y%m%d_%H%M%S).log"
readonly ERROR_LOG="${LOG_DIR}/usb-monitor-error-$(date +%Y%m%d_%H%M%S).log"
readonly STATE_FILE="${SCRIPT_DIR}/.last_devices"

# Create log directory
mkdir -p "${LOG_DIR}"

# Source error handling library
if [[ -f "${PROJECT_ROOT}/lib/error-handler.sh" ]]; then
    source "${PROJECT_ROOT}/lib/error-handler.sh"
    init_error_handling
else
    echo "Warning: error-handler.sh not found, using basic logging"
fi

log_monitor() {
    local level=${1:-INFO}
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [$level] ${message}" >> "${MONITOR_LOG}"
    
    # Also use library logging if available
    if declare -f log_info &>/dev/null; then
        case $level in
            INFO) log_info "$message" ;;
            WARN) log_warn "$message" ;;
            ERROR) log_error "$message" ;;
            DEBUG) log_debug "$message" ;;
        esac
    fi
}

get_device_list() {
    log_monitor DEBUG "Fetching device list"
    
    local output
    local exit_code
    
    # Try to get devices with timeout
    if declare -f execute_with_timeout &>/dev/null; then
        output=$(execute_with_timeout 10 "ADB device list" adb devices 2>&1) || exit_code=$?
    else
        output=$(timeout 10 adb devices 2>&1) || exit_code=$?
    fi
    
    if [[ $exit_code -ne 0 ]] && [[ -n "${exit_code:-}" ]]; then
        log_monitor ERROR "Failed to get device list (exit code: $exit_code)"
        
        # Try to restart ADB
        log_monitor WARN "Attempting to restart ADB server"
        adb kill-server 2>/dev/null || true
        sleep 1
        adb start-server 2>/dev/null || true
        sleep 1
        
        # Retry
        output=$(timeout 10 adb devices 2>&1) || {
            log_monitor ERROR "Failed to get devices after ADB restart"
            echo ""
            return 1
        }
    fi
    
    # Parse and validate devices
    local devices=""
    while IFS= read -r line; do
        if [[ $line =~ ^([a-zA-Z0-9._:-]+)[[:space:]]+device$ ]]; then
            local serial="${BASH_REMATCH[1]}"
            
            # Validate serial format
            if [[ "$serial" =~ ^[a-zA-Z0-9._:-]+$ ]]; then
                devices="${devices}${serial}"$'\n'
                log_monitor DEBUG "Found valid device: $serial"
            else
                log_monitor WARN "Invalid device serial format: $serial"
            fi
        fi
    done <<< "$output"
    
    # Remove trailing newline and sort
    devices=$(echo "$devices" | grep -v "^$" | sort)
    echo "$devices"
    return 0
}

check_for_new_devices() {
    log_monitor INFO "Checking for device changes"
    
    local current_devices
    local previous_devices=""
    
    # Get current device list
    if ! current_devices=$(get_device_list); then
        log_monitor ERROR "Failed to get current device list"
        return 1
    fi
    
    # Read previous device list
    if [[ -f "${STATE_FILE}" ]]; then
        previous_devices=$(<"${STATE_FILE}")
    fi
    
    log_monitor DEBUG "Current devices: ${current_devices:-none}"
    log_monitor DEBUG "Previous devices: ${previous_devices:-none}"
    
    # Compare device lists
    if [[ "${current_devices}" != "${previous_devices}" ]] && [[ -n "${current_devices}" ]]; then
        # New device(s) detected
        local new_devices
        new_devices=$(comm -13 <(echo "${previous_devices}") <(echo "${current_devices}"))
        
        if [[ -n "${new_devices}" ]]; then
            log_monitor INFO "New Android device(s) detected: ${new_devices}"
            
            # Update state file before prompting (to avoid duplicate prompts)
            echo "${current_devices}" > "${STATE_FILE}"
            
            # Prompt user for each new device
            while IFS= read -r device; do
                if [[ -n "$device" ]]; then
                    prompt_user "${device}"
                fi
            done <<< "${new_devices}"
        fi
    elif [[ -z "${current_devices}" ]] && [[ -n "${previous_devices}" ]]; then
        # All devices disconnected
        log_monitor INFO "All Android devices disconnected"
        echo "" > "${STATE_FILE}"
    else
        log_monitor DEBUG "No device changes detected"
    fi
    
    # Always update state
    echo "${current_devices}" > "${STATE_FILE}"
}

prompt_user() {
    local device_serial="$1"
    
    log_monitor INFO "Prompting user for device: $device_serial"
    
    # Validate device serial
    if [[ -z "$device_serial" ]]; then
        log_monitor ERROR "Empty device serial provided to prompt_user"
        return 1
    fi
    
    # Get device info for better dialog
    local device_info="Serial: $device_serial"
    local model
    
    if model=$(timeout 3 adb -s "$device_serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r'); then
        if [[ -n "$model" ]]; then
            device_info="Model: $model\nSerial: $device_serial"
            log_monitor DEBUG "Device info: $model"
        fi
    fi
    
    # Use osascript to show a native macOS dialog with retry
    local response
    local attempt=1
    local max_attempts=3
    
    while [[ $attempt -le $max_attempts ]]; do
        if response=$(osascript 2>&1 <<EOF
tell application "System Events"
    activate
    set response to display dialog "Android device detected!\n\n${device_info}\n\nWould you like to start screen mirroring?" buttons {"No", "Yes"} default button "Yes" with icon note with title "Android Mirror"
    return button returned of response
end tell
EOF
        ); then
            break
        else
            log_monitor WARN "Failed to show dialog (attempt $attempt/$max_attempts)"
            ((attempt++))
            sleep 1
        fi
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_monitor ERROR "Failed to show dialog after $max_attempts attempts"
        return 1
    fi
    
    log_monitor DEBUG "User response: $response"
    
    if [[ "${response}" == "Yes" ]]; then
        log_monitor INFO "User accepted - launching mirror script"
        
        # Validate main script exists
        if [[ ! -f "${MAIN_SCRIPT}" ]]; then
            log_monitor ERROR "Main script not found: ${MAIN_SCRIPT}"
            osascript -e 'display dialog "Error: Mirror script not found!" buttons {"OK"} default button "OK" with icon stop'
            return 1
        fi
        
        # Open Terminal and run the script with error handling
        if ! osascript 2>&1 <<EOF
tell application "Terminal"
    activate
    do script "cd '${SCRIPT_DIR}' && '${MAIN_SCRIPT}'; exit"
end tell
EOF
        then
            log_monitor ERROR "Failed to launch Terminal"
            return 1
        fi
        
        log_monitor INFO "Successfully launched mirror script in Terminal"
    else
        log_monitor INFO "User declined connection for device: $device_serial"
    fi
    
    return 0
}

cleanup_monitor() {
    log_monitor INFO "Monitor cleanup"
}

# Register cleanup if available
if declare -f register_cleanup &>/dev/null; then
    register_cleanup cleanup_monitor
fi

# Main monitoring logic
main_monitor() {
    log_monitor INFO "=========================================="
    log_monitor INFO "USB Monitor Check Started"
    log_monitor INFO "=========================================="
    
    # Check if adb is available
    if ! command -v adb &>/dev/null; then
        log_monitor ERROR "ADB not found in PATH"
        return 1
    fi
    
    log_monitor INFO "ADB found: $(command -v adb)"
    
    # Check for new devices
    if ! check_for_new_devices; then
        log_monitor ERROR "Device check failed"
        return 1
    fi
    
    log_monitor INFO "USB Monitor Check Completed"
    return 0
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if declare -f try &>/dev/null; then
        try
            main_monitor
        catch || {
            local exit_code=$?
            log_monitor ERROR "Monitor failed with exit code: $exit_code"
            exit "$exit_code"
        }
    else
        main_monitor
    fi
fi
