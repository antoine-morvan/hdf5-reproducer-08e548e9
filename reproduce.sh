#!/bin/bash -eu

SCRIPT_DIR=$(dirname $(readlink -f $0))

[ -f $HOME/.proxy_vars.sh ] && source $HOME/.proxy_vars.sh
mkdir -p $SCRIPT_DIR/cache
CACHE_DIR=$SCRIPT_DIR/cache

########################
### ZLib
########################

ZLIB_VERSION=1.2.13

DEST=${SCRIPT_DIR}/zlib
mkdir -p ${DEST}
DIR=$(readlink -f ${DEST})
PREFIX=${DIR}/prefix

ZLIB_DIR=zlib-${ZLIB_VERSION}
ZLIB_ARCHIVE=${ZLIB_DIR}.tar.gz
ZLIB_URL=https://zlib.net/${ZLIB_ARCHIVE}
ZLIB_CACHE=${CACHE_DIR}/${ZLIB_ARCHIVE}

if [ ! -f ${PREFIX}/lib/libz.a ]; then
    echo "Extract & Build ZLib"
    if [ ! -d ${DIR}/${ZLIB_DIR} ]; then
        if [ ! -f ${DIR}/${ZLIB_ARCHIVE} ]; then
            [ ! -f ${ZLIB_CACHE} ] && wget -c ${ZLIB_URL} -O ${ZLIB_CACHE}
            cp ${ZLIB_CACHE} ${DIR}/${ZLIB_ARCHIVE}
        fi
        (cd ${DIR} && tar xf ${DIR}/${ZLIB_ARCHIVE})
    fi
    (cd ${DIR}/${ZLIB_DIR} && CFLAGS="-O3 -fPIC" ./configure --static --prefix=${PREFIX} ) |& tee ${SCRIPT_DIR}/01_zlib_configure.log
    (cd ${DIR}/${ZLIB_DIR} && make -j $(nproc)) |& tee ${SCRIPT_DIR}/02_zlib_make.log
    (cd ${DIR}/${ZLIB_DIR} && make -j $(nproc) install) |& tee ${SCRIPT_DIR}/03_zlib_make_install.log
    SETVARS_SCRIPT=${DIR}/setvars.sh
    cat > ${SETVARS_SCRIPT} << EOF
#!/bin/bash
echo " -- Load ZLib"
export ZLIB_HOME=${PREFIX}
export ZLIB_DIR=\$ZLIB_HOME
export ZLIB_ROOT=\$ZLIB_HOME
export ZLIB_LIB=\$ZLIB_HOME/lib
export ZLIB_LIBRARY=\$ZLIB_HOME/lib
export ZLIB_INC=\$ZLIB_HOME/include
export ZLIB_INCLUDE_DIR=\$ZLIB_HOME/include
export LD_LIBRARY_PATH=\$ZLIB_LIB:\${LD_LIBRARY_PATH:-}
export LIBRARY_PATH=\$ZLIB_LIB:\${LIBRARY_PATH:-}
EOF
    chmod +x ${SETVARS_SCRIPT}
    echo "Done: source '${SETVARS_SCRIPT}'"
else
    echo "Skip ZLib"
fi

########################
### HDF5
########################
source $SCRIPT_DIR/zlib/setvars.sh

HDF5_VERSION=1.13.2

DEST=${SCRIPT_DIR}/hdf5
mkdir -p ${DEST}
DIR=$(readlink -f ${DEST})
PREFIX=${DIR}/prefix

HDF5_DIR=hdf5-${HDF5_VERSION}
HDF5_ARCHIVE=${HDF5_DIR}.tar.bz2
HDF5_URL=https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-${HDF5_VERSION%.*}/${HDF5_DIR}/src/${HDF5_ARCHIVE}
HDF5_CACHE=${CACHE_DIR}/${HDF5_ARCHIVE}

echo "Extract & Build HDF5"
if [ ! -d ${DIR}/${HDF5_DIR} ]; then
    if [ ! -f ${DIR}/${HDF5_ARCHIVE} ]; then
        [ ! -f ${HDF5_CACHE} ] && wget -c ${HDF5_URL} -O ${HDF5_CACHE}
        cp ${HDF5_CACHE} ${DIR}/${HDF5_ARCHIVE}
    fi
    (cd ${DIR} && tar xf ${DIR}/${HDF5_ARCHIVE})
fi

mkdir -p ${DIR}/${HDF5_DIR}/build
    # -DBUILD_STATIC_LIBS=ON \
(cd ${DIR}/${HDF5_DIR}/build && cmake \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_STATIC_LIBS=ON \
    -DHDF5_ENABLE_Z_LIB_SUPPORT=ON \
    -DZLIB_USE_STATIC_LIBS=ON \
    -G "Unix Makefiles" \
    ${DIR}/${HDF5_DIR}) |& tee ${SCRIPT_DIR}/04_hdf5_cmake.log
(cd ${DIR}/${HDF5_DIR}/build && make -j $(nproc) VERBOSE=1)|& tee ${SCRIPT_DIR}/05_hdf5_make.log
(cd ${DIR}/${HDF5_DIR}/build && make -j $(nproc) install)|& tee ${SCRIPT_DIR}/06_hdf5_make_install.log

echo " -- "
echo " -- "
echo " -- "
echo " -- "
echo " -- Running 'nm' on static. Should NOT have undefined symbols (U <symbol name>) "
echo " -- "
set -x
nm ${PREFIX}/lib/libhdf5.a | grep inflate
nm ${PREFIX}/lib/libhdf5.so | grep inflate
set +x
