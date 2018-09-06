#!/bin/bash -eu

#
# Copyright 4eyes GmbH (https://www.4eyes.ch/) All Rights Reserved.
#
# Adaption from: https://raw.githubusercontent.com/hyperledger/fabric/master/scripts/bootstrap.sh
#
# This script downloads platform binaries and pulls docker images from the Dockerhub hyperledger repositories

# set all variables in .env file as environmental variables
set -o allexport
source ./.env
set +o allexport

export ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
#Set MARCH variable i.e ppc64le,s390x,x86_64,i386
MARCH=`uname -m`

FABRIC_TAG="${MARCH}-${FABRIC_VERSION}"
THIRDPARTY_TAG="$MARCH-$FABRIC_THIRDPARTY_IMAGE_VERSION"

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ./download.sh -m binaries|images"
  echo "  ./download.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'build', 'start', 'stop', 'down' or 'generate'"
  echo "      - 'binaries' - build the network: generate required certificates and genesis block & create all containers needed for the network"
  echo "      - 'images' - remove the network containers"

}

dockerFabricPull() {
  local FABRIC_TAG=$1
  for IMAGES in peer ccenv orderer ca; do
      echo "==> FABRIC IMAGE: $IMAGES"
      echo
      docker pull hyperledger/fabric-$IMAGES:$FABRIC_TAG
      docker tag hyperledger/fabric-$IMAGES:$FABRIC_TAG hyperledger/fabric-$IMAGES
  done
}

dockerThirdPartyImagesPull() {
  local THIRDPARTY_TAG=$1
  for IMAGES in couchdb; do
      echo "==> THIRDPARTY DOCKER IMAGE: $IMAGES"
      echo
      docker pull hyperledger/fabric-$IMAGES:$THIRDPARTY_TAG
      docker tag hyperledger/fabric-$IMAGES:$THIRDPARTY_TAG hyperledger/fabric-$IMAGES
  done
}

binariesInstall() {
  rm -rf ${FABRIC_BINARIES_DIRECTORY}
  mkdir ${FABRIC_BINARIES_DIRECTORY}
  echo "===> Downloading version ${FABRIC_TAG} platform specific fabric binaries"
  curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/${ARCH}-${FABRIC_VERSION}/hyperledger-fabric-${ARCH}-${FABRIC_VERSION}.tar.gz | tar xz -C ${FABRIC_BINARIES_DIRECTORY}

  echo "===> Downloading version ${FABRIC_TAG} platform specific fabric-ca-client binary"
  curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/${ARCH}-${FABRIC_VERSION}/hyperledger-fabric-ca-${ARCH}-${FABRIC_VERSION}.tar.gz | tar xz -C ${FABRIC_BINARIES_DIRECTORY}
}

# Parse commandline args
while getopts "h?m:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    m)  MODE=$OPTARG
    ;;
  esac
done

# Determine whether downloading binaries or docker images
if [ "$MODE" == "binaries" ]; then
  EXPMODE="Installing Hyperledger Fabric binaries"
  elif [ "$MODE" == "images" ]; then
  EXPMODE="Pulling fabric Images"
else
  printHelp
  exit 1
fi

# Announce what was requested
echo ${EXPMODE}

if [ "${MODE}" == "binaries" ]; then
  binariesInstall
  elif [ "${MODE}" == "images" ]; then
    echo
    echo "===> Pulling fabric Images"
    dockerFabricPull ${FABRIC_TAG}
    echo
    echo "===> Pulling thirdparty docker images"
    dockerThirdPartyImagesPull ${THIRDPARTY_TAG}
    echo
    echo "===> List out hyperledger docker images"
    docker images | grep hyperledger*
else
  printHelp
  exit 1
fi