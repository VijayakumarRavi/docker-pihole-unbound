#!/bin/bash
# Run this once: docker buildx create --use --name build --node build --driver-opt network=host
PIHOLE_VER=`cat VERSION`

docker buildx build --build-arg "$PIHOLE_VER","$KEY" --platform linux/arm64/v8,linux/arm/v7,linux/amd64 -t vijaysrv/pihole-unbound:$PIHOLE_VER --push .
docker buildx build --build-arg "$PIHOLE_VER","$KEY" --platform linux/arm64/v8,linux/arm/v7,linux/amd64 -t vijaysrv/pihole-unbound:latest --push .

