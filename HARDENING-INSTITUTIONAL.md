# Security Hardening Report — LocoLab Fleet

**Platform:** Ubuntu 22.04 LTS minimal server (headless, no GUI)
**Role:** GPU compute nodes — non-production teaching and research sandbox
**Operating model:** All nodes run headless. No monitor or keyboard is attached during normal operation. All administration is performed remotely via SSH. A keyboard and monitor are connected only for crash recovery or initial BIOS configuration.
**Date:** 2026-03-18

---

## 0. Environment context

This section summarises the environment boundaries relevant to interpreting the controls below. Full details are in the covering Solution Design document.

### 0.1 Network position

All nodes are connected via Ethernet to the Curtin internal campus network on a dedicated VLAN (low-security tier). No node has a public IP address or is exposed to the public internet.

### 0.2 Traffic profile

| Direction | Permitted | Purpose |
|-----------|-----------|---------|
| **Inbound** | SSH (port 22/tcp) | Remote administration from Curtin network / VPN |
| **Inbound** | HTTPS (port 443/tcp) | Internal access to prototype web applications (where enabled) |
| **Outbound** | HTTPS / HTTP | OS and package updates only |

No other inbound or outbound traffic is required.

### 0.3 Data classification

**Classification:** Internal

All data on these nodes is non-critical and reproducible. No personally identifiable information (PII) is stored or processed. Any identifiers used are synthetic and for teaching or demonstration purposes only. No integration exists with Curtin SSO, identity systems, or authoritative data sources.

### 0.4 Backup and recovery

No central backup service from DTS is required. All data (model weights, configuration, experimental results) can be regenerated from public sources and version-controlled repositories. In the event of a compromised or failed node, the standard recovery procedure is a clean OS reinstall using the lab's automated provisioning tooling, followed by re-download of models and data.

### 0.5 Administration model

The environment is self-maintained by the academic owner (Dr Michael Borck). As the lab grows, additional team members (staff and research students) will be onboarded with individual named accounts and SSH key pairs. Each operator has their own account — there is no shared administrative credential. The sudo privilege model (section 1.6) ensures all privileged actions are attributable to a named user regardless of team size.

---

## 1. Measures implemented

### 1.1 Firewall (UFW)

**What:** UFW is enabled with a default-deny inbound policy. SSH (port 22/tcp) and HTTPS (port 443/tcp, where a prototype web application is running) are allowed inbound. Outbound traffic is permitted for OS and package updates.

**Why:** Prevents any service accidentally exposed on the network from being reachable. Only SSH and HTTPS are required for administration and internal user access to prototype applications.

**Current rules:**
```
Default: deny (incoming), allow (outgoing), disabled (routed)
22/tcp     ALLOW IN    Anywhere
443/tcp    ALLOW IN    Anywhere    (on nodes running web applications)
```

### 1.2 SSH brute-force protection (fail2ban)

**What:** fail2ban is enabled with the `sshd` jail active, using the systemd backend.

**Why:** Automatically bans IP addresses after repeated failed SSH login attempts, mitigating brute-force and credential-stuffing attacks.

**Config:** `/etc/fail2ban/jail.local`
```ini
[sshd]
enabled = true
backend = systemd
```

Default ban policy: 10-minute ban after 5 failures within 10 minutes.

### 1.3 Minimal install / reduced attack surface

**What:** All machines are installed as minimal Ubuntu Server with no desktop environment, window manager, or X11 session. No web servers, database servers, or other network-facing services are installed.

**Why:** Every installed package and running service is a potential attack vector. A headless workstation with only SSH exposed has a very small attack surface.

**Listening services (verified):**
| Port | Service | Binding | Purpose |
|------|---------|---------|---------|
| 22/tcp | sshd | 0.0.0.0 + [::] | Remote administration (Curtin network / VPN only) |
| 443/tcp | Application server | 0.0.0.0 (where enabled) | Prototype web applications (Curtin network / VPN only) |
| 53/udp+tcp | systemd-resolved | 127.0.0.53 (loopback only) | Local DNS resolution |
| 68/udp | DHCP client | link-local | Network address assignment |
| 546/udp | DHCPv6 client | link-local | IPv6 address assignment |

No other ports are open. Access is restricted to the Curtin internal network by VLAN placement — no public internet exposure.

### 1.4 Automatic security updates

**What:** `unattended-upgrades` is installed and enabled. All machines automatically download and install security updates daily.

**Why:** Ensures critical security patches (kernel, OpenSSL, SSH, etc.) are applied without manual intervention.

