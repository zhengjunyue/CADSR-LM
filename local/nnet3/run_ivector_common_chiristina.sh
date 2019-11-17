#!/bin/bash

# Cristina Espana-Bonet
# Modified to deal with the Torgo DB and to consider different time shifts when extracting 
# the features according to the nature of the speaker (dysartric vs. control)

# this script is called from scripts like run_ms.sh; it does the common stages
# of the build, such as feature extraction.
# This is actually the same as local/online/run_nnet2_common.sh, except
# for the directory names.

. cmd.sh
mfccdir=mfcc

# Subtests to be decoded
tests=("test" "test_head" "test_head_single" "test_head_sentence")

stage=1

. cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if [ $stage -le 1 ]; then
  for datadir in "${tests[@]}"; do
    utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
    local/torgo_make_mfcc.sh --nj 1 --mfcc_config conf/mfcc_hires.conf \
      --cmd "$train_cmd" data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
  done

  datadir=train
  utils/copy_data_dir.sh data/$datadir data/${datadir}_hires
  local/torgo_make_mfcc.sh --nj 14 --mfcc_config conf/mfcc_hires.conf \
    --cmd "$train_cmd" data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;
  steps/compute_cmvn_stats.sh data/${datadir}_hires exp/make_hires/$datadir $mfccdir || exit 1;

  # 6175 is the end of FC03
  # Not enough data for this?
  #utils/subset_data_dir.sh --first data/train 6175 data/train_small || exit 1
  #utils/subset_data_dir.sh --first data/train_hires 6175 data/train_small_hires || exit 1
fi

if [ $stage -le 2 ]; then
  # We need to build a small system just because we need the LDA+MLLT transform
  # to train the diag-UBM on top of.  We align the small data for this purpose.

  # too small to split ($nj=1)
  steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
    data/train data/lang exp/tri4b exp/nnet3/tri4b_ali
    #data/train_small data/lang exp/tri4b exp/nnet3/tri4b_ali_small

fi

if [ $stage -le 3 ]; then
  # Train a small system just for its LDA+MLLT transform.  We use --num-iters 13
  # because after we get the transform (12th iter is the last), any further
  # training is pointless.
  steps/train_lda_mllt.sh --cmd "$train_cmd" --num-iters 13 \
    --realign-iters "" \
    --splice-opts "--left-context=3 --right-context=3" \
    5000 10000 data/train_hires data/lang \
     exp/nnet3/tri4b_ali exp/nnet3/tri5b
     #exp/nnet3/tri4b_ali_small exp/nnet3/tri5b
fi

if [ $stage -le 4 ]; then
  mkdir -p exp/nnet3

  # too small to split ($nj=1)
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 1 \
     --num-frames 400000 data/train_hires 256 exp/nnet3/tri5b exp/nnet3/diag_ubm
     #--num-frames 400000 data/train_small_hires 256 exp/nnet3/tri5b exp/nnet3/diag_ubm
fi

if [ $stage -le 5 ]; then
  # even though $nj is just 10, each job uses multiple processes and threads.
  # too small to split ($nj=1)                                                                           
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 1 \
    data/train_hires exp/nnet3/diag_ubm exp/nnet3/extractor || exit 1;
    #data/train_small_hires exp/nnet3/diag_ubm exp/nnet3/extractor || exit 1;
fi

if [ $stage -le 6 ]; then
  # We extract iVectors on all the train_si284 data, which will be what we
  # train the system on.

  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  steps/online/nnet2/copy_data_dir.sh --utts-per-spk-max 2 data/train_hires \
    data/train_hires_max2

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 14 \
    data/train_hires_max2 exp/nnet3/extractor exp/nnet3/ivectors_train || exit 1;
fi

if [ $stage -le 7 ]; then
  rm exp/nnet3/.error 2>/dev/null
  # too small to split ($nj=1) 
  hires="_hires" 
  for x in "${tests[@]}"; do
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 1 \
      data/$x$hires exp/nnet3/extractor exp/nnet3/ivectors_$x || touch exp/nnet3/.error &
  done
  wait
  [ -f exp/nnet3/.error ] && echo "$0: error extracting iVectors." && exit 1;
fi

exit 0;
