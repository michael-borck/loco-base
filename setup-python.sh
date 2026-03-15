#!/bin/bash
# ══════════════════════════════════════════════
# Python Development Environment Setup
# Usage: bash setup-python.sh [--python 3.13] [--env-name base]
#
# Installs uv, creates a global "base" environment with a modern
# Python stack, and configures shell functions for conda-style
# environment management. Everything lives in the user's home
# directory — no system Python packages are touched.
# ══════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults
PYTHON_VERSION="3.13"
ENV_NAME="base"
UV_ENV_HOME="${UV_ENV_HOME:-$HOME/.uv-envs}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --python)  PYTHON_VERSION="$2"; shift 2 ;;
        --env-name) ENV_NAME="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash $(basename "$0") [--python 3.13] [--env-name base]"
            echo ""
            echo "  --python    Python version to install (default: 3.13)"
            echo "  --env-name  Name for the global environment (default: base)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Colors
G='\033[1;32m'
C='\033[1;36m'
Y='\033[1;33m'
R='\033[0m'

step() { echo -e "\n${C}══════════════════════════════════════════════${R}"; echo -e "${C}  $1${R}"; echo -e "${C}══════════════════════════════════════════════${R}"; }
ok()   { echo -e "  ${G}✓${R} $1"; }
warn() { echo -e "  ${Y}!${R} $1"; }

BASHRC="$HOME/.bashrc"
UV_FUNCTIONS_SRC="${SCRIPT_DIR}/uv-functions.bash"
UV_FUNCTIONS_DEST="$HOME/.uv-functions.bash"

# ── Step 1: Install uv ──
step "Install uv"
if command -v uv &>/dev/null; then
    CURRENT_UV=$(uv --version 2>/dev/null)
    ok "uv already installed ($CURRENT_UV)"
    # Update to latest
    uv self update 2>/dev/null || true
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add to PATH for this session
    export PATH="$HOME/.local/bin:$PATH"
    ok "uv installed ($(uv --version))"
fi

# ── Step 2: Install Python ──
step "Install Python ${PYTHON_VERSION}"
if uv python list --only-installed 2>/dev/null | grep -q "cpython-${PYTHON_VERSION}"; then
    ok "Python ${PYTHON_VERSION} already installed via uv"
else
    uv python install "$PYTHON_VERSION"
    ok "Python ${PYTHON_VERSION} installed"
fi

# ── Step 3: Install uv-functions.bash ──
step "Install uv shell functions"
cp "$UV_FUNCTIONS_SRC" "$UV_FUNCTIONS_DEST"
ok "Copied uv-functions.bash to ${UV_FUNCTIONS_DEST}"

# Source functions for use in this script
export UV_ENV_HOME
source "$UV_FUNCTIONS_DEST"

# Add to .bashrc if not already present (marker-based)
MARKER_START="# >>> machine-setup uv-functions >>>"
MARKER_END="# <<< machine-setup uv-functions <<<"

if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    sed -i "/${MARKER_START}/,/${MARKER_END}/d" "$BASHRC"
fi

cat >> "$BASHRC" <<EOF

${MARKER_START}
export UV_ENV_HOME="${UV_ENV_HOME}"
[ -f ~/.uv-functions.bash ] && source ~/.uv-functions.bash
${MARKER_END}
EOF
ok "Shell functions added to .bashrc"

# ── Step 4: Create base environment ──
step "Create '${ENV_NAME}' global environment (Python ${PYTHON_VERSION})"
ENV_DIR="$UV_ENV_HOME/$ENV_NAME"

if [ -d "$ENV_DIR" ]; then
    warn "Environment '${ENV_NAME}' already exists — reinstalling packages"
else
    mkdir -p "$UV_ENV_HOME"
    uv venv -p "python${PYTHON_VERSION}" "$ENV_DIR"
    ok "Created environment '${ENV_NAME}'"
fi

# Activate for package installation
source "$ENV_DIR/bin/activate"

# ── Step 5: Install Python packages ──
step "Install Python packages into '${ENV_NAME}'"

