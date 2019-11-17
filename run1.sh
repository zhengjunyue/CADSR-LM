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

vers=0  #new method
         #change this variable and stage 


# base url for downloads.
lm_url=www.openslr.org/resources/11

                                                                                                                        
# Paths to software and data
. ./cmd.sh || exit 1
. ./path.sh || exit 1
. ./utils/parse_options.sh


spk_test=$spktest
# Test-time language model order
lm_order=3
#subset to train
#trains=("train_word" "train_sentence")
# Subtests to be decoded
#tests=("test" "test_word" "test_sentence")
trains=("train" "train_word" "train_sentence")
tests=("test" "test_word" "test_sentence" "test_head" "test_head_word" "test_head_sentence" "test_array" "test_array_word" "test_array_sentence")

lms=("lm30" "lm35" "lm40" "lm45" "lm50" "lm100" "lm150" "lm200")
#lms=("lm2" "lm5" "lm10" "lm15" "lm20" "lm25")
mfccdir=${DATA_ROOT}/${spk_test}/mfcc
# Word position dependent phones?
pos_dep_phones=true

# Number of leaves and total gaussians
leaves=1800
gaussians=9000 
 
# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false


[[ $# -ge 2 ]] && { echo "Unexpected arguments"; exit 1; } 




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

#local/torgo_data_prep_multi.sh ${spk_test} || exit 1
#local/torgo_data_prep_multi.sh ${spk_test} || exit 1
if [ $stage -le 0 ]; then

echo
echo "===== download the LM resources  ====="
echo
local/download_lm.sh $lm_url data/local/lm || exit 1





echo
echo "===== PREPARING Diictionary and Lexicon ====="
echo

#local/chime_prepare_dict.sh 
local/libri_prepare_dict.sh --stage 3 --nj 14 --cmd "$train_cmd" \
   data/local/lm data/local/lm data/local/dict  || exit 1

utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang_tmp data/lang || exit 1
local/format_lms.sh --src-dir data/lang data/local/lm || exit 1



# Needs to be prepared by hand (or using self written scripts):
#
# lexicon.txt           [<word> <phone 1> <phone 2> ...]
# nonsilence_phones.txt [<phone>]
# silence_phones.txt    [<phone>]
# optional_silence.txt  [<phone>]
# Preparing language data
fi


if [ $stage -le 1 ]; then
  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs

#for lm in ${lms[@]}; do
 # utils/build_const_arpa_lm.sh data/local/lm/$lm.arpa data/lang data/lang_$lm
local/format_lms.sh --src-dir data/lang data/local/lm || exit 1
#done
fi

exit
  if [ $stage -le 2 ]; then
# Now make MFCC features.
echo ""
echo "=== Making MFCC features ..."
echo ""
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
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

for x in "${trains[@]}"; do 
local/torgo_make_mfcc.sh --cmd "$train_cmd" --nj $njobs \
   data/$x exp/make_mfcc/$x $mfccdir || exit 1;
steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
done
fi
