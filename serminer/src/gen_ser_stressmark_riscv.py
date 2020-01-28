from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import sys
import csv
import numpy as np
import string
import random
import os
import os.path
import subprocess as sp
from collections import defaultdict
import pdb 
from numpy import genfromtxt
#np.set_printoptions(threshold=np.nan)

VERBOSE=0
INST_SCALE_FACTOR = 2
#EXCLUDED_INST_LIST=('SLBMFEE_V0', 'TLBIE_V0', 'SLBIE_V0', 'SLBMFEV_V0', 'SLBIA_V0', 'TLBIEL_V0', 'XSCVDPSPN_V0', 'XSCVDPSP_V0', 'XSCVSPDP_V0', 'XVCVDPSP_V0', 'XVCVSPDP_V0') #threshold 100


def get_stressmark_inst_res(cov_list, res_list, inst_index, tot_cov_list, tot_res_list, return_list):
    #pdb.set_trace()
    #find max residency value
    max_res = max(tot_res_list.values())
    #if VERBOSE:
    #	print(tot_sw_list.values())
    #Find list of instructions with max switching
    max_res_list = [inst for inst,val in tot_res_list.items() if val==max_res]

    #Check which insts with max switching have highest coverwge - use 1st inst in case of tie
    max_cov = max([tot_cov_list[inst] for inst in max_res_list])
    tmp_list=dict(zip(max_res_list,[tot_cov_list[inst] for inst in max_res_list]))
    #max_cov_list = [inst for inst,val in tot_cov_list.items() if val==max_cov]
    max_cov_list = [inst for inst,val in tmp_list.items() if val==max_cov]

    #Choose instruction with max coverage in case of tie.. if coverage is equal, choose a random index
    random_cov_index=random.randint(0,len(max_cov_list)-1)  
    if VERBOSE: 
        print(max_res, max_res_list)
        print("Coverage of max insts: ")
        print(max_cov,max_cov_list[random_cov_index],inst_index[max_cov_list[random_cov_index]])
        print("random index = "+str(random_cov_index)+ " length: " +str(len(max_cov_list)))
    
    todel_list=[]
    deleted_cov_list=[]
    deleted_res_list=[]
    deleted_list_count = 0
	
    for macro in res_list:
        if (res_list[macro][inst_index[max_cov_list[random_cov_index]]] > 0):
            todel_list.append(macro)    
    
    if VERBOSE: 
        print("macros to delete")
        print(todel_list, len(todel_list))

    #delete macros corresponding to max inst
    if len(res_list.keys()) >0 and len(todel_list)>0:
        for m in todel_list:
            deleted_res_list.append(res_list[m])
            deleted_cov_list.append(cov_list[m])
            deleted_list_count = deleted_list_count + 1
            del cov_list[m]
            del res_list[m]

        if VERBOSE: 
            print("remaining macros: " +str(len(res_list.keys())))
            print("append inst: " +str(max_cov_list[random_cov_index]))
        #append instruction to stressmark list
        return_list.append(max_cov_list[random_cov_index])
        print(return_list)
        
    else:
        if VERBOSE: 
           print("no macros selected by instruction "+str(max_cov_list[random_cov_index]))  

    for i in tot_res_list:
        for l in range(0,deleted_list_count): 
            if tot_res_list[i]:
                tot_res_list[i] = tot_res_list[i] - deleted_res_list[l][inst_index[i]]        
                tot_cov_list[i] = tot_cov_list[i] - deleted_cov_list[l][inst_index[i]]        
            
    #delete instruction    
    #for i in max_res_list:
    inst=max_cov_list[random_cov_index]
    del inst_index[inst]
    del tot_cov_list[inst]
    del tot_res_list[inst]

    if VERBOSE: 
        print(res_list.keys())
    #print(res_list)
       
    if (len(res_list.keys()) >0):
        get_stressmark_inst_res(cov_list, res_list, inst_index, tot_cov_list, tot_res_list, return_list)
    else:    
        print(return_list)
    #return return_list

#Threshold insts based on CPI

