#!/bin/bash

if which realpath &>/dev/null; then
    cd $(realpath $(dirname $0)/../)
else
    cd $(dirname $0)/../
fi

set -e
set -u

declare -a additional_tags
while getopts ":t:" opt; do
  case $opt in
    t)
        additional_tags+=($OPTARG)
    ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
    ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
    ;;
  esac
done

# get tag from git: if not tag on last commit (vX.Y.Z), default to
# current branch name if no tag.
tag=$(git log -n1 --pretty=format:%h%d | grep -o -E 'v[0-9]+\.[0-9]+\.[0-9]\.+(rc|a|b)?[0-9]+' || git rev-parse --abbrev-ref HEAD)
build_cmd="docker build --rm -t gild/gaptool:$tag ."
echo "Building docker image: $build_cmd"
$build_cmd

additional_tags+=('latest')

for (( i=0; i<${#additional_tags[@]}; i++ )) do
    t=${additional_tags[$i]}
    echo "Setting tag $t"
    docker tag gild/gaptool:$tag gild/gaptool:$t
done
