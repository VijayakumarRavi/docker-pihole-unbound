#!/bin/bash
# Run this once: docker buildx create --use --name build --node build --driver-opt network=host
docker buildx build --platform linux/arm64/v8,linux/arm/v7,linux/amd64 -t vijaysrv/pihole-unbound:latest .

