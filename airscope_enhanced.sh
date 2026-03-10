#!/bin/bash
# ================================================
#   AirScope Enhanced - WiFi Radar for Android
#   Version 2.0 with Network Forensics
# ================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Configuration
OUTPUT_FILE="wifi_scan_$(date +%Y%m%d_%H%M%S).txt"
DEVICE=""
QUIET=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ADB command wrapper
adb_cmd() {
    if [ -n "$DEVICE" ]; then
        adb -s "$DEVICE" "$@"
    else
        adb "$@"
    fi
}

# Banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    _    _      ____                       
   / \  (_)_ __/ ___|  ___ ___  _ __   ___ 
  / _ \ | | '__\___ \ / __/ _ \| '_ \ / _ \
 / ___ \| | |   ___) | (_| (_) | |_) |  __/
/_/   \_\_|_|  |____/ \___\___/| .__/ \___|
                               |_|    
            WiFi Radar v2.0
EOF
    echo -e "${RESET}"
}

# Check for device
check_device() {
    if ! adb_cmd get-state &>/dev/null; then
        echo -e "${RED}[ERROR] No device connected${RESET}"
        exit 1
    fi
}

# Refresh WiFi scan
refresh_wifi() {
    echo -e "${YELLOW}[*] Refreshing WiFi scan...${RESET}"
    adb_cmd shell svc wifi disable
    sleep 2
    adb_cmd shell svc wifi enable
    sleep 5
}

# Parse and display scan results
parse_wifi_scan() {
    echo -e "${WHITE}============================================================${RESET}"
    echo -e "${WHITE}                    WiFi NETWORKS DETECTED${RESET}"
    echo -e "${WHITE}============================================================${RESET}"
    echo ""

    # Header
    printf "${WHITE}%-32s %-8s %-12s %-20s${RESET}\n" "SSID" "BAND" "SIGNAL" "BSSID"
    echo -e "${WHITE}--------------------------------------------------------------------------------${RESET}"

    # Get scan results
    adb_cmd shell dumpsys wifi | \
        grep "Networks filtered out due" | \
        sed 's/.*Networks filtered out due [^:]*: //' | \
        tr '/' '\n' | \
        grep -E '[0-9a-f]{2}(:[0-9a-f]{2}){5}' | \
        sed -E 's/([^:]+):([0-9a-f:]+)\(([^)]+)\)(-?[0-9]+)/\1,\2,\3,\4/' | \
        awk -F, 'NF==4 {
            ssid=$1; bssid=$2; band=$3; rssi=$4;
            if (ssid=="" || bssid=="") next;
            
            # Color code by signal strength
            if (rssi >= -70) color="\033[1;32m";      # Green - excellent
            else if (rssi >= -80) color="\033[1;33m"; # Yellow - good
            else if (rssi >= -90) color="\033[1;31m"; # Red - weak
            else color="\033[0;31m";                   # Dark red - very weak
            
            # Color BSSID purple
            bssid_color="\033[1;35m";
            
            printf "%-32s %-8s %s%-4d dBm\033[0m  %s%s\033[0m\n", \
                substr(ssid,1,32), band, color, rssi, bssid_color, bssid;
        }' | sort -t' ' -k3 -n -r
}

# Save to file
save_results() {
    local timestamp=$(date)
    
    echo "=== WiFi Scan Results ===" > "$OUTPUT_FILE"
    echo "Timestamp: $timestamp" >> "$OUTPUT_FILE"
    echo "Device: $(adb_cmd shell getprop ro.product.model | tr -d '\r')" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    adb_cmd shell dumpsys wifi >> "$OUTPUT_FILE" 2>/dev/null
    
    echo -e "${GREEN}[✓] Full results saved to: $OUTPUT_FILE${RESET}"
}

# Show connected network info
show_connected() {
    echo ""
    echo -e "${WHITE}=== Currently Connected Network ===${RESET}"
    
    adb_cmd shell dumpsys wifi | grep -A 20 "mNetworkInfo" | head -25
    
    # Get IP address
    local ip=$(adb_cmd shell ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    if [ -n "$ip" ]; then
        echo -e "${GREEN}Device IP: $ip${RESET}"
    fi
}

# Show saved networks (if accessible)
show_saved_networks() {
    echo ""
    echo -e "${WHITE}=== Saved Network Configuration ===${RESET}"
    
    adb_cmd shell dumpsys wifi | grep -E "SSID|preSharedKey|wepKey" | head -50
    
    # Check if passwords are accessible
    if adb_cmd shell dumpsys wifi | grep -q "preSharedKey"; then
        echo -e "${YELLOW}[!] WiFi passwords may be visible (check output)${RESET}"
    fi
}

# Main execution
main() {
    show_banner
    check_device
    
    if [ "$QUIET" = false ]; then
        refresh_wifi
    fi
    
    parse_wifi_scan
    show_connected
    save_results
    
    if [ "$QUIET" = false ]; then
        show_saved_networks
    fi
    
    echo ""
    echo -e "${GREEN}Scan complete.${RESET}"
}

main "$@"
