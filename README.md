# LocoBase

Core setup kit for the LocoLab Ubuntu 22.04 LTS workstations. Installs NVIDIA drivers, CUDA toolkit, Ollama, Docker, branded boot splash, MOTD with ASCII art, tmux dashboard, custom bash prompt, and security hardening.

All scripts are **idempotent** — re-running fixes drift, installs anything missing, and skips what's already correct. A separate `reset.sh` can strip a machine back to minimal server state for a clean start.

This is the **foundation layer** — individual loco-* projects (loco-bench, loco-llm, loco-convoy, loco-ensayo) have their own setup scripts that build on top of this base.

## Quick start (fresh install)

```bash
# 1. Install Ubuntu 22.04 LTS (minimised server)
# 2. Log in and run:
sudo apt install git
git clone https://github.com/<your-user>/loco-base.git
cd loco-base
sudo -E bash install.sh
```

The installer is menu-driven — it will:
1. Ask you to select a machine name (or enter a custom one)
2. Show the main workflow menu (Fresh Install, Fix Drift, Reset, Post-Install, Individual Script)
3. Run everything with sensible defaults — no config file editing required

After install, reboot and verify:
```bash
sudo reboot
# after reboot:
bash ~/loco-base/verify.sh
```

## Lab machines

| Machine | Name (Spanish) | Emoji | Role |
|---------|---------------|-------|------|
| burro | donkey | 🫏 | Retired (art retained) |
| cerebro | brain | 🧠 | Education platform (RTX 2060 Super 8GB) |
| colmena | beehive | 🐝 | Benchmarking + multi-GPU + fine-tuning (8-GPU chassis) |
| hormiga | ant | 🐜 | Reference floor node (GTX 1050 Ti 4GB) |
| mesa | table | 🪑 | Staging node art (legacy name) |
| pulpo | octopus | 🐙 | Overflow, GPU onboarding/testing (RTX 3060 12GB) |
| tortuga | turtle | 🐢 | Legacy benchmarking (8-GPU chassis) |

Machine selection drives the emoji, bash prompt, Plymouth splash, MOTD header, and ASCII art automatically via a built-in lookup table. Custom machine names are also supported.

## What it does

| Script | Description |
|--------|-------------|
| `01-packages.sh` | Installs all tools: tmux, htop, btop, cmatrix, cbonsai, pipes.sh, asciiquarium, toilet, figlet, neofetch, nmon, tty-clock, lm-sensors, fancontrol, etc. |
| `02-nvidia.sh` | Installs NVIDIA drivers (configurable version). Skips if correct version already running. Detects Secure Boot and warns if enabled. |
| `03-plymouth.sh` | Generates a boot splash PNG from the machine name using toilet/figlet and installs it as a Plymouth theme. Skips if already active. |
| `04-motd.sh` | Custom MOTD with figlet header, random ASCII art from `ascii-art/<machine>/`, GPU/CPU/memory/disk/uptime stats. Disables all default Ubuntu MOTD messages. |
| `05-grub.sh` | Sets `quiet splash` in GRUB for Plymouth. |
| `06-autologin.sh` | Configures systemd autologin on a TTY. |
| `07-dashboard.sh` | Creates a tmux dashboard script with configurable panes (including multi-command rotation) and hooks it into `.bash_profile` to auto-launch on the autologin TTY. |
| `08-prompt.sh` | Sets a two-line bash prompt with machine emoji, name, path, and git branch. Uses marker blocks for safe re-runs. |
| `09-harden.sh` | Enables UFW (deny incoming, allow SSH) and fail2ban (systemd backend). |
| `10-ai-stack.sh` | Installs CUDA 12.4 toolkit, Ollama, Docker (+ NVIDIA Container Toolkit), Node.js LTS, HuggingFace CLI. |

## Workflows

### Fresh Install / Fix Drift

Options 1 and 2 on the main menu both run the full install sequence. Since all scripts are idempotent, re-running fixes drift without duplicating or corrupting configs.

### Full Reset

Option 3 runs `reset.sh` — strips the machine to minimal Ubuntu 22.04 server state:
- Removes all loco-base artifacts (Plymouth, MOTD, dashboard, prompt, autologin, sudoers, fail2ban)
- Purges desktop environments and display managers
- Removes snap and flatpak
- Disables unnecessary services
- Never touches: SSH, kernel, networking, sudo, or apt itself

### Post-Install Setup

Option 4 opens a submenu for optional configuration after the base install:

| Option | Description |
|--------|-------------|
| GitHub & SSH key setup | Authenticates `gh`, generates/uploads SSH key, switches repo to SSH, saves token to `~/.env.keys` |
| Install Claude Code | Installs Claude Code CLI, optionally saves Anthropic API key to `~/.env.keys` |
| Configure dashboard | Interactive tool to change panes, layout, and rotation interval |
| Update MOTD art | Re-copies art from `ascii-art/<machine>/` and regenerates MOTD |
| Fan curve setup | Runs `sensors-detect` + `pwmconfig` to configure fan curves, enables `fancontrol` service |

### Run Individual Script

