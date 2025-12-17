#!/usr/bin/env bash

################################################################################
# Amirror Doctor - System Diagnostic & Setup Tool
# Description: Checks and helps install all dependencies needed for Amirror
# Usage: ./doctor [--fix] [--install-all]
################################################################################

set -o pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Checkmark and cross symbols
readonly CHECK="✓"
readonly CROSS="✗"
readonly WARN="⚠"

# Configuration
AUTO_FIX=false
INSTALL_ALL=false
ISSUES_FOUND=0
WARNINGS_FOUND=0

################################################################################
# Utility Functions
################################################################################

show_header() {
    echo -e "\n${CYAN}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║   Amirror System Doctor v${VERSION}       ║${NC}"
    echo -e "${CYAN}${BOLD}║   Dependency Checker & Setup Helper     ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════╝${NC}\n"
}

show_help() {
    cat << 'EOF'
USAGE:
    ./doctor [OPTIONS]

OPTIONS:
    --help              Show this help message
    --version           Show version
    --fix               Automatically install missing dependencies
    --install-all       Install/update all dependencies (requires Homebrew)
    --verbose           Show detailed output

EXAMPLES:
    ./doctor                    # Check system readiness
    ./doctor --fix              # Install missing dependencies
    ./doctor --install-all      # Install/update all dependencies

The doctor will check for:
    ✓ Homebrew installation
    ✓ Required tools (adb, scrcpy, timeout)
    ✓ System configuration
    ✓ File permissions
    ✓ Log directory setup

EOF
}

log_pass() {
    echo -e "${GREEN}${CHECK}${NC} $*"
}

log_fail() {
    echo -e "${RED}${CROSS}${NC} $*"
    ((ISSUES_FOUND++))
}

