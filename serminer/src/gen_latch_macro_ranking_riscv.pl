#!/usr/bin/env perl
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

use List::Util qw( min max );

use List::Util qw(sum max min);
use List::MoreUtils qw(uniq);
use Getopt::Std;
use IO::File;
use strict;
use warnings;
use Cwd 'abs_path';

#Check if env variable is set
if(!$ENV{'ERASER_SETENV'})
{
	die ("ERASER environment not set. Please run: source eraser_setenv\n");
}

if ($#ARGV != 2 ) { die "Syntax: perl gen_latch_macro_ranking_riscv.pl <INPUT_DIR> <OUTPUT_DIR> <RESIDENCY THRESHOLD>\n"; }

my $PARSE_VCDSTATS=1;
my $GEN_MACRO_HASH=1;

my $INPUT_DIR = $ARGV[0];
my $OUTPUT_DIR = $ARGV[1];
my $RESIDENCY_THRESHOLD = $ARGV[2];

my $macro_datafile;
my $tmp_swlist;
my $tmp_reslist;

my $max_macro_cov;
my $max_macro_sw;
my $max_macro_res;

my @macro_list;
my @bit_list;
my @sw_list;
my @res_list;
my @thresholded_hash;

my %macro_coverage_hash;
my %macro_switching_hash;
my %macro_residency_hash;

my $CONFIG_DIR=$ENV{'SERMINER_CONFIG_HOME'};
my $MACRO_PERINST_OUTPUT="$OUTPUT_DIR/res_th_$RESIDENCY_THRESHOLD";
system("mkdir -p $MACRO_PERINST_OUTPUT");

my $macro_cov_file="$MACRO_PERINST_OUTPUT/macro_perinst_coverage_th${RESIDENCY_THRESHOLD}.txt";
my $macro_sw_file="$MACRO_PERINST_OUTPUT/macro_perinst_switching_th${RESIDENCY_THRESHOLD}.txt";
my $macro_res_file="$MACRO_PERINST_OUTPUT/macro_perinst_residency_th${RESIDENCY_THRESHOLD}.txt";
my $macro_inst_list="$CONFIG_DIR/inst_list.txt";

my $inst;
my $fctr=0;

system("rm -f $macro_cov_file");
system("rm -f $macro_sw_file");
system("rm -f $macro_res_file");

#Obtain macro and latch names
#my $tmp_latchlist = `awk '{print \$1}' $fname`; my @latch_list = split(/\n/, $tmp_latchlist);

#Generate macro and latch level stats

if ($PARSE_VCDSTATS)
{

	print ("Parsing VCD Stats\n");
	#Create instruction list
	#system("rm -f $macro_inst_list");

	foreach my $fname (`ls -v $INPUT_DIR/*.stats`)
	{
		chomp($fname);
		$macro_datafile = "${OUTPUT_DIR}/${inst}_macro_data.txt";
		$inst = `basename $fname | awk -F '.stats' '{print \$1}'`; chomp($inst);
		system("echo \${SERMINER_HOME}/src/parse_vcdstats.sh $fname $inst $OUTPUT_DIR");
		system("\${SERMINER_HOME}/src/parse_vcdstats.sh $fname $inst $OUTPUT_DIR");
		#system("echo $inst >> $macro_inst_list");
	}
}

if ($GEN_MACRO_HASH)
{
	print "Gen macro hash\n";
	foreach my $mname (`ls -v $OUTPUT_DIR/*macro_data.txt`)
	{
		if ($fctr==0)
		{
			my $tmp_macrolist = `awk '{ if (NR>1) print \$1}' $mname`; @macro_list = split(/\n/, $tmp_macrolist);
			my $tmp_bitlist = `awk '{ if (NR>1) print \$3}' $mname`; @bit_list = split(/\n/, $tmp_bitlist);
		}
		
		$tmp_swlist = `awk '{ if (NR>1) print \$(NF-1)}' $mname`; @sw_list = split(/\n/, $tmp_swlist);
		$tmp_reslist = `awk '{ if (NR>1) print \$(NF)}' $mname`; @res_list = split(/\n/, $tmp_reslist);
		
		for (my $i=0; $i<=$#macro_list; $i++)
		{
			#print("$macro_list[$i]: $bit_list[$i] $sw_list[$i]\n");
			if ($sw_list[$i])
			{
				#$macro_coverage_hash{$macro_list[$i]}[$fctr] = $sw_list[$i]?($sw_list[$i]>0?1:0):0; 
				$macro_coverage_hash{$macro_list[$i]}[$fctr] = $sw_list[$i]>0?1:0; 
				$macro_switching_hash{$macro_list[$i]}[$fctr] = $sw_list[$i];
				$macro_residency_hash{$macro_list[$i]}[$fctr] = $res_list[$i];
			}
		}	
		$fctr++;
	}

	#	for (my $i=0;$i<=$#macro_list; $i++)
	#	{
	#		print("$macro_list[$i]: $bit_list[$i] $sw_list[$i]\n");
	#	}

	foreach my $key (keys %macro_coverage_hash)
	{
		#$max_macro_cov = max @{$macro_coverage_hash{$key}};
		$max_macro_res = max @{$macro_residency_hash{$key}};
		#@thresholded_hash = map {($_ >= $RESIDENCY_THRESHOLD*$max_macro_cov)?$_:0} @{$macro_coverage_hash{$key}};
		@thresholded_hash = map {($_ >= $RESIDENCY_THRESHOLD*$max_macro_res)?1:0} @{$macro_residency_hash{$key}};
		#print("$key, $max_macro_cov, @{$macro_coverage_hash{$key}}\n");
		#print("$key, @thresholded_hash\n ");
		system("echo $key @thresholded_hash >> $macro_cov_file");
	}

	foreach my $key (keys %macro_switching_hash)
	{
		$max_macro_sw = max @{$macro_switching_hash{$key}};
		@thresholded_hash = map {($_ >= $RESIDENCY_THRESHOLD*$max_macro_sw)?$_:0} @{$macro_switching_hash{$key}};
		#print("$key,$max_macro_sw @{$macro_switching_hash{$key}}\n");
		#print("$key, @thresholded_hash\n ");
		system("echo $key @thresholded_hash >> $macro_sw_file");
	}
	foreach my $key (keys %macro_residency_hash)
	{
		$max_macro_res = max @{$macro_residency_hash{$key}};
		@thresholded_hash = map {($_ >= $RESIDENCY_THRESHOLD*$max_macro_res)?$_:0} @{$macro_residency_hash{$key}};
		#print("$key,$max_macro_res @{$macro_residency_hash{$key}}\n");
		system(" echo $key @thresholded_hash >> $macro_res_file");
	}
	#Copy over instruction list to res_th folder
	system("cp $CONFIG_DIR/inst_list.txt $MACRO_PERINST_OUTPUT/.");
}
