#!/bin/bash
# ══════════════════════════════════════════════
# Set up cron jobs for security monitoring
# Usage: sudo ./setup-cron.sh
# ══════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Run with: sudo $0"
    exit 1
fi

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

CRON_FILE="/etc/cron.d/security-audit"

cat > "$CRON_FILE" <<EOF
# Security audit — runs daily at 3am, logs only warnings/failures
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Local audit daily at 3:00 AM
0 3 * * * root ${SCRIPT_DIR}/audit-local.sh --cron >> /var/log/security-audit/cron.log 2>&1

# Remote scan weekly on Sunday at 4:00 AM (only if hosts.txt has entries)
0 4 * * 0 root [ -s ${SCRIPT_DIR}/hosts.txt ] && grep -v '^\#' ${SCRIPT_DIR}/hosts.txt | grep -q . && ${SCRIPT_DIR}/audit-remote.sh >> /var/log/security-audit/cron.log 2>&1

# Lynis full audit weekly on Saturday at 3:00 AM
0 3 * * 6 root lynis audit system --no-colors --quick --logfile /var/log/security-audit/lynis-weekly.log --report-file /var/log/security-audit/lynis-weekly.dat > /dev/null 2>&1
EOF

chmod 644 "$CRON_FILE"
ok "Cron jobs installed at ${CRON_FILE}"

# Set up log rotation
cat > /etc/logrotate.d/security-audit <<'EOF'
/var/log/security-audit/*.log {
    weekly
    rotate 12
    compress
    missingok
    notifempty
}
EOF

ok "Log rotation configured (12 weeks)"

echo ""
echo "  Schedule:"
echo "    Daily 3:00 AM  — local audit (warnings/failures only)"
echo "    Weekly Sun 4AM — remote port scan (if hosts.txt populated)"
echo "    Weekly Sat 3AM — full Lynis audit"
echo ""
echo "  Logs: /var/log/security-audit/"
echo "  Edit: $CRON_FILE"
