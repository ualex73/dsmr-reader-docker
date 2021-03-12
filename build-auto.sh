#!/bin/bash

FILE="/docker/appdaemon/conf/apps/data/dsmrversion.txt"

# Check if a file exist, ifso - do some magic
if [ -f "$FILE" ]; then

  VERSION=`cat $FILE | grep "^new: " | cut -d " " -f 2`

  if [ ! -z "$VERSION" ]; then

    docker rmi python:alpine
    docker rmi arm32v6/python:alpine
    docker rmi arm64v8/python:alpine

    # Check if version already exista, then skip
    if [ ! -f "$FILE.$VERSION" ]; then
      mv $FILE $FILE.$VERSION
      echo "================================================"
      echo "==="`date '+%Y%m%d-%H%M%S'`"==="
      echo "================================================"
      cd /docker/github/dsmr-reader-docker
      ./build.sh $VERSION
      echo "=== END ==="
    else
      mv $FILE $FILE.$VERSION.`date '+%Y%m%d-%H%M%S'`
      echo "================================================"
      echo "==="`date '+%Y%m%d-%H%M%S'`"==="
      echo "================================================"
      echo "DUPLICATE $VERSION FOUND?"
      echo "=== END ==="
    fi
  fi 

fi

exit 0
