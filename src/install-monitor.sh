#!/bin/bash

################################################################################
# Auto-Monitor Installation Script
# Description: Installs USB monitoring for automatic Android device detection
################################################################################

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PLIST_TEMPLATE="${SCRIPT_DIR}/com.user.android.usb-monitor.plist"
readonly PLIST_NAME="com.user.android.usb-monitor.plist"
readonly LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
readonly PLIST_DEST="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Android USB Monitor - Installer     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo -e "${RED}❌ Error: adb not found${NC}"
    echo -e "${YELLOW}Please install scrcpy first: brew install scrcpy${NC}\n"
    exit 1
fi

# Create Launch Agents directory if it doesn't exist
mkdir -p "${LAUNCH_AGENTS_DIR}"

# Make monitor script executable
chmod +x "${SCRIPT_DIR}/usb-monitor.sh"

# Replace placeholder in plist template
echo -e "${BLUE}⚙️  Configuring Launch Agent...${NC}"
sed "s|SCRIPT_DIR_PLACEHOLDER|${SCRIPT_DIR}|g" "${PLIST_TEMPLATE}" > "${PLIST_DEST}"

# Unload existing service if running
if launchctl list | grep -q "${PLIST_NAME%.*}"; then
    echo -e "${YELLOW}⚠️  Unloading existing service...${NC}"
    launchctl unload "${PLIST_DEST}" 2>/dev/null || true
fi

# Load the Launch Agent
echo -e "${BLUE}🚀 Loading USB monitor service...${NC}"
launchctl load "${PLIST_DEST}"

# Verify it's loaded
if launchctl list | grep -q "${PLIST_NAME%.*}"; then
    echo -e "\n${GREEN}✓ USB monitor installed successfully!${NC}\n"
    echo -e "The system will now automatically detect when you connect an Android device."
    echo -e "You'll see a dialog asking if you want to start screen mirroring.\n"
    
    echo -e "${BLUE}To test:${NC}"
    echo -e "  1. Disconnect your Android device (if connected)"
    echo -e "  2. Reconnect it via USB"
    echo -e "  3. A dialog should appear asking if you want to mirror\n"
    
    echo -e "${BLUE}To uninstall:${NC}"
    echo -e "  ${YELLOW}./uninstall-monitor.sh${NC}\n"
    
    echo -e "${BLUE}Logs location:${NC}"
    echo -e "  ${SCRIPT_DIR}/logs/usb-monitor.log\n"
else
    echo -e "${RED}❌ Failed to load USB monitor service${NC}"
    echo -e "Check the system logs: ${YELLOW}launchctl list | grep android${NC}\n"
    exit 1
fi