Option 5 lets you re-run any of the 10 setup scripts independently. Useful for targeted fixes (e.g., just re-run NVIDIA setup after disabling Secure Boot, or re-run the AI stack).

## AI stack

The `10-ai-stack.sh` script installs the ML/AI foundation that all loco-* projects depend on:

| Component | What | Why |
|-----------|------|-----|
| **CUDA 12.4** | GPU compute toolkit | Supports compute 5.0+ (GTX 950 through RTX 4050) |
| **Ollama** | LLM inference engine | Used by loco-llm, loco-bench, loco-ensayo |
| **Docker** | Container runtime + NVIDIA Container Toolkit | GPU passthrough, service deployment |
| **Node.js 22 LTS** | JavaScript runtime | Astro Starlight docs sites |
| **HuggingFace CLI** | Model hub access | Model downloads for loco-bench, loco-llm |

Each component is individually toggleable in `config.env` (e.g., `CUDA_ENABLE=true`).

## ASCII art

Art files live in the repo under `ascii-art/<machine-name>/`:

```
ascii-art/
├── burro/          # donkey art (*.txt)
├── cerebro/        # brain art (*.txt)
├── colmena/        # beehive art (*.txt)
├── hormiga/        # ant art (*.txt)
├── mesa/           # table art (*.txt)
├── pulpo/          # octopus art (*.txt)
└── tortuga/        # turtle art (*.txt)
```

During install, all `*.txt` files from the machine's folder are copied to `/etc/motd-art/` on the target. The MOTD script picks one at random on each login.

**To add new art:** Drop `.txt` files into the machine's folder, then either re-run the full install or use Post-Install > Update MOTD art. The old art at `/etc/motd-art/` is replaced entirely with what's in the repo folder.

## Python development setup (optional)

Not all machines need Python. Run this separately after `install.sh`:

```bash
bash setup-python.sh                    # defaults: Python 3.13, env name "base"
bash setup-python.sh --python 3.12      # specific Python version
bash setup-python.sh --env-name ml      # custom environment name
```

This installs `uv` (user-local, no root needed), creates a global `base` environment, and installs a full modern Python stack:

| Group | Packages |
|-------|----------|
| Dev tools | ruff, mypy, basedpyright, pytest, pytest-cov, pytest-xdist, twine, build, ipython, pre-commit |
| TUI | textual, rich, click, typer, tqdm, prompt-toolkit |
| Data | numpy, pandas, polars, matplotlib, seaborn, scipy |
| ML | scikit-learn, xgboost, lightgbm |
| Utilities | requests, httpx, pydantic, sqlalchemy, orjson, jinja2, pyyaml, python-dotenv |

It also installs `uvenv`, a single conda-style command with tab completion:

```bash
uvenv use [name]                    # activate local .venv or named global env
uvenv create <name> [pyver] [pkgs]  # create a new global env
uvenv ls                            # list global environments (with * for active)
uvenv rm <name>                     # remove a global environment
uvenv help                          # show help
```

## Toggle scripts

| Script | Description |
|--------|-------------|
| `toggle-autologin.sh` | Enable/disable TTY autologin. Usage: `sudo ./toggle-autologin.sh on\|off\|status` |
| `toggle-nopasswd.sh` | Enable/disable NOPASSWD sudo. Usage: `sudo ./toggle-nopasswd.sh on\|off\|status` |

## Configuration

Settings live in `config.env`. Machine identity (name + emoji) is set by the install menu and saved in `.machine` — you don't need to edit these manually.

```
PROMPT_COLOR            ANSI color code for prompt (default: 1;36m = cyan)
PLYMOUTH_ENABLE         true/false
PLYMOUTH_FONT           figlet/toilet font name (default: future)
PLYMOUTH_FG_COLOR       ImageMagick color for splash text (default: cyan)
NVIDIA_ENABLE           true/false
NVIDIA_DRIVER_VERSION   Driver version (default: 535)
CUDA_ENABLE             true/false (default: true)
CUDA_VERSION            CUDA version (default: 12-4)
OLLAMA_ENABLE           true/false (default: true)
DOCKER_ENABLE           true/false (default: true)
NODEJS_ENABLE           true/false (default: true)
NODEJS_VERSION          Node.js major version (default: 22)
HF_CLI_ENABLE           true/false (default: true)
AUTOLOGIN_ENABLE        true/false
AUTOLOGIN_TTY           Which TTY (default: tty1)
DASHBOARD_ENABLE        true/false
DASHBOARD_LAYOUT        tmux layout: tiled, even-horizontal, even-vertical, main-horizontal, main-vertical
DASHBOARD_ROTATE_INTERVAL  Default rotation interval in seconds (default: 300)
DASHBOARD_PANE_1-8      Commands for each pane — use | to rotate multiple (set to "" to disable)
UFW_ENABLE              true/false
FAIL2BAN_ENABLE         true/false
EXTRA_PACKAGES          Additional apt packages (space-separated)
```

## API keys and tokens

Post-install scripts save credentials to `~/.env.keys` (chmod 600), which is auto-sourced from `.bashrc`:

