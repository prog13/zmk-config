#!/usr/bin/env bash

set -euo pipefail

CFG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

volume_ownership() {
    echo "==> volume ownership"
    # Docker creates the volume mountpoints as root.
    for d in /build "${HOME}/.claude" "${CFG_DIR}/zmk" "${CFG_DIR}/zephyr" "${CFG_DIR}/modules"; do
        [ -d "${d}" ] || continue
        [ -O "${d}" ] || sudo chown "$(id -u):$(id -g)" "${d}"
    done
}

git_identity() {
    echo "==> git identity"
    git config --global user.name "Alex Gavrilov"
    git config --global user.email "me@p13.xyz"
    # Bind-mounted repos are owned by the host user. Git refuses them without this.
    git config --global --add safe.directory '*'
}

claude_plugins() {
    echo "==> claude plugins"
    # claude-plugins-official is only auto-registered on a first interactive launch.
    claude plugin marketplace add anthropics/claude-plugins-official || true
    claude plugin marketplace add https://github.com/prog13/skills.git || true
    claude plugin install mattpocock-skills@claude-plugins-official --scope user -y || true
    claude plugin install p13-skills@prog13 --scope user -y || true
}

flash_tools() {
    echo "==> flash tools"
    # Flashes the dongle over the bootloader's CDC port; MSC needs mounts we don't have.
    command -v adafruit-nrfutil >/dev/null ||
        pip install --user --break-system-packages adafruit-nrfutil
}

west_workspace() {
    echo "==> west workspace"
    cd "${CFG_DIR}"

    [ -e .west/config ] || west init -l config

    if [ -d zephyr/cmake ]; then
        west zephyr-export >/dev/null
    else
        echo "    zephyr is not fetched. Run 'west update'."
    fi
}

volume_ownership
git_identity
claude_plugins
flash_tools
west_workspace

cat <<'EOF'

Ready.
  west update          # fetches zmk, zephyr and the modules
  ./build.sh --list
  ./build.sh urchin_dongle
EOF
