#!/bin/bash
# ================================================
#   ENHANCED ANDROID FORENSICS EXTRACTOR
#   Version 3.0 - Comprehensive Forensic Toolkit
# ================================================
# Based on AndroidForensics by Douglas Habian
# Enhanced with additional forensic capabilities
# ================================================

# ---------- COLORS ----------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
NC="\033[0m"

SCRIPT_START=$(date +%s)
SCRIPT_VERSION="3.0.0"

# ---------- CONFIGURATION ----------
OUTPUT_BASE="./forensic_output"
CASE_ID=""
DEVICE_SERIAL=""
INCLUDE_NETWORK_SCAN=false
INCLUDE_WIFI_PASSWORDS=false
EXTRACTION_TYPE="full"  # full, quick, user, system

# ---------- COMMAND LINE ARGUMENTS ----------
usage() {
    echo -e "${CYAN}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Options:"
    echo "  -c, --case-id ID        Specify case ID"
    echo "  -d, --device SERIAL     Target specific device"
    echo "  -t, --type TYPE         Extraction type: full, quick, user, system"
    echo "  -w, --wifi              Include WiFi password extraction (requires root)"
    echo "  -n, --network           Include network ADB scan"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -c CASE_2025_001 -d RZ8N1234XYZ -t full"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--case-id)
            CASE_ID="$2"
            shift 2
            ;;
        -d|--device)
            DEVICE_SERIAL="$2"
            shift 2
            ;;
        -t|--type)
            EXTRACTION_TYPE="$2"
            shift 2
            ;;
        -w|--wifi)
            INCLUDE_WIFI_PASSWORDS=true
            shift
            ;;
        -n|--network)
            INCLUDE_NETWORK_SCAN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# ---------- CHECK ADB ----------
check_adb() {
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}[ERROR] ADB is not installed. Please install Android Platform Tools.${NC}"
        echo -e "${YELLOW}Install: sudo apt install android-tools-adb${NC}"
        exit 1
    fi
    echo -e "${GREEN}[✓] ADB found: $(which adb)${NC}"
}

# ---------- START ADB SERVER ----------
start_adb_server() {
    adb start-server &> /dev/null
    echo -e "${GREEN}[✓] ADB server started${NC}"
}

# ---------- DETECT DEVICES ----------
detect_devices() {
    local devices=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')

    if [ -z "$devices" ]; then
        echo -e "${RED}[ERROR] No authorized devices found.${NC}"
        echo -e "${YELLOW}Ensure device is connected and USB debugging is enabled.${NC}"

        # Check for unauthorized devices
        local unauth=$(adb devices | awk 'NR>1 && $2=="unauthorized" {print $1}')
        if [ -n "$unauth" ]; then
            echo -e "${YELLOW}Unauthorized device detected. Accept the debugging prompt on the device.${NC}"
        fi

        # Offer network scan
        if [ "$INCLUDE_NETWORK_SCAN" = true ]; then
            echo -e "${BLUE}[*] Scanning for network ADB devices...${NC}"
            scan_network_adb
        fi
        exit 1
    fi

    # Count devices
    local count=$(echo "$devices" | wc -l)

    if [ $count -gt 1 ] && [ -z "$DEVICE_SERIAL" ]; then
        echo -e "${YELLOW}Multiple devices detected:${NC}"
        echo "$devices" | nl -w2 -s') '
        echo ""
        read -p "Select device number: " selection
        DEVICE_SERIAL=$(echo "$devices" | sed -n "${selection}p")
    elif [ -n "$DEVICE_SERIAL" ]; then
        if ! echo "$devices" | grep -q "$DEVICE_SERIAL"; then
            echo -e "${RED}[ERROR] Device $DEVICE_SERIAL not found.${NC}"
            exit 1
        fi
    else
        DEVICE_SERIAL=$(echo "$devices" | head -1)
    fi

    echo -e "${GREEN}[✓] Target device: $DEVICE_SERIAL${NC}"
}

