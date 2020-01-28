#!/usr/bin/env sh
# Script to run all single instruction testcases

DD=0
LS=10000
OUT_DIR=$(pwd)/src

start_str="python riscv_ipc.py --dependency-distances $DD --loop-size $LS --instructions"
end_str="--output-dir $OUT_DIR"
inst_str=""

# shellcheck disable=SC2013
for INST in $(cat "$SERMINER_CONFIG_HOME/inst_list.txt");      
do
    inst_str="$inst_str $INST"
done

cd "$MICROPROBE_HOME/targets/riscv/examples" || exit
echo "$start_str $inst_str $end_str"
run_cmd="$start_str $inst_str $end_str"
${run_cmd}
