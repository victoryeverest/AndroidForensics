# AndroidForensics Enhanced

## 🕵️‍♂️ Advanced Android Device Forensic Toolkit

An enhanced version of the [AndroidForensics](https://github.com/DouglasFreshHabian/AndroidForensics) project by Douglas Habian (Fresh Forensics), with additional forensic capabilities, export formats, and analysis tools.

---

## 🆕 Enhancements Over Original

| Feature | Original | Enhanced |
|---------|----------|----------|
| Error Handling | Basic | Comprehensive with device selection |
| Output Formats | TXT only | TXT, CSV, JSON |
| Hash Verification | ❌ | ✅ SHA-256 + MD5 |
| Case ID Tracking | ❌ | ✅ Full case management |
| WiFi Passwords | ❌ | ✅ Attempted extraction |
| Browser History | ❌ | ✅ Chrome + default browser |
| Timeline Analysis | ❌ | ✅ Chronological event mapping |
| SIM Extraction | ❌ | ✅ Via ADB and USB reader |
| Network ADB Scan | ❌ | ✅ Auto-discovery |
| Forensic Report | ❌ | ✅ Professional report generation |
| Extraction Types | Single | full, quick, user, system |

---

## 📁 Project Structure

```
AndroidForensics_Enhanced/
├── README.md
└── scripts/
    ├── enhanced_extract.sh      # Main extraction tool
    ├── airscope_enhanced.sh     # WiFi radar
    ├── sim_extractor.sh         # SIM card forensics
    └── timeline_analyzer.sh     # Event timeline generator
```

---

## ⚙️ Prerequisites

### Required
```bash
# ADB
sudo apt install android-tools-adb android-tools-fastboot

# Python (for some features)
sudo apt install python3 python3-pip
```

### Optional
```bash
# SIM card extraction
sudo apt install pcscd pcsc-tools
pip install pySim

# Network scanning
sudo apt install nmap netcat
```

---

## 🚀 Quick Start

### Basic Extraction
```bash
chmod +x scripts/*.sh
./scripts/enhanced_extract.sh
```

### With Options
```bash
# Specify case ID and device
./scripts/enhanced_extract.sh -c CASE_2025_001 -d RZ8N1234XYZ

# Quick extraction (device info + user data only)
./scripts/enhanced_extract.sh -t quick

# Include WiFi password extraction
./scripts/enhanced_extract.sh -w

# Scan for network ADB devices
./scripts/enhanced_extract.sh -n
```

### WiFi Scanning
```bash
./scripts/airscope_enhanced.sh
```

### SIM Card Extraction
```bash
./scripts/sim_extractor.sh
```

### Timeline Analysis
```bash
# Auto-detect most recent extraction
./scripts/timeline_analyzer.sh

# Specify input directory
./scripts/timeline_analyzer.sh -i ./forensic_output/CASE_2025_001
```

---

## 📋 Extraction Types

| Type | Description | Duration |
|------|-------------|----------|
| `full` | Complete extraction (default) | 2-5 min |
| `quick` | Device info + user data | 30-60 sec |
| `user` | User data + apps + browser | 1-2 min |
| `system` | System diagnostics + security | 1-2 min |

---

## 📂 Output Structure

```
forensic_output/CASE_ID/
├── raw/                    # Raw extraction files
│   ├── device_info.txt
│   ├── contacts.txt
│   ├── call_logs.txt
│   ├── sms.txt
│   ├── wifi_config.txt
│   └── ...
├── csv/                    # CSV exports
│   ├── contacts.csv
│   ├── call_logs.csv
│   └── packages.csv
├── json/                   # JSON exports
│   ├── device_info.json
│   ├── emails.json
│   └── packages.json
├── reports/                # Forensic reports
│   ├── FORENSIC_REPORT.txt
│   └── integrity_hashes.txt
└── logs/                   # Execution logs
```

---

## 🔐 Data Extracted

### Device Information
- Model, manufacturer, serial number
- Android version, API level, build fingerprint
- IMEI, phone number
- Uptime, battery status

### User Data
- Contacts (names + numbers)
- Call logs (incoming/outgoing/missed)
- SMS messages
- Calendar events
- Registered accounts
- Email addresses

### Applications
- All installed packages
- Third-party packages
- Running services
- Recent tasks
- Usage statistics

### Network
- WiFi configuration & scan results
- Network interfaces
- Connectivity status
- Bluetooth paired devices
- DNS configuration

### Browser Data
- Chrome history (if accessible)
- Default browser history
- Bookmarks
- Download history

### System
- System logs (logcat)
- Memory information
- Battery statistics
- Location history
- Notifications
- Sensors

### Security
- Lock screen settings
- Fingerprint configuration
- Trust agents (Smart Lock)
- Device administrators
- Certificates

### Hidden
- Android secret codes
- Clipboard contents
- Alarm history

---

## 📊 Timeline Analysis

The timeline analyzer creates a chronological map of device activity:

```
2025-01-15 08:30:22|SMS    |Sent        |+1234567890|Hey, how are you?
2025-01-15 09:15:03|CALL   |Incoming    |+1987654321|Duration: 120s
2025-01-15 10:22:45|NOTIF  |WhatsApp    |New message|
2025-01-15 11:30:00|USAGE  |com.instagram|App used|
2025-01-15 14:22:11|LOC    |GPS         |40.7128,-74.0060|
```

---

## 🔒 Integrity Verification

All extracted files include cryptographic hashes:

```bash
# Verify integrity
sha256sum -c reports/integrity_hashes.txt

# View hashes
cat reports/integrity_hashes.txt
```

---

## 📝 Forensic Report

Each extraction generates a professional forensic report including:

- Case information
- Device identification
- Extraction manifest
- Chain of custody section
- Integrity verification
- Legal notice

---

## ⚖️ Legal Notice

This toolkit is for **authorized forensic investigations only**.

- Ensure compliance with local laws
- Obtain proper authorization before extraction
- Handle extracted data securely
- Maintain chain of custody
- Document all actions

---

## 🤝 Credits

- **Original Project**: [AndroidForensics](https://github.com/DouglasFreshHabian/AndroidForensics) by Douglas Habian (Fresh Forensics, LLC)
- **Enhanced Version**: Community contributions

---

## 📜 License

MIT License - See LICENSE file for details.

---

## 📧 Contact

- Original Author: Douglas Habian (freshforensicsllc@tuta.com)
- GitHub: github.com/DouglasFreshHabian

- Victory: wifieast@gmail.com
- GitHub: https://github.com/victoryeverest/

---

## 🙏 Support the Original Author

If this tool helps your investigations, consider supporting continued development:

[Buy Me A Coffee](https://www.buymeacoffee.com/dfreshZ)
