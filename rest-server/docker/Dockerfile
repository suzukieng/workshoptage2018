FROM hyperledger/composer-rest-server:0.19.14
RUN npm install --production loopback-connector-mongodb passport-github && \
    npm cache clean --force && \
    ln -s node_modules .node_modules \