# Machine Setup

Automated setup kit for Ubuntu 22.04 LTS workstations. Installs a branded boot splash, MOTD with ASCII art, tmux dashboard on autologin TTY, custom bash prompt, and basic hardening.

All scripts are **idempotent** — re-running `install.sh` will fix drift, install anything missing, and skip what's already correct. A separate `reset.sh` can strip a machine back to minimal server state for a clean start.

## What it does

| Script | Description |
|--------|-------------|
| `01-packages.sh` | Installs all tools: tmux, htop, btop, cmatrix, cbonsai, pipes.sh, asciiquarium, toilet, figlet, neofetch, nmon, tty-clock, etc. |
| `02-nvidia.sh` | Installs NVIDIA drivers (configurable version). Skips if correct version already running. Detects Secure Boot and warns if enabled. |
| `03-plymouth.sh` | Generates a boot splash PNG from the machine name using toilet/figlet and installs it as a Plymouth theme. Skips if already active. |
| `04-motd.sh` | Custom MOTD with figlet header, random ASCII art, GPU/CPU/memory/disk/uptime stats. Disables all default Ubuntu MOTD messages. |
| `05-grub.sh` | Sets `quiet splash` in GRUB for Plymouth. |
| `06-autologin.sh` | Configures systemd autologin on a TTY. |
| `07-dashboard.sh` | Creates a tmux dashboard script with configurable panes (including multi-command rotation) and hooks it into `.bash_profile` to auto-launch on the autologin TTY. |
| `08-prompt.sh` | Sets a two-line bash prompt with configurable emoji, machine name, path, and git branch. Uses marker blocks for safe re-runs. |
| `09-harden.sh` | Enables UFW (deny incoming, allow SSH) and fail2ban (systemd backend). |

## Quick start

### Fresh install

1. Install Ubuntu 22.04 LTS on the target machine.

2. Copy this folder and your ASCII art folder to the machine:
   ```bash
   scp -r machine-setup/ user@host:~/
   scp -r ant-art/ user@host:~/        # or whatever art folder you use
   ```

3. Edit `config.env` for the new machine:
   ```bash
   cd ~/machine-setup
   nano config.env
   ```
   At minimum, change:
   - `MACHINE_NAME` — used in Plymouth, MOTD header, prompt, dashboard script name
   - `SETUP_USER` — the user account to configure
   - `PROMPT_EMOJI` — emoji shown in the bash prompt
   - `ART_DIR` / `ART_GLOB` — path and glob pattern for ASCII art files

4. Run the installer:
   ```bash
   sudo -E bash install.sh
   ```

5. If Secure Boot is enabled, the NVIDIA step will warn you. Disable it in BIOS, reboot, then run:
   ```bash
   sudo dpkg --configure -a
   ```

6. Reboot and verify:
   ```bash
   sudo reboot
   # after reboot:
   bash ~/machine-setup/verify.sh
   ```

7. Remove temporary passwordless sudo:
   ```bash
   sudo rm /etc/sudoers.d/<username>-nopasswd
   ```

### Drift recovery (re-run install)

