#!/bin/bash

# This script documents the installation procedure used to
# install GCC v13.2.0 with nvptx offload support.

GCC_VERSION="13.2.0"
BUILD_ID="${GCC_VERSION}-20240501"
JOBS=24
BUILDTIME="$(\date --iso-8601=min)"

PREFIX="/sw/frontier/ums/ums012/gcc/offloading/${BUILD_ID}"
WORKSPACE_PATH="/tmp/gcc-build-${BUILD_ID}"
SRC_PATH="${WORKSPACE_PATH}/src"

PKG_NAME="gcc-${GCC_VERSION}"
SRC_NAME="gcc-${GCC_VERSION}.tar.xz"

LOG_PATH="/ccs/home/jarmusch/gcc-build/logs"

set -e

mkdir -p "${LOG_PATH}"

# Function to log output and errors to separate files
log_step() {
    local step_name="$1"
    local log_file="${LOG_PATH}/build.${step_name}.${BUILDTIME}.log"
    shift
    {
        printf "\n\n=====================\n%s\n\n" "$step_name"
        "$@"
    } 2>&1 | tee "$log_file"
}

# Remove old build directories
[ -d "${WORKSPACE_PATH}" ] &&  rm -rf "${WORKSPACE_PATH}"
[ -d "${PREFIX}" ] &&  rm -rf "${PREFIX}"

module -t list

mkdir -pv "${SRC_PATH}"
cd "${SRC_PATH}"
# Get newlib # Get GCC source
log_step "Cloning newlib" git clone  https://sourceware.org/git/newlib-cygwin.git newlib
log_step "Downloading GCC source" wget "ftp://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/${SRC_NAME}"
log_step "Downloading LLVM source" wget "https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/llvm-project-17.0.6.src.tar.xz"
log_step "Extracting GCC source" tar -xf "${SRC_PATH}/${SRC_NAME}"
log_step "Extracting LLVM source" tar -xf llvm-project-17.0.6.src.tar.xz

cd "${SRC_PATH}/${PKG_NAME}"
./contrib/download_prerequisites
ln -s ../newlib/newlib .

mkdir -pv build-amdgcn/llvm
cd build-amdgcn/llvm
module load cmake ninja

cmake ${SRC_PATH}/llvm-project-17.0.6.src/llvm \
  -G Ninja \
  -DCMAKE_CXX_COMPILER=$(which g++) \
  -DCMAKE_C_COMPILER=$(which gcc) \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS=lld \
  -DLLVM_TARGETS_TO_BUILD='X86;AMDGPU'

ninja -j24

mkdir -pv "${PREFIX}/amdgcn-amdhsa/bin"
cd "${PREFIX}/amdgcn-amdhsa/bin"

