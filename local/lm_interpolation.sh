#!/bin/bash
# Copyright 2015-2016  Sarah Flora Juan
# Copyright 2016  Johns Hopkins University (Author: Yenda Trmal)
# Apache 2.0

set -e -o pipefail
extext=/data/ac1zy/data/lm_text/wsj_text
# To create G.fst from ARPA language model
. ./path.sh || die "path.sh expected";
cut -f2- -d' ' < data/train/text | sort -u > data/train/train_uniq
local/train_lms_srilm_intp.sh --train-text data/train/text --dev_text data/test/text data/ data/srilm
nl -nrz -w10 $extext | utils/shuffle_list.pl > data/local/external_text
local/train_lms_srilm_intp.sh --train-text data/local/external_text --dev_text data/test/text data/ data/srilm_external
# let's do ngram interpolation of the previous two LMs
# the lm.gz is always symlink to the model with the best perplexity, so we use that

mkdir -p data/srilm_interp
for w in 0.9 0.8 0.7 0.6 0.5 0.4 0.3 0.2; do
    ngram -lm data/srilm/lm.gz  -mix-lm data/srilm_external/lm.gz \
          -lambda $w -write-lm data/srilm_interp/lm.${w}.gz
    echo -n "data/srilm_interp/lm.${w}.gz "
    ngram -lm data/srilm_interp/lm.${w}.gz -ppl data/srilm/dev.txt | paste -s -
done | sort  -k15,15g  > data/srilm_interp/perplexities.txt

# for basic decoding, let's use only a trigram LM
[ -d data/lang_test/ ] && rm -rf data/lang_test
cp -R data/lang data/lang_test
lm=$(cat data/srilm/perplexities.txt | grep 3gram | head -n1 | awk '{print $1}')
local/arpa2G.sh $lm data/lang_test data/lang_test


lms="lm.0.2.gz lm.0.3.gz lm.0.4.gz lm.0.5.gz lm.0.6.gz lm.0.7.gz lm.0.8.gz lm.0.9.gz "
for lm in ${lms}; do
affix=$(echo $lm | sed 's/.*lm.0.\([0-9]*\).*/\1/g')
[ -d data/lang_big$affix ] && rm -rf data/lang_big$affix
cp -R data/lang data/lang_big$affix
local/arpa2G.sh data/srilm_interp/$lm data/lang_big$affix data/lang_big$affix

# for really big lm, we should only decode using small LM
# and resocre using the big lm
utils/build_const_arpa_lm.sh data/srilm_interp/$lm data/lang_big$affix data/lang_big$affix
done

exit 0;
