# uv-functions.bash — Conda-style virtual environment management using uv
#
# Source this file from your .bashrc:
#   source ~/.uv-functions.bash
#
# ┌──────────────┬──────────────────────────────────────────────────────────────┐
# │ Function     │ Purpose                                                      │
# ├──────────────┼──────────────────────────────────────────────────────────────┤
# │ use_uv       │ Smart activate — local .venv/ first, else central env name  │
# │ create_uv    │ Create a named central env (optional python ver & packages) │
# │ activate_uv  │ Activate a specific central env by name                     │
# │ list_uv      │ List all central environments                               │
# │ remove_uv    │ Delete a central environment                                │
# │ ensure_uv_home │ (Helper) Creates UV_ENV_HOME directory if missing         │
# └──────────────┴──────────────────────────────────────────────────────────────┘

export UV_ENV_HOME="${UV_ENV_HOME:-$HOME/.uv-envs}"

ensure_uv_home() {
    [[ -d "$UV_ENV_HOME" ]] || mkdir -p -- "$UV_ENV_HOME"
}

create_uv() {
    ensure_uv_home
    local name="$1"
    shift || true

    if [[ -z "$name" ]]; then
        echo "Usage: create_uv <env_name> [python_version] [spec...]" >&2
        return 1
    fi

    local pyver="$1"
    [[ -n "$pyver" ]] && shift || true

    local env_dir="$UV_ENV_HOME/$name"
    if [[ -d "$env_dir" ]]; then
        echo "Error: Environment '$name' already exists at $env_dir" >&2
        return 1
    fi

    if [[ -n "$pyver" ]]; then
        uv python install "$pyver" > /dev/null 2>&1 || true
        uv venv -p "python$pyver" -- "$env_dir"
    else
        uv venv -- "$env_dir"
    fi

    if (( $# > 0 )); then
        source "$env_dir/bin/activate"
        if [[ -f "$1" ]]; then
            uv pip install -r "$1"
        else
            uv pip install "$@"
        fi
        deactivate
    fi

    echo "Created env '$name' at: $env_dir"
    echo "Activate: source \"$env_dir/bin/activate\""
}

activate_uv() {
    ensure_uv_home
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: activate_uv <env_name>" >&2
        return 1
    fi

    local env_dir="$UV_ENV_HOME/$name"
    if [[ -d "$env_dir" ]]; then
        source "$env_dir/bin/activate"
    else
        echo "Environment '$name' not found in $UV_ENV_HOME" >&2
        return 1
    fi
}

remove_uv() {
    ensure_uv_home
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: remove_uv <env_name>" >&2
        return 1
    fi

    local env_dir="$UV_ENV_HOME/$name"
    if [[ -d "$env_dir" ]]; then
        rm -rf -- "$env_dir"
        echo "Removed $name"
    else
        echo "No such env: $name" >&2
        return 1
    fi
}

list_uv() {
    ensure_uv_home
    echo "(UV_ENV_HOME: $UV_ENV_HOME)"
    if [[ -d "$UV_ENV_HOME" ]]; then
        ls -1 -- "$UV_ENV_HOME" 2>/dev/null || true
    fi
}

use_uv() {
    ensure_uv_home
    local name="$1"

    if [[ -d ".venv" ]]; then
        source ".venv/bin/activate"
    elif [[ -n "$name" && -d "$UV_ENV_HOME/$name" ]]; then
        source "$UV_ENV_HOME/$name/bin/activate"
    else
        echo "No .venv here and no matching central env." >&2
        echo "Usage: use_uv [central_env_name]" >&2
        return 1
    fi
}
