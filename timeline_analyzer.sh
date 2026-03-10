#!/bin/bash
# ================================================
#   Android Timeline Analyzer
#   Creates chronological timeline from forensic data
# ================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INPUT_DIR=""
OUTPUT_FILE="timeline_analysis.txt"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Convert Unix timestamp to readable format
convert_timestamp() {
    local ts="$1"
    if [[ "$ts" =~ ^[0-9]+$ ]]; then
        # Milliseconds or seconds?
        if [ ${#ts} -gt 10 ]; then
            ts=$((ts / 1000))
        fi
        date -d "@$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null
    fi
}

# Parse SMS timestamps
parse_sms() {
    local sms_file="$INPUT_DIR/raw/sms.txt"
    
    if [ ! -f "$sms_file" ]; then
        return
    fi
    
    echo -e "${BLUE}[*] Parsing SMS messages...${NC}"
    
    grep "date=" "$sms_file" | while read line; do
        local ts=$(echo "$line" | grep -oP 'date=\K[0-9]+')
        local addr=$(echo "$line" | grep -oP 'address=\K[^,]+' | head -1)
        local type=$(echo "$line" | grep -oP 'type=\K[0-9]+')
        local body=$(echo "$line" | grep -oP 'body=\K.*' | cut -c1-50)
        
        if [ -n "$ts" ]; then
            local dt=$(convert_timestamp "$ts")
            local direction="Received"
            [ "$type" = "2" ] && direction="Sent"
            
            echo "$dt|SMS|$direction|$addr|$body"
        fi
    done
}

# Parse call logs
parse_calls() {
    local calls_file="$INPUT_DIR/raw/call_logs.txt"
    
    if [ ! -f "$calls_file" ]; then
        return
    fi
    
    echo -e "${BLUE}[*] Parsing call logs...${NC}"
    
    grep "date=" "$calls_file" | while read line; do
        local ts=$(echo "$line" | grep -oP 'date=\K[0-9]+')
        local num=$(echo "$line" | grep -oP 'number=\K[^,]+' | head -1)
        local type=$(echo "$line" | grep -oP 'type=\K[0-9]+')
        local dur=$(echo "$line" | grep -oP 'duration=\K[0-9]+')
        
        if [ -n "$ts" ]; then
            local dt=$(convert_timestamp "$ts")
            local ctype="Unknown"
            case "$type" in
                1) ctype="Incoming" ;;
                2) ctype="Outgoing" ;;
                3) ctype="Missed" ;;
                4) ctype="Voicemail" ;;
                5) ctype="Rejected" ;;
                6) ctype="Blocked" ;;
            esac
            
            echo "$dt|CALL|$ctype|$num|Duration: ${dur}s"
        fi
    done
}

# Parse notifications
parse_notifications() {
    local notif_file="$INPUT_DIR/raw/notifications.txt"
    
    if [ ! -f "$notif_file" ]; then
        return
    fi
    
    echo -e "${BLUE}[*] Parsing notifications...${NC}"
    
    grep -E "postTime|when=" "$notif_file" | while read line; do
        local ts=$(echo "$line" | grep -oP '(postTime|when)=\K[0-9]+')
        
        if [ -n "$ts" ]; then
            local dt=$(convert_timestamp "$ts")
            local pkg=$(echo "$line" | grep -oP 'pkg=\K[^,]+' | head -1)
            local title=$(echo "$line" | grep -oP 'title=\K[^,]+' | cut -c1-30)
            
            echo "$dt|NOTIF|$pkg|$title|"
        fi
    done
}

# Parse app usage stats
parse_usage_stats() {
    local usage_file="$INPUT_DIR/raw/usage_stats.txt"
    
    if [ ! -f "$usage_file" ]; then
        return
    fi
    
    echo -e "${BLUE}[*] Parsing usage statistics...${NC}"
    
    grep -E "lastTimeUsed|lastEventTime" "$usage_file" | while read line; do
        local ts=$(echo "$line" | grep -oP '(lastTimeUsed|lastEventTime)=\K[0-9]+')
        
        if [ -n "$ts" ] && [ "$ts" != "0" ]; then
            local dt=$(convert_timestamp "$ts")
            local pkg=$(echo "$line" | grep -oP 'packageName=\K[^,}]+' | head -1)
            
            echo "$dt|USAGE|$pkg|App used|"
        fi
    done
}