# ---------- SCAN NETWORK ADB ----------
scan_network_adb() {
    local found_devices=()

    for subnet in "192.168.1" "192.168.0" "10.0.0"; do
        echo -e "${BLUE}[*] Scanning $subnet.0/24 for ADB (port 5555)...${NC}"
        for i in $(seq 1 254); do
            (
                if timeout 0.3 bash -c "echo '' | nc -w1 $subnet.$i 5555" 2>/dev/null; then
                    echo "$subnet.$i"
                fi
            ) &
        done
        wait
    done | while read ip; do
        echo -e "${GREEN}[+] Found potential ADB at $ip:5555${NC}"
        if adb connect "$ip:5555" 2>/dev/null | grep -q "connected"; then
            echo -e "${GREEN}[✓] Connected to $ip:5555${NC}"
        fi
    done
}

# ---------- CREATE CASE ID ----------
create_case_id() {
    if [ -z "$CASE_ID" ]; then
        CASE_ID="CASE_$(date +%Y%m%d_%H%M%S)_$(head /dev/urandom | tr -dc 'A-Z0-9' | head -c 6)"
    fi
    echo -e "${CYAN}Case ID: $CASE_ID${NC}"
}

# ---------- CREATE OUTPUT DIRECTORY ----------
create_output_dir() {
    OUTPUT_DIR="${OUTPUT_BASE}/${CASE_ID}"
    mkdir -p "$OUTPUT_DIR"/{raw,csv,json,reports,logs}

    echo -e "${GREEN}[✓] Output directory: $OUTPUT_DIR${NC}"
}

# ---------- HELPER: RUN ADB COMMAND ----------
run_adb() {
    local description="$1"
    local command="$2"
    local filename="$3"
    local silent="$4"

    echo -e "${BLUE}[*] ${description}${NC}"

    if [ "$silent" = "silent" ]; then
        adb -s "$DEVICE_SERIAL" shell $command > "$OUTPUT_DIR/raw/$filename" 2>&1
    else
        adb -s "$DEVICE_SERIAL" shell $command | tee "$OUTPUT_DIR/raw/$filename"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Saved: raw/$filename${NC}"
        return 0
    else
        echo -e "${RED}[✗] Failed: $filename${NC}"
        return 1
    fi
}

# ---------- EXTRACTION: DEVICE INFO ----------
extract_device_info() {
    echo -e "\n${MAGENTA}═══ DEVICE INFORMATION ═══${NC}\n"

    # Basic info
    run_adb "Gathering device identification..." \
        "getprop | grep -E 'ro.product.model|ro.product.manufacturer|ro.product.name|ro.build.version|ro.serialno|ro.build.fingerprint'" \
        "device_info.txt"

    # Detailed properties
    run_adb "Collecting all system properties..." \
        "getprop" \
        "all_properties.txt" \
        "silent"

    # Device state
    run_adb "Capturing device state (uptime, battery)..." \
        "echo '=== UPTIME ===' && uptime && echo '' && echo '=== BATTERY ===' && dumpsys battery" \
        "device_state.txt" \
        "silent"

    # IMEI and phone info
    run_adb "Extracting telephony information..." \
        "dumpsys telephony.registry" \
        "telephony.txt" \
        "silent"
}

# ---------- EXTRACTION: USER DATA ----------
extract_user_data() {
    echo -e "\n${MAGENTA}═══ USER DATA EXTRACTION ═══${NC}\n"

    # Accounts
    run_adb "Listing registered accounts..." \
        "dumpsys account | grep -i com.*$ -o | cut -d' ' -f1 | cut -d'}' -f1 | grep -v com$" \
        "registered_accounts.txt"

    # Emails
    run_adb "Extracting email addresses..." \
        "dumpsys account | grep -E -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}' | sort -u" \
        "emails.txt"

    # Boot count
    run_adb "Reading boot count..." \
        "settings list global | grep 'boot_count=' | cut -d= -f2 | head -n 1 | xargs echo 'Booted:' | sed 's/$/ times/g'" \
        "boot_count.txt"

    # Contacts
    run_adb "Extracting contacts with phone numbers..." \
        "content query --uri content://contacts/phones/ --projection display_name:number" \
        "contacts.txt"

    # Call logs
    run_adb "Dumping call history..." \
        "content query --uri content://call_log/calls" \
        "call_logs.txt"

    # SMS
    run_adb "Extracting SMS messages..." \
        "content query --uri content://sms/" \
        "sms.txt"

    # Calendar events
    run_adb "Extracting calendar events..." \
        "content query --uri content://calendar/events" \
        "calendar.txt"

    # Notes (varies by device)
    run_adb "Attempting notes extraction..." \
        "content query --uri content://com.android.notes/notes 2>/dev/null || echo 'Notes extraction not available'" \
        "notes.txt" \
        "silent"
}

