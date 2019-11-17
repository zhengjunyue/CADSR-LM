#!/bin/bash
#$ -l h_rt=10:00:00
#$ -l rmem=12G
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

#tests=("test_sentence" "test_head_sentence" "test_array_sentence")
tests_word=("test_word" "test_head_word" "test_array_word")

lang=("lang_word_2" "lang_word_5" "lang_word_10" "lang_word_15" "lang_word_20" "lang_word_25" "lang_word_30" "lang_word_35" "lang_word_40" "lang_word_45" "lang_word_50" "lang_word_100" "lang_word_150" "lang_word_200")

lms_small=("lm0.05" "lm0.1" "lm0.2" "lm0.5" "lm1" "lm1.5")


lms_graph=("lm100" "lm150" "lm200")
lms=( "lm0" "lm2" "lm5" "lm10" "lm15" "lm20" "lm25" "lm30" "lm35" "lm40" "lm45" "lm50" "lm100" "lm150" "lm200")
lms_decode=( "lm0" "lm2" "lm5" "lm10" "lm15" "lm20" "lm25" "lm30" "lm35" "lm40" "lm45" "lm50")
tests_sent=("test_sentence" "test_head_sentence" "test_array_sentence")

train_text=/data/ac1zy/data/lm_text/newtrainset/combine_repeat
#train_text=/data/ac1zy/data/lm_text/newtrainset/combine_unique


# Word position dependent phones?
pos_dep_phones=true

# Number of leaves and total gaussians
leaves=1800
gaussians=9000 
 
# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false


