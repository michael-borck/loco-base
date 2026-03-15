#!/bin/bash
# ══════════════════════════════════════════════
# Local Security Audit
# Runs Lynis + custom hardening checks on this machine.
# Usage: sudo ./audit-local.sh [--cron]
#   --cron  Quiet mode: only output if something changed or failed
# ══════════════════════════════════════════════
# No set -e: checks intentionally return non-zero

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="/var/log/security-audit"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname)
CRON_MODE=false

[ "$1" = "--cron" ] && CRON_MODE=true

mkdir -p "$REPORT_DIR"

# Colors (disabled in cron mode)
if [ "$CRON_MODE" = true ]; then
    G=''; Y=''; RED=''; C=''; DIM=''; R=''
else
    G='\033[1;32m'; Y='\033[1;33m'; RED='\033[1;31m'; C='\033[1;36m'; DIM='\033[2m'; R='\033[0m'
fi

PASS="${G}PASS${R}"
WARN="${Y}WARN${R}"
FAIL="${RED}FAIL${R}"

WARNINGS=0
FAILURES=0

check() {
    local label="$1" result="$2" detail="$3"
    if [ "$result" = "PASS" ]; then
        [ "$CRON_MODE" = false ] && echo -e "  $PASS  $label"
    elif [ "$result" = "WARN" ]; then
        echo -e "  $WARN  $label — $detail"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  $FAIL  $label — $detail"
        FAILURES=$((FAILURES + 1))
    fi
}

# ── Header ──
[ "$CRON_MODE" = false ] && echo -e "\n${C}══ Security Audit: ${HOSTNAME} — $(date) ══${R}\n"

# ══════════════════════════════════════════════
# SECTION 1: Custom hardening checks
# ══════════════════════════════════════════════
[ "$CRON_MODE" = false ] && echo -e "${C}── Hardening Checks ──${R}"

# 1. UFW active
if ufw status 2>/dev/null | grep -q "Status: active"; then
    check "UFW firewall active" "PASS"
else
    check "UFW firewall active" "FAIL" "UFW is not active"
fi

# 2. Only SSH open inbound
OPEN_PORTS=$(ufw status 2>/dev/null | grep "ALLOW IN" | grep -v "22/tcp" | head -5)
if [ -z "$OPEN_PORTS" ]; then
    check "No unexpected inbound ports" "PASS"
else
    check "No unexpected inbound ports" "WARN" "Extra rules: $OPEN_PORTS"
fi

# 3. fail2ban running
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    check "fail2ban running" "PASS"
else
    check "fail2ban running" "FAIL" "fail2ban is not active"
fi

# 4. No NOPASSWD sudo
if find /etc/sudoers.d/ -type f ! -name README -exec grep -l 'NOPASSWD' {} \; 2>/dev/null | grep -q .; then
    NOPASSWD_FILES=$(find /etc/sudoers.d/ -type f ! -name README -exec grep -l 'NOPASSWD' {} \;)
    check "No NOPASSWD sudo" "FAIL" "Found in: $NOPASSWD_FILES"
else
    if grep -q 'NOPASSWD' /etc/sudoers 2>/dev/null; then
        check "No NOPASSWD sudo" "FAIL" "Found in /etc/sudoers"
    else
        check "No NOPASSWD sudo" "PASS"
    fi
fi

# 5. Root account locked
ROOT_PW=$(sudo getent shadow root | cut -d: -f2)
if [[ "$ROOT_PW" == "!"* ]] || [[ "$ROOT_PW" == "*" ]]; then
    check "Root account locked" "PASS"
else
    check "Root account locked" "WARN" "Root has a password set"
fi