# Parse location data
parse_location() {
    local loc_file="$INPUT_DIR/raw/location.txt"
    
    if [ ! -f "$loc_file" ]; then
        return
    fi
    
    echo -e "${BLUE}[*] Parsing location data...${NC}"
    
    grep -E "lastLocation|Last Known Location" -A 10 "$loc_file" | \
    grep -E "latitude|longitude|time=" | while read line; do
        local lat=$(echo "$line" | grep -oP 'latitude=\K[0-9.-]+')
        local lon=$(echo "$line" | grep -oP 'longitude=\K[0-9.-]+')
        local ts=$(echo "$line" | grep -oP 'time=\K[0-9]+')
        
        if [ -n "$lat" ] && [ -n "$lon" ]; then
            local dt=$(convert_timestamp "$ts")
            echo "$dt|LOC|GPS|$lat,$lon|"
        fi
    done
}

# Parse battery stats for charging events
parse_battery() {
    local battery_file="$INPUT_DIR/raw/batterystats.txt"
    
    if [ ! -f "$battery_file" ]; then
        return
    fi
    
    echo -e "${BLUE}[*] Parsing battery events...${NC}"
    
    grep -E "charge|plug|unplug" "$battery_file" | while read line; do
        local ts=$(echo "$line" | grep -oP '[0-9]{10,}')
        
        if [ -n "$ts" ]; then
            local dt=$(convert_timestamp "$ts")
            local event="Power Event"
            echo "$line" | grep -qi "charge\|plug" && event="Charging Started"
            echo "$line" | grep -qi "unplug" && event="Charging Stopped"
            
            echo "$dt|POWER|$event||"
        fi
    done
}

