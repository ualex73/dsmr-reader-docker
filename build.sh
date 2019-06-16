#!/bin/bash

VERSION=$1

for ARCH in amd64  arm32v6 arm64v8
do
  docker build -f Dockerfile.${ARCH} -t ualex73/dsmr-reader-docker:${ARCH} .

  # Tag it with a version
  if [ ! -z "$VERSION" ]; then
    docker tag ualex73/dsmr-reader-docker:${ARCH} ualex73/dsmr-reader-docker:${ARCH}-${VERSION}
  fi
done

if [ ! -z "$VERSION" ]; then
  docker tag ualex73/dsmr-reader-docker:amd64 ualex73/dsmr-reader-docker:latest
  docker tag ualex73/dsmr-reader-docker:amd64 ualex73/dsmr-reader-docker:$VERSION
  echo "=== Push to hub.docker.com ==="
  echo "docker push ualex73/dsmr-reader-docker:arm32v6;docker push ualex73/dsmr-reader-docker:arm64v8;docker push ualex73/dsmr-reader-docker:amd64;docker push ualex73/dsmr-reader-docker:arm32v6-$VERSION;docker push ualex73/dsmr-reader-docker:arm64v8-$VERSION;docker push ualex73/dsmr-reader-docker:amd64-$VERSION;docker push ualex73/dsmr-reader-docker:latest"
fi

