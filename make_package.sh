#!/bin/bash
################################################################################
# Copyright (c) 2022 ModalAI, Inc. All rights reserved.
#
# Semi-universal script for making a deb and ipk package. This is shared
# between the vast majority of VOXL-SDK packages
#
# Add the 'timestamp' argument to add a date-timestamp suffix to the deb package
# version. This is used by CI for making nightly and development builds.
#
# author: james@modalai.com
################################################################################

set -e # exit on error to prevent bad ipk from being generated

################################################################################
# Check arguments
################################################################################

USETIMESTAMP=false
MAKE_DEB=false
MAKE_IPK=false

print_usage(){
	echo ""
	echo " Package the current project into a deb or ipk package."
	echo " You must run build.sh first to build the binaries"
	echo ""
	echo " Usage:"
	echo ""
	echo "  ./make_package.sh ipk"
	echo "        Build an IPK package for 820"
	echo ""
	echo "  ./make_package.sh deb"
	echo "        Build a DEB package for 865"
	echo ""
	echo "  ./make_package.sh 865 timestamp"
	echo "        Build a DEB package with the current timestamp as a"
	echo "        suffix in both the package name and deb filename."
	echo "        This is used by CI for development packages."
	echo ""
	echo ""
}

process_argument () {

	if [ "$#" -ne 1 ]; then
		echo "ERROR process_argument expected 1 argument"
		exit 1
	fi

	## convert argument to lower case for robustness
	arg=$(echo "$1" | tr '[:upper:]' '[:lower:]')
	case ${arg} in
		"")
			#echo "Making Normal Package"
			;;
		"-t"|"timestamp"|"--timestamp")
			echo "using timestamp suffix"
			USETIMESTAMP=true
			;;
		"-d"|"deb"|"debian"|"--deb"|"--debian")
			echo "using timestamp suffix"
			MAKE_DEB=true
			;;
		"-i"|"ipk"|"opkg"|"--ipk"|"--opkg")
			echo "using timestamp suffix"
			MAKE_IPK=true
			;;
		*)
			echo "invalid option"
			print_usage
			exit 1
	esac
}


## parse all arguments or run wizard
for var in "$@"
do
	process_argument $var
done


if [ $MAKE_DEB == false ] && [ $MAKE_IPK == false ]; then
	echo "please specify \"deb\" or \"ipk\" argument to specify what package to build"
	print_usage
	exit 1
fi

################################################################################
# variables
################################################################################
VERSION=$(cat pkg/control/control | grep "Version" | cut -d' ' -f 2)
PACKAGE=$(cat pkg/control/control | grep "Package" | cut -d' ' -f 2)
IPK_NAME=${PACKAGE}_${VERSION}.ipk
DEB_NAME=${PACKAGE}_${VERSION}.deb

DATA_DIR=pkg/data
CONTROL_DIR=pkg/control
IPK_DIR=pkg/IPK
DEB_DIR=pkg/DEB

echo "Package Name: " $PACKAGE
echo "version Number: " $VERSION

################################################################################
# start with a little cleanup to remove old files
################################################################################
# remove data directory where 'make install' installed to
sudo rm -rf $DATA_DIR
mkdir $DATA_DIR

# remove ipk and deb packaging folders
rm -rf $IPK_DIR
rm -rf $DEB_DIR

# remove old ipk and deb packages
rm -f *.ipk
rm -f *.deb

################################################################################
## copy useful files into data directory
################################################################################

mkdir -p $DATA_DIR

# ros binaries go into normal /opt/ros/indigo place
mkdir -p $DATA_DIR/opt/ros/indigo/
cp -r catkin_ws/install/lib/  $DATA_DIR/opt/ros/indigo/
cp -r catkin_ws/install/share/  $DATA_DIR/opt/ros/indigo/

################################################################################
# make an IPK
################################################################################

if $MAKE_IPK; then
	echo "starting building IPK package"

	## make a folder dedicated to IPK building and make the required version file
	mkdir $IPK_DIR
	echo "2.0" > $IPK_DIR/debian-binary

	## add tar archives of data and control for the IPK package
	cd $CONTROL_DIR/
	tar --create --gzip -f ../../$IPK_DIR/control.tar.gz *
	cd ../../
	cd $DATA_DIR/
	tar --create --gzip -f ../../$IPK_DIR/data.tar.gz *
	cd ../../

	## update version with timestamp if enabled
	if $USETIMESTAMP; then
		dts=$(date +"%Y%m%d%H%M")
		VERSION="${VERSION}_${dts}"
		IPK_NAME=${PACKAGE}_${VERSION}.ipk
		echo "new version with timestamp: $VERSION"
	fi

	## use ar to make the final .ipk and place it in the repository root
	ar -r $IPK_NAME $IPK_DIR/control.tar.gz $IPK_DIR/data.tar.gz $IPK_DIR/debian-binary
fi

################################################################################
# make a DEB package
################################################################################

if $MAKE_DEB; then
	echo "starting building Debian Package"

	## make a folder dedicated to IPK building and copy the requires debian-binary file in
	mkdir $DEB_DIR

	## copy the control stuff in
	cp -rf $CONTROL_DIR/ $DEB_DIR/DEBIAN
	cp -rf $DATA_DIR/*   $DEB_DIR

	## update version with timestamp if enabled
	if $USETIMESTAMP; then
		dts=$(date +"%Y%m%d%H%M")
		sed -E -i "s/Version.*/&-$dts/" $DEB_DIR/DEBIAN/control
		VERSION="${VERSION}-${dts}"
		DEB_NAME=${PACKAGE}_${VERSION}.deb
		echo "new version with timestamp: $VERSION"
	fi


	dpkg-deb --build ${DEB_DIR} ${DEB_NAME}
fi

echo "DONE"