#Get latest version number when using "master"
#or file url in the SWIPL_SRC variable
#get_master_vsn() {
   #local verf=./swipl-latest-version
   #curl -s --compressed -o $verf http://www.swi-prolog.org/ && \
   #   perl -0777 -p -i -e 's/.*by SWI-Prolog (\d+\.\d+.\d+).*$/\1/gs' $verf
   #if [ $? -eq 0 ]; then
   #   local VER=`cat $verf`
   #   cp $verf $verf.cache
   #else
   #   local VER=`cat $verf.cache`
   #fi 
   #echo $VER
   #(>&2 echo "Building SWI-Prolog from git, last version $VER")
#}

                           ########################################
                           #          Set variables               #
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
            rm -rf $_CACHED_SRC_DIR
         fi

         mkdir -p $_CACHED_SRC_DIR
         pushd $_CACHED_SRC_DIR > /dev/null
         if [ ! -d .git ] ; then                              #if we have not cloned it
            if [ x${SWIPL_SRC=} = x"master"  ]; then        #use master from github
               git clone --shallow-since=Nov-5-2018                  \
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

         local GITVER=`git describe|tail -c +2`
         popd > /dev/null

         (>&2 echo "Building SWI-Prolog from git, version $GITVER")

         echo $GITVER
}


TERMUX_PKG_HOMEPAGE=https://swi-prolog.org/
TERMUX_PKG_DESCRIPTION="Most popular and complete prolog implementation"

if [ x${SWIPL_SRC=} = x"master" ]  || \
   [ x${SWIPL_SRC=} = x"local" ]; then        #use master branch
   _CACHED_SRC_DIR="${TERMUX_PKG_CACHEDIR}/swi-prolog.$SWIPL_SRC"
   TERMUX_PKG_VERSION=`clone_with_git`
else                                           #use latest release (manual)
   TERMUX_PKG_VERSION=7.7.21
   TERMUX_PKG_REVISION=1
   TERMUX_PKG_SHA256="f4795d3e6abe9289729169a9d74a006e55df95a2e118b7a1701bb7bd92c864f4"
   TERMUX_PKG_SRCURL=http://www.swi-prolog.org/download/devel/src/swipl-${TERMUX_PKG_VERSION}.tar.gz
fi

TERMUX_PKG_DEPENDS="readline, libgmp, libcrypt, pcre, libarchive, libyaml, libuuid, libjpeg-turbo"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DTERMUX_ARCH=${TERMUX_ARCH}
-DINSTALL_DOCUMENTATION=OFF
-DUSE_GMP=ON
-DPROG_OPENSSL=
-C${TERMUX_PKG_BUILDER_DIR}/TryRunResults.cmake"
#-DCMAKE_CROSSCOMPILING_EMULATOR=qemu-arm-static"

TERMUX_PKG_FORCE_CMAKE=true
TERMUX_PKG_HOSTBUILD=true

                           ########################################
                           #          Prepare sources             #
                           ########################################

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
# - defatom, mkvmi and swipl
#    to be used during crosscompiling
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
           -DSWIPL_PACKAGES=OFF                              \
           -DGMP=OFF                                         \
           -DPROG_OPENSSL=                                   \
           -DSWIPL_SHARED_LIB=OFF
        ninja

        unset LDFLAGS
        unset CFLAGS
        unset CXXFLAGS
}

termux_step_pre_configure () {
        if [ -d .git ]; then
           git submodule update --init
        fi
}


                           ########################################
                           #     Put prebuilt defatom, mkvmi      #
                           #     and swipl in a usable place      #
                           ########################################
termux_step_post_configure () {
        cp $TERMUX_PKG_HOSTBUILD_DIR/src/defatom $TERMUX_PKG_BUILDDIR/src/defatom-host
        cp $TERMUX_PKG_HOSTBUILD_DIR/src/mkvmi   $TERMUX_PKG_BUILDDIR/src/mkvmi-host

        #fIXME: where should we put this?
        sudo sh -c "cat <<\EOD > /usr/local/bin/swipl
#!/bin/sh

$TERMUX_PKG_HOSTBUILD_DIR/src/swipl \"\$@\" 
#cd $TERMUX_PKG_HOSTBUILD_DIR/src
EOD"
        sudo chmod a+x /usr/local/bin/swipl
}


                           ########################################
                           #       Put final libraries and        #
                           #   binaries in the appropiate place   #
                           ########################################
#Executed after make install
termux_step_post_make_install () {
        # Put libswipl.so in the directory contained in Termux's 
        # LD_LIBRARY_PATH
        mv $TERMUX_PREFIX/lib/swipl/lib/${TERMUX_ARCH}-linux/libswipl.so $TERMUX_PREFIX/lib/
        cp $TERMUX_PKG_HOSTBUILD_DIR/home/boot${TERMUX_ARCH_BITS}.prc $TERMUX_PREFIX/lib/swipl

        #-------------------------------------------------------

        mv $TERMUX_PREFIX/bin/swipl $TERMUX_PREFIX/bin/swipl-bin
        # Replace swipl binary with a script that sets
        # LD_PRELOAD and TMP
        sh -c "cat <<\EOD > $TERMUX_PREFIX/bin/swipl
#!/bin/sh

export TMP="\$HOME/tmp"
if ! echo "\$LD_PRELOAD" | grep libswipl; then
   export LD_PRELOAD=libswipl.so:libnativehelper.so:\${LD_PRELOAD}
fi
if [ ! -d "\$TMP" ]; then
   mkdir "\$TMP"
fi

exec $TERMUX_PREFIX/bin/swipl-bin \"\$@\" 
EOD"
        chmod a+x $TERMUX_PREFIX/bin/swipl

        #-------------------------------------------------------


        #FIXME: Is there a better way to do this?
        sudo rm /usr/local/bin/swipl 
}
