#!/bin/bash

VERSION=$1
DEV=$2

IMAGE="ualex73/dsmr-reader-docker"
ARCHLIST="amd64 arm32v6 arm32v7 arm64v8"

for ARCH in $ARCHLIST
do
  # Copy from main file
  cp Dockerfile Dockerfile.$ARCH

  # Append ARM architecture in from of none-AMD64
  echo $ARCH | grep "^arm" >/dev/null
  if [ $? -eq 0 ]; then
    #if [ "$ARCH" == "arm32v6" ] || [ "$ARCH" == "arm32v7" ]; then
    #  sed -i "s/FROM python:alpine/FROM $ARCH\/python:alpine3.12/" Dockerfile.$ARCH
    #else
    #  sed -i "s/FROM python:alpine/FROM $ARCH\/python:alpine/" Dockerfile.$ARCH
    #fi

    sed -i "s/FROM python:alpine/FROM $ARCH\/python:alpine/" Dockerfile.$ARCH

    # Figure out the ARM platform type
    SARCH=`echo $ARCH | cut -c 1-5 | sed "s/arm32/arm/"`
    PLATFORM="--platform linux/$SARCH"
  else
    PLATFORM=""
  fi

  # Replace version in Dockerfile
  if [ ! -z "$VERSION" ]; then
    sed -i "s/^ENV DSMR_READER_VERSION v.*/ENV DSMR_READER_VERSION v$VERSION/" Dockerfile.${ARCH}
  fi

  # Lets remove python:alpine from the repo, then we always use the latest from hub.docker.com
  #if [ "$ARCH" != "arm32v6" ] && [ "$ARCH" != "arm32v7" ]; then
  #  echo "INFO: Removing parent docker image Dockerfile.${ARCH}"
  #  docker rmi `cat Dockerfile.${ARCH} | head -1 | grep "^FROM " | cut -d " " -f 2`
  #fi

  echo ""
  echo "========================================================================================"
  echo "=== Docker build * $ARCH * ==="
  echo "=== docker build $PLATFORM -f Dockerfile.${ARCH} -t $IMAGE:${ARCH} ."
  echo "========================================================================================"
  if [ ! -z "$DEV" ]; then
    docker build $PLATFORM -f Dockerfile.${ARCH} -t $IMAGE:${ARCH}-dev .
  else
    docker build $PLATFORM -f Dockerfile.${ARCH} -t $IMAGE:${ARCH} .
  fi

  # Tag it with a version
  if [ ! -z "$VERSION" ] && [ -z "$DEV" ]; then
    docker tag $IMAGE:${ARCH} $IMAGE:${ARCH}-${VERSION}
  fi

done

if [ ! -z "$VERSION" ] && [ -z "$DEV" ]; then
  docker tag $IMAGE:amd64 $IMAGE:$VERSION
  echo "=== Push * $ARCH * to hub.docker.com ==="

  for ARCH in $ARCHLIST
  do
    echo ""
    echo "=== Docker push: $IMAGE:$ARCH ==="
    docker push $IMAGE:$ARCH
    echo "=== Docker push: $IMAGE:$ARCH-$VERSION ==="
    docker push $IMAGE:$ARCH-$VERSION
  done

  # Do the multi-arch push of latest
  ./manifest-tool-linux-amd64 push from-spec multi-arch-latest.yaml

  # Do the multi-arch push of <version>
  ./manifest-tool-linux-amd64 push from-spec multi-arch-version.yaml
fi

# don't care about ARM and AMD tags in my local repo ;)
for ARCH in $ARCHLIST
do
  echo "=== Deleting * $ARCH * from local repo ==="
  #docker rmi $IMAGE:$ARCH $IMAGE:$ARCH-$VERSION
done

# End
