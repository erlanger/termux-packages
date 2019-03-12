
                           ########################################
                           #          For development             #
                           ########################################

# Executed by TERMUX_PKG_VERSION, don't call it otherwise
clone_with_git() {
         if [ -z "${SWIPL_SRC}" ]; then
            (>&2 echo "BUG: clone_with_git called with empty SWIPL_SRC")
         fi

         if [ x${SWIPL_SRC=} = x"master"  ]; then           #use master from github
            local git_src="https://github.com/SWI-Prolog/swipl-devel"
         elif [ x${SWIPL_SRC=} = x"local" ]; then           #use local swi-devel dir
            local git_src="$TERMUX_PKG_BUILDER_DIR/swipl-devel"
         fi

         (>&2 echo "GITSRC= $git_src")

         if [ -n ${TERMUX_FORCE_BUILD=""} ] && \
            [ -n ${_CACHED_SRC_DIR=""} ]; then                #delete cache if -f given
            rm -rf "$_CACHED_SRC_DIR"
            rm -rf "$TERMUX_PKG_SRCDIR"
         fi

         mkdir -p $_CACHED_SRC_DIR
         pushd $_CACHED_SRC_DIR > /dev/null
         if [ ! -d .git ] ; then                              #if we have not cloned it
            if [ x${SWIPL_SRC=} = x"master"  ]; then        #use master from github
               git clone --shallow-since=Nov-18-2018                  \
                         --shallow-submodules                        \
                         $git_src                                    \
                         . > /dev/null
               git submodule update --init > /dev/null
            elif [ x${SWIPL_SRC=} = x"local" ]; then        #use local swi-devel dir
               tar -C $git_src -cf - . | tar -xf -
            fi
         else                                                 #pull if we have cloned it
            git pull > /dev/null
         fi

         local GITVER=`git describe --abbrev=9|tail -c +2`
         popd > /dev/null

         (>&2 echo "Building SWI-Prolog from git, version $GITVER")

         echo $GITVER
}


                           ########################################
                           #          Set variables               #
                           ########################################
_TMP_DIR=${TERMUX_PREFIX}/../../cache
TERMUX_PKG_HOMEPAGE=https://swi-prolog.org/
TERMUX_PKG_DESCRIPTION="Most popular and complete prolog implementation"

if [ x${SWIPL_SRC=} = x"master" ]  || \
   [ x${SWIPL_SRC=} = x"local" ]; then        #use master branch
   _CACHED_SRC_DIR="${TERMUX_PKG_CACHEDIR}/swi-prolog.$SWIPL_SRC"
   TERMUX_PKG_VERSION=`clone_with_git`
   TERMUX_PKG_EXTRA_CONFIGURE_ARGS="-DINSTALL_TESTS=ON -DBUILD_TESTING=ON "
fi

TERMUX_PKG_DEPENDS="readline, libgmp, libcrypt, pcre, libarchive, libyaml, libjpeg-turbo, ncurses, ncurses-ui-libs, ossp-uuid"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
$TERMUX_PKG_EXTRA_CONFIGURE_ARGS
-DINSTALL_DOCUMENTATION=OFF
-DUSE_GMP=ON
-DSWIPL_NATIVE_FRIEND=${TERMUX_PKG_HOSTBUILD_DIR}
-DPOSIX_SHELL=${TERMUX_PREFIX}/bin/sh
-DSWIPL_TMP_DIR=${_TMP_DIR}
-DSWIPL_INSTALL_IN_LIB=ON
-DSWIPL_PACKAGES_BDB=OFF
-DSWIPL_PACKAGES_ODBC=OFF
-DSWIPL_PACKAGES_QT=OFF
-DSWIPL_PACKAGES_X=OFF
-DINSTALL_TESTS=ON
-DBUILD_TESTING=ON
-DSYSTEM_CACERT_FILENAME=${TERMUX_PREFIX}/etc/tls/cert.pem"

TERMUX_PKG_FORCE_CMAKE=true
TERMUX_PKG_HOSTBUILD=true

                           ########################################
                           #          Prepare sources             #
                           ########################################

#Needed only for development from git source
if [ x${SWIPL_SRC=} = x"master" ]  || \
   [ x${SWIPL_SRC=} = x"local" ]; then
   (>&2 echo "----------------> BUILDING from GIT: $SWIPL_SRC" )
   termux_step_extract_package() {
         mkdir -p "$TERMUX_PKG_SRCDIR"
         set +u
         pushd "$_CACHED_SRC_DIR"
         set -u

         # Now copy the files to the SRCDIR
         # The files came from clone_with_git() which is 
         # ran to get the value of TERMUX_PKG_VERSION
         cp -ar . "$TERMUX_PKG_SRCDIR"

         popd
   }
fi
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
        sudo apt-get -y install openssl libssl-dev:i386 zlib1g-dev:i386

        if [ $TERMUX_ARCH_BITS = 32 ]; then
           export LDFLAGS=-m32 
           export CFLAGS=-m32 
           export CXXFLAGS=-m32 

           CMAKE_EXTRA_DEFS="-DCMAKE_LIBRARY_PATH=/usr/lib/i386-linux-gnu"
           #CMAKE_EXTRA_DEFS="-DSWIPL_M32"

        else
           CMAKE_EXTRA_DEFS=""
        fi

        cmake "$TERMUX_PKG_SRCDIR"                           \
           -G "Ninja"                                        \
           $CMAKE_EXTRA_DEFS				     \
           -DINSTALL_DOCUMENTATION=OFF                       \
           -DSWIPL_PACKAGES=ON                               \
           -DUSE_GMP=OFF                                         \
           -DBUILD_TESTING=ON                                \
           -DSWIPL_SHARED_LIB=OFF
        ninja

        unset LDFLAGS
        unset CFLAGS
        unset CXXFLAGS
}

#For development from git source
termux_step_pre_configure () {
        # Download submodules only if we are using git
        # and not local files
        if [ -d .git ] && \
           [ x${SWIPL_SRC=} != x"local" ]; then
           git submodule update --init
        fi
}



                           ########################################
                           #       Put final libraries and        #
                           #   binaries in the appropiate place   #
                           ########################################
#Executed after make install
termux_step_post_make_install () {
        mkdir -p ${_TMP_DIR}

        # Remove host build because future builds may be
        # of a different word size (e.g. 32bit or 64bit)
        rm -rf "$TERMUX_PKG_HOSTBUILD_DIR"

}

