#!/usr/bin/env bash

################################################################################
# Error Handling Library for Bash Scripts (Bash 3.2+ compatible)
# Provides comprehensive error handling, logging, and retry mechanisms
################################################################################

# Disable strict mode temporarily for compatibility setup
set +u

# Color codes (define early for all shells)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'
readonly NC='\033[0m' # No Color (alias)

# Check bash version and use appropriate syntax
if [ -n "${BASH_VERSION:-}" ]; then
    # Bash - check version
    if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
        # Bash 4.0+, use associative arrays
        declare -A ERROR_CODES=(
            [SUCCESS]=0
            [GENERAL_ERROR]=1
            [MISSING_DEPENDENCIES]=10
            [NO_DEVICES]=11
            [DEVICE_DISCONNECTED]=12
            [SCRCPY_FAILED]=13
            [ADB_ERROR]=14
            [USER_CANCELLED]=15
            [PERMISSION_DENIED]=16
            [TIMEOUT]=17
            [INVALID_INPUT]=18
            [UNKNOWN]=99
        )

        declare -A ERROR_MESSAGES=(
            [10]="Required dependencies are missing"
            [11]="No Android devices found"
            [12]="Device connection lost"
            [13]="Screen mirroring failed to start"
            [14]="ADB communication error"
            [15]="Operation cancelled by user"
            [16]="Permission denied"
            [17]="Operation timed out"
            [18]="Invalid input provided"
            [99]="An unexpected error occurred"
        )

        declare -A LOG_LEVELS=(
            [DEBUG]=0
            [INFO]=1
            [WARN]=2
            [ERROR]=3
            [FATAL]=4
        )
    else
        # Bash 3.x - use functions to simulate associative arrays
        ERROR_CODE_SUCCESS=0
        ERROR_CODE_GENERAL_ERROR=1
        ERROR_CODE_MISSING_DEPENDENCIES=10
        ERROR_CODE_NO_DEVICES=11
        ERROR_CODE_DEVICE_DISCONNECTED=12
        ERROR_CODE_SCRCPY_FAILED=13
        ERROR_CODE_ADB_ERROR=14
        ERROR_CODE_USER_CANCELLED=15
        ERROR_CODE_PERMISSION_DENIED=16
        ERROR_CODE_TIMEOUT=17
        ERROR_CODE_INVALID_INPUT=18
        ERROR_CODE_UNKNOWN=99
        
        # Helper function to get error codes
        get_error_code() {
            case "$1" in
                SUCCESS) echo 0 ;;
                GENERAL_ERROR) echo 1 ;;
                MISSING_DEPENDENCIES) echo 10 ;;
                NO_DEVICES) echo 11 ;;
                DEVICE_DISCONNECTED) echo 12 ;;
                SCRCPY_FAILED) echo 13 ;;
                ADB_ERROR) echo 14 ;;
                USER_CANCELLED) echo 15 ;;
                PERMISSION_DENIED) echo 16 ;;
                TIMEOUT) echo 17 ;;
                INVALID_INPUT) echo 18 ;;
                UNKNOWN) echo 99 ;;
                *) echo 99 ;;
            esac
        }
        
        # Helper function to get error messages
        get_error_message() {
            case "$1" in
                10) echo "Required dependencies are missing" ;;
                11) echo "No Android devices found" ;;
                12) echo "Device connection lost" ;;
                13) echo "Screen mirroring failed to start" ;;
                14) echo "ADB communication error" ;;
                15) echo "Operation cancelled by user" ;;
                16) echo "Permission denied" ;;
                17) echo "Operation timed out" ;;
                18) echo "Invalid input provided" ;;
                99) echo "An unexpected error occurred" ;;
                *) echo "Unknown error" ;;
            esac
        }
        
        # Helper function for log levels
        get_log_level() {
            case "$1" in
                DEBUG) echo 0 ;;
                INFO) echo 1 ;;
                WARN) echo 2 ;;
                ERROR) echo 3 ;;
                FATAL) echo 4 ;;
                *) echo 1 ;;
            esac
        }
        
        # Create associative array compatibility
        declare -A ERROR_CODES 2>/dev/null || true
        declare -A ERROR_MESSAGES 2>/dev/null || true
        declare -A LOG_LEVELS 2>/dev/null || true
    fi
