#setup_env.sh
module load apps/python/conda
source activate python2

#sharc
if [ "$SGE_CLUSTER_NAME" == "sharc" ]; then
module load libs/icu/58.2/gcc-4.9.4
module load libs/CUDA/8.0.44 # note uppercase CUDA
module load dev/gcc/4.9.4
module load dev/cmake/3.7.1/gcc-4.9.4
PATH=/usr/local/packages/libs/icu/58.2/gcc-4.9.4/bin/:$PATH
PATH=/home/$USER/package/bin:$PATH
PATH=/usr/local/sge/live/bin/lx-amd64:$PATH
fi


