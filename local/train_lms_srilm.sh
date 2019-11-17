#!/bin/bash
. path.sh
. cmd.sh
export LC_ALL=C

words_file=
train_text=
dev_text=
oov_symbol=

. ./utils/parse_options.sh

echo "-------------------------------------"
echo "Building an SRILM language model     "
echo "-------------------------------------"

if [[ ! -d $1 && ! -f $2 && ! -f $3 && ! -d $4 && ! $5 ]];then
    echo "usage $0 <lang folder> <train text> <dev text> <target dir> <outlm.gz>"
    exit 0
else
    
#lang/words.txt    
lang=$1
words_file=$lang/words.txt
#train.text
train_text=$2
#dev.text
dev_text=$3
#target dir
tgtdir=$4
#outlm=lm.gz
outlm=$5
oov_symbol="!SIL"
##End of configuration
loc=`which ngram-count`;
if [ -z $loc ]; then
  if uname -a | grep 64 >/dev/null; then # some kind of 64 bit...
    sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64 
  else
    sdir=$KALDI_ROOT/tools/srilm/bin/i686
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

[ -z $words_file ]
[ -z $train_text ]
[ -z $dev_text ] 

echo "Using words file: $words_file"
echo "Using train text: $train_text"
echo "Using dev text  : $dev_text"

for f in $words_file $train_text $dev_text; do
  [ ! -s $f ] && echo "No such file $f" && exit 1;
done

# Prepare the destination directory
mkdir -p $tgtdir

# Extract the word list from the training dictionary; exclude special symbols
sort $words_file | cut -f1 -d' ' | grep -v '\#0' | grep -v '<eps>' > $tgtdir/vocab
if (($?)); then
  echo "Failed to create vocab from $words_file"
  exit 1
else
  # wc vocab # doesn't work due to some encoding issues
  echo vocab contains `cat $tgtdir/vocab | perl -ne 'BEGIN{$l=$w=0;}{split; $w+=$#_; $w++; $l++;}END{print "$l lines, $w words\n";}'`
fi

<<'COMMENT' ...
if [ ! -z "$train_text" ] && [ -z "$dev_text" ] ; then
  nr=`cat  $train_text | wc -l`
  nr_dev=$(($nr / 10 ))
  nr_train=$(( $nr - $nr_dev ))
  orig_train_text=$train_text
  head -n $nr_train $train_text > $tgtdir/train_text
  tail -n $nr_dev $train_text > $tgtdir/dev_text
  cat $tgtdir/train_text | cut -f2- -d' ' > $tgtdir/train.txt
  cat $tgtdir/dev_text | cut -f2- -d' ' > $tgtdir/train.txt

  train_text=$tgtdir/train_text
  dev_text=$tgtdir/dev_text
  echo "Using words file: $words_file"
  echo "Using train text: 9/10 of $orig_train_text"
  echo "Using dev text  : 1/10 of $orig_train_text"
COMMENT
  
  

# Kaldi transcript files contain Utterance_ID as the first word; remove it
cat $train_text | cut -f2- -d' ' > $tgtdir/train.txt
if (($?)); then
    echo "Failed to create $tgtdir/train.txt from $train_text"
    exit 1
else
    echo "Removed first word (uid) from every line of $train_text"
    # wc text.train train.txt # doesn't work due to some encoding issues
    echo $train_text contains `cat $train_text | perl -ane 'BEGIN{$w=$s=0;}{$w+=@F; $w--; $s++;}END{print "$w words, $s sentences\n";}'`
    echo train.txt contains `cat $tgtdir/train.txt | perl -ane 'BEGIN{$w=$s=0;}{$w+=@F; $w--; $s++;}END{print "$w words, $s sentences\n";}'`
fi

# Kaldi transcript files contain Utterance_ID as the first word; remove it
cat $dev_text | cut -f2- -d' ' > $tgtdir/dev.txt
if (($?)); then
    echo "Failed to create $tgtdir/dev.txt from $dev_text"
    exit 1