# ── Development tools ──
DEV_TOOLS=(
    ruff                    # Linter + formatter (replaces black, isort, flake8)
    mypy                    # Static type checker
    basedpyright            # Fast type checker (Pyright fork)
    pytest                  # Testing framework
    pytest-cov              # Coverage plugin
    pytest-xdist            # Parallel test execution
    twine                   # PyPI publishing
    build                   # PEP 517 build frontend
    ipython                 # Better REPL
    pre-commit              # Git hooks framework
)

# ── TUI / terminal libraries ──
TUI_LIBS=(
    textual                 # Modern TUI framework (Rich-based)
    rich                    # Rich text and formatting
    click                   # CLI framework
    typer                   # CLI framework (type hints)
    tqdm                    # Progress bars
    prompt-toolkit          # Interactive prompts
)

# ── Data analysis ──
DATA_LIBS=(
    numpy                   # Numerical computing
    pandas                  # Data manipulation
    polars                  # Fast DataFrames
    matplotlib              # Plotting
    seaborn                 # Statistical visualisation
    scipy                   # Scientific computing
)

# ── Machine learning ──
ML_LIBS=(
    scikit-learn            # Classical ML
    xgboost                 # Gradient boosting
    lightgbm                # Gradient boosting (fast)
)

# ── Utilities ──
UTIL_LIBS=(
    requests                # HTTP client
    httpx                   # Modern HTTP client (async)
    python-dotenv           # .env file loading
    pydantic                # Data validation
    jinja2                  # Templating
    pyyaml                  # YAML parsing
    orjson                  # Fast JSON
    sqlalchemy              # Database toolkit
)

echo "  Installing development tools..."
uv pip install "${DEV_TOOLS[@]}" 2>&1 | tail -3
ok "Dev tools installed"

echo "  Installing TUI libraries..."
uv pip install "${TUI_LIBS[@]}" 2>&1 | tail -3
ok "TUI libraries installed"

echo "  Installing data analysis packages..."
uv pip install "${DATA_LIBS[@]}" 2>&1 | tail -3
ok "Data analysis packages installed"

echo "  Installing machine learning packages..."
uv pip install "${ML_LIBS[@]}" 2>&1 | tail -3
ok "ML packages installed"

echo "  Installing utility libraries..."
uv pip install "${UTIL_LIBS[@]}" 2>&1 | tail -3
ok "Utility libraries installed"

# Deactivate
deactivate

# ── Step 6: Auto-activate base environment ──
step "Configure auto-activation"

ACTIVATE_MARKER_START="# >>> machine-setup uv-activate >>>"
ACTIVATE_MARKER_END="# <<< machine-setup uv-activate <<<"

if grep -q "$ACTIVATE_MARKER_START" "$BASHRC" 2>/dev/null; then
    sed -i "/${ACTIVATE_MARKER_START}/,/${ACTIVATE_MARKER_END}/d" "$BASHRC"
fi

cat >> "$BASHRC" <<EOF

${ACTIVATE_MARKER_START}
# Auto-activate the '${ENV_NAME}' global Python environment
uvenv use ${ENV_NAME} 2>/dev/null
${ACTIVATE_MARKER_END}
EOF
ok "Auto-activation of '${ENV_NAME}' added to .bashrc"

# ── Done ──
step "PYTHON SETUP COMPLETE"
echo ""
echo "  Python:       ${PYTHON_VERSION} (managed by uv)"
echo "  Environment:  ${ENV_NAME} → ${ENV_DIR}"
echo "  Env home:     ${UV_ENV_HOME}"
echo ""
echo "  Shell functions available after: source ~/.bashrc"
echo ""
echo "    uvenv use [name]                    activate local .venv or named global env"
echo "    uvenv create <name> [pyver] [pkgs]  create a new global env"
echo "    uvenv ls                            list all global environments"
echo "    uvenv rm <name>                     remove a global environment"
echo "    uvenv help                          show help"
echo ""
echo "  Installed package groups:"
echo "    Dev:   ruff, mypy, basedpyright, pytest, twine, build, ipython, pre-commit"
echo "    TUI:   textual, rich, click, typer, tqdm, prompt-toolkit"
echo "    Data:  numpy, pandas, polars, matplotlib, seaborn, scipy"
echo "    ML:    scikit-learn, xgboost, lightgbm"
echo "    Utils: requests, httpx, pydantic, sqlalchemy, orjson, jinja2, pyyaml"
echo ""
