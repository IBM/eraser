#!/usr/bin/env sh
# Copyright 2020 IBM Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
