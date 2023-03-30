#!/bin/bash


## rectifier

image_name=$1
## catch single image name
echo -n $image_name|tr -cd '/'|wc -c|grep ^0$ -q && image_name=library/$image_name
## catch no-reg image name (docker hub)
echo -n $image_name|tr -cd '/'|wc -c|grep ^1$ -q  && image_name=docker.io/$image_name

REGISTRY_ADDRESS=$(echo "$image_name"|cut -d"/" -f1)
echo "$REGISTRY_ADDRESS"  |grep -q "docker.io" && REGISTRY_ADDRESS=registry-1.docker.io

echo "using reg $REGISTRY_ADDRESS FOR $image_name TAG $tag" >&2
[[ -z "$USE_PROXY" ]] && REGURL="https://${REGISTRY_ADDRESS}"
[[ -z "$USE_PROXY" ]] || REGURL="${USE_PROXY}/${REGISTRY_ADDRESS}"

#[[ -z "$USE_PROXY" ]] && REGISTRY_ADDRESS="${REGISTRY_ADDRESS:-http://localhost:5000}"
REGISTRY_ADDRESS="$REGURL"





echo "$image_name"|grep -q ":" || image_name=$image_name":latest"
echo "$image_name"|grep -q ":" && tag=${image_name/*:/}
echo "$image_name"|grep -q ":" && image_name=${image_name/:*/}
(echo "$image_name" |grep -q docker.io )&& ( echo "$REGISTRY_ADDRESS"|grep -q docker.io ) && image_name=${image_name/docker.io\//}
(echo "$image_name" |grep -q quay.io )&& ( echo "$REGISTRY_ADDRESS"|grep -q quay.io ) && image_name=${image_name/quay.io\//}

echo "using reg $REGISTRY_ADDRESS FOR $image_name TAG $tag" >&2
# Address of the registry that we'll be 
# performing the inspections against.
# This is necessary as the arguments we
# supply to the API calls don't include 
# such address (the address is used in the
# url itself).




# Entry point of the script.
# If makes sure that the user supplied the right
# amount of arguments (image_name and image_tag)
# and then performs the main workflow:
#       1.      retrieve the image digest
#       2.      retrieve the configuration for
#               that digest.
get_docker_image_json_config() {
  check_args "$@"

  local image=$1
  local tag=$2
  echo "$REGISTRY_ADDRESS"|grep -q docker.io || local digest=$(get_digest $image $tag)
  echo "$REGISTRY_ADDRESS"|grep -q docker.io && token=$(get_dockerhub_token $image)
  echo "$REGISTRY_ADDRESS"|grep -q docker.io && local digest=$(get_dockerhub_digest $image $tag $token)
  echo "$REGISTRY_ADDRESS"|grep -q docker.io || get_image_configuration $image $digest
  echo "$REGISTRY_ADDRESS"|grep -q docker.io && get_dockerhub_image_configuration $image $token $digest
}

get_dockerhub_digest() {
  local image=$1
  local tag=$2
  local token=$3

  echo "Retrieving DOCKERHUB image digest.
    IMAGE:  $image
    TAG:    $tag
    TOKEN:  $token
  " >&2

  curl \
    --silent \
    --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    --header "Authorization: Bearer $token" \
    "https://registry-1.docker.io/v2/$image/manifests/$tag" \
    | jq -r '.config.digest'
}
get_dockerhub_image_configuration() {
  local image=$1
  local token=$2
  local digest=$3

  echo "Retrieving DOCKERHUB Image Configuration.
    IMAGE:  $image
    TOKEN:  $token
    DIGEST: $digest
  " >&2

  myres=$(curl \
    --silent \
    --location \
    --header "Authorization: Bearer $token" \
    "https://registry-1.docker.io/v2/$image/blobs/$digest" )
   echo "$myres" | tee /dev/shm/.dockerimage.dh.imageconfig.log 
   #| jq -r '.container_config' || echo "$myres" >&2 
}

get_dockerhub_token() {
  local image=$1

  echo "Retrieving Docker Hub token.
    IMAGE: $image
  " >&2

  curl \
    --silent \
    "https://auth.docker.io/token?scope=repository:$image:pull&service=registry.docker.io" \
    | jq -r '.token'
}

# Makes sure that we provided (from the cli) 
# enough arguments.
check_args() {
  if (($# != 2)); then
    echo "Error:
    Two arguments must be provided - $# provided.
    Usage:
      ./get-image-config.sh <image> <tag>
Aborting."
    exit 1
  fi
}


# Retrieves the digest of a specific image tag,
# that is, the address of the uppermost of a specific 
# tag of an image (see more at 
# https://docs.docker.com/registry/spec/api/#content-digests).
# 
# You can know more about the endpoint used at
# https://docs.docker.com/registry/spec/api/#pulling-an-image-manifest
get_digest() {
  local image=$1
  local tag=$2

  echo "Retrieving image digest FROM $REGISTRY_ADDRESS/v2/$image/manifests/$tag
    IMAGE:  $image
    TAG:    $tag
  " >&2

  curl \
    --silent \
    --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "$REGISTRY_ADDRESS/v2/$image/manifests/$tag" |
    jq -r '.config.digest'
}


# Retrieves the image configuration from a given
# digest.
# See more about the endpoint at:
# https://docs.docker.com/registry/spec/api/#pulling-a-layer
get_image_configuration() {
  local image=$1
  local digest=$2

  echo "Retrieving Image Configuration FROM $REGISTRY_ADDRESS/v2/$image/blobs/$digest
    IMAGE:  $image
    DIGEST: $digest
  " >&2

  curl \
    --silent \
    --location \
    "$REGISTRY_ADDRESS/v2/$image/blobs/$digest" |
    jq -r '.container_config' ||   curl \
    --silent \
    --location \
    "$REGISTRY_ADDRESS/v2/$image/blobs/$digest"
}


[[ -z "$SHIELDS_SERVER" ]] && SHIELDS_SERVER=https://img.shields.io
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



#layersraw=$(docker history $1 2>&1 )
#did_we_pull=no
#echo "$layersraw"|grep "Error response from daemon: No such image" -q && { did_we_pull=yes;docker pull $image_name  &>/dev/shm/.autopull_out ; } ;

#size=`docker images $1 | tail -n +2 | awk '{print$(NF-1)"_"$NF}'`
#res=$(  docker image inspect "$image_name" );
res=$(get_docker_image_json_config $image_name $tag )
#layers=$(echo "$layersraw"| tail -n +2 | wc -l)
layers=$(echo "$res" | jq '.[].RootFS.Layers'|jq length)
[[ -z "$layers" ]] && layers=$(echo "$res" |jq .rootfs.diff_ids|jq length)
[[ -z "$layers" ]] && layers=0

imgtime=$(echo "$res" |jq -c .[].Created --raw-output);
[[ -z "$imgtime" ]] && imgtime=$(echo "$res" |jq -c .created --raw-output)

timetime=$(date -u -d "$imgtime")
echo "$REGISTRY_ADDRESS"|grep -q docker.io || { 
                                               imgsize=$(echo "$res" |jq -c .[].Size --raw-output)
                                               [[ "$imgsize" = "0" ]] || size="Size:"$(bytesToHumanReadable "$imgsize") ; } ; ## end not dockerhub
echo "$REGISTRY_ADDRESS"|grep -q docker.io && {
size=$(
   echo "Size: ";
   curl -s https://hub.docker.com/v2/repositories/$image_name/tags/ |         jq '.results[] | select(.name=="'$tag'") | .images[] | {architecture: .architecture, size: .size}'|jq -c .|while read line ;do 
               imgsize=$(echo "$line"|jq .size --raw-output);
               [[ -z "$imgsize" ]] ||  ( arch=$(echo "$line"|jq .architecture --raw-output);echo " $arch : "$(bytesToHumanReadable "$imgsize")" |"  ) ;
done |tr -d '\n'|sed 's/|$//g')
echo -n ; } ; ## end dockerhub

#curl -s https://hub.docker.com/v2/repositories/library/alpine/tags/ | \
#        jq '.results[] | select(.name=="latest") | .images[] | {architecture: .architecture, size: .size}



[[ "$size" = "" ]] && size="0"
[[ "$size" = "0" ]] && size=""


if [ "${#layers}" -ne "1" ]
  then
    info="_${size// /_}/_${layers}_Layers_/created:_${timetime// /_}"
  else
    info="_${size// /_}/${layers}_Layer_/created:_${timetime// /_}"
fi

echo "$did_we_pull"|grep yes -q && docker rmi $image_name &>/dev/null
echo '|' $image_name '| ![ '$info' ]('"$SHIELDS_SERVER"'/badge/Image:'$image_name-${info}'-blue.svg?style=flat-square)  |'
#echo "$SHIELDS_SERVER"/badge/Image:$image_name-${info}-blue.svg?style=flat-square