**Config:** `/etc/apt/apt.conf.d/20auto-upgrades`
```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

### 1.5 AppArmor

**What:** AppArmor is loaded and enforcing with Ubuntu default profiles active. Covers NetworkManager DHCP helpers and other system components.

**Why:** Mandatory Access Control (MAC) that confines programs to a limited set of resources, reducing the impact of a compromised process.

### 1.6 Privilege escalation model (sudo)

**What:** Operator accounts use standard `sudo` with password authentication for all privileged operations. Direct root login is not used. The root account has no password set (Ubuntu default) — `su` to root is not possible.

**Why:** sudo provides per-command privilege escalation with an audit trail in the systemd journal. Every privileged command is logged with the invoking user, timestamp, and command. This is preferable to shared root access because:
- Accountability: actions are tied to a named user, not a generic root session
- Least privilege: users operate unprivileged by default
- Auditability: `sudo` invocations are logged via syslog/journal

### 1.7 Console authentication

**What:** The physical console (TTY) requires standard username/password authentication. There is no automatic login.

**Why:** Anyone with physical access must authenticate before obtaining a shell. Physical access controls are not a substitute for authentication.

### 1.8 Root login disabled

**What:** Direct root login is blocked at multiple levels:
- **SSH:** `PermitRootLogin` defaults to `prohibit-password` (Ubuntu 22.04). No SSH key is deployed for root, so root SSH access is effectively impossible.
- **Console:** The root account has no password set (Ubuntu default `!` in `/etc/shadow`). `su - root` is not possible.
- **All administration** is performed via `sudo` from the operator's named account.

**Why:** Disabling direct root access ensures all privileged actions pass through sudo's audit logging. There is no shared root credential that could be leaked or brute-forced.

### 1.9 Kernel hardening (Ubuntu defaults)

The following kernel parameters are set to secure defaults (Ubuntu 22.04 ships these):

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `kernel.randomize_va_space` | 2 | Full ASLR — randomises stack, heap, mmap, VDSO |
| `net.ipv4.tcp_syncookies` | 1 | SYN flood protection |
| `net.ipv4.conf.all.rp_filter` | 2 | Reverse path filtering (loose mode) |
| `net.ipv4.icmp_echo_ignore_broadcasts` | 1 | Ignore broadcast pings (smurf attack prevention) |
| `net.ipv4.conf.all.accept_source_route` | 0 | Reject source-routed packets |
| `net.ipv4.conf.all.send_redirects` | 1 | See section 3.3 |
| `net.ipv4.conf.all.accept_redirects` | 0 | Reject ICMP redirects |

---

## 2. Trade-offs and known deviations

### 2.1 Secure Boot is disabled

**What:** Secure Boot is disabled in BIOS on all GPU nodes to allow the NVIDIA proprietary kernel module (DKMS) to load.

**Why it is necessary:** The NVIDIA driver installs a kernel module via DKMS. With Secure Boot enabled, the module must be signed with a Machine Owner Key (MOK), which requires interactive enrolment at the UEFI console on each kernel update. On headless workstations managed remotely, this is impractical — a failed MOK enrolment bricks GPU support until someone is physically present.

**Risk:** Without Secure Boot, the boot chain is not cryptographically verified. A threat actor with physical access could modify the bootloader or kernel. This is accepted because:
- Machines are on a private network
- Physical access is controlled
- The threat model prioritises remote attacks over physical tampering

### 2.2 SSH is key-only (password authentication disabled)

**What:** SSH password authentication is disabled at installation. Only public key authentication is accepted. Each operator's key is deployed during provisioning.

**Config:** `/etc/ssh/sshd_config`
```
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
```

**Recovery path:** If an operator's key is lost, recovery requires physical console access (keyboard and monitor) to add a new key. This is acceptable given the headless operating model — physical access is available on campus for break-glass scenarios.

---

## 3. Measures considered but not implemented

### 3.1 SSH port change (e.g. move to non-standard port)

**Why not:** Security through obscurity. Does not stop targeted attacks, only reduces log noise from automated scanners. fail2ban handles brute-force attempts effectively. Changing the port complicates documentation and tooling for minimal benefit.

### 3.2 auditd (Linux Audit Framework)

**Why not:** auditd provides detailed syscall-level logging useful for forensics and compliance auditing (PCI-DSS, HIPAA, etc.). It generates significant log volume and requires active review or a SIEM to be useful. For workstations not handling regulated data, fail2ban + systemd journal provide sufficient logging. Can be enabled later if compliance requirements change.

### 3.3 Additional sysctl hardening

**What could be done:**
```bash
net.ipv4.conf.all.send_redirects = 0    # Currently 1 (Ubuntu default)
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
kernel.sysrq = 0
```

**Why not:** The machines are not routers — ICMP redirect sending is low-risk on an endpoint. Martian logging is useful for network debugging but noisy in normal operation. These can be applied via `/etc/sysctl.d/99-hardening.conf` if the threat model tightens.

### 3.4 Disk encryption (LUKS)

**Why not:** Must be configured at install time (or requires significant repartitioning). On headless machines, LUKS requires entering a passphrase at boot via console (or configuring network-based unlock via Clevis/Tang), which adds operational complexity. If machines store sensitive data, this should be revisited.

### 3.5 CIS Benchmark / full hardening profile

**Why not:** The CIS Ubuntu 22.04 benchmark includes ~250 checks covering everything from filesystem mount options to cron permissions. Many controls target multi-user servers or GUI workstations and are not applicable to single-user headless machines. Individual controls from CIS can be adopted as needed.

### 3.6 Intrusion detection (AIDE, rkhunter, chkrootkit)

**Why not:** File integrity monitoring (AIDE) and rootkit scanners are valuable on internet-facing servers. On internal workstations with SSH as the only entry point, protected by fail2ban and UFW, the risk is lower. Can be added if machine exposure changes.

### 3.7 Idle session timeout

**Why not:** SSH sessions could be configured with `ClientAliveInterval` / `ClientAliveCountMax` in sshd_config, but this can disrupt long-running interactive work (compilation, training jobs, etc.). The small number of named operators and key-only SSH access means unattended session risk is low.

### 3.8 Login banner / legal warning

**What:** A pre-authentication banner (`/etc/issue.net` + `Banner` in sshd_config) warning that unauthorised access is prohibited.

**Why not:** No legal or compliance requirement has been identified. Can be added trivially if needed:
```bash
echo "Authorized use only. All activity is monitored." | sudo tee /etc/issue.net
# Add to /etc/ssh/sshd_config: Banner /etc/issue.net
```

---

## 4. Ongoing security monitoring

Security hardening is not a one-time activity. The lab uses a tiered monitoring approach to detect drift, new vulnerabilities, and unexpected changes across all machines.

### Tier 1 — Automated auditing (current)

Lightweight, script-based monitoring that runs on each machine with no additional infrastructure.

**Local audit:**
- Runs custom hardening checks: firewall state, fail2ban, sudo configuration, root account, SSH config, listening ports, world-writable files, kernel hardening (ASLR, SYN cookies)
- Runs a full [Lynis](https://cisofy.com/lynis/) security audit (300+ checks) and reports the hardening score
- Drift detection: snapshots firewall rules, listening ports, SSH config, and sudoers state. Compares against a saved baseline and flags any changes
- Cron: runs daily at 3:00 AM. Only produces output on warnings or failures

**Remote scan:**
- Port scans all lab machines from the outside using nmap (TCP + UDP)
- Flags any open port that is not SSH (port 22)
- Drift detection: compares open ports against previous scan and alerts on newly opened ports
- Cron: runs weekly (Sunday 4:00 AM) from a designated scanner host

**Lynis weekly audit:**
- Full Lynis system audit runs weekly (Saturday 3:00 AM)
- Produces a hardening score (0–100) and detailed findings
- Reports stored in `/var/log/security-audit/` with 12-week log rotation

### Tier 2 — Centralised SIEM (future option)

If compliance requirements grow or the lab expands, [Wazuh](https://wazuh.com/) (open source, free) can be deployed as a centralised security platform:

| Component | Where it runs | Resources | What it does |
|-----------|---------------|-----------|--------------|
| Wazuh Server + Indexer + Dashboard | One dedicated machine or VM | ~2–4 GB RAM | Collects and indexes events, web dashboard |
| Wazuh Agent | Each lab machine | ~35–50 MB RAM idle | File integrity monitoring, vulnerability scanning, log analysis, rootkit detection |

**What Wazuh adds over Tier 1:**
- **File integrity monitoring (FIM):** Alerts when system files (`/etc/passwd`, `/etc/ssh/sshd_config`, binaries) are modified unexpectedly
- **Vulnerability detection:** Cross-references installed packages against CVE databases
- **Real-time intrusion detection:** Analyses logs for attack patterns (not just SSH brute force)
- **Compliance reporting:** PCI-DSS, HIPAA, CIS benchmark dashboards out of the box
- **Centralised dashboard:** Single view across all lab machines
- **Active response:** Can automatically block IPs or kill processes on detection

**When to move to Tier 2:**
- The lab grows beyond current fleet size
- Compliance or audit requirements mandate a SIEM
- The organisation requires centralised log retention
- Real-time alerting (email/Slack) is needed on security events

Tier 1 and Tier 2 are complementary — the local audit scripts continue to work alongside Wazuh and serve as an independent verification layer.

---

## 5. Summary

| Control | Status | Notes |
|---------|--------|-------|
| Firewall (UFW) | Active | Deny all inbound except SSH and HTTPS |
| fail2ban | Active | SSH jail, systemd backend |
| Minimal install | Yes | No GUI, no unnecessary services |
| Automatic security updates | Active | unattended-upgrades |
| AppArmor | Enforcing | Ubuntu default profiles |
| Sudo with password | Enforced | All admin via sudo, password required |
| Root login | Disabled | No root password, no root SSH key |
| Console authentication | Enforced | Password required at physical console |
| Secure Boot | Disabled | Required for NVIDIA DKMS (see 2.1) |
| SSH key-only auth | Enforced | Password authentication disabled at installation (see 2.2) |
| Kernel ASLR | Enabled | `randomize_va_space = 2` |
| SYN cookies | Enabled | TCP flood protection |
| ICMP broadcast ignore | Enabled | Smurf attack prevention |
| Disk encryption | Not configured | Would require reinstall (see 3.4) |
| auditd | Not configured | Not required for current use case (see 3.2) |
