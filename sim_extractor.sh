#!/bin/bash
# ================================================
#   SIM Card Forensic Extractor
#   Extracts data directly from SIM card
# ================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

OUTPUT_DIR="./sim_forensics_$(date +%Y%m%d_%H%M%S)"

# Check for SIM reader
check_reader() {
    echo -e "${BLUE}[*] Checking for SIM card reader...${NC}"
    
    if ! lsusb | grep -qi "smart\|reader\|gemalto\|acs"; then
        echo -e "${YELLOW}[!] No SIM reader detected via USB${NC}"
        echo -e "${YELLOW}    Please connect a USB SIM card reader${NC}"
        return 1
    fi
    
    echo -e "${GREEN}[✓] SIM reader detected${NC}"
    return 0
}

# Check for pcscd
check_pcscd() {
    if ! command -v pcscd &> /dev/null; then
        echo -e "${YELLOW}[!] pcscd not installed${NC}"
        echo -e "${YELLOW}    Install: sudo apt install pcscd pcsc-tools${NC}"
        return 1
    fi
    
    sudo systemctl start pcscd 2>/dev/null
    echo -e "${GREEN}[✓] pcscd service running${NC}"
    return 0
}

# Extract SIM data using pysim
extract_sim_pysim() {
    echo -e "${BLUE}[*] Attempting SIM extraction with PySIM...${NC}"
    
    if ! python3 -c "import pySim" 2>/dev/null; then
        echo -e "${YELLOW}[!] PySIM not installed${NC}"
        echo -e "${YELLOW}    Install: pip install pySim${NC}"
        return 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    # Try common reader ports
    for port in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyACM0; do
        if [ -e "$port" ]; then
            echo -e "${BLUE}[*] Trying $port...${NC}"
            
            # Read SIM info
            pySim-read -p "$port" > "$OUTPUT_DIR/sim_info.txt" 2>&1
            
            if [ -s "$OUTPUT_DIR/sim_info.txt" ]; then
                echo -e "${GREEN}[✓] SIM data extracted${NC}"
                return 0
            fi
        fi
    done
    
    return 1
}

# Extract using shell commands (via ADB if SIM in phone)
extract_sim_adb() {
    echo -e "${BLUE}[*] Attempting SIM extraction via ADB...${NC}"
    
    if ! adb get-state &>/dev/null; then
        echo -e "${YELLOW}[!] No ADB device connected${NC}"
        return 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    # ICCID
    echo -e "${BLUE}[*] Reading ICCID...${NC}"
    adb shell "service call iphonesubinfo 11" | \
        sed 's/.*\([0-9]\{4\}\)\([0-9]\{4\}\)\([0-9]\{4\}\)\([0-9]\{4\}\).*/\1\2\3\4/' > \
        "$OUTPUT_DIR/iccid.txt" 2>/dev/null
    
    # IMSI
    echo -e "${BLUE}[*] Reading IMSI...${NC}"
    adb shell "service call iphonesubinfo 7" | \
        sed 's/.*\([0-9]\{5\}\)\([0-9]\{5\}\)\([0-9]\{5\}\).*/\1\2\3/' > \
        "$OUTPUT_DIR/imsi.txt" 2>/dev/null
    
    # Phone number (MSISDN) - requires Android 11+
    echo -e "${BLUE}[*] Reading phone number...${NC}"
    adb shell "service call iphonesubinfo 13" | \
        sed 's/[^0-9+]//g' > "$OUTPUT_DIR/msisdn.txt" 2>/dev/null
    
    # SIM operator info
    echo -e "${BLUE}[*] Reading operator info...${NC}"
    adb shell getprop gsm.sim.operator.alpha > "$OUTPUT_DIR/operator.txt" 2>/dev/null
    adb shell getprop gsm.sim.operator.numeric >> "$OUTPUT_DIR/operator.txt" 2>/dev/null
    adb shell getprop gsm.sim.operator.iso-country >> "$OUTPUT_DIR/operator.txt" 2>/dev/null
    
    # SIM contacts (if accessible)
    echo -e "${BLUE}[*] Attempting SIM contacts extraction...${NC}"
    adb shell "content query --uri content://icc/adn" > "$OUTPUT_DIR/sim_contacts.txt" 2>/dev/null
    
    # SIM SMS (if accessible)
    echo -e "${BLUE}[*] Attempting SIM SMS extraction...${NC}"
    adb shell "content query --uri content://sms/icc" > "$OUTPUT_DIR/sim_sms.txt" 2>/dev/null
    
    echo -e "${GREEN}[✓] SIM data extraction complete${NC}"
    return 0
}

