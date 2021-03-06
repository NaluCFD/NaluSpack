#!/bin/bash -l

# Instructions:
# Make a directory in the Nalu-Wind directory for building,
# Copy this script to that directory and edit the
# options below to your own needs and run it.

COMPILER=gcc #intel

if [ "${COMPILER}" == 'gcc' ]; then
  CXX_COMPILER=mpicxx
  FORTRAN_COMPILER=mpif90
  #FLAGS="-O2 -march=skylake-avx512 -mtune=skylake-avx512"
  FLAGS="-O2 -march=skylake -mtune=skylake"
  OVERSUBSCRIBE_FLAGS="--use-hwthread-cpus --oversubscribe"
elif [ "${COMPILER}" == 'intel' ]; then
  CXX_COMPILER=mpiicpc
  FORTRAN_COMPILER=mpiifort
  FLAGS="-O2 -xSKYLAKE-AVX512"
fi
  
set -e

cmd() {
  echo "+ $@"
  eval "$@"
}

# Set up environment on Eagle
cmd "module purge"
cmd "module unuse ${MODULEPATH}"
cmd "module use /nopt/nrel/ecom/hpacf/compilers/modules-2020-07"
cmd "module use /nopt/nrel/ecom/hpacf/utilities/modules-2020-07"
if [ "${COMPILER}" == 'gcc' ]; then
  cmd "module use /nopt/nrel/ecom/hpacf/software/modules-2020-07/gcc-8.4.0"
elif [ "${COMPILER}" == 'intel' ]; then
  cmd "module use /nopt/nrel/ecom/hpacf/software/modules-2020-07/intel-18.0.4"
fi
cmd "module load gcc"
cmd "module load python"
cmd "module load git"
cmd "module load binutils"
if [ "${COMPILER}" == 'gcc' ]; then
  cmd "module load mpt"
  cmd "module load netlib-lapack"
elif [ "${COMPILER}" == 'intel' ]; then
  cmd "module load intel-parallel-studio/cluster.2018.4"
  cmd "module load intel-mpi/2018.4.274"
  cmd "module load intel-mkl/2018.4.274"
fi
#cmd "module load openfast"
cmd "module load hypre"
cmd "module load tioga"
cmd "module load yaml-cpp"
cmd "module load cmake"
#cmd "module load trilinos"
cmd "module load fftw"
cmd "module load boost"
cmd "module list"

TRILINOS_ROOT_DIR=/projects/hfm/shreyas/exawind/install/gcc/trilinos

# Set tmpdir to the scratch filesystem so it doesn't run out of space
cmd "mkdir -p ${HOME}/.tmp"
cmd "export TMPDIR=${HOME}/.tmp"

# Clean before cmake configure
set +e
cmd "rm -rf CMakeFiles"
cmd "rm -f CMakeCache.txt"
set -e

cmd "which cmake"
cmd "which mpirun"

# Extra TPLs that can be included in the cmake configure:
#  -DENABLE_PARAVIEW_CATALYST:BOOL=ON \
#  -DPARAVIEW_CATALYST_INSTALL_PATH:PATH=${CATALYST_IOSS_ADAPTER_ROOT_DIR} \
#  -DENABLE_OPENFAST:BOOL=ON \
#  -DOpenFAST_DIR:PATH=${OPENFAST_ROOT_DIR} \
#  -DENABLE_FFTW:BOOL=ON \
#  -DFFTW_DIR:PATH=${FFTW_ROOT_DIR} \
#  -DCMAKE_BUILD_RPATH:STRING="${NETLIB_LAPACK_ROOT_DIR}/lib64;${TIOGA_ROOT_DIR}/lib;${HYPRE_ROOT_DIR}/lib;${OPENFAST_ROOT_DIR}/lib;${FFTW_ROOT_DIR}/lib;${YAML_ROOT_DIR}/lib;${TRILINOS_ROOT_DIR}/lib;$(pwd)" \
# Rpath stuff I don't have fully working
#  -DCMAKE_SKIP_BUILD_RPATH:BOOL=FALSE \
#  -DCMAKE_BUILD_WITH_INSTALL_RPATH:BOOL=FALSE \
#  -DCMAKE_INSTALL_RPATH_USE_LINK_PATH:BOOL=TRUE \
#  -DCMAKE_BUILD_RPATH:STRING="${NETLIB_LAPACK_ROOT_DIR}/lib64;${TIOGA_ROOT_DIR}/lib;${HYPRE_ROOT_DIR}/lib;${YAML_ROOT_DIR}/lib;${TRILINOS_ROOT_DIR}/lib;$(pwd)" \

(set -x; cmake \
  -DCMAKE_CXX_COMPILER:STRING=${CXX_COMPILER} \
  -DCMAKE_CXX_FLAGS:STRING="${FLAGS}" \
  -DCMAKE_Fortran_COMPILER:STRING=${FORTRAN_COMPILER} \
  -DCMAKE_Fortran_FLAGS:STRING="${FLAGS}" \
  -DMPI_CXX_COMPILER:STRING=${CXX_COMPILER} \
  -DMPI_Fortran_COMPILER:STRING=${FORTRAN_COMPILER} \
  -DMPIEXEC_PREFLAGS:STRING="${OVERSUBSCRIBE_FLAGS}" \
  -DTrilinos_DIR:PATH=${TRILINOS_ROOT_DIR} \
  -DYAML_DIR:PATH=${YAML_CPP_ROOT_DIR} \
  -DBoost_DIR:PATH=${BOOST_ROOT_DIR} \
  -DENABLE_HYPRE:BOOL=ON \
  -DHYPRE_DIR:PATH=${HYPRE_ROOT_DIR} \
  -DENABLE_TIOGA:BOOL=ON \
  -DTIOGA_DIR:PATH=${TIOGA_ROOT_DIR} \
  -DCMAKE_BUILD_TYPE:STRING=RELEASE \
  -DENABLE_DOCUMENTATION:BOOL=OFF \
  -DENABLE_TESTS:BOOL=ON \
  ..)

(set -x; nice make -j 16)