# 6. SSH root login
ROOT_LOGIN=$(grep -E '^\s*PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
if [ -z "$ROOT_LOGIN" ]; then
    # Default on Ubuntu 22.04 is prohibit-password
    check "SSH root login restricted" "PASS" "(default: prohibit-password)"
elif [ "$ROOT_LOGIN" = "no" ] || [ "$ROOT_LOGIN" = "prohibit-password" ]; then
    check "SSH root login restricted" "PASS"
else
    check "SSH root login restricted" "FAIL" "PermitRootLogin=$ROOT_LOGIN"
fi

# 7. No autologin on TTY
if find /etc/systemd/system/getty@*.service.d/ -name 'override.conf' -exec grep -l 'autologin' {} \; 2>/dev/null | grep -q .; then
    check "No TTY autologin" "WARN" "Autologin is enabled (use toggle-autologin.sh off)"
else
    check "No TTY autologin" "PASS"
fi

# 8. Unattended upgrades
if dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
    check "Unattended upgrades installed" "PASS"
else
    check "Unattended upgrades installed" "FAIL" "Package not installed"
fi

# 9. AppArmor enforcing
AA_PROFILES=$(aa-status 2>/dev/null | grep "profiles are in enforce mode" | awk '{print $1}')
if [ -n "$AA_PROFILES" ] && [ "$AA_PROFILES" -gt 0 ] 2>/dev/null; then
    check "AppArmor enforcing ($AA_PROFILES profiles)" "PASS"
else
    check "AppArmor enforcing" "WARN" "No profiles in enforce mode"
fi

# 10. Listening services check
UNEXPECTED=$(ss -tulnp 2>/dev/null | grep LISTEN | grep -v -E '(127\.0\.0\.(1|53)|::1|:22\b)' | head -5)
if [ -z "$UNEXPECTED" ]; then
    check "No unexpected listening services" "PASS"
else
    check "No unexpected listening services" "WARN" "Found: $(echo "$UNEXPECTED" | awk '{print $5}' | tr '\n' ' ')"
fi

# 11. No world-writable files in /etc
WW_FILES=$(find /etc -xdev -type f -perm -0002 2>/dev/null | head -5)
if [ -z "$WW_FILES" ]; then
    check "No world-writable files in /etc" "PASS"
else
    check "No world-writable files in /etc" "WARN" "$WW_FILES"
fi

# 12. Kernel hardening
ASLR=$(sysctl -n kernel.randomize_va_space 2>/dev/null)
if [ "$ASLR" = "2" ]; then
    check "ASLR enabled (full)" "PASS"
else
    check "ASLR enabled (full)" "FAIL" "randomize_va_space=$ASLR (expected 2)"
fi

SYNCOOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
if [ "$SYNCOOKIES" = "1" ]; then
    check "SYN cookies enabled" "PASS"
else
    check "SYN cookies enabled" "FAIL" "tcp_syncookies=$SYNCOOKIES"
fi

# ══════════════════════════════════════════════
# SECTION 2: Lynis audit
# ══════════════════════════════════════════════
[ "$CRON_MODE" = false ] && echo -e "\n${C}── Lynis Audit ──${R}"

LYNIS_REPORT="$REPORT_DIR/lynis-${HOSTNAME}-${TIMESTAMP}.log"
LYNIS_DATA="$REPORT_DIR/lynis-${HOSTNAME}-${TIMESTAMP}.dat"

lynis audit system --no-colors --quick --logfile "$LYNIS_REPORT" --report-file "$LYNIS_DATA" > /dev/null 2>&1 || true

# Extract score
LYNIS_SCORE=$(grep 'hardening_index=' "$LYNIS_DATA" 2>/dev/null | cut -d= -f2)
LYNIS_WARNINGS=$(grep -c '^warning\[\]=' "$LYNIS_DATA" 2>/dev/null || echo 0)
LYNIS_SUGGESTIONS=$(grep -c '^suggestion\[\]=' "$LYNIS_DATA" 2>/dev/null || echo 0)

if [ -n "$LYNIS_SCORE" ]; then
    if [ "$LYNIS_SCORE" -ge 70 ]; then
        check "Lynis score: ${LYNIS_SCORE}/100" "PASS"
    elif [ "$LYNIS_SCORE" -ge 50 ]; then
        check "Lynis score: ${LYNIS_SCORE}/100" "WARN" "${LYNIS_WARNINGS} warnings, ${LYNIS_SUGGESTIONS} suggestions"
    else
        check "Lynis score: ${LYNIS_SCORE}/100" "FAIL" "${LYNIS_WARNINGS} warnings, ${LYNIS_SUGGESTIONS} suggestions"
    fi
else
    check "Lynis audit" "WARN" "Could not parse score"
fi

[ "$CRON_MODE" = false ] && echo -e "  ${DIM}Full report: ${LYNIS_REPORT}${R}"
[ "$CRON_MODE" = false ] && echo -e "  ${DIM}Data file:   ${LYNIS_DATA}${R}"

# ══════════════════════════════════════════════
# SECTION 3: Drift detection
# ══════════════════════════════════════════════
[ "$CRON_MODE" = false ] && echo -e "\n${C}── Drift Detection ──${R}"

BASELINE="$REPORT_DIR/baseline-${HOSTNAME}.dat"
CURRENT="$REPORT_DIR/current-${HOSTNAME}.dat"

# Generate current state snapshot
{
    echo "# Snapshot $(date -Iseconds)"
    echo "## UFW rules"
    ufw status numbered 2>/dev/null
    echo "## Listening ports"
    ss -tulnp 2>/dev/null | grep LISTEN | sort
    echo "## SSHD config (non-comments)"
    grep -v '^#\|^$' /etc/ssh/sshd_config 2>/dev/null | sort
    echo "## Sudoers.d files"
    ls -la /etc/sudoers.d/ 2>/dev/null
    echo "## Autologin overrides"
    find /etc/systemd/system/getty@*.service.d/ -name '*.conf' -exec cat {} \; 2>/dev/null || echo "none"
    echo "## Installed kernel modules (nvidia)"
    lsmod 2>/dev/null | grep nvidia | sort || echo "none loaded"
    echo "## fail2ban jails"
    fail2ban-client status 2>/dev/null
} > "$CURRENT"

if [ -f "$BASELINE" ]; then
    DRIFT=$(diff "$BASELINE" "$CURRENT" | grep '^[<>]' | grep -v '# Snapshot' | head -20)
    if [ -z "$DRIFT" ]; then
        check "No drift from baseline" "PASS"
    else
        check "Configuration drift detected" "WARN" "Run: diff $BASELINE $CURRENT"
        if [ "$CRON_MODE" = false ]; then
            echo -e "  ${DIM}Changes:${R}"
            diff "$BASELINE" "$CURRENT" | grep '^[<>]' | grep -v '# Snapshot' | head -10 | while read -r line; do
                echo -e "    ${DIM}${line}${R}"
            done
        fi
    fi
else
    cp "$CURRENT" "$BASELINE"
    check "Baseline created" "PASS" "First run — saved to $BASELINE"
fi

# ══════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════
echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}RESULT: ${FAILURES} failure(s), ${WARNINGS} warning(s)${R}"
    exit 2
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${Y}RESULT: ${WARNINGS} warning(s), 0 failures${R}"
    exit 1
else
    echo -e "${G}RESULT: All checks passed${R}"
    exit 0
fi
