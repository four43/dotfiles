# Devcontainers CLI — start/attach to dev containers without VS Code in the loop.
# Install with: yay -S devcontainer-cli  (or: npm i -g @devcontainers/cli)

alias dc-build='devcontainer build --workspace-folder .'

# Force-remove the devcontainer(s) for $PWD. @devcontainers/cli has no `down`
# subcommand, so we do it via docker against the standard devcontainer label.
# Compose-based projects can have multiple containers under one label.
dc-down() {
    local ids
    ids=$(docker ps -aq --filter "label=devcontainer.local_folder=$PWD")
    if [[ -z "$ids" ]]; then
        print -u2 "No devcontainer for $PWD."
        return 0
    fi
    print "$ids" | xargs docker rm -f
}

# Forward the host SSH agent into the container by default. `up` accepts --mount
# (only honored at container creation), `exec` only --remote-env. Populated each
# call so it tracks the current host SSH_AUTH_SOCK. Opt out with DC_SKIP_SSH=1.
_dc_up_ssh_args=()
_dc_exec_ssh_args=()
_dc_set_ssh_args() {
    _dc_up_ssh_args=()
    _dc_exec_ssh_args=()
    [[ -z "$DC_SKIP_SSH" ]] || return
    [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" ]] || return
    _dc_up_ssh_args=(
        --mount "type=bind,source=$SSH_AUTH_SOCK,target=/tmp/dc-ssh-agent.sock"
        --remote-env "SSH_AUTH_SOCK=/tmp/dc-ssh-agent.sock"
    )
    _dc_exec_ssh_args=(--remote-env "SSH_AUTH_SOCK=/tmp/dc-ssh-agent.sock")
}

dc-up() {
    _dc_set_ssh_args
    devcontainer up --workspace-folder . "${_dc_up_ssh_args[@]}" "$@"
}

# Start the devcontainer for $PWD if no matching one is already running, and
# populate _dc_exec_ssh_args either way for downstream `devcontainer exec` use.
_dc_ensure_up() {
    _dc_set_ssh_args
    local cid
    cid=$(docker ps --filter "label=devcontainer.local_folder=$PWD" \
                    --format '{{.ID}}' | head -n1)
    [[ -n "$cid" ]] || devcontainer up --workspace-folder . "${_dc_up_ssh_args[@]}"
}

# Drop into the devcontainer (bash if available, else sh). Starts it if needed.
dc-shell() {
    _dc_ensure_up && devcontainer exec --workspace-folder . "${_dc_exec_ssh_args[@]}" \
        sh -c 'command -v bash >/dev/null && exec bash || exec sh'
}

# Mirror VS Code's dotfiles.* feature inside the running devcontainer: clone the
# configured repo and run its install command. Idempotent via a sentinel that
# records the repo URL, so changing the URL re-applies on next run. Skip with
# DC_SKIP_DOTFILES=1.
_dc_apply_dotfiles() {
    [[ -z "$DC_SKIP_DOTFILES" ]] || return 0
    local settings="${VSCODE_SETTINGS:-$HOME/.config/Code/User/settings.json}"
    [[ -r "$settings" ]] || return 0

    local cfg
    if ! cfg=$(python3 - "$settings" <<'PY'
import json5, sys
with open(sys.argv[1]) as f:
    s = json5.load(f)
print(s.get("dotfiles.repository", ""))
print(s.get("dotfiles.targetPath", "~/dotfiles"))
print(s.get("dotfiles.installCommand", ""))
PY
    ); then
        print -u2 "_dc_apply_dotfiles: could not parse $settings — dotfiles not applied"
        return 1
    fi

    local lines=("${(@f)cfg}")
    local repo="${lines[1]}" target="${lines[2]}" install="${lines[3]}"
    [[ -n "$repo" ]] || return 0

    devcontainer exec --workspace-folder . "${_dc_exec_ssh_args[@]}" \
        env DC_REPO="$repo" DC_TARGET="$target" DC_INSTALL="$install" \
        sh -c '
            set -e
            sentinel="$HOME/.dc-dotfiles-installed"
            [ "$(cat "$sentinel" 2>/dev/null)" = "$DC_REPO" ] && exit 0
            # bash tilde-expands the pattern in ${var#~/}, so use a literal-2-char
            # strip after the case has already verified the prefix.
            case "$DC_TARGET" in
                "~/"*) target="$HOME/${DC_TARGET#??}" ;;
                "~")   target="$HOME" ;;
                *)     target="$DC_TARGET" ;;
            esac
            if [ ! -d "$target/.git" ]; then
                git clone --depth 1 "$DC_REPO" "$target"
            fi
            if [ -n "$DC_INSTALL" ]; then
                if [ -x "$target/$DC_INSTALL" ]; then
                    (cd "$target" && "./$DC_INSTALL")
                else
                    (cd "$target" && sh "./$DC_INSTALL")
                fi
            fi
            printf "%s" "$DC_REPO" > "$sentinel"
        ' || print -u2 "_dc_apply_dotfiles: install script failed (continuing)"
}

