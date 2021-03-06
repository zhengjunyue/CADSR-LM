#!/bin/bash

# this is the standard "tdnn" system, built in nnet3; it's what we use to
# call multi-splice.

. cmd.sh


# At this script level we don't support not running on GPU, as it would be painfully slow.
# If you want to run without GPU you'd have to call train_tdnn.sh with --gpu false,
# --num-threads 16 and --minibatch-size 128.

#tests=("test" "test_head" "test_head_single" "test_head_sentence")
tests=("test" "test_head" "test_head_word" "test_head_sentence" "test_array" "test_array_word" "test_array_sentence")
stage=0
train_stage=-10
dir=exp/nnet3/nnet_tdnn_a_noIvec


. cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

local/nnet3/run_common.sh --stage $stage || exit 1;

if [ $stage -le 3 ]; then

  steps/nnet3/train_tdnn.sh --stage $train_stage \
    --num-epochs 8 --num-jobs-initial 2 --num-jobs-final 14 \
    --splice-indexes "-4,-3,-2,-1,0,1,2,3,4  0  -2,2  0  -4,4 0" \
    --feat-type raw \
    --cmvn-opts "--norm-means=false --norm-vars=false" \
    --initial-effective-lrate 0.005 --final-effective-lrate 0.0005 \
    --cmd "$decode_cmd" \
    --pnorm-input-dim 2000 \
    --pnorm-output-dim 250 \
    --egs-opts "--nj 1" \
    data/train_hires data/lang exp/tri4b_ali $dir  || exit 1;
fi


if [ $stage -le 4 ]; then
  # this does offline decoding that should give the same results as the real
  # online decoding.
    graph_dir=exp/tri4b/graph_
    # use already-built graphs.
    for x in "${tests[@]}"; do
       hires=_hires
       steps/nnet3/decode.sh --nj 1 --cmd "$decode_cmd" \
         $graph_dir$x data/$x$hires $dir/decode_$x || exit 1;
    done
fi

exit 0;
