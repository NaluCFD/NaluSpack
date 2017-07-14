#!/bin/bash -l

#PBS -N nalu_build_intel
#PBS -l nodes=1:ppn=24,walltime=4:00:00
#PBS -A windFlowModeling
#PBS -q batch
#PBS -j oe
#PBS -W umask=002

#Script for installing Nalu on Merlin using Spack with Intel compiler

set -e

module purge
module load GCC/4.8.5

export INTEL_LICENSE_FILE=28518@hpc-admin1.hpc.nrel.gov

for i in ICCCFG ICPCCFG IFORTCFG
do
  export $i=${SPACK_ROOT}/etc/spack/intel.cfg
done

# Get TPL preferences from a single location
NALUSPACK_ROOT=`pwd`
source ${NALUSPACK_ROOT}/../spack_config/tpls.sh
TPLS="${TPLS} ^openmpi@1.10.3 ^cmake@3.6.1 ^netlib-lapack"

export TMPDIR=/dev/shm
spack install nalu %intel@17.0.2 ^${TRILINOS}@develop ${TPLS}
