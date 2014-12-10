#!/bin/bash

if which realpath &>/dev/null; then
    cd $(realpath $(dirname $0)/../)
else
    cd $(dirname $0)/../
fi

set -e
set -u

additional_tags=()
run_tests=false
push=false

while getopts ":t:TP" opt; do
  case $opt in
    t)
        additional_tags+=($OPTARG)
    ;;
    T)
      run_tests=true
    ;;
    P)
      push=true
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
tag=$(git log -n1 --pretty=format:%h%d | grep -o -E 'v[0-9]+\.[0-9]+\.[0-9]' || echo "latest")

if [[ "$tag" != "latest" ]]; then
  additional_tags+=("release")
fi

build_cmd="docker build --rm -t gild/gaptool:$tag ."
echo "Building docker image: $build_cmd"
$build_cmd

if [ "$run_tests" = true ]; then
  echo "Running tests in gild/gaptool:$tag"
  docker run -a stdout -a stderr --rm -i -t gild/gaptool:$tag rake test 2>&1
fi

for (( i=0; i<${#additional_tags[@]}; i++ )) do
    t=${additional_tags[$i]}
    echo "Setting tag $t"
    docker tag gild/gaptool:$tag gild/gaptool:$t
done

if [ "$push" = true ]; then
  echo "Pushing images..."
  docker push gild/gaptool
fi
