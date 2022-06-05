#!/usr/bin/env bash
# Script to clean Docker containers and dangling images
# This Script will exit if any of bellow happens
# nounset: Attempting to use a variable that is not defined
set -o nounset

CONTAINERS=$(docker ps -aq)
IMAGES=$(docker images --filter "dangling=true" -q --no-trunc)

if [ "${CONTAINERS}" ]; then
    docker rm ${CONTAINERS}

else
    echo 'No Containers to be removed.'
fi

if [ "${IMAGES}" ]; then
    docker rmi ${IMAGES} --force

else
    echo 'No Dangling Images to be removed.'
fi