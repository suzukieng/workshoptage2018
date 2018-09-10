#!/bin/bash

#
# Copyright 4eyes GmbH (https://www.4eyes.ch/) All Rights Reserved.
#
# this script configures and creates the rest server and mongoDB containers
#

# Grab the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# set all variables in .env file as environmental variables
set -o allexport
source ${DIR}/.env
set +o allexport


# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  ./rest-server.sh -m build|start|stop|recreate"
  echo "  ./rest-server.sh -h|--help (print this message)"
  echo "    -m <mode> - one of 'build', 'start'"
  echo "      - 'build' - pull the docker images and start the containers"
  echo "      - 'start' - start mongoDB & rest server containers"
  echo "      - 'stop' - stop mongoDB & rest server containers"
  echo "      - 'recreate' - recreate mongoDB & rest server containers"
}

# Get network name
function askNetworkName () {
    read -p "Business network name: " COMPOSER_NETWORK_NAME
    if [ ! -d "../composer/$COMPOSER_NETWORK_NAME" ]; then
        echo "Business network not found! Enter Business network name which you defined during building the composer network."
        askNetworkName
    fi
}

# create rest admin card
function createRestCard() {

    # remove card if exists
    if docker exec ${COMPOSER_CONTAINER_NAME} composer card list -c ${REST_ADMIN}@${COMPOSER_NETWORK_NAME} > /dev/null; then
        docker exec ${COMPOSER_CONTAINER_NAME} composer card delete -c ${REST_ADMIN}@${COMPOSER_NETWORK_NAME}
        rm -f ../composer/cards/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}.card
    fi

    docker exec ${COMPOSER_CONTAINER_NAME} composer participant add -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -d '{"$class":"org.hyperledger.composer.system.NetworkAdmin", "participantId":"'${REST_ADMIN}'"}'
    docker exec ${COMPOSER_CONTAINER_NAME} composer identity issue -c ${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} -f ${DOMAIN}/cards/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}.card -u ${REST_ADMIN} -a "resource:org.hyperledger.composer.system.NetworkAdmin#"${REST_ADMIN}""
    docker exec ${COMPOSER_CONTAINER_NAME} composer card import --file ${DOMAIN}/cards/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}.card
    # Show imported cards
    docker exec ${COMPOSER_CONTAINER_NAME} composer card list
    docker exec ${COMPOSER_CONTAINER_NAME} composer network ping -c ${REST_ADMIN}@${COMPOSER_NETWORK_NAME}

    rm -rf ${DIR}/.composer
    mkdir ${DIR}/.composer
    mkdir ${DIR}/.composer/cards
    mkdir ${DIR}/.composer/cards/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}
    mkdir ${DIR}/.composer/cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
    mkdir ${DIR}/.composer/client-data
    mkdir ${DIR}/.composer/client-data/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}
    mkdir ${DIR}/.composer/client-data/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
    mkdir ${DIR}/.composer/logs

    cp -r ../composer/.composer/cards/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}/. ${DIR}/.composer/cards/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}
    cp -r ../composer/.composer/client-data/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}/. ${DIR}/.composer/client-data/${REST_ADMIN}@${COMPOSER_NETWORK_NAME}

    cp -r ../composer/.composer/cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}/. ${DIR}/.composer/cards/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
    cp -r ../composer/.composer/client-data/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}/. ${DIR}/.composer/client-data/${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME}
}

# Configure and start the docker containers
function build() {

    askNetworkName

    # create rest admin card
    createRestCard

    # remove old containers and images
    docker stop ${MONGO_CONTAINER_NAME} ${REST_CONTAINER_NAME} single-user-rest-server.${DOMAIN} || true && docker rm -f ${MONGO_CONTAINER_NAME} ${REST_CONTAINER_NAME} single-user-rest-server.${DOMAIN} || true && docker rmi -f ${DOMAIN}/rest-server || true

    rm -rf ${DIR}/.mongodb
    mkdir ${DIR}/.mongodb
    mkdir ${DIR}/.mongodb/entrypoint

cat << EOF > ${DIR}/.mongodb/entrypoint/createUser.js
db.createUser(
    {
        user: "${MONGO_ZNUENI_DB_USER}",
        pwd: "${MONGO_ZNUENI_DB_USER_PASSWORD}",
        roles: [
            { role: "readWrite", db: "test" }
        ]
    }
);
EOF

    # Build the extended Docker image by running the following docker build command in the directory containing the file named Dockerfile.
    cd ${DIR}/docker
    docker build -t ${DOMAIN}/rest-server .
    cd ${DIR}

    createContainers

    rm -f ${DIR}/.mongodb/entrypoint/createUser.js
}


