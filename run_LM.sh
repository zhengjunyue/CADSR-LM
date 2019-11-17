#!/bin/bash
#$ -P rse
#$ -q rse.q
#$ -l rmem=14G
#$ -M z.yue@sheffield.ac.uk
#$ -m a

# qsub command: cmd.sh conf/queue.conf qsub command
# sharc (96h max)
# qsub -V -l h_rt=48:00:00 -o qsub_torgo -e qsub_torgo -j y ./run.sh --njobs 14 --njobsT 1 --spktest "" --stage 0


# Begin configuration section.
# The number of parallel jobs to be started for some parts of the recipe
# Since the test is just one speaker we don't parellelize it
# Make sure you have enough resources(CPUs and RAM) to accomodate this number of jobs
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

spk_test=$spktest
lang_wsj=/data/ac1zy/kaldi/egs/wsj/s5/data/lang_nosp

# Test-time language model order
lm_order=3
# Subtests to be decoded
tests=("test" "test_head" "test_head_word" "test_head_sentence" "test_array" "test_array_word" "test_array_sentence")


# Word position dependent phones?
pos_dep_phones=true

# Number of leaves and total gaussians
leaves=1800
gaussians=9000 
 
# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false
#. utils/parse_options.sh || exit 1

[[ $# -ge 2 ]] && { echo "Unexpected arguments"; exit 1; } 



if [ $stage -le 0 ]; then
# Initial extraction and distribution of the data: data/{train,test} directories  
## TODO: aixo no em funciona i hauria pq es standard
#local/torgo_data_prep.sh --spk_test ${spk_test} || exit 1
local/torgo_data_prep_multi.sh ${spk_test} || exit 1
# Prepare ARPA LM and vocabulary using SRILM
#local/torgo_prepare_lm.sh --order ${lm_order} || exit 1

# Prepare the lexicon and various phone lists
# Pronunciations for OOV words are obtained using a pre-trained Sequitur model
#local/torgo_prepare_dict.sh || exit 1


# Prepare data/lang and data/local/lang directories
echo ""
echo "=== Preparing data/lang and data/local/lang directories ..."
echo ""
#utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones \
 # data/local/dict '!SIL' data/local/lang data/lang || exit 1

# Prepare G.fst and data/{train,test} directories

  #local/torgo_prepare_grammar.sh "test" || exit 1


#Bahman's strategy to train LM
#local_dem/make_language/train_lms_srilm.sh <lang_nosp> <train_text> <dev_text> <LM_folder> <lm.gz>
#e.g. local_dem/make_language/train_lms_srilm.sh lang/lang_nosp $train/text $test/text $lm lm.gz
  
local/train_lms_srilm.sh $lang_wsj data/train_90/text data/train_10/text data/lang lm.gz || exit 1
fi


if [ $stage -le 1 ]; then
# Now make MFCC features.
echo ""
echo "=== Making MFCC features ..."
echo ""
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=${spk_test}/mfcc
#for x in "${tests[@]}"; do
# steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 \
#   data/$x exp/make_mfcc/$x $mfccdir || exit 1;
# steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
#done
# steps/make_mfcc.sh --cmd "$train_cmd" --nj 14 \
#   data/train exp/make_mfcc/train $mfccdir || exit 1;
# steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir || exit 1;
utils/validate_data_dir.sh data/train
utils/fix_data_dir.sh data/train 
# Change previous lines for these ones if you want to calculate 
# features differently for speakers with dysartria and for control speakers 
for x in "${tests[@]}"; do 
 local/torgo_make_mfcc.sh --cmd "$train_cmd" --nj 1 \
   data/$x exp/make_mfcc/$x $mfccdir || exit 1;
 steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
done

local/torgo_make_mfcc.sh --cmd "$train_cmd" --nj $njobs \
   data/train exp/make_mfcc/train $mfccdir || exit 1;
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir || exit 1;





# Train monophone models on a subset of the data
echo ""
echo "=== Monophone models ..."
echo ""
echo "--- Training"
#utils/subset_data_dir.sh data/train 1000 data/train.1k  || exit 1;
steps/train_mono.sh --nj $njobs --cmd "$train_cmd" data/train data/lang/lang exp/mono  || exit 1;


# Monophone decoding
echo "--- Monophone decoding"    
  utils/mkgraph.sh --mono data/lang/lang exp/mono exp/mono/graph_test || exit 1
# note: local/decode.sh calls the command line once for each
# test, and afterwards averages the WERs into (in this case
# exp/mono/decode/
for x in "${tests[@]}"; do     
  steps/decode.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" \
    exp/mono/graph_test data/$x exp/mono/decode_$x
done
fi

if [ $stage -le 2 ]; then
# Get alignments from monophone system.
steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
  data/train data/lang/lang exp/mono exp/mono_ali || exit 1;

echo ""
echo "=== Triphone models ..."
# train tri1 [first triphone pass]
echo ""
echo "--- tri1 (first triphone pass, velocity)"
steps/train_deltas.sh --cmd "$train_cmd" \
  $leaves $gaussians data/train data/lang/lang exp/mono_ali exp/tri1 || exit 1;

# decode tri1

  utils/mkgraph.sh data/lang/lang exp/tri1 exp/tri1/graph_test || exit 1;
  for x in "${tests[@]}"; do
  steps/decode.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" \
     exp/tri1/graph_test data/$x exp/tri1/decode_$x
done

draw-tree data/lang/lang/phones.txt exp/tri1/tree | dot -Tps -Gsize=8,10.5 | ps2pdf - tree.pdf

# align tri1
steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
  --use-graphs true data/train data/lang/lang exp/tri1 exp/tri1_ali || exit 1;

# train tri2a [delta+delta-deltas] (velocity+acceleration)
echo ""
echo "--- tri2a (delta + delta-deltas, velocity+acceleration)"
steps/train_deltas.sh --cmd "$train_cmd" $leaves $gaussians \
  data/train data/lang/lang exp/tri1_ali exp/tri2a || exit 1;

# decode tri2a

  utils/mkgraph.sh data/lang/lang exp/tri2a exp/tri2a/graph_test
  for x in "${tests[@]}"; do
  steps/decode.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" \
    exp/tri2a/graph_test data/$x exp/tri2a/decode_$x
done

# train and decode tri2b [LDA+MLLT]
echo ""
echo "--- tri2b (LDA+MLLT)"
steps/train_lda_mllt.sh --cmd "$train_cmd" $leaves $gaussians \
  data/train data/lang/lang exp/tri1_ali exp/tri2b || exit 1;

# decode tri2b

  utils/mkgraph.sh data/lang/lang exp/tri2b exp/tri2b/graph_test
  for x in "${tests[@]}"; do
  steps/decode.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" \
    exp/tri2b/graph_test data/$x exp/tri2b/decode_$x
done

# Align all data with LDA+MLLT system (tri2b)
steps/align_si.sh --nj $njobs --cmd "$train_cmd" --use-graphs true \
   data/train data/lang/lang exp/tri2b exp/tri2b_ali || exit 1;


# Do MMI on top of LDA+MLLT.
# Maximum Mutual Information
echo ""
echo "---  MMI on top of LDA+MLLT"

steps/make_denlats.sh --nj $njobs --cmd "$train_cmd" \
  data/train data/lang/lang exp/tri2b exp/tri2b_denlats || exit 1;
steps/train_mmi.sh --cmd "$train_cmd" data/train data/lang/lang exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi || exit 1;

for x in "${tests[@]}"; do
  #steps/decode.sh --config conf/decode.config --iter 4 --nj $njobsT --cmd "$decode_cmd" \
     #exp/tri2b/graph_test data/$x exp/tri2b_mmi/decode_$x._it4
  steps/decode.sh --config conf/decode.config --iter 3 --nj $njobsT --cmd "$decode_cmd" \
     exp/tri2b/graph_test data/$x exp/tri2b_mmi/decode_$x._it3
done


<<'COMMENT' ...
# Do the same with boosting.
echo ""
echo "---  MMI with boosting on top of LDA+MLLT"
steps/train_mmi.sh --cmd "$train_cmd" --boost 0.05 data/train data/lang \
   exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mmi_b0.05 || exit 1;

for x in "${tests[@]}"; do
  steps/decode.sh --config conf/decode.config --iter 4 --nj $njobsT --cmd "$decode_cmd" \
    exp/tri2b/graph_test data/$x exp/tri2b_mmi_b0.05/decode_$x._it4 || exit 1;
  steps/decode.sh --config conf/decode.config --iter 3 --nj $njobsT --cmd "$decode_cmd" \
    exp/tri2b/graph_test data/$x exp/tri2b_mmi_b0.05/decode_$x._it3 || exit 1;
done
COMMENT

# Do MPE.
# Minimum Phone Error
echo ""
echo "---  MPE on top of LDA+MLLT"
steps/train_mpe.sh --cmd "$train_cmd" data/train data/lang/lang exp/tri2b_ali exp/tri2b_denlats exp/tri2b_mpe || exit 1;
for x in "${tests[@]}"; do
  #steps/decode.sh --config conf/decode.config --iter 4 --nj $njobsT --cmd "$decode_cmd" \
    #exp/tri2b/graph_test data/$x exp/tri2b_mpe/decode_$x._it4 || exit 1;
  steps/decode.sh --config conf/decode.config --iter 3 --nj $njobsT --cmd "$decode_cmd" \
    exp/tri2b/graph_test data/$x exp/tri2b_mpe/decode_$x_.it3 || exit 1;
done
fi



if [ $stage -le 3 ]; then
## Do LDA+MLLT+SAT, and decode.
echo ""
echo "--- tri3b (LDA+MLLT+SAT)"
steps/train_sat.sh --cmd "$train_cmd" $leaves $gaussians data/train data/lang/lang exp/tri2b_ali exp/tri3b || exit 1;


  utils/mkgraph.sh data/lang/lang exp/tri3b exp/tri3b/graph_test || exit 1;
  for x in "${tests[@]}"; do
  steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" \
    exp/tri3b/graph_test data/$x exp/tri3b/decode_$x || exit 1;
done

# Align all data with LDA+MLLT+SAT system (tri3b)
steps/align_fmllr.sh --nj $njobs --cmd "$train_cmd" --use-graphs true \
  data/train data/lang/lang exp/tri3b exp/tri3b_ali || exit 1;


## MMI on top of tri3b (i.e. LDA+MLLT+SAT+MMI)
echo ""
echo "---  MMI on top of tri3b (LDA+MLLT+SAT+MMI)"
steps/make_denlats.sh --config conf/decode.config \
   --nj $njobs --cmd "$train_cmd" --transform-dir exp/tri3b_ali \
  data/train data/lang/lang exp/tri3b exp/tri3b_denlats || exit 1;
steps/train_mmi.sh --cmd "$train_cmd" data/train data/lang/lang exp/tri3b_ali exp/tri3b_denlats exp/tri3b_mmi || exit 1;
for x in "${tests[@]}"; do
  steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" \
    --alignment-model exp/tri3b/final.alimdl --adapt-model exp/tri3b/final.mdl \
     exp/tri3b/graph_test data/$x exp/tri3b_mmi/decode_$x || exit 1;
done 
# Do a decoding that uses the exp/tri3b/decode directory to get transforms from.
for x in "${tests[@]}"; do
  steps/decode.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" \
    --transform-dir exp/tri3b/decode_$x  exp/tri3b/graph_test data/$x exp/tri3b_mmi/decode2_$x || exit 1;
done





echo ""
echo "--- fMMI"
#first, train UBM for fMMI experiments.
#Universal Background Model
steps/train_diag_ubm.sh --silence-weight 0.5 --nj $njobs --cmd "$train_cmd" \
  250 data/train data/lang/lang exp/tri3b_ali exp/dubm3b  ##need to be edited 




# Next, various fMMI+MMI configurations.

<<'COMMENT' ...
steps/train_mmi_fmmi.sh --learning-rate 0.0025 \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_b || exit 1;

  for x in "${tests[@]}"; do
     steps/decode_fmmi.sh --nj $njobsT --config conf/decode.config --cmd "$decode_cmd" --iter 4 \
       --transform-dir exp/tri3b/decode_$x  exp/tri3b/graph_test data/$x exp/tri3b_fmmi_b/decode_it_$x$iter 
  done
COMMENT




steps/train_mmi_fmmi.sh --learning-rate 0.001 \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_0.001 || exit 1;

  for x in "${tests[@]}"; do
     steps/decode_fmmi.sh --nj $njobsT --config conf/decode.config --cmd "$decode_cmd" --iter 4 \
       --transform-dir exp/tri3b/decode_$x  exp/tri3b/graph_test data/$x exp/tri3b_fmmi_c/decode_it$x4 
  done


<<'COMMENT' ...
# for indirect one, use twice the learning rate.
steps/train_mmi_fmmi_indirect.sh --learning-rate 0.002 --schedule "fmmi fmmi fmmi fmmi mmi mmi mmi mmi" \
  --boost 0.1 --cmd "$train_cmd" data/train data/lang exp/tri3b_ali exp/dubm3b exp/tri3b_denlats \
  exp/tri3b_fmmi_d || exit 1;
for iter in 3 4 5 6 7 8; do
  for x in "${tests[@]}"; do
    steps/decode_fmmi.sh --nj $njobsT --config conf/decode.config --cmd "$decode_cmd" --iter $iter \
      --transform-dir exp/tri3b/decode_$x  exp/tri3b/graph_test data/$x exp/tri3b_fmmi_d/decode_it$x$iter &
  done
done
COMMENT




# train another LDA+MLLT+SAT system 
## Do LDA+MLLT+SAT on the previous one, and decode.                                                                                       
echo ""
echo "--- tri4b (LDA+MLLT+SAT+SAT)"
steps/train_sat.sh --cmd "$train_cmd" $leaves $gaussians  data/train data/lang/lang exp/tri3b_ali exp/tri4b || exit 1;

# decode using the tri4b model

  utils/mkgraph.sh data/lang/lang exp/tri4b exp/tri4b/graph_test || exit 1;
  for x in "${tests[@]}"; do
  steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/tri4b/graph_test data/$x exp/tri4b/decode_$x || exit 1; 
done

#steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test  data/test exp/tri4b/decode  || exit 1;
#steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" data/lang_test data/test exp/tri4b/decode || exit 1;

# align train using the tri4b model
steps/align_fmllr.sh --nj $njobs --cmd "$train_cmd" --use-graphs true  data/train data/lang/lang exp/tri4b exp/tri4b_ali || exit 1;
fi
for x in exp/*/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh >> ./result_${spk_test}.txt; done; 

exit



if [ $stage -le 4 ]; then
echo ""
echo "--- SGMM"
# Subspace Gaussian Mixture Models (SGMMs)
#local/run_sgmm2.sh --nj $njobsT

fi


if [ $stage -le 5 ]; then
echo ""
echo "=== Neural Network models ..."
#echo "--- nnet: Deep Neural Network (dnn)"
# Karel's neural net recipe.
local/nnet/run_dnn.sh --nj $njobsT 
fi


#echo ""
#echo "--- nnet: Convolutional Neural Network (cnn)"
# Karel's CNN recipe. 
#local/nnet/run_cnn.sh --nj $njobsT

#echo ""
#echo "--- nnet: Convolutional Neural Network"
# Karel's 2D-CNN recipe (from Harish). NOT CHECKED 
# local/nnet/run_cnn2d.sh --nj $njobsT

#echo ""
#echo "--- nnet: Autoencoder" 
# NOT WORKING
#local/nnet/run_autoencoder.sh


if [ $stage -le 6 ]; then
echo ""
echo "--- nnet3: Deep Neural Network baseline without i-vectors"
 local/nnet3/run_tdnn_baseline_noIvec.sh 
fi


#echo ""
#echo "--- nnet3: Deep Neural Network baseline with i-vectors"
# local/nnet3/run_tdnn_baseline_ivec.sh  # designed for exact comparison with nnet2 recipe
if [ $stage -le 7 ]; then
echo ""
echo "--- nnet3: Time Delay Neural Network (tdnn) without i-vectors " 
local/nnet3/run_tdnn_noIvec.sh --stage 3  # better absolute results
fi
#echo ""
#echo "--- nnet3: Time Delay Neural Network (tdnn) with i-vectors " 
#local/nnet3/run_tdnn_ivec.sh --stage 8 # better absolute results

#echo ""
#echo "--- nnet3: Long Short Time Memory (lstm) without i-vectors " 
# local/nnet3/run_lstm_noIvec.sh  --stage 3 # lstm recipe

echo ""
#echo "--- nnet3: Long Short Time Memory (lstm) with i-vectors " 
# local/nnet3/run_lstm_ivec.sh --stage 8  # lstm recipe
if [ $stage -le 8 ]; then
echo ""
echo "--- nnet3: Bidirectional Long Short Time Memory (lstm) without i-vectors "
local/nnet3/run_lstm_noIvec.sh  --stage 3 --affix bidirectional \
                 --lstm-delay " [-1,1] [-2,2] [-3,3] " \
                 --label-delay 0 \
                 --cell-dim 640 \
                 --recurrent-projection-dim 128 \
                 --non-recurrent-projection-dim 128 \
                 --chunk-left-context 40 \
                 --chunk-right-context 40
fi
# Looking at the results. Summary.
echo "Print best results summary"
echo "--- WER scores"
for x in exp/*/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh >> ./result_${spk_test}.txt; done; 
for x in exp/*/nn*/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh >> ./result_${spk_test}.txt; done; 





