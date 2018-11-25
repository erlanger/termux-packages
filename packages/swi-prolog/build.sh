
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
TERMUX_PKG_HOMEPAGE=https://swi-prolog.org/
TERMUX_PKG_DESCRIPTION="Most popular and complete prolog implementation"

if [ x${SWIPL_SRC=} = x"master" ]  || \
   [ x${SWIPL_SRC=} = x"local" ]; then        #use master branch
   _CACHED_SRC_DIR="${TERMUX_PKG_CACHEDIR}/swi-prolog.$SWIPL_SRC"
   TERMUX_PKG_VERSION=`clone_with_git`
   TERMUX_PKG_EXTRA_CONFIGURE_ARGS="-DINSTALL_TESTS=ON -DBUILD_TESTING=ON "
else                                           #use latest release (manual)
   TERMUX_PKG_VERSION=7.7.22
   TERMUX_PKG_REVISION=1
   TERMUX_PKG_SHA256="55096d6bc1d70463b3cf1148e43e8953733ab30ca06ba3f467b562762ed4cb4c"
   TERMUX_PKG_SRCURL=http://www.swi-prolog.org/download/devel/src/swipl-${TERMUX_PKG_VERSION}.tar.gz
fi

TERMUX_PKG_DEPENDS="readline, libgmp, libcrypt, pcre, libarchive, libyaml, ossp-uuid, libjpeg-turbo"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
$TERMUX_PKG_EXTRA_CONFIGURE_ARGS
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
        mkdir -p ${TERMUX_PREFIX}/lib/swipl/tmp

        #For development
        if [ x${SWIPL_SRC=} = x"master" ]  || \
           [ x${SWIPL_SRC=} = x"local" ]; then        #use local files
           SWIPL_HOME=$TERMUX_PREFIX/lib/swipl
           #cp -ar $_CACHED_SRC_DIR/packages $SWIPL_HOME/
           _mk_test_script

        fi

}


_mk_test_script() {
   SWIPL_BIN=$TERMUX_PREFIX/bin/swipl-bin
   sh -c "cat <<\EOD > $TERMUX_PREFIX/bin/swipl-test
#!/bin/sh

   SWIPL_HOME=$SWIPL_HOME 
   cd $SWIPL_HOME/test

   if [ -z \"\$1\" ]; then
      swipl -f none test.pl --packages
   else
      swipl -f none test.pl \"\$@\"
   fi

EOD"
   chmod a+x $TERMUX_PREFIX/bin/swipl-test
}

#_mk_test_script() {
#   SWIPL_BIN=$TERMUX_PREFIX/bin/swipl-bin
#   sh -c "cat <<\EOD > $TERMUX_PREFIX/bin/swipl-test
##!/bin/sh

#   SWIPL_HOME=$SWIPL_HOME 
#   cd $SWIPL_HOME/packages

#   test_pkg() {
#      local p="\$1"
#      local pname=\$(echo "\${p}" | tr '[:upper:]' '[:lower:]')
#      local tname=test_\${pname}
#      local fname=$SWIPL_HOME/packages/\${p}/\${tname}.pl
#      if [ -d \$p ] && [ -f \${fname} ]; then
#         cd \${p}
#         echo \"------- testing package: \${pname}\"
#         plibrary=\${plibrary}:\${SWIPL_HOME}/\${pname}
#         swipl -p library=\${plibrary} \
#               -f none                \
#               -s \${fname}           \
#               -g "\${tname}"         \
#               -t halt
#         cd - > /dev/null
#      fi
#   }

#   if [ -z "\$1" ]; then
#      for p in *; do
#         test_pkg \${p}
#      done
#   else
#      if [ -d "\$1" ]; then
#         test_pkg \$1
#      else
#         echo \"Package \$1 does not exist.\"
#         exit 1
#      fi
#   fi

#EOD"
#   chmod a+x $TERMUX_PREFIX/bin/swipl-test
#}

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
