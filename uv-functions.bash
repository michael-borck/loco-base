# uv-functions.bash — Conda-style global environment management using uv
#
# Source this file from your .bashrc:
#   source ~/.uv-functions.bash
#
# Usage:
#   uvenv use [name]                  Smart activate — local .venv first, else named global env
#   uvenv create <name> [pyver] [pkg...]  Create a named global env
#   uvenv ls                          List all global environments
#   uvenv rm <name>                   Delete a global environment
#   uvenv help                        Show this help
#
# Global environments live in UV_ENV_HOME (default: ~/.uv-envs)

export UV_ENV_HOME="${UV_ENV_HOME:-$HOME/.uv-envs}"

uvenv() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        use)      _uvenv_use "$@" ;;
        create)   _uvenv_create "$@" ;;
        ls|list)  _uvenv_ls "$@" ;;
        rm)       _uvenv_rm "$@" ;;
        help|-h|--help) _uvenv_help ;;
        *)
            echo "uvenv: unknown command '$cmd'" >&2
            _uvenv_help
            return 1
            ;;
    esac
}

_uvenv_help() {
    cat <<EOF
uvenv — conda-style environment management for uv

  uvenv use [name]                    activate local .venv or named global env
  uvenv create <name> [pyver] [pkg..] create a global env (optional python version & packages)
  uvenv ls                            list global environments
  uvenv rm <name>                     remove a global environment
  uvenv help                          show this help

  Global envs: ${UV_ENV_HOME}
EOF
}

_uvenv_use() {
    local name="$1"

    if [[ -d ".venv" ]]; then
        source ".venv/bin/activate"
    elif [[ -n "$name" ]]; then
        local env_dir="$UV_ENV_HOME/$name"
        if [[ -d "$env_dir" ]]; then
            source "$env_dir/bin/activate"
        else
            echo "uvenv: no environment '$name' in $UV_ENV_HOME" >&2
            echo "Available:" >&2
            _uvenv_ls >&2
            return 1
        fi
    else
        echo "uvenv use: no .venv here and no name given" >&2
        echo "Usage: uvenv use <name>" >&2
        echo "Available:" >&2
        _uvenv_ls >&2
        return 1
    fi
}

_uvenv_create() {
    local name="$1"
    shift 2>/dev/null || true

    if [[ -z "$name" ]]; then
        echo "Usage: uvenv create <name> [python_version] [packages...]" >&2
        return 1
    fi

    local env_dir="$UV_ENV_HOME/$name"
    if [[ -d "$env_dir" ]]; then
        echo "uvenv: '$name' already exists at $env_dir" >&2
        return 1
    fi

    [[ -d "$UV_ENV_HOME" ]] || mkdir -p "$UV_ENV_HOME"

    local pyver="$1"
    [[ -n "$pyver" ]] && shift || true

    if [[ -n "$pyver" ]]; then
        uv python install "$pyver" > /dev/null 2>&1 || true
        uv venv -p "python$pyver" "$env_dir"
    else
        uv venv "$env_dir"
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

    echo "Created '$name' → $env_dir"
    echo "Activate: uvenv use $name"
}

_uvenv_ls() {
    [[ -d "$UV_ENV_HOME" ]] || mkdir -p "$UV_ENV_HOME"

    local envs=("$UV_ENV_HOME"/*)
    if [[ ! -d "${envs[0]}" ]]; then
        echo "  (none)"
        return
    fi

    local current=""
    [[ -n "$VIRTUAL_ENV" ]] && current="$VIRTUAL_ENV"

    for env_dir in "${envs[@]}"; do
        [[ -d "$env_dir" ]] || continue
        local name=$(basename "$env_dir")
        local pyver=$("$env_dir/bin/python" --version 2>/dev/null || echo "unknown")
        local pkgs=$(ls "$env_dir/lib"/python*/site-packages/ 2>/dev/null | grep -v '__\|\.dist-info\|\.egg-info\|pip\|setuptools\|_distutils_hack' | wc -l)
        local marker="  "
        [[ "$env_dir" = "$current" ]] && marker="* "
        echo "  ${marker}${name}  (${pyver}, ${pkgs} packages)"
    done
}

_uvenv_rm() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: uvenv rm <name>" >&2
        return 1
    fi

    local env_dir="$UV_ENV_HOME/$name"
    if [[ -d "$env_dir" ]]; then
        # Deactivate if this env is currently active
        [[ "$VIRTUAL_ENV" = "$env_dir" ]] && deactivate
        rm -rf "$env_dir"
        echo "Removed '$name'"
    else
        echo "uvenv: no environment '$name'" >&2
        return 1
    fi
}

# Tab completion
_uvenv_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "use create ls rm help" -- "$cur"))
    elif [[ $COMP_CWORD -eq 2 ]]; then
        case "$prev" in
            use|rm)
                local envs=""
                if [[ -d "$UV_ENV_HOME" ]]; then
                    envs=$(ls -1 "$UV_ENV_HOME" 2>/dev/null)
                fi
                COMPREPLY=($(compgen -W "$envs" -- "$cur"))
                ;;
        esac
    fi
}
complete -F _uvenv_completions uvenv
