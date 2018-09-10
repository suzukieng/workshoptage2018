#!/bin/bash

#
# Copyright 4eyes GmbH (https://www.4eyes.ch/) All Rights Reserved.
#

#
# This script builds, deploys or updates the composer network
#

# Grab the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FABRIC_CRYPTO_CONFIG=../fabric/crypto-config

# set all variables in .env file as environmental variables
set -o allexport
source ${DIR}/fabric-network/.env
set +o allexport

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ./composer-network.sh -m build|deploy|update|start|stop|down|recreate|demoSetup"
  echo "  ./composer-network.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'build', 'deploy'"
  echo "      - 'build' - build the network"
  echo "      - 'deploy' - deploy the network"
  echo "      - 'upgrade' - upgrade the network"
  echo "      - 'start' - start composer-cli container"
  echo "      - 'stop' - create composer-cli container"
  echo "      - 'down' - removing container, cards and bna files"
  echo "      - 'recreate' - recreate composer-cli container"
  echo "      - 'recreate' - recreate composer-cli container"
  echo "      - 'demoSetup' - run demo setup"
}

# Connection credentials
function connectionCredentials () {
    rm -f .connection.json

    CA_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/org1.${DOMAIN}/ca/ca.org1.${DOMAIN}-cert.pem)"
    ORDERER_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/ordererOrganizations/${DOMAIN}/orderers/orderer.${DOMAIN}/msp/tlscacerts/tlsca.${DOMAIN}-cert.pem)"
    PEER0_CERT="$(awk '{printf "%s\\n", $0}' ${FABRIC_CRYPTO_CONFIG}/peerOrganizations/org1.${DOMAIN}/peers/peer0.org1.${DOMAIN}/msp/tlscacerts/tlsca.org1.${DOMAIN}-cert.pem)"

cat << EOF > .connection.json
{
  "name": "fabric-network",
  "x-type": "hlfv1",
  "x-commitTimeout": 300,
  "version": "1.0.0",
  "client": {
    "organization": "Org1",
    "connection": {
      "timeout": {
        "peer": {
          "endorser": "300",
          "eventHub": "300",
          "eventReg": "300"
        },
        "orderer": "300"
      }
    }
  },
  "channels": {
    "${CHANNEL_NAME}": {
      "orderers": [
        "orderer.${DOMAIN}"
      ],
      "peers": {
        "peer0.org1.${DOMAIN}": {
          "endorsingPeer": true,
          "chaincodeQuery": true,
          "ledgerQuery": true,
          "eventSource": true
        }
      }
    }
  },
  "organizations": {
    "Org1": {
      "mspid": "Org1MSP",
      "peers": [
        "peer0.org1.${DOMAIN}"
      ],
      "certificateAuthorities": [
        "ca.org1.${DOMAIN}"
      ]
    }
  },
  "orderers": {
    "orderer.${DOMAIN}": {
      "url": "grpcs://orderer.${DOMAIN}:7050",
      "grpcOptions": {
        "ssl-target-name-override": "orderer.${DOMAIN}",
        "grpc.keepalive_time_ms": 600000,
        "grpc.max_send_message_length": 15728640,
        "grpc.max_receive_message_length": 15728640
      },
      "tlsCACerts": {
        "pem": "${ORDERER_CERT}"
      }
    }
  },
  "peers": {
    "peer0.org1.${DOMAIN}": {
      "url": "grpcs://peer0.org1.${DOMAIN}:7051",
      "eventUrl": "grpcs://peer0.org1.${DOMAIN}:7053",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.org1.${DOMAIN}"
      },
      "tlsCACerts": {
        "pem": "${PEER0_CERT}"
      }
    }
  },
  "certificateAuthorities": {
    "ca.org1.${DOMAIN}": {
      "url": "https://ca.org1.${DOMAIN}:7054",
      "caName": "ca.org1.${DOMAIN}",
      "tlsCACerts": {
        "pem": "${CA_CERT}"
      }
    }
  }
}
EOF

}

# create node container and install composer-cli on it
function buildComposer () {
  rm -rf ${DIR}/.composer

  mkdir ${DIR}/.composer

  runComposerContainer

}

# recreate node container and install composer-cli on it
function recreateComposer () {
    runComposerContainer
}


function runComposerContainer() {
    docker stop ${COMPOSER_CONTAINER_NAME} || true && docker rm -f ${COMPOSER_CONTAINER_NAME} || true

    docker run \
      -d \
      -it \
      -e TZ=${TIME_ZONE} \
      -w /home/composer \
      -v ${DIR}:/home/composer/${DOMAIN} \
      -v ${DIR}/.composer:/home/composer/.composer \
      --name ${COMPOSER_CONTAINER_NAME} \
      --network ${FABRIC_DOCKER_NETWORK_NAME} \
      -p 9090:9090 \
      --entrypoint /bin/sh \
      hyperledger/composer-cli:0.19.14
}