# ---------- EXTRACTION: APP DATA ----------
extract_app_data() {
    echo -e "\n${MAGENTA}═══ APPLICATION DATA ═══${NC}\n"

    # All packages
    run_adb "Listing all installed packages..." \
        "pm list packages -f" \
        "packages_all.txt" \
        "silent"

    # Third-party packages
    run_adb "Listing third-party packages..." \
        "pm list packages -3" \
        "packages_thirdparty.txt"

    # Running services
    run_adb "Listing running services..." \
        "dumpsys activity services" \
        "running_services.txt" \
        "silent"

    # Recent tasks
    run_adb "Extracting recent tasks..." \
        "dumpsys activity recents" \
        "recent_tasks.txt" \
        "silent"

    # App usage stats
    run_adb "Extracting app usage statistics..." \
        "dumpsys usagestats" \
        "usage_stats.txt" \
        "silent"
}

# ---------- EXTRACTION: NETWORK DATA ----------
extract_network_data() {
    echo -e "\n${MAGENTA}═══ NETWORK DATA ═══${NC}\n"

    # WiFi info
    run_adb "Extracting WiFi configuration..." \
        "dumpsys wifi" \
        "wifi_config.txt" \
        "silent"

    # Network interfaces
    run_adb "Listing network interfaces..." \
        "ifconfig 2>/dev/null || ip addr show" \
        "network_interfaces.txt" \
        "silent"

    # Network stats
    run_adb "Collecting network statistics..." \
        "dumpsys netstats" \
        "network_stats.txt" \
        "silent"

    # Connectivity
    run_adb "Extracting connectivity info..." \
        "dumpsys connectivity" \
        "connectivity.txt" \
        "silent"

    # DNS
    run_adb "Reading DNS configuration..." \
        "getprop | grep dns" \
        "dns_config.txt"

    # Bluetooth paired devices
    run_adb "Listing Bluetooth paired devices..." \
        "dumpsys bluetooth_manager | grep -A 20 'Bonded devices'" \
        "bluetooth_devices.txt"

    # WiFi passwords (if requested and rooted)
    if [ "$INCLUDE_WIFI_PASSWORDS" = true ]; then
        run_adb "Attempting WiFi password extraction (requires root)..." \
            "cat /data/misc/wifi/wpa_supplicant.conf 2>/dev/null || echo 'Requires root access'" \
            "wifi_passwords.txt" \
            "silent"
    fi
}

# ---------- EXTRACTION: BROWSER DATA ----------
extract_browser_data() {
    echo -e "\n${MAGENTA}═══ BROWSER DATA ═══${NC}\n"

    # Chrome history
    run_adb "Attempting Chrome history extraction..." \
        "content query --uri content://com.android.chrome.browser/history 2>/dev/null || echo 'Chrome history requires additional access'" \
        "chrome_history.txt" \
        "silent"

    # Default browser
    run_adb "Extracting default browser history..." \
        "content query --uri content://browser/history 2>/dev/null || echo 'No default browser history available'" \
        "browser_history.txt" \
        "silent"

    # Browser bookmarks
    run_adb "Extracting browser bookmarks..." \
        "content query --uri content://browser/bookmarks 2>/dev/null || echo 'No bookmarks available'" \
        "browser_bookmarks.txt" \
        "silent"

    # Download manager
    run_adb "Extracting download history..." \
        "content query --uri content://downloads/my_downloads" \
        "downloads.txt"
}

