# Continuous dysarthric speech recognition (ACDSR) -- Out-of-domain (OOD) language model

Copyright 2022 Zhengjun Yue, Feifei Xiong, Heidi Christensen, Jon Barker

# Description

This is a Kaldi recipe to build automatic speech recognition systems on the
[Torgo corpus](http://www.cs.toronto.edu/~complingweb/data/TORGO/torgo.html) of
dysarthric speech.

## Setup

Update the `KALDI_ROOT` and `DATA_ORIG` variables in `path.sh` to point to the
correct locations for your Kaldi installation and the Torgo corpus. Then run
the following:

```sh
source path.sh
ln -s $KALDI_ROOT/egs/wsj/s5/{steps,utils} .
```

Some scripts in `local/` also require the following Python packages:

```
invoke numpy pandas python-Levenshtein
```

## Usage

The following instructions allow to train ASR systems on Torgo and to reproduce
results from the paper.

### Train ASR systems

```sh
# HMM/GMM systems + LF-MMI (TDNN-F) systems:
./run.sh

# Show WER:
./local/get_wer.py exp/sgmm
```




## Citation 

Please cite the following [paper](https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=9054343) if you use this script for your research or are 
interested in this paper.

```BibTeX
@inproceedings{yue2020exploring,
  title={Exploring appropriate acoustic and language modelling choices for continuous dysarthric speech recognition},
  author={Yue, Zhengjun and Xiong, Feifei and Christensen, Heidi and Barker, Jon},
  booktitle={In IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP) 2020},
  pages={6094--6098},
  year={2020},
  organization={IEEE}
}
```
The code is based on [an earlier recipe](https://github.com/cristinae/ASRdys) by
Cristina España-Bonet and José A. R. Fonollosa.
