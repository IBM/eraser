#!/usr/bin/env sh
#
# ERASER support scripts
#

set -e
eraserpath=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )

git submodule update --init --recursive

if [ ! -f "$eraserpath/rocket-tools-install/bin/riscv64-unknown-elf-gcc" ]; then
    mkdir "$eraserpath/rocket-tools-install" 
    cd "$eraserpath/rocket-tools" 
    RISCV="$eraserpath/rocket-tools-install" ./build.sh
    cd "$eraserpath"
fi

if [ ! -e "$eraserpath/microprobe/venv" ]; then
    cd "$eraserpath/microprobe" 
    ./bootstrap_environment.sh 
    cd "$eraserpath"
fi

if [ ! -x "$eraserpath/rocket-chip/emulator/emulator-freechips.rocketchip.system-DefaultConfig-debug" ]; then
    cd "$eraserpath/rocket-chip/emulator"
    RISCV=$eraserpath/rocket-tools-install make debug
    cd "$eraserpath"
fi

. "$eraserpath/eraser_setenv"