elif [ -n "${ZSH_VERSION:-}" ]; then
    # zsh - supports associative arrays natively
    typeset -A ERROR_CODES=(
        SUCCESS 0
        GENERAL_ERROR 1
        MISSING_DEPENDENCIES 10
        NO_DEVICES 11
        DEVICE_DISCONNECTED 12
        SCRCPY_FAILED 13
        ADB_ERROR 14
        USER_CANCELLED 15
        PERMISSION_DENIED 16
        TIMEOUT 17
        INVALID_INPUT 18
        UNKNOWN 99
    )

    typeset -A ERROR_MESSAGES=(
        10 "Required dependencies are missing"
        11 "No Android devices found"
        12 "Device connection lost"
        13 "Screen mirroring failed to start"
        14 "ADB communication error"
        15 "Operation cancelled by user"
        16 "Permission denied"
        17 "Operation timed out"
        18 "Invalid input provided"
        99 "An unexpected error occurred"
    )

    typeset -A LOG_LEVELS=(
        DEBUG 0
        INFO 1
        WARN 2
        ERROR 3
        FATAL 4
    )
fi

# Default log level
if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    CURRENT_LOG_LEVEL=$(get_log_level INFO)
else
    CURRENT_LOG_LEVEL=${LOG_LEVELS[INFO]}
fi

#==========================================
# COMPATIBILITY LAYER
#==========================================

# Now re-enable strict mode for the library
# Note: We avoid 'set -u' to maintain Bash 3.2 compatibility

#==========================================
# GLOBAL VARIABLES
#==========================================

ERROR_COUNT=0
WARNING_COUNT=0
CLEANUP_FUNCTIONS=()

#==========================================
# INITIALIZATION
#==========================================

init_error_handling() {
    # Enable strict error handling (except -u for Bash 3.2 compatibility)
    set -eo pipefail
    
    # Set up traps
    trap '_error_handler ${LINENO} "${BASH_COMMAND}" $?' ERR
    trap '_exit_handler' EXIT
    trap '_interrupt_handler' INT TERM
    
    # Initialize counters
    ERROR_COUNT=0
    WARNING_COUNT=0
}

#==========================================
# LOGGING FUNCTIONS
#==========================================

log_debug() {
    _log "DEBUG" "$@"
}

log_info() {
    _log "INFO" "$@"
}

log_warn() {
    _log "WARN" "$@"
    ((WARNING_COUNT++))
}

log_error() {
    _log "ERROR" "$@"
    ((ERROR_COUNT++))
}

log_fatal() {
    _log "FATAL" "$@"
    ((ERROR_COUNT++))
}