def main():

    print("Running command: python " +str(sys.argv) + "............")
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output_dir", type=str, help="Output dir", required=True)
    parser.add_argument("-n", "--num_insts", type=int, help="Number of input instructions", required=True)
    parser.add_argument("-t", "--stressmark_type", type=str, help="Type of stressmark (coverage/switching/residency based)", required=False, default="res")
    parser.add_argument("-th", "--res_threshold", type=str, help="Residency Threshold", required=True)
    parser.add_argument("-p", "--print_val", type=int, help="Print insts (0) / Print weights (1)", required=True)

    #Paths
    SERMINER_CONFIG_HOME=os.environ['SERMINER_CONFIG_HOME']

    args = parser.parse_args()
    OUTPUT_DIR = args.output_dir
    NUM_INSTS = args.num_insts  
    if (args.stressmark_type):
        stressmk_type = args.stressmark_type  
    res_threshold = args.res_threshold
    if (args.print_val):
        PRINT_WEIGHTS = 1
        PRINT_INSTS = 0    
    else:
        PRINT_INSTS = 1    
        PRINT_WEIGHTS = 0    

    #out = sp.Popen(['wc -l ', str(OUTPUT_DIR),'/inst_list.txt'], stdout=sp.PIPE, stderr=sp.STDOUT) 
    #stdout, stderr = out.communicate()
    #print("Num insts: "+str(stdout))
    coverage_file = str(OUTPUT_DIR) + '/macro_perinst_coverage_th' +str(res_threshold)+'.txt'
    switching_file = str(OUTPUT_DIR) + '/macro_perinst_switching_th' +str(res_threshold)+'.txt'
    residency_file = str(OUTPUT_DIR) + '/macro_perinst_residency_th' +str(res_threshold)+'.txt'
    inst_list = str(SERMINER_CONFIG_HOME) + '/inst_list.txt'

    #Initialize lists
    cov_dict = defaultdict(list)
    sw_dict = defaultdict(list)
    res_dict = defaultdict(list)

    pruned_cov_dict = defaultdict(list)
    pruned_sw_dict = defaultdict(list)
    pruned_res_dict = defaultdict(list)

    macros_per_inst = np.zeros(NUM_INSTS)
    macro_sw_per_inst = np.zeros(NUM_INSTS)
    macro_res_per_inst = np.zeros(NUM_INSTS)

    inst_array = [line.rstrip('\n') for line in open(inst_list, 'r').readlines()]


    with open(coverage_file) as cf:
        for line in cf:
            dict_arr = line.split()
            cov_dict[dict_arr[0]] = np.array(dict_arr[1:len(dict_arr)]).astype(int)
            pruned_cov_dict[dict_arr[0]] = cov_dict[dict_arr[0]]
            cov_sum= np.sum(cov_dict[dict_arr[0]])
            macros_per_inst = macros_per_inst + cov_dict[dict_arr[0]]
            if (cov_sum==0):
                del pruned_cov_dict[dict_arr[0]]
            #else:
                #print(str(dict_arr[0]) + " : " +str(cov_sum))
    
    #print("Pruned_cov_dict:")
    #print(pruned_cov_dict)
    print("Macros with non-zero switching: " +str(len(pruned_cov_dict)))    

    with open(switching_file) as sf:
        for line in sf:
            dict_arr = line.split()
            sw_dict[dict_arr[0]] = np.array(dict_arr[1:len(dict_arr)]).astype(float)
            pruned_sw_dict[dict_arr[0]] = sw_dict[dict_arr[0]]
            sw_sum= np.sum(sw_dict[dict_arr[0]])
            macro_sw_per_inst = macro_sw_per_inst + sw_dict[dict_arr[0]]

            if (sw_sum==0):
                del pruned_sw_dict[dict_arr[0]]
            #else:
                #print(str(dict_arr[0]) + " : " +str(sw_sum))
    
    with open(residency_file) as rf:
        for line in rf:
            dict_arr = line.split()
            res_dict[dict_arr[0]] = np.array(dict_arr[1:len(dict_arr)]).astype(float)
            pruned_res_dict[dict_arr[0]] = res_dict[dict_arr[0]]
            res_sum= np.sum(res_dict[dict_arr[0]])
            macro_res_per_inst = macro_res_per_inst + res_dict[dict_arr[0]]

            if (res_sum==0):
                del pruned_res_dict[dict_arr[0]]
            #else:
                #print(str(dict_arr[0]) + " : " +str(res_sum))
    
    inst_index_dict = dict(zip(inst_array,range(0,len(inst_array))))
    inst_macro_dict = dict(zip(inst_array, macros_per_inst))
    inst_macro_sw_dict = dict(zip(inst_array, macro_sw_per_inst))
    inst_macro_res_dict = dict(zip(inst_array, macro_res_per_inst))
    
    #Preserve original list
    init_inst_macro_sw_dict = inst_macro_sw_dict.copy()
    init_inst_macro_res_dict = inst_macro_res_dict.copy()
    
    #print (inst_macro_sw_dict)
    #Recursive function to get list of instructions in stressmark
    stressmark_inst_list=[]
    #get_stressmark_inst( pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_sw_dict, stressmark_inst_list)    
    if (stressmk_type == "cov"):
        print ("Generating Coverage stressmark")
        get_stressmark_inst_cov( pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_sw_dict, stressmark_inst_list)    
    elif (stressmk_type == "sw"):
        get_stressmark_inst_sw( pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_sw_dict, stressmark_inst_list)    
    elif (stressmk_type == "sw_ex"):
        get_stressmark_inst_sw_exclude( pruned_cov_dict, pruned_sw_dict, inst_index_dict, inst_macro_dict, inst_macro_sw_dict, EXCLUDED_INST_LIST, stressmark_inst_list)    
    elif (stressmk_type == "res"):	# Default option for any core with no clock gating
        get_stressmark_inst_res( pruned_cov_dict, pruned_res_dict, inst_index_dict, inst_macro_dict, inst_macro_res_dict, stressmark_inst_list)    
    
    if(PRINT_INSTS):
        print("Print stressmark instructions")
        print(stressmark_inst_list)

    #print("Switching vals")
    #print("Max inst lists: " +str(stressmark_inst_list))
    if(PRINT_WEIGHTS):
        min_sw=min([init_inst_macro_sw_dict[inst] for inst in stressmark_inst_list])
        print("Print stressmark instruction weights")
        for inst in stressmark_inst_list:
            print(str(int(round(INST_SCALE_FACTOR*init_inst_macro_sw_dict[inst]/min_sw))),' ',end='')
           #print("Inst: "+str(inst) + " switching: " +str(init_inst_macro_sw_dict[inst]) + " Weight: " +str(int(round(INST_SCALE_FACTOR*init_inst_macro_sw_dict[inst]/min_sw))),' ',end='')
        print('')
    
            
if __name__ == "__main__":
   main()
