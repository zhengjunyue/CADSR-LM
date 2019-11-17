#!/bin/bash



# Copyright 2012-2014  Brno University of Technology (Author: Karel Vesely)
# Apache 2.0

# This example script trains a DNN on top of fMLLR features. 
# The training is done in 3 stages,
#
# 1) RBM pre-training:
#    in this unsupervised stage we train stack of RBMs, 
#    a good starting point for frame cross-entropy trainig.
# 2) frame cross-entropy training:
#    the objective is to classify frames to correct pdfs.
# 3) sequence-training optimizing sMBR: 
#    the objective is to emphasize state-sequences with better 
#    frame accuracy w.r.t. reference alignment.

# Note: With DNNs in RM, the optimal LMWT is 2-6. Don't be tempted to try acwt's like 0.2, 
# the value 0.1 is better both for decoding and sMBR.
#tests=("test" "test_word" "test_sentence" "test_head" "test_head_word" "test_head_sentence" "test_array" "test_array_word" "test_array_sentence")
tests1=("test_word" "test_head_word" "test_array_word")
tests2=("test_sentence" "test_head_sentence" "test_array_sentence")
tests3=("test_array_sentence")

lang=("lang_word_2" "lang_word_5" "lang_word_10" "lang_word_15" "lang_word_20" "lang_word_25" "lang_word_30" "lang_word_35" "lang_word_40" "lang_word_45" "lang_word_50" "lang_word_100" "lang_word_150" "lang_word_200")
lms_small=("lm0.05" "lm0.1" "lm0.2" "lm0.5" "lm1" "lm1.5")
lms=("lm2" "lm5" "lm10" "lm15" "lm20" "lm25" "lm30" "lm35" "lm40" "lm45" "lm50" "lm100" "lm150" "lm200")
lms1=("lm45" "lm50" "lm100" "lm150" "lm200")
lms2=("lm45")

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

. ./path.sh ## Source the tools/utils (import the queue.pl)

set -eu

echo "$0 $@"  # Print the command line for logging

# Config:
gmm=exp/tri3b
data_fmllr=data-fmllr-tri3b
stage=0 # resume training with --stage=N
nj=1
cv_spk_percent=8 # one speaker of the 14 in training for CV                                                               # End of config.
langdir=data/lang
. utils/parse_options.sh
#

echo "Store fMLLR features"
if [ $stage -le 0 ]; then
  # Store fMLLR features, so we can train on them easily,
  # test
#for x in test_word; do
#for y in "${lang[@]}"; do 
 #dir=$data_fmllr/$x$y
  #steps/nnet/make_fmllr_feats.sh --nj $nj --cmd "$train_cmd" \
   #  --transform-dir $gmm/decode_$x$y \
    # $dir data/$x $gmm $dir/log $dir/data
     #done
#done
 
for x in test_sentence; do
 for y in "${lms_small[@]}"; do
  dir=$data_fmllr/$x$y
  steps/nnet/make_fmllr_feats.sh --nj $nj --cmd "$train_cmd" \
     --transform-dir $gmm/decode_$x$y \
     $dir data/$x $gmm $dir/log $dir/data
     done
done
 # train
  dir=$data_fmllr/train
  steps/nnet/make_fmllr_feats.sh --nj $nj --cmd "$train_cmd" \
     --transform-dir ${gmm}_ali \
     $dir data/train $gmm $dir/log $dir/data
  # split the data : 13 speakers train 1 speaker cross-validation (held-out)
  utils/subset_data_dir_tr_cv.sh --cv-spk-percent ${cv_spk_percent}  $dir ${dir}_tr90 ${dir}_cv10
fi

echo "Pre-train DBN"
if [ $stage -le 1 ]; then
  # Pre-train DBN, i.e. a stack of RBMs (small database, smaller DNN)
  dir=exp/dnn3b_pretrain-dbn
  $cuda_cmd $dir/log/pretrain_dbn.log steps/nnet/pretrain_dbn.sh --hid-dim 1024 --rbm-iter 20 $data_fmllr/train $dir
echo "finish DBN"

fi

echo "Train the DNN optimizing per-frame cross-entropy"
if [ $stage -le 2 ]; then
  # Train the DNN optimizing per-frame cross-entropy.
  dir=exp/dnn3b_pretrain-dbn_dnn
  ali=${gmm}_ali
  feature_transform=exp/dnn3b_pretrain-dbn/final.feature_transform
  dbn=exp/dnn3b_pretrain-dbn/6.dbn
  # Train
  $cuda_cmd $dir/log/train_nnet.log steps/nnet/train.sh --feature-transform $feature_transform --dbn $dbn --hid-layers 0 --learn-rate 0.008 \
    $data_fmllr/train_tr90 $data_fmllr/train_cv10 $langdir $ali $ali $dir || exit 1
  
echo "finish DNN training"

# Decode (reuse HCLG graph)
 
# for x in "${tests[@]}"; do
 #steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode_dnn.config --acwt 0.1 \
  #  $gmm/graph_$x $data_fmllr/$x $dir/decode_$x #cris graph_test
   # done
fi
if [ $stage -le 3 ]; then
dir=exp/dnn3b_pretrain-dbn_dnn

#for x in test_word; do
#for y in "${lang[@]}"; do

#steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode_dnn.config --acwt 0.1 $gmm/graph_$y $data_fmllr/$x$y $dir/decode_$x$y #cris graph_test
 #done
  #done 
for x in test_sentence; do
for y in "${lms_small[@]}"; do
steps/nnet/decode.sh --nj $nj --cmd "$decode_cmd" --config conf/decode_dnn.config --acwt 0.1 $gmm/graph_$y $data_fmllr/$x$y $dir/decode_$x$y
  done
  done


fi
echo Success
exit 0
# Getting results [see RESULTS file]
# for x in exp/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
# to see how model conversion to nnet2 works, run run_dnn_convert_nnet2.sh at this point.
