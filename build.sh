#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

stacks="golang kamel node10 php python skopeo"

if [ "$1" == "clean" ] ; then
  for b in ${stacks} ; do
    rm -Rf "${b}/target"
  done
  exit 0
fi

for b in ${stacks} ; do
  "${SCRIPT_DIR}/${b}/build.sh" &
done
wait
docker system prune -af
