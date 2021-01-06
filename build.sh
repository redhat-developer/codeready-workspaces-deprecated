#!/bin/bash -ex

# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

stacks="golang kamel node10 php python skopeo"
runmode="series" # or parallel

cleanTargetFolders () {
  for b in ${stacks} ; do 
    rm -Rf "${b}/target"
  done
}
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--clean-only') cleanTargetFolders; exit 0; shift 0;;
    '--clean') cleanTargetFolders; shift 0;;
    '--parallel'   ) runmode="parallel"; shift 0;;
  esac
  shift 1
done

if [ "$runmode" == "parallel" ] ; then # run builds in parallel, which might consume a lot of memory / disk
  for b in ${stacks} ; do
    "${SCRIPT_DIR}/${b}/build.sh" &
  done
  wait
else # run in series, which might take longer but require fewer memory / disk resources
  for b in ${stacks} ; do
    "${SCRIPT_DIR}/${b}/build.sh"
  done
fi

PODMAN=$(command -v podman || true)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker || true)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

${PODMAN} system prune -af || true