log_warn() {
    echo -e "${YELLOW}${WARN}${NC} $*"
    ((WARNINGS_FOUND++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_section() {
    echo -e "\n${BOLD}${CYAN}━━ $* ━━${NC}"
}

################################################################################
# Dependency Checks
################################################################################

check_homebrew() {
    log_section "Homebrew"
    
    if command -v brew &>/dev/null; then
        local brew_version
        brew_version=$(brew --version | head -1)
        log_pass "Homebrew installed: $brew_version"
        return 0
    else
        log_fail "Homebrew not found"
        log_info "Install Homebrew from: https://brew.sh"
        log_info "Or run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        return 1
    fi
}

check_scrcpy() {
    log_section "scrcpy (Screen Mirroring Tool)"
    
    if command -v scrcpy &>/dev/null; then
        local scrcpy_version
        scrcpy_version=$(scrcpy --version 2>&1 | head -1)
        log_pass "scrcpy installed: $scrcpy_version"
        return 0
    else
        log_fail "scrcpy not found"
        if [[ "$AUTO_FIX" == "true" ]]; then
            log_info "Installing scrcpy..."
            if brew install scrcpy; then
                log_pass "scrcpy installed successfully"
                return 0
            else
                log_fail "Failed to install scrcpy"
                return 1
            fi
        else
            log_info "Install with: brew install scrcpy"
            return 1
        fi
    fi
}

check_adb() {
    log_section "adb (Android Debug Bridge)"
    
    if command -v adb &>/dev/null; then
        local adb_version
        adb_version=$(adb version 2>&1 | grep "Version" | head -1)
        log_pass "adb installed: $adb_version"
        return 0
    else
        log_fail "adb not found"
        log_info "adb is included with scrcpy"
        log_info "Install with: brew install scrcpy"
        return 1
    fi
}

check_coreutils() {
    log_section "GNU coreutils (timeout command)"
    
    if command -v timeout &>/dev/null; then
        local timeout_version
        timeout_version=$(timeout --version 2>&1 | head -1)
        log_pass "GNU timeout available: $timeout_version"
        return 0
    elif command -v gtimeout &>/dev/null; then
        log_warn "Found gtimeout but not timeout in PATH"
        log_info "Install full coreutils: brew install coreutils"
        if [[ "$AUTO_FIX" == "true" ]]; then
            log_info "Installing coreutils..."
            if brew install coreutils; then
                log_pass "coreutils installed successfully"
                return 0
            else
                log_fail "Failed to install coreutils"
                return 1
            fi
        fi
        return 1
    else
        log_fail "GNU coreutils (timeout) not found"
        log_info "This is required for the timeout functionality"
        if [[ "$AUTO_FIX" == "true" ]]; then
            log_info "Installing coreutils..."
            if brew install coreutils; then
                log_pass "coreutils installed successfully"
                return 0
            else
                log_fail "Failed to install coreutils"
                return 1
            fi
        else
            log_info "Install with: brew install coreutils"
            return 1
        fi
    fi
}

check_bash_version() {
    log_section "Bash Version"
    
    local bash_version
    bash_version=$("$BASH" --version | head -1)
    
    # Check if bash version is 3.2 or higher
    local major minor
    major=$(echo "$bash_version" | grep -oE '[0-9]+' | head -1)
    minor=$(echo "$bash_version" | grep -oE '[0-9]+' | head -2 | tail -1)
    
    if [[ $major -gt 3 ]] || [[ $major -eq 3 && $minor -ge 2 ]]; then
        log_pass "Bash version compatible: $bash_version"
        return 0
    else
        log_fail "Bash version too old: $bash_version (need 3.2+)"
        return 1
    fi
}

check_git() {
    log_section "Git (Optional)"
    
    if command -v git &>/dev/null; then
        local git_version
        git_version=$(git --version)
        log_pass "Git installed: $git_version"
        return 0
    else
        log_warn "Git not found (optional for this project)"
        return 0
    fi
}

check_file_permissions() {
    log_section "File Permissions"
    
    local has_issues=0
    
    # Check main executable
    if [[ -x "$PROJECT_ROOT/amirror" ]]; then
        log_pass "amirror is executable"
    else
        log_fail "amirror is not executable"
        has_issues=1
    fi
    
    # Check main script
    if [[ -x "$PROJECT_ROOT/src/amirror.sh" ]]; then
        log_pass "amirror.sh is executable"
    else
        log_fail "amirror.sh is not executable"
        has_issues=1
    fi
    
    if [[ $has_issues -eq 1 ]]; then
        if [[ "$AUTO_FIX" == "true" ]]; then
            log_info "Fixing file permissions..."
            chmod +x "$PROJECT_ROOT/amirror"
            chmod +x "$PROJECT_ROOT/src/amirror.sh"
            log_pass "File permissions fixed"
        fi
        return 1
    fi
    
    return 0
}

check_log_directory() {
    log_section "Log Directory"
    
    local log_dir="$PROJECT_ROOT/logs"
    
    if [[ -d "$log_dir" ]]; then
        log_pass "Log directory exists: $log_dir"
        
        if [[ -w "$log_dir" ]]; then
            log_pass "Log directory is writable"
            return 0
        else
            log_fail "Log directory is not writable"
            return 1
        fi
    else
        log_info "Log directory doesn't exist (will be created on first run)"
        return 0
    fi
}

check_android_device() {
    log_section "Android Device"
    
    if ! command -v adb &>/dev/null; then
        log_warn "adb not available (install scrcpy first)"
        return 1
    fi
    
    local devices
    devices=$(adb devices 2>/dev/null | tail -n +2 | grep "device$" | wc -l)
    
    if [[ $devices -gt 0 ]]; then
        log_pass "Android device(s) detected: $devices"
        adb devices 2>/dev/null | grep "device$" | while read -r line; do
            local serial
            serial=$(echo "$line" | awk '{print $1}')
            echo -e "  ${GREEN}•${NC} $serial"
        done
        return 0
    else
        log_warn "No Android devices detected"
        log_info "Connect an Android device via USB and enable USB debugging"
        return 0
    fi
}

################################################################################
# Installation Functions
################################################################################

install_all_dependencies() {
    log_section "Installing All Dependencies"
    
    if ! command -v brew &>/dev/null; then
        log_fail "Homebrew is required"
        log_info "Install from: https://brew.sh"
        return 1
    fi
    
    log_info "This will install: scrcpy, coreutils, and update homebrew"
    echo -e "\n${YELLOW}Continue? (y/n)${NC} "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        return 0
    fi
    
    # Update homebrew
    log_info "Updating Homebrew..."
    brew update
    
    # Install scrcpy
    log_info "Installing scrcpy..."
    if ! brew install scrcpy; then
        log_fail "Failed to install scrcpy"
        return 1
    fi
    log_pass "scrcpy installed"
    
    # Install coreutils
    log_info "Installing coreutils..."
    if ! brew install coreutils; then
        log_fail "Failed to install coreutils"
        return 1
    fi
    log_pass "coreutils installed"
    
    log_pass "All dependencies installed successfully!"
    return 0
}

################################################################################
# Summary Functions
################################################################################

show_summary() {
    echo -e "\n${BOLD}${CYAN}━━ Summary ━━${NC}\n"
    
    if [[ $ISSUES_FOUND -eq 0 && $WARNINGS_FOUND -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ System is ready!${NC}"
        echo -e "\nYou can now run:"
        echo -e "  ${BLUE}./amirror start${NC}              - Start mirroring"
        echo -e "  ${BLUE}./amirror list${NC}               - List devices"
        echo -e "  ${BLUE}./amirror install${NC}            - Enable auto-detection"
        echo -e "\n"
        return 0
    else
        if [[ $ISSUES_FOUND -gt 0 ]]; then
            echo -e "${RED}${BOLD}✗ Issues found: $ISSUES_FOUND${NC}"
        fi
        if [[ $WARNINGS_FOUND -gt 0 ]]; then
            echo -e "${YELLOW}${BOLD}⚠ Warnings: $WARNINGS_FOUND${NC}"
        fi
        
        if [[ $ISSUES_FOUND -gt 0 ]]; then
            echo -e "\n${YELLOW}To fix automatically, run:${NC}"
            echo -e "  ${BLUE}./doctor --fix${NC}\n"
        fi
        
        return 1
    fi
}

################################################################################
# Main
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "Amirror Doctor v$VERSION"
                exit 0
                ;;
            --fix)
                AUTO_FIX=true
                shift
                ;;
            --install-all)
                INSTALL_ALL=true
                AUTO_FIX=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    show_header
    
    # Run diagnostics
    check_homebrew
    check_scrcpy
    check_adb
    check_coreutils
    check_bash_version
    check_git
    check_file_permissions
    check_log_directory
    check_android_device
    
    # Install all if requested
    if [[ "$INSTALL_ALL" == "true" ]]; then
        install_all_dependencies
    fi
    
    # Show summary
    show_summary
}

# Run main
main "$@"
