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
- $ ./network.sh -m build

now if you run 'docker ps' you wil see that all containers are running

### Start or stop the network (not for first time setup)
- $ cd fabric
- $ ./network.sh -m start
- $ ./network.sh -m stop

### Remove the network including the data 
- $ cd fabric
- $ ./network.sh -m down

### Recreate the containers without losing the data (not for first time setup)
- $  cd fabric/
- $ ./network.sh -m recreate