[[ $# -ge 2 ]] && { echo "Unexpected arguments"; exit 1; } 



if [ $stage -le 0 ]; then

# Initial extraction and distribution of the data: data/{train,test} directories  

echo
echo "===== PREPARING ACOUSTIC DATA ====="
echo
# Needs to be prepared by hand (or using self written scripts):
#
# spk2gender  [<speaker-id> <gender>]
# wav.scp     [<uterranceID> <full_path_to_audio_file>]
# text        [<uterranceID> <text_transcription>]
# utt2spk     [<uterranceID> <speakerID>]
# corpus.txt  [<text_transcription>]

local/torgo_data_prep_multi.sh ${spk_test} || exit 1
#local/torgo_data_prep_multi.sh ${spk_test} || exit 1
echo
echo "===== PREPARING Diictionary and Lexicon ====="
echo

#local/chime_prepare_dict.sh data/train/text
local/chime_prepare_dict.sh 


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
utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones \
  data/local/dict '!SIL' data/local/lang data/lang || exit 1

  
echo
echo "===== PREPARING Language Model ====="
echo
#Bahman's strategy to train LM
#local_dem/make_language/train_lms_srilm.sh <lang_nosp> <train_text> <dev_text> <LM_folder> <lm.gz>
#e.g. local_dem/make_language/train_lms_srilm.sh lang/lang_nosp $train/text $test/text $lm lm.gz

#local/train_lms_srilm.sh data/lang $train_text data/test/text data/srilm lm.gz || exit 1
local/train_lms_srilm.sh data/lang /data/ac1zy/data/lm_text/newtrainset/combine_unique data/test/text data/srilm_unique lm_unique.gz
scp -r data/srilm_unique/G.fst data/lang


#local/lm_interpolation.sh  


#oov=`cat $lang/oov.int`
#lang=data/lang


echo
echo "===== PREPARING Other Language Model (G.fst)====="
echo
echo "Making unigram grammar FST in $new_lang"
#cat data/train/text | utils/sym2int.pl --map-oov $oov -f 2- data/lang/words.txt | \
  #awk '{for(n=2;n<=NF;n++){ printf("%s ", $n); } printf("\n"); }' | \
  #utils/make_unigram_grammar.pl | fstcompile | fstarcsort --sort_type=ilabel > G.fst 
   #|| exit 1;
#scp -r G.fst data/lang

fi


if [ $stage -le 1 ]; then
# Now make MFCC features.
echo ""
echo "=== Making MFCC features ..."
echo ""
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=${DATA_ROOT}/${spk_test}/mfcc
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
# Change previous lineshttps://github.com/zhengjunyue/asrdys for these ones if you want to calculate 
# features differently for speakers with dysartria and for control speakers 
for x in "${tests[@]}"; do 
 local/torgo_make_mfcc.sh --cmd "$train_cmd" --nj 1 \
   data/$x exp/make_mfcc/$x $mfccdir || exit 1;
 steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
done

local/torgo_make_mfcc.sh --cmd "$train_cmd" --nj $njobs \
   data/train exp/make_mfcc/train $mfccdir || exit 1;
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir || exit 1;
fi



if [ $stage -le 2 ]; then
# Train monophone models on a subset of the data
echo ""
echo "=== Monophone models ..."
echo ""
echo "--- Training"
#utils/subset_data_dir.sh data/train 1000 data/train.1k  || exit 1;
steps/train_mono.sh --nj $njobs --cmd "$train_cmd" data/train data/lang exp/mono  || exit 1;
# Get alignments from monophone system.
steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
  data/train data/lang exp/mono exp/mono_ali || exit 1;
fi


if [ $stage -le 3 ]; then
echo ""
echo "=== Triphone models ..."
# train tri1 [first triphone pass]
echo ""
echo "--- tri1 (first triphone pass, velocity)"
steps/train_deltas.sh --cmd "$train_cmd" \
  $leaves $gaussians data/train data/lang exp/mono_ali exp/tri1_700 || exit 1;

#utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph_test || exit 1;
# align tri1
steps/align_si.sh --nj $njobs --cmd "$train_cmd" data/train data/lang exp/tri1_700 exp/tri1_ali_700 || exit 1;


# train and decode tri2b [LDA+MLLT]
echo ""
echo "--- tri2b (LDA+MLLT)"
steps/train_lda_mllt.sh --cmd "$train_cmd" $leaves $gaussians \
  data/train data/lang exp/tri1_ali_700 exp/tri2b_700 || exit 1;
#utils/mkgraph.sh data/lang exp/tri2b exp/tri2b/graph_test
# Align all data with LDA+MLLT system (tri2b)
steps/align_si.sh --nj $njobs --cmd "$train_cmd" data/train data/lang exp/tri2b_700 exp/tri2b_ali_700 || exit 1;

fi


if [ $stage -le 4 ]; then
## Do LDA+MLLT+SAT, and decode.
echo ""
echo "--- tri3b (LDA+MLLT+SAT)"
steps/train_sat.sh --cmd "$train_cmd" $leaves $gaussians data/train data/lang exp/tri2b_ali_700 exp/tri3b_700 || exit 1;

#utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph_test || exit 1;
# Align all data with LDA+MLLT+SAT system (tri3b)
steps/align_fmllr.sh --nj $njobs --cmd "$train_cmd" data/train data/lang exp/tri3b_700 exp/tri3b_ali_700 || exit 1
fi




if [ $stage -le 5 ]; then
echo ""
echo "--- Decode tri3b"
for y in "${lang[@]}"; do
utils/mkgraph.sh data/$y exp/tri3b exp/tri3b/graph_$y || exit 1;

for x in test_word; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/tri3b/graph_$y data/$x exp/tri3b/decode_$x$y || exit 1;
done
done
exit
fi


if [ $stage -le 6 ]; then
echo ""
echo "--- Decode tri3b"
for y in "${lms_small[@]}"; do
utils/mkgraph.sh data/lang_$y exp/tri3b exp/tri3b/graph_$y || exit 1;

for x in test_sentence; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/tri3b/graph_$y data/$x exp/tri3b/decode_$x$y || exit 1;
done
done
exit
fi







if [ $stage -le 7 ]; then
echo ""
echo "--- Decode tri3b"
for y in "${lang[@]}"; do
utils/mkgraph.sh data/$y exp/tri3b exp/tri3b/graph_$y || exit 1;
  
for x in "${tests[@]}"; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/tri3b/graph_$y data/$x exp/tri3b/decode_$x$y || exit 1;
done
done
fi


if [ $stage -le 8 ]; then
echo ""
echo "--- Decode tri3b"
for y in "${lms_graph[@]}"; do
utils/mkgraph.sh data/lang_$y exp/tri3b exp/tri3b/graph_$y || exit 1;
done
exit

fi



if [ $stage -le 9 ]; then
for y in "${lms_graph[@]}"; do
for x in test_sentence; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp/tri3b/graph_$y data/$x exp/tri3b/decode_$x$y || exit 1;
done
done
fi


if [ $stage -le 5 ]; then
echo ""

nums="2 3 4 5 6 7 8 9"
echo "--- Decode tri3bi"
for i in $nums;do
utils/mkgraph.sh data/lang_big${i} exp_0/tri3b exp_0/tri3b/graph${i}

for x in "${tests[@]}"; do
steps/decode_fmllr.sh --config conf/decode.config --nj $njobsT --cmd "$decode_cmd" exp_0/tri3b/graph${i} data/$x exp_0/tri3b/decode${i}_$x || exit 1;


done
done







echo ""
echo "--- score tri3b"
for y in "${lms[@]}"; do

for x in "${tests_sent[@]}"; do
steps/score_kaldi.sh --cmd "$decode_cmd" data/$x exp/tri3b/graph_$y exp/tri3b/decode_$x$y || exit 1;
done
done
fi

if [ $stage -le 10 ]; then

echo ""
echo "--- score dnn"
for y in "${lms[@]}"; do

for x in test_sentence; do
steps/score_kaldi.sh --cmd "$decode_cmd" data-fmllr-tri3b/$x$y exp/tri3b/graph_$y exp/dnn3b_pretrain-dbn_dnn/decode_$x$y || exit 1;
done
done
fi


















#for x in exp*/*/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh >> ./result_${spk_test}.txt; done; 

if [ $stage -le 11 ]; then
# # A couple of nnet3 recipes:
echo ""
# local/nnet3/run_tdnn_baseline.sh  # designed for exact comparison with nnet2 recipe
echo "--- chain: Time Delay Neural Network (cnn_tdnnf)" 
local/chain/tuning/run_cnn_tdnn_1c.sh   # better absolute results
fi


if [ $stage -le 20 ]; then
echo ""
echo "=== Neural Network models ..."
#echo "--- nnet: Deep Neural Network (dnn)"
# Karel's neural net recipe.
local/nnet/run_dnn.sh --nj $njobsT --gmm exp/tri3b --langdir data/lang --stage 3

#local/nnet/run_dnn.sh --nj $njobsT --gmm exp/tri3b --langdir data/lang --stage 0
exit
fi




if [ $stage -le 12]; then
# # A couple of nnet3 recipes:
echo ""
# local/nnet3/run_tdnn_baseline.sh  # designed for exact comparison with nnet2 recipe
echo "--- chain: Time Delay Neural Network (tdnn_lstm)" 
local/chain/tuning/run_tdnn_lstm_1b.sh   # better absolute results
fi