ln -s ${SRC_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-ar amdgcn-amdhsa-ar
ln -s ${SRC_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-ar amdgcn-amdhsa-ranlib
ln -s ${SRC_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-ar ar
ln -s ${SRC_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-ar ranlib
ln -s ${SRC_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-mc as
ln -s ${SRC_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-nm nm
ln -s ${SRC_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/lld ld

cd "${SRC_PATH}/${PKG_NAME}/build-amdgcn"
mkdir -pv gcc
cd gcc

../../configure --target=amdgcn-amdhsa \
    --enable-languages="c,c++,fortran,lto" \
    --disable-bootstrap \
    --disable-sjlj-exceptions \
    --with-newlib \
    --enable-as-accelerator-for=x86_64-pc-linux-gnu \
    --with-build-time-tools="${PREFIX}/amdgcn-amdhsa/bin" \
    --disable-libquadmath \
    --prefix="${PREFIX}"

make -j24
make install




# mkdir -pv "${BUILD_PATH}"
# cd "${BUILD_PATH}"

# #log_step "Extracting LLVM source" tar -xf "${SRC_PATH}/llvm-project-18.1.4.src.tar.xz"

# cp -r "${SRC_PATH}/newlib" ./

# cd "${PKG_NAME}"
# mkdir -pv build-amdgcn/llvm
# cd build-amdgcn/llvm

# #module load cmake ninja

# #cmake ${BUILD_PATH}/llvm-project-18.1.4.src/llvm \
# #  -G Ninja \
# #  -DCMAKE_BUILD_TYPE=Release \
# #  -DLLVM_ENABLE_PROJECTS=lld \
# #  -D 'LLVM_TARGETS_TO_BUILD=X86;AMDGPU'

# #ninja -j"${JOBS}"


# cd "${BUILD_PATH}"
# HOST_TARGET=$(${PKG_NAME}/config.guess)
# OFFLOAD_TARGET="amdgcn-amdhsa"


# mkdir -pv "${PREFIX}"
# cd "${PREFIX}"

# mkdir -pv amdgcn-amdhsa/bin
# cd amdgcn-amdhsa/bin
# #ln -s ${BUILD_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-ar amdgcn-amdhsa-ar
# #ln -s ${BUILD_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-ar amdgcn-amdhsa-ranlib
# #ln -s ${BUILD_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-mc as
# #ln -s ${BUILD_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/llvm-nm nm
# #ln -s ${BUILD_PATH}/${PKG_NAME}/build-amdgcn/llvm/bin/lld ld
# ln -s /opt/rocm-5.3.0/llvm/bin/llvm-ar amdgcn-amdhsa-ar
# ln -s /opt/rocm-5.3.0/llvm/bin/llvm-ar amdgcn-amdhsa-ranlib
# ln -s /opt/rocm-5.3.0/llvm/bin/llvm-mc as
# ln -s /opt/rocm-5.3.0/llvm/bin/llvm-nm nm
# ln -s /opt/rocm-5.3.0/llvm/bin/lld ld

# cd "${BUILD_PATH}/${PKG_NAME}"
# # Get pre-requisites
# ./contrib/download_prerequisites
# ln -s "${BUILD_PATH}/newlib/newlib" newlib

# cd "${BUILD_PATH}"
# mkdir -pv build-amdgcn-gcc
# cd build-amdgcn-gcc
# # Build offload compiler
# log_step "Building GCC Offload Compiler" "${BUILD_PATH}/${PKG_NAME}/configure" \
#     --target="${OFFLOAD_TARGET}" \
#     --with-build-time-tools="${PREFIX}/amdgcn-amdhsa/bin" \
#     --enable-as-accelerator-for="${HOST_TARGET}" \
#     --disable-sjlj-exceptions \
#     --enable-newlib-io-long-long \
#     --enable-languages="c,c++,fortran,lto" \
#     --with-newlib \
#     --disable-libquadmath \
#     --prefix="${PREFIX}" && \
#     make -j "${JOBS:-1}" && \
#     make install

# cd "${BUILD_PATH}"
# mkdir -pv build-gcc
# cd build-gcc
# # Build host compiler
# log_step "Building GCC Host Compiler" "${BUILD_PATH}/${PKG_NAME}/configure" \
#     --prefix="${PREFIX}" \
#     --enable-offload-targets="${OFFLOAD_TARGET}=${BUILD_PATH}/amdgcn-amdhsa/bin" \
#     --enable-languages="c,c++,fortran,lto" \
#     --disable-bootstrap \
#     --disable-multilib  && \
#     make -j "${JOBS:-1}" && \
#     make install

echo "Finished successfully"


#../../configure --target=amdgcn-amdhsa --enable-languages=c,c++,fortran,lto --disable-sjlj-exceptions --with-newlib --enable-as-accelerator-for=x86_64-pc-linux-gnu --with-build-time-tools=/tmp/gcc/12.2.0-openacc/amdgcn-amdhsa/bin --disable-libquadmath --prefix=/tmp/gcc/12.2.0-openacc
# /tmp/gcc/12.2.0-openacc/src/gcc-13.2.0/build-amdgcn/gcc/amdgcn-amdhsa/libgcc