# ---------- EXTRACTION: SYSTEM DIAGNOSTICS ----------
extract_system_diagnostics() {
    echo -e "\n${MAGENTA}═══ SYSTEM DIAGNOSTICS ═══${NC}\n"

    # Logcat snapshot
    run_adb "Capturing system log snapshot..." \
        "logcat -d -v time | tail -n 2000" \
        "logcat.txt" \
        "silent"

    # Memory info
    run_adb "Extracting memory information..." \
        "dumpsys meminfo" \
        "meminfo.txt" \
        "silent"

    # Battery stats
    run_adb "Collecting battery statistics..." \
        "dumpsys batterystats" \
        "batterystats.txt" \
        "silent"

    # Location history
    run_adb "Extracting location history..." \
        "dumpsys location" \
        "location.txt" \
        "silent"

    # Notifications
    run_adb "Extracting notification history..." \
        "dumpsys notification" \
        "notifications.txt" \
        "silent"

    # Alarm history
    run_adb "Extracting alarm history..." \
        "dumpsys alarm" \
        "alarms.txt" \
        "silent"

    # Clipboard (may be empty)
    run_adb "Checking clipboard contents..." \
        "dumpsys clipboard" \
        "clipboard.txt"

    # Sensor data
    run_adb "Extracting sensor information..." \
        "dumpsys sensorservice" \
        "sensors.txt" \
        "silent"
}

# ---------- EXTRACTION: SECURITY DATA ----------
extract_security_data() {
    echo -e "\n${MAGENTA}═══ SECURITY DATA ═══${NC}\n"

    # Lock settings
    run_adb "Extracting lock screen settings..." \
        "dumpsys lock_settings" \
        "lock_settings.txt" \
        "silent"

    # Fingerprint
    run_adb "Extracting fingerprint data..." \
        "dumpsys fingerprint" \
        "fingerprint.txt" \
        "silent"

    # Keyguard state
    run_adb "Checking keyguard state..." \
        "dumpsys keyguard" \
        "keyguard.txt" \
        "silent"

    # Trust agents (Smart Lock)
    run_adb "Extracting trust agent info..." \
        "dumpsys trust" \
        "trust_agents.txt" \
        "silent"

    # Device admin apps
    run_adb "Listing device administrator apps..." \
        "dumpsys device_policy" \
        "device_policy.txt" \
        "silent"

    # Certificates
    run_adb "Listing installed certificates..." \
        "dumpsys keystore" \
        "keystore.txt" \
        "silent"
}

# ---------- EXTRACTION: SECRET CODES ----------
extract_secret_codes() {
    echo -e "\n${MAGENTA}═══ SECRET CODES ═══${NC}\n"

    local secret_codes_file="$OUTPUT_DIR/raw/secret_codes.txt"

    echo -e "${BLUE}[*] Extracting Android secret codes...${NC}"

    package_list=$(adb -s "$DEVICE_SERIAL" shell pm list packages -s -f | \
        awk -F 'package:' '{print $2}' | awk -F '=' '{print $2}')

    echo "=== ANDROID SECRET CODES ===" > "$secret_codes_file"
    echo "Extracted: $(date)" >> "$secret_codes_file"
    echo "" >> "$secret_codes_file"

    for pkg in $package_list; do
        codes=$(adb -s "$DEVICE_SERIAL" shell pm dump "$pkg" 2>/dev/null | \
            grep -E 'Scheme: "android_secret_code"|Authority: "[0-9].*"|Authority: "[A-Z].*"')

        if [ -n "$codes" ]; then
            echo "Package: $pkg" >> "$secret_codes_file"
            echo "$codes" >> "$secret_codes_file"
            echo "" >> "$secret_codes_file"
        fi
    done

    echo -e "${GREEN}[✓] Saved: raw/secret_codes.txt${NC}"
}

# ---------- BUGREPORT (BACKGROUND) ----------
generate_bugreport() {
    echo -e "\n${BLUE}[*] Initiating full bugreport (runs in background)...${NC}"
    echo -e "${YELLOW}[i] Bugreport may take several minutes.${NC}"

    BUGREPORT_FILE="${OUTPUT_DIR}/raw/bugreport_$(date +%Y%m%d_%H%M%S).zip"

    (
        if adb -s "$DEVICE_SERIAL" shell 'command -v bugreportz' &> /dev/null; then
            adb -s "$DEVICE_SERIAL" bugreport "$BUGREPORT_FILE" 2>/dev/null
        else
            adb -s "$DEVICE_SERIAL" bugreport > "${BUGREPORT_FILE%.zip}.txt" 2>/dev/null
        fi
        echo -e "\n${GREEN}[✓] Bugreport completed: $(basename $BUGREPORT_FILE)${NC}" >> "$OUTPUT_DIR/logs/bugreport_status.txt"
    ) &

    BUGREPORT_PID=$!
    echo $BUGREPORT_PID > "$OUTPUT_DIR/logs/bugreport.pid"
}

