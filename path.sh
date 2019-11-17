
source /data/ac1zy/kaldi/tools/env.sh
#export KALDI_ROOT=`pwd`/../../..
export KALDI_ROOT=/data/$USER/kaldi
export PATH=$PWD/utils/:$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/src/fstbin/:$KALDI_ROOT/src/gmmbin/:$KALDI_ROOT/src/featbin/:$KALDI_ROOT/src/lmbin/:$KALDI_ROOT/src/sgmmbin/:$KALDI_ROOT/src/sgmm2bin/:$KALDI_ROOT/src/fgmmbin/:$KALDI_ROOT/src/latbin/:$KALDI_ROOT/src/onlinebin/:$KALDI_ROOT/src/nnetbin/:$KALDI_ROOT/src/nnet2bin/:$KALDI_ROOT/src/nnet3bin/:$KALDI_ROOT/src/online2bin/:$KALDI_ROOT/src/ivectorbin/:$KALDI_ROOT/src/kwsbin/:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
#  IRSTLM
#export IRSTLM=/data/ac1zy/kaldi/tools/irstlm
#export PATH=${PATH}:${IRSTLM}/bin

#  SRILM                                            
#export SRILM=/data/ac1zy/kaldi/tools/extras/srilm-1.7.2
#export PATH=${PATH}:${SRILM}/bin/i686-m64

# SEQUITUR
export SEQUITUR=/data/ac1zy/kaldi/tools/sequitur-g2p
export PATH=$PATH:${SEQUITUR}/bin
_site_packages=`find ${SEQUITUR}/lib -type d -regex '.*python.*/site-packages'`
export PYTHONPATH=$PYTHONPATH:$_site_packages
#export PYTHONPATH="${PYTHONPATH:-}:$SEQUITUR/./lib/python2.7/site-packages"


# Torgo data
export DATA_ORIG="/data/ac1zy/data/torgo"    
export DATA_ROOT="/fastdata/ac1zy/kaldi/egs/torgo/final/open_sentence/MFCC"  # Please modify it to the reposite to store the MFCC  

if [ -z $DATA_ROOT ]; then
  echo "You need to set \"DATA_ROOT\" variable in path.sh to point to the directory where Torgo data will be"
  exit 1
fi

# Make sure that MITLM shared libs are found by the dynamic linker/loader
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/tools/mitlm-svn/lib

# Needed for "correct" sorting
export LC_ALL=C
source setup_env.sh

