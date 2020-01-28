#!/usr/bin/env sh
#
# ERASER support scripts
#

set -e
eraserpath=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )

CORES="$(grep -c processor < /proc/cpuinfo)"

git submodule update --init --recursive --jobs "$CORES"

MAKEFLAGS="$MAKEFLAGS -j $CORES"
export MAKEFLAGS

if [ ! -f "$eraserpath/rocket-tools-install/bin/riscv64-unknown-elf-gcc" ]; then
    mkdir -p "$eraserpath/rocket-tools-install"
    sed -i "s/\$MAKE /\$MAKE \$MAKEFLAGS /g" rocket-tools/build.common
    cd "$eraserpath/rocket-tools"
    RISCV="$eraserpath/rocket-tools-install" ./build.sh
    cd "$eraserpath"
fi

if [ ! -e "$eraserpath/microprobe/venv" ]; then
    cd "$eraserpath/microprobe"
    echo "numpy" >> ./requirements.txt
    ./bootstrap_environment.sh 3
    cd "$eraserpath"
fi

if [ ! -x "$eraserpath/rocket-chip/emulator/emulator-freechips.rocketchip.system-DefaultConfig-debug" ]; then
    cd "$eraserpath/rocket-chip/emulator"
    RISCV=$eraserpath/rocket-tools-install make -j "$CORES" debug
    cd "$eraserpath"
fi

echo "ERASER Setup OK"