function createContainers() {
   # Start an instance of the Docker image for MongoDB named mongo.
    # This MongoDB instance will be used to persist all information regarding authenticated users
    # and their wallets (containing that users business network cards when multiple user mode is enabled) for the REST server.
    docker run \
        -d \
        -e MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME} \
        -e MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD} \
        -e TZ=${TIME_ZONE} \
        -v ${DIR}/.mongodb/data/db:/data/db \
        -v ${DIR}/.mongodb/data/configdb:/data/configdb \
        -v ${DIR}/.mongodb/entrypoint:/docker-entrypoint-initdb.d \
        --name ${MONGO_CONTAINER_NAME} \
        --network ${FABRIC_DOCKER_NETWORK_NAME} \
        -p 27017:27017 \
        mongo

    echo "waiting for mongo database to start ..."
    sleep 20

    # Start a new instance of the extended Docker image for the REST server that created.
    # This REST server will run in single-user mode und used to the create participants and cards.
    docker run \
        -d \
        -e COMPOSER_CARD=${CA_USER_ENROLLMENT}@${COMPOSER_NETWORK_NAME} \
        -e COMPOSER_NAMESPACES=${COMPOSER_NAMESPACES} \
        -e COMPOSER_AUTHENTICATION=false \
        -e COMPOSER_MULTIUSER=false \
        -e COMPOSER_TLS=${COMPOSER_TLS} \
        -e COMPOSER_WEBSOCKETS=${COMPOSER_WEBSOCKETS} \
        -e PORT=3001 \
        -e TZ=${TIME_ZONE} \
        -v ${DIR}/.composer:/home/composer/.composer \
        --name single-user-rest-server.${DOMAIN} \
        --network ${FABRIC_DOCKER_NETWORK_NAME} \
        -p 3001:3001 \
        ${DOMAIN}/rest-server

    # Start a new instance of the extended Docker image for the REST server that created.
    # This REST server will run in multi-user mode und used to the authentication.
    docker run \
        -d \
        -e COMPOSER_CARD=${REST_ADMIN}@${COMPOSER_NETWORK_NAME} \
        -e COMPOSER_NAMESPACES=${COMPOSER_NAMESPACES} \
        -e COMPOSER_AUTHENTICATION=${COMPOSER_AUTHENTICATION} \
        -e COMPOSER_MULTIUSER=${COMPOSER_MULTIUSER} \
        -e COMPOSER_PROVIDERS="${COMPOSER_PROVIDERS}" \
        -e COMPOSER_DATASOURCES="${COMPOSER_DATASOURCES}" \
        -e COMPOSER_TLS=${COMPOSER_TLS} \
        -e COMPOSER_WEBSOCKETS=${COMPOSER_WEBSOCKETS} \
        -e PORT=3000 \
        -e TZ=${TIME_ZONE} \
        -v ${DIR}/.composer:/home/composer/.composer \
        --name ${REST_CONTAINER_NAME} \
        --network ${FABRIC_DOCKER_NETWORK_NAME} \
        -p 3000:3000 \
        ${DOMAIN}/rest-server
}

function recreate() {

    askNetworkName

    docker stop ${MONGO_CONTAINER_NAME} ${REST_CONTAINER_NAME} single-user-rest-server.${DOMAIN} || true && docker rm -f ${MONGO_CONTAINER_NAME} ${REST_CONTAINER_NAME} single-user-rest-server.${DOMAIN} || true

    createContainers

}

# start the docker containers
function start() {
    docker start ${MONGO_CONTAINER_NAME} ${REST_CONTAINER_NAME} single-user-rest-server.${DOMAIN}
}

# stop the docker containers
function stop() {
    docker stop ${MONGO_CONTAINER_NAME} ${REST_CONTAINER_NAME} single-user-rest-server.${DOMAIN}
}


REST_CONTAINER_NAME=multi-user-rest-server.${DOMAIN}
MONGO_INITDB_ROOT_USERNAME=root
MONGO_INITDB_ROOT_PASSWORD=UserPassword

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

# Determine whether building, starting or stopping for announce
if [ "$MODE" == "build" ]; then
  EXPMODE="Building"
  elif [ "$MODE" == "start" ]; then
    EXPMODE="Starting"
  elif [ "$MODE" == "stop" ]; then
    EXPMODE="Stopping"
  elif [ "$MODE" == "recreate" ]; then
    EXPMODE="Recreating"
else
  printHelp
  exit 1
fi

# Announce what was requested
echo "${EXPMODE}"

# building, starting or stopping the network
if [ "${MODE}" == "build" ]; then
  build
  elif [ "${MODE}" == "start" ]; then
    start
  elif [ "${MODE}" == "stop" ]; then
    stop
  elif [ "${MODE}" == "recreate" ]; then
    recreate
else
  printHelp
  exit 1
fi