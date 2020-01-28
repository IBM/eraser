#!/usr/bin/env bash

DEBUG=1

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <SERMINER_OUTPUT_DIR> <STRESSMARK_OUT_DIR> <RESIDENCY_THRESHOLD> <NUM_PERMUTATIONS> <DEPENDENCY DISTANCE>" >&2
    exit 1
fi

SERMINER_OUTPUT_DIR=$1
STRESSMARK_OUT_DIR=$2
RES_THRESHOLD=$3
NUM_PERMUTATIONS=$4
DEP_DISTANCE=$5

# Set instruction weights to 0 for now  --- Additional features to be added later
WEIGHTED=0

# Check if results directory exists
if [ -d "$SERMINER_OUTPUT_DIR" ] && [ -e "${SERMINER_CONFIG_HOME}/inst_list.txt" ]
then
    if [ $DEBUG -eq 1 ]
    then
        echo "Verifying $SERMINER_OUTPUT_DIR exists"
    fi
else
    echo "SERMiner output directory or instruction list not present. Exiting..."
    exit 1
fi

NUM_INSTS=$(wc -l "${SERMINER_CONFIG_HOME}/inst_list.txt" | awk '{print $1}')

# Create STRESSMARK_OUT_DIR 
mkdir -p "$STRESSMARK_OUT_DIR"

if [ $DEBUG -eq 1 ]
then
    echo "Dictionary size = $NUM_INSTS"
fi

if [ $DEBUG -eq 1 ]
then
    echo "python $SERMINER_HOME/src/gen_ser_stressmark_riscv.py -o $SERMINER_OUTPUT_DIR -n $NUM_INSTS -th $RES_THRESHOLD -p 0 2>/tmp/err.txt| tail -n 1 | tr -d \"[],'\""
fi

stressmark_insts_list=$(python "$SERMINER_HOME/src/gen_ser_stressmark_riscv.py" -o "$SERMINER_OUTPUT_DIR" -n "$NUM_INSTS" -th "$RES_THRESHOLD" -p 0 2> /tmp/err.txt | tail -n 1 | tr -d "[],'")

if [ $DEBUG -eq 1 ]
then
    echo "Insts list: $stressmark_insts_list"
fi

if  [ $WEIGHTED -eq 1 ]
then
    inst_weights=( $(python "$SERMINER_HOME/src/gen_ser_stressmark_riscv.py" -o "${SERMINER_OUTPUT_DIR}" -n "$NUM_INSTS" -th "$RES_THRESHOLD" -p 1| tail -n 1 ) )
else
    for (( i=0; i<${#stressmark_insts_list[@]}; i++ ))
    do
        inst_weights[$i]=1
    done
fi

k=0

for (( i=0; i<${#stressmark_insts_list[@]}; i++ ))
do
    for (( j=0; j<${inst_weights[$i]}; j++ ))
    do
        weighted_stressmark_insts_list[$k]=${stressmark_insts_list[$i]}
        k=$((k+1))
    done
done

num_insts=${#weighted_stressmark_insts_list[@]}

im=""
gm=""
gM=""

for (( i=1; i<$((num_insts-2)); i=$((i+2)) ))
do
    if [ $WEIGHTED -eq 1 ]
    then
        im=$im"$i $((i+1)) "
    else
        im=$im"$i,$((i+1)) $i,$((i+1)) "
    fi

    gm=$gm"1 1 "
    gM=$gM"1 1 "
done

if [ $((num_insts%2)) -eq 0 ]
then
    if [ $WEIGHTED -eq 1 ]
    then
        im=$im"$((num_insts-1)) ${num_insts}"
    else
        im=$im"$((num_insts-1)),${num_insts} $((num_insts-1)),${num_insts}"
    fi
    gm=$gm"1 1"
    gM=$gM"1 1"
else
    if [ $WEIGHTED -eq 1 ]
    then
        im=$im"$((num_insts-2)) $((num_insts-1)) ${num_insts}"
    else
        im=$im"$((num_insts-2)),$((num_insts-1)) $((num_insts-2)),$((num_insts-1)) ${num_insts}"
    fi
    gm=$gm"1 1 1"
    gM=$gM"1 1 1"
fi

#gm=$inst_weights_list
echo "python riscv_ipc_seq.py --dependency-distances $DEP_DISTANCE --loop-size 10000 --instructions $stressmark_insts_list --output-dir $STRESSMARK_OUT_DIR --num_permutations $NUM_PERMUTATIONS --microbenchmark_name SM_TH_${RES_THRESHOLD} &"
