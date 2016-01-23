#!/bin/sh

pushd ../

IS_SIMULATOR=1

#NAME='iPhone 4s'
#NAME='iPhone 5'
#NAME='iPhone 5s'
NAME="iPhone 6"
#NAME='iPhone 6 Plus'
#NAME='iPad 2'
#NAME='iPad Air'
#NAME='iPad Retina'

DEVICE_ID=0

if [ "$IS_SIMULATOR" -ne 0 ]; then
	#DEST="'platform=iOS Simulator,name=$NAME,OS=latest'"
	DEST="platform=iOS Simulator,name=$NAME,OS=latest"
	SDK='iphonesimulator9.2'
else
	DEST='platform=iOS,name='$NAME',id='$DEVICE_ID
	SDK='iphoneos8.1'
fi

#eval "xcodebuild \
#	-destination $DEST \
#	-configuration debug \
#	-sdk $SDK build"

xcodebuild \
	-destination "$DEST" \
	-configuration debug \
	-sdk $SDK \
	build

popd
