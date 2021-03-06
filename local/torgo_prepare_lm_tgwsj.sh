#!/bin/bash

# Copyright 2012 Vassil Panayotov
# Adapted: Cristina Espana-Bonet 2016
#Adapted: Zhengjun Yue 2019
# Apache 2.0

. path.sh || exit 1

echo ""
echo "=== Building a language model with Torgo+WSJ train..."

locdata=data/local
loctmp=$locdata/tmp
mkdir -p $loctmp

# Language model order
order=3

. utils/parse_options.sh

# Prepare a LM training corpus from the transcripts _not_ in the test set
cut -f2- -d' ' < data/test/text |\
  sed -e 's:[ ]\+: :g' | sort -u > $loctmp/test_utt.txt

# Create tgwsj_text, a new file with Torgo+Voxforge train
cat data/train/text $KALDI_ROOT/egs/wsj/s5/data/train_si284/text > data/train/tgwsj_text # the text from WSJ 
#cat data/train/text /data/ac1zy/data/lm_text/s_h_a.hal_1.txt > data/train/tgbah_text # the text from Bahman's general LM
#cat data/train/text /data/ac1zy/data/lm_text/chime.txt > data/train/tgchime_text # the text from Bahman's general LM



# We are not removing the test utterances in the current version of the recipe
# because this messes up with some of the later stages - e.g. too many OOV
# words in tri2b_mmi
cut -f2- -d' ' < data/train/tgwsj_text |\
   sed -e 's:[ ]\+: :g' |\
   sort -u > $loctmp/corpus.txt
 #sort -u > $loctmp/train_utt.txt
#awk '{print $0}' train_utt.txt test_utt.txt |sort|uniq -u > corpus.txt

loc=`which ngram-count`;
if [ -z $loc ]; then
  if uname -a | grep 64 >/dev/null; then # some kind of 64 bit...
    sdir=$KALDI_ROOT/tools/extras/srilm/bin/i686-m64 
  else
    sdir=$KALDI_ROOT/tools/extras/srilm/bin/i686
  fi
  if [ -f $sdir/ngram-count ]; then
    echo Using SRILM tools from $sdir
    export PATH=$PATH:$sdir
  else
    echo You appear to not have SRILM tools installed, either on your path,
    echo or installed in $sdir.  See tools/install_srilm.sh for installation
    echo instructions.
    exit 1
  fi
fi

ngram-count -order $order -write-vocab $locdata/vocab-full.txt -wbdiscount \
  -text $loctmp/corpus.txt -lm $locdata/lm.arpa
