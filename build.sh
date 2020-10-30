#!/bin/bash -e

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

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

${PODMAN} system prune -af
