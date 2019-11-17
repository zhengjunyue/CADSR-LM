#!/bin/bash

# Author: Cristina Espana-Bonet
# Description: Launches an instance of Kaldi pipeline for each speaker
#  in the Torgo database taken as a test speaker.

#speakers=(FC01 FC02 FC03 MC01 MC02 MC03 MC04)
speakers=(F01 F03 F04 M01 M02 M03 M04 M05)
#speakers=(FC03 MC01 MC02 MC03 MC04)
#speakers=(F03)

chmod +x *sh
chmod +x local/*sh
chmod +x local/chain/tuning/*sh

for speaker in ${speakers[@]} ; do
   mkdir -p $speaker
   cd $speaker
#   cp cmd.sh path.sh run.sh $speaker/.
#   cp -r local  $speaker/.


   ln -s ../cmd.sh ../path.sh ../runMulti.sh ../conf ../local .
   ln -s ../utils .
   ln -s ../steps .
   ln -s ../setup_env.sh ../run3.sh .
   ln -s ../run.sh ../run1.sh ../run2.sh ../rundnns.sh . 

   mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/final
   mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/final/open_sentence/$speaker/data
   mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/final/open_sentence/$speaker/exp
   ln -s /fastdata/ac1zy/kaldi/egs/torgo/final/open_sentence/$speaker/data data
   ln -s /fastdata/ac1zy/kaldi/egs/torgo/final/open_sentence/$speaker/exp exp
   

   
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lm3
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lm3/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lm3/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lm3/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lm3/$speaker/exp exp 
   
   
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_phone_indep
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_phone_indep/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_phone_indep/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_phone_indep/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_phone_indep/$speaker/exp exp 
   
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_state
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_state/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_state/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_state/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_state/$speaker/exp exp
   
   
   
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lda
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lda/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lda/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lda/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/baseline/base_lda/$speaker/exp exp 
   

   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs/$speaker/exp exp 
   #scp -r /data/ac1zy/kaldi/egs/wsj/s5/data/lang_nosp data
   #scp -r /data/ac1zy/kaldi/egs/wsj/s5/data/lang_nosp_test_tgpr data

   
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs_text
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs_text/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs_text/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs_text/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_wjs_text/$speaker/exp exp
   
   
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime/$speaker/exp exp 
   #scp -r /fastdata/acx17jz/kaldi_chime5_storage/egs/chime5_baseline/s5/data/lang data/
  
  
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime_text
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime_text/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime_text/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime_text/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/lm/lm_chime_text/$speaker/exp exp 
 
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/split/train_cs
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/split/train_cs/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/split/train_cs/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/split/train_cs/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/split/train_cs/$speaker/exp exp 
   
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/split/train_ds
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/split/train_ds/$speaker/data
   #mkdir -p /fastdata/ac1zy/kaldi/egs/torgo/split/train_ds/$speaker/exp
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/split/train_ds/$speaker/data data
   #ln -s /fastdata/ac1zy/kaldi/egs/torgo/split/train_ds/$speaker/exp exp 
   
   #qsub -V -o qsub_dnn2 -e qsub_dnn2 -j y ./rundnns.sh  
  #qsub -V -o qsub_3 -e qsub_3 -j y ./run3.sh --spktest $speaker --stage 5
   #qsub -V -o qsub_$speaker -e qsub_$speaker -j y ./runMulti.sh --spktest $speaker
  qsub -V -o qsub_smalllm -e qsub_smalllm -j y ./run.sh --spktest $speaker --stage 20
  
   cd ..
done