else
    echo "Removed first word (uid) from every line of $dev_text"
    # wc text.train train.txt # doesn't work due to some encoding issues
    echo $train_text contains `cat $dev_text | perl -ne 'BEGIN{$w=$s=0;}{split; $w+=$#_; $w++; $s++;}END{print "$w words, $s sentences\n";}'`
    echo $tgtdir/dev.txt contains `cat $tgtdir/dev.txt | perl -ne 'BEGIN{$w=$s=0;}{split; $w+=$#_; $w++; $s++;}END{print "$w words, $s sentences\n";}'`
fi


echo "-------------------"
echo "Witten-Bell smoothing 2grams"
echo "-------------------"
ngram-count -lm $tgtdir/2gram.wbd011.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -order 2 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/2gram.wbd012.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -order 2 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"



echo "-------------------"
echo "Good-Turing 2grams"
echo "-------------------"
ngram-count -lm $tgtdir/2gram.gt011.gz -gt1min 0 -gt2min 1 -order 2 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/2gram.gt012.gz -gt1min 0 -gt2min 1 -order 2 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"


echo "-------------------"
echo "Kneser-Ney 2grams"
echo "-------------------"
ngram-count -lm $tgtdir/2gram.kn011.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -order 2 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/2gram.kn012.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -order 2 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"


echo "-------------------"
echo "Witten-Bell smoothing 3grams"
echo "-------------------"
ngram-count -lm $tgtdir/3gram.wbd011.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -wbdiscount3 -gt3min 1 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.wbd012.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -wbdiscount3 -gt3min 2 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.wbd022.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 2 -wbdiscount3 -gt3min 2 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.wbd023.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 2 -wbdiscount3 -gt3min 3 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"



echo "-------------------"
echo "Good-Turing 3grams"
echo "-------------------"
ngram-count -lm $tgtdir/3gram.gt011.gz -gt1min 0 -gt2min 1 -gt3min 1 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.gt012.gz -gt1min 0 -gt2min 1 -gt3min 2 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.gt022.gz -gt1min 0 -gt2min 2 -gt3min 2 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.gt023.gz -gt1min 0 -gt2min 2 -gt3min 3 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"

echo "-------------------"
echo "Kneser-Ney 3grams"
echo "-------------------"
ngram-count -lm $tgtdir/3gram.kn011.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -kndiscount3 -gt3min 1 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.kn012.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -kndiscount3 -gt3min 2 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.kn022.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 2 -kndiscount3 -gt3min 2 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/3gram.kn023.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 2 -kndiscount3 -gt3min 3 -order 3 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"

<<'COMMENT' ...
echo "-------------------"
echo "Good-Turing 4grams"
echo "-------------------"
ngram-count -lm $tgtdir/4gram.gt0111.gz -gt1min 0 -gt2min 1 -gt3min 1 -gt4min 1 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.gt0112.gz -gt1min 0 -gt2min 1 -gt3min 1 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.gt0122.gz -gt1min 0 -gt2min 1 -gt3min 2 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.gt0123.gz -gt1min 0 -gt2min 1 -gt3min 2 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.gt0113.gz -gt1min 0 -gt2min 1 -gt3min 1 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.gt0222.gz -gt1min 0 -gt2min 2 -gt3min 2 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.gt0223.gz -gt1min 0 -gt2min 2 -gt3min 2 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"

echo "-------------------"
echo "Kneser-Ney 4grams"
echo "-------------------"
ngram-count -lm $tgtdir/4gram.kn0111.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -kndiscount3 -gt3min 1 -kndiscount4 -gt4min 1 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.kn0112.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -kndiscount3 -gt3min 1 -kndiscount4 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.kn0113.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -kndiscount3 -gt3min 1 -kndiscount4 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.kn0122.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -kndiscount3 -gt3min 2 -kndiscount4 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.kn0123.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 1 -kndiscount3 -gt3min 2 -kndiscount4 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.kn0222.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 2 -kndiscount3 -gt3min 2 -kndiscount4 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.kn0223.gz -kndiscount1 -gt1min 0 -kndiscount2 -gt2min 2 -kndiscount3 -gt3min 2 -kndiscount4 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"

