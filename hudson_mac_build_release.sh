#!/bin/sh

if [ "$WORKSPACE" == "" ]; then
    echo "ERROR: Missing WORKSPACE environment variable."
    exit 1
fi

###############################################################################
# remove old and create fresh build directories
rm -rf sgBuild
rm -rf fgBuild
mkdir -p sgBuild
mkdir -p fgBuild
mkdir -p output
rm -rf output/*
rm -rf $WORKSPACE/dist/include/simgear $WORKSPACE/dist/libSim* $WORKSPACE/dist/libsg*.a

###############################################################################
echo "Starting on SimGear"
pushd sgBuild
cmake -DCMAKE_INSTALL_PREFIX:PATH=$WORKSPACE/dist -G Xcode ../simgear

# compile
xcodebuild -configuration Release -target install  build

if [ $? -ne '0' ]; then
    echo "make simgear failed"
    exit 1
fi

popd

################################################################################
echo "Starting on FlightGear"
pushd fgBuild
cmake -DCMAKE_INSTALL_PREFIX:PATH=$WORKSPACE/dist -G Xcode ../flightgear

xcodebuild -configuration Release -target install  build

if [ $? -ne '0' ]; then
    echo "make flightgear failed"
    exit 1
fi

popd

chmod +x $WORKSPACE/dist/bin/osgversion

################################################################################
echo "Building Macflightgear launcher"

#OSX_TARGET="10.6"
# JMT - disabling setting the sysroot since it's breaking things on 
# current build slave. Sinc ethe slave runs 10.6 natively, we don't 
# actually need to set these. Real solution would be to use a proper
# build system for the Mac-launcher of course.
# -mmacosx-version-min=$OSX_TARGET -isysroot $SDK_PATH

pushd maclauncher/FlightGearOSX

# compile the stub executable
gcc -o FlightGear main.m \
    -framework Cocoa -framework RubyCocoa -framework Foundation -framework AppKit

popd

################################################################################
echo "Syncing base packages files from sphere.telascience.org"
rsync -avz --filter 'merge base-package.rules' \
 -e ssh jturner@sphere.telascience.org:/home/jturner/fgdata .

# run the unlock script now - we need to do this right before code-signing,
# or the keychain may automatically re-lock after some period of time
unlock-keychain.sh

echo "Running package script"
./hudson_mac_package_release.rb