# ---------- CSV EXPORT ----------
export_to_csv() {
    echo -e "\n${MAGENTA}═══ CSV EXPORT ═══${NC}\n"

    # Contacts CSV
    if [ -f "$OUTPUT_DIR/raw/contacts.txt" ] && [ -s "$OUTPUT_DIR/raw/contacts.txt" ]; then
        echo -e "${BLUE}[*] Converting contacts to CSV...${NC}"
        echo "Name,Phone Number" > "$OUTPUT_DIR/csv/contacts.csv"
        grep -oP 'display_name=\K[^,]+|number=\K[0-9+]+' "$OUTPUT_DIR/raw/contacts.txt" | \
            paste - - | sed 's/\t/,/' >> "$OUTPUT_DIR/csv/contacts.csv"
        echo -e "${GREEN}[✓] Saved: csv/contacts.csv${NC}"
    fi

    # Call logs CSV
    if [ -f "$OUTPUT_DIR/raw/call_logs.txt" ] && [ -s "$OUTPUT_DIR/raw/call_logs.txt" ]; then
        echo -e "${BLUE}[*] Converting call logs to CSV...${NC}"
        echo "Number,Type,Date,Duration" > "$OUTPUT_DIR/csv/call_logs.csv"
        grep -oP 'number=\K[^,]+|type=\K[0-9]+|date=\K[0-9]+|duration=\K[0-9]+' "$OUTPUT_DIR/raw/call_logs.txt" | \
            paste - - - - | sed 's/\t/,/g' >> "$OUTPUT_DIR/csv/call_logs.csv"
        echo -e "${GREEN}[✓] Saved: csv/call_logs.csv${NC}"
    fi

    # Packages CSV
    if [ -f "$OUTPUT_DIR/raw/packages_thirdparty.txt" ] && [ -s "$OUTPUT_DIR/raw/packages_thirdparty.txt" ]; then
        echo -e "${BLUE}[*] Converting packages to CSV...${NC}"
        echo "Package Name" > "$OUTPUT_DIR/csv/packages.csv"
        sed 's/package://' "$OUTPUT_DIR/raw/packages_thirdparty.txt" >> "$OUTPUT_DIR/csv/packages.csv"
        echo -e "${GREEN}[✓] Saved: csv/packages.csv${NC}"
    fi
}

# ---------- JSON EXPORT ----------
export_to_json() {
    echo -e "\n${MAGENTA}═══ JSON EXPORT ═══${NC}\n"

    # Device info JSON
    echo -e "${BLUE}[*] Creating device info JSON...${NC}"
    cat > "$OUTPUT_DIR/json/device_info.json" << EOF
{
    "case_id": "$CASE_ID",
    "extraction_time": "$(date -Iseconds)",
    "device": {
        "model": "$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.model | tr -d '\r')",
        "manufacturer": "$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.manufacturer | tr -d '\r')",
        "android_version": "$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.release | tr -d '\r')",
        "api_level": "$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')",
        "serial": "$(adb -s "$DEVICE_SERIAL" shell getprop ro.serialno | tr -d '\r')",
        "build_fingerprint": "$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.fingerprint | tr -d '\r')",
        "device_id": "$DEVICE_SERIAL"
    },
    "extraction_type": "$EXTRACTION_TYPE",
    "tool_version": "$SCRIPT_VERSION"
}
EOF
    echo -e "${GREEN}[✓] Saved: json/device_info.json${NC}"

    # Emails JSON
    if [ -f "$OUTPUT_DIR/raw/emails.txt" ] && [ -s "$OUTPUT_DIR/raw/emails.txt" ]; then
        echo -e "${BLUE}[*] Creating emails JSON...${NC}"
        echo '{"emails": [' > "$OUTPUT_DIR/json/emails.json"
        cat "$OUTPUT_DIR/raw/emails.txt" | sed 's/^/"/; s/$/",/' | sed '$ s/,$//'
        echo '>}' >> "$OUTPUT_DIR/json/emails.json"
        echo -e "${GREEN}[✓] Saved: json/emails.json${NC}"
    fi

    # Packages JSON
    if [ -f "$OUTPUT_DIR/raw/packages_thirdparty.txt" ] && [ -s "$OUTPUT_DIR/raw/packages_thirdparty.txt" ]; then
        echo -e "${BLUE}[*] Creating packages JSON...${NC}"
        echo '{"third_party_packages": [' > "$OUTPUT_DIR/json/packages.json"
        sed 's/package:/"/; s/$/",/' "$OUTPUT_DIR/raw/packages_thirdparty.txt" | sed '$ s/,$//'
        echo ']}' >> "$OUTPUT_DIR/json/packages.json"
        echo -e "${GREEN}[✓] Saved: json/packages.json${NC}"
    fi
}

