#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    echo $1
    exit 1
  fi
}

if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

if [ -z "$WORKSPACE" ]
then
  echo WORKSPACE not specified
  exit 1
fi

if [ -z "$CLEAN_TYPE" ]
then
  echo CLEAN_TYPE not specified
  exit 1
fi

if [ -z "$REPO_BRANCH" ]
then
  echo REPO_BRANCH not specified
  exit 1
fi

# colorization fix in Jenkins
export CL_PFX="\"\033[34m\""
export CL_INS="\"\033[32m\""
export CL_RST="\"\033[0m\""

cd $WORKSPACE
rm -rf archive
mkdir -p archive
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER
export ROOTFS_PATH="ramdisk-samsung"
export KBUILD_BUILD_VERSION="NEAK-SGS3-$(date +%d%m%Y)"
export TOOLCHAIN="$WORKSPACE/arm-eabi-4.4.3/bin/arm-eabi-"

if [ -f ~/.jenkins_profile ]
then
  . ~/.jenkins_profile
fi

if [ ! -d arm-eabi-4.4.3 ]
then
  curl -O http://www.mimeko.it/neak-kernel/arm-eabi-4.4.3.tar
  tar xvf arm-eabi-4.4.3.tar
fi

if [ ! -d galaxys3 ]
then
  git clone git://github.com/simone201/neak-gs3-kernel.git galaxys3
fi

cd galaxys3
git checkout $REPO_BRANCH
git pull

make CROSS_COMPILE=$TOOLCHAIN -j8 $CLEAN_TYPE
make CROSS_COMPILE=$TOOLCHAIN -j8 neak_defconfig
make CROSS_COMPILE=$TOOLCHAIN -j8

rm -f releasetools/tar/$KBUILD_BUILD_VERSION.tar
rm -f releasetools/zip/$KBUILD_BUILD_VERSION.zip
cp -f arch/arm/boot/zImage .

find -name '*.ko' -exec cp -av {} $ROOTFS_PATH/lib/modules/ \;
unzip proprietary-modules/proprietary-modules.zip -d $ROOTFS_PATH/lib/modules

cd $ROOTFS_PATH
find . | cpio -o -H newc | gzip > ../ramdisk.cpio.gz
cd ..

./mkbootimg --kernel zImage --ramdisk ramdisk.cpio.gz --board smdk4x12 --base 0x10000000 --pagesize 2048 --ramdiskaddr 0x11000000 -o boot.img
cp boot.img releasetools/zip/
cp boot.img releasetools/tar/

# Creating flashable zip and tar
cd releasetools/zip
zip -r $KBUILD_BUILD_VERSION.zip *
cd ..
cd tar
tar cvf $KBUILD_BUILD_VERSION.tar boot.img && ls -lh $KBUILD_BUILD_VERSION.tar
cd ../..

# Cleanup
rm releasetools/zip/boot.img
rm releasetools/tar/boot.img
rm zImage

check_result "Build failed."

cp releasetools/zip/*.zip $WORKSPACE/archive
cp releasetools/tar/*.tar $WORKSPACE/archive

# chmod the files in case UMASK blocks permissions
chmod -R ugo+r $WORKSPACE/archive
