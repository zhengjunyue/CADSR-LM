#!/bin/bash

# Copyright 2012  Vassil Panayotov
#           2014  Johns Hopkins University (author: Daniel Povey)
#           2016  Cristina Espana-Bonet
# Apache 2.0

# Converts the data into Kaldi's format and makes train/test splits

source path.sh

echo ""
echo "=== Starting initial Torgo data preparation ..."
echo ""

. utils/parse_options.sh




if [ $# != 1 ]; then
  echo "Usage: $0 <test speaker>";
  exit 1;
fi

test_spk=$1

# Look for the necessary information in the original data
echo "--- Looking into the original data ..."
num_users=0
num_sessions=0
num_Tsessions=0
spk_test_seen=false
for speaker in $DATA_ORIG/* ; do
    spk=$(basename $speaker)
    if [ "$spk" == "$test_spk" ] ; then   #your test speaker must exist
       spk_test_seen=true
    fi
    global=false  #all the information in any session of a user
    for waves in $speaker/S*/wav_* ; do
       info=false  #all the information within a session
       if  [ -d "$waves" ] ; then
            acoustics=true
            transcript="${waves/wav_*Mic/prompts}"
            if  [ -d "$transcript" ] ; then
                 transcriptions=true
                 info=true
	         global=true
            fi

       fi
       if [ "$info" = true ] && [ "$spk" != "$test_spk" ] ; then
       
           #if  [[ $spk =~ C ]]; then  #train on control speakers only (YZJ)
          #if [[ $spk  != *C* ]] ; then #train on dysarthria speakers only (YZJ)
       train_sessions[$num_sessions]="$waves"
        ((num_sessions++))
       #fi
    fi
       if [ "$info" = true ] && [ "$spk" == "$test_spk" ] ; then
        test_sessions[$num_Tsessions]="$waves"
        ((num_Tsessions++))
       fi
    done

    if [ "$global" = true ] ; then
        if [ "$spk" != "$test_spk" ] ; then
	#if [ "$spk" != "$test_spk" ] && [[ $spk =~ C ]]; then  #train on control speakers only (YZJ)
	#if [ "$spk" != "$test_spk" ] && [[ $spk  != *C* ]]; then  #train on dysarthria speakers only (YZJ)
	train_spks[$num_users]="$spk"
	((num_users++))
        fi  
    else
        if [ "$spk" == "$test_spk" ]  || [ "$spk_test_seen" = false ]; then
            echo " -- ERROR"
	    echo " --  Your test speaker $test_spk does not have all necessary data"
	    exit 1
        fi
    fi
done
echo "  $num_users users besides your test speaker have all necessary data"
echo "     ${train_spks[@]}"

echo ""
echo "--- Extracting training ..."

# Create the main folders to store the data  

mkdir -p data/train

mkdir -p data/train_word
mkdir -p data/train_sentence

mkdir -p data/test
mkdir -p data/test_word
mkdir -p data/test_sentence
mkdir -p data/test_head
mkdir -p data/test_head_word
mkdir -p data/test_head_sentence
mkdir -p data/test_array
mkdir -p data/test_array_word
mkdir -p data/test_array_sentence



# Create the data for training
rm -f data/train/text.unsorted
rm -f data/train/wav.scp.unsorted
rm -f data/train/utt2spk.unsorted
rm -f data/train/spk2gender.unsorted
for waves in ${train_sessions[@]} ; do
#  get the nomenclature
   session=$(dirname $waves)        
   ssn=$(basename $session)
   tmp=${session#*02/data/}
   spk=${tmp%/Sess*}
   spk=$(basename $spk)
   mic=${waves#*wav_}
   echo "  $spk $ssn $mic"
   gender=${spk:0:1}
   gender=${gender,,}
   for doc in $session/prompts/* ; do
       line=$(cat $doc)
       #line=$(tr 'A-Z' 'a-z' < $doc)

       #line=$(<$doc)
       #The DB has incomplete transcriptions. Till solved we
       #  remove transcriptions with comments
       if [[ $line == *'['*']'* ]] ; then
          continue
       fi
       #  remove transcriptions that are paths to files where descriptions should be included
       if [[ $line == *'input/images'* ]] ; then
	  continue
       fi
       if [[ $line == *'xxx'* ]] ; then
	  continue
       fi
       utt="${doc%.txt}"
       utt=$(basename $utt)
       id="$spk-$ssn-$mic-$utt"
       line="$id ${line^^}"
       if [ -f $waves/$utt.wav ] ; then  #only files with all the associated info are written
          wav="$id $waves/$utt.wav"
          echo "$wav" >> data/train/wav.scp.unsorted
          #buscar que fer amb les cometes simples
          echo "$line" | tr -d '[.,?!:;"]'  >> data/train/text.unsorted
          echo "$id $spk" >> data/train/utt2spk.unsorted
	  echo "$spk $gender" >> data/train/spk2gender.unsorted
	  words=( $line )
          num_words=${#words[@]}
	  if [[ $num_words -lt 3 ]] ; then  #id plus a word
                echo "$wav" >> data/train_word/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/train_word/text.unsorted
                echo "$id $spk" >> data/train_word/utt2spk.unsorted
                echo "$spk $gender" >> data/train_word/spk2gender.unsorted
		
	else 
                echo "$wav" >> data/train_sentence/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/train_sentence/text.unsorted
                echo "$id $spk" >> data/train_sentence/utt2spk.unsorted
                echo "$spk $gender" >> data/train_sentence/spk2gender.unsorted	
	  fi
       fi
   done
done

echo "--- Extracting test ..."
# Create the data for test    
for waves in ${test_sessions[@]} ; do
#  get the nomenclature         
   session=$(dirname $waves)
   ssn=$(basename $session)
   tmp=${session#*02/data/}
   spk=${tmp%/Sess*}
   spk=$(basename $spk)
   mic=${waves#*wav_}
   echo "  $spk $ssn $mic"
   gender=${spk:0:1}  #inside the for just in case there were more than one test speaker  
   gender=${gender,,}
   for doc in $session/prompts/* ; do
       line=$(cat $doc)
        #line=$(tr 'A-Z' 'a-z' < $doc)
       if [[ $line == *'['*']'* ]] ; then
          continue
       fi
       #  remove transcriptions that are paths to files where descriptions should be included
       if [[ $line == *'input/images'* ]] ; then
          continue
       fi
       if [[ $line == *'xxx'* ]] ; then
	  continue
       fi
       
       utt="${doc%.txt}"
       utt=$(basename $utt)
       id="$spk-$ssn-$mic-$utt"
       line="$id ${line^^}"
       
       if [ -f $waves/$utt.wav ] ; then   #only files with all the associated info are written
          wav="$id $waves/$utt.wav"
          echo "$wav" >> data/test/wav.scp.unsorted
          #buscar que fer amb les cometes simples
          echo "$line" | tr -d '[.,?!:;"]'  >> data/test/text.unsorted
          echo "$id $spk" >> data/test/utt2spk.unsorted
	  echo "$spk $gender" >> data/test/spk2gender.unsorted
          words=( $line )
          num_words=${#words[@]}
	  if [[ $num_words -lt 3 ]] ; then  #id plus a word
                echo "$wav" >> data/test_word/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/test_word/text.unsorted
                echo "$id $spk" >> data/test_word/utt2spk.unsorted
                echo "$spk $gender" >> data/test_word/spk2gender.unsorted	     
	     	     	     	     	     	    
             else 
                echo "$wav" >> data/test_sentence/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/test_sentence/text.unsorted
                echo "$id $spk" >> data/test_sentence/utt2spk.unsorted
                echo "$spk $gender" >> data/test_sentence/spk2gender.unsorted
           fi
	  
	  
	  
	  if [[ $mic == 'headMic' ]] ; then
             echo "$wav" >> data/test_head/wav.scp.unsorted
             echo "$line" | tr -d '[.,?!:;"]'  >> data/test_head/text.unsorted
             echo "$id $spk" >> data/test_head/utt2spk.unsorted
             echo "$spk $gender" >> data/test_head/spk2gender.unsorted
             words=( $line )
             num_words=${#words[@]}
           
             if [[ $num_words -lt 3 ]] ; then  #id plus a word
                echo "$wav" >> data/test_head_word/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/test_head_word/text.unsorted
                echo "$id $spk" >> data/test_head_word/utt2spk.unsorted
                echo "$spk $gender" >> data/test_head_word/spk2gender.unsorted	     
	     	     	     	     	     	    
             else 
                echo "$wav" >> data/test_head_sentence/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/test_head_sentence/text.unsorted
                echo "$id $spk" >> data/test_head_sentence/utt2spk.unsorted
                echo "$spk $gender" >> data/test_head_sentence/spk2gender.unsorted
             fi
          fi
	  
	  
          if [[ $mic == 'arrayMic' ]] ; then
             echo "$wav" >> data/test_array/wav.scp.unsorted
             echo "$line" | tr -d '[.,?!:;"]'  >> data/test_array/text.unsorted
             echo "$id $spk" >> data/test_array/utt2spk.unsorted
             echo "$spk $gender" >> data/test_array/spk2gender.unsorted
             words=( $line )
             num_words=${#words[@]}
             if [[ $num_words -lt 3 ]] ; then  #id plus a word
                echo "$wav" >> data/test_array_word/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/test_array_word/text.unsorted
                echo "$id $spk" >> data/test_array_word/utt2spk.unsorted
                echo "$spk $gender" >> data/test_array_word/spk2gender.unsorted
             else 
                echo "$wav" >> data/test_array_sentence/wav.scp.unsorted
                echo "$line" | tr -d '[.,?!:;"]'  >> data/test_array_sentence/text.unsorted
                echo "$id $spk" >> data/test_array_sentence/utt2spk.unsorted
                echo "$spk $gender" >> data/test_array_sentence/spk2gender.unsorted
             fi
          fi	  
	  
	  
	  
	  
	  
	  
	  
       fi
   done
done

# Sorting and cleaning everything
for x in train train_word train_sentence test test_word test_sentence test_head test_head_word test_head_sentence test_array test_array_word test_array_sentence; do
    sort -u data/$x/wav.scp.unsorted > data/$x/wav.scp
    sort -u data/$x/text.unsorted > data/$x/text
     sed -i 's///g' data/$x/text
    sort -u data/$x/utt2spk.unsorted > data/$x/utt2spk
    sort -u data/$x/spk2gender.unsorted > data/$x/spk2gender
    rm data/$x/*.unsorted
    utils/utt2spk_to_spk2utt.pl data/$x/utt2spk > data/$x/spk2utt
done


# split traindata for lm building
#num_utts_total=$(wc -l <data/${trainset}/utt2spk)
  #num_train_90=$[$num_utts_total/10*9]
  #utils/data/subset_data_dir.sh data/${trainset} \
      #$num_train_90 data/train_90

  #num_train_10=$[$num_utts_total/10]
  #utils/data/subset_data_dir.sh data/${trainset} \
      #$num_train_10 data/train_10   
