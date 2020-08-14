#!/bin/bash

VERSION=$1

for ARCH in amd64  arm32v6 arm64v8
do
  # Replace version in Dockerfile
  if [ ! -z "$VERSION" ]; then
    sed -i "s/^ENV DSMR_READER_VERSION v.*/ENV DSMR_READER_VERSION v$VERSION/" Dockerfile.${ARCH}
  fi

  docker build -f Dockerfile.${ARCH} -t ualex73/dsmr-reader-docker:${ARCH} .

  # Tag it with a version
  if [ ! -z "$VERSION" ]; then
    docker tag ualex73/dsmr-reader-docker:${ARCH} ualex73/dsmr-reader-docker:${ARCH}-${VERSION}
  fi
done

if [ ! -z "$VERSION" ]; then
  docker tag ualex73/dsmr-reader-docker:amd64 ualex73/dsmr-reader-docker:$VERSION
  echo "=== Push to hub.docker.com ==="
  echo "docker push ualex73/dsmr-reader-docker:arm32v6;docker push ualex73/dsmr-reader-docker:arm64v8;docker push ualex73/dsmr-reader-docker:amd64;docker push ualex73/dsmr-reader-docker:arm32v6-$VERSION;docker push ualex73/dsmr-reader-docker:arm64v8-$VERSION;docker push ualex73/dsmr-reader-docker:amd64-$VERSION"

  # Do the real push anyway
  docker push ualex73/dsmr-reader-docker:arm32v6;docker push ualex73/dsmr-reader-docker:arm64v8;docker push ualex73/dsmr-reader-docker:amd64;docker push ualex73/dsmr-reader-docker:arm32v6-$VERSION;docker push ualex73/dsmr-reader-docker:arm64v8-$VERSION;docker push ualex73/dsmr-reader-docker:amd64-$VERSION

  # Do the multi-arch push of latest
  ./manifest-tool-linux-amd64 push from-spec multi-arch-manifest.yaml

  # don't care about ARM stuff in my local repo ;)
  docker rmi ualex73/dsmr-reader-docker:arm32v6 ualex73/dsmr-reader-docker:arm64v8 ualex73/dsmr-reader-docker:arm32v6-$VERSION ualex73/dsmr-reader-docker:arm64v8-$VERSION

  # Don't care about other tags
  docker rmi ualex73/dsmr-reader-docker:amd64 ualex73/dsmr-reader-docker:amd64-$VERSION
fi