# Parse WiFi connections
parse_wifi() {
    local wifi_file="$INPUT_DIR/raw/wifi_config.txt"
    
    if [ ! -f "$wifi_file" ]; then
        return
    fi
    
    echo -e "${BLUE}[*] Parsing WiFi events...${NC}"
    
    grep -E "connection|SSID|connect" "$wifi_file" | while read line; do
        local ssid=$(echo "$line" | grep -oP 'SSID: \K[^,}]+')
        
        if [ -n "$ssid" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S')|WIFI|Connected|$ssid|"
        fi
    done
}

# Generate timeline report
generate_report() {
    local temp_file=$(mktemp)
    
    # Collect all events
    parse_sms >> "$temp_file"
    parse_calls >> "$temp_file"
    parse_notifications >> "$temp_file"
    parse_usage_stats >> "$temp_file"
    parse_location >> "$temp_file"
    parse_battery >> "$temp_file"
    parse_wifi >> "$temp_file"
    
    # Sort by timestamp
    sort -t'|' -k1 "$temp_file" > "$OUTPUT_FILE"
    rm "$temp_file"
    
    # Create detailed report
    local detailed_report="${OUTPUT_FILE%.txt}_detailed.txt"
    
    cat > "$detailed_report" << EOF
============================================
ANDROID DEVICE TIMELINE ANALYSIS
============================================
Generated: $(date)
Source: $INPUT_DIR

============================================
LEGEND
============================================
SMS     - Text messages
CALL    - Phone calls
NOTIF   - Notifications
USAGE   - App usage events
LOC     - Location data
POWER   - Power/battery events
WIFI    - WiFi connections

============================================
TIMELINE (Chronological)
============================================

EOF
    
    # Add formatted timeline
    cat "$OUTPUT_FILE" | awk -F'|' '
    function get_color(type) {
        if (type == "SMS") return "\033[1;32m"
        if (type == "CALL") return "\033[1;33m"
        if (type == "NOTIF") return "\033[1;34m"
        if (type == "USAGE") return "\033[1;35m"
        if (type == "LOC") return "\033[1;36m"
        if (type == "POWER") return "\033[1;31m"
        if (type == "WIFI") return "\033[1;37m"
        return "\033[0m"
    }
    {
        printf "%s %-8s %s %-15s %s %s %s\n", $1, $2, get_color($2), $3, "\033[0m", $4, $5
    }
    ' >> "$detailed_report"
    
    # Add statistics
    cat >> "$detailed_report" << EOF

============================================
STATISTICS
============================================
EOF
    
    echo "Total Events: $(wc -l < "$OUTPUT_FILE")" >> "$detailed_report"
    echo "" >> "$detailed_report"
    echo "By Type:" >> "$detailed_report"
    cut -d'|' -f2 "$OUTPUT_FILE" | sort | uniq -c | sort -rn >> "$detailed_report"
    
    echo "" >> "$detailed_report"
    echo "Date Range:" >> "$detailed_report"
    echo "  First Event: $(head -1 "$OUTPUT_FILE" | cut -d'|' -f1)" >> "$detailed_report"
    echo "  Last Event:  $(tail -1 "$OUTPUT_FILE" | cut -d'|' -f1)" >> "$detailed_report"
    
    echo -e "${GREEN}[✓] Timeline saved: $OUTPUT_FILE${NC}"
    echo -e "${GREEN}[✓] Detailed report: $detailed_report${NC}"
}

# Display summary
display_summary() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}        TIMELINE ANALYSIS SUMMARY${NC}"
    echo -e "${CYAN}============================================${NC}"
    
    if [ -f "$OUTPUT_FILE" ]; then
        echo ""
        echo -e "${YELLOW}Total Events: $(wc -l < "$OUTPUT_FILE")${NC}"
        echo ""
        echo -e "${YELLOW}By Type:${NC}"
        cut -d'|' -f2 "$OUTPUT_FILE" | sort | uniq -c | sort -rn | \
            awk '{printf "  %s%-10s%s %d\n", "\033[32m", $2, "\033[0m", $1}'
        
        echo ""
        echo -e "${YELLOW}Date Range:${NC}"
        echo -e "  First: ${GREEN}$(head -1 "$OUTPUT_FILE" | cut -d'|' -f1)${NC}"
        echo -e "  Last:  ${GREEN}$(tail -1 "$OUTPUT_FILE" | cut -d'|' -f1)${NC}"
        
        echo ""
        echo -e "${YELLOW}Recent Events:${NC}"
        tail -10 "$OUTPUT_FILE" | awk -F'|' '{printf "  %s | %-6s | %s\n", $1, $2, $3}'
    fi
}

# Main
main() {
    if [ -z "$INPUT_DIR" ]; then
        # Try to find the most recent extraction
        INPUT_DIR=$(ls -dt ./AndroidForensics_* 2>/dev/null | head -1)
        
        if [ -z "$INPUT_DIR" ]; then
            echo -e "${RED}[ERROR] No input directory specified${NC}"
            echo "Usage: $0 -i <input_directory> [-o <output_file>]"
            exit 1
        fi
        
        echo -e "${YELLOW}[*] Using most recent extraction: $INPUT_DIR${NC}"
    fi
    
    echo -e "${CYAN}"
    cat << "EOF"
  _____ _      _     _______    _    _               _   
 |_   _(_) ___| | __| |_   _|__| | _| |__   ___  ___| |_ 
   | | | |/ __| |/ / __| | |/ __| |/ / '_ \ / _ \/ __| __|
   | | | | (__|   <\__ \ | | (__|   <| |_) |  __/ (__| |_ 
   |_| |_|\___|_|\_\___/ |_|\___|_|\_\_.__/ \___|\___|\__|
                    Analyzer v2.0
EOF
    echo -e "${NC}"
    
    generate_report
    display_summary
}

main "$@"
