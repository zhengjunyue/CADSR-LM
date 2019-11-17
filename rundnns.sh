#!/bin/bash
# -l gpu=1
#$ -l h_rt=30:00:00
#$ -l rmem=20G
#$ -M z.yue@sheffield.ac.uk
#$ -m bea
#$ -P rse
#$ -q rse.q
# -q all.q
# -P all
# -q gpu.q
# -q rse-gpu.q
# -P tapas 
# -q tapas.q




# qsub command: cmd.sh conf/queue.conf qsub command
# sharc (96h max)
# qsub -V -o qsub_torgo -e qsub_torgo -j y ./rundnns.sh --njobs 14 --njobsT 1 --spktest "" --stage 0


# Begin configuration section.
njobs=14  # probably max 13 for ctl and max 15 for dys due to limited speakers
njobsT=1  # 1
stage=0
spktest=""  # ctl: training with control speech data, or "dys": training with speech from dysarthric speakers
# End configuration section

#ln -s /fastdata/ac1zy/kaldi/egs/torgo/s5/F01/exp exp

# Author: Cristina Espana-Bonet
# Adaptation from Voxforge run.sh:
# Copyright 2012 Vassil Panayotov                                                                                         
# Apache 2.0                                                                                                                          
# Paths to software and data
. ./utils/parse_options.sh

. ./path.sh || exit 1

# If you have cluster of machines running GridEngine you may want to
# change the train and decode commands in the file below
. ./cmd.sh || exit 1

# The number of parallel jobs to be started for some parts of the recipe
# Since the test is just one speaker we don't parellelize it
# Make sure you have enough resources(CPUs and RAM) to accomodate this number of jobs
#njobs=1
#njobsT=1

# Test-time language model order
lm_order=2

# Word position dependent phones?
pos_dep_phones=true

# Test user
spk_test=$spktest

# Number of leaves and total gaussians
leaves=1800
gaussians=9000

# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false
. utils/parse_options.sh || exit 1

[[ $# -ge 2 ]] && { echo "Unexpected arguments"; exit 1; }



if [ $stage -le 0 ]; then
echo ""
echo "=== Neural Network models ..."
echo "--- nnet: Deep Neural Network (dnn)"
# Karel's neural net recipe.
local/nnet/run_dnn.sh --nj $njobsT --stage 3
fi
exit
if [ $stage -le 1 ]; then
# # A couple of nnet3 recipes:
echo ""
# local/nnet3/run_tdnn_baseline.sh  # designed for exact comparison with nnet2 recipe
echo "--- nnet3: Time Delay Neural Network (tdnn)" 
local/nnet3/run_tdnn_noIvec.sh  # better absolute results
fi


if [ $stage -le 2 ]; then
# # A couple of nnet3 recipes:
echo ""
# local/nnet3/run_tdnn_baseline.sh  # designed for exact comparison with nnet2 recipe
echo "--- chain: Time Delay Neural Network (cnn_tdnnf)" 
local/chain/tuning/run_cnn_tdnn_1c.sh   # better absolute results
fi


echo ""
#echo "--- nnet: Convolutional Neural Network"
# Karel's CNN recipe. NOT CHECKED
#local/nnet/run_cnn.sh --nj $njobsT

echo ""
#echo "--- nnet: Convolutional Neural Network"
# Karel's 2D-CNN recipe (from Harish). NOT CHECKED 
# local/nnet/run_cnn2d.sh --nj $njobsT


echo ""
#echo "--- nnet: Autoencoder" 
# NOT WORKING
#local/nnet/run_autoencoder.sh

echo ""
#echo "--- nnet2: Deep Neural Network"
# if you want at this point you can train and test NN model(s)
#local/nnet2/run_5a_clean_100.sh || exit 1



# local/nnet3/run_lstm.sh  # lstm recipe
# bidirectional lstm recipe
# local/nnet3/run_lstm.sh --affix bidirectional \
#                  --lstm-delay " [-1,1] [-2,2] [-3,3] " \
#                         --label-delay 0 \
#                         --cell-dim 640 \
#                         --recurrent-projection-dim 128 \
#                         --non-recurrent-projection-dim 128 \
#                         --chunk-left-context 40 \
#                         --chunk-right-context 40

# Looking at the results. Summary.
echo "Print best results summary"
echo "--- WER scores"
for x in exp/*/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh >> ./result_${spk_test}.txt; done


©