# build
function networkBuild () {

    # create node container and install composer-cli on it
    buildComposer

     if [ -d "$FABRIC_CRYPTO_CONFIG" ]
        then
            rm -rf ./fabric-network/crypto-config
            ln -s ../${FABRIC_CRYPTO_CONFIG}/ fabric-network/
        else
            echo "Fabric crypto-config not found! Please run './fabric-network.sh -m build' in fabric directory"
            exit
    fi

    rm -f ./cards/*.card

    connectionCredentials

    rm -f ${CERT_FILE_NAME}
    CERT_PATH=fabric-network/crypto-config/peerOrganizations/org1.${DOMAIN}/users/Admin@org1.${DOMAIN}/msp/signcerts/${CERT_FILE_NAME}
    cp ${CERT_PATH} .

    PRIVATE_KEY_PATH=fabric-network/crypto-config/peerOrganizations/org1.${DOMAIN}/users/Admin@org1.${DOMAIN}/msp/keystore
    PRIVATE_KEY=$(ls ${PRIVATE_KEY_PATH}/*_sk)
    rm -f *_sk
    cp ${PRIVATE_KEY} .
    PRIVATE_KEY=$(ls *_sk)

    # remove card if exists
    if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} > /dev/null; then
        docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME}
        rm -f ./cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}
    fi

    # Create connection profile
    docker exec ${COMPOSER_CONTAINER_NAME} composer card create -p ${DOMAIN}/.connection.json -u ${FABRIC_NETWORK_PEERADMIN} -c "${DOMAIN}/${CERT_FILE_NAME}" -k "${DOMAIN}/${PRIVATE_KEY}" -r PeerAdmin -r ChannelAdmin -f ${DOMAIN}/cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

    # import PeerAdmin card to Composer
    docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ${DOMAIN}/cards/${FABRIC_NETWORK_PEERADMIN_CARD_FILE_NAME}

    rm -rf .connection.json ${CERT_FILE_NAME} ${PRIVATE_KEY}

    echo "Hyperledger Composer PeerAdmin card has been imported"
    # Show imported cards
    docker exec ${COMPOSER_CONTAINER_NAME} composer card list
}

# Get network name
function askNetworkName () {
    read -p "Business network name: " COMPOSER_NETWORK_NAME
    if [ ! -d "$COMPOSER_NETWORK_NAME" ]; then
        echo "Business network not found! Enter Business network name which you defined during building the composer network."
        askNetworkName
    fi
}

function replaceVersionNr () {
    # sed on MacOSX does not support -i flag with a null extension. We will use
    # 't' for our back-up's extension and depete it at the end of the function
    ARCH=`uname -s | grep Darwin`
    if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
    else
        OPTS="-i"
    fi

    # change default version
    sed $OPTS 's/"version": "0.0.'${1}'"/"version": "0.0.'${NETWORK_ARCHIVE_VERSION}'"/g' ${COMPOSER_NETWORK_NAME}/package.json
    # If MacOSX, remove the temporary backup of the docker-compose file
    if [ "$ARCH" == "Darwin" ]; then
        rm -rf ${COMPOSER_NETWORK_NAME}/package.jsont
    fi
}

# deploy
function networkDeploy () {
    askNetworkName

    replaceVersionNr 1

    # Generate a business network archive
    docker exec ${COMPOSER_CONTAINER_NAME} composer archive create -t dir -n ${DOMAIN}/${COMPOSER_NETWORK_NAME} -a ${DOMAIN}/network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # Install the composer network
    docker exec ${COMPOSER_CONTAINER_NAME} composer network install --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --archiveFile ${DOMAIN}/network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # remove card if exists
    if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} > /dev/null; then
        docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
        rm -f ./cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card
    fi

    # Deploy the business network, from COMPOSER_NETWORK_NAME directory
    docker exec ${COMPOSER_CONTAINER_NAME} composer network start --card ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} --networkAdmin ${CA_USER_ENROLLMENT} --networkAdminEnrollSecret ${CA_ENROLLMENT_SECRET} --networkName ${COMPOSER_NETWORK_NAME} --networkVersion 0.0.${NETWORK_ARCHIVE_VERSION} --file ${DOMAIN}/cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card --loglevel ${FABRIC_LOGGING_LEVEL}

    # Import the network administrator identity as a usable business network card
    docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ${DOMAIN}/cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}.card

    echo "Hyperledger Composer admin card has been imported"
    # Show imported cards
    docker exec ${COMPOSER_CONTAINER_NAME} composer card list

    # Check if the business network has been deployed successfully
    docker exec ${COMPOSER_CONTAINER_NAME} composer network ping --card ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}

}

# update
function networkUpgrade () {
    askNetworkName
    replaceVersionNr ${NUMBER_OF_FILES}

    # Generate a business network archive
    docker exec ${COMPOSER_CONTAINER_NAME} composer archive create -t dir -n ${DOMAIN}/${COMPOSER_NETWORK_NAME} -a ${DOMAIN}/network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # network archive created from the previous command
    NETWORK_ARCHIVE=${DOMAIN}/network-archives/${COMPOSER_NETWORK_NAME}@0.0.${NETWORK_ARCHIVE_VERSION}.bna

    # install the new business network
    docker exec ${COMPOSER_CONTAINER_NAME} composer network install -a ${NETWORK_ARCHIVE} -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME}

    # Upgrade to the new business network that was installed
    docker exec ${COMPOSER_CONTAINER_NAME} composer network upgrade -c ${FABRIC_NETWORK_PEERADMIN_CARD_NAME} -n ${COMPOSER_NETWORK_NAME} -V 0.0.${NETWORK_ARCHIVE_VERSION}
}

# start the docker composer-cli container
function start() {
    docker start ${COMPOSER_CONTAINER_NAME}
}

# stop the docker composer-cli container
function stop() {
    docker stop ${COMPOSER_CONTAINER_NAME}
}


# removing container, cards and bna files
function down() {

    askNetworkName

    docker stop ${COMPOSER_CONTAINER_NAME} || true && docker rm -f ${COMPOSER_CONTAINER_NAME} || true

    # remove ledger data
    ARCH=`uname -s | grep Darwin`
    if [ "$ARCH" == "Darwin" ]; then
      rm -rf ${DIR}/.composer
      rm -rf ${DIR}/cards/*.card
      rm -rf ${DIR}/network-archives/*.bna
      rm -rf ${DIR}/${COMPOSER_NETWORK_NAME}/package.json
    else
      sudo rm -rf ${DIR}/.composer
      sudo rm -rf ${DIR}/cards/*.card
      sudo rm -rf ${DIR}/network-archives/*.bna
      sudo rm -rf ${DIR}/${COMPOSER_NETWORK_NAME}/package.json
    fi

cat << EOF > ${COMPOSER_NETWORK_NAME}/package.json
{
  "name": "${COMPOSER_NETWORK_NAME}",
  "version": "0.0.1",
  "description": "Hyperledger Composer Network Definition",
  "scripts": {
    "test": "mocha --recursive"
  },
  "author": "Hyperledger Composer",
  "license": "Apache-2.0",
  "deependencies": {
    "composer-admin": "latest",
    "composer-client": "latest",
    "composer-common": "latest",
    "composer-connector-embedded": "latest",
    "chai": "latest",
    "eslint": "latest",
    "istanbul": "latest",
    "mkdirp": "latest",
    "mocha": "latest"
  }
}
EOF
}

function demoSetup() {
    askNetworkName
    TIMESTAMP=$(date +%s)
    docker exec ${COMPOSER_CONTAINER_NAME} composer transaction submit -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -d '{"$class":"org.collectable.penguin._demoSetup","transactionId":"TRANSACTION_'${TIMESTAMP}'"}'
}

NUMBER_OF_FILES=$(ls network-archives/ | wc -l)
NETWORK_ARCHIVE_VERSION=$(( ${NUMBER_OF_FILES}+1 ))
CERT_FILE_NAME=Admin@org1.${DOMAIN}-cert.pem

# use this file to start cli container
DOCKER_COMPOSE_TEMPLATE=docker/docker-compose-template.yaml

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

# Determine whether building or deploying for announce
if [ "$MODE" == "build" ]; then
  EXPMODE="Building"
  elif [ "$MODE" == "deploy" ]; then
    EXPMODE="Deploying"
  elif [ "$MODE" == "upgrade" ]; then
    EXPMODE="Upgrading"
  elif [ "$MODE" == "start" ]; then
    EXPMODE="Starting composer-cli container"
  elif [ "$MODE" == "recreate" ]; then
    EXPMODE="Recreating composer-cli container"
  elif [ "$MODE" == "stop" ]; then
    EXPMODE="Stopping composer-cli container"
  elif [ "$MODE" == "down" ]; then
    EXPMODE="Removing container, cards and bna files"
  elif [ "$MODE" == "demoSetup" ]; then
    EXPMODE="Running demo setup"
else
  printHelp
  exit 1
fi

# Announce what was requested
echo "${EXPMODE}"

# building or deploying the network
if [ "${MODE}" == "build" ]; then
  networkBuild
  elif [ "${MODE}" == "deploy" ]; then
    networkDeploy
  elif [ "${MODE}" == "upgrade" ]; then
    networkUpgrade
  elif [ "${MODE}" == "start" ]; then
    start
  elif [ "${MODE}" == "stop" ]; then
    stop
  elif [ "${MODE}" == "recreate" ]; then
    recreateComposer
  elif [ "${MODE}" == "down" ]; then
    down
  elif [ "${MODE}" == "demoSetup" ]; then
    demoSetup
else
  printHelp
  exit 1
fi