# ---------- GENERATE HASHES ----------
generate_hashes() {
    echo -e "\n${MAGENTA}═══ INTEGRITY VERIFICATION ═══${NC}\n"

    local hash_file="$OUTPUT_DIR/reports/integrity_hashes.txt"

    echo "============================================" > "$hash_file"
    echo "FORENSIC INTEGRITY VERIFICATION" >> "$hash_file"
    echo "============================================" >> "$hash_file"
    echo "Case ID: $CASE_ID" >> "$hash_file"
    echo "Generated: $(date -Iseconds)" >> "$hash_file"
    echo "Examiner: $(whoami)@$(hostname)" >> "$hash_file"
    echo "============================================" >> "$hash_file"
    echo "" >> "$hash_file"
    echo "=== SHA-256 HASHES ===" >> "$hash_file"

    find "$OUTPUT_DIR/raw" -type f -exec sha256sum {} \; >> "$hash_file"

    echo "" >> "$hash_file"
    echo "=== MD5 HASHES ===" >> "$hash_file"
    find "$OUTPUT_DIR/raw" -type f -exec md5sum {} \; >> "$hash_file"

    echo -e "${GREEN}[✓] Integrity hashes saved: reports/integrity_hashes.txt${NC}"
}

# ---------- GENERATE REPORT ----------
generate_report() {
    echo -e "\n${MAGENTA}═══ FORENSIC REPORT ═══${NC}\n"

    local report_file="$OUTPUT_DIR/reports/FORENSIC_REPORT.txt"

    SCRIPT_END=$(date +%s)
    TOTAL_TIME=$((SCRIPT_END - SCRIPT_START))

    cat > "$report_file" << EOF
============================================
ANDROID FORENSIC EXTRACTION REPORT
============================================
Generated by AndroidForensics Enhanced v${SCRIPT_VERSION}

============================================
CASE INFORMATION
============================================
Case ID:         $CASE_ID
Extraction Date: $(date)
Examiner:        $(whoami)@$(hostname)
Extraction Type: $EXTRACTION_TYPE

============================================
DEVICE INFORMATION
============================================
Device ID:       $DEVICE_SERIAL
Model:           $(adb -s "$DEVICE_SERIAL" shell getprop ro.product.model | tr -d '\r')
Manufacturer:    $(adb -s "$DEVICE_SERIAL" shell getprop ro.product.manufacturer | tr -d '\r')
Android Version: $(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.release | tr -d '\r')
API Level:       $(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.sdk | tr -d '\r')
Serial Number:   $(adb -s "$DEVICE_SERIAL" shell getprop ro.serialno | tr -d '\r')
Build Fingerprint: $(adb -s "$DEVICE_SERIAL" shell getprop ro.build.fingerprint | tr -d '\r')

============================================
EXTRACTION MANIFEST
============================================
EOF

    # Add file listing
    echo "" >> "$report_file"
    echo "Raw Data Files:" >> "$report_file"
    ls -lh "$OUTPUT_DIR/raw" | awk 'NR>1 {printf "  %-30s %10s\n", $9, $5}' >> "$report_file"

    echo "" >> "$report_file"
    echo "CSV Files:" >> "$report_file"
    ls -lh "$OUTPUT_DIR/csv" 2>/dev/null | awk 'NR>1 {printf "  %-30s %10s\n", $9, $5}' >> "$report_file"

    echo "" >> "$report_file"
    echo "JSON Files:" >> "$report_file"
    ls -lh "$OUTPUT_DIR/json" 2>/dev/null | awk 'NR>1 {printf "  %-30s %10s\n", $9, $5}' >> "$report_file"

    cat >> "$report_file" << EOF

============================================
EXTRACTION SUMMARY
============================================
Total Runtime:   ${TOTAL_TIME} seconds
Total Files:     $(find "$OUTPUT_DIR/raw" -type f | wc -l)
Total Data:      $(du -sh "$OUTPUT_DIR/raw" 2>/dev/null | cut -f1)

============================================
CHAIN OF CUSTODY
============================================
[ ] Evidence collected by: ______________________
[ ] Collection date/time: ______________________
[ ] Location: _________________________________
[ ] Device received from: _____________________
[ ] Purpose of extraction: ____________________
[ ] Hash verified by: _________________________
[ ] Verification date: ________________________

============================================
INTEGRITY VERIFICATION
============================================
SHA-256 and MD5 hashes saved to:
  reports/integrity_hashes.txt

To verify file integrity:
  sha256sum -c reports/integrity_hashes.txt

============================================
NOTES
============================================



============================================
LEGAL NOTICE
============================================
This forensic extraction was performed for
authorized purposes only. All data extracted
is confidential and protected by applicable
laws and regulations.

============================================
END OF REPORT
============================================
EOF

    echo -e "${GREEN}[✓] Forensic report generated: reports/FORENSIC_REPORT.txt${NC}"
}

# ---------- SUMMARY ----------
print_summary() {
    SCRIPT_END=$(date +%s)
    TOTAL_TIME=$((SCRIPT_END - SCRIPT_START))

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}   EXTRACTION COMPLETE${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${CYAN}Case ID:     $CASE_ID${NC}"
    echo -e "${CYAN}Device:      $DEVICE_SERIAL${NC}"
    echo -e "${CYAN}Output:      $OUTPUT_DIR${NC}"
    echo -e "${CYAN}Runtime:     ${TOTAL_TIME} seconds${NC}"
    echo ""
    echo -e "${YELLOW}Files extracted:${NC}"
    ls -lh "$OUTPUT_DIR/raw" | awk 'NR>1 {printf "  %-30s %10s\n", $9, $5}'
    echo ""
    echo -e "${YELLOW}Reports:${NC}"
    ls -lh "$OUTPUT_DIR/reports" 2>/dev/null | awk 'NR>1 {printf "  %-30s %10s\n", $9, $5}'
    echo ""
    echo -e "${BLUE}[i] Bugreport is running in background (if initiated)${NC}"
    echo ""
}

# ---------- MAIN ----------
main() {
    clear

    echo -e "${CYAN}"
    cat << "EOF"
    _    _      ____                  ______ __
   / \  (_)_ __/ ___|  ___ ___  _ __ |  ___/ _|___
  / _ \ | | '__\___ \ / __/ _ \| '_ \| |_ | |_/ __|
 / ___ \| | |   ___) | (_| (_) | | | |  _||  _\__ \
/_/   \_\_|_|  |____/ \___\___/|_| |_|_| |_| |___/
     ___  __          _____  _____
    / _ \/ /  ___ ___/ / _ )/ ___/
   / // / _ \/ -_) _  / _  / /__
  /____/_//_/\__/\_,_/____/\___/

          Enhanced Forensic Toolkit v3.0
EOF
    echo -e "${NC}"

    # Pre-flight checks
    check_adb
    start_adb_server
    create_case_id
    detect_devices
    create_output_dir

    # Run extractions based on type
    case "$EXTRACTION_TYPE" in
        quick)
            extract_device_info
            extract_user_data
            ;;
        user)
            extract_device_info
            extract_user_data
            extract_app_data
            extract_browser_data
            ;;
        system)
            extract_device_info
            extract_system_diagnostics
            extract_security_data
            ;;
        full|*)
            extract_device_info
            extract_user_data
            extract_app_data
            extract_network_data
            extract_browser_data
            extract_system_diagnostics
            extract_security_data
            extract_secret_codes
            generate_bugreport
            ;;
    esac

    # Export formats
    export_to_csv
    export_to_json

    # Integrity and reporting
    generate_hashes
    generate_report

    # Final summary
    print_summary
}

# Run main
main "$@"
