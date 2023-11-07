#!/usr/bin/zsh
MONGODB_VERSION="4"
alias mongodump="docker run --rm -i --network host --entrypoint mongodump mongo:${MONGODB_VERSION}"
alias mongorestore="docker run --rm -i --network host --entrypoint mongorestore mongo:${MONGODB_VERSION}"
alias mongoexport="docker run --rm -i --network host --entrypoint mongoexport mongo:${MONGODB_VERSION}"

# Backup an entire database:
# mongodump --host [host] --db [db] --archive | mongorestore --host localhost --archive
# Collection, just add --collection
