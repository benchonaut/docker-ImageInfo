#!/bin/bash

# Converts bytes value to human-readable string [$1: bytes value] #https://unix.stackexchange.com/questions/44040/a-standard-tool-to-convert-a-byte-count-into-human-kib-mib-etc-like-du-ls1
bytesToHumanReadable() {
    local i=${1:-0} d="" s=0 S=("Bytes" "KiB" "MiB" "GiB" "TiB" "PiB" "EiB" "YiB" "ZiB")
    while ((i > 1024 && s < ${#S[@]}-1)); do
        printf -v d ".%02d" $((i % 1024 * 100 / 1024))
        i=$((i / 1024))
        s=$((s + 1))
    done
    echo "$i$d ${S[$s]}"
}

if [ -z "$1" ]
  then
    echo "Image name needed"
    exit 1;
fi

image_name=$1

layersraw=$(docker history $1 2>&1 )
did_we_pull=no
echo "$layersraw"|grep "Error response from daemon: No such image" -q && { did_we_pull=yes;docker pull $image_name  ; } ;

#layers=$(echo "$layersraw"| tail -n +2 | wc -l)
layers=$(echo "$res" | jq '.[].RootFS.Layers'|jq length)
[[ -z "$layers" ]] && layers=0
#size=`docker images $1 | tail -n +2 | awk '{print$(NF-1)"_"$NF}'`
res=$(sudo  docker image inspect jpillora/chisel );
imgtime=$(echo "$res" |jq -c .[].Created --raw-output);
timetime=$(date -u -d "$imgtime")
imgsize=$(echo "$res" |jq -c .[].Size --raw-output)
size=$(bytesToHumanReadable "$imgsize")

if [ "${#layers}" -ne "1" ]
  then
    info="_${size// /_}/_${layers}_Layers_/created:_${timetime// /_}"
  else
    info="_${size// /_}/${layers}_Layer_/created:_${timetime// /_}"
fi

echo "$did_we_pull"|grep yes -q && docker rmi $image_name &>/dev/null
echo '|' $image_name '| ![ '$info' ]('https://img.shields.io/badge/Image:$image_name-${info}-blue.svg?style=flat-square')  | '
#echo https://img.shields.io/badge/Image:$image_name-${info}-blue.svg?style=flat-square
