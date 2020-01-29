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

SW_FILE=$1
INST=$2
OUTPUT_DIR=$3
LATCH_DATAFILE="${OUTPUT_DIR}/${INST}_latch_data.txt"
MACRO_DATAFILE="${OUTPUT_DIR}/${INST}_macro_data.txt"
RTL_CORE_MODULE=$ROCKET_RTL_MODULE
#RTL_CORE_MODULE="TOP.TestHarness.ldut.tile.core." 
echo "Generating Latch data file for $INST" #Cores only
#grep "TOP.TestHarness.ldut.tile.core" $SW_FILE | sed -e 's/TOP.TestHarness.ldut.tile.core.//' | tr -d "[]" | awk -F '[, ]' '{
grep "$RTL_CORE_MODULE" "$SW_FILE" | sed -e "s/${RTL_CORE_MODULE}//" | tr -d "[]" | awk -F '[, ]' '{
if ($1~/./)
    { 
        split($1,s,"."); 
        S=s[1];
    } else 
    {
        S=$1;
    }
    if( $2~/:/) 
        {
            split($2,a,":"); 
            sig_bits[S] = sig_bits[S] + int(a[1])
            numbits = int(a[1])
        } else 
        {
            sig_bits[S]++;
            numbits=1
        };
        num_signals[S]++; 
        sig_name[S] = S; 
        tot_sw[S] += $NF*numbits; 
        tot_res[S] += ($NF==0)?0:numbits/$NF; tot_bits[S] +=numbits;
    }
END {
print "#Name Num_signals Num_bits Total_sw Avg_residency" 
for (sig in sig_name) print sig " " num_signals[sig] " " sig_bits[sig] " " tot_sw[sig] " " tot_res[sig]/(tot_bits[sig])
}' > "$LATCH_DATAFILE"

# aggregated_signal_list=('io_rocc' 'io_fpu' 'io_dmem' 'mem_reg' 'mem_int' 'll' 'id_' 'ex_rs' 'ex_op' 'ex_cause' 'ex_reg' 'div_io' 'csr_io' 'bypass_mux' 'alu_io' 'io_imem' 'io_dmem' 'io_ptw' 'wb_reg' 'PlusArgTimeout' 'ibuf_io' 'ex_imm')
#Get stats per macro and submacro division

echo "Generating Macro data file for $INST"

awk '{
if (NR==1) next;
    if ($1~/_/) 
        { 
            split($1,s,"_"); macro=s[1]"_"s[2]
        } else
        {	
            macro=$1;
        }
        numsigs[macro]+=$(NF-3); 
        numbits[macro]+=$(NF-2); 
        tot_sw[macro]+=$(NF-1);
        tot_res[macro]=$NF
    } 
END {
print "#Name Num_signals Num_bits Total_sw Avg_residency" 
for (i in numsigs) 
    {
        avg_res = (numbits[i]==0)?0:tot_res[i]/numbits[i]; 
        print i " " numsigs[i] " " numbits[i] " " tot_sw[i] " " avg_res
    }
}' "$LATCH_DATAFILE" > "$MACRO_DATAFILE"