If a machine has drifted from the expected state (missing packages, changed configs, students installed things they shouldn't have), just re-run the installer:

```bash
sudo -E bash install.sh
```

This will:
- Install any missing packages, skip already-installed ones
- Reconfigure MOTD, prompt, autologin, dashboard, hardening to match `config.env`
- Skip expensive operations (NVIDIA driver install, Plymouth initramfs rebuild) if already correct
- Never duplicate or corrupt existing config (prompt uses marker blocks, `.bash_profile` hook is guarded)

### Full reset (nuke and pave)

If a machine is too far gone (desktop environment installed, snaps everywhere, wrong shell, etc.), reset it first:

```bash
sudo -E bash reset.sh      # strips to minimal server state
sudo -E bash install.sh     # re-applies everything cleanly
```

`reset.sh` will:
- Require you to type `YES` to confirm
- Remove all machine-setup artifacts (Plymouth theme, MOTD, dashboard, prompt, autologin, sudoers, fail2ban config)
- Purge desktop environments and display managers (GNOME, KDE, XFCE, LXDE, LXQt, MATE, Cinnamon)
- Remove snap and flatpak completely
- Disable and remove unnecessary services (cups, avahi, bluetooth, modemmanager, apport, cloud-init, etc.)
- Reset all user shells to bash, remove zsh/fish
- Remove all packages installed by our scripts
- Run `autoremove --purge` to clean orphans

It will **never** touch: SSH, kernel, networking, sudo, apt, or systemd itself.

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

Global environments live in `~/.uv-envs/` (configurable via `UV_ENV_HOME`). The `base` environment auto-activates on login.

**Two modes, one tool**: Use `uv` directly for project-local work (pyproject.toml, .venv per project). Use `uvenv` for shared/global environments (data science, teaching, etc.). `uvenv use` checks for a local `.venv` first, so they coexist naturally.

Everything stays in the user's home directory — no system Python is touched.

## Toggle scripts

Convenience scripts for toggling settings on and off:

| Script | Description |
|--------|-------------|
| `toggle-autologin.sh` | Enable/disable TTY autologin. Usage: `sudo ./toggle-autologin.sh on\|off\|status` |
| `toggle-nopasswd.sh` | Enable/disable NOPASSWD sudo. Usage: `sudo ./toggle-nopasswd.sh on\|off\|status` |

## Configuration reference

All settings live in `config.env`:

```
MACHINE_NAME            Name used everywhere (Plymouth, MOTD, prompt)
SETUP_USER              Linux user to configure
PROMPT_EMOJI            Emoji in bash prompt (renders on SSH clients, not framebuffer TTY)
PROMPT_COLOR            ANSI color code for prompt (default: 1;36m = cyan)
ART_DIR                 Absolute path to folder with ASCII art files
ART_GLOB                Glob pattern for art files (e.g. "ant-*.txt", "brain-*.txt")
PLYMOUTH_ENABLE         true/false
PLYMOUTH_FONT           figlet/toilet font name (default: future)
PLYMOUTH_FG_COLOR       ImageMagick color for splash text (default: cyan)
NVIDIA_ENABLE           true/false
NVIDIA_DRIVER_VERSION   Driver version (default: 535)
AUTOLOGIN_ENABLE        true/false
AUTOLOGIN_TTY           Which TTY (default: tty1)
DASHBOARD_ENABLE        true/false
DASHBOARD_LAYOUT        tmux layout: tiled, even-horizontal, even-vertical, main-horizontal, main-vertical
DASHBOARD_ROTATE_INTERVAL  Default rotation interval in seconds for multi-command panes (default: 300)
DASHBOARD_PANE_1-8      Commands for each pane — use | to rotate multiple commands (set to "" to disable)
DASHBOARD_PANE_N_INTERVAL  Per-pane rotation interval override (optional)
UFW_ENABLE              true/false
FAIL2BAN_ENABLE         true/false
EXTRA_PACKAGES          Additional apt packages (space-separated)
```

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

## File structure

```
machine-setup/
├── config.env              # Per-machine configuration
├── install.sh              # Main installer (run with sudo -E)
├── reset.sh                # Strip to minimal server state
├── setup-python.sh         # Python dev environment (optional, no root needed)
├── uv-functions.bash       # Conda-style shell functions for uv
├── verify.sh               # Post-install verification
├── toggle-autologin.sh     # Toggle TTY autologin on/off
├── toggle-nopasswd.sh      # Toggle NOPASSWD sudo on/off
├── README.md
└── scripts/
    ├── 01-packages.sh
    ├── 02-nvidia.sh
    ├── 03-plymouth.sh
    ├── 04-motd.sh
    ├── 05-grub.sh
    ├── 06-autologin.sh
    ├── 07-dashboard.sh
    ├── 08-prompt.sh
    ├── 09-harden.sh
    └── pane-runner.sh      # Helper for dashboard pane rotation
```

## Notes

- The prompt emoji renders correctly over SSH (your terminal handles it) but will show as a diamond on the physical framebuffer TTY. This is expected — SSH is the primary access method.
- The installer creates a temporary NOPASSWD sudo entry. Always remove it as the final step.
- Individual scripts can be re-run independently by sourcing `config.env` first.
- The dashboard script is installed to `~/<machine-name>-dashboard.sh` and can be edited directly after install to change panes or layout without re-running the installer.
- `reset.sh` only supports Ubuntu 22.04 LTS. It will refuse to run on other versions.