_log() {
    local level=$1
    shift
    local message="$*"
    local level_num
    
    # Check if we should log this level
    if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        level_num=$(get_log_level "$level")
    else
        level_num=${LOG_LEVELS[$level]:-1}
    fi
    
    if [[ $level_num -lt $CURRENT_LOG_LEVEL ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller_info=""
    
    # Get caller information (skip the _log function itself)
    if [[ ${#BASH_SOURCE[@]} -gt 2 ]]; then
        local caller_file="${BASH_SOURCE[2]##*/}"
        local caller_line="${BASH_LINENO[1]}"
        caller_info="[$caller_file:$caller_line]"
    fi
    
    local log_entry="[$timestamp] [$level] $caller_info $message"
    
    # Write to log file if defined
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "$log_entry" >> "$LOG_FILE"
    fi
    
    # Also write errors to error log if defined
    local error_level
    if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        error_level=$(get_log_level ERROR)
    else
        error_level=${LOG_LEVELS[ERROR]:-3}
    fi
    
    if [[ $level_num -ge $error_level ]] && [[ -n "${ERROR_LOG:-}" ]]; then
        echo "$log_entry" >> "$ERROR_LOG"
    fi
}

#==========================================
# ERROR HANDLERS
#==========================================

_error_handler() {
    local line_number=$1
    local command=$2
    local exit_code=$3
    
    log_fatal "Error at line $line_number: '$command' (exit code: $exit_code)"
    
    # Print stack trace
    _print_stack_trace
}

_exit_handler() {
    local exit_code=$?
    
    # Run cleanup functions
    for cleanup_func in "${CLEANUP_FUNCTIONS[@]}"; do
        if declare -f "$cleanup_func" > /dev/null; then
            log_debug "Running cleanup function: $cleanup_func"
            $cleanup_func || log_warn "Cleanup function failed: $cleanup_func"
        fi
    done
    
    if [[ $exit_code -ne 0 ]] && [[ $exit_code -ne 130 ]]; then
        log_error "Script exited with code: $exit_code (Errors: $ERROR_COUNT, Warnings: $WARNING_COUNT)"
    else
        log_info "Script completed (Errors: $ERROR_COUNT, Warnings: $WARNING_COUNT)"
    fi
}

_interrupt_handler() {
    echo ""
    log_warn "Script interrupted by user (SIGINT/SIGTERM)"
    exit 130
}

_print_stack_trace() {
    local frame=0
    log_error "Stack trace:"
    
    while [[ $frame -lt ${#FUNCNAME[@]} ]]; do
        local func="${FUNCNAME[$frame]}"
        local file="${BASH_SOURCE[$frame]}"
        local line="${BASH_LINENO[$((frame - 1))]}"
        
        if [[ "$func" != "_error_handler" ]] && [[ "$func" != "_print_stack_trace" ]]; then
            log_error "  $frame: $func() at ${file##*/}:$line"
        fi
        
        ((frame++))
    done
}

#==========================================
# CLEANUP MANAGEMENT
#==========================================

register_cleanup() {
    local cleanup_function=$1
    CLEANUP_FUNCTIONS+=("$cleanup_function")
    log_debug "Registered cleanup function: $cleanup_function"
}

#==========================================
# ERROR DISPLAY
#==========================================

show_error() {
    local error_code=$1
    local message=$2
    local suggestions=${3:-}
    
    echo ""
    echo -e "${RED}${BOLD}✗ Error (Code: $error_code)${RESET}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${RED}$message${RESET}"
    
    if [[ -n "$suggestions" ]]; then
        echo ""
        echo -e "${YELLOW}${BOLD}Suggestions:${RESET}"
        echo -e "${YELLOW}$suggestions${RESET}"
    fi
    
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo ""
        echo -e "${CYAN}Log file: $LOG_FILE${RESET}"
    fi
    
    if [[ -n "${ERROR_LOG:-}" ]]; then
        echo -e "${CYAN}Error log: $ERROR_LOG${RESET}"
    fi
    
    echo ""
}

show_warning() {
    local message=$1
    echo -e "${YELLOW}⚠  Warning: $message${RESET}"
    log_warn "$message"
}

show_success() {
    local message=$1
    echo -e "${GREEN}✓ $message${RESET}"
    log_info "$message"
}

#==========================================
# TRY-CATCH MECHANISM
#==========================================

try() {
    [[ $- = *e* ]]; SAVED_OPT_E=$?
    set +e
}

catch() {
    export exception_code=$?
    (( SAVED_OPT_E )) && set +e
    return $exception_code
}

throw() {
    local error_code=${1:-1}
    local error_message=${2:-}
    
    if [[ -n "$error_message" ]]; then
        log_error "$error_message"
    fi
    
    exit "$error_code"
}

#==========================================
# SAFE EXECUTION WRAPPERS
#==========================================

execute_safe() {
    local description="$1"
    shift
    local command=("$@")
    
    log_info "Executing: $description"
    log_debug "Command: ${command[*]}"
    
    local output
    local exit_code
    
    if output=$("${command[@]}" 2>&1); then
        exit_code=$?
        log_info "Success: $description"
        echo "$output"
        return 0
    else
        exit_code=$?
        log_error "Failed: $description (exit code: $exit_code)"
        log_debug "Output: $output"
        return $exit_code
    fi
}

execute_with_timeout() {
    local timeout_seconds=$1
    local description=$2
    shift 2
    local command=("$@")
    
    log_info "Executing with ${timeout_seconds}s timeout: $description"
    
    local output
    local exit_code
    
    if output=$(timeout "$timeout_seconds" "${command[@]}" 2>&1); then
        exit_code=$?
        log_info "Completed: $description"
        echo "$output"
        return 0
    else
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Timeout after ${timeout_seconds}s: $description"
            return "${ERROR_CODES[TIMEOUT]}"
        else
            log_error "Failed: $description (exit code: $exit_code)"
            log_debug "Output: $output"
            return $exit_code
        fi
    fi
}

retry_with_backoff() {
    local max_attempts=$1
    local initial_delay=$2
    local description=$3
    shift 3
    local command=("$@")
    
    local attempt=1
    local delay=$initial_delay
    local exit_code
    
    log_info "Starting retry loop for: $description (max attempts: $max_attempts)"
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: $description"
        
        if "${command[@]}"; then
            log_info "Success on attempt $attempt: $description"
            return 0
        fi
        
        exit_code=$?
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Attempt $attempt failed (code: $exit_code), retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        ((attempt++))
    done
    
    log_error "All $max_attempts attempts failed: $description"
    return $exit_code
}

#==========================================
# VALIDATION FUNCTIONS
#==========================================

assert_not_empty() {
    local var_name=$1
    local var_value=$2
    local error_message=${3:-"Variable '$var_name' is empty"}
    
    if [[ -z "$var_value" ]]; then
        log_error "Assertion failed: $error_message"
        return 1
    fi
    
    return 0
}

assert_file_exists() {
    local file=$1
    local error_message=${2:-"File does not exist: $file"}
    
    if [[ ! -f "$file" ]]; then
        log_error "Assertion failed: $error_message"
        return 1
    fi
    
    return 0
}

assert_dir_exists() {
    local dir=$1
    local error_message=${2:-"Directory does not exist: $dir"}
    
    if [[ ! -d "$dir" ]]; then
        log_error "Assertion failed: $error_message"
        return 1
    fi
    
    return 0
}

assert_command_exists() {
    local command=$1
    local error_message=${2:-"Command not found: $command"}
    
    if ! command -v "$command" &> /dev/null; then
        log_error "Assertion failed: $error_message"
        return 1
    fi
    
    return 0
}

validate_serial() {
    local serial=$1
    
    if [[ -z "$serial" ]]; then
        log_error "Empty device serial"
        return 1
    fi
    
    # Check if serial looks valid (alphanumeric, dots, colons, hyphens, underscores)
    if [[ ! "$serial" =~ ^[a-zA-Z0-9._:-]+$ ]]; then
        log_warn "Suspicious device serial format: $serial"
        return 1
    fi
    
    return 0
}

#==========================================
# COMMAND EXISTENCE CHECK
#==========================================

require_command() {
    local cmd=$1
    local package=${2:-$cmd}
    local install_hint=${3:-"brew install $package"}
    
    log_debug "Checking for command: $cmd"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        show_error "${ERROR_CODES[MISSING_DEPENDENCIES]}" \
            "Missing dependency: $cmd" \
            "Install with: $install_hint"
        throw "${ERROR_CODES[MISSING_DEPENDENCIES]}"
    fi
    
    log_debug "Command found: $cmd ($(command -v "$cmd"))"
}

#==========================================
# UTILITY FUNCTIONS
#==========================================

is_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

is_positive_integer() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

trim() {
    local var="$*"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

#==========================================
# EXPORT FUNCTIONS
#==========================================

# Export all functions to be available to scripts that source this library
export -f init_error_handling
export -f log_debug log_info log_warn log_error log_fatal
export -f show_error show_warning show_success
export -f try catch throw
export -f execute_safe execute_with_timeout retry_with_backoff
export -f assert_not_empty assert_file_exists assert_dir_exists assert_command_exists
export -f validate_serial require_command
export -f is_integer is_positive_integer trim
export -f register_cleanup
