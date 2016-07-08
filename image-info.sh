#!/bin/bash

if [ -z "$1" ]
  then
    echo "Image name needed"
    exit 1;
fi

image_name=$1

layers=`docker history $1 | tail -n +2 | wc -l`
size=`docker images $1 | tail -n +2 | awk '{print$(NF-1)"_"$NF}'`

info="_${size}/_${layers}_Layers_"

echo https://img.shields.io/badge/ImageInfo-${info}-blue.svg?style=flat-square
