#!/bin/bash

################################################################################
# Auto-Monitor Uninstallation Script
# Description: Removes USB monitoring service
################################################################################

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly PLIST_NAME="com.user.android.usb-monitor.plist"
readonly LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
readonly PLIST_DEST="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   Android USB Monitor - Uninstaller   ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}\n"

# Check if service is loaded
if launchctl list | grep -q "${PLIST_NAME%.*}"; then
    echo -e "${YELLOW}⚠️  Unloading USB monitor service...${NC}"
    launchctl unload "${PLIST_DEST}" 2>/dev/null || true
    sleep 1
fi

# Remove plist file
if [[ -f "${PLIST_DEST}" ]]; then
    echo -e "${YELLOW}🗑️  Removing configuration file...${NC}"
    rm -f "${PLIST_DEST}"
fi

# Verify removal
if launchctl list | grep -q "${PLIST_NAME%.*}"; then
    echo -e "${RED}❌ Failed to unload USB monitor service${NC}\n"
    exit 1
else
    echo -e "\n${GREEN}✓ USB monitor uninstalled successfully!${NC}\n"
    echo -e "The system will no longer automatically detect Android devices.\n"
    echo -e "You can still manually run: ${YELLOW}./android-mirror.sh${NC}\n"
fi
