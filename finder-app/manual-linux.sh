#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld	
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
	mkdir -p ${OUTDIR}
else
	OUTDIR=$1
	mkdir -p ${OUTDIR}
	echo "Using passed directory ${OUTDIR} for output"
fi

if [ ! -d "$OUTDIR" ];
then
	exit 1
fi 

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}
    
    # Setting up Cross compiler
    cp ~/Desktop/Linux_Coursera/Git_Assignment1/assignment-3-AbhinitShetty/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz $(pwd) 		 
    mkdir -p install-lnx
    tar x -C install-lnx -f gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz
    export PATH=$PATH:$(pwd)/install-lnx/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin
    
    # TODO: Add your kernel build steps here
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- mrproper	# Cleans up all existing .config files
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- defconfig	# Builds .config file
    make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- all	# Builds Kernel Image - vmlinux and system.map
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- dtbs		# Configure Device Tree
	
fi

echo "Adding the Image in outdir"
ln -sf ${OUTDIR}/linux-stable/arch/arm64/boot/Image ${OUTDIR}/Image #Create symbolic link to find Image file

#***********************************************************************************************************************************************************
# CREATING ROOTFILE SYSTEM

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir rootfs
cd "$OUTDIR/rootfs"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/sbin usr/lib
mkdir -p var/log


#***********************************************************************************************************************************************************
## BUSYBOX CONFIGURATION 

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO : Configure busybox
    
else
    cd busybox
fi

# TODO: Make and install busybox
make distclean		# Deletes all files that .config creates 
make defconfig		# Contains all of the Linux kconfig settings required to properly configure the kernel build for that platform.
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs  ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install	# CHECK THIS !!!!!

#***********************************************************************************************************************************************************
## ADDING FILES TO DESIRED LOCATIONS 

cd "${OUTDIR}/rootfs"
echo "Library dependencies"
# TODO: Add library dependencies to rootfs
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

TOOLCHAIN_ARM="$(dirname $(which ${CROSS_COMPILE}gcc))/../"
TOOLCHAIN_LIBC="${TOOLCHAIN_ARM}/aarch64-none-linux-gnu/libc/"
cp $TOOLCHAIN_LIBC/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
cp $TOOLCHAIN_LIBC/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/
cp $TOOLCHAIN_LIBC/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/
cp $TOOLCHAIN_LIBC/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/

# TODO: Make device nodes
# mknod - Create a device file 
# option 'c' - character device 
# option '1' - it identifies the driver for the kernel to use (major)
# option '3' - it is passed to the driver for its internal usage (minor)
#sudo mknod -m 666 /dev/null c 1 3	# to add permissions to all users, we specify -m option
#sudo mknod -m 600 /dev/console c 5 1


# TODO: Clean and build the writer utility
MY_DIR=~/Desktop/Linux_Coursera/Git_Assignment1/assignment-2-AbhinitShetty
#cp ${MY_DIR}/finder-app/writer ${OUTDIR}/rootfs/home/



# TODO: Copy the finder related scripts and executables to the /home directory on the target rootfs
#cd "$MY_DIR"/finder-app/
#cp ./*.sh "${OUTDIR}/rootfs/home/"
#cp ${MY_DIR}/finder-app/finder.sh ${OUTDIR}/rootfs/home/
#cp ${MY_DIR}/finder-app/finder-test.sh ${OUTDIR}/rootfs/home/
#cp ${MY_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/home/
#cp ${MY_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/
#cp ${MY_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/
#cp ${MY_DIR}/conf/username.txt ${OUTDIR}/rootfs/

cd "$MY_DIR"/

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp -Lr conf/assignment.txt "${OUTDIR}/rootfs/home/"
cp -Lr conf/username.txt "${OUTDIR}/rootfs/home/"
cp -Lr conf/assignment.txt "${OUTDIR}/rootfs/"
cp -Lr conf/username.txt "${OUTDIR}/rootfs/"
cd finder-app/
make clean
make writer
cp ./*.sh "${OUTDIR}/rootfs/home/"
#cp writer.out "${OUTDIR}/rootfs/home/"
cp *.* "${OUTDIR}/rootfs/home/"

cp ~/Desktop/Linux_Coursera/Git_Assignment1/assignment-3-AbhinitShetty/finder-app/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# TODO: Chown the root directory
sudo chown -R root:root "${OUTDIR}/rootfs" #Change owner command - Changes ownership (user and group) to root

# TODO: Create initramfs.cpio.gz
cd "$OUTDIR/rootfs"
find . | cpio -H newc -ov --owner root:root > $OUTDIR/initramfs.cpio	# Find everything in my rootfile sys and create a cpio file an owner of root 
gzip -f $OUTDIR/initramfs.cpio	#using gzip to compress into a .gz file 


