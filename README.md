# 4eyes GmbH

These instructions are only for MacOSX and Linux (Debian or Ubuntu).

## Prerequisites
### for the backend
- cURL
- git
- Docker & Docker Compose

### for the frontend
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

### Deploy the network and create the cards (Business network name is 'composer-network') (for first time setup)
- $ cd composer/
- $ ./composer.sh -m deploy     # business network name is 'composer-network' & it will take a while ;)

### If you want to update your business network (not for first time setup)
- $ cd composer/
- $ ./composer.sh -m upgrade

### Start or stop composer-cli container (not for first time setup)
- $ cd composer/
- $ ./composer.sh -m start
- $ ./composer.sh -m stop

### Recreate the container without losing the data (not for first time setup)
- $ cd composer/
- $ ./composer.sh -m recreate
