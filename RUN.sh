#!/bin/bash

./print_lm.sh --model tri3b

./print_lm.sh --model dnn3b_pretrain-dbn_dnn

./print_correct.sh --model tri3b

./print_correct.sh --model dnn3b_pretrain-dbn_dnn
