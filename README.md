# 4eyes GmbH

These instructions are only for MacOSX and Linux (Debian or Ubuntu).

## Prerequisites
### for the backend
- cURL
- git
- Docker & Docker Compose
- node & npm

## Fabric
- $ cd fabric

if you want to change the domain name of your organisation, you can change the DOMAIN variable value in .env file.
if you want to change the logging level of the peers you can change the FABRIC_LOGGING_LEVEL variable value from INFO to DEBUG in .env file.

### download fabric binaries & docker images
- $ ./scripts/download.sh -m binaries
- $ ./scripts/download.sh -m images

### Build the fabric network (for first time setup)
- $ ./fabric.sh -m build

now if you run 'docker ps' you wil see that all containers are running

### Start or stop the network (not for first time setup)
- $ cd fabric
- $ ./fabric.sh -m start
- $ ./fabric.sh -m stop

### Remove the network including the data 
- $ cd fabric
- $ ./fabric.sh -m down

### Recreate the containers without losing the data (not for first time setup)
- $  cd fabric/
- $ ./fabric.sh -m recreate

## Composer

### Install Composer (for first time setup)
- $ cd composer/
- $ ./composer.sh -m build

### Deploy the network and create the cards (Business network name is 'penguin') (for first time setup)
- $ cd composer/
- $ ./composer.sh -m deploy     # business network name is 'penguin' & it will take a while ;)

### If you want to update your business network (not for first time setup)
- $ cd composer/
- $ ./composer.sh -m upgrade    # business network name is 'penguin'

### Start or stop composer-cli container (not for first time setup)
- $ cd composer/
- $ ./composer.sh -m start
- $ ./composer.sh -m stop

### Recreate the container without losing the data (not for first time setup)
- $ cd composer/
- $ ./composer.sh -m recreate

## Rest Server & mongo containers (Business network name is 'penguin') (for first time setup)

Before you start the rest server, you must follow this tutorial (beginning from: Configuring the REST server to use an authentication strategy) 
https://hyperledger.github.io/composer/latest/integrating/enabling-rest-authentication

add the clientID and clientSecret values to COMPOSER_PROVIDERS object in fabric/.env

### Create rest & mongo containers
- $ cd rest-server/
- $ ./rest-server.sh -m build   # business network name is 'penguin'

### Start or stop the rest Server & mongo containers (not for first time setup) (not for first time setup)
- $ cd rest-server/
- $ ./rest-server.sh -m start
- $ ./rest-server.sh -m stop

### Recreate the containers without losing the data (not for first time setup)
- $ cd rest-server/
- $ ./rest-server.sh -m recreate

## Angular
- $ cd angular/
- $ npm install
- $ ng start
- Open http://localhost:4200/ on your browser