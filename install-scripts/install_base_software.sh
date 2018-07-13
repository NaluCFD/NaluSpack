#!/bin/bash -l

#PBS -N install-base-software
#PBS -l nodes=1:ppn=24,walltime=24:00:00,feature=haswell
#PBS -A windsim
#PBS -q batch-h
#PBS -j oe
#PBS -W umask=002

# Script for shared installation of ECP related software on Peregrine and Rhodes using Spack

# Control over printing and executing commands
print_cmds=true
execute_cmds=true

# Function for printing and executing commands
cmd() {
  if ${print_cmds}; then echo "+ $@"; fi
  if ${execute_cmds}; then eval "$@"; fi
}

printf "============================================================\n"
printf "$(date)\n"
printf "============================================================\n"
printf "Job is running on ${HOSTNAME}\n"
printf "============================================================\n"
if [ ! -z "${PBS_JOBID}" ]; then
  printf "PBS: Qsub is running on ${PBS_O_HOST}\n"
  printf "PBS: Originating queue is ${PBS_O_QUEUE}\n"
  printf "PBS: Executing queue is ${PBS_QUEUE}\n"
  printf "PBS: Working directory is ${PBS_O_WORKDIR}\n"
  printf "PBS: Execution mode is ${PBS_ENVIRONMENT}\n"
  printf "PBS: Job identifier is ${PBS_JOBID}\n"
  printf "PBS: Job name is ${PBS_JOBNAME}\n"
  printf "PBS: Node file is ${PBS_NODEFILE}\n"
  printf "PBS: Current home directory is ${PBS_O_HOME}\n"
  printf "PBS: PATH = ${PBS_O_PATH}\n"
  printf "============================================================\n"
fi

# Find machine we're on
MYHOSTNAME=$(hostname -d)
case "${MYHOSTNAME}" in
  hpc.nrel.gov)
    MACHINE=peregrine
  ;;
esac
MYHOSTNAME=$(hostname -s)
case "${MYHOSTNAME}" in
  rhodes)
    MACHINE=rhodes
  ;;
esac
 
if [ "${MACHINE}" == 'peregrine' ]; then
  INSTALL_DIR=/nopt/nrel/ecom/ecp/base/a
  GCC_COMPILER_VERSION="6.2.0"
  INTEL_COMPILER_VERSION="18.1.163"
elif [ "${MACHINE}" == 'rhodes' ]; then
  INSTALL_DIR=/opt/software/a
  GCC_COMPILER_VERSION="4.8.5"
  INTEL_COMPILER_VERSION="18.1.163"
else
  printf "\nMachine name not recognized.\n"
  exit 1
fi

TRILINOS_BRANCH=develop
BUILD_TEST_DIR=${INSTALL_DIR}/build-test

# Set spack location
export SPACK_ROOT=${INSTALL_DIR}/spack

if [ ! -d "${INSTALL_DIR}" ]; then
  printf "============================================================\n"
  printf "Install directory doesn't exist.\n"
  printf "Creating everything from scratch...\n"
  printf "============================================================\n"

  printf "Creating top level install directory...\n"
  cmd "mkdir -p ${INSTALL_DIR}"

  printf "\nCloning Spack repo...\n"
  cmd "git clone https://github.com/spack/spack.git ${SPACK_ROOT}"

  printf "\nConfiguring Spack...\n"
  cmd "git clone https://github.com/exawind/build-test.git ${BUILD_TEST_DIR}"
  cmd "cd ${BUILD_TEST_DIR}/configs && ./setup-spack.sh"

  printf "============================================================\n"
  printf "Done setting up install directory.\n"
  printf "============================================================\n"
fi

printf "\nLoading Spack...\n"
cmd "source ${SPACK_ROOT}/share/spack/setup-env.sh"
cmd "source ${INSTALL_DIR}/build-test/configs/shared-constraints.sh"

