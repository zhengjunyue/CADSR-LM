#!/bin/bash
#$ -l h_rt=30:00:00
#$ -l rmem=16G
#$ -M z.yue@sheffield.ac.uk
#$ -m bea
#$ -P rse
#$ -q rse.q
# -l gpu=1
# -P tapas 
# -q tapas.q

# qsub command: cmd.sh conf/queue.conf qsub command
# sharc (96h max)
# qsub -V -o qsub_torgo -e qsub_torgo -j y ./run.sh --njobs 14 --njobsT 1 --spktest "" --stage 0


# Begin configuration section.

njobs=14  # probably max 13 for ctl and max 15 for dys due to limited speakers
njobsT=1  # 1
stage=0
spktest=""  # ctl: training with control speech data, or "dys": training with speech from dysarthric speakers

version=0  #new method
         #change this variable and stage 


# End configuration section
#ln -s /fastdata/ac1zy/kaldi/egs/torgo/s5/F01/exp exp

                                                                                                                        
# Paths to software and data
. ./utils/parse_options.sh
. ./path.sh || exit 1

# If you have cluster of machines running GridEngine you may want to
# change the train and decode commands in the file below
. ./cmd.sh || exit 1


spk_test=$spktest
# Test-time language model order
lm_order=3
# Subtests to be decoded
#tests=("test" "test_word" "test_sentence" "test_head" "test_head_word" "test_head_sentence" "test_array" "test_array_word" "test_array_sentence")

tests_sent=("test_sentence" "test_head_sentence" "test_array_sentence")
tests_word=("test_word" "test_head_word" "test_array_word")

#langs=("lang_word_20" "lang_word_30" "lang_word_40")

lang=("lang_word_2" "lang_word_5" "lang_word_10" "lang_word_15" "lang_word_20" "lang_word_25" "lang_word_30" "lang_word_35" "lang_word_40" "lang_word_45" "lang_word_50" "lang_word_100" "lang_word_150" "lang_word_200")


lms=("lm0" "lm2" "lm5" "lm10" "lm15" "lm20" "lm25" "lm30" "lm35" "lm40" "lm40" "lm50" "lm100" "lm150" "lm200")

# Word position dependent phones?
pos_dep_phones=false

# Number of leaves and total gaussians
leaves=700
gaussians=9000 
 
# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false


[[ $# -ge 2 ]] && { echo "Unexpected arguments"; exit 1; } 



if [ $stage -le 0 ]; then

# Initial extraction and distribution of the data: data/{train,test} directories  



echo
echo "===== PREPARING LANGUAGE DATA ====="
echo
# Needs to be prepared by hand (or using self written scripts):
#
# lexicon.txt           [<word> <phone 1> <phone 2> ...]
# nonsilence_phones.txt [<phone>]
# silence_phones.txt    [<phone>]
# optional_silence.txt  [<phone>]
# Preparing language data
utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones data/local/dict "<UNK>" data/local/lang_pi_tmp data/phidp/lang || exit 1
local/format_lms.sh --src-dir data/phidp/lang data/local/lm || exit 1
  
fi




if [ $stage -le 2 ]; then
# Train monophone models on a subset of the data
echo ""
echo "=== Monophone models ..."
echo ""
echo "--- Training"
#utils/subset_data_dir.sh data/train 1000 data/train.1k  || exit 1;
steps/train_mono.sh --nj $njobs --cmd "$train_cmd" data/train data/phidp/lang exp/phidp/mono  || exit 1;
# Get alignments from monophone system.
steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
  data/train data/phidp/lang exp/phidp/mono exp/phidp/mono_ali || exit 1;
fi


if [ $stage -le 3 ]; then
echo ""
echo "=== Triphone models ..."
# train tri1 [first triphone pass]
echo ""
echo "--- tri1 (first triphone pass, velocity)"
steps/train_deltas.sh --cmd "$train_cmd" \
  $leaves $gaussians data/train data/phidp/lang exp/phidp/mono_ali exp/phidp/tri1 || exit 1;

#utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph_test || exit 1;
# align tri1
steps/align_si.sh --nj $njobs --cmd "$train_cmd" data/train data/phidp/lang exp/phidp/tri1 exp/phidp/tri1_ali || exit 1;


# train and decode tri2b [LDA+MLLT]
echo ""
echo "--- tri2b (LDA+MLLT)"
steps/train_lda_mllt.sh --cmd "$train_cmd" $leaves $gaussians \
  data/train data/phidp/lang exp/phidp/tri1_ali exp/phidp/tri2b || exit 1;
#utils/mkgraph.sh data/lang exp/tri2b exp/tri2b/graph_test
# Align all data with LDA+MLLT system (tri2b)
steps/align_si.sh --nj $njobs --cmd "$train_cmd" data/train data/phidp/lang exp/phidp/tri2b exp/phidp/tri2b_ali || exit 1;

fi


if [ $stage -le 4 ]; then
## Do LDA+MLLT+SAT, and decode.
echo ""
echo "--- tri3b (LDA+MLLT+SAT)"
steps/train_sat.sh --cmd "$train_cmd" $leaves $gaussians data/train data/phidp/lang exp/phidp/tri2b_ali exp/phidp/tri3b || exit 1;

#utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph_test || exit 1;
# Align all data with LDA+MLLT+SAT system (tri3b)
steps/align_fmllr.sh --nj $njobs --cmd "$train_cmd" data/train data/phidp/lang exp/phidp/tri3b exp/phidp/tri3b_ali || exit 1
fi




if [ $stage -le 5 ]; then
echo ""
echo "--- Decode tri3b"
for y in "${lang[@]}"; do
utils/mkgraph.sh data/phidp/$y exp/phidp/tri3b exp/phidp/tri3b/graph_$y || exit 1; 

for x in "${tests_word[@]}"; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/phidp/tri3b/graph_$y data/$x exp/phidp/tri3b/decode_$x$y || exit 1;
done
done
fi


if [ $stage -le 6 ]; then
echo ""
echo "--- Decode tri3b"
for y in "${lms[@]}"; do
utils/mkgraph.sh data/phidp/lang_$y exp/phidp/tri3b exp/phidp/tri3b/graph_$y || exit 1;

for x in "${tests_sent[@]}"; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/phidp/tri3b/graph_$y data/$x exp/phidp/tri3b/decode_$x$y || exit 1;
done
done
fi
exit

if [ $stage -le 8 ]; then
echo ""
echo "--- Decode tri3b"
for y in "${lang[@]}"; do
utils/mkgraph.sh data/phidp/$y exp/phidp/tri3b exp/phidp/tri3b/graph_$y || exit 1;
  
for x in "${tests[@]}"; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/phidp/tri3b/graph_$y data/$x exp/phidp/tri3b/decode_$x$y || exit 1;
done
done
fi
exit






for x in exp*/*/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh >> ./result_${spk_test}.txt; done; 
exit

if [ $stage -le 11 ]; then
# # A couple of nnet3 recipes:
echo ""
# local/nnet3/run_tdnn_baseline.sh  # designed for exact comparison with nnet2 recipe
echo "--- chain: Time Delay Neural Network (cnn_tdnnf)" 
local/chain/tuning/run_cnn_tdnn_1c.sh   # better absolute results
fi
exit


if [ $stage -le 10 ]; then
echo ""
echo "=== Neural Network models ..."
#echo "--- nnet: Deep Neural Network (dnn)"
# Karel's neural net recipe.
local/nnet/run_dnn.sh --nj $njobsT 
fi




if [ $stage -le 12]; then
# # A couple of nnet3 recipes:
echo ""
# local/nnet3/run_tdnn_baseline.sh  # designed for exact comparison with nnet2 recipe
echo "--- chain: Time Delay Neural Network (tdnn_lstm)" 
local/chain/tuning/run_tdnn_lstm_1b.sh   # better absolute results
fi