# Run Claude Code inside the devcontainer. Starts it if needed, applies your
# VS Code dotfiles on first entry, then passes extra args through.
dc-claude() {
    _dc_ensure_up || return
    _dc_apply_dotfiles
    # Run through interactive bash so .bashrc loads — the dotfiles ship `claude`
    # as a lazy-install shell function, which docker exec would otherwise miss.
    devcontainer exec --workspace-folder . "${_dc_exec_ssh_args[@]}" \
        bash -ic 'claude "$@"' _ "$@"
}

dc-sshd() {
	_dc_ensure_up || return
    _dc_apply_dotfiles
    # Run through interactive bash so .bashrc loads — the dotfiles ship `claude`
    # as a lazy-install shell function, which docker exec would otherwise miss.
    devcontainer exec --workspace-folder . "${_dc_exec_ssh_args[@]}" \
        bash -ic 'sshd-start' _ "$@"
}

# Initialize or regenerate docker-compose.override.dev.yml with Xweather dev settings.
# Pass -f/--force to overwrite if file exists.
dc-init-override-dev() {
    local force=0
    if [[ "${1:-}" == "-f" || "${1:-}" == "--force" ]]; then
        force=1
    fi

    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        print -u2 "error: not inside a git repository"
        return 1
    }

    local target_dir="$repo_root/.devcontainer"
    local target_file="$target_dir/docker-compose.override.dev.yml"

    if [[ -e "$target_file" && $force -eq 0 ]]; then
        print -u2 "error: $target_file already exists (use -f to overwrite)"
        return 1
    fi

    mkdir -p "$target_dir"

    cat > "$target_file" <<'YAML'
services:
  app:
    environment:
      - GIT_SSH_COMMAND=/host/home/git-ssh-key-rotation.sh
    volumes:
      # Claude
      - ~/.claude:/host/home/.claude:rw
      - ~/.claude.json:/host/home/.claude.json:rw
      # SSH Key for XWE Meta containers
      - ~/.ssh/xwe-meta-sshd.pub:/opt/sshd/xwe-meta-sshd.pub:ro
      - ~/.dotfiles/git/git-ssh-key-rotation.sh:/host/home/git-ssh-key-rotation.sh:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"

YAML

    print -u2 "wrote $target_file"
}

# Initialize or regenerate docker-compose.override.dev.yml with Xweather dev settings.
# Pass -f/--force to overwrite if file exists.
dc-init-override-dev-full() {
    local force=0
    if [[ "${1:-}" == "-f" || "${1:-}" == "--force" ]]; then
        force=1
    fi

    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        print -u2 "error: not inside a git repository"
        return 1
    }

    local target_dir="$repo_root/.devcontainer"
    local target_file="$target_dir/docker-compose.override.dev.yml"

    if [[ -e "$target_file" && $force -eq 0 ]]; then
        print -u2 "error: $target_file already exists (use -f to overwrite)"
        return 1
    fi

    mkdir -p "$target_dir"

    cat > "$target_file" <<'YAML'
services:
  app:
    environment:
      - AWS_PROFILE=vaisala-xwe-xwc-data-dev-ro
      - XWE_ATLASSIAN_EMAIL=${XWE_ATLASSIAN_EMAIL}
      - XWE_ATLASSIAN_API_TOKEN=${XWE_ATLASSIAN_API_TOKEN}
      - GIT_SSH_COMMAND=/host/home/git-ssh-key-rotation.sh
    volumes:
      # AWS
      - ~/.aws/config-ro:/root/.aws/config:ro
      - ~/.aws/sso:/root/.aws/sso:rw
      - ~/.ssh/config:/host/home/.ssh/config:ro
      # Claude
      - ~/.claude:/host/home/.claude:rw
      - ~/.claude.json:/host/home/.claude.json:rw
      # SSH Key for XWE Meta containers
      - ~/.ssh/xwe-meta-sshd.pub:/opt/sshd/xwe-meta-sshd.pub:ro
      - ~/.dotfiles/git/git-ssh-key-rotation.sh:/host/home/git-ssh-key-rotation.sh:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"

YAML

    print -u2 "wrote $target_file"
}

# List running devcontainers. Pass -a to include stopped ones.
# Filters on the `devcontainer.local_folder` label, which both
# @devcontainers/cli and the VS Code extension stamp onto every container.
dc-status() {
    docker ps --filter 'label=devcontainer.local_folder' \
        --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Label "devcontainer.local_folder"}}\t{{.Status}}' \
        "$@"
}

# Open VS Code attached to the running devcontainer for $PWD (or $1).
dc-code() {
    local workspace="${1:-$PWD}"
    local cid
    cid=$(docker ps --filter "label=devcontainer.local_folder=$workspace" \
                    --format '{{.ID}}' | head -n1)
    if [[ -z "$cid" ]]; then
        print -u2 "No running devcontainer for $workspace — run dc-up first."
        return 1
    fi
    local config_file remote_folder
    config_file=$(docker inspect -f \
        '{{ index .Config.Labels "devcontainer.config_file" }}' "$cid")
    remote_folder=$(dirname "$(dirname "$config_file")")
    local hex
    hex=$(printf '%s' "$cid" | xxd -p -c 256)
    code --folder-uri "vscode-remote://attached-container+${hex}${remote_folder}"
}
