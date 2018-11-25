                           ########################################
                           #          Set variables               #
                           ########################################
TERMUX_PKG_HOMEPAGE=https://swi-prolog.org/
TERMUX_PKG_DESCRIPTION="Most popular and complete prolog implementation"
TERMUX_PKG_VERSION=7.7.22
TERMUX_PKG_REVISION=1
TERMUX_PKG_SHA256="55096d6bc1d70463b3cf1148e43e8953733ab30ca06ba3f467b562762ed4cb4c"
TERMUX_PKG_SRCURL=http://www.swi-prolog.org/download/devel/src/swipl-${TERMUX_PKG_VERSION}.tar.gz

TERMUX_PKG_DEPENDS="readline, libgmp, libcrypt, pcre, libarchive, libyaml, libjpeg-turbo"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DINSTALL_DOCUMENTATION=OFF
-DUSE_GMP=ON
-DSWIPL_NATIVE_FRIEND=${TERMUX_PKG_HOSTBUILD_DIR}
-DUNIX_SHELL=${TERMUX_PREFIX}/bin/sh
-DSWIPL_TMP_DIR=${TERMUX_PREFIX}/lib/swipl/tmp
-DSWIPL_INSTALL_IN_LIB=ON
-DSWIPL_PACKAGES_BDB=OFF
-DSWIPL_PACKAGES_ODBC=OFF
-DSWIPL_PACKAGES_QT=OFF
-DSWIPL_PACKAGES_X=OFF
-C${TERMUX_PKG_BUILDER_DIR}/TryRunResults.cmake"

#-DCMAKE_CROSSCOMPILING_EMULATOR=qemu-arm-static"

TERMUX_PKG_FORCE_CMAKE=true
TERMUX_PKG_HOSTBUILD=true

                           ########################################
                           #          Build in Host               #
                           #   (in addition to crosscompiling)    #
                           ########################################
# We do this to produce:
# a native host build to produce
# boot<nn>.prc, INDEX.pl, ssl cetificate tests,
# SWIPL_NATIVE_FRIEND tells SWI-Prolog to use 
# this build for the artifacts needed to build the
# Android version
termux_step_host_build () {
        termux_setup_ninja
        termux_setup_cmake

        sudo dpkg --add-architecture i386
        sudo apt-get -y update
        sudo apt-get -y install zlib1g-dev:i386

        if [ $TERMUX_ARCH_BITS = 32 ]; then
           export LDFLAGS=-m32 
           export CFLAGS=-m32 
           export CXXFLAGS=-m32 

        fi

        cmake "$TERMUX_PKG_SRCDIR"                           \
           -G "Ninja"                                        \
           -DINSTALL_DOCUMENTATION=OFF                       \
           -DSWIPL_PACKAGES=ON                               \
           -DGMP=OFF                                         \
           -DBUILD_TESTING=ON                                \
           -DSWIPL_SHARED_LIB=OFF
        ninja

        unset LDFLAGS
        unset CFLAGS
        unset CXXFLAGS
}



                           ########################################
                           #       Put final libraries and        #
                           #   binaries in the appropiate place   #
                           ########################################
#Executed after make install
termux_step_post_make_install () {
        mkdir -p ${TERMUX_PREFIX}/lib/swipl/tmp
}