for COMPILER_NAME in gcc intel
do
  if [ ${COMPILER_NAME} == 'gcc' ]; then
    COMPILER_VERSION="${GCC_COMPILER_VERSION}"
  elif [ ${COMPILER_NAME} == 'intel' ]; then
    COMPILER_VERSION="${INTEL_COMPILER_VERSION}"
  fi
  printf "\nInstalling base software with ${COMPILER_NAME}@${COMPILER_VERSION} at $(date).\n"

  # Load necessary modules
  printf "\nLoading modules...\n"
  if [ "${MACHINE}" == 'peregrine' ]; then
    cmd "module purge"
    cmd "module use /nopt/nrel/ecom/ecp/base/c/spack/share/spack/modules/linux-centos7-x86_64/gcc-6.2.0"
    cmd "module load gcc/6.2.0"
    cmd "module load git/2.17.0"
    cmd "module load python/2.7.14"
    cmd "module load curl/7.59.0"
    cmd "module load binutils/2.29.1"
    cmd "module load texinfo/6.5"
    cmd "module load texlive/live"
    cmd "module list"
    # Set the TMPDIR to disk so it doesn't run out of space
    printf "\nMaking and setting TMPDIR to disk...\n"
    cmd "mkdir -p /scratch/${USER}/.tmp"
    cmd "export TMPDIR=/scratch/${USER}/.tmp"
  elif [ "${MACHINE}" == 'rhodes' ]; then
    #Rhodes has almost *nothing* installed on it besides python and gcc
    #so we are relying on Spack heavily as a non-root package manager here.
    #Kind of annoying to use Spack to build tools Spack needs, but after
    #the initial bootstrapping, we can now just rely on pure modules sans Spack
    #to set up our environment and tools we need to build with Spack.
    
    #Pure modules sans Spack (assuming the module init is alreay in .bashrc)
    #export MODULE_PREFIX=/opt/software/module_prefix
    #export PATH=${MODULE_PREFIX}/Modules/bin:${PATH}
    #module() { eval $(${MODULE_PREFIX}/Modules/bin/modulecmd $(basename ${SHELL}) $*); }
    #module use /opt/software/modules
    cmd "module purge"
    cmd "module load unzip"
    cmd "module load patch"
    cmd "module load bzip2"
    cmd "module load cmake"
    cmd "module load git"
    cmd "module load texinfo"
    cmd "module load flex"
    cmd "module load bison"
    cmd "module load wget"
    cmd "module load texlive"
    cmd "module list"
    printf "\nBootstrapping Spack with environment-modules...\n"
    #cmd "spack bootstrap"
    cmd "spack install environment-modules %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "source ${SPACK_ROOT}/share/spack/setup-env.sh"
  fi

  if [ ${COMPILER_NAME} == 'gcc' ]; then
    # Install our own python
    printf "\nInstalling Python using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    for PYTHON_VERSION in '2.7.15' '3.6.5'; do
      cmd "spack install python@${PYTHON_VERSION} %${COMPILER_NAME}@${COMPILER_VERSION}"
      for PYTHON_LIBRARY in py-numpy py-matplotlib py-pandas py-nose py-autopep8 py-flake8 py-jedi py-pip py-pyyaml py-rope py-seaborn py-sphinx py-yapf py-scipy py-yt; do
        cmd "spack install ${PYTHON_LIBRARY} ^python@${PYTHON_VERSION} %${COMPILER_NAME}@${COMPILER_VERSION}"
      done
    done

    printf "\nInstalling other tools using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    cmd "spack install binutils %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install curl %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install wget %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install cmake %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install emacs %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install vim %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install git %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install tmux %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install screen %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install global %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install texlive scheme=full %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install gnuplot+X+wx %${COMPILER_NAME}@${COMPILER_VERSION} ^pango+X"
    cmd "spack install htop %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install makedepend %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install libxml2+python %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install cppcheck %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install likwid %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install texinfo %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install masa %${COMPILER_NAME}@${COMPILER_VERSION}"

    # Rhodes specific
    if [ "${MACHINE}" == 'rhodes' ]; then
      cmd "spack install unzip %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install bc %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install patch %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install bzip2 %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install flex %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install bison %${COMPILER_NAME}@${COMPILER_VERSION}"
      printf "\nInstalling stuff needed for Visit ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
      cmd "spack install libxrender %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install libxml2+python %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install libxrandr %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install libxi %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install libxft %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install libxcursor %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install libxt %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install glib %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install glproto %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install libxt %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install mesa %${COMPILER_NAME}@${COMPILER_VERSION}"
      cmd "spack install mesa-glu %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install xproto %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install inputproto %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install xextproto %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install xcb-proto %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install xtrans %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install fontconfig %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install freetype %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install randrproto %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install renderproto %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libx11 %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxau %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxcb %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxcursor %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxdamage %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxdmcp %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxext %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxfixes %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxft %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxi %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxpm %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxrandr %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxrender %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxshmfence %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxv %${COMPILER_NAME}@${COMPILER_VERSION}"
      #cmd "spack install libxvmc %${COMPILER_NAME}@${COMPILER_VERSION}"
    fi

    # Install our own compilers
    printf "\nInstalling compilers using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    cmd "spack install gcc@8.1.0 %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install gcc@7.3.0 %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install gcc@6.4.0 %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install gcc@5.5.0 %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install gcc@4.9.4 %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install llvm %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install intel-parallel-studio@cluster.2018.1+advisor+inspector+mkl+mpi+vtune threads=openmp %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install flang %${COMPILER_NAME}@${COMPILER_VERSION}"

    printf "\nInstalling Nalu-Wind stuff using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    # Install Nalu-Wind dependencies with everything turned on
    cmd "spack install --only dependencies nalu-wind+openfast+tioga+hypre+catalyst %${COMPILER_NAME}@${COMPILER_VERSION} ^${TRILINOS}@${TRILINOS_BRANCH}"
    # Install Nalu-Wind with Trilinos debug
    cmd "spack install --only dependencies nalu-wind+openfast+tioga+hypre+catalyst %${COMPILER_NAME}@${COMPILER_VERSION} build_type=Debug ^${TRILINOS}@${TRILINOS_BRANCH} build_type=Debug"
    # Turn off OpenMP
    TRILINOS=$(sed 's/+openmp/~openmp/g' <<<"${TRILINOS}")
    # Install Nalu-Wind dependencies with everything turned on
    cmd "spack install --only dependencies nalu-wind+openfast+tioga+hypre+catalyst %${COMPILER_NAME}@${COMPILER_VERSION} ^${TRILINOS}@${TRILINOS_BRANCH}"
    # Install Nalu-Wind with Trilinos debug
    cmd "spack install --only dependencies nalu-wind+openfast+tioga+hypre+catalyst %${COMPILER_NAME}@${COMPILER_VERSION} build_type=Debug ^${TRILINOS}@${TRILINOS_BRANCH} build_type=Debug"

    printf "\nInstalling NetCDF Fortran using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    (set -x; spack install netcdf-fortran@4.4.3 %${COMPILER_NAME}@${COMPILER_VERSION} ^/$(spack find -L netcdf %${COMPILER_NAME}@${COMPILER_VERSION} ^hdf5+cxx | grep netcdf | awk -F" " '{print $1}' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g"))

    printf "\nInstalling Percept using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    cmd "spack install percept %${COMPILER_NAME}@${COMPILER_VERSION} ^${TRILINOS_PERCEPT}@12.12.1 ^netcdf@4.3.3.1 ^hdf5@1.8.16 ^boost@1.60.0 ^parallel-netcdf@1.6.1 ^libxml2@2.9.4"

    printf "\nInstalling Valgrind using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    cmd "spack install valgrind %${COMPILER_NAME}@${COMPILER_VERSION}"

    printf "\nInstalling Paraview server using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    cmd "spack install paraview+mpi+python+osmesa+visit+boxlib %${COMPILER_NAME}@${COMPILER_VERSION}"
    #printf "\nInstalling Paraview GUI using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    #cmd "spack install paraview+mpi+python+qt+visit+boxlib %${COMPILER_NAME}@${COMPILER_VERSION}" # Use downloadable paraview

    printf "\nInstalling Amrvis using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    cmd "spack install amrvis+mpi dims=3 %${COMPILER_NAME}@${COMPILER_VERSION}"
    cmd "spack install amrvis+mpi dims=2 %${COMPILER_NAME}@${COMPILER_VERSION}"
  elif [ ${COMPILER_NAME} == 'intel' ]; then
    # Need to update compilers.yaml to point to newest intel-parallel-studio built by gcc before installing with intel
    printf "\nInstalling Nalu-Wind stuff using ${COMPILER_NAME}@${COMPILER_VERSION}...\n"
    cmd "spack install --only dependencies nalu-wind+openfast+tioga+hypre %${COMPILER_NAME}@${COMPILER_VERSION} ^${TRILINOS}@${TRILINOS_BRANCH} ^intel-mpi ^intel-mkl"
    # Turn off OpenMP
    TRILINOS=$(sed 's/+openmp/~openmp/g' <<<"${TRILINOS}")
    cmd "spack install --only dependencies nalu-wind+openfast+tioga+hypre %${COMPILER_NAME}@${COMPILER_VERSION} ^${TRILINOS}@${TRILINOS_BRANCH} ^intel-mpi ^intel-mkl"
  fi

  cmd "unset TMPDIR"

  printf "\nDone installing shared software with ${COMPILER_NAME}@${COMPILER_VERSION} at $(date).\n"
done

printf "\nSetting permissions...\n"
if [ "${MACHINE}" == 'peregrine' ]; then
  #cmd "chmod -R a+rX,o-w,g+w ${INSTALL_DIR}"
elif [ "${MACHINE}" == 'rhodes' ]; then
  cmd "chgrp windsim /opt"
  cmd "chgrp -R windsim /opt/software"
  cmd "chgrp -R windsim ${INSTALL_DIR}"
  cmd "chmod a+rX,go-w /opt"
  cmd "chmod -R a+rX,go-w /opt/software"
  cmd "chmod -R a+rX,go-w ${INSTALL_DIR}"
fi

printf "\n$(date)\n"
printf "\nDone!\n"

# Other final manual customizations:
# - Rename necessary module files and set defaults
# - Use downloadable Paraview for dav node; add module
# - Use downloadable Visit for dav node; add module
# - Add visit server module manually, and add ld_library_path stuff to internallauncher