```bash
export GITHUB_TOKEN="ghp_..."
export ANTHROPIC_API_KEY="sk-ant-..."
```

This file is never committed to the repo.

## Dashboard pane options

Any terminal command works. Use `|` to rotate multiple commands in the same pane:

```bash
DASHBOARD_PANE_1="htop"                                          # single command
DASHBOARD_PANE_2="cmatrix -C cyan | pipes.sh | cbonsai --live"   # rotates every 5 min
DASHBOARD_PANE_2_INTERVAL=60                                     # override: rotate every 1 min
```

If a command is not installed, the pane shows an "N/A" message with the missing tool name, then rotates to the next command.

Some good pane commands:

| Command | Description |
|---------|-------------|
| `htop` | Interactive process viewer |
| `btop` | Fancy resource monitor |
| `cmatrix -C cyan` | Matrix rain |
| `cbonsai --live --infinite` | Growing bonsai tree |
| `pipes.sh` | Animated pipes |
| `asciiquarium` | ASCII aquarium |
| `tty-clock -c -C 6` | Centered clock (cyan) |
| `nmon` | System monitor |
| `neofetch --loop` | System info on repeat |
| `watch -n2 -c nvidia-smi` | Live GPU stats |

Use Post-Install > Configure dashboard to reconfigure panes interactively after install.

## File structure

```
loco-base/
├── config.env              # Configurable defaults (dashboard, NVIDIA, AI stack, hardening, etc.)
├── install.sh              # Menu-driven installer (run with sudo -E)
├── reset.sh                # Strip to minimal server state
├── verify.sh               # Post-install verification
├── setup-python.sh         # Python dev environment (optional, no root needed)
├── uv-functions.bash       # Conda-style shell functions for uv
├── toggle-autologin.sh     # Toggle TTY autologin on/off
├── toggle-nopasswd.sh      # Toggle NOPASSWD sudo on/off
├── README.md
├── HARDENING.md            # Security posture documentation
├── .machine                # Machine identity (auto-generated, gitignored)
├── ascii-art/              # Per-machine ASCII art
│   ├── burro/
│   ├── cerebro/
│   ├── colmena/
│   ├── hormiga/
│   ├── mesa/
│   ├── pulpo/
│   └── tortuga/
├── scripts/
│   ├── 01-packages.sh
│   ├── 02-nvidia.sh
│   ├── 03-plymouth.sh
│   ├── 04-motd.sh
│   ├── 05-grub.sh
│   ├── 06-autologin.sh
│   ├── 07-dashboard.sh
│   ├── 08-prompt.sh
│   ├── 09-harden.sh
│   ├── 10-ai-stack.sh      # CUDA + Ollama + Docker + Node.js + HF CLI
│   └── pane-runner.sh      # Helper for dashboard pane rotation
├── post-install/
│   ├── github-ssh.sh       # GitHub auth + SSH key setup
│   ├── claude-code.sh      # Install Claude Code CLI
│   ├── configure-dashboard.sh  # Interactive dashboard reconfiguration
│   ├── update-motd-art.sh  # Re-copy art and regenerate MOTD
│   └── fan-setup.sh        # Fan curve configuration (lm-sensors + fancontrol)
└── security/
    ├── audit-local.sh       # Local security audit + drift detection
    ├── audit-remote.sh      # Remote nmap port scanning
    ├── setup-cron.sh        # Install automated audit cron jobs
    └── hosts.txt            # Lab machine list for remote scans
```

## Security auditing

The `security/` folder contains standalone audit scripts — run these after setup to monitor machine health:

| Script | Description |
|--------|-------------|
| `audit-local.sh` | Runs Lynis + custom hardening checks (UFW, fail2ban, NOPASSWD, open ports, AppArmor, drift detection). Usage: `sudo ./security/audit-local.sh` |
| `audit-remote.sh` | Scans lab machines externally with nmap. Usage: `./security/audit-remote.sh [host1 host2 ...]` or reads from `hosts.txt` |
| `setup-cron.sh` | Installs cron jobs for automated auditing (daily local, weekly remote, weekly Lynis). Usage: `sudo ./security/setup-cron.sh` |
| `hosts.txt` | List of lab machine hostnames/IPs for remote scanning (one per line) |

`audit-local.sh` supports `--cron` mode for quiet output (only warnings/failures). On first run it saves a baseline; subsequent runs detect drift.

See [HARDENING.md](HARDENING.md) for a full write-up of the security posture.

## Notes

- The prompt emoji renders correctly over SSH (your terminal handles it) but will show as a diamond on the physical framebuffer TTY. This is expected — SSH is the primary access method.
- The installer creates a temporary NOPASSWD sudo entry. Always remove it as the final step.
- Individual scripts can be re-run from the menu (option 5) or independently after sourcing `config.env`.
- The dashboard script is installed to `~/<machine-name>-dashboard.sh` and can be edited directly, or reconfigured via Post-Install > Configure dashboard.
- `reset.sh` only supports Ubuntu 22.04 LTS. It will refuse to run on other versions.
