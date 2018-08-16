#!/bin/bash

#
# Copyright Waleed El Sayed All Rights Reserved.
#
# Adaption from: https://github.com/hyperledger/fabric-samples/blob/release/first-network/scripts/script.sh
#
# This script creates the fabric channel and join the created peers to this channel

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "BuildFabricNetwork"
echo

# set all variables in .env file as environmental variables
set -o allexport
source ./.env
set +o allexport

COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/$DOMAIN/orderers/orderer.$DOMAIN/msp/tlscacerts/tlsca.$DOMAIN-cert.pem

echo "Channel name : "$CHANNEL_NAME

# verify the result of the end-to-end test
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute script ==========="
		echo
   		exit 1
	fi
}

setGlobals () {
    if [ $1 -eq 0 ]; then
        CORE_PEER_ADDRESS=peer0.org1.$DOMAIN:7051
    else
        CORE_PEER_ADDRESS=peer1.org1.$DOMAIN:7051
    fi
	env |grep CORE
}

createChannel() {
	setGlobals 0
	sleep $TIMEOUT

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.$DOMAIN:7050 -c $CHANNEL_NAME -f ./$CHANNEL_ARTIFACTS_PATH/$CHANNEL_FILE_NAME >&log.txt
	else
		peer channel create -o orderer.$DOMAIN:7050 -c $CHANNEL_NAME -f ./$CHANNEL_ARTIFACTS_PATH/$CHANNEL_FILE_NAME --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep $DELAY
		joinWithRetry $1
	else
		COUNTER=1
	fi
  verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in 0 1; do
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep $DELAY
		echo
	done
}

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

echo
echo "========= All GOOD, BuildFabricNetwork execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0