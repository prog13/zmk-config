#!/usr/bin/env bash
# Build a target from build.yaml with the same board, shield, snippet and
# cmake-args as CI.
#
#   ./build.sh --list
#   ./build.sh urchin_dongle
#   ./build.sh urchin_dongle -DCONFIG_PROSPECTOR_TOUCH_DEBUG=n
#   ./build.sh --all
#
# ZMK_LOCAL_MODULES builds against locally fetched siblings.
#
#   ZMK_LOCAL_MODULES=prospector-zmk-module ./build.sh urchin_dongle
set -euo pipefail

CFG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${CFG_DIR}"

BUILD_ROOT="${BUILD_ROOT:-/build}"
ARTIFACTS="${CFG_DIR}/artifacts"

target="${1:-}"
[ $# -gt 0 ] && shift
extra_args=("$@")

if [ -z "${target}" ] || [ "${target}" = "-h" ] || [ "${target}" = "--help" ]; then
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
    exit 0
fi

read_targets() {
    "${CFG_DIR}/targets.py" "$1" "${CFG_DIR}/build.yaml"
}

if [ "${target}" = "--list" ]; then
    read_targets --list | cut -d"$(printf '\037')" -f1
    exit 0
fi

if [ ! -d "${CFG_DIR}/zephyr/cmake" ]; then
    echo "zephyr is not fetched. Run 'west update' first." >&2
    exit 1
fi


zephyr_pkg="${CFG_DIR}/zephyr/share/zephyr-package/cmake"
if ! grep -rqxF "${zephyr_pkg}" "${HOME}/.cmake/packages/Zephyr" 2>/dev/null; then
    echo "==> west zephyr-export"
    west zephyr-export >/dev/null
fi

extra_modules=""
for m in ${ZMK_LOCAL_MODULES:-}; do
    extra_modules="${extra_modules}${extra_modules:+;}$(dirname "${CFG_DIR}")/${m}"
done
[ -n "${extra_modules}" ] && echo "==> local modules: ${extra_modules}"

targets="$(read_targets "${target}")"
if [ -z "${targets}" ]; then
    echo "no target named '${target}' in build.yaml. Try ./build.sh --list." >&2
    exit 1
fi

while IFS="$(printf '\037')" read -r name board shield snippet cmake_args; do
    build_dir="${BUILD_ROOT}/${name}"

    read -ra cargs <<<"${cmake_args}"
    args=(-s "${CFG_DIR}/zmk/app" -b "${board}" -d "${build_dir}")
    [ -n "${snippet}" ] && args+=(-S "${snippet}")
    args+=(-- "-DZMK_CONFIG=${CFG_DIR}/config")
    [ -n "${shield}" ] && args+=("-DSHIELD=${shield}")
    [ -n "${extra_modules}" ] && args+=("-DZMK_EXTRA_MODULES=${extra_modules}")
    [ ${#cargs[@]} -gt 0 ] && args+=("${cargs[@]}")
    [ ${#extra_args[@]} -gt 0 ] && args+=("${extra_args[@]}")

    stamp="${build_dir}/.build_args"
    cmd=(west build)
    [ -f "${stamp}" ] && [ "$(cat "${stamp}")" != "${args[*]}" ] && cmd+=(-p always)
    cmd+=("${args[@]}")

    echo
    echo "==> ${name}  (${board} / ${shield:-no shield})"
    "${cmd[@]}" </dev/null
    printf '%s\n' "${args[*]}" > "${stamp}"

    uf2="${build_dir}/zephyr/zmk.uf2"
    if [ -f "${uf2}" ]; then
        mkdir -p "${ARTIFACTS}"
        cp "${uf2}" "${ARTIFACTS}/${name}.uf2"
        echo "    artifact: artifacts/${name}.uf2"
    else
        echo "    no .uf2 produced (${uf2} missing)" >&2
    fi
done <<<"${targets}"

if [ "${target}" != "--all" ] && [ -f "${build_dir}/compile_commands.json" ]; then
    ln -sf "${build_dir}/compile_commands.json" "${CFG_DIR}/compile_commands.json"
fi