# Parse and display results
parse_results() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}        SIM CARD DATA SUMMARY${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    if [ -f "$OUTPUT_DIR/iccid.txt" ]; then
        echo -e "${GREEN}ICCID:${NC} $(cat $OUTPUT_DIR/iccid.txt)"
    fi
    
    if [ -f "$OUTPUT_DIR/imsi.txt" ]; then
        echo -e "${GREEN}IMSI:${NC} $(cat $OUTPUT_DIR/imsi.txt)"
    fi
    
    if [ -f "$OUTPUT_DIR/msisdn.txt" ]; then
        local msisdn=$(cat $OUTPUT_DIR/msisdn.txt)
        if [ -n "$msisdn" ]; then
            echo -e "${GREEN}Phone Number:${NC} $msisdn"
        fi
    fi
    
    if [ -f "$OUTPUT_DIR/operator.txt" ]; then
        echo -e "${GREEN}Operator:${NC}"
        cat "$OUTPUT_DIR/operator.txt"
    fi
    
    if [ -f "$OUTPUT_DIR/sim_contacts.txt" ] && [ -s "$OUTPUT_DIR/sim_contacts.txt" ]; then
        local contacts=$(wc -l < "$OUTPUT_DIR/sim_contacts.txt")
        echo -e "${GREEN}SIM Contacts:${NC} $contacts entries"
    fi
    
    if [ -f "$OUTPUT_DIR/sim_sms.txt" ] && [ -s "$OUTPUT_DIR/sim_sms.txt" ]; then
        local sms=$(wc -l < "$OUTPUT_DIR/sim_sms.txt")
        echo -e "${GREEN}SIM SMS:${NC} $sms messages"
    fi
}

# Generate report
generate_report() {
    local report="$OUTPUT_DIR/SIM_REPORT.txt"
    
    cat > "$report" << EOF
============================================
SIM CARD FORENSIC REPORT
============================================
Extraction Date: $(date)
Output Directory: $OUTPUT_DIR

============================================
SIM IDENTIFICATION
============================================
ICCID: $(cat $OUTPUT_DIR/iccid.txt 2>/dev/null)
IMSI: $(cat $OUTPUT_DIR/imsi.txt 2>/dev/null)
Phone: $(cat $OUTPUT_DIR/msisdn.txt 2>/dev/null)
Operator: $(head -1 $OUTPUT_DIR/operator.txt 2>/dev/null)

============================================
DATA SUMMARY
============================================
EOF

    if [ -f "$OUTPUT_DIR/sim_contacts.txt" ] && [ -s "$OUTPUT_DIR/sim_contacts.txt" ]; then
        echo -e "\n=== SIM CONTACTS ===" >> "$report"
        cat "$OUTPUT_DIR/sim_contacts.txt" >> "$report"
    fi
    
    if [ -f "$OUTPUT_DIR/sim_sms.txt" ] && [ -s "$OUTPUT_DIR/sim_sms.txt" ]; then
        echo -e "\n=== SIM SMS ===" >> "$report"
        cat "$OUTPUT_DIR/sim_sms.txt" >> "$report"
    fi
    
    echo ""
    echo -e "${GREEN}[✓] Report saved: $report${NC}"
}

# Main
main() {
    echo -e "${CYAN}"
    cat << "EOF"
  _____ ____  ______  ______  _____ 
 / ___// __ \/ ____/ / ____/ |__  /
 \__ \/ /_/ / /     / __/     /_< 
 ___/ / ____/ /___  / /___ ___/ / 
/____/_/    \____/ /_____//____/  
      Forensic Extractor v2.0
EOF
    echo -e "${NC}"
    
    # Try extraction methods
    if check_reader && check_pcscd; then
        extract_sim_pysim
    fi
    
    extract_sim_adb
    
    parse_results
    generate_report
    
    echo ""
    echo -e "${GREEN}SIM forensics complete.${NC}"
    echo -e "${YELLOW}Output: $OUTPUT_DIR${NC}"
}

main "$@"
