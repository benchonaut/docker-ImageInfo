#!/bin/bash

if [ -z "$1" ]
  then
    echo "Image name needed"
    exit 1;
fi

image_name=$1

layers=`docker history $1 | tail -n +2 | wc -l`
size=`docker images $1 | tail -n +2 | awk '{print$(NF-1)"_"$NF}'`

if [ "${#layers}" -ne "1" ]
  then
    info="_${size}/_${layers}_Layers_"
  else
    info="_${size}/${layers}_Layers_"
fi

echo https://img.shields.io/badge/ImageInfo-${info}-blue.svg?style=flat-square