echo "-------------------"
echo "Kneser-Ney 4grams"
echo "-------------------"
ngram-count -lm $tgtdir/4gram.wbd0111.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -wbdiscount3 -gt3min 1 -wbdiscount4 -gt4min 1 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.wbd0112.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -wbdiscount3 -gt3min 1 -wbdiscount4 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.wbd0113.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -wbdiscount3 -gt3min 1 -wbdiscount4 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.wbd0122.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -wbdiscount3 -gt3min 2 -wbdiscount4 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.wbd0123.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 1 -wbdiscount3 -gt3min 2 -wbdiscount4 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.wbd0222.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 2 -wbdiscount3 -gt3min 2 -wbdiscount4 -gt4min 2 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
ngram-count -lm $tgtdir/4gram.wbd0223.gz -wbdiscount1 -gt1min 0 -wbdiscount2 -gt2min 2 -wbdiscount3 -gt3min 2 -wbdiscount4 -gt4min 3 -order 4 -text $tgtdir/train.txt -vocab $tgtdir/vocab -unk -sort -map-unk "$oov_symbol"
COMMENT


echo "--------------------"
echo "Computing perplexity"
echo "--------------------"
(
  for f in $tgtdir/2gram* ; do ( echo $f; ngram -order 2 -lm $f -unk -ppl $tgtdir/dev.txt ) | paste -s -d ' ' ; done 
  for f in $tgtdir/3gram* ; do ( echo $f; ngram -order 3 -lm $f -unk -ppl $tgtdir/dev.txt ) | paste -s -d ' ' ; done
)  | sort  -r -n -k 13 | column -t | tee $tgtdir/perplexities.txt

echo "The perlexity scores report is stored in $tgtdir/perplexities.txt "

#This will link the lowest perplexity LM as the output LM.
#ln -sf $tgtdir/`head -n 1 $tgtdir/perplexities.txt | cut -f 1 -d ' '` $outlm

#A slight modification of the previous approach:
#We look at the two lowest perplexity LMs and use a 3gram LM if one of the two, even if the 4gram is of lower ppl
nof_trigram_lm=`head -n 2 $tgtdir/perplexities.txt | grep 3gram | wc -l`
if [[ $nof_trigram_lm -eq 0 ]] ; then
  lmfilename=`head -n 1 $tgtdir/perplexities.txt | cut -f 1 -d ' '`
elif [[ $nof_trigram_lm -eq 2 ]] ; then
  lmfilename=`head -n 1 $tgtdir/perplexities.txt | cut -f 1 -d ' '` 
else  #exactly one 3gram LM
  lmfilename=`head -n 2 $tgtdir/perplexities.txt | grep 3gram | cut -f 1 -d ' '` 
fi

for x in $tgtdir/*.gz;
do
    [[ $x != $lmfilename ]] && echo "removing $x" && rm $x
done

(cd $tgtdir; ln -sf `basename $lmfilename` $outlm )

test=$tgtdir/lang
mkdir -p $test
tmpdir=$test/lm_tmp
mkdir -p $tmpdir

cp -r $lang/* $test || exit 1;

gunzip -c $tgtdir/$outlm | \
    utils/find_arpa_oovs.pl $test/words.txt  > $tmpdir/oovs.txt

gunzip -c $tgtdir/$outlm | \
    grep -v '<s> <s>' | \
    grep -v '</s> <s>' | \
    grep -v '</s> </s>' | \
    arpa2fst - | fstprint | \
    utils/remove_oovs.pl $tmpdir/oovs.txt | \
utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=$test/words.txt \
      --osymbols=$test/words.txt  --keep_isymbols=false --keep_osymbols=false | \
     fstrmepsilon | fstarcsort --sort_type=ilabel > $test/G.fst
scp -r $test/G.fst $tgtdir
#utils/validate_lang.pl --skip-determinization-check $test || exit 1;
